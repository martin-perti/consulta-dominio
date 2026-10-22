import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../ajustes.dart';
import '../config.dart';
import '../dominio.dart';
import '../provincias.dart';
import '../resultado.dart';
import 'estimador_page.dart';
import 'resultado_page.dart';

class ConsultaPage extends StatefulWidget {
  const ConsultaPage({super.key});

  @override
  State<ConsultaPage> createState() => _ConsultaPageState();
}

class _ConsultaPageState extends State<ConsultaPage> {
  final _dominio = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _provincia = Config.provinciaPorDefecto;
  bool _leyendoFoto = false;

  @override
  void dispose() {
    _dominio.dispose();
    super.dispose();
  }

  Future<void> _sacarFoto() async {
    final foto = await ImagePicker().pickImage(source: ImageSource.camera);
    if (foto == null) return;
    setState(() => _leyendoFoto = true);
    final lector = TextRecognizer();
    try {
      final texto = await lector.processImage(
        InputImage.fromFilePath(foto.path),
      );
      final dominio = buscarDominioEnTexto(texto.text);
      if (!mounted) return;
      if (dominio == null) {
        _avisar(
          'No encontré una patente en la foto. Probá de más cerca o escribila.',
        );
      } else {
        _dominio.text = dominio;
        _avisar('Leí $dominio. Revisala antes de verificar.');
      }
    } finally {
      await lector.close();
      if (mounted) setState(() => _leyendoFoto = false);
    }
  }

  Future<void> _verificar() async {
    if (!_formKey.currentState!.validate()) return;
    final dominio = normalizarDominio(_dominio.text);
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute<ResultadoEstimador>(
        builder: (_) => EstimadorPage(dominio: dominio, provincia: _provincia),
      ),
    );
    if (resultado == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultadoPage(resultado: resultado)),
    );
  }

  Future<void> _abrirAjustes() async {
    final actuales = await Ajustes.cargar();
    if (!mounted) return;
    final nuevos = await showDialog<Ajustes>(
      context: context,
      builder: (_) => _AjustesDialog(actuales: actuales),
    );
    if (nuevos == null) return;
    await nuevos.guardar();
    if (mounted) _avisar('Ajustes guardados.');
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta por dominio'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _abrirAjustes,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _dominio,
              textCapitalization: TextCapitalization.characters,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: 'Dominio',
                hintText: 'AB123CD o ABC123',
                border: const OutlineInputBorder(),
                suffixIcon: _leyendoFoto
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Leer la patente con la cámara',
                        icon: const Icon(Icons.photo_camera_outlined),
                        onPressed: _sacarFoto,
                      ),
              ),
              validator: (v) => esDominioValido(v ?? '')
                  ? null
                  : 'Ingresá un dominio válido (ej. AB123CD, ABC123, A123BCD)',
              onFieldSubmitted: (_) => _verificar(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _provincia,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Provincia de radicación',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in provincias)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (p) => setState(() => _provincia = p ?? _provincia),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _verificar,
              icon: const Icon(Icons.search),
              label: const Text('Verificar datos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AjustesDialog extends StatefulWidget {
  const _AjustesDialog({required this.actuales});

  final Ajustes actuales;

  @override
  State<_AjustesDialog> createState() => _AjustesDialogState();
}

class _AjustesDialogState extends State<_AjustesDialog> {
  late final _usuario = TextEditingController(text: widget.actuales.usuario);
  late final _url = TextEditingController(text: widget.actuales.sheetsUrl);
  late final _token = TextEditingController(text: widget.actuales.sheetsToken);

  @override
  void dispose() {
    _usuario.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usuario,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                helperText: 'Se guarda en la planilla con cada consulta.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link de la planilla',
                hintText: 'https://script.google.com/macros/s/.../exec',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clave de la planilla',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            Ajustes(
              usuario: _usuario.text.trim(),
              sheetsUrl: _url.text.trim(),
              sheetsToken: _token.text.trim(),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
