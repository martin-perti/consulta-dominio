import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ajustes.dart';
import 'resultado.dart';

class SheetsException implements Exception {
  SheetsException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Revisa que el link sea el de una aplicación web de Apps Script. Devuelve
/// el problema en palabras, o null si está bien.
String? problemaConLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host != 'script.google.com') {
    return 'El link tiene que empezar con https://script.google.com/';
  }
  if (!uri.path.endsWith('/exec')) {
    return 'El link tiene que terminar en /exec (el de "Aplicación web").';
  }
  return null;
}

/// Guarda una consulta en la planilla a través del script de Apps Script.
class SheetsClient {
  SheetsClient({http.Client? client}) : _client = client ?? http.Client();

  static const _espera = Duration(seconds: 25);

  final http.Client _client;

  /// Guarda [r] y devuelve el número (#) que le asignó la planilla.
  Future<int> guardar(ResultadoEstimador r, Ajustes ajustes) async {
    if (!ajustes.planillaConfigurada) {
      throw SheetsException('Falta conectar la planilla (ícono de ajustes).');
    }
    final json = await _enviar(ajustes.sheetsUrl, {
      'token': ajustes.sheetsToken,
      'usuario': ajustes.usuario,
      ...r.toJson(),
    });
    return (json['indice'] as num).toInt();
  }

  /// Comprueba el link y la clave sin agregar filas.
  Future<void> probar(Ajustes ajustes) async {
    await _enviar(ajustes.sheetsUrl, {
      'token': ajustes.sheetsToken,
      'prueba': true,
    });
  }

  Future<Map<String, dynamic>> _enviar(
    String url,
    Map<String, Object?> datos,
  ) async {
    final problema = problemaConLink(url);
    if (problema != null) throw SheetsException(problema);

    try {
      // Apps Script responde a los POST con una redirección (302) a otra
      // dirección donde queda la respuesta. Los datos ya se guardaron con el
      // POST; el GET posterior solo sirve para leer el resultado.
      final req = http.Request('POST', Uri.parse(url.trim()))
        ..headers['Content-Type'] = 'text/plain; charset=utf-8'
        ..body = jsonEncode(datos)
        ..followRedirects = false;
      var resp = await http.Response.fromStream(
        await _client.send(req).timeout(_espera),
      );
      if (resp.isRedirect || resp.statusCode == 302 || resp.statusCode == 303) {
        final destino = resp.headers['location'];
        if (destino == null) {
          throw SheetsException('La planilla no respondió bien.');
        }
        resp = await _client.get(Uri.parse(destino)).timeout(_espera);
      }
      if (resp.statusCode != 200) {
        throw SheetsException(
          'La planilla respondió con error ${resp.statusCode}. Revisá que '
          'la implementación diga "Cualquier usuario".',
        );
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(resp.body) as Map<String, dynamic>;
      } on FormatException {
        // Google devuelve una página web (no JSON) cuando la implementación
        // no es pública o el link no es el de la aplicación web.
        throw SheetsException(
          'La planilla no respondió como se esperaba. Revisá que la '
          'implementación sea "Aplicación web" con acceso "Cualquier usuario".',
        );
      }
      if (json['ok'] != true) {
        final error = json['error'];
        throw SheetsException(
          error == 'clave incorrecta'
              ? 'La clave no coincide con la propiedad TOKEN del script.'
              : 'La planilla rechazó el dato: $error',
        );
      }
      return json;
    } on TimeoutException {
      throw SheetsException('La planilla tardó demasiado. Probá de nuevo.');
    } on http.ClientException {
      throw SheetsException('Sin conexión con la planilla. Revisá internet.');
    }
  }
}
