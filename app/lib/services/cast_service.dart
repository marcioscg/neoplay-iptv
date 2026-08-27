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
  Future<void> castItem(
    GoogleCastDevice device,
    MediaItem item, {
    Duration position = Duration.zero,
  }) async {
    if (!_ready) {
      throw const CastException('Transmissão indisponível neste aparelho');
    }

    await GoogleCastSessionManager.instance.startSessionWithDevice(device);
    await GoogleCastRemoteMediaClient.instance.loadMedia(
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
    );
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
