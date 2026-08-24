import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'm3u_parser.dart';

/// Importação de listas em *isolate* separado.
///
/// Listas de IPTV têm de 5 mil a 60 mil itens. Fazer o parse, o mapeamento e a
/// serialização na thread da interface congela o app (era o bug de travamento
/// ao adicionar a lista). Tudo aqui roda via [compute], fora da UI, e devolve
/// de uma vez o conteúdo pronto e o JSON já serializado para o cache — assim o
/// trabalho pesado acontece uma única vez, em segundo plano.

/// Conteúdo importado + JSON pronto para gravar em disco.
class ImportResult {
  final PlaylistContent content;
  final String cacheJson;
  const ImportResult(this.content, this.cacheJson);
}

/// Dados brutos de uma importação Xtream Codes.
class XtreamJob {
  final String liveBody;
  final String vodBody;
  final Map<String, String> liveCategories;
  final Map<String, String> vodCategories;
  final String host;
  final String username;
  final String password;

  const XtreamJob({
    required this.liveBody,
    required this.vodBody,
    required this.liveCategories,
    required this.vodCategories,
    required this.host,
    required this.username,
    required this.password,
  });
}

/// Processa uma lista M3U/M3U8 fora da thread da interface.
Future<ImportResult> importM3u(String body) => compute(_m3uWorker, body);

/// Processa as respostas do player_api.php fora da thread da interface.
Future<ImportResult> importXtream(XtreamJob job) => compute(_xtreamWorker, job);

/// Lê o cache do disco fora da thread da interface.
Future<PlaylistContent> decodeCache(String raw) => compute(_cacheWorker, raw);

/// Monta a URL de canal ao vivo (usada também dentro do isolate).
String liveStreamUrl(String host, String user, String pass, String id) =>
    '$host/live/$user/$pass/$id.m3u8';

/// Monta a URL de filme (usada também dentro do isolate).
String movieStreamUrl(
  String host,
  String user,
  String pass,
  String id,
  String ext,
) =>
    '$host/movie/$user/$pass/$id.$ext';

// ---------------------------------------------------------------------------
// Funções executadas no isolate (precisam ser de nível superior).
// ---------------------------------------------------------------------------

ImportResult _m3uWorker(String body) {
  final items = M3uParser.parse(body);
  final live = <MediaItem>[];
  final movies = <MediaItem>[];
  for (final item in items) {
    if (item.kind == MediaKind.live) {
      live.add(item);
    } else {
      movies.add(item);
    }
  }
  return _pack(live, movies);
}

ImportResult _xtreamWorker(XtreamJob job) {
  final live = _mapStreams(
    body: job.liveBody,
    categories: job.liveCategories,
    kind: MediaKind.live,
    job: job,
  );
  final movies = _mapStreams(
    body: job.vodBody,
    categories: job.vodCategories,
    kind: MediaKind.movie,
    job: job,
  );
  return _pack(live, movies);
}

List<MediaItem> _mapStreams({
  required String body,
  required Map<String, String> categories,
  required MediaKind kind,
  required XtreamJob job,
}) {
  if (body.trim().isEmpty) return const [];

  dynamic data;
  try {
    data = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (data is! List) return const [];

  final out = <MediaItem>[];
  final seen = <String>{};
  for (final entry in data) {
    if (entry is! Map) continue;
    final id = '${entry['stream_id']}';
    if (id.isEmpty || id == 'null' || !seen.add(id)) continue;

    final ext = '${entry['container_extension'] ?? 'mp4'}';
    final group = categories['${entry['category_id']}'] ?? 'Sem categoria';
    out.add(
      MediaItem(
        id: kind == MediaKind.live ? id : 'vod_$id',
        name: '${entry['name'] ?? 'Sem nome'}'.trim(),
        url: kind == MediaKind.live
            ? liveStreamUrl(job.host, job.username, job.password, id)
            : movieStreamUrl(job.host, job.username, job.password, id, ext),
        logo: '${entry['stream_icon'] ?? entry['cover'] ?? ''}',
        group: group,
        tvgId: '${entry['epg_channel_id'] ?? ''}',
        kind: kind,
      ),
    );
  }
  return out;
}

ImportResult _pack(List<MediaItem> live, List<MediaItem> movies) {
  final json = jsonEncode({
    'v': 1,
    'live': [for (final e in live) e.toJson()],
    'movies': [for (final e in movies) e.toJson()],
  });
  return ImportResult(PlaylistContent(live: live, movies: movies), json);
}

PlaylistContent _cacheWorker(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return const PlaylistContent();
    return PlaylistContent(
      live: _decodeItems(data['live']),
      movies: _decodeItems(data['movies']),
    );
  } on FormatException {
    return const PlaylistContent();
  }
}

List<MediaItem> _decodeItems(dynamic list) {
  if (list is! List) return const [];
  final out = <MediaItem>[];
  for (final e in list) {
    if (e is Map) {
      out.add(MediaItem.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}
