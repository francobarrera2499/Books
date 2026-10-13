# devtools/drivers/v2_novato.gd — PLAYTEST v2 «jugador novato real» (sólo diagnóstico; no arregla nada).
# Juega el juego REAL sin --fast, sólo con eventos reales de mouse/teclado (warp_mouse + Input.parse_input_event; helpers de
# w3int_flow/w4novato), y evalúa los 8 puntos del feedback del usuario (GDD_v2): lenguaje, qué hacer tras el tutorial,
# distinguir lo que hay en la mesa, usable vs examinable, cámara (bordes/arrastre/rueda/clic derecho), look aguada,
# vistas que abruman, herramientas sin sentido (regla/lupa). Imprime «V2N …» y captura cada paso.
# Fases (la partida se guarda en user://saves/v2novato.jsonl y la siguiente fase sigue con «Continuar»):
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2n res://devtools/drivers/v2_novato.gd --mute --v2-fase=a
#   a: título, opciones, prólogo a ciegas + el tutorial siguiendo lo que pide la nota, dormir, bandeja del día 1.
#   b: día 1: Pendientes, bandeja, notas de Lisle (primera conclusión), cuaderno, libro, mapa, una salida, noche, dormir.
#   c: días 2 y 3: bandeja, mapa con lo nuevo, Crane, Sala de Lectura (catálogo), informe de la noche del 2.
extends "res://devtools/drivers/w4novato.gd"

var fase := "a"
var _hover_seen := {}

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("V2N sin Shell")
		return
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--v2-fase="):
			fase = s.substr(10)
	g.save_path = "user://saves/v2novato.jsonl"
	if fase == "a":
		for suf in ["", ".bak", ".tmp"]:
			var p := ProjectSettings.globalize_path(g.save_path + suf)
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	await _settle_window()
	shell.show_title()
	await tool.frames(40)
	if fase == "a":
		await _fase_a()
	else:
		await _continuar()
		if g.sim == null:
			_summary()
			return
		if fase == "b":
			await _fase_b()
		elif fase == "c":
			await _fase_c()
		elif fase == "d":
			await _fase_d()
		elif fase == "e":
			await _fase_e()
	_summary()
	if g.sim != null:
		g.end_session()

# ================================================================== utilidades v2
func _hover_text() -> String:
	var gsc = gs()
	if gsc == null or gsc.hover_label == null:
		return ""
	return String(gsc.hover_label.label_text())

func _cursor_name() -> String:
	var s := DisplayServer.cursor_get_shape()
	match s:
		DisplayServer.CURSOR_ARROW: return "flecha"
		DisplayServer.CURSOR_HELP: return "lupa"
		DisplayServer.CURSOR_POINTING_HAND: return "mano"
		DisplayServer.CURSOR_IBEAM: return "texto"
		DisplayServer.CURSOR_DRAG: return "arrastre"
		DisplayServer.CURSOR_MOVE: return "mover"
		DisplayServer.CURSOR_CROSS: return "cruz"
	return str(s)

func _yaw() -> float:
	var rig = shell.world.rig if shell.world != null else null
	return float(rig.yaw_off) if rig != null else 0.0

func _pose() -> String:
	var rig = shell.world.rig if shell.world != null else null
	if rig == null:
		return "-"
	return "%s/%s yaw=%.1f pitch=%.1f fov=%.1f" % [String(rig.mode()), String(rig.cur), float(rig.yaw_off), float(rig.pitch_off), float(rig.cam.fov) if rig.cam != null else 0.0]

# Barrido con el mouse por la pantalla: qué etiquetas aparecen, con qué cursor (lupa=examinable, mano=usable).
func _hover_sweep(tag: String, step := 60, snaps := 3) -> Dictionary:
	var seen := {}
	var n_snap := 0
	for y in range(70, 860, step):
		for x in range(40, 1580, step):
			var p := Vector2(x, y)
			_mm(p)
			await tool.frames(2)
			var hov = vp.gui_get_hovered_control()
			if hov != null and hov.mouse_filter == Control.MOUSE_FILTER_STOP:
				continue
			await tool.frames(4)   # la etiqueta aparece a los 0,08 s y el pick corre a 30 Hz
			var t := _hover_text()
			if t == "":
				continue
			if not seen.has(t):
				seen[t] = {"pos": p, "cursor": _cursor_name(), "pick": String(shell.world.pick(p).get("id", ""))}
				if n_snap < snaps:
					n_snap += 1
					await tool.frames(3)
					await _snap("hover_%s_%d" % [tag, n_snap])
	var lst: Array = []
	for t in seen.keys():
		lst.append("%s(%s,%s)" % [t, seen[t].cursor, seen[t].pick])
	print("V2N HOVER %s: %d etiquetas: %s" % [tag, seen.size(), ", ".join(lst)])
	return seen

func _find_label(seen: Dictionary, words: Array) -> Vector2:
	for t in seen.keys():
		var tl := String(t).to_lower()
		for w in words:
			if tl.contains(String(w).to_lower()):
				return seen[t].pos
	return Vector2(-1, -1)

func _hold_space(sec: float, shot: String) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(sec)
	await _snap(shot)
	var gsc = gs()
	var many := int(gsc.hover_label.many_count()) if gsc != null and gsc.hover_label != null else -1
	print("V2N MIRAR ALREDEDOR (%s): etiquetas a la vez=%d looking=%s" % [shot, many, str(gsc.looking_around()) if gsc != null else "?"])
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.3)

func _edge(dir: int, sec: float, shot: String) -> void:
	var y0 := _yaw()
	var at := Vector2(5, 450) if dir < 0 else Vector2(1595, 450)
	await _sync_mouse(at)
	await _wait(sec)
	await _snap(shot)
	var y1 := _yaw()
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.4)
	print("V2N CÁMARA borde %s %.1fs: yaw %.1f -> %.1f (%s)" % ["izq" if dir < 0 else "der", sec, y0, y1, _pose()])

func _wheel(at: Vector2, down: bool, n: int) -> void:
	for _i in n:
		_mm(at)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.factor = 1.0
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await tool.frames(4)

# Lista los controles visibles de un panel (para medir «cuánta cosa hay a la vez»).
func _inventory(tag: String, n) -> void:
	if n == null or not is_instance_valid(n):
		print("V2N INVENTARIO %s: (nada)" % tag)
		return
	var btns: Array = []
	var labels := 0
	var words := 0
	for c in n.find_children("*", "", true, false):
		if not (c is CanvasItem) or not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is Button:
			var t := String((c as Button).text).strip_edges()
			if t == "":
				t = "<" + String(c.name) + ">"
			btns.append(t)
		elif c is RichTextLabel:
			labels += 1
			words += String((c as RichTextLabel).get_parsed_text()).split(" ", false).size()
		elif c is Label:
			labels += 1
			words += String((c as Label).text).split(" ", false).size()
	print("V2N INVENTARIO %s: %d botones %s · %d textos · %d palabras" % [tag, btns.size(), str(btns).left(900), labels, words])

func _speech_through(tag: String, maxn := 30) -> void:
	var n := 0
	var gsc = gs()
	while gsc.speech.visible and n < maxn:
		var before := String(gsc.speech.text.get_parsed_text())
		print("V2N DICHO [%s] %s" % [tag, before.replace("\n", " / ")])
		await _click(_c(gsc.speech))
		await _wait(0.35)
		n += 1
		if String(gsc.speech.text.get_parsed_text()) == before and gsc.speech.visible:
			await _wait(0.8)
			if String(gsc.speech.text.get_parsed_text()) == before and gsc.speech.visible:
				print("V2N la tarjeta de lo dicho no avanza con el clic: ", before.left(80))
				break
	print("V2N clics para pasar lo dicho (%s): %d" % [tag, n])

func _tutor_dump(tag: String) -> String:
	var gsc = gs()
	var t := ""
	if gsc != null and gsc.tutor.visible:
		t = String(gsc.tutor.text.get_parsed_text())
	print("V2N TUTOR [%s] paso=%d · %s" % [tag, _tut_index(), t.replace("\n", " / ")])
	return t

func _guide_dump(tag: String) -> void:
	var gsc = gs()
	if gsc == null:
		return
	var lines: Array = gsc.hud.guide_lines() if gsc.hud.has_method("guide_lines") else []
	print("V2N PENDIENTES [%s] visible=%s %s" % [tag, str(gsc.hud.guide_box.is_visible_in_tree()) if gsc.hud.guide_box != null else "?", str(lines)])
	print("V2N PENDIENTES texto [%s] %s" % [tag, _texts(gsc.hud.guide_box, 600)])

func _continuar() -> void:
	await _snap("titulo_cont")
	var bc := _button(shell.screen, Widgets.t("shell.title.continuar"))
	_check(bc != null, "título: «Continuar» con partida guardada")
	if bc == null:
		return
	await _click(_c(bc))
	await tool.frames(10)
	var t = shell.screen
	if t != null and is_instance_valid(t) and t.get("_confirm") != null and is_instance_valid(t._confirm):
		var sb := _button(t._confirm, Widgets.t("shell.title.seguir"))
		if sb != null:
			await _click(_c(sb))
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 1500)
	await tool.frames(40)
	await _snap("continuar")
	_dump("continuar")

# ================================================================== FASE A: título y prólogo
func _fase_a() -> void:
	await _snap("titulo")
	_dump("titulo")
	_inventory("titulo", shell.screen)
	for b in shell.screen.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			_mm(_c(b))
			await tool.frames(6)
	await _snap("titulo_hover")
	# Opciones (¿está la aguada? ¿qué dice?)
	var bo := _button(shell.screen, Widgets.t("shell.title.opciones"))
	if bo != null:
		await _click(_c(bo))
		await _wait(0.6)
		await _snap("opciones")
		var op = shell.top()
		print("V2N OPCIONES arriba=%s · %s" % [shell.top_kind(), _texts(op, 900)])
		_inventory("opciones", op)
		var lk = _find(op, "Look") if op != null else null
		if lk != null:
			print("V2N OPCIONES look elegido: «%s» (de %d)" % [(lk as OptionButton).get_item_text((lk as OptionButton).selected), (lk as OptionButton).item_count])
		await _key(KEY_ESCAPE)
		await _wait(0.4)
		if shell.top() != null:
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
		await _snap("opciones_cerradas")
	# Partida nueva
	var t0 := Time.get_ticks_msec()
	await _title()
	print("V2N CARGA título->prólogo ms=%d" % (Time.get_ticks_msec() - t0))
	if g.sim == null:
		return
	await _wait(0.5)
	await _snap("prologo_0")
	_dump("prologo_0")
	await _wait(2.0)
	await _snap("prologo_2s")
	_dump("prologo_2s")
	_tutor_dump("inicio")
	await _speech_through("prologo")
	await _wait(0.6)
	await _snap("prologo_tras_dicho")
	_dump("prologo_tras_dicho")
	var tut := _tutor_dump("tras_dicho")
	_guide_dump("prologo")
	_inventory("hud_prologo", gs().hud)
	# ¿qué hay sobre la mesa? barrido con el mouse en la vista general
	await _clear_top()
	print("V2N POSE inicial: ", _pose())
	var seen := await _hover_sweep("general", 60, 4)
	# mirar alrededor (Espacio)
	await _hold_space(0.8, "mirar_general")
	# cámara: bordes, arrastre, rueda, clic derecho
	await _edge(-1, 1.2, "borde_izq")
	await _edge(1, 2.4, "borde_der")
	await _edge(-1, 1.2, "borde_vuelta")
	var y0 := _yaw()
	await _drag(Vector2(700, 300), Vector2(950, 320))
	await _wait(0.5)
	print("V2N CÁMARA arrastre 250px: yaw %.1f -> %.1f (%s)" % [y0, _yaw(), _pose()])
	await _snap("arrastre")
	await _wheel(Vector2(500, 600), false, 3)
	await _wait(0.6)
	print("V2N CÁMARA rueda x3 hacia (500,600): ", _pose())
	await _snap("rueda")
	await _wheel(Vector2(500, 600), true, 3)
	await _wait(0.6)
	await _rclick(Vector2(800, 450))
	await _wait(0.6)
	print("V2N CÁMARA tras clic derecho: ", _pose())
	# seguir la nota: busca lo que nombra pasando el mouse
	await _follow_read(seen, tut)
	await _follow_clip()
	await _follow_ad()
	_tutor_dump("antes_dormir")
	_guide_dump("antes_dormir")
	await _snap("antes_dormir")
	# dormir: la nota dice calendario
	var tday := Time.get_ticks_msec()
	await _sleep_and_dawn("prologo")
	print("V2N CARGA dormir->bandeja ms=%d" % (Time.get_ticks_msec() - tday))
	await _wait(1.0)
	await _snap("dia1_bandeja")
	_dump("dia1_bandeja")
	_inventory("bandeja_d1", gs().tray)
	_guide_dump("dia1_amanecer")
	_tutor_dump("dia1_amanecer")

func _follow_read(seen: Dictionary, tut: String) -> void:
	await _clear_top()
	var p := _find_label(seen, ["encargo", "carta de pell", "carta"])
	if p.x < 0.0:
		print("V2N el novato NO encuentra el encargo pasando el mouse en la vista general; prueba la zona del escritorio")
		await _click(Vector2(800, 600))
		await _wait(0.8)
		var s2 := await _hover_sweep("tras_clic_mesa", 50, 2)
		p = _find_label(s2, ["encargo", "carta"])
	if p.x < 0.0:
		p = _node_pos("encargo")
		print("V2N RESPALDO posición del encargo por id: ", p)
		fallbacks += 1
	await _click(p)
	await _wait(0.9)
	await _snap("clic_encargo")
	_dump("clic_encargo")
	print("V2N POSE tras clic en el encargo: ", _pose())
	if not gs().exam.visible and not shell.reader_open():
		# quizá el primer clic acercó la zona: segundo clic
		var p2 := _node_pos("encargo")
		await _click(p2)
		await _wait(0.9)
		await _snap("clic_encargo_2")
		_dump("clic_encargo_2")
	if gs().exam.visible:
		_inventory("examen_encargo", gs().exam)
		var links: Array = gs().exam.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
		print("V2N enlaces del encargo: ", str(links.map(func(b): return b.text)))
		var target: Button = null
		for b in links:
			if String(b.text).to_lower().contains("leer") or String(b.text).to_lower().contains("abrir"):
				target = b
				break
		if target == null and not links.is_empty():
			target = links[0]
		if target != null:
			await _click(_c(target))
			await _wait(1.0)
	_check(shell.reader_open(), "encargo -> lector")
	if shell.reader_open():
		await _reader_probe("encargo")
	_tutor_dump("tras_leer")

# Lector: ¿qué controles hay? ¿descripción física? ¿regla/lupa? ¿zoom?
func _reader_probe(tag: String) -> void:
	var r = shell.reader
	await _snap("lector_" + tag)
	_inventory("lector_" + tag, r)
	var v: Dictionary = r.view
	print("V2N LECTOR %s: vista=%s título=«%s» hojas=%d fisica=«%s»" % [tag, String(v.get("view", "")), String(v.get("title", "")), (v.get("pages", []) as Array).size(), String(v.get("fisica", v.get("physical", ""))).left(200)])
	print("V2N LECTOR texto visible [%s]: %s" % [tag, _texts(r, 1400)])
	var bad: Array = []
	for b in r.find_children("*", "Button", true, false):
		var bt := String((b as Button).text).to_lower()
		if (b as Button).is_visible_in_tree() and (bt.contains("lupa") or bt.contains("regla") or bt.contains("medida")):
			bad.append(bt)
	print("V2N LECTOR herramientas viejas visibles: ", str(bad))
	# rueda: zoom
	var rr: Rect2 = r._read_rect() if r.has_method("_read_rect") else Rect2(400, 100, 800, 700)
	await _wheel(rr.get_center(), false, 2)
	await _wait(0.4)
	await _snap("lector_%s_rueda" % tag)
	print("V2N LECTOR tras rueda arriba x2: ", _texts(r, 300))
	await _wheel(rr.get_center(), true, 2)
	await _wait(0.3)

func _follow_clip() -> void:
	var t := _tutor_dump("clip")
	if not shell.reader_open():
		await _read_from_node("encargo", "")
	if not shell.reader_open():
		return
	var tid := "aviso"
	if _find_tramo(shell.reader.view, tid).is_empty():
		tid = _first_tramo(shell.reader.view)
	clips["aviso"] = await _clip_tramo(tid, "tijera_aviso")
	await _wait(0.6)
	await _snap("tras_recorte")
	_dump("tras_recorte")
	print("V2N recorte del aviso: ", String(g.sim.q_clip(clips.get("aviso", "")).get("text", "")).left(200) if clips.get("aviso", "") != "" else "(nada)")
	await _close_reader()
	await _wait(0.6)
	_tutor_dump("tras_cerrar_lector")
	_dump("tras_cerrar_lector")
	await _snap("tras_cerrar_lector")
	# ¿qué es nuevo en el HUD? (cuaderno)
	_inventory("hud_tras_recorte", gs().hud)
	if _tut_index() <= 1:
		_respaldo_clip("aviso", "D23@L1")

func _follow_ad() -> void:
	await _speech_through("harris")
	await _wait(0.5)
	var t := _tutor_dump("ad")
	await _snap("nota_aviso")
	await _clear_top()
	var seen := await _hover_sweep("busca_tintero", 60, 2)
	var p := _find_label(seen, ["tintero"])
	print("V2N tintero por etiqueta: ", p, " cursor=", (seen.get(_label_of(seen, "tintero"), {}) as Dictionary).get("cursor", "-"))
	if p.x < 0.0:
		p = _node_pos("tintero")
		fallbacks += 1
		print("V2N RESPALDO tintero por id: ", p)
	await _click(p)
	await _wait(0.9)
	await _snap("clic_tintero")
	_dump("clic_tintero")
	if shell.top_kind() != "ad":
		var link := _link_button(gs().exam, Widgets.t("shell.compose.ad"))
		if link == null and gs().exam.visible:
			var links: Array = gs().exam.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
			print("V2N enlaces del tintero: ", str(links.map(func(b): return b.text)))
			if not links.is_empty():
				link = links[0]
		if link != null:
			await _click(_c(link))
			await _wait(0.8)
	var ac = shell.top()
	if ac == null or shell.top_kind() != "ad":
		print("V2N FALLA el compositor de avisos no se abrió (arriba=%s)" % shell.top_kind())
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
		return
	await _snap("aviso_compositor")
	_inventory("compositor_aviso", ac)
	print("V2N AVISO texto: ", _texts(ac, 1200))
	print("V2N AVISO formas: ", str(ac.forms_available()) if ac.has_method("forms_available") else "?")
	for slot in ac._blanks.keys():
		var bl = ac._blanks[slot]
		if String(bl.value) != "":
			continue
		await _choose_popup(bl, "")
		await _wait(0.3)
	await _snap("aviso_lleno")
	print("V2N AVISO lleno: ", _texts(ac, 800))
	var send := _button(ac, Widgets.t("sceneui.ad.send"))
	if send != null and not send.disabled:
		await _click(_c(send))
		await _wait(0.5)
		await _snap("aviso_confirma")
		print("V2N AVISO confirma: ", _texts(ac, 600))
		var cf = _find(ac, "Confirmacion")
		if cf != null and "ok_button" in cf:
			await _click(_c(cf.ok_button))
			await _wait(1.4)
	_check(_tut_index() >= 3, "aviso enviado por clic (paso %d)" % _tut_index())
	if _tut_index() < 3:
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	await _clear_top()
	await _speech_through("tras_aviso")

func _label_of(seen: Dictionary, w: String) -> String:
	for t in seen.keys():
		if String(t).to_lower().contains(w):
			return t
	return ""

# ================================================================== FASE B: día 1
func _exam_links() -> Array:
	return gs().exam.find_children("*", "Button", true, false).filter(func(b): return (b as Button).is_visible_in_tree())

func _exam_click(match_fn: Callable, tag: String) -> bool:
	var links := _exam_links()
	print("V2N enlaces [%s]: %s" % [tag, str(links.map(func(b): return b.text))])
	for b in links:
		if match_fn.call(String(b.text)):
			await _scroll_into_view(b)
			await tool.frames(4)
			await _click(_c(b))
			await _wait(0.7)
			return true
	return false

func _click_label(words: Array, tag: String, sweep_step := 50) -> bool:
	await _clear_top()
	var seen := await _hover_sweep(tag, sweep_step, 1)
	var p := _find_label(seen, words)
	if p.x < 0.0:
		print("V2N el novato NO encuentra %s pasando el mouse (%s)" % [str(words), tag])
		return false
	print("V2N encontrado %s en %s (cursor %s)" % [str(words), str(p), String((seen.get(_label_of(seen, String(words[0]).to_lower()), {}) as Dictionary).get("cursor", "?"))])
	await _click(p)
	await _wait(0.9)
	return true

func _tray_v2(day: int) -> void:
	if not gs().tray.visible:
		print("V2N día %d: la bandeja no está abierta" % day)
		return
	await _snap("d%d_bandeja" % day)
	_inventory("bandeja_d%d" % day, gs().tray)
	print("V2N BANDEJA d%d: %s" % [day, _texts(gs().tray, 900)])
	var k := 0
	while k < 6 and gs().tray.visible:
		var rows: Array = gs().tray.list.get_children().filter(func(r): return r is Control and (r as Control).is_visible_in_tree())
		if k >= rows.size():
			break
		await _scroll_into_view(rows[k])
		await _click(_c(rows[k]))
		await _wait(0.8)
		if shell.reader_open():
			await _reader_probe("d%d_bandeja_%d" % [day, k])
			await _close_reader()
			await _wait(0.4)
		k += 1
	if gs().tray.visible:
		await _close_tray()

func _fase_b() -> void:
	var day := int(g.sim.q_clock().day)
	await _tray_v2(day)
	await _clear_top()
	await _wait(0.5)
	await _snap("d1_general")
	_guide_dump("d1_general")
	_inventory("hud_d1", gs().hud)
	await _wait(5.0)
	await _snap("d1_general_5s")
	_guide_dump("d1_general_5s")
	_mm(_c(gs().hud.guide_box))
	await _wait(0.6)
	await _snap("d1_pendientes_hover")
	_guide_dump("d1_pendientes_hover")
	var seen := await _hover_sweep("d1_general", 50, 4)
	await _hold_space(0.8, "d1_mirar")
	# Pendientes 1: «recorto las dos fechas de La liga de los pelirrojos (tomo II)»
	var ok := await _click_label(["tomos"], "d1_busca_tomos")
	if not ok:
		var p := _node_pos("tomos")
		fallbacks += 1
		await _click(p)
		await _wait(0.9)
	await _snap("d1_tomos_tarjeta")
	_dump("d1_tomos")
	_inventory("tarjeta_tomos", gs().exam)
	var re := RegEx.new()
	re.compile("\\bII\\b")
	var got := await _exam_click(func(t): return re.search(t) != null, "tomos")
	await _snap("d1_tomo_II")
	_dump("d1_tomo_II")
	got = await _exam_click(func(t): return t.to_lower().contains("pelirrojos"), "tomo II")
	if not shell.reader_open():
		print("V2N FALLA no se llegó a «La liga de los pelirrojos» desde la tarjeta de los tomos")
		await _read_from_node("tomos", "pelirrojos")
	if shell.reader_open():
		await _reader_probe("redh")
		clips["abril"] = await _clip_tramo("abril", "d1_tijera_abril")
		clips["octubre"] = await _clip_tramo("octubre", "d1_tijera_octubre")
		await _close_reader()
	_respaldo_clip("abril", "D01.REDH@tomo")
	_respaldo_clip("octubre", "D01.REDH@tomo")
	await _wait(0.5)
	_guide_dump("tras_fechas")
	await _snap("d1_tras_fechas")
	# Pendientes 2: juntar en el cuaderno
	await _click_ribbon("notebook")
	await _wait(0.6)
	var nb = shell.panel("notebook")
	await _snap("d1_cuaderno")
	_inventory("cuaderno_d1", nb)
	print("V2N CUADERNO texto: ", _texts(nb, 1000))
	var ca = _card(nb, clips.get("abril", ""))
	var co = _card(nb, clips.get("octubre", ""))
	if ca != null and co != null:
		var pairs0: int = g.sim.q_pairs().size()
		await _drag(_c(ca), _c(co))
		await _wait(0.6)
		await _snap("d1_juntar")
		var form = nb.overlay_panel() if nb.has_method("overlay_panel") else null
		if form != null:
			_inventory("form_par", form)
			print("V2N PAR formulario: ", _texts(form, 600))
			if "ok_button" in form:
				await _click(_c(form.ok_button))
				await _wait(0.6)
		_check(g.sim.q_pairs().size() > pairs0, "par hecho con el mouse")
		if g.sim.q_pairs().size() <= pairs0:
			_respaldo("link", {"t": "link", "a": clips.get("abril", ""), "b": clips.get("octubre", ""), "note": ""})
	await _snap("d1_cuaderno_par")
	_inventory("cuaderno_d1_par", nb)
	_guide_dump("tras_par")
	await _rclick(Vector2(800, 450))
	await _wait(0.5)
	await _clear_top()
	# Pendientes 3–5: libro de conclusiones
	await _click_ribbon("ledger")
	await _wait(0.8)
	var lg = shell.panel("ledger")
	await _snap("d1_libro")
	_inventory("libro_d1", lg)
	print("V2N LIBRO texto: ", _texts(lg, 1500))
	var nfo = _find(lg, "NuevoFolio")
	if nfo != null and (nfo as Control).is_visible_in_tree():
		await _click_ctrl(nfo)
		await _wait(0.5)
		if lg.picker() != null:
			await _snap("d1_libro_elegir_recorte")
			_inventory("picker_hoja", lg.picker())
			var rr = lg.picker().row_rect(clips.get("abril", ""))
			await _click(rr.get_center() if rr.size.x > 0 else Vector2(-1, -1))
			await _wait(0.5)
	else:
		print("V2N «Nueva hoja» no está a la vista")
	var folio := ""
	for fo in g.sim.q_ledger().get("folios", []):
		if String(fo.get("head_clip", "")) == clips.get("abril", ""):
			folio = String(fo.id)
	_check(folio != "", "«Nueva hoja» con el recorte de abril")
	if folio == "":
		folio = String(_respaldo("folio_open", {"t": "folio_open", "clip": clips.get("abril", "")}).get("folio", ""))
		lg.show_page(folio)
		await _wait(0.4)
	await _snap("d1_libro_hoja")
	_inventory("libro_hoja", lg)
	_guide_dump("tras_hoja")
	await _click_ctrl(_find(lg, "NuevoAsiento"))
	await _wait(0.5)
	if lg.picker() != null:
		await _snap("d1_libro_tipos")
		_inventory("picker_tipos", lg.picker())
		var tr = lg.picker().row_rect("T1")
		await _click(tr.get_center() if tr.size.x > 0 else Vector2(-1, -1))
		await _wait(0.5)
	var e := String(lg.selected)
	if e == "" or String(g.sim.q_entry(e).get("template", "")) != "T1":
		e = String(_respaldo("entry_new", {"t": "entry_new", "folio": folio, "template": "T1"}).get("entry", ""))
		lg.select_entry(e)
		await _wait(0.4)
	await _snap("d1_libro_conclusion_vacia")
	_inventory("conclusion_vacia", lg)
	print("V2N CONCLUSIÓN vacía: ", _texts(lg, 1200))
	for x in [[0, "fuente_a", "redh"], [0, "dice_a", "abril_27_1890"], [1, "fuente_b", "redh"], [1, "dice_b", "octubre_9_1890"]]:
		await _ledger_field(lg, e, int(x[0]), String(x[1]), String(x[2]))
	await _snap("d1_libro_campos")
	await _ledger_support(lg, e, 0, clips.get("abril", ""))
	await _ledger_support(lg, e, 1, clips.get("octubre", ""))
	await _snap("d1_libro_pruebas")
	_inventory("conclusion_llena", lg)
	print("V2N CONCLUSIÓN llena: ", _texts(lg, 1500))
	_guide_dump("tras_conclusion")
	var pr = _find(_find(lg, "Pie"), "Practicar")
	if pr != null and (pr as Control).is_visible_in_tree():
		await _click_ctrl(pr)
		await _wait(1.2)
		await _snap("d1_libro_practica")
		print("V2N PRÁCTICA: ", _texts(lg, 800))
	else:
		print("V2N FALLA no hay botón de práctica a la vista")
		await _snap("d1_libro_sin_practica")
	_guide_dump("tras_practica")
	await _rclick(Vector2(800, 450))
	await _wait(0.5)
	await _clear_top()
	await _snap("d1_tras_libro")
	_guide_dump("tras_libro")
	# el plano: ¿lo encuentra un novato? (Pendientes dice «en el plano»)
	var mok := await _click_label(["mapa", "plano"], "d1_busca_mapa", 50)
	if not mok or not shell.is_open("map"):
		await _snap("d1_mapa_no")
		_dump("d1_mapa_no")
		if gs().exam.visible:
			await _exam_click(func(t): return true, "mapa_tarjeta")
	if not shell.is_open("map"):
		print("V2N el novato no abrió el mapa con el mouse; prueba la tecla M")
		await _key(KEY_M)
		await _wait(0.8)
	await _map_and_go("L4")
	await _visit_v2()
	# resto del día: calendario hasta la noche, y dormir
	await _finish_day()

func _map_and_go(pid: String) -> void:
	var ms = shell.panel("map")
	if ms == null or not shell.is_open("map"):
		print("V2N FALLA el mapa no está abierto")
		return
	await _wait(0.4)
	var c: Dictionary = g.sim.q_clock()
	await _snap("d%d_mapa" % int(c.day))
	_inventory("mapa_d%d" % int(c.day), ms)
	print("V2N MAPA d%d: %s" % [int(c.day), _texts(ms, 1200)])
	var ids: Array = []
	for m in ms.markers.get_children():
		if "place_id" in m:
			ids.append("%s(%s)" % [String(m.place_id), "abierto" if bool(m.state.get("open", false)) else "cerrado"])
	print("V2N MAPA marcadores: ", str(ids))
	var mk = ms.marker(pid)
	if mk == null:
		print("V2N FALLA sin marcador %s" % pid)
		return
	var at: Vector2 = mk.get_global_rect().position + mk.get_meta("origin", Vector2(12, 12))
	_mm(at)
	await _wait(0.6)
	await _snap("d%d_mapa_hover_%s" % [int(c.day), pid])
	print("V2N MAPA hover %s: %s" % [pid, _texts(ms, 400)])
	await _click(at)
	await _wait(0.5)
	await _snap("d%d_mapa_popup_%s" % [int(c.day), pid])
	if ms._popup != null and is_instance_valid(ms._popup):
		_inventory("popup_" + pid, ms._popup)
		print("V2N MAPA popup %s: %s" % [pid, _texts(ms._popup, 500)])
		if _button(ms._popup, Widgets.t("shell.map.ir"), true) == null:
			var b := _first_enabled_button(ms._popup)
			if b != null:
				await _click(_c(b))
				await _wait(0.4)
	var ir := _button(ms._popup, Widgets.t("shell.map.ir"), true) if ms._popup != null and is_instance_valid(ms._popup) else null
	if ir == null:
		print("V2N FALLA sin «Ir» en %s" % pid)
		return
	var t0 := Time.get_ticks_msec()
	await _click(_c(ir))
	await _until(func(): return g.sim != null and String(g.sim.q_clock().phase) != "desk", 900)
	await _idle()
	print("V2N CARGA «Ir» %s ms=%d" % [pid, Time.get_ticks_msec() - t0])

func _visit_v2() -> void:
	if g.sim == null or String(g.sim.q_clock().phase) != "visit":
		print("V2N no hay visita (fase %s)" % String(g.sim.q_clock().phase))
		return
	await _wait(1.0)
	var c: Dictionary = g.sim.q_clock()
	var sc: Dictionary = g.sim.q_scene()
	var tag := "d%d_%s_%s" % [int(c.day), String(sc.get("place", "")), String(sc.get("area", ""))]
	await _snap(tag)
	_dump(tag)
	await _speech_through(tag, 16)
	await _snap(tag + "_tras_dicho")
	var seen := await _hover_sweep(tag, 60, 3)
	await _hold_space(0.8, tag + "_mirar")
	await _edge(-1, 1.5, tag + "_borde")
	for ch in sc.get("chars", []):
		var cid := String(ch.get("id", ""))
		var wp: Vector2 = gs().char_screen_pos(cid)
		print("V2N personaje %s en %s" % [cid, str(wp)])
		if wp.x < 0.0:
			continue
		await _click(wp)
		await _wait(0.7)
		var sp = shell.panel("scene")
		if sp == null or not shell.is_open("scene"):
			print("V2N clic en %s no abrió la conversación" % cid)
			continue
		await _snap(tag + "_charla_" + cid)
		_inventory("escena_" + cid, sp)
		print("V2N ESCENA %s: %s" % [cid, _texts(sp, 900)])
		var verb = _find(sp, "Personaje_" + cid)
		var ask = _find(verb if verb != null else sp, "Verbo_ask")
		if ask != null and (ask as Control).is_visible_in_tree():
			await _click_ctrl(ask)
			await _wait(0.5)
			var ap = sp.ask_panel
			await _snap(tag + "_preguntar_" + cid)
			_inventory("preguntar_" + cid, ap)
			print("V2N PREGUNTAR %s: %s" % [cid, _texts(ap, 900)])
			if ap.visible and ap._list.item_count > 0:
				var r: Rect2 = ap._list.get_item_rect(0)
				await _click(ap._list.get_global_transform_with_canvas() * r.get_center())
				await _wait(0.3)
				await _click(_c(ap._ok))
				await _wait(1.6)
				await _snap(tag + "_respuesta_" + cid)
				var lines: Array = g.sim.q_scene().get("lines", [])
				for ln in lines.slice(maxi(0, lines.size() - 4)):
					print("V2N RESPUESTA %s: %s" % [cid, String(ln.get("parsed", {}).get("plain", ln.get("text", ""))).left(400)])
				await _speech_through(tag + "_resp", 10)
		# Mostrar un recorte
		var show = _find(verb if verb != null else sp, "Verbo_present")
		if show == null:
			show = _button(sp, "Mostrar", false, true)
		if show != null and (show as Control).is_visible_in_tree():
			await _click_ctrl(show)
			await _wait(0.6)
			await _snap(tag + "_mostrar_" + cid)
			print("V2N MOSTRAR %s: %s" % [cid, _texts(shell.top(), 700)])
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
		break
	await _snap(tag + "_antes_salir")
	await _leave_visit()
	await _wait(0.6)
	await _snap(tag + "_vuelta")
	_dump(tag + "_vuelta")

func _finish_day() -> void:
	var guard := 0
	while g.sim != null and guard < 8:
		guard += 1
		var c: Dictionary = g.sim.q_clock()
		var ph := String(c.phase)
		if ph == "desk":
			await _clear_top()
			await _click_ctrl(gs().hud.card)
			await _wait(0.6)
			var m = gs().modal()
			await _snap("d%d_calendario_%s" % [int(c.day), String(c.slot)])
			print("V2N CALENDARIO %s: %s" % [String(c.slot), _texts(m, 500)])
			if m == null:
				break
			await _click(_c(_first_enabled_button(m, true)))
			await _until(func(): return g.sim == null or g.sim.q_clock() != c, 600)
			await _idle()
			await _wait(0.8)
			_guide_dump("d%d_%s" % [int(c.day), String(g.sim.q_clock().slot)])
		elif ph == "night":
			if bool(g.sim.q_report_status().get("due", false)):
				await _snap("d%d_noche_informe" % int(c.day))
				await _nov_report(false)
				continue
			await _sleep_and_dawn("noche_d%d" % int(c.day))
			await _wait(1.0)
			await _snap("d%d_amanecer" % (int(c.day) + 1))
			_guide_dump("amanecer_d%d" % (int(c.day) + 1))
			return
		elif ph == "visit":
			await _leave_visit()
		else:
			print("V2N fase inesperada ", ph)
			await _snap("fase_" + ph)
			await _speech_through(ph, 12)
			await _wait(1.0)

# ================================================================== FASE C: días 2 y 3
func _many_texts() -> Array:
	var out: Array = []
	var hl = gs().hover_label
	if hl == null:
		return out
	var many = hl.get_node_or_null("Todas")
	if many == null:
		return out
	for c in many.find_children("*", "Label", true, false):
		out.append(String((c as Label).text))
	return out

# Mirar alrededor girando la cabeza: Espacio en cada orientación; devuelve todas las etiquetas vistas.
func _look_all_around(tag: String) -> Array:
	var all: Array = []
	for step in [[0, 0.0], [-1, 2.0], [-1, 2.0], [1, 6.0]]:
		if int(step[0]) != 0:
			await _sync_mouse(Vector2(4, 450) if int(step[0]) < 0 else Vector2(1596, 450))
			await _wait(float(step[1]))
			await _sync_mouse(Vector2(800, 300))
			await _wait(0.8)
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await _wait(0.5)
		var ts := _many_texts()
		print("V2N GIRO %s yaw=%.1f (%s): %s" % [tag, _yaw(), _pose(), str(ts)])
		await _snap("%s_giro_%d" % [tag, all.size()])
		for t in ts:
			if not all.has(t):
				all.append(t)
		var u := e.duplicate()
		u.pressed = false
		Input.parse_input_event(u)
		await _wait(0.3)
	return all

func _talk_open(cid: String, tag: String) -> void:
	var sp = shell.panel("scene")
	if sp == null or not shell.is_open("scene"):
		var wp: Vector2 = gs().char_screen_pos(cid)
		if wp.x >= 0.0:
			await _click(wp)
			await _wait(0.7)
		sp = shell.panel("scene")
	if sp == null or not shell.is_open("scene"):
		print("V2N no se abre la conversación con %s" % cid)
		return
	var blk = _find(sp, "Personaje_" + cid)
	await _snap(tag + "_charla_" + cid)
	_inventory("escena_" + cid, sp)
	print("V2N ESCENA %s: %s" % [cid, _texts(sp, 900)])
	var ask = _find(blk if blk != null else sp, "Verbo_ask")
	if ask != null and (ask as Control).is_visible_in_tree():
		await _click_ctrl(ask)
		await _wait(0.6)
		var ap = sp.ask_panel
		await _snap(tag + "_preguntar_" + cid)
		_inventory("preguntar_" + cid, ap)
		print("V2N PREGUNTAR %s: %s" % [cid, _texts(ap, 1200)])
		if ap.visible and ap._list.item_count > 0:
			var items: Array = []
			for i in ap._list.item_count:
				items.append(ap._list.get_item_text(i))
			print("V2N PREGUNTAR temas %s: %s" % [cid, str(items)])
			var r: Rect2 = ap._list.get_item_rect(0)
			await _click(ap._list.get_global_transform_with_canvas() * r.get_center())
			await _wait(0.3)
			await _click(_c(ap._ok))
			await _wait(1.8)
			await _snap(tag + "_respuesta_" + cid)
			var lines: Array = g.sim.q_scene().get("lines", [])
			for ln in lines.slice(maxi(0, lines.size() - 4)):
				print("V2N RESPUESTA %s: %s" % [cid, String(ln.get("parsed", {}).get("plain", ln.get("text", ""))).left(500)])
			await _speech_through(tag + "_resp", 10)
			if sp.sub_open() != "":
				sp.close_sub()
	var show = _find(blk if blk != null else sp, "Verbo_present")
	if show != null and (show as Control).is_visible_in_tree():
		await _click_ctrl(show)
		await _wait(0.7)
		await _snap(tag + "_mostrar_" + cid)
		_inventory("mostrar_" + cid, sp)
		print("V2N MOSTRAR %s: %s" % [cid, _texts(sp, 900)])
		var cards: Array = sp.picker.cards() if "picker" in sp and sp.picker != null and sp.picker.visible else []
		if not cards.is_empty():
			await _click(_c(cards[0].node))
			await _wait(0.6)
			await _snap(tag + "_mostrar_elegido_" + cid)
			print("V2N MOSTRAR elegido: ", _texts(sp, 700))
			var ok := _button(sp, Widgets.t("sceneui.present.ok"))
			if ok != null:
				await _click(_c(ok))
				await _wait(1.8)
				await _snap(tag + "_mostrar_resp_" + cid)
				var lines2: Array = g.sim.q_scene().get("lines", [])
				for ln in lines2.slice(maxi(0, lines2.size() - 3)):
					print("V2N RESPUESTA MOSTRAR %s: %s" % [cid, String(ln.get("parsed", {}).get("plain", ln.get("text", ""))).left(500)])
				await _speech_through(tag + "_resp2", 10)
		if sp.sub_open() != "":
			sp.close_sub()
			await _wait(0.3)

func _visit2(tag_extra := "") -> void:
	if g.sim == null or not ["visit", "scene"].has(String(g.sim.q_clock().phase)):
		print("V2N no hay visita (fase %s)" % String(g.sim.q_clock().phase))
		return
	await _wait(1.2)
	var c: Dictionary = g.sim.q_clock()
	var sc: Dictionary = g.sim.q_scene()
	var tag := "d%d_%s_%s%s" % [int(c.day), String(sc.get("place", "")), String(sc.get("area", "")), tag_extra]
	await _snap(tag)
	_dump(tag)
	await _speech_through(tag, 16)
	await _hold_space(0.8, tag + "_mirar")
	print("V2N VISITA %s personajes=%s" % [tag, str((sc.get("chars", []) as Array).map(func(ch): return String(ch.get("id", ""))))])
	for ch in sc.get("chars", []):
		await _talk_open(String(ch.get("id", "")), tag)
		break

func _read_some_from_exam(tag: String, n: int) -> void:
	for i in n:
		if not gs().exam.visible:
			return
		var links := _exam_links()
		var cand: Array = links.filter(func(b): return String(b.text).begins_with("Leer") or String(b.text).contains("«"))
		if i >= cand.size():
			return
		await _click(_c(cand[i]))
		await _wait(0.9)
		if shell.reader_open():
			await _reader_probe("%s_%d" % [tag, i])
			await _close_reader()
			await _wait(0.5)

func _fase_c() -> void:
	var day := int(g.sim.q_clock().day)
	await _tray_v2(day)
	await _clear_top()
	await _wait(0.5)
	await _snap("d%d_general" % day)
	_guide_dump("d%d_general" % day)
	# ¿dónde está la puerta (tienda de Crane), el mapa, la cama? girando la cabeza con los bordes
	var all := await _look_all_around("d%d_buhardilla" % day)
	print("V2N GIRO todo lo visto en la buhardilla: ", str(all))
	await _sync_mouse(Vector2(800, 450))
	await _rclick(Vector2(800, 450))
	await _wait(0.6)
	# Crane: bajar a la tienda (la puerta)
	var ok := await _click_label(["puerta", "escalera", "tienda"], "d%d_busca_puerta" % day, 50)
	if not ok:
		for k in 3:
			await _edge(-1 if k < 2 else 1, 2.0, "d%d_gira_puerta_%d" % [day, k])
			ok = await _click_label(["puerta", "escalera", "tienda"], "d%d_busca_puerta_%d" % [day, k], 50)
			if ok:
				break
	await _wait(1.5)
	await _snap("d%d_tras_puerta" % day)
	_dump("d%d_tras_puerta" % day)
	if gs().exam.visible:
		await _exam_click(func(t): return true, "puerta")
		await _wait(1.5)
	await _idle()
	await _wait(1.0)
	print("V2N tras la puerta: lugar=%s fase=%s pose=%s" % [gs().cur_place, String(g.sim.q_clock().phase), _pose()])
	await _snap("d%d_tienda" % day)
	_dump("d%d_tienda" % day)
	var ph := String(g.sim.q_clock().phase)
	if ph == "visit" or shell.is_open("scene"):
		await _visit2("_crane")
	else:
		await _speech_through("tienda", 10)
		await _talk_open("crane", "d%d_tienda" % day)
		await _clear_top()
	var seen := await _hover_sweep("d%d_tienda" % day, 50, 3)
	# la mesa de novedades / estantes
	if await _click_label(["novedades", "mesa", "estante", "saldos"], "d%d_tienda_estantes" % day, 50):
		await _snap("d%d_tienda_tarjeta" % day)
		_dump("d%d_tienda_tarjeta" % day)
		_inventory("tarjeta_tienda", gs().exam)
		await _exam_click(func(t): return not t.begins_with("Volver") and not t.begins_with("Leer"), "tienda_grupo")
		await _snap("d%d_tienda_tarjeta2" % day)
		_dump("d%d_tienda_tarjeta2" % day)
		await _read_some_from_exam("tienda", 2)
	await _clear_top()
	# volver arriba
	await _snap("d%d_tienda_salir" % day)
	if String(g.sim.q_clock().phase) == "visit":
		await _leave_visit()
	else:
		if not await _click_label(["escalera", "subir", "volver"], "d%d_tienda_escalera" % day, 50):
			await _rclick(Vector2(800, 450))
	await _idle()
	await _wait(1.0)
	await _snap("d%d_tras_tienda" % day)
	print("V2N tras la tienda: lugar=%s fase=%s" % [gs().cur_place, String(g.sim.q_clock().phase)])
	# Museo Británico: Sala de Lectura y catálogo
	await _clear_top()
	await _key(KEY_M)
	await _wait(0.8)
	await _map_and_go("L2")
	await _visit2("")
	await _catalog_probe(day)
	await _leave_visit()
	await _idle()
	await _wait(0.8)
	# tarde: Baker Street (lo nuevo)
	await _end_turn_once()
	if String(g.sim.q_clock().phase) == "desk":
		await _key(KEY_M)
		await _wait(0.8)
		await _map_and_go("L3")
		await _visit2("")
		await _leave_visit()
		await _idle()
	await _finish_day()
	# día 3 (bandeja + plano)
	if g.sim != null and int(g.sim.q_clock().day) >= 3:
		day = int(g.sim.q_clock().day)
		await _tray_v2(day)
		await _clear_top()
		_guide_dump("d%d" % day)
		await _snap("d%d_general" % day)
		await _key(KEY_M)
		await _wait(0.8)
		await _map_and_go("L6")
		await _visit2("")
		await _leave_visit()
		await _idle()
		# el cuaderno y el libro a mitad de partida (¿abruman?)
		await _click_ribbon("notebook")
		await _wait(0.8)
		await _snap("d%d_cuaderno" % day)
		_inventory("cuaderno_d%d" % day, shell.panel("notebook"))
		await _rclick(Vector2(800, 450))
		await _wait(0.4)
		await _clear_top()
		await _click_ribbon("ledger")
		await _wait(0.8)
		await _snap("d%d_libro" % day)
		_inventory("libro_d%d" % day, shell.panel("ledger"))
		await _rclick(Vector2(800, 450))
		await _wait(0.4)
		await _clear_top()
		await _snap("d%d_fin" % day)

# ================================================================== FASE D: diagnósticos y vistas que faltan (día 3 tarde → día 4)
func _probe_door() -> void:
	# DIAGNÓSTICO (no es juego): ¿en qué giro de la vista general se puede apuntar a la puerta de la escalera?
	await _clear_top()
	await _rclick(Vector2(800, 450))
	await _wait(0.5)
	var rig = shell.world.rig
	var found: Array = []
	for y in range(-100, 101, 20):
		rig.yaw_t = float(y)
		rig.yaw_off = float(y)
		await _wait(0.3)
		var hits := {}
		for py in range(40, 880, 40):
			for px in range(20, 1590, 40):
				var id := String(shell.world.pick(Vector2(px, py)).get("id", ""))
				if id in ["puerta", "escalera_tienda", "escalera_baja", "cama", "mapa"]:
					hits[id] = int(hits.get(id, 0)) + 1
		print("V2N PUERTA yaw=%d (límite %s): %s" % [y, str(rig.limits()), str(hits)])
		if hits.has("puerta"):
			found.append(y)
	print("V2N PUERTA alcanzable en giros: %s" % str(found))
	rig.yaw_t = 0.0
	await _wait(0.6)

func _probe_look_drift() -> void:
	await _clear_top()
	await _rclick(Vector2(800, 450))
	await _wait(0.6)
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.6)
	# Espacio con el mouse quieto en el centro: etiquetas vs. anclas
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.4)
	await _snap("deriva_centro")
	var p0 := _node_pos("tomos")
	print("V2N DERIVA centro: tomos en %s; etiquetas=%d" % [str(p0), _many_texts().size()])
	# mientras se mantiene Espacio, el mouse llega al borde izquierdo (la vista gira)
	await _sync_mouse(Vector2(5, 450))
	await _wait(1.5)
	await _snap("deriva_borde")
	var p1 := _node_pos("tomos")
	print("V2N DERIVA tras 1,5 s en el borde con Espacio: tomos en %s (yaw %.1f); las etiquetas %s" % [str(p1), _yaw(), "se movieron" if false else "quedan donde estaban (show_many una sola vez)"])
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _sync_mouse(Vector2(800, 450))
	await _wait(0.8)

func _probe_composers() -> void:
	await _clear_top()
	await _rclick(Vector2(800, 450))
	await _wait(0.5)
	var p := _node_pos("tintero")
	await _click(p)
	await _wait(1.0)
	await _snap("d3_tintero")
	_dump("d3_tintero")
	_inventory("tintero_d3", gs().exam)
	var links := _exam_links()
	print("V2N TINTERO d3 enlaces: ", str(links.map(func(b): return b.text)))
	for b in links:
		var t := String(b.text)
		await _click(_c(b))
		await _wait(0.9)
		await _snap("d3_compositor_" + str(links.find(b)))
		print("V2N COMPOSITOR «%s» arriba=%s: %s" % [t, shell.top_kind(), _texts(shell.top(), 1200)])
		_inventory("compositor_" + t.left(20), shell.top())
		var top = shell.top()
		if top != null and top.has_method("forms_available"):
			print("V2N COMPOSITOR formas: ", str(top.forms_available()))
		await _clear_top()
		await _click(_node_pos("tintero"))
		await _wait(0.9)
		links = _exam_links()
		if links.size() <= 1:
			break
	await _clear_top()
	await _click(_node_pos("pliegos"))
	await _wait(0.9)
	await _snap("d3_pliegos")
	_dump("d3_pliegos")
	await _clear_top()

func _probe_shop_api() -> void:
	# RESPALDO (diagnóstico): la puerta de la escalera no se alcanza con el mouse; se baja a la tienda por la API para
	# poder evaluar la vista de Crane.
	await _clear_top()
	fallbacks += 1
	print("V2N RESPALDO: on_node(«puerta») por la API para ver la tienda")
	gs().on_node("puerta")
	await _idle()
	await _wait(2.0)
	await _snap("tienda_api")
	_dump("tienda_api")
	print("V2N TIENDA lugar=%s pose=%s fase=%s" % [gs().cur_place, _pose(), String(g.sim.q_clock().phase)])
	await _speech_through("tienda_api", 10)
	await _hold_space(0.8, "tienda_mirar")
	var seen := await _hover_sweep("tienda_api", 50, 3)
	for words in [["novedades", "saldos"], ["estante"], ["mostrador"]]:
		var p := _find_label(seen, words)
		if p.x < 0.0:
			continue
		await _clear_top()
		await _click(p)
		await _wait(1.0)
		if not gs().exam.visible:
			await _click(p)
			await _wait(1.0)
		await _snap("tienda_%s" % String(words[0]))
		print("V2N TIENDA tarjeta %s: %s" % [str(words), _texts(gs().exam, 1000)])
		_inventory("tienda_" + String(words[0]), gs().exam)
		await _exam_click(func(t): return not t.begins_with("Volver") and not t.begins_with("Leer"), "tienda_grupo")
		await _snap("tienda_%s_2" % String(words[0]))
		print("V2N TIENDA tarjeta2 %s: %s" % [str(words), _texts(gs().exam, 1000)])
		await _read_some_from_exam("tienda_" + String(words[0]), 1)
	await _clear_top()
	# Crane
	var cp := _find_label(seen, ["crane", "librero", "señor"])
	if cp.x >= 0.0:
		await _click(cp)
		await _wait(0.8)
		await _talk_open("crane", "tienda")
	await _clear_top()
	await _snap("tienda_antes_subir")
	var up := await _click_label(["escalera", "subir", "buhardilla"], "tienda_escalera", 50)
	await _idle()
	await _wait(1.5)
	print("V2N tras subir: lugar=%s pose=%s (encontró la escalera=%s)" % [gs().cur_place, _pose(), str(up)])
	if gs().cur_place != "L1" or String(shell.world.place.get("area", "")) == "tienda":
		gs().on_node("escalera_tienda")
		await _idle()
		await _wait(1.0)
	await _snap("tras_subir")

func _somerset_search() -> void:
	await _wait(1.0)
	var seen := await _hover_sweep("d3_L6_busca", 50, 1)
	for words in [["índices", "indices"], ["mostrador"], ["libro"]]:
		await _clear_top()
		var p := _find_label(seen, words)
		if p.x < 0.0:
			continue
		var id := String(shell.world.pick(p).get("id", ""))
		var np := _node_pos(id) if id != "" else p
		await _click(np)
		await _wait(1.0)
		await _snap("d3_L6_%s" % String(words[0]))
		print("V2N SOMERSET %s: %s" % [str(words), _texts(gs().exam, 1000)])
		_inventory("somerset_" + String(words[0]), gs().exam)
		await _read_some_from_exam("somerset_" + String(words[0]), 1)

func _fase_d() -> void:
	var c: Dictionary = g.sim.q_clock()
	print("V2N FASE D en %s fase=%s" % [TimeKey.label(int(c.tk)), String(c.phase)])
	await _clear_top()
	await _probe_door()
	await _probe_look_drift()
	await _probe_composers()
	await _probe_shop_api()
	# tarde: Somerset House (búsqueda)
	await _end_turn_once()
	if String(g.sim.q_clock().phase) == "desk":
		await _key(KEY_M)
		await _wait(0.8)
		await _map_and_go("L6")
		await _visit2("_tarde")
		await _somerset_search()
		await _leave_visit()
		await _idle()
	# noche: la Sala de Lectura (catálogo) abre hasta las 20
	await _end_turn_once()
	if String(g.sim.q_clock().phase) == "desk":
		await _key(KEY_M)
		await _wait(0.8)
		await _map_and_go("L2")
		await _visit2("_noche")
		await _clear_top()
		await _catalog_probe2()
		await _leave_visit()
		await _idle()
	await _finish_day()
	# día 4: Watson de verdad (preguntar con un tema, mostrar, decir)
	if g.sim != null and int(g.sim.q_clock().day) == 4:
		await _tray_v2(4)
		await _clear_top()
		_guide_dump("d4")
		await _snap("d4_general")
		await _key(KEY_M)
		await _wait(0.8)
		await _map_and_go("L4")
		await _wait(1.2)
		await _talk_watson()
		await _leave_visit()
		await _idle()
		await _snap("d4_fin")

func _catalog_probe2() -> void:
	var p := _node_pos("catalogo")
	print("V2N catálogo en ", p, " pick=", str(shell.world.pick(p)))
	await _click(p)
	await _wait(1.0)
	if not gs().catalog.visible and gs().exam.visible:
		await _exam_click(func(t): return true, "catalogo_tarjeta")
		await _wait(0.8)
	await _snap("catalogo2")
	if not gs().catalog.visible:
		print("V2N FALLA el catálogo no se abre con el clic en su nodo (%s)" % _texts(gs().exam, 300))
		return
	_inventory("catalogo", gs().catalog)
	print("V2N CATÁLOGO: ", _texts(gs().catalog, 1500))
	var le: LineEdit = null
	for x in gs().catalog.find_children("*", "LineEdit", true, false):
		if (x as LineEdit).is_visible_in_tree():
			le = x
	if le != null:
		await _click(_c(le))
		await _wait(0.2)
		for ch in "gazette":
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(ch.to_upper())
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0)
			ev.pressed = true
			Input.parse_input_event(ev)
			await tool.frames(2)
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			await tool.frames(2)
		await _wait(0.6)
		await _snap("catalogo2_busqueda")
		print("V2N CATÁLOGO búsqueda «%s»: %s" % [le.text, _texts(gs().catalog, 1500)])
	var bs: Array = gs().catalog.find_children("*", "Button", true, false).filter(func(x): return (x as Button).is_visible_in_tree() and not (x as Button).disabled)
	print("V2N CATÁLOGO botones: ", str(bs.map(func(x): return x.text)).left(1000))
	var target: Button = null
	for x in bs:
		var t := String(x.text).to_lower()
		if target == null and (t.contains("gazette") or t.contains("pedir")):
			target = x
	if target == null and not bs.is_empty():
		target = bs[0]
	if target != null:
		await _click(_c(target))
		await _wait(1.2)
		await _snap("catalogo2_pedido")
		print("V2N CATÁLOGO tras «%s»: %s · lector=%s" % [target.text, _texts(gs().catalog, 1200), str(shell.reader_open())])
		var bs2: Array = gs().catalog.find_children("*", "Button", true, false).filter(func(x): return (x as Button).is_visible_in_tree() and not (x as Button).disabled)
		print("V2N CATÁLOGO botones 2: ", str(bs2.map(func(x): return x.text)).left(1000))
	if shell.reader_open():
		await _reader_probe("catalogo")
		await _close_reader()
	await _clear_top()

func _talk_watson() -> void:
	var sp = shell.panel("scene")
	if sp == null or not shell.is_open("scene"):
		print("V2N Watson: no hay banda de escena")
		return
	var blk = _find(sp, "Personaje_watson")
	var ask = _find(blk if blk != null else sp, "Verbo_ask")
	if ask != null:
		await _click_ctrl(ask)
		await _wait(0.6)
		var ap = sp.ask_panel
		var items: Array = []
		for i in ap._list.item_count:
			items.append("%d:%s%s" % [i, ap._list.get_item_text(i), "" if ap._list.is_item_selectable(i) else "(no)"])
		print("V2N WATSON temas: ", str(items))
		for i in ap._list.item_count:
			if ap._list.is_item_selectable(i) and not String(ap._list.get_item_text(i)).begins_with("›"):
				var r: Rect2 = ap._list.get_item_rect(i)
				await _click(ap._list.get_global_transform_with_canvas() * r.get_center())
				await _wait(0.3)
				break
		await _snap("d4_watson_tema")
		await _click(_c(ap._ok))
		await _wait(2.0)
		await _snap("d4_watson_respuesta")
		var lines: Array = g.sim.q_scene().get("lines", [])
		for ln in lines.slice(maxi(0, lines.size() - 5)):
			print("V2N WATSON dice: %s" % String(ln.get("parsed", {}).get("plain", ln.get("text", ""))).left(500))
		await _speech_through("watson", 10)
		if sp.sub_open() != "":
			sp.close_sub()
			await _wait(0.3)
	var say = _find(blk if blk != null else sp, "Verbo_assert")
	if say != null and (say as Control).is_visible_in_tree():
		await _click_ctrl(say)
		await _wait(0.6)
		await _snap("d4_watson_decir")
		print("V2N WATSON decir: ", _texts(sp.ask_panel, 900))
		_inventory("decir_watson", sp.ask_panel)
		if sp.sub_open() != "":
			sp.close_sub()
			await _wait(0.3)
	var show = _find(blk if blk != null else sp, "Verbo_present")
	if show != null:
		await _click_ctrl(show)
		await _wait(0.7)
		var cards: Array = sp.picker.cards() if sp.picker != null and sp.picker.visible else []
		if not cards.is_empty():
			await _click(_c(cards[mini(1, cards.size() - 1)].node))
			await _wait(0.6)
			await _snap("d4_watson_mostrar")
			var pb = sp.present_bar if "present_bar" in sp else sp
			print("V2N WATSON mostrar barra: ", _texts(pb, 600))
			var ok: Button = null
			for b in pb.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and String((b as Button).text) == Widgets.t("sceneui.present.ok"):
					ok = b
			if ok != null:
				await _click(_c(ok))
				await _wait(2.0)
				await _snap("d4_watson_mostrar_resp")
				var l2: Array = g.sim.q_scene().get("lines", [])
				for ln in l2.slice(maxi(0, l2.size() - 3)):
					print("V2N WATSON tras mostrar: %s" % String(ln.get("parsed", {}).get("plain", ln.get("text", ""))).left(500))
				await _speech_through("watson2", 10)

# ================================================================== FASE E: compositores, usables 3D, pila de la cámara
func _fase_e() -> void:
	var c: Dictionary = g.sim.q_clock()
	print("V2N FASE E en %s fase=%s" % [TimeKey.label(int(c.tk)), String(c.phase)])
	await _clear_top()
	for i in 3:
		await _rclick(Vector2(800, 450))
		await _wait(0.5)
	print("V2N POSE inicial E: ", _pose())
	# compositores del tintero (por índice, re-abriendo la tarjeta cada vez)
	for k in 3:
		await _clear_top()
		for j in 2:
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
		await _click(_node_pos("tintero"))
		await _wait(1.0)
		var links := _exam_links()
		if k >= links.size():
			break
		var t := String(links[k].text)
		await _click(_c(links[k]))
		await _wait(1.0)
		await _snap("e_compositor_%d" % k)
		var top = shell.top()
		print("V2N COMPOSITOR «%s» arriba=%s: %s" % [t, shell.top_kind(), _texts(top, 1500)])
		_inventory("compositor_" + str(k), top)
		if top != null and top.has_method("forms_available"):
			print("V2N COMPOSITOR formas: ", str(top.forms_available()))
		# abrir el primer hueco/destino para ver opciones
		var bl: Button = null
		if top != null:
			for b in top.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and String((b as Button).text).contains("___"):
					bl = b
					break
		if bl != null:
			await _click(_c(bl))
			await _wait(0.5)
			await _snap("e_compositor_%d_hueco" % k)
			var pm: PopupMenu = bl.get("_popup") if "_popup" in bl else null
			if pm != null and pm.visible:
				var its: Array = []
				for i in pm.item_count:
					its.append(pm.get_item_text(i))
				print("V2N COMPOSITOR hueco opciones: ", str(its))
				pm.hide()
	await _clear_top()
	# pila de poses: objeto -> zona -> general con clic derecho
	for j in 3:
		await _rclick(Vector2(800, 450))
		await _wait(0.5)
	print("V2N PILA 0: ", _pose())
	await _click(_node_pos("escritorio"))
	await _wait(0.8)
	print("V2N PILA clic escritorio: ", _pose(), " tarjeta=", gs().exam.visible)
	await _snap("e_pila_escritorio")
	await _click(_node_pos("monedas"))
	await _wait(0.9)
	print("V2N PILA clic monedas: ", _pose(), " tarjeta=", _texts(gs().exam, 300))
	await _snap("e_pila_monedas")
	await _rclick(Vector2(800, 450))
	await _wait(0.7)
	print("V2N PILA clic derecho 1: ", _pose(), " tarjeta=", gs().exam.visible)
	await _rclick(Vector2(800, 450))
	await _wait(0.7)
	print("V2N PILA clic derecho 2: ", _pose())
	await _rclick(Vector2(800, 450))
	await _wait(0.7)
	print("V2N PILA clic derecho 3: ", _pose(), " arriba=", shell.top_kind())
	await _snap("e_pila_fin")
	if shell.top() != null:
		await _key(KEY_ESCAPE)
		await _wait(0.4)
	# flechas del teclado
	var y0 := _yaw()
	var ev := InputEventKey.new()
	ev.keycode = KEY_LEFT
	ev.physical_keycode = KEY_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(1.0)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.4)
	print("V2N FLECHA izq 1 s: yaw %.1f -> %.1f" % [y0, _yaw()])
	# usables en 3D desde la general: cuaderno, calendario, bandeja
	for nid in ["cuaderno", "calendario", "bandeja", "libro_mayor"]:
		await _clear_top()
		for j in 2:
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
		var p := _node_pos(nid)
		_mm(p)
		await _wait(0.4)
		var hov := _hover_text()
		var cur := _cursor_name()
		await _click(p)
		await _wait(0.9)
		print("V2N USABLE %s: etiqueta «%s» cursor=%s -> arriba=%s modal=%s tarjeta=%s pose=%s" % [nid, hov, cur, shell.top_kind(), str(gs().modal() != null), str(gs().exam.visible), _pose()])
		await _snap("e_usable_" + nid)
		if gs().modal() != null:
			await _click(_c(_button(gs().modal(), Widgets.t("kit.back")) if _button(gs().modal(), Widgets.t("kit.back")) != null else _first_enabled_button(gs().modal())))
			await _wait(0.4)
	await _clear_top()

func _end_turn_once() -> void:
	var c: Dictionary = g.sim.q_clock()
	if String(c.phase) != "desk":
		return
	await _clear_top()
	await _click_ctrl(gs().hud.card)
	await _wait(0.6)
	var m = gs().modal()
	if m == null:
		return
	await _click(_c(_first_enabled_button(m, true)))
	await _until(func(): return g.sim == null or g.sim.q_clock() != c, 600)
	await _idle()
	await _wait(0.8)

func _catalog_probe(day: int) -> void:
	await _clear_top()
	var ok := await _click_label(["catálogo", "catalogo", "fichero", "mostrador"], "d%d_sala_busca_catalogo" % day, 50)
	await _wait(0.8)
	await _snap("d%d_catalogo" % day)
	_dump("d%d_catalogo" % day)
	if gs().exam.visible and not gs().catalog.visible:
		await _exam_click(func(t): return true, "catalogo_tarjeta")
		await _wait(0.8)
	if gs().catalog.visible:
		_inventory("catalogo", gs().catalog)
		print("V2N CATÁLOGO: ", _texts(gs().catalog, 1500))
		await _snap("d%d_catalogo_abierto" % day)
		var le: LineEdit = null
		for x in gs().catalog.find_children("*", "LineEdit", true, false):
			if (x as LineEdit).is_visible_in_tree():
				le = x
		if le != null:
			await _click(_c(le))
			for ch in "gazette":
				var ev := InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(ch.to_upper())
				ev.unicode = ch.unicode_at(0)
				ev.pressed = true
				Input.parse_input_event(ev)
				await tool.frames(2)
				var up := ev.duplicate()
				up.pressed = false
				Input.parse_input_event(up)
				await tool.frames(2)
			await _wait(0.6)
			await _snap("d%d_catalogo_busqueda" % day)
			print("V2N CATÁLOGO búsqueda: ", _texts(gs().catalog, 1200))
		var b := _first_enabled_button(gs().catalog)
		var bs: Array = gs().catalog.find_children("*", "Button", true, false).filter(func(x): return (x as Button).is_visible_in_tree() and not (x as Button).disabled)
		print("V2N CATÁLOGO botones: ", str(bs.map(func(x): return x.text)).left(800))
		for x in bs:
			var t := String(x.text).to_lower()
			if t.contains("gazette") or t.contains("pedir"):
				await _click(_c(x))
				await _wait(1.0)
				await _snap("d%d_catalogo_pedido" % day)
				print("V2N CATÁLOGO tras pedir: ", _texts(gs().catalog, 900), " lector=", shell.reader_open())
				break
		if shell.reader_open():
			await _reader_probe("catalogo")
			await _close_reader()
	else:
		print("V2N el catálogo no se abrió")
	await _clear_top()
