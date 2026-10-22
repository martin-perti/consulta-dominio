import 'package:consulta_dominio/dominio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarDominio', () {
    test('saca espacios, guiones y pasa a mayúsculas', () {
      expect(normalizarDominio(' ab 123-cd '), 'AB123CD');
    });
  });

  group('formatoDe', () {
    test('reconoce los cuatro formatos', () {
      expect(formatoDe('ABC123'), FormatoDominio.autoViejo);
      expect(formatoDe('AB123CD'), FormatoDominio.autoMercosur);
      expect(formatoDe('123ABC'), FormatoDominio.motoVieja);
      expect(formatoDe('A123BCD'), FormatoDominio.motoMercosur);
    });

    test('rechaza textos que no son dominios', () {
      expect(formatoDe('AB12CD'), isNull);
      expect(formatoDe('ABCD12'), isNull);
      expect(formatoDe(''), isNull);
    });
  });

  group('buscarDominioEnTexto', () {
    test('encuentra la patente Mercosur entre otros textos de la chapa', () {
      const ocr = 'REPUBLICA ARGENTINA\nAB 123 CD\nMERCOSUR';
      expect(buscarDominioEnTexto(ocr), 'AB123CD');
    });

    test('encuentra la patente vieja', () {
      expect(buscarDominioEnTexto('ARGENTINA\nGHT 482'), 'GHT482');
    });

    test('corrige confusiones típicas del OCR', () {
      expect(buscarDominioEnTexto('A8 I23 CD'), 'AB123CD');
      expect(buscarDominioEnTexto('0RT 4S2'), 'ORT452');
    });

    test('devuelve null si no hay patente', () {
      expect(buscarDominioEnTexto('REPUBLICA ARGENTINA'), isNull);
    });
  });
}
