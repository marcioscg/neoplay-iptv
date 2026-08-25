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

  bool get isAdult => isAdultContentGroup(group) || isAdultContentGroup(name);

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

  bool get isAdult => isAdultContentGroup(name);
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

  /// Rótulo curto usado nas listas: S01E03.
  String get label =>
      'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';

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



/// Planos de assinatura do sistema MIAUNET.
enum AdminPlan { mensal, trimestral, semestral, anual, vitalicio }

extension AdminPlanExtension on AdminPlan {
  String get label {
    switch (this) {
      case AdminPlan.mensal:
        return 'Mensal (30 dias)';
      case AdminPlan.trimestral:
        return 'Trimestral (90 dias)';
      case AdminPlan.semestral:
        return 'Semestral (180 dias)';
      case AdminPlan.anual:
        return 'Anual (365 dias)';
      case AdminPlan.vitalicio:
        return 'Vitalício';
    }
  }

  int get days {
    switch (this) {
      case AdminPlan.mensal:
        return 30;
      case AdminPlan.trimestral:
        return 90;
      case AdminPlan.semestral:
        return 180;
      case AdminPlan.anual:
        return 365;
      case AdminPlan.vitalicio:
        return 36500;
    }
  }

  DateTime calculateExpiration([DateTime? from]) {
    final start = from ?? DateTime.now();
    if (this == AdminPlan.vitalicio) {
      return DateTime(2099, 12, 31);
    }
    return start.add(Duration(days: days));
  }
}

/// Usuário cadastrado pelo Administrador no MIAUNET.
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final AdminPlan plan;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String notes;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.plan,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.notes = '',
  });

  bool get isExpired =>
      plan != AdminPlan.vitalicio && DateTime.now().isAfter(expiresAt);

  int get daysRemaining {
    if (plan == AdminPlan.vitalicio) return 9999;
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'plan': plan.name,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'isActive': isActive,
        'notes': notes,
      };

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        password: (j['password'] ?? '') as String,
        plan: AdminPlan.values.firstWhere(
          (e) => e.name == (j['plan'] ?? 'mensal'),
          orElse: () => AdminPlan.mensal,
        ),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        expiresAt: DateTime.tryParse('${j['expiresAt']}') ??
            DateTime.now().add(const Duration(days: 30)),
        isActive: (j['isActive'] as bool?) ?? true,
        notes: (j['notes'] ?? '') as String,
      );

  AdminUser copyWith({
    String? name,
    String? email,
    String? password,
    AdminPlan? plan,
    DateTime? expiresAt,
    bool? isActive,
    String? notes,
  }) {
    return AdminUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}

/// Progresso salvo de reprodução ("Continuar Assistindo").
class PlaybackProgress {
  final String itemId;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;

  const PlaybackProgress({
    required this.itemId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
  });

  double get fraction => durationSeconds > 0
      ? (positionSeconds / durationSeconds).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlaybackProgress.fromJson(Map<String, dynamic> j) => PlaybackProgress(
        itemId: (j['itemId'] ?? '') as String,
        positionSeconds: (j['positionSeconds'] ?? 0) as int,
        durationSeconds: (j['durationSeconds'] ?? 0) as int,
        updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      );
}

/// Heurística para identificar conteúdo ou categoria adulta (+18).
bool isAdultContentGroup(String group) {
  final g = group.toLowerCase();
  return g.contains('+18') ||
      g.contains('18+') ||
      g.contains('adult') ||
      g.contains('adulto') ||
      g.contains('xxx') ||
      g.contains('porn') ||
      g.contains('erot') ||
      g.contains('sexy') ||
      g.contains('sensual') ||
      g.contains('red light') ||
      g.contains('hustler') ||
      g.contains('venus') ||
      g.contains('sextreme') ||
      g.contains('playboy');
}
  int get episodeCount =>
      seasons.fold<int>(0, (sum, s) => sum + s.episodes.length);
}
