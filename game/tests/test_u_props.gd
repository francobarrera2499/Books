# Tests unitarios de la biblioteca 3D (W1-3D): props de §7.2, materiales, maniquíes §7.4, DioramaBuilder.
extends "res://tests/test_base.gd"

const DB = preload("res://world/diorama_builder.gd")
const M = preload("res://world/materials.gd")
const MQ = preload("res://world/characters/mannequin.gd")
const CR = preload("res://world/characters/crowd.gd")
const ARCH = preload("res://world/props/architecture.gd")
const RC = preload("res://world/rect_clip.gd")

# §7.2 «Biblioteca base (W1-3D)» — todas las funciones del contrato
const BUILDERS := {
	"furniture": ["desk", "table", "chair", "armchair", "bookshelf", "counter", "stool", "bed", "stove", "fireplace", "coat_stand",
		"reading_desk_radial", "index_shelves", "cabinet", "crate"],
	"architecture": ["room", "attic", "sash_window", "door", "facade", "dome", "stairs", "railing", "eave", "arch"],
	"street": ["gas_lamp", "wall_lamp", "cab", "crocus_bed", "lawn_strip", "sign_board", "kiosk", "pavement", "post_box"],
	"small": ["book", "book_pile", "tome_set", "paper_stack", "letter", "envelope", "basket_strips", "ash_pile", "scissors", "ruler",
		"lens", "stamp", "ink_pot", "clock_mantel", "coins", "tray", "desk_calendar", "map_board", "tobacco_tin", "photo_frame",
		"open_ledger_book", "lantern"],
}

func _sample() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/places/sample.json"))

func _occ_ok(occ) -> bool:
	if not (occ is Array): return false
	for e in occ:
		if not (e is AABB or e is Transform3D): return false
	return true

func test_every_builder_with_default_params() -> void:
	var count := 0
	for module in BUILDERS:
		var s: Script = load("res://world/props/%s.gd" % module)
		ok(s != null, "no carga props/%s.gd" % module)
		if s == null: continue
		for fn in BUILDERS[module]:
			ok(s.has_method("build_" + fn), "%s.build_%s no existe" % [module, fn])
			if not s.has_method("build_" + fn): continue
			var n = s.call("build_" + fn, {})
			ok(n is Node3D, "%s.%s no devuelve Node3D" % [module, fn])
			if not (n is Node3D): continue
			ok(n.has_meta("occ"), "%s.%s sin meta occ" % [module, fn])
			ok(_occ_ok(n.get_meta("occ", null)), "%s.%s occ no es Array[AABB|Transform3D]" % [module, fn])
			var box := M.aabb_of(n)
			ok(box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0, "%s.%s sin geometría (aabb %s)" % [module, fn, str(box)])
			n.free()
			count += 1
	eq(count, 56, "cantidad de builders de §7.2")

func test_builders_are_deterministic() -> void:
	var a := DB.build_prop("furniture.bookshelf", {"seed": 11})
	var b := DB.build_prop("furniture.bookshelf", {"seed": 11})
	var c := DB.build_prop("furniture.bookshelf", {"seed": 12})
	var ma := _multi_xforms(a); var mb := _multi_xforms(b); var mc := _multi_xforms(c)
	eq(ma, mb, "misma semilla, mismos lomos")
	ok(ma != mc, "otra semilla, otros lomos")
	a.free(); b.free(); c.free()

func _multi_xforms(n: Node) -> Array:
	var out: Array = []
	for mm in n.find_children("*", "MultiMeshInstance3D", true, false):
		var m: MultiMesh = (mm as MultiMeshInstance3D).multimesh
		for i in m.instance_count: out.append(m.get_instance_transform(i))
	return out

func test_build_prop_dispatch_and_unknown_type() -> void:
	var n := DB.build_prop("furniture.desk", {"w": 1.2})
	ok(n is Node3D)
	near(M.aabb_of(n).size.x, 1.2, 0.05, "ancho del escritorio")
	n.free()
	var u := DB.build_prop("nada.inexistente", {})
	ok(u.has_meta("missing_type"), "tipo desconocido → marcador")
	u.free()
	var f := DB.build_prop("figure.cofia", {"id": "x"})
	eq(str(f.get_meta("trait", "")), "cofia")
	f.free()
	var cw := DB.build_prop("crowd.make", {"n": 5, "seed": 3})
	eq(cw.get_child_count(), 5, "multitud de 5")
	cw.free()

func test_materials_shared_and_contract_colors() -> void:
	ok(M.mat("madera_oscura") == M.mat("madera_oscura"), "material compartido (cache)")
	var expect := {"madera_oscura": "5a4632", "madera_clara": "8a7050", "papel": "e8dcc0", "yeso": "cfc6b4", "hierro": "2e2c2a",
		"laton": "a08040", "paño": "3a3a3e", "cuero": "5a3a2a", "ladrillo_hollin": "4a4036"}
	for id in expect:
		var m: StandardMaterial3D = M.mat(id)
		if m.albedo_texture == null:
			eq(m.albedo_color.to_html(false), expect[id], "color de " + id)
		near(m.roughness, 1.0, 0.0001, "roughness " + id)
		near(m.metallic, 0.0, 0.0001, "metallic " + id)
	var v: StandardMaterial3D = M.mat("vidrio")
	eq(v.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "vidrio transparente")
	near(v.albedo_color.a, 0.25, 0.001, "alfa del vidrio")
	ok((M.mat("gas_emisivo") as StandardMaterial3D).emission_enabled, "gas emisivo")
	ok((M.mat("ladrillo_stock") as StandardMaterial3D).albedo_texture != null, "ladrillo con textura procedural")

func test_rnd_is_deterministic_and_bounded() -> void:
	eq(M.rnd(7, 3, 1), M.rnd(7, 3, 1))
	ne(M.rnd(7, 3, 1), M.rnd(8, 3, 1))
	for i in 200:
		var r := M.rnd(5, i, 2)
		ok(r >= 0.0 and r < 1.0, "rnd fuera de rango %f" % r)

func test_wall_strips_leaves_openings_empty() -> void:
	var holder := Node3D.new()
	var boxes := ARCH.wall_strips(holder, 4.0, 0.2, [[-2.0, 3.0]], [{"x": 0.5, "w": 1.0, "h": 1.5, "sill": 0.8}], "yeso")
	var area := 0.0
	for b in boxes:
		area += (b as AABB).size.x * (b as AABB).size.y
		ok(not (b as AABB).has_point(Vector3(0.5, 1.55, 0.0)), "una caja tapa el vano")
	near(area, 4.0 * 3.0 - 1.0 * 1.5, 0.001, "área del muro sin el vano")
	holder.free()

func test_wall_strips_sloped_profile() -> void:
	var holder := Node3D.new()
	var boxes := ARCH.wall_strips(holder, 4.0, 0.2, [[-2.0, 1.0], [0.0, 3.0], [2.0, 1.0]], [], "yeso")
	ok(boxes.size() >= 4, "perfil a dos aguas en franjas")
	var prisms := 0
	for c in holder.get_children():
		if (c as MeshInstance3D).mesh is PrismMesh: prisms += 1
	eq(prisms, 2, "dos triángulos de hastial")
	holder.free()

func test_room_has_cut_groups_with_occluders() -> void:
	var r := ARCH.build_room({"w": 4.0, "d": 3.0, "h": 2.8, "openings": [{"wall": "n", "kind": "window", "x": 0.5, "w": 1.0, "h": 1.4, "sill": 0.9}, {"wall": "e", "kind": "door", "x": 0.0, "w": 0.9, "h": 2.1}]})
	var names := []
	for c in r.get_children():
		if c.has_meta("cut_n"):
			names.append(str(c.name))
			ok((c.get_meta("occ") as Array).size() > 0, "grupo %s sin oclusores" % c.name)
	for n in ["wall_n", "wall_s", "wall_e", "wall_w", "ceiling"]:
		has(names, n, "grupos de corte")
	var wn: Node3D = r.get_node("wall_n")
	var n_in: Vector3 = wn.get_meta("cut_n")
	near(n_in.z, 1.0, 0.0001, "la normal del muro norte mira al interior (+Z)")
	for b in wn.get_meta("occ"):
		ok(not (b as AABB).has_point(Vector3(0.5, 1.6, -1.58)), "el muro norte tapa la ventana")
	ok(r.find_children("sash_window", "Node3D", true, false).size() == 1, "la ventana trae su guillotina")
	ok(r.find_children("door", "Node3D", true, false).size() == 1, "la puerta trae su hoja")
	r.free()

func test_railing_is_see_through() -> void:
	# una verja no tapa lo que está detrás: sólo el zócalo y los postes de extremo ocluyen
	var r := ARCH.build_railing({"len": 3.0, "h": 1.0})
	var occ: Array = r.get_meta("occ")
	ok(occ.size() >= 1, "el zócalo ocluye")
	for b in occ:
		ok(not (b as AABB).has_point(Vector3(0.3, 0.7, 0.0)), "los barrotes no ocluyen")
		ok(not (b as AABB).has_point(Vector3(-0.9, 0.5, 0.0)), "los barrotes no ocluyen")
	r.free()

func test_attic_has_two_slopes() -> void:
	var a := ARCH.build_attic({"w": 4.0, "d": 3.0, "h": 2.6, "slope": 40})
	ok(a.get_node_or_null("slope_e") != null and a.get_node_or_null("slope_w") != null, "faldones e y w")
	var tr = (a.get_node("slope_e").get_meta("occ") as Array)[0]
	ok(tr is Transform3D, "oclusor orientado del faldón")
	a.free()

func test_bookshelf_gap_is_empty() -> void:
	var s := DB.build_prop("furniture.bookshelf", {"w": 1.6, "h": 2.1, "rows": 5, "fill": 1.0, "gap": {"row": 1, "from": 0.35, "to": 0.62}, "seed": 3})
	var st := 0.03
	var x0 := -0.8 + st
	var span := 1.6 - 2 * st
	var g0 := x0 + span * 0.35
	var g1 := x0 + span * 0.62
	var rh := (2.1 - 0.1 - 0.08) / 5.0
	var y0 := 0.1 + rh
	var mm: MultiMeshInstance3D = null
	for c in s.get_children():
		if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh.use_colors: mm = c
	ok(mm != null, "lomos en MultiMesh")
	var inside := 0
	for i in mm.multimesh.instance_count:
		var t := mm.multimesh.get_instance_transform(i)
		if t.origin.y > y0 and t.origin.y < y0 + rh and t.origin.x > g0 + 0.02 and t.origin.x < g1 - 0.02: inside += 1
	eq(inside, 0, "libros dentro del hueco")
	s.free()

func test_mannequin_every_trait() -> void:
	var traits := MQ.traits()
	eq(traits.size(), 12, "rasgos de §7.4")
	var heights := {}
	for t in traits:
		var f := MQ.make("c_" + t, t, "")
		var box: AABB = f.get_meta("aabb")
		ok(box.size.y > 1.2 and box.size.y < 2.3, "%s alto %.2f" % [t, box.size.y])
		eq(str(f.get_meta("char_id")), "c_" + t)
		heights[t] = box.size.y
		f.free()
	ok(heights["bajo_agachado"] < heights["gorra_larga"] - 0.3, "Parker es bajito y Wiggins alto")
	ok(heights["chistera_bigote"] > heights["bombin_crespon"], "la chistera de ópera supera al bombín")
	var two := MQ.make("m3", "dos_bombines", "")
	ok((two.get_meta("aabb") as AABB).size.x > 0.9, "dos figuras")
	two.free()
	var g := MQ.make("x", "rasgo_inexistente", "")
	ok(g is Node3D, "rasgo desconocido → figura genérica")
	g.free()

func test_mannequin_poses_and_determinism() -> void:
	for pose in ["de_pie", "sentado", "encorvado", "apoyado"]:
		var a := MQ.make("w", "bombin_crespon", pose)
		var b := MQ.make("w", "bombin_crespon", pose)
		ok((a.get_meta("aabb") as AABB).is_equal_approx(b.get_meta("aabb")), "pose %s determinista" % pose)
		a.free(); b.free()
	var st := MQ.make("w", "bombin_crespon", "de_pie")
	var se := MQ.make("w", "bombin_crespon", "sentado")
	ok((se.get_meta("aabb") as AABB).size.y < (st.get_meta("aabb") as AABB).size.y - 0.25, "sentado es más bajo")
	st.free(); se.free()

func test_crowd_deterministic() -> void:
	var a := CR.make({"n": 8, "seed": 9, "face": [0, 5]})
	var b := CR.make({"n": 8, "seed": 9, "face": [0, 5]})
	for i in 8:
		ok((a.get_child(i) as Node3D).transform.is_equal_approx((b.get_child(i) as Node3D).transform), "figura %d" % i)
	a.free(); b.free()

func test_diorama_build_sample_structure() -> void:
	var place := _sample()
	var ids: Array = []
	for n in place["nodes"]: ids.append(str(n["id"]))
	var snap := {"id": "PL.SAMPLE.3.M", "place": "SAMPLE", "area": "estudio", "day": 3, "slot": "M", "variant": "", "nodes": ids,
		"chars": [{"id": "watson", "pose": "de_pie", "trait": "bombin_crespon"}], "silhouettes": ["wiggins", "sil_cochero"]}
	var d := DB.build(place, snap)
	for c in ["Props", "Occluders", "Nodes", "Chars", "Lights", "Frames", "Env"]:
		ok(d.get_node_or_null(c) != null, "falta hijo " + c)
	ok(d.get_node("Env") is WorldEnvironment, "Env es WorldEnvironment")
	var idx: Dictionary = d.get_meta("nodes_index")
	eq(idx.size(), ids.size() + 2, "nodos + 2 siluetas")
	ok(idx.has("sil_wiggins") and idx.has("sil_cochero"), "siluetas como nodos sil_<who>")
	var sb: StaticBody3D = idx["sil_wiggins"]
	ok(sb.collision_layer & 2 != 0, "silueta en capa 2 (nodo)")
	ok(sb.collision_layer & 4 != 0, "la silueta tapa como un personaje")
	eq(str(sb.get_meta("node_id")), "sil_wiggins")
	var lupa: StaticBody3D = idx["lupa"]
	eq(lupa.collision_layer, 2, "nodo en capa 2")
	eq(str(lupa.get_meta("noun")), "lupa")
	ok(lupa.position.is_equal_approx(Vector3(-0.8, 0.775, -1.37)), "anchor.c")
	var ci: Dictionary = d.get_meta("chars_index")
	ok(ci.has("watson"), "personaje")
	eq((ci["watson"] as StaticBody3D).collision_layer, 4, "personaje en capa 4")
	for b in d.get_node("Occluders").get_children():
		eq((b as StaticBody3D).collision_layer, 1, "oclusor en capa 1")
	eq((d.get_meta("frames") as Dictionary).size(), (place["frames"] as Array).size(), "encuadres")
	var fr: Marker3D = d.get_node("Frames/puerta")
	near(float(fr.get_meta("fov")), 50.0, 0.001, "fov del encuadre")
	ok((d.get_meta("cutaways") as Array).size() >= 5, "grupos de corte del cuarto")
	d.free()

func test_snapshot_filters_nodes_and_variant_moves() -> void:
	var place := _sample()
	var d := DB.build(place, {"id": "a", "area": "estudio", "slot": "T", "nodes": ["lupa", "carta"], "chars": [], "silhouettes": []})
	eq((d.get_meta("nodes_index") as Dictionary).keys().size(), 2, "sólo los nodos de la instantánea")
	var carta0: Vector3 = (d.get_meta("nodes_index")["carta"] as Node3D).position
	d.free()
	var v := DB.build(place, {"id": "b", "area": "estudio", "slot": "M", "variant": "registrada", "nodes": ["lupa", "carta", "ceniza"], "chars": [], "silhouettes": []})
	var idx: Dictionary = v.get_meta("nodes_index")
	ok(idx.has("ceniza"), "add_nodes de la variante")
	var carta1: Vector3 = (idx["carta"] as Node3D).position
	ok(carta1.distance_to(carta0) > 0.3, "el ancla sigue al prop movido")
	ok((idx["lupa"] as Node3D).position.is_equal_approx(Vector3(-0.8, 0.775, -1.37)), "lo no movido queda")
	ok(v.get_node_or_null("Props/ceniza_p") != null, "add_props de la variante")
	var silla: Node3D = v.get_node("Props/silla")
	ok(silla.position.is_equal_approx(Vector3(-0.4, 0, -0.5)), "move de la variante")
	v.free()

func test_ray_box_entry() -> void:
	near(RC.ray_box_entry(Vector3(0, 0, 5), Vector3(0, 0, -1), Vector3(1, 1, 1)), 4.0, 0.0001)
	eq(RC.ray_box_entry(Vector3(0, 5, 5), Vector3(0, 0, -1), Vector3(1, 1, 1)), -1.0)
	near(RC.ray_box_entry(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(1, 1, 1)), 0.0, 0.0001)
	var pts := RC.sample_points(Vector3(0, 0, 9), Vector3(0.5, 0.5, 0.5))
	eq(pts.size(), 5, "5 puntos de oclusión")
	near((pts[1] as Vector3).z, 0.49, 0.001, "centro de la cara hacia la cámara")
