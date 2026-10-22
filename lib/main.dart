import 'package:flutter/material.dart';

import 'pantallas/consulta_page.dart';

void main() => runApp(const ConsultaDominioApp());

class ConsultaDominioApp extends StatelessWidget {
  const ConsultaDominioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta por dominio',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F4E79)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F4E79),
        brightness: Brightness.dark,
      ),
      home: const ConsultaPage(),
    );
  }
}
