import 'package:consulta_dominio/resultado.dart';
import 'package:flutter_test/flutter_test.dart';

// Datos tomados de una consulta real al estimador (dominio de ejemplo).
const _resumen = [
  ['Trámite', 'TRANSFERENCIA DE AUTOMOTOR IMPORTADO'],
  ['Valor Declarado', r'$10.000,00', 'Provincia Radicación', 'BUENOS AIRES'],
  ['Marca', 'VOLKSWAGEN', 'Modelo', 'VOLKSWAGEN VENTO 2.0 TDI'],
  ['Tipo', 'RURAL 5 PTAS', 'Año / Origen', '2011 / IMPORTADO'],
  ['Valor Tabla', r'$11.702.900,00'],
];

const _presupuesto = [
  ['Item', 'Descripción', 'Precio', 'Cantidad', 'Total'],
  ['1', 'TRANSFERENCIA IMPORTADO', r'$117.023,00', '1', r'$117.023,00'],
  ['2', '8A ADICIONALES-CERTIFICACIÓN FIRMAS', r'$3.080,00', '1', r'$3.080,00'],
  ['5', 'BONIFICACION SEGUN RESOL. VIG. EXP. TÍTULO', r'-$4.110,00', '1', r'-$4.110,00'],
  ['', '', '', '', r'$120.103,00'],
];

void main() {
  group('parsearPesos', () {
    test('entiende el formato argentino', () {
      expect(parsearPesos(r'$11.702.900,00'), 11702900);
      expect(parsearPesos(r'-$4.110,00'), -4110);
      expect(parsearPesos('sin número'), isNull);
    });
  });

  group('interpretarResultado', () {
    test('lee todos los campos de las tablas', () {
      final r = interpretarResultado(
        const DatosPagina(tablas: [_resumen, _presupuesto], hojas: []),
        'AB123CD',
      )!;
      expect(r.dominio, 'AB123CD');
      expect(r.tipoVehiculo, 'Auto');
      expect(r.marca, 'VOLKSWAGEN');
      expect(r.modelo, 'VOLKSWAGEN VENTO 2.0 TDI');
      expect(r.tipo, 'RURAL 5 PTAS');
      expect(r.anio, 2011);
      expect(r.origen, 'IMPORTADO');
      expect(r.valorTabla, 11702900);
      expect(r.provincia, 'BUENOS AIRES');
      expect(r.arancelTotal, 120103);
    });

    test('si el resumen no es una tabla, usa los textos sueltos', () {
      final hojas = ['RESUMEN DE LA SOLICITUD', ..._resumen.expand((f) => f)];
      final r = interpretarResultado(
        DatosPagina(tablas: const [_presupuesto], hojas: hojas),
        'AB123CD',
      )!;
      expect(r.marca, 'VOLKSWAGEN');
      expect(r.anio, 2011);
      expect(r.arancelTotal, 120103);
    });

    test('detecta motos', () {
      final r = interpretarResultado(
        const DatosPagina(
          tablas: [
            [
              ['Trámite', 'TRANSFERENCIA DE MOTOVEHICULO NACIONAL'],
              ['Marca', 'HONDA', 'Modelo', 'WAVE 110'],
            ],
          ],
          hojas: [],
        ),
        'A123BCD',
      )!;
      expect(r.tipoVehiculo, 'Moto');
    });

    test('devuelve null si no encuentra marca y modelo', () {
      expect(
        interpretarResultado(
          const DatosPagina(tablas: [], hojas: ['Error']),
          'AB123CD',
        ),
        isNull,
      );
    });
  });
}
