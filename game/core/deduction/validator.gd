# core/deduction/validator.gd — utilidades de validación compartidas (GDD_v3 §1.6). Dueño: CORE-EXPEDIENTE.
# v3: el libro de conclusiones, las plantillas, los pares y las pasadas por lote ya no existen (los reemplaza el
# Expediente, core/deduction/dossier.gd). Quedan las piezas comunes:
#   tag_match(clip_tags, t)       etiqueta de grupo contra las etiquetas de un recorte (sin prefijo = "a:<x>")
#   origins_of(st, clips)         orígenes distintos de una lista de recortes (dos fuentes distintas)
#   canon(v, groups) / alias      forma canónica bajo los alias vigentes (Dossier.alias_groups)
#   clip_tags(st, ids)            unión ordenada de etiquetas internas de varios recortes (confrontación, HB12)
#   covers_groups(tags_a, tags_b, g1, g2) / covers_both(tags, g1, g2)   T4 (un recorte nunca prueba las dos mitades)
extends RefCounted

const REFUTADO := "f:refutado"

static func tag_match(clip_tags: Array, t: String) -> bool:
	if t == "":
		return false
	if t.contains(":"):
		return clip_tags.has(t)
	return clip_tags.has("a:" + t)

static func any_match(clip_tags: Array, group: Array) -> bool:
	for t in group:
		if tag_match(clip_tags, String(t)):
			return true
	return false

static func canon(v: String, groups: Array) -> String:
	for g in groups:
		if g.has(v):
			return g[0]
	return v

static func _clips(st) -> Dictionary:
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var c = ded.get("clips", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

static func origins_of(st, clips: Array) -> Array:
	var cs := _clips(st)
	var out: Array = []
	for c in clips:
		var o := String(cs.get(String(c), {}).get("origin", ""))
		if not out.has(o):
			out.append(o)
	return out

static func clip_tags(st, ids: Array) -> Array:
	var cs := _clips(st)
	var out: Array = []
	for id in ids:
		for t in cs.get(String(id), {}).get("tags", []):
			if not out.has(t):
				out.append(t)
	out.sort()
	return out

# Dos recortes cubren los dos grupos (en cualquier orden).
static func covers_groups(ta: Array, tb: Array, g1: Array, g2: Array) -> bool:
	return (any_match(ta, g1) and any_match(tb, g2)) or (any_match(ta, g2) and any_match(tb, g1))

# T4: un solo recorte (o tramo) que lleva etiquetas de los dos grupos de una variante.
static func covers_both(tags: Array, g1: Array, g2: Array) -> bool:
	return any_match(tags, g1) and any_match(tags, g2)
