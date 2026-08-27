import '../models/models.dart';
import 'storage.dart';

/// Credencial master fixa do app. Sempre abre o painel de controle.
const kMasterEmail = 'marcioscg@hotmail.com';
const kMasterPassword = '27062015EmillY';

bool isMasterCredential(String email, String password) =>
    email.trim().toLowerCase() == kMasterEmail && password == kMasterPassword;

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
  /// em caso de sucesso ou uma mensagem de erro.
  Future<String?> signInMaster(String email, String password);

  Future<void> signOut();

  List<AdminUser> get users;
  Future<void> saveUser(AdminUser user);
  Future<void> deleteUser(String id);

  /// Dispara e-mail de redefinição de senha (no-op no modo local).
  Future<void> sendPasswordReset(String email);

  List<UsageEvent> get events;
  Future<void> recordEvent(UsageEvent event);
  Future<void> clearEvents();
}

/// Tudo neste aparelho, via [Storage]/SharedPreferences.
class LocalAccountsRepository implements AccountsRepository {
  LocalAccountsRepository(this._storage);

  final Storage _storage;

  @override
  Future<void> init({void Function()? onChanged}) async {}

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
  Future<String?> signInMaster(String email, String password) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  List<AdminUser> get users => _storage.adminUsers;

  @override
  Future<void> saveUser(AdminUser user) async {
    final list = users.toList();
    final i = list.indexWhere((u) => u.id == user.id);
    if (i >= 0) {
      list[i] = user;
    } else {
      list.add(user);
    }
    await _storage.saveAdminUsers(list);
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
