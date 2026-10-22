import 'dart:convert';

// JavaScript que la app ejecuta dentro de la página del estimador.
//
// La página está hecha con AngularJS, así que no alcanza con cambiar el
// valor de un campo: hay que disparar los eventos "input" y "change" para que
// Angular se entere. Los campos se buscan por su texto (placeholder y
// opciones), no por ids internos, para que sobreviva a cambios chicos.

const _comunes = r'''
function norm(s) {
  return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toUpperCase().replace(/\s+/g, ' ').trim();
}
function selectConOpcion(re) {
  var sels = document.querySelectorAll('select');
  for (var i = 0; i < sels.length; i++) {
    for (var j = 0; j < sels[i].options.length; j++) {
      if (re.test(norm(sels[i].options[j].text))) return sels[i];
    }
  }
  return null;
}
function elegir(sel, buscados) {
  var ops = sel.options;
  for (var k = 0; k < buscados.length; k++) {
    var b = norm(buscados[k]);
    for (var j = 0; j < ops.length; j++) {
      if (norm(ops[j].text) === b) { return poner(sel, ops[j].value); }
    }
  }
  for (var k = 0; k < buscados.length; k++) {
    var b = norm(buscados[k]);
    for (var j = 0; j < ops.length; j++) {
      if (norm(ops[j].text).indexOf(b) >= 0) { return poner(sel, ops[j].value); }
    }
  }
  return false;
}
function poner(el, valor) {
  var proto = el.tagName === 'SELECT' ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
  Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, valor);
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  return true;
}
function inputPorTexto(re) {
  var ins = document.querySelectorAll('input');
  for (var i = 0; i < ins.length; i++) {
    if (re.test(norm(ins[i].placeholder)) || re.test(norm(ins[i].name))) return ins[i];
  }
  return null;
}
''';

/// Completa el formulario. Se llama varias veces hasta que devuelve "listo"
/// o "sin-provincia", porque los campos de la transferencia aparecen recién
/// después de elegir el tipo de trámite.
String jsCompletarFormulario({
  required String tramite,
  required String dominio,
  required String valorDeclarado,
  required List<String> provincias,
}) {
  final args = jsonEncode({
    'tramite': tramite,
    'dominio': dominio,
    'valor': valorDeclarado,
    'provincias': provincias,
  });
  return '''
(function() {
$_comunes
var a = $args;
var selTramite = selectConOpcion(/TRANSFERENCIA/);
if (!selTramite) return 'esperando';
var actual = selTramite.options[selTramite.selectedIndex];
if (!actual || norm(actual.text).indexOf(norm(a.tramite)) < 0) {
  elegir(selTramite, [a.tramite]);
  return 'esperando';
}
var patente = inputPorTexto(/PATENTE|DOMINIO/);
var valor = inputPorTexto(/VALOR/);
var selProv = selectConOpcion(/CORDOBA|MENDOZA|SANTA FE/);
if (!patente || !valor || !selProv) return 'esperando';
poner(patente, a.dominio);
poner(valor, a.valor);
if (!elegir(selProv, a.provincias)) return 'sin-provincia';
var boton = Array.prototype.find.call(document.querySelectorAll('button, a, input[type=submit]'),
  function(b) { return /CONTINUAR/.test(norm(b.innerText || b.value)); });
if (boton) boton.scrollIntoView({ block: 'center' });
return 'listo';
})()
''';
}

/// Devuelve un JSON con las tablas y los textos de la página, o "" si
/// todavía no apareció el resultado.
const jsLeerResultado = '''
(function() {
$_comunes
var texto = norm(document.body.innerText);
if (texto.indexOf('VALOR TABLA') < 0 || texto.indexOf('MARCA') < 0) return '';
function txt(e) { return (e.innerText || e.textContent || '').replace(/\\s+/g, ' ').trim(); }
var tablas = Array.prototype.map.call(document.querySelectorAll('table'), function(t) {
  return Array.prototype.map.call(t.rows, function(r) {
    return Array.prototype.map.call(r.cells, txt);
  });
});
var hojas = [];
Array.prototype.forEach.call(document.body.querySelectorAll('*'), function(e) {
  if (e.children.length === 0 && !/^(SCRIPT|STYLE)\$/.test(e.tagName)) {
    var t = txt(e);
    if (t) hojas.push(t);
  }
});
return JSON.stringify({ tablas: tablas, hojas: hojas });
})()
''';

/// Detecta si la página mostró un mensaje de error (por ejemplo, dominio
/// inexistente). Devuelve el texto del mensaje o "".
const jsLeerError = r'''
(function() {
var el = document.querySelector('.alert-danger, .text-danger, .has-error .help-block');
return el ? (el.innerText || '').trim() : '';
})()
''';
