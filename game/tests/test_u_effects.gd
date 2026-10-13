# Unit: core/react/effects.gd (W2-REACT). Documentos runtime, Ley 5 (privado nunca en la columna), flags del registro,
# estado de mundo y sus accesores, texto con variables y tono, desborde tras el día 10.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Effects = preload("res://core/react/effects.gd")
const Director = preload("res://core/react/director.gd")
const Markup = preload("res://core/text/markup.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func after_each() -> void:
	H.cleanup()

func R():
	return fixture_repo("react/data")

func _inst(h, rid: String, due: String, extra := {}) -> Dictionary:
	var rule: Dictionary = h.repo.reaction(rid)
	var c := {"rid": rid, "channel": String(extra.get("channel", "")), "anchor": extra.get("anchor", {"tk": TimeKey.parse(due), "day": TimeKey.day_of(TimeKey.parse(due))}),
		"n": int(extra.get("n", 1)), "guaranteed": false, "once": "", "src_ev": 0, "act_tk": TimeKey.parse(due), "fixed_due": TimeKey.parse(due)}
	return Director._make_inst(h.st, h.repo, rule, c, TimeKey.parse(due))

func test_voice_a_letter_document():
	var h = H.new(R())
	h.ev("slip", {"seat": 214, "doc": "D05", "title": "el Journal de Genève", "topic": "holmes_prensa_1891", "hour": "10:15"}, "1.M")
	h.advance_to("2.dawn")
	var ha1: Dictionary = h.first("HA1")
	var doc: Dictionary = h.sink.docs[ha1.iid]
	var tpl: Dictionary = doc.tpl
	eq(String(tpl.font), "maquina")
	eq(String(tpl.machine), "remington_cotter", "la Remington con la «s» alzada")
	eq(String(tpl.paper), "diogenes_recortado")
	no(tpl.has("measure"), "v2 (§C.5): sin regla; la medida va en la línea física de la plantilla")
	eq(tpl.paper_mm, [203, 244], "20 × 24 cm: un centímetro menos que el papel del club")
	eq(String(tpl["class"]), "P")
	eq(String(tpl.entity), "cartas_a_maquina")
	eq(String(doc.meta.act), "act.1", "la entidad del acto ancla")
	var text := String(tpl.parts[0].text)
	ok(text.ends_with("—Un amigo de la exactitud"), "firma de la voz A: " + text)
	var p := Markup.parse(text, {"act": "act.1"})
	eq(p.errors, [], "marcado válido")
	ok(p.plain.begins_with("Asiento 214"), p.plain)
	var anchors := false
	for t in p.tramos:
		if t.tags.a.has("ancla_kbm"):
			anchors = true
	ok(anchors, "etiqueta ancla_kbm para C6")
	var mention := false
	for m in p.mentions:
		if m.ent == "act.1":
			mention = true
	ok(mention, "[[@act|…]] = entidad del acto (enlaza con el diario)")
	eq(String(h.sink.deliveries[h.sink.deliveries.size() - 1].how), "correo")

func test_column_document():
	var h = H.new(R())
	h.ev("ad", {"ad": "AD.1", "form": "testigo", "text": "Se busca testigo de la cascada del Reichenbach. Escribir a E. L., Holywell Street.", "pub_day": 1, "prologue": true}, "1.dawn")
	h.advance_to("4.dawn")
	var hc10: Dictionary = h.first("HC10")
	eq(String(hc10.how), "columna")
	var tpl: Dictionary = h.sink.docs[hc10.iid].tpl
	eq(String(tpl.origin), "D15.0330", "comparte origen con el Times del día")
	eq(String(tpl["class"]), "I")
	eq(String(tpl.insert.doc), "D15.0330")
	eq(String(tpl.insert.part), "columna")
	eq(String(tpl.entity), "times_0330")
	eq(String(hc10.anchor.act), "act.1", "el ancla es el aviso del prólogo")
	ok(String(hc10.text).begins_with("AL LECTOR DE HOLYWELL STREET"))

func test_private_never_in_column():
	var h = H.new(R())
	var inst := _inst(h, "HB1", "5.dawn", {"channel": "K-W", "anchor": {"type": "say", "tk": TimeKey.parse("2.M"), "day": 2, "bait_topic": "pared", "privado_kw": true}})
	inst.channel = "K-W"
	Effects.apply(h.st, h.repo, inst, false)
	eq(String(inst.how), "correo", "K-W → carta «—S.», nunca la columna (Ley 5, T23)")
	# aunque una regla mal escrita pida columna, lo privado se fuerza a carta
	var inst2 := _inst(h, "HB7", "5.dawn", {"channel": "K-H"})
	inst2.channel = "K-H"
	Effects.apply(h.st, h.repo, inst2, false)
	ne(String(inst2.how), "columna")

func test_flags_only_from_registry():
	var h = H.new(R())
	ok(Effects._set_flag(h.st, "watson_avisado", true))
	ok(Effects._set_flag(h.st, "canal_cerrado.K-W", true))
	no(Effects._set_flag(h.st, "errata_ofrecida", "mycroft"), "errata_ofrecida la escribe Dialogue/Confrontation")
	no(Effects._set_flag(h.st, "forasteros_cerrada", true))
	no(h.st.flags.has("errata_ofrecida"))
	var notes: Array = h.st.notes
	var flagged := false
	for n in notes:
		if n.kind == "flag" and n.payload.name == "watson_avisado":
			flagged = true
	ok(flagged, "aviso «flag» a la UI (nunca «reaction»)")
	for n in notes:
		ne(String(n.kind), "reaction")

func test_withdraw_and_access_accessors():
	var h = H.new(R())
	var inst := _inst(h, "M1", "3.M", {"anchor": {"tk": 24, "day": 2, "copies": ["D02@L1", "D21@L1"]}})
	Effects.apply(h.st, h.repo, inst, false)
	eq(Effects.withdrawn(h.st, TimeKey.parse("3.T")), ["D02@L1", "D21@L1"])
	no(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("2.N")), "antes del registro está")
	no(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("4.dawn")), "falta como mucho un día")
	var soft := _inst(h, "M1", "3.M", {"anchor": {"tk": 24, "day": 2, "copies": ["D05@BM"]}})
	Effects.apply(h.st, h.repo, soft, true)
	no(Effects.copy_withdrawn(h.st, "D05@BM", TimeKey.parse("3.T")), "variante blanda: registran sin llevarse originales")
	eq(Effects.place_variant(h.st, "L1"), "registrada")
	var hb4 := _inst(h, "HB4", "4.dawn", {"n": 2, "anchor": {"tk": TimeKey.parse("3.M"), "day": 3}})
	Effects.apply(h.st, h.repo, hb4, false)
	eq(int(h.st.flags.consulta_cerrada_hasta), 5)
	ok(Effects.access_closed(h.st, "L4.consulta", 5))
	no(Effects.access_closed(h.st, "L4.consulta", 6))
	no(Effects.access_closed(h.st, "L5.forasteros", 5))

func test_silhouettes_replace():
	var h = H.new(R())
	h.advance_to("3.dawn")
	eq(Effects.silhouettes(h.st, "L2", 2), [], "Wiggins desde el día 3")
	eq(Effects.silhouettes(h.st, "L2", 3), ["wiggins"])
	var hb8b := _inst(h, "HB8b", "5.dawn", {"n": 2})
	Effects.apply(h.st, h.repo, hb8b, false)
	eq(Effects.silhouettes(h.st, "L4", 5), ["muchacho_sin_gorra"], "HB8b: otro muchacho, sin gorra")
	ok(bool(h.st.flags.wiggins_quemado))

func test_text_vars_and_tone():
	var h = H.new(R())
	var inst := _inst(h, "HB1", "5.dawn", {"channel": "K-H", "n": 1, "anchor": {"tk": 21, "day": 2, "bait_topic": "pared", "act": "act.9"}})
	inst.channel = "K-H"
	inst.vars = {}
	var t := Effects.instance_text(h.st, h.repo, inst)
	ok(t.contains("a:ancla_kh"), "${ch} resuelto: " + t)
	no(t.contains("${"), "sin placeholders")
	# tono: alternativa por confianza
	var rule := {"id": "X", "rastro": [{"tpl": "t", "tono": {"alto": "Bien visto; no del todo.", "bajo": "Tut."}}]}
	ok(Effects._block_text(h.st, FakeRepo.new(rule), {"rid": "X", "tpl": "t", "tono": "alto", "vars": {"x": 1}}) == "Bien visto; no del todo.")
	ok(Effects._block_text(h.st, FakeRepo.new(rule), {"rid": "X", "tpl": "t", "tono": "bajo", "vars": {"x": 1}}) == "Tut.")

class FakeRepo:
	var r: Dictionary
	func _init(p: Dictionary) -> void:
		r = p
	func reaction(_id: String) -> Dictionary:
		return r

func test_scene_and_lines():
	var h = H.new(R())
	h.advance_to("8.dawn")
	ok(h.st.react.world.scenes.has("HC05") and h.st.react.world.scenes.has("HC06"), "escenas fijas del día 8")
	var scene_notes := 0
	for n in h.st.notes:
		if n.kind == "scene":
			scene_notes += 1
	ok(scene_notes >= 3, "aviso «scene» (M6, M7, HC05, HC06…)")
	var hb6 := _inst(h, "HB6", "9.dawn")
	Effects.apply(h.st, h.repo, hb6, false)
	eq(Effects.lines(h.st, "mrs_hudson"), ["ordenes_del_empleado"])
	ok(bool(h.st.flags.hudson_cerrada))
	ok(Effects.access_closed(h.st, "L3.recibos", 9))

func test_overflow_only_flags():
	var h = H.new(R())
	var inst := _inst(h, "HB9", "11.dawn", {"n": 2})
	inst["overflow"] = true
	Effects.apply(h.st, h.repo, inst, false)
	ok(bool(h.st.flags.get("watson_expuesto", false)), "el flag sí (fusionar con el día 10)")
	eq(h.sink.docs.size(), 0, "ningún documento después del día 10")
	no(inst.has("view"))

func test_merged_letter_text():
	var h = H.new(R())
	h.ev("slip", {"seat": 214, "doc": "D05", "title": "t", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "cn.chelsea", "topic": "lisle_mudanza", "canary": "lisle_mudanza", "phrase": "Me mudo a Chelsea."}, "1.T")
	h.advance_to("2.dawn")
	var ha1: Dictionary = h.first("HA1")
	var ha4: Dictionary = h.first("HA4")
	eq(String(ha4.merged_into), String(ha1.iid), "dos de voz A la misma mañana: una carta")
	eq(String(ha4.view), String(ha1.view))
	var t := String(h.sink.docs[ha1.iid].tpl.parts[0].text)
	ok(t.contains("Asiento 214") and t.contains("Chelsea"), t)
	eq(t.count("—Un amigo de la exactitud"), 1, "una firma")
	eq(h.sink.docs.size(), 2, "HC01 y la carta fusionada")

func test_inline_effects_from_dialogue_line():
	# Dialogue: Effects.apply(st, repo, {iid:"LINE.<uid>", rid:"", efecto:[ops], char, line, anchor}, false)
	var h = H.new(R())
	var inst := {"iid": "LINE.LN0007", "rid": "", "efecto": [{"op": "flag", "name": "hudson_cerrada", "value": true},
		{"op": "linea", "char": "mrs_hudson", "line": "mas_sir"}, {"op": "flag", "name": "errata_ofrecida", "value": "mycroft"}],
		"char": "mrs_hudson", "line": "x", "anchor": {"phrase": "¿Y los recibos?"}, "tk": 21}
	Effects.apply(h.st, h.repo, inst, false)
	ok(bool(h.st.flags.get("hudson_cerrada", false)))
	no(h.st.flags.has("errata_ofrecida"), "los flags de otros dueños no los escribe Effects")
	eq(Effects.lines(h.st, "mrs_hudson"), ["mas_sir"])
	eq(Effects.lines(h.st, "mrs_hudson", 20), [], "desde el tk de la línea (inst.tk)")
	eq(h.sink.docs.size(), 0)

func test_desde_and_wildcard_channel():
	eq(Effects._day_spec("3.dawn", 1), 3)
	eq(Effects._day_spec("+1", 5), 6)
	eq(Effects._day_spec(4, 1), 4)
	eq(Effects._day_spec(null, 7), 7)
	var h = H.new(R())
	var rule := {"id": "X", "efecto": [{"op": "cerrar", "target": "canal:*", "dias": null}]}
	ok(Effects._apply_op(h.st, h.repo, rule, {"iid": "R.X.1", "rid": "X", "channel": "K-H", "due_tk": 41, "anchor": {"day": 4}}, rule.efecto[0]))
	ok(bool(h.st.flags.get("canal_cerrado.K-H", false)), "canal:* = el canal de la instancia")

func test_soft_variant_nodes():
	# HB5 blanda: no se llevan las pruebas → no hay recibo «p.p. M. H.»; dura: sí.
	var h = H.new(R())
	var soft := _inst(h, "HB5", "4.dawn", {"n": 2, "channel": "K-W"})
	Effects.apply(h.st, h.repo, soft, true)
	eq(Effects.extra_nodes(h.st, "L4", TimeKey.parse("4.M")), [], "blanda: sin recibo")
	no(Effects.copy_withdrawn(h.st, "D29a@L4", TimeKey.parse("4.M")))
	var hard := _inst(h, "HB5", "5.dawn", {"n": 2, "channel": "K-W"})
	Effects.apply(h.st, h.repo, hard, false)
	eq(Effects.extra_nodes(h.st, "L4", TimeKey.parse("5.M")).size(), 1, "dura: recibo")
	ok(Effects._node_in_effects("N:L1.ceniza_registro", [{"op": "alterar_lugar", "place": "L1"}]))
	ok(Effects._node_in_effects("L:chico_del_agente.ayer_vino", [{"op": "linea", "char": "chico_del_agente", "line": "ayer_vino"}]))
	no(Effects._node_in_effects("L:mrs_hudson.ordenes", [{"op": "evento_mundo", "id": "x"}]))

func test_no_empty_document():
	# Un efecto documental sin rastro con texto para ese ancla/canal no deja un sobre vacío en la bandeja.
	var h = H.new(R())
	var inst := {"iid": "LINE.LN0001", "rid": "", "efecto": [{"op": "carta"}, {"op": "flag", "name": "hudson_cerrada", "value": true}],
		"char": "mrs_hudson", "line": "x", "anchor": {}, "tk": 31, "due_tk": 31}
	Effects.apply(h.st, h.repo, inst, false)
	eq(h.sink.docs.size(), 0, "sin documento")
	eq(h.sink.deliveries.size(), 0, "sin entrega")
	ok(bool(h.st.flags.get("hudson_cerrada", false)), "los efectos de mundo siguen")
	no(inst.has("view"))

func test_world_model_bridge_devolver():
	# HB10 con WorldModel real: «devolver» levanta el retiro sin «entregar» el ejemplar como documento runtime (eso
	# sería un L.bug de WorldModel.deliver); la tarjeta de la reacción sí llega por el mostrador de Crane.
	if not FileAccess.get_file_as_string("res://core/sim/world_model.gd").contains("func return_copy"):
		skip("WorldModel sin return_copy")
		return
	var wm = load("res://core/sim/world_model.gd")
	var h = H.new(R())
	Effects.sink = null
	wm.init_state(h.st, h.repo)
	h.ev("report", {"n": 1, "mode": "items", "items": [{"kind": "clip", "id": "RC1", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]}]}, "2.night")
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "3.M")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("3.T")))
	h.advance_to("4.dawn")
	var hb10: Dictionary = h.first("HB10")
	ok(not hb10.is_empty(), "HB10")
	eq(str(hb10.get("returned", [])), str(["D02@L1"]))
	no(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("4.M")), "devuelto")
	var hows: Array = []
	for t in h.st.world.tray:
		hows.append(String(t.how))
		ne(String(t.view), "D02@L1")
	has(hows, "mostrador_crane", "la tarjeta del paquete")

func test_world_model_bridge():
	# Integración con W2-SIM: sin sink, Effects crea y entrega el documento con WorldModel (cargado con load()).
	var wm = load("res://core/sim/world_model.gd")
	if not FileAccess.get_file_as_string("res://core/sim/world_model.gd").contains("func instantiate_doc"):
		skip("WorldModel sin instantiate_doc")
		return
	var h = H.new(R())
	Effects.sink = null
	wm.init_state(h.st, h.repo)
	h.st.clock = {"day": 2, "slot": "dawn", "phase": "desk"}
	h.st.set("now_tk", TimeKey.parse("2.dawn"))
	var inst := _inst(h, "HA1", "2.dawn", {"channel": "K-BM", "anchor": {"tk": 11, "day": 1, "seat": 214, "topic": "holmes_prensa_1891", "act": "act.3"}})
	inst.tpl = "holmes_prensa_1891"
	Effects.apply(h.st, h.repo, inst, false)
	var view := String(inst.get("view", ""))
	ok(h.st.world.docs.has(view), "documento runtime en st.world.docs: " + view)
	var tray_views: Array = []
	for t in h.st.world.tray:
		tray_views.append(String(t.view))
	has(tray_views, view, "en la bandeja")
