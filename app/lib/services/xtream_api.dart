import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Cliente da API Xtream Codes (player_api.php), padrão de fato do mercado.
class XtreamApi {
  final Playlist playlist;
  XtreamApi(this.playlist);

  static const _timeout = Duration(seconds: 25);
  static const _bigTimeout = Duration(seconds: 90);

  Uri _api(String action, [Map<String, String> extra = const {}]) {
    return Uri.parse('${playlist.normalizedHost}/player_api.php').replace(
      queryParameters: {
        'username': playlist.username,
        'password': playlist.password,
        'action': action,
        ...extra,
      },
    );
  }

  Future<dynamic> _get(Uri uri) async {
    final res = await http.get(uri, headers: const {
      'User-Agent': 'NEOPLAY/1.0 (Android)',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw XtreamException('Servidor respondeu ${res.statusCode}');
    }
    if (res.body.trim().isEmpty) return const <dynamic>[];
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw const XtreamException('Resposta inválida do servidor');
    }
  }

  /// Valida as credenciais e devolve informações da conta.
  Future<XtreamAccount> authenticate() async {
    final uri = Uri.parse('${playlist.normalizedHost}/player_api.php').replace(
      queryParameters: {
        'username': playlist.username,
        'password': playlist.password,
      },
    );
    final data = await _get(uri);
    if (data is! Map || data['user_info'] == null) {
      throw const XtreamException('Não foi possível autenticar na lista');
    }
    final info = Map<String, dynamic>.from(data['user_info'] as Map);
    if ('${info['auth']}' == '0') {
      throw const XtreamException('Usuário ou senha inválidos');
    }
    if ('${info['status']}'.toLowerCase() != 'active') {
      throw XtreamException('Conta ${info['status']} no servidor');
    }
    return XtreamAccount(
      status: '${info['status']}',
      expiresAt: _parseUnix(info['exp_date']),
      maxConnections: int.tryParse('${info['max_connections']}') ?? 1,
      activeConnections: int.tryParse('${info['active_cons']}') ?? 0,
    );
  }

  /// Baixa o corpo bruto de uma ação (JSON não decodificado).
  ///
  /// O decode e o mapeamento acontecem em outro isolate (ver importer.dart),
  /// por isso aqui devolvemos apenas texto.
  Future<String> rawBody(String action, {bool optional = false}) async {
    try {
      final res = await http.get(_api(action), headers: const {
        'User-Agent': 'NEOPLAY/1.0 (Android)',
        'Accept-Encoding': 'gzip',
      }).timeout(_bigTimeout);
      if (res.statusCode != 200) {
        if (optional) return '';
        throw XtreamException('Servidor respondeu ${res.statusCode}');
      }
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } on XtreamException {
      if (optional) return '';
      rethrow;
    } on Exception {
      if (optional) return '';
      rethrow;
    }
  }

  /// Mapa categoria_id -> nome da categoria.
  Future<Map<String, String>> categories(String action) async {
    try {
      final data = await _get(_api(action));
      final map = <String, String>{};
      if (data is List) {
        for (final c in data) {
          if (c is Map) {
            map['${c['category_id']}'] = '${c['category_name']}'.trim();
          }
        }
      }
      return map;
    } on Exception {
      return <String, String>{};
    }
  }

  /// Temporadas e episódios de uma série (get_series_info).
  Future<SeriesDetail> seriesInfo(String seriesId) async {
    final data = await _get(_api('get_series_info', {'series_id': seriesId}));
    if (data is! Map) {
      throw const XtreamException('A série não retornou episódios');
    }

    final info = data['info'] is Map
        ? Map<String, dynamic>.from(data['info'] as Map)
        : <String, dynamic>{};

    final seasons = <int, List<SeriesEpisode>>{};
    final raw = data['episodes'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final seasonNumber = int.tryParse('${entry.key}') ?? 1;
        final list = entry.value;
        if (list is! List) continue;
        for (final e in list) {
          if (e is! Map) continue;
          final id = '${e['id'] ?? ''}';
          if (id.isEmpty || id == 'null') continue;
          final extra = e['info'] is Map
              ? Map<String, dynamic>.from(e['info'] as Map)
              : <String, dynamic>{};
          (seasons[seasonNumber] ??= <SeriesEpisode>[]).add(
            SeriesEpisode(
              id: id,
              title: '${e['title'] ?? 'Episódio'}'.trim(),
              url: episodeUrl(id, '${e['container_extension'] ?? 'mp4'}'),
              image: '${extra['movie_image'] ?? ''}',
              plot: '${extra['plot'] ?? ''}',
              season: seasonNumber,
              number: int.tryParse('${e['episode_num']}') ?? 0,
              duration: _parseDuration('${extra['duration'] ?? ''}'),
            ),
          );
        }
      }
    }

    final ordered = seasons.keys.toList()..sort();
    return SeriesDetail(
      plot: '${info['plot'] ?? ''}'.trim(),
      cover: '${info['cover'] ?? ''}',
      genre: '${info['genre'] ?? ''}'.trim(),
      rating: '${info['rating'] ?? ''}'.trim(),
      releaseDate:
          '${info['releaseDate'] ?? info['release_date'] ?? ''}'.trim(),
      seasons: [
        for (final n in ordered)
          SeriesSeason(
            n,
            seasons[n]!..sort((a, b) => a.number.compareTo(b.number)),
          ),
      ],
    );
  }

  /// URL de episódio de série.
  String episodeUrl(String episodeId, String ext) =>
      '${playlist.normalizedHost}/series/${playlist.username}/${playlist.password}/$episodeId.${ext.isEmpty ? 'mp4' : ext}';

  static Duration? _parseDuration(String value) {
    final parts = value.split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final sec = double.tryParse(parts[2]);
    if (h == null || m == null || sec == null) return null;
    return Duration(hours: h, minutes: m, seconds: sec.round());
  }

  /// URL de stream ao vivo. `.m3u8` é o formato mais compatível com ExoPlayer.
  String liveUrl(String streamId) =>
      '${playlist.normalizedHost}/live/${playlist.username}/${playlist.password}/$streamId.m3u8';

  String movieUrl(String streamId, String ext) =>
      '${playlist.normalizedHost}/movie/${playlist.username}/${playlist.password}/$streamId.$ext';

  /// EPG curto do canal (usado na tela do player).
  Future<List<XtreamProgram>> shortEpg(String streamId, {int limit = 6}) async {
    try {
      final data = await _get(_api('get_short_epg', {
        'stream_id': streamId,
        'limit': '$limit',
      }));
      final list = (data is Map ? data['epg_listings'] : null);
      if (list is! List) return const [];
      return list.whereType<Map>().map((e) {
        return XtreamProgram(
          title: _b64('${e['title'] ?? ''}'),
          description: _b64('${e['description'] ?? ''}'),
          start: DateTime.tryParse('${e['start']}')?.toLocal(),
          end: DateTime.tryParse('${e['end']}')?.toLocal(),
        );
      }).toList();
    } on Exception {
      return const [];
    }
  }

  static String _b64(String value) {
    if (value.isEmpty) return value;
    try {
      return utf8.decode(base64.decode(value));
    } on Exception {
      return value;
    }
  }

  static DateTime? _parseUnix(dynamic v) {
    final secs = int.tryParse('$v');
    if (secs == null || secs == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }
}

class XtreamAccount {
  final String status;
  final DateTime? expiresAt;
  final int maxConnections;
  final int activeConnections;
  const XtreamAccount({
    required this.status,
    this.expiresAt,
    this.maxConnections = 1,
    this.activeConnections = 0,
  });
}

class XtreamProgram {
  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;
  const XtreamProgram({
    required this.title,
    this.description = '',
    this.start,
    this.end,
  });

  /// Progresso de 0 a 1 do programa em relação ao horário atual.
  double get progress {
    if (start == null || end == null) return 0;
    final total = end!.difference(start!).inSeconds;
    if (total <= 0) return 0;
    final done = DateTime.now().difference(start!).inSeconds;
    return (done / total).clamp(0, 1).toDouble();
  }
}

class XtreamException implements Exception {
  final String message;
  const XtreamException(this.message);
  @override
  String toString() => message;
}
