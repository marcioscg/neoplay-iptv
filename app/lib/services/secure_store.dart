import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda segredos pequenos (senha do "manter conectado") no armazenamento
/// protegido do sistema — Keystore no Android. Substitui o texto puro que ficava
/// em SharedPreferences até a 1.0.7.
///
/// Alguns aparelhos lançam exceção na leitura/gravação (Keystore corrompido,
/// backup restaurado de outro device). Todo acesso é embrulhado em try/catch e
/// devolve `null` / silencia — nesse caso o app só perde o preenchimento
/// automático, sem quebrar o login.
class SecureStore {
  static const _opts = AndroidOptions(encryptedSharedPreferences: true);
  static const _storage = FlutterSecureStorage(aOptions: _opts);

  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (e) {
      debugPrint('SecureStore.read($key) falhou: $e');
      return null;
    }
  }

  static Future<void> write(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } on Object catch (e) {
      debugPrint('SecureStore.write($key) falhou: $e');
    }
  }

  static Future<void> delete(String key) => write(key, null);
}
