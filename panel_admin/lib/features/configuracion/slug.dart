/// Slug del restaurante — el identificador ESTRUCTURAL de todo el sistema.
///
/// ⚠️ RESTRICCIÓN DURA, NO NEGOCIABLE (decisión bloqueada del usuario,
/// `11-CONTEXT.md` → "Bootstrap del restaurante").
///
/// El doc ID del restaurante (`restaurantes/{slug}`) es el `rid`, y el doc ID
/// de CADA MESA deriva de él: `GRI-MESA-{rid}-{NNN}`
/// (`features/mesas/mesas_crud.dart:10`). Ese doc ID **es** el contenido del
/// código QR impreso y pegado en la mesa. El escáner de la app cliente lo
/// valida con:
///
///     RegExp(r'^GRI-MESA-[a-z0-9-]+-\d{3}$')
///     // app_cliente/lib/features/sesion_qr/scan_screen.dart:41
///
/// Consecuencia de tocar esto a la ligera: un rid con mayúsculas, tildes, ñ o
/// espacios genera mesas cuyo QR **jamás** pasa el escáner. El fallo no
/// aparece al crear el restaurante ni al crear la mesa: aparece semanas
/// después, con los QR ya impresos y pegados, cuando el primer cliente intenta
/// escanear y el móvil dice "código inválido". Silencioso y tardío — el peor
/// tipo.
///
/// Quien modifique `generarSlug` o `slugEsValido` debe correr
/// `test/configuracion/slug_test.dart`, cuyo grupo "puente con el escáner del
/// cliente" compone `GRI-MESA-{slug}-001` y lo evalúa contra esa misma regexp.
library;

/// Mapa de plegado de acentos. El dominio es español (Colombia): tildes, ñ,
/// diéresis y la ç del catalán/portugués aparecen en nombres reales de
/// restaurante. Se resuelve con una tabla explícita en vez de con
/// normalización Unicode (NFD) porque Dart no trae `unorm` en el core y una
/// tabla de 25 entradas es más legible y más barata que la dependencia.
const _acentos = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Forma canónica exigida: segmentos alfanuméricos en minúscula unidos por un
/// ÚNICO guion, sin guion inicial ni final.
final _slugValido = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Deriva un slug a partir del nombre del restaurante.
///
/// `'Pizzería Doña Ana'` → `'pizzeria-dona-ana'`.
///
/// Devuelve **cadena vacía** cuando el nombre no aporta ni una letra ni un
/// dígito (p. ej. `'★★★'`). En ese caso el formulario debe pedir un
/// identificador escrito a mano: es preferible eso a inventar un id opaco que
/// el operador no reconocería después en los QR de sus mesas.
String generarSlug(String nombre) {
  var s = nombre.toLowerCase().trim();
  _acentos.forEach((k, v) => s = s.replaceAll(k, v));
  s = s
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return s;
}

/// ¿Es `s` un identificador de restaurante aceptable?
///
/// Es el ÚNICO gate antes de escribir `restaurantes/{s}`: el usuario puede
/// editar a mano el campo del diálogo, así que no basta con que `generarSlug`
/// produzca algo correcto.
///
/// Tope de 40 caracteres: el doc ID de mesa añade `GRI-MESA-` + `-NNN`
/// (13 caracteres), y mantener el identificador legible importa porque acaba
/// impreso en un QR que un humano puede tener que teclear a mano (la pantalla
/// de escaneo acepta entrada manual).
bool slugEsValido(String s) =>
    s.isNotEmpty && s.length <= 40 && _slugValido.hasMatch(s);
