# world/camera_rig.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.5.
# Encuadres fijos con transición 0,5 s (ease in-out). Órbita corta alrededor de orbit.pivot (yaw ±orbit.yaw, pitch ±orbit.pitch;
# por defecto 25°/10°); FOV ±10° con la rueda. Examinar: encuadra un AABB y orbita alrededor de él; back() regresa.
# La entrada (mouse/teclas) la traduce WorldRoot; acá sólo hay estado y matemática (testeable headless).
extends Node3D

const TRANSITION_S := 0.5
const EXAMINE_YAW := 40.0
const EXAMINE_PITCH := 22.0

var cam: Camera3D
var frames := {}            # id → {id, pos, look, fov, area, pivot, yaw, pitch}
var cur := ""
var orbit_enabled := true
var fast := false           # sin transiciones (--fast, tests)
var yaw_off := 0.0
var pitch_off := 0.0
var fov_off := 0.0
var _ex := {}               # examen activo: {pivot, dist, dir, fov, yaw, pitch}
var _from_xf := Transform3D.IDENTITY
var _from_fov := 45.0
var _t := 1.0
var _tween: Tween = null
var _hold_xf := Transform3D.IDENTITY
var _hold_fov := 45.0

signal frame_changed(id: String)

func _init() -> void:
	name = "CameraRig"
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.near = 0.03
	cam.far = 400.0
	add_child(cam)

func _ready() -> void:
	cam.current = true

func setup(frames_meta: Dictionary) -> void:
	frames = frames_meta.duplicate(true)
	_ex = {}
	if not frames.has(cur): cur = ""

func frame_ids() -> Array:
	var ids: Array = frames.keys()
	return ids

func has_frame(id: String) -> bool:
	return frames.has(id)

func set_frame(id: String, instant := false) -> void:
	if not frames.has(id): return
	var was_xf := cam.transform
	var was_fov := cam.fov
	var had := cur != ""
	cur = id
	yaw_off = 0.0; pitch_off = 0.0; fov_off = 0.0
	_ex = {}
	_start_transition(was_xf, was_fov, instant or not had)
	frame_changed.emit(id)

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

# ---- órbita y zoom
func orbit_by(dyaw: float, dpitch: float) -> void:
	if not orbit_enabled and _ex.is_empty(): return
	var ly := limits()
	yaw_off = clampf(yaw_off + dyaw, -ly.x, ly.x)
	pitch_off = clampf(pitch_off + dpitch, -ly.y, ly.y)
	_apply()

func zoom_by(steps: float) -> void:
	fov_off = clampf(fov_off + steps * 2.0, -10.0, 10.0)
	_apply()

func limits() -> Vector2:
	if not _ex.is_empty(): return Vector2(EXAMINE_YAW, EXAMINE_PITCH)
	if not frames.has(cur): return Vector2.ZERO
	var f: Dictionary = frames[cur]
	return Vector2(absf(float(f.get("yaw", 25.0))), absf(float(f.get("pitch", 10.0))))

# ---- examinar
func examine_aabb(box: AABB) -> void:
	var was_xf := cam.transform
	var was_fov := cam.fov
	var c := box.get_center()
	var dir := (cam.global_position - c)
	if dir.length() < 0.001: dir = Vector3(0, 0.3, 1)
	dir = dir.normalized()
	var fov := base_fov()
	var rad := maxf(box.size.length() * 0.5, 0.05)
	var dist := clampf(rad / tan(deg_to_rad(fov) * 0.5) * 1.5, 0.3, 6.0)
	_ex = {"pivot": c, "dist": dist, "dir": dir, "fov": fov}
	yaw_off = 0.0; pitch_off = 0.0
	_start_transition(was_xf, was_fov, false)

func is_examining() -> bool:
	return not _ex.is_empty()

func back() -> bool:
	if _ex.is_empty(): return false
	var was_xf := cam.transform
	var was_fov := cam.fov
	_ex = {}
	yaw_off = 0.0; pitch_off = 0.0
	_start_transition(was_xf, was_fov, false)
	return true

func base_fov() -> float:
	if frames.has(cur): return float(frames[cur].get("fov", 45.0))
	return 45.0

# ---- transform objetivo
func target_transform() -> Transform3D:
	var piv: Vector3
	var base: Transform3D
	if not _ex.is_empty():
		piv = _ex["pivot"]
		var p: Vector3 = piv + (_ex["dir"] as Vector3) * float(_ex["dist"])
		base = Transform3D(Basis.IDENTITY, p).looking_at(piv, Vector3.UP) if absf((_ex["dir"] as Vector3).dot(Vector3.UP)) < 0.98 else Transform3D(Basis.IDENTITY, p).looking_at(piv, Vector3.FORWARD)
	elif frames.has(cur):
		var f: Dictionary = frames[cur]
		var pos: Vector3 = f["pos"]; var look: Vector3 = f["look"]
		base = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP) if pos.distance_to(look) > 0.001 else Transform3D(Basis.IDENTITY, pos)
		piv = f.get("pivot", look)
	else:
		return cam.transform
	if absf(yaw_off) < 0.0001 and absf(pitch_off) < 0.0001: return base
	var right := base.basis.x.normalized()
	var r := Basis(Vector3.UP, deg_to_rad(yaw_off)) * Basis(right, deg_to_rad(-pitch_off))
	var t := Transform3D(r, Vector3.ZERO)
	return Transform3D(Basis.IDENTITY, piv) * t * Transform3D(Basis.IDENTITY, -piv) * base

func target_fov() -> float:
	return clampf(base_fov() + fov_off, base_fov() - 10.0, base_fov() + 10.0)

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
