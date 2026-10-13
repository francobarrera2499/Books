# tests/fixtures/v2cam/window_base.gd — base de los tests con ventana de CÁMARA + AFORDANCIAS (T32, T34): el juego real
# SIN --fast hasta el escritorio del día 1 (el bot deductor juega el prólogo por el sim) y el mouse real (Input.warp_mouse
# + Input.parse_input_event, como devtools/drivers/title_smoke.gd). No es un test (no empieza con test_).
extends "res://tests/test_base.gd"

const Shell = preload("res://ui/shell.gd")
const Bot = preload("res://devtools/bots/bot_deductor.gd")

var sh = null
var g = null
var _last := Vector2.ZERO

func after_each() -> void:
	if g != null and g.sim != null:
		g.end_session()
	if sh != null and is_instance_valid(sh):
		sh.free()
	sh = null
	if g != null:
		g.save_path = g.SAVE_PATH

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func _wait(s: float) -> void:
	await tree.create_timer(s).timeout
	await tree.process_frame

func _settle(max_frames := 2400) -> void:
	for i in max_frames:
		await tree.process_frame
		if i < 3: continue
		var gs = sh.game_screen
		if not sh.is_busy() and (gs == null or gs.idle()): return

func _focus() -> void:
	for _i in 60:
		if DisplayServer.window_is_focused(): return
		DisplayServer.window_move_to_foreground()
		await _frames(3)

# p en coordenadas del viewport (1600×900); la ventana del sistema puede tener otro tamaño (pantallas chicas, escala
# del escritorio): warp_mouse y los eventos van en píxeles de la ventana.
func _win(p: Vector2) -> Vector2:
	var vs: Vector2 = tree.root.get_visible_rect().size
	var ws := Vector2(DisplayServer.window_get_size())
	if vs.x <= 0.0 or vs.y <= 0.0 or ws.x <= 0.0: return p
	var sc := minf(ws.x / vs.x, ws.y / vs.y)
	var off := (ws - vs * sc) * 0.5
	return p * sc + off

func _mm(p: Vector2) -> void:
	var wp := _win(p)
	Input.warp_mouse(wp)
	var ev := InputEventMouseMotion.new()
	ev.position = wp
	ev.global_position = wp
	ev.relative = p - _last
	_last = p
	Input.parse_input_event(ev)

func _move(p: Vector2) -> void:
	for _i in 20:
		_mm(p)
		await _frames(1)
		if tree.root.get_mouse_position().distance_to(p) < 1.5: return

func _btn(p: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = idx
	e.pressed = pressed
	var wp := _win(p)
	e.position = wp
	e.global_position = wp
	if idx == MOUSE_BUTTON_LEFT and pressed: e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	await _move(p)
	_btn(p, idx, true)
	await _frames(1)
	_btn(p, idx, false)
	await _frames(4)

func _node_pos(id: String) -> Vector2:
	var w = sh.world
	var b: Node3D = w.node_body(id)
	var cam: Camera3D = w.camera()
	if b == null or cam.is_position_behind(b.global_position): return Vector2(-1, -1)
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 160, 6):
		for k in 16:
			var p := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if String(w.pick(p).get("id", "")) == id: return p
			if r == 0: break
	return c

func _boot_day1() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("requiere ventana")
		return false
	tree.root.size = Vector2i(1600, 900)
	print("[v2cam] ventana ", DisplayServer.window_get_size(), " viewport ", tree.root.get_visible_rect().size, " final ", tree.root.get_final_transform())
	g = tree.root.get_node("Game")
	sh = Shell.new()
	tree.root.add_child(sh)
	await _frames(1)
	await sh.boot({"new": true, "seed": 1894, "fast": false, "mute": true, "save": tmp_dir().path_join("t32w.jsonl")})
	await _settle()
	var bot = Bot.new()
	bot.setup(g.sim, 1)
	for _i in 600:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= 1 and String(c.phase) == "desk": break
		if not bot.step(): break
	await _settle()
	await _focus()
	for _k in 4:
		if sh.top() == null: break
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _settle()
	var c2: Dictionary = g.sim.q_clock()
	eq([int(c2.day), String(c2.phase)], [1, "desk"], "día 1 en el escritorio")
	return true

