import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../estimador_js.dart';
import '../resultado.dart';

/// Abre el estimador de la DNRPA dentro de la app, lo completa solo y espera
/// a que el usuario toque "Continuar". Cuando aparece el resultado, lo lee y
/// vuelve con un [ResultadoEstimador].
class EstimadorPage extends StatefulWidget {
  const EstimadorPage({
    required this.dominio,
    required this.provincia,
    super.key,
  });

  final String dominio;
  final String provincia;

  @override
  State<EstimadorPage> createState() => _EstimadorPageState();
}

enum _Paso { cargando, completando, esperandoContinuar, leyendo }

class _EstimadorPageState extends State<EstimadorPage> {
  static const _intervalo = Duration(milliseconds: 600);
  static const _maxIntentosFormulario = 50; // ~30 segundos

  late final WebViewController _web;
  Timer? _timer;
  _Paso _paso = _Paso.cargando;
  int _intentos = 0;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _empezarACompletar()),
      )
      ..loadRequest(Uri.parse(Config.estimadorUrl));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// En el estimador, Ciudad de Buenos Aires puede figurar con otro nombre.
  List<String> get _nombresProvincia => switch (widget.provincia) {
    'CIUDAD AUTONOMA DE BUENOS AIRES' => [
      'CIUDAD AUTONOMA DE BUENOS AIRES',
      'CAPITAL FEDERAL',
      'CABA',
      'C.A.B.A.',
    ],
    'TIERRA DEL FUEGO' => [
      'TIERRA DEL FUEGO',
      'TIERRA DEL FUEGO, ANTARTIDA E ISLAS DEL ATLANTICO SUR',
    ],
    final p => [p],
  };

  void _empezarACompletar() {
    if (_paso != _Paso.cargando) return;
    setState(() => _paso = _Paso.completando);
    _timer = Timer.periodic(_intervalo, (_) => _tic());
  }

  Future<void> _tic() async {
    try {
      switch (_paso) {
        case _Paso.completando:
          await _completar();
        case _Paso.esperandoContinuar:
          await _buscarResultado();
        case _Paso.cargando:
        case _Paso.leyendo:
          break;
      }
    } on Exception {
      // La página puede estar navegando; se reintenta en el próximo tic.
    }
  }

  Future<void> _completar() async {
    final estado = await _ejecutar(
      jsCompletarFormulario(
        tramite: Config.tipoTramite,
        dominio: widget.dominio,
        valorDeclarado: Config.valorDeclarado,
        provincias: _nombresProvincia,
      ),
    );
    if (!mounted) return;
    if (estado == 'listo' || estado == 'sin-provincia') {
      setState(() {
        _paso = _Paso.esperandoContinuar;
        _aviso = estado == 'sin-provincia'
            ? 'No encontré "${widget.provincia}" en la lista. Elegila a mano.'
            : null;
      });
    } else if (++_intentos > _maxIntentosFormulario) {
      setState(() {
        _paso = _Paso.esperandoContinuar;
        _aviso = 'No pude completar el formulario solo. Completalo a mano.';
      });
    }
  }

  Future<void> _buscarResultado() async {
    final json = await _ejecutar(jsLeerResultado);
    if (json.isEmpty || !mounted) return;
    setState(() => _paso = _Paso.leyendo);
    _timer?.cancel();

    final datos = DatosPagina.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    final resultado = interpretarResultado(datos, widget.dominio);
    if (!mounted) return;
    if (resultado == null) {
      setState(() {
        _paso = _Paso.esperandoContinuar;
        _aviso =
            'No pude leer los datos del resultado. '
            'Puede que la DNRPA haya cambiado la página.';
      });
      return;
    }
    Navigator.of(context).pop(resultado);
  }

  /// Ejecuta JavaScript y devuelve el resultado como texto. En Android el
  /// resultado llega como un string JSON (con comillas); en iOS, tal cual.
  Future<String> _ejecutar(String js) async {
    final r = await _web.runJavaScriptReturningResult(js);
    if (r is String && r.length >= 2 && r.startsWith('"') && r.endsWith('"')) {
      return jsonDecode(r) as String;
    }
    return r.toString();
  }

  String get _instruccion => switch (_paso) {
    _Paso.cargando => 'Abriendo el estimador de la DNRPA...',
    _Paso.completando => 'Completando ${widget.dominio}...',
    _Paso.esperandoContinuar => _aviso ?? 'Revisá los datos y tocá CONTINUAR.',
    _Paso.leyendo => 'Leyendo el resultado...',
  };

  @override
  Widget build(BuildContext context) {
    final esperando = _paso == _Paso.esperandoContinuar;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.dominio)),
      body: Column(
        children: [
          Material(
            color: esperando && _aviso == null
                ? scheme.primaryContainer
                : _aviso != null
                ? scheme.errorContainer
                : scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (!esperando)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(child: Text(_instruccion)),
                ],
              ),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _web)),
        ],
      ),
    );
  }
}
