import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/m3u_parser.dart';
import '../services/storage.dart';
import '../services/xtream_api.dart';

enum LoadStage { idle, loading, ready, error }

/// Estado global do app: lista ativa, conteúdo importado, favoritos e busca.
///
/// Em um projeto maior, trocar por Riverpod conforme a especificação técnica.
class AppState extends ChangeNotifier {
  AppState(this._storage);

  final Storage _storage;

  Playlist? playlist;
  LoadStage stage = LoadStage.idle;
  String? error;
  String progressLabel = '';

  List<MediaItem> live = const [];
  List<MediaItem> movies = const [];
  Set<String> favorites = <String>{};
  XtreamAccount? account;
  DateTime? updatedAt;

  bool get hasPlaylist => playlist != null;

  /// Carrega a lista salva e o cache local, sem rede.
  Future<void> bootstrap() async {
    playlist = _storage.playlist;
    favorites = _storage.favorites;
    updatedAt = _storage.cachedAt;
    final cached = _storage.cachedContent;
    if (cached != null) {
      live = cached.live;
      movies = cached.movies;
      stage = LoadStage.ready;
    }
    notifyListeners();
  }

  /// Salva uma nova lista e importa o conteúdo.
  Future<bool> connect(Playlist p) async {
    playlist = p;
    await _storage.savePlaylist(p);
    return refresh();
  }

  /// Reimporta o conteúdo da lista ativa.
  Future<bool> refresh() async {
    final p = playlist;
    if (p == null) return false;

    stage = LoadStage.loading;
    error = null;
    progressLabel = 'Conectando ao servidor…';
    notifyListeners();

    try {
      PlaylistContent content;
      if (p.kind == PlaylistKind.xtream) {
        final api = XtreamApi(p);
        account = await api.authenticate();
        progressLabel = 'Baixando canais e filmes…';
        notifyListeners();
        content = await api.loadContent();
      } else {
        progressLabel = 'Baixando a lista M3U…';
        notifyListeners();
        content = await _loadM3u(p.url);
      }

      if (content.isEmpty) {
        throw const XtreamException('A lista foi carregada, mas está vazia');
      }

      live = content.live;
      movies = content.movies;
      await _storage.saveContent(content);
      updatedAt = DateTime.now();
      stage = LoadStage.ready;
      progressLabel = '';
      notifyListeners();
      return true;
    } on TimeoutException {
      return _fail('O servidor não respondeu. Verifique a conexão.');
    } on XtreamException catch (e) {
      return _fail(e.message);
    } on Exception catch (e) {
      return _fail('Falha ao carregar a lista: $e');
    }
  }

  bool _fail(String message) {
    error = message;
    stage = live.isEmpty && movies.isEmpty ? LoadStage.error : LoadStage.ready;
    progressLabel = '';
    notifyListeners();
    return false;
  }

  Future<PlaylistContent> _loadM3u(String url) async {
    final res = await http.get(Uri.parse(url), headers: const {
      'User-Agent': 'NEOPLAY/1.0 (Android)'
    }).timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      throw XtreamException('A URL respondeu ${res.statusCode}');
    }
    final items = M3uParser.parse(res.body);
    return PlaylistContent(
      live: items.where((e) => e.kind == MediaKind.live).toList(),
      movies: items.where((e) => e.kind != MediaKind.live).toList(),
    );
  }

  // ---------- consultas ----------
  List<MediaCategory> get liveCategories => _categoriesOf(live);
  List<MediaCategory> get movieCategories => _categoriesOf(movies);

  List<MediaCategory> _categoriesOf(List<MediaItem> items) {
    final counts = <String, int>{};
    for (final i in items) {
      counts[i.group] = (counts[i.group] ?? 0) + 1;
    }
    final list = counts.entries
        .map((e) => MediaCategory(e.key, e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<MediaItem> inCategory(List<MediaItem> items, String category) =>
      items.where((e) => e.group == category).toList();

  List<MediaItem> get allItems => [...live, ...movies];

  List<MediaItem> get favoriteItems {
    final ids = favorites;
    return allItems.where((e) => ids.contains(e.id)).toList();
  }

  List<MediaItem> get recentItems {
    final byId = {for (final e in allItems) e.id: e};
    return _storage.recent
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList();
  }

  List<MediaItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return allItems
        .where((e) => e.name.toLowerCase().contains(q))
        .take(200)
        .toList();
  }

  bool isFavorite(MediaItem item) => favorites.contains(item.id);

  Future<void> toggleFavorite(MediaItem item) async {
    if (!favorites.remove(item.id)) favorites.add(item.id);
    favorites = {...favorites};
    await _storage.saveFavorites(favorites);
    notifyListeners();
  }

  Future<void> markWatched(MediaItem item) async {
    await _storage.pushRecent(item.id);
    notifyListeners();
  }

  Future<void> resetEverything() async {
    await _storage.clearAll();
    playlist = null;
    live = const [];
    movies = const [];
    favorites = <String>{};
    account = null;
    updatedAt = null;
    stage = LoadStage.idle;
    notifyListeners();
  }
}
