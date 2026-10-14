# T16 (W2-REACT → v3): HB13, el antiestancamiento, empuja hacia actividades y nunca hacia el documento clave: ningún rastro
# de HB13 lleva etiquetas de grupo de las preguntas del expediente (data/dossier.json), salvo me_vigila_de_cerca, propia
# de toda carta de voz A (Q3). Se dispara sólo por inactividad observable (GDD§9.6 HB13, D4). Las etiquetas prohibidas
# salen siempre de las preguntas reales (también para el fixture de reacciones, que no tiene expediente).
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Markup = preload("res://core/text/markup.gd")

const ALLOWED := ["me_vigila_de_cerca"]

func after_each() -> void:
	H.cleanup()

# {etiqueta: "Qn"} de los grupos de todas las variantes de las preguntas reales, salvo ALLOWED.
func question_tags() -> Dictionary:
	var out := {}
	for q in repo().questions():
		for v in RDB._as_arr(q.get("variantes", [])):
			for g in RDB._as_arr(v.get("grupos", [])):
				for t in RDB._as_arr(g.get("tags", [])):
					var s := String(t).trim_prefix("a:")
					if not ALLOWED.has(s):
						out[s] = String(q.get("id", ""))
	return out

static func rastro_tags(rule: Dictionary) -> Array:
	var out: Array = []
	for rs in RDB._as_arr(rule.get("rastro", [])):
		if typeof(rs) != TYPE_DICTIONARY:
			continue
		var texts: Array = []
		if rs.has("texto"):
			texts.append(String(rs.texto))
		if typeof(rs.get("tono")) == TYPE_DICTIONARY:
			for k in rs.tono:
				texts.append(String(rs.tono[k]))
		for tx in texts:
			for t in Markup.parse(Markup.fill(tx, {"ch": "kbm"})).tramos:
				for p in t.tags:
					for v in t.tags[p]:
						out.append(String(p) + ":" + String(v))
		for t in RDB._as_arr(rs.get("tags", [])):
			out.append(String(t))
	return out

func _check(r, label: String) -> void:
	var hb13: Dictionary = r.reaction("HB13")
	if hb13.is_empty():
		fail(label + ": no hay HB13")
		return
	var bad := question_tags()
	ok(not bad.is_empty(), label + ": las preguntas traen etiquetas")
	var tags := rastro_tags(hb13)
	ok(not tags.is_empty() or RDB._as_arr(hb13.get("rastro", [])).size() > 0, label + ": HB13 tiene rastro")
	for t in tags:
		var v := String(t).get_slice(":", 1) if String(t).contains(":") else String(t)
		if String(t).begins_with("a:") or not String(t).contains(":"):
			no(bad.has(v), "%s: HB13 lleva %s (de %s)" % [label, t, bad.get(v, "")])
	eq(RDB.evento_list(hb13), ["inactividad"], label + ": sólo por inactividad")
	eq(RDB._as_arr(hb13.get("corta", [])), [], label + ": no corta nada")

func test_hb13_fixture():
	_check(fixture_repo("react/data"), "fixture")

func test_hb13_real_data():
	var r = repo()
	if r.reaction("HB13").is_empty() or r.questions().is_empty():
		pending_content("HB13 y dossier.json")
		return
	_check(r, "data")

func test_hb13_delivered_texts_clean():
	for label in ["fixture", "data"]:
		var r = fixture_repo("react/data") if label == "fixture" else repo()
		if r.reaction("HB13").is_empty():
			continue
		var bad := question_tags()
		var h = H.new(r, 21)
		h.advance_to("10.night")
		var n := 0
		for i in h.find("HB13"):
			n += 1
			for t in Markup.parse(String(i.get("text", ""))).tramos:
				for v in t.tags.a:
					no(bad.has(String(v)), "%s: HB13 entregada con a:%s" % [label, v])
		ok(n >= 3, "%s: el pasivo recibe varias (%d)" % [label, n])

func test_detector_negative():
	var r = fixture_repo("react/data")
	var fake := {"id": "HB13", "rastro": [{"tpl": "x", "texto": "{{#t a:cornisa_existe|La cornisa existe.}}"}]}
	var bad := question_tags()
	var found := false
	for t in rastro_tags(fake):
		if bad.has(String(t).get_slice(":", 1)):
			found = true
	ok(found, "el detector ve una etiqueta de Q2 (cornisa_existe)")
