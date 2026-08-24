import '../models/models.dart';

/// Parser de listas M3U/M3U8 (formato #EXTINF com atributos tvg-*).
class M3uParser {
  static final _attr = RegExp(r'([a-zA-Z0-9\-_]+)="([^"]*)"');

  /// Converte o conteúdo bruto de um arquivo .m3u em itens de mídia.
  static List<MediaItem> parse(String content) {
    final items = <MediaItem>[];
    final lines = content.split(RegExp(r'\r?\n'));

    String name = '';
    String logo = '';
    String group = 'Sem categoria';
    String tvgId = '';
    var pending = false;
    var index = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.toUpperCase().startsWith('#EXTINF')) {
        final attrs = <String, String>{};
        for (final m in _attr.allMatches(line)) {
          attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
        }
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : '';
        if (name.isEmpty) name = attrs['tvg-name'] ?? 'Sem nome';
        logo = attrs['tvg-logo'] ?? '';
        group = (attrs['group-title'] ?? '').trim();
        if (group.isEmpty) group = 'Sem categoria';
        tvgId = attrs['tvg-id'] ?? '';
        pending = true;
        continue;
      }

      // Diretivas auxiliares que não representam mídia.
      if (line.startsWith('#')) continue;

      if (pending) {
        items.add(MediaItem(
          id: 'm3u_${index++}',
          name: name,
          url: line,
          logo: logo,
          group: group,
          tvgId: tvgId,
          kind: _guessKind(line, group),
        ));
        pending = false;
      }
    }
    return items;
  }

  /// Heurística simples: arquivos de vídeo viram VOD, o resto é canal ao vivo.
  static MediaKind _guessKind(String url, String group) {
    final u = url.toLowerCase();
    final g = group.toLowerCase();
    final isFile = u.endsWith('.mp4') ||
        u.endsWith('.mkv') ||
        u.endsWith('.avi') ||
        u.contains('/movie/') ||
        u.contains('/series/');
    final looksVod = g.contains('filme') ||
        g.contains('movie') ||
        g.contains('série') ||
        g.contains('serie');
    return (isFile || looksVod) ? MediaKind.movie : MediaKind.live;
  }
}
