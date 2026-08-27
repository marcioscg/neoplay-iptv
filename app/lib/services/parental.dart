/// Heurística de detecção de conteúdo adulto por nome de categoria ou item.
///
/// Usada pelo controle parental: categorias marcadas como adultas ficam atrás
/// do PIN e podem ser totalmente ocultadas nas configurações.
class Parental {
  static final _adult = RegExp(
    r'(\bxxx\b|\+\s*18|\b18\s*\+|\badult\b|adulto|adultos|\bporn|porno|hentai|\berot|er[oó]tic|\bsex\b|sexo|priv[eê]|onlyfans|\bcam4\b|brazzers)',
    caseSensitive: false,
  );

  static bool isAdult(String text) {
    if (text.isEmpty) return false;
    return _adult.hasMatch(text);
  }
}
