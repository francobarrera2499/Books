# devtools/drivers/v3mundo_hover.gd — UI-MUNDO (GDD_v3 §6.5, §6.6): contorno blanco y cursor con el mouse real, SIN --fast.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3mundo_hover res://devtools/drivers/v3mundo_hover.gd --mute
# Recorrido (día 1, escritorio): sobre el tintero (contorno blanco + mano) · sobre la ventana (contorno + lupa) · sobre la
# pared (nada) · clic en el expediente (se abre en el acto, la cámara no se mueve) · clic en el tintero (el aviso, directo
# o la tarjeta con lo que se puede escribir) · girar hacia la cama (decoración: nada bajo el mouse).
extends "res://devtools/drivers/v3mundo_base.gd"

func _coded(key: String, code: int) -> bool:
	var w = shell.world
	for gi in AFF.owners(w.diorama).get(key, []):
		var g3 := gi as GeometryInstance3D
		if g3.material_override != g3.get_meta("aff_orig", null) and AFF.code_of(g3) == code:
			return true
	return false

func _any_outline() -> bool:
	var w = shell.world
	for k in AFF.owners(w.diorama):
		if _coded(String(k), 3):
			return true
	return false

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 300 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3mundo_hover.jsonl"):
		_summary()
		return
	var w = shell.world
	var cam: Camera3D = w.camera()
	await _focus()
	# un punto sin nada debajo (el tintero del frente, §10, ocupa el centro de la vista)
	await _move(_empty_point())
	await _wait(0.4)
	no_outline_check("sin el mouse encima de nada: ningún contorno")
	await _snap("01_sin_realce")
	# el tintero: se usa
	var pt := _safe_point("tintero")
	_check(pt.x >= 0.0, "el tintero a la vista")
	await _move(pt)
	await _wait(0.4)
	_check(w.hover_id == "tintero" and _coded("n:tintero", 3), "sobre el tintero: contorno blanco")
	_check(_cursor_name() == "mano", "y la mano (%s)" % _cursor_name())
	await _snap("02_tintero_mano")
	# la carpeta del expediente: se usa
	var pe := _safe_point("expediente")
	await _move(pe)
	await _wait(0.4)
	_check(w.hover_id == "expediente" and _cursor_name() == "mano", "sobre la carpeta: contorno y mano (%s)" % _cursor_name())
	await _snap("03_expediente_mano")
	# la ventana: se mira
	var pv := _safe_point("ventana")
	await _move(pv)
	await _wait(0.4)
	_check(w.hover_id == "ventana" and _coded("n:ventana", 3), "sobre la ventana: contorno blanco")
	_check(_cursor_name() == "lupa", "y la lupa (%s)" % _cursor_name())
	await _snap("04_ventana_lupa")
	# clic en el expediente: se abre en el acto, sin mover la cámara
	var x0 := cam.global_transform
	await _click(pe)
	await _wait(0.8)
	_check(shell.is_open("dossier"), "clic en la carpeta: el expediente")
	_check(cam.global_transform.is_equal_approx(x0), "la cámara no se movió")
	await _snap("05_expediente_abierto")
	for _k in 3:
		if shell.top() == null: break
		await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
		await _wait(0.5)
	# clic en la ventana: su tarjeta (sin acercarse)
	await _click(pv)
	await _wait(0.6)
	_check(gs().exam.visible, "clic en la ventana: su tarjeta de examen")
	_check(cam.global_transform.is_equal_approx(x0), "sin acercarse")
	_check(gs().exam.scissors_btn.visible, "la tarjeta lleva la tijera como ícono suelto")
	await _snap("06_tarjeta_ventana")
	await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
	await _wait(0.4)
	# clic en el tintero: lo que se puede escribir
	await _click(pt)
	await _wait(0.8)
	_check(shell.is_open("ad") or gs().exam.visible, "clic en el tintero: el aviso o la tarjeta con lo que se puede escribir")
	await _snap("07_tintero")
	for _k in 3:
		if shell.top() == null and not gs().exam.visible: break
		await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
		await _wait(0.5)
	# la cama: decoración, nada bajo el mouse
	var bed: Node3D = w.diorama.get_node_or_null("Props/cama")
	var pb := Vector2(-1, -1)
	if bed != null:
		for yy in range(180, 340, 5):
			w.rig.yaw_t = float(yy); w.rig.yaw_off = float(yy); w.rig._apply()
			var q := bed.global_position + Vector3(0, 0.45, 0)
			if cam.is_position_behind(q): continue
			var sp := cam.unproject_position(q)
			if Rect2(200, 150, 1200, 600).has_point(sp):
				pb = sp
				break
	_check(pb.x >= 0.0, "la cama en pantalla")
	await _move(pb)
	await _wait(0.5)
	_check(w.hover_kind == "none" and _cursor_name() == "flecha", "sobre la cama: nada (%s, %s)" % [w.hover_id, _cursor_name()])
	no_outline_check("ningún contorno sobre la decoración")
	await _snap("08_cama_nada")
	_summary()
	g.end_session()

# Punto de la vista (fuera de las bandas del borde y del HUD) donde el clic no da con nada, el más cercano al centro.
func _empty_point() -> Vector2:
	var w = shell.world
	var hud_r := Rect2()
	if gs() != null and gs().hud != null and gs().hud.visible:
		hud_r = (gs().hud.cover_rect() as Rect2).grow(12.0)
	var best := Vector2(800, 450)
	var bd := INF
	for y in range(130, 770, 20):
		for x in range(170, 1430, 20):
			var p := Vector2(x, y)
			if hud_r.size.x > 0.0 and hud_r.has_point(p): continue
			if String(w.pick(p).get("kind", "none")) != "none": continue
			var d := p.distance_to(Vector2(800, 450))
			if d < bd:
				bd = d
				best = p
	return best

func no_outline_check(what: String) -> void:
	_check(not _any_outline(), what)
