# W2-DED: libro mayor (folios, asientos a lápiz, chequeo formal; §5.2, GDD§8.3–8.5). Fixture tests/fixtures/ded.
# T14: los tests pueden llamar Ledger.create_folio (tests/ queda fuera del lint).
extends "res://tests/test_base.gd"

const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const Ledger = preload("res://core/deduction/ledger.gd")
const FakeState = preload("res://tests/fixtures/ded/fake_state.gd")

var r

func before_each() -> void:
	r = fixture_repo("ded")
	Clipper.test_access = func(_st, _repo, _kind, _ref): return true

func after_each() -> void:
	Clipper.test_access = Callable()

func _st():
	var st = FakeState.new()
	st.clock = {"day": 3, "slot": "M", "phase": "desk"}
	Clipper.init_state(st, r)
	Ledger.init_state(st, r)
	return st

func _clip(st, view: String, part, needle: String) -> String:
	var cp: Dictionary = r.copy(view)
	var pid: String = part if typeof(part) == TYPE_STRING else String(r.doc(cp.doc).parts[int(part)].id)
	var plain: String = r.parsed(cp.doc, pid).plain
	var k := plain.find(needle)
	ok(k >= 0, needle)
	var res := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": view, "part": part}, "from": k, "len": needle.length()})
	ok(res.ok, str(res))
	return String(res.get("clip", ""))

func _new(st, folio := "varios", tpl := "T2") -> String:
	var res := Ledger.act_entry_new(st, r, {"folio": folio, "template": tpl})
	ok(res.ok, str(res))
	return String(res.get("entry", ""))

func _eset(st, e: String, line: int, field: String, value: String) -> Dictionary:
	return Ledger.act_entry_set(st, r, {"entry": e, "line": line, "field": field, "value": value})

func _esup(st, e: String, line: int, item: String) -> Dictionary:
	return Ledger.act_entry_support_add(st, r, {"entry": e, "line": line, "item": item})

func test_create_folio():
	var st = _st()
	var c := _clip(st, "D05@BM", 0, "une marque récente")
	var f := Ledger.create_folio(st, r, c)
	eq(f, "FO001")
	eq(Ledger.create_folio(st, r, c), "FO001", "el mismo recorte reabre su folio")
	eq(Ledger.create_folio(st, r, "RC9999"), "")
	eq(st.ded.folios.FO001.head_clip, c)

func test_entry_new_pages_and_errors():
	var st = _st()
	var c := _clip(st, "D05@BM", 0, "une marque récente")
	var f := Ledger.create_folio(st, r, c)
	var e1 := _new(st, "varios", "T2")
	var e2 := _new(st, f, "T5")
	var e3 := _new(st, "erratas", "T1")
	eq([e1, e2, e3], ["AS001", "AS002", "AS003"])
	eq(st.ded.entries[e2].lines.size(), 5, "T5 tiene 5 líneas")
	eq(st.ded.entries[e1].ink, "lapiz")
	eq(st.ded.folios[f].entries, [e2])
	ok(st.ded.entries[e3].practice, "«Erratas inocentes» = práctica")
	no(st.ded.entries[e1].practice)
	eq(Ledger.act_entry_new(st, r, {"folio": "FO999", "template": "T2"}).get("err"), "folio")
	eq(Ledger.act_entry_new(st, r, {"folio": "varios", "template": "T99"}).get("err"), "plantilla")
	var lv := Ledger.ledger_view(st, r)
	eq(lv.varios, [e1])
	eq(lv.erratas, [e3])
	eq(lv.folios, [{"id": f, "head_clip": c, "entries": [e2]}])
	eq(lv.rules_page.size(), 2, "reglas del fixture")

func test_entry_set_index_and_lists():
	var st = _st()
	var e := _new(st, "varios", "T6")
	eq(_eset(st, e, 0, "persona", "holmes").get("err"), "no_indexado", "no se escribe lo que no se recortó")
	Index.add_entities(st, r, ["holmes", "watson", "fina"])
	ok(_eset(st, e, 0, "persona", "holmes").ok)
	eq(_eset(st, e, 0, "persona", "fina").get("err"), "fuera_de_lista", "un documento no es una persona")
	eq(_eset(st, e, 0, "relacion", "ama_a").get("err"), "fuera_de_lista")
	ok(_eset(st, e, 0, "relacion", "lee_a").ok)
	ok(_eset(st, e, 0, "a_quien", "lisle").ok, "Lisle está en el índice desde el principio")
	ok(_eset(st, e, 0, "por_medio", "sala_lectura").ok, "medio por id de lista")
	eq(_eset(st, e, 1, "y_de", "mrs_hudson").get("err"), "no_indexado", "sensor de un medio: sólo si está en el índice")
	ok(_eset(st, e, 1, "y_de", "watson").ok, "sensor indexado vale como medio")
	eq(_eset(st, e, 1, "y_de", "cualquiera").get("err"), "fuera_de_lista")
	eq(_eset(st, e, 0, "inventado", "holmes").get("err"), "campo")
	eq(_eset(st, e, 7, "persona", "holmes").get("err"), "campo")
	eq(_eset(st, "AS999", 0, "persona", "holmes").get("err"), "no_existe")
	eq(st.ded.entries[e].lines[0].fields, {"persona": "holmes", "relacion": "lee_a", "a_quien": "lisle", "por_medio": "sala_lectura"})
	ok(_eset(st, e, 0, "persona", "").ok, "\"\" borra")
	no(st.ded.entries[e].lines[0].fields.has("persona"))

func test_support_add_remove_delete_and_ink():
	var st = _st()
	var a := _clip(st, "D05@BM", 0, "une marque récente")
	var b := _clip(st, "D03@Crane", "p7", "Era un sendero de tres pies")
	var p: String = Clipper.act_link(st, r, {"a": a, "b": b}).pair
	var e := _new(st)
	ok(_esup(st, e, 0, a).ok)
	ok(_esup(st, e, 0, a).ok, "repetir no duplica")
	ok(_esup(st, e, 1, p).ok, "un par vale como ítem")
	eq(st.ded.entries[e].lines[0].support, [a])
	eq(_esup(st, e, 0, "RC9999").get("err"), "no_existe")
	eq(_esup(st, e, 5, a).get("err"), "campo")
	eq(Ledger.entry_clips(st, e), [a, b], "pares expandidos, cada recorte una vez")
	ok(Ledger.act_entry_support_remove(st, r, {"entry": e, "line": 1, "item": p}).ok)
	eq(Ledger.entry_clips(st, e), [a])
	ok(_esup(st, e, 1, p).ok)
	st.ded.entries[e].ink = "tinta"
	eq(_eset(st, e, 0, "fuente", "fina").get("err"), "en_tinta")
	eq(_esup(st, e, 0, b).get("err"), "en_tinta")
	eq(Ledger.act_entry_support_remove(st, r, {"entry": e, "line": 0, "item": a}).get("err"), "en_tinta")
	eq(Ledger.act_entry_delete(st, r, {"entry": e}).get("err"), "en_tinta")
	eq(Clipper.act_unlink(st, r, {"pair": p}).get("err"), "en_tinta", "un par que sostiene tinta no se deshace")
	var e2 := _new(st)
	ok(_esup(st, e2, 0, p).ok)
	st.ded.entries[e].ink = "lapiz"
	ok(Clipper.act_unlink(st, r, {"pair": p}).ok)
	eq(st.ded.entries[e2].lines[0].support, [], "el par se va de los asientos a lápiz")
	ok(Ledger.act_entry_delete(st, r, {"entry": e2}).ok)
	no(st.ded.entries.has(e2))

func test_formal_check_codes():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", "Era un sendero de tres pies")
	var sheer_bm := _clip(st, "D03@BM", "p7", "con una pared a pique a un lado")
	var marque := _clip(st, "D05@BM", 0, "une marque récente")
	Index.add_entities(st, r, ["fina", "raspadura"])
	var e := _new(st)
	eq(Ledger.formal_check(st, r, e), ["una_fuente"], "asiento vacío: sin fuentes")
	ok(_eset(st, e, 0, "fuente", "fina").ok)
	eq(Ledger.formal_check(st, r, e), ["falta_segun", "una_fuente"])
	_esup(st, e, 0, sheer)
	eq(Ledger.formal_check(st, r, e), ["una_fuente"])
	_esup(st, e, 1, sheer_bm)
	eq(Ledger.formal_check(st, r, e), ["una_fuente"], "dos recortes del mismo papel son una sola fuente")
	_esup(st, e, 1, marque)
	eq(Ledger.formal_check(st, r, e), [], "dos orígenes, cada línea llena con su según")
	ok(_eset(st, e, 1, "consta_en", "journal_de_geneve").ok)
	eq(Ledger.formal_check(st, r, e), [])
	var x1 := _clip(st, "D10@BM", 0, "Del cabrito atado")
	var x2 := _clip(st, "D11@BM", 0, "Un cabrito que no bala")
	_esup(st, e, 1, x1)
	eq(Ledger.formal_check(st, r, e), [], "cuatro recortes es el tope")
	_esup(st, e, 1, x2)
	eq(Ledger.formal_check(st, r, e), ["demasiado_papel"])
	var vw := Ledger.entry_view(st, r, e)
	eq(vw.formal, ["demasiado_papel"])
	eq(vw.lines[0].support, [sheer])

func test_formal_pairs_count_once():
	var st = _st()
	var a := _clip(st, "D05@BM", 0, "une marque récente")
	var b := _clip(st, "D03@Crane", "p7", "Era un sendero de tres pies")
	var p: String = Clipper.act_link(st, r, {"a": a, "b": b}).pair
	var e := _new(st)
	_esup(st, e, 0, p)
	_esup(st, e, 1, a)
	eq(Ledger.entry_clips(st, e).size(), 2)
	eq(Ledger.formal_check(st, r, e), [])

func test_formal_practice_counts_passages():
	var st = _st()
	var ab := _clip(st, "D01.REDH@tomo", 0, "El anuncio salió el 27 de abril, y ocho semanas")
	var oc := _clip(st, "D01.REDH@tomo", 0, "La liga se disolvió el 9 de octubre")
	var ab2 := _clip(st, "D01.REDH@tomo", 0, "El anuncio salió el 27 de abril, y ocho semanas de copiar siguieron")
	var ep := _new(st, "erratas", "T1")
	var ev := _new(st, "varios", "T1")
	for e in [ep, ev]:
		_esup(st, e, 0, ab)
		_esup(st, e, 1, oc)
	eq(Ledger.formal_check(st, r, ep), [], "C1: dos pasajes del mismo documento bastan")
	eq(Ledger.formal_check(st, r, ev), ["una_fuente"], "fuera de la práctica, un documento es una fuente")
	var e3 := _new(st, "erratas", "T1")
	_esup(st, e3, 0, ab)
	_esup(st, e3, 1, ab2)
	eq(Ledger.formal_check(st, r, e3), ["una_fuente"], "el mismo tramo dos veces es un solo pasaje")
