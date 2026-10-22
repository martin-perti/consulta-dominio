import 'dart:convert';

import 'package:consulta_dominio/ajustes.dart';
import 'package:consulta_dominio/resultado.dart';
import 'package:consulta_dominio/sheets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url = 'https://script.google.com/macros/s/ABC/exec';
const _ajustes = Ajustes(usuario: 'marto', sheetsUrl: _url, sheetsToken: 'k');

const _resultado = ResultadoEstimador(
  dominio: 'AB123CD',
  tramite: 'TRANSFERENCIA DE AUTOMOTOR IMPORTADO',
  tipoVehiculo: 'Auto',
  marca: 'VOLKSWAGEN',
  modelo: 'VENTO',
  tipo: 'RURAL 5 PTAS',
  anio: 2011,
  origen: 'IMPORTADO',
  valorTabla: 11702900,
  provincia: 'BUENOS AIRES',
);

void main() {
  group('problemaConLink', () {
    test('acepta el link de la aplicación web', () {
      expect(problemaConLink(_url), isNull);
    });

    test('rechaza el link de la planilla o uno sin /exec', () {
      expect(
        problemaConLink('https://docs.google.com/spreadsheets/d/x/edit'),
        isNotNull,
      );
      expect(
        problemaConLink('https://script.google.com/macros/s/ABC/dev'),
        isNotNull,
      );
    });
  });

  group('SheetsClient.guardar', () {
    test('sigue la redirección de Apps Script y devuelve el número', () async {
      late Map<String, dynamic> enviado;
      final client = MockClient((req) async {
        if (req.method == 'POST') {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://script.googleusercontent.com/r'},
          );
        }
        return http.Response(jsonEncode({'ok': true, 'indice': 7}), 200);
      });

      final indice = await SheetsClient(
        client: client,
      ).guardar(_resultado, _ajustes);

      expect(indice, 7);
      expect(enviado['token'], 'k');
      expect(enviado['usuario'], 'marto');
      expect(enviado['marca'], 'VOLKSWAGEN');
    });

    test('explica cuando la clave no coincide', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': false, 'error': 'clave incorrecta'}),
          200,
        ),
      );
      expect(
        SheetsClient(client: client).guardar(_resultado, _ajustes),
        throwsA(
          isA<SheetsException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('clave'),
          ),
        ),
      );
    });

    test('explica cuando Google devuelve una página web', () async {
      final client = MockClient(
        (_) async => http.Response('<html>Iniciar sesión</html>', 200),
      );
      expect(
        SheetsClient(client: client).guardar(_resultado, _ajustes),
        throwsA(
          isA<SheetsException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('Cualquier usuario'),
          ),
        ),
      );
    });

    test('pide conectar la planilla si no hay link', () async {
      expect(
        SheetsClient().guardar(
          _resultado,
          const Ajustes(usuario: '', sheetsUrl: '', sheetsToken: ''),
        ),
        throwsA(isA<SheetsException>()),
      );
    });
  });
}
