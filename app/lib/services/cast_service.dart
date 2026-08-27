import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

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
              contentId: item.url,
              streamType: item.kind == MediaKind.live
                  ? CastMediaStreamType.live
                  : CastMediaStreamType.buffered,
              contentUrl: Uri.parse(item.url),
              contentType: contentTypeFor(item.url),
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
    if (clean.endsWith('.mkv')) return 'video/x-matroska';
    if (clean.endsWith('.ts')) return 'video/mp2t';
    return 'video/mp4';
  }

  /// Formatos que o Chromecast costuma recusar.
  static bool isRiskyFormat(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mkv') || clean.endsWith('.avi');
  }
}

class CastException implements Exception {
  final String message;
  const CastException(this.message);
  @override
  String toString() => message;
}
