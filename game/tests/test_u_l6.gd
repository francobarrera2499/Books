# Tests de L6 (W2-PLACES-C): data/places/L6.json + world/props/l6.gd. ARCHITECTURE §4.11, §7.3; GDD§5 (L6), D18.
extends "res://tests/test_base.gd"

const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")
const TIMEOUT_S := 180.0

const PLAN := [["sala", 3, "M"], ["sala", 4, "T"]]

func _place() -> Dictionary:
	return repo().place("L6")

func test_loads_without_errors() -> void:
	var mine: Array = []
	for e in repo().errors():
		if str(e).contains("places/L6.json"): mine.append(e)
	eq(mine, [], "errores de carga de L6")
	ok(not _place().is_empty(), "L6 cargado")

func test_static_checks() -> void:
	eq(PC.static_problems(repo(), _place()), [], "L6")

func test_contract() -> void:
	var p := _place()
	eq(p.get("areas", {}).keys(), ["sala"], "una sola área")
	eq(p.get("observers", []), [], "nadie observa (ciego, §9.2)")
	eq(p.get("characters", []), [], "sin personajes con diálogo")
	# los índices (D18) se ven en la sala; registros públicos: clase I
	for nid in ["calendars", "indices_defunciones", "atril_calendars"]:
		var n := PC.find_node(p, nid)
		eq(str(n.get("_doc")), "D18@L6", nid)
		eq(str(n.get("cls")), "I", nid)
	for n in PC.node_defs(p, ""):
		eq((n.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:")), [], "%s: la sala no sostiene rutas por sí sola" % n.get("id"))

func test_every_node_reachable_and_silhouettes() -> void:
	eq(await PC.reach_problems(tree, _place(), PLAN), [], "L6")

func test_calendars_clippable() -> void:
	ok(not (await PC.clip_alone_frames(tree, _place(), "sala", 3, "M", "atril_calendars")).is_empty(), "atril con el calendar abierto")

func test_props_build() -> void:
	var L6 = load("res://world/props/l6.gd")
	for fn in ["calendar_shelves", "lectern_table", "will_table", "copy_box", "wall_clock", "colonnade"]:
		var n = L6.call("build_" + fn, {})
		ok(n is Node3D and n.has_meta("occ"), fn)
		n.free()

func test_prewarm() -> void:
	eq(await PC.prewarm_problems(tree, _place()), [], "precalentado")
