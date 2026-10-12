# Tests de la lámina del Reichenbach (W2-PLACES-C): data/plates/RB.json + world/props/plates.gd.
# ARCHITECTURE §4.11 (variants fina/journal/foto, doc_variant), §4.8 (C3.R2: N:RB.foto.linea), GDD§5 «Láminas», §14.4.
extends "res://tests/test_base.gd"

const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")
const RC = preload("res://world/rect_clip.gd")
const PL = preload("res://world/props/plates.gd")
const TIMEOUT_S := 180.0

func _plate() -> Dictionary:
	return repo().plate("RB")

func test_loads_without_errors() -> void:
	var mine: Array = []
	for e in repo().errors():
		if str(e).contains("plates/RB.json"): mine.append(e)
	eq(mine, [], "errores de carga de RB")
	ok(not _plate().is_empty(), "RB cargada")

func test_static_checks() -> void:
	eq(PC.static_problems(repo(), _plate(), "plates"), [], "RB")

func test_variants_and_doc_variant() -> void:
	var p := _plate()
	ok(bool(p.get("fixed", false)), "lámina fija")
	eq(p.get("doc_variant", {}), {"D03": "fina", "D05": "journal", "D07": "foto"}, "variante por documento (§4.11)")
	eq((p.get("variants", {}) as Dictionary).keys(), ["fina", "journal", "foto"], "tres variantes")
	for v in ["fina", "journal", "foto"]:
		var vd: Dictionary = p["variants"][v]
		ok(str(vd.get("_origin", "")) != "", "%s: origen propuesto" % v)

func test_contract_and_tags() -> void:
	var p := _plate()
	# C3.R2: N:RB.foto.linea lleva cornisa_existe; la foto no dice que sea una cornisa
	var linea := PC.find_node(p, "linea", "foto")
	ok(PC.has_tags(linea, ["a:cornisa_existe"]), "linea: %s" % str(linea.get("tags")))
	no(str(linea.get("examine", "")).to_lower().contains("cornisa"), "la foto no nombra la cornisa")
	no(str(linea.get("noun", "")).to_lower().contains("cornisa"), "ni en el epígrafe")
	ok(PC.has_tags(PC.find_node(p, "cornisa", "journal"), ["a:cornisa_existe"]), "Journal: la cornisa")
	ok(PC.has_tags(PC.find_node(p, "marca", "journal"), ["a:raspadura_registrada"]), "Journal: la marca")
	# FINA (pared lisa) no sostiene nada por sí sola; sin cornisa ni marca
	for n in PC.node_defs(p, "fina"):
		eq((n.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:")), [], "FINA %s" % n.get("id"))
	for nid in ["cornisa", "linea", "marca", "saliente"]:
		ok(PC.find_node(p, nid, "fina").is_empty(), "FINA sin %s" % nid)
	ok(PC.find_node(p, "baston", "foto").is_empty(), "la foto-recuerdo no tiene bastón")
	ok(PC.find_node(p, "marca", "foto").is_empty(), "ni la marca")
	# T4 por nodo: a lo sumo una etiqueta de conclusión por nodo (y nunca las dos de C2 o de C3 juntas)
	for v in ["", "fina", "journal", "foto"]:
		for n in PC.node_defs(p, v):
			ok((n.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:")).size() <= 1, "%s/%s" % [v, n.get("id")])
	for n in PC.node_defs(p, ""):
		eq(str(n.get("cls")), "I", "las láminas son inmutables: %s" % n.get("id"))

func test_every_node_reachable_each_variant() -> void:
	var plan: Array = []
	for v in ["fina", "journal", "foto"]: plan.append(["*", 0, "T", v])
	eq(await PC.reach_problems(tree, _plate(), plan), [], "RB")

func test_photo_line_clippable_alone() -> void:
	var fr: Array = await PC.clip_alone_frames(tree, _plate(), "*", 0, "T", "linea", "foto")
	has(fr, "otra_orilla", "la línea oscura se recorta sola desde la otra orilla")

func test_ledge_hidden_from_path() -> void:
	# «une corniche que l'on ne voit pas du sentier»: desde el sendero no se ve ni se toca; desde la otra orilla sí
	var p := _plate()
	var wr = PC.make_world(tree)
	wr.show_plate(PC.snapshot(p, "*", "T", 0, "journal"), p)
	await tree.physics_frame
	await tree.physics_frame
	wr.set_frame("sendero", true)
	await tree.physics_frame
	var body = wr.node_body("cornisa")
	ok(RC.is_occluded(wr.camera(), body, wr.diorama, wr.excluded_rids()), "ocluida desde el sendero")
	eq(PC.pick_point(wr, "cornisa"), Vector2(-1, -1), "no se clica desde el sendero")
	wr.set_frame("otra_orilla", true)
	await tree.physics_frame
	no(RC.is_occluded(wr.camera(), body, wr.diorama, wr.excluded_rids()), "visible desde la otra orilla")
	ok(PC.pick_point(wr, "cornisa").x >= 0.0, "se clica desde la otra orilla")
	PC.free_world(wr)

func test_builders_deterministic_and_distinct() -> void:
	var counts := {}
	for v in ["fina", "journal", "foto"]:
		var a = PL.build_reichenbach({"variant": v, "seed": 1891})
		var b = PL.build_reichenbach({"variant": v, "seed": 1891})
		var ca: int = a.find_children("*", "MeshInstance3D", true, false).size()
		eq(ca, b.find_children("*", "MeshInstance3D", true, false).size(), "%s determinista" % v)
		eq(a.get_meta("occ"), b.get_meta("occ"), "%s oclusores iguales" % v)
		counts[v] = ca
		a.free(); b.free()
	ne(counts["fina"], counts["journal"], "FINA y Journal no son la misma roca")
	var s = PL.build_reichenbach_saliente({"variant": "journal"})
	ok(s.get_meta("occ").size() >= 3, "el saliente tapa")
	s.free()

func test_prewarm() -> void:
	eq(await PC.prewarm_problems(tree, _plate()), [], "precalentado")
