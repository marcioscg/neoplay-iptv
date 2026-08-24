import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
          const SectionLabel('Aplicativo'),
          const _StaticRow(label: 'Tema de cores', value: 'Escuro (padrão)'),
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
                  'NEOPLAY · versão 1.0.2',
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
          style: const TextStyle(
              fontSize: 12, color: AppColors.muted, height: 1.45),
        ),
      );

  void _replace(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SetupScreen()),
    );
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SetupScreen()),
      (route) => false,
    );
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
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
