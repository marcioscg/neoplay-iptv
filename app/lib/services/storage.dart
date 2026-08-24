import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persistência local simples (SharedPreferences).
///
/// Para produção com listas grandes, trocar o cache de itens por um banco
/// local (Isar/Drift) conforme a especificação em docs/.
class Storage {
  static const _kPlaylist = 'playlist';
  static const _kFavorites = 'favorites';
  static const _kRecent = 'recent';
  static const _kCacheLive = 'cache_live';
  static const _kCacheMovies = 'cache_movies';
  static const _kCacheAt = 'cache_at';

  final SharedPreferences _p;
  Storage(this._p);

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  // ---------- lista de reprodução ----------
  Playlist? get playlist {
    final raw = _p.getString(_kPlaylist);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Playlist.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Exception {
      return null;
    }
  }

  Future<void> savePlaylist(Playlist playlist) =>
      _p.setString(_kPlaylist, jsonEncode(playlist.toJson()));

  // ---------- cache de conteúdo ----------
  Future<void> saveContent(PlaylistContent content) async {
    await _p.setString(
        _kCacheLive, jsonEncode(content.live.map((e) => e.toJson()).toList()));
    await _p.setString(_kCacheMovies,
        jsonEncode(content.movies.map((e) => e.toJson()).toList()));
    await _p.setInt(_kCacheAt, DateTime.now().millisecondsSinceEpoch);
  }

  PlaylistContent? get cachedContent {
    final live = _decodeItems(_p.getString(_kCacheLive));
    final movies = _decodeItems(_p.getString(_kCacheMovies));
    if (live.isEmpty && movies.isEmpty) return null;
    return PlaylistContent(live: live, movies: movies);
  }

  DateTime? get cachedAt {
    final ms = _p.getInt(_kCacheAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  List<MediaItem> _decodeItems(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on Exception {
      return const [];
    }
  }

  // ---------- favoritos e histórico ----------
  Set<String> get favorites =>
      (_p.getStringList(_kFavorites) ?? const []).toSet();

  Future<void> saveFavorites(Set<String> ids) =>
      _p.setStringList(_kFavorites, ids.toList());

  List<String> get recent => _p.getStringList(_kRecent) ?? const [];

  Future<void> pushRecent(String id) async {
    final list = recent.toList()..remove(id);
    list.insert(0, id);
    if (list.length > 30) list.removeRange(30, list.length);
    await _p.setStringList(_kRecent, list);
  }

  Future<void> clearAll() => _p.clear();
}
