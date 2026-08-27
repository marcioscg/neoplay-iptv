import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ponte para o Picture-in-Picture nativo (Android 8+).
///
/// O lado nativo (`MainActivity.kt`) expõe `isSupported` / `enter` / `setPlaying`
/// e devolve `action` (rewind / playpause / forward) e `pipModeChanged`.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('miaunet/pip');

  void Function(String control)? _onAction;
  void Function(bool inPip)? _onModeChanged;
  bool _supported = false;
  bool _probed = false;

  /// A tela do player registra os callbacks enquanto está viva.
  void attach({
    required void Function(String control) onAction,
    required void Function(bool inPip) onModeChanged,
  }) {
    _onAction = onAction;
    _onModeChanged = onModeChanged;
    _channel.setMethodCallHandler(_handle);
  }

  void detach() {
    _onAction = null;
    _onModeChanged = null;
    _channel.setMethodCallHandler(null);
  }

  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'action':
        _onAction?.call('${call.arguments}');
      case 'pipModeChanged':
        _onModeChanged?.call(call.arguments == true);
    }
  }

  /// `true` só no Android com suporte a PiP. Resultado é cacheado.
  Future<bool> isSupported() async {
    if (_probed) return _supported;
    _probed = true;
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on Object catch (e) {
      debugPrint('PiP indisponível: $e');
      _supported = false;
    }
    return _supported;
  }

  /// Pede para entrar em PiP agora. Retorna `true` se entrou.
  Future<bool> enter({required bool playing}) async {
    if (!await isSupported()) return false;
    try {
      return await _channel
              .invokeMethod<bool>('enter', {'playing': playing}) ??
          false;
    } on Object catch (e) {
      debugPrint('PiP enter falhou: $e');
      return false;
    }
  }

  /// Atualiza o ícone play/pause da janelinha.
  Future<void> setPlaying(bool playing) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('setPlaying', {'playing': playing});
    } on Object catch (_) {
      // sem impacto
    }
  }
}
