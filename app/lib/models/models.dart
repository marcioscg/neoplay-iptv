/// Tipo de fonte da lista.
enum PlaylistKind { m3u, xtream }

/// Lista de reprodução cadastrada pelo usuário.
class Playlist {
  final String name;
  final PlaylistKind kind;

  /// Usado quando [kind] == PlaylistKind.m3u
  final String url;

  /// Usados quando [kind] == PlaylistKind.xtream
  final String host;
  final String username;
  final String password;

  const Playlist({
    required this.name,
    required this.kind,
    this.url = '',
    this.host = '',
    this.username = '',
    this.password = '',
  });

  /// Host normalizado, sempre com esquema e sem barra final.
  String get normalizedHost {
    var h = host.trim();
    if (h.isEmpty) return h;
    if (!h.startsWith('http://') && !h.startsWith('https://')) h = 'http://$h';
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'url': url,
        'host': host,
        'username': username,
        'password': password,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        name: (j['name'] ?? 'Minha lista') as String,
        kind: (j['kind'] as String?) == 'xtream'
            ? PlaylistKind.xtream
            : PlaylistKind.m3u,
        url: (j['url'] ?? '') as String,
        host: (j['host'] ?? '') as String,
        username: (j['username'] ?? '') as String,
        password: (j['password'] ?? '') as String,
      );
}

/// Tipo de mídia de um item da lista.
enum MediaKind { live, movie, series }

/// Item reproduzível (canal ao vivo ou filme) ou container (série).
class MediaItem {
  final String id;
  final String name;
  final String url;
  final String logo;
  final String group;
  final String tvgId;
  final MediaKind kind;

  const MediaItem({
    required this.id,
    required this.name,
    required this.url,
    this.logo = '',
    this.group = 'Sem categoria',
    this.tvgId = '',
    this.kind = MediaKind.live,
  });

  /// Série do Xtream: não tem URL própria, precisa abrir para ver episódios.
  bool get isSeriesContainer => kind == MediaKind.series && url.isEmpty;

  /// ID numérico usado nas chamadas da API (sem os prefixos internos).
  String get remoteId {
    final i = id.indexOf('_');
    return i < 0 ? id : id.substring(i + 1);
  }

  Map<String, dynamic> toJson() => {
        'i': id,
        'n': name,
        'u': url,
        'l': logo,
        'g': group,
        't': tvgId,
        'k': kind.name,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: (j['i'] ?? '') as String,
        name: (j['n'] ?? '') as String,
        url: (j['u'] ?? '') as String,
        logo: (j['l'] ?? '') as String,
        group: (j['g'] ?? 'Sem categoria') as String,
        tvgId: (j['t'] ?? '') as String,
        kind: MediaKind.values.firstWhere(
          (e) => e.name == (j['k'] ?? 'live'),
          orElse: () => MediaKind.live,
        ),
      );
}

/// Categoria agrupada a partir do group-title (M3U) ou da API (Xtream).
class MediaCategory {
  final String name;
  final int count;
  const MediaCategory(this.name, this.count);
}

/// Resultado da importação de uma lista.
class PlaylistContent {
  final List<MediaItem> live;
  final List<MediaItem> movies;

  /// Em listas Xtream, cada item é uma série (container que precisa ser aberto
  /// para listar temporadas). Em listas M3U, são os episódios já prontos.
  final List<MediaItem> series;

  const PlaylistContent({
    this.live = const [],
    this.movies = const [],
    this.series = const [],
  });

  bool get isEmpty => live.isEmpty && movies.isEmpty && series.isEmpty;
}

/// Episódio de uma série (Xtream: get_series_info).
class SeriesEpisode {
  final String id;
  final String title;
  final String url;
  final String image;
  final String plot;
  final int season;
  final int number;
  final Duration? duration;

  const SeriesEpisode({
    required this.id,
    required this.title,
    required this.url,
    this.image = '',
    this.plot = '',
    this.season = 1,
    this.number = 1,
    this.duration,
  });

  /// Rótulo curto usado nas listas: T01E03.
  String get label =>
      'T${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';

  /// Converte para item reproduzível, reaproveitando o player.
  MediaItem toMediaItem(String seriesName) => MediaItem(
        id: 'ep_$id',
        name: '$label · $title',
        url: url,
        logo: image,
        group: seriesName,
        kind: MediaKind.series,
      );
}

/// Temporada com seus episódios.
class SeriesSeason {
  final int number;
  final List<SeriesEpisode> episodes;
  const SeriesSeason(this.number, this.episodes);
}

/// Detalhe de uma série carregado sob demanda.
class SeriesDetail {
  final String plot;
  final String cover;
  final String genre;
  final String rating;
  final String releaseDate;
  final List<SeriesSeason> seasons;

  const SeriesDetail({
    this.plot = '',
    this.cover = '',
    this.genre = '',
    this.rating = '',
    this.releaseDate = '',
    this.seasons = const [],
  });

  int get episodeCount =>
      seasons.fold<int>(0, (sum, s) => sum + s.episodes.length);
}

/// Tipos de Plano de Assinatura no Painel Admin.
enum UserPlan {
  mensal('Mensal', 30),
  trimestral('Trimestral', 90),
  semestral('Semestral', 180),
  anual('Anual', 365),
  vitalicio('Vitalício', null);

  final String label;
  final int? days;
  const UserPlan(this.label, this.days);

  static UserPlan fromString(String str) {
    return UserPlan.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase() || e.label.toLowerCase() == str.toLowerCase(),
      orElse: () => UserPlan.mensal,
    );
  }
}

/// Status do Usuário no sistema.
enum UserStatus {
  active('Ativo'),
  blocked('Bloqueado');

  final String label;
  const UserStatus(this.label);

  static UserStatus fromString(String str) {
    return UserStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase() || e.label.toLowerCase() == str.toLowerCase(),
      orElse: () => UserStatus.active,
    );
  }
}

/// Modelo de Usuário para o Painel Admin / Autenticação.
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String password;

  /// Lista M3U/M3U8 que vai rodar no app desta conta.
  final String m3uUrl;
  final UserPlan plan;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// Aparelho e momento do último acesso desta conta (preenchido no login).
  /// Só cruza aparelhos no modo Firebase; no modo local fica em branco.
  final String lastDevice;
  final DateTime? lastSeenAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.m3uUrl = '',
    this.plan = UserPlan.mensal,
    this.status = UserStatus.active,
    required this.createdAt,
    this.expiresAt,
    this.lastDevice = '',
    this.lastSeenAt,
  });

  bool get isExpired {
    if (plan == UserPlan.vitalicio || expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive => status == UserStatus.active && !isExpired;

  /// Dias até o vencimento (negativo se já venceu). `null` para vitalício.
  int? get daysLeft {
    if (plan == UserPlan.vitalicio || expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.inSeconds <= 0 ? diff.inDays : diff.inHours ~/ 24 + 1;
  }

  /// Está perto de vencer (7 dias ou menos) mas ainda não venceu.
  bool get isExpiringSoon {
    final d = daysLeft;
    return d != null && d >= 0 && d <= 7 && !isExpired;
  }

  /// Nova data de vencimento ao renovar por mais um período do plano.
  /// Parte da data atual de expiração se ela ainda está no futuro; senão de hoje.
  DateTime? renewedExpiry({DateTime? from}) {
    final days = plan.days;
    if (days == null) return null;
    final now = DateTime.now();
    final base = (expiresAt != null && expiresAt!.isAfter(now))
        ? expiresAt!
        : (from ?? now);
    return base.add(Duration(days: days));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'm3uUrl': m3uUrl,
        'plan': plan.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lastDevice': lastDevice,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        password: (j['password'] ?? '') as String,
        m3uUrl: (j['m3uUrl'] ?? '') as String,
        plan: UserPlan.fromString((j['plan'] ?? 'mensal') as String),
        status: UserStatus.fromString((j['status'] ?? 'active') as String),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime.now(),
        expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt'] as String) : null,
        lastDevice: (j['lastDevice'] ?? '') as String,
        lastSeenAt: j['lastSeenAt'] != null
            ? DateTime.tryParse(j['lastSeenAt'] as String)
            : null,
      );

  AdminUser copyWith({
    String? name,
    String? email,
    String? password,
    String? m3uUrl,
    UserPlan? plan,
    UserStatus? status,
    DateTime? expiresAt,
    String? lastDevice,
    DateTime? lastSeenAt,
  }) {
    return AdminUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastDevice: lastDevice ?? this.lastDevice,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

/// Tabela de preços dos planos, editável no painel (aba Pagamentos).
class Pricing {
  final double mensal;
  final double trimestral;
  final double semestral;
  final double anual;

  const Pricing({
    this.mensal = 0.0,
    this.trimestral = 0.0,
    this.semestral = 0.0,
    this.anual = 0.0,
  });

  static const empty = Pricing();

  double forPlan(UserPlan plan) => switch (plan) {
        UserPlan.mensal => mensal,
        UserPlan.trimestral => trimestral,
        UserPlan.semestral => semestral,
        UserPlan.anual => anual,
        UserPlan.vitalicio => 0.0,
      };

  /// Valor do plano dividido pelos meses que ele cobre — base do MRR.
  double monthlyEquivalent(UserPlan plan) => switch (plan) {
        UserPlan.mensal => mensal,
        UserPlan.trimestral => trimestral / 3,
        UserPlan.semestral => semestral / 6,
        UserPlan.anual => anual / 12,
        UserPlan.vitalicio => 0.0,
      };

  Pricing copyWith({
    double? mensal,
    double? trimestral,
    double? semestral,
    double? anual,
  }) =>
      Pricing(
        mensal: mensal ?? this.mensal,
        trimestral: trimestral ?? this.trimestral,
        semestral: semestral ?? this.semestral,
        anual: anual ?? this.anual,
      );

  Map<String, dynamic> toJson() => {
        'mensal': mensal,
        'trimestral': trimestral,
        'semestral': semestral,
        'anual': anual,
      };

  factory Pricing.fromJson(Map<String, dynamic> j) => Pricing(
        mensal: _asDouble(j['mensal']),
        trimestral: _asDouble(j['trimestral']),
        semestral: _asDouble(j['semestral']),
        anual: _asDouble(j['anual']),
      );
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', '.')) ?? 0;
}

/// Evento de uso registrado quando alguém abre um conteúdo. Base da central de
/// estatísticas do painel de controle.
class UsageEvent {
  final String userEmail;
  final String userName;
  final String mediaId;
  final String title;
  final String group;

  /// Para episódios de série: o nome da série (ex.: "Breaking Bad"). O [title]
  /// segue sendo o episódio ("T01E03 · Piloto"). Vazio para filmes e canais.
  final String seriesName;
  final MediaKind kind;
  final DateTime watchedAt;

  const UsageEvent({
    required this.userEmail,
    this.userName = '',
    required this.mediaId,
    required this.title,
    this.group = '',
    this.seriesName = '',
    required this.kind,
    required this.watchedAt,
  });

  /// Texto completo do que foi assistido, pronto para exibir.
  String get fullTitle => seriesName.isEmpty || title.startsWith(seriesName)
      ? title
      : '$seriesName · $title';

  Map<String, dynamic> toJson() => {
        'e': userEmail,
        'n': userName,
        'i': mediaId,
        't': title,
        'g': group,
        's': seriesName,
        'k': kind.name,
        'w': watchedAt.toIso8601String(),
      };

  factory UsageEvent.fromJson(Map<String, dynamic> j) => UsageEvent(
        userEmail: (j['e'] ?? '') as String,
        userName: (j['n'] ?? '') as String,
        mediaId: (j['i'] ?? '') as String,
        title: (j['t'] ?? '') as String,
        group: (j['g'] ?? '') as String,
        seriesName: (j['s'] ?? '') as String,
        kind: MediaKind.values.firstWhere(
          (x) => x.name == (j['k'] ?? 'live'),
          orElse: () => MediaKind.live,
        ),
        watchedAt: DateTime.tryParse((j['w'] ?? '') as String) ?? DateTime.now(),
      );
}

/// Posição salva de reprodução ("Continuar Assistindo").
class PlaybackProgress {
  final String mediaId;
  final String title;
  final String logo;
  final String group;
  final String url;
  final MediaKind kind;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;

  const PlaybackProgress({
    required this.mediaId,
    required this.title,
    this.logo = '',
    this.group = '',
    required this.url,
    required this.kind,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
  });

  double get percent => durationSeconds > 0
      ? (positionSeconds / durationSeconds).clamp(0.0, 1.0).toDouble()
      : 0.0;

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'title': title,
        'logo': logo,
        'group': group,
        'url': url,
        'kind': kind.name,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlaybackProgress.fromJson(Map<String, dynamic> j) => PlaybackProgress(
        mediaId: (j['mediaId'] ?? j['itemId'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        logo: (j['logo'] ?? '') as String,
        group: (j['group'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        kind: MediaKind.values.firstWhere(
          (e) => e.name == (j['kind'] ?? 'movie'),
          orElse: () => MediaKind.movie,
        ),
        positionSeconds: _asInt(j['positionSeconds']),
        durationSeconds: _asInt(j['durationSeconds']),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ?? DateTime.now(),
      );

  MediaItem toMediaItem() => MediaItem(
        id: mediaId,
        name: title,
        url: url,
        logo: logo,
        group: group,
        kind: kind,
      );
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse('$v') ?? 0;
}
