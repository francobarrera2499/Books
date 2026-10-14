# Unit: core/util/cond.gd (W1-ENG). DSL §4.18 con estado en Dictionary y en objeto (como GameState).
extends "res://tests/test_base.gd"

const Cond = preload("res://core/util/cond.gd")

class FakeSt extends RefCounted:
	var clock := {}
	var world := {}
	var ded := {}
	var react := {}
	var flags := {}
	var events := []

var rp

func before_each() -> void:
	rp = fixture_repo()

func _st(over := {}) -> Dictionary:
	var st := {
		"clock": {"day": 4, "slot": "M", "phase": "desk"},
		"flags": {"watson_avisado": true, "hb4_veces": 1, "errata_ofrecida": "", "canal_cerrado.K-H": true},
		"ded": {"sealed": {"C2": "AS001", "C6": "AS002"}},
		"react": {"counters": {"bait.pared": 2}},
		"world": {"visits": ["S.L3.4.M", {"place": "L2", "area": "sala"}], "visit": {"chars": ["watson", {"id": "wiggins"}]}},
		"events": [
			{"type": "say", "char": "watson", "topic": "pared"},
			{"type": "say", "char": "crane", "topic": "fina"},
			{"type": "report", "n": 2, "items": [{"cats": ["camden"]}]},
			{"type": "report", "n": 4, "items": [{"cats": ["holmes_vive", "verdadero"]}]},
		],
	}
	for k in over:
		st[k] = over[k]
	return st

func _ev(c, st = null, extra := {}) -> bool:
	var ctx := {"st": _st() if st == null else st, "repo": rp}
	for k in extra:
		ctx[k] = extra[k]
	return Cond.eval(c, ctx)

func test_empty_and_null_true():
	ok(_ev({}))
	ok(_ev(null))
	ok(_ev({"_nota": "ignorado"}))

func test_day_slot_tk():
	ok(_ev({"day": 4}))
	no(_ev({"day": 5}))
	ok(_ev({"day": {"gte": 1, "lte": 9}}))
	no(_ev({"day": {"gte": 5}}))
	ok(_ev({"day": {"eq": 4}}))
	ok(_ev({"slot": ["M", "T"]}))
	no(_ev({"slot": ["N"]}))
	ok(_ev({"tk": {"gte": "4.dawn", "lte": "4.M"}}))
	no(_ev({"tk": {"gte": "4.T"}}))
	ok(_ev({"tk": "4.M"}))
	ok(_ev({"slot": ["night"]}, _st({"clock": {"day": 4, "slot": "N", "phase": "night"}})), "fase night -> franja night")
	ok(_ev({"tk": {"gte": "7.night"}}, null, {"tk": 74}), "ctx.tk manda")
	ok(_ev({"slot": ["dawn"], "day": 8}, null, {"tk": 80}))

func test_weekday_from_schedule():
	ok(_ev({"weekday": "vie"}), "día 4 = vie 30-mar")
	ok(_ev({"weekday": "dom"}, _st({"clock": {"day": 6, "slot": "T"}})))
	no(_ev({"not": {"weekday": "dom"}}, _st({"clock": {"day": 6, "slot": "T"}})))
	ok(_ev({"weekday": ["sab", "dom"]}, _st({"clock": {"day": 5, "slot": "M"}})))
	ok(_ev({"weekday": "sáb"}, _st({"clock": {"day": 5, "slot": "M"}})), "tilde indistinta")
	ok(_ev({"weekday": ["mié"]}, _st({"clock": {"day": 2, "slot": "M"}})))

func test_flags():
	ok(_ev({"flag": "watson_avisado"}))
	no(_ev({"flag": "watson_expuesto"}), "flag ausente")
	no(_ev({"flag": "errata_ofrecida"}), "texto vacío = falso")
	ok(_ev({"flag_eq": {"errata_ofrecida": ""}}))
	ok(_ev({"flag_eq": {"informe_final": ""}}), "ausente == valor por defecto del tipo")
	no(_ev({"flag_eq": {"hb4_veces": 2}}))
	ok(_ev({"flag_gte": {"hb4_veces": 1}}))
	no(_ev({"flag_gte": {"informes_vacios": 2}}))
	ok(_ev({"channel_closed": "K-H"}))
	no(_ev({"channel_closed": "K-W"}))

# GDD_v3 §6.10: átomos del Expediente (inked*) y la traducción de los viejos sealed* (C<n> -> su pregunta).
func test_inked():
	var s := FakeSt.new()
	s.ded = {"dossier": {"inked": {"Q1": {}, "Q2": {}, "Q3": {}}}}
	var ctx := {"st": s, "repo": rp}
	ok(Cond.eval({"inked": "Q1"}, ctx))
	no(Cond.eval({"inked": "Q6"}, ctx))
	ok(Cond.eval({"inked_all": ["Q1", "Q3"]}, ctx))
	no(Cond.eval({"inked_all": ["Q1", "Q6"]}, ctx))
	ok(Cond.eval({"inked_count": {"gte": 2}}, ctx), "Q1 y Q2 son obligatorias del fixture (Q3 no está en él)")
	ok(Cond.eval({"inked_count": {"lt": 3}}, ctx))
	ok(Cond.eval({"sealed": "C2"}, ctx), "C2 -> Q1")
	ok(Cond.eval({"sealed": "C7"}, ctx), "C7 -> Q3")
	no(Cond.eval({"sealed": "C12"}, ctx), "C12 no tiene pregunta")
	s.flags = {"curiosidad_tomos": true}
	ok(Cond.eval({"sealed": "C14"}, ctx), "C14 -> flag curiosidad_tomos")

func test_counter_event_count_visited():
	ok(_ev({"counter": {"name": "bait.pared", "gte": 2}}))
	ok(_ev({"counter": {"name": "x", "eq": 5}}, null, {"counters": {"x": 5}}))
	ok(_ev({"counter": {"name": "hb4_veces", "eq": 1}}), "respaldo: flags")
	ok(_ev({"event_count": {"type": "say", "where": {"char": "watson", "topic_group": "roca"}, "gte": 1}}))
	no(_ev({"event_count": {"type": "say", "where": {"char": "crane", "topic_group": "mary"}, "gte": 1}}))
	ok(_ev({"event_count": {"type": "say", "gte": 2}}))
	ok(_ev({"event_count": {"type": "say", "where": {"char": ["watson", "crane"]}, "eq": 2}}))
	ok(_ev({"visited": "L3"}))
	ok(_ev({"visited": "L2"}))
	no(_ev({"visited": "L4"}))

func test_reports_anchor_chars():
	ok(_ev({"report_final_cats_any": ["holmes_vive", "camden"]}))
	no(_ev({"report_final_cats_any": ["camden"]}), "sólo cuenta el informe final (n=4)")
	ok(_ev({"anchor": {"seat": 214}}, null, {"anchor": {"seat": 214, "title": "x"}}))
	ok(_ev({"anchor": {"topic": "pared"}}, null, {"ev": {"type": "say", "topic": "pared"}}), "sin ctx.anchor: campos de ctx.ev")
	no(_ev({"anchor": {"topic": "pared"}}, null, {"ev": {"topic": "mary"}, "anchor": {"topic": "x"}}), "ctx.anchor manda sobre ev")
	ok(_ev({"anchor": {"topic": ["a", "b"]}}, null, {"anchor": {"topic": "b"}}))
	no(_ev({"anchor": {"seat": 1}}, null, {"anchor": {"seat": 214}}))
	ok(_ev({"char_present": "wiggins"}))
	no(_ev({"char_present": "mycroft"}))
	ok(_ev({"char_present": "mycroft"}, null, {"chars_present": ["mycroft"]}))

func test_combinators():
	ok(_ev({"all": [{"day": 4}, {"slot": ["M"]}]}))
	no(_ev({"all": [{"day": 4}, {"slot": ["T"]}]}))
	ok(_ev({"any": [{"day": 9}, {"slot": ["M"]}]}))
	no(_ev({"any": []}))
	ok(_ev({"all": []}))
	ok(_ev({"not": {"day": 9}}))
	ok(_ev({"always": true}))
	no(_ev({"always": false}))
	no(_ev({"day": 4, "slot": ["T"]}), "varias claves = AND")
	ok(_ev({"any": [{"slot": ["M"]}, {"day": 6}]}), "ejemplo de §4.11")

func test_object_state():
	var s := FakeSt.new()
	s.clock = {"day": 8, "slot": "T"}
	s.flags = {"moran_credito": true}
	s.ded = {"dossier": {"inked": {"Q3": {}}}}
	s.events = [{"type": "go", "place": "L3"}]
	ok(Cond.eval({"all": [{"day": {"gte": 8}}, {"flag": "moran_credito"}, {"inked": "Q3"}, {"event_count": {"type": "go", "gte": 1}}]}, {"st": s, "repo": rp}))

func test_unknown_atom_is_bug():
	expect_error("átomo desconocido")
	no(_ev({"lluvia": true}))

func test_validate_ok_on_examples():
	var good := [
		{}, {"all": [{"day": {"gte": 1, "lte": 9}}, {"not": {"weekday": "dom"}}]}, {"not": {"flag": "watson_expuesto"}},
		{"any": [{"slot": ["M"]}, {"day": 6}]}, {"flag_gte": {"informes_vacios": 2}},
		{"event_count": {"type": "say", "where": {"char": "watson", "topic_group": "roca"}, "gte": 1}},
		{"sealed_count": {"of": "mandatory", "gte": 8}}, {"report_final_cats_any": ["camden"]}, {"always": true},
		{"tk": {"gte": "4.dawn"}}, {"counter": {"name": "x", "lte": 3}}, {"anchor": {"seat": 1}}, {"char_present": "wiggins"},
	]
	for c in good:
		eq(Cond.validate(c), [], str(c))

func test_validate_errors():
	var bad := [
		{"lluvia": 1}, {"day": "x"}, {"slot": ["Q"]}, {"tk": {"gte": "zz"}}, {"sealed_count": {"of": "mandatory"}},
		{"all": {"day": 1}}, {"weekday": "domingo"}, {"flag": ""}, {"event_count": {"gte": 1}}, {"day": {"mayor": 3}},
		{"not": {"lluvia": 1}}, "texto", {"weekday": "sáb"}, {"weekday": ["mié"]},
	]
	for c in bad:
		ok(Cond.validate(c).size() > 0, "debe fallar: " + str(c))
	ok(str(Cond.validate({"all": [{"x": 1}]}, "r.cond")).contains("r.cond.all[0].x"), "ruta del error")
