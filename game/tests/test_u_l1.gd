# Tests de W2-PLACES-A (dueño de world/props/l1.gd, data/places/L1.json, data/plates/{PRO,M7}.json).
# - cada build_* de l1.gd construye headless con parámetros por defecto, con meta occ y geometría; determinismo;
# - L1, PRO y M7 válidos (repo sin errores en estos archivos; entidades de etiquetas existentes, también en variantes);
# - objetos de GDD §5 presentes; nodos del contrato §4.8 con sus etiquetas exactas (las de los rastros de W2-STRUCT);
# - todo nodo se ve (mayoría de puntos de muestra a la vista, dentro del cuadro) en al menos un encuadre de su lámina;
# - nodos del contrato recortables solos (cover ≥ 0,5, tight, rectángulo ≤ 1/8 de la pantalla).
extends "res://tests/test_base.gd"

const PLC = preload("res://tests/fixtures/w2placesa/places_check.gd")
const DB = preload("res://world/diorama_builder.gd")
const M = preload("res://world/materials.gd")
const L1_PATH := "res://world/props/l1.gd"

const TIMEOUT_S := 240.0

const BUILDERS := ["marker", "reading_stand", "notebook", "thick_book", "spectacles_case", "banknotes", "clipping", "loose_papers",
	"drawer_out", "footprint", "rug", "washstand", "peg_rail", "gas_bracket", "counter_lamp", "shop_window", "shop_door", "paper_lot",
	"photo_box", "newspaper_bundle", "magazine_stack", "book_table", "stair_glimpse", "own_front", "holywell_row", "reflection", "trunk"]

# GDD §5, L1 (GDD_v2 §C.4: sin lupa ni regla): escritorio (lector, cuaderno, libro de conclusiones, tijera, sello), bandeja, cinco tomos, cajón con la
# galerada, concordancia, mapa con horarios, calendario de escritorio, estufa, ventana a la calle (aleros salientes), y la tienda:
# estantes, libro de ventas, mostrador. Más lo que pide el resto del GDD (mechero bajo de la tienda, monedas sobre la mesa).
const GDD5_L1 := ["escritorio", "atril", "cuaderno", "libro_mayor", "tijera", "sello", "bandeja", "tomos", "cajon",
	"concordancia", "mapa", "calendario", "estufa", "ventana", "enfrente", "monedas", "estantes_libros", "estantes_revistas",
	"libro_ventas", "mostrador", "mechero", "papel_peso", "fotografias", "diarios", "revistas", "escaparate"]

# §4.8 + rastros de data/reactions (HC07, M1): id → etiquetas exactas
const CONTRACT_L1 := {
	"librero_dedos": ["a:rasgo_holmes", "e:librero", "e:amarillo"],
	"librero_sombra": ["a:librero_falso", "e:librero", "e:sombra"],
}
const CONTRACT_L1_REG := {
	"ceniza_registro": ["a:tirador", "e:cheroot", "e:ceniza_negra", "f:secreto_camden"],
	"pisada": ["e:pisada", "e:registro_de_la_buhardilla"],
}

func after_each() -> void:
	PLC.free_world()

func test_every_l1_builder_default_params() -> void:
	var n_ok := 0
	var s: Script = load(L1_PATH)
	for fn in BUILDERS:
		ok(s.has_method("build_" + fn), "l1.build_%s" % fn)
		if not s.has_method("build_" + fn): continue
		var n = s.call("build_" + fn, {})
		ok(n is Node3D, "%s devuelve Node3D" % fn)
		if not (n is Node3D): continue
		ok(n.has_meta("occ"), "%s sin occ" % fn)
		for e in n.get_meta("occ", []):
			ok(e is AABB or e is Transform3D, "%s: occ mal formado" % fn)
		if fn != "marker":
			var box := M.aabb_of(n)
			ok(box.size.x > 0.0 and box.size.y >= 0.0 and box.size.z > 0.0, "%s sin geometría %s" % [fn, str(box)])
		n.free()
		n_ok += 1
	eq(n_ok, BUILDERS.size(), "builders")

func test_l1_builders_deterministic() -> void:
	for fn in ["holywell_row", "shop_window", "paper_lot", "book_table"]:
		var a := DB.build_prop("l1." + fn, {"seed": 5})
		var b := DB.build_prop("l1." + fn, {"seed": 5})
		eq(PLC.multi_xforms(a), PLC.multi_xforms(b), "%s: misma semilla, misma geometría" % fn)
		eq(M.aabb_of(a), M.aabb_of(b), "%s: misma caja" % fn)
		a.free(); b.free()

func test_counter_lamp_casts_shadow_and_is_always_on() -> void:
	var n := DB.build_prop("l1.counter_lamp", {"stand": 0.62})
	var o: OmniLight3D = n.find_children("*", "OmniLight3D", true, false)[0]
	ok(o.shadow_enabled, "la luz del mechero hace sombra (la del librero llega al techo)")
	ok(M._rel_xform(n, o).origin.y < 1.0, "llama baja: por debajo de 1 m")
	no(o.has_meta("light"), "no la apaga Lighting de día")
	n.free()

func test_l1_data_valid() -> void:
	for id in ["L1", "PRO", "M7"]:
		eq(PLC.repo_errors_for(repo(), id), [], "%s sin errores de carga/esquema" % id)
		eq(PLC.bad_entity_tags(repo(), PLC.place(repo(), id)), [], "%s: etiquetas e:/p: con entidades existentes" % id)
		eq(PLC.dangling_props(PLC.place(repo(), id)), [], "%s: nodos con prop existente" % id)
		eq(PLC.bare_mentions(PLC.place(repo(), id)), [], "%s: menciones con superficie explícita" % id)

func test_l1_gdd_objects_and_frames() -> void:
	var pl := PLC.place(repo(), "L1")
	var ids := PLC.node_ids(pl)
	for nid in GDD5_L1:
		has(ids, nid, "L1 tiene el nodo %s (GDD §5)" % nid)
	for nid in ["lupa", "regla"]:
		no(ids.has(nid), "GDD_v2 §C.4: sin el nodo %s" % nid)
	var fr := {}
	for f in pl.frames: fr[str(f.id)] = str(f.get("area", "*"))
	eq(fr.get("escritorio"), "buhardilla"); eq(fr.get("ventana"), "buhardilla"); eq(fr.get("pared"), "buhardilla")
	for f in ["mostrador", "estantes", "escaparate"]: eq(fr.get(f), "tienda", "encuadre %s de la tienda" % f)
	ok((pl.get("silhouettes", {}) as Dictionary).has("wiggins"), "Wiggins por la ventana (desde el día 3)")
	eq(str(pl.silhouettes.wiggins.frame), "ventana")
	has((pl.get("variants", {}) as Dictionary).keys(), "registrada", "variante M1")

func test_l1_contract_nodes_and_tags() -> void:
	var pl := PLC.place(repo(), "L1")
	for nid in CONTRACT_L1:
		var nd := PLC.node_def(pl, nid)
		ok(not nd.is_empty(), "N:L1.%s existe" % nid)
		eq(PLC.sorted(nd.get("tags", [])), PLC.sorted(CONTRACT_L1[nid]), "N:L1.%s etiquetas" % nid)
		eq(nd.get("when"), {"all": [{"day": 10}, {"slot": ["M"]}]}, "N:L1.%s sólo el día 10 por la mañana (HC07)" % nid)
		eq(str(nd.get("area")), "tienda")
	for nid in CONTRACT_L1_REG:
		var nd2 := PLC.node_def(pl, nid, "registrada")
		ok(not nd2.is_empty(), "N:L1.%s en la variante registrada" % nid)
		eq(PLC.sorted(nd2.get("tags", [])), PLC.sorted(CONTRACT_L1_REG[nid]), "N:L1.%s etiquetas" % nid)
	# los rastros que nombran estos nodos llevan las mismas etiquetas (si W2-STRUCT ya publicó las reacciones)
	var mism := PLC.rastro_mismatch(repo(), "L1", pl)
	eq(mism, [], "rastros de reacciones = etiquetas de los nodos")

func test_prologue_and_m7_plates() -> void:
	var pro := PLC.place(repo(), "PRO")
	ok(bool(pro.get("fixed", false)), "PRO fija")
	eq(str(pro.get("origin")), "PL.prologo")
	var h := PLC.node_def(pro, "harris")
	ok(not h.is_empty(), "N:PRO.harris")
	for t in ["a:harris_es_moran", "a:tirador", "e:harris", "e:bigote", "f:secreto_camden"]:
		has(h.get("tags", []), t, "N:PRO.harris lleva %s (C10 Ia, C10a, C13.R3)" % t)
	for nid in ["reflejo", "parker", "cotter_enfrente", "pell"]:
		ok(not PLC.node_def(pro, nid).is_empty(), "PRO: %s (GDD §3.2/§5)" % nid)
	var chars: Array = []
	for c in pro.characters: chars.append(str(c.id))
	eq(PLC.sorted(chars), ["harris", "pell"])
	var m7 := PLC.place(repo(), "M7")
	eq(str(m7.get("origin")), "PL.M7")
	ok(not PLC.node_def(m7, "ceniza").is_empty(), "M7: ceniza en el escritorio")
	has(PLC.node_def(m7, "ceniza").get("tags", []), "a:tirador")
	ok(not PLC.node_def(m7, "harris").is_empty(), "M7: Harris")

func test_l1_every_node_visible_somewhere() -> void:
	var pl := PLC.place(repo(), "L1")
	var scen := [{"day": 3, "slot": "M", "variant": ""}, {"day": 10, "slot": "M", "variant": ""}, {"day": 4, "slot": "M", "variant": "registrada"}]
	var miss: Array = await PLC.unseen_nodes(tree, pl, scen)
	eq(miss, [], "nodos de L1 que no se ven en ningún encuadre")

func test_plates_every_node_visible_somewhere() -> void:
	for id in ["PRO", "M7"]:
		var pl := PLC.place(repo(), id)
		var miss: Array = await PLC.unseen_nodes(tree, pl, [{"day": int(pl.get("day", 0)), "slot": str(pl.get("slot", "N")), "variant": ""}], false)
		eq(miss, [], "nodos de %s que no asoman en ningún encuadre" % id)
		# lo que cuenta la lámina se ve bien (mayoría de los puntos de muestra), no sólo asoma
		var key: Array = ["harris", "reflejo", "parker", "cotter_enfrente", "pell"] if id == "PRO" else ["harris", "ceniza"]
		var strict_miss: Array = await PLC.unseen_nodes(tree, pl, [{"day": int(pl.get("day", 0)), "slot": str(pl.get("slot", "N")), "variant": ""}], true)
		for m in strict_miss:
			no(key.has(str(m).get_slice(":", 0)), "%s: %s" % [id, m])

func test_characters_clickable() -> void:
	var pl := PLC.place(repo(), "L1")
	var scen := [{"day": 3, "slot": "M"}, {"day": 10, "slot": "M"}, {"day": 5, "slot": "dawn"}, {"day": 2, "slot": "night"}]
	eq(await PLC.unclickable_chars(tree, pl, scen), [], "personajes de L1 sin clic en ningún encuadre (Crane, librero, Pell, chico de Pell)")
	for id in ["PRO", "M7"]:
		var pp := PLC.place(repo(), id)
		eq(await PLC.unclickable_chars(tree, pp, [{"day": int(pp.day), "slot": str(pp.slot)}]), [], "%s: personajes sin clic" % id)

func test_contract_nodes_clippable_alone() -> void:
	var cases := [
		["L1", "librero_dedos", {"day": 10, "slot": "M", "variant": ""}],
		["L1", "librero_sombra", {"day": 10, "slot": "M", "variant": ""}],
		["L1", "ceniza_registro", {"day": 4, "slot": "M", "variant": "registrada"}],
		["PRO", "harris", {"day": 0, "slot": "N", "variant": ""}],
		["M7", "ceniza", {"day": 7, "slot": "night", "variant": ""}],
	]
	for c in cases:
		var r: Dictionary = await PLC.clip_alone_any_frame(tree, PLC.place(repo(), c[0]), str(c[1]), c[2])
		ok(bool(r.ok), "%s.%s recortable solo: %s" % [c[0], c[1], r.why])

# Toda silueta que una reacción pone en L1 (o en todo lugar: HC02 Wiggins, M11 cochero, HB8b muchacho sin gorra) tiene su
# lugar en la ventana; si faltara, tras HB8b desaparecería el vigía de K-S de la calle de Holywell Street.
func test_silhouettes_cover_reactions() -> void:
	var pl := PLC.place(repo(), "L1")
	var whos := PLC.reaction_silhouettes(repo(), "L1")
	if whos.is_empty():
		pending_content("sin reacciones con op silueta todavía"); return
	for who in whos:
		ok((pl.get("silhouettes", {}) as Dictionary).has(who), "L1 sin silueta «%s» (op silueta de una reacción)" % who)

# Día 10: el librero mira al encuadre principal de la tienda (el de la confrontación), con los dedos (y los libros)
# delante del cuerpo; ningún personaje de la tienda queda pegado a la cámara de un encuadre (< 1,5 m delante).
func test_shop_composition_day10() -> void:
	var pl := PLC.place(repo(), "L1")
	var fr := {}
	for f in pl.frames: fr[str(f.id)] = f
	var lib := {}
	for c in pl.characters:
		if str(c.id) == "librero": lib = c
	ok(not lib.is_empty(), "librero en L1")
	var pos := PLC.v3(lib.pos)
	var face := Basis(Vector3.UP, deg_to_rad(float(lib.get("rot", 0.0)))) * Vector3.BACK  # Mannequin mira a +Z
	var to_cam := PLC.v3(fr["mostrador"].pos) - pos
	to_cam.y = 0.0
	ok(face.dot(to_cam.normalized()) > 0.85, "el librero mira al encuadre «mostrador» (%.2f)" % face.dot(to_cam.normalized()))
	var dd := PLC.node_def(pl, "librero_dedos")
	var off := PLC.v3(dd.anchor.c) - pos
	off.y = 0.0
	ok(face.dot(off) > 0.2, "N:L1.librero_dedos delante del librero (%.2f)" % face.dot(off))
	for fid in ["mostrador", "estantes", "escaparate"]:
		var f: Dictionary = fr[fid]
		var cam := PLC.v3(f.pos)
		var fwd := (PLC.v3(f.look) - cam).normalized()
		for c in pl.characters:
			if str(c.get("area", "*")) != "tienda": continue
			var rel := PLC.v3(c.pos) - cam
			rel.y = 0.0
			var along := rel.dot(Vector3(fwd.x, 0.0, fwd.z).normalized())
			ok(along < 0.3 or rel.length() > 1.5, "%s pegado a la cámara de «%s» (%.2f m)" % [c.id, fid, rel.length()])

func test_hub_show_and_frames() -> void:
	tree.root.size = Vector2i(1600, 900)
	var wr = PLC.new_world(tree)
	wr.show_hub("escritorio", "M")
	await tree.physics_frame
	ok(wr.diorama != null, "hub L1")
	ok(wr.orbit_enabled, "v2 (GDD_v2 §E): en casa también se mira alrededor")
	eq(PLC.sorted(wr.frames()), ["escritorio", "pared", "ventana"], "encuadres del hub (buhardilla)")
	wr.show_hub("mostrador", "T")
	await tree.physics_frame
	eq(PLC.sorted(wr.frames()), ["escaparate", "estantes", "mostrador"], "encuadres de la tienda")
