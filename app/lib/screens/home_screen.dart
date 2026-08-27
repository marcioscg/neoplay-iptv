import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'items_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Tela 05 — Home com abas Canais / Filmes / Séries / Favoritos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const MiauLogo(),
          actions: [
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar lista',
              icon: const Icon(Icons.refresh),
              onPressed: state.stage == LoadStage.loading
                  ? null
                  : () => state.refresh(),
            ),
            IconButton(
              tooltip: 'Configurações',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Canais'),
              Tab(text: 'Filmes'),
              Tab(text: 'Séries'),
              Tab(text: 'Favoritos'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (state.stage == LoadStage.loading) _loadingBar(state),
            Expanded(
              child: TabBarView(
                children: [
                  _ChannelsTab(state: state),
                  _MoviesTab(state: state),
                  _SeriesTab(state: state),
                  _FavoritesTab(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBar(AppState state) => Container(
        color: AppColors.surface2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.progressLabel.isEmpty
                    ? 'Atualizando…'
                    : state.progressLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.live.isEmpty) {
      return _emptyOrError(context, state, 'Nenhum canal na lista ativa');
    }
    final cats = state.liveCategories;

    return ListView(
      children: [
        CategoryTile(
          title: 'Todos os canais',
          count: state.live.length,
          icon: Icons.grid_view_rounded,
          onTap: () => _open(context, 'Todos os canais', state.live),
        ),
        CategoryTile(
          title: 'Assistido recentemente',
          count: state.recentItems.length,
          icon: Icons.history,
          onTap: () =>
              _open(context, 'Assistido recentemente', state.recentItems),
        ),
        CategoryTile(
          title: 'Favoritos',
          count: state.favoriteItems.length,
          icon: Icons.favorite_border,
          highlight: true,
          onTap: () => _open(context, 'Favoritos', state.favoriteItems),
        ),
        const SectionLabel('Categorias'),
        ...cats.map(
          (c) => CategoryTile(
            title: c.name,
            count: c.count,
            onTap: () =>
                _open(context, c.name, state.inCategory(state.live, c.name)),
          ),
        ),
        if (state.updatedAt != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Lista atualizada em ${_stamp(state.updatedAt!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B6274)),
            ),
          ),
      ],
    );
  }
}

class _MoviesTab extends StatelessWidget {
  const _MoviesTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.movies.isEmpty) {
      return const EmptyState(
        icon: Icons.movie_outlined,
        title: 'Nenhum filme encontrado',
        message:
            'Esta lista não expõe conteúdo sob demanda ou ainda não foi importada.',
      );
    }
    final cats = state.movieCategories;

    return ListView(
      children: [
        CategoryTile(
          title: 'Todos os filmes',
          count: state.movies.length,
          icon: Icons.grid_view_rounded,
          onTap: () =>
              _open(context, 'Todos os filmes', state.movies, grid: true),
        ),
        const SectionLabel('Categorias'),
        ...cats.map(
          (c) => CategoryTile(
            title: c.name,
            count: c.count,
            onTap: () => _open(
              context,
              c.name,
              state.inCategory(state.movies, c.name),
              grid: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesTab extends StatelessWidget {
  const _SeriesTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.series.isEmpty) {
      return const EmptyState(
        icon: Icons.live_tv_outlined,
        title: 'Nenhuma série encontrada',
        message:
            'Esta lista não expõe séries. Em listas Xtream Codes as temporadas '
            'e episódios aparecem aqui automaticamente.',
      );
    }
    final cats = state.seriesCategories;

    return ListView(
      children: [
        CategoryTile(
          title: 'Todas as séries',
          count: state.series.length,
          icon: Icons.grid_view_rounded,
          onTap: () =>
              _open(context, 'Todas as séries', state.series, grid: true),
        ),
        const SectionLabel('Categorias'),
        ...cats.map(
          (c) => CategoryTile(
            title: c.name,
            count: c.count,
            onTap: () => _open(
              context,
              c.name,
              state.inCategory(state.series, c.name),
              grid: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = state.favoriteItems;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'Sem favoritos ainda',
        message: 'Toque no coração ao lado de um canal para salvá-lo aqui.',
      );
    }
    return ItemsList(items: items);
  }
}

Widget _emptyOrError(BuildContext context, AppState state, String title) {
  if (state.stage == LoadStage.loading) {
    return const Center(child: CircularProgressIndicator());
  }
  return EmptyState(
    icon: Icons.error_outline,
    title: state.error == null ? title : 'Falha ao carregar',
    message: state.error ?? 'Atualize a lista para importar os canais.',
    action: FilledButton(
      onPressed: () => state.refresh(),
      child: const Text('Tentar novamente'),
    ),
  );
}

void _open(BuildContext context, String title, List<MediaItem> items,
    {bool grid = false}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ItemsScreen(title: title, items: items, grid: grid),
    ),
  );
}

String _stamp(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} às ${two(d.hour)}:${two(d.minute)}';
}
