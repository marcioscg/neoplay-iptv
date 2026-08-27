import 'package:flutter_test/flutter_test.dart';

import 'package:miaunet/services/genres.dart';

void main() {
  test('reconhece gênero pelo nome da pasta', () {
    expect(Genres.of('Filmes | Ação e Aventura', 'John Wick 4'),
        containsAll(<String>['Ação', 'Aventura']));
  });

  test('reconhece novelas turcas', () {
    expect(Genres.of('NOVELAS TURCAS', 'Züleyha'), contains('Novelas'));
  });

  test('marca +18 e nada mais quando é só adulto', () {
    final g = Genres.of('CANAIS +18', 'XXX Brazzers');
    expect(g, contains('+18'));
  });

  test('conteúdo sem pista não recebe gênero', () {
    expect(Genres.of('Abertos HD', 'TV Brasil Leste'), isEmpty);
  });
}
