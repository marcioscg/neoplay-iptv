import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'account_form_screen.dart';
import 'billing_tab.dart';
import 'payments_tab.dart';
import 'usage_dashboard.dart';

/// Painel de controle do master: contas, uso, pagamentos e faturamento.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel de controle'),
          actions: [
            IconButton(
              tooltip: 'Usar como aplicativo',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => context.read<AppState>().enterMasterAppMode(),
            ),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AppState>().logout(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Contas'),
              Tab(text: 'Central de uso'),
              Tab(text: 'Pagamentos'),
              Tab(text: 'Faturamento'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AccountsTab(state: state),
            const UsageDashboard(),
            const PaymentsTab(),
            const BillingTab(),
          ],
        ),
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final users = state.adminUsers;
    final alerts = [...state.expiredUsers, ...state.expiringSoonUsers];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nova conta'),
      ),
      body: users.isEmpty
          ? const EmptyState(
              icon: Icons.group_outlined,
              title: 'Nenhuma conta cadastrada',
              message:
                  'Toque em "Nova conta" para criar um acesso com e-mail, senha '
                  'e a lista M3U que vai rodar no app da pessoa.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (alerts.isNotEmpty) _RenewalAlerts(users: alerts),
                const SectionLabel('Todas as contas'),
                ...users.map((u) => _AccountRow(user: u)),
              ],
            ),
    );
  }

  void _openForm(BuildContext context, AdminUser? user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountFormScreen(user: user)),
    );
  }
}

/// Bloco de destaque no topo: contas vencidas e perto de vencer, com renovação
/// em um toque.
class _RenewalAlerts extends StatelessWidget {
  const _RenewalAlerts({required this.users});
  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Renovações (${users.length})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ...users.map((u) {
            final expired = u.isExpired;
            final days = u.daysLeft ?? 0;
            return ListTile(
              dense: true,
              title: Text(u.name.isEmpty ? u.email : u.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                expired
                    ? 'Venceu — acesso bloqueado'
                    : 'Vence em ${days <= 0 ? 'menos de 1 dia' : '$days ${days == 1 ? 'dia' : 'dias'}'}',
                style: TextStyle(
                    fontSize: 11,
                    color: expired ? AppColors.bad : AppColors.muted),
              ),
              trailing: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => _confirmRenew(context, u),
                child: const Text('Renovar'),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surface3,
          child: Text(
            _initial(u.name.isNotEmpty ? u.name : u.email),
            style: TextStyle(color: AppColors.text),
          ),
        ),
        title: Text(u.name.isEmpty ? u.email : u.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${u.plan.label} · ${_statusText(u)}',
              style: TextStyle(
                fontSize: 11,
                color: u.isActive ? AppColors.ok : AppColors.bad,
              ),
            ),
            if (u.lastDevice.isNotEmpty)
              Text(
                'Aparelho: ${u.lastDevice}'
                '${u.lastSeenAt != null ? ' · ${_date(u.lastSeenAt!)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
          ],
        ),
        isThreeLine: u.lastDevice.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _openForm(context, u);
              case 'renew':
                _confirmRenew(context, u);
              case 'block':
                context.read<AppState>().setUserBlocked(u, true);
              case 'unblock':
                context.read<AppState>().setUserBlocked(u, false);
              case 'delete':
                _confirmDelete(context, u);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (u.plan != UserPlan.vitalicio)
              const PopupMenuItem(
                  value: 'renew', child: Text('Renovar (+1 período)')),
            if (u.status == UserStatus.blocked)
              const PopupMenuItem(
                  value: 'unblock', child: Text('Desbloquear'))
            else
              const PopupMenuItem(value: 'block', child: Text('Bloquear')),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
        onTap: () => _openForm(context, u),
      ),
    );
  }

  void _openForm(BuildContext context, AdminUser? user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountFormScreen(user: user)),
    );
  }
}

String _initial(String s) {
  final t = s.trim();
  return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
}

String _statusText(AdminUser u) {
  if (u.status == UserStatus.blocked) return 'Bloqueado';
  if (u.isExpired) return 'Vencido — renove para liberar';
  if (u.expiresAt != null) return 'até ${_date(u.expiresAt!)}';
  return 'Ativo';
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Future<void> _confirmRenew(BuildContext context, AdminUser u) async {
  final next = u.renewedExpiry();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      title: const Text('Renovar plano'),
      content: Text(
        'Renovar ${u.email} por mais um período do plano ${u.plan.label}?'
        '${next != null ? '\n\nNova validade: ${_date(next)}.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Renovar'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await context.read<AppState>().renewUser(u);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plano renovado.')),
      );
    }
  }
}

Future<void> _confirmDelete(BuildContext context, AdminUser u) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      title: const Text('Excluir conta'),
      content: Text('Remover o acesso de ${u.email}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await context.read<AppState>().deleteAdminUser(u.id);
  }
}
