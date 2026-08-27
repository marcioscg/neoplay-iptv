/// Classificação de conteúdo por gênero a partir do nome da categoria
/// (group-title) e do nome do item.
///
/// Serve para os filtros da Home: a pessoa escolhe "Ação", "Novelas", "+18" etc.
/// e vê tudo daquele gênero, sem importar em qual pasta o provedor colocou.
///
/// É uma heurística de palavras‑chave — listas IPTV não trazem metadados de
/// gênero confiáveis. Um item pode cair em mais de um gênero.
class Genres {
  /// Ordem em que os chips aparecem na tela.
  static const all = <String>[
    'Ação',
    'Aventura',
    'Comédia',
    'Drama',
    'Terror',
    'Ficção científica',
    'Romance',
    'Suspense',
    'Documentário',
    'Animação',
    'Infantil',
    'Novelas',
    'Notícias',
    'Esportes',
    'Religioso',
    'Música',
    '+18',
  ];

  /// Gênero -> expressão que reconhece o gênero em um texto já normalizado.
  static final Map<String, RegExp> _rules = {
    'Ação': _re(r'\ba[çc][ãa]o\b|\baction\b|tiroteio|combate'),
    'Aventura': _re(r'aventura|adventure'),
    'Comédia': _re(r'com[ée]dia|comedy|humor|sitcom'),
    'Drama': _re(r'\bdrama\b|dram[áa]tico'),
    'Terror': _re(r'terror|horror|medo|assombr'),
    'Ficção científica':
        _re(r'fic[çc][ãa]o\s*cient|sci[\s-]?fi|\bficc\b|espacial|\bscifi\b'),
    'Romance': _re(r'romance|rom[âa]ntico|\blove\b|amor'),
    'Suspense': _re(r'suspense|thriller|mist[ée]rio|myster'),
    'Documentário': _re(r'document[áa]r|\bdocs?\b|\bdoc\b|reportagem'),
    'Animação': _re(r'anima[çc][ãa]o|animation|anime|\bcartoon|desenho'),
    'Infantil': _re(r'infantil|\bkids\b|crian[çc]|\bcrianças\b|junior|\bbaby\b'),
    'Novelas': _re(r'novela|nvl|telenovela|turcas?|turca|coreana|dorama'),
    'Notícias': _re(r'not[íi]cias?|\bnews\b|jornal|jornalismo'),
    'Esportes':
        _re(r'esporte|sport|\bfutebol\b|\bnba\b|\bnfl\b|\bufc\b|combat|premiere|dazn'),
    'Religioso':
        _re(r'religios|\bgospel\b|\bcat[óo]lic|evang[ée]lic|\bfé\b|crist[ãa]o|igreja'),
    'Música': _re(r'\bm[úu]sica\b|\bmusic\b|\bshow\b|\bshows\b|clipe|\bmtv\b'),
    '+18': _re(
        r'\bxxx\b|\+\s*18|\b18\s*\+|\badult\b|adulto|adultos|\bporn|porno|hentai|\berot|er[óo]tic|\bsex\b|sexo|priv[êe]|onlyfans|brazzers'),
  };

  static RegExp _re(String pattern) => RegExp(pattern, caseSensitive: false);

  /// Gêneros que casam com [group] + [name].
  static Set<String> of(String group, String name) {
    final text = '$group  $name';
    final out = <String>{};
    for (final entry in _rules.entries) {
      if (entry.value.hasMatch(text)) out.add(entry.key);
    }
    return out;
  }

  static bool isAdultGenre(String genre) => genre == '+18';
}
