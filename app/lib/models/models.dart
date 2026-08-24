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
  const PlaylistContent({this.live = const [], this.movies = const []});

  bool get isEmpty => live.isEmpty && movies.isEmpty;
}
