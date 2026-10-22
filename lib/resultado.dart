/// Datos del vehículo que devuelve el estimador de costos de la DNRPA.
class ResultadoEstimador {
  const ResultadoEstimador({
    required this.dominio,
    required this.tramite,
    required this.tipoVehiculo,
    required this.marca,
    required this.modelo,
    required this.tipo,
    required this.anio,
    required this.origen,
    required this.valorTabla,
    required this.provincia,
    this.arancelTotal,
  });

  final String dominio;
  final String tramite;

  /// "Auto" o "Moto", deducido del texto del trámite.
  final String tipoVehiculo;
  final String marca;
  final String modelo;
  final String tipo;
  final int? anio;
  final String origen;
  final double? valorTabla;
  final String provincia;
  final double? arancelTotal;

  Map<String, Object?> toJson() => {
    'dominio': dominio,
    'tramite': tramite,
    'tipoVehiculo': tipoVehiculo,
    'marca': marca,
    'modelo': modelo,
    'tipo': tipo,
    'anio': anio,
    'origen': origen,
    'valorTabla': valorTabla,
    'provincia': provincia,
    'arancelTotal': arancelTotal,
  };
}

/// Lo que junta el JavaScript de la página de resultado: las celdas de cada
/// tabla y, por si el resumen no está armado como tabla, los textos de todos
/// los elementos "hoja" en orden.
class DatosPagina {
  const DatosPagina({required this.tablas, required this.hojas});

  factory DatosPagina.fromJson(Map<String, dynamic> json) => DatosPagina(
    tablas: [
      for (final t in (json['tablas'] as List? ?? const []))
        [
          for (final fila in (t as List))
            [for (final c in (fila as List)) c.toString()],
        ],
    ],
    hojas: [for (final h in (json['hojas'] as List? ?? const [])) h.toString()],
  );

  final List<List<List<String>>> tablas;
  final List<String> hojas;
}

/// Saca acentos, pasa a minúsculas y junta espacios, para comparar etiquetas.
String normalizarEtiqueta(String s) {
  const conAcento = 'áéíóúüñ';
  const sinAcento = 'aeiouun';
  var r = s.toLowerCase().trim();
  for (var i = 0; i < conAcento.length; i++) {
    r = r.replaceAll(conAcento[i], sinAcento[i]);
  }
  return r
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*/\s*'), ' / ')
      .replaceAll(RegExp(r'\s*:$'), '');
}

/// Convierte "$11.702.900,00" en 11702900.0. Devuelve null si no hay número.
double? parsearPesos(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio.replaceAll('.', '').replaceAll(',', '.'));
}

const _etiquetas = {
  'tramite': 'tramite',
  'provincia radicacion': 'provincia',
  'marca': 'marca',
  'modelo': 'modelo',
  'tipo': 'tipo',
  'ano / origen': 'anioOrigen',
  'valor tabla': 'valorTabla',
};

/// Arma pares etiqueta → valor mirando la celda que sigue a cada etiqueta.
Map<String, String> _pares(List<String> celdas) {
  final r = <String, String>{};
  for (var i = 0; i + 1 < celdas.length; i++) {
    final clave = _etiquetas[normalizarEtiqueta(celdas[i])];
    if (clave != null && !r.containsKey(clave)) {
      final valor = celdas[i + 1].trim();
      if (_etiquetas.containsKey(normalizarEtiqueta(valor))) continue;
      r[clave] = valor;
    }
  }
  return r;
}

/// El total del presupuesto: el último importe de la tabla que tiene
/// columnas "Descripción" y "Total".
double? _arancelTotal(List<List<List<String>>> tablas) {
  for (final tabla in tablas) {
    final encabezados = tabla.expand((f) => f).map(normalizarEtiqueta).toSet();
    if (!encabezados.contains('descripcion') ||
        !encabezados.contains('total')) {
      continue;
    }
    for (final fila in tabla.reversed) {
      for (final celda in fila.reversed) {
        if (celda.contains(r'$')) return parsearPesos(celda);
      }
    }
  }
  return null;
}

/// Interpreta la página de resultado del estimador. Devuelve null si no
/// encuentra al menos marca y modelo (por ejemplo, si la DNRPA cambió la
/// página o el dominio no existe), para no guardar datos incompletos.
ResultadoEstimador? interpretarResultado(DatosPagina datos, String dominio) {
  var p = _pares(datos.tablas.expand((t) => t.expand((f) => f)).toList());
  if (!p.containsKey('marca') || !p.containsKey('modelo')) {
    p = _pares(datos.hojas);
  }
  final marca = p['marca'];
  final modelo = p['modelo'];
  if (marca == null || marca.isEmpty || modelo == null || modelo.isEmpty) {
    return null;
  }

  final anioOrigen = (p['anioOrigen'] ?? '').split('/');
  final anio = int.tryParse(anioOrigen.first.trim());
  final origen = anioOrigen.length > 1
      ? anioOrigen.sublist(1).join('/').trim()
      : '';

  final tramite = p['tramite'] ?? '';
  final t = normalizarEtiqueta(tramite);
  // "automotor" también contiene "moto": se busca al principio de palabra.
  final tipoVehiculo = RegExp(r'\bmoto').hasMatch(t)
      ? 'Moto'
      : t.contains('automotor')
      ? 'Auto'
      : '';

  return ResultadoEstimador(
    dominio: dominio,
    tramite: tramite,
    tipoVehiculo: tipoVehiculo,
    marca: marca,
    modelo: modelo,
    tipo: p['tipo'] ?? '',
    anio: anio,
    origen: origen,
    valorTabla: parsearPesos(p['valorTabla'] ?? ''),
    provincia: p['provincia'] ?? '',
    arancelTotal: _arancelTotal(datos.tablas),
  );
}
