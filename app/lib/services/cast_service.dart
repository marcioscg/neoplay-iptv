import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Transmissão para Chromecast, Google TV e TVs com Cast embutido.
///
/// Encapsula o SDK do Google Cast para que as telas não dependam dele
/// diretamente: se o plugin falhar em algum aparelho, o app continua
/// funcionando normalmente na tela do celular.
class CastService {
  CastService._();
  static final CastService instance = CastService._();

  bool _ready = false;
  bool get isAvailable => _ready;

  /// Inicializa o contexto do Cast. Seguro de chamar mais de uma vez.
  Future<void> init() async {
    if (_ready) return;
    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      if (Platform.isAndroid) {
        GoogleCastContext.instance.setSharedInstanceWithOptions(
          GoogleCastOptionsAndroid(appId: appId),
        );
      } else if (Platform.isIOS) {
        GoogleCastContext.instance.setSharedInstanceWithOptions(
          IOSGoogleCastOptions(
            GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
          ),
        );
      } else {
        return;
      }
      _ready = true;
    } on Object catch (e) {
      debugPrint('Cast indisponível: $e');
      _ready = false;
    }
  }

  /// Aparelhos encontrados na rede local.
  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  /// Sessão atual (null quando não está transmitindo).
  Stream<GoogleCastSession?> get sessionStream =>
      GoogleCastSessionManager.instance.currentSessionStream;

  bool get isConnected =>
      _ready &&
      GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.connected;

  String? get deviceName =>
      GoogleCastSessionManager.instance.currentSession?.device?.friendlyName;

  void startDiscovery() {
    if (!_ready) return;
    try {
      GoogleCastDiscoveryManager.instance.startDiscovery();
    } on Object catch (e) {
      debugPrint('Falha ao buscar aparelhos: $e');
    }
  }

  void stopDiscovery() {
    if (!_ready) return;
    try {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    } on Object catch (_) {
      // Sem impacto para o usuário.
    }
  }

  /// Conecta e já manda o item tocar na TV.
  ///
  /// Tem timeout em cada etapa: sem isso, quando a TV aceita a conexão mas o
  /// vídeo não carrega (formato, bloqueio do provedor), o app fica preso na
  /// "tela azul do Chromecast" para sempre.
  Future<void> castItem(
    GoogleCastDevice device,
    MediaItem item, {
    Duration position = Duration.zero,
  }) async {
    if (!_ready) {
      throw const CastException('Transmissão indisponível neste aparelho');
    }

    // Checa o stream no celular ANTES de conectar: formato real, URL HLS
    // alternativa e erros HTTP. Assim um formato impossível para o
    // Chromecast vira mensagem clara, sem "conectar" à toa.
    final target = await resolveTarget(item);

    try {
      await GoogleCastSessionManager.instance
          .startSessionWithDevice(device)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      await _safeDisconnect();
      throw const CastException(
        'A TV não respondeu à conexão. Confirme que ela está ligada e no '
        'mesmo Wi-Fi do celular.',
      );
    } on Object catch (e) {
      await _safeDisconnect();
      throw CastException('Não foi possível conectar na TV: ${_short(e)}');
    }

    try {
      await GoogleCastRemoteMediaClient.instance
          .loadMedia(
            GoogleCastMediaInformationIOS(
              // O receptor padrão do Chromecast usa contentId como URL de mídia.
              contentId: target.url,
              streamType: item.kind == MediaKind.live
                  ? CastMediaStreamType.live
                  : CastMediaStreamType.buffered,
              contentUrl: Uri.parse(target.url),
              contentType: target.contentType,
              metadata: GoogleCastMovieMediaMetadata(
                title: item.name,
                subtitle: item.group,
                images: [
                  if (item.logo.isNotEmpty && item.logo.startsWith('http'))
                    GoogleCastImage(url: Uri.parse(item.logo)),
                ],
              ),
            ),
            autoPlay: true,
            playPosition: position,
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      await _safeDisconnect();
      throw CastException(
        isRiskyFormat(item.url)
            ? 'Conectou na TV, mas o vídeo não abriu — este arquivo está em '
                'MKV/AVI, que o Chromecast costuma recusar. Tente um episódio '
                'em MP4 ou m3u8.'
            : 'Conectou na TV, mas o vídeo não carregou. Pode ser bloqueio do '
                'provedor da lista ou formato não suportado pelo Chromecast.',
      );
    } on Object catch (e) {
      await _safeDisconnect();
      throw CastException('A TV recusou o vídeo: ${_short(e)}');
    }

    // loadMedia só confirma o envio; o receptor ainda pode falhar ao abrir.
    if (await _receiverFailed(target.url)) {
      await _safeDisconnect();
      throw CastException(
        target.hls
            ? 'A TV não conseguiu abrir este stream HLS. O receptor do '
                'Chromecast exige que o servidor da lista libere acesso '
                '(CORS/HTTPS); este provedor não libera. Assista no celular.'
            : 'A TV não conseguiu reproduzir este vídeo (codec ou formato não '
                'suportado pelo Chromecast). Assista no celular.',
      );
    }
  }

  /// Espera o receptor sair de "carregando". `true` só com erro explícito;
  /// sem status (ou ainda carregando) não trava quem já funcionava.
  Future<bool> _receiverFailed(String url) async {
    bool mine(GoggleCastMediaStatus s) {
      final info = s.mediaInformation;
      return info == null ||
          info.contentId == url ||
          info.contentUrl?.toString() == url;
    }

    try {
      final s = await GoogleCastRemoteMediaClient.instance.mediaStatusStream
          .where((s) =>
              s != null &&
              mine(s) &&
              (s.playerState == CastMediaPlayerState.playing ||
                  s.playerState == CastMediaPlayerState.paused ||
                  (s.playerState == CastMediaPlayerState.idle &&
                      s.idleReason == GoogleCastMediaIdleReason.error)))
          .first
          .timeout(const Duration(seconds: 15));
      return s!.playerState == CastMediaPlayerState.idle;
    } on Object {
      return false;
    }
  }

  static final _xtreamPath =
      RegExp(r'^(https?://[^/]+)/(?:live/)?([^/]+)/([^/]+)/(\d+)(?:\.ts)?$');

  /// Define a URL e o content-type que vão para a TV.
  ///
  /// - Ao vivo em MPEG-TS (`.../usuario/senha/123` ou `.ts`): o receptor
  ///   padrão não toca TS puro; tenta a variante HLS do painel Xtream
  ///   (`/live/usuario/senha/123.m3u8`).
  /// - Filmes/episódios: o tipo vem dos primeiros bytes (MP4, MKV, HLS), não
  ///   só da extensão.
  Future<CastTarget> resolveTarget(MediaItem item) async {
    final url = item.url;
    final clean = url.split('?').first;

    if (item.kind == MediaKind.live && !clean.toLowerCase().contains('.m3u8')) {
      final m = _xtreamPath.firstMatch(clean);
      if (m != null) {
        final hlsUrl = '${m[1]}/live/${m[2]}/${m[3]}/${m[4]}.m3u8';
        if ((await _probe(hlsUrl)).kind == CastStreamKind.hls) {
          return CastTarget(hlsUrl, 'application/x-mpegurl', hls: true);
        }
      }
    }

    final p = await _probe(url);
    if (p.status == 401 || p.status == 403) {
      throw const CastException(
        'O servidor da lista recusou o acesso (limite de conexões ou '
        'credencial). A TV também seria bloqueada.',
      );
    }
    if (p.status == 404) {
      throw const CastException(
          'Stream não encontrado (404). O conteúdo pode ter mudado de endereço.');
    }
    switch (p.kind) {
      case CastStreamKind.hls:
        return CastTarget(url, 'application/x-mpegurl', hls: true);
      case CastStreamKind.ts:
        throw const CastException(
          'Este conteúdo é transmitido em MPEG-TS puro, formato que o '
          'Chromecast não reproduz, e o servidor não oferece versão HLS '
          '(m3u8). Assista no celular.',
        );
      case CastStreamKind.mp4:
        return CastTarget(url, 'video/mp4');
      case CastStreamKind.matroska:
        // Sem transcodificação no app: MKV não é formato suportado pelo
        // receptor padrão, e rotulá-lo como outro container não o converte.
        throw const CastException(_mkvMessage);
      case CastStreamKind.unknown:
        // Não deu para ler o stream: decide pela extensão, recusando o que o
        // receptor padrão não suporta (MKV/AVI e TS progressivo).
        final clean = url.split('?').first.toLowerCase();
        if (isRiskyFormat(url)) throw const CastException(_mkvMessage);
        if (clean.endsWith('.ts')) {
          throw const CastException(
            'Este conteúdo está em MPEG-TS, formato que o Chromecast não '
            'reproduz. Assista no celular.',
          );
        }
        final type = contentTypeFor(url);
        return CastTarget(url, type, hls: type == 'application/x-mpegurl');
    }
  }

  static const _mkvMessage =
      'Este vídeo está em MKV/AVI, formato que o Chromecast não reproduz '
      '(o app não converte vídeo). Assista no celular ou escolha uma versão '
      'em MP4 ou m3u8.';

  /// Lê só os primeiros bytes (com o User-Agent do Chromecast, porque é ele
  /// quem vai buscar o vídeo).
  Future<_Probe> _probe(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['Range'] = 'bytes=0-4095'
        ..headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux armv7l) CrKey/1.56';
      final res = await client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) {
        return _Probe(res.statusCode, CastStreamKind.unknown);
      }
      final bytes = <int>[];
      await for (final chunk
          in res.stream.timeout(const Duration(seconds: 6))) {
        bytes.addAll(chunk);
        if (bytes.length >= 200) break;
      }
      return _Probe(
          res.statusCode, sniff(bytes, res.headers['content-type'] ?? ''));
    } on Object {
      return const _Probe(0, CastStreamKind.unknown);
    } finally {
      client.close();
    }
  }

  /// Identifica o formato pelos primeiros bytes (e, na falta, pelo header).
  @visibleForTesting
  static CastStreamKind sniff(List<int> b, String contentType) {
    var i = 0;
    // pula BOM/espaços antes de "#EXTM3U"
    while (i < b.length &&
        (b[i] == 0xEF ||
            b[i] == 0xBB ||
            b[i] == 0xBF ||
            b[i] == 0x20 ||
            b[i] == 0x0A ||
            b[i] == 0x0D)) {
      i++;
    }
    if (b.length - i >= 7 &&
        String.fromCharCodes(b.sublist(i, i + 7)) == '#EXTM3U') {
      return CastStreamKind.hls;
    }
    if (b.length >= 8 && String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') {
      return CastStreamKind.mp4;
    }
    if (b.length >= 4 &&
        b[0] == 0x1A &&
        b[1] == 0x45 &&
        b[2] == 0xDF &&
        b[3] == 0xA3) {
      return CastStreamKind.matroska;
    }
    if (b.isNotEmpty && b[0] == 0x47 && (b.length < 189 || b[188] == 0x47)) {
      return CastStreamKind.ts;
    }
    final ct = contentType.toLowerCase();
    if (ct.contains('mpegurl')) return CastStreamKind.hls;
    if (ct.contains('mp2t')) return CastStreamKind.ts;
    if (ct.contains('mp4')) return CastStreamKind.mp4;
    return CastStreamKind.unknown;
  }

  Future<void> _safeDisconnect() async {
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    } on Object catch (_) {
      // já desconectado / sem sessão
    }
  }

  static String _short(Object e) {
    final t = '$e'.replaceAll('Exception:', '').trim();
    return t.length > 100 ? '${t.substring(0, 100)}…' : t;
  }

  Future<void> play() async => GoogleCastRemoteMediaClient.instance.play();
  Future<void> pause() async => GoogleCastRemoteMediaClient.instance.pause();

  Future<void> seek(Duration position) async =>
      GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: position),
      );

  Future<void> disconnect() async {
    if (!_ready) return;
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    } on Object catch (e) {
      debugPrint('Falha ao encerrar a transmissão: $e');
    }
  }

  Stream<GoggleCastMediaStatus?> get mediaStatusStream =>
      GoogleCastRemoteMediaClient.instance.mediaStatusStream;

  /// O Chromecast escolhe o decodificador pelo content-type, então enviar o
  /// tipo certo evita a tela preta com áudio.
  static String contentTypeFor(String url) {
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.m3u8') || clean.contains('.m3u8')) {
      return 'application/x-mpegurl';
    }
    if (clean.endsWith('.mpd')) return 'application/dash+xml';
    if (clean.endsWith('.webm')) return 'video/webm';
    if (clean.endsWith('.ts')) return 'video/mp2t';
    return 'video/mp4';
  }

  /// Formatos que o Chromecast costuma recusar.
  static bool isRiskyFormat(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mkv') || clean.endsWith('.avi');
  }
}

/// URL e content-type efetivamente enviados ao Chromecast.
class CastTarget {
  final String url;
  final String contentType;
  final bool hls;
  const CastTarget(this.url, this.contentType, {this.hls = false});
}

enum CastStreamKind { hls, ts, mp4, matroska, unknown }

class _Probe {
  final int status;
  final CastStreamKind kind;
  const _Probe(this.status, this.kind);
}

class CastException implements Exception {
  final String message;
  const CastException(this.message);
  @override
  String toString() => message;
}
