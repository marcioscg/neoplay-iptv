import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pin_dialog.dart';
import 'setup_screen.dart';

/// Tela 14 — Configurações.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.playlist;
    final account = state.account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          const SectionLabel('Lista ativa'),
          CategoryTile(
            title: p?.name ?? 'Nenhuma lista',
            count: 0,
            icon: Icons.tv,
            onTap: () => _replace(context),
          ),
          _info(
            p == null
                ? 'Cadastre uma lista para começar.'
                : p.kind == PlaylistKind.xtream
                    ? 'Xtream Codes · ${p.normalizedHost}'
                    : 'M3U · ${p.url}',
          ),
          if (account != null)
            _info(
              'Conta ${account.status} · '
              '${account.expiresAt == null ? 'sem validade informada' : 'expira ${_date(account.expiresAt!)}'} · '
              '${account.activeConnections}/${account.maxConnections} conexões',
            ),
          _info(
              '${state.live.length} canais e ${state.movies.length} filmes importados'),
          const SectionLabel('Conteúdo'),
          CategoryTile(
            title: 'Atualizar lista de reprodução',
            count: 0,
            icon: Icons.refresh,
            onTap: () {
              Navigator.of(context).pop();
              state.refresh();
            },
          ),
          if (state.isMaster)
            CategoryTile(
              title: 'Trocar de lista',
              count: 0,
              icon: Icons.playlist_add,
              onTap: () => _replace(context),
            ),
          CategoryTile(
            title: 'Limpar favoritos e histórico',
            count: state.favoriteItems.length,
            icon: Icons.delete_outline,
            onTap: () => _confirmClearFavorites(context, state),
          ),
          const SectionLabel('Controle parental'),
          SwitchListTile(
            tileColor: AppColors.surface1,
            title: const Text('Ativar controle parental',
                style: TextStyle(fontSize: 14)),
            subtitle: Text(
              'Pede PIN para abrir categorias adultas',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            value: state.parentalActive,
            onChanged: (v) => _toggleParental(context, state, v),
          ),
          if (state.parentalActive) ...[
            SwitchListTile(
              tileColor: AppColors.surface1,
              title: const Text('Ocultar conteúdo adulto',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                'Some com as categorias adultas da navegação e da busca',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              value: state.hideAdult,
              onChanged: state.setHideAdult,
            ),
            CategoryTile(
              title: state.isParentalEnabled
                  ? 'Alterar PIN parental'
                  : 'Definir PIN parental (padrão 1234)',
              count: 0,
              icon: Icons.password,
              onTap: () => changeParentalPin(context, state),
            ),
            if (state.adultUnlocked)
              CategoryTile(
                title: 'Bloquear conteúdo adulto agora',
                count: 0,
                icon: Icons.lock_outline,
                onTap: state.lockAdultSession,
              ),
          ],
          if (!state.isMaster && state.session?.account != null) ...[
            const SectionLabel('Meu plano'),
            _PlanCard(account: state.session!.account!),
          ],
          const SectionLabel('Conta'),
          _info('Conectado como ${state.session?.displayName ?? '—'}'),
          CategoryTile(
            title: 'Sair da conta',
            count: 0,
            icon: Icons.logout,
            onTap: () => _confirmLogout(context, state),
          ),
          const SectionLabel('Aplicativo'),
          _ThemeRow(state: state),
          const _StaticRow(label: 'Língua', value: 'Português (BR)'),
          const _StaticRow(label: 'Player', value: 'ExoPlayer (Media3)'),
          CategoryTile(
            title: 'Exclusão de dados',
            count: 0,
            icon: Icons.no_accounts_outlined,
            onTap: () => _confirmReset(context, state),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'MIAU NET · versão 1.0.7',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF5B6274)),
                ),
                SizedBox(height: 6),
                Text(
                  'Este aplicativo não fornece, hospeda ou distribui conteúdo. '
                  'Todo o conteúdo vem da lista cadastrada pelo usuário.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF5B6274), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45),
        ),
      );

  void _replace(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SetupScreen()),
    );
  }

  Future<void> _toggleParental(
      BuildContext context, AppState state, bool value) async {
    await state.setParentalEnabled(value);
    if (!context.mounted) return;
    if (value && !state.isParentalEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN padrão 1234. Troque em "Alterar PIN parental".'),
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, AppState state) async {
    final ok = await _ask(context, 'Sair da conta neste aparelho?');
    if (!ok || !context.mounted) return;
    await state.logout();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmClearFavorites(
      BuildContext context, AppState state) async {
    final ok = await _ask(context, 'Limpar favoritos e histórico?');
    if (!ok) return;
    await state.clearFavoritesAndHistory();
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final ok = await _ask(
      context,
      'Apagar todos os dados do app (lista, favoritos e cache)?',
    );
    if (!ok) return;
    await state.resetEverything();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<bool> _ask(BuildContext context, String question) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Confirmar'),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Seletor de tema: do sistema / claro / escuro.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Tema de cores', style: TextStyle(fontSize: 14)),
          ),
          DropdownButton<AppThemeChoice>(
            value: state.themeChoice,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 13, color: AppColors.text),
            dropdownColor: AppColors.surface2,
            items: [
              for (final c in AppThemeChoice.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) {
              if (v != null) state.setThemeChoice(v);
            },
          ),
        ],
      ),
    );
  }
}

/// Cartão "Meu plano" para a conta comum: validade + botão de renovação.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.account});
  final AdminUser account;

  @override
  Widget build(BuildContext context) {
    final expired = account.isExpired;
    final days = account.daysLeft;
    final lifetime = account.plan == UserPlan.vitalicio;

    final String status;
    if (lifetime) {
      status = 'Plano vitalício — sem data de vencimento.';
    } else if (account.expiresAt == null) {
      status = 'Sem data de vencimento informada.';
    } else if (expired) {
      status = 'Venceu em ${_date(account.expiresAt!)}. Renove para liberar.';
    } else {
      status = 'Vence em ${_date(account.expiresAt!)}'
          '${days != null ? ' · ${days <= 0 ? 'hoje' : '$days ${days == 1 ? 'dia' : 'dias'}'}' : ''}.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expired
              ? AppColors.bad.withValues(alpha: 0.5)
              : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Plano ${account.plan.label}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(status,
              style: TextStyle(
                  fontSize: 12,
                  color: expired ? AppColors.bad : AppColors.muted,
                  height: 1.4)),
          if (!lifetime) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _renew(context),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Renovar pelo WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _renew(BuildContext context) async {
    final ok =
        await Launcher.whatsapp('Meu plano está vencendo, preciso renovar.');
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
