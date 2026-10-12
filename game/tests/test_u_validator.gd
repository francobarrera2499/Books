# W2-DED: validador y pasadas en limpio (§5.2, GDD§8.5). Fixture tests/fixtures/ded.
# Cada una de las 5 condiciones con caso positivo y negativo; lotes (tamaño por calendario, conclusiones distintas,
# todo o nada, mensaje único, el formal no gasta); C1 aparte (práctica, pasajes); regla de alias C10a.
# Costuras: Clipper.test_access (accesibilidad) y Validator.test_passes_left (pasadas) — no dependen de W2-SIM.
extends "res://tests/test_base.gd"

const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const Ledger = preload("res://core/deduction/ledger.gd")
const Validator = preload("res://core/deduction/validator.gd")
const FakeState = preload("res://tests/fixtures/ded/fake_state.gd")

const SHEER := "Era un sendero de tres pies, con una pared a pique a un lado"
const MARQUE := "En la pared, «une marque récente»"

var r
var passes := 1

func before_each() -> void:
	r = fixture_repo("ded")
	passes = 1
	Clipper.test_access = func(_st, _repo, _kind, _ref): return true
	Validator.test_passes_left = func(_st, _repo): return passes

func after_each() -> void:
	Clipper.test_access = Callable()
	Validator.test_passes_left = Callable()

func _st(day := 4, slot := "M"):
	var st = FakeState.new()
	st.clock = {"day": day, "slot": slot, "phase": "desk"}
	Clipper.init_state(st, r)
	Ledger.init_state(st, r)
	return st

func _clip(st, view: String, part, needle: String) -> String:
	var cp: Dictionary = r.copy(view)
	var pid: String = part if typeof(part) == TYPE_STRING else String(r.doc(cp.doc).parts[int(part)].id)
	var plain: String = r.parsed(cp.doc, pid).plain
	var k := plain.find(needle)
	ok(k >= 0, "«%s» en %s" % [needle, plain])
	var res := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": view, "part": part}, "from": k, "len": needle.length()})
	ok(res.ok, str(res))
	return String(res.get("clip", ""))

func _inj(st, origin: String, tags: Array, ents: Array) -> String:
	return Clipper.inject(st, r, {"origin": origin, "tags": tags, "ents": ents, "text": "x"})

# fields: [[line, campo, valor], ...]; support: [[line, item], ...]
func _entry(st, tpl: String, fields: Array, support: Array, folio := "varios") -> String:
	var res := Ledger.act_entry_new(st, r, {"folio": folio, "template": tpl})
	ok(res.ok, str(res))
	var e: String = res.entry
	for f in fields:
		var s := Ledger.act_entry_set(st, r, {"entry": e, "line": f[0], "field": f[1], "value": f[2]})
		ok(s.ok, "%s %s" % [str(f), str(s)])
	for p in support:
		var s2 := Ledger.act_entry_support_add(st, r, {"entry": e, "line": p[0], "item": p[1]})
		ok(s2.ok, "%s %s" % [str(p), str(s2)])
	return e

func _idx_c2(st) -> void:
	Index.add_entities(st, r, ["fina", "raspadura", "journal_de_geneve"])

func _c2(st, line1 := []) -> String:
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var marque := _clip(st, "D05@BM", 0, MARQUE)
	var sup := [[0, sheer], [1, marque]]
	for it in line1:
		sup.append([1, it])
	return _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], sup)

func _c6(st, x := "la_calle", y := "columna", hc10_ents := ["act.1"]) -> String:
	var go := _inj(st, "D36", ["a:acto_ks"], ["act.5"])
	var sil := _inj(st, "PL.L2.3.M", ["a:ancla_ks"], ["act.5", "muchacho_de_gorra"])
	var ad := _inj(st, "D15.0327", ["a:acto_kt"], ["act.1", "times"])
	var hc := _inj(st, "D15.0330", ["a:ancla_kt"], hc10_ents)
	Index.add_entities(st, r, ["holmes"])
	return _entry(st, "T6", [[0, "persona", "holmes"], [0, "relacion", "lee_a"], [0, "a_quien", "lisle"], [0, "por_medio", x], [1, "y_de", y]],
		[[0, go], [0, sil], [1, ad], [1, hc]])

func _c10(st, persona := "moran", ident_ents := ["moran", "bigote"]) -> String:
	var idn := _inj(st, "D16", ["a:harris_es_moran"], ident_ents)
	var cebo := _inj(st, "D10", ["a:cebo"], ["cabrito", "moran"])
	var busca := _inj(st, "D11", ["a:busca_a_holmes"], ["cabrito", "donde"])
	Index.add_entities(st, r, ["moran", "harris", "cebo", "holmes"])
	return _entry(st, "T9", [[0, "persona", persona], [1, "usa_a", "lisle"], [1, "como", "cebo"], [2, "para", "hallar"], [2, "a_quien", "holmes"]],
		[[0, idn], [1, cebo], [2, busca]])

func _c10a(st) -> String:
	var a := _inj(st, "PL.prologo", ["a:harris_es_moran"], ["harris", "bigote"])
	var b := _inj(st, "D16", ["a:retrato_moran"], ["moran", "bigote"])
	Index.add_entities(st, r, ["harris", "moran"])
	return _entry(st, "T3", [[0, "persona", "harris"], [1, "es", "moran"]], [[0, a], [1, b]])

func _c12(st) -> String:
	var a := _inj(st, "S.HC07", ["a:librero_falso"], ["librero"])
	var b := _inj(st, "D14", ["a:rasgo_holmes"], ["librero", "holmes"])
	Index.add_entities(st, r, ["librero", "holmes"])
	return _entry(st, "T3", [[0, "persona", "librero"], [1, "es", "holmes"]], [[0, a], [1, b]])

func _ok(st, e: String) -> Dictionary:
	return Validator.entry_ok(st, r, e)

# ---------------- las cinco condiciones ----------------
func test_c2_positive_route():
	var st = _st()
	var e := _c2(st)
	eq(Ledger.formal_check(st, r, e), [])
	eq(_ok(st, e), {"ok": true, "cid": "C2", "failed": []})

func test_cond1_values():
	var st = _st()
	var e := _c2(st)
	Index.add_entities(st, r, ["cornisa"])
	ok(Ledger.act_entry_set(st, r, {"entry": e, "line": 0, "field": "calla", "value": "cornisa"}).ok)
	eq(_ok(st, e), {"ok": false, "cid": "", "failed": [1]}, "valor fuera de answers")
	Index.add_entities(st, r, ["marca_en_la_roca"])
	ok(Ledger.act_entry_set(st, r, {"entry": e, "line": 0, "field": "calla", "value": "marca_en_la_roca"}).ok)
	ok(_ok(st, e).ok, "valor alternativo aceptado")
	ok(Ledger.act_entry_set(st, r, {"entry": e, "line": 1, "field": "consta_en", "value": ""}).ok)
	eq(_ok(st, e).failed, [1], "campo de answers vacío")

func test_cond2_group_on_its_line():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var marque := _clip(st, "D05@BM", 0, MARQUE)
	var fields := [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]]
	var swapped := _entry(st, "T2", fields, [[0, marque], [1, sheer]])
	eq(_ok(st, swapped), {"ok": false, "cid": "C2", "failed": [2]}, "cada grupo sostiene SU línea")
	var right := _entry(st, "T2", fields, [[0, sheer], [1, marque]])
	ok(_ok(st, right).ok)

func test_cond3_two_origins():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var fake := _inj(st, "D03", ["a:raspadura_registrada"], ["raspadura", "fina"])
	_idx_c2(st)
	var e := _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, sheer], [1, fake]])
	eq(_ok(st, e).failed, [3], "dos recortes del mismo papel = una fuente")
	has(Ledger.formal_check(st, r, e), "una_fuente")

func test_cond4_every_clip_tagged_and_not_refuted():
	var st = _st()
	var stray := _clip(st, "D03@Crane", "p1", "—De los fusiles de aire.")
	var e := _c2(st, [stray])
	eq(_ok(st, e).failed, [4], "un recorte sin etiqueta de la conclusión")
	var st2 = _st()
	var extra := _clip(st2, "D05@BM", 0, "Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que l'on ne voit pas du sentier»")
	var e2 := _c2(st2, [extra])
	ok(_ok(st2, e2).ok, "tags_extra cuenta como etiqueta de la conclusión: " + str(_ok(st2, e2)))
	var st3 = _st()
	var sheer := _clip(st3, "D03@Crane", "p7", SHEER)
	var falsa := _clip(st3, "D99@BM", 0, "El muchacho suizo borró la raspadura de la pared")
	ok(Clipper.get_clip(st3, falsa).tags.has("f:refutado"))
	_idx_c2(st3)
	var e3 := _entry(st3, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, sheer], [1, falsa]])
	eq(_ok(st3, e3).failed, [4], "refutado no sostiene nada aunque lleve el grupo")

func test_cond5_linked_by_keys():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var loose := _inj(st, "DX", ["a:raspadura_registrada"], ["ruido_azul"])
	_idx_c2(st)
	var e := _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, sheer], [1, loose]])
	eq(_ok(st, e).failed, [5], "sin entidad clave común")
	var linked := _inj(st, "DY", ["a:raspadura_registrada"], ["ruido_azul", "pared"])
	ok(Ledger.act_entry_support_add(st, r, {"entry": e, "line": 1, "item": linked}).ok)
	eq(_ok(st, e).failed, [5], "el suelto sigue suelto")
	ok(Ledger.act_entry_support_remove(st, r, {"entry": e, "line": 1, "item": loose}).ok)
	ok(_ok(st, e).ok, "«pared» es clave de C2")
	var same := _inj(st, "D03", ["a:fina_a_pique"], ["ruido_azul"])
	ok(Ledger.act_entry_support_add(st, r, {"entry": e, "line": 0, "item": same}).ok)
	eq(_ok(st, e).failed, [4], "fina_a_pique no es etiqueta de C2")

func test_cond5_same_origin_links():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var marque := _clip(st, "D05@BM", 0, MARQUE)
	var odd := _inj(st, "D05", ["a:raspadura_registrada"], ["ruido_azul"])
	var e := _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, sheer], [1, marque], [1, odd]])
	ok(_ok(st, e).ok, "dos recortes del mismo origen quedan enlazados")

func test_pairs_count_as_their_two_clips():
	var st = _st()
	var sheer := _clip(st, "D03@Crane", "p7", SHEER)
	var marque := _clip(st, "D05@BM", 0, MARQUE)
	var p: String = Clipper.act_link(st, r, {"a": sheer, "b": marque}).pair
	var e := _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, p], [1, marque]])
	ok(_ok(st, e).ok, str(_ok(st, e)))

# ---------------- C6: ${ch:campo}, medios y distinct ----------------
func test_c6_channels():
	var st = _st()
	var e := _c6(st)
	eq(_ok(st, e), {"ok": true, "cid": "C6", "failed": []}, "K-S + K-T: subrutas unidas por citar actos")
	var e2 := _c6(st, "muchacho_de_gorra", "times")
	eq(_ok(st, e2).failed, [], "un sensor indexado vale como su medio")
	var e3 := _c6(st, "sala_lectura", "columna")
	has(_ok(st, e3).failed, 2, "el canal elegido no es el de los recortes")
	var e4 := _c6(st, "la_calle", "la_calle")
	eq(_ok(st, e4).failed, [1], "X ≠ Y")
	var e5 := _c6(st, "la_calle", "muchacho_de_gorra")
	eq(_ok(st, e5).failed, [1], "medio y su sensor son el mismo medio")
	var e6 := _c6(st, "la_calle", "columna", [])
	eq(_ok(st, e6).failed, [5], "un ancla que no cita acto queda suelta")

func test_hb12_exclude_origins():
	var st = _st()
	var e := _c6(st)
	ok(Validator.evaluate(st, r, st.ded.entries[e], {"exclude_origins": ["S.HC06"]}).ok)
	eq(Validator.evaluate(st, r, st.ded.entries[e], {"exclude_origins": ["D15."]}).ok, false)
	var st2 = _st()
	var e2 := _c6(st2)
	var hc := Clipper.inject(st2, r, {"origin": "S.L5.8.T", "scene": "HC06", "tags": ["a:ancla_kt"], "ents": ["act.1"], "text": "x"})
	var ent: Dictionary = st2.ded.entries[e2]
	ent.lines[1].support = [ent.lines[1].support[0], hc]
	ok(Validator.evaluate(st2, r, ent).ok, "con el ancla de HC06")
	no(Validator.evaluate(st2, r, ent, {"exclude_origins": ["S.HC06"]}).ok, "sin los recortes de la escena HC06 (§12.1.4)")

# ---------------- C10 y la regla de alias C10a ----------------
func test_alias_rule():
	var st = _st()
	var e := _c10(st)
	ok(_ok(st, e).ok, "C10 con Moran: " + str(_ok(st, e)))
	var eh := _c10(st, "harris")
	eq(Validator.which_conclusion(r, st.ded.entries[eh], st.ded.sealed), "", "«@alias:harris» no vale sin C10a")
	var ek := _c10(st, "moran", ["harris", "bigote"])
	eq(_ok(st, ek).failed, [5], "harris y moran no enlazan sin C10a")
	st.ded.sealed["C10a"] = "AS999"
	eq(Validator.which_conclusion(r, st.ded.entries[eh], st.ded.sealed), "C10", "con C10a sellada vale Harris")
	ok(_ok(st, ek).ok, "con C10a sellada harris ≡ moran como clave")
	ok(Validator.values_match(r, st.ded.entries[eh], "C10", {"C10a": "x"}))
	no(Validator.values_match(r, st.ded.entries[eh], "C10", {}))

func test_c10a_entry_and_alias_in_same_lot():
	var st = _st(5)
	var ea := _c10a(st)
	eq(_ok(st, ea), {"ok": true, "cid": "C10a", "failed": []})
	var eh := _c10(st, "harris")
	var res := Validator.act_pass_clean(st, r, {"entries": [ea, eh]})
	ok(res.ok)
	no(res.inked, "el alias rige recién después de sellar C10a")
	var ea2 := _c10a(st)
	var e2 := _c2(st)
	var res2 := Validator.act_pass_clean(st, r, {"entries": [ea2, e2]})
	ok(res2.inked, str(res2))
	eq(res2.sealed, ["C10a", "C2"])
	var eh2 := _c10(st, "harris")
	var e6 := _c6(st)
	ok(Validator.act_pass_clean(st, r, {"entries": [eh2, e6]}).inked, "ahora sí: Harris vale como Moran")

# ---------------- lotes ----------------
func test_lot_size_by_calendar():
	var st = _st(3)
	eq(Validator.lot_size(st, r), 2)
	st.clock.day = 10
	eq(Validator.lot_size(st, r), 1, "día 10: de a uno")
	st.clock.day = 7
	st.ded.sealed = {"C2": "a", "C6": "b", "C10": "c"}
	eq(Validator.lot_size(st, r), 1, "min(2, sin sellar)")
	st.ded.sealed["C12"] = "d"
	eq(Validator.lot_size(st, r), 0)
	st.ded.sealed = {"C10a": "x"}
	eq(Validator.lot_size(st, r), 2, "C10a no está en lot_counts")

func test_pass_clean_all_good():
	var st = _st()
	var e1 := _c2(st)
	var e2 := _c6(st)
	st.notes.clear()
	var res := Validator.act_pass_clean(st, r, {"t": "pass_clean", "entries": [e1, e2]})
	eq(res, {"ok": true, "inked": true, "msg": "Visto.", "sealed": ["C2", "C6"], "spent": true})
	eq(st.ded.entries[e1].ink, "tinta")
	eq(st.ded.entries[e2].cid, "C6")
	eq(st.ded.sealed, {"C2": e1, "C6": e2})
	eq(st.ded.passes, [{"tk": 41, "entries": [e1, e2], "inked": true}])
	eq(Validator.passes_spent(st, 41), 1)
	eq(st.notes.map(func(n): return n.kind), ["entry", "entry"], "el aviso «pass» lo emite el despachador (W2-SIM)")
	eq(Ledger.act_entry_set(st, r, {"entry": e1, "line": 0, "field": "calla", "value": ""}).get("err"), "en_tinta", "la tinta es inmutable")
	eq(Validator.act_pass_clean(st, r, {"entries": [e1, e2]}).get("err"), "en_tinta")

func test_pass_clean_all_or_nothing_single_message():
	var st = _st()
	var e1 := _c2(st)
	var bad := _c10(st, "moran", ["harris", "bigote"])
	var res := Validator.act_pass_clean(st, r, {"entries": [e1, bad]})
	eq(res, {"ok": true, "inked": false, "msg": "Alguno no se sostiene.", "sealed": [], "spent": true})
	eq(st.ded.entries[e1].ink, "lapiz", "si uno no se sostiene, ninguno se entinta")
	eq(st.ded.sealed, {})
	eq(st.ded.passes.size(), 1, "la pasada se gastó")
	var st2 = _st()
	var b1 := _c10(st2, "moran", ["harris", "bigote"])
	var b2 := _c2(st2)
	var res2 := Validator.act_pass_clean(st2, r, {"entries": [b2, b1]})
	eq(res2.msg, res.msg, "mensaje único: no dice cuál")

func test_pass_clean_distinct_and_not_sealed():
	var st = _st()
	var a := _c2(st)
	var b := _c2(st)
	ok(_ok(st, a).ok and _ok(st, b).ok)
	no(Validator.act_pass_clean(st, r, {"entries": [a, b]}).inked, "dos veces lo mismo no")
	var c6 := _c6(st)
	ok(Validator.act_pass_clean(st, r, {"entries": [a, c6]}).inked)
	var c10 := _c10(st)
	no(Validator.act_pass_clean(st, r, {"entries": [b, c10]}).inked, "C2 ya está sellada")

func test_pass_clean_formal_does_not_spend():
	var st = _st()
	var e1 := _c2(st)
	var e2 := _entry(st, "T6", [], [])
	Index.add_entities(st, r, ["holmes"])
	ok(Ledger.act_entry_set(st, r, {"entry": e2, "line": 0, "field": "persona", "value": "holmes"}).ok)
	var res := Validator.act_pass_clean(st, r, {"entries": [e1, e2]})
	eq(res.get("ok"), false)
	eq(res.get("err"), "formal")
	eq(res.get("formal"), [{"entry": e2, "code": "falta_segun"}, {"entry": e2, "code": "una_fuente"}])
	eq(st.ded.passes, [], "el formal no gasta")
	eq(st.ded.entries[e1].ink, "lapiz")

func test_pass_clean_lot_and_passes():
	var st = _st()
	var e1 := _c2(st)
	var e2 := _c6(st)
	eq(Validator.act_pass_clean(st, r, {"entries": [e1]}), {"ok": false, "err": "lote", "lot_size": 2})
	eq(Validator.act_pass_clean(st, r, {"entries": [e1, e1]}).get("err"), "lote")
	eq(Validator.act_pass_clean(st, r, {"entries": [e1, "AS999"]}).get("err"), "no_existe")
	passes = 0
	eq(Validator.act_pass_clean(st, r, {"entries": [e1, e2]}).get("err"), "sin_pasada")
	eq(st.ded.passes, [])

func test_day10_lot_of_one_and_validate_window():
	var st = _st(10, "M")
	var e := _c12(st)
	eq(_ok(st, e).ok, true)
	var st2 = _st(10, "T")
	var e2 := _c12(st2)
	var res2 := Validator.act_pass_clean(st2, r, {"entries": [e2]})
	no(res2.inked, "C12 sólo hasta las 12 h del día 10 (validate.until)")
	var res := Validator.act_pass_clean(st, r, {"entries": [e]})
	eq(res.sealed, ["C12"], "lote de 1 el día 10")
	var st3 = _st(3, "M")
	var e3 := _c6(st3)
	var e4 := _c2(st3)
	no(Validator.act_pass_clean(st3, r, {"entries": [e3, e4]}).inked, "C6 se valida desde 4.dawn")

# ---------------- C1: práctica aparte ----------------
func _c101(st, folio := "erratas", dice_b := "pierna") -> String:
	var h := _clip(st, "D43@Crane", 0, "La bala me dio en el hombro y me rozó la arteria.")
	var p := _clip(st, "D44@Crane", 0, "Tenía la bala de Jezail en la pierna, y me dolía")
	return _entry(st, "T1", [[0, "fuente_a", "estudio_escarlata"], [0, "dice_a", "hombro"], [1, "fuente_b", "signo_de_los_cuatro"], [1, "dice_b", dice_b]],
		[[0, h], [1, p]], folio)

func test_practice_c1():
	var st = _st()
	var e := _c101(st)
	eq(Validator.which_conclusion(r, st.ded.entries[e], {}), "C1.01")
	var res := Validator.act_practice(st, r, {"t": "practice", "entry": e})
	eq(res, {"ok": true, "inked": true, "msg": "Visto. Errata inocente: sic."})
	eq(st.ded.entries[e].ink, "tinta")
	eq(st.ded.entries[e].cid, "C1.01")
	eq(st.ded.sealed, {}, "la práctica no cuenta para nada")
	eq(st.ded.passes, [], "ni gasta pasada")
	eq(st.ded.practice.size(), 1)
	var v := _c101(st, "varios")
	eq(Validator.which_conclusion(r, st.ded.entries[v], {}), "", "C1 no se pasa en limpio con el lote")
	var bad := _c101(st, "erratas", "hombro")
	var rb := Validator.act_practice(st, r, {"entry": bad})
	eq(rb, {"ok": true, "inked": false, "msg": "No se sostiene."})
	eq(st.ded.entries[bad].ink, "lapiz")

func test_practice_two_passages_same_document():
	var st = _st()
	var ab := _clip(st, "D01.REDH@tomo", 0, "El anuncio salió el 27 de abril, y ocho semanas de copiar siguieron.")
	var oc := _clip(st, "D01.REDH@tomo", 0, "La liga se disolvió el 9 de octubre.")
	var e := _entry(st, "T1", [[0, "fuente_a", "liga_pelirrojos"], [0, "dice_a", "fecha_abril"], [1, "fuente_b", "liga_pelirrojos"], [1, "dice_b", "fecha_octubre"]],
		[[0, ab], [1, oc]], "erratas")
	ok(Validator.act_practice(st, r, {"entry": e}).inked, "INC-10: dos pasajes del mismo relato")
	var one := _entry(st, "T1", [[0, "fuente_a", "liga_pelirrojos"], [0, "dice_a", "fecha_abril"], [1, "fuente_b", "liga_pelirrojos"], [1, "dice_b", "fecha_octubre"]],
		[[0, ab], [1, ab]], "erratas")
	eq(Validator.act_practice(st, r, {"entry": one}).get("err"), "formal", "un solo pasaje")

func test_practice_entry_in_lot_does_not_count():
	var st = _st()
	var pe := _c101(st)
	var e := _c2(st)
	no(Validator.act_pass_clean(st, r, {"entries": [pe, e]}).inked)

# ---------------- auxiliares ----------------
func test_entry_tags_and_unknown():
	var st = _st()
	var e := _c2(st)
	eq(Validator.entry_tags(st, e), ["a:fina_a_pique", "a:fina_impreso_sin_raspadura", "a:raspadura_registrada"])
	eq(Validator.entry_tags(st, "AS999"), [])
	eq(Validator.entry_ok(st, r, "AS999"), {"ok": false, "cid": "", "failed": [1]})

func test_covers_all_groups():
	eq(Validator.covers_all_groups(r, "C2", ["a:fina_impreso_sin_raspadura", "a:raspadura_registrada"]), true)
	eq(Validator.covers_all_groups(r, "C2", ["a:fina_impreso_sin_raspadura"]), false)
	eq(Validator.covers_all_groups(r, "C6", ["a:acto_kbm", "a:ancla_kbm", "a:acto_kw", "a:ancla_kw"]), true)
	eq(Validator.covers_all_groups(r, "C6", ["a:acto_kbm", "a:ancla_kbm"]), false, "X = Y no vale")
	eq(Validator.covers_all_groups(r, "C10", ["a:harris_es_moran", "a:cebo"]), false)
	eq(Validator.covers_all_groups(r, "C404", ["a:x"]), false)

func test_group_tags_resolution():
	var st = _st()
	var e := _c6(st, "sala_lectura", "221b")
	var gt := Validator.group_tags(r, "C6", st.ded.entries[e])
	eq(gt.groups.map(func(g): return g.tags), [["acto_kbm"], ["ancla_kbm"], ["acto_kh"], ["ancla_kh"]])

func test_cond5_empty_origin_does_not_link():
	var st = _st()
	var a := _inj(st, "", ["a:fina_impreso_sin_raspadura"], ["ruido_azul"])
	var b := _inj(st, "", ["a:raspadura_registrada"], ["ruido_verde"])
	var c := _inj(st, "D05", ["a:raspadura_registrada"], ["pared"])
	_idx_c2(st)
	var e := _entry(st, "T2", [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "journal_de_geneve"]], [[0, a], [1, b], [1, c]])
	has(_ok(st, e).failed, 5, "un origen vacío no es «el mismo origen»")

# C6 por la calle (K-S) con recortes producidos por el sim real: diario del acto «go» + silueta de Wiggins en la lámina
# de esa visita (comparten la entidad del acto); K-T inyectado.
func test_c6_street_channel_through_game_sim():
	Clipper.test_access = Callable()
	Validator.test_passes_left = Callable()
	var GS: Script = load("res://core/sim/game_sim.gd")
	var WM: Script = load("res://core/sim/world_model.gd")
	var sim = GS.new(r, 5)
	sim.st.clock.day = 3
	sim.st.clock.slot = "M"
	sim.st.clock.phase = "desk"
	WM.add_silhouette(sim.st, "wiggins", 3)
	var g := sim.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}) as Dictionary
	ok(g.get("ok", false), str(g))
	var plate := String(sim.q_visit_plate().get("id", ""))
	var sil := sim.apply({"t": "clip_plate", "plate": plate, "hits": [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], "touched": [], "area_frac": 0.05}) as Dictionary
	ok(sil.get("ok", false), str(sil))
	var dy: Dictionary = sim.st.world.diary[sim.st.world.diary.size() - 1]
	var p: Dictionary = r.parse_text(String(dy.text), {}, String(dy.get("act", "")))
	var go := sim.apply({"t": "clip_text", "src": {"kind": "diary", "ref": String(dy.id)}, "from": 0, "len": p.plain.length()}) as Dictionary
	ok(go.get("ok", false), str(go))
	var cs := Clipper.get_clip(sim.st, String(sil.clip))
	var cg := Clipper.get_clip(sim.st, String(go.clip))
	eq(cs.tags, ["a:ancla_ks"])
	eq(cg.tags, ["a:acto_ks"])
	has(cs.ents, String(dy.act), "la silueta cita el acto de esa visita")
	has(cg.ents, String(dy.act))
	var st = sim.st
	var ad := _inj(st, "D15.0327", ["a:acto_kt"], ["act.90", "times"])
	var hc := _inj(st, "D15.0330", ["a:ancla_kt"], ["act.90"])
	Index.add_entities(st, r, ["holmes"])
	var e: String = sim.apply({"t": "entry_new", "folio": "varios", "template": "T6"}).get("entry", "")
	for f in [[0, "persona", "holmes"], [0, "relacion", "lee_a"], [0, "a_quien", "lisle"], [0, "por_medio", "la_calle"], [1, "y_de", "columna"]]:
		ok(sim.apply({"t": "entry_set", "entry": e, "line": f[0], "field": f[1], "value": f[2]}).get("ok", false), str(f))
	for s in [[0, String(go.clip)], [0, String(sil.clip)], [1, ad], [1, hc]]:
		ok(sim.apply({"t": "entry_support_add", "entry": e, "line": s[0], "item": s[1]}).get("ok", false), str(s))
	eq(sim.q_entry(e).get("formal"), [])
	eq(Validator.entry_ok(st, r, e), {"ok": true, "cid": "C6", "failed": []})

# ---------------- integración con el sim real (W2-SIM): accesibilidad, despacho y pasada gastada ----------------
func test_through_game_sim():
	Clipper.test_access = Callable()
	Validator.test_passes_left = Callable()
	var GS: Script = load("res://core/sim/game_sim.gd")
	var sim = GS.new(r, 5)
	sim.st.clock.day = 4
	sim.st.clock.slot = "M"
	sim.st.clock.phase = "desk"
	var p2: String = r.parsed("D02", "p1").plain
	var k := p2.find("En la roca")
	var res := sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D02@L1", "part": "p1", "block": 0}, "from": k, "len": p2.find("arriba.") + 7 - k}) as Dictionary
	ok(res.get("ok", false), str(res))
	var p3: String = r.parsed("D03", "p7").plain
	var k3 := p3.find(SHEER)
	var res3 := sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D03@tomo", "part": "p7", "block": 0}, "from": k3, "len": SHEER.length()}) as Dictionary
	ok(res3.get("ok", false), str(res3))
	eq(sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D05@BM", "part": 0}, "from": 0, "len": 5}).get("err"), "inaccesible", "el BM no está a mano en casa")
	var e: String = sim.apply({"t": "entry_new", "folio": "varios", "template": "T2"}).get("entry", "")
	for f in [[0, "fuente", "fina"], [0, "calla", "raspadura"], [1, "consta_en", "galerada"]]:
		ok(sim.apply({"t": "entry_set", "entry": e, "line": f[0], "field": f[1], "value": f[2]}).get("ok", false), str(f))
	ok(sim.apply({"t": "entry_support_add", "entry": e, "line": 0, "item": res3.clip}).get("ok", false))
	ok(sim.apply({"t": "entry_support_add", "entry": e, "line": 1, "item": res.clip}).get("ok", false))
	eq(sim.q_entry(e).get("formal"), [])
	sim.st.ded.sealed = {"C6": "x", "C10": "y", "C12": "z"}
	eq(int(sim.q_clock().get("lot_size", -1)), 1)
	var pc := sim.apply({"t": "pass_clean", "entries": [e]}) as Dictionary
	eq(pc.get("inked"), true, str(pc))
	eq(pc.get("sealed"), ["C2"])
	eq(int(sim.st.clock.get("passes_used", 0)), 1, "el despachador cuenta la pasada (spent)")
	eq(sim.apply({"t": "pass_clean", "entries": [e]}).get("err"), "sin_pasada")
	eq(sim.q_entry(e).get("ink"), "tinta")
