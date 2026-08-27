import 'dart:io';

import 'package:flutter/foundation.dart';

/// Descrição curta do aparelho de onde a conta acessou, para o painel mostrar
/// "de onde cada pessoa usa o app".
///
/// 1.0.5 usa só o que o `dart:io` entrega sem plugin: sistema + versão
/// (ex.: "Android 13"). Dá para trocar por `device_info_plus` mais tarde e
/// obter marca/modelo — o resto do fluxo (Firestore, tela do painel) já está
/// pronto para uma string mais rica.
class DeviceLabel {
  static String? _cached;

  static Future<String> resolve() async {
    if (_cached != null) return _cached!;
    try {
      if (Platform.isAndroid) {
        _cached = 'Android${_androidVersion()}';
      } else if (Platform.isIOS) {
        _cached = 'iOS ${Platform.operatingSystemVersion}';
      } else {
        _cached =
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } on Object catch (e) {
      debugPrint('DeviceLabel indisponível: $e');
      _cached = 'Aparelho desconhecido';
    }
    return _cached!.trim();
  }

  /// Extrai " 13" de algo como "… (Android 13) …".
  static String _androidVersion() {
    final m = RegExp(r'Android[ ]?([0-9]+(?:\.[0-9]+)?)')
        .firstMatch(Platform.operatingSystemVersion);
    return m != null ? ' ${m.group(1)}' : '';
  }
}
