import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identificador estável do aparelho, usado para travar o acesso do Master 1 em
/// um único celular (1.0.8).
///
/// O Android moderno não deixa mais um app ler um id de hardware único sem
/// permissões invasivas (`ANDROID_ID` saiu das libs, `serialNumber` exige
/// `READ_PHONE_STATE`). Então usamos um UUID aleatório gerado na primeira
/// execução e guardado no aparelho. Consequências, todas desejáveis para uma
/// trava de aparelho:
///  - o id acompanha atualizações do app;
///  - reinstalar / limpar os dados gera um id novo (não dá para burlar a trava
///    reinstalando — o Master 2 precisa liberar);
///  - o valor real fica no Firestore (`master_bindings`), não no código.
class DeviceIdentity {
  static const _kUuid = 'device_uuid';
  static String? _cached;

  static Future<String> stableId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(_kUuid);
    if (uuid == null || uuid.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
      uuid = base64Url.encode(bytes).replaceAll('=', '');
      await prefs.setString(_kUuid, uuid);
    }
    _cached = uuid;
    return uuid;
  }
}
