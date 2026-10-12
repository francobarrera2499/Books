# Unit: core/react/holmes_agent.gd (W2-REACT). Ley 2, canario → HA4 → HB11, HA1/HB14, HA3, HB4, HB13, postura, tono.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const HolmesAgent = preload("res://core/react/holmes_agent.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func after_each() -> void:
	H.cleanup()

func R():
	return fixture_repo("react/data")

func _ad(h, day: int, topic: String) -> Dictionary:
	return h.ev("ad", {"ad": "AD.%d" % day, "form": "a_proposito", "text": "A propósito de El problema final: %s. —E. L." % topic,
		"assertion": "as." + topic, "bait_topic": topic, "pub_day": day}, "%d.dawn" % day)

func _say(h, tk: String, who: String, f: Dictionary) -> Dictionary:
	var d := {"char": who, "kind": "assert", "phrase": "…"}
	for k in f:
		d[k] = f[k]
	return h.ev("say", d, tk)

func _bait(h, tk: String, who: String, topic: String) -> Dictionary:
	return _say(h, tk, who, {"assertion": "as." + topic, "topic": topic, "bait_topic": topic, "ents": [topic]})

func _canary(h, tk: String, who: String, topic := "lisle_mudanza") -> Dictionary:
	return _say(h, tk, who, {"assertion": "cn.chelsea", "topic": topic, "canary": topic})

func _all(h, rid: String) -> Array:
	return h.find(rid) + h.queued(rid)

# Ley 2: 1–2 correcciones verdaderas que remiten a una fuente, 3.ª falsa (f:refutado), 4.ª en adelante silencio.
func test_ley2_same_channel():
	var h = H.new(R())
	for d in [1, 2, 3, 4, 5]:
		_ad(h, d, "pared")
	h.advance_to("10.night")
	var hb1 := _all(h, "HB1")
	eq(hb1.size(), 2, "dos verdaderas")
	eq(String(hb1[0].tpl), "pared.1")
	eq(String(hb1[1].tpl), "pared.2")
	ok(String(hb1[0].text).contains("Journal de Genève"), "remite a una fuente: " + String(hb1[0].text))
	var hb2 := _all(h, "HB2")
	eq(hb2.size(), 1, "la tercera es falsa")
	ok(String(hb2[0].text).contains("f:refutado") or String(hb2[0].text).contains("refutado"), "lleva f:refutado")
	eq(int(h.st.react.holmes.bait.pared), 5, "contador por tema")
	eq(int(h.st.react.counters.get("bait_topic=pared", 0)), 5)

func test_ley2_global_between_channels_and_per_topic():
	var h = H.new(R())
	_bait(h, "1.T", "watson", "pared")       # K-W n=1
	_ad(h, 2, "pared")                        # K-T n=2
	_bait(h, "2.M", "mrs_hudson", "pared")   # K-H n=3 → HB2
	_bait(h, "2.T", "watson", "cayeron")     # otro tema n=1
	h.advance_to("10.night")
	var tpls: Array = []
	for i in _all(h, "HB1"):
		tpls.append(String(i.tpl))
	tpls.sort()
	eq(tpls, ["cayeron.1", "pared.1", "pared.2"])
	var hb2 := _all(h, "HB2")
	eq(hb2.size(), 1)
	eq(String(hb2[0].channel), "K-H", "la falsa por el mismo canal que el cebo")
	ne(String(hb2[0].how), "columna", "lo dicho a Mrs. Hudson se contesta en privado")

func test_canary_ha4_then_hb11_closes_channel():
	var h = H.new(R())
	_canary(h, "1.M", "mrs_hudson")
	h.advance_to("2.night")
	eq(h.find("HA4").size(), 1, "primer canario → HA4")
	ok(String(h.text("HA4")).contains("Chelsea"), h.text("HA4"))
	_canary(h, "3.M", "mrs_hudson", "lisle_ojos")
	h.advance_to("4.night")
	eq(h.find("HB11").size(), 1, "segundo canario en el canal → HB11")
	ok(bool(h.st.flags.get("canal_cerrado.K-H", false)), "canal cerrado")
	ok(String(h.text("HB11")).contains("señora Hudson"), h.text("HB11"))
	# desde ahora el canal no produce opcionales nuevas (un cebo a Mrs. Hudson no recibe HB1)
	_bait(h, "5.M", "mrs_hudson", "testamento")
	_canary(h, "5.T", "mrs_hudson", "lisle_boda")
	h.advance_to("10.night")
	eq(_all(h, "HB1").size(), 0, "canal cerrado: sin HB1")
	eq(_all(h, "HA4").size(), 1)
	eq(_all(h, "HB11").size(), 1)
	# otro canal sigue abierto
	var h2 = H.new(R())
	_canary(h2, "1.M", "mrs_hudson")
	_canary(h2, "1.T", "watson")
	h2.advance_to("3.night")
	eq(_all(h2, "HA4").size(), 2, "un HA4 por canal")
	eq(_all(h2, "HB11").size(), 0)

# Un cebo o un canario dicho a Wiggins (K-S) no es un cebo de la Ley 2 ni un canario de HA4/HB11 (GDD: anuncio, Watson,
# Mrs. Hudson): no consume el contador ni deja instancias mudas; sólo cuenta para HB8b.
func test_wiggins_is_not_a_bait_channel():
	var h = H.new(R())
	h.st.flags["wiggins_aliado"] = true
	_bait(h, "3.M", "wiggins", "pared")
	_canary(h, "3.T", "wiggins")
	_ad(h, 4, "pared")
	h.advance_to("10.night")
	eq(int(h.st.react.counters.get("bait_topic=pared", 0)), 1, "sólo el anuncio cuenta")
	var hb1 := _all(h, "HB1")
	eq(hb1.size(), 1)
	if hb1.size() == 1:
		eq(String(hb1[0].channel), "K-T")
		eq(String(hb1[0].tpl), "pared.1", "la primera corrección verdadera no se perdió")
		ok(bool(hb1[0].guaranteed), "primer cebo en la columna: garantizada")
	eq(_all(h, "HA4").size(), 0, "Wiggins no es canal de canario")
	eq(_all(h, "HB8b").size(), 1, "pasar información falsa por Wiggins dos veces → HB8b")

func test_ha1_once_per_topic_and_silence():
	var h = H.new(R())
	h.ev("slip", {"seat": 214, "doc": "D05", "title": "el Journal", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	h.ev("slip", {"seat": 214, "doc": "D06", "title": "el Times de 1891", "topic": "holmes_prensa_1891", "hour": "10:05"}, "1.M")
	h.ev("slip", {"seat": 214, "doc": "D09", "title": "las cartas del coronel", "topic": "coronel", "hour": "10:10"}, "1.M")
	h.ev("slip", {"seat": 88, "doc": "D03", "title": "«El problema final»", "topic": "holmes_cronicas", "hour": "15:00"}, "2.T")
	h.advance_to("4.night")
	var ha1 := h.find("HA1")
	eq(ha1.size(), 2, "una por tema; «coronel» es silencio (HB14)")
	ok(String(ha1[0].text).contains("Asiento 214"), "cita el asiento: " + String(ha1[0].text))
	ok(String(ha1[0].text).contains("lea a Reuter"), "desvía hacia la fuente menos informativa")
	ok(String(ha1[1].text).contains("Asiento 88"))
	eq(h.find("HA0").size(), 0, "HA0 no sale si hubo HA1 el día 1")
	eq(h.find("HB14").size(), 0)
	eq(h.find("HA2").size(), 1, "segunda papeleta del mismo tema: HA2 (señalador)")

func test_ha3_first_outing_from_day3_with_itinerary():
	var h = H.new(R())
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "2.M")
	h.ev("go", {"place": "L4", "area": "consulta", "streets": ["Kensington High Street"], "hour": "10:00"}, "3.M")
	h.ev("go", {"place": "L6", "area": "", "streets": ["el Strand"], "hour": "15:00"}, "3.T")
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "4.M")
	h.advance_to("6.night")
	var ha3 := h.find("HA3")
	eq(ha3.size(), 1, "HA3 una sola vez")
	eq(TimeKey.day_of(int(ha3[0].delivered_tk)), 4)
	var t := String(ha3[0].text)
	ok(t.contains("Kensington High Street a las diez") and t.contains("el Strand a las tres"), "calles y horas del día: " + t)
	no(t.contains("L4") or t.contains("consulta"), "nunca la casa ni lo consultado")

func test_hb4_mary_twice_closes_consulta():
	var h = H.new(R())
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "¿Y la señora Watson?", "ents": ["mary_watson"]}, "1.M")
	h.advance_to("2.night")
	eq(h.find("HB4").size(), 1)
	ok(String(h.text("HB4")).contains("Deje al doctor"), h.text("HB4"))
	eq(int(h.st.flags.get("hb4_veces", 0)), 1)
	eq(h.find("HB1").size(), 0, "nada de Mary llega a Holmes")
	h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.vive", "topic": "vive", "phrase": "Holmes vive, doctor.", "ents": ["holmes"]}, "3.M")
	h.advance_to("4.night")
	eq(int(h.st.flags.get("hb4_veces", 0)), 2)
	eq(int(h.st.flags.get("consulta_cerrada_hasta", 0)), 5, "cierra la consulta dos días desde el día 3")
	has(load("res://core/react/effects.gd").lines(h.st, "watson"), "vuelva_usted")

func test_hb13_inactivity():
	var h = H.new(R())
	h.ev("slip", {"seat": 1, "doc": "D05", "title": "t", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	h.advance_to("1.night")
	eq(h.queued("HB13").size(), 1, "M con acto observado, T y N vacías: dos franjas seguidas → HB13")
	eq(int(h.st.react.inactivity.slots), 0, "se reinicia tras disparar")
	var h2 = H.new(R())
	h2.ev("slip", {"seat": 1, "doc": "D05", "title": "t", "topic": "holmes_prensa_1891", "hour": "15:00"}, "1.T")
	h2.advance_to("1.night")
	eq(h2.queued("HB13").size(), 0, "sólo N sin actos")
	h2.advance_to("2.night")
	eq(h2.queued("HB13").size(), 1, "N del 1, M, T y N del 2 sin actos observados")
	h2.advance_to("3.dawn")
	eq(h2.find("HB13").size(), 1)
	var t := String(h2.text("HB13"))
	ok(["no sale", "dos veces", "Sala de Periódicos"].any(func(x): return t.contains(x)), t)

func test_watson_expuesto_silences_voice_b_but_not_guaranteed():
	var h = H.new(R())
	h.st.flags["watson_expuesto"] = true
	h.st.flags["canal_cerrado.K-T"] = true
	h.st.flags["canal_cerrado.K-BM"] = true
	_bait(h, "1.T", "watson", "pared")
	_ad(h, 2, "cayeron")
	h.ev("slip", {"seat": 7, "doc": "D03", "title": "t", "topic": "holmes_cronicas", "hour": "10:00"}, "2.M")
	h.advance_to("10.night")
	var tpls: Array = []
	for i in _all(h, "HB1"):
		tpls.append(String(i.tpl))
	eq(tpls, ["cayeron.1"], "sólo el primer cebo publicado (garantizado): " + str(tpls))
	eq(h.find("HA1").size(), 1, "HA1 garantizada aunque el canal esté cerrado")

func test_posture_and_tone():
	var h = H.new(R())
	eq(HolmesAgent.tone(h.st), "bajo")
	h.ev("slip", {"seat": 9, "doc": "D13", "title": "despachos de Sigerson", "topic": "sigerson", "hour": "10:00"}, "1.M")
	h.advance_to("4.night")
	eq(h.find("HB3").size(), 1, "Sigerson → HB3 (noticia comunicada)")
	eq(String(h.first("HB3").how), "noticias")
	ok(int(h.st.react.holmes.posture) >= 3, "postura sube por exposición visible")
	h.st.react.holmes.confidence = 1
	eq(HolmesAgent.tone(h.st), "alto")

func test_blind_to_notebook():
	# El agente sólo recibe observaciones: el cuaderno (st.ded) no cambia nada.
	var r = R()
	var h1 = H.new(r)
	var h2 = H.new(r)
	h2.st.ded = {"clips": {"RC0001": {"tags": ["a:cornisa_existe"]}}, "entries": {"AS001": {}}, "sealed": {"C2": "AS001"}}
	for h in [h1, h2]:
		_bait(h, "1.T", "watson", "pared")
		_ad(h, 3, "pared")
		h.advance_to("8.night")
	eq(h1.signature(), h2.signature())
