# devtools/drivers/v3fix_mundo.gd — CORRECTOR FINAL (playtest v3), con ventana y SIN --fast, sobre la partida que deja
# v3integ_partida.gd (user://saves/v3integ.jsonl, día 3 por la mañana, de vuelta de Kensington). «Continuar» con el mouse y:
#   1. Empujón corto por el borde izquierdo (0,8 s, mouse real): la cámara se asienta en el estante, no vuelve al escritorio.
#   2. Cerrar la franja -> tarde -> Somerset House por el plano: los objetos con algo para leer o pedir llevan la MANO
#      (antes, 19 lupas y la acción escondida); el botón de salida dice «Salir».
#   3. Pocos objetos con lupa en la sala.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3fixm res://devtools/drivers/v3fix_mundo.gd --mute
extends "res://devtools/drivers/w3int_flow.gd"

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(500.0).timeout.connect(func():
		print("W3INT VIGIA")
		tool.quit(2))
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	g.save_path = "user://saves/v3integ.jsonl"
	await _settle_window()
	shell.show_title()
	await tool.frames(30)
	var bc := _button(shell.screen, Widgets.t("shell.title.continuar"))
	_check(bc != null, "título: «Continuar»")
	if bc == null:
		_summary()
		return
	await _click(_c(bc))
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 600)
	if shell.game_screen == null:
		print("W3INT AVISO (entorno): el clic en «Continuar» no llegó (cursor del sistema); se sigue con shell.continue_game()")
		await shell.continue_game()
		await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 1500)
	await tool.frames(40)
	if gs().tray.visible:
		await _close_tray()
	var c: Dictionary = g.sim.q_clock()
	print("W3INT continuar: día %s %s %s" % [str(c.day), str(c.slot), str(c.phase)])
	# ---- 1. empujón corto por el borde izquierdo
	shell.world.set_frame("escritorio", true)
	await tool.frames(10)
	await _mm(Vector2(800, 450))
	await _wait(0.4)
	var w = shell.world
	print("W3INT borde: %s" % str(w.edge_debug()))
	await _mm(Vector2(10, 470))
	await _wait(0.8)
	await _mm(Vector2(800, 470))
	await _wait(2.2)
	print("W3INT tras un empujón de 0,8 s: punto «%s», yaw %.1f" % [String(w.rig.cur), w.rig.yaw_off])
	_check(String(w.rig.cur) == "estante", "un empujón corto por el borde se asienta en el estante (no vuelve al escritorio)")
	await _snap("empujon_estante")
	shell.world.set_frame("escritorio")
	await _wait(1.2)
	# ---- 2. a Somerset House por el plano
	if String(g.sim.q_clock().slot) == "M":
		await _click_ctrl(gs().hud.card)
		await tool.frames(12)
		var m = gs().modal()
		if m != null:
			await _click(_c(_first_enabled_button(m, true)))
			await _until(func(): return String(g.sim.q_clock().slot) != "M", 300)
			await _idle()
			await tool.frames(20)
	print("W3INT franja: %s %s" % [String(g.sim.q_clock().slot), String(g.sim.q_clock().phase)])
	shell.world.set_frame("mapa")
	await _wait(1.6)
	if not await _click_3d("mapa"):
		_check(false, "el plano")
		_summary()
		return
	await _wait(1.0)
	var ms = shell.panel("map") if shell.is_open("map") else null
	var mk = ms.marker("L6") if ms != null and ms.has_method("marker") else null
	print("W3INT plano abierto: %s, marcador de Somerset: %s, lugares: %s" % [str(ms != null), str(mk != null), str(g.sim.q_places().map(func(p): return String(p.get("id", ""))))])
	if mk == null:
		# el cursor del sistema no obedece (el usuario usa el mouse): se sigue por la API para mirar Somerset
		await _clear_top()
		var r: Dictionary = g.act({"t": "go", "place": "L6", "area": "sala"})
		print("W3INT AVISO (entorno): a Somerset por Game.act -> %s" % str(r))
	else:
		await _click((mk as Control).get_global_rect().position + (mk as Control).get_meta("origin", Vector2(12, 12)))
		await _wait(0.8)
	for _k in 4:
		if String(g.sim.q_clock().phase) == "visit":
			break
		var b := _first_enabled_button(ms, true) if ms != null and is_instance_valid(ms) else null
		var cf = gs().modal()
		if cf != null:
			b = _first_enabled_button(cf, true)
		if b == null:
			break
		print("W3INT plano: clic en «%s»" % b.text)
		await _click(_c(b))
		await _wait(1.0)
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 1200)
	await _idle()
	await _wait(1.5)
	_check(String(g.sim.q_clock().phase) == "visit" and String(gs().cur_place) == "L6", "en Somerset House")
	if String(gs().cur_place) != "L6":
		_summary()
		return
	await _clear_top()
	var idx: Dictionary = w.diorama.get_meta("nodes_index", {})
	var hands: Array = []
	var looks: Array = []
	for nid in idx:
		if w.usable.has("n:" + String(nid)):
			hands.append(String(nid))
		else:
			looks.append(String(nid))
	print("W3INT Somerset: mano %s · lupa %s" % [str(hands), str(looks)])
	_check(hands.has("calendars") and hands.has("atril_calendars") and hands.has("indices_defunciones"), "los índices (D18) llevan la mano")
	_check(looks.size() <= 15, "pocos objetos para mirar (%d; antes 28)" % looks.size())
	# hover real sobre un objeto con mano: el cursor
	for nid in ["atril_calendars", "calendars", "indices_defunciones"]:
		var p := _node_pos(nid)
		if p.x < 0.0:
			continue
		await _mm(p)
		await _wait(0.5)
		print("W3INT hover %s: %s / %s" % [nid, String(w.hover_id), str(Input.get_current_cursor_shape())])
		await _snap("somerset_hover_" + nid)
		break
	var lb: Button = gs()._leave_btn
	print("W3INT botón de salida: «%s» (visible %s)" % [lb.text, str(lb.visible)])
	var sp = shell.panel("scene")
	var leave_txt := ""
	if sp != null:
		for key in ["sceneui.leave.free", "sceneui.leave"]:
			if leave_txt == "" and _button(sp, Widgets.t(key), true) != null:
				leave_txt = Widgets.t(key)
	_check(lb.text == Widgets.t("shell.nav.volver") and Widgets.t("shell.nav.volver") == "Salir", "el botón de salida dice «Salir»")
	await _snap("somerset")
	_summary()
	g.end_session()
