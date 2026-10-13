# core/text/fisica.gd — línea de DESCRIPCIÓN FÍSICA de un documento (GDD_v2 §C.5). Dueño: DESPEJE-UI.
# Reemplaza la lupa y la regla del lector: TODO documento (estático o generado en el juego) lleva al principio una línea
# con el mismo formato y en la misma posición, recortable como cualquier texto (tramo #fisica). No marca pistas: sale de
# tablas cerradas (data/fisica.json: papeles, medios, estado breve) y está en todos los papeles por igual.
# Formato fijo (un tramo, una oración, ≤40 palabras):
#   <f=ui><i><ink=tenue>{{#fisica TAGS e:<ent del papel>|[[<ent del papel>|<Papel>]], <W> × <H> cm; <medio 1>[ y <medio 2>]; <estado>.}}</ink></i></f>
#   (tinta tenue: se separa del texto del documento sin dejar de ser recortable; playtest v2)
# API (firma publicada para PROGRESIÓN, que pone los ganchos en DataRepo y Effects):
#   line(spec, mm, fis) -> String     marcado de la línea (spec = fis.docs[id] o fis.plantillas[entity]; mm = [w, h] en mm
#                                    o [] para omitir la medida; spec.mm, si está, manda sobre mm)
#   tags(spec) -> Array               etiquetas ocultas del tramo (["a:vinculo_mycroft"]); sólo D46 y la Remington
#   ents(spec, fis) -> Array          entidades del tramo (la del papel)
#   spec_doc(fis, doc_id) / spec_tpl(fis, entity) -> Dictionary ({} si no hay)
#   doc_line(fis, doc) -> String      atajo: spec del documento + su paper_mm ("" si el documento no tiene descripción)
#   prepend(text, line) -> String     line + "\n" + text (lo que hace el gancho)
#   load_fis(path) -> Dictionary      lee data/fisica.json (para tests y herramientas; el juego usa el del DataRepo)
#   cm(mm) -> String                  «20 × 24 cm» (redondeo a centímetros enteros)
extends RefCounted

const Markup = preload("res://core/text/markup.gd")

const TRAMO_ID := "fisica"
const PATH := "res://data/fisica.json"

static func spec_doc(fis: Dictionary, doc_id: String) -> Dictionary:
	var d = fis.get("docs", {}).get(doc_id, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func spec_tpl(fis: Dictionary, entity: String) -> Dictionary:
	var d = fis.get("plantillas", {}).get(entity, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func cm(mm: Array) -> String:
	if mm.size() != 2:
		return ""
	return "%d × %d cm" % [int(round(float(mm[0]) / 10.0)), int(round(float(mm[1]) / 10.0))]

static func tags(spec: Dictionary) -> Array:
	var out: Array = []
	for t in spec.get("tags", []):
		var s := String(t)
		if s != "" and not out.has(s):
			out.append(s)
	return out

static func ents(spec: Dictionary, fis: Dictionary) -> Array:
	var p = fis.get("papeles", {}).get(String(spec.get("papel", "")), {})
	if typeof(p) != TYPE_DICTIONARY or String(p.get("ent", "")) == "":
		return []
	return [String(p.ent)]

static func line(spec: Dictionary, mm: Array, fis: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var p = fis.get("papeles", {}).get(String(spec.get("papel", "")), {})
	if typeof(p) != TYPE_DICTIONARY or p.is_empty():
		return ""
	var ent := String(p.get("ent", ""))
	var paper := Markup.escape(String(p.get("txt", "")))
	var size := mm
	if typeof(spec.get("mm")) == TYPE_ARRAY and (spec.mm as Array).size() == 2:
		size = spec.mm
	var segs: Array = []
	var head := "[[%s|%s]]" % [ent, paper] if ent != "" else paper
	var c := cm(size)
	segs.append(head + (", " + c if c != "" else ""))
	var med: Array = []
	for m in spec.get("medio", []):
		var t := String(fis.get("medios", {}).get(String(m), ""))
		if t != "":
			med.append(Markup.escape(t))
	if not med.is_empty():
		segs.append(" y ".join(med))
	var est := Markup.escape(String(spec.get("estado", "")).strip_edges().trim_suffix("."))
	if est != "":
		segs.append(est)
	var hdr := ["#" + TRAMO_ID]
	hdr.append_array(tags(spec))
	if ent != "":
		hdr.append("e:" + ent)
	return "<f=ui><i><ink=tenue>{{%s|%s.}}</ink></i></f>" % [" ".join(hdr), "; ".join(segs)]

static func doc_line(fis: Dictionary, doc: Dictionary) -> String:
	var spec := spec_doc(fis, String(doc.get("id", "")))
	if spec.is_empty():
		return ""
	var mm = doc.get("paper_mm", [])
	return line(spec, mm if typeof(mm) == TYPE_ARRAY else [], fis)

static func prepend(text: String, ln: String) -> String:
	if ln == "":
		return text
	return ln + "\n" + text

static func load_fis(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}
