# Tests de W2-PLACES-A (dueño de world/props/l2.gd y data/places/L2.json).
# - cada build_* de l2.gd construye headless con parámetros por defecto (meta occ, geometría); determinismo;
# - L2 válido; objetos de GDD §5 presentes; nodos del contrato §4.8 (C7.R4) con sus etiquetas;
# - todo nodo se ve en algún encuadre; los dos nodos de C7.R4 recortables solos; Wiggins visible en su encuadre.
extends "res://tests/test_base.gd"

const PLC = preload("res://tests/fixtures/w2placesa/places_check.gd")
const DB = preload("res://world/diorama_builder.gd")
const M = preload("res://world/materials.gd")
const L2_PATH := "res://world/props/l2.gd"

const TIMEOUT_S := 240.0

const BUILDERS := ["reading_room", "radial_desks", "center", "slip_basket", "cotter_desk", "seat_items", "arc_lamps", "readers",
	"attendant", "newspaper_lectern", "folio_shelves", "vestibule", "pendant_lamps", "standing_readers", "clerk", "strip_basket"]

# GDD §5, L2: catálogo general, papeletas (blancas y verdes), número de asiento, mesas radiales, mostrador con canastilla y,
# junto a ella, Cotter; su escritorio con el cesto de tiras; cúpula; luz eléctrica fría; Sala de Periódicos.
const GDD5_L2 := ["catalogo", "papeletas", "asiento", "mesas", "mostrador", "cotter_canastilla", "puesto_cotter", "cesto_tiras",
	"cupula", "lamparas", "tarima", "atril_periodicos", "colecciones", "puerta_sala"]

func after_each() -> void:
	PLC.free_world()

func test_every_l2_builder_default_params() -> void:
	var s: Script = load(L2_PATH)
	var n_ok := 0
	for fn in BUILDERS:
		ok(s.has_method("build_" + fn), "l2.build_%s" % fn)
		if not s.has_method("build_" + fn): continue
		var n = s.call("build_" + fn, {} if fn != "readers" else {"seats": [[11.25, 7.2, 1]]})
		ok(n is Node3D, "%s devuelve Node3D" % fn)
		if not (n is Node3D): continue
		ok(n.has_meta("occ"), "%s sin occ" % fn)
		for e in n.get_meta("occ", []):
			ok(e is AABB or e is Transform3D, "%s: occ mal formado" % fn)
		var box := M.aabb_of(n)
		ok(box.size.x > 0.0 and box.size.z > 0.0, "%s sin geometría %s" % [fn, str(box)])
		n.free()
		n_ok += 1
	eq(n_ok, BUILDERS.size(), "builders")

func test_l2_builders_deterministic() -> void:
	for fn in ["radial_desks", "center", "folio_shelves", "readers"]:
		var p := {"seed": 3, "n": 4} if fn != "readers" else {"seed": 3, "seats": [[11.25, 7.2, 1], [33.75, 8.3, -1]]}
		var a := DB.build_prop("l2." + fn, p)
		var b := DB.build_prop("l2." + fn, p)
		eq(PLC.multi_xforms(a), PLC.multi_xforms(b), "%s: misma semilla, misma geometría" % fn)
		a.free(); b.free()

func test_radial_geometry_helpers() -> void:
	var s: Script = load(L2_PATH)
	var b: Basis = s.radial_basis(90.0)
	ok((b * Vector3.RIGHT).is_equal_approx(Vector3(0, 0, 1)), "+X radial a 90° apunta a +Z")
	var f: Basis = s.facing_center(90.0)
	ok((f * Vector3.BACK).is_equal_approx(Vector3(0, 0, -1)), "+Z mira al centro desde 90°")
	ok((s.polar(0.0, 2.0) as Vector3).is_equal_approx(Vector3(2, 0, 0)))

func test_l2_data_valid() -> void:
	eq(PLC.repo_errors_for(repo(), "L2"), [], "L2 sin errores de carga/esquema")
	var pl := PLC.place(repo(), "L2")
	eq(PLC.bad_entity_tags(repo(), pl), [], "etiquetas e:/p: con entidades existentes")
	eq(PLC.dangling_props(pl), [], "nodos con prop existente")
	eq(PLC.bare_mentions(pl), [], "menciones con superficie explícita")
	eq((pl.areas as Dictionary).keys(), ["sala"], "un área, como schedule.places.L2")
	for k in ["M", "T", "N"]:
		eq(str(pl.light.get(k)), "electrica_fria", "luz eléctrica fría (%s)" % k)

func test_l2_gdd_objects_and_contract() -> void:
	var pl := PLC.place(repo(), "L2")
	var ids := PLC.node_ids(pl)
	for nid in GDD5_L2:
		has(ids, nid, "L2 tiene el nodo %s (GDD §5)" % nid)
	var cot := PLC.node_def(pl, "cotter_canastilla")
	has(cot.get("tags", []), "a:me_vigila_de_cerca", "N:L2.cotter_canastilla (C7 cerca)")
	has(cot.get("tags", []), "e:hombre_de_la_canastilla", "el sensor K-BM es entidad del recorte")
	var ces := PLC.node_def(pl, "cesto_tiras")
	has(ces.get("tags", []), "a:vinculo_mycroft", "N:L2.cesto_tiras (C7 mycroft)")
	has(ces.get("tags", []), "e:pall_mall", "clave de C7")
	ok(str(ces.examine).contains("GENES CLUB"), "el membrete recortado se lee")
	# ninguno de los dos lleva a la vez los dos grupos de C7 (T4)
	no(cot.tags.has("a:vinculo_mycroft"))
	no(ces.tags.has("a:me_vigila_de_cerca"))
	ok((pl.get("silhouettes", {}) as Dictionary).has("wiggins"), "Wiggins desde el día 3")
	eq(PLC.rastro_mismatch(repo(), "L2", pl), [], "rastros = etiquetas")

func test_l2_every_node_visible_somewhere() -> void:
	var pl := PLC.place(repo(), "L2")
	var miss: Array = await PLC.unseen_nodes(tree, pl, [{"day": 3, "slot": "M", "variant": ""}])
	eq(miss, [], "nodos de L2 que no se ven en ningún encuadre")

func test_l2_contract_nodes_clippable_alone() -> void:
	var pl := PLC.place(repo(), "L2")
	for nid in ["cotter_canastilla", "cesto_tiras"]:
		var r: Dictionary = await PLC.clip_alone_any_frame(tree, pl, nid, {"day": 3, "slot": "M", "variant": ""})
		ok(bool(r.ok), "L2.%s recortable solo: %s" % [nid, r.why])

func test_l2_silhouettes_unobstructed() -> void:
	var pl := PLC.place(repo(), "L2")
	for who in (pl.silhouettes as Dictionary):
		var fr := str(pl.silhouettes[who].frame)
		var wr = await PLC._show(tree, pl, {"day": 3, "slot": "M", "variant": ""}, fr)
		eq(PLC.visibility(wr, "sil_" + str(who)), "", "%s sin tapar en %s" % [who, fr])

# Toda silueta que una reacción pone en L2 o en todo lugar (Wiggins, cochero, HB8b muchacho sin gorra) tiene su lugar.
func test_l2_silhouettes_cover_reactions() -> void:
	var pl := PLC.place(repo(), "L2")
	var whos := PLC.reaction_silhouettes(repo(), "L2")
	if whos.is_empty():
		pending_content("sin reacciones con op silueta todavía"); return
	for who in whos:
		ok((pl.get("silhouettes", {}) as Dictionary).has(who), "L2 sin silueta «%s» (op silueta de una reacción)" % who)

func test_l2_characters_clickable() -> void:
	var pl := PLC.place(repo(), "L2")
	eq(await PLC.unclickable_chars(tree, pl, [{"day": 3, "slot": "M"}]), [], "el ujier se puede clicar")
