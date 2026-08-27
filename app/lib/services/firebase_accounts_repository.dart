import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/models.dart';
import 'accounts_repository.dart';

/// Contas e telemetria de uso no Firebase (Auth + Firestore).
///
/// - `users/{uid}`: perfil da conta (nome, e-mail, lista M3U, plano, status).
///   A senha fica só no Firebase Auth, nunca no Firestore.
/// - `usage_events/{id}`: eventos de "assistiu tal conteúdo".
///
/// A conta master é um usuário normal do Auth (criado na primeira entrada);
/// as regras do Firestore liberam leitura/escrita ampla só para o e-mail dela.
class FirebaseAccountsRepository implements AccountsRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void Function()? _onChanged;
  List<AdminUser> _users = const [];
  List<UsageEvent> _events = const [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;

  @override
  Future<void> init({void Function()? onChanged}) async {
    _onChanged = onChanged;
    if (_auth.currentUser != null) _attachListeners();
  }

  void _attachListeners() {
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
  Future<String?> signInMaster(String email, String password) async {
    try {
      try {
        await _auth.signInWithEmailAndPassword(
            email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password') {
          await _auth.createUserWithEmailAndPassword(
              email: email.trim(), password: password);
        } else {
          rethrow;
        }
      }
      _attachListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'Não foi possível entrar no Firebase: ${e.message ?? e.code}';
    }
  }

  @override
  Future<void> signOut() async {
    await _usersSub?.cancel();
    await _eventsSub?.cancel();
    _usersSub = null;
    _eventsSub = null;
    _users = const [];
    _events = const [];
    await _auth.signOut();
  }

  @override
  List<AdminUser> get users => _users;

  @override
  Future<void> saveUser(AdminUser user) async {
    final isExisting = _users.any((u) => u.id == user.id);
    if (isExisting) {
      await _db
          .collection('users')
          .doc(user.id)
          .set(_toDoc(user), SetOptions(merge: true));
      return;
    }

    // Conta nova: cria no Auth por um app secundário para não deslogar o master.
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
    } finally {
      await secondary.delete();
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    await _db
        .collection('users')
        .doc(id)
        .set({'deleted': true}, SetOptions(merge: true));
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

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
      );
}
