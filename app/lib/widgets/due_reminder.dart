import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Mostra, no máximo 1x por dia, um popup quando a mensalidade da conta comum
/// vence em ≤1 dia (ou já venceu), com o botão do WhatsApp para pagar.
Future<void> maybeShowDueReminder(BuildContext context) async {
  final state = context.read<AppState>();
  if (!state.dueReminderPending) return;

  final account = state.session!.account!;
  await state.markDueReminderShown();
  if (!context.mounted) return;

  final expired = account.isExpired;
  final expires = account.expiresAt;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      title: Text(expired ? 'Mensalidade vencida' : 'Sua mensalidade vence'),
      content: Text(
        expired
            ? 'O acesso está vencido${expires != null ? ' desde ${_date(expires)}' : ''}. '
                'Faça o pagamento para continuar assistindo.'
            : 'Falta 1 dia para o vencimento'
                '${expires != null ? ' (${_date(expires)})' : ''}. '
                'Garanta o pagamento para não perder o acesso.',
        style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Agora não'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bad,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            Launcher.whatsapp(
              'Quero pagar minha mensalidade do MIAU NET '
              '(plano ${account.plan.label}'
              '${expires != null ? ', vence ${_date(expires)}' : ''}).',
            );
          },
          icon: const Icon(Icons.chat, size: 18),
          label: const Text('Pagar pelo WhatsApp'),
        ),
      ],
    ),
  );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
