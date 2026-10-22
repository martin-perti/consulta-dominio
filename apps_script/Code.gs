/**
 * Recibe las consultas de la app y las agrega a la hoja "Consultas".
 *
 * Instalación: ver README.md, sección "Planilla de Google".
 * La clave se guarda en Configuración del proyecto > Propiedades del script,
 * con el nombre TOKEN (la misma que se pasa a la app como SHEETS_TOKEN).
 */

var HOJA = 'Consultas';
var ENCABEZADOS = [
  '#', 'Fecha y hora', 'Dominio', 'Auto/Moto', 'Marca', 'Modelo', 'Tipo',
  'Año', 'Origen', 'Valor tabla', 'Arancel total', 'Provincia', 'Trámite',
  'Usuario',
];

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var datos = JSON.parse(e.postData.contents);
    var token = PropertiesService.getScriptProperties().getProperty('TOKEN');
    if (!token || datos.token !== token) {
      return responder({ ok: false, error: 'clave incorrecta' });
    }
    if (datos.prueba) {
      return responder({ ok: true, mensaje: 'Planilla conectada' });
    }
    if (!datos.dominio || !datos.marca) {
      return responder({ ok: false, error: 'faltan datos' });
    }

    // El lock evita que dos consultas al mismo tiempo tomen el mismo número.
    lock.waitLock(10000);
    var hoja = obtenerHoja();
    var indice = siguienteIndice(hoja);
    hoja.appendRow([
      indice,
      new Date(),
      String(datos.dominio).toUpperCase(),
      datos.tipoVehiculo || '',
      datos.marca || '',
      datos.modelo || '',
      datos.tipo || '',
      datos.anio || '',
      datos.origen || '',
      datos.valorTabla || '',
      datos.arancelTotal || '',
      datos.provincia || '',
      datos.tramite || '',
      datos.usuario || '',
    ]);
    return responder({ ok: true, indice: indice });
  } catch (err) {
    return responder({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

/** Abrir el link en el navegador muestra si el script está publicado. */
function doGet() {
  return responder({ ok: true, mensaje: 'El script está publicado. Usá este link en la app.' });
}

/**
 * Número correlativo que no se repite aunque se borren filas: se guarda el
 * último usado en las propiedades del script. Se llama con el lock tomado.
 */
function siguienteIndice(hoja) {
  var props = PropertiesService.getScriptProperties();
  var ultimo = Number(props.getProperty('ULTIMO_INDICE'));
  if (!ultimo) {
    ultimo = Math.max(hoja.getLastRow() - 1, 0); // la fila 1 es el encabezado
  }
  var indice = ultimo + 1;
  props.setProperty('ULTIMO_INDICE', String(indice));
  return indice;
}

function obtenerHoja() {
  var libro = SpreadsheetApp.getActiveSpreadsheet();
  var hoja = libro.getSheetByName(HOJA);
  if (!hoja) {
    hoja = libro.insertSheet(HOJA);
  }
  if (hoja.getLastRow() === 0) {
    hoja.appendRow(ENCABEZADOS);
    hoja.setFrozenRows(1);
    hoja.getRange(1, 1, 1, ENCABEZADOS.length).setFontWeight('bold');
    hoja.getRange('B:B').setNumberFormat('dd/mm/yyyy hh:mm');
    hoja.getRange('J:K').setNumberFormat('$ #,##0');
  }
  return hoja;
}

function responder(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
