# W3-SHELL: flujo completo con capturas sobre main.tscn (ARCHITECTURE §10 ola 3, §9.4).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3shell res://devtools/drivers/w3shell_flujo.gd
# Título -> partida nueva -> prólogo (tutorial por Game.act; el lector con la tijera) -> dormir -> ritual del amanecer ->
# escritorio y bandeja -> encuadres -> examinar -> atajos (Tab, L, C, Esc) -> mapa (Baedeker, áreas, viaje) -> visita
# (Watson) -> presentar arrastrando al 3D (mouse real por Input) -> volver -> mapa con persianas -> cerrar franjas ->
# noche -> dormir -> amanecer -> domingo (persianas con su motivo) -> Esc: opciones.
# Dataset: data/ estructural + tests/fixtures/integ (Fallback.data_repo("fixture")), mientras el contenido real esté a
# medio escribir. Capturas: .work/shots/w3shell_<n>.png. Imprime «W3SHELL OK|FALLA <paso>» y un resumen.
extends RefCounted

const Fallback = preload("res://ui/desk/fallback.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")
const Chips = preload("res://ui/drag/chips.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Layers = preload("res://ui/layers.gd")

var tool
var shell
var gs
var g
var fails := 0
var _last := Vector2.ZERO

func _p(msg: String) -> void:
	print("[w3shell] ", msg)

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("W3SHELL %s %s" % ["OK" if c else "FALLA", what])

func act(a: Dictionary) -> Dictionary:
	return g.act(a)

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(4)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	if shell == null:
		_p("sin Shell")
		return
	await tool.frames(30)
	await tool.snap("01_titulo")
	g.repo_override = Fallback.data_repo("fixture")
	g.save_path = "user://saves/w3shell_flujo.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	shell.new_game(1894)
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 900)
	gs = shell.game_screen
	await _settle(30)
	_check(String(g.sim.q_clock().phase) == "prologue", "partida nueva -> prólogo")
	await tool.snap("02_prologo")
	gs.go_frame("ventana")
	await _settle(40)
	await tool.snap("03_prologo_ventana")
	gs.go_frame(String(gs.frames()[0]))
	await _settle(30)
	# el encargo en el lector, con la tijera
	shell.open_reader("D23@L1")
	await _settle(20)
	shell.reader.set_tijera(true)
	await _settle(6)
	await tool.snap("04_lector_tijera")
	shell.pop()
	shell.pop()
	await _settle(10)
	W.tutorial(g.sim, act)
	_check(W.errs.is_empty(), "tutorial: %s" % str(W.errs))
	await _idle()
	await _settle(30)
	await tool.snap("05_prologo_listo")
	# dormir (calendario, dos pasos) -> ritual del amanecer
	gs.calendar()
	await _settle(10)
	_check(gs.modal() != null, "dormir pide confirmación")
	await tool.snap("06_dormir_confirma")
	_confirm(gs.modal())
	await _until(func(): return shell.get_node_or_null("Layer_fade/Root/Dawn") != null or Layers.root_of(shell.layers.fade).get_child_count() > 1, 240)
	await tool.frames(40)
	await tool.snap("07_amanecer")
	await _idle()
	await _settle(20)
	_check(String(g.sim.q_clock().phase) == "desk" and int(g.sim.q_clock().day) == 1, "amanecer -> escritorio del martes")
	_check(shell.is_open("tray"), "la bandeja se abre sola")
	await tool.snap("08_bandeja")
	shell.pop()
	await _settle(20)
	await tool.snap("09_escritorio")
	gs.go_frame("ventana")
	await _settle(40)
	await tool.snap("10_ventana")
	gs.go_frame("pared")
	await _settle(40)
	await tool.snap("11_pared")
	gs.go_frame("escritorio")
	await _settle(40)
	gs.on_node("tomos")
	await _settle(20)
	_check(gs.exam.visible, "examinar los tomos")
	await tool.snap("12_examinar_tomos")
	gs.back()
	await _settle(8)
	# atajos: Tab (cuaderno) + L (libro mayor) = dos libros; C (tijera); Esc
	await _key(KEY_TAB)
	await _key(KEY_L)
	await _settle(20)
	_check(shell.is_open("notebook") and shell.is_open("ledger"), "Tab y L: dos libros")
	await tool.snap("13_dos_libros")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _settle(10)
	_check(shell.top() == null, "Esc cierra de arriba hacia abajo")
	await _key(KEY_C)
	await _settle(6)
	_check(gs.scissors_on, "C: tijera sobre el diorama")
	await _drag_free(Vector2(640, 500), Vector2(860, 610), true)
	await tool.frames(2)
	await tool.snap("14_tijera_rect")
	_btn(Vector2(860, 610), false)
	await _settle(20)
	await tool.snap("14b_tijera_recorte")
	await _key(KEY_ESCAPE)
	await _settle(6)
	# mapa -> Kensington
	await _key(KEY_M)
	await _settle(30)
	var ms = shell.panel("map")
	_check(ms != null and ms.visible, "M: mapa")
	await tool.snap("15_mapa")
	var mk = ms.marker("L4")
	await _click(mk.get_global_rect().position + mk.get_meta("origin", Vector2(12, 12)))
	await _settle(12)
	await tool.snap("16_mapa_areas")
	var consulta := {}
	for a in ms.place_state("L4").areas:
		if String(a.area) == "consulta":
			consulta = a
	ms._confirm_go(consulta)
	await _settle(12)
	await tool.snap("17_mapa_confirma")
	_confirm(ms._popup)
	await tool.frames(70)
	await tool.snap("18_viaje")
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 900)
	await _idle()
	await _settle(40)
	_check(String(g.sim.q_clock().phase) == "visit" and gs.cur_place == "L4", "visita a Kensington")
	await tool.snap("19_visita_l4")
	# presentar arrastrando un recorte sobre Watson (mouse real: Input)
	var sp = shell.panel("scene")
	if sp != null and sp.has_method("close_sub"):
		sp.close_sub()
	await _settle(6)
	var pos: Vector2 = gs.char_screen_pos("watson")
	_check(pos.x >= 0.0, "Watson en pantalla %s" % str(pos))
	var src := Control.new()
	src.position = Vector2(60, 300)
	src.size = Vector2(40, 30)
	Layers.root_of(shell.layers.hud).add_child(src)
	var clip_id := String(g.sim.q_clips()[1].id) if (g.sim.q_clips() as Array).size() > 1 else "RC0001"
	var data := Chips.data("clip", clip_id)
	_mm(Vector2(80, 315))
	await tool.frames(2)
	src.force_drag(data, Widgets.chip(Chips.label(data), data))
	for k in range(1, 16):
		_mm(Vector2(80, 315).lerp(pos, float(k) / 15.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	await tool.frames(4)
	_check(shell.drop_catcher.armed, "DropCatcher3D activo en la visita")
	await tool.snap("20_arrastre_3d")
	var got := []
	shell.drop_catcher.present_requested.connect(func(cid, _d): got.append(cid), CONNECT_ONE_SHOT)
	# el puntero real del sistema puede moverse durante una corrida con ventana: se reafirma la posición antes de soltar
	_mm(pos, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(2)
	var hov = scene.get_viewport().gui_get_hovered_control()
	_p("antes de soltar: arrastrando=%s char=%s hover=%s" % [scene.get_viewport().gui_is_dragging(), shell.drop_catcher.char_at(pos), str(hov.get_path()) if hov != null else ""])
	# el SO puede mandar su propio movimiento (warp) entre cuadros con otra escala de ventana: se reafirma y se suelta ya
	_mm(pos, MOUSE_BUTTON_MASK_LEFT)
	# Godot suelta donde está el puntero del SO (Viewport.get_mouse_position); si la ventana de la corrida no tiene el foco,
	# warp_mouse no lo mueve y el soltar caería en otro lado: se avisa y se suelta por el mismo camino del motor.
	var vpm: Vector2 = scene.get_viewport().get_mouse_position()
	if vpm.distance_to(pos) > 2.0:
		_p("AVISO sin foco: puntero del SO en %s, no en %s; soltar por código" % [vpm, pos])
		var dc = shell.drop_catcher
		var dd = scene.get_viewport().gui_get_drag_data()
		if dc._can_drop_data(pos - dc.global_position, dd):
			dc._drop_data(pos - dc.global_position, dd)
		scene.get_viewport().gui_cancel_drag()
	else:
		_btn(pos, false)
	await _settle(12)
	_check(got == ["watson"], "soltar sobre Watson pide presentar (%s)" % str(got))
	if sp != null and "present_bar" in sp and sp.present_bar != null:
		_check(sp.present_bar.visible, "soltar sobre Watson -> frase de Lisle con Mostrar / Guardar")
	await tool.snap("21_presentar")
	if sp != null and "present_bar" in sp and sp.present_bar != null and sp.present_bar.visible:
		sp.present_bar.keep()
	src.queue_free()
	await _settle(8)
	# volver a casa
	gs._leave(false)
	await _settle(10)
	_check(gs.modal() != null, "volver pide confirmación")
	await tool.snap("22_volver_confirma")
	_confirm(gs.modal())
	await _idle()
	await _settle(30)
	_check(String(g.sim.q_clock().phase) == "desk", "de vuelta en el escritorio")
	await tool.snap("23_vuelta")
	await _key(KEY_M)
	await _settle(30)
	await tool.snap("24_mapa_persianas")
	# láminas de lo visto: la de Kensington, a mirar y recortar otra vez
	ms = shell.panel("map")
	await _click(ms.plates_tab.get_global_rect().get_center())
	await _settle(12)
	await tool.snap("24b_laminas")
	var lb: Button = null
	for b in ms.find_children("Lamina_*", "Button", true, false):
		if String(b.get_meta("plate", "")) == "PL.L4.1.M":
			lb = b
	_check(lb != null, "lámina de Kensington en la lista")
	if lb != null:
		await _click(lb.get_global_rect().get_center())
		await _idle()
		await _settle(40)
		_check(gs._doc_plate and gs.cur_plate == "PL.L4.1.M", "lámina archivada en el 3D")
		await tool.snap("24c_lamina_l4")
		await _click(gs._leave_btn.get_global_rect().get_center())
		await _settle(30)
		_check(not gs._doc_plate, "«Dejar la lámina»")
	# cerrar franjas: M -> T -> N -> noche
	gs.calendar()
	await _settle(10)
	await tool.snap("25_cerrar_franja")
	_confirm(gs.modal())
	await _idle()
	await _settle(20)
	# Sala de Lectura por la tarde: asiento, catálogo, papeleta (comprometida, dos pasos) -> lector
	await _key(KEY_M)
	await _settle(30)
	ms = shell.panel("map")
	var sala: Dictionary = ms.place_state("L2").areas[0]
	ms._confirm_go(sala)
	await _settle(12)
	await tool.snap("26_mapa_asiento")
	_confirm(ms._popup)
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 900)
	await _idle()
	await _settle(40)
	_check(gs.cur_place == "L2", "Sala de Lectura")
	await tool.snap("27_sala_lectura")
	gs.on_node("catalogo")
	await _settle(20)
	var cat = gs.catalog
	_check(cat.visible, "catálogo abierto")
	var pedir: Button = null
	for x in g.sim.q_index():
		cat._search(String(x.id))
		await _settle(4)
		for b in cat.results.find_children("*", "Button", true, false):
			if (b as Button).text == Widgets.t("shell.cat.pedir"):
				pedir = b
		if pedir != null:
			break
	await _settle(8)
	await tool.snap("28_catalogo")
	# en el dataset de prueba el catálogo apenas tiene fichas: si ninguna se sirve en sala, la papeleta de D05 (el
	# mismo camino del botón «Pedir»: confirmación en dos pasos -> slip -> lector)
	if pedir != null:
		await _click(pedir.get_global_rect().get_center())
	else:
		cat._ask_slip("D05", String(g.sim.repo.doc("D05").get("title", "D05")))
	if true:
		await _settle(10)
		_check(cat.confirm_panel() != null, "papeleta: confirmación con el asiento")
		await tool.snap("29_papeleta")
		var n_slip: int = g.sim.actions_log().size()
		_confirm(cat.confirm_panel())
		await _settle(30)
		_check(g.sim.actions_log().size() == n_slip + 1 and shell.reader_open() and not cat.visible, "papeleta -> el libro en el lector (el catálogo se aparta)")
		await tool.snap("30_papeleta_lector")
	await _key(KEY_ESCAPE)
	await _settle(20)
	_check(cat.visible, "al cerrar el lector vuelve el catálogo")
	await tool.snap("30b_catalogo_mesa")
	await _key(KEY_ESCAPE)
	await _settle(8)
	gs._leave(false)
	await _settle(6)
	_confirm(gs.modal())
	await _idle()
	for i in 2:
		gs.calendar()
		await _settle(6)
		_confirm(gs.modal())
		await _idle()
	await _settle(30)
	_check(String(g.sim.q_clock().phase) == "night", "noche")
	await tool.snap("31_noche")
	gs.calendar()
	await _settle(8)
	_confirm(gs.modal())
	await _until(func(): return Layers.root_of(shell.layers.fade).get_child_count() > 1, 240)
	await tool.frames(150)
	await tool.snap("32_amanecer_2")
	await _idle()
	await _settle(30)
	_check(int(g.sim.q_clock().day) == 2, "miércoles")
	await tool.snap("33_dia2")
	shell.close_all()
	# domingo: persianas con su motivo
	W.advance_to(g.sim, act, 6, "T")
	await _idle()
	await _settle(30)
	shell.close_all()
	await _settle(4)
	_check(String(g.sim.q_clock().weekday) == "dom", "domingo 1 de abril")
	await _key(KEY_M)
	await _settle(30)
	ms = shell.panel("map")
	var l2 = ms.marker("L2")
	_check(l2 != null and not l2.is_open(), "la Sala de Lectura con persiana el domingo")
	var n0: int = g.sim.actions_log().size()
	var at: Vector2 = l2.get_global_rect().position + l2.get_meta("origin", Vector2(12, 12))
	_mm(at)
	await _settle(6)
	await _click(at)
	await _settle(6)
	_check(g.sim.actions_log().size() == n0, "clic en la persiana: nada")
	await tool.snap("34_mapa_domingo")
	await _key(KEY_ESCAPE)
	await _settle(6)
	gs.speech.clear()
	gs.exam.hide_card()
	await _key(KEY_ESCAPE)
	await _settle(30)
	_check(shell.top_kind() == "options", "Esc sin nada que cerrar: opciones")
	await tool.snap("35_opciones")
	_p("RESUMEN %d fallas" % fails)
	g.end_session()

# ------------------------------------------------------------------ utilidades
func _confirm(m) -> void:
	if m == null:
		_p("sin modal")
		return
	var c = m
	if not c.has_signal("decided"):
		for ch in m.find_children("*", "", true, false):
			if ch.has_signal("decided"):
				c = ch
				break
	if c.has_signal("decided"):
		c.decided.emit(true)
	else:
		_p("modal sin decided")

func _settle(n := 12) -> void:
	await tool.frames(n)

func _idle(max_frames := 1200) -> void:
	await tool.frames(3)
	await _until(func(): return gs != null and gs.idle(), max_frames)

func _until(f: Callable, max_frames: int) -> void:
	var i := 0
	while not f.call() and i < max_frames:
		await tool.frames(1)
		i += 1
	if i >= max_frames:
		_p("timeout esperando condición")

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await tool.frames(2)
	var u := InputEventKey.new()
	u.keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await tool.frames(4)

func _mm(pos: Vector2, mask := 0) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last
	ev.button_mask = mask
	_last = pos
	Input.parse_input_event(ev)

func _btn(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	_mm(p)
	await tool.frames(3)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(3)

# Arrastre libre (rectángulo de la tijera); release=false deja la captura con el rectángulo a la vista y lo suelta luego.
func _drag_free(a: Vector2, b: Vector2, snap_before_release := false) -> void:
	_mm(a)
	await tool.frames(2)
	_btn(a, true)
	await tool.frames(2)
	for k in range(1, 10):
		_mm(a.lerp(b, float(k) / 9.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	if snap_before_release:
		return
	_btn(b, false)
	await tool.frames(8)
