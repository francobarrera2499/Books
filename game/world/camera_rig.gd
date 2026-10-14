# world/camera_rig.gd — v3 CÁMARA EN RIEL (GDD_v3 §6.6; reemplaza la pila de poses de GDD_v2 §E). Dueño: UI-MUNDO.
# Sin posiciones intermedias: no hay vista general → zona → examen. Un clic usa el objeto EN EL ACTO y la cámara no se
# mueve; mientras el jugador gira (bordes, arrastre, flechas) la cámara se desliza sola por un RIEL al mejor punto para
# mirar hacia donde apunta (mirando el escritorio se acerca al escritorio; mirando la pared, se para frente al plano).
# Riel por área (world/camera.json, clave "<lugar>.<área>" | "<lugar>" | "*"):
#   {"rail": [{"id", "yaw", "pos", "look", "fov", "alias": [...]}, ...], "cyclic": bool, "home": id, "pitch": lím,
#    "yaw": [min, max]}
#   «yaw» de cada punto = el valor del parámetro del riel donde se lo alcanza (+ = girar a la izquierda). Sin «rail»: los
#   encuadres del lugar (places/*.json, los del área) ordenados por rumbo; el parámetro de cada uno es su rumbo, separado
#   del vecino por max(Δrumbo, GAP_PER_M·distancia) acotado a [MIN_GAP, MAX_GAP] (dos encuadres con el mismo rumbo y
#   lejos entre sí no se pisan) y se puede seguir girando END_MARGIN° en el lugar más allá de los extremos.
# Estado: yaw_t (objetivo del parámetro) → yaw_off (suavizado x += (obj − x)·(1 − e^(−8·dt)), ≤ MAX_YAW_S). El riel da
#   posición, rumbo, cabeceo y FOV con Hermite cúbico de tangentes Catmull-Rom (no uniformes). Encima, en el lugar:
#   pitch_off (mirar arriba/abajo, ±pitch), turn_off (lo que la rueda gira hacia el cursor) y fov_off (rueda, −18°/+4°).
#   La pose dibujada sigue a la del riel con tope de velocidad (MAX_POS_S, MAX_ANG_S, MAX_FOV_S): nunca salta
#   (T32: < 3° y < 5 cm por cuadro a 60 fps).
# Soltado el giro (SETTLE_IDLE s sin entrada) a mitad de camino entre dos puntos, el objetivo se desliza al punto más
#   cercano: la cámara siempre descansa en un punto del riel (ni mirando una esquina ni adentro de una pared).
# set_frame(id) (o un alias): al punto del riel con ese id (instantáneo con instant o fast; si no, se desliza). cur = id
#   del punto más cercano (frame_changed al cambiar). Los tests y drivers pueden fijar yaw_t/yaw_off y llamar _apply().
# La entrada (mouse/teclas) la traduce WorldRoot; acá sólo hay estado y matemática (testeable headless).
extends Node3D

const SMOOTH_K := 8.0
const MAX_YAW_S := 110.0      # °/s del parámetro del riel
const MAX_POS_S := 2.9        # m/s de la cámara (≤ 4,8 cm por cuadro a 60 fps)
const MAX_ANG_S := 150.0      # °/s de rumbo y cabeceo
const MAX_FOV_S := 60.0
const DEF_PITCH := 12.0
const FOV_IN := 18.0
const FOV_OUT := 4.0
const FOV_STEP := 3.0
const WHEEL_TURN := 0.25
const TURN_LIM := 24.0
const END_MARGIN := 20.0
const MIN_GAP := 25.0
const MAX_GAP := 120.0
const GAP_PER_M := 10.0
const SETTLE_M := 6.0
const SETTLE_IDLE := 0.5
const SETTLE_DIR_T := 0.2     # playtest v3: girando hacia un lado basta pasar el 20 % del tramo para asentarse en el punto siguiente
const DRAG_YAW := 0.12        # ° por píxel de arrastre
const DRAG_PITCH := 0.1
const GENERAL := "general"
const CFG_PATH := "res://world/camera.json"

static var edge_turn := true
static var _cfg_all = null

var cam: Camera3D
var frames := {}            # id → encuadre del diorama {id, pos, look, fov, area, pivot, yaw, pitch}
var cfg := {}
var fixed := false
var rail: Array = []        # [{id, s, pos, h, p, fov, alias}] por s creciente
var cyclic := false
var period := 360.0
var s_min := 0.0
var s_max := 0.0
var pitch_lim := DEF_PITCH
var home := ""
var cur := ""
var fast := false
var orbit_enabled := true   # girar habilitado (compatibilidad; la pantalla de juego lo deja encendido)
var yaw_t := 0.0
var yaw_off := 0.0
var pitch_t := 0.0
var pitch_off := 0.0
var fov_t := 0.0
var fov_off := 0.0
var turn_t := 0.0
var turn_off := 0.0
var _wheel: Array = []      # giros de la rueda hacia el cursor (se deshacen al alejar)
var _pos := Vector3.ZERO    # pose dibujada
var _h := 0.0
var _p := 0.0
var _fov := 50.0
var _have := false
var _idle := 0.0
var _last_dir := 0.0        # signo del último giro de yaw (+ = hacia s mayor): el asentado sigue la dirección del giro
var last_dt := 0.0          # dt del último paso de suavizado (para medir saltos por cuadro sin confundirlos con tirones del motor)

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
			return (all[k] as Dictionary).duplicate(true)
	var s = all.get("*", {})
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}

static func _v3(a) -> Vector3:
	if a is Vector3: return a
	if a is Array and a.size() >= 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

static func heading_of(pos: Vector3, look: Vector3) -> float:
	var d := look - pos
	return rad_to_deg(atan2(-d.x, -d.z))

static func pitch_of(pos: Vector3, look: Vector3) -> float:
	var d := look - pos
	return rad_to_deg(atan2(d.y, sqrt(d.x * d.x + d.z * d.z)))

static func wrap180(a: float) -> float:
	return fposmod(a + 180.0, 360.0) - 180.0

# frames_meta: encuadres del diorama; p_cfg: entrada de camera.json; area_frames: ids de los encuadres del área (sin
# riel propio, el riel sale de ellos).
func setup(frames_meta: Dictionary, p_cfg := {}, p_fixed := false, area_frames: Array = []) -> void:
	frames = frames_meta.duplicate(true)
	cfg = p_cfg
	fixed = p_fixed
	rail = []
	_wheel = []
	home = ""
	cur = ""
	cyclic = bool(cfg.get("cyclic", false))
	pitch_lim = float(cfg.get("pitch", DEF_PITCH))
	var pts: Array = []
	var explicit = cfg.get("rail", null)
	if explicit is Array and not (explicit as Array).is_empty():
		for r in explicit:
			if not (r is Dictionary): continue
			var pos := _v3(r.get("pos", [0, 1.6, 0]))
			var look := _v3(r.get("look", [0, 1.6, -1]))
			pts.append({"id": str(r.get("id", "")), "s": float(r.get("yaw", heading_of(pos, look))), "pos": pos, "look": look,
				"h": heading_of(pos, look), "p": pitch_of(pos, look), "fov": float(r.get("fov", 55.0)),
				"alias": (r.get("alias", []) as Array).duplicate() if r.get("alias", []) is Array else []})
			if not frames.has(str(r.get("id", ""))):
				frames[str(r.get("id", ""))] = {"id": str(r.get("id", "")), "pos": pos, "look": look, "fov": float(r.get("fov", 55.0)),
					"area": "*", "pivot": look, "yaw": 0.0, "pitch": 0.0, "rail": true}
		pts.sort_custom(func(a, b): return float(a.s) < float(b.s))
	else:
		cyclic = false
		var ids: Array = area_frames if not area_frames.is_empty() else frames.keys()
		for fid in ids:
			if not frames.has(str(fid)): continue
			var f: Dictionary = frames[str(fid)]
			var pos2: Vector3 = f["pos"]
			var look2: Vector3 = f["look"]
			if pos2.distance_to(look2) < 0.001: continue
			pts.append({"id": str(fid), "s": 0.0, "pos": pos2, "look": look2, "h": heading_of(pos2, look2), "p": pitch_of(pos2, look2),
				"fov": float(f.get("fov", 45.0)), "alias": []})
		pts.sort_custom(func(a, b): return float(a.h) < float(b.h) if absf(float(a.h) - float(b.h)) > 0.001 else str(a.id) < str(b.id))
		for i in pts.size():
			if i == 0:
				pts[i].s = float(pts[i].h)
			else:
				var dh := float(pts[i].h) - float(pts[i - 1].h)
				var dist: float = (pts[i].pos as Vector3).distance_to(pts[i - 1].pos)
				pts[i].s = float(pts[i - 1].s) + clampf(maxf(dh, GAP_PER_M * dist), MIN_GAP, MAX_GAP)
	# rumbos desenrollados (consecutivos a menos de 180°)
	for i in range(1, pts.size()):
		pts[i].h = float(pts[i - 1].h) + wrap180(float(pts[i].h) - float(pts[i - 1].h))
	rail = pts
	if rail.is_empty():
		s_min = 0.0
		s_max = 0.0
		return
	if cyclic:
		period = 360.0
		s_min = float(rail[0].s)
		s_max = s_min + period
	else:
		var yr = cfg.get("yaw", null)
		if yr is Array and (yr as Array).size() >= 2:
			s_min = float(yr[0])
			s_max = float(yr[1])
		else:
			s_min = float(rail[0].s) - END_MARGIN
			s_max = float(rail[-1].s) + END_MARGIN
	var h0 := str(cfg.get("home", ""))
	if h0 != "" and index_of(h0) >= 0:
		home = str(rail[index_of(h0)].id)

func set_home(id: String) -> void:
	if home != "" and str(cfg.get("home", "")) != "": return
	var i := index_of(id)
	if i >= 0:
		home = str(rail[i].id)
	elif home == "" and not rail.is_empty():
		home = str(rail[0].id)

func frame_ids() -> Array:
	return rail.map(func(r): return str(r.id))

func has_frame(id: String) -> bool:
	return index_of(id) >= 0 or (id == GENERAL and not rail.is_empty())

# Punto del riel con ese id o alias (GENERAL = el de inicio); -1 si no.
func index_of(id: String) -> int:
	if id == GENERAL and home != "":
		id = home
	for i in rail.size():
		if str(rail[i].id) == id or (rail[i].alias as Array).has(id):
			return i
	return -1

func wraps() -> bool:
	return cyclic

func mode() -> String:
	return "" if rail.is_empty() else "rail"

func depth() -> int:
	return 0 if rail.is_empty() else 1

func is_examining() -> bool:
	return false

func inplace() -> bool:
	return true

func station_mode() -> bool:
	return false

func back() -> bool:
	return false

func zone_of(_node_id: String) -> String:
	return ""

func limits() -> Vector2:
	if rail.is_empty(): return Vector2.ZERO
	return Vector2((s_max - s_min) * 0.5, pitch_lim)

func base_fov() -> float:
	if rail.is_empty(): return 45.0
	return float(eval_rail(yaw_off).fov)

func target_fov() -> float:
	return _fov

# ---- ir a un punto
func set_frame(id: String, instant := false) -> void:
	if rail.is_empty(): return
	if home == "": home = str(rail[0].id)
	var i := index_of(id)
	if i < 0: return
	var s := float(rail[i].s)
	if cyclic:
		# la representación más cercana al giro actual (no dar la vuelta entera)
		s += period * round((yaw_off - s) / period)
	yaw_t = s
	pitch_t = 0.0
	turn_t = 0.0
	fov_t = 0.0
	_wheel = []
	_idle = 0.0
	_last_dir = 0.0
	if instant or fast or not _have or not is_inside_tree():
		yaw_off = yaw_t
		pitch_off = 0.0
		turn_off = 0.0
		fov_off = 0.0
		_snap_pose()
	var nid := str(rail[i].id)
	if nid != cur:
		cur = nid
		frame_changed.emit(cur)
	pose_changed.emit(mode())

func go_overview(instant := false) -> void:
	if home != "": set_frame(home, instant)
	elif not rail.is_empty(): set_frame(str(rail[0].id), instant)

func go_station(id: String) -> void:
	set_frame(id)

# ---- evaluación del riel
func _knot(i: int) -> Dictionary:
	# índice con vueltas (riel cíclico): desplaza s y el rumbo un período por vuelta
	var n := rail.size()
	if not cyclic:
		return rail[clampi(i, 0, n - 1)]
	var k := posmod(i, n)
	var laps := int(floor(float(i) / float(n)))
	var r: Dictionary = rail[k]
	var lap_h := _lap_heading()
	return {"id": r.id, "s": float(r.s) + period * laps, "pos": r.pos, "h": float(r.h) + lap_h * laps, "p": r.p, "fov": r.fov}

func _lap_heading() -> float:
	# rumbo que suma una vuelta del riel cíclico (≈ ±360; si los datos no cierran, 360)
	var n := rail.size()
	var last := float(rail[n - 1].h)
	var close := last + wrap180(float(rail[0].h) - last)
	var d := close - float(rail[0].h)
	return d if absf(absf(d) - 360.0) < 1.0 else 360.0

func _tangent(i: int, key: String):
	var n := rail.size()
	var a: Dictionary
	var b: Dictionary
	if cyclic:
		a = _knot(i - 1); b = _knot(i + 1)
	else:
		a = rail[maxi(i - 1, 0)]; b = rail[mini(i + 1, n - 1)]
	var ds := float(b.s) - float(a.s)
	if ds <= 0.0001:
		return Vector3.ZERO if key == "pos" else 0.0
	if key == "pos":
		return ((b.pos as Vector3) - (a.pos as Vector3)) / ds
	return (float(b[key]) - float(a[key])) / ds

static func _herm(p0, p1, m0, m1, t: float, ds: float):
	var t2 := t * t
	var t3 := t2 * t
	var h00 := 2.0 * t3 - 3.0 * t2 + 1.0
	var h10 := t3 - 2.0 * t2 + t
	var h01 := -2.0 * t3 + 3.0 * t2
	var h11 := t3 - t2
	return p0 * h00 + m0 * (h10 * ds) + p1 * h01 + m1 * (h11 * ds)

# {pos, h, p, fov, i} del riel en el parámetro s (sin lo que agrega el jugador en el lugar).
func eval_rail(s: float) -> Dictionary:
	if rail.is_empty():
		return {"pos": Vector3(0, 1.6, 3), "h": 0.0, "p": 0.0, "fov": 50.0, "i": -1}
	var n := rail.size()
	if n == 1:
		var r: Dictionary = rail[0]
		return {"pos": r.pos, "h": float(r.h) + (s - float(r.s)), "p": r.p, "fov": r.fov, "i": 0}
	if not cyclic:
		if s <= float(rail[0].s):
			var r0: Dictionary = rail[0]
			return {"pos": r0.pos, "h": float(r0.h) + (s - float(r0.s)), "p": r0.p, "fov": r0.fov, "i": 0}
		if s >= float(rail[n - 1].s):
			var r1: Dictionary = rail[n - 1]
			return {"pos": r1.pos, "h": float(r1.h) + (s - float(r1.s)), "p": r1.p, "fov": r1.fov, "i": n - 1}
	var laps := 0
	var ss := s
	if cyclic:
		laps = int(floor((s - s_min) / period))
		ss = s - period * laps
	var i := 0
	while i < n - 1 and ss >= float(rail[i + 1].s):
		i += 1
	var a: Dictionary = _knot(i) if cyclic else rail[i]
	var b: Dictionary = _knot(i + 1) if cyclic else rail[i + 1]
	var ds := float(b.s) - float(a.s)
	var t := 0.0 if ds <= 0.0001 else clampf((ss - float(a.s)) / ds, 0.0, 1.0)
	var pos: Vector3 = _herm(a.pos, b.pos, _tangent(i, "pos"), _tangent(i + 1, "pos"), t, ds)
	var h: float = _herm(float(a.h), float(b.h), _tangent(i, "h"), _tangent(i + 1, "h"), t, ds)
	var p: float = _herm(float(a.p), float(b.p), _tangent(i, "p"), _tangent(i + 1, "p"), t, ds)
	var fv: float = _herm(float(a.fov), float(b.fov), _tangent(i, "fov"), _tangent(i + 1, "fov"), t, ds)
	if cyclic:
		h += _lap_heading() * laps
	return {"pos": pos, "h": h, "p": p, "fov": fv, "i": i, "t": t, "ds": ds}

# Pose objetivo completa (riel + lo del jugador en el lugar).
func target_pose() -> Dictionary:
	var e := eval_rail(yaw_off)
	var b := float(e.fov)
	return {"pos": e.pos, "h": float(e.h) + turn_off, "p": clampf(float(e.p) + pitch_off, -85.0, 85.0),
		"fov": clampf(b + fov_off, b - FOV_IN, b + FOV_OUT)}

func _snap_pose() -> void:
	var tp := target_pose()
	_pos = tp.pos
	_h = float(tp.h)
	_p = float(tp.p)
	_fov = float(tp.fov)
	_have = true
	_apply_pose()

static func basis_for(h: float, p: float) -> Basis:
	var hr := deg_to_rad(h)
	var pr := deg_to_rad(p)
	var fwd := Vector3(-sin(hr) * cos(pr), sin(pr), -cos(hr) * cos(pr))
	return Transform3D(Basis.IDENTITY, Vector3.ZERO).looking_at(fwd, Vector3.UP).basis

func _apply_pose() -> void:
	cam.transform = Transform3D(basis_for(_h, _p), _pos)
	cam.fov = _fov

# Compatibilidad (tests, drivers): aplicar el estado actual sin suavizado.
func _apply() -> void:
	_clamp_targets()
	if fast or not is_inside_tree():
		yaw_off = yaw_t; pitch_off = pitch_t; fov_off = fov_t; turn_off = turn_t
	_snap_pose()
	_update_cur()

func target_transform() -> Transform3D:
	var tp := target_pose()
	return Transform3D(basis_for(float(tp.h), float(tp.p)), tp.pos)

func in_transition() -> bool:
	if rail.is_empty(): return false
	var tp := target_pose()
	return absf(yaw_t - yaw_off) > 0.5 or _pos.distance_to(tp.pos) > 0.02 or absf(_h - float(tp.h)) > 0.5

# ---- mirar y zoom
func _clamp_targets() -> void:
	if not cyclic:
		yaw_t = clampf(yaw_t, s_min, s_max)
	pitch_t = clampf(pitch_t, -pitch_lim, pitch_lim)
	turn_t = clampf(turn_t, -TURN_LIM, TURN_LIM)
	fov_t = clampf(fov_t, -FOV_IN, FOV_OUT)

func _norm_laps() -> void:
	if not cyclic: return
	# la pose dibujada da la misma vuelta (su rumbo, desenrollado, no puede saltar 360°)
	var lh := _lap_heading()
	while yaw_off >= s_max and yaw_t >= s_max:
		yaw_off -= period; yaw_t -= period; _h -= lh
	while yaw_off < s_min and yaw_t < s_min:
		yaw_off += period; yaw_t += period; _h += lh

func _can_look() -> bool:
	return not rail.is_empty() and orbit_enabled

# suavizado (bandas del borde, flechas, arrastre): dyaw + = mirar a la izquierda, dpitch + = mirar arriba
func look_by(dyaw: float, dpitch: float) -> void:
	if not _can_look(): return
	yaw_t += dyaw
	pitch_t += dpitch
	if absf(dyaw) > 0.0001: _last_dir = signf(dyaw)
	_clamp_targets()
	_idle = 0.0
	if fast:
		_apply()

# inmediato (tests, drivers)
func look_now(dyaw: float, dpitch: float) -> void:
	if not _can_look(): return
	yaw_t += dyaw
	pitch_t += dpitch
	_clamp_targets()
	yaw_off = yaw_t; pitch_off = pitch_t
	_idle = 0.0
	_snap_pose()
	_update_cur()

func orbit_by(dyaw: float, dpitch: float) -> void:
	look_now(dyaw, dpitch)

# arrastre en píxeles: «se agarra el mundo» (arrastrar a la derecha = mirar a la izquierda)
func drag_by(rel: Vector2) -> void:
	look_by(rel.x * DRAG_YAW, rel.y * DRAG_PITCH)

func zoom_by(steps: float) -> void:
	if rail.is_empty(): return
	fov_t = clampf(fov_t + steps * FOV_STEP, -FOV_IN, FOV_OUT)
	if fast:
		_apply()

# Rueda: steps < 0 acerca (FOV −3°) y gira el 25 % hacia el cursor en el lugar (sin moverse por el riel); steps > 0
# aleja y deshace el último giro.
func wheel(steps: float, cursor_deg := Vector2.ZERO) -> void:
	if rail.is_empty(): return
	var f0 := fov_t
	fov_t = clampf(fov_t + signf(steps) * FOV_STEP, -FOV_IN, FOV_OUT)
	if absf(fov_t - f0) < 0.001:
		return
	if steps < 0.0:
		var t0 := turn_t; var p0 := pitch_t
		turn_t = clampf(turn_t + cursor_deg.x * WHEEL_TURN, -TURN_LIM, TURN_LIM)
		pitch_t = clampf(pitch_t + cursor_deg.y * WHEEL_TURN, -pitch_lim, pitch_lim)
		_wheel.append(Vector2(turn_t - t0, pitch_t - p0))
	elif not _wheel.is_empty():
		var d: Vector2 = _wheel.pop_back()
		turn_t = clampf(turn_t - d.x, -TURN_LIM, TURN_LIM)
		pitch_t = clampf(pitch_t - d.y, -pitch_lim, pitch_lim)
	_idle = 0.0
	if fast:
		_apply()

# ángulo (grados) del rayo por screen_pos respecto del centro de la cámara: x = yaw (+ izquierda), y = pitch (+ arriba)
func cursor_angles(screen_pos: Vector2) -> Vector2:
	if not cam.is_inside_tree(): return Vector2.ZERO
	var d := cam.project_ray_normal(screen_pos)
	var l := cam.global_transform.basis.inverse() * d
	var yaw := rad_to_deg(atan2(-l.x, -l.z))
	var pitch := rad_to_deg(atan2(l.y, sqrt(l.x * l.x + l.z * l.z)))
	return Vector2(yaw, pitch)

static func _exp_step(c: float, t: float, k: float, max_d: float) -> float:
	if absf(t - c) <= 0.0005:
		return t
	var d := (t - c) * k
	return c + clampf(d, -max_d, max_d)

# Un paso de suavizado (dt en s). true si algo cambió.
func smooth_step(dt: float) -> bool:
	last_dt = dt
	if rail.is_empty(): return false
	_clamp_targets()
	_settle_step(dt)
	var k := 1.0 - exp(-SMOOTH_K * dt)
	var y0 := yaw_off; var p0 := pitch_off; var f0 := fov_off; var t0 := turn_off
	yaw_off = _exp_step(yaw_off, yaw_t, k, MAX_YAW_S * dt)
	pitch_off = _exp_step(pitch_off, pitch_t, k, MAX_ANG_S * dt)
	fov_off = _exp_step(fov_off, fov_t, k, MAX_FOV_S * dt)
	turn_off = _exp_step(turn_off, turn_t, k, MAX_ANG_S * dt)
	_norm_laps()
	var changed := y0 != yaw_off or p0 != pitch_off or f0 != fov_off or t0 != turn_off
	if not _have:
		_snap_pose()
		return true
	var tp := target_pose()
	var tpos: Vector3 = tp.pos
	var dp := tpos - _pos
	var mx := MAX_POS_S * dt
	if dp.length() > mx:
		_pos += dp.normalized() * mx
		changed = true
	elif dp.length() > 0.00001:
		_pos = tpos
		changed = true
	var nh: float = clampf(float(tp.h) - _h, -MAX_ANG_S * dt, MAX_ANG_S * dt)
	var np: float = clampf(float(tp.p) - _p, -MAX_ANG_S * dt, MAX_ANG_S * dt)
	var nf: float = clampf(float(tp.fov) - _fov, -MAX_FOV_S * dt, MAX_FOV_S * dt)
	if absf(nh) > 0.00001 or absf(np) > 0.00001 or absf(nf) > 0.00001:
		_h += nh; _p += np; _fov += nf
		changed = true
	if changed:
		_apply_pose()
		_update_cur()
	return changed

# Soltado el giro a mitad de camino entre dos puntos, el objetivo se desliza al punto más cercano (GDD_v3 §6.6: «la
# cámara se desliza sola al mejor punto»): la cámara nunca queda parada mirando una esquina ni adentro de una pared. Más
# allá de los extremos de un riel no cíclico se mira libre (sin asentar).
func _settle_step(dt: float) -> void:
	_idle += dt
	if _idle < SETTLE_IDLE or rail.size() < 2: return
	if not cyclic and (yaw_t <= float(rail[0].s) or yaw_t >= float(rail[-1].s)): return
	var e := eval_rail(yaw_t)
	if not e.has("ds"): return
	var i := int(e.i)
	var a: Dictionary = _knot(i) if cyclic else rail[i]
	var b: Dictionary = _knot(i + 1) if cyclic else rail[mini(i + 1, rail.size() - 1)]
	var t := float(e.get("t", 0.0))
	if t <= 0.005 or t >= 0.995: return
	var laps: float = floor((yaw_t - s_min) / period) if cyclic else 0.0
	# hacia donde se venía girando alcanza con pasar el 20 % del tramo (un empujón corto por el borde no vuelve atrás)
	var thr := 0.5
	if _last_dir > 0.0: thr = SETTLE_DIR_T
	elif _last_dir < 0.0: thr = 1.0 - SETTLE_DIR_T
	yaw_t = (float(a.s) if t < thr else float(b.s)) + period * laps

# Mientras se aprieta el botón (arrastre en curso) no se asienta.
func hold() -> void:
	_idle = 0.0

func _update_cur() -> void:
	if rail.is_empty(): return
	var best := ""
	var bd := INF
	for r in rail:
		var d := absf(yaw_off - float(r.s))
		if cyclic:
			d = absf(wrap180(yaw_off - float(r.s)))
		if d < bd:
			bd = d; best = str(r.id)
	if best != cur:
		cur = best
		frame_changed.emit(cur)

func _process(dt: float) -> void:
	if rail.is_empty(): return
	if fast:
		if yaw_off != yaw_t or pitch_off != pitch_t or fov_off != fov_t or turn_off != turn_t or not _have:
			_apply()
		return
	smooth_step(dt)

# ---- compatibilidad v2 (sin efecto: no hay acercamiento)
func examine_aabb(_box: AABB) -> void:
	pass

func examine_distance(_box: AABB) -> float:
	return INF
