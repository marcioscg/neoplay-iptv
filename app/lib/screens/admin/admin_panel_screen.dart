import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'account_form_screen.dart';
import 'usage_dashboard.dart';

/// Painel de controle do master: cadastro de contas e central de uso.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DefaultTabController(
      length: 2,
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
            tabs: [
              Tab(text: 'Contas'),
              Tab(text: 'Central de uso'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AccountsTab(state: state),
            const UsageDashboard(),
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
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface1,
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface3,
                      child: Text(
                        _initial(u.name.isNotEmpty ? u.name : u.email),
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                    title: Text(u.name.isEmpty ? u.email : u.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.email,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${u.plan.label} · ${_statusText(u)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: u.isActive ? AppColors.ok : AppColors.bad,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _openForm(context, u);
                        if (v == 'delete') _confirmDelete(context, u);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                    onTap: () => _openForm(context, u),
                  ),
                );
              },
            ),
    );
  }

  static String _initial(String s) {
    final t = s.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }

  static String _statusText(AdminUser u) {
    if (u.status == UserStatus.blocked) return 'Bloqueado';
    if (u.isExpired) return 'Expirado';
    if (u.expiresAt != null) {
      final d = u.expiresAt!;
      return 'até ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return 'Ativo';
  }

  void _openForm(BuildContext context, AdminUser? user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountFormScreen(user: user)),
    );
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
}
