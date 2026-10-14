# devtools/drivers/v3mundo_plano.gd — UI-MUNDO (GDD_v3 §5.3, §5.4): el plano de la pared con el mouse real, SIN --fast.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3mundo_plano res://devtools/drivers/v3mundo_plano.gd --mute
# Recorrido (día 1): girar hasta el plano de la pared y clic -> el plano; al pasar el mouse por cada marcador, «qué hay»,
# «por qué está» y el horario -> salir a Kensington (pieza -> lugar) -> «Volver a casa» (lugar -> pieza) -> el plano otra
# vez: la salida ya está hecha (persianas). No hay cinta ni tecla M.
extends "res://devtools/drivers/v3mundo_base.gd"

const Widgets = preload("res://ui/kit/widgets.gd")

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 300 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3mundo_plano.jsonl"):
		_summary()
		return
	var w = shell.world
	_check(gs().hud.ribbon("map") == null, "sin cinta «Plano» en el HUD")
	await _key(KEY_M)
	await _wait(0.3)
	_check(not shell.is_open("map"), "M no abre nada")
	# girar a la izquierda con el borde hasta el plano
	await _focus()
	await _move(Vector2(10, 470))
	var t0 := Time.get_ticks_msec()
	var last_print := 0
	while Time.get_ticks_msec() - t0 < 6000 and w.rig.cur != "mapa":
		await tool.process_frame
		if Time.get_ticks_msec() - last_print > 700:
			last_print = Time.get_ticks_msec()
			print("V3M girando: %s yaw=%.1f→%.1f %s" % [w.rig.cur, w.rig.yaw_off, w.rig.yaw_t, str(w.edge_debug())])
	await _move(Vector2(800, 450))
	await _wait(0.9)
	_check(w.rig.cur == "mapa", "girando a la izquierda, la cámara se para frente al plano (%s)" % w.rig.cur)
	await _snap("01_pared")
	var pm := _safe_point("mapa")
	_check(pm.x >= 0.0, "el plano de la pared a la vista")
	await _move(pm)
	await _wait(0.4)
	_check(_cursor_name() == "mano", "sobre el plano: la mano (%s)" % _cursor_name())
	w.node_clicked.connect(func(id): print("V3M [node_clicked] %s busy=%s top=%s" % [id, str(shell.is_busy()), str(shell.top_kind())]))
	await _click(pm)
	await _wait(1.0)
	_check(shell.is_open("map"), "clic en la pared: el plano (%s, top=%s)" % [str(pm), shell.top_kind()])
	var ms = shell.panel("map")
	await _snap("02_plano")
	# hover por los marcadores
	var n := 0
	for id in ["L1", "L2", "L4", "L3", "L6"]:
		var m = ms.marker(id)
		if m == null:
			print("V3M (sin marcador %s todavía)" % id)
			continue
		var c: Vector2 = (m as Control).get_global_rect().position + (m as Control).get_meta("origin", Vector2(12, 12))
		await _move(c)
		await _wait(0.4)
		var txt: String = ms._hover.text if ms._hover.visible else ""
		print("V3M marcador %s: %s" % [id, txt.replace("\n", " | ")])
		var lines: Array = ms.hover_lines(id)
		if id != "L1":
			_check(lines.size() >= 2 or txt.count("\n") >= 1, "%s: varias líneas al pasar el mouse" % id)
		n += 1
		await _snap("03_hover_%s" % id)
	_check(n >= 2, "marcadores para mirar")
	# Kensington: pieza -> lugar
	var mk = ms.marker("L4")
	if mk != null and mk.is_open():
		await _click_ctrl(mk)
		await _wait(0.6)
		var popup = ms._popup
		if popup != null and is_instance_valid(popup):
			var b: Button = null
			for bt in popup.find_children("*", "Button", true, false):
				if (bt as Button).text.to_lower().contains("consult"):
					b = bt
			if b == null:
				for bt in popup.find_children("*", "Button", true, false):
					b = bt
					break
			if b != null:
				await _click_ctrl(b)
				await _wait(0.6)
		# confirmación del viaje
		for bt in ms.find_children("*", "Button", true, false):
			if (bt as Button).is_visible_in_tree() and (bt as Button).text == Widgets.t("shell.map.ir"):
				await _click_ctrl(bt)
				break
		await _wait(4.0)
		await _settle()
		_check(String(g.sim.q_clock().phase) == "visit", "salir: de la pieza al lugar (%s)" % String(g.sim.q_clock().phase))
		await _snap("04_kensington")
		# lugar -> pieza
		var lb: Control = gs()._leave_btn
		if lb != null and lb.is_visible_in_tree():
			await _click_ctrl(lb)
			await _wait(0.5)
			var mo = gs().modal()
			if mo != null:
				for bt in mo.find_children("*", "Button", true, false):
					if (bt as Button).text == Widgets.t("shell.leave.ok"):
						await _click_ctrl(bt)
						break
		else:
			var sp = shell.panel("scene")
			if sp != null: sp._do_leave()
		await _settle()
		await _wait(0.6)
		_check(String(g.sim.q_clock().phase) == "desk", "volver: del lugar a la pieza")
		_check(w.rig.cur == "escritorio", "de vuelta, mirando el escritorio (%s)" % w.rig.cur)
		await _snap("05_de_vuelta")
		w.set_frame("mapa")
		await _wait(1.6)
		await _click(_safe_point("mapa"))
		await _wait(1.0)
		_check(shell.is_open("map"), "el plano otra vez")
		await _snap("06_plano_salida_hecha")
	else:
		_check(false, "Kensington abierto en el plano")
	_summary()
	g.end_session()
