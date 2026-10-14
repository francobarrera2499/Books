# T1 (CORE-EXPEDIENTE; GDD_v3 §2.4): para cada pregunta con invariante «normal», ≥2 rutas ★ (sólo-I, deps fija/columna/
# garantizada) de la variante principal sin ejemplar ni escena común; toda ruta (todas las variantes) pasa RouteDB.lint
# con los datos reales: exactamente 2 fragmentos de 2 orígenes, que cubren los dos grupos (uno cada uno), enlazados por
# claves, sin f:refutado, obtenibles antes del informe final; ninguna ruta usa un documento inactivo. Negativos sobre
# data/ real con PatchRepo. Contenido que todavía no existe (tramo o nodo pendiente) -> pending_content.
extends "res://tests/test_base.gd"

const RouteDB = preload("res://core/graph/route_db.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _patched(qid: String, f: Callable):
	var r = repo()
	var q: Dictionary = r.question(qid).duplicate(true)
	f.call(q)
	return PatchRepo.new(r, {"questions": {qid: q}})

func _errors(r, uid: String) -> String:
	return str(RouteDB.lint(r, uid).errors)

func test_t01_units():
	var r = repo()
	eq(RouteDB.mandatory(r), ["Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7", "Q9", "Q10"], "invariante normal (Q8 es desde_nacimiento)")
	eq(RouteDB.from_birth(r), ["Q8"])
	has(RouteDB.units(r), "Q8.B")
	has(RouteDB.units(r), "Q10.B")
	eq(String(RouteDB.unit(r, "Q10").variant), "A", "la unidad sin sufijo es la principal")
	eq((RouteDB.unit(r, "Q1").groups as Array).size(), 2)

func test_t01_real_data():
	var r = repo()
	var pend: Array = []
	var nerr := 0
	for uid in RouteDB.units(r):
		var l := RouteDB.lint(r, String(uid))
		for e in l.errors:
			fail(e)
			nerr += 1
		pend.append_array(l.pending)
	if nerr == 0 and not pend.is_empty():
		pending_content("T1: %d fragmentos/rutas sin contenido; p. ej. %s" % [pend.size(), str(pend.slice(0, 6))])

func test_t01_no_inactive_docs():
	var r = repo()
	for uid in RouteDB.units(r):
		for rt in RouteDB.routes(r, String(uid)):
			for f in rt.frags:
				no(f.has("inactive"), "%s %s usa %s (inactivo)" % [uid, rt.id, f.ref])

func test_t01_neg_two_frags_exactly():
	var p = _patched("Q1", func(q): q.variantes[0].rutas[0].frags.append({"ref": "D08#kanzel", "copy": "D08@BM"}))
	ok(_errors(p, "Q1").contains("3 fragmentos"), _errors(p, "Q1"))

func test_t01_neg_one_origin():
	var p = _patched("Q2", func(q): q.variantes[0].rutas[0].frags = [{"ref": "D05#corniche", "copy": "D05@BM"}, {"ref": "D05#marque", "copy": "D05@BM"}])
	var e := _errors(p, "Q2")
	ok(e.contains("un solo origen"), e)
	ok(e.contains("no cubre los grupos"), e)

func test_t01_neg_star_shared():
	# dejar sólo dos ★ que comparten D03@Crane
	var p = _patched("Q2", func(q):
		q.variantes[0].rutas = [q.variantes[0].rutas[0], q.variantes[0].rutas[2]])
	var e := _errors(p, "Q2")
	ok(e.contains("ningún par de rutas ★") or RouteDB.lint(p, "Q2").pending.size() > 0, e)

func test_t01_neg_declared_star_not_I():
	var p = _patched("Q1", func(q): q.variantes[0].rutas[2].star = true)
	var l := RouteDB.lint(p, "Q1")
	ok(str(l.errors).contains("declarada ★ con fragmentos no I") or not l.pending.is_empty(), str(l))

func test_t01_neg_inactive_doc():
	var p = _patched("Q5", func(q): q.variantes[0].rutas[0].frags[1] = {"ref": "D01.REDH#fecha", "copy": "D01.REDH@BM"})
	ok(_errors(p, "Q5").contains("documento inactivo"), _errors(p, "Q5"))

func test_t01_pending_on_missing_fragment():
	var p = _patched("Q5", func(q): q.variantes[0].rutas[0].frags[1] = {"ref": "D13#nada", "copy": "D13@BM"})
	var l := RouteDB.lint(p, "Q5")
	ok(str(l.pending).contains("D13 no tiene el tramo #nada"), str(l.pending))
