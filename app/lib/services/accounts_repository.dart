import '../models/models.dart';
import 'login_guard.dart' show LoginLockEntry;
import 'storage.dart';

/// Credenciais master fixas do app. Sempre abrem o painel de controle.
///
/// Os valores podem ser sobrescritos no build com `--dart-define` (CI), mas o
/// default mantém tudo funcionando em `flutter run` local.
const kMasterEmail = 'marcioscg@hotmail.com';
const kMasterPassword =
    String.fromEnvironment('MASTER1_PASS', defaultValue: '27062015EmillY#');

/// Senhas antigas do Master 1. Se o usuário do Firebase Auth ainda estiver com
/// uma delas, [AccountsRepository.signInMaster] migra para [kMasterPassword].
const kMasterPasswordLegacy = <String>['27062015EmillY'];

/// Master 2: tudo que o Master 1 faz, menos a aba "Central de uso".
const kMaster2Email = 'nunestrc09@gmail.com';
const kMaster2Password =
    String.fromEnvironment('MASTER2_PASS', defaultValue: 'Nunes@2026');

/// Nível de acesso da credencial informada: 1 = Master 1, 2 = Master 2, 0 = comum.
int masterLevelFor(String email, String password) {
  final e = email.trim().toLowerCase();
  if (e == kMasterEmail &&
      (password == kMasterPassword || kMasterPasswordLegacy.contains(password))) {
    return 1;
  }
  if (e == kMaster2Email && password == kMaster2Password) return 2;
  return 0;
}

/// Resultado de [AccountsRepository.saveUser].
enum SaveOutcome {
  /// Conta nova criada (Auth + Firestore).
  created,

  /// Conta existente atualizada.
  updated,

  /// E‑mail já existia (conta antes excluída): o perfil foi reativado e um
  /// e‑mail de redefinição de senha foi disparado.
  revived,
}

/// Contrato de persistência de contas e telemetria de uso.
///
/// Duas implementações: [LocalAccountsRepository] (só este aparelho) e
/// `FirebaseAccountsRepository` (contas e uso compartilhados). A escolha é feita
/// em `main.dart` conforme o Firebase inicializa ou não. Nenhuma tela conhece a
/// implementação concreta.
abstract class AccountsRepository {
  /// [onChanged] é chamado quando a lista de contas ou de eventos muda por fora
  /// (ex.: sincronização do Firestore), para a UI se atualizar.
  Future<void> init({void Function()? onChanged});

  /// Autentica uma conta comum. `null` quando e-mail/senha não conferem ou a
  /// conta está bloqueada/removida.
  Future<AdminUser?> authenticate(String email, String password);

  /// Garante que a conta master esteja autenticada no backend. Retorna `null`
  /// em caso de sucesso ou uma mensagem de erro. [legacyPasswords] são senhas
  /// antigas aceitas para migração automática para [password].
  Future<String?> signInMaster(
    String email,
    String password, {
    List<String> legacyPasswords = const [],
  });

  Future<void> signOut();

  /// Rótulo curto do backend em uso, para diagnóstico no painel.
  String get backendLabel;

  List<AdminUser> get users;

  /// Cria, atualiza ou reativa a conta. Ver [SaveOutcome].
  Future<SaveOutcome> saveUser(AdminUser user);
  Future<void> deleteUser(String id);

  /// O master consegue definir a senha de uma conta direto pelo painel?
  /// `true` no modo local; `false` no Firebase (lá a troca é por e-mail).
  bool get canMasterSetPassword;

  /// Este backend envia e-mail de redefinição de senha? `false` no modo local.
  bool get canEmailPasswordReset;

  /// Define uma nova senha para [user]. `null` em sucesso ou uma mensagem.
  Future<String?> setPassword(AdminUser user, String newPassword);

  /// Dispara e-mail de redefinição de senha (no modo local lança erro claro).
  Future<void> sendPasswordReset(String email);

  /// Registra o aparelho e o momento do último acesso de uma conta.
  Future<void> reportDevice(String userId, String device);

  // ---------- trava de aparelho (Master 1) ----------
  /// Aparelho ao qual [key] está preso, ou `null` se ainda livre.
  Future<String?> readDeviceBinding(String key);
  Future<void> writeDeviceBinding(String key, String deviceId, String label);
  Future<void> clearDeviceBinding(String key);

  // ---------- trava de tentativas de login ----------
  /// Momento até quando [emailHash] está bloqueado, ou `null`.
  Future<DateTime?> readRemoteLoginLock(String emailHash);
  Future<void> writeRemoteLoginLock(
    String emailHash, {
    required String email,
    required int fails,
    required DateTime firstFailAt,
    DateTime? lockedUntil,
  });
  Future<void> clearRemoteLoginLock(String emailHash);

  /// Lista de e-mails com tentativas erradas guardada no backend (só o master
  /// consegue ler). Vazia no modo local.
  Future<List<LoginLockEntry>> listRemoteLoginLocks();

  List<UsageEvent> get events;
  Future<void> recordEvent(UsageEvent event);
  Future<void> clearEvents();

  /// Tabela de preços dos planos, compartilhada entre os aparelhos do master.
  Pricing get pricing;
  Future<void> savePricing(Pricing pricing);
}

/// Tudo neste aparelho, via [Storage]/SharedPreferences.
class LocalAccountsRepository implements AccountsRepository {
  LocalAccountsRepository(this._storage);

  final Storage _storage;

  @override
  Future<void> init({void Function()? onChanged}) async {}

  @override
  String get backendLabel =>
      'LOCAL — Firebase desligado; e-mail de recuperação indisponível';

  AdminUser? _userByEmail(String email) {
    final target = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email.trim().toLowerCase() == target) return u;
    }
    return null;
  }

  @override
  Future<AdminUser?> authenticate(String email, String password) async {
    final u = _userByEmail(email);
    if (u == null || u.password != password) return null;
    return u;
  }

  @override
  Future<String?> signInMaster(
    String email,
    String password, {
    List<String> legacyPasswords = const [],
  }) async =>
      null;

  @override
  Future<void> signOut() async {}

  @override
  bool get canMasterSetPassword => true;

  @override
  bool get canEmailPasswordReset => false;

  @override
  Future<String?> setPassword(AdminUser user, String newPassword) async {
    final list = users.toList();
    final i = list.indexWhere((u) => u.id == user.id);
    if (i < 0) return 'Conta não encontrada neste aparelho.';
    list[i] = list[i].copyWith(password: newPassword);
    await _storage.saveAdminUsers(list);
    return null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw Exception(
      'Sem servidor de e-mail no modo local. Defina a nova senha da conta '
      'direto no painel (campo "Nova senha" ao editar a conta).',
    );
  }

  @override
  Future<void> reportDevice(String userId, String device) async {
    final list = users.toList();
    final i = list.indexWhere((u) => u.id == userId);
    if (i < 0) return;
    list[i] = list[i].copyWith(lastDevice: device, lastSeenAt: DateTime.now());
    await _storage.saveAdminUsers(list);
  }

  @override
  Future<String?> readDeviceBinding(String key) async =>
      _storage.deviceBinding(key);

  @override
  Future<void> writeDeviceBinding(
          String key, String deviceId, String label) =>
      _storage.saveDeviceBinding(key, deviceId);

  @override
  Future<void> clearDeviceBinding(String key) =>
      _storage.saveDeviceBinding(key, null);

  @override
  Future<DateTime?> readRemoteLoginLock(String emailHash) async => null;

  @override
  Future<void> writeRemoteLoginLock(
    String emailHash, {
    required String email,
    required int fails,
    required DateTime firstFailAt,
    DateTime? lockedUntil,
  }) async {}

  @override
  Future<void> clearRemoteLoginLock(String emailHash) async {}

  @override
  Future<List<LoginLockEntry>> listRemoteLoginLocks() async => const [];

  @override
  Pricing get pricing => _storage.pricing;

  @override
  Future<void> savePricing(Pricing pricing) => _storage.savePricing(pricing);

  @override
  List<AdminUser> get users => _storage.adminUsers;

  @override
  Future<SaveOutcome> saveUser(AdminUser user) async {
    final list = users.toList();
    final i = list.indexWhere((u) => u.id == user.id);
    if (i >= 0) {
      list[i] = user;
      await _storage.saveAdminUsers(list);
      return SaveOutcome.updated;
    }
    list.add(user);
    await _storage.saveAdminUsers(list);
    return SaveOutcome.created;
  }

  @override
  Future<void> deleteUser(String id) async {
    await _storage.saveAdminUsers(users.where((u) => u.id != id).toList());
  }

  @override
  List<UsageEvent> get events => _storage.usageEvents;

  @override
  Future<void> recordEvent(UsageEvent event) async {
    final list = _storage.usageEvents..insert(0, event);
    if (list.length > 400) list.removeRange(400, list.length);
    await _storage.saveUsageEvents(list);
  }

  @override
  Future<void> clearEvents() => _storage.saveUsageEvents(const []);
}
