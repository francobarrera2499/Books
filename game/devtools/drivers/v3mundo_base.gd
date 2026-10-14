# devtools/drivers/v3mundo_base.gd — base de los drivers de UI-MUNDO (GDD_v3 §7.2 P4): el juego REAL sin --fast, con
# eventos reales de mouse y teclado (Input.warp_mouse + Input.parse_input_event, como devtools/drivers/title_smoke.gd),
# hasta el escritorio del día 1 (el bot deductor juega el prólogo por el sim). Capturas en .work/shots/<prefijo>_<n>.png.
# No es un driver (no tiene drive): lo extienden v3mundo_general/hover/plano/crane.
# Salida: «V3M OK|FALLA <qué>» y «V3M RESUMEN n fallas».
extends RefCounted

const Bot = preload("res://devtools/bots/bot_deductor.gd")
const AFF = preload("res://world/affordance/affordance.gd")

var tool
var shell
var g
var vp: Viewport
var fails := 0
var _last := Vector2.ZERO

func gs():
	return shell.game_screen if shell != null else null

func _check(c: bool, what: String) -> void:
	print("V3M %s %s" % ["OK" if c else "FALLA", what])
	if not c:
		fails += 1

func _summary() -> void:
	print("V3M RESUMEN %d fallas" % fails)

func _snap(name: String) -> void:
	await tool.frames(2)
	await tool.snap(name)

func _wait(s: float) -> void:
	await tool.create_timer(s).timeout
	await tool.process_frame

func _settle(max_frames := 2400) -> void:
	for i in max_frames:
		await tool.process_frame
		if i < 3: continue
		var gsc = gs()
		if not shell.is_busy() and (gsc == null or gsc.idle()): return

func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	var last := DisplayServer.window_get_position()
	var still := 0
	for _i in 120:
		await tool.frames(1)
		var p := DisplayServer.window_get_position()
		still = still + 1 if p == last else 0
		last = p
		if still >= 10 and DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _win(p: Vector2) -> Vector2:
	var vs: Vector2 = tool.root.get_visible_rect().size
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
		await tool.frames(1)
		if tool.root.get_mouse_position().distance_to(p) < 1.5: return

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
	await tool.frames(1)
	_btn(p, idx, false)
	await tool.frames(4)

func _click_ctrl(c) -> void:
	if not (c is Control) or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
		_check(false, "control para el clic")
		return
	await _click((c as Control).get_global_rect().get_center())

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await tool.frames(2)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await tool.frames(2)

func _focus() -> void:
	for _i in 60:
		if DisplayServer.window_is_focused(): return
		DisplayServer.window_move_to_foreground()
		await tool.frames(3)

# Punto de la pantalla, fuera de las bandas del borde y de la interfaz (la columna del HUD), donde el clic da con el nodo
# (rejilla de 16 px; primero los del centro).
func _safe_point(id: String) -> Vector2:
	var w = shell.world
	var hud_r := Rect2()
	if gs() != null and gs().hud != null and gs().hud.visible:
		hud_r = (gs().hud.cover_rect() as Rect2).grow(12.0)
	var pts: Array = []
	for y in range(110, 790, 16):
		for x in range(150, 1450, 16):
			var p := Vector2(x, y)
			if hud_r.size.x > 0.0 and hud_r.has_point(p): continue
			if String(w.pick(p).get("id", "")) == id:
				pts.append(p)
	if pts.is_empty():
		return Vector2(-1, -1)
	var c := Vector2.ZERO
	for p in pts: c += p
	c /= float(pts.size())
	pts.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return pts[0]

func _cursor_name() -> String:
	match DisplayServer.cursor_get_shape():
		DisplayServer.CURSOR_ARROW: return "flecha"
		DisplayServer.CURSOR_HELP: return "lupa"
		DisplayServer.CURSOR_POINTING_HAND: return "mano"
		DisplayServer.CURSOR_IBEAM: return "texto"
	return str(DisplayServer.cursor_get_shape())

# Partida nueva hasta el escritorio del día 1 (bandeja cerrada). false si no se pudo.
func _boot_day1(scene, save := "user://saves/v3mundo.jsonl") -> bool:
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		_check(false, "Shell")
		return false
	g.save_path = save
	for suf in ["", ".bak", ".tmp", ".fin"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	await shell.new_game(1894)
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
		if shell.top() == null: break
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _settle()
	var c2: Dictionary = g.sim.q_clock()
	_check(int(c2.day) == 1 and String(c2.phase) == "desk", "día 1 en el escritorio (%s)" % str([c2.day, c2.phase]))
	return int(c2.day) == 1 and String(c2.phase) == "desk"
