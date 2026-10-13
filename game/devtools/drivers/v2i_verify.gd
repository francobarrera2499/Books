# devtools/drivers/v2i_verify.gd — INTEGRACIÓN v2: verificación con ventana, SIN --fast y con eventos reales de mouse y
# teclado, de los arreglos del playtest v2 (sólo diagnóstico + capturas para .work/reports/v2_shots.txt).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2iv res://devtools/drivers/v2i_verify.gd --mute --v2i=casa
#     (sigue la partida user://saves/v2novato.jsonl de v2_novato.gd): mesa con lo usable y la mano; girar la buhardilla con
#     el borde hasta la puerta (BLOCKER) y bajar a la tienda con un clic; mirar alrededor en la tienda (las etiquetas siguen
#     el giro); hablar con Crane; «‹ Alejarse»; un documento con su línea física; terminar los turnos hasta la noche.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2ip res://devtools/drivers/v2i_verify.gd --mute --v2i=park --new --seed=1 --script=<guion hasta Park Lane>
#     (Park Lane del día 10 con el guion de slice_f1 cortado en la escena).
# Imprime «V2I …» (OK/FALLA) y «V2I RESUMEN».
extends "res://devtools/drivers/v2_novato.gd"

var mode := "casa"
var _fails := 0

func _ok(c: bool, what: String) -> void:
	if not c:
		_fails += 1
	print("V2I %s %s" % ["OK" if c else "FALLA", what])

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--v2i="):
			mode = s.substr(6)
	await _settle_window()
	if mode == "park":
		await _park()
	else:
		g.save_path = "user://saves/v2novato.jsonl"
		shell.show_title()
		await tool.frames(40)
		await _continuar()
		await _casa()
	print("V2I RESUMEN %d fallas" % _fails)
	if g.sim != null and mode != "park":
		g.end_session()

func _clear() -> void:
	for _i in 6:
		if gs() == null:
			return
		if gs().tray.visible:
			await _close_tray()
			await _wait(0.4)
			continue
		if shell.reader_open():
			await _close_reader()
			await _wait(0.4)
			continue
		if shell.top() != null:
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
			continue
		break

func _home_general() -> void:
	for _i in 4:
		if shell.world.rig.depth() <= 1:
			break
		await _rclick(Vector2(800, 450))
		await _wait(0.6)

func _casa() -> void:
	await _idle()
	await _clear()
	var ph := String(g.sim.q_clock().phase)
	print("V2I fase al seguir: %s día %d" % [ph, int(g.sim.q_clock().day)])
	if ph == "visit":
		var lb = gs()._leave_btn
		if lb != null and lb.is_visible_in_tree():
			await _click(_c(lb))
			await _wait(0.8)
			var m = gs().modal()
			if m != null:
				var ok := _first_enabled_button(m, true)
				if ok != null:
					await _click(_c(ok))
			await _idle()
			await _clear()
	await _home_general()
	await _wait(0.6)
	# 1. la mesa: lo usable lleva su filete rojo; el mouse sobre el cuaderno da la mano y «Cuaderno · abrir»
	await _snap("mesa_general")
	var pc := _node_pos("cuaderno")
	if pc.x >= 0.0:
		await _sync_mouse(pc)
		await _wait(0.6)
		await _snap("mesa_cuaderno_usable")
		_ok(String(gs().hover_label.label_text()).begins_with("Cuaderno"), "etiqueta sobre el cuaderno: «%s»" % gs().hover_label.label_text())
		_ok(Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND, "cursor de mano sobre lo usable")
	var ps := _node_pos("silla")
	if ps.x >= 0.0:
		await _sync_mouse(ps)
		await _wait(0.6)
		_ok(gs().hover_label.label_text() == "silla" and Input.get_current_cursor_shape() == Input.CURSOR_HELP, "la silla: etiqueta «silla» y lupa")
	# 2. BLOCKER: girar con el borde izquierdo hasta ver la puerta y bajar con un clic
	var found := false
	for k in 8:
		var pd := _node_pos("puerta")
		if pd.x >= 40.0 and pd.x <= 1560.0 and String(shell.world.pick(pd).get("id", "")) == "puerta":
			found = true
			break
		await _sync_mouse(Vector2(4, 450))
		await _wait(0.9)
		await _sync_mouse(Vector2(800, 380))
		await _wait(0.4)
	print("V2I giro hasta la puerta: yaw=%.1f" % shell.world.rig.yaw_off)
	_ok(found, "la puerta a la tienda se ve girando la vista con el borde (vista general)")
	# mirar alrededor mientras gira: las etiquetas siguen a los objetos
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.5)
	await _snap("puerta_mirar")
	var before: Array = _label_positions()
	await _sync_mouse(Vector2(1596, 450))
	await _wait(0.8)
	await _sync_mouse(Vector2(800, 380))
	await _wait(0.4)
	var after: Array = _label_positions()
	_ok(before.size() > 0 and after.size() > 0 and str(before) != str(after), "con Espacio y la vista girando, las etiquetas se recalculan")
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.4)
	# volver a apuntar a la puerta y bajar
	for k in 6:
		var pd2 := _node_pos("puerta")
		if pd2.x >= 40.0 and pd2.x <= 1560.0 and String(shell.world.pick(pd2).get("id", "")) == "puerta":
			break
		await _sync_mouse(Vector2(4, 450))
		await _wait(0.6)
		await _sync_mouse(Vector2(800, 380))
		await _wait(0.3)
	var pdoor := _node_pos("puerta")
	await _sync_mouse(pdoor)
	await _wait(0.5)
	await _snap("puerta_hover")
	print("V2I etiqueta de la puerta: «%s»" % gs().hover_label.label_text())
	await _click(pdoor)
	await _wait(1.5)
	await _idle()
	var sc: Dictionary = g.sim.q_scene()
	_ok(String(g.sim.q_clock().phase) == "visit" and String(sc.get("area", "")) == "tienda", "clic en la puerta: la tienda de Crane (%s/%s)" % [String(g.sim.q_clock().phase), String(sc.get("area", ""))])
	await _wait(1.0)
	await _snap("tienda")
	if shell.is_open("scene"):
		await _snap("tienda_banda")
	# mirar alrededor en la tienda
	Input.parse_input_event(e)
	await _wait(0.5)
	await _snap("tienda_mirar")
	print("V2I tienda, etiquetas: %s" % str(gs().hover_label.many_texts()))
	Input.parse_input_event(u)
	await _wait(0.3)
	# Crane
	var cp: Vector2 = gs().char_screen_pos("crane")
	print("V2I Crane en %s" % str(cp))
	if not shell.is_open("scene") and cp.x >= 0.0:
		await _click(cp)
		await _wait(0.8)
	if shell.is_open("scene"):
		await _snap("crane_banda")
		var sp = shell.panel("scene")
		var ask = _find(sp, "Verbo_ask")
		if ask != null and (ask as Control).is_visible_in_tree():
			await _click_ctrl(ask)
			await _wait(0.6)
			await _snap("crane_preguntar")
			var ap = sp.ask_panel
			if ap.visible and ap._list.item_count > 0:
				var items: Array = []
				for i in ap._list.item_count:
					items.append(ap._list.get_item_text(i))
				print("V2I temas de Crane: %s" % str(items))
				_ok(not str(items).contains("Times, The") and not str(items).contains("Watson, John"), "los temas van con su nombre natural, no en forma de catálogo")
				var r: Rect2 = ap._list.get_item_rect(1 if ap._list.is_item_disabled(0) else 0)
				await _click(ap._list.get_global_transform_with_canvas() * r.get_center())
				await _wait(0.3)
				await _click(_c(ap._ok))
				await _wait(2.0)
				await _snap("crane_respuesta")
			if sp.sub_open() != "":
				sp.close_sub()
	# examinar algo en la tienda y alejarse con el botón
	await _clear()
	var pm := _node_pos("mesa_saldos")
	if pm.x >= 0.0:
		await _click(pm)
		await _wait(0.9)
		await _snap("tienda_mesa_novedades")
		var aw = gs()._away_btn
		_ok(aw != null and aw.is_visible_in_tree(), "acercado a un objeto: «‹ Alejarse» a la vista")
		await _clear()
		if aw != null and aw.is_visible_in_tree():
			await _click(_c(aw))
			await _wait(0.8)
		_ok(not shell.world.is_examining(), "«‹ Alejarse» vuelve un paso")
	# subir
	await _clear()
	var lb2 = gs()._leave_btn
	if lb2 != null and lb2.is_visible_in_tree():
		await _click(_c(lb2))
		await _wait(0.8)
		var mm = gs().modal()
		if mm != null:
			var okm := _first_enabled_button(mm, true)
			if okm != null:
				await _click(_c(okm))
		await _wait(1.5)
		await _idle()
	print("V2I tras subir: %s" % String(g.sim.q_clock().phase))
	# un documento con su línea física (la primera carta a máquina)
	if shell.open_reader("R.HA0.3"):
		await _wait(0.8)
		await _snap("documento_fisica")
		await _close_reader()
		await _wait(0.4)
	# terminar los turnos hasta la noche
	for _i in 4:
		var ph2 := String(g.sim.q_clock().phase)
		if ph2 != "desk":
			break
		await _clear()
		await _home_general()
		gs().calendar()
		await _wait(0.6)
		var m2 = gs().modal()
		if m2 != null:
			await _snap("calendario_%s" % String(g.sim.q_clock().slot))
			var ok2 := _first_enabled_button(m2, true)
			if ok2 != null:
				await _click(_c(ok2))
		await _wait(1.5)
		await _idle()
	await _clear()
	await _wait(1.0)
	await _snap("noche")
	print("V2I noche: fase=%s %s" % [String(g.sim.q_clock().phase), String(g.sim.q_clock().slot)])

func _label_positions() -> Array:
	var out: Array = []
	var hl = gs().hover_label
	if hl == null or hl._many == null:
		return out
	for c in hl._many.get_children():
		out.append((c as Control).position.round())
	return out

func _park() -> void:
	await _until(func(): return g.sim != null and gs() != null and gs().idle(), 3000)
	await _wait(2.0)
	print("V2I Park Lane: fase=%s día %d" % [String(g.sim.q_clock().phase), int(g.sim.q_clock().day)])
	_ok(String(g.sim.q_clock().phase) == "parklane", "el guion llega a Park Lane")
	await _snap("park_lane")
	for _i in 6:
		if gs().speech.visible:
			await _click(Vector2(800, 300))
			await _wait(0.8)
	await _snap("park_lane_b")
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.5)
	await _snap("park_lane_mirar")
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.3)
