# Tests de L4 (W2-PLACES-C): data/places/L4.json + world/props/l4.gd. ARCHITECTURE §4.11, §7.3, §4.8 (C14), GDD§5.
extends "res://tests/test_base.gd"

const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")
const DB = preload("res://world/diorama_builder.gd")
const TIMEOUT_S := 180.0

# [área, día, franja]: consulta un martes por la mañana (desde el día 3: siluetas), el domingo en el estudio
const PLAN := [["consulta", 3, "M"], ["estudio", 6, "T"]]

func _place() -> Dictionary:
	return repo().place("L4")

func test_loads_without_errors() -> void:
	var r = repo()
	var mine: Array = []
	for e in r.errors():
		if str(e).contains("places/L4.json") or str(e).contains("entities/places_c.json"): mine.append(e)
	eq(mine, [], "errores de carga de L4")
	ok(not _place().is_empty(), "L4 cargado")

func test_static_checks() -> void:
	eq(PC.static_problems(repo(), _place()), [], "L4")

func test_contract_nodes() -> void:
	var p := _place()
	# §4.8 C14.R3: N:L4.hueco_estante / N:L4.crespon con sus grupos; visibles desde el día 1 (consulta) → área «*»
	var hueco := PC.find_node(p, "hueco_estante")
	ok(PC.has_tags(hueco, ["a:tomos_de_watson", "c:watson_privado"]), "hueco_estante: %s" % str(hueco.get("tags")))
	eq(str(hueco.get("area")), "*", "hueco_estante visible en la consulta y el domingo")
	var cr := PC.find_node(p, "crespon")
	ok(PC.has_tags(cr, ["a:duelo", "c:watson_privado"]), "crespon: %s" % str(cr.get("tags")))
	eq(str(cr.get("prop")), "perchero", "crespón en el perchero")
	# la ventana a Church Street muestra la esquina sin librería (GDD§5) → refuerza librero_falso (C12)
	ok(PC.has_tags(PC.find_node(p, "esquina"), ["a:librero_falso"]), "esquina")
	# ningún nodo carga los dos grupos de una misma variante de pregunta (T4 por nodo, GDD_v3 §1.8; CONTENIDO)
	for n in PC.node_defs(p, "") + PC.node_defs(p, "prestadas"):
		var a_tags := (n.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:")).map(func(t): return str(t).substr(2))
		for q in repo().questions():
			for v in q.get("variantes", []):
				var hit := 0
				for g in v.get("grupos", []):
					for t in g.get("tags", []):
						if a_tags.has(str(t).trim_prefix("a:")):
							hit += 1
							break
				ok(hit < 2, "%s cubre los dos grupos de %s.%s: %s" % [n.get("id"), q.id, v.id, str(a_tags)])
	# el recibo de HB5 (variante «prestadas»): Q3 (vinculo_mycroft) y Q4 (mycroft_gobierno, con la mención del ministerio)
	ok(PC.has_tags(PC.find_node(p, "recibo", "prestadas"), ["a:vinculo_mycroft", "a:mycroft_gobierno"]), "recibo p.p. M. H. (Q3, Q4)")
	eq(p.get("areas", {}).keys(), ["consulta", "estudio"], "áreas de §4.10/§4.11")

func test_characters_by_area_and_slot() -> void:
	var p := _place()
	var ids := func(s: Dictionary) -> Array: return s["chars"].map(func(c): return c["id"])
	eq(ids.call(PC.snapshot(p, "consulta", "M", 3)), ["watson"], "Watson atiende de mañana")
	eq(ids.call(PC.snapshot(p, "consulta", "T", 3)), [], "de tarde no hay consulta")
	eq(ids.call(PC.snapshot(p, "estudio", "T", 6)), ["watson"], "el domingo recibe en el estudio")
	var st := PC.snapshot(p, "estudio", "T", 6)
	eq(st["chars"][0]["pose"], "sentado", "sentado junto al fuego")

func test_variant_prestadas() -> void:
	var p := _place()
	var s := PC.snapshot(p, "consulta", "M", 4, "prestadas")
	ok(s["nodes"].has("recibo"), "queda el recibo")
	no(s["nodes"].has("pruebas"), "las pruebas no están")
	ok(PC.has_tags(PC.find_node(p, "recibo", "prestadas"), ["a:vinculo_mycroft"]), "recibo p.p. M. H.")
	var d := DB.build(p, s)
	# contrato §4.11 (add_nodes + move): el legajo se mueve bajo el piso del estudio; no queda a la vista
	var pp = d.get_node("Props").get_node_or_null("pruebas_p")
	ok(pp == null or (pp as Node3D).position.y < -0.5, "sin el legajo sobre la mesa")
	ok(d.get_node("Props").has_node("recibo_p"), "con el recibo")
	d.free()

# Con el WorldModel REAL (W2-SIM): mientras snapshot no lea remove_nodes, `pruebas` sigue en la instantánea; el legajo y
# su nodo viajan bajo el piso (move): desde ningún encuadre se clica ni se recorta, y en su lugar se clica el recibo.
func test_variant_prestadas_with_real_snapshot() -> void:
	var p := _place()
	var sim = load("res://core/sim/game_sim.gd").new(repo(), 7)
	sim.st.clock.day = 4
	sim.st.clock.slot = "M"
	var s: Dictionary = load("res://core/sim/world_model.gd").snapshot(sim.st, repo(), "L4", "consulta", "prestadas")
	ok(s["nodes"].has("recibo"), "recibo en la instantánea real")
	s["id"] = "PL.L4.4.M"
	var wr = PC.make_world(tree)
	wr.show_plate(s, p)
	await tree.physics_frame
	await tree.physics_frame
	var recibo_ok := false
	for f in PC.frames_for(p, "consulta"):
		wr.set_frame(f, true)
		await tree.physics_frame
		if s["nodes"].has("pruebas"):
			eq(PC.pick_point(wr, "pruebas"), Vector2(-1, -1), "pruebas no se clica desde %s" % f)
			var cam: Camera3D = wr.camera()
			var vp := cam.get_viewport().get_visible_rect()
			var res: Dictionary = wr.rect_clip(vp.grow(-vp.size.x * 0.33))
			no(res["touched"].has("pruebas"), "pruebas no se toca desde %s" % f)
		if PC.pick_point(wr, "recibo").x >= 0.0: recibo_ok = true
	ok(recibo_ok, "el recibo se clica desde algún encuadre de la consulta")
	PC.free_world(wr)

# WorldModel.snapshot elige el primer encuadre del área: la consulta abre en el consultorio y el domingo en el estudio
# (con Watson sentado), no en la sala de espera.
func test_initial_frame_by_area_real_snapshot() -> void:
	var sim = load("res://core/sim/game_sim.gd").new(repo(), 7)
	var WMs = load("res://core/sim/world_model.gd")
	sim.st.clock.day = 3
	sim.st.clock.slot = "M"
	eq(WMs.snapshot(sim.st, repo(), "L4", "consulta", "")["frame"], "consultorio", "consulta")
	sim.st.clock.day = 6
	sim.st.clock.slot = "T"
	eq(WMs.snapshot(sim.st, repo(), "L4", "estudio", "")["frame"], "estudio", "domingo")

# «Todo lo visible se puede examinar» (GDD§5): lo que se ve del estudio por el vano desde la consulta es examinable allí.
func test_study_seen_through_the_arch_is_examinable() -> void:
	var p := _place()
	var s := PC.snapshot(p, "consulta", "M", 3)
	for nid in ["sillon", "chimenea_e", "retrato", "comoda", "cajon_manuscrito"]:
		ok((s["nodes"] as Array).has(nid), "%s en la consulta" % nid)

func test_every_node_reachable_and_silhouettes() -> void:
	eq(await PC.reach_problems(tree, _place(), PLAN), [], "L4")

func test_contract_nodes_clippable_alone() -> void:
	var p := _place()
	for nid in ["hueco_estante", "crespon", "esquina"]:
		var fr: Array = await PC.clip_alone_frames(tree, p, "consulta", 3, "M", nid)
		ok(not fr.is_empty(), "%s no se recorta solo desde ningún encuadre de la consulta" % nid)
	var fr2: Array = await PC.clip_alone_frames(tree, p, "estudio", 6, "T", "hueco_estante")
	ok(not fr2.is_empty(), "hueco_estante el domingo")

func test_gap_is_five_volumes_wide() -> void:
	# el hueco del segundo estante mide lo que cinco tomos de la Strand (≈ 6 cm de lomo): entre 0,28 y 0,36 m
	var p := _place()
	var pr: Dictionary = {}
	for x in p["props"]:
		if x["id"] == "biblioteca": pr = x
	var gw := float(pr["p"]["gap_to"]) - float(pr["p"]["gap_from"])
	ok(gw >= 0.28 and gw <= 0.36, "ancho %.2f" % gw)
	var bc = load("res://world/props/l4.gd").build_bookcase(pr["p"])
	ok(bc.get_meta("occ").size() >= 4, "oclusores")
	bc.free()

func test_prewarm() -> void:
	eq(await PC.prewarm_problems(tree, _place()), [], "precalentado")

func test_props_build() -> void:
	var L4 = load("res://world/props/l4.gd")
	for fn in ["couch", "instrument_cabinet", "stethoscope", "framed", "bench", "periodicals", "umbrella_stand", "galley_bundle",
			"notebook_leaves", "chest_open", "mourning_portrait", "receipt", "bookcase", "prescription_book"]:
		var n = L4.call("build_" + fn, {})
		ok(n is Node3D and n.has_meta("occ"), fn)
		n.free()

func test_eggs_and_reaction_nodes() -> void:
	var p := _place()
	# EE04 (easter_eggs.json): N:L4.cajon_manuscrito lleva x:EE04 y ninguna etiqueta de conclusión (T13)
	var cj := PC.find_node(p, "cajon_manuscrito")
	ok(PC.has_tags(cj, ["x:EE04"]), "x:EE04")
	eq((cj.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:")), [], "sin a:")
	# HB5 (reactions/mycroft.json): rastro N:L4.recibo con a:vinculo_mycroft — existe en la variante «prestadas»
	ok(PC.has_tags(PC.find_node(p, "recibo", "prestadas"), ["a:vinculo_mycroft", "e:remington_s_alzada"]), "recibo")
	# M3 (reactions/moran.json): N:L4.sil_m3_hombres
	ok((p.get("silhouettes", {}) as Dictionary).has("m3_hombres"), "silueta de M3")
