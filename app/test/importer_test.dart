import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoplay/models/models.dart';
import 'package:neoplay/services/importer.dart';

void main() {
  test('importa M3U separando canais e filmes', () async {
    const body = '''
#EXTM3U
#EXTINF:-1 tvg-id="globo.br" tvg-logo="http://x/l.png" group-title="ABERTOS",Globo HD
http://servidor.com/live/u/p/1.m3u8
#EXTINF:-1 group-title="FILMES | ACAO",Duro de Matar
http://servidor.com/movie/u/p/9.mp4
''';

    final result = await importM3u(body);
    expect(result.content.live.length, 1);
    expect(result.content.movies.length, 1);
    expect(result.content.live.first.name, 'Globo HD');
    expect(result.content.live.first.group, 'ABERTOS');
    expect(result.content.movies.first.kind, MediaKind.movie);
    expect(result.cacheJson, contains('Globo HD'));
  });

  test('importa Xtream montando URLs e categorias', () async {
    final liveBody = jsonEncode([
      {
        'stream_id': 101,
        'name': 'SporTV',
        'category_id': '7',
        'stream_icon': 'http://x/s.png',
        'epg_channel_id': 'sportv.br',
      },
      {'stream_id': 101, 'name': 'Duplicado', 'category_id': '7'},
    ]);
    final vodBody = jsonEncode([
      {
        'stream_id': 55,
        'name': 'Matrix',
        'category_id': '9',
        'container_extension': 'mkv',
      },
    ]);

    final result = await importXtream(
      XtreamJob(
        liveBody: liveBody,
        vodBody: vodBody,
        liveCategories: const {'7': 'ESPORTES'},
        vodCategories: const {'9': 'CLASSICOS'},
        host: 'http://servidor.com:8080',
        username: 'user',
        password: 'pass',
      ),
    );

    expect(result.content.live.length, 1, reason: 'deve ignorar duplicados');
    expect(
      result.content.live.first.url,
      'http://servidor.com:8080/live/user/pass/101.m3u8',
    );
    expect(result.content.live.first.group, 'ESPORTES');
    expect(
      result.content.movies.first.url,
      'http://servidor.com:8080/movie/user/pass/55.mkv',
    );
    expect(result.content.movies.first.id, 'vod_55');
  });

  test('cache faz ida e volta sem perder itens', () async {
    final items = [
      for (var i = 0; i < 500; i++)
        {
          'stream_id': i,
          'name': 'Canal $i',
          'category_id': '1',
        },
    ];
    final result = await importXtream(
      XtreamJob(
        liveBody: jsonEncode(items),
        vodBody: '',
        liveCategories: const {'1': 'GERAL'},
        vodCategories: const {},
        host: 'http://h',
        username: 'u',
        password: 'p',
      ),
    );

    final restored = await decodeCache(result.cacheJson);
    expect(restored.live.length, 500);
    expect(restored.movies, isEmpty);
    expect(restored.live.last.name, 'Canal 499');
  });

  test('corpo vazio ou inválido não quebra a importação', () async {
    final result = await importXtream(
      const XtreamJob(
        liveBody: '<html>erro</html>',
        vodBody: '',
        liveCategories: {},
        vodCategories: {},
        host: 'http://h',
        username: 'u',
        password: 'p',
      ),
    );
    expect(result.content.isEmpty, isTrue);
  });
}
