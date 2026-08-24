import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Cliente da API Xtream Codes (player_api.php), padrão de fato do mercado.
class XtreamApi {
  final Playlist playlist;
  XtreamApi(this.playlist);

  static const _timeout = Duration(seconds: 25);

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

  /// Baixa canais ao vivo e filmes com suas categorias.
  Future<PlaylistContent> loadContent() async {
    final liveCats = await _categories('get_live_categories');
    final vodCats = await _categories('get_vod_categories');

    final live = await _streams(
      action: 'get_live_streams',
      categories: liveCats,
      kind: MediaKind.live,
    );
    final movies = await _streams(
      action: 'get_vod_streams',
      categories: vodCats,
      kind: MediaKind.movie,
    );
    return PlaylistContent(live: live, movies: movies);
  }

  Future<Map<String, String>> _categories(String action) async {
    try {
      final data = await _get(_api(action));
      final map = <String, String>{};
      if (data is List) {
        for (final c in data) {
          if (c is Map) {
            map['${c['category_id']}'] = '${c['category_name']}';
          }
        }
      }
      return map;
    } on Exception {
      return <String, String>{};
    }
  }

  Future<List<MediaItem>> _streams({
    required String action,
    required Map<String, String> categories,
    required MediaKind kind,
  }) async {
    late final dynamic data;
    try {
      data = await _get(_api(action));
    } on Exception {
      return const [];
    }
    if (data is! List) return const [];

    final out = <MediaItem>[];
    for (final s in data) {
      if (s is! Map) continue;
      final id = '${s['stream_id']}';
      if (id.isEmpty || id == 'null') continue;
      final ext = '${s['container_extension'] ?? 'mp4'}';
      out.add(MediaItem(
        id: id,
        name: '${s['name'] ?? 'Sem nome'}',
        url: kind == MediaKind.live ? liveUrl(id) : movieUrl(id, ext),
        logo: '${s['stream_icon'] ?? ''}',
        group: categories['${s['category_id']}'] ?? 'Sem categoria',
        tvgId: '${s['epg_channel_id'] ?? ''}',
        kind: kind,
      ));
    }
    return out;
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
