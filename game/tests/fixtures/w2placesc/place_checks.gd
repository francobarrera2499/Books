# tests/fixtures/w2placesc/place_checks.gd — W2-PLACES-C. Utilidades compartidas por los tests test_u_l4/l5/l6/plates
# y los drivers de captura w2placesc_*. Arma instantáneas como lo hará WorldModel.snapshot (§3.7 q_plate):
# nodos base + add_nodes de la variante (menos remove_nodes), filtrados por área ("*" o la del snap) y `when`
# (Cond con tk = día/franja); personajes por área y `when`; siluetas desde el día 3 (las de M3/M11 se piden aparte).
extends RefCounted

const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")

static func load_json(path: String) -> Dictionary:
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}

static func _area_ok(a, area: String) -> bool:
	var s := str(a) if a != null else "*"
	return s == "" or s == "*" or area == "*" or area == "" or s == area

static func _when_ok(w, day: int, slot: String) -> bool:
	if w == null or (w is Dictionary and w.is_empty()): return true
	if day < 0: return true
	return Cond.eval(w, {"tk": TimeKey.tk(day, slot)})

static func node_defs(place: Dictionary, variant: String) -> Array:
	var out: Array = []
	var vdef: Dictionary = {}
	var vs = place.get("variants", {})
	if variant != "" and vs is Dictionary and vs.has(variant): vdef = vs[variant]
	var removed: Array = vdef.get("remove_nodes", [])
	for n in place.get("nodes", []):
		if not removed.has(str(n.get("id", ""))): out.append(n)
	for n in vdef.get("add_nodes", []): out.append(n)
	return out

# sils: null = las del lugar sin condición (wiggins y cochero desde el día 3, más m3_hombres si m3=true)
static func snapshot(place: Dictionary, area: String, slot: String, day: int, variant := "", sils = null, frame := "") -> Dictionary:
	var ids: Array = []
	for n in node_defs(place, variant):
		if _area_ok(n.get("area", "*"), area) and _when_ok(n.get("when", {}), day, slot):
			ids.append(str(n["id"]))
	var chars: Array = []
	for c in place.get("characters", []):
		if _area_ok(c.get("area", "*"), area) and _when_ok(c.get("when", {}), day, slot):
			chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sl: Array = []
	if sils is Array:
		sl = sils
	elif day >= 3 and place.get("silhouettes", {}) is Dictionary:
		for k in (place["silhouettes"] as Dictionary).keys():
			sl.append(str(k))
	return {"id": "PL.%s.%d.%s" % [place.get("id", "X"), day, slot], "place": str(place.get("id", "")), "area": area, "day": day,
		"slot": slot, "variant": variant, "nodes": ids, "chars": chars, "silhouettes": sl, "frame": frame}

static func frames_for(place: Dictionary, area: String) -> Array:
	var out: Array = []
	for f in place.get("frames", []):
		if _area_ok(f.get("area", "*"), area): out.append(str(f["id"]))
	return out

static func make_world(tree: SceneTree) -> Node:
	tree.root.size = Vector2i(1600, 900)
	var wr = WR.new()
	tree.root.add_child(wr)
	wr.set_fast(true)
	return wr

static func free_world(wr) -> void:
	if wr != null and is_instance_valid(wr):
		if wr.get_parent() != null: wr.get_parent().remove_child(wr)
		wr.free()

# punto de pantalla donde un clic da con el nodo (centro de su rectángulo visible; si no, una grilla de 5×5 puntos)
static func pick_point(wr, nid: String) -> Vector2:
	var body = wr.node_body(nid)
	if body == null: return Vector2(-1, -1)
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var r := RC.screen_rect(cam, body).intersection(vp)
	if r.get_area() <= 0.0: return Vector2(-1, -1)
	var c := r.get_center()
	if str(wr.pick(c).get("id", "")) == nid: return c
	for i in 5:
		for j in 5:
			var pt := r.position + r.size * Vector2((i + 0.5) / 5.0, (j + 0.5) / 5.0)
			if str(wr.pick(pt).get("id", "")) == nid: return pt
	return Vector2(-1, -1)

static func clip_alone(wr, nid: String, grow := 0.03) -> Dictionary:
	var body = wr.node_body(nid)
	if body == null: return {"ok": false, "why": "no existe"}
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body).intersection(vp)
	var r := a.grow(maxf(2.0, a.size.length() * grow)).intersection(vp)
	if r.get_area() <= 0.0: return {"ok": false, "why": "fuera de cuadro"}
	var res: Dictionary = wr.rect_clip(r)
	var big: Array = []
	for h in res["hits"]:
		if float(h["cover"]) >= 0.5: big.append(h)
	var why := ""
	if float(res["area_frac"]) > 0.125: why = "rectángulo > 1/8 (%.3f)" % float(res["area_frac"])
	elif big.size() != 1 or str(big[0]["node"]) != nid: why = "captura %s" % str(big)
	elif not bool(big[0]["tight"]): why = "no ajustado"
	return {"ok": why == "", "why": why, "res": res}

static func visible_in_frame(wr, nid: String) -> String:
	var body = wr.node_body(nid)
	if body == null: return "no existe el nodo"
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body)
	if a.get_area() <= 0.0: return "detrás de la cámara"
	if not vp.has_point(a.get_center()): return "fuera del frustum"
	if a.intersection(vp).get_area() < 0.6 * a.get_area(): return "más de 40 % fuera de cuadro"
	var vis: Vector2i = RC.visible_points(cam, body, wr.diorama, wr.excluded_rids())
	if vis.x == 0: return "tapado"
	if vis.x * 2 <= vis.y: return "tapado en buena parte (%d de %d puntos a la vista)" % [vis.x, vis.y]
	return ""

# Por cada nodo de la instantánea: encuadres del área desde donde un clic lo alcanza. -> {nid: [frames]}
static func pickable_frames(tree: SceneTree, wr, place: Dictionary, snap: Dictionary) -> Dictionary:
	var out := {}
	for nid in snap["nodes"]: out[nid] = []
	for s in snap.get("silhouettes", []): out["sil_" + str(s)] = []
	for f in frames_for(place, str(snap["area"])):
		wr.set_frame(f, true)
		await tree.physics_frame
		for nid in out:
			if pick_point(wr, nid).x >= 0.0: out[nid].append(f)
	return out

# {nid: [frames donde se recorta solo]}
static func clippable_frames(tree: SceneTree, wr, place: Dictionary, snap: Dictionary, ids: Array) -> Dictionary:
	var out := {}
	for nid in ids: out[nid] = []
	for f in frames_for(place, str(snap["area"])):
		wr.set_frame(f, true)
		await tree.physics_frame
		for nid in ids:
			if bool(clip_alone(wr, nid)["ok"]): out[nid].append(f)
	return out

# mención [[ent|…]] y entidades e: de los nodos que no existen en el repo
static func missing_entities(repo, place: Dictionary) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("\\[\\[([a-z0-9_@]+)")
	var all := node_defs(place, "")
	var vs = place.get("variants", {})
	if vs is Dictionary:
		for v in vs.values():
			if v is Dictionary: all.append_array(v.get("add_nodes", []))
	for n in all:
		for m in rx.search_all(str(n.get("examine", ""))):
			var e := m.get_string(1)
			if repo.entity(e).is_empty(): out.append("%s: [[%s]]" % [n.get("id"), e])
		for t in n.get("tags", []):
			if str(t).begins_with("e:") and repo.entity(str(t).substr(2)).is_empty(): out.append("%s: %s" % [n.get("id"), t])
	return out

# ---------------------------------------------------------------------------------------------
# Chequeos compartidos (devuelven listas de fallas legibles; [] = bien)
const DB = preload("res://world/diorama_builder.gd")
const Schema = preload("res://core/data/schema.gd")

# esquema, ids, examine/noun/cls/área/prop de cada nodo, props construibles, menciones y entidades e: existentes
static func static_problems(repo, place: Dictionary, dataset := "places") -> Array:
	var out: Array = []
	for e in Schema.check(dataset, place):
		out.append("esquema: " + str(e))
	var areas: Array = (place.get("areas", {}) as Dictionary).keys() if place.get("areas", {}) is Dictionary else []
	var prop_ids := {}
	for pr in place.get("props", []): prop_ids[str(pr["id"])] = pr
	var vs: Dictionary = place.get("variants", {}) if place.get("variants", {}) is Dictionary else {}
	for vk in vs:
		for pr in (vs[vk] as Dictionary).get("add_props", []): prop_ids[str(pr["id"])] = pr
	var nodes: Array = (place.get("nodes", []) as Array).duplicate()
	for vk in vs: nodes.append_array((vs[vk] as Dictionary).get("add_nodes", []))
	for n in nodes:
		var nid := str(n.get("id", ""))
		if str(n.get("examine", "")).strip_edges() == "": out.append("%s: sin examine" % nid)
		if str(n.get("noun", "")).strip_edges() == "": out.append("%s: sin noun" % nid)
		if not ["I", "P", "C"].has(str(n.get("cls", ""))): out.append("%s: cls '%s'" % [nid, n.get("cls")])
		var a := str(n.get("area", "*"))
		if a != "*" and not areas.has(a): out.append("%s: área desconocida '%s'" % [nid, a])
		if not prop_ids.has(str(n.get("prop", ""))): out.append("%s: prop inexistente '%s'" % [nid, n.get("prop")])
		var p: Dictionary = repo.parse_text(str(n.get("examine", "")))
		for e in p.get("errors", []): out.append("%s: marcado: %s" % [nid, str(e)])
	for f in place.get("frames", []):
		var a := str(f.get("area", "*"))
		if a != "*" and not areas.has(a): out.append("encuadre %s: área desconocida '%s'" % [f.get("id"), a])
	for pid in prop_ids:
		var pr: Dictionary = prop_ids[pid]
		var pp: Dictionary = (pr.get("p", {}) as Dictionary).duplicate()
		pp["id"] = pid
		var nd := DB.build_prop(str(pr["type"]), pp)
		if nd.has_meta("missing_type"): out.append("prop %s: tipo desconocido %s" % [pid, pr["type"]])
		elif not nd.has_meta("occ"): out.append("prop %s: sin meta occ" % pid)
		nd.free()
	out.append_array(missing_entities(repo, place))
	return out

# Todo nodo presente en un área se alcanza con un clic desde algún encuadre de esa área; toda silueta queda «sin tapar»
# (criterio T29) en algún encuadre de cada área y en el suyo propio. plan: [[área, día, franja, variante?]].
static func reach_problems(tree: SceneTree, place: Dictionary, plan: Array) -> Array:
	var out: Array = []
	for pl in plan:
		var area: String = pl[0]
		var variant: String = pl[3] if pl.size() > 3 else ""
		var snap := snapshot(place, area, pl[2], int(pl[1]), variant)
		var wr = make_world(tree)
		wr.show_plate(snap, place)
		await tree.physics_frame
		await tree.physics_frame
		var reach := await pickable_frames(tree, wr, place, snap)
		for nid in reach:
			if (reach[nid] as Array).is_empty():
				out.append("%s/%s: %s no se alcanza con un clic desde ningún encuadre" % [area, variant, nid])
		for s in snap.get("silhouettes", []):
			var seen := false
			var own := str((place["silhouettes"] as Dictionary)[s].get("frame", ""))
			for f in frames_for(place, area):
				wr.set_frame(f, true)
				await tree.physics_frame
				var why := visible_in_frame(wr, "sil_" + str(s))
				if why == "": seen = true
				elif f == own: out.append("%s: silueta %s tapada en su encuadre %s: %s" % [area, s, f, why])
			if not seen: out.append("%s: silueta %s no se ve sin tapar desde ningún encuadre" % [area, s])
		free_world(wr)
	return out

# nodo `nid` se recorta solo (cover ≥ 0,5, ajustado, único hit grande) desde algún encuadre del área
static func clip_alone_frames(tree: SceneTree, place: Dictionary, area: String, day: int, slot: String, nid: String, variant := "") -> Array:
	var snap := snapshot(place, area, slot, day, variant)
	var wr = make_world(tree)
	wr.show_plate(snap, place)
	await tree.physics_frame
	await tree.physics_frame
	var got: Array = []
	for f in frames_for(place, area):
		wr.set_frame(f, true)
		await tree.physics_frame
		if bool(clip_alone(wr, nid)["ok"]): got.append(f)
	free_world(wr)
	return got

static func find_node(place: Dictionary, nid: String, variant := "") -> Dictionary:
	for n in node_defs(place, variant):
		if str(n.get("id", "")) == nid: return n
	return {}

static func has_tags(n: Dictionary, tags: Array) -> bool:
	for t in tags:
		if not (n.get("tags", []) as Array).has(t): return false
	return true

# WorldRoot.prewarm(place) (precalentado detrás del fundido): construye todo el lugar, no deja restos ni toca el diorama vivo
static func prewarm_problems(tree: SceneTree, place: Dictionary) -> Array:
	var out: Array = []
	var wr = make_world(tree)
	var smp := load_json("res://tests/fixtures/places/sample.json")
	wr.show_plate(snapshot(smp, "estudio", "M", 3), smp)
	await tree.physics_frame
	var live = wr.diorama
	await wr.prewarm(place)
	await tree.process_frame
	if wr.find_children("Prewarm", "", false, false).size() != 0: out.append("el precalentado no se liberó")
	if wr.diorama != live: out.append("el precalentado tocó el diorama vivo")
	free_world(wr)
	return out
