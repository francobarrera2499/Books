# devtools/drivers/w4novato_epi.gd — W4 playtest (diagnóstico): el epílogo con el mouse real, desde la partida del novato
# (registro copiado en user://saves/w4novato_epi.jsonl). Prueba: clic sobre la ficha vs. sobre el fondo; la tijera
# (clic en una oración equivocada, «›» de hoja, clic en la oración buscada); Esc y rueda en el lápiz azul; «Cerrar el libro».
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4novepi res://devtools/drivers/w4novato_epi.gd --mute
extends "res://devtools/drivers/w3int_flow.gd"

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	var src := ProjectSettings.globalize_path("res://").path_join("../.work/w4nov/save_epilogo.jsonl")
	g.save_path = "user://saves/w4novato_epi.jsonl"
	var dst := ProjectSettings.globalize_path(g.save_path)
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	for suf in [".bak", ".tmp"]:
		if FileAccess.file_exists(dst + suf):
			DirAccess.remove_absolute(dst + suf)
	DirAccess.copy_absolute(src, dst)
	await _settle_window()
	shell.show_title()
	await tool.frames(30)
	await _click(_c(_button(shell.screen, Widgets.t("shell.title.continuar"))))
	await _until(func(): return String(shell.screen_id) == "epilogue", 1200)
	await _wait(1.0)
	var epi = shell.screen
	var st: Dictionary = epi.state()
	# ---- hasta la ficha con «Seguir» / clic
	for i in 40:
		st = epi.state()
		if String(st.stage) == "ficha":
			break
		var nb: Button = epi._b_next
		await _click(_c(nb) if nb.is_visible_in_tree() else Vector2(120, 820))
		await _wait(0.5)
	await _wait(0.8)
	await _snap("ficha")
	print("EPI ficha: Seguir visible=%s" % epi._b_next.is_visible_in_tree())
	await _click(Vector2(800, 500))
	await _wait(0.6)
	print("EPI clic sobre la ficha -> estadio %s" % String(epi.state().stage))
	if String(epi.state().stage) == "ficha":
		await _click(Vector2(120, 820))
		await _wait(0.6)
		print("EPI clic en el fondo -> estadio %s" % String(epi.state().stage))
	# ---- hasta la tijera
	for i in 80:
		st = epi.state()
		if String(st.stage) == "tijera":
			break
		if bool(st.get("offer", false)):
			await _snap("oferta")
			print("EPI oferta: %s" % _texts(epi._offer))
			var ob: Button = null
			for b in epi._offer.find_children("*", "Button", true, false):
				if ob == null and (b as Button).is_visible_in_tree():
					ob = b
			await _click(_c(ob))
			await _wait(0.6)
			for c in epi.find_children("*", "", true, false):
				if c.get("ok_button") is Button and (c as CanvasItem).is_visible_in_tree():
					await _snap("oferta_confirma")
					await _click(_c(c.ok_button))
					await _wait(0.6)
					break
			continue
		var nb2: Button = epi._b_next
		await _click(_c(nb2) if nb2.is_visible_in_tree() and not nb2.disabled else Vector2(120, 820))
		await _wait(0.45)
	await _wait(0.8)
	await _snap("tijera")
	var sv = epi._strand
	var cut: Dictionary = epi.cut
	print("EPI tijera: corte=%s hoja actual=%d de %d · texto=%s" % [str({"page": cut.get("page"), "from": cut.get("from"), "to": cut.get("to")}), int(sv.page_idx), sv.page_count(), String(cut.get("text", "")).left(120)])
	await _click(_c(epi._b_tijera))
	await _wait(0.4)
	print("EPI botón Tijera -> tijera=%s" % str(epi.state().scissors))
	# oración equivocada: el primer renglón de la hoja visible
	var pv = sv.page
	var rtl: RichTextLabel = sv._block(pv, 0)
	var p_wrong: Vector2 = rtl.get_global_transform_with_canvas() * Vector2(60, float(rtl.get_line_offset(2)) + 8.0)
	var m0 := int(epi.misses)
	await _click(p_wrong)
	await _wait(0.25)
	await _snap("tijera_equivocada")
	print("EPI clic en otra oración (%s): misses %d -> %d · estadio %s · nota=%s" % [p_wrong.round(), m0, int(epi.misses), String(epi.state().stage), _texts(epi, 4000).find("no es la m") >= 0])
	# a la hoja del corte con «›» (botón de la hoja)
	var guard := 0
	while int(sv.page_idx) != int(cut.get("page", 0)) and guard < 4:
		await _click(_c(sv._b_next))
		await _wait(0.6)
		guard += 1
	print("EPI hoja tras «›»: %d (corte en %d)" % [int(sv.page_idx), int(cut.get("page", 0))])
	await _snap("tijera_hoja_corte")
	pv = sv.page
	var segs: Array = sv.line_segments(pv, int(cut.from), int(cut.to))
	print("EPI renglones del corte: %d" % segs.size())
	if not segs.is_empty():
		var s0: Dictionary = segs[0]
		var local := Vector2((float(s0.x0) + float(s0.x1)) * 0.5, (float(s0.y0) + float(s0.y1)) * 0.5)
		var p_ok: Vector2 = pv.get_global_transform_with_canvas() * local
		_mm(p_ok)
		await tool.frames(3)
		var hv = vp.gui_get_hovered_control()
		print("EPI control bajo el mouse en la oración: %s (filtro %s)" % [str(hv.get_path()) if hv != null else "-", str(hv.mouse_filter) if hv != null else "-"])
		await _click(p_ok)
		await _wait(0.8)
		await _snap("tijera_corte")
		print("EPI clic en la oración del corte (%s) -> estadio %s · misses %d" % [p_ok.round(), String(epi.state().stage), int(epi.misses)])
		if String(epi.state().stage) == "tijera":
			var a2: Vector2 = pv.get_global_transform_with_canvas() * Vector2(float(s0.x0) + 4.0, (float(s0.y0) + float(s0.y1)) * 0.5)
			var b2: Vector2 = pv.get_global_transform_with_canvas() * Vector2(float(s0.x1) - 4.0, (float(s0.y0) + float(s0.y1)) * 0.5)
			await _drag(a2, b2)
			await _wait(0.8)
			print("EPI arrastre sobre la oración del corte -> estadio %s · misses %d" % [String(epi.state().stage), int(epi.misses)])
	if String(epi.state().stage) == "tijera":
		print("EPI FALLA el corte con el mouse no entró; do_cut por API")
		epi.do_cut(int(cut.page), int(cut.from), int(cut.to) - int(cut.from))
		await _wait(1.0)
	# ---- hasta el lápiz azul
	for i in 120:
		st = epi.state()
		if String(st.stage) == "lapiz":
			break
		var nb3: Button = epi._b_next
		await _click(_c(nb3) if nb3.is_visible_in_tree() and not nb3.disabled else Vector2(120, 820))
		await _wait(0.45)
	await _wait(3.0)
	await _snap("lapiz")
	var pen = epi._pencil
	var close_b: Button = pen._close if pen != null else null
	var vs := vp.get_visible_rect().size
	print("EPI lápiz: «Cerrar el libro» rect=%s, pantalla=%s, a la vista=%s" % [close_b.get_global_rect() if close_b != null else "-", vs, Rect2(Vector2.ZERO, vs).encloses(close_b.get_global_rect()) if close_b != null else false])
	await _key(KEY_ESCAPE)
	await _wait(0.6)
	print("EPI Esc en el lápiz -> pantalla=%s arriba=%s" % [shell.screen_id, shell.top_kind()])
	await _snap("lapiz_esc")
	if shell.top_kind() == "options":
		await _key(KEY_ESCAPE)
		await _wait(0.5)
	await _rclick(Vector2(800, 450))
	await _wait(0.6)
	print("EPI clic derecho en el lápiz -> pantalla=%s" % shell.screen_id)
	# rueda hasta ver «Cerrar el libro»
	for i in 30:
		if close_b == null or Rect2(Vector2.ZERO, vs).encloses(close_b.get_global_rect()):
			break
		_mm(Vector2(800, 500))
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.factor = 1.0
		ev.position = Vector2(800, 500)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await tool.frames(3)
	print("EPI rueda: «Cerrar el libro» a la vista=%s rect=%s" % [Rect2(Vector2.ZERO, vs).encloses(close_b.get_global_rect()) if close_b != null else false, close_b.get_global_rect() if close_b != null else "-"])
	await _snap("lapiz_abajo")
	if close_b != null:
		await _click(_c(close_b))
		await _wait(2.5)
	await _snap("despues_cerrar")
	print("EPI tras «Cerrar el libro»: pantalla=%s sim=%s" % [shell.screen_id, g.sim != null])

func _texts(n, maxlen := 700) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var parts: Array = []
	for c in n.find_children("*", "", true, false):
		if not (c is CanvasItem) or not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is RichTextLabel:
			parts.append((c as RichTextLabel).get_parsed_text())
		elif c is Label:
			parts.append((c as Label).text)
		elif c is Button:
			parts.append("[" + (c as Button).text + "]")
	return " · ".join(parts).left(maxlen)

func _snap(name: String) -> void:
	_shot += 1
	await tool.snap("%02d_%s" % [_shot, name])
