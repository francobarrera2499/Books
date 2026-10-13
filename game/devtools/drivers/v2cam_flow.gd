# devtools/drivers/v2cam_flow.gd — CÁMARA + AFORDANCIAS v2 (GDD_v2 §D, §E, §F.3) con ventana y SIN --fast: el juego real,
# sólo eventos reales de mouse/teclado (warp_mouse + Input.parse_input_event, utilidades de w3int_flow.gd).
#   título -> prólogo (vista de la lámina, realce) -> el bot deductor (sim) hasta el día 1 en el escritorio ->
#   vista general (captura v2cam_general) -> mouse sobre la silla (contorno, «silla», lupa: v2cam_hover_silla) ->
#   clic en el escritorio (zona) -> mouse sobre el cuaderno («Cuaderno · abrir», mano) -> clic derecho (general) ->
#   Espacio (mirar alrededor: v2cam_mirar) -> borde izquierdo 1 s (gira ≥ 20°) -> rueda (FOV baja, mira al cursor) ->
#   no existe ningún ChevronIzq/ChevronDer.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2cam res://devtools/drivers/v2cam_flow.gd --mute
# Salida: «V2CAM OK|FALLA …» y «V2CAM RESUMEN». Capturas: .work/shots/v2cam_NN_<paso>.png
extends "res://devtools/drivers/w3int_flow.gd"

const Bot = preload("res://devtools/bots/bot_deductor.gd")

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("V2CAM sin Shell")
		return
	g.save_path = "user://saves/v2cam.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	shell.show_title()
	await tool.frames(30)
	await _title()
	if g.sim == null:
		_summary()
		return
	await _idle()
	await tool.frames(20)
	await _snap("prologo")
	_check(shell.find_children("ChevronIzq", "", true, false).is_empty() and shell.find_children("ChevronDer", "", true, false).is_empty(), "sin chevrones (prólogo)")
	await _to_day1_desk()
	await _general()
	await _read_pending()
	await _hover_chair()
	await _zone_and_notebook()
	await _look_around()
	await _edge_turn()
	await _wheel()
	await _visit_station()
	_check(shell.find_children("ChevronIzq", "", true, false).is_empty() and shell.find_children("ChevronDer", "", true, false).is_empty(), "sin chevrones (día 1)")
	_summary()
	g.end_session()

# La ventana necesita el foco del sistema (warp_mouse y las bandas del borde lo exigen); en corridas automáticas a veces
# lo pierde: se la trae al frente antes de cada paso con el mouse.
func _focus() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 60:
		if DisplayServer.window_is_focused():
			return
		DisplayServer.window_move_to_foreground()
		DisplayServer.window_request_attention()
		await tool.frames(3)
	print("V2CAM aviso: la ventana no recupera el foco")

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("V2CAM %s %s" % ["OK" if c else "FALLA", what])

func _summary() -> void:
	print("V2CAM RESUMEN %d fallas, %d capturas" % [fails, _shot])

func _snap(name: String) -> void:
	_shot += 1
	await tool.snap("%02d_%s" % [_shot, name])

# El bot deductor juega el prólogo por el sim (no es lo que se prueba acá) hasta el escritorio del día 1.
func _to_day1_desk() -> void:
	var bot = Bot.new()
	bot.setup(g.sim, 1)
	for _i in 400:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= 1 and String(c.phase) == "desk":
			break
		if not bot.step():
			break
	await _idle(2500)
	await tool.frames(30)
	# la bandeja del amanecer se cierra con el clic derecho (volver)
	for _k in 4:
		if shell.top() == null:
			break
		await _rclick(Vector2(800, 450))
		await _idle()
	var c2: Dictionary = g.sim.q_clock()
	_check(int(c2.day) >= 1 and String(c2.phase) == "desk", "día 1 en el escritorio (día %d, %s)" % [int(c2.day), String(c2.phase)])

func _general() -> void:
	var w = shell.world
	if w.rig.mode() != "overview":
		await _rclick(Vector2(800, 450))
		await _wait(0.6)
	_check(w.rig.mode() == "overview" and w.rig.cur == "general", "vista general de la buhardilla (modo %s, %s)" % [w.rig.mode(), w.rig.cur])
	_mm(Vector2(800, 450))
	await _wait(0.3)
	await _snap("general")

# Leer la tira «Pendientes» (arriba a la izquierda, dentro de la banda del borde) no gira la vista ni realza el 3D.
func _read_pending() -> void:
	var w = shell.world
	var box: Control = gs().hud.guide_box
	if box == null or not box.is_visible_in_tree():
		print("V2CAM (sin Pendientes a la vista)")
		return
	await _focus()
	var y0: float = w.rig.yaw_off
	var at := Vector2(box.get_global_rect().position.x + 30.0, box.get_global_rect().get_center().y)
	await _sync_mouse(at)
	await _wait(1.0)
	_check(absf(w.rig.yaw_off - y0) < 0.5 and w.hover_id == "", "leer Pendientes no gira la vista ni realza el 3D (yaw %.1f -> %.1f)" % [y0, w.rig.yaw_off])
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.3)

func _hover_chair() -> void:
	await _focus()
	var p := _node_pos("silla")
	_check(p.x >= 0.0, "la silla está a la vista")
	await _sync_mouse(p)
	await _wait(0.4)
	var w = shell.world
	var lbl: String = gs().hover_label.label_text()
	print("V2CAM silla: hover=%s/%s etiqueta=«%s» cursor=%d" % [w.hover_kind, w.hover_id, lbl, Input.get_current_cursor_shape()])
	_check(w.hover_id == "silla", "pick bajo el mouse: silla")
	_check(lbl == "silla", "etiqueta «silla»")
	_check(Input.get_current_cursor_shape() == Input.CURSOR_HELP, "cursor de lupa sobre la silla")
	await _snap("hover_silla")

func _zone_and_notebook() -> void:
	await _focus()
	var w = shell.world
	var p := _node_pos("escritorio")
	await _click(p)
	await _wait(0.7)
	_check(w.rig.mode() == "zone" and w.rig.cur == "escritorio", "clic en el escritorio -> zona escritorio (%s %s)" % [w.rig.mode(), w.rig.cur])
	await _snap("zona_escritorio")
	await _focus()
	var q := _node_pos("cuaderno")
	await _sync_mouse(q)
	await _wait(0.4)
	var lbl: String = gs().hover_label.label_text()
	var usable: bool = w.is_usable("node", "cuaderno")
	print("V2CAM cuaderno: hover=%s etiqueta=«%s» usable=%s cursor=%d" % [w.hover_id, lbl, usable, Input.get_current_cursor_shape()])
	if usable:
		_check(lbl.begins_with("Cuaderno · "), "etiqueta «Cuaderno · abrir»")
		_check(Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND, "mano sobre el cuaderno")
	else:
		_check(Input.get_current_cursor_shape() == Input.CURSOR_HELP, "cuaderno sin bandera: lupa")
	await _snap("hover_cuaderno")
	await _rclick(Vector2(800, 450))
	await _wait(0.7)
	_check(w.rig.mode() == "overview", "clic derecho -> vista general (%s)" % w.rig.mode())

func _look_around() -> void:
	await _focus()
	_mm(Vector2(800, 420))
	await _wait(0.2)
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.4)
	var n: int = gs().hover_label.many_count()
	print("V2CAM mirar alrededor: %d etiquetas: %s" % [n, str(gs().hover_label.many_texts())])
	_check(gs().looking_around() and n >= 5, "Espacio: todas las etiquetas del encuadre (%d)" % n)
	await _snap("mirar")
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.3)
	_check(not gs().looking_around() and gs().hover_label.many_count() == 0, "al soltar Espacio se van")

func _edge_turn() -> void:
	await _focus()
	var w = shell.world
	var f0: Vector3 = -w.camera().global_transform.basis.z
	await _sync_mouse(Vector2(12, 470))
	print("V2CAM borde: ", w.edge_debug())
	await _wait(1.0)
	var f1: Vector3 = -w.camera().global_transform.basis.z
	var ang := rad_to_deg(atan2(f0.cross(f1).y, f0.dot(f1)))
	print("V2CAM borde izquierdo 1 s: giro %.1f° (yaw_off %.1f)" % [ang, w.rig.yaw_off])
	_check(ang >= 20.0, "mouse en el borde izquierdo 1 s -> la vista gira ≥ 20° a la izquierda (%.1f°)" % ang)
	await _snap("borde_izquierdo")
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.2)

func _wheel() -> void:
	await _focus()
	var w = shell.world
	var fov0: float = w.camera().fov
	var at := Vector2(1150, 380)
	var a0: Vector2 = w.rig.cursor_angles(at)
	_mm(at)
	await tool.frames(2)
	for _i in 2:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.factor = 1.0
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await tool.frames(3)
	await _wait(0.5)
	var a1: Vector2 = w.rig.cursor_angles(at)
	print("V2CAM rueda: fov %.1f -> %.1f; cursor %.1f° -> %.1f° del centro" % [fov0, w.camera().fov, a0.length(), a1.length()])
	_check(w.camera().fov < fov0 - 3.0, "rueda -> el FOV baja")
	_check(a1.length() < a0.length(), "rueda -> la vista apunta hacia el cursor")
	await _snap("rueda")
	await _rclick(Vector2(800, 450))
	await _wait(0.3)

# Una visita (la consulta de Watson, L4): estaciones; empujar contra el borde lleva a la vecina.
func _visit_station() -> void:
	var r: Dictionary = g.act({"t": "go", "place": "L4", "area": ""})
	if not bool(r.get("ok", false)):
		print("V2CAM (sin visita a L4: %s)" % str(r.get("err", "")))
		return
	await _idle(2500)
	await tool.frames(40)
	for _k in 3:
		if shell.top() == null or String(shell.top_kind()) == "scene":
			break
		await _rclick(Vector2(800, 450))
		await _idle()
	# la banda de la escena queda ABIERTA, como la ve un jugador (con Watson presente se abre sola): los bordes y
	# «mirar alrededor» tienen que andar igual (antes el driver la cerraba por la API y eso escondía que no andaban)
	var w = shell.world
	_check(w.edge_enabled, "visita con la banda de escena (%s): los bordes giran" % str(shell.top_kind()))
	var st0: String = w.rig.cur
	await _snap("visita_estacion")
	await _focus()
	await _sync_mouse(Vector2(10, 470))
	print("V2CAM borde (visita): ", w.edge_debug())
	await _wait(1.6)
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.6)
	print("V2CAM visita: estación %s -> %s (vuelta %s) modo=%s yaw=%.1f/%.1f límites=%s cam=%s" % [st0, w.rig.cur, str(w.rig.station_ring()), w.rig.mode(), w.rig.yaw_off, w.rig.yaw_t, str(w.rig.limits()), str(w.camera().global_position)])
	_check(w.rig.cur != st0, "empujar contra el borde lleva a la estación vecina (%s -> %s)" % [st0, w.rig.cur])
	await _snap("visita_vecina")
	await _sync_mouse(Vector2(800, 300))
	await _wait(0.3)
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.4)
	_check(gs().looking_around() and gs().hover_label.many_count() >= 1, "visita con la banda: Espacio, mirar alrededor (%d)" % gs().hover_label.many_count())
	await _snap("visita_mirar")
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.3)
	await _sync_mouse(Vector2(800, 450))
