# Tests de L5 (W2-PLACES-C): data/places/L5.json + world/props/l5.gd. ARCHITECTURE §4.11, §7.3; GDD§5 (L5), HC06, HB12.
extends "res://tests/test_base.gd"

const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")
const TIMEOUT_S := 180.0

# portería un jueves de mañana y de noche; Sala de Forasteros el martes 3 (día 8) de tarde
const PLAN := [["porteria", 3, "M"], ["porteria", 4, "N"], ["forasteros", 8, "T"]]

func _place() -> Dictionary:
	return repo().place("L5")

func test_loads_without_errors() -> void:
	var mine: Array = []
	for e in repo().errors():
		if str(e).contains("places/L5.json"): mine.append(e)
	eq(mine, [], "errores de carga de L5")
	ok(not _place().is_empty(), "L5 cargado")

func test_static_checks() -> void:
	eq(PC.static_problems(repo(), _place()), [], "L5")

func test_areas_and_contract() -> void:
	var p := _place()
	eq(p.get("areas", {}).keys(), ["porteria", "forasteros"], "áreas de §4.10")
	# D31 se lee en la portería (del revés, sobre el mostrador); el nodo es el libro físico
	var lt := PC.find_node(p, "libro_telegramas")
	eq(str(lt.get("area")), "porteria", "libro en la portería")
	eq(str(lt.get("_doc")), "D31@L5", "abre D31")
	# el papel del club (medible en HC06 (f)) lleva el vínculo con Mycroft (C7) en la mesa de la Sala de Forasteros
	ok(PC.has_tags(PC.find_node(p, "papel_mesa"), ["a:vinculo_mycroft"]), "papel en la mesa")
	ok(PC.has_tags(PC.find_node(p, "papel_club"), ["a:vinculo_mycroft"]), "papel en la portería")
	# registros públicos de la portería: clase I; la Sala de Forasteros la cierra HB12: clase C
	eq(str(lt.get("cls")), "I", "D31 inmutable")
	eq(str(PC.find_node(p, "mesa_forasteros").get("cls")), "C", "Forasteros cortable")
	for n in PC.node_defs(p, ""):
		var a_tags := (n.get("tags", []) as Array).filter(func(t): return str(t).begins_with("a:"))
		ok(a_tags.size() <= 1, "%s lleva %s" % [n.get("id"), str(a_tags)])

func test_characters() -> void:
	var p := _place()
	var ids := func(s: Dictionary) -> Array: return s["chars"].map(func(c): return c["id"])
	eq(ids.call(PC.snapshot(p, "porteria", "M", 1)), ["portero"], "el portero siempre")
	eq(ids.call(PC.snapshot(p, "forasteros", "T", 8)), ["mycroft"], "Mycroft el martes 3")
	eq(ids.call(PC.snapshot(p, "forasteros", "N", 9)), ["mycroft"], "y el miércoles 4 de noche")
	eq(ids.call(PC.snapshot(p, "forasteros", "T", 7)), [], "no antes del día 8")
	eq(ids.call(PC.snapshot(p, "forasteros", "M", 8)), [], "no de mañana (16:45 a 19:40)")
	eq(PC.snapshot(p, "forasteros", "T", 8)["chars"][0]["trait"], "esfera_panuelo", "rasgo de Mycroft (§7.4)")

func test_every_node_reachable_and_silhouettes() -> void:
	eq(await PC.reach_problems(tree, _place(), PLAN), [], "L5")

func test_wiggins_seen_from_both_rooms() -> void:
	# HC02: la silueta se ve en cada visita (también en la Sala de Forasteros, que da a Pall Mall)
	var p := _place()
	for pl in [["porteria", "pall_mall"], ["forasteros", "mirador"]]:
		var wr = PC.make_world(tree)
		wr.show_plate(PC.snapshot(p, pl[0], "T", 8), p)
		await tree.physics_frame
		wr.set_frame(pl[1], true)
		await tree.physics_frame
		eq(PC.visible_in_frame(wr, "sil_wiggins"), "", "Wiggins desde %s" % pl[1])
		eq(PC.visible_in_frame(wr, "sil_cochero"), "", "cochero desde %s" % pl[1])
		PC.free_world(wr)

func test_telegram_book_and_paper_clippable() -> void:
	var p := _place()
	ok(not (await PC.clip_alone_frames(tree, p, "porteria", 3, "M", "libro_telegramas")).is_empty(), "libro de telegramas")
	ok(not (await PC.clip_alone_frames(tree, p, "forasteros", 8, "T", "papel_mesa")).is_empty(), "papel del club en la mesa")

func test_props_build() -> void:
	var L5 = load("res://world/props/l5.gd")
	for fn in ["glass_screen", "pigeonholes", "card_tray", "stationery", "long_case_clock", "notice", "bow_window", "reading_nook", "snuff_box"]:
		var n = L5.call("build_" + fn, {})
		ok(n is Node3D and n.has_meta("occ"), fn)
		n.free()

func test_prewarm() -> void:
	eq(await PC.prewarm_problems(tree, _place()), [], "precalentado")
