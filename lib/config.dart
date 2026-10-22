/// Configuración de la app. La URL y la clave de la planilla se pasan al
/// compilar, para no dejarlas escritas en el código:
///
///   flutter run --dart-define=SHEETS_URL=https://script.google.com/... \
///               --dart-define=SHEETS_TOKEN=mi-clave
class Config {
  static const estimadorUrl =
      'https://www2.jus.gov.ar/dnrpa-site/#!/estimador';

  /// Valor declarado fijo. El arancel se calcula sobre el mayor entre este
  /// valor y el de tabla, así que con un valor bajo siempre aparece el de tabla.
  static const valorDeclarado = '1000';

  static const tipoTramite = 'TRANSFERENCIA';

  static const provinciaPorDefecto = 'BUENOS AIRES';

  static const sheetsUrl = String.fromEnvironment('SHEETS_URL');
  static const sheetsToken = String.fromEnvironment('SHEETS_TOKEN');
}
