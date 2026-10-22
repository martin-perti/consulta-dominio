import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Datos que el usuario carga en la app: su nombre y la conexión con la
/// planilla. Si no cargó la planilla, se usan los valores de compilación
/// (SHEETS_URL y SHEETS_TOKEN), si los hay.
class Ajustes {
  const Ajustes({
    required this.usuario,
    required this.sheetsUrl,
    required this.sheetsToken,
  });

  final String usuario;
  final String sheetsUrl;
  final String sheetsToken;

  bool get planillaConfigurada => sheetsUrl.isNotEmpty;

  static Future<Ajustes> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    String leer(String clave, String porDefecto) {
      final v = prefs.getString(clave) ?? '';
      return v.isEmpty ? porDefecto : v;
    }

    return Ajustes(
      usuario: prefs.getString('usuario') ?? '',
      sheetsUrl: leer('sheetsUrl', Config.sheetsUrl),
      sheetsToken: leer('sheetsToken', Config.sheetsToken),
    );
  }

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuario', usuario);
    await prefs.setString('sheetsUrl', sheetsUrl);
    await prefs.setString('sheetsToken', sheetsToken);
  }
}
