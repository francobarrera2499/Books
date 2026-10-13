# W3-NOTEBOOK: flujo completo del cuaderno con el mouse de verdad (ventana), sobre la GameSim real del recorrido de
# integración: arrastrar un recorte sobre otro -> nota -> «Cotejar» -> Cotejos; Diario: tijera -> arrastrar sobre un
# renglón -> la tira vuela a Recortes; Índice: arrastrar un chip a la pestaña Recortes -> filtrado; Esc cierra.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3notebook res://devtools/drivers/w3notebook_flujo.gd
# Capturas (.work/shots/w3notebook_flujo_<n>.png): 1_arrastre, 2_nota, 3_cotejos, 4_tijera, 5_vuelo, 6_recortes,
#   7_chip, 8_filtrado. Imprime FLUJO OK|FALLA por paso.
extends RefCounted

const Notebook = preload("res://ui/notebook/notebook.gd")
const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const Paper = preload("res://ui/kit/paper.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

var tool
var nb
var sim
var _last := Vector2.ZERO

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	sim = NbWalk.sim()
	if sim == null:
		print("SIN RECORRIDO ", NbWalk.errs)
		return
	var bg := ColorRect.new()
	bg.color = Paper.MESA
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(bg)
	var layer := CanvasLayer.new()
	layer.layer = 20
	scene.add_child(layer)
	nb = Notebook.new()
	nb.sim_override = sim
	nb.act_fn = func(a): return sim.apply(a)
	nb.sounds = false
	layer.add_child(nb)
	await _settle_window()
	nb.open("recortes")
	await tool.frames(10)
	# 1. recorte sobre recorte
	var page = nb.page("recortes")
	var pa: Vector2 = page.card("RC0007").strip.get_global_rect().get_center()
	var pb: Vector2 = page.card("RC0002").strip.get_global_rect().get_center()
	await _press_drag(pa, pb)
	await tool.snap("flujo_1_arrastre")
	await _release(pb)
	await tool.frames(6)
	var form = nb.overlay_panel()
	_check(form != null, "formulario al soltar")
	if form == null:
		return
	var le: LineEdit = form.get_meta("note_edit")
	await _click(le.get_global_rect().get_center())
	for ch in "contradice":
		var k := InputEventKey.new()
		k.unicode = ch.unicode_at(0)
		k.keycode = OS.find_keycode_from_string(ch.to_upper())
		k.pressed = true
		Input.parse_input_event(k)
		await tool.frames(1)
		var ku := k.duplicate()
		ku.pressed = false
		Input.parse_input_event(ku)
	await tool.frames(3)
	await tool.snap("flujo_2_nota")
	var n0: int = sim.q_pairs().size()
	await _click(form.ok_button.get_global_rect().get_center())
	await tool.frames(6)
	_check(sim.q_pairs().size() == n0 + 1, "par creado con el mouse")
	_check(String(sim.q_pairs()[sim.q_pairs().size() - 1].note) == "contradice", "nota tecleada")
	await _click(nb._tab_buttons["cotejos"].get_global_rect().get_center())
	await tool.frames(8)
	_hide_note()
	await tool.snap("flujo_3_cotejos")
	# 2. tijera en el diario
	await _click(nb._tab_buttons["diario"].get_global_rect().get_center())
	await tool.frames(8)
	var d = nb.page("diario")
	await _click(d._b_tijera.get_global_rect().get_center())
	await tool.frames(3)
	_check(d.scissors, "tijera en la mano (botón)")
	var eid := ""
	for id in d.row_ids():
		if eid == "" and String(d.parsed_of(id).get("plain", "")).contains("Le escribí al señor Mycroft"):
			eid = id
	var rt: RichTextLabel = d.rtl_of(eid)
	d._scroll.ensure_control_visible(rt)
	await tool.frames(6)
	var plain: String = d.parsed_of(eid).plain
	var pts := SelectionMapper.drag_points(rt, 0, plain.length())
	var c0: int = sim.q_clips().size()
	await _press_drag(pts[0], pts[1])
	await tool.create_timer(0.15).timeout
	await tool.snap("flujo_4_tijera")
	await _release(pts[1])
	await tool.frames(3)
	await tool.snap("flujo_5_vuelo")
	_check(sim.q_clips().size() == c0 + 1, "recorte del diario con el mouse")
	await tool.create_timer(0.5).timeout
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await tool.frames(2)
	_check(not d.scissors and nb.is_open(), "Esc deja la tijera y el cuaderno sigue abierto")
	await _click(nb._tab_buttons["recortes"].get_global_rect().get_center())
	await tool.frames(8)
	var sc: ScrollContainer = page._scroll
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await tool.frames(6)
	_hide_note()
	await tool.snap("flujo_6_recortes")
	# 3. chip del índice a la pestaña Recortes
	await _click(nb._tab_buttons["indice"].get_global_rect().get_center())
	await tool.frames(8)
	var chip: Control = nb.page("indice").chip("pared")
	var p0 := chip.get_global_rect().get_center()
	var p1: Vector2 = nb._tab_buttons["recortes"].get_global_rect().get_center()
	await _press_drag(p0, p1)
	await tool.snap("flujo_7_chip")
	await _release(p1)
	await tool.frames(8)
	_check(nb.tab == "recortes" and String(nb.filters.get("ent", "")) == "pared", "chip soltado en la pestaña filtra")
	await tool.snap("flujo_8_filtrado")
	var esc2 := InputEventKey.new()
	esc2.keycode = KEY_ESCAPE
	esc2.pressed = true
	Input.parse_input_event(esc2)
	await tool.frames(16)
	_check(not nb.is_open(), "Esc cierra el cuaderno")

func _check(c: bool, what: String) -> void:
	print("FLUJO %s %s" % ["OK" if c else "FALLA", what])

func _hide_note() -> void:
	if nb._note_tw != null and nb._note_tw.is_valid():
		nb._note_tw.kill()
	nb._note.visible = false

func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	var last := DisplayServer.window_get_position()
	var still := 0
	for _i in 120:
		await tool.frames(1)
		var p := DisplayServer.window_get_position()
		still = still + 1 if p == last else 0
		last = p
		if still >= 10 and DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = pos - _last
	e.button_mask = mask
	_last = pos
	Input.parse_input_event(e)

func _mb(pos: Vector2, pressed: bool) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func _click(p: Vector2) -> void:
	_mm(p, 0)
	await tool.frames(2)
	_mb(p, true)
	await tool.frames(1)
	_mb(p, false)
	await tool.frames(2)

func _press_drag(a: Vector2, b: Vector2) -> void:
	_mm(a, 0)
	await tool.frames(2)
	_mb(a, true)
	await tool.frames(2)
	for i in range(1, 15):
		_mm(a.lerp(b, float(i) / 14.0))
		await tool.frames(1)
	_mm(b)
	await tool.frames(3)

func _release(b: Vector2) -> void:
	_mb(b, false)
	await tool.frames(2)
