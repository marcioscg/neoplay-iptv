import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/accounts_repository.dart';
import '../services/device_label.dart';
import '../services/genres.dart';
import '../services/importer.dart';
import '../services/parental.dart';
import '../services/storage.dart';
import '../services/xtream_api.dart';
import '../theme.dart';

enum LoadStage { idle, loading, ready, error }

/// Sessão ativa. [isMaster] abre o painel de controle; contas comuns recebem a
/// lista M3U cadastrada pelo master.
class SessionUser {
  final String email;
  final bool isMaster;
  final AdminUser? account;
  const SessionUser({required this.email, this.isMaster = false, this.account});

  String get displayName =>
      account?.name.isNotEmpty == true ? account!.name : (isMaster ? 'Master' : email);
}

/// Estado global do app: lista ativa, conteúdo importado, favoritos e busca.
///
/// Todo o trabalho pesado (parse, serialização, leitura de cache) é delegado
/// ao importer, que roda em isolate. Aqui só ficam dados já prontos e índices
/// pré-calculados, para que nenhuma tela precise varrer milhares de itens a
/// cada frame.
class AppState extends ChangeNotifier {
  AppState(this._storage, this._accounts);

  final Storage _storage;
  final AccountsRepository _accounts;

  AccountsRepository get accounts => _accounts;

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

  // Episódios M3U agrupados por série (id do container -> episódios).
  Map<String, List<MediaItem>> _m3uEpisodes = const {};

  // Índices por gênero (rótulo -> itens), um por aba. Recalculados na importação.
  Map<String, List<MediaItem>> _genreLive = const {};
  Map<String, List<MediaItem>> _genreMovies = const {};
  Map<String, List<MediaItem>> _genreSeries = const {};

  bool _busy = false;
  bool _booted = false;

  // ---------- sessão ----------
  SessionUser? session;
  bool masterAppMode = false;
  AdminUser? _pendingAccount;

  bool get isLogged => session != null;
  bool get isMaster => session?.isMaster ?? false;

  // ---------- controle parental ----------
  bool _adultUnlocked = false;

  // ---------- tema ----------
  AppThemeChoice _themeChoice = AppThemeChoice.system;
  AppThemeChoice get themeChoice => _themeChoice;

  Future<void> setThemeChoice(AppThemeChoice choice) async {
    _themeChoice = choice;
    await _storage.saveThemeChoice(choice.name);
    notifyListeners();
  }

  bool get hasPlaylist => playlist != null;
  bool get isBusy => _busy;

  /// Carrega a lista salva e o cache local, sem rede. Só roda uma vez.
  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;

    _themeChoice = AppThemeChoiceX.fromName(_storage.themeChoice);

    await _accounts.init(onChanged: notifyListeners);
    await _tryAutoLogin();

    playlist = _storage.playlist;
    favorites = _storage.favorites;
    _recentIds = _storage.recent.toList();
    updatedAt = _storage.cachedAt;
    _playbackProgress =
      Map<String, PlaybackProgress>.from(_storage.playbackProgress);
    notifyListeners();

    final cached = await _storage.loadCachedContent();
    if (cached != null) {
      _apply(cached);
      stage = LoadStage.ready;
    }
    notifyListeners();

    // Conta comum lembrada: garante que a lista dela esteja carregada.
    final pending = _pendingAccount;
    _pendingAccount = null;
    if (pending != null) {
      unawaited(_applyAccountPlaylist(pending));
    }
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
      'User-Agent': 'MIAUNET/1.0 (Android)',
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

    // Listas M3U trazem episódios soltos; agrupamos por série para a aba Séries
    // mostrar containers (capa + temporadas), como no Xtream.
    final rawSeries = content.series;
    if (rawSeries.isNotEmpty && rawSeries.any((e) => e.url.isNotEmpty)) {
      final built = _buildM3uSeries(rawSeries);
      series = built.$1;
      _m3uEpisodes = built.$2;
    } else {
      series = rawSeries;
      _m3uEpisodes = const {};
    }

    final episodePool = _m3uEpisodes.values.expand((e) => e).toList();
    _all = [...live, ...movies, ...series, ...episodePool];

    _byId = {for (final e in _all) e.id: e};
    _liveByGroup = _group(live);
    _movieByGroup = _group(movies);
    _seriesByGroup = _group(series);
    _liveCategories = _categories(_liveByGroup);
    _movieCategories = _categories(_movieByGroup);
    _seriesCategories = _categories(_seriesByGroup);
    _genreLive = _byGenre(live);
    _genreMovies = _byGenre(movies);
    _genreSeries = _byGenre(series);
    _recentIds = _recentIds.where(_byId.containsKey).toList();
    _seriesCache.clear();
  }

  /// Distribui os itens nos gêneros que reconhecemos pelo nome da pasta/título.
  Map<String, List<MediaItem>> _byGenre(List<MediaItem> items) {
    final map = <String, List<MediaItem>>{};
    for (final item in items) {
      for (final g in Genres.of(item.group, item.name)) {
        (map[g] ??= <MediaItem>[]).add(item);
      }
    }
    return map;
  }

  // ---------- agrupamento de séries M3U ----------
  static final _epPatterns = <RegExp>[
    RegExp(r'^(.*?)[\s._-]+[sS](\d{1,2})[\s._-]*[eExX](\d{1,3})'),
    RegExp(r'^(.*?)[\s._-]+(\d{1,2})[xX](\d{1,3})\b'),
    RegExp(
        r'^(.*?)[\s._-]+[tT](?:emporada)?[\s._-]*(\d{1,2})[\s._-]+[eE][pP]?(?:is[oó]dio)?[\s._-]*(\d{1,3})'),
  ];
  static final _epOnly =
      RegExp(r'^(.*?)[\s._-]+[eE][pP]?(?:is[oó]dio)?[\s._-]*(\d{1,3})\b');
  static final _noise = RegExp(
    r'\b(1080p|720p|480p|360p|4k|uhd|fhd|hdr|hd|sd|h ?264|h ?265|x264|x265|10bit|dual|dublado|dub|leg|legendado|nacional|web-?dl|web-?rip|bluray|hdtv)\b',
    caseSensitive: false,
  );

  ({String show, int season, int number}) _parseEpisode(String raw) {
    final name = raw.trim();
    for (final p in _epPatterns) {
      final m = p.firstMatch(name);
      if (m != null) {
        return (
          show: _clean(m.group(1)!),
          season: int.tryParse(m.group(2)!) ?? 1,
          number: int.tryParse(m.group(3)!) ?? 0,
        );
      }
    }
    final only = _epOnly.firstMatch(name);
    if (only != null) {
      return (
        show: _clean(only.group(1)!),
        season: 1,
        number: int.tryParse(only.group(2)!) ?? 0,
      );
    }
    return (show: _clean(name), season: 1, number: 0);
  }

  String _clean(String s) => s
      .replaceAll(RegExp(r'[\[(].*?[\])]'), ' ')
      .replaceAll(_noise, ' ')
      .replaceAll(RegExp(r'[\s._-]+$'), '')
      .replaceAll(RegExp(r'^[\s._-]+'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  String _normShow(String s) {
    final n = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return n.isEmpty ? 'serie' : n;
  }

  (List<MediaItem>, Map<String, List<MediaItem>>) _buildM3uSeries(
      List<MediaItem> eps) {
    final groups = <String, List<MediaItem>>{};
    final showName = <String, String>{};
    final showLogo = <String, String>{};
    final showGroup = <String, String>{};

    for (final e in eps) {
      final parsed = _parseEpisode(e.name);
      final display = parsed.show.isEmpty ? e.group : parsed.show;
      final key = _normShow(display);
      (groups[key] ??= <MediaItem>[]).add(e);
      showName.putIfAbsent(key, () => display);
      showGroup.putIfAbsent(key, () => e.group);
      if ((showLogo[key] ?? '').isEmpty && e.logo.isNotEmpty) {
        showLogo[key] = e.logo;
      }
    }

    final keys = groups.keys.toList()
      ..sort((a, b) =>
          showName[a]!.toLowerCase().compareTo(showName[b]!.toLowerCase()));

    final containers = <MediaItem>[];
    final episodesById = <String, List<MediaItem>>{};
    for (final key in keys) {
      final id = 'm3useries_$key';
      containers.add(MediaItem(
        id: id,
        name: showName[key]!,
        url: '',
        logo: showLogo[key] ?? '',
        group: showGroup[key]!,
        kind: MediaKind.series,
      ));
      episodesById[id] = groups[key]!;
    }
    return (containers, episodesById);
  }

  SeriesDetail _seriesFromEpisodes(MediaItem container, List<MediaItem> eps) {
    final bySeason = <int, List<SeriesEpisode>>{};
    for (var i = 0; i < eps.length; i++) {
      final e = eps[i];
      final parsed = _parseEpisode(e.name);
      final number = parsed.number == 0 ? i + 1 : parsed.number;
      (bySeason[parsed.season] ??= <SeriesEpisode>[]).add(SeriesEpisode(
        id: e.id,
        title: _episodeTitle(e.name, container.name),
        url: e.url,
        image: e.logo.isNotEmpty ? e.logo : container.logo,
        season: parsed.season,
        number: number,
      ));
    }
    final keys = bySeason.keys.toList()..sort();
    return SeriesDetail(
      cover: container.logo,
      seasons: [
        for (final n in keys)
          SeriesSeason(
            n,
            bySeason[n]!..sort((a, b) => a.number.compareTo(b.number)),
          ),
      ],
    );
  }

  String _episodeTitle(String raw, String show) {
    var t = raw.trim();
    if (show.isNotEmpty && t.toLowerCase().startsWith(show.toLowerCase())) {
      t = t.substring(show.length);
    }
    t = t.replaceAll(RegExp(r'^[\s._:\-]+'), '').trim();
    return t.isEmpty ? raw.trim() : t;
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
  List<MediaCategory> get liveCategories => _visibleCats(_liveCategories);
  List<MediaCategory> get movieCategories => _visibleCats(_movieCategories);
  List<MediaCategory> get seriesCategories => _visibleCats(_seriesCategories);
  List<MediaItem> get allItems => _all;

  // Controle parental: quando ativo, categorias adultas somem da navegação
  // (se "ocultar" estiver ligado) ou aparecem com cadeado até liberar o PIN.
  bool get parentalActive => _storage.parentalEnabled;
  bool get hideAdult => _storage.hideAdult;
  bool get adultUnlocked => _adultUnlocked;
  bool get _filterAdult => parentalActive && hideAdult && !_adultUnlocked;

  bool isAdultGroup(String group) => Parental.isAdult(group);
  bool isGroupLocked(String group) =>
      parentalActive && !_adultUnlocked && Parental.isAdult(group);

  List<MediaCategory> _visibleCats(List<MediaCategory> all) {
    if (!_filterAdult) return all;
    return all.where((c) => !Parental.isAdult(c.name)).toList();
  }

  void unlockAdultSession() {
    _adultUnlocked = true;
    notifyListeners();
  }

  void lockAdultSession() {
    _adultUnlocked = false;
    notifyListeners();
  }

  Future<void> setParentalEnabled(bool enabled) async {
    await _storage.saveParentalEnabled(enabled);
    if (!enabled) _adultUnlocked = false;
    notifyListeners();
  }

  Future<void> setHideAdult(bool hide) async {
    await _storage.saveHideAdult(hide);
    notifyListeners();
  }

  // ---------- filtros por gênero (cruzam todas as pastas) ----------
  Map<String, List<MediaItem>> _genreMapFor(List<MediaItem> items) => items == live
      ? _genreLive
      : items == series
          ? _genreSeries
          : _genreMovies;

  /// Gêneros com pelo menos um item na aba, na ordem fixa de [Genres.all].
  /// Esconde "+18" quando o controle parental está ocultando conteúdo adulto.
  List<String> genresFor(List<MediaItem> items) {
    final map = _genreMapFor(items);
    return [
      for (final g in Genres.all)
        if ((map[g]?.isNotEmpty ?? false) &&
            !(Genres.isAdultGenre(g) && _filterAdult))
          g,
    ];
  }

  /// Itens de um gênero, de qualquer pasta. Aplica o filtro adulto da sessão.
  List<MediaItem> inGenre(List<MediaItem> items, String genre) {
    final hit = _genreMapFor(items)[genre] ?? const <MediaItem>[];
    if (!_filterAdult) return hit;
    return hit.where((e) => !Parental.isAdult(e.group)).toList();
  }

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
    final filterAdult = _filterAdult;
    final out = <MediaItem>[];
    for (final item in _all) {
      if (filterAdult && Parental.isAdult(item.group)) continue;
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

    // Séries de lista M3U: episódios já agrupados na importação.
    final local = _m3uEpisodes[item.id];
    if (local != null && local.isNotEmpty) {
      final detail = _seriesFromEpisodes(item, local);
      _seriesCache[item.id] = detail;
      return detail;
    }

    final p = playlist;
    if (p != null && p.kind == PlaylistKind.xtream) {
      final detail = await XtreamApi(p).seriesInfo(item.remoteId);
      if (detail.seasons.isNotEmpty) {
        _seriesCache[item.id] = detail;
        return detail;
      }
    }

    throw const XtreamException('Esta série não retornou episódios');
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
    _recordUsage(item);
  }

  void _recordUsage(MediaItem item) {
    if (item.url.isEmpty) return; // container de série, não conta
    final s = session;
    final email = s == null
        ? 'local'
        : s.isMaster
            ? kMasterEmail
            : s.email;
    // Episódio de série: o nome da série vem no `group`; guardamos separado
    // para o painel mostrar "Série · T01E03 · Título" e não só "T01E03".
    final isEpisode = item.kind == MediaKind.series && item.group.isNotEmpty;
    unawaited(_accounts.recordEvent(UsageEvent(
      userEmail: email,
      userName: s?.displayName ?? '',
      mediaId: item.id,
      title: item.name,
      group: item.group,
      seriesName: isEpisode ? item.group : '',
      kind: item.kind,
      watchedAt: DateTime.now(),
    )));
  }

  Future<void> clearFavoritesAndHistory() async {
    favorites = <String>{};
    _recentIds = const [];
    _playbackProgress = {};
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
    _playbackProgress = {};
    _seriesCache.clear();
    session = null;
    masterAppMode = false;
    _adultUnlocked = false;
    _apply(const PlaylistContent());
    stage = LoadStage.idle;
    notifyListeners();
  }

  // ---------- controle parental / PIN ----------
  static const defaultPin = '1234';

  String? get parentalPin => _storage.parentalPin;
  bool get isParentalEnabled => parentalPin != null && parentalPin!.isNotEmpty;

  bool verifyPin(String input) {
    final stored = parentalPin;
    if (stored == null || stored.isEmpty) return input == defaultPin;
    if (stored == defaultPin) return input == defaultPin;
    if (stored == input) return true;
    return stored == sha256.convert(utf8.encode(input)).toString();
  }

  Future<void> setParentalPin(String? pin) async {
    if (pin == null || pin.isEmpty || pin == defaultPin) {
      await _storage.saveParentalPin(null);
    } else {
      await _storage.saveParentalPin(
        sha256.convert(utf8.encode(pin)).toString(),
      );
    }
    notifyListeners();
  }

  // ---------- continuar assistindo ----------
    Map<String, PlaybackProgress> _playbackProgress = {};

  Map<String, PlaybackProgress> get playbackProgress =>
      Map<String, PlaybackProgress>.unmodifiable(_playbackProgress);

    PlaybackProgress? getProgress(String itemId) => _playbackProgress[itemId];

  Future<void> saveProgress(MediaItem item, int posSec, int durSec) async {
    if (item.kind == MediaKind.live || item.url.isEmpty || durSec <= 0) {
      return;
    }
    final progress = PlaybackProgress(
      mediaId: item.id,
      title: item.name,
      logo: item.logo,
      group: item.group,
      url: item.url,
      kind: item.kind,
      positionSeconds: posSec,
      durationSeconds: durSec,
      updatedAt: DateTime.now(),
    );
    await _storage.savePlaybackProgress(progress);
    _playbackProgress =
      Map<String, PlaybackProgress>.from(_storage.playbackProgress);
    notifyListeners();
  }

  Future<void> clearProgress(String itemId) async {
    await _storage.clearPlaybackProgress(itemId);
    _playbackProgress =
      Map<String, PlaybackProgress>.from(_storage.playbackProgress);
    notifyListeners();
  }

  List<MediaItem> get continueWatchingItems {
    if (_playbackProgress.isEmpty) return const [];
    final list = _playbackProgress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final out = <MediaItem>[];
    for (final p in list) {
      final item = _byId[p.mediaId] ?? p.toMediaItem();
      if (item.url.isNotEmpty) out.add(item);
    }
    return out;
  }

  // ---------- login / sessão ----------
  Future<String?> login(
    String email,
    String password, {
    required bool remember,
  }) async {
    final e = email.trim();
    if (e.isEmpty || password.isEmpty) return 'Informe e-mail e senha.';

    if (isMasterCredential(e, password)) {
      final err = await _accounts.signInMaster(e, password);
      if (err != null) return err;
      session = const SessionUser(email: kMasterEmail, isMaster: true);
      masterAppMode = false;
      await _remember(remember, kMasterEmail, password);
      notifyListeners();
      return null;
    }

    final user = await _accounts.authenticate(e, password);
    if (user == null) return 'E-mail ou senha inválidos.';
    if (!user.isActive) {
      return 'Conta ${user.status.label.toLowerCase()} ou expirada. Fale com o administrador.';
    }

    session = SessionUser(email: user.email, account: user);
    await _remember(remember, e, password);
    notifyListeners();
    unawaited(_reportDevice(user));
    await _applyAccountPlaylist(user);
    return null;
  }

  /// Anota, no perfil da conta, o aparelho e o horário deste acesso.
  Future<void> _reportDevice(AdminUser user) async {
    try {
      final label = await DeviceLabel.resolve();
      await _accounts.reportDevice(user.id, label);
    } on Object {
      // telemetria best-effort
    }
  }

  Future<void> _remember(bool remember, String email, String password) async {
    if (remember) {
      await _storage.saveRememberedLogin(email, password);
    } else {
      await _storage.clearRememberedLogin();
    }
  }

  Future<void> _tryAutoLogin() async {
    final e = _storage.rememberedEmail;
    final p = _storage.rememberedPassword;
    if (e == null || p == null || e.isEmpty) {
      // Sem "manter conectado": encerra qualquer sessão persistida do backend.
      await _accounts.signOut();
      return;
    }

    if (isMasterCredential(e, p)) {
      final err = await _accounts.signInMaster(e, p);
      if (err == null) {
        session = const SessionUser(email: kMasterEmail, isMaster: true);
      }
      return;
    }
    final user = await _accounts.authenticate(e, p);
    if (user != null && user.isActive) {
      session = SessionUser(email: user.email, account: user);
      _pendingAccount = user;
      unawaited(_reportDevice(user));
    }
  }

  Future<void> _applyAccountPlaylist(AdminUser user) async {
    final url = user.m3uUrl.trim();
    if (url.isEmpty) return;
    final current = _storage.playlist;
    if (current != null &&
        current.kind == PlaylistKind.m3u &&
        current.url == url) {
      return; // já é a lista certa; o cache carregado basta
    }
    await connect(Playlist(
      name: user.name.isEmpty ? 'Minha lista' : user.name,
      kind: PlaylistKind.m3u,
      url: url,
    ));
  }

  Future<void> logout() async {
    await _storage.clearRememberedLogin();
    await _accounts.signOut();
    session = null;
    masterAppMode = false;
    _adultUnlocked = false;
    notifyListeners();
  }

  void enterMasterAppMode() {
    masterAppMode = true;
    notifyListeners();
  }

  void exitMasterAppMode() {
    masterAppMode = false;
    notifyListeners();
  }

  // ---------- contas (painel de controle) ----------
  List<AdminUser> get adminUsers => _accounts.users;

  /// Contas que vencem em até 7 dias, mais próximas do vencimento primeiro.
  List<AdminUser> get expiringSoonUsers => adminUsers
      .where((u) => u.isExpiringSoon)
      .toList()
    ..sort((a, b) => (a.daysLeft ?? 0).compareTo(b.daysLeft ?? 0));

  /// Contas já vencidas (login bloqueado até o master renovar).
  List<AdminUser> get expiredUsers =>
      adminUsers.where((u) => u.isExpired).toList();

  Future<void> saveAdminUser(AdminUser user) async {
    await _accounts.saveUser(user);
    notifyListeners();
  }

  Future<void> deleteAdminUser(String userId) async {
    await _accounts.deleteUser(userId);
    notifyListeners();
  }

  // ---------- senha das contas ----------
  bool get canMasterSetPassword => _accounts.canMasterSetPassword;
  bool get canEmailPasswordReset => _accounts.canEmailPasswordReset;

  /// Define a senha de [user]. `null` em sucesso ou mensagem de erro.
  Future<String?> setUserPassword(AdminUser user, String newPassword) async {
    final err = await _accounts.setPassword(user, newPassword);
    if (err == null) notifyListeners();
    return err;
  }

  Future<void> sendPasswordReset(String email) =>
      _accounts.sendPasswordReset(email);

  /// Renova o plano da conta por mais um período e reativa o acesso.
  Future<void> renewUser(AdminUser user) async {
    final next = user.copyWith(
      expiresAt: user.renewedExpiry(),
      status: UserStatus.active,
    );
    await _accounts.saveUser(next);
    notifyListeners();
  }

  Future<void> setUserBlocked(AdminUser user, bool blocked) async {
    final next = user.copyWith(
      status: blocked ? UserStatus.blocked : UserStatus.active,
    );
    await _accounts.saveUser(next);
    notifyListeners();
  }

  // ---------- preços dos planos ----------
  Pricing get pricing => _accounts.pricing;

  Future<void> savePricing(Pricing p) async {
    await _accounts.savePricing(p);
    notifyListeners();
  }

  List<UsageEvent> get usageEvents => _accounts.events;

  Future<void> clearUsage() async {
    await _accounts.clearEvents();
    notifyListeners();
  }
}
