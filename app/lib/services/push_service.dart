import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push (Firebase Cloud Messaging): permissão, token e toque na notificação.
///
/// O envio é feito pela Cloud Function agendada (`functions/index.js`), que lê
/// o perfil gravado em `push_profiles/{uid}`. O app só entrega o token e as
/// sugestões calculadas a partir do catálogo que está no aparelho.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;
  String? token;

  /// Chamado com o `data` da notificação tocada (app aberto ou frio).
  void Function(Map<String, dynamic> data)? onOpen;

  /// Chamado quando o token muda, para regravar o perfil.
  void Function()? onToken;

  /// Pede permissão e obtém o token. Só deve rodar com Firebase real.
  Future<void> start() async {
    if (_started || !(Platform.isAndroid || Platform.isIOS)) return;
    _started = true;
    try {
      final m = FirebaseMessaging.instance;
      final perm = await m.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      token = await m.getToken();
      m.onTokenRefresh.listen((t) {
        token = t;
        onToken?.call();
      });
      FirebaseMessaging.onMessageOpenedApp
          .listen((msg) => onOpen?.call(msg.data));
      final initial = await m.getInitialMessage();
      if (initial != null) onOpen?.call(initial.data);
    } on Object catch (e) {
      // Sem Google Play Services / APNs não configurado: segue sem push.
      debugPrint('Push indisponível: $e');
    }
  }

  String get platform => Platform.isIOS ? 'ios' : 'android';
}
