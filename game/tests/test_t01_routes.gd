# T1 (W2-GRAPH; GDD§10.6, ARCHITECTURE §9.2): para toda conclusión obligatoria ≥2 rutas sólo-I sin ejemplar común
# (salvo diario); cada ruta con ≥2 orígenes, enlazada por claves, cubriendo sus grupos, con etiquetas de la conclusión y
# «desde» antes de la última pasada útil; C6 por pares que difieren en una subruta. Fixture sintético + negativos +
# datos reales (faltantes → pending_content).
extends "res://tests/test_base.gd"

const RouteDB = preload("res://core/graph/route_db.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _errors(r, cid: String) -> String:
	return str(RouteDB.lint(r, cid).errors)

func _patched_conc(cid: String, f: Callable):
	var r = _r()
	var c: Dictionary = r.conclusion(cid).duplicate(true)
	f.call(c)
	return PatchRepo.new(r, {"conclusions": {cid: c}})

func test_t01_fixture():
	var r = _r()
	var mand := RouteDB.mandatory(r)
	eq(mand.size(), 12)
	for cid in mand:
		var l := RouteDB.lint(r, cid)
		eq(l.errors, [], cid)
		eq(l.pending, [], cid)

func test_t01_neg_single_star():
	var p = _patched_conc("C3", func(c): c.routes = [c.routes[0], c.routes[3]])
	ok(_errors(p, "C3").contains("1 ruta(s) ★"), _errors(p, "C3"))

func test_t01_neg_shared_exemplar():
	var p = _patched_conc("C2", func(c): c.routes[2].frags[1].copy = "D03@Crane")
	ok(_errors(p, "C2").contains("comparten") and _errors(p, "C2").contains("D03@Crane"), _errors(p, "C2"))

func test_t01_neg_one_origin_and_tags():
	var p = _patched_conc("C2", func(c): c.routes.append({"id": "C2.R9", "deps": "fija", "frags": [{"ref": "D05#marque", "copy": "D05@BM"}, {"ref": "D05#corniche", "copy": "D05@BM"}]}))
	var e := _errors(p, "C2")
	ok(e.contains("C2.R9: un solo origen"), e)
	ok(e.contains("D05#corniche sin etiqueta de la conclusión"), e)
	ok(e.contains("C2.R9: no cubre los grupos"), e)

func test_t01_neg_unlinked():
	var p = _patched_conc("C8", func(c): c.routes[0].frags[1] = {"ref": "D44#oficios_mano", "copy": "D44@Crane"})
	ok(_errors(p, "C8").contains("C8.R1: fragmentos no enlazados"), _errors(p, "C8"))

func test_t01_neg_desde_after_last_pass():
	var p = _patched_conc("C2", func(c): c.routes[1].from = "10.N")
	ok(_errors(p, "C2").contains("C2.R2: «desde» (10.N) después de la última pasada"), _errors(p, "C2"))
	var q = _patched_conc("C5", func(c): c.routes[0].frags[0] = {"ref": "D15.0405#meunier", "copy": "D15.0405@L1"})
	ok(_errors(q, "C5").contains("sin etiqueta"), "fragmento ajeno a la conclusión")

func test_t01_neg_declared_star_not_I():
	var p = _patched_conc("C2", func(c): c.routes[0].star = true)
	ok(_errors(p, "C2").contains("declarada ★ con fragmentos no I"), _errors(p, "C2"))

func test_t01_neg_refuted_fragment():
	var p = _patched_conc("C8", func(c): c.routes[0].frags[0] = {"ref": "D13#jartum", "copy": "D13@BM"})
	ok(_errors(p, "C8").contains("D13#jartum lleva f:refutado"), _errors(p, "C8"))

func test_t01_neg_c6_pairs():
	var p = _patched_conc("C6", func(c):
		c.subroutes = {"K-S": c.subroutes["K-S"], "K-T": c.subroutes["K-T"], "K-BM": c.subroutes["K-BM"]}
		c.routes = [c.routes[0]])
	ok(_errors(p, "C6").contains("1 ruta(s) ★"), "un solo par ★: " + _errors(p, "C6"))
	var q = _patched_conc("C6", func(c): c.subroutes["K-T"].frags.pop_back())
	ok(_errors(q, "C6").contains("no cubre los grupos"), "sin ancla de K-T: " + _errors(q, "C6"))

func test_t01_pending_on_missing_fragment():
	var p = _patched_conc("C4", func(c): c.routes[0].frags[1] = {"ref": "D18#nada", "copy": "D18@L6"})
	var l := RouteDB.lint(p, "C4")
	eq(l.errors, [])
	ok(str(l.pending).contains("D18 no tiene el tramo #nada"), str(l.pending))

func test_t01_real_data():
	var r = repo()
	if r.conclusions().is_empty() or r.schedule().is_empty():
		pending_content("T1: data/conclusions.json o data/schedule.json sin datos (W2-STRUCT)")
		return
	var pend: Array = []
	var nerr := 0
	for cid in RouteDB.mandatory(r):
		var l := RouteDB.lint(r, cid)
		for e in l.errors:
			fail(e)
			nerr += 1
		pend.append_array(l.pending)
	if nerr == 0 and not pend.is_empty():
		pending_content("T1: %d fragmentos/rutas sin contenido; p. ej. %s" % [pend.size(), str(pend.slice(0, 5))])
