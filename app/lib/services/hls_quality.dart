import 'dart:convert';

import 'package:http/http.dart' as http;

/// Uma faixa de qualidade encontrada no manifesto HLS (master playlist).
class HlsVariant {
  final String label;
  final String url;
  final int height;
  final int bandwidth;

  const HlsVariant({
    required this.label,
    required this.url,
    this.height = 0,
    this.bandwidth = 0,
  });
}

/// Lê o master playlist `.m3u8` e devolve as qualidades disponíveis.
///
/// O `video_player` (ExoPlayer) troca de faixa sozinho quando recebe o master,
/// mas não expõe API para o usuário forçar uma resolução. A solução é ler o
/// próprio manifesto, listar as variantes e reabrir o player apontando direto
/// para a sub-playlist escolhida.
class HlsQuality {
  static const _timeout = Duration(seconds: 12);

  static final _streamInf = RegExp(r'#EXT-X-STREAM-INF:(.*)', caseSensitive: false);
  static final _resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false);
  static final _bandwidth = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false);

  /// Devolve as variantes do manifesto. Lista vazia quando não é um master
  /// playlist, quando só há uma faixa ou quando a leitura falha — nesses casos
  /// o player simplesmente não mostra o menu de qualidade.
  static Future<List<HlsVariant>> variants(String url) async {
    final clean = url.split('?').first.toLowerCase();
    if (!clean.endsWith('.m3u8') && !clean.contains('.m3u8')) return const [];

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'MIAUNET/1.0 (Android)'},
      ).timeout(_timeout);
      if (res.statusCode != 200) return const [];

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (!body.contains('#EXT-X-STREAM-INF')) return const [];

      final base = Uri.parse(url);
      final lines = body.split(RegExp(r'\r?\n'));
      final out = <HlsVariant>[];
      final seen = <String>{};

      for (var i = 0; i < lines.length; i++) {
        final m = _streamInf.firstMatch(lines[i].trim());
        if (m == null) continue;

        final attrs = m.group(1) ?? '';
        final res0 = _resolution.firstMatch(attrs);
        final band = int.tryParse(_bandwidth.firstMatch(attrs)?.group(1) ?? '') ?? 0;
        final height = int.tryParse(res0?.group(2) ?? '') ?? 0;

        // A URI da variante é a próxima linha não-comentada.
        String? uri;
        for (var j = i + 1; j < lines.length; j++) {
          final l = lines[j].trim();
          if (l.isEmpty || l.startsWith('#')) continue;
          uri = l;
          break;
        }
        if (uri == null) continue;

        final abs = uri.startsWith('http') ? uri : base.resolve(uri).toString();
        final label = height > 0
            ? '${height}p'
            : band > 0
                ? '${(band / 1000).round()} kbps'
                : 'Faixa ${out.length + 1}';
        if (!seen.add(label)) continue;

        out.add(HlsVariant(
          label: label,
          url: abs,
          height: height,
          bandwidth: band,
        ));
      }

      if (out.length < 2) return const [];
      out.sort((a, b) {
        if (a.height != b.height) return b.height.compareTo(a.height);
        return b.bandwidth.compareTo(a.bandwidth);
      });
      return out;
    } on Exception {
      return const [];
    }
  }
}
