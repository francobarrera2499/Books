# T22 (W2-REACT): Camden House es un secreto de Moran (GDD§2.4, §9.8 D10). Ninguna etiqueta secreto_camden ni entidad
# de Camden House llega al Holmes-agente ni a Mycroft: los sensores las quitan, las reacciones del bando de Holmes no
# se disparan por ellas y sus instancias (ancla, variables, texto) no las contienen.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Sensors = preload("res://core/react/sensors.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func after_each() -> void:
	H.cleanup()

func _camden(r) -> Array:
	var out: Array = ["secreto_camden"]
	for e in r.lists().get("camden_entities", []):
		out.append(String(e))
	return out

func _leaks(r, v) -> Array:
	var s := J.stringify_canon(v)
	var out: Array = []
	for c in _camden(r):
		if s.contains("\"" + c + "\"") or s.contains(":" + c + "\"") or s.contains("e:" + c) or s.contains("f:" + c):
			out.append(c)
	return out

# Eventos públicos de todo tipo cargados de Camden House.
func _events() -> Array:
	var item := {"kind": "clip", "id": "RC0042", "doc_ids": ["D32"], "ents": ["camden_house", "guillotina", "libro_de_llaves", "pared", "221b", "mary_watson"],
		"src_types": ["registro"], "origins": ["D32"], "tags": ["a:tirador", "f:secreto_camden", "c:camden"], "cats": ["camden"],
		"entry_values": {"lugar": "camden_house", "persona": "moran"}}
	return [
		{"type": "go", "tk": TimeKey.parse("7.T"), "day": 7, "place": "L8", "area": "interior", "streets": ["Baker Street"], "hour": "15:00", "tags": ["f:secreto_camden"]},
		{"type": "go", "tk": TimeKey.parse("8.M"), "day": 8, "place": "L3", "area": "vestibulo", "streets": ["Baker Street"], "hour": "10:00"},
		{"type": "say", "tk": TimeKey.parse("8.M"), "day": 8, "char": "mrs_hudson", "kind": "ask", "topic": "camden_house", "phrase": "¿Y la casa de enfrente?", "ents": ["camden_house", "221b"]},
		{"type": "say", "tk": TimeKey.parse("8.T"), "day": 8, "char": "watson", "kind": "ask", "topic": "pared", "phrase": "¿Y la guillotina?", "ents": ["pared", "guillotina", "casa_vacia"]},
		{"type": "show", "tk": TimeKey.parse("8.T"), "day": 8, "char": "watson", "item": item},
		{"type": "show", "tk": TimeKey.parse("8.M"), "day": 8, "char": "mrs_hudson", "item": item},
		{"type": "show", "tk": TimeKey.parse("8.N"), "day": 8, "char": "wiggins", "item": item},
		{"type": "slip", "tk": TimeKey.parse("8.M"), "day": 8, "seat": 9, "doc": "D32", "title": "libro de llaves", "topic": "otros", "hour": "10:00", "ents": ["camden_house"]},
		{"type": "ad", "tk": TimeKey.parse("9.dawn"), "day": 9, "ad": "AD.9", "form": "a_proposito", "text": "x", "assertion": "as.pared", "bait_topic": "pared", "pub_day": 9, "ents": ["camden_house"]},
	]

func test_sensors_strip_camden():
	for label in ["fixture", "data"]:
		var r = fixture_repo("react/data") if label == "fixture" else repo()
		if r.lists().is_empty():
			continue
		for ev in _events():
			var obs := Sensors.observe(null, r, ev)
			eq(_leaks(r, obs), [], "%s %s/%s: %s" % [label, ev.type, ev.get("char", ""), J.stringify_canon(obs).left(300)])

func _holmes_side(r, h) -> Array:
	var out: Array = []
	for i in h.delivered() + h.st.react.queue:
		if ["holmes", "mycroft"].has(String(i.lado)):
			out.append(i)
	return out

func test_holmes_side_instances_clean():
	var reps := {"fixture": fixture_repo("react/data")}
	if not repo().reactions().is_empty():
		reps["data"] = repo()
	for label in reps:
		var r = reps[label]
		var h = H.new(r)
		h.play([], "6.night")
		for ev in _events():
			var f: Dictionary = ev.duplicate(true)
			var t := TimeKey.label(int(f.tk))
			var ty := String(f.type)
			for k in ["type", "tk", "day"]:
				f.erase(k)
			h.ev(ty, f, t)
		h.advance_to("10.night")
		var side := _holmes_side(r, h)
		ok(side.size() > 3, "%s: hubo reacciones del bando de Holmes (%d)" % [label, side.size()])
		for i in side:
			eq(_leaks(r, [i.anchor, i.vars, i.get("text", "")]), [], "%s %s: %s" % [label, i.iid, J.stringify_canon(i.anchor).left(300)])
		# el informe con Camden sí lo lee Moran (es su secreto)
		h.ev("report", {"n": 3, "mode": "items", "items": [{"kind": "clip", "id": "RC0042", "cats": ["camden"], "copies": ["D32@L3"], "cls": ["C"]}]}, "8.night")

func test_static_no_holmes_trigger_on_camden():
	var reps := {"fixture": fixture_repo("react/data")}
	if not repo().reactions().is_empty():
		reps["data"] = repo()
	else:
		pending_content("data/reactions (W2-STRUCT)")
	for label in reps:
		var r = reps[label]
		var cam := _camden(r)
		for rule in r.reactions():
			if not ["holmes", "mycroft"].has(RDB.lado(rule)):
				continue
			var m := J.stringify_canon(RDB.disp(rule))
			for c in cam + ["camden"]:
				no(m.contains("\"" + c + "\""), "%s %s: el disparador mira %s" % [label, rule.id, c])
			for rs in RDB._as_arr(rule.get("rastro", [])):
				no(J.stringify_canon(rs).contains("secreto_camden"), "%s %s: rastro con secreto_camden" % [label, rule.id])
		for f in r.lists().get("ad_forms", []):
			has(RDB._as_arr(f.get("forbid_tags", [])), "secreto_camden", "%s: el anuncio %s no admite secreto_camden" % [label, f.get("id", "")])

func test_detector_negative():
	var r = fixture_repo("react/data")
	ok(not _leaks(r, {"ents": ["guillotina"]}).is_empty())
	ok(not _leaks(r, ["a:x", "f:secreto_camden"]).is_empty())
	eq(_leaks(r, {"ents": ["pared"]}), [])
