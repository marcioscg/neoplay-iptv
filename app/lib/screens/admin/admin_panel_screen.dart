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
    // Só o Master 1 vê a "Central de uso".
    final showUsage = state.canViewUsage;

    final tabs = <Tab>[
      const Tab(text: 'Contas'),
      if (showUsage) const Tab(text: 'Central de uso'),
      const Tab(text: 'Pagamentos'),
      const Tab(text: 'Faturamento'),
    ];
    final views = <Widget>[
      _AccountsTab(state: state),
      if (showUsage) const UsageDashboard(),
      const PaymentsTab(),
      const BillingTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
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
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: views),
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
    final isMaster2 = state.session?.masterLevel == 2;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nova conta'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (alerts.isNotEmpty) _RenewalAlerts(users: alerts),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Nenhuma conta cadastrada. Toque em "Nova conta" para criar um '
                'acesso com e-mail, senha e a lista M3U da pessoa.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            )
          else ...[
            const SectionLabel('Todas as contas'),
            ...users.map((u) => _AccountRow(user: u)),
          ],
          const SectionLabel('Tentativas de login'),
          _LoginUnlock(state: state),
          if (isMaster2) ...[
            const SectionLabel('Master 1'),
            _Master1BindingRelease(state: state),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Backend: ${state.accounts.backendLabel}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
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
            // Vermelho quando venceu ou falta 3 dias ou menos.
            final urgent = expired || days <= 3;
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
                  backgroundColor: urgent ? AppColors.bad : null,
                  foregroundColor: urgent ? Colors.white : null,
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
      content: Text(
        'Remover o acesso de ${u.email}?\n\n'
        'O e-mail continua reservado no servidor. Se recadastrar depois com o '
        'mesmo e-mail, a conta é reativada e a pessoa redefine a senha por e-mail.',
      ),
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

/// Campo para o master liberar um e-mail travado por 3 senhas erradas.
class _LoginUnlock extends StatefulWidget {
  const _LoginUnlock({required this.state});
  final AppState state;

  @override
  State<_LoginUnlock> createState() => _LoginUnlockState();
}

class _LoginUnlockState extends State<_LoginUnlock> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    setState(() => _busy = true);
    await widget.state.unlockLoginAttempts(email);
    if (!mounted) return;
    setState(() => _busy = false);
    _email.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tentativas de "$email" liberadas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3 senhas erradas bloqueiam o e-mail por 24 h. Informe o e-mail para '
            'liberar antes disso.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail bloqueado',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: Text(_busy ? '...' : 'Liberar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botão (só Master 2) que remove a trava de aparelho do Master 1.
class _Master1BindingRelease extends StatefulWidget {
  const _Master1BindingRelease({required this.state});
  final AppState state;

  @override
  State<_Master1BindingRelease> createState() => _Master1BindingReleaseState();
}

class _Master1BindingReleaseState extends State<_Master1BindingRelease> {
  bool _busy = false;

  Future<void> _release() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Liberar aparelho do Master 1'),
        content: const Text(
          'O Master 1 poderá entrar de um novo celular, que passa a ser o '
          'aparelho travado. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await widget.state.clearMaster1DeviceBinding();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trava de aparelho do Master 1 removida.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _release,
        icon: const Icon(Icons.lock_open_outlined, size: 18),
        label: const Text('Liberar trava de aparelho do Master 1'),
      ),
    );
  }
}
