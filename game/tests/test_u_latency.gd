# Unit: core/react/latency.gd (W2-REACT). Tabla de latencias GDD§9.3 caso por caso; domingo en mano; tipos de latencia.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Latency = preload("res://core/react/latency.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func after_each() -> void:
	H.cleanup()

func R():
	return fixture_repo("react/data")

func _bait_watson(h, tk: String, topic := "pared") -> Dictionary:
	return h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as." + topic, "topic": topic, "bait_topic": topic,
		"phrase": "La pared era a pique, ¿no, doctor?", "ents": [topic]}, tk)

# GDD§9.3: acto el día D → respuesta de voz B el día…
const VOICE_B := {1: 4, 2: 5, 3: 7, 4: 8, 5: 8, 6: 10, 7: 10, 8: 10, 9: 10}

func test_voice_b_table():
	var r = R()
	for d in VOICE_B:
		eq(Latency.voice_b_day(r, d), VOICE_B[d], "voz B día %d" % d)
	eq(Latency.voice_b_tk(r, 9), TimeKey.parse("10.M"), "día 9 → 10.M en persona")
	eq(Latency.voice_b_tk(r, 4), TimeKey.parse("8.dawn"))
	eq(Latency.voice_b_day(r, 10), -1, "el día 10 no hay voz B")
	eq(Latency.voice_b_day(r, 0), -1)

func test_due_tk_by_type():
	var r = R()
	var act := TimeKey.parse("3.T")
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "voz_a"}}, act), TimeKey.parse("4.dawn"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "voz_b"}}, act), TimeKey.parse("7.dawn"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "fija", "tk": "8.dawn"}}, act), TimeKey.parse("8.dawn"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "fija"}, "disparador": {"tk": "4.dawn"}}, act), TimeKey.parse("4.dawn"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "inmediata"}}, act), act)
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "siguiente_comunicacion"}}, act), act)
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "siguiente_salida"}}, TimeKey.parse("2.night")), TimeKey.parse("3.M"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "dias", "n": 2}}, act), TimeKey.parse("5.dawn"))
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "otra"}}, act), -1)
	# anuncio: el evento ad se emite al amanecer de la publicación; la latencia cuenta desde ese día (GDD§7.5)
	eq(Latency.due_tk(null, r, {"latencia": {"tipo": "voz_b"}}, TimeKey.parse("3.dawn")), TimeKey.parse("7.dawn"))

# Caso por caso: un cebo a Watson (K-W, privado) el día D → carta «—S.» el día de la tabla; el 9 → 10.M en persona.
func test_voice_b_case_by_case_private():
	for d in VOICE_B:
		var h = H.new(R())
		var tk := "%d.%s" % [d, "T" if d == 6 else "M"]
		_bait_watson(h, tk)
		h.advance_to("10.night")
		var hb1: Dictionary = h.first("HB1")
		ok(not hb1.is_empty(), "HB1 para el día %d" % d)
		if hb1.is_empty():
			continue
		eq(TimeKey.day_of(int(hb1.delivered_tk)), VOICE_B[d], "día %d" % d)
		ne(String(hb1.how), "columna", "lo dicho a Watson nunca va a la columna (día %d)" % d)
		if d == 9:
			eq(TimeKey.slot_of(int(hb1.delivered_tk)), "M", "el 9 contesta a las 9:30 del 10")
			ok(bool(hb1.get("en_persona", false)), "en persona")
			eq(String(hb1.how), "mostrador_crane", "nota del librero")
		else:
			eq(TimeKey.slot_of(int(hb1.delivered_tk)), "dawn")
			eq(String(hb1.how), "correo")

# Lo publicado se contesta en la columna con la misma tabla (anuncio publicado el día D).
func test_voice_b_case_by_case_published():
	for d in [1, 2, 3, 4, 5, 7, 8, 9]:
		var h = H.new(R())
		h.ev("ad", {"ad": "AD.%d" % d, "form": "a_proposito", "text": "A propósito de El problema final: cayeron los dos. —E. L.",
			"assertion": "as.cayeron", "bait_topic": "cayeron", "pub_day": d}, "%d.dawn" % d)
		h.advance_to("10.night")
		var hb1: Dictionary = h.first("HB1")
		ok(not hb1.is_empty(), "HB1 publicado el %d" % d)
		if hb1.is_empty():
			continue
		eq(TimeKey.day_of(int(hb1.delivered_tk)), VOICE_B[d], "anuncio del %d" % d)
		if d != 9:
			eq(String(hb1.how), "columna", "contesta en la columna (Ley 5)")
		ok(String(hb1.text).contains("aucun corps") or String(hb1.text).contains("Cayeron"), "texto de la Ley 2: " + String(hb1.text))

# Voz A: siempre una noche; si la mañana siguiente es domingo, en mano y sin sello (HC03).
func test_voice_a_next_morning_and_sunday():
	var reps := [R()]
	if not repo().reaction("HA1").is_empty():
		reps.append(repo())
	for d in [1, 2, 3, 4, 5, 7, 8, 9]:
		for rp in reps:
			_voice_a_case(rp, d)

func _voice_a_case(rp, d: int) -> void:
	if true:
		var h = H.new(rp)
		h.ev("slip", {"seat": 214, "doc": "D05", "title": "el Journal de Genève", "topic": "holmes_prensa_1891", "hour": "10:00"}, "%d.M" % d)
		h.advance_to("10.night")
		var ha1: Dictionary = h.first("HA1")
		ok(not ha1.is_empty(), "HA1 tras papeleta del %d" % d)
		if ha1.is_empty():
			return
		eq(int(ha1.delivered_tk), TimeKey.tk(d + 1, "dawn"), "voz A: una noche (día %d)" % d)
		if d + 1 == 6:
			eq(String(ha1.how), "en_mano", "domingo: en mano")
			ok(String(h.sink.docs[ha1.iid].tpl.title).contains("sin sello"), "sin sello")
		else:
			eq(String(ha1.how), "correo")
			ok(String(h.sink.docs[ha1.iid].tpl.title).contains("S.W."), "matasellos S.W.")

func test_respuestas_dias():
	var h = H.new(R())
	h.ev("telegram", {"to": "meiringen", "text": "¿Hay cornisa?"}, "2.N")
	h.ev("letter", {"to": "bath", "text": "¿Conoce usted a un tal Pell?"}, "2.N")
	h.advance_to("6.night")
	eq(h.day_of_delivery("D27"), 3, "telegrama al día siguiente")
	eq(h.day_of_delivery("D28"), 4, "carta de Bath a los dos días")
	ok(h.text("D27").contains("CORNISA"))

# Moran: siguiente_salida = primera salida del día siguiente o, si no sale, a la noche.
func test_siguiente_salida():
	var item := {"kind": "clip", "id": "RC0001", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]}
	var h = H.new(R())
	h.ev("report", {"n": 1, "mode": "items", "items": [item]}, "2.night")
	h.advance_to("3.M")
	eq(h.find("M1").size(), 0, "todavía no")
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "14:00"}, "3.T")
	eq(h.day_of_delivery("M1"), 3)
	eq(int(h.first("M1").delivered_tk), TimeKey.parse("3.T"), "en la salida de la tarde")
	var h2 = H.new(R())
	h2.ev("report", {"n": 1, "mode": "items", "items": [item]}, "2.night")
	h2.advance_to("3.night")
	eq(int(h2.first("M1").get("delivered_tk", -1)), TimeKey.parse("3.night"), "sin salida: a la noche")

func test_how_for():
	var r = R()
	var rule: Dictionary = r.reaction("HA1")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("6.dawn")}, {"op": "carta"}), "en_mano")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("7.dawn")}, {"op": "carta"}), "correo")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("7.dawn")}, {"op": "columna"}), "columna")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("7.dawn")}, {"op": "noticia"}), "noticias")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("7.dawn")}, {"op": "carta", "entrega": "mostrador_crane"}), "mostrador_crane")
	eq(Latency.how_for(null, r, r.reaction("M2"), {"due_tk": TimeKey.parse("7.dawn")}, {"op": "carta"}), "en_mano", "Moran: nota en mano")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("6.dawn")}, {"op": "carta", "entrega": "correo"}), "en_mano", "«correo» un domingo: en mano")
	eq(Latency.how_for(null, r, rule, {"due_tk": TimeKey.parse("5.dawn")}, {"op": "carta", "entrega": "correo"}), "correo")
	ok(Latency.has_mail(r, 5) and not Latency.has_mail(r, 6))
	ok(Latency.has_times(r, 7) and not Latency.has_times(r, 6))
