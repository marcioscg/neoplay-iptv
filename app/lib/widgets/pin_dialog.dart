import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Pede o PIN parental. Devolve true e libera a sessão adulta quando acerta.
Future<bool> promptParentalPin(
  BuildContext context,
  AppState state, {
  String title = 'Conteúdo protegido',
}) async {
  if (!state.parentalActive || state.adultUnlocked) return true;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _PinDialog(
      title: title,
      message: 'Digite o PIN para liberar o conteúdo adulto nesta sessão.',
      validate: state.verifyPin,
    ),
  );
  if (ok == true) {
    state.unlockAdultSession();
    return true;
  }
  return false;
}

/// Define ou troca o PIN parental (pede o PIN atual quando já existe).
Future<void> changeParentalPin(BuildContext context, AppState state) async {
  if (state.isParentalEnabled) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PinDialog(
        title: 'PIN atual',
        message: 'Confirme o PIN atual para poder trocá-lo.',
        validate: state.verifyPin,
      ),
    );
    if (ok != true) return;
  }
  if (!context.mounted) return;

  final novo = await showDialog<String>(
    context: context,
    builder: (ctx) => _PinDialog(
      title: 'Novo PIN',
      message: 'Escolha um PIN de 4 dígitos para o controle parental.',
      returnValue: true,
    ),
  );
  if (novo == null || !context.mounted) return;
  await state.setParentalPin(novo);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('PIN atualizado.')),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.message,
    this.validate,
    this.returnValue = false,
  });

  final String title;
  final String message;
  final bool Function(String)? validate;

  /// Quando true, o diálogo devolve o texto digitado (para cadastrar PIN novo)
  /// em vez de um booleano de validação.
  final bool returnValue;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final value = _ctrl.text.trim();
    if (value.length < 4) {
      setState(() => _error = 'O PIN tem 4 dígitos.');
      return;
    }
    if (widget.returnValue) {
      Navigator.of(context).pop(value);
      return;
    }
    if (widget.validate?.call(value) ?? false) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'PIN incorreto.';
        _ctrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface2,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 24, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              errorText: _error,
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}
