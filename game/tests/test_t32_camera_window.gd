# T32 (UI-MUNDO, GDD_v3 §6.6) — con ventana y SIN --fast, con eventos reales (Input.warp_mouse + Input.parse_input_event,
# como devtools/drivers/title_smoke.gd): el juego real hasta el escritorio del día 1 (el bot deductor juega el prólogo
# por el sim) y entonces, con el mouse:
#   mouse en el borde izquierdo 1 s → la vista gira ≥ 20° a la izquierda y la cámara se desliza por el riel (del
#   escritorio hacia el estante), sin saltos: < 3° y < 5 cm por cuadro;
#   clic en el expediente → se abre en el acto y la cámara NO se mueve; clic derecho → se cierra;
#   rueda → baja el FOV y la vista apunta hacia el cursor, sin trasladar la cámara; no existe ChevronIzq/ChevronDer.
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window t32
extends "res://tests/fixtures/v2cam/window_base.gd"

const WINDOW := true
const TIMEOUT_S := 240.0

func test_camera_with_real_mouse() -> void:
	if not await _boot_day1(): return
	var w = sh.world
	eq(sh.find_children("ChevronIzq", "", true, false).size() + sh.find_children("ChevronDer", "", true, false).size(), 0, "ningún chevrón")
	eq([w.rig.mode(), w.rig.cur], ["rail", "escritorio"], "la buhardilla, mirando el escritorio")
	var cam: Camera3D = w.camera()
	# borde izquierdo 1 s, midiendo cada cuadro
	await _focus()
	await _move(Vector2(800, 450))
	await _wait(0.3)
	var f0: Vector3 = -cam.global_transform.basis.z
	var p0: Vector3 = cam.global_position
	await _move(Vector2(12, 470))
	var worst_a := 0.0
	var worst_p := 0.0
	# (se mide desde que el mouse llegó al borde: lo girado mientras viajaba no es un cuadro)
	var prev_f: Vector3 = -cam.global_transform.basis.z
	var prev_p: Vector3 = cam.global_position
	var t0 := Time.get_ticks_msec()
	var last_us := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 1000:
		await tree.process_frame
		var fr: Vector3 = -cam.global_transform.basis.z
		var ps: Vector3 = cam.global_position
		# a 60 fps: lo medido por cuadro escalado al cuadro real
		# tiempo real entre cuadros (al emitirse process_frame el delta del root todavía es el del cuadro anterior)
		var now_us := Time.get_ticks_usec()
		var dt: float = maxf(float(now_us - last_us) / 1000000.0, 1.0 / 240.0)
		last_us = now_us
		# un cuadro lento del motor (otro proceso) mueve la cámara su delta entero: se normaliza también por el dt del riel
		var k := (1.0 / 60.0) / maxf(maxf(dt, float(w.rig.last_dt)), 1.0 / 60.0)
		worst_a = maxf(worst_a, rad_to_deg(prev_f.angle_to(fr)) * k)
		worst_p = maxf(worst_p, prev_p.distance_to(ps) * k)
		prev_f = fr
		prev_p = ps
	var f1: Vector3 = -cam.global_transform.basis.z
	var ang := rad_to_deg(atan2(f0.cross(f1).y, f0.dot(f1)))
	ok(ang >= 20.0, "mouse en el borde izquierdo 1 s: la vista gira ≥ 20° a la izquierda (%.1f°, %s)" % [ang, str(w.edge_debug())])
	ok(cam.global_position.distance_to(p0) > 0.1, "y la cámara se desliza por el riel (%.2f m)" % cam.global_position.distance_to(p0))
	ok(worst_a < 3.0 and worst_p < 0.05, "sin saltos: %.2f° y %.1f cm por cuadro a 60 fps" % [worst_a, worst_p * 100.0])
	await _move(Vector2(800, 450))
	await _wait(0.3)
	w.set_frame("escritorio", true)
	await _frames(4)
	# clic en el expediente: se usa en el acto, sin mover la cámara
	await _focus()
	var x0: Transform3D = cam.global_transform
	var fov_c := cam.fov
	var pe := _node_pos("expediente")
	ok(pe.x >= 0.0 and String(w.pick(pe).get("id", "")) == "expediente", "el expediente se ve desde el escritorio")
	await _click(pe)
	await _wait(0.6)
	ok(sh.is_open("dossier"), "clic en la carpeta: el expediente abierto")
	ok(cam.global_transform.is_equal_approx(x0) and is_equal_approx(cam.fov, fov_c), "la cámara no se movió")
	# clic derecho cierra
	await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
	await _wait(0.6)
	for _k in 3:
		if sh.top() == null: break
		await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
		await _wait(0.5)
	no(sh.is_open("dossier"), "clic derecho: se cierra")
	# rueda hacia un punto a la derecha y arriba
	var at := Vector2(1150, 330)
	var fov0: float = cam.fov
	var a0: Vector2 = w.rig.cursor_angles(at)
	var pos0: Vector3 = cam.global_position
	await _move(at)
	for _i in 2:
		_btn(at, MOUSE_BUTTON_WHEEL_UP, true)
		_btn(at, MOUSE_BUTTON_WHEEL_UP, false)
		await _frames(3)
	await _wait(0.6)
	ok(cam.fov < fov0 - 3.0, "rueda: el FOV baja (%.1f → %.1f)" % [fov0, cam.fov])
	ok(w.rig.cursor_angles(at).length() < a0.length() - 1.0, "rueda: la vista apunta hacia el cursor")
	ok(cam.global_position.distance_to(pos0) < 0.001, "sin trasladar la cámara")
