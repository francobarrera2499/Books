# Unit: core/react/sensors.gd (W2-REACT). Qué ve cada canal y qué no transmite (GDD§9.2, ARCHITECTURE §5.4).
extends "res://tests/test_base.gd"

const Sensors = preload("res://core/react/sensors.gd")
const GameState = preload("res://core/sim/game_state.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")

func R():
	return fixture_repo("react/data")

func _st():
	var st = GameState.new()
	st.seed = 3
	return st

func _e(type: String, tk: String, f := {}) -> Dictionary:
	var t := TimeKey.parse(tk)
	var e := {"seq": 1, "tk": t, "day": TimeKey.day_of(t), "slot": TimeKey.slot_of(t), "type": type, "act": "act.1"}
	for k in f:
		e[k] = f[k]
	return e

func _chs(obs: Array) -> Array:
	var out: Array = []
	for o in obs:
		out.append(String(o.channel))
	return out

func test_ks_from_day_3_streets_only():
	var r = R()
	var go := {"place": "L4", "area": "consulta", "streets": ["Kensington High Street", "Church Street"], "hour": "10:00"}
	eq(Sensors.observe(_st(), r, _e("go", "2.M", go)), [], "antes del día 3 la calle no mira")
	var obs := Sensors.observe(_st(), r, _e("go", "3.M", go))
	eq(_chs(obs), ["K-S"])
	eq(obs[0].content.keys().size(), 2, "sólo calles y hora: " + str(obs[0].content))
	eq(obs[0].content.streets, ["Kensington High Street", "Church Street"])
	no(obs[0].content.has("place"), "nunca la casa")
	ok(obs[0].to_holmes and obs[0].to_mycroft)

func test_kh_visits_only_interior():
	var r = R()
	var o1 := Sensors.observe(_st(), r, _e("go", "2.M", {"place": "L3", "area": "vestibulo", "streets": ["Baker Street"], "hour": "10:00"}))
	eq(_chs(o1), ["K-H"], "visita al 221B (día 2: sin K-S)")
	var o2 := Sensors.observe(_st(), r, _e("go", "4.M", {"place": "L3", "area": "calle", "streets": ["Baker Street"], "hour": "10:00"}))
	eq(_chs(o2), ["K-S"], "la calle no es el 221B")
	var o3 := Sensors.observe(_st(), r, _e("go", "4.T", {"place": "L8", "area": "interior", "streets": ["Baker Street"], "hour": "15:00"}))
	eq(_chs(o3), ["K-S"], "Camden House: sólo Baker Street por la calle")
	eq(o3[0].content.streets, ["Baker Street"])

func test_kbm_slip():
	var obs := Sensors.observe(_st(), R(), _e("slip", "1.M", {"seat": 214, "doc": "D05", "title": "el Journal", "topic": "holmes_prensa_1891", "hour": "10:15", "read": "secreto"}))
	eq(_chs(obs), ["K-BM"])
	eq(int(obs[0].content.seat), 214)
	eq(String(obs[0].content.title), "el Journal")
	no(obs[0].content.has("read"), "no lo leído")

func test_kw_topics_and_mary():
	var r = R()
	var pared := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "ask", "topic": "pared", "phrase": "¿Qué sabe de la pared?", "ents": ["pared"]}))
	eq(_chs(pared), ["K-W"])
	ok(pared[0].to_holmes and pared[0].to_mycroft, "roca: llega a Holmes")
	ok(bool(pared[0].content.privado_kw), "K-W marcado privado (T23)")
	var mary := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "¿Y su esposa?", "ents": ["mary_watson"]}))
	eq(_chs(mary), ["K-W"])
	no(mary[0].to_holmes, "Mary no pasa de Mycroft")
	ok(mary[0].to_mycroft)
	var vive := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "assert", "assertion": "as.vive", "topic": "vive", "phrase": "Holmes vive, doctor.", "ents": ["holmes"]}))
	eq(_chs(vive), ["K-W"])
	no(vive[0].to_holmes, "«vive» dicho a Watson: sólo Mycroft (HB4)")
	var otro := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "ask", "topic": "lestrade", "phrase": "¿Y Lestrade?", "ents": ["lestrade"]}))
	eq(otro, [], "otros temas no se transmiten")
	var crane := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "crane", "kind": "ask", "topic": "pared", "phrase": "¿Y la pared?", "ents": ["pared"]}))
	eq(crane, [], "Crane no es canal")

func test_kw_canary_and_bait_asserts():
	var r = R()
	var cn := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "assert", "assertion": "cn.chelsea", "topic": "lisle_mudanza", "canary": "lisle_mudanza", "phrase": "Me mudo a Chelsea."}))
	eq(_chs(cn), ["K-W"], "canario a Watson")
	eq(String(cn[0].content.canary), "lisle_mudanza")
	var bait := Sensors.observe(_st(), r, _e("say", "2.M", {"char": "mrs_hudson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "La pared era a pique, ¿no, sir?"}))
	eq(_chs(bait), ["K-H"], "un cebo a Mrs. Hudson también llega (assertion_kinds)")
	ok(bait[0].to_holmes)

func test_kh_talk_221b_not_other_houses():
	var r = R()
	var cuartos := Sensors.observe(_st(), r, _e("say", "2.M", {"char": "mrs_hudson", "kind": "ask", "topic": "cuartos", "phrase": "¿Se alquilan los cuartos?", "ents": ["cuartos"]}))
	eq(_chs(cuartos), ["K-H"])
	var camden := Sensors.observe(_st(), r, _e("say", "2.M", {"char": "mrs_hudson", "kind": "ask", "topic": "camden_house", "phrase": "¿Y la casa de enfrente?", "ents": ["camden_house"]}))
	eq(camden, [], "«Esa casa no es asunto mío, sir»")

func test_show_filters_camden():
	var r = R()
	var item := {"kind": "clip", "id": "RC0007", "doc_ids": ["D30"], "ents": ["221b", "camden_house", "guillotina", "libro_de_recibos"],
		"src_types": ["registro"], "tags": ["a:tirador", "f:secreto_camden"]}
	var obs := Sensors.observe(_st(), r, _e("show", "2.M", {"char": "mrs_hudson", "item": item}))
	eq(_chs(obs), ["K-H"])
	var s := J.stringify_canon(obs)
	no(s.contains("camden"), "sin Camden House: " + s)
	no(s.contains("guillotina"))
	no(s.contains("secreto"), "sin etiquetas ocultas")
	no(obs[0].content.item.has("tags"), "presentar sólo muestra lo visible")
	has(obs[0].content.item.ents, "221b")

func test_kt_ads():
	var obs := Sensors.observe(_st(), R(), _e("ad", "3.dawn", {"ad": "AD.2", "form": "a_proposito", "text": "A propósito…", "assertion": "as.pared", "bait_topic": "pared", "to_s": false, "says_alive": false, "pub_day": 3}))
	eq(_chs(obs), ["K-T"])
	eq(String(obs[0].content.text), "A propósito…")
	eq(String(obs[0].content.bait_topic), "pared")

func test_blind_events():
	var r = R()
	for t in ["telegram", "letter", "order_copy", "report"]:
		eq(Sensors.observe(_st(), r, _e(t, "2.N", {"to": "meiringen", "text": "x", "doc": "D18", "n": 1, "items": []})), [], t + " es ciego para Holmes")

func test_wiggins_dealings_from_day_3():
	var r = R()
	eq(Sensors.observe(_st(), r, _e("pay", "2.M", {"char": "wiggins", "amount_d": 12})), [], "Wiggins aparece desde el día 3")
	var o := Sensors.observe(_st(), r, _e("pay", "3.M", {"char": "wiggins", "amount_d": 12}))
	eq(_chs(o), ["K-S"])
	eq(int(o[0].content.amount_d), 12)

func test_old_sensor_format_defaults():
	# data_min usa el formato breve de §4.6 (sin char/assertion_kinds): valen los valores por defecto.
	var r = fixture_repo("data_min")
	var o := Sensors.observe(_st(), r, _e("say", "1.T", {"char": "watson", "kind": "ask", "topic": "pared", "phrase": "x", "ents": ["pared"]}))
	eq(_chs(o), ["K-W"])

func test_acts_by_channel():
	var r = R()
	var st = _st()
	st.events = [_e("slip", "1.M", {"seat": 214, "title": "t", "topic": "holmes_cronicas", "hour": "10:00"}),
		_e("go", "3.M", {"place": "L2", "streets": ["Great Russell Street"], "hour": "10:00"}),
		_e("telegram", "3.N", {"to": "meiringen"})]
	var a := Sensors.acts_by_channel(st, r)
	eq(a.keys().size(), 2, str(a.keys()))
	eq(int(a.kbm[0].seat), 214)
	eq(a.ks.size(), 1)
