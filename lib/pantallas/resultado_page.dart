import 'package:flutter/material.dart';

import '../ajustes.dart';
import '../resultado.dart';
import '../sheets.dart';

/// Muestra los datos del vehículo y los guarda en la planilla.
class ResultadoPage extends StatefulWidget {
  const ResultadoPage({
    required this.resultado,
    SheetsClient? sheets,
    super.key,
  }) : _sheets = sheets;

  final ResultadoEstimador resultado;
  final SheetsClient? _sheets;

  @override
  State<ResultadoPage> createState() => _ResultadoPageState();
}

class _ResultadoPageState extends State<ResultadoPage> {
  late final SheetsClient _sheets = widget._sheets ?? SheetsClient();
  bool? _configurado;
  bool _guardando = false;
  int? _indice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _guardar();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final ajustes = await Ajustes.cargar();
      if (!mounted) return;
      setState(() => _configurado = ajustes.planillaConfigurada);
      if (!ajustes.planillaConfigurada) return;
      final indice = await _sheets.guardar(widget.resultado, ajustes);
      if (mounted) setState(() => _indice = indice);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final filas = <(String, String)>[
      ('Auto/Moto', r.tipoVehiculo),
      ('Marca', r.marca),
      ('Modelo', r.modelo),
      ('Tipo', r.tipo),
      ('Año', r.anio?.toString() ?? ''),
      ('Origen', r.origen),
      ('Valor tabla', formatearPesos(r.valorTabla)),
      ('Arancel total', formatearPesos(r.arancelTotal)),
      ('Provincia', r.provincia),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(r.dominio)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                for (final (etiqueta, valor) in filas)
                  ListTile(
                    dense: true,
                    title: Text(etiqueta),
                    trailing: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.55,
                      ),
                      child: Text(
                        valor.isEmpty ? '-' : valor,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _estadoPlanilla(context),
        ],
      ),
    );
  }

  Widget _estadoPlanilla(BuildContext context) {
    if (_configurado == false) {
      return const Text(
        'No se guardó: falta conectar la planilla (ícono de ajustes en la '
        'pantalla inicial).',
      );
    }
    if (_guardando) {
      return const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Guardando en la planilla...'),
      );
    }
    if (_indice != null) {
      return ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text('Guardado en la planilla con el número $_indice.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _error ?? 'No se guardó en la planilla.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

/// 11702900.0 → "$ 11.702.900"
String formatearPesos(double? valor) {
  if (valor == null) return '';
  final entero = valor.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) b.write('.');
    b.write(entero[i]);
  }
  return '\$ $b';
}
