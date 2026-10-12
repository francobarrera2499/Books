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

func test_report_cats_entries_by_values():
	# entry_conclusions usa Validator.values_match (W2-DED). Con el stub no hay coincidencias: se salta.
	var r = fixture_repo("data_min")
	var val = load("res://core/deduction/validator.gd")
	var e := {"template": "T2", "lines": [{"fields": {"fuente": "fina", "calla": "raspadura"}, "support": []}, {"fields": {"consta_en": "galerada"}, "support": []}]}
	if not val.values_match(r, e, "C2", {}):
		skip("Validator.values_match todavía es stub (W2-DED)")
		return
	var st = _st_with({}, {"A1": e})
	var lists: Dictionary = r.lists()
	var has_c2 := false
	for c in lists.get("report_cats", []):
		if c.get("entry_conclusions", []).has("C2"):
			has_c2 = true
	if has_c2:
		has(MoranAgent.report_cats(st, r, {"kind": "entry", "id": "A1"}), "verdadero")
