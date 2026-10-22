# Consulta por dominio

App para Android e iOS: ingresás un dominio (o le sacás una foto a la patente), la app completa el **estimador de costos de la DNRPA** y guarda en una **planilla de Google** la marca, modelo, tipo, año, origen, valor de tabla y arancel, con número correlativo y fecha.

## Instalar en Android

Desde el celular, abrí en **Chrome** (no desde otra app):
https://github.com/martin-perti/consulta-dominio/releases/latest/download/consulta-dominio.apk

Ese link siempre baja la última versión. Para actualizar, bajala e instalala encima: los datos y los ajustes se mantienen.

## Cómo funciona

1. **Consulta**: escribís el dominio o tocás la cámara para leer la patente (el texto se reconoce en el teléfono con ML Kit). Elegís la provincia de radicación (Buenos Aires por defecto).
2. **Verificar datos**: se abre el estimador ([www2.jus.gov.ar/dnrpa-site/#!/estimador](https://www2.jus.gov.ar/dnrpa-site/#!/estimador)) dentro de la app y se completa solo:
   - Tipo de trámite: Transferencia
   - Patente: el dominio ingresado
   - Valor declarado: 1000
   - Provincia de radicación: la elegida
3. **Vos tocás CONTINUAR.** El estimador tiene reCAPTCHA invisible, por eso ese paso lo hace una persona y no un robot.
4. La app lee el "Resumen de la solicitud" y el total del presupuesto, te los muestra y los guarda en la planilla.

Solo se leen y guardan datos del **vehículo**; el estimador no muestra datos del titular.

## Planilla de Google

1. Creá una planilla nueva en Google Sheets.
2. En **Archivo > Configuración**, poné la zona horaria en `(GMT-03:00) Buenos Aires`.
3. **Extensiones > Apps Script**. Borrá lo que haya y pegá el contenido de [`apps_script/Code.gs`](apps_script/Code.gs). Guardá.
4. En el editor de Apps Script: **Configuración del proyecto (engranaje) > Propiedades del script > Agregar propiedad**: nombre `TOKEN`, valor una clave larga que inventes.
5. **Implementar > Nueva implementación > Tipo: Aplicación web**.
   - Ejecutar como: *Yo*
   - Quién tiene acceso: *Cualquier usuario*
   - Implementar y copiar la URL que termina en `/exec`.

6. En la app, tocá el ícono de **ajustes** (arriba a la derecha), pegá el link en "Link de la planilla" y la clave del paso 4 en "Clave de la planilla". Tocá **Probar conexión**: tiene que decir "Planilla conectada". Guardá.

La hoja "Consultas" se crea sola con la primera consulta, con estas columnas:

`# | Fecha y hora | Dominio | Auto/Moto | Marca | Modelo | Tipo | Año | Origen | Valor tabla | Arancel total | Provincia | Trámite | Usuario`

Si consultás el mismo dominio de nuevo se agrega otra fila, así queda el historial de cómo cambia la valuación.

## Correr la app

Necesitás [Flutter](https://docs.flutter.dev/get-started/install) instalado (y Xcode en una Mac para iOS).

La primera vez, generá las carpetas de Android e iOS desde la carpeta del proyecto:

```bash
flutter create --platforms android,ios .
flutter pub get
```

Después agregá estos permisos:

- **iOS** (`ios/Runner/Info.plist`), dentro de `<dict>`:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Para leer la patente con la cámara.</string>
  ```
  y en `ios/Podfile` la línea `platform :ios, '15.5'` (ML Kit lo pide).
- **Android** (`android/app/src/main/AndroidManifest.xml`), antes de `<application`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```

Para correrla con la planilla conectada:

```bash
flutter run \
  --dart-define=SHEETS_URL=https://script.google.com/macros/s/XXXX/exec \
  --dart-define=SHEETS_TOKEN=la-clave-del-paso-4
```

Sin esos datos la app funciona igual, pero no guarda en la planilla.

## Pruebas

```bash
flutter test
```

## Estructura

| Archivo | Qué hace |
|---|---|
| `lib/pantallas/consulta_page.dart` | Pantalla inicial: dominio, cámara, provincia |
| `lib/pantallas/estimador_page.dart` | Abre el estimador, lo completa y espera el resultado |
| `lib/pantallas/resultado_page.dart` | Muestra los datos y los guarda en la planilla |
| `lib/estimador_js.dart` | JavaScript que completa el formulario y lee el resultado |
| `lib/resultado.dart` | Interpreta la página de resultado |
| `lib/dominio.dart` | Valida dominios y los busca en el texto de la foto |
| `lib/sheets.dart` | Envía la consulta a la planilla |
| `lib/config.dart` | Valor declarado, trámite, provincia por defecto |
| `apps_script/Code.gs` | Script de la planilla |

## Si la DNRPA cambia la página

La app busca los campos por su texto (TRANSFERENCIA, PATENTE, VALOR, CONTINUAR) y las etiquetas del resultado (Marca, Modelo, Tipo, Año / Origen, Valor Tabla). Si algo cambia, la app avisa "No pude leer los datos" en lugar de guardar algo incorrecto, y el ajuste se hace en `lib/estimador_js.dart` o `lib/resultado.dart`.

## Firma del instalador

Android solo deja actualizar una app si todas las versiones están firmadas con la misma clave. Por eso el armado usa una clave fija (`firma/debug.keystore`). Como el repositorio es público, esa clave también lo es: alcanza para uso propio, pero para distribuir la app a otras personas conviene una clave privada guardada como secreto `ANDROID_KEYSTORE_BASE64` en Settings > Secrets and variables > Actions (el armado la usa automáticamente si existe).

## Uso responsable

Es para consultas puntuales hechas por una persona. No la uses para recorrer dominios en forma masiva.
