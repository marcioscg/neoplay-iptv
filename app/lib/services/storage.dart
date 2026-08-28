import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'importer.dart';
import 'secure_store.dart';

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
  static const _kParentalPin = 'parental_pin';
  static const _kParentalEnabled = 'parental_enabled';
  static const _kHideAdult = 'hide_adult';
  static const _kUsers = 'admin_users';
  static const _kUsage = 'usage_events';
  static const _kRememberEmail = 'remember_email';
  static const _kRememberPass = 'remember_pass'; // legado (texto puro) — migrado
  static const _kSecureRememberPass = 'remember_pass_secure';
  static const _kProgress = 'playback_progress';
  static const _kPricing = 'plan_pricing';
  static const _kLoginFails = 'login_fails';
  static const _kDeviceBindings = 'device_bindings';
  static const _kDueReminderDate = 'due_reminder_date';

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

    // 1.0.8: o seletor de tema saiu (app é sempre escuro).
    await prefs.remove('theme_choice');

    // 1.0.8: a senha do "manter conectado" saiu do texto puro para o Keystore.
    final legacyPass = prefs.getString(_kRememberPass);
    if (legacyPass != null && legacyPass.isNotEmpty) {
      await SecureStore.write(_kSecureRememberPass, legacyPass);
      await prefs.remove(_kRememberPass);
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

  // ---------- controle parental ----------
  String? get parentalPin {
    final v = _p.getString(_kParentalPin);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> saveParentalPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _p.remove(_kParentalPin);
    } else {
      await _p.setString(_kParentalPin, pin);
    }
  }

  bool get parentalEnabled => _p.getBool(_kParentalEnabled) ?? false;

  Future<void> saveParentalEnabled(bool enabled) =>
      _p.setBool(_kParentalEnabled, enabled);

  bool get hideAdult => _p.getBool(_kHideAdult) ?? true;

  Future<void> saveHideAdult(bool hide) => _p.setBool(_kHideAdult, hide);

  // ---------- sessão lembrada (manter conectado) ----------
  // O e-mail não é segredo e fica em SharedPreferences; a senha vai para o
  // armazenamento protegido do sistema (Keystore no Android) via [SecureStore].
  String? get rememberedEmail => _p.getString(_kRememberEmail);

  Future<String?> readRememberedPassword() =>
      SecureStore.read(_kSecureRememberPass);

  Future<void> saveRememberedLogin(String email, String password) async {
    await _p.setString(_kRememberEmail, email);
    await SecureStore.write(_kSecureRememberPass, password);
  }

  Future<void> clearRememberedLogin() async {
    await _p.remove(_kRememberEmail);
    await _p.remove(_kRememberPass);
    await SecureStore.delete(_kSecureRememberPass);
  }

  // ---------- autenticação & admin ----------
  AdminUser? get loggedUser {
    final raw = _p.getString('logged_user');
    if (raw == null || raw.isEmpty) return null;
    try {
      return AdminUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Exception {
      return null;
    }
  }

  Future<void> saveLoggedUser(AdminUser? user) async {
    if (user == null) {
      await _p.remove('logged_user');
    } else {
      await _p.setString('logged_user', jsonEncode(user.toJson()));
    }
  }

  List<AdminUser> get adminUsers {
    final raw = _p.getString(_kUsers);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map) AdminUser.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on Exception {
      return const [];
    }
  }

  Future<void> saveAdminUsers(List<AdminUser> users) => _p.setString(
        _kUsers,
        jsonEncode([for (final u in users) u.toJson()]),
      );

  // ---------- telemetria de uso (central de estatísticas) ----------
  List<UsageEvent> get usageEvents {
    final raw = _p.getString(_kUsage);
    if (raw == null || raw.isEmpty) return <UsageEvent>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <UsageEvent>[];
      return [
        for (final e in list)
          if (e is Map) UsageEvent.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on Exception {
      return <UsageEvent>[];
    }
  }

  Future<void> saveUsageEvents(List<UsageEvent> events) => _p.setString(
        _kUsage,
        jsonEncode([for (final e in events) e.toJson()]),
      );

  // ---------- progresso de reprodução ----------
  Map<String, PlaybackProgress> get playbackProgress {
    final raw = _p.getString(_kProgress);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      final out = <String, PlaybackProgress>{};
      map.forEach((k, v) {
        if (v is Map) {
          out['$k'] = PlaybackProgress.fromJson(Map<String, dynamic>.from(v));
        }
      });
      return out;
    } on Exception {
      return {};
    }
  }

  Future<void> savePlaybackProgress(PlaybackProgress progress) async {
    final map = playbackProgress;
    if (progress.percent >= 0.95 || progress.positionSeconds < 10) {
      map.remove(progress.mediaId);
    } else {
      map[progress.mediaId] = progress;
    }
    await _p.setString(
      _kProgress,
      jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}),
    );
  }

  Future<void> clearPlaybackProgress(String itemId) async {
    final map = playbackProgress;
    if (map.remove(itemId) != null) {
      await _p.setString(
        _kProgress,
        jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}),
      );
    }
  }

  // ---------- trava de tentativas de login (item 1.0.8) ----------
  Map<String, dynamic> get loginFails {
    final raw = _p.getString(_kLoginFails);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : {};
    } on Exception {
      return {};
    }
  }

  Future<void> saveLoginFails(Map<String, dynamic> map) =>
      _p.setString(_kLoginFails, jsonEncode(map));

  // ---------- trava de aparelho (Master 1) ----------
  String? deviceBinding(String key) {
    final raw = _p.getString(_kDeviceBindings);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is Map && m[key] is String) return m[key] as String;
    } on Exception {
      // ignora
    }
    return null;
  }

  Future<void> saveDeviceBinding(String key, String? deviceId) async {
    final raw = _p.getString(_kDeviceBindings);
    Map<String, dynamic> m = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) m = Map<String, dynamic>.from(d);
      } on Exception {
        m = {};
      }
    }
    if (deviceId == null) {
      m.remove(key);
    } else {
      m[key] = deviceId;
    }
    await _p.setString(_kDeviceBindings, jsonEncode(m));
  }

  // ---------- lembrete de mensalidade (mostrado 1x por dia) ----------
  String? get lastDueReminderDate => _p.getString(_kDueReminderDate);

  Future<void> setLastDueReminderDate(String yyyymmdd) =>
      _p.setString(_kDueReminderDate, yyyymmdd);

  // ---------- tabela de preços dos planos (aba Pagamentos) ----------
  Pricing get pricing {
    final raw = _p.getString(_kPricing);
    if (raw == null || raw.isEmpty) return Pricing.empty;
    try {
      return Pricing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Exception {
      return Pricing.empty;
    }
  }

  Future<void> savePricing(Pricing p) =>
      _p.setString(_kPricing, jsonEncode(p.toJson()));

  Future<void> clearAll() async {
    await _p.clear();
    try {
      if (await _cacheFile.exists()) await _cacheFile.delete();
    } on Exception {
      // Ignora falha ao apagar o arquivo de cache.
    }
  }
}
