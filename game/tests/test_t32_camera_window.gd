# T32 (CÁMARA, GDD_v2 §E.4) — con ventana y SIN --fast, con eventos reales (Input.warp_mouse + Input.parse_input_event,
# como devtools/drivers/title_smoke.gd): el juego real hasta el escritorio del día 1 (el bot deductor juega el prólogo por
# el sim) y entonces, con el mouse:
#   mouse en el borde izquierdo 1 s → la vista gira ≥ 20° a la izquierda; clic en el escritorio → zona «escritorio»;
#   clic derecho → vista general; rueda → baja el FOV y la vista apunta hacia el cursor; no existe ChevronIzq/ChevronDer.
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window t32
extends "res://tests/fixtures/v2cam/window_base.gd"

const WINDOW := true
const TIMEOUT_S := 240.0

func test_camera_with_real_mouse() -> void:
	if not await _boot_day1(): return
	var w = sh.world
	eq(sh.find_children("ChevronIzq", "", true, false).size() + sh.find_children("ChevronDer", "", true, false).size(), 0, "ningún chevrón")
	if w.rig.mode() != "overview":
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _wait(0.6)
	eq([w.rig.mode(), w.rig.cur], ["overview", "general"], "vista general de la buhardilla")
	# borde izquierdo 1 s
	await _focus()
	var f0: Vector3 = -w.camera().global_transform.basis.z
	await _move(Vector2(12, 470))
	await _wait(1.0)
	var f1: Vector3 = -w.camera().global_transform.basis.z
	var ang := rad_to_deg(atan2(f0.cross(f1).y, f0.dot(f1)))
	ok(ang >= 20.0, "mouse en el borde izquierdo 1 s: la vista gira ≥ 20° a la izquierda (%.1f°, %s)" % [ang, str(w.edge_debug())])
	await _move(Vector2(800, 450))
	await _wait(0.3)
	w.rig.go_overview(true)
	await _frames(3)
	# clic en el escritorio → zona
	await _focus()
	await _click(_node_pos("escritorio"))
	await _wait(0.7)
	eq([w.rig.mode(), w.rig.cur], ["zone", "escritorio"], "clic en el escritorio: encuadre de la zona")
	# clic derecho → general
	await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
	await _wait(0.7)
	eq(w.rig.mode(), "overview", "clic derecho: vista general")
	# rueda hacia un punto a la derecha y arriba
	var at := Vector2(1150, 330)
	var fov0: float = w.camera().fov
	var a0: Vector2 = w.rig.cursor_angles(at)
	await _move(at)
	for _i in 2:
		_btn(at, MOUSE_BUTTON_WHEEL_UP, true)
		_btn(at, MOUSE_BUTTON_WHEEL_UP, false)
		await _frames(3)
	await _wait(0.6)
	ok(w.camera().fov < fov0 - 3.0, "rueda: el FOV baja (%.1f → %.1f)" % [fov0, w.camera().fov])
	ok(w.rig.cursor_angles(at).length() < a0.length() - 1.0, "rueda: la vista apunta hacia el cursor")
