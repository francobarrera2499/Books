# T16 (W2-REACT): HB13, el antiestancamiento, empuja hacia actividades y nunca hacia el documento clave: ningún rastro de
# HB13 lleva etiquetas de C2–C5 ni de C8–C13 (sólo las de C6/C7 propias de toda carta de voz A). Se dispara sólo por
# inactividad observable (GDD§9.6 HB13, D4).
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Markup = preload("res://core/text/markup.gd")

const FORBIDDEN := ["C2", "C3", "C4", "C5", "C8", "C9", "C10", "C11", "C12", "C13"]

func after_each() -> void:
	H.cleanup()

static func conclusion_tags(r, cids: Array) -> Dictionary:
	var out := {}
	for c in r.conclusions():
		var cid := String(c.get("id", ""))
		var hit := false
		for want in cids:
			if cid == want or cid.begins_with(want) and not cid.substr(want.length()).is_valid_int():
				hit = true
		if not hit:
			continue
		for g in RDB._as_arr(c.get("groups", [])):
			for t in RDB._as_arr(g.get("tags", [])):
				out[String(t)] = cid
		for t in RDB._as_arr(c.get("tags_extra", [])):
			out[String(t)] = cid
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
	var bad := conclusion_tags(r, FORBIDDEN)
	ok(not bad.is_empty(), label + ": las conclusiones traen etiquetas")
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
	if r.reaction("HB13").is_empty() or r.conclusions().is_empty():
		pending_content("HB13 y conclusions.json (W2-STRUCT)")
		return
	_check(r, "data")

func test_hb13_delivered_texts_clean():
	for label in ["fixture", "data"]:
		var r = fixture_repo("react/data") if label == "fixture" else repo()
		if r.reaction("HB13").is_empty():
			continue
		var bad := conclusion_tags(r, FORBIDDEN)
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
	var bad := conclusion_tags(r, FORBIDDEN)
	var found := false
	for t in rastro_tags(fake):
		if bad.has(String(t).get_slice(":", 1)):
			found = true
	ok(found, "el detector ve una etiqueta de C3")
