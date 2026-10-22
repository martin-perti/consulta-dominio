import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'resultado.dart';

class SheetsException implements Exception {
  SheetsException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Guarda una consulta en la planilla a través del script de Apps Script.
/// Devuelve el número de fila (#) que le asignó la planilla.
class SheetsClient {
  SheetsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get configurado => Config.sheetsUrl.isNotEmpty;

  Future<int> guardar(ResultadoEstimador r, {required String usuario}) async {
    if (!configurado) {
      throw SheetsException('Falta configurar la URL de la planilla (SHEETS_URL).');
    }
    final cuerpo = jsonEncode({
      'token': Config.sheetsToken,
      'usuario': usuario,
      ...r.toJson(),
    });

    // Apps Script responde a los POST con una redirección (302) a otra
    // dirección donde queda la respuesta. Los datos ya se guardaron con el
    // POST; el GET posterior solo sirve para leer el resultado.
    final req = http.Request('POST', Uri.parse(Config.sheetsUrl))
      ..headers['Content-Type'] = 'text/plain; charset=utf-8'
      ..body = cuerpo
      ..followRedirects = false;
    var resp = await http.Response.fromStream(await _client.send(req));
    if (resp.isRedirect || resp.statusCode == 302 || resp.statusCode == 303) {
      final destino = resp.headers['location'];
      if (destino == null) throw SheetsException('La planilla no respondió bien.');
      resp = await _client.get(Uri.parse(destino));
    }
    if (resp.statusCode != 200) {
      throw SheetsException('La planilla respondió con error ${resp.statusCode}.');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw SheetsException('La planilla rechazó el dato: ${json['error']}');
    }
    return (json['indice'] as num).toInt();
  }
}
