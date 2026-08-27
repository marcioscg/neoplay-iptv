import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Aba Faturamento: estimativas de receita e gráficos simples a partir das
/// contas cadastradas e da tabela de preços.
class BillingTab extends StatelessWidget {
  const BillingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final users = state.adminUsers;
    final pricing = state.pricing;

    if (users.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Sem contas para faturar',
        message: 'Cadastre contas e defina os preços na aba Pagamentos.',
      );
    }

    final active = users.where((u) => u.isActive).toList();
    final expired = users.where((u) => u.isExpired).length;
    final blocked = users.where((u) => u.status == UserStatus.blocked).length;

    // MRR: soma do valor mensal equivalente de cada conta ativa.
    final mrr = active.fold<double>(
        0, (sum, u) => sum + pricing.monthlyEquivalent(u.plan));

    // Receita por plano = contas ativas do plano × preço do plano.
    final planCounts = <UserPlan, int>{};
    for (final u in active) {
      planCounts[u.plan] = (planCounts[u.plan] ?? 0) + 1;
    }
    final planRevenue = <UserPlan, double>{
      for (final p in UserPlan.values)
        p: (planCounts[p] ?? 0) * pricing.forPlan(p),
    };
    final maxPlanRevenue = planRevenue.values.fold<double>(
        0, (m, v) => v > m ? v : m);

    // Novos cadastros nos últimos 6 meses.
    final now = DateTime.now();
    final months = <DateTime>[
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final signups = <String, int>{for (final m in months) _mLabel(m): 0};
    for (final u in users) {
      final key = _mLabel(DateTime(u.createdAt.year, u.createdAt.month));
      if (signups.containsKey(key)) signups[key] = signups[key]! + 1;
    }
    final maxSignups =
        signups.values.fold<int>(1, (m, v) => v > m ? v : m).toDouble();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SectionLabel('Receita mensal estimada (MRR)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Text(
            _money(mrr),
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.accent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Text(
            '${active.length} conta(s) ativa(s) · projeção anual ${_money(mrr * 12)}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        const SectionLabel('Receita por plano (ciclo cheio)'),
        for (final p in UserPlan.values)
          if (p != UserPlan.vitalicio)
            MiniBar(
              label: '${p.label} · ${planCounts[p] ?? 0} conta(s)',
              amount: planRevenue[p] ?? 0,
              max: maxPlanRevenue,
              display: _money(planRevenue[p] ?? 0),
            ),
        const SectionLabel('Situação das contas'),
        MiniBar(
            label: 'Ativas',
            amount: active.length.toDouble(),
            max: users.length.toDouble(),
            display: '${active.length}'),
        MiniBar(
            label: 'Vencidas',
            amount: expired.toDouble(),
            max: users.length.toDouble(),
            display: '$expired'),
        MiniBar(
            label: 'Bloqueadas',
            amount: blocked.toDouble(),
            max: users.length.toDouble(),
            display: '$blocked'),
        const SectionLabel('Novos cadastros (6 meses)'),
        for (final entry in signups.entries)
          MiniBar(
            label: entry.key,
            amount: entry.value.toDouble(),
            max: maxSignups,
            display: '${entry.value}',
          ),
      ],
    );
  }

  static String _mLabel(DateTime d) {
    const names = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    return '${names[d.month - 1]}/${d.year % 100}';
  }

  static String _money(double v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    // separador de milhar
    final parts = s.split(',');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $intPart,${parts[1]}';
  }
}
