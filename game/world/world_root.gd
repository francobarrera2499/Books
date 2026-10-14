# world/world_root.gd — W1-3D; v3 UI-MUNDO (GDD_v3 §6.5, §6.6). Contrato: docs/ARCHITECTURE.md §7.1 (Node3D; lo crea Shell
# en la capa 3D). API: señales node_clicked / character_clicked / empty_clicked / hover_changed / plate_ready; show_hub,
# show_plate, set_frame, frames, set_orbit_enabled, pick, pick_character, rect_clip (bots y tests: la interfaz ya no
# recorta el 3D con un rectángulo), prewarm, current_plate, camera(), node_body(id), set_input_enabled(on), set_fast(on),
# set_engraving(on), excluded_rids() (oclusores de muros cortados + nodos montados en ellos: lo que no se ve no se clica).
# v3 CÁMARA (§6.6): sin posiciones intermedias. La cámara va por el riel de camera_rig.gd; un clic USA en el acto (sólo
#  informa node_clicked/character_clicked: no se acerca ni se mueve). examine(id)/is_examining()/back() quedan por
#  compatibilidad sin mover nada.
# Entrada (_unhandled_input): clic izquierdo = pick + señal (sólo si el puntero no se movió >6 px entre apretar y soltar);
#  arrastre >6 px = girar (se agarra el mundo); rueda = acercar el FOV hacia el cursor; flechas (fe_orbita_*) = girar.
#  Bandas del borde (8 % a los lados, 10 % arriba y abajo, 0,15 s, 45 °/s × smoothstep; nunca sobre la interfaz, con un
#  panel, durante un arrastre o sin un movimiento real del mouse: edge_enabled lo pone la pantalla de juego).
# v3 AFORDANCIAS (§6.5): world/affordance/* — bajo el mouse (pick a ≤30 Hz con picker.gd) SÓLO un contorno blanco (código 3
#  en la rugosidad) y el cursor: lupa (examinable) o mano (usable: set_usable con dueños «n:<nodo>»/«c:<personaje>», y
#  hand: siluetas a las que se les habla). Sin etiqueta, sin aclarado, sin contorno permanente.
extends Node3D

signal node_clicked(node_id: String)
signal character_clicked(char_id: String)
signal empty_clicked(screen_pos: Vector2)
signal plate_ready(plate_id: String)   # tras el primer physics_frame del diorama nuevo (rect_clip ya es válido)
signal hover_changed(kind: String, id: String, screen_pos: Vector2)

const DB = preload("res://world/diorama_builder.gd")
const RIG = preload("res://world/camera_rig.gd")
const PK = preload("res://world/picker.gd")
const RC = preload("res://world/rect_clip.gd")
const M3 = preload("res://world/materials.gd")
const AFF = preload("res://world/affordance/affordance.gd")
const AFFP = preload("res://world/affordance/affordance_post.gd")

const HUB_PLACE := "L1"
const DRAG_PX := 6.0
const KEY_DEG_S := 60.0
const EDGE_X := 0.08
const EDGE_Y := 0.10
const EDGE_DELAY := 0.15
const EDGE_DEG_S := 45.0
const HOVER_HZ := 30.0

var rig: Node3D
var diorama: Node3D = null
var place := {}
var snap := {}
var orbit_enabled := false
var input_enabled := true
var edge_enabled := true:         # la pantalla de juego lo apaga con un panel abierto
	set(v):
		if v and not edge_enabled: _edge_armed = false   # al cerrar un panel el mouse suele quedar sobre la franja
		edge_enabled = v
# Bandas «armadas»: tras cerrar un panel (o reactivar la entrada) el borde no gira hasta que el mouse se mueva de verdad
# FUERA de las franjas (playtest v3: el botón Volver/Subir/Cerrar queda en la franja y la vista salía disparada).
var _edge_armed := true
var hover_enabled := true
var usable := {}                  # dueño -> true: mano al pasar
var hand := {}                    # dueño -> true: mano al pasar (siluetas con las que se habla)
var hover_kind := "none"
var hover_id := ""
var _hover_acc := 0.0
var _hover_last_mouse := Vector2(-1, -1)
var _edge_t := 0.0
var _mouse_in := true
var _mouse_seen := false          # hubo un movimiento real del mouse (sin él, ni bandas ni realce: tests sin pantalla)
var _mouse_pos := Vector2(-1, -1) # última posición del mouse según sus eventos (coordenadas del viewport, como el clic)
var _aff_post: Node = null
var _hidden_rids: Array = []
var _last_cam := Transform3D()
var _pressing := false
var _dragging := false
var _moved := false
var _cut_nodes: Array = []   # por grupo de corte (mismo orden que meta "cutaways"): cuerpos de nodos montados en ese muro
var _press_pos := Vector2.ZERO
var _post: Node = null
var _engraving_on := true

func _init() -> void:
	name = "WorldRoot"
	rig = RIG.new()
	add_child(rig)

func _ready() -> void:
	_attach_post()
	_attach_aff()

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
	# la instantánea del hub trae todas las áreas (""): la cámara usa el riel del área del encuadre pedido
	if str(sn.get("area", "")) in ["", "*"]: sn["cam_area"] = area
	# misma instantánea salvo el encuadre → no reconstruir (cambiar de punto en el hub es sólo mover la cámara)
	var same: bool = diorama != null and str(place.get("id", "")) == str(pl.get("id", "")) and _snap_key(snap) == _snap_key(sn)
	if not same:
		_show(sn, pl)
	set_orbit_enabled(true)
	if rig.has_frame(frame): set_frame(frame, not same)
	elif not same: rig.go_overview(true)

func show_plate(p_snap: Dictionary, p_place: Dictionary) -> void:
	var same: bool = diorama != null and str(place.get("id", "")) == str(p_place.get("id", "")) and _snap_key(p_snap) == _snap_key(snap)
	if not same:
		_show(p_snap, p_place)
	elif p_snap.has("frame"):
		snap["frame"] = p_snap["frame"]
	set_orbit_enabled(true)
	var f := str(p_snap.get("frame", ""))
	if f == "" or not rig.has_frame(f):
		f = rig.home
	if f != "": set_frame(f, not same)

func set_frame(id: String, instant := false) -> void:
	rig.set_frame(id, instant)
	_update_cutaway(true)

# Puntos del riel del área actual (los ids que acepta set_frame).
func frames() -> Array:
	return rig.frame_ids()

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

# v3: examinar ya no acerca la cámara (la tarjeta basta). true si el nodo existe.
func examine(node_id: String) -> bool:
	return node_body(node_id) != null

func is_examining() -> bool:
	return false

func back() -> bool:
	return false

func go_overview() -> void:
	rig.go_overview()
	_update_cutaway(true)

func pose_mode() -> String:
	return rig.mode()

# Rids ocultos por el corte de muros si la cámara estuviera en cp (mismo criterio que _update_cutaway).
func hidden_rids_for(cp: Vector3) -> Array:
	var hidden: Array = []
	if diorama == null: return hidden
	var cws: Array = diorama.get_meta("cutaways", [])
	for i in cws.size():
		var cw: Dictionary = cws[i]
		var grp: Node3D = cw["group"]
		if not is_instance_valid(grp): continue
		var gx := grp.global_transform
		var n: Vector3 = (gx.basis * (grp.get_meta("cut_n") as Vector3)).normalized()
		var p: Vector3 = gx * (grp.get_meta("cut_p") as Vector3)
		if (cp - p).dot(n) <= 0.0:
			hidden.append((cw["body"] as CollisionObject3D).get_rid())
			if i < _cut_nodes.size():
				for nb in _cut_nodes[i]:
					if is_instance_valid(nb): hidden.append((nb as CollisionObject3D).get_rid())
	return hidden

func set_input_enabled(on: bool) -> void:
	if on == input_enabled:
		return
	input_enabled = on
	_pressing = false
	_dragging = false
	_moved = false
	_edge_t = 0.0
	if on: _edge_armed = false
	if not on:
		_hover_set("none", "", Vector2.ZERO)

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
	var area := str(snap.get("cam_area", snap.get("area", "*")))
	var key := str(place.get("id", ""))
	# láminas fijas (PRO, M7): su propio riel si camera.json lo trae; si no, el de su lugar
	var cfg: Dictionary = RIG.cfg_for(key, area)
	rig.setup(diorama.get_meta("frames", {}), cfg, bool(place.get("fixed", false)), _area_frames(area))
	rig.set_home(_first_frame(area))
	_hover_set("none", "", Vector2.ZERO)
	# lo usable era del diorama anterior: la pantalla de juego lo vuelve a decidir al sincronizar
	usable = {}
	hand = {}
	_cut_nodes = _nodes_on_cut_groups(diorama)
	_hidden_rids = []
	_last_cam = Transform3D()
	_set_post_slot(str(snap.get("slot", "M")))
	_sync_aff_palette()
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

# Encuadres del lugar que son del área (los del área y los comunes "*").
func _area_frames(area: String) -> Array:
	var out: Array = []
	for fr in place.get("frames", []):
		if not (fr is Dictionary): continue
		var a := str(fr.get("area", "*"))
		if a == "*" or area == "*" or area == "" or a == area:
			out.append(str(fr.get("id", "")))
	return out

func _first_frame(area: String) -> String:
	var af := _area_frames(area)
	if not af.is_empty(): return str(af[0])
	var ids: Array = rig.frame_ids()
	return str(ids[0]) if not ids.is_empty() else ""

func _frame_area(pl: Dictionary, frame: String) -> String:
	for fr in pl.get("frames", []):
		if fr is Dictionary and str(fr.get("id", "")) == frame:
			var a := str(fr.get("area", "*"))
			if a != "*": return a
	# un punto del riel de camera.json (L1.tienda: escalera, revistas…) dice su área
	var all := RIG.cfg_all()
	for k in all:
		if not str(k).begins_with(str(pl.get("id", "")) + "."): continue
		var c = all[k]
		if c is Dictionary:
			for r in c.get("rail", []):
				if r is Dictionary and (str(r.get("id", "")) == frame or (r.get("alias", []) as Array).has(frame)):
					return str(k).get_slice(".", 1)
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
	var cws: Array = diorama.get_meta("cutaways", [])
	for i in cws.size():
		var cw: Dictionary = cws[i]
		var grp: Node3D = cw["group"]
		if not is_instance_valid(grp): continue
		var gx := grp.global_transform
		var n: Vector3 = (gx.basis * (grp.get_meta("cut_n") as Vector3)).normalized()
		var p: Vector3 = gx * (grp.get_meta("cut_p") as Vector3)
		grp.visible = (cp - p).dot(n) > 0.0
	# los nodos montados en un muro cortado (puerta, ventana, cartel…) tampoco se ven: no se clican
	_hidden_rids = hidden_rids_for(cp)

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
	var fo = get_viewport().gui_get_focus_owner()
	var typing: bool = fo != null and (fo is LineEdit or fo is TextEdit)
	if input_enabled and orbit_enabled and not typing:
		var dy := 0.0; var dp := 0.0
		# ← mira a la izquierda (yaw +), ↑ mira arriba
		if InputMap.has_action("fe_orbita_izq") and Input.is_action_pressed("fe_orbita_izq"): dy += 1.0
		if InputMap.has_action("fe_orbita_der") and Input.is_action_pressed("fe_orbita_der"): dy -= 1.0
		if InputMap.has_action("fe_orbita_arriba") and Input.is_action_pressed("fe_orbita_arriba"): dp += 1.0
		if InputMap.has_action("fe_orbita_abajo") and Input.is_action_pressed("fe_orbita_abajo"): dp -= 1.0
		if dy != 0.0 or dp != 0.0:
			rig.look_by(dy * KEY_DEG_S * delta, dp * KEY_DEG_S * 0.6 * delta)
	if _pressing:
		rig.hold()   # con el botón apretado (arrastre) la cámara no se asienta en un punto
	_edge_step(delta)
	_hover_step(delta)
	_update_cutaway()

# Vector de las bandas del borde para una posición del mouse (x: + mira a la izquierda; y: + mira arriba), 0..1 con
# smoothstep de la profundidad en la banda. Estática: la prueban los tests sin pantalla.
static func edge_vector(pos: Vector2, size: Vector2) -> Vector2:
	var v := Vector2.ZERO
	if size.x <= 0.0 or size.y <= 0.0: return v
	var bx := size.x * EDGE_X
	var by := size.y * EDGE_Y
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > size.x or pos.y > size.y: return v
	if pos.x < bx: v.x = smoothstep(0.0, 1.0, (bx - pos.x) / bx)
	elif pos.x > size.x - bx: v.x = -smoothstep(0.0, 1.0, (pos.x - (size.x - bx)) / bx)
	if pos.y < by: v.y = smoothstep(0.0, 1.0, (by - pos.y) / by)
	elif pos.y > size.y - by: v.y = -smoothstep(0.0, 1.0, (pos.y - (size.y - by)) / by)
	return v

func edge_debug() -> Dictionary:
	var vp := get_viewport()
	var w := get_window()
	return {"opt": RIG.edge_turn, "edge_enabled": edge_enabled, "input": input_enabled, "pressing": _pressing, "dragging": _dragging,
		"mouse_in": _mouse_in, "mouse_seen": _mouse_seen, "armed": _edge_armed, "mode": rig.mode(), "orbit": orbit_enabled,
		"hovered": str(vp.gui_get_hovered_control().get_path()) if vp != null and vp.gui_get_hovered_control() != null else "",
		"focus": DisplayServer.window_is_focused(), "win_focus": w.has_focus() if w != null else false, "mouse": _mouse_pos,
		"mouse_vp": vp.get_mouse_position() if vp != null else Vector2.ZERO}

# ¿Puede girar la banda del borde ahora? (sin interfaz debajo, sin panel, sin arrastre, con foco)
func edge_allowed() -> bool:
	if not RIG.edge_turn or not edge_enabled or not input_enabled or diorama == null: return false
	if _pressing or _dragging or not _mouse_in or not _mouse_seen or not _edge_armed: return false
	if rig.mode() == "" or not orbit_enabled: return false
	var vp := get_viewport()
	if vp == null or vp.gui_get_hovered_control() != null or vp.gui_is_dragging(): return false
	# foco de la ventana del sistema (Window.has_focus() del root quedaba en false tras los menús emergentes del título)
	if DisplayServer.get_name() != "headless" and not DisplayServer.window_is_focused(): return false
	return true

func _edge_step(delta: float) -> void:
	if not edge_allowed():
		_edge_t = 0.0
		return
	var vp := get_viewport()
	var v := edge_vector(_mouse_pos, vp.get_visible_rect().size)
	if v == Vector2.ZERO:
		_edge_t = 0.0
		return
	_edge_t += delta
	if _edge_t < EDGE_DELAY: return
	rig.look_by(v.x * EDGE_DEG_S * delta, v.y * EDGE_DEG_S * delta)

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse_seen = true
		_mouse_in = true
		_mouse_pos = (ev as InputEventMouseMotion).position
		if not _edge_armed:
			var vp := get_viewport()
			if vp != null and edge_vector(_mouse_pos, vp.get_visible_rect().size) == Vector2.ZERO: _edge_armed = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in = false
		_hover_set("none", "", Vector2.ZERO)
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in = true

func _unhandled_input(ev: InputEvent) -> void:
	if not input_enabled or diorama == null: return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_moved = false
				_press_pos = mb.position
			else:
				# umbral 6 px (§7.5): si el puntero se movió más que eso no es clic (giró la vista)
				if _pressing and not _moved and mb.position.distance_to(_press_pos) <= DRAG_PX: _click(_press_pos)
				_pressing = false
				_dragging = false
				_moved = false
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			rig.wheel(-1.0 if up else 1.0, rig.cursor_angles(mb.position) if up else Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and _pressing:
		var mm := ev as InputEventMouseMotion
		if not _moved and mm.position.distance_to(_press_pos) > DRAG_PX:
			_moved = true
			if orbit_enabled:
				_dragging = true
				_hover_set("none", "", Vector2.ZERO)
		if _dragging:
			rig.drag_by(mm.relative)
			get_viewport().set_input_as_handled()

func _click(pos: Vector2) -> void:
	var r := pick(pos)
	match str(r["kind"]):
		"node":
			node_clicked.emit(str(r["id"]))
		"char":
			character_clicked.emit(str(r["id"]))
		_:
			empty_clicked.emit(pos)

# ---------------------------------------------------------------------------------------------
# v3 afordancias (GDD_v3 §6.5): contorno blanco y cursor bajo el mouse
func _attach_aff() -> void:
	if _aff_post != null and is_instance_valid(_aff_post): return
	_aff_post = AFFP.attach(rig.cam)

func aff_post() -> Node:
	return _aff_post

func _sync_aff_palette() -> void:
	pass

# usable/hand: {dueño: true} con dueños «n:<nodo>» / «c:<personaje>» (AFF.key_of). Sólo deciden el cursor (mano).
func set_usable(p_usable: Dictionary, p_hand := {}) -> void:
	if p_usable == usable and p_hand == hand: return
	usable = p_usable.duplicate()
	hand = p_hand.duplicate()
	_hover_set(hover_kind, hover_id, _hover_last_mouse, true)

func is_usable(kind: String, id: String) -> bool:
	var k := AFF.key_of(kind, id)
	return usable.has(k) or hand.has(k)

func cursor_for(kind: String, id: String) -> int:
	if kind == "none" or id == "": return Input.CURSOR_ARROW
	return Input.CURSOR_POINTING_HAND if is_usable(kind, id) else Input.CURSOR_HELP

func _hover_step(delta: float) -> void:
	if not hover_enabled: return   # (tests y sondas fijan el realce con hover_at)
	_hover_acc += delta
	if _hover_acc < 1.0 / HOVER_HZ: return
	_hover_acc = 0.0
	var vp := get_viewport()
	if vp == null: return
	var ok := input_enabled and diorama != null and _mouse_in and _mouse_seen and not _dragging and is_plate_ready()
	if ok and (vp.gui_get_hovered_control() != null or vp.gui_is_dragging()): ok = false
	if not ok:
		_hover_set("none", "", Vector2.ZERO)
		return
	var mp := _mouse_pos
	if not vp.get_visible_rect().has_point(mp):
		_hover_set("none", "", Vector2.ZERO)
		return
	_hover_last_mouse = mp
	var r := pick(mp)
	_hover_set(str(r["kind"]), str(r["id"]), mp)

func _hover_set(kind: String, id: String, pos: Vector2, force := false) -> void:
	if id == "": kind = "none"
	var changed := kind != hover_kind or id != hover_id
	if not changed and not force: return
	hover_kind = kind
	hover_id = id
	if diorama != null:
		AFF.set_hover(diorama, AFF.key_of(kind, id))
	Input.set_default_cursor_shape(cursor_for(kind, id))
	if changed: hover_changed.emit(kind, id, pos)

# Forzar el realce bajo una posición (drivers y tests con ventana; el jugador lo hace con el mouse).
func hover_at(pos: Vector2) -> Dictionary:
	var r := pick(pos)
	_hover_last_mouse = pos
	_hover_set(str(r["kind"]), str(r["id"]), pos)
	return r

func _pick_near(cam: Camera3D, b: Node3D, excl: Array) -> Vector2:
	var nid := str(b.get_meta("node_id", ""))
	var s: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
	for off in [Vector3.ZERO, Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.3, 0, 0), Vector3(-s.x * 0.3, 0, 0), Vector3(0, -s.y * 0.3, 0), Vector3(0, 0, s.z * 0.3)]:
		var p: Vector3 = b.global_position + off
		if cam.is_position_behind(p): continue
		var q := cam.unproject_position(p)
		if str(PK.pick(cam, q, excl).get("id", "")) == nid: return q
	return Vector2(-1, -1)

# Examinables a la vista con un punto donde el clic llega a ellos: [{kind, id, pos}] (drivers y tests).
func visible_nodes() -> Array:
	var out: Array = []
	if diorama == null: return out
	var cam: Camera3D = rig.cam
	var vr := get_viewport().get_visible_rect()
	var excl := excluded_rids()
	var idx: Dictionary = diorama.get_meta("nodes_index", {})
	for nid in idx:
		var b: Node3D = idx[nid]
		if excl.has((b as CollisionObject3D).get_rid()): continue
		var p := b.global_position
		if cam.is_position_behind(p): continue
		var sp := cam.unproject_position(p)
		if not vr.grow(-8.0).has_point(sp): continue
		var at := _pick_near(cam, b, excl)
		if at.x < 0.0: continue
		out.append({"kind": "node", "id": str(nid), "pos": at})
	var ci: Dictionary = diorama.get_meta("chars_index", {})
	for cid in ci:
		var cb: Node3D = ci[cid]
		var aabb: AABB = cb.get_meta("aabb", AABB(Vector3(-0.25, 0, -0.2), Vector3(0.5, 1.8, 0.4)))
		var p2: Vector3 = cb.global_transform * aabb.get_center()
		if cam.is_position_behind(p2): continue
		var sp2 := cam.unproject_position(p2)
		if not vr.grow(-8.0).has_point(sp2): continue
		out.append({"kind": "char", "id": str(cid), "pos": sp2})
	return out

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
