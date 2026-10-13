# T34 (AFORDANCIAS, GDD_v2 §D.5) — con ventana:
#  - calibración del quad (world/affordance/affordance.gdshader, compila): con el look por defecto, el código 3 (silla
#    bajo el mouse) da un borde detectable POR FUERA de su máscara y el código 2 (lo usable) un filete rojo; sin realce,
#    las capturas con código 1 y con el material original son prácticamente iguales (el código no cambia el dibujo);
#  - con el juego real (SIN --fast) y el mouse real: sobre la silla, contorno + etiqueta «silla» + cursor de lupa; sobre
#    el cuaderno (con su bandera), «Cuaderno · abrir» y la mano; manteniendo Espacio, todas las etiquetas a la vez.
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window t34
extends "res://tests/fixtures/v2cam/window_base.gd"

const WINDOW := true
const TIMEOUT_S := 240.0

const WR = preload("res://world/world_root.gd")
const AFF = preload("res://world/affordance/affordance.gd")

var _wr = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		_wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null
	super.after_each()

func _cap() -> Image:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()

static func _diff_mask(a: Image, b: Image, thr := 0.08) -> Array:
	var out: Array = []
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > thr:
				out.append(Vector2i(x, y))
	return out

func test_calibration_codes_draw_borders() -> void:
	if DisplayServer.get_name() == "headless":
		skip("requiere ventana"); return
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("escritorio", "M")
	for _i in 8: await tree.process_frame
	var ap = _wr.aff_post()
	ok(ap != null and ap.mat.shader != null, "quad de afordancias con su shader")
	# §D.4: la aguada lava menos y lleva más pluma en lo examinable (todo, por igual); para comparar SÓLO el material,
	# el ajuste del look se apaga un momento
	var post = _wr.engraving_post()
	var tweak: bool = post != null and post.has_method("set_param")
	if tweak:
		post.set_param("obj_soften", 1.0)
		post.set_param("obj_line", 1.0)
		for _i in 2: await tree.process_frame
	var base := await _cap()
	# código 1 contra el material original: el código no cambia el dibujo
	var owners: Dictionary = AFF.owners(_wr.diorama)
	for gi in owners["n:silla"]:
		(gi as GeometryInstance3D).material_override = (gi as GeometryInstance3D).get_meta("aff_orig")
	var orig := await _cap()
	AFF.apply(_wr.diorama, {}, "")
	var d0 := _diff_mask(base, orig, 0.06)
	ok(d0.size() < 40, "código 1 ≈ material original (%d píxeles distintos de 360 000 muestreados)" % d0.size())
	if tweak:
		post.set_param("obj_soften", 0.5)
		post.set_param("obj_line", 1.3)
		for _i in 2: await tree.process_frame
		var sharp := await _cap()
		var dd := _diff_mask(base, sharp, 0.04)
		ok(dd.size() > 40, "§D.4: lo examinable se dibuja más nítido que con el look parejo (%d píxeles)" % dd.size())
		base = sharp
	# código 3 bajo el mouse
	var p: Vector2 = _wr.camera().unproject_position(_wr.node_body("silla").global_position)
	_wr.hover_at(p)
	var hov := await _cap()
	ap.set_param("debug_view", 1)
	var mask := await _cap()
	ap.set_param("debug_view", 0)
	var d1 := _diff_mask(base, hov)
	var outside := 0
	for q in d1:
		if mask.get_pixel(q.x, q.y).r < 0.9: outside += 1
	ok(d1.size() > 300, "el realce bajo el mouse se ve (%d píxeles)" % d1.size())
	ok(outside > 150, "con un borde por fuera de la máscara del código 3 (%d píxeles)" % outside)
	# código 2: filete rojo
	_wr.hover_at(Vector2(-20, -20))
	_wr.set_usable({"n:cuaderno": true}, {})
	var use := await _cap()
	var d2 := _diff_mask(base, use)
	var reddish := 0
	for q in d2:
		var c := use.get_pixel(q.x, q.y)
		if c.r > c.g + 0.08 and c.r > c.b + 0.08: reddish += 1
	ok(reddish > 30, "lo usable lleva un filete rojo (%d píxeles rojizos)" % reddish)

func test_hover_label_cursor_and_look_around_with_real_mouse() -> void:
	if not await _boot_day1(): return
	var w = sh.world
	var gs = sh.game_screen
	if w.rig.mode() != "overview":
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _wait(0.6)
	await _focus()
	await _move(_node_pos("silla"))
	await _wait(0.4)
	eq(w.hover_id, "silla", "bajo el mouse: la silla")
	eq(gs.hover_label.label_text(), "silla", "etiqueta «silla»")
	eq(Input.get_current_cursor_shape(), Input.CURSOR_HELP, "cursor de lupa")
	var cu: Array = AFF.owners(w.diorama).get("n:silla", [])
	ok(not cu.is_empty() and AFF.code_of(cu[0]) == 3, "la silla lleva el código 3 (contorno)")
	await _click(_node_pos("escritorio"))
	await _wait(0.7)
	await _focus()
	var qp := _node_pos("cuaderno")
	await _move(qp)
	await _wait(0.4)
	var dbg := "pos %s hover %s/%s modo %s top %s %s" % [str(qp), w.hover_kind, w.hover_id, w.rig.mode(), str(sh.top_kind()), str(w.edge_debug())]
	if w.is_usable("node", "cuaderno"):
		ok(gs.hover_label.label_text().begins_with("Cuaderno · "), "etiqueta «Cuaderno · abrir» (%s; %s)" % [gs.hover_label.label_text(), dbg])
		eq(Input.get_current_cursor_shape(), Input.CURSOR_POINTING_HAND, "mano sobre lo usable")
	await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
	await _wait(0.6)
	await _move(Vector2(800, 420))
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.3)
	ok(gs.looking_around() and gs.hover_label.many_count() >= 5, "Espacio: todas las etiquetas a la vez (%d)" % gs.hover_label.many_count())
	ok(w.reveal_all, "y el contorno de todo lo examinable")
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.2)
	no(gs.looking_around(), "al soltar se va")

# Playtest v2: «‹ Alejarse» enseña a volver (clic derecho/Esc) y un clic en el vacío baja un paso; con Espacio y la vista
# girando, las etiquetas siguen a los objetos; la puerta a la tienda se alcanza girando (vuelta entera en la buhardilla).
func test_back_button_relabel_and_door_with_real_mouse() -> void:
	if not await _boot_day1(): return
	var w = sh.world
	var gs = sh.game_screen
	while w.rig.depth() > 1:
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _wait(0.6)
	await _focus()
	no(gs._away_btn.is_visible_in_tree(), "en la vista general no hay «Alejarse»")
	await _click(_node_pos("escritorio"))
	await _wait(0.7)
	ok(w.rig.depth() > 1 and gs._away_btn.is_visible_in_tree(), "acercado: «‹ Alejarse» a la vista")
	eq(gs._away_btn.tooltip_text, "Clic derecho o Esc", "y su atajo")
	await _click(gs._away_btn.get_global_rect().get_center())
	await _wait(0.7)
	eq(w.rig.depth(), 1, "«‹ Alejarse» vuelve a la vista general")
	# Espacio + girar: las etiquetas se recalculan
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.3)
	var before: Array = []
	for c in gs.hover_label._many.get_children(): before.append((c as Control).position)
	w.rig.look_by(40.0, 0.0)
	await _wait(0.6)
	var after: Array = []
	for c in gs.hover_label._many.get_children(): after.append((c as Control).position)
	ok(not before.is_empty() and str(before) != str(after), "las etiquetas siguen el giro (%d -> %d)" % [before.size(), after.size()])
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.2)
	# la puerta: girar hasta tenerla delante y bajar a la tienda
	w.rig.look_by(180.0 - w.rig.yaw_t, 0.0)
	await _wait(1.0)
	var pd := _node_pos("puerta")
	ok(pd.x >= 0.0 and String(w.pick(pd).get("id", "")) == "puerta", "la puerta se ve dando la vuelta")
	await _move(pd)
	await _wait(0.4)
	ok(gs.hover_label.label_text().begins_with("Puerta · "), "«Puerta · bajar» (%s)" % gs.hover_label.label_text())
