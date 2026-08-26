import 'package:flutter_test/flutter_test.dart';

import 'package:miaunet/services/m3u_parser.dart';
import 'package:miaunet/models/models.dart';

void main() {
  test('classifica filmes M3U por categoria e URL parametrizada', () {
    final items = M3uParser.parse('''#EXTM3U
#EXTINF:-1 tvg-name="Megapix" group-title="VOD | Filmes",Megapix
http://iptv.test/movie/usuario/senha/12345.mp4?token=abc
#EXTINF:-1 tvg-name="Canal 24h" group-title="Esportes",Canal 24h
http://iptv.test/live/usuario/senha/67890.m3u8?token=abc
''');

    expect(items, hasLength(2));
    expect(items[0].kind, MediaKind.movie);
    expect(items[1].kind, MediaKind.live);
  });
}
