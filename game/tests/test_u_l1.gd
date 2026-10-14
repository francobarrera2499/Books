# Tests de W2-PLACES-A → v3 REACCIONES-PIEZA (dueño de world/props/l1.gd y data/places/L1.json; PRO y M7 son de CONTENIDO).
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
const RIG = preload("res://world/camera_rig.gd")

const TIMEOUT_S := 240.0

const BUILDERS := ["marker", "reading_stand", "notebook", "thick_book", "spectacles_case", "banknotes", "clipping", "loose_papers",
	"drawer_out", "footprint", "rug", "washstand", "peg_rail", "gas_bracket", "counter_lamp", "shop_window", "shop_door", "paper_lot",
	"photo_box", "newspaper_bundle", "magazine_stack", "book_table", "stair_glimpse", "own_front", "holywell_row", "reflection", "trunk",
	"sash_frame", "sash_lower", "sash_lock", "curtain", "desk_drawer", "dossier_folder", "soot_print", "lock_scratches", "ash_flakes"]

# GDD_v3 §6.4: en la buhardilla sólo es interactivo lo útil (y lo que cambió: variantes); en la tienda se quitan los
# estantes de sermones, varios y del fondo, el escaparate y la puerta de la calle. Lo que deja de ser nodo sigue como prop.
const V3_L1 := ["bandeja", "tintero", "cuaderno", "expediente", "estante", "mapa", "puerta", "ventana", "calle", "enfrente",
	"mostrador", "libro_ventas", "mechero", "estantes_libros", "estantes_revistas", "estantes_viajes", "revistas", "fotografias",
	"mesa_saldos", "papel_peso", "diarios", "escalera_tienda", "librero_dedos", "librero_sombra"]
# playtest v3: los tomos y la tijera del escritorio se quitaron (parecían usables y no hacían nada; las crónicas están
# en el estante y la tijera es la del lector y el cuaderno)
const V3_DECOR_PROPS := ["escritorio", "silla", "atril", "calendario", "sello", "lampara", "monedas", "mesita",
	"concordancia", "estuche", "pliegos", "brazo_gas", "estufa", "cama", "lavamanos", "percha", "escaparate", "puerta_calle"]
const V3_GONE_PROPS := ["tomos", "tijera"]

# §4.8 + rastros de data/reactions (HC07, M1, HA5): id → etiquetas exactas
const CONTRACT_L1 := {
	"librero_dedos": ["a:rasgo_holmes", "e:librero", "e:amarillo"],
	"librero_sombra": ["a:librero_falso", "e:librero", "e:sombra"],
}
const CONTRACT_L1_REG := {
	"ceniza_escritorio": ["a:entraron_por_la_puerta", "e:cheroot", "e:ceniza_negra"],
	"cerradura_rayada": ["a:entraron_por_la_puerta", "e:cerradura"],
	"cajon_entreabierto": ["a:entraron_por_la_puerta", "e:cajon_del_escritorio"],
	"silla_corrida": ["a:entraron_por_la_puerta"],
}
const CONTRACT_L1_TECHOS := {
	"ventana_abierta": ["a:entro_por_los_techos", "e:techos", "e:muchacho"],
	"papeles_viento": [],
}

func after_each() -> void:
	PLC.free_world()

# v3 (GDD_v3 §6.6, UI-MUNDO): la cámara recorre un riel por área (world/camera.json); lo que ve el jugador son los puntos
# del riel (buhardilla: escritorio, estante, plano, puerta, ventana; tienda: 4), no sólo los frames de L1.json. Copia del
# lugar con frames = puntos del riel {id, area} (sin riel: el lugar tal cual).
static func _rail_place(pl: Dictionary) -> Dictionary:
	var all: Dictionary = RIG.cfg_all()
	var fr: Array = []
	for k in all:
		if not str(k).begins_with(str(pl.get("id", "")) + ".") or typeof(all[k]) != TYPE_DICTIONARY: continue
		for r in all[k].get("rail", []):
			if typeof(r) == TYPE_DICTIONARY: fr.append({"id": str(r.id), "area": str(k).get_slice(".", 1)})
	if fr.is_empty(): return pl
	var out := pl.duplicate()
	out["frames"] = fr
	return out

static func _rail_ids(place_area: String) -> Array:
	var c = RIG.cfg_all().get(place_area, {})
	var out: Array = []
	if typeof(c) == TYPE_DICTIONARY:
		for r in c.get("rail", []): out.append(str(r.id))
	out.sort()
	return out

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
	var ids: Array = []
	for n in pl.nodes: ids.append(str(n.id))
	eq(PLC.sorted(ids), PLC.sorted(V3_L1), "GDD_v3 §6.4: sólo lo útil es nodo")
	for nid in ["lupa", "regla", "cama", "libro_mayor", "tijera"]:
		no(PLC.node_ids(pl).has(nid), "sin el nodo %s" % nid)
	var props: Array = []
	for p in pl.props: props.append(str(p.id))
	for pid in V3_DECOR_PROPS:
		has(props, pid, "la decoración sigue como prop (%s)" % pid)
	for pid in V3_GONE_PROPS:
		no(props.has(pid), "sin %s sobre el escritorio" % pid)
	var fr := {}
	for f in pl.frames: fr[str(f.id)] = str(f.get("area", "*"))
	eq(fr.get("escritorio"), "buhardilla"); eq(fr.get("ventana"), "buhardilla"); eq(fr.get("pared"), "buhardilla")
	for f in ["mostrador", "estantes", "escaparate"]: eq(fr.get(f), "tienda", "encuadre %s de la tienda" % f)
	ok((pl.get("silhouettes", {}) as Dictionary).has("wiggins"), "Wiggins por la ventana (desde el día 3)")
	eq(str(pl.silhouettes.wiggins.frame), "ventana")
	for v in ["registrada", "techos", "registrada+techos"]:
		has((pl.get("variants", {}) as Dictionary).keys(), v, "variante %s" % v)

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
		eq(str(nd2.get("aviso", "")), "M1", "N:L1.%s avisa de M1 (examine → Q8)" % nid)
	for nid in CONTRACT_L1_TECHOS:
		var nd3 := PLC.node_def(pl, nid, "techos")
		ok(not nd3.is_empty(), "N:L1.%s en la variante techos" % nid)
		eq(PLC.sorted(nd3.get("tags", [])), PLC.sorted(CONTRACT_L1_TECHOS[nid]), "N:L1.%s etiquetas" % nid)
		eq(str(nd3.get("aviso", "")), "HA5", "N:L1.%s avisa de HA5" % nid)
	# los rastros que nombran estos nodos llevan las mismas etiquetas (si W2-STRUCT ya publicó las reacciones)
	var mism := PLC.rastro_mismatch(repo(), "L1", pl)
	eq(mism, [], "rastros de reacciones = etiquetas de los nodos")

func test_prologue_and_m7_plates() -> void:
	var pro := PLC.place(repo(), "PRO")
	ok(bool(pro.get("fixed", false)), "PRO fija")
	eq(str(pro.get("origin")), "PL.prologo")
	var h := PLC.node_def(pro, "harris")
	ok(not h.is_empty(), "N:PRO.harris")
	for t in ["a:rasgo_de_harris", "a:tirador", "e:harris", "e:bigote", "f:secreto_camden"]:
		has(h.get("tags", []), t, "N:PRO.harris lleva %s (Q6, Q10 B; GDD_v3 §1.8)" % t)
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
	var pl := _rail_place(PLC.place(repo(), "L1"))
	var scen := [{"day": 3, "slot": "M", "variant": ""}, {"day": 10, "slot": "M", "variant": ""}, {"day": 4, "slot": "M", "variant": "registrada"},
		{"day": 4, "slot": "M", "variant": "techos"}]
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
	var pl := _rail_place(PLC.place(repo(), "L1"))
	var scen := [{"day": 3, "slot": "M"}, {"day": 10, "slot": "M"}, {"day": 5, "slot": "dawn"}, {"day": 2, "slot": "night"}]
	eq(await PLC.unclickable_chars(tree, pl, scen), [], "personajes de L1 sin clic en ningún encuadre (Crane, librero, Pell, chico de Pell)")
	for id in ["PRO", "M7"]:
		var pp := PLC.place(repo(), id)
		eq(await PLC.unclickable_chars(tree, pp, [{"day": int(pp.day), "slot": str(pp.slot)}]), [], "%s: personajes sin clic" % id)

func test_contract_nodes_clippable_alone() -> void:
	var cases := [
		["L1", "librero_dedos", {"day": 10, "slot": "M", "variant": ""}],
		["L1", "librero_sombra", {"day": 10, "slot": "M", "variant": ""}],
		["L1", "ceniza_escritorio", {"day": 4, "slot": "M", "variant": "registrada"}],
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
	eq(PLC.sorted(wr.frames()), _rail_ids("L1.buhardilla"), "encuadres del hub (buhardilla) = riel de camera.json")
	ok(wr.frames().size() >= 5, "GDD_v3 §6.6: la buhardilla tiene 5 puntos (puerta, estante, escritorio, ventana, plano)")
	wr.show_hub("mostrador", "T")
	await tree.physics_frame
	eq(PLC.sorted(wr.frames()), _rail_ids("L1.tienda"), "encuadres de la tienda = riel de camera.json")
	ok(wr.frames().size() >= 4, "GDD_v3 §6.6: la tienda tiene 4 puntos")
