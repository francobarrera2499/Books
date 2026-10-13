# world/diorama_builder.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2.
# DioramaBuilder.build(place: Dictionary, snap: Dictionary) -> Node3D
# Hijos: Props · Occluders (StaticBody3D capa 1) · Nodes (StaticBody3D capa 2, BoxShape3D = anchor; meta node_id/noun/prop)
#        · Chars (maniquíes, StaticBody3D capa 4, meta char_id) · Lights · Frames (Marker3D meta fov/orbit) · Env (WorldEnvironment)
# Siluetas `sil_<who>` = nodos (capa 2) con maniquí. Capas como máscara de bits: 1 ocluidores, 2 nodos, 4 personajes.
# Extensiones (no rompen el contrato):
#  - prop.type "crowd.make" → world/characters/crowd.gd; "figure.<rasgo>" → maniquí genérico (sin colisión de personaje).
#  - prop.area (opcional): sólo se construye si coincide con snap.area ("*" o ausente = siempre).
#  - variants[v]: add_nodes, move{prop:{pos,rot}}, add_props, remove_props (ids).
#  - meta "occ" admite AABB o Transform3D (caja orientada: escala del basis = tamaño).
#  - grupos de corte (cuartos): meta cut_n/cut_p/occ → WorldRoot los oculta si la cámara queda afuera.
#  - v2 afordancias (GDD_v2 §D.3): al final, world/affordance/affordance.gd reparte las mallas de cada nodo (su prop dentro
#    de su ancla, el maniquí de siluetas y personajes) y les pone el código 1 (examinable) en la rugosidad; el 2 (usable)
#    lo pone WorldRoot.set_usable. Meta "aff" = {"n:<nodo>"|"c:<personaje>": [GeometryInstance3D]}.
extends RefCounted

const M = preload("res://world/materials.gd")
const AFF = preload("res://world/affordance/affordance.gd")
const MQ = preload("res://world/characters/mannequin.gd")

const LAYER_OCC := 1
const LAYER_NODE := 2
const LAYER_CHAR := 4

const SLOT_LIGHT_FALLBACK := {"dawn": "manana_perla", "M": "dia_ventana", "T": "tarde", "N": "gas", "night": "gas"}
const PAPER := {"dawn": "e8e6e0", "M": "e8e6e0", "T": "efe6d2", "N": "ecd9b4", "night": "ecd9b4"}

static var _scripts := {}

static func _script(module: String) -> Script:
	if _scripts.has(module): return _scripts[module]
	var path := ""
	match module:
		"crowd": path = "res://world/characters/crowd.gd"
		"mannequin", "figure": path = "res://world/characters/mannequin.gd"
		_: path = "res://world/props/%s.gd" % module
	var s: Script = load(path) if ResourceLoader.exists(path) else null
	_scripts[module] = s
	return s

# construye un prop suelto por tipo "<módulo>.<función>"; nunca falla (tipo desconocido → caja marcada)
static func build_prop(type: String, p: Dictionary) -> Node3D:
	var parts := type.split(".", false, 1)
	var n: Node3D = null
	if parts.size() == 2:
		var s := _script(parts[0])
		if s != null:
			if parts[0] == "crowd":
				n = s.make(p)
			elif parts[0] == "figure" or parts[0] == "mannequin":
				n = s.make(str(p.get("id", "")), parts[1], str(p.get("pose", "")))
				n.set_meta("occ", [])
			else:
				var fn := "build_" + parts[1]
				if s.has_method(fn):
					n = s.call(fn, p)
	if n == null:
		push_warning("DioramaBuilder: tipo de prop desconocido '%s'" % type)
		n = M.root("missing")
		M.box(n, Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0), "papel")
		n.set_meta("missing_type", type)
		n.set_meta("occ", [])
	if not n.has_meta("occ"): M.set_occ(n)
	return n

static func _rot_basis(r) -> Basis:
	if r is Array and r.size() >= 3:
		return Basis.from_euler(Vector3(deg_to_rad(float(r[0])), deg_to_rad(float(r[1])), deg_to_rad(float(r[2]))))
	if r == null: return Basis.IDENTITY
	return Basis(Vector3.UP, deg_to_rad(float(r)))

static func _xf(pos, rot) -> Transform3D:
	return Transform3D(_rot_basis(rot), M.v3(pos))

static func _area_ok(item_area, snap_area: String) -> bool:
	var a := str(item_area) if item_area != null else "*"
	if a == "" or a == "*": return true
	if snap_area == "" or snap_area == "*": return true
	return a == snap_area

# ---------------------------------------------------------------------------------------------
static func build(place: Dictionary, snap: Dictionary) -> Node3D:
	var root := Node3D.new()
	var pid := str(snap.get("id", place.get("id", "diorama")))
	root.name = pid.replace(".", "_").replace("/", "_")
	var area := str(snap.get("area", "*"))
	var slot := str(snap.get("slot", "M"))
	var variant := str(snap.get("variant", ""))
	var vdef: Dictionary = {}
	var variants = place.get("variants", {})
	if variants is Dictionary and variant != "" and variants.has(variant) and variants[variant] is Dictionary:
		vdef = variants[variant]
	root.set_meta("place_id", str(place.get("id", "")))
	root.set_meta("plate_id", pid)
	root.set_meta("area", area)
	root.set_meta("slot", slot)
	root.set_meta("variant", variant)
	root.set_meta("fixed", bool(place.get("fixed", false)))
	var g_props := Node3D.new(); g_props.name = "Props"; root.add_child(g_props)
	var g_occ := Node3D.new(); g_occ.name = "Occluders"; root.add_child(g_occ)
	var g_nodes := Node3D.new(); g_nodes.name = "Nodes"; root.add_child(g_nodes)
	var g_chars := Node3D.new(); g_chars.name = "Chars"; root.add_child(g_chars)
	var g_frames := Node3D.new(); g_frames.name = "Frames"; root.add_child(g_frames)
	var cutaways: Array = []
	var prop_bodies := {}
	var nodes_index := {}
	var chars_index := {}
	# ---- props (+ variante)
	var moves: Dictionary = vdef.get("move", {}) if vdef.get("move", {}) is Dictionary else {}
	var removed: Array = vdef.get("remove_props", []) if vdef.get("remove_props", []) is Array else []
	var props: Array = []
	for pr in place.get("props", []): props.append(pr)
	for pr in vdef.get("add_props", []): props.append(pr)
	var prop_xf := {}
	var prop_delta := {}
	for pr in props:
		if not (pr is Dictionary): continue
		var id := str(pr.get("id", "prop%d" % g_props.get_child_count()))
		if removed.has(id): continue
		if not _area_ok(pr.get("area", null), area): continue
		var pp: Dictionary = (pr.get("p", {}) as Dictionary).duplicate() if pr.get("p", {}) is Dictionary else {}
		if not pp.has("id"): pp["id"] = id
		var n := build_prop(str(pr.get("type", "")), pp)
		n.name = id.replace(".", "_")
		var base := _xf(pr.get("pos", [0, 0, 0]), pr.get("rot", 0))
		var xf := base
		if moves.has(id) and moves[id] is Dictionary:
			var mv: Dictionary = moves[id]
			xf = _xf(mv.get("pos", pr.get("pos", [0, 0, 0])), mv.get("rot", pr.get("rot", 0)))
			prop_delta[id] = xf * base.affine_inverse()
		n.transform = xf
		n.set_meta("prop_id", id)
		n.set_meta("type", str(pr.get("type", "")))
		g_props.add_child(n)
		prop_xf[id] = xf
		# oclusores del prop y de sus grupos de corte
		var bodies: Array = []
		var occ: Array = n.get_meta("occ", [])
		if not occ.is_empty():
			var b := _occ_body("occ_" + n.name, occ, xf)
			b.set_meta("prop_id", id)
			g_occ.add_child(b)
			bodies.append(b)
		for grp in _cut_groups(n):
			var gocc: Array = grp.get_meta("occ", [])
			var gb := _occ_body("occ_%s__%s" % [n.name, grp.name], gocc, xf * M._rel_xform(n, grp))
			gb.set_meta("prop_id", id)
			gb.set_meta("cut_group", true)
			g_occ.add_child(gb)
			bodies.append(gb)
			cutaways.append({"group": grp, "body": gb, "prop": id})
		prop_bodies[id] = bodies
	# ---- nodos lógicos
	var node_defs: Array = []
	for nd in place.get("nodes", []): node_defs.append(nd)
	for nd in vdef.get("add_nodes", []): node_defs.append(nd)
	var present = snap.get("nodes", null)
	for nd in node_defs:
		if not (nd is Dictionary): continue
		var nid := str(nd.get("id", ""))
		if nid == "": continue
		if present is Array and not present.has(nid): continue
		if present == null and not _area_ok(nd.get("area", null), area): continue
		var anc: Dictionary = nd.get("anchor", {}) if nd.get("anchor", {}) is Dictionary else {}
		var c := M.v3(anc.get("c", [0, 0, 0]))
		var s := M.v3(anc.get("s", [0.2, 0.2, 0.2]), Vector3(0.2, 0.2, 0.2))
		var t := Transform3D(Basis.IDENTITY, c)
		var prop_id := str(nd.get("prop", ""))
		if prop_delta.has(prop_id): t = prop_delta[prop_id] * t
		var body := _node_body(nid, s, t)
		body.set_meta("noun", str(nd.get("noun", "")))
		body.set_meta("prop", prop_id)
		body.set_meta("area", str(nd.get("area", "*")))
		g_nodes.add_child(body)
		nodes_index[nid] = body
	# ---- personajes
	var char_defs: Array = place.get("characters", []) if place.get("characters", []) is Array else []
	var snap_chars = snap.get("chars", null)
	if snap_chars == null:
		snap_chars = []
		for cd in char_defs:
			if cd is Dictionary and _area_ok(cd.get("area", null), area):
				snap_chars.append({"id": cd.get("id", ""), "pose": cd.get("pose", ""), "trait": cd.get("trait", "")})
	for ch in snap_chars:
		if not (ch is Dictionary): continue
		var cid := str(ch.get("id", ""))
		var cdef: Dictionary = {}
		for cd in char_defs:
			if cd is Dictionary and str(cd.get("id", "")) == cid:
				if cdef.is_empty() or _area_ok(cd.get("area", null), area): cdef = cd
		var trt := str(ch.get("trait", cdef.get("trait", MQ.SIL_TRAITS.get(cid, ""))))
		var pose := str(ch.get("pose", cdef.get("pose", "")))
		var fig := MQ.make(cid, trt, pose)
		var cb := _char_body(cid, fig, _xf(cdef.get("pos", ch.get("pos", [0, 0, 0])), cdef.get("rot", ch.get("rot", 0))))
		g_chars.add_child(cb)
		chars_index[cid] = cb
	# ---- siluetas (nodos con maniquí)
	var sil_defs: Dictionary = place.get("silhouettes", {}) if place.get("silhouettes", {}) is Dictionary else {}
	var sils = snap.get("silhouettes", [])
	if sils is Array:
		for who0 in sils:
			var who := str(who0)
			if who.begins_with("sil_"): who = who.substr(4)
			if not sil_defs.has(who): continue
			var sd: Dictionary = sil_defs[who]
			var trt2 := str(sd.get("trait", MQ.SIL_TRAITS.get(who, "")))
			var fig2 := MQ.make("sil_" + who, trt2, str(sd.get("pose", "")))
			var xf2 := _xf(sd.get("pos", [0, 0, 0]), sd.get("rot", 0))
			var aabb: AABB = fig2.get_meta("aabb")
			var sb := _node_body("sil_" + who, aabb.size, xf2 * Transform3D(Basis.IDENTITY, aabb.get_center()))
			sb.add_child(fig2)
			fig2.transform = Transform3D(Basis.IDENTITY, -aabb.get_center())
			sb.set_meta("noun", str(sd.get("noun", MQ.SIL_NOUNS.get(who, "figura"))))
			sb.set_meta("prop", "")
			sb.set_meta("silhouette", who)
			sb.collision_layer = LAYER_NODE | LAYER_CHAR  # la figura también tapa lo que está detrás (como un personaje)
			sb.set_meta("frame", str(sd.get("frame", "")))
			g_nodes.add_child(sb)
			nodes_index["sil_" + who] = sb
	# ---- encuadres
	var frames_meta := {}
	for fr in place.get("frames", []):
		if not (fr is Dictionary): continue
		var fid := str(fr.get("id", ""))
		var mk := Marker3D.new()
		mk.name = fid
		var pos := M.v3(fr.get("pos", [0, 1.6, 4]))
		var look := M.v3(fr.get("look", [0, 1.2, 0]))
		mk.transform = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP) if pos.distance_to(look) > 0.001 else Transform3D(Basis.IDENTITY, pos)
		var orbit: Dictionary = fr.get("orbit", {}) if fr.get("orbit", {}) is Dictionary else {}
		mk.set_meta("fov", float(fr.get("fov", 45.0)))
		mk.set_meta("orbit", orbit)
		mk.set_meta("area", str(fr.get("area", "*")))
		mk.set_meta("look", look)
		g_frames.add_child(mk)
		frames_meta[fid] = {"id": fid, "pos": pos, "look": look, "fov": float(fr.get("fov", 45.0)), "area": str(fr.get("area", "*")),
			"pivot": M.v3(orbit.get("pivot", null), look), "yaw": float(orbit.get("yaw", 25.0)), "pitch": float(orbit.get("pitch", 10.0))}
	# ---- luz y ambiente
	var lmap = place.get("light", {})
	var preset := ""
	var LT: Script = load("res://world/lighting.gd") if ResourceLoader.exists("res://world/lighting.gd") else null
	if LT != null and LT.has_method("preset_for"):
		preset = str(LT.preset_for(place, slot, snap))   # snap.day: luz por día (place.light["<día>.<franja>"]) y clima (noche del 5)
	elif lmap is Dictionary:
		preset = str(lmap.get(slot, ""))
		if preset == "" and slot == "dawn": preset = str(lmap.get("M", ""))
		if preset == "" and slot == "night": preset = str(lmap.get("N", ""))
	elif lmap is String:
		preset = lmap
	if preset == "": preset = SLOT_LIGHT_FALLBACK.get(slot, "dia_ventana")
	if snap.has("light"): preset = str(snap["light"])
	root.set_meta("light_preset", preset)
	var lights := build_lights(preset, slot, root)
	lights.name = "Lights"
	root.add_child(lights)
	var env := build_env(preset, slot)
	env.name = "Env"
	root.add_child(env)
	root.set_meta("frames", frames_meta)
	root.set_meta("cutaways", cutaways)
	root.set_meta("prop_bodies", prop_bodies)
	root.set_meta("nodes_index", nodes_index)
	root.set_meta("chars_index", chars_index)
	AFF.tag(root)
	return root

static func _cut_groups(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c.has_meta("cut_n"): out.append(c)
		out.append_array(_cut_groups(c))
	return out

static func _occ_body(name: String, occ: Array, xf: Transform3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.collision_layer = LAYER_OCC
	b.collision_mask = 0
	b.transform = xf
	b.set_meta("occluder", true)
	for e in occ:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		if e is AABB:
			sh.size = Vector3(maxf(e.size.x, 0.002), maxf(e.size.y, 0.002), maxf(e.size.z, 0.002))
			cs.position = e.get_center()
		elif e is Transform3D:
			var sc: Vector3 = e.basis.get_scale()
			sh.size = Vector3(maxf(absf(sc.x), 0.002), maxf(absf(sc.y), 0.002), maxf(absf(sc.z), 0.002))
			cs.transform = Transform3D(e.basis.orthonormalized(), e.origin)
		else:
			continue
		cs.shape = sh
		b.add_child(cs)
	return b

static func _node_body(nid: String, size: Vector3, xf: Transform3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nid.replace(".", "_")
	b.collision_layer = LAYER_NODE
	b.collision_mask = 0
	b.transform = xf
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(size.x, 0.005), maxf(size.y, 0.005), maxf(size.z, 0.005))
	cs.shape = sh
	b.add_child(cs)
	b.set_meta("node_id", nid)
	b.set_meta("size", sh.size)
	return b

static func _char_body(cid: String, fig: Node3D, xf: Transform3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "char_" + cid
	b.collision_layer = LAYER_CHAR
	b.collision_mask = 0
	b.transform = xf
	b.add_child(fig)
	var aabb: AABB = fig.get_meta("aabb", AABB(Vector3(-0.25, 0, -0.2), Vector3(0.5, 1.8, 0.4)))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = aabb.size
	cs.shape = sh
	cs.position = aabb.get_center()
	b.add_child(cs)
	b.set_meta("char_id", cid)
	b.set_meta("aabb", aabb)
	return b

# ---------------------------------------------------------------------------------------------
# Luz: si world/lighting.gd (W1-POST) expone `static func build(preset: String, slot: String) -> Node3D`, se usa;
# si no, presets mínimos propios (mismos nombres de §7.7). Los Marker3D "light_anchor" de los props se encienden
# como OmniLight3D en presets nocturnos (gas, farol_calle, noche_viento) o si el ancla tiene meta always=true.
static func build_lights(preset: String, slot: String, diorama: Node3D) -> Node3D:
	var L: Script = load("res://world/lighting.gd") if ResourceLoader.exists("res://world/lighting.gd") else null
	if L != null and L.has_method("build"):
		var n = L.build(preset, slot)
		if n is Node3D:
			if L.has_method("light_props"): L.light_props(n, diorama, preset)
			else: _light_anchors(n, diorama, preset)
			return n
	var root := Node3D.new()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var col := Color("f2ead8"); var en := 1.0; var ang := Vector3(-40, -35, 0)
	match preset:
		"manana_perla": col = Color("dcdcd6"); en = 0.9; ang = Vector3(-35, -30, 0)
		"dia_ventana": col = Color("f4ecdc"); en = 1.05; ang = Vector3(-42, -25, 0)
		"tarde": col = Color("f0d4a8"); en = 0.95; ang = Vector3(-22, 55, 0)
		"gas": col = Color("8a90a0"); en = 0.12; ang = Vector3(-60, 20, 0)
		"farol_calle": col = Color("9aa4b4"); en = 0.15; ang = Vector3(-55, 30, 0)
		"electrica_fria": col = Color("e6eef4"); en = 0.95; ang = Vector3(-70, 10, 0)
		"dorada_parklane": col = Color("ffc878"); en = 1.35; ang = Vector3(-11, 75, 0)
		"noche_viento": col = Color("8a96aa"); en = 0.12; ang = Vector3(-55, 30, 0)
	sun.light_color = col
	sun.light_energy = en
	sun.rotation_degrees = ang
	sun.shadow_enabled = preset in ["dorada_parklane", "tarde", "dia_ventana", "manana_perla", "electrica_fria"]
	root.add_child(sun)
	_light_anchors(root, diorama, preset)
	return root

static func _light_anchors(lights: Node3D, diorama: Node3D, preset: String) -> void:
	var night := preset in ["gas", "farol_calle", "noche_viento"]
	for mk in diorama.find_children("light_anchor*", "Marker3D", true, false):
		if not mk.get_meta("light", false): continue
		if not night and not mk.get_meta("always", false): continue
		var o := OmniLight3D.new()
		o.light_color = mk.get_meta("color", Color("ffc87a"))
		o.light_energy = float(mk.get_meta("energy", 1.4))
		o.omni_range = float(mk.get_meta("range", 7.0))
		o.omni_attenuation = 1.2
		o.shadow_enabled = bool(mk.get_meta("shadow", false))
		lights.add_child(o)
		o.position = M._rel_xform(diorama, mk).origin  # Lights cuelga del diorama con transform identidad

static func build_env(preset: String, slot: String) -> WorldEnvironment:
	var L: Script = load("res://world/lighting.gd") if ResourceLoader.exists("res://world/lighting.gd") else null
	if L != null and L.has_method("build_env"):
		var e = L.build_env(preset, slot)
		if e is WorldEnvironment: return e
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(PAPER.get(slot, "efe6d2"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb := Color("c8c0b0"); var ae := 0.55
	match preset:
		"manana_perla": amb = Color("c4c4bc"); ae = 0.6
		"dia_ventana": amb = Color("ccc4b4"); ae = 0.55
		"tarde": amb = Color("c8b498"); ae = 0.5
		"gas": amb = Color("8a7458"); ae = 0.45
		"farol_calle": amb = Color("6a7080"); ae = 0.4
		"electrica_fria": amb = Color("c4ccd4"); ae = 0.65
		"dorada_parklane": amb = Color("b89870"); ae = 0.45
		"noche_viento": amb = Color("606878"); ae = 0.38
	env.ambient_light_color = amb
	env.ambient_light_energy = ae
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssao_enabled = false
	we.environment = env
	return we
