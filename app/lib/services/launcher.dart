import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Atalhos para abrir apps externos (usado no botão de renovação de plano).
class Launcher {
  /// Número do suporte no WhatsApp (formato internacional, só dígitos).
  static const whatsappNumber = '5541999928132';

  /// Abre a conversa do WhatsApp com o suporte, já com a mensagem escrita.
  static Future<bool> whatsapp(String message) {
    final uri = Uri.parse(
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}',
    );
    return _open(uri);
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('Não foi possível abrir $uri: $e');
      return false;
    }
  }
}
