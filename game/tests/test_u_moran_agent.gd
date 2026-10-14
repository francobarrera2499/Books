# Unit: core/react/moran_agent.gd (W2-REACT). Informes → flags y M1–M12; report_cats por valores y procedencia visible.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const MoranAgent = preload("res://core/react/moran_agent.gd")
const Effects = preload("res://core/react/effects.gd")
const GameState = preload("res://core/sim/game_state.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func after_each() -> void:
	H.cleanup()

func R():
	return fixture_repo("react/data")

func _report(h, n: int, tk: String, items: Array, mode := "items") -> Dictionary:
	return h.ev("report", {"n": n, "mode": mode, "items": items}, tk)

func _it(cats: Array, copies := [], cls := []) -> Dictionary:
	return {"kind": "clip", "id": "RC0001", "cats": cats, "copies": copies, "cls": cls}

func test_report_flags():
	var h = H.new(R())
	_report(h, 1, "2.night", [_it(["verdadero"])])
	ok(bool(h.st.flags.get("moran_credito", false)), "dato verdadero en informe 1–3 → crédito")
	ok(MoranAgent.has_credit(h.st))
	_report(h, 2, "5.night", [], "nada")
	eq(int(h.st.flags.get("informes_vacios", 0)), 1, "«Sin novedad» erosiona")
	_report(h, 3, "8.night", [_it(["falso_verificable"])])
	ok(bool(h.st.flags.get("moran_credito_perdido", false)), "M9: pierde el crédito")
	no(MoranAgent.has_credit(h.st))
	no(bool(h.st.flags.get("holmes_entregado", false)))
	_report(h, 4, "10.M", [_it(["paradero_extranjero"])])
	ok(bool(h.st.flags.get("holmes_entregado", false)), "un paradero de Holmes entregado bloquea F1")
	eq(h.st.react.moran.reports.size(), 4)

func test_final_report_no_credit():
	var h = H.new(R())
	_report(h, 4, "10.M", [_it(["verdadero"])])
	no(bool(h.st.flags.get("moran_credito", false)), "el informe final no da crédito")

func test_m1_withdraws_and_hb10_returns():
	var h = H.new(R())
	_report(h, 1, "2.night", [_it(["original_p"], ["D02@L1"], ["P"])])
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "3.M")
	var m1: Dictionary = h.first("M1")
	ok(not m1.is_empty(), "M1 en la primera salida")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("3.T")), "la galerada falta")
	eq(Effects.place_variant(h.st, "L1"), "registrada")
	eq(Effects.extra_nodes(h.st, "L1", TimeKey.parse("3.T")).size(), 1, "ceniza de cheroot en la buhardilla")
	h.advance_to("4.dawn")
	var hb10: Dictionary = h.first("HB10")
	ok(not hb10.is_empty(), "HB10 a la mañana siguiente")
	eq(String(hb10.how), "mostrador_crane")
	no(Effects.copy_withdrawn(h.st, "D02@L1", TimeKey.parse("4.M")), "devueltos intactos")
	var back := false
	for d in h.sink.returns:
		if String(d.copy) == "D02@L1" and int(d.day) == 4:
			back = true
	ok(back, "el original vuelve (WorldModel.return_copy): " + str(h.sink.returns))
	for d in h.sink.deliveries:
		ne(String(d.view), "D02@L1", "un ejemplar no se «entrega» como documento runtime")
	ok(String(hb10.text).contains("Ponga cerrojo"), hb10.text)

# M1 se lleva «esos originales»: sólo ejemplares P de recortes informados; un asiento (se lee por sus valores) no
# aporta sus ejemplares y nunca se retira un ejemplar I (D9).
func test_m1_only_p_copies_of_clips():
	var h = H.new(R())
	_report(h, 1, "2.night", [_it(["original_p"], ["D02@L1"], ["P"]),
		{"kind": "entry", "id": "AS001", "cats": ["verdadero"], "copies": ["D05@BM", "D03@tomo"], "cls": ["I", "P"]}])
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "3.M")
	eq(h.first("M1").get("anchor", {}).get("copies", []), ["D02@L1"])
	eq(Effects.withdrawn(h.st, TimeKey.parse("3.T")), ["D02@L1"], "nada del asiento")
	# con data/docs: la clase de cada ejemplar manda
	var RDB = load("res://core/react/reaction_db.gd")
	var dm = fixture_repo("data_min")
	var src := {"type": "report", "items": [
		{"kind": "clip", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]},
		{"kind": "clip", "cats": ["original_p"], "copies": ["D03@Crane"], "cls": ["P"]},
		{"kind": "clip", "cats": ["original_p"], "copies": ["R.HA1.3"], "cls": ["P"]},
		{"kind": "clip", "cats": ["original_p"], "copies": ["R.HC10.4"], "cls": ["I", "P"]},
		{"kind": "entry", "cats": ["original_p"], "copies": ["D05@BM", "D03@tomo"], "cls": ["I", "P"]}]}
	eq(RDB.report_p_copies(dm, src), ["D02@L1", "D03@tomo", "R.HA1.3"], "D03@Crane y D05@BM son I; R.HC10.4 sin clase propia en un elemento mixto")

func test_m3_hb9_then_watson_expuesto():
	var h = H.new(R())
	_report(h, 1, "2.night", [_it(["watson_privado"])])
	h.advance_to("4.night")
	eq(h.day_of_delivery("M3"), 3)
	has(Effects.silhouettes(h.st, "L4", 3), "m3_hombres")
	eq(h.day_of_delivery("HB9"), 4, "Wiggins ve a los hombres y Cotter avisa")
	ok(bool(h.st.flags.get("watson_avisado", false)))
	no(bool(h.st.flags.get("watson_expuesto", false)), "el primer aviso no marca nada")
	_report(h, 2, "5.night", [_it(["watson_privado"])])
	h.advance_to("8.night")
	ok(bool(h.st.flags.get("watson_expuesto", false)), "segunda entrega tras HB9")
	eq(h.find("HB9").size(), 2)
	ok(String(h.find("HB9")[1].text).contains("Se lo dije"))

func test_m4_pell_fired_then_h_notes():
	var h = H.new(R())
	_report(h, 1, "2.night", [{"kind": "entry", "id": "AS001", "cats": ["moran_autor"], "copies": [], "cls": []}])
	h.advance_to("3.dawn")
	eq(h.find("M4").size(), 1)
	ok(bool(h.st.flags.get("pell_despedido", false)))
	ok(String(h.text("M4")).contains("no me nombre"))
	ok(String(h.text("M4")).ends_with("—J. Pell"), "la nota temblorosa la firma Pell: " + h.text("M4"))
	h.advance_to("5.dawn")
	var m6: Dictionary = h.first("M6")
	ok(String(m6.text).ends_with("—H."), "desde M4, «H.»: " + String(m6.text))
	ok(String(h.sink.docs[m6.iid].tpl.title).contains("«H.»"))

func test_next_communication_lines():
	var h = H.new(R())
	h.ev("go", {"place": "L3", "area": "calle", "streets": ["Baker Street"], "hour": "10:00"}, "1.M")
	eq(h.st.react.moran.next_lines.size(), 1, "M10 espera la próxima comunicación")
	h.advance_to("5.dawn")
	ok(String(h.text("M6")).contains("diligencia en Baker Street"), "se adjunta a la nota de Pell: " + h.text("M6"))
	eq(h.st.react.moran.next_lines.size(), 0)
	h.ev("go", {"place": "L8", "area": "interior", "streets": ["Baker Street"], "hour": "10:00"}, "7.T")
	eq(h.st.react.moran.next_lines.size(), 0, "M10 una sola vez")

func test_m11_follows_after_s_column_from_day5():
	var h = H.new(R())
	h.ev("ad", {"ad": "AD.1", "form": "a_proposito", "text": "x", "assertion": "as.pared", "bait_topic": "pared", "pub_day": 2}, "2.dawn")
	h.advance_to("6.night")
	eq(h.day_of_delivery("HB1"), 5, "«—S.» contesta en la columna el día 5")
	eq(h.day_of_delivery("M11"), 6, "el hombre de Moran lo sigue desde el día siguiente")
	ok(bool(h.st.flags.get("seguido_por_cochero", false)))
	has(Effects.silhouettes(h.st, "L2", 6), "cochero")
	h.advance_to("7.night")
	ok(Effects.scene_extra(h.st, "M7").size() >= 1, "la línea va con M7: " + str(Effects.scene_extra(h.st, "M7")))
	var h2 = H.new(R())
	h2.ev("ad", {"ad": "AD.1", "form": "testigo", "text": "Se busca testigo", "pub_day": 1, "prologue": true}, "1.dawn")
	h2.advance_to("6.night")
	eq(h2.find("M11").size(), 0, "HC10 (día 4) no despierta a Moran")

# M10–M12 en la voz de quien comunica (data/ real): Pell transmite en tercera persona («El mayor…»); Harris en persona
# (M7) o firmando «H.» (tras M4) habla en primera persona: nunca «El mayor» en boca de Harris. Mismas etiquetas.
func test_next_lines_voice_real_data():
	var h = H.new(repo())
	_report(h, 2, "5.night", [{"kind": "entry", "id": "AS009", "cats": ["paradero_extranjero"], "copies": [], "cls": []}])
	h.advance_to("7.night")
	var ex: Array = Effects.scene_extra(h.st, "M7")
	eq(ex.size(), 1, str(ex))
	ok(String(ex[0]).contains("No cazo en monte ajeno") and String(ex[0]).contains("a:busca_a_holmes"), str(ex))
	no(String(ex[0]).contains("mayor"), "Harris no habla de sí en tercera persona: " + str(ex))
	var h2 = H.new(repo())
	h2.ev("go", {"place": "L3", "area": "calle", "streets": ["Baker Street"], "hour": "10:00"}, "1.M")
	h2.advance_to("5.dawn")
	var m6: Dictionary = h2.first("M6")
	var t6 := String(m6.get("text", "")) + str(Effects.scene_extra(h2.st, "M6"))
	ok(t6.contains("El mayor") and t6.contains("celebra su diligencia"), "Pell transmite: " + t6)
	var h3 = H.new(repo())
	_report(h3, 1, "2.night", [{"kind": "entry", "id": "AS001", "cats": ["moran_autor"], "copies": [], "cls": []}])
	h3.advance_to("3.dawn")
	ok(bool(h3.st.flags.get("pell_despedido", false)))
	h3.ev("go", {"place": "L3", "area": "calle", "streets": ["Baker Street"], "hour": "10:00"}, "3.M")
	h3.advance_to("5.dawn")
	var t3 := h3.text("M6")
	ok(t3.contains("Celebro su diligencia") and t3.ends_with("—H."), "nota «H.» en primera persona: " + t3)
	no(t3.contains("El mayor celebra"), t3)

func test_m12_paradero():
	var h = H.new(R())
	_report(h, 2, "5.night", [{"kind": "entry", "id": "AS009", "cats": ["paradero_extranjero"], "copies": [], "cls": []}])
	eq(h.st.react.moran.next_lines.size(), 1)
	h.advance_to("7.night")
	ok(Effects.scene_extra(h.st, "M7").size() == 1 and String(Effects.scene_extra(h.st, "M7")[0]).contains("monte ajeno"))

# ---------------- report_cats ----------------
func _st_with(clips: Dictionary, entries: Dictionary):
	var st = GameState.new()
	st.ded = {"clips": clips, "entries": entries, "sealed": {}}
	st.react = {}
	return st

func test_report_cats_clips():
	var r = R()
	var st = _st_with({}, {})
	var c1 := {"kind": "clip", "id": "RC1", "clip": {"id": "RC1", "tags": ["a:cornisa_existe", "c:holmes_vive"], "cls": "I", "view": "D05@BM"}}
	eq(MoranAgent.report_cats(st, r, c1), ["holmes_vive"], "por c:, nunca por a:")
	var c2 := {"kind": "clip", "id": "RC2", "clip": {"id": "RC2", "tags": [], "cls": "P", "copy": "D02@L1", "view": "D02@L1"}}
	eq(MoranAgent.report_cats(st, r, c2), ["original_p"], "clase P → original_p")
	var c3 := {"kind": "clip", "id": "RC3", "clip": {"id": "RC3", "tags": [], "cls": "C", "doc_cats": ["watson_privado"]}}
	eq(MoranAgent.report_cats(st, r, c3), ["watson_privado"], "procedencia visible")
	var c4 := {"kind": "clip", "id": "RC4", "clip": {"id": "RC4", "tags": [], "cls": "P", "origin": "R.HB1.7", "view": "R.HB1.7"}}
	var cats := MoranAgent.report_cats(st, r, c4)
	has(cats, "respuesta_s", "una respuesta «—S.»")
	has(cats, "original_p")
	var item := MoranAgent.report_item(st, r, c2)
	eq(item.copies, ["D02@L1"])
	eq(item.cls, ["P"])

func test_report_cats_clip_from_state():
	var r = R()
	var st = _st_with({"RC9": {"id": "RC9", "tags": ["c:camden"], "cls": "C"}}, {})
	eq(MoranAgent.report_cats(st, r, {"kind": "clip", "id": "RC9"}), ["camden"])

func test_report_cats_entries_template_values():
	var r = R()
	var mk := func(lugar: String) -> Dictionary:
		return {"template": "T8", "lines": [{"fields": {"persona": "holmes"}, "support": []}, {"fields": {"lugar": lugar}, "support": []}, {"fields": {"dia": "jueves"}, "support": []}]}
	var st = _st_with({}, {"A1": mk.call("montpellier"), "A2": mk.call("fleet_street"), "A3": mk.call("baker_street")})
	has(MoranAgent.report_cats(st, r, {"kind": "entry", "id": "A1"}), "paradero_extranjero")
	var a2 := MoranAgent.report_cats(st, r, {"kind": "entry", "id": "A2"})
	has(a2, "falso_verificable", "un lugar de Londres inventado")
	var a3 := MoranAgent.report_cats(st, r, {"kind": "entry", "id": "A3"})
	has(a3, "baker_street")
	no(a3.has("falso_verificable"), "Baker Street es verdadero")
	eq(MoranAgent.report_item(st, r, {"kind": "entry", "id": "A1"}).values, {"persona": "holmes", "lugar": "montpellier", "dia": "jueves"})

# v3 (GDD_v3 §6.10): Moran lee una PREGUNTA informada por su respuesta visible y su estado (lápiz/tinta), nunca por si
# cierra. «Harris» cuenta como Moran (Moran sabe quién es). Q1/Q2 sólo dan crédito en tinta.
func _st_q(answers: Dictionary, inked: Array = []):
	var st = GameState.new()
	st.ded = {"clips": {}}
	st.react = {}
	st.clock = {"day": 5, "slot": "M", "phase": "desk"}
	var born := {}
	var drafts := {}
	var ink := {}
	var n := 0
	for q in answers:
		n += 1
		born[q] = {"tk": 41, "via": "test", "origin": "", "n": n}
		if inked.has(q):
			ink[q] = {"tk": 51, "variant": "A", "answer": String(answers[q]), "proofs": ["", ""], "n": n}
		else:
			drafts[q] = {"answer": String(answers[q]), "proofs": ["", ""]}
	st.ded["dossier"] = {"born": born, "open": {}, "waiting": [], "drafts": drafts, "inked": ink, "attempts": {}, "noticed": {}, "seen": {}, "shown_n": n}
	return st

func test_report_cats_questions_by_visible_answer():
	var r = repo()
	if r.question("Q7").is_empty():
		pending_content("data/dossier.json sin preguntas (CORE)")
		return
	var st = _st_q({"Q7": "moran", "Q6": "harris", "Q5": "holmes", "Q10": "watson", "Q1": "raspadura", "Q2": "cornisa", "Q9": "watson", "Q8": "wiggins"}, ["Q2"])
	var cats := func(q: String) -> Array:
		return MoranAgent.report_cats(st, r, {"kind": "pregunta", "id": q})
	has(cats.call("Q7"), "moran_autor", "Q7 con Moran en lápiz y sin pruebas: Moran lee la respuesta, no si cierra")
	has(cats.call("Q6"), "moran_autor", "«Harris» cuenta como Moran")
	has(cats.call("Q5"), "holmes_vive")
	has(cats.call("Q10"), "falso_verificable", "Q10 en lápiz con una persona que no es Holmes, Moran ni Harris")
	no(cats.call("Q1").has("verdadero"), "Q1 en lápiz no da crédito")
	has(cats.call("Q2"), "verdadero", "Q2 en tinta, sí")
	has(cats.call("Q9"), "moran_autor", "Q9 con cualquier respuesta")
	no(cats.call("Q8").has("moran_autor"), "Q8 con el muchacho no nombra a Moran")
	eq(MoranAgent.report_cats(st, r, {"kind": "pregunta", "id": "Q3"}), [], "pregunta no nacida: nada")
	var st2 = _st_q({"Q10": "holmes"})
	var c10 := MoranAgent.report_cats(st2, r, {"kind": "pregunta", "id": "Q10"})
	has(c10, "regreso_jueves")
	has(c10, "baker_street")
	no(c10.has("falso_verificable"))
	var st3 = _st_q({"Q10": "harris"})
	has(MoranAgent.report_cats(st3, r, {"kind": "pregunta", "id": "Q10"}), "camden")
	var it := MoranAgent.report_item(st, r, {"kind": "pregunta", "id": "Q7"})
	eq(String(it.kind), "pregunta")
	eq(it.values, {"respuesta": "moran"})
