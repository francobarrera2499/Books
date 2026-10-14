# T38 (CORE-EXPEDIENTE; GDD_v3 §3.5): crónicas activas e inactivas (data/corpus.json).
#  - 6 activas (D03 FINA, GREE, SCAN, TWIS, D43, D44) y 20 inactivas; ninguna en las dos listas.
#  - DataRepo no carga los documentos inactivos (siguen en el repo, intactos) y los lista con inactive_docs(); sus
#    ejemplares y fichas de catálogo desaparecen con ellos (ni repo.copy, ni catálogo, ni bandeja, ni accesibles).
#  - Error de datos: un ref de ruta, un huevo, un match.doc o un ref que nombre un documento inactivo (lint y T38).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120.0
const GameSim = preload("res://core/sim/game_sim.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

const ACTIVE := ["D03", "D01.GREE", "D01.SCAN", "D01.TWIS", "D43", "D44"]

func test_lists():
	var r = repo()
	var c: Dictionary = r.corpus()
	eq(c.get("activas", []), ACTIVE)
	eq((c.get("inactivas", []) as Array).size(), 20, "las otras 20 (no 18: GDD_v3 §3.5)")
	for d in c.get("inactivas", []):
		no(ACTIVE.has(String(d)), "%s en las dos listas" % d)
		ok(String(d).begins_with("D01."), "inactiva = crónica de la Strand: %s" % d)

func test_inactive_not_loaded_but_kept_on_disk():
	var r = repo()
	eq(r.inactive_docs().size(), 20)
	for d in r.inactive_docs():
		ok(r.doc(String(d)).is_empty(), "%s no se carga" % d)
		ok(r.is_inactive(String(d)))
		var f := "res://data/docs/D01/%s.json" % String(d).get_slice(".", 1)
		ok(FileAccess.file_exists(f), "%s sigue en el repo" % f)
		ok(r.copy(String(d) + "@tomo").is_empty(), "%s: sin ejemplar" % d)
	for d in ACTIVE:
		if FileAccess.file_exists("res://data/docs/%s.json" % d) or FileAccess.file_exists("res://data/docs/D01/%s.json" % String(d).get_slice(".", 1)):
			no(r.doc(String(d)).is_empty(), "%s (activa) se carga" % d)

func test_inactive_absent_from_game():
	var r = repo()
	var inact: Array = r.inactive_docs()
	var s = GameSim.new(r, 7)
	for x in s.q_accessible():
		no(inact.has(String(x.doc)), "accesible: %s" % x.view)
	var cat = r.catalog() if r.has_method("catalog") else {}
	var txt := JSON.stringify(cat)
	for d in inact:
		no(txt.contains("\"%s\"" % d), "ficha de catálogo de %s" % d)

func test_routes_eggs_and_refs_never_name_inactive():
	var r = repo()
	var inact: Array = r.inactive_docs()
	for q in r.questions():
		for v in q.get("variantes", []):
			for rt in v.get("rutas", []):
				for f in rt.get("frags", []):
					var ref := String(f.get("ref", ""))
					var did := ref.get_slice("#", 0)
					no(inact.has(did), "%s nombra la crónica inactiva %s" % [rt.get("id", "?"), did])
	var eggs := JSON.stringify(r.eggs())
	for d in inact:
		no(eggs.contains(String(d) + "#") or eggs.contains("\"%s\"" % d), "un huevo nombra %s" % d)
	var rx := JSON.stringify(r.reactions())
	for d in inact:
		no(rx.contains("\"%s\"" % d) or rx.contains(String(d) + "@") or rx.contains(String(d) + "#"), "una reacción nombra %s" % d)

func test_lint_flags_inactive_ref():
	var r = repo()
	var q: Dictionary = r.question("Q2").duplicate(true)
	q.variantes[0].rutas[0].frags[0] = {"ref": "D01.REDH#abril", "copy": "D01.REDH@tomo"}
	var p = PatchRepo.new(r, {"questions": {"Q2": q}})
	var l := RouteDB.lint(p, "Q2")
	ok(str(l.errors).contains("inactivo") or str(l.pending).contains("D01.REDH"), "una ruta con una crónica inactiva es error de datos: %s" % str(l))
