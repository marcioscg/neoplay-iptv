import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'accounts_repository.dart';
import 'storage.dart';

/// Resultado de uma checagem de bloqueio de login.
class LoginLockState {
  final bool locked;
  final DateTime? until;
  const LoginLockState(this.locked, this.until);

  static const open = LoginLockState(false, null);

  /// Horas inteiras que ainda faltam para liberar (mínimo 1 quando ainda travado).
  int get hoursLeft {
    if (until == null) return 0;
    final diff = until!.difference(DateTime.now());
    if (diff.inSeconds <= 0) return 0;
    return diff.inMinutes ~/ 60 + 1;
  }
}

/// Trava de força‑bruta: 3 senhas erradas para o mesmo e‑mail bloqueiam o acesso
/// por 24 h. A contagem local vale por aparelho; quando o Firebase está ligado, um
/// espelho em `login_locks/<hash>` cruza os aparelhos e deixa o Master 1
/// desbloquear de longe.
class LoginGuard {
  LoginGuard(this._storage, this._accounts);

  final Storage _storage;
  final AccountsRepository _accounts;

  static const maxAttempts = 3;
  static const window = Duration(hours: 1);
  static const lockDuration = Duration(hours: 24);

  static String hashEmail(String email) =>
      sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();

  String _key(String email) => email.trim().toLowerCase();

  /// Verifica se [email] está bloqueado (local ou remoto). Nunca lança.
  Future<LoginLockState> check(String email) async {
    final now = DateTime.now();
    DateTime? until;

    final local = _storage.loginFails[_key(email)];
    final localUntil = _parse(local?['lockedUntil']);
    if (localUntil != null && localUntil.isAfter(now)) until = localUntil;

    try {
      final remoteUntil = await _accounts.readRemoteLoginLock(hashEmail(email));
      if (remoteUntil != null && remoteUntil.isAfter(now)) {
        if (until == null || remoteUntil.isAfter(until)) until = remoteUntil;
      }
    } on Object {
      // Sem rede / backend local: vale só o que está no aparelho.
    }

    return until == null ? LoginLockState.open : LoginLockState(true, until);
  }

  /// Registra uma tentativa falha. Devolve o estado de bloqueio resultante.
  Future<LoginLockState> registerFailure(String email) async {
    final now = DateTime.now();
    final map = _storage.loginFails;
    final entry = Map<String, dynamic>.from(map[_key(email)] as Map? ?? {});

    final firstFailAt = _parse(entry['firstFailAt']);
    final fresh = firstFailAt == null || now.difference(firstFailAt) > window;
    final fails = (fresh ? 0 : (entry['fails'] as num? ?? 0).toInt()) + 1;

    entry['fails'] = fails;
    entry['firstFailAt'] =
        (fresh ? now : firstFailAt!).toIso8601String();

    DateTime? lockedUntil;
    if (fails >= maxAttempts) {
      lockedUntil = now.add(lockDuration);
      entry['lockedUntil'] = lockedUntil.toIso8601String();
    }

    map[_key(email)] = entry;
    await _storage.saveLoginFails(map);

    try {
      await _accounts.writeRemoteLoginLock(
        hashEmail(email),
        fails: fails,
        firstFailAt: _parse(entry['firstFailAt'])!,
        lockedUntil: lockedUntil,
      );
    } on Object {
      // best-effort
    }

    return lockedUntil == null
        ? LoginLockState.open
        : LoginLockState(true, lockedUntil);
  }

  /// Limpa a trava de [email] neste aparelho e no backend.
  Future<void> clear(String email) async {
    final map = _storage.loginFails;
    if (map.remove(_key(email)) != null) {
      await _storage.saveLoginFails(map);
    }
    try {
      await _accounts.clearRemoteLoginLock(hashEmail(email));
    } on Object {
      // best-effort
    }
  }

  static DateTime? _parse(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
