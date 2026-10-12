# tests/fixtures/w2placesa/places_check.gd — W2-PLACES-A. Utilidades de verificación de lugares y láminas
# (las usan tests/test_u_l1.gd y tests/test_u_l2.gd). Estáticas; un WorldRoot vivo a la vez (free_world() lo libera).
extends RefCounted

const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")

static var _wr = null

static func new_world(tree: SceneTree):
	free_world()
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	return _wr

static func free_world() -> void:
	if _wr != null and is_instance_valid(_wr):
		if _wr.get_parent() != null: _wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null

static func sorted(a) -> Array:
	var b: Array = (a as Array).duplicate()
	b.sort()
	return b

static func place(repo, id: String) -> Dictionary:
	var p: Dictionary = repo.place(id)
	if p.is_empty(): p = repo.plate(id)
	return p

static func all_nodes(pl: Dictionary, variant := "*") -> Array:
	var out: Array = (pl.get("nodes", []) as Array).duplicate()
	var vs = pl.get("variants", {})
	if vs is Dictionary:
		var ks: Array = vs.keys(); ks.sort()
		for v in ks:
			if variant == "*" or v == variant:
				if vs[v] is Dictionary: out.append_array(vs[v].get("add_nodes", []))
	return out

static func node_ids(pl: Dictionary) -> Array:
	var out: Array = []
	for n in all_nodes(pl): out.append(str(n.get("id", "")))
	return out

static func node_def(pl: Dictionary, nid: String, variant := "") -> Dictionary:
	for n in all_nodes(pl, variant if variant != "" else "-"):
		if str(n.get("id", "")) == nid: return n
	if variant == "":
		return {}
	return {}

static func multi_xforms(n: Node) -> Array:
	var out: Array = []
	for mm in n.find_children("*", "MultiMeshInstance3D", true, false):
		var m: MultiMesh = (mm as MultiMeshInstance3D).multimesh
		for i in m.instance_count: out.append(m.get_instance_transform(i))
	return out

static func repo_errors_for(repo, id: String) -> Array:
	var out: Array = []
	for e in repo.errors():
		var s := str(e)
		if s.contains("places/%s.json" % id) or s.contains("plates/%s.json" % id) or s.contains("places_a.json"):
			out.append(s)
	return out

static func bad_entity_tags(repo, pl: Dictionary) -> Array:
	var ents: Dictionary = repo.entities()
	var out: Array = []
	var re := RegEx.create_from_string("\\[\\[([a-z0-9_]+)(\\|[^\\]]*)?\\]\\]")
	for n in all_nodes(pl):
		for t in n.get("tags", []):
			var s := str(t)
			var pre := s.get_slice(":", 0)
			if (pre == "e" or pre == "p") and not ents.has(s.substr(2)):
				out.append("%s: %s" % [n.get("id"), s])
		for m in re.search_all(str(n.get("examine", ""))):
			if not ents.has(m.get_string(1)):
				out.append("%s: mención [[%s]]" % [n.get("id"), m.get_string(1)])
	return out

static func dangling_props(pl: Dictionary) -> Array:
	var props := {}
	for p in pl.get("props", []): props[str(p.get("id", ""))] = true
	var vs = pl.get("variants", {})
	if vs is Dictionary:
		for v in vs.values():
			for p in v.get("add_props", []): props[str(p.get("id", ""))] = true
	var out: Array = []
	for n in all_nodes(pl):
		var pr := str(n.get("prop", ""))
		if pr != "" and not props.has(pr): out.append("%s → %s" % [n.get("id"), pr])
	if vs is Dictionary:
		for v in vs.values():
			for k in (v.get("move", {}) as Dictionary):
				if not props.has(str(k)): out.append("move %s" % k)
	return out

static func bare_mentions(pl: Dictionary) -> Array:
	var re := RegEx.create_from_string("\\[\\[[a-z0-9_]+\\]\\]")
	var out: Array = []
	for n in all_nodes(pl):
		if re.search(str(n.get("examine", ""))) != null: out.append(str(n.get("id")))
	return out

# rastros de reacciones con "nodo": "N:<id>.<nodo>": sus etiquetas deben coincidir con las del nodo
static func rastro_mismatch(repo, id: String, pl: Dictionary) -> Array:
	var out: Array = []
	for r in repo.reactions():
		for ra in r.get("rastro", []):
			var nref := str(ra.get("nodo", ""))
			if not nref.begins_with("N:%s." % id): continue
			var nid := nref.substr(("N:%s." % id).length())
			var nd := {}
			for n in all_nodes(pl):
				if str(n.get("id", "")) == nid: nd = n
			if nd.is_empty():
				out.append("%s: %s no existe" % [r.get("id"), nref]); continue
			if ra.has("tags") and sorted(ra.tags) != sorted(nd.get("tags", [])):
				out.append("%s: %s %s ≠ %s" % [r.get("id"), nref, str(sorted(ra.tags)), str(sorted(nd.get("tags", [])))])
	return out

# «who» de los efectos op «silueta» de las reacciones (y de sus variantes blandas) que caen en este lugar (place "*" o
# el id): cada uno necesita su entrada en `silhouettes` (HB8b pone muchacho_sin_gorra en todo lugar y quita a Wiggins).
static func reaction_silhouettes(repo, place_id: String) -> Array:
	var out: Array = []
	for r in repo.reactions():
		if not (r is Dictionary): continue
		var effs: Array = []
		if r.get("efecto") is Array: effs.append_array(r.efecto)
		var vb = r.get("variante_blanda")
		if vb is Dictionary and vb.get("efecto") is Array: effs.append_array(vb.efecto)
		for e in effs:
			if not (e is Dictionary) or str(e.get("op", "")) != "silueta": continue
			var where := str(e.get("place", "*"))
			var who := str(e.get("who", ""))
			if who != "" and (where == "*" or where == place_id) and not out.has(who): out.append(who)
	out.sort()
	return out

static func v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

# ---------------------------------------------------------------------------------------------
static func frame_area(pl: Dictionary, fid: String) -> String:
	for f in pl.get("frames", []):
		if str(f.get("id", "")) == fid: return str(f.get("area", "*"))
	return "*"

static func _ctx(sc: Dictionary) -> Dictionary:
	return {"tk": TimeKey.tk(int(sc.get("day", 3)), str(sc.get("slot", "M"))), "st": {"flags": sc.get("flags", {}), "clock": {}}}

static func snapshot(pl: Dictionary, sc: Dictionary, fid: String) -> Dictionary:
	var area := "*" if bool(pl.get("fixed", false)) else frame_area(pl, fid)
	var variant := str(sc.get("variant", ""))
	var ctx := _ctx(sc)
	var nodes: Array = []
	for n in all_nodes(pl, variant if variant != "" else "-"):
		var a := str(n.get("area", "*"))
		if a != "*" and area != "*" and a != area: continue
		if n.has("when") and not Cond.eval(n.when, ctx): continue
		nodes.append(str(n.id))
	var chars: Array = []
	for c in pl.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if a2 != "*" and area != "*" and a2 != area: continue
		if c.has("when") and not Cond.eval(c.when, ctx): continue
		chars.append({"id": str(c.id), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sils: Array = []
	if int(sc.get("day", 3)) >= 3 and not bool(pl.get("fixed", false)):
		for k in (pl.get("silhouettes", {}) as Dictionary): sils.append(str(k))
	return {"id": "PL.%s.%d.%s.%s" % [pl.get("id", "X"), int(sc.get("day", 3)), str(sc.get("slot", "M")), fid], "place": pl.get("id", ""),
		"area": area, "day": int(sc.get("day", 3)), "slot": str(sc.get("slot", "M")), "variant": variant, "nodes": nodes, "chars": chars,
		"silhouettes": sils, "frame": fid}

# "" si el nodo se ve en el encuadre actual; si no, el motivo. strict: mayoría de los puntos de muestra a la vista
# (lugares que se recorren); si no, basta con que algo se vea (láminas: composiciones; lo que asoma se puede clicar).
static func visibility(wr, nid: String, strict := true) -> String:
	var body = wr.node_body(nid)
	if body == null: return "no está"
	if wr.excluded_rids().has((body as CollisionObject3D).get_rid()): return "en un muro cortado"
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body)
	if a.get_area() <= 0.0: return "detrás de la cámara"
	var inter := a.intersection(vp).get_area()
	if inter <= 0.0: return "fuera de cuadro"
	if inter < 0.25 * a.get_area() and inter < 0.02 * vp.get_area(): return "casi fuera de cuadro"
	var vis: Vector2i = RC.visible_points(cam, body, wr.diorama, wr.excluded_rids())
	if (strict and vis.x * 2 <= vis.y) or vis.x == 0: return "tapado (%d/%d)" % [vis.x, vis.y]
	return ""

static func _show(tree: SceneTree, pl: Dictionary, sc: Dictionary, fid: String):
	if _wr == null or not is_instance_valid(_wr): new_world(tree)
	_wr.show_plate(snapshot(pl, sc, fid), pl)
	_wr.set_orbit_enabled(false)
	_wr.set_frame(fid, true)
	await tree.physics_frame
	await tree.physics_frame
	return _wr

# nodos (presentes en algún escenario) que no se ven en ningún encuadre de ningún escenario → ["id: motivos"]
static func unseen_nodes(tree: SceneTree, pl: Dictionary, scenarios: Array, strict := true) -> Array:
	var seen := {}
	var why := {}
	var present := {}
	for sc in scenarios:
		for f in pl.get("frames", []):
			var fid := str(f.id)
			var sn := snapshot(pl, sc, fid)
			if sn.nodes.is_empty(): continue
			var wr = await _show(tree, pl, sc, fid)
			for nid in sn.nodes:
				present[nid] = true
				if seen.has(nid): continue
				var w := visibility(wr, nid, strict)
				if w == "": seen[nid] = true
				else: why[nid] = str(why.get(nid, "")) + " %s:%s;" % [fid, w]
	var out: Array = []
	var ks: Array = present.keys(); ks.sort()
	for nid in ks:
		if not seen.has(nid): out.append("%s:%s" % [nid, why.get(nid, "")])
	free_world()
	return out

# recorta el nodo solo con un rectángulo ajustado en algún encuadre: {ok, why, frame}
static func clip_alone_any_frame(tree: SceneTree, pl: Dictionary, nid: String, sc: Dictionary) -> Dictionary:
	var reasons: Array = []
	for f in pl.get("frames", []):
		var fid := str(f.id)
		var sn := snapshot(pl, sc, fid)
		if not sn.nodes.has(nid): continue
		var wr = await _show(tree, pl, sc, fid)
		if visibility(wr, nid) != "": reasons.append("%s: no se ve" % fid); continue
		var cam: Camera3D = wr.camera()
		var vp := cam.get_viewport().get_visible_rect()
		var a := RC.screen_rect(cam, wr.node_body(nid)).intersection(vp)
		var r := a.grow(maxf(2.0, a.size.length() * 0.03)).intersection(vp)
		var res: Dictionary = wr.rect_clip(r)
		var big: Array = []
		for h in res.hits:
			if float(h.cover) >= 0.5: big.append(h)
		var w := ""
		if float(res.area_frac) > 0.125: w = "rectángulo > 1/8 (%.3f)" % float(res.area_frac)
		elif big.is_empty() or str(big[0].node) != nid: w = "captura %s" % str(big)
		elif big.size() > 2: w = "más de 2 nodos con cover ≥ 0,5: %s" % str(big)
		elif not bool(big[0].tight): w = "no ajustado"
		if w == "":
			free_world()
			return {"ok": true, "why": "", "frame": fid}
		reasons.append("%s: %s" % [fid, w])
	free_world()
	return {"ok": false, "why": "; ".join(reasons), "frame": ""}

# personajes (presentes en algún escenario) a los que no se les puede hacer clic en ningún encuadre → ["id"]
# (clic en el centro de su caja proyectada → pick devuelve el personaje; así se presenta y se pregunta)
static func unclickable_chars(tree: SceneTree, pl: Dictionary, scenarios: Array) -> Array:
	var ok_ids := {}
	var present := {}
	for sc in scenarios:
		for f in pl.get("frames", []):
			var fid := str(f.id)
			var sn := snapshot(pl, sc, fid)
			if sn.chars.is_empty(): continue
			var wr = await _show(tree, pl, sc, fid)
			var ci: Dictionary = wr.diorama.get_meta("chars_index", {})
			var cam: Camera3D = wr.camera()
			var vp := cam.get_viewport().get_visible_rect()
			for c in sn.chars:
				var cid := str(c.id)
				present[cid] = true
				if ok_ids.has(cid) or not ci.has(cid): continue
				var b: Node3D = ci[cid]
				var box: AABB = b.get_meta("aabb", AABB())
				for fy in [0.75, 0.55, 0.35]:
					var p := b.global_transform * (box.position + Vector3(box.size.x * 0.5, box.size.y * fy, box.size.z * 0.5))
					if cam.is_position_behind(p): continue
					var sp := cam.unproject_position(p)
					if not vp.has_point(sp): continue
					if str(wr.pick_character(sp)) == cid:
						ok_ids[cid] = true
						break
	var out: Array = []
	var ks: Array = present.keys(); ks.sort()
	for cid in ks:
		if not ok_ids.has(cid): out.append(cid)
	free_world()
	return out
