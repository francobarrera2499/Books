# devtools/drivers/v3mundo_general.gd — UI-MUNDO (GDD_v3 §6.4–§6.6, §5.4): la pieza del día 1 con el mouse real, SIN --fast.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3mundo_general res://devtools/drivers/v3mundo_general.gd --mute
# Recorrido: escritorio (HUD: calendario y Pendientes, sin cintas) -> borde derecho: la cámara se desliza al escritorio y
# a la ventana (mide saltos por cuadro) -> borde izquierdo: estante, plano, puerta -> clic en la puerta: la tienda de
# Crane (cintas «Cuaderno» y «Expediente» a la vista) -> «Subir» -> la pieza.
extends "res://devtools/drivers/v3mundo_base.gd"

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 300 s")
		tool.quit(2))
	if not await _boot_day1(scene):
		_summary()
		return
	var w = shell.world
	var cam: Camera3D = w.camera()
	w.rig.frame_changed.connect(func(id): print("V3M [frame_changed] %s yaw=%.1f→%.1f" % [id, w.rig.yaw_off, w.rig.yaw_t]))
	w.rig.pose_changed.connect(func(k): print("V3M [pose_changed] %s yaw=%.1f" % [k, w.rig.yaw_off]))
	w.plate_ready.connect(func(pid): print("V3M [plate_ready] %s" % pid))
	await _move(Vector2(800, 450))
	await _wait(0.4)
	_check(w.rig.cur == "escritorio", "se entra mirando el escritorio (%s)" % w.rig.cur)
	_check(not gs().hud.books_box.visible, "en la buhardilla, sin cintas en el HUD")
	await _snap("01_escritorio")
	# borde derecho: escritorio -> ventana, midiendo cada cuadro
	var worst_a := 0.0
	var worst_p := 0.0
	await _move(Vector2(1590, 470))
	# (se mide desde que el mouse llegó al borde: lo girado mientras viajaba no es un cuadro)
	var prev_f: Vector3 = -cam.global_transform.basis.z
	var prev_p: Vector3 = cam.global_position
	var t0 := Time.get_ticks_msec()
	var last_us := Time.get_ticks_usec()
	var shot_mid := false
	while Time.get_ticks_msec() - t0 < 1400:
		await tool.process_frame
		# tiempo real entre cuadros (al emitirse process_frame el delta del root todavía es el del cuadro anterior)
		var now_us := Time.get_ticks_usec()
		var dt: float = maxf(float(now_us - last_us) / 1000000.0, 1.0 / 240.0)
		last_us = now_us
		# un cuadro lento del motor (otro proceso) mueve la cámara su delta entero: se normaliza también por el dt del riel
		var k := (1.0 / 60.0) / maxf(maxf(dt, float(w.rig.last_dt)), 1.0 / 60.0)
		var da := rad_to_deg(prev_f.angle_to(-cam.global_transform.basis.z)) * k
		var dp := prev_p.distance_to(cam.global_position) * k
		if da > 2.5 or dp > 0.04:
			print("V3M cuadro: dt=%.4f k=%.3f giro=%.2f° paso=%.1f cm yaw=%.1f→%.1f" % [dt, k, da, dp * 100.0, w.rig.yaw_off, w.rig.yaw_t])
		worst_a = maxf(worst_a, da)
		worst_p = maxf(worst_p, dp)
		prev_f = -cam.global_transform.basis.z
		prev_p = cam.global_position
		if not shot_mid and Time.get_ticks_msec() - t0 > 450:
			shot_mid = true
			await tool.snap("02_girando")
			# (la captura frena el cuadro siguiente: el riel avanza ese delta largo; no se mide a través de ella)
			await tool.process_frame
			await tool.process_frame
			prev_f = -cam.global_transform.basis.z
			prev_p = cam.global_position
			last_us = Time.get_ticks_usec()
	await _move(Vector2(800, 450))
	await _wait(1.0)
	print("V3M riel: %s yaw=%.1f pos=%s" % [w.rig.cur, w.rig.yaw_off, str(cam.global_position.snapped(Vector3.ONE * 0.01))])
	_check(w.rig.cur == "ventana", "borde derecho: la cámara llega a la ventana (%s)" % w.rig.cur)
	_check(worst_a < 3.0 and worst_p < 0.05, "sin saltos: %.2f° y %.1f cm por cuadro a 60 fps" % [worst_a, worst_p * 100.0])
	await _snap("03_ventana")
	# borde izquierdo: de vuelta, el estante y el plano
	await _move(Vector2(10, 470))
	await _wait(2.3)
	await _move(Vector2(800, 450))
	await _wait(0.8)
	print("V3M riel: %s yaw=%.1f" % [w.rig.cur, w.rig.yaw_off])
	await _snap("04_izquierda_%s" % w.rig.cur)
	w.set_frame("mapa")
	await _wait(1.6)
	_check(w.rig.cur == "mapa", "el plano de la pared (%s)" % w.rig.cur)
	await _snap("05_plano_en_la_pared")
	w.set_frame("puerta")
	await _wait(1.4)
	await _snap("06_puerta")
	# clic en la puerta: la tienda
	var pd := _safe_point("puerta")
	_check(pd.x >= 0.0, "la puerta a la vista")
	await _click(pd)
	await _settle()
	await _wait(0.8)
	var sc: Dictionary = g.sim.q_scene()
	_check(String(g.sim.q_clock().phase) == "visit" and String(sc.get("area", "")) == "tienda", "la puerta baja a la tienda")
	_check(gs().hud.books_box.visible, "en la tienda, las cintas «Cuaderno» y «Expediente»")
	await _snap("07_tienda")
	# «Subir» (botón de abajo o la escalera)
	var lb: Control = gs()._leave_btn
	if lb != null and lb.is_visible_in_tree():
		await _click_ctrl(lb)
	else:
		var sp = shell.panel("scene")
		if sp != null:
			sp.leave()
	await _settle()
	await _wait(0.6)
	_check(String(g.sim.q_clock().phase) == "desk", "de vuelta en la pieza")
	_check(not gs().hud.books_box.visible, "y sin cintas otra vez")
	await _snap("08_de_vuelta")
	_summary()
	g.end_session()
