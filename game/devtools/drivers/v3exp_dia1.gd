# devtools/drivers/v3exp_dia1.gd — UI-EXPEDIENTE (GDD_v3 §7.2 P3), segunda mitad del criterio con datos REALES: el bot
# deductor juega el prólogo por el sim hasta el escritorio del día 1 (base de UI-MUNDO), y desde ahí TODO con el mouse
# real, SIN --fast: clic en la carpeta 3D del escritorio -> la carpeta abre con el cuaderno acoplado a la izquierda ->
# se mira la hoja de cada pregunta abierta (dudas, ranuras, tarjetas reales) -> se arrastra un recorte REAL del
# cuaderno a una prueba -> clic en «Respuesta» abre el selector -> Esc -> clic derecho saca la prueba -> Esc cierra.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3exp_d1 res://devtools/drivers/v3exp_dia1.gd --mute
# Salida: «V3M OK|FALLA <qué>», «V3M RESUMEN n fallas».
extends "res://devtools/drivers/v3mundo_base.gd"

const ClipCard = preload("res://ui/notebook/clip_card.gd")

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 300 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3exp_d1.jsonl"):
		_summary()
		return
	await _move(Vector2(800, 450))
	await _wait(0.6)
	await _snap("00_dia1")
	var p := _safe_point("expediente")
	_check(p.x >= 0.0, "la carpeta del expediente se ve en el escritorio")
	if p.x < 0.0:
		_summary()
		return
	await _move(p)
	await _wait(0.3)
	print("V3M cursor sobre la carpeta: %s" % _cursor_name())
	await _snap("01_sobre_la_carpeta")
	await _click(p)
	await _wait(1.0)
	_check(shell.is_open("dossier"), "clic en la carpeta del escritorio abre el expediente")
	if not shell.is_open("dossier"):
		await _snap("01b_no_abrio")
		_summary()
		return
	var ex = shell.panel("dossier")
	var nb = shell.panel("notebook") if shell.is_open("notebook") else null
	_check(nb != null and String(nb.layout) == "left", "el cuaderno se acopla a la izquierda")
	var d: Dictionary = g.sim.q_dossier()
	print("V3M abiertas: %s · en tinta: %s" % [str(d.open.map(func(h): return h.id)), str(d.inked.map(func(h): return h.id))])
	_check(d.open.size() >= 1 and d.open.size() <= 3, "entre 1 y 3 preguntas abiertas a la vista")
	await _snap("02_carpeta")
	# cada hoja abierta, con el mouse
	var i := 0
	for h in d.open:
		var r: Rect2 = ex.row_rect(String(h.id))
		if r.size.x <= 0.0:
			_check(false, "renglón de %s en el índice" % h.id)
			continue
		await _click(r.get_center())
		await _wait(0.5)
		_check(String(ex.debug_state().selected) == String(h.id), "clic en %s la muestra a la derecha" % h.id)
		await _snap("03_hoja_%s" % h.id)
		i += 1
	# un recorte REAL del cuaderno a la prueba 1 de la primera pregunta
	var q0 := String(d.open[0].id)
	await _click(ex.row_rect(q0).get_center())
	await _wait(0.4)
	if nb != null:
		nb.show_tab("recortes")
		await _wait(0.4)
		var ids: Array = nb.page("recortes").visible_ids()
		print("V3M recortes reales en el cuaderno: %d" % ids.size())
		var maxw := 0
		for cid in ids:
			var c = nb.page("recortes").card(cid)
			if c != null:
				maxw = maxi(maxw, ClipCard.shown_text(c.clip).strip_edges().split(" ", false).size())
		_check(maxw <= 15, "ninguna tarjeta del cuaderno pasa de 15 palabras (máx %d)" % maxw)
		if not ids.is_empty():
			var card = nb.page("recortes").card(ids[0])
			await _drag((card.strip as Control).get_global_rect().get_center(), ex.rect_of("prueba", 0).get_center())
			await _wait(0.6)
			_check(String(ex.debug_state().proofs[0]) == String(ids[0]), "arrastrar un recorte real a la prueba 1")
			await _snap("04_prueba_real")
	await _click(ex.rect_of("respuesta").get_center())
	await _wait(0.5)
	_check(ex.picker() != null, "clic en «Respuesta» abre el selector")
	await _snap("05_selector_real")
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	_check(ex.picker() == null and ex.is_open(), "Esc cierra el selector y la carpeta sigue")
	if String(ex.debug_state().proofs[0]) != "":
		await _click(ex.rect_of("prueba", 0).get_center(), MOUSE_BUTTON_RIGHT)
		await _wait(0.4)
		_check(String(ex.debug_state().proofs[0]) == "" and ex.is_open(), "clic derecho saca la prueba (la carpeta sigue)")
	await _key(KEY_ESCAPE)
	await _wait(0.8)
	_check(not shell.is_open("dossier") and not shell.is_open("notebook"), "Esc cierra la carpeta y el cuaderno")
	await _snap("06_cerrado")
	_summary()
	g.end_session()

func _drag(a: Vector2, b: Vector2) -> void:
	await _move(a)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = _win(a)
	e.global_position = e.position
	Input.parse_input_event(e)
	await tool.frames(2)
	for k in range(1, 25):
		var q := a.lerp(b, float(k) / 24.0)
		var wp := _win(q)
		Input.warp_mouse(wp)
		var m := InputEventMouseMotion.new()
		m.position = wp
		m.global_position = wp
		m.relative = q - _last
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		_last = q
		Input.parse_input_event(m)
		await tool.frames(1)
		if k == 16:
			await _snap("arrastre")
	await tool.frames(3)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = _win(b)
	u.global_position = u.position
	Input.parse_input_event(u)
	await tool.frames(8)
