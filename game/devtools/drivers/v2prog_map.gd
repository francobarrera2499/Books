# PROGRESIÓN (GDD_v2 §B.3, §C.3): el mapa revelado, con el mouse real y SIN --fast (como un jugador).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2prog res://devtools/drivers/v2prog_map.gd
# Datos reales. Título (clic en «Partida nueva») -> prólogo v2 por acciones (abrir el encargo, recortar el aviso, el aviso,
# dormir) -> día 1: mapa con SÓLO casa, Sala de Lectura y consultorio, sellos «Nuevo», sin página Baedeker ni selector de
# asiento; al pasar el mouse por la Sala, su horario en una línea; clic en la Sala -> «Ir» -> viaje (con animación) ->
# visita con el asiento 214 -> volver. Día 2: Baker Street aparece (garantía) con su sello. Capturas en .work/shots/.
# Salida: «V2PROG OK|FALLA <qué>» por chequeo y «V2PROG FIN fallas=<n>».
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")

var tool
var shell
var g
var fails := 0
var _last := Vector2.ZERO

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("V2PROG %s %s" % ["OK" if c else "FALLA", what])

func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = g.act(a)
	if not bool(r.get("ok", false)):
		print("V2PROG acción rechazada %s -> %s" % [str(a), str(r.get("err", ""))])
	return r

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(30)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	g.save_path = "user://saves/v2prog_map.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_check(not bool(shell.fast), "sin --fast")
	# ---- título: clic real en «Partida nueva»
	var title = shell.screen
	var bn := _button(title, Widgets.t("shell.title.nueva"))
	_check(bn != null, "título: «Partida nueva»")
	if bn == null:
		_end()
		return
	await _click(_c(bn))
	await tool.frames(8)
	if title != null and is_instance_valid(title) and title.get("_confirm") != null and is_instance_valid(title._confirm):
		await _click(_c(_button(title._confirm, Widgets.t("shell.title.nueva_ok"))))
	await _until(func(): return shell.game_screen != null and g.sim != null, 900)
	await tool.frames(30)
	_check(g.sim != null and String(g.sim.q_clock().phase) == "prologue", "prólogo")
	if g.sim == null:
		_end()
		return
	# ---- prólogo v2 por acciones (la interfaz del prólogo es de otras áreas)
	_act({"t": "read", "view": "D23@L1", "part": 0})
	var v: Dictionary = g.sim.q_view("D23@L1")
	for pi in (v.pages as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for tr in v.pages[pi][bi].parsed.tramos:
				if String(tr.id) == "aviso":
					_act({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
	_act({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_act({"t": "sleep"})
	if shell.game_screen != null and shell.game_screen.has_method("request_sync"):
		shell.game_screen.request_sync()
	await tool.frames(60)
	_check(String(g.sim.q_clock().phase) == "desk" and int(g.sim.q_clock().day) == 1, "día 1, escritorio")
	_check(bool(g.sim.q_ui().get("desk.mapa", false)), "q_ui: el mapa es usable")
	# ---- mapa del día 1
	await _open_map()
	var ms = shell.panel("map")
	_check(ms != null and ms.visible, "mapa abierto")
	if ms == null:
		_end()
		return
	_check(ms.get_node_or_null("Board/Baedeker") == null, "sin página Baedeker")
	var ids: Array = []
	for m in ms.markers.get_children():
		if m.get("place_id") != null:
			ids.append(String(m.place_id))
	ids.sort()
	_check(ids == ["L1", "L2", "L4"], "día 1: casa, Sala de Lectura y consultorio: %s" % str(ids))
	var l2 = ms.marker("L2")
	_check(l2 != null and bool(l2.is_new), "sello «Nuevo» en la Sala de Lectura")
	await tool.snap("01_mapa_dia1")
	# hover real: el horario en una línea
	await _move(_marker_point(l2))
	await tool.frames(6)
	_check(ms._hover.visible and ms._hover.text.contains(String(g.sim.repo.map().places.L2.hours)), "al pasar el mouse: el horario de la Sala («%s»)" % ms._hover.text)
	await tool.snap("02_hover_sala")
	# clic real en la Sala -> confirmación sin selector de asiento -> «Ir»
	await _click(_marker_point(l2))
	await tool.frames(10)
	var pop = ms._popup
	_check(pop != null and is_instance_valid(pop), "confirmación del viaje")
	if pop != null and is_instance_valid(pop):
		_check(pop.find_children("*", "SpinBox", true, false).is_empty(), "sin selector de asiento en el mapa")
		await tool.snap("03_confirmar")
		var ir := _button(pop, Widgets.t("shell.map.ir"))
		_check(ir != null, "botón «Ir»")
		var n0: int = g.sim.actions_log().size()
		await _click(_c(ir))
		await _until(func(): return String(g.sim.q_clock().phase) == "visit" and not ms.traveling(), 900)
		await tool.frames(20)
		var last: Dictionary = g.sim.actions_log()[-1] if g.sim.actions_log().size() > n0 else {}
		_check(String(last.get("t", "")) == "go" and int(last.get("seat", 0)) == 214, "go a la Sala con el asiento 214: %s" % str(last))
		await tool.snap("04_visita_sala")
		_act({"t": "leave"})
	# ---- día 2: Baker Street por garantía, con su sello
	for i in 12:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= 2 and String(c.phase) == "desk":
			break
		match String(c.phase):
			"desk": _act({"t": "end_slot"})
			"visit", "scene": _act({"t": "leave"})
			"night":
				if bool(g.sim.q_report_status().get("due", false)):
					_act({"t": "report_submit", "mode": "nada", "items": []})
				_act({"t": "sleep"})
	if shell.game_screen != null and shell.game_screen.has_method("request_sync"):
		shell.game_screen.request_sync()
	await tool.frames(40)
	if ms.visible:
		ms.close()
	await _open_map()
	ms = shell.panel("map")
	var l3 = ms.marker("L3")
	_check(l3 != null, "día 2: Baker Street en el plano")
	_check(l3 != null and bool(l3.is_new), "Baker Street con el sello «Nuevo»")
	_check(ms.marker("L6") == null, "Somerset House todavía no (garantía 3.dawn)")
	_check(ms.marker("L2") != null and not bool(ms.marker("L2").is_new), "la Sala ya no es nueva")
	await tool.snap("05_mapa_dia2")
	var gd: Array = g.sim.q_guide()
	_check(gd.size() <= 3 and not gd.is_empty(), "Pendientes: %s" % str(gd))
	_end()

# Espera a que el escritorio esté quieto (amanecer, bandeja, Pendientes) y abre el mapa.
func _open_map() -> void:
	await _until(func(): return shell.game_screen == null or (shell.game_screen.has_method("idle") and shell.game_screen.idle()), 1200)
	for i in 300:
		var n = shell.open_panel("map")
		if n != null and n.visible:
			break
		await tool.frames(2)
	await tool.frames(20)

func _end() -> void:
	print("V2PROG FIN fallas=%d" % fails)

func _marker_point(m) -> Vector2:
	if m == null:
		return Vector2(-1, -1)
	var o: Vector2 = m.get_meta("origin", Vector2.ZERO)
	return m.get_global_rect().position + o

func _c(c: Control) -> Vector2:
	return c.get_global_rect().get_center() if c != null else Vector2(-1, -1)

func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for b in root.find_children("*", "Button", true, false):
		var bt := b as Button
		if bt.is_visible_in_tree() and bt.text == text:
			return bt
	return null

func _until(f: Callable, max_frames: int) -> void:
	var i := 0
	while not f.call() and i < max_frames:
		await tool.frames(1)
		i += 1

func _move(p: Vector2) -> void:
	Input.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.relative = p - _last
	_last = p
	Input.parse_input_event(ev)
	await tool.frames(3)

func _btn(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	if p.x < 0.0:
		print("V2PROG clic sin destino")
		return
	await _move(p)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(3)
