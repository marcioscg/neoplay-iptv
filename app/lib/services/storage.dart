import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'importer.dart';

/// Persistência local.
///
/// Preferências (lista ativa, favoritos, histórico) ficam em SharedPreferences,
/// que é rápido para valores pequenos. O conteúdo da lista — que pode passar de
/// 10 MB — vai para um arquivo JSON no diretório de suporte do app. Gravar isso
/// em SharedPreferences travava a interface por vários segundos.
class Storage {
  static const _kPlaylist = 'playlist';
  static const _kFavorites = 'favorites';
  static const _kRecent = 'recent';
  static const _kCacheAt = 'cache_at';

  // Chaves da versão 1.0.0, removidas na migração.
  static const _kLegacyLive = 'cache_live';
  static const _kLegacyMovies = 'cache_movies';

  final SharedPreferences _p;
  final File _cacheFile;

  Storage(this._p, this._cacheFile);

  static Future<Storage> open() async {
    final prefs = await SharedPreferences.getInstance();

    Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } on Exception {
      dir = Directory.systemTemp;
    }

    // Migração: apaga o cache antigo salvo em SharedPreferences.
    if (prefs.containsKey(_kLegacyLive) || prefs.containsKey(_kLegacyMovies)) {
      await prefs.remove(_kLegacyLive);
      await prefs.remove(_kLegacyMovies);
      await prefs.remove(_kCacheAt);
    }

    return Storage(prefs, File('${dir.path}/neoplay_cache.json'));
  }

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

  /// Grava o JSON já serializado pelo isolate de importação.
  Future<void> writeCache(String json) async {
    try {
      await _cacheFile.writeAsString(json, flush: true);
      await _p.setInt(_kCacheAt, DateTime.now().millisecondsSinceEpoch);
    } on Exception {
      // Sem espaço em disco ou permissão: o app segue funcionando em memória.
    }
  }

  /// Lê e decodifica o cache fora da thread da interface.
  Future<PlaylistContent?> loadCachedContent() async {
    try {
      if (!await _cacheFile.exists()) return null;
      final raw = await _cacheFile.readAsString();
      if (raw.trim().isEmpty) return null;
      final content = await decodeCache(raw);
      return content.isEmpty ? null : content;
    } on Exception {
      return null;
    }
  }

  DateTime? get cachedAt {
    final ms = _p.getInt(_kCacheAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ---------- favoritos e histórico ----------
  Set<String> get favorites =>
      (_p.getStringList(_kFavorites) ?? const []).toSet();

  Future<void> saveFavorites(Set<String> ids) =>
      _p.setStringList(_kFavorites, ids.toList());

  List<String> get recent => _p.getStringList(_kRecent) ?? const [];

  Future<void> saveRecent(List<String> ids) => _p.setStringList(_kRecent, ids);

  Future<void> clearAll() async {
    await _p.clear();
    try {
      if (await _cacheFile.exists()) await _cacheFile.delete();
    } on Exception {
      // Ignora falha ao apagar o arquivo de cache.
    }
  }
}
