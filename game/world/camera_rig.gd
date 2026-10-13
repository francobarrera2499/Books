# world/camera_rig.gd — W1-3D; v2 CÁMARA (GDD_v2 §E: adiós a las flechitas). Contrato: docs/ARCHITECTURE.md §7.5.
# Pila de poses: [vista general] → [zona] → [examen]. back() saca una (clic derecho / Esc baja un nivel).
#   overview: «de pie en la puerta»; gira EN EL LUGAR (pivote = la cámara) dentro de límites (yaw/pitch de la pose).
#   zone:     un encuadre de places/*.json (los frames de siempre); mirada reducida a ±12°, en el lugar.
#   examine:  órbita corta (±40°/±22°) alrededor de la caja del objeto examinado (el examine_aabb de antes).
# Vista general: world/camera.json (por «<lugar>.<área>», «<lugar>» o «*»): {overview: {pos, look, fov, yaw, pitch} |
#   "first_frame", zones: {nodo: frame}}. Con "first_frame" la general es el primer encuadre del área (home, lo fija
#   WorldRoot) con la órbita de ese encuadre (±orbit.yaw/±orbit.pitch, 25°/10° si no trae) acotada a un arco de
#   ORBIT_ARC m alrededor de su pivote; láminas fijas además ≤ ±15°/±8°. (El yaw_min/pitch de «*» que proponía el GDD
#   §E.2 NO se usa: con ±35° los dioramas mostraban sus bordes y atravesaban paredes; lo reemplazan las estaciones.)
# Signos en el lugar: yaw + = mirar a la izquierda, pitch + = mirar arriba. En el examen: los de la órbita de antes.
# Suavizado: giro y FOV siguen a su objetivo con x += (obj − x)·(1 − e^(−12·dt)) (look_by, wheel); orbit_by/zoom_by
#   (arrastre, flechas, API de tests) son inmediatos. FOV entre base −18° y base +4°; rueda: −3° por muesca y gira el 25 %
#   hacia el cursor; hacia afuera deshace el último giro de la rueda. Transición entre poses 0,45 s (ease in-out).
# set_frame(id): id = home (o "general") → [general]; otro encuadre → [general, zona(id)] (director, tutorial, drivers).
# edge_turn (static): opción «Girar la vista con los bordes de la pantalla» (Opciones; WorldRoot la consulta).
# Estaciones (lugares sin vista general propia: L2–L8 y láminas): cada encuadre del área es un punto desde donde mirar,
#   con los mismos límites que la general; neighbor(dir) = el encuadre cuyo foco queda más cerca hacia ese lado (dar
#   la vuelta). WorldRoot pasa a la estación vecina si se sigue empujando contra el límite (borde o flechas) 0,6 s y
#   lleva a la estación de un nodo lejano al clicarlo (best_station). En casa (general propia) las zonas son explícitas.
# La entrada (mouse/teclas) la traduce WorldRoot; acá sólo hay estado y matemática (testeable headless).
extends Node3D

const TRANSITION_S := 0.45
const EXAMINE_YAW := 40.0
const EXAMINE_PITCH := 22.0
const ZONE_LOOK := 12.0
const SMOOTH_K := 12.0
const FOV_IN := 18.0
const FOV_OUT := 4.0
const FOV_STEP := 3.0
const WHEEL_TURN := 0.25
const DEF_YAW_MIN := 35.0
const DEF_PITCH := 12.0
const FIXED_YAW := 15.0
const FIXED_PITCH := 8.0
const GENERAL := "general"
const ORBIT_ARC := 1.8       # m: lo más que la órbita de un diorama traslada la cámara
const CFG_PATH := "res://world/camera.json"

static var edge_turn := true
static var _cfg_all = null

var cam: Camera3D
var frames := {}            # id → {id, pos, look, fov, area, pivot, yaw, pitch}
var cfg := {}               # entrada de camera.json para este lugar/área
var fixed := false          # lámina fija
var home := ""              # encuadre de la vista general (GENERAL si camera.json trae una pose propia)
var stack: Array = []       # poses: {kind, id, pos, look, fov, yaw, pitch} | {kind: examine, pivot, dist, dir, fov}
var cur := ""               # encuadre de la última pose que no es examen (compatibilidad)
var orbit_enabled := true   # mirar alrededor habilitado (el examen siempre orbita)
var fast := false           # sin transiciones ni suavizado (--fast, tests)
var yaw_off := 0.0
var pitch_off := 0.0
var fov_off := 0.0
var yaw_t := 0.0
var pitch_t := 0.0
var fov_t := 0.0
var _wheel: Array = []      # giros de la rueda hacia el cursor (se deshacen al alejar)
var stations: Array = []    # encuadres del área (WorldRoot.frames())
var _from_xf := Transform3D.IDENTITY
var _from_fov := 45.0
var _t := 1.0
var _tween: Tween = null

signal frame_changed(id: String)
signal pose_changed(kind: String)

func _init() -> void:
	name = "CameraRig"
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.near = 0.03
	cam.far = 400.0
	add_child(cam)

func _ready() -> void:
	cam.current = true

# ---- configuración (world/camera.json)
static func cfg_all() -> Dictionary:
	if _cfg_all == null:
		_cfg_all = {}
		if FileAccess.file_exists(CFG_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
			if d is Dictionary:
				_cfg_all = d
	return _cfg_all

static func cfg_for(place_id: String, area: String) -> Dictionary:
	var all := cfg_all()
	for k in [place_id + "." + area, place_id]:
		if all.has(k) and all[k] is Dictionary:
			var c: Dictionary = (all[k] as Dictionary).duplicate(true)
			var star = all.get("*", {})
			if star is Dictionary:
				for sk in star:
					if not c.has(sk) and sk != "overview": c[sk] = star[sk]
			return c
	var s = all.get("*", {})
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}

func setup(frames_meta: Dictionary, p_cfg := {}, p_fixed := false) -> void:
	frames = frames_meta.duplicate(true)
	cfg = p_cfg
	fixed = p_fixed
	stack = []
	_wheel = []
	home = ""
	var ov = cfg.get("overview", null)
	if ov is Dictionary:
		var pos := _v3(ov.get("pos", [0, 1.6, 3]))
		var look := _v3(ov.get("look", [0, 1, 0]))
		frames[GENERAL] = {"id": GENERAL, "pos": pos, "look": look, "fov": float(ov.get("fov", 60.0)), "area": "*",
			"pivot": look, "yaw": float(ov.get("yaw", DEF_YAW_MIN)), "pitch": float(ov.get("pitch", DEF_PITCH)), "custom": true}
		home = GENERAL
	if not frames.has(cur): cur = ""

static func _v3(a) -> Vector3:
	if a is Vector3: return a
	if a is Array and a.size() >= 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

func set_home(id: String) -> void:
	if home == GENERAL and frames.has(GENERAL): return
	if frames.has(id): home = id

func frame_ids() -> Array:
	var ids: Array = frames.keys()
	ids.erase(GENERAL)
	return ids

func has_frame(id: String) -> bool:
	return frames.has(id)

# Encuadre al que lleva un nodo-zona en la vista general ("" si no es zona o el encuadre no existe aquí).
func zone_of(node_id: String) -> String:
	var z = cfg.get("zones", {})
	if not (z is Dictionary): return ""
	var f := str((z as Dictionary).get(node_id, ""))
	return f if f != "" and frames.has(f) and f != home else ""

# Pose de un encuadre de diorama (lugares y láminas): la órbita corta de siempre alrededor de su pivote (W1: los
# dioramas están armados y verificados para eso; girar en el lugar mostraría sus bordes), con sus propios límites
# (láminas fijas: ≤ ±15°/±8°).
func _frame_pose(kind: String, id: String) -> Dictionary:
	var f: Dictionary = frames[id]
	var yl := absf(float(f.get("yaw", 25.0)))
	var pl := absf(float(f.get("pitch", 10.0)))
	if fixed:
		yl = minf(yl, FIXED_YAW); pl = minf(pl, FIXED_PITCH)
	# con un pivote lejano (la ventana de la consulta mira a la calle) la órbita traslada mucho la cámara y la mete en la
	# pared: el arco recorrido se acota a ORBIT_ARC m (con las bandas del borde es fácil llegar al límite sin querer)
	var piv: Vector3 = f.get("pivot", f["look"])
	var d := (f["pos"] as Vector3).distance_to(piv)
	if d > 0.01:
		var cap := rad_to_deg(ORBIT_ARC / d)
		yl = minf(yl, cap); pl = minf(pl, cap)
	return {"kind": kind, "id": id, "pos": f["pos"], "look": f["look"], "fov": float(f.get("fov", 45.0)), "yaw": yl, "pitch": pl,
		"inplace": false, "pivot": piv}

func _overview_pose() -> Dictionary:
	var f: Dictionary = frames[home]
	if bool(f.get("custom", false)):
		return {"kind": "overview", "id": home, "pos": f["pos"], "look": f["look"], "fov": float(f.get("fov", 45.0)),
			"yaw": float(f.get("yaw", DEF_YAW_MIN)), "pitch": float(f.get("pitch", DEF_PITCH)), "inplace": true}
	return _frame_pose("overview", home)

func _zone_pose(id: String) -> Dictionary:
	if frames.has(GENERAL):
		# casa: la zona es un encuadre del cuarto completo; se mira en el lugar con la mirada reducida
		var f: Dictionary = frames[id]
		return {"kind": "zone", "id": id, "pos": f["pos"], "look": f["look"], "fov": float(f.get("fov", 45.0)), "yaw": ZONE_LOOK,
			"pitch": ZONE_LOOK, "inplace": true}
	return _frame_pose("zone", id)

func inplace() -> bool:
	return not stack.is_empty() and bool(stack[-1].get("inplace", false))

# Lugares sin vista general propia (camera.json "first_frame") y sin zonas explícitas: los encuadres son estaciones.
func station_mode() -> bool:
	if frames.has(GENERAL): return false
	var z = cfg.get("zones", {})
	return not (z is Dictionary and not (z as Dictionary).is_empty())

func set_stations(ids: Array) -> void:
	stations = []
	for i in ids:
		if frames.has(str(i)) and str(i) != GENERAL: stations.append(str(i))

# Estaciones en vuelta: ordenadas por el rumbo de su mirada (creciente = girar a la izquierda). Fija por área, así que
# empujando siempre hacia el mismo lado se recorren todas.
func station_ring() -> Array:
	var arr: Array = []
	for sid in stations:
		var f: Dictionary = frames[sid]
		var d: Vector3 = (f["look"] as Vector3) - (f["pos"] as Vector3)
		arr.append([atan2(-d.x, -d.z), str(sid)])
	arr.sort_custom(func(a, b): return float(a[0]) < float(b[0]) if absf(float(a[0]) - float(b[0])) > 0.001 else str(a[1]) < str(b[1]))
	return arr.map(func(x): return x[1])

# Estación vecina hacia dir (+1 izquierda, −1 derecha) en la vuelta; "" si no hay otra.
func neighbor(dir: int) -> String:
	if stations.size() < 2 or stack.is_empty() or is_examining(): return ""
	var ring := station_ring()
	var i := ring.find(cur)
	if i < 0: i = 0
	return str(ring[(i + dir + ring.size() * 2) % ring.size()])

# Ir a una estación: la de inicio deja sólo la general; otra reemplaza la zona de arriba (la pila no crece).
func go_station(id: String) -> void:
	if not frames.has(id): return
	set_frame(id)

func set_frame(id: String, instant := false) -> void:
	if not frames.has(id): return
	var was_xf := cam.transform
	var was_fov := cam.fov
	var had := not stack.is_empty()
	if home == "" or not frames.has(home): home = id
	stack = [_overview_pose()]
	if id != home and id != GENERAL:
		stack.append(_zone_pose(id))
	cur = id if id != GENERAL else home
	_reset_offsets()
	_start_transition(was_xf, was_fov, instant or not had)
	frame_changed.emit(cur)
	pose_changed.emit(mode())

func go_overview(instant := false) -> void:
	if home != "": set_frame(home, instant)

func mode() -> String:
	return "" if stack.is_empty() else str(stack[-1]["kind"])

func depth() -> int:
	return stack.size()

func _reset_offsets() -> void:
	yaw_off = 0.0; pitch_off = 0.0; fov_off = 0.0
	yaw_t = 0.0; pitch_t = 0.0; fov_t = 0.0
	_wheel = []

func _start_transition(was_xf: Transform3D, was_fov: float, instant: bool) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	if instant or fast or not is_inside_tree():
		_t = 1.0
		_apply()
		return
	_from_xf = was_xf
	_from_fov = was_fov
	_t = 0.0
	_tween = create_tween()
	_tween.tween_method(func(v: float): _t = v; _apply(), 0.0, 1.0, TRANSITION_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func in_transition() -> bool:
	return _t < 1.0

# ---- mirar, órbita y zoom
func limits() -> Vector2:
	if stack.is_empty(): return Vector2.ZERO
	var p: Dictionary = stack[-1]
	if p["kind"] == "examine": return Vector2(EXAMINE_YAW, EXAMINE_PITCH)
	if not orbit_enabled: return Vector2.ZERO
	return Vector2(absf(float(p.get("yaw", 0.0))), absf(float(p.get("pitch", 0.0))))

func _can_look() -> bool:
	return not stack.is_empty() and (orbit_enabled or is_examining())

# inmediato (arrastre, flechas, tests)
func orbit_by(dyaw: float, dpitch: float) -> void:
	if not _can_look(): return
	var ly := limits()
	yaw_t = _clamp_yaw(yaw_t + dyaw, ly.x)
	pitch_t = clampf(pitch_t + dpitch, -ly.y, ly.y)
	yaw_off = yaw_t
	pitch_off = pitch_t
	_wrap_norm()
	_apply()

# Vista general con «yaw» ≥ 180 (la buhardilla): se da la vuelta entera, como girar la cabeza en el cuarto (playtest v2:
# la puerta a la tienda quedaba a la espalda, fuera de ±100°). Sin tope; el ángulo se normaliza a ±180 sin saltos.
func wraps() -> bool:
	if stack.is_empty() or not orbit_enabled: return false
	var p: Dictionary = stack[-1]
	return str(p.get("kind", "")) != "examine" and bool(p.get("inplace", false)) and absf(float(p.get("yaw", 0.0))) >= 180.0

func _clamp_yaw(v: float, lim: float) -> float:
	return v if wraps() else clampf(v, -lim, lim)

func _wrap_norm() -> void:
	if not wraps(): return
	while yaw_t > 180.0:
		yaw_t -= 360.0; yaw_off -= 360.0
	while yaw_t < -180.0:
		yaw_t += 360.0; yaw_off += 360.0

# suavizado (bandas del borde): dyaw + = mirar a la izquierda, dpitch + = mirar arriba (en la órbita de un diorama,
# mirar arriba es bajar la cámara alrededor del pivote)
func look_by(dyaw: float, dpitch: float) -> void:
	if not _can_look(): return
	if not inplace() and not is_examining(): dpitch = -dpitch
	var ly := limits()
	yaw_t = _clamp_yaw(yaw_t + dyaw, ly.x)
	pitch_t = clampf(pitch_t + dpitch, -ly.y, ly.y)
	_wrap_norm()
	if fast:
		yaw_off = yaw_t; pitch_off = pitch_t
		_apply()

# inmediato con el sentido de look_by (flechas)
func look_now(dyaw: float, dpitch: float) -> void:
	if not _can_look(): return
	if not inplace() and not is_examining(): dpitch = -dpitch
	orbit_by(dyaw, dpitch)

# arrastre en píxeles: en el lugar «se agarra el mundo» (arrastrar a la derecha = mirar a la izquierda); en el examen,
# la órbita de siempre
func drag_by(rel: Vector2) -> void:
	if inplace():
		orbit_by(rel.x * 0.12, rel.y * 0.1)
	else:
		orbit_by(-rel.x * 0.25, rel.y * 0.2)

func zoom_by(steps: float) -> void:
	if stack.is_empty(): return
	fov_t = clampf(fov_t + steps * FOV_STEP, -FOV_IN, FOV_OUT)
	fov_off = fov_t
	_apply()

# Rueda: steps < 0 acerca (FOV −3°) y gira el 25 % hacia el cursor (cursor_deg: ángulo del cursor respecto del centro,
# x = yaw + a la izquierda, y = pitch + arriba); steps > 0 aleja y deshace el último giro.
func wheel(steps: float, cursor_deg := Vector2.ZERO) -> void:
	if stack.is_empty(): return
	var f0 := fov_t
	fov_t = clampf(fov_t + signf(steps) * FOV_STEP, -FOV_IN, FOV_OUT)
	if absf(fov_t - f0) < 0.001:
		return
	if steps < 0.0:
		if inplace() and orbit_enabled:
			var ly := limits()
			var y0 := yaw_t; var p0 := pitch_t
			yaw_t = _clamp_yaw(yaw_t + cursor_deg.x * WHEEL_TURN, ly.x)
			pitch_t = clampf(pitch_t + cursor_deg.y * WHEEL_TURN, -ly.y, ly.y)
			_wheel.append(Vector2(yaw_t - y0, pitch_t - p0))
	elif not _wheel.is_empty():
		var d: Vector2 = _wheel.pop_back()
		var ly2 := limits()
		yaw_t = _clamp_yaw(yaw_t - d.x, ly2.x)
		pitch_t = clampf(pitch_t - d.y, -ly2.y, ly2.y)
	if fast:
		yaw_off = yaw_t; pitch_off = pitch_t; fov_off = fov_t
		_apply()

# ángulo (grados) del rayo por screen_pos respecto del centro de la cámara: x = yaw (+ izquierda), y = pitch (+ arriba)
func cursor_angles(screen_pos: Vector2) -> Vector2:
	if not cam.is_inside_tree(): return Vector2.ZERO
	var d := cam.project_ray_normal(screen_pos)
	var l := cam.global_transform.basis.inverse() * d
	var yaw := rad_to_deg(atan2(-l.x, -l.z))
	var pitch := rad_to_deg(atan2(l.y, sqrt(l.x * l.x + l.z * l.z)))
	return Vector2(yaw, pitch)

func smooth_step(dt: float) -> bool:
	var k := 1.0 - exp(-SMOOTH_K * dt)
	var changed := false
	var vals := [[yaw_off, yaw_t], [pitch_off, pitch_t], [fov_off, fov_t]]
	var outv: Array = []
	for pr in vals:
		var c: float = pr[0]; var t: float = pr[1]
		if absf(t - c) > 0.0005:
			c += (t - c) * k
			changed = true
		else:
			if c != t: changed = true
			c = t
		outv.append(c)
	yaw_off = outv[0]; pitch_off = outv[1]; fov_off = outv[2]
	if changed: _apply()
	return changed

func _process(dt: float) -> void:
	if fast:
		if yaw_off != yaw_t or pitch_off != pitch_t or fov_off != fov_t:
			yaw_off = yaw_t; pitch_off = pitch_t; fov_off = fov_t
			_apply()
		return
	smooth_step(dt)

# ---- examinar
func examine_aabb(box: AABB) -> void:
	if stack.is_empty(): return
	var was_xf := cam.transform
	var was_fov := cam.fov
	var c := box.get_center()
	var dir := (cam.global_position - c)
	if dir.length() < 0.001: dir = Vector3(0, 0.3, 1)
	dir = dir.normalized()
	var fov := base_fov() if not is_examining() else float(stack[-1]["fov"])
	var rad := maxf(box.size.length() * 0.5, 0.05)
	var dist := clampf(rad / tan(deg_to_rad(fov) * 0.5) * 1.5, 0.3, 6.0)
	var ex := {"kind": "examine", "pivot": c, "dist": dist, "dir": dir, "fov": fov}
	if is_examining(): stack[-1] = ex
	else: stack.append(ex)
	_reset_offsets()
	_start_transition(was_xf, was_fov, false)
	pose_changed.emit(mode())

# distancia a la que quedaría la cámara examinando box (para no «acercarse» alejándose: la calle desde la ventana)
func examine_distance(box: AABB) -> float:
	var fov := base_fov()
	var rad := maxf(box.size.length() * 0.5, 0.05)
	return clampf(rad / tan(deg_to_rad(fov) * 0.5) * 1.5, 0.3, 6.0)

func is_examining() -> bool:
	return mode() == "examine"

func back() -> bool:
	if stack.size() <= 1: return false
	var was_xf := cam.transform
	var was_fov := cam.fov
	stack.pop_back()
	if mode() != "examine": cur = str(stack[-1].get("id", cur))
	_reset_offsets()
	_start_transition(was_xf, was_fov, false)
	if mode() != "examine": frame_changed.emit(cur)
	pose_changed.emit(mode())
	return true

func base_fov() -> float:
	if not stack.is_empty(): return float(stack[-1].get("fov", 45.0))
	if frames.has(cur): return float(frames[cur].get("fov", 45.0))
	return 45.0

# ---- transform objetivo
func target_transform() -> Transform3D:
	if stack.is_empty(): return cam.transform
	var p: Dictionary = stack[-1]
	var piv: Vector3
	var base: Transform3D
	var inpl := bool(p.get("inplace", false))
	if p["kind"] == "examine":
		piv = p["pivot"]
		var d: Vector3 = p["dir"]
		var pos0: Vector3 = piv + d * float(p["dist"])
		base = Transform3D(Basis.IDENTITY, pos0).looking_at(piv, Vector3.UP) if absf(d.dot(Vector3.UP)) < 0.98 else Transform3D(Basis.IDENTITY, pos0).looking_at(piv, Vector3.FORWARD)
	else:
		var pos: Vector3 = p["pos"]; var look: Vector3 = p["look"]
		base = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP) if pos.distance_to(look) > 0.001 else Transform3D(Basis.IDENTITY, pos)
		piv = pos if inpl else (p.get("pivot", look) as Vector3)
	if absf(yaw_off) < 0.0001 and absf(pitch_off) < 0.0001: return base
	var right := base.basis.x.normalized()
	var r := Basis(Vector3.UP, deg_to_rad(yaw_off)) * Basis(right, deg_to_rad(pitch_off if inpl else -pitch_off))
	var t := Transform3D(r, Vector3.ZERO)
	return Transform3D(Basis.IDENTITY, piv) * t * Transform3D(Basis.IDENTITY, -piv) * base

func target_fov() -> float:
	var b := base_fov()
	return clampf(b + fov_off, b - FOV_IN, b + FOV_OUT)

func _apply() -> void:
	var tx := target_transform()
	var tf := target_fov()
	if _t >= 1.0:
		cam.transform = tx
		cam.fov = tf
		return
	var e := _t
	var q0 := _from_xf.basis.get_rotation_quaternion()
	var q1 := tx.basis.get_rotation_quaternion()
	cam.transform = Transform3D(Basis(q0.slerp(q1, e)), _from_xf.origin.lerp(tx.origin, e))
	cam.fov = lerpf(_from_fov, tf, e)
