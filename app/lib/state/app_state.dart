import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/importer.dart';
import '../services/storage.dart';
import '../services/xtream_api.dart';

enum LoadStage { idle, loading, ready, error }

/// Estado global do app: lista ativa, conteúdo importado, favoritos e busca.
///
/// Todo o trabalho pesado (parse, serialização, leitura de cache) é delegado
/// ao importer, que roda em isolate. Aqui só ficam dados já prontos e índices
/// pré-calculados, para que nenhuma tela precise varrer milhares de itens a
/// cada frame.
class AppState extends ChangeNotifier {
  AppState(this._storage);

  final Storage _storage;

  Playlist? playlist;
  LoadStage stage = LoadStage.idle;
  String? error;
  String progressLabel = '';

  List<MediaItem> live = const [];
  List<MediaItem> movies = const [];
  List<MediaItem> series = const [];
  Set<String> favorites = <String>{};
  XtreamAccount? account;
  DateTime? updatedAt;

  // Índices derivados, recalculados uma única vez por importação.
  List<MediaItem> _all = const [];
  List<MediaCategory> _liveCategories = const [];
  List<MediaCategory> _movieCategories = const [];
  List<MediaCategory> _seriesCategories = const [];
  Map<String, MediaItem> _byId = const {};
  Map<String, List<MediaItem>> _liveByGroup = const {};
  Map<String, List<MediaItem>> _movieByGroup = const {};
  Map<String, List<MediaItem>> _seriesByGroup = const {};
  List<String> _recentIds = const [];

  bool _busy = false;
  bool _booted = false;

  bool get hasPlaylist => playlist != null;
  bool get isBusy => _busy;

  /// Carrega a lista salva e o cache local, sem rede. Só roda uma vez.
  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;

    playlist = _storage.playlist;
    favorites = _storage.favorites;
    _recentIds = _storage.recent.toList();
    updatedAt = _storage.cachedAt;
    notifyListeners();

    final cached = await _storage.loadCachedContent();
    if (cached != null) {
      _apply(cached);
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
    if (p == null || _busy) return false;

    _busy = true;
    stage = LoadStage.loading;
    error = null;
    _progress('Conectando ao servidor…');

    try {
      final result = p.kind == PlaylistKind.xtream
          ? await _importXtream(p)
          : await _importM3u(p);

      if (result.content.isEmpty) {
        throw const XtreamException(
          'A lista respondeu, mas não veio nenhum canal ou filme',
        );
      }

      _progress('Organizando o conteúdo…');
      _apply(result.content);
      updatedAt = DateTime.now();
      stage = LoadStage.ready;
      progressLabel = '';
      _busy = false;
      notifyListeners();

      // Grava o cache depois de liberar a tela: o usuário já pode navegar.
      await _storage.writeCache(result.cacheJson);
      return true;
    } on TimeoutException {
      return _fail('O servidor não respondeu em tempo. Tente novamente.');
    } on XtreamException catch (e) {
      return _fail(e.message);
    } on Exception catch (e) {
      return _fail('Falha ao carregar a lista: ${_short(e)}');
    }
  }

  Future<ImportResult> _importXtream(Playlist p) async {
    final api = XtreamApi(p);
    account = await api.authenticate();

    _progress('Lendo as categorias…');
    final liveCats = await api.categories('get_live_categories');
    final vodCats = await api.categories('get_vod_categories');

    _progress('Baixando os canais ao vivo…');
    final liveBody = await api.rawBody('get_live_streams');

    _progress('Baixando os filmes…');
    final vodBody = await api.rawBody('get_vod_streams', optional: true);

    _progress('Baixando as séries…');
    final seriesCats = await api.categories('get_series_categories');
    final seriesBody = await api.rawBody('get_series', optional: true);

    _progress('Processando a lista…');
    return importXtream(
      XtreamJob(
        liveBody: liveBody,
        vodBody: vodBody,
        seriesBody: seriesBody,
        liveCategories: liveCats,
        vodCategories: vodCats,
        seriesCategories: seriesCats,
        host: p.normalizedHost,
        username: p.username,
        password: p.password,
      ),
    );
  }

  Future<ImportResult> _importM3u(Playlist p) async {
    _progress('Baixando a lista M3U…');
    final res = await http.get(Uri.parse(p.url), headers: const {
      'User-Agent': 'NEOPLAY/1.0 (Android)',
      'Accept-Encoding': 'gzip',
    }).timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw XtreamException('A URL respondeu ${res.statusCode}');
    }
    _progress('Processando a lista…');
    return importM3u(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  void _progress(String label) {
    progressLabel = label;
    notifyListeners();
  }

  bool _fail(String message) {
    error = message;
    stage = _all.isEmpty ? LoadStage.error : LoadStage.ready;
    progressLabel = '';
    _busy = false;
    notifyListeners();
    return false;
  }

  static String _short(Object e) {
    final text = '$e'.replaceAll('Exception:', '').trim();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  /// Recalcula todos os índices a partir do conteúdo importado.
  void _apply(PlaylistContent content) {
    live = content.live;
    movies = content.movies;
    series = content.series;
    _all = [...live, ...movies, ...series];

    _byId = {for (final e in _all) e.id: e};
    _liveByGroup = _group(live);
    _movieByGroup = _group(movies);
    _seriesByGroup = _group(series);
    _liveCategories = _categories(_liveByGroup);
    _movieCategories = _categories(_movieByGroup);
    _seriesCategories = _categories(_seriesByGroup);
    _recentIds = _recentIds.where(_byId.containsKey).toList();
  }

  Map<String, List<MediaItem>> _group(List<MediaItem> items) {
    final map = <String, List<MediaItem>>{};
    for (final item in items) {
      (map[item.group] ??= <MediaItem>[]).add(item);
    }
    return map;
  }

  List<MediaCategory> _categories(Map<String, List<MediaItem>> groups) {
    final list = groups.entries
        .map((e) => MediaCategory(e.key, e.value.length))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ---------- consultas (todas O(1) ou sobre listas já prontas) ----------
  List<MediaCategory> get liveCategories => _liveCategories;
  List<MediaCategory> get movieCategories => _movieCategories;
  List<MediaCategory> get seriesCategories => _seriesCategories;
  List<MediaItem> get allItems => _all;

  List<MediaItem> inCategory(List<MediaItem> items, String category) {
    final source = items == live
        ? _liveByGroup
        : items == series
            ? _seriesByGroup
            : _movieByGroup;
    final hit = source[category];
    if (hit != null) return hit;
    return items.where((e) => e.group == category).toList();
  }

  List<MediaItem> get favoriteItems {
    if (favorites.isEmpty) return const [];
    return [
      for (final id in favorites)
        if (_byId[id] != null) _byId[id]!,
    ];
  }

  List<MediaItem> get recentItems => [
        for (final id in _recentIds)
          if (_byId[id] != null) _byId[id]!,
      ];

  List<MediaItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final out = <MediaItem>[];
    for (final item in _all) {
      if (item.name.toLowerCase().contains(q)) {
        out.add(item);
        if (out.length >= 300) break;
      }
    }
    return out;
  }

  final Map<String, SeriesDetail> _seriesCache = {};

  /// Carrega temporadas e episódios sob demanda, guardando em memória.
  Future<SeriesDetail> seriesDetail(MediaItem item) async {
    final cached = _seriesCache[item.id];
    if (cached != null) return cached;

    final p = playlist;
    if (p == null || p.kind != PlaylistKind.xtream) {
      throw const XtreamException(
        'Temporadas só estão disponíveis em listas Xtream Codes',
      );
    }
    final detail = await XtreamApi(p).seriesInfo(item.remoteId);
    if (detail.seasons.isEmpty) {
      throw const XtreamException('Esta série não retornou episódios');
    }
    _seriesCache[item.id] = detail;
    return detail;
  }

  bool isFavorite(MediaItem item) => favorites.contains(item.id);

  Future<void> toggleFavorite(MediaItem item) async {
    final next = favorites.toSet();
    if (!next.remove(item.id)) next.add(item.id);
    favorites = next;
    notifyListeners();
    await _storage.saveFavorites(next);
  }

  Future<void> markWatched(MediaItem item) async {
    final list = _recentIds.toList()..remove(item.id);
    list.insert(0, item.id);
    if (list.length > 30) list.removeRange(30, list.length);
    _recentIds = list;
    notifyListeners();
    await _storage.saveRecent(list);
  }

  Future<void> clearFavoritesAndHistory() async {
    favorites = <String>{};
    _recentIds = const [];
    notifyListeners();
    await _storage.saveFavorites(const <String>{});
    await _storage.saveRecent(const []);
  }

  Future<void> resetEverything() async {
    await _storage.clearAll();
    playlist = null;
    account = null;
    updatedAt = null;
    error = null;
    favorites = <String>{};
    _recentIds = const [];
    _seriesCache.clear();
    _apply(const PlaylistContent());
    stage = LoadStage.idle;
    notifyListeners();
  }


  // ---------- controle parental ----------
  final Set<String> _unlockedCategories = <String>{};

  String? get parentalPin => _storage.parentalPin;
  bool get isParentalEnabled => parentalPin != null && parentalPin!.isNotEmpty;

  bool isCategoryUnlocked(String name) => _unlockedCategories.contains(name);

  void unlockCategory(String name) {
    _unlockedCategories.add(name);
    notifyListeners();
  }

  Future<void> setParentalPin(String? pin) async {
    await _storage.saveParentalPin(pin);
    notifyListeners();
  }

  // ---------- continuar assistindo ----------
  Map<String, PlaybackProgress> get playbackProgress => _storage.playbackProgress;

  PlaybackProgress? getProgress(String itemId) => _storage.playbackProgress[itemId];

  Future<void> saveProgress(MediaItem item, int posSec, int durSec) async {
    if (durSec <= 0) return;
    final progress = PlaybackProgress(
      itemId: item.id,
      positionSeconds: posSec,
      durationSeconds: durSec,
      updatedAt: DateTime.now(),
    );
    await _storage.savePlaybackProgress(progress);
    notifyListeners();
  }

  Future<void> clearProgress(String itemId) async {
    await _storage.clearPlaybackProgress(itemId);
    notifyListeners();
  }

  List<MediaItem> get continueWatchingItems {
    final map = _storage.playbackProgress;
    if (map.isEmpty) return const [];
    final list = map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final out = <MediaItem>[];
    for (final p in list) {
      final item = _byId[p.itemId];
      if (item != null) out.add(item);
    }
    return out;
  }

  // ---------- autenticação e usuários admin ----------
  AdminUser? get loggedUser => _storage.loggedUser;

  bool get isAdminLogged => loggedUser?.email == 'marcioscg@hotmail.com';

  Future<void> setLoggedUser(AdminUser? user) async {
    await _storage.saveLoggedUser(user);
    notifyListeners();
  }

  Future<void> logoutUser() async {
    await _storage.saveLoggedUser(null);
    notifyListeners();
  }

  List<AdminUser> get adminUsers => _storage.adminUsers;

  Future<void> saveAdminUser(AdminUser user) async {
    final users = _storage.adminUsers.toList();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    await _storage.saveAdminUsers(users);
    notifyListeners();
  }

  Future<void> deleteAdminUser(String userId) async {
    final users = _storage.adminUsers.where((u) => u.id != userId).toList();
    await _storage.saveAdminUsers(users);
    notifyListeners();
  }
}
