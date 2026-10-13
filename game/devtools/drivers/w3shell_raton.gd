# W3-SHELL (verificación): el mismo recorrido que un jugador nuevo, SOLO con el mouse real (Input.parse_input_event):
# título (clic en «Partida nueva») -> prólogo (clic en el encargo del 3D -> tarjeta -> enlace -> lector; clic derecho
# cierra) -> calendario (clic) -> «Dormir» (clic) -> bandeja (clic en un papel -> lector; «Cerrar») -> mapa (cerrar con su
# botón; reabrir) -> marcador (clic) -> área (clic) -> «Ir» (clic) -> visita -> cinta «Cuaderno» (clic) -> arrastrar un
# recorte del cuaderno sobre Watson -> «Guardar» -> calendario -> «Volver a casa» (clic) -> escritorio.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3raton res://devtools/drivers/w3shell_raton.gd
extends RefCounted

const Fallback = preload("res://ui/desk/fallback.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

var tool
var shell
var gs
var g
var vp: Viewport
var fails := 0
var _last := Vector2.ZERO

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("W3RATON %s %s" % ["OK" if c else "FALLA", what])

func act(a: Dictionary) -> Dictionary:
	return g.act(a)

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(30)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	vp = scene.get_viewport()
	g.repo_override = Fallback.data_repo("fixture")
	g.save_path = "user://saves/w3shell_raton.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	# ---- título: clic en «Partida nueva»
	var title = shell.screen
	var bn := _button(title, Widgets.t("shell.title.nueva"))
	_check(bn != null, "título: botón «Partida nueva»")
	if bn == null:
		return
	await _click(_c(bn))
	await tool.frames(6)
	if title != null and is_instance_valid(title) and title.get("_confirm") != null and is_instance_valid(title._confirm):
		await _click(_c(_button(title._confirm, Widgets.t("shell.title.nueva_ok"))))
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 900)
	gs = shell.game_screen
	await tool.frames(30)
	_check(gs != null and String(g.sim.q_clock().phase) == "prologue", "clic -> prólogo")
	await tool.snap("01_prologo")
	# ---- clic en el encargo (3D) -> tarjeta -> enlace -> lector
	var ep := _node_pos("encargo")
	print("[raton] encargo en ", ep, " pick=", shell.world.pick(ep))
	await _click(ep)
	await tool.frames(20)
	_check(gs.exam.visible, "clic en el encargo: tarjeta de examen")
	await tool.snap("02_encargo")
	var links: Array = gs.exam.links_box.get_children().filter(func(b): return b is Button)
	print("[raton] enlaces: ", links.map(func(b): return b.text))
	if not links.is_empty():
		await _click(_c(links[0]))
		await tool.frames(20)
	_check(shell.reader_open(), "enlace de la tarjeta -> lector")
	await tool.snap("03_lector")
	await _rclick(Vector2(800, 450))
	await tool.frames(20)
	_check(not shell.reader_open(), "clic derecho cierra el lector")
	# ---- tutorial (acciones) y dormir con clics
	W.tutorial(g.sim, act)
	await _idle()
	await tool.frames(20)
	await _click(_c(gs.hud.card))
	await tool.frames(12)
	_check(gs.modal() != null, "clic en el calendario: dormir pide confirmación")
	await tool.snap("04_dormir")
	if gs.modal() != null:
		await _click(_c(_button(gs.modal(), Widgets.t("shell.cal.dormir"), true)))
	await _until(func(): return String(g.sim.q_clock().phase) == "desk", 600)
	await _idle()
	await tool.frames(20)
	_check(shell.is_open("tray"), "amanecer -> bandeja")
	# ---- bandeja: clic en un papel -> lector; clic derecho; «Cerrar»
	var rows: Array = gs.tray.list.get_children()
	if not rows.is_empty():
		await _click(_c(rows[0]))
		await tool.frames(20)
	_check(shell.reader_open(), "clic en un papel de la bandeja -> lector")
	await _rclick(Vector2(800, 450))
	await tool.frames(20)
	_check(not shell.reader_open() and gs.tray.visible, "clic derecho: vuelve a la bandeja")
	await _click(_c(_button(gs.tray, Widgets.t("kit.close"))))
	await tool.frames(12)
	_check(not gs.tray.visible, "«Cerrar» la bandeja")
	await tool.snap("05_escritorio")
	# ---- encuadres con los chevrones (clic)
	var f0 := String(gs.frame)
	await _click(_c(gs._chev_r))
	await tool.frames(40)
	_check(String(gs.frame) != f0, "chevrón: otro encuadre (%s -> %s)" % [f0, gs.frame])
	await tool.snap("06_encuadre")
	# el mapa de la pared (3D) si está en este encuadre; si no, M
	var mp := _node_pos("mapa")
	if mp.x >= 0.0 and String(shell.world.pick(mp).get("id", "")) == "mapa":
		await _click(mp)
	else:
		print("[raton] mapa no visible en ", gs.frame, ": tecla M")
		await _key(KEY_M)
	await tool.frames(30)
	var ms = shell.panel("map")
	_check(ms != null and ms.visible, "mapa abierto")
	# cerrar el mapa con el mouse (botón propio)
	var cb := _button(ms, Widgets.t("shell.map.volver")) if ms != null else null
	_check(cb != null, "el mapa tiene un botón para cerrarlo")
	if cb != null:
		await _click(_c(cb))
		await tool.frames(20)
		_check(not ms.visible, "«Cerrar el mapa»")
		await _key(KEY_M)
		await tool.frames(30)
	await tool.snap("07_mapa")
	# ---- Kensington: marcador -> área -> Ir (clics)
	var mk = ms.marker("L4")
	await _click(mk.get_global_rect().position + mk.get_meta("origin", Vector2(12, 12)))
	await tool.frames(12)
	var area_b := _button(ms._popup, "Sala de espera", false, true) if ms._popup != null else null
	if area_b != null:
		await _click(_c(area_b))
		await tool.frames(12)
	var ir := _button(ms._popup, Widgets.t("shell.map.ir"), true) if ms._popup != null else null
	_check(ir != null, "confirmación de viaje con «Ir»")
	await tool.snap("08_ir")
	if ir != null:
		await _click(_c(ir))
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 900)
	await _idle()
	await tool.frames(40)
	_check(gs.cur_place == "L4", "visita a Kensington por clics")
	await tool.snap("09_visita")
	# ---- cinta «Cuaderno» -> arrastrar un recorte sobre Watson
	await _click(_c(gs.hud.ribbon("notebook")))
	await tool.frames(30)
	var nb = shell.panel("notebook")
	_check(nb != null and shell.is_open("notebook"), "cinta «Cuaderno» abre el cuaderno en la visita")
	var card: Control = null
	if nb != null:
		for c in nb.find_children("*", "Control", true, false):
			var sc = c.get_script()
			if sc != null and String(sc.resource_path).ends_with("clip_card.gd") and (c as Control).is_visible_in_tree():
				card = c
				break
	_check(card != null, "tarjeta de recorte en el cuaderno")
	await tool.snap("10_cuaderno")
	var wp: Vector2 = gs.char_screen_pos("watson")
	if card != null and wp.x >= 0.0:
		var a := _c(card)
		_mm(a)
		await tool.frames(2)
		_btn(a, true)
		await tool.frames(2)
		var got := []
		shell.drop_catcher.present_requested.connect(func(cid, _d): got.append(cid), CONNECT_ONE_SHOT)
		for k in range(1, 25):
			_mm(a.lerp(wp, float(k) / 24.0), MOUSE_BUTTON_MASK_LEFT)
			await tool.frames(1)
		await tool.frames(3)
		_mm(wp, MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(2)
		var hov = vp.gui_get_hovered_control()
		print("[raton] arrastrando=%s hover=%s" % [vp.gui_is_dragging(), str(hov.get_path()) if hov != null else ""])
		_check(vp.gui_is_dragging(), "arrastre real desde el cuaderno")
		var dc = shell.drop_catcher
		print("[raton] catcher armed=%s filter=%d char=%s can_drop=%s data=%s" % [dc.armed, dc.mouse_filter, dc.char_at(wp), dc._can_drop_data(wp - dc.global_position, vp.gui_get_drag_data()), str(vp.gui_get_drag_data())])
		var ended := []
		shell.drag_layer.ended.connect(func(d, ok): ended.append(ok), CONNECT_ONE_SHOT)
		await tool.snap("11_arrastre")
		# el puntero real del sistema puede moverse entre cuadros (corrida con ventana): se reafirma y se suelta enseguida
		_mm(wp, MOUSE_BUTTON_MASK_LEFT)
		# Godot suelta donde está el puntero del SO; sin foco, warp_mouse no lo mueve: se avisa y se suelta por código
		var vpm: Vector2 = vp.get_mouse_position()
		if vpm.distance_to(wp) > 2.0:
			print("[raton] AVISO sin foco: puntero del SO en %s, no en %s; soltar por código" % [vpm, wp])
			var dd = vp.gui_get_drag_data()
			if dc._can_drop_data(wp - dc.global_position, dd):
				dc._drop_data(wp - dc.global_position, dd)
			vp.gui_cancel_drag()
		else:
			_btn(wp, false)
		await tool.frames(16)
		print("[raton] tras soltar: arrastrando=%s exito=%s ended=%s" % [vp.gui_is_dragging(), vp.gui_is_drag_successful(), str(ended)])
		_check(got == ["watson"], "soltar sobre Watson desde el cuaderno -> presentar (%s)" % str(got))
		var sp = shell.panel("scene")
		var bar_ok: bool = sp != null and "present_bar" in sp and sp.present_bar != null and sp.present_bar.visible
		_check(bar_ok, "frase de Lisle con Mostrar / Guardar")
		await tool.snap("12_presentar")
		if bar_ok:
			var gb := _button(sp.present_bar, Widgets.t("shell.present.guardar"), false, true)
			if gb == null:
				gb = _button(sp.present_bar, "Guardar", false, true)
			if gb != null:
				await _click(_c(gb))
				await tool.frames(12)
	else:
		_check(false, "Watson en pantalla %s" % str(wp))
	# ---- volver a casa con clics (calendario -> «Volver a casa»)
	# en la visita el cuaderno va a la izquierda, sin velo, y tapa el calendario: se cierra con su «Volver»
	await tool.snap("12b_guardado")
	if shell.is_open("notebook"):
		var vb: Node = shell.panel("notebook").find_child("Volver", true, false)
		await _click(_c(vb as Control) if vb is Control else Vector2(-1, -1))
		await tool.frames(16)
	_check(not shell.is_open("notebook"), "«Volver» del cuaderno lo cierra")
	await _click(_c(gs.hud.card))
	await tool.frames(12)
	_check(gs.modal() != null, "calendario en la visita: volver pide confirmación")
	if gs.modal() != null:
		await _click(_c(_button(gs.modal(), Widgets.t("shell.leave.ok"), true)))
	await _until(func(): return String(g.sim.q_clock().phase) == "desk", 600)
	await _idle()
	await tool.frames(30)
	_check(String(g.sim.q_clock().phase) == "desk" and gs.mode == "hub", "de vuelta en el escritorio")
	await tool.snap("13_casa")
	# ---- Esc sin nada que cerrar -> opciones; «Cerrar» con clic
	await _key(KEY_ESCAPE)
	await tool.frames(20)
	_check(shell.top_kind() == "options", "Esc: opciones")
	var op = shell.top()
	var cl := _button(op, Widgets.t("kit.close"), true) if op != null else null
	if cl != null:
		await _click(_c(cl))
		await tool.frames(20)
	_check(shell.top() == null, "opciones: «Cerrar» con clic")
	print("[raton] RESUMEN %d fallas" % fails)
	g.end_session()

# ------------------------------------------------------------------ utilidades
func _c(c: Control) -> Vector2:
	return c.get_global_rect().get_center() if c != null else Vector2(-1, -1)

# Primer Button visible bajo root con ese texto (prefix: empieza por; last: el último que coincida).
func _button(root: Node, text: String, last := false, prefix := false) -> Button:
	if root == null:
		return null
	var hit: Button = null
	for b in root.find_children("*", "Button", true, false):
		var bt := b as Button
		if not bt.is_visible_in_tree():
			continue
		if bt.text == text or (prefix and bt.text.begins_with(text)):
			hit = bt
			if not last:
				return hit
	return hit

# Un punto de la pantalla donde el pick da ese nodo (como lo encontraría el jugador al pasar el mouse): alrededor de
# la proyección de su cuerpo, en espiral de 6 px.
func _node_pos(id: String) -> Vector2:
	var b: Node3D = shell.world.node_body(id)
	var cam: Camera3D = shell.world.camera()
	if b == null or cam == null or cam.is_position_behind(b.global_position):
		return Vector2(-1, -1)
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 120, 6):
		for k in 16:
			var p := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if String(shell.world.pick(p).get("id", "")) == id:
				return p
			if r == 0:
				break
	return c

func _idle(max_frames := 1200) -> void:
	await tool.frames(3)
	await _until(func(): return gs != null and gs.idle(), max_frames)

func _until(f: Callable, max_frames: int) -> void:
	var i := 0
	while not f.call() and i < max_frames:
		await tool.frames(1)
		i += 1
	if i >= max_frames:
		print("[raton] timeout")

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

func _btn(p: Vector2, pressed: bool, idx := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	if p.x < 0.0:
		print("[raton] clic sin destino")
		return
	_mm(p)
	await tool.frames(3)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(3)

func _rclick(p: Vector2) -> void:
	_mm(p)
	await tool.frames(2)
	_btn(p, true, MOUSE_BUTTON_RIGHT)
	await tool.frames(1)
	_btn(p, false, MOUSE_BUTTON_RIGHT)
	await tool.frames(3)
