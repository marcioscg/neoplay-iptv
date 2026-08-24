import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'player_screen.dart';
import 'series_screen.dart';

/// Telas 06 e 09 — lista de canais / grid de filmes de uma categoria.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({
    super.key,
    required this.title,
    required this.items,
    this.grid = false,
  });

  final String title;
  final List<MediaItem> items;
  final bool grid;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.items
        : widget.items.where((e) => e.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Filtrar nesta categoria',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.search_off, title: 'Nada encontrado aqui')
          : widget.grid
              ? _MediaGrid(items: items)
              : ItemsList(items: items),
    );
  }
}

/// Lista vertical de canais.
class ItemsList extends StatelessWidget {
  const ItemsList({super.key, required this.items});
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView.builder(
      itemCount: items.length,
      itemExtent: 65,
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaTile(
          item: item,
          index: i + 1,
          isFavorite: state.isFavorite(item),
          onFavorite: () => state.toggleFavorite(item),
          onTap: () => openPlayer(context, item, playlist: items),
        );
      },
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return InkWell(
          onTap: () => openPlayer(context, item, playlist: items),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ArtThumb(
                  name: item.name,
                  logo: item.logo,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 10,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, height: 1.25),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Abre o player mantendo a lista para permitir zapear.
///
/// Séries do Xtream não têm URL própria: nesse caso abrimos a tela de
/// temporadas em vez do player.
void openPlayer(BuildContext context, MediaItem item,
    {List<MediaItem> playlist = const []}) {
  if (item.isSeriesContainer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SeriesDetailScreen(series: item)),
    );
    return;
  }
  context.read<AppState>().markWatched(item);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(item: item, siblings: playlist),
    ),
  );
}
