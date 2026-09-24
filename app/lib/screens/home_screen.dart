import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pin_dialog.dart';
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
              Tab(text: 'TV'),
              Tab(text: 'Filmes'),
              Tab(text: 'Séries'),
              Tab(text: 'Favoritos'),
            ],
          ),
        ),
        body: Column(
          children: [
            const _PlanExpiryBanner(),
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
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
}

/// Faixa de aviso quando o plano da conta comum está perto de vencer ou venceu.
class _PlanExpiryBanner extends StatelessWidget {
  const _PlanExpiryBanner();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final account = state.session?.account;
    if (state.isMaster || account == null) return const SizedBox.shrink();
    if (!account.isExpired && !account.isExpiringSoon) {
      return const SizedBox.shrink();
    }

    final expired = account.isExpired;
    final days = account.daysLeft ?? 0;
    final msg = expired
        ? 'Seu plano venceu. Renove para voltar a assistir.'
        : days <= 0
            ? 'Seu plano vence hoje.'
            : 'Seu plano vence em $days ${days == 1 ? 'dia' : 'dias'}.';

    return Material(
      color: expired
          ? AppColors.bad.withValues(alpha: 0.16)
          : AppColors.accent.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(expired ? Icons.lock_clock : Icons.schedule,
                size: 18, color: expired ? AppColors.bad : AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: TextStyle(fontSize: 12.5, color: AppColors.text)),
            ),
            TextButton(
              onPressed: () => Launcher.whatsapp(
                  'Meu plano está vencendo, preciso renovar.'),
              child: const Text('Renovar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de chips de gênero. Ao tocar, abre a lista daquele gênero cruzando
/// todas as pastas.
class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.source, required this.grid});

  final List<MediaItem> source;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final genres = state.genresFor(source);
    if (genres.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Gêneros'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final g in genres)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(g),
                    onPressed: () => _open(
                      context,
                      g,
                      state.inGenre(source, g),
                      grid: grid,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Estrutura comum das abas de conteúdo: busca, atalhos (favoritos, recentes,
/// continuar), gêneros, "todos" e categorias — nessa ordem de prioridade.
class _ContentHub extends StatelessWidget {
  const _ContentHub({
    required this.state,
    required this.source,
    required this.categories,
    required this.allTitle,
    required this.rails,
    required this.grid,
  });

  final AppState state;
  final List<MediaItem> source;
  final List<MediaCategory> categories;
  final String allTitle;
  final List<Widget> rails;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _SearchPill(),
        ...rails,
        _GenreChips(source: source, grid: grid),
        const SectionLabel('Navegar'),
        CategoryTile(
          title: allTitle,
          count: source.length,
          icon: Icons.grid_view_rounded,
          highlight: true,
          onTap: () => _open(context, allTitle, source, grid: grid),
        ),
        if (categories.isNotEmpty) const SectionLabel('Categorias'),
        ...categories.map(
          (c) => CategoryTile(
            title: c.name,
            count: c.count,
            locked: state.isGroupLocked(c.name),
            onTap: () => _openCategory(
              context,
              state,
              c.name,
              state.inCategory(source, c.name),
              grid: grid,
            ),
          ),
        ),
        if (state.updatedAt != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Lista atualizada em ${_stamp(state.updatedAt!)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

/// Atalho de busca no topo de cada aba.
class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: AppColors.muted),
                const SizedBox(width: 10),
                Text(
                  'Buscar canais, filmes e séries',
                  style: TextStyle(fontSize: 13.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fileira horizontal de atalhos (favoritos, recentes, continuar assistindo).
/// Some quando não há itens.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.title,
    required this.icon,
    required this.items,
    this.poster = true,
    this.showProgress = false,
  });

  final String title;
  final IconData icon;
  final List<MediaItem> items;
  final bool poster;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final state = context.watch<AppState>();
    final w = poster ? 104.0 : 92.0;
    final h = poster ? 150.0 : 92.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _open(context, title, items, grid: poster),
                child: Text('Ver tudo (${items.length})'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: h + 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length > 20 ? 20 : items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              final pct =
                  showProgress ? state.getProgress(item.id)?.percent : null;
              return SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => openPlayer(context, item, playlist: items),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ArtThumb(
                            name: item.name,
                            logo: item.logo,
                            width: w,
                            height: h,
                            radius: 10,
                          ),
                          if (pct != null)
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 3,
                                  backgroundColor: Colors.black45,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, height: 1.2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.live.isEmpty) {
      return _emptyOrError(context, state, 'Nenhum canal na lista ativa');
    }
    return _ContentHub(
      state: state,
      source: state.live,
      categories: state.liveCategories,
      allTitle: 'Todos os canais',
      grid: false,
      rails: [
        _Rail(
          title: 'Favoritos',
          icon: Icons.favorite,
          items: state.favoritesOf(MediaKind.live),
          poster: false,
        ),
        _Rail(
          title: 'Assistidos recentemente',
          icon: Icons.history,
          items: state.recentOf(MediaKind.live),
          poster: false,
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
    return _ContentHub(
      state: state,
      source: state.movies,
      categories: state.movieCategories,
      allTitle: 'Todos os filmes',
      grid: true,
      rails: [
        _Rail(
          title: 'Favoritos',
          icon: Icons.favorite,
          items: state.favoritesOf(MediaKind.movie),
        ),
        _Rail(
          title: 'Assistidos recentemente',
          icon: Icons.history,
          items: state.recentOf(MediaKind.movie),
          showProgress: true,
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
    // Temporadas e episódios abrem ao tocar numa série (SeriesDetailScreen).
    return _ContentHub(
      state: state,
      source: state.series,
      categories: state.seriesCategories,
      allTitle: 'Todas as séries',
      grid: true,
      rails: [
        _Rail(
          title: 'Continuar assistindo',
          icon: Icons.play_circle_outline,
          items: state.continueSeries,
          showProgress: true,
        ),
        _Rail(
          title: 'Favoritos',
          icon: Icons.favorite,
          items: state.favoritesOf(MediaKind.series),
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

/// Abre uma categoria; se estiver marcada como adulta e o controle parental
/// ativo, pede o PIN antes.
Future<void> _openCategory(
  BuildContext context,
  AppState state,
  String title,
  List<MediaItem> items, {
  bool grid = false,
}) async {
  if (state.isGroupLocked(title)) {
    final ok =
        await promptParentalPin(context, state, title: 'Categoria adulta');
    if (!ok || !context.mounted) return;
  }
  if (!context.mounted) return;
  _open(context, title, items, grid: grid);
}

String _stamp(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} às ${two(d.hour)}:${two(d.minute)}';
}
