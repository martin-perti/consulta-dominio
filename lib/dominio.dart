/// Formatos de dominio argentinos que acepta la app.
enum FormatoDominio { autoViejo, autoMercosur, motoVieja, motoMercosur }

// L = letra, N = número.
const _patrones = <FormatoDominio, String>{
  FormatoDominio.autoViejo: 'LLLNNN', // ABC123
  FormatoDominio.autoMercosur: 'LLNNNLL', // AB123CD
  FormatoDominio.motoVieja: 'NNNLLL', // 123ABC
  FormatoDominio.motoMercosur: 'LNNNLLL', // A123BCD
};

// Confusiones típicas del OCR, según lo que se espera en cada posición.
const _aLetra = {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '8': 'B', '6': 'G'};
const _aNumero = {
  'O': '0',
  'Q': '0',
  'D': '0',
  'I': '1',
  'L': '1',
  'Z': '2',
  'S': '5',
  'B': '8',
  'G': '6',
};

/// Pasa a mayúsculas y saca espacios, guiones, puntos y barras.
String normalizarDominio(String texto) =>
    texto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Devuelve el formato si [dominio] (ya normalizado) es válido, o null.
FormatoDominio? formatoDe(String dominio) {
  for (final e in _patrones.entries) {
    if (_cumple(dominio, e.value)) return e.key;
  }
  return null;
}

bool esDominioValido(String texto) =>
    formatoDe(normalizarDominio(texto)) != null;

bool _cumple(String s, String patron) {
  if (s.length != patron.length) return false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final esLetra = c >= 65 && c <= 90;
    final esNumero = c >= 48 && c <= 57;
    if (patron[i] == 'L' ? !esLetra : !esNumero) return false;
  }
  return true;
}

String? _corregir(String s, String patron) {
  if (s.length != patron.length) return null;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final tabla = patron[i] == 'L' ? _aLetra : _aNumero;
    b.write(tabla[c] ?? c);
  }
  final r = b.toString();
  return _cumple(r, patron) ? r : null;
}

/// Busca un dominio dentro del texto que leyó el OCR de una foto.
///
/// Primero busca coincidencias exactas y después prueba corrigiendo
/// confusiones típicas (0/O, 1/I, 8/B...). Se revisa línea por línea para
/// no mezclar textos de distintas partes de la chapa.
String? buscarDominioEnTexto(String texto) {
  final lineas = texto
      .split('\n')
      .map(normalizarDominio)
      .where((l) => l.length >= 6)
      .toList();
  for (final corregir in [false, true]) {
    for (final linea in lineas) {
      // Corregir letras por números en textos largos ("REPUBLICA ARGENTINA")
      // inventa patentes; solo se corrige en líneas cortas, donde la patente
      // suele quedar sola.
      if (corregir && linea.length > 8) continue;
      for (final largo in [7, 6]) {
        for (var i = 0; i + largo <= linea.length; i++) {
          final ventana = linea.substring(i, i + largo);
          for (final patron in _patrones.values) {
            if (patron.length != largo) continue;
            final r = corregir ? _corregir(ventana, patron) : ventana;
            if (r != null && _cumple(r, patron)) return r;
          }
        }
      }
    }
  }
  return null;
}
