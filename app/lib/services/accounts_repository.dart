import '../models/models.dart';
import 'storage.dart';

/// Credencial master fixa do app. Sempre abre o painel de controle.
const kMasterEmail = 'marcioscg@hotmail.com';
const kMasterPassword = '27062015EmillY';

bool isMasterCredential(String email, String password) =>
    email.trim().toLowerCase() == kMasterEmail && password == kMasterPassword;

/// Contrato de persistência de contas e telemetria de uso.
///
/// A implementação atual ([LocalAccountsRepository]) guarda tudo neste
/// aparelho. Migrar para um backend (Firebase) é implementar esta mesma
/// interface e injetar a nova classe em `main.dart` — nenhuma tela muda.
abstract class AccountsRepository {
  Future<void> init();

  List<AdminUser> get users;
  AdminUser? userByEmail(String email);
  AdminUser? authenticate(String email, String password);
  Future<void> saveUser(AdminUser user);
  Future<void> deleteUser(String id);

  List<UsageEvent> get events;
  Future<void> recordEvent(UsageEvent event);
  Future<void> clearEvents();
}

class LocalAccountsRepository implements AccountsRepository {
  LocalAccountsRepository(this._storage);

  final Storage _storage;

  @override
  Future<void> init() async {}

  @override
  List<AdminUser> get users => _storage.adminUsers;

  @override
  AdminUser? userByEmail(String email) {
    final target = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email.trim().toLowerCase() == target) return u;
    }
    return null;
  }

  @override
  AdminUser? authenticate(String email, String password) {
    final u = userByEmail(email);
    if (u == null || u.password != password) return null;
    return u;
  }

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
