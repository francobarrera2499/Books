# W3-NOTEBOOK: capturas del cuaderno sobre la GameSim REAL del recorrido de integración (datos reales + fixtures/integ),
# del prólogo al amanecer del día 4 (17 recortes, un par, diario con llegadas y líneas dichas).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3notebook res://devtools/drivers/w3notebook_shots.gd
# Capturas (.work/shots/w3notebook_<nombre>.png): recortes, filtro_persona, busqueda, menu_fecha, indice, cotejo_form,
#   cotejos, diario, diario_tijera (selección real con eventos de mouse), diario_recortado, marginalia, vacio,
#   izquierda (con el libro mayor al lado), izquierda_16 / izquierda_16_cotejos (acoplado con texto 1,6×),
#   hc (alto contraste), escala (texto 1,3×).
extends RefCounted

const Notebook = preload("res://ui/notebook/notebook.gd")
const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const Paper = preload("res://ui/kit/paper.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

var tool
var nb
var sim

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	sim = NbWalk.sim()
	if sim == null:
		print("SIN RECORRIDO ", NbWalk.errs)
		return
	var repo = NbWalk.repo()
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
	await tool.frames(2)
	nb.open("recortes")
	await _settle()
	await tool.snap("recortes")
	var sc: ScrollContainer = nb.page("recortes")._scroll
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _settle()
	await tool.snap("recortes_fin")
	sc.scroll_vertical = 0
	nb.filter_entity("watson")
	await _settle()
	await tool.snap("filtro_persona")
	nb.clear_filters()
	nb.page("recortes")._search.text = "pared"
	nb.page("recortes")._search.text_changed.emit("pared")
	await _settle()
	await tool.snap("busqueda")
	nb.page("recortes")._search.text = ""
	nb.page("recortes")._search.text_changed.emit("")
	var mb: MenuButton = nb.page("recortes")._menus["fecha"]
	mb.show_popup()
	await _settle()
	await tool.snap("menu_fecha")
	mb.get_popup().hide()
	nb.show_tab("indice")
	await _settle()
	await tool.snap("indice")
	nb.show_tab("recortes")
	await _settle()
	nb.request_link("RC0007", "RC0002")
	await _settle()
	var form = nb.overlay_panel()
	if form != null:
		form.get_meta("note_edit").text = "contradice"
	await tool.snap("cotejo_form")
	if form != null:
		form._decide(true)
	await _settle()
	await tool.snap("cotejado")
	_hide_note()
	nb.show_tab("cotejos")
	await _settle()
	await tool.snap("cotejos")
	nb.show_tab("diario")
	await _settle()
	await tool.snap("diario")
	nb._set_scissors(true)
	await _settle()
	var d = nb.page("diario")
	var eid := ""
	for id in d.row_ids():
		if eid == "" and String(d._rows[id].entry.get("kind", "")) == "line" and String(d.parsed_of(id).get("plain", "")).contains("Era un"):
			eid = id
	if eid != "":
		var rt: RichTextLabel = d.rtl_of(eid)
		d._scroll.ensure_control_visible(rt)
		await _settle()
		var plain: String = d.parsed_of(eid).plain
		var k := plain.find("Era")
		var e := plain.find(".", k) + 1
		var pts := SelectionMapper.drag_points(rt, k, e)
		await _drag(pts[0], pts[1], false)
		await tool.frames(2)
		await tool.snap("diario_tijera")
		await _mouse_up(pts[1])
		await tool.frames(3)
		await tool.snap("diario_recortado")
		_hide_note()
		print("DIARIO_CLIP ", nb.page("recortes") != null, " clips=", sim.q_clips().size())
	nb._set_scissors(false)
	sim.st.world.eggs["EE01"] = {"tk": 41}
	nb.refresh()
	nb.show_tab("marginalia")
	await _settle()
	await tool.snap("marginalia")
	nb.set_layout("left")
	nb.backdrop = false
	nb.show_tab("recortes")
	var ledger := Panel.new()
	ledger.position = Vector2(820, 26)
	ledger.size = Vector2(760, 850)
	ledger.add_theme_stylebox_override("panel", Paper.style("libro_mayor", {}))
	layer.add_child(ledger)
	layer.move_child(ledger, 0)
	nb._layout()
	nb.refresh()
	await _settle()
	await tool.snap("izquierda")
	# acoplado con el texto al máximo de accesibilidad: pestañas, filtros y tiras dentro del libro
	var ti0 = scene.get_tree().root.get_node("ThemeInstaller")
	ti0.set_text_scale(1.6)
	await _settle()
	await tool.snap("izquierda_16")
	nb.show_tab("cotejos")
	await _settle()
	await tool.snap("izquierda_16_cotejos")
	ti0.set_text_scale(1.0)
	nb.show_tab("recortes")
	await _settle()
	ledger.queue_free()
	nb.set_layout("full")
	nb.backdrop = true
	nb._layout()
	var ti = scene.get_tree().root.get_node("ThemeInstaller")
	ti.set_high_contrast(true)
	await _settle()
	await tool.snap("hc")
	ti.set_high_contrast(false)
	ti.set_text_scale(1.3)
	nb.show_tab("recortes")
	await _settle()
	await tool.snap("escala")
	ti.set_text_scale(1.0)
	# cuaderno vacío (prólogo recién empezado)
	var GameSim = load("res://core/sim/game_sim.gd")
	var fresh = GameSim.new(repo, 7)
	nb.sim_override = fresh
	nb.act_fn = func(a): return fresh.apply(a)
	nb.clear_filters()
	nb.refresh()
	nb.show_tab("recortes")
	await _settle()
	await tool.snap("vacio")
	nb.close()
	await tool.frames(4)

func _hide_note() -> void:
	if nb._note_tw != null and nb._note_tw.is_valid():
		nb._note_tw.kill()
	nb._note.visible = false
	# la tira que vuela a Recortes (0,4 s) no debe quedar a medio camino en la captura siguiente
	for c in nb._fly.get_children():
		c.queue_free()

func _settle() -> void:
	await tool.frames(8)

# Selección real: el RichTextLabel extiende la selección con la posición REAL del mouse (como w2reader_t19).
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

func _sync_mouse(pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		Input.warp_mouse(pos)
		await tool.frames(1)
		if tool.root.get_viewport().get_mouse_position().distance_to(pos) < 1.5:
			return

func _mb(pos: Vector2, pressed: bool) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func _mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = mask
	Input.parse_input_event(e)

func _drag(a: Vector2, b: Vector2, release := true) -> void:
	await _settle_window()
	await _sync_mouse(a)
	_mm(a, 0)
	await tool.frames(1)
	_mb(a, true)
	await tool.frames(2)
	for i in range(1, 11):
		var p := a.lerp(b, float(i) / 10.0)
		_mm(p)
		await tool.frames(1)
	await _sync_mouse(b)
	_mm(b)
	await tool.frames(2)
	if release:
		await _mouse_up(b)

func _mouse_up(b: Vector2) -> void:
	_mb(b, false)
	await tool.frames(2)
