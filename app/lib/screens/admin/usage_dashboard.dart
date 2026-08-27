import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Central de uso: quem assiste mais, que tipo de conteúdo e acessos recentes.
class UsageDashboard extends StatelessWidget {
  const UsageDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final events = state.usageEvents;

    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Sem dados de uso ainda',
        message:
            'Assim que as contas começarem a assistir, aqui aparece quem assiste '
            'mais e que tipo de conteúdo cada pessoa acessa.',
      );
    }

    final byViewer = <String, int>{};
    final viewerName = <String, String>{};
    final byKind = <MediaKind, int>{};
    final byGroup = <String, int>{};

    for (final e in events) {
      byViewer[e.userEmail] = (byViewer[e.userEmail] ?? 0) + 1;
      viewerName.putIfAbsent(
          e.userEmail, () => e.userName.isEmpty ? e.userEmail : e.userName);
      byKind[e.kind] = (byKind[e.kind] ?? 0) + 1;
      if (e.group.isNotEmpty) {
        byGroup[e.group] = (byGroup[e.group] ?? 0) + 1;
      }
    }

    final viewers = byViewer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final groups = byGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = events.length;

    return ListView(
      children: [
        const SectionLabel('Quem assiste mais'),
        ...viewers.take(10).map((e) => _BarRow(
              label: viewerName[e.key] ?? e.key,
              sub: e.key,
              value: e.value,
              max: viewers.first.value,
            )),
        const SectionLabel('Tipo de conteúdo'),
        _BarRow(
          label: 'Canais ao vivo',
          value: byKind[MediaKind.live] ?? 0,
          max: total,
        ),
        _BarRow(
          label: 'Filmes',
          value: byKind[MediaKind.movie] ?? 0,
          max: total,
        ),
        _BarRow(
          label: 'Séries / episódios',
          value: byKind[MediaKind.series] ?? 0,
          max: total,
        ),
        if (groups.isNotEmpty) ...[
          const SectionLabel('Categorias mais acessadas'),
          ...groups.take(8).map((e) => _BarRow(
                label: e.key,
                value: e.value,
                max: groups.first.value,
              )),
        ],
        const SectionLabel('Acessos recentes'),
        ...events.take(40).map((e) => ListTile(
              dense: true,
              leading: Icon(_iconFor(e.kind), size: 18, color: AppColors.muted),
              title: Text(e.fullTitle,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${_kindLabel(e.kind)} · ${e.userName.isEmpty ? e.userEmail : e.userName} · ${_stamp(e.watchedAt)}',
                style: const TextStyle(fontSize: 11),
              ),
            )),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => context.read<AppState>().clearUsage(),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Limpar histórico de uso'),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(MediaKind k) => switch (k) {
        MediaKind.live => Icons.live_tv,
        MediaKind.movie => Icons.movie_outlined,
        MediaKind.series => Icons.video_library_outlined,
      };

  static String _kindLabel(MediaKind k) => switch (k) {
        MediaKind.live => 'Canal',
        MediaKind.movie => 'Filme',
        MediaKind.series => 'Série',
      };

  static String _stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    this.sub,
  });

  final String label;
  final String? sub;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text('$value',
                  style: TextStyle(fontSize: 12, color: AppColors.accent)),
            ],
          ),
          if (sub != null)
            Text(sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: ratio, minHeight: 5),
          ),
        ],
      ),
    );
  }
}
