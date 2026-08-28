import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/models.dart';
import 'accounts_repository.dart';
import 'login_guard.dart' show LoginLockEntry;

/// Contas e telemetria de uso no Firebase (Auth + Firestore).
///
/// - `users/{uid}`: perfil da conta (nome, e-mail, lista M3U, plano, status).
///   A senha fica só no Firebase Auth, nunca no Firestore.
/// - `usage_events/{id}`: eventos de "assistiu tal conteúdo".
/// - `master_bindings/{hash}`: aparelho ao qual o acesso do Master 1 está preso.
/// - `login_locks/{hash}`: trava de 24 h por 3 senhas erradas (cruza aparelhos).
///
/// A conta master é um usuário normal do Auth (criado na primeira entrada);
/// as regras do Firestore liberam leitura/escrita ampla só para os e-mails dela.
class FirebaseAccountsRepository implements AccountsRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void Function()? _onChanged;
  List<AdminUser> _users = const [];
  List<UsageEvent> _events = const [];
  Pricing _pricing = Pricing.empty;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pricingSub;

  @override
  Future<void> init({void Function()? onChanged}) async {
    _onChanged = onChanged;
    if (_auth.currentUser != null) _attachListeners();
  }

  @override
  String get backendLabel {
    String project = 'iptv';
    try {
      project = Firebase.app().options.projectId;
    } on Object {
      // ignora
    }
    final who = _auth.currentUser?.email ?? 'não autenticado';
    return 'Firebase (projeto $project) — $who';
  }

  void _attachListeners() {
    _pricingSub ??= _db.collection('config').doc('pricing').snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data != null) _pricing = Pricing.fromJson(data);
        _onChanged?.call();
      },
      onError: (Object _) {},
    );

    _usersSub ??= _db
        .collection('users')
        .where('deleted', isEqualTo: false)
        .snapshots()
        .listen(
      (snap) {
        _users = [for (final d in snap.docs) _fromDoc(d.id, d.data())]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _onChanged?.call();
      },
      onError: (Object _) {}, // conta comum não lê a coleção inteira: ok
    );

    _eventsSub ??= _db
        .collection('usage_events')
        .orderBy('w', descending: true)
        .limit(400)
        .snapshots()
        .listen(
      (snap) {
        _events = [
          for (final d in snap.docs) UsageEvent.fromJson(d.data()),
        ];
        _onChanged?.call();
      },
      onError: (Object _) {},
    );
  }

  @override
  Future<AdminUser?> authenticate(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null || data['deleted'] == true) {
        await _auth.signOut();
        return null;
      }
      final user = _fromDoc(uid, data);
      if (!user.isActive) {
        await _auth.signOut();
        return null;
      }
      _attachListeners();
      return user;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<String?> signInMaster(
    String email,
    String password, {
    List<String> legacyPasswords = const [],
  }) async {
    final e = email.trim();
    try {
      try {
        await _auth.signInWithEmailAndPassword(email: e, password: password);
      } on FirebaseAuthException catch (err) {
        final recoverable = err.code == 'user-not-found' ||
            err.code == 'invalid-credential' ||
            err.code == 'wrong-password';
        if (!recoverable) rethrow;

        // Tenta as senhas antigas e migra para a nova.
        var signedInWithLegacy = false;
        for (final old in legacyPasswords) {
          try {
            await _auth.signInWithEmailAndPassword(email: e, password: old);
          } on FirebaseAuthException {
            continue;
          }
          signedInWithLegacy = true;
          try {
            await _auth.currentUser?.updatePassword(password);
          } on FirebaseAuthException {
            // segue logado com a senha antiga; migra numa próxima entrada
          }
          break;
        }

        if (!signedInWithLegacy) {
          // Com a proteção contra enumeração de e-mail (padrão nos projetos
          // novos), o Firebase devolve 'invalid-credential' tanto para senha
          // errada quanto para conta inexistente. Então tentamos CRIAR a conta
          // master; se o e-mail já existir, aí sim a senha está errada.
          try {
            await _auth.createUserWithEmailAndPassword(
                email: e, password: password);
          } on FirebaseAuthException catch (e2) {
            if (e2.code == 'email-already-in-use') {
              return 'Senha master incorreta.';
            }
            if (e2.code == 'operation-not-allowed') {
              return 'Ative "E-mail/Senha" em Authentication no console do '
                  'Firebase para criar o acesso master.';
            }
            rethrow;
          }
        }
      }
      _attachListeners();
      return null;
    } on FirebaseException catch (err) {
      return 'Não foi possível entrar no Firebase: ${err.message ?? err.code}';
    }
  }

  @override
  Future<void> signOut() async {
    await _usersSub?.cancel();
    await _eventsSub?.cancel();
    await _pricingSub?.cancel();
    _usersSub = null;
    _eventsSub = null;
    _pricingSub = null;
    _users = const [];
    _events = const [];
    _pricing = Pricing.empty;
    await _auth.signOut();
  }

  @override
  Future<void> reportDevice(String userId, String device) async {
    try {
      await _db.collection('users').doc(userId).set(
        {'lastDevice': device, 'lastSeenAt': DateTime.now().toIso8601String()},
        SetOptions(merge: true),
      );
    } on FirebaseException {
      // Sem permissão / offline: não é crítico.
    }
  }

  // ---------- trava de aparelho ----------
  @override
  Future<String?> readDeviceBinding(String key) async {
    try {
      final snap = await _db
          .collection('master_bindings')
          .doc(key)
          .get()
          .timeout(const Duration(seconds: 8));
      return snap.data()?['deviceId'] as String?;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeDeviceBinding(
      String key, String deviceId, String label) async {
    try {
      await _db.collection('master_bindings').doc(key).set({
        'deviceId': deviceId,
        'label': label,
        'boundAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException {
      // best-effort
    }
  }

  @override
  Future<void> clearDeviceBinding(String key) async {
    try {
      await _db.collection('master_bindings').doc(key).delete();
    } on FirebaseException {
      // best-effort
    }
  }

  // ---------- trava de tentativas de login ----------
  @override
  Future<DateTime?> readRemoteLoginLock(String emailHash) async {
    final snap = await _db
        .collection('login_locks')
        .doc(emailHash)
        .get()
        .timeout(const Duration(seconds: 8));
    final v = snap.data()?['lockedUntil'];
    return v is String ? DateTime.tryParse(v) : null;
  }

  @override
  Future<void> writeRemoteLoginLock(
    String emailHash, {
    required String email,
    required int fails,
    required DateTime firstFailAt,
    DateTime? lockedUntil,
  }) async {
    await _db.collection('login_locks').doc(emailHash).set({
      'email': email,
      'fails': fails,
      'firstFailAt': firstFailAt.toIso8601String(),
      'lockedUntil': lockedUntil?.toIso8601String(),
    });
  }

  @override
  Future<void> clearRemoteLoginLock(String emailHash) async {
    try {
      await _db.collection('login_locks').doc(emailHash).delete();
    } on FirebaseException {
      // best-effort
    }
  }

  @override
  Future<List<LoginLockEntry>> listRemoteLoginLocks() async {
    final snap = await _db
        .collection('login_locks')
        .get()
        .timeout(const Duration(seconds: 8));
    final out = <LoginLockEntry>[];
    for (final d in snap.docs) {
      final m = d.data();
      final email = (m['email'] ?? '') as String;
      if (email.isEmpty) continue;
      out.add(LoginLockEntry(
        email: email,
        fails: (m['fails'] as num? ?? 0).toInt(),
        firstFailAt: m['firstFailAt'] is String
            ? DateTime.tryParse(m['firstFailAt'] as String)
            : null,
        lockedUntil: m['lockedUntil'] is String
            ? DateTime.tryParse(m['lockedUntil'] as String)
            : null,
      ));
    }
    return out;
  }

  @override
  Pricing get pricing => _pricing;

  @override
  Future<void> savePricing(Pricing pricing) async {
    if (_auth.currentUser == null) {
      throw Exception('Sessão master expirou. Saia e entre de novo.');
    }
    _pricing = pricing; // otimista: a UI reflete já; o listener concilia
    try {
      await _db
          .collection('config')
          .doc('pricing')
          .set(pricing.toJson(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Sem permissão para salvar. Confira as regras do Firestore '
          '(coleção config) e se você está logado como master.',
        );
      }
      throw Exception('Falha ao salvar no servidor: ${e.message ?? e.code}');
    }
  }

  @override
  List<AdminUser> get users => _users;

  /// Busca qualquer doc de conta com este e-mail, **incluindo os excluídos**
  /// (o listener vivo filtra `deleted:false`, por isso a consulta é direta).
  Future<({String uid, Map<String, dynamic> data})?> _findAnyByEmail(
      String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return (uid: d.id, data: d.data());
  }

  @override
  Future<SaveOutcome> saveUser(AdminUser user) async {
    final isExisting = _users.any((u) => u.id == user.id);
    if (isExisting) {
      await _db
          .collection('users')
          .doc(user.id)
          .set(_toDoc(user), SetOptions(merge: true));
      return SaveOutcome.updated;
    }

    // Conta nova. Antes de criar no Auth, vê se o e-mail já existiu (e foi
    // excluído): sem Admin SDK não dá para apagar do Auth, então reativamos o
    // perfil e mandamos e-mail para a pessoa definir a nova senha.
    final existing = await _findAnyByEmail(user.email);
    if (existing != null) {
      if (existing.data['deleted'] != true) {
        throw Exception('Já existe uma conta ativa com esse e-mail.');
      }
      final revived = _toDoc(user)
        ..['deleted'] = false
        ..['revivedAt'] = DateTime.now().toIso8601String()
        ..remove('createdAt'); // preserva a data original
      await _db
          .collection('users')
          .doc(existing.uid)
          .set(revived, SetOptions(merge: true));
      try {
        await _auth.sendPasswordResetEmail(email: user.email.trim());
      } on FirebaseException {
        // segue mesmo assim; o master pode reenviar pelo formulário
      }
      return SaveOutcome.revived;
    }

    // Conta realmente nova: cria no Auth por um app secundário para não deslogar
    // o master.
    final secondary = await Firebase.initializeApp(
      name: 'creator-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(
        email: user.email.trim(),
        password: user.password,
      );
      final uid = cred.user!.uid;
      await FirebaseAuth.instanceFor(app: secondary).signOut();
      await _db.collection('users').doc(uid).set(_toDoc(user));
      return SaveOutcome.created;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(
          'Este e-mail já existe no servidor. Recadastre pelo mesmo e-mail '
          'para reativar a conta, ou use outro e-mail.',
        );
      }
      rethrow;
    } finally {
      await secondary.delete();
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).set(
      {'deleted': true, 'deletedAt': DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }

  @override
  bool get canMasterSetPassword => false;

  @override
  bool get canEmailPasswordReset => true;

  @override
  Future<String?> setPassword(AdminUser user, String newPassword) async =>
      'No modo Firebase a senha não é trocada pelo painel. Use "Enviar e-mail '
      'de redefinição" ou peça para a pessoa redefinir pelo link do e-mail.';

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Não há conta com esse e-mail no servidor.');
        case 'invalid-email':
          throw Exception('E-mail inválido.');
        case 'too-many-requests':
          throw Exception('Muitas tentativas. Aguarde alguns minutos.');
        default:
          throw Exception('Não foi possível enviar: ${e.message ?? e.code}');
      }
    }
  }

  @override
  List<UsageEvent> get events => _events;

  @override
  Future<void> recordEvent(UsageEvent event) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final data = event.toJson()..['uid'] = uid;
    await _db.collection('usage_events').add(data);
  }

  @override
  Future<void> clearEvents() async {
    final snap = await _db.collection('usage_events').limit(400).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Map<String, dynamic> _toDoc(AdminUser u) => {
        'name': u.name,
        'email': u.email.trim(),
        'm3uUrl': u.m3uUrl,
        'plan': u.plan.name,
        'status': u.status.name,
        'createdAt': u.createdAt.toIso8601String(),
        'expiresAt': u.expiresAt?.toIso8601String(),
        'deleted': false,
      };

  AdminUser _fromDoc(String id, Map<String, dynamic> d) => AdminUser(
        id: id,
        name: (d['name'] ?? '') as String,
        email: (d['email'] ?? '') as String,
        password: '',
        m3uUrl: (d['m3uUrl'] ?? '') as String,
        plan: UserPlan.fromString((d['plan'] ?? 'mensal') as String),
        status: UserStatus.fromString((d['status'] ?? 'active') as String),
        createdAt:
            DateTime.tryParse((d['createdAt'] ?? '') as String) ?? DateTime.now(),
        expiresAt: d['expiresAt'] != null
            ? DateTime.tryParse(d['expiresAt'] as String)
            : null,
        lastDevice: (d['lastDevice'] ?? '') as String,
        lastSeenAt: d['lastSeenAt'] != null
            ? DateTime.tryParse(d['lastSeenAt'] as String)
            : null,
      );
}
