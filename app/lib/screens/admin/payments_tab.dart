import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Aba Pagamentos: valores editáveis de cada plano.
class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  late final TextEditingController _mensal;
  late final TextEditingController _trimestral;
  late final TextEditingController _semestral;
  late final TextEditingController _anual;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().pricing;
    _mensal = TextEditingController(text: _fmt(p.mensal));
    _trimestral = TextEditingController(text: _fmt(p.trimestral));
    _semestral = TextEditingController(text: _fmt(p.semestral));
    _anual = TextEditingController(text: _fmt(p.anual));
    for (final c in [_mensal, _trimestral, _semestral, _anual]) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    _mensal.dispose();
    _trimestral.dispose();
    _semestral.dispose();
    _anual.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == 0 ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    setState(() => _saving = true);
    final pricing = Pricing(
      mensal: _parse(_mensal),
      trimestral: _parse(_trimestral),
      semestral: _parse(_semestral),
      anual: _parse(_anual),
    );

    String? error;
    var timedOut = false;
    try {
      await context
          .read<AppState>()
          .savePricing(pricing)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      timedOut = true;
    } on Object catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      // Sucesso/timeout: some com o "não salvo". Erro: mantém para tentar de novo.
      _dirty = error != null;
    });

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.bad,
        content: Text('Não salvou: $error'),
      ));
    } else if (timedOut) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Salvo no aparelho; sincroniza quando a internet voltar.'),
      ));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Preços salvos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionLabel('Valores dos planos'),
        Text(
          'Usados na aba Faturamento e mostrados como referência. Deixe em '
          'branco o que você não vende.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        _field('Mensal', _mensal),
        _field('Trimestral', _trimestral),
        _field('Semestral', _semestral),
        _field('Anual', _anual),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving || !_dirty ? null : _save,
          child: Text(_saving ? 'Salvando…' : 'Salvar valores'),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            prefixText: r'R$ ',
            hintText: '0,00',
          ),
        ),
      );
}
