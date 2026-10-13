# Unit: core/sim/endings.gd (W2-SCENES). Finales en el orden de endings.json (GDD §12.1: F1, F4, F2, F3a, F3b),
# rank §12.1.2 (F1=1, F3a=2, F3b=3, F2=4, F4=5), variantes acumulables, lápiz azul (§5.2) y congelado.
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Endings = preload("res://core/sim/endings.gd")

const RANKS := {"F1": 1, "F3a": 2, "F3b": 3, "F2": 4, "F4": 5}
const ORDER := ["F1", "F4", "F2", "F3a", "F3b"]

var rp

func before_each() -> void:
	Fakes.install()
	rp = Fakes.repo()

func after_each() -> void:
	Fakes.uninstall()

func _st(sealed: Array, flags := {}):
	var st = Fakes.state(rp, {"day": 10, "phase": "parklane"})
	for c in sealed:
		st.ded.sealed[c] = "AS_" + c
	for k in flags:
		st.flags[k] = flags[k]
	return st

func _final_report(st, cats: Array) -> void:
	st.events.append({"type": "report", "seq": st.events.size() + 1, "n": 4, "mode": "items", "final": true, "items": [{"kind": "entry", "cats": cats, "copies": [], "cls": []}]})

const EIGHT := ["C2", "C3", "C4", "C6", "C7", "C8", "C10", "C11"]
const SIX := ["C2", "C3", "C4", "C5", "C8", "C9"]

func test_f1_requires_the_whole_chain():
	var st = _st(EIGHT, {"informe_final": "errata", "moran_credito": true})
	var r: Dictionary = Endings.evaluate(st, rp)
	eq([r.ending, r.rank], ["F1", 1])
	eq(r.card, "Lisle, Edmund. Lector. Sabe dónde se esconde la gente en una errata.")
	eq(r.scene, "END.F1")
	# cada condición faltante cae al silencio mentiroso (errata no es nada/quemar)
	for broken in [{"moran_credito": false}, {"moran_credito_perdido": true}, {"holmes_entregado": true}, {"watson_expuesto": true}, {"informe_final": "items"}]:
		var f := {"informe_final": "errata", "moran_credito": true}
		f.merge(broken, true)
		eq(Endings.evaluate(_st(EIGHT, f), rp).ending, "F3b", "F1 roto por " + str(broken))
	eq(Endings.evaluate(_st(["C2", "C3", "C4", "C5", "C6", "C7", "C8"], {"informe_final": "errata", "moran_credito": true}), rp).ending, "F3b", "sin C10")
	eq(Endings.evaluate(_st(["C6", "C7", "C10", "C2", "C3", "C4", "C5"], {"informe_final": "errata", "moran_credito": true}), rp).ending, "F3b", "7 selladas")

func test_order_f4_before_f2_before_f3():
	var st = _st(["C2", "C3", "C4", "C5", "C6"], {"informe_final": "items"})
	_final_report(st, ["holmes_vive"])
	eq(Endings.evaluate(st, rp).ending, "F4", "menos de 6: F4 aunque el informe sea fiel")
	var st2 = _st(SIX, {"informe_final": "items"})
	_final_report(st2, ["camden"])
	eq([Endings.evaluate(st2, rp).ending, Endings.evaluate(st2, rp).rank], ["F2", 4])
	var st3 = _st(SIX, {"informe_final": "items"})
	_final_report(st3, ["verdadero"])
	eq(Endings.evaluate(st3, rp).ending, "F3b", "datos sin coordinación ni regreso")
	# sólo cuenta el informe final (n = 4)
	var st4 = _st(SIX, {"informe_final": "nada"})
	st4.events.append({"type": "report", "n": 2, "mode": "items", "items": [{"kind": "clip", "cats": ["holmes_vive"]}]})
	eq([Endings.evaluate(st4, rp).ending, Endings.evaluate(st4, rp).rank], ["F3a", 2])
	eq(Endings.evaluate(_st(SIX, {"informe_final": "quemar"}), rp).ending, "F3a")
	eq([Endings.evaluate(_st(SIX, {"informe_final": "items"}), rp).ending, Endings.evaluate(_st(SIX, {"informe_final": "items"}), rp).rank], ["F3b", 3])
	# F1 gana a F2 aunque haya categorías (el orden manda)
	var st5 = _st(EIGHT, {"informe_final": "errata", "moran_credito": true})
	_final_report(st5, ["baker_street"])
	eq(Endings.evaluate(st5, rp).ending, "F1")

func test_variants_accumulate():
	var st = _st(SIX + ["C14", "C11"], {"informe_final": "nada", "confront_estado": "completa", "watson_expuesto": true})
	var r: Dictionary = Endings.evaluate(st, rp)
	eq(r.ending, "F3a")
	eq(r.variants.map(func(v): return v.id), ["V.confront_completa", "V.C14", "V.C11", "V.expuesto"])
	eq(r.card, "Supo cuándo callar. Cuatro de cuatro.")
	eq(r.card_adds, ["Cuatro de cuatro."])
	eq(r.epilogue, ["tomos_devueltos", "teoria_correcta", "subraya_first_and_last"])
	var st2 = _st(SIX, {"informe_final": "nada", "confront_estado": "incompleta"})
	eq(Endings.evaluate(st2, rp).card, "Supo cuándo callar. Tres errores; buen papel.")
	eq(Endings.evaluate(_st(SIX, {"informe_final": "nada"}), rp).variants, [])

func _check_table(r) -> Array:
	var errs: Array = []
	var ends: Array = r.endings().get("endings", [])
	var by := {}
	for e in ends:
		by[String(e.id)] = e
	for id in RANKS:
		if not by.has(id):
			errs.append("falta " + id)
		elif int(by[id].rank) != RANKS[id]:
			errs.append("%s rank %d != %d" % [id, int(by[id].rank), RANKS[id]])
	var ordered := ends.duplicate()
	ordered.sort_custom(func(a, b): return int(a.order) < int(b.order))
	if ordered.map(func(e): return String(e.id)) != ORDER:
		errs.append("orden %s != %s" % [str(ordered.map(func(e): return e.id)), str(ORDER)])
	if ordered.is_empty() or not ordered[-1].cond.get("always", false):
		errs.append("el último final debe ser incondicional")
	return errs

func test_rank_table_fixture():
	eq(_check_table(rp), [])

func test_rank_table_real_data():
	var r = repo()
	if r.endings().is_empty():
		pending_content("data/endings.json (W2-STRUCT)")
		return
	eq(_check_table(r), [], "endings.json real")

func test_blue_pencil():
	var st = _st(["C2", "C3", "C4", "C5", "C6", "C9", "C10", "C11", "C12", "C13"])
	Fakes.clip(st, "RC1", "a", ["holmes"], [], "D01")
	Fakes.clip(st, "RC2", "b", ["holmes"], [], "D02")
	Fakes.entry(st, "AS1", "T7", [{"fields": {"persona": "holmes"}, "support": ["RC1"]}], "lapiz", {"fake_cid": "C8", "fake_ok": false})
	Fakes.entry(st, "AS2", "T6", [{"fields": {"persona": "x"}, "support": ["RC1", "RC2"]}], "lapiz", {"fake_cid": "C7"})
	Fakes.entry(st, "AS3", "T5", [{"fields": {"persona": "x"}, "support": ["RC1"]}], "lapiz")
	Fakes.entry(st, "AS4", "T5", [{"fields": {"persona": "x"}, "support": ["RC1"]}], "tinta", {"fake_cid": "C2", "fake_ok": false})
	var bp: Array = Endings.blue_pencil(st, rp)
	eq(bp, [
		{"kind": "missing", "cid": "C7", "note": "Falta: quién paga el alquiler."},
		{"kind": "missing", "cid": "C8", "note": "Falta: el estado del difunto."},
		{"kind": "wrong", "entry": "AS1", "cid": "C8", "note": "Dele: la cornisa no se ve desde el sendero."},
	])

func test_freeze_result_and_epilogue():
	var st = _st(SIX, {"informe_final": "nada", "noche_final": "baker_street", "publica_errata": true})
	eq(Endings.result(st, rp).ending, "F3a", "sin congelar: evaluate")
	var fr: Dictionary = Endings.freeze(st, rp)
	eq(st.scenes.ending, fr)
	st.flags["informe_final"] = "items"
	eq(Endings.result(st, rp).ending, "F3a", "congelado")
	var ep: Dictionary = Endings.epilogue(st, rp)
	eq([ep.ending, ep.noche_final, ep.publica_errata, ep.informe_final], ["F3a", "baker_street", true, "items"])

func test_no_data_is_neutral():
	var empty = load("res://core/data/data_repo.gd").load_dir("res://tests/fixtures/__nada__")
	var st = Fakes.state(rp)
	eq(Endings.evaluate(st, empty).ending, "")
	eq(Endings.blue_pencil(st, empty), [])

# Hallazgos del playtest sobre data/ real:
#  - V.C12 (GDD §12.2): «C12 sellado, o C12.R2 vista en Park Lane». Recortar N:PARK.libros escribe vio_libros_park
#    (on_clip_flag del nodo) y la variante aparece sin C12 sellado.
#  - pencil_wrong (Cond): END.F1 dice «Una de sus entradas no es literalmente cierta» sólo si el lápiz azul marca alguna.
func test_real_vc12_by_park_clip_and_pencil_wrong():
	Fakes.uninstall()   # módulos reales (Deps.validator): este caso usa data/ real
	var r = repo()
	var Cond = load("res://core/util/cond.gd")
	var Clipper = load("res://core/deduction/clipper.gd")
	var st = load("res://core/sim/game_state.gd").new()
	st.clock = {"day": 10, "slot": "T", "phase": "parklane"}
	Clipper.init_state(st, r)
	load("res://core/deduction/ledger.gd").init_state(st, r)
	var vids := func() -> Array:
		var out: Array = []
		for v in Endings.evaluate(st, r).variants:
			out.append(String(v.id))
		return out
	no(vids.call().has("V.C12"))
	Clipper.test_access = func(_s, _r, _k, _ref): return true
	var res: Dictionary = Clipper.act_clip_plate(st, r, {"plate": "PARK", "hits": [{"node": "libros", "cover": 0.9, "tight": true}], "area_frac": 0.05})
	Clipper.test_access = Callable()
	ok(res.get("ok", false), str(res))
	ok(bool(st.flags.get("vio_libros_park", false)), "recortar los libros caídos escribe el flag")
	has(vids.call(), "V.C12", "Lisle reconoce los libros caídos sin C12 sellado")
	var ctx := {"st": st, "repo": r}
	no(Cond.eval({"pencil_wrong": true}, ctx), "sin asientos, nada que corregir")
	ok(Cond.eval({"pencil_wrong": false}, ctx))
	st.ded.entries["AS001"] = {"id": "AS001", "folio": "varios", "template": "T7", "ink": "lapiz", "practice": false, "cid": "",
		"lines": [{"fields": {"persona": "holmes"}, "support": []}, {"fields": {"estado": "vivo"}, "support": []}]}
	ok(Cond.eval({"pencil_wrong": true}, ctx), "un lápiz con los valores de C8 sin fundamento: el lápiz azul lo marca")
	eq(Cond.validate({"pencil_wrong": 1}), ["cond.pencil_wrong: debe ser bool"])
