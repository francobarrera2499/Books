# world/world_root.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.1 (Node3D; lo crea Shell en la capa 3D).
# API del contrato: señales node_clicked / character_clicked / empty_clicked; show_hub, show_plate, set_frame, frames,
# set_orbit_enabled, pick, pick_character, rect_clip, prewarm, current_plate.
# Extras: examine(node_id), back() -> bool (examen activo → vuelve; true si consumió), is_examining(), camera(),
#  set_input_enabled(on) (p. ej. en modo tijera la UI dibuja el rectángulo y llama rect_clip), set_fast(on),
#  set_engraving(on), diorama (Node3D actual), excluded_rids() (oclusores de muros cortados + nodos montados en ellos:
#  lo que no se ve no se clica ni se recorta).
# Entrada propia (_unhandled_input): clic izquierdo = pick + señal (sólo si el puntero no se movió >6 px entre apretar y
#  soltar); arrastre >6 px que empieza sobre el vacío = órbita; rueda = FOV; flechas (fe_orbita_*) = órbita;
#  fe_volver (clic derecho / Esc) sólo se consume si hay un examen activo.
extends Node3D

signal node_clicked(node_id: String)
signal character_clicked(char_id: String)
signal empty_clicked(screen_pos: Vector2)
signal plate_ready(plate_id: String)   # extra: tras el primer physics_frame del diorama nuevo (rect_clip ya es válido)

const DB = preload("res://world/diorama_builder.gd")
const RIG = preload("res://world/camera_rig.gd")
const PK = preload("res://world/picker.gd")
const RC = preload("res://world/rect_clip.gd")
const M3 = preload("res://world/materials.gd")

const HUB_PLACE := "L1"
const DRAG_PX := 6.0
const ORBIT_KEY_DEG_S := 50.0

var rig: Node3D
var diorama: Node3D = null
var place := {}
var snap := {}
var orbit_enabled := false
var input_enabled := true
var auto_examine := true
var _hidden_rids: Array = []
var _last_cam := Transform3D()
var _pressing := false
var _dragging := false
var _moved := false
var _cut_nodes: Array = []   # por grupo de corte (mismo orden que meta "cutaways"): cuerpos de nodos montados en ese muro
var _press_pos := Vector2.ZERO
var _press_kind := "none"
var _post: Node = null
var _engraving_on := true

func _init() -> void:
	name = "WorldRoot"
	rig = RIG.new()
	add_child(rig)

func _ready() -> void:
	_attach_post()

# ---------------------------------------------------------------------------------------------
# API §7.1
func show_hub(frame: String, slot: String) -> void:
	var repo = _repo()
	var pl: Dictionary = {}
	if repo != null and repo.has_method("place"):
		pl = repo.place(HUB_PLACE)
	if pl.is_empty():
		push_warning("WorldRoot.show_hub: no hay data/places/%s.json todavía" % HUB_PLACE)
		pl = {"id": HUB_PLACE, "frames": [{"id": frame, "pos": [0, 1.6, 3.5], "look": [0, 1.0, 0], "fov": 45}], "props": []}
	var area := _frame_area(pl, frame)
	var sn := _hub_snapshot(pl, area, slot)
	if not sn.has("slot"): sn["slot"] = slot
	# misma instantánea salvo el encuadre → no reconstruir (cambiar de encuadre en el hub es sólo mover la cámara)
	var same: bool = diorama != null and str(place.get("id", "")) == str(pl.get("id", "")) and _snap_key(snap) == _snap_key(sn)
	if not same:
		_show(sn, pl)
	set_orbit_enabled(false)
	if rig.has_frame(frame): set_frame(frame, not same)

func show_plate(p_snap: Dictionary, p_place: Dictionary) -> void:
	var same: bool = diorama != null and str(place.get("id", "")) == str(p_place.get("id", "")) and _snap_key(p_snap) == _snap_key(snap)
	if not same:
		_show(p_snap, p_place)
	elif p_snap.has("frame"):
		snap["frame"] = p_snap["frame"]
	set_orbit_enabled(str(p_place.get("id", "")) != HUB_PLACE)
	var f := str(p_snap.get("frame", ""))
	if f == "" or not rig.has_frame(f):
		f = _first_frame(str(p_snap.get("area", "*")))
	if f != "": set_frame(f, not same)

func set_frame(id: String, instant := false) -> void:
	rig.set_frame(id, instant)
	_update_cutaway(true)

func frames() -> Array:
	var area := str(snap.get("area", "*"))
	var out: Array = []
	var fm: Dictionary = diorama.get_meta("frames", {}) if diorama != null else {}
	var src: Array = place.get("frames", [])
	for fr in src:
		if not (fr is Dictionary): continue
		var a := str(fr.get("area", "*"))
		if a == "*" or area == "*" or area == "" or a == area:
			out.append(str(fr.get("id", "")))
	if out.is_empty(): out = fm.keys()
	return out

func set_orbit_enabled(on: bool) -> void:
	orbit_enabled = on
	rig.orbit_enabled = on

func pick(screen_pos: Vector2) -> Dictionary:
	var r := PK.pick(rig.cam, screen_pos, excluded_rids())
	return {"kind": r.get("kind", "none"), "id": r.get("id", "")}

func pick_character(screen_pos: Vector2) -> String:
	return PK.pick_character(rig.cam, screen_pos, excluded_rids())

func rect_clip(rect: Rect2) -> Dictionary:
	_update_cutaway(true)
	return RC.clip(rig.cam, rect, diorama, excluded_rids())

func prewarm(p_place: Dictionary) -> void:
	# construye el lugar completo, lo deja visible 2 cuadros detrás del fundido (compila pipelines) y lo libera
	if not is_inside_tree(): return
	var sn := {"id": "prewarm", "place": p_place.get("id", ""), "area": "*", "slot": "M", "variant": ""}
	var d := DB.build(p_place, sn)
	d.name = "Prewarm"
	# no tocar el diorama vivo: sin WorldEnvironment ni luces propias (liberar un Env vacía el del escenario)
	# y sin colisiones (un clic durante el precalentado no debe dar con estos cuerpos)
	for nm in ["Env", "Lights"]:
		var c := d.get_node_or_null(nm)
		if c != null:
			d.remove_child(c)
			c.free()
	for b in d.find_children("*", "CollisionObject3D", true, false):
		(b as CollisionObject3D).collision_layer = 0
	add_child(d)
	await get_tree().process_frame
	await get_tree().process_frame  # (frame_post_draw no llega en headless: dos cuadros alcanzan para dibujar uno)
	if is_instance_valid(d): d.queue_free()

func current_plate() -> String:
	return str(snap.get("id", ""))

# ---------------------------------------------------------------------------------------------
# extras
func camera() -> Camera3D:
	return rig.cam

func examine(node_id: String) -> bool:
	if diorama == null: return false
	var idx: Dictionary = diorama.get_meta("nodes_index", {})
	if not idx.has(node_id): return false
	var b: Node3D = idx[node_id]
	var s: Vector3 = b.get_meta("size", Vector3(0.3, 0.3, 0.3))
	var box := AABB(b.global_position - s * 0.5, s)
	rig.examine_aabb(box)
	return true

func back() -> bool:
	return rig.back()

func is_examining() -> bool:
	return rig.is_examining()

func set_input_enabled(on: bool) -> void:
	input_enabled = on
	_pressing = false
	_dragging = false
	_moved = false

func set_fast(on: bool) -> void:
	rig.fast = on

func excluded_rids() -> Array:
	return _hidden_rids.duplicate()

func node_body(node_id: String) -> Node3D:
	if diorama == null: return null
	return (diorama.get_meta("nodes_index", {}) as Dictionary).get(node_id, null)

# ---------------------------------------------------------------------------------------------
func _show(p_snap: Dictionary, p_place: Dictionary) -> void:
	if diorama != null:
		remove_child(diorama)
		diorama.queue_free()
		diorama = null
	place = p_place
	snap = p_snap.duplicate(true)
	diorama = DB.build(place, snap)
	add_child(diorama)
	rig.setup(diorama.get_meta("frames", {}))
	_cut_nodes = _nodes_on_cut_groups(diorama)
	_hidden_rids = []
	_last_cam = Transform3D()
	_set_post_slot(str(snap.get("slot", "M")))
	_physics_ready = false
	_emit_ready.call_deferred(diorama)

var _physics_ready := false

func is_plate_ready() -> bool:
	return _physics_ready

func _emit_ready(d: Node3D) -> void:
	if not is_inside_tree(): return
	await get_tree().physics_frame
	if d != diorama or not is_instance_valid(d): return
	_physics_ready = true
	plate_ready.emit(current_plate())

static func _snap_key(s: Dictionary) -> Dictionary:
	var k := s.duplicate(true)
	k.erase("frame")
	return k

func _first_frame(area: String) -> String:
	for fr in place.get("frames", []):
		if fr is Dictionary:
			var a := str(fr.get("area", "*"))
			if a == "*" or area == "*" or area == "" or a == area: return str(fr.get("id", ""))
	var ids: Array = rig.frame_ids()
	return str(ids[0]) if not ids.is_empty() else ""

func _frame_area(pl: Dictionary, frame: String) -> String:
	for fr in pl.get("frames", []):
		if fr is Dictionary and str(fr.get("id", "")) == frame:
			var a := str(fr.get("area", "*"))
			if a != "*": return a
	var areas = pl.get("areas", {})
	if pl.has("hub_area"): return str(pl["hub_area"])
	if areas is Dictionary and not areas.is_empty():
		var ks: Array = areas.keys()
		return str(ks[0])
	return "*"

func _hub_snapshot(pl: Dictionary, area: String, slot: String) -> Dictionary:
	var g = _autoload("Game")
	var sim = g.get("sim") if g != null else null
	if sim != null:
		if sim.has_method("q_hub_plate"):
			var s = sim.q_hub_plate()
			if s is Dictionary and not s.is_empty(): return s
		var WM = load("res://core/sim/world_model.gd") if ResourceLoader.exists("res://core/sim/world_model.gd") else null
		if WM != null and WM.has_method("snapshot") and sim.get("st") != null:
			var s2 = WM.snapshot(sim.st, sim.repo, HUB_PLACE, area, "")
			if s2 is Dictionary and not s2.is_empty():
				if not s2.has("slot"): s2["slot"] = slot
				return s2
	var ids: Array = []
	for nd in pl.get("nodes", []):
		if nd is Dictionary:
			var a := str(nd.get("area", "*"))
			if a == "*" or a == area or area == "*": ids.append(str(nd.get("id", "")))
	return {"id": "HUB.%s" % area, "place": HUB_PLACE, "area": area, "day": 0, "slot": slot, "variant": "", "nodes": ids, "chars": [], "silhouettes": []}

func _repo():
	var d = _autoload("Data")
	if d != null and d.has_method("repo"): return d.repo()
	return null

func _autoload(n: String) -> Node:
	if not is_inside_tree(): return null
	return get_tree().root.get_node_or_null(n)

# ---------------------------------------------------------------------------------------------
# corte de muros: oculta el grupo (y quita su oclusor de los rayos) si la cámara está del lado de afuera
func _update_cutaway(force := false) -> void:
	if diorama == null or not is_inside_tree(): return
	var cxf: Transform3D = rig.cam.global_transform
	if not force and cxf.is_equal_approx(_last_cam): return
	_last_cam = cxf
	var cp := cxf.origin
	var hidden: Array = []
	var cws: Array = diorama.get_meta("cutaways", [])
	for i in cws.size():
		var cw: Dictionary = cws[i]
		var grp: Node3D = cw["group"]
		if not is_instance_valid(grp): continue
		var gx := grp.global_transform
		var n: Vector3 = (gx.basis * (grp.get_meta("cut_n") as Vector3)).normalized()
		var p: Vector3 = gx * (grp.get_meta("cut_p") as Vector3)
		var inside := (cp - p).dot(n) > 0.0
		grp.visible = inside
		if not inside:
			hidden.append((cw["body"] as CollisionObject3D).get_rid())
			# los nodos montados en ese muro (puerta, ventana, cartel…) tampoco se ven: no se clican ni se recortan
			if i < _cut_nodes.size():
				for nb in _cut_nodes[i]:
					if is_instance_valid(nb): hidden.append((nb as CollisionObject3D).get_rid())
	_hidden_rids = hidden

# nodos cuyo centro de ancla cae dentro de la losa de un grupo de corte (entre su cara interior y la exterior, ±6 cm)
static func _nodes_on_cut_groups(d: Node3D) -> Array:
	const MARGIN := 0.06
	var out: Array = []
	var idx: Dictionary = d.get_meta("nodes_index", {})
	for cw in d.get_meta("cutaways", []):
		var lst: Array = []
		out.append(lst)
		var grp: Node3D = cw["group"]
		var body: Node3D = cw["body"]
		if not is_instance_valid(grp) or not is_instance_valid(body): continue
		var gx := M3._rel_xform(d, grp)
		var n: Vector3 = (gx.basis * (grp.get_meta("cut_n") as Vector3)).normalized()
		var p: Vector3 = gx * (grp.get_meta("cut_p") as Vector3)
		var bx := M3._rel_xform(d, body)
		var dmin := 0.0
		var box := AABB()
		var first := true
		for cs in body.get_children():
			if not (cs is CollisionShape3D) or not ((cs as CollisionShape3D).shape is BoxShape3D): continue
			var h: Vector3 = ((cs as CollisionShape3D).shape as BoxShape3D).size * 0.5
			var t: Transform3D = bx * (cs as CollisionShape3D).transform
			for k in 8:
				var c := t * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1))
				dmin = minf(dmin, (c - p).dot(n))
				if first: box = AABB(c, Vector3.ZERO); first = false
				else: box = box.expand(c)
		if first: continue
		box = box.grow(MARGIN)
		for nid in idx:
			var nb: Node3D = idx[nid]
			if nb.has_meta("silhouette"): continue
			var c2: Vector3 = M3._rel_xform(d, nb).origin
			var dist := (c2 - p).dot(n)
			if dist <= MARGIN and dist >= dmin - MARGIN and box.has_point(c2): lst.append(nb)
	return out

func _process(delta: float) -> void:
	if diorama == null: return
	if input_enabled and (orbit_enabled or rig.is_examining()):
		var fo = get_viewport().gui_get_focus_owner()
		if fo == null or not (fo is LineEdit or fo is TextEdit):
			var dy := 0.0; var dp := 0.0
			if InputMap.has_action("fe_orbita_izq") and Input.is_action_pressed("fe_orbita_izq"): dy -= 1.0
			if InputMap.has_action("fe_orbita_der") and Input.is_action_pressed("fe_orbita_der"): dy += 1.0
			if InputMap.has_action("fe_orbita_arriba") and Input.is_action_pressed("fe_orbita_arriba"): dp += 1.0
			if InputMap.has_action("fe_orbita_abajo") and Input.is_action_pressed("fe_orbita_abajo"): dp -= 1.0
			if dy != 0.0 or dp != 0.0:
				rig.orbit_by(dy * ORBIT_KEY_DEG_S * delta, dp * ORBIT_KEY_DEG_S * 0.6 * delta)
	_update_cutaway()

func _unhandled_input(ev: InputEvent) -> void:
	if not input_enabled or diorama == null: return
	# fe_volver (clic derecho o Esc) primero: el clic derecho también es un InputEventMouseButton
	if InputMap.has_action("fe_volver") and ev.is_action_pressed("fe_volver") and rig.is_examining():
		rig.back()
		_pressing = false
		_dragging = false
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_moved = false
				_press_pos = mb.position
				_press_kind = pick(mb.position)["kind"]
			else:
				# umbral 6 px (§7.5): si el puntero se movió más que eso no es clic (orbitó o se arrastró sobre un objeto)
				if _pressing and not _moved and mb.position.distance_to(_press_pos) <= DRAG_PX: _click(_press_pos)
				_pressing = false
				_dragging = false
				_moved = false
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			rig.zoom_by(-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and _pressing:
		var mm := ev as InputEventMouseMotion
		if not _moved and mm.position.distance_to(_press_pos) > DRAG_PX:
			_moved = true
			if _press_kind == "none" and (orbit_enabled or rig.is_examining()):
				_dragging = true
		if _dragging:
			rig.orbit_by(-mm.relative.x * 0.25, mm.relative.y * 0.2)
			get_viewport().set_input_as_handled()

func _click(pos: Vector2) -> void:
	var r := pick(pos)
	match str(r["kind"]):
		"node":
			node_clicked.emit(str(r["id"]))
			if auto_examine and orbit_enabled: examine(str(r["id"]))
		"char":
			character_clicked.emit(str(r["id"]))
		_:
			empty_clicked.emit(pos)

# ---------------------------------------------------------------------------------------------
# post-proceso de grabado (W1-POST): se cuelga de la cámara si existe world/post/engraving_post.gd
func set_engraving(on: bool) -> void:
	_engraving_on = on
	if _post != null and is_instance_valid(_post):
		if _post is Node3D: (_post as Node3D).visible = on
	elif on:
		_attach_post()

func _attach_post() -> void:
	if not _engraving_on or _post != null: return
	var path := "res://world/post/engraving_post.gd"
	if not ResourceLoader.exists(path): return
	var E: Script = load(path)
	if E == null: return
	if E.has_method("attach"):
		var r = E.attach(rig.cam)
		if r is Node: _post = r
	else:
		var inst = E.new()
		if inst is Node:
			rig.cam.add_child(inst)
			_post = inst
	_set_post_slot(str(snap.get("slot", "M")))

func _set_post_slot(slot: String) -> void:
	if _post == null or not is_instance_valid(_post): return
	var preset := str(diorama.get_meta("light_preset", "")) if diorama != null else ""
	var LT: Script = load("res://world/lighting.gd") if ResourceLoader.exists("res://world/lighting.gd") else null
	if LT != null and LT.has_method("look") and _post.has_method("set_look") and preset != "":
		_post.set_look(LT.look(preset, slot))
	elif _post.has_method("set_slot"):
		_post.set_slot(slot)
	if _post.has_method("reanchor"): _post.reanchor()

func engraving_post() -> Node:
	return _post
