import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'items_screen.dart';

/// Tela de detalhe da série: capa, sinopse, temporadas e episódios.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final MediaItem series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetail? _detail;
  String? _error;
  bool _loading = true;
  int _season = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<AppState>().seriesDetail(widget.series);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _season = 0;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final detail = _detail;
    final fav = state.isFavorite(widget.series);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? AppColors.accent : null,
            ),
            onPressed: () => state.toggleFavorite(widget.series),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Não foi possível abrir a série',
                  message: _error ?? '',
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                )
              : _content(detail!),
    );
  }

  Widget _content(SeriesDetail detail) {
    final season = detail.seasons[_season];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(detail),
        if (detail.seasons.length > 1) _seasonPicker(detail),
        SectionLabel(
          'Temporada ${season.number} · ${season.episodes.length} episódios',
        ),
        ...season.episodes.map((e) => _episodeTile(e, season.episodes)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _header(SeriesDetail detail) {
    final cover = detail.cover.isNotEmpty ? detail.cover : widget.series.logo;
    final chips = <String>[
      if (detail.releaseDate.isNotEmpty) detail.releaseDate,
      if (detail.rating.isNotEmpty) '★ ${detail.rating}',
      if (detail.genre.isNotEmpty) detail.genre,
      '${detail.seasons.length} temporada${detail.seasons.length > 1 ? 's' : ''}',
      '${detail.episodeCount} episódios',
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtThumb(
                name: widget.series.name,
                logo: cover,
                width: 104,
                height: 150,
                radius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.series.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                  fontSize: 10.5, color: AppColors.muted),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.plot.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              detail.plot,
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.muted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seasonPicker(SeriesDetail detail) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            for (var i = 0; i < detail.seasons.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('T${detail.seasons[i].number}'),
                  selected: _season == i,
                  onSelected: (_) => setState(() => _season = i),
                ),
              ),
          ],
        ),
      );

  Widget _episodeTile(SeriesEpisode ep, List<SeriesEpisode> season) {
    final items = [
      for (final e in season) e.toMediaItem(widget.series.name),
    ];
    final item = ep.toMediaItem(widget.series.name);

    return InkWell(
      onTap: () => openPlayer(context, item, playlist: items),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ArtThumb(
              name: ep.title,
              logo: ep.image.isNotEmpty ? ep.image : widget.series.logo,
              width: 72,
              height: 44,
              radius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ep.label} · ${ep.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (ep.duration != null || ep.plot.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ep.duration != null
                          ? '${ep.duration!.inMinutes} min'
                          : ep.plot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.play_circle_outline,
                size: 22, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
