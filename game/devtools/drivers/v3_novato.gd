# devtools/drivers/v3_novato.gd — PLAYTEST v3 «jugador novato real» (sólo diagnóstico; no arregla nada).
# Se juega POR TRAMOS, como una persona: cada corrida lee una lista de comandos (lo que el jugador hace con el mouse y el
# teclado después de MIRAR la captura anterior) y la partida sigue en la corrida siguiente con «Continuar» (clic real).
# Todo es input real (warp_mouse + Input.parse_input_event, helpers de w3int_flow), SIN --fast. Partida aparte:
# user://saves/v3novato.jsonl (nunca .work/jugador/). Sonido: suena (subtítulos visibles) pero con el Master a −80 dB
# (después de los efectos): una captura en el Master mide lo que oiría el jugador (comando listen).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3n_<tramo> res://devtools/drivers/v3_novato.gd --v3n-cmds=.work/v3nov/<tramo>.txt [--v3n-new]
# Comandos (uno por renglón; # comenta):
#   snap N | gsnap N (con grilla cada 100 px) · click X Y · rclick X Y · dclick X Y · hover X Y [s] · clicktext TEXTO
#   drag X1 Y1 X2 Y2 · seldrag X1 Y1 X2 Y2 (arrastre lento con la tijera) · key NOMBRE · keyhold NOMBRE s · type TEXTO
#   wait s · edge L|R s · wheel UP|DOWN X Y n · idle · state · texts [filtro] · buttons · sweep N (barrido de hover)
#   listen s (nivel del sonido) · quit
extends "res://devtools/drivers/w3int_flow.gd"

const CursorsK = preload("res://ui/desk/cursors.gd")
const An = preload("res://audio/analysis.gd")

var _new := false
var _cap: AudioEffectCapture = null
var _subs: Array = []

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(580.0).timeout.connect(func():
		print("V3N VIGIA 580 s")
		if g != null and g.sim != null:
			g.end_session()
		tool.quit(2))
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	var path := ""
	var save := "v3novato"
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--v3n-cmds="):
			path = s.substr(11)
		elif s.begins_with("--v3n-save="):
			save = s.substr(11)
		elif s == "--v3n-new":
			_new = true
	g.save_path = "user://saves/%s.jsonl" % save
	if _new:
		for suf in ["", ".bak", ".tmp", ".fin"]:
			var p := ProjectSettings.globalize_path(g.save_path + suf)
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	_audio_setup()
	var au = tool.root.get_node_or_null("Audio")
	if au != null and au.has_signal("subtitle"):
		au.subtitle.connect(func(t, s): _subs.append(String(t)); print("V3N SUBTITULO «%s»" % String(t)))
	await _settle_window()
	shell.show_title()
	await tool.frames(40)
	var full := ProjectSettings.globalize_path("res://").path_join("..").path_join(path)
	var f := FileAccess.open(full, FileAccess.READ)
	if f == null:
		print("V3N sin comandos en ", full)
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	for ln in lines:
		var s := String(ln).strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		if s == "quit":
			break
		_audio_quiet()
		await _cmd(s)
	print("V3N FIN capturas=%d" % _shot)
	if g.sim != null:
		g.end_session()

func _v(sp: PackedStringArray, i: int) -> Vector2:
	return Vector2(float(sp[i]), float(sp[i + 1]))

func _cmd(s: String) -> void:
	var sp := s.split(" ", false)
	var c := String(sp[0])
	var rest := s.substr(c.length()).strip_edges()
	print("V3N > ", s)
	match c:
		"snap":
			await _nsnap(rest, false)
		"gsnap":
			await _nsnap(rest, true)
		"click":
			var p := _v(sp, 1)
			var before := _pick_at(p)
			await _click(p)
			await _after(p, before)
		"rclick":
			await _rclick(_v(sp, 1))
			await _after(_v(sp, 1), "")
		"dclick":
			var p := _v(sp, 1)
			await _click(p)
			_btn(p, true)
			await tool.frames(1)
			_btn(p, false)
			await _after(p, "")
		"hover":
			var p := _v(sp, 1)
			_mm(p)
			await _hold_at(p, float(sp[3]) if sp.size() > 3 else 0.7)
			print("V3N HOVER %s pick=%s cursor=%s gui=%s" % [p, _pick_at(p), _cursor_name(), _gui_at()])
		"clicktext":
			await _click_text(rest)
		"drag":
			var a := _v(sp, 1)
			var b := _v(sp, 3)
			var n0 := _proofs_sig()
			await _drag(a, b)
			await _wait(0.4)
			print("V3N DRAG %s -> %s top=%s pruebas %s -> %s" % [a, b, shell.top_kind(), n0, _proofs_sig()])
		"seldrag":
			await _seldrag(_v(sp, 1), _v(sp, 3))
		"selclip":
			await _selclip(rest)
		"readall":
			await _readall(rest)
		"key":
			await _key(_kc(String(sp[1])))
			await _wait(0.4)
			print("V3N KEY %s top=%s fase=%s" % [sp[1], shell.top_kind(), _phase()])
		"keyhold":
			await _keyhold(_kc(String(sp[1])), float(sp[2]))
		"type":
			await _type_text(rest)
		"wait":
			await _hold_at(_last, float(sp[1]))
		"edge":
			var at := Vector2(3, 450) if String(sp[1]) == "L" else Vector2(1597, 450)
			var y0 := _yaw_s()
			var dur := float(sp[2])
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < int(dur * 1000.0):
				_pm(at)
				await tool.frames(1)
			await _hold_at(Vector2(800, 450), 0.6)
			print("V3N EDGE %s %.1fs yaw %s -> %s" % [sp[1], dur, y0, _yaw_s()])
		"wheel":
			var p := _v(sp, 2)
			for _i in int(sp[4]):
				_mm(p)
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_WHEEL_UP if String(sp[1]) == "UP" else MOUSE_BUTTON_WHEEL_DOWN
				ev.pressed = true
				ev.factor = 1.0
				ev.position = p
				ev.global_position = p
				Input.parse_input_event(ev)
				var u := ev.duplicate()
				u.pressed = false
				Input.parse_input_event(u)
				await tool.frames(3)
			await _wait(0.4)
		"idle":
			await _idle()
		"state":
			_state()
		"texts":
			_texts(rest)
		"buttons":
			_buttons()
		"sweep":
			await _sweep(rest)
		"listen":
			await _listen(float(sp[1]), rest)
		"talk":
			await _talk(int(sp[1]) if sp.size() > 1 else 20)
		"note":
			_note()
		"edgeprobe":
			await _edgeprobe(String(sp[1]), float(sp[2]))
		"eval":
			var ex := Expression.new()
			if ex.parse(rest, ["sim", "shell", "g"]) == OK:
				print("V3N EVAL %s = %s" % [rest, str(ex.execute([g.sim, shell, g], null, false)).left(3000)])
			else:
				print("V3N EVAL error de sintaxis: ", ex.get_error_text())
		_:
			print("V3N comando desconocido: ", s)

func _phase() -> String:
	return String(g.sim.q_clock().phase) if g.sim != null else "-"

func _yaw_s() -> String:
	var rig = shell.world.rig if shell.world != null and "rig" in shell.world else null
	if rig == null:
		return "-"
	var y = rig.get("yaw_off") if "yaw_off" in rig else rig.get("yaw")
	return str(y)

func _pick_at(p: Vector2) -> String:
	if shell.world == null or not shell.world.has_method("pick"):
		return "-"
	var r = shell.world.pick(p)
	return String(r.get("id", "")) if typeof(r) == TYPE_DICTIONARY else "-"

func _gui_at() -> String:
	var h = vp.gui_get_hovered_control()
	if h == null:
		return "-"
	var t := ""
	if h is Button:
		t = (h as Button).text
	elif h is Label:
		t = (h as Label).text
	return "%s:%s«%s»" % [h.get_class(), h.name, t.left(40)]

func _cursor_name() -> String:
	match DisplayServer.cursor_get_shape():
		DisplayServer.CURSOR_ARROW: return "flecha"
		DisplayServer.CURSOR_HELP: return "lupa"
		DisplayServer.CURSOR_POINTING_HAND: return "mano"
		DisplayServer.CURSOR_IBEAM: return "texto/tijera"
		DisplayServer.CURSOR_DRAG: return "arrastre"
		DisplayServer.CURSOR_MOVE: return "mover"
		DisplayServer.CURSOR_CROSS: return "cruz"
	return str(DisplayServer.cursor_get_shape())

func _after(p: Vector2, before: String) -> void:
	await _wait(0.5)
	print("V3N CLICK %s pick_antes=%s top=%s fase=%s tarjeta=%s lector=%s" % [p, before, shell.top_kind(), _phase(),
		str(gs().exam.visible) if gs() != null else "-", str(shell.reader_open())])

func _proofs_sig() -> String:
	if g.sim == null:
		return "-"
	var out := []
	for h in g.sim.q_dossier().open:
		out.append("%s:%s" % [h.id, str((h.proofs as Array).map(func(c): return "" if c == null else String(c.get("id", ""))))])
	return ",".join(out)

# ---------------------------------------------------------------- captura con el cursor dibujado
func _nsnap(name: String, grid: bool) -> void:
	_shot += 1
	_pm(_last)
	await tool.frames(2)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var mp := _last
	var cur: Image = null
	var hot := Vector2i.ZERO
	match DisplayServer.cursor_get_shape():
		DisplayServer.CURSOR_HELP:
			cur = CursorsK.lens(); hot = Vector2i(12, 12)
		DisplayServer.CURSOR_POINTING_HAND:
			cur = CursorsK.hand(); hot = Vector2i(11, 2)
		DisplayServer.CURSOR_IBEAM:
			if gs() != null and bool(gs().state().get("scissors", false)):
				cur = CursorsK.scissors_img(32); hot = Vector2i(6, 6)
	if cur != null:
		cur.convert(Image.FORMAT_RGBA8)
		img.blend_rect(cur, Rect2i(Vector2i.ZERO, cur.get_size()), Vector2i(mp) - hot)
	else:
		# flecha: una cruz chica roja donde está el mouse
		for k in range(-7, 8):
			for d in [0, 1]:
				_px(img, int(mp.x) + k, int(mp.y) + d, Color(0.9, 0.1, 0.1))
				_px(img, int(mp.x) + d, int(mp.y) + k, Color(0.9, 0.1, 0.1))
	if grid:
		for x in range(100, img.get_width(), 100):
			for y in img.get_height():
				_px(img, x, y, Color(1, 0, 1, 0.55) if x % 500 != 0 else Color(0, 0.8, 1, 0.8))
		for y in range(100, img.get_height(), 100):
			for x in img.get_width():
				_px(img, x, y, Color(1, 0, 1, 0.55) if y % 500 != 0 else Color(0, 0.8, 1, 0.8))
	var p: String = tool.out_dir.path_join("%s_%02d_%s.png" % [tool.prefix, _shot, name])
	img.save_png(p)
	print("SNAP ", p, " cursor=", _cursor_name(), " mouse=", mp, " os=", vp.get_mouse_position())

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(c))

# ---------------------------------------------------------------- lo que el jugador ve (texto en pantalla)
func _visible_controls() -> Array:
	var out: Array = []
	var screen := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	for n in tool.root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x < 2 or r.size.y < 2 or not screen.intersects(r):
			continue
		out.append(c)
	return out

func _ctext(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	if c is Label:
		return (c as Label).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return "[campo] " + (c as LineEdit).text + " / " + (c as LineEdit).placeholder_text
	return ""

func _texts(filt: String) -> void:
	var seen := {}
	for c in _visible_controls():
		var t := _ctext(c).strip_edges()
		if t == "" or (filt != "" and not t.to_lower().contains(filt.to_lower())):
			continue
		var r: Rect2 = c.get_global_rect()
		var k := "%d,%d:%s" % [int(r.position.x), int(r.position.y), t.left(30)]
		if seen.has(k):
			continue
		seen[k] = true
		print("V3N TEXTO [%s @%d,%d %dx%d] %s" % [c.get_class(), int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y), t.replace("\n", " ⏎ ").left(600)])

func _buttons() -> void:
	for c in _visible_controls():
		if c is BaseButton:
			var r: Rect2 = c.get_global_rect()
			var t := _ctext(c)
			if t == "" and c is TextureButton:
				t = "[ícono %s]" % c.name
			print("V3N BOTON «%s» centro=%d,%d %s%s" % [t.replace("\n", " ").left(60), int(r.get_center().x), int(r.get_center().y), c.name, " (deshabilitado)" if (c as BaseButton).disabled else ""])

func _click_text(txt: String) -> void:
	var want := txt.to_lower()
	var best: Control = null
	var exact: Control = null
	for c in _visible_controls():
		if not (c is BaseButton or c is Label):
			continue
		var t := _ctext(c).strip_edges().to_lower()
		if t == want and c is BaseButton:
			exact = c
		elif t.contains(want) and best == null:
			best = c
	var hit: Control = exact if exact != null else best
	if hit == null:
		print("V3N CLICKTEXT «%s»: no está en pantalla" % txt)
		return
	var p := hit.get_global_rect().get_center()
	print("V3N CLICKTEXT «%s» -> %s «%s» en %s" % [txt, hit.get_class(), _ctext(hit).left(60), p])
	await _click(p)
	await _after(p, "")

# ---------------------------------------------------------------- tijera, teclas
func _seldrag(a: Vector2, b: Vector2) -> void:
	var n0: int = g.sim.q_clips().size() if g.sim != null else 0
	_mm(a)
	await tool.frames(2)
	await _sync_mouse(a)
	_mm(a)
	_btn(a, true)
	await tool.frames(2)
	for i in range(1, 16):
		_mm(a.lerp(b, float(i) / 15.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	var rtl = vp.gui_get_hovered_control()
	for _k in 30:
		_mm(b, MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	if rtl is RichTextLabel:
		print("V3N SELECCION «%s» (os=%s)" % [(rtl as RichTextLabel).get_selected_text(), vp.get_mouse_position()])
	else:
		print("V3N SELECCION bajo el mouse: %s" % _gui_at())
	_btn(b, false)
	await _wait(0.6)
	var cl: Array = g.sim.q_clips() if g.sim != null else []
	if cl.size() > n0:
		var c: Dictionary = cl[-1]
		print("V3N RECORTE nuevo «%s» (%s) origen=%s" % [String(c.get("text", "")), String(c.get("id", "")), str(c.get("origin", c.get("src", "")))])
	else:
		print("V3N RECORTE ninguno (top=%s)" % shell.top_kind())

func _kc(name: String) -> Key:
	match name.to_upper():
		"ESC", "ESCAPE": return KEY_ESCAPE
		"TAB": return KEY_TAB
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"ENTER": return KEY_ENTER
		"SPACE": return KEY_SPACE
		"BACKSPACE": return KEY_BACKSPACE
	return OS.find_keycode_from_string(name.to_upper())

func _keyhold(code: Key, sec: float) -> void:
	var y0 := _yaw_s()
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(sec)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _wait(0.5)
	print("V3N KEYHOLD yaw %s -> %s" % [y0, _yaw_s()])

func _type_text(text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch.to_upper())
		e.pressed = true
		Input.parse_input_event(e)
		await tool.frames(1)
		var u := e.duplicate()
		u.pressed = false
		Input.parse_input_event(u)
		await tool.frames(1)
	await _wait(0.3)

# ---------------------------------------------------------------- estado (sólo para el informe; no guía al jugador)
func _state() -> void:
	if g.sim == null:
		print("V3N ESTADO sin partida (pantalla=%s)" % str(shell.get("screen")))
		return
	var c: Dictionary = g.sim.q_clock()
	var d: Dictionary = g.sim.q_dossier()
	var gsc = gs()
	var tut := ""
	if gsc != null and gsc.tutor.visible:
		tut = String(gsc.tutor.text.get_parsed_text()).replace("\n", " / ")
	var guide: Array = gsc.hud.guide_lines() if gsc != null and gsc.hud.has_method("guide_lines") else []
	print("V3N ESTADO día %s %s fase=%s top=%s pila=%s" % [str(c.get("day")), str(c.get("slot")), str(c.get("phase")), shell.top_kind(), str(shell.stack.map(func(e): return String(e.kind))) if "stack" in shell else "?"])
	print("V3N ESTADO expediente abiertas=%s tinta=%s" % [str(d.open.map(func(h): return "%s «%s» resp=%s pruebas=%s" % [h.id, h.text, str(h.answer), str((h.proofs as Array).map(func(x): return "" if x == null else String(x.get("text", "")).left(40)))])), str(d.inked.map(func(h): return h.id))])
	print("V3N ESTADO nota=«%s» pendientes=%s" % [tut, str(guide)])
	print("V3N ESTADO recortes=%d lugares=%s faltan=%s amb=%s" % [g.sim.q_clips().size(), str(g.sim.q_places().map(func(p): return String(p.get("id", "")))), str(g.sim.q_missing()) if g.sim.has_method("q_missing") else "?", _amb()])

func _amb() -> String:
	var au = tool.root.get_node_or_null("Audio")
	return String(au.current_amb()) if au != null and au.has_method("current_amb") else "-"

# ---------------------------------------------------------------- barrido de hover (mover el mouse por la pantalla)
func _sweep(tag: String) -> void:
	var seen := {}
	for y in range(100, 800, 40):
		for x in range(140, 1460, 40):
			var p := Vector2(x, y)
			_pm(p)
			await tool.frames(2)
			var hov = vp.gui_get_hovered_control()
			if hov != null and hov.mouse_filter == Control.MOUSE_FILTER_STOP:
				continue
			var id := _pick_at(p)
			if id == "" or id == "-":
				continue
			if not seen.has(id):
				for _k in 4:
					_pm(p)
					await tool.frames(1)
				seen[id] = {"pos": p, "cursor": _cursor_name(), "n": 0}
			seen[id].n += 1
	var lst: Array = []
	for id in seen.keys():
		lst.append("%s@%d,%d(%s,%d)" % [id, int(seen[id].pos.x), int(seen[id].pos.y), seen[id].cursor, seen[id].n])
	print("V3N SWEEP %s: %d cosas: %s" % [tag, seen.size(), ", ".join(lst)])

# ---------------------------------------------------------------- sonido
func _audio_setup() -> void:
	var mi := AudioServer.get_bus_index("Master")
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	AudioServer.add_bus_effect(mi, _cap, 0)
	_audio_quiet()

func _audio_quiet() -> void:
	var mi := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(mi, -80.0)
	AudioServer.set_bus_mute(mi, false)

func _listen(sec: float, tag: String) -> void:
	if _cap == null:
		return
	_cap.clear_buffer()
	var x := PackedFloat32Array()
	var t0 := Time.get_ticks_msec()
	_subs.clear()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await tool.frames(1)
		_audio_quiet()
		var n := _cap.get_frames_available()
		if n > 0:
			for v in _cap.get_buffer(n):
				x.append((v.x + v.y) * 0.5)
	var rate := AudioServer.get_mix_rate()
	var win := int(rate * 0.4)
	var loud := -120.0
	var i := 0
	while i + win <= x.size():
		var s := 0.0
		for k in range(i, i + win, 4):
			s += x[k] * x[k]
		loud = maxf(loud, 10.0 * log(maxf(s / float(win / 4), 1e-12)) / log(10.0))
		i += win
	print("V3N SONIDO [%s] %.1fs (%d muestras a %d Hz) amb=%s RMS=%.1f dBFS siseo(2-8k)=%.1f dBFS ventana_max(0,4s)=%.1f dBFS subtitulos=%s" % [
		tag, sec, x.size(), int(rate), _amb(), An.rms_db(x), An.band_rms_db(x, 2000.0 * 44100.0 / rate, 8000.0 * 44100.0 / rate), loud, str(_subs)])

# ---------------------------------------------------------------- lo dicho: leer y «Seguir» con el mouse
func _talk(maxn: int) -> void:
	var n := 0
	for _w in 40:
		if gs() != null and gs().speech.visible:
			break
		await _hold_at(_last, 0.1)
	while n < maxn:
		var gsc = gs()
		if gsc == null or not gsc.speech.visible:
			break
		var who := ""
		for c in gsc.speech.find_children("*", "Label", true, false):
			if (c as Label).is_visible_in_tree() and (c as Label).text != "":
				who = (c as Label).text
				break
		var before := String(gsc.speech.text.get_parsed_text())
		print("V3N DICHO [%s] %s" % [who, before.replace("\n", " / ")])
		var more = gsc.speech.get("more")
		var p: Vector2 = (more as Control).get_global_rect().get_center() if more is Control and (more as Control).is_visible_in_tree() else (gsc.speech as Control).get_global_rect().get_center()
		await _click(p)
		await _wait(0.6)
		n += 1
		if gsc.speech.visible and String(gsc.speech.text.get_parsed_text()) == before:
			await _wait(1.0)
			if gsc.speech.visible and String(gsc.speech.text.get_parsed_text()) == before:
				print("V3N DICHO no avanza")
				break
	_note()

func _note() -> void:
	var gsc = gs()
	if gsc == null:
		return
	if gsc.tutor.visible:
		print("V3N NOTA «%s»" % String(gsc.tutor.text.get_parsed_text()).replace("\n", " / "))
	var guide: Array = gsc.hud.guide_lines() if gsc.hud.has_method("guide_lines") else []
	if not guide.is_empty():
		print("V3N PENDIENTES %s" % str(guide))

# Movimiento del mouse SIN mover el cursor del sistema (el usuario puede estar usando su mouse): sólo el evento.
func _pm(pos: Vector2, mask := 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last
	ev.button_mask = mask
	_last = pos
	Input.parse_input_event(ev)

# Deja el mouse quieto en p durante sec (reenvía el evento cada cuadro: pisa movimientos ajenos del cursor del sistema).
func _hold_at(p: Vector2, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		_pm(p)
		await tool.frames(1)

# Recortar un texto que el jugador VE en pantalla: arrastre real sobre esas palabras (hasta 3 intentos, con el cursor del
# sistema llevado al punto cada cuadro). Si el cursor del sistema no obedece (el usuario usa su mouse), en el lector se
# sigue por Game.act con la misma selección y se avisa «RESPALDO (entorno)».
func _selclip(txt: String) -> void:
	var rtl: RichTextLabel = null
	var blk := -1
	var rd = shell.reader if shell.reader_open() else null
	if rd != null:
		for i in 40:
			var r: RichTextLabel = rd.block_rtl(i)
			if r == null:
				break
			if r.is_visible_in_tree() and r.get_parsed_text().contains(txt):
				rtl = r
				blk = i
				break
	if rtl == null:
		for c in _visible_controls():
			if c is RichTextLabel and (c as RichTextLabel).get_parsed_text().contains(txt):
				rtl = c
	if rtl == null:
		print("V3N SELCLIP «%s»: no está en pantalla" % txt)
		return
	var from := rtl.get_parsed_text().find(txt)
	var to := from + txt.length()
	var n0: int = g.sim.q_clips().size()
	for attempt in 3:
		var pts: Array = SelectionMapper.drag_points(rtl, from, to)
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		_mm(a)
		await tool.frames(2)
		await _sync_mouse(a)
		_mm(a)
		_btn(a, true)
		await tool.frames(2)
		for i in range(1, 16):
			_mm(a.lerp(b, float(i) / 15.0), MOUSE_BUTTON_MASK_LEFT)
			await tool.frames(1)
		var sel := ""
		for _k in 40:
			_mm(b, MOUSE_BUTTON_MASK_LEFT)
			await tool.frames(1)
			sel = rtl.get_selected_text().strip_edges()
			if sel == txt.strip_edges():
				break
		if sel != txt.strip_edges():
			# selección equivocada por el cursor del sistema: se vuelve al punto de partida para no dejar un recorte basura
			for _k in 6:
				_mm(a, MOUSE_BUTTON_MASK_LEFT)
				await tool.frames(1)
			rtl.deselect()
			_btn(a, false)
			await _wait(0.5)
			print("V3N SELCLIP intento %d cancelado: seleccionado «%s»" % [attempt + 1, sel])
			if g.sim.q_clips().size() > n0:
				print("V3N SELCLIP OJO: quedó un recorte «%s»" % String(g.sim.q_clips()[-1].get("text", "")))
				break
			continue
		_btn(b, false)
		await _wait(0.7)
		print("V3N SELCLIP intento %d: seleccionado «%s»" % [attempt + 1, sel])
		if g.sim.q_clips().size() > n0:
			break
		if attempt == 0:
			await _snap_err("selclip_fallido")
	if g.sim.q_clips().size() > n0:
		var c: Dictionary = g.sim.q_clips()[-1]
		print("V3N RECORTE nuevo «%s» (%s)" % [String(c.get("text", "")), String(c.get("id", ""))])
		return
	if rd != null and blk >= 0:
		var r: Dictionary = g.act({"t": "clip_text", "src": {"kind": "doc", "ref": String(rd.view.get("view", "")), "part": int(rd.page_idx), "block": blk}, "from": from, "len": to - from})
		print("V3N RESPALDO (entorno: el cursor del sistema no obedece) clip_text -> %s «%s»" % [str(r.get("ok")) if r.get("ok", false) else str(r.get("err")), String(g.sim.q_clip(String(r.get("clip", ""))).get("text", "")) if r.get("ok", false) else ""])
	else:
		print("V3N RECORTE ninguno")

func _snap_err(name: String) -> void:
	await _nsnap(name, false)

# Todas las hojas del documento abierto con la flecha de abajo (clic real); captura y vuelca cada bloque con su lugar.
func _readall(tag: String) -> void:
	if not shell.reader_open():
		print("V3N READALL sin lector")
		return
	var rd = shell.reader
	var v: Dictionary = rd.view
	print("V3N DOC %s «%s» hojas=%d ficha=%s marcas=%s" % [String(v.get("view", "")), String(v.get("title", "")), rd.page_count(), str(v.get("ficha")), str(v.get("marks", []))])
	for pi in rd.page_count():
		await _hold_at(_last, 0.4)
		await _nsnap("%s_p%d" % [tag, int(rd.page_idx) + 1], false)
		var pg: Array = v.pages[int(rd.page_idx)] if int(rd.page_idx) < (v.pages as Array).size() else []
		for bi in pg.size():
			var b: Dictionary = pg[bi]
			var t := String(b.get("parsed", {}).get("plain", ""))
			print("V3N HOJA %d bloque %d [%s %s] %s" % [int(rd.page_idx) + 1, bi, String(b.get("slot", "")), String(b.get("origin", b.get("doc", ""))), t.replace("
", " / ").left(700)])
		if pi < rd.page_count() - 1:
			var nb = rd.get("_b_next")
			if nb is Control and (nb as Control).is_visible_in_tree():
				await _click((nb as Control).get_global_rect().get_center())
				await _hold_at(_last, 0.4)

# Giro con el borde midiendo, cuadro a cuadro, el salto de la cámara (posición y ángulo) y lo que se ve: ¿se desliza?
func _edgeprobe(side: String, dur: float) -> void:
	var at := Vector2(3, 450) if side == "L" else Vector2(1597, 450)
	var cam: Camera3D = shell.world.camera()
	var last_p := cam.global_position
	var last_b := cam.global_transform.basis
	var max_dp := 0.0
	var max_da := 0.0
	var n := 0
	_tprev = Time.get_ticks_usec()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(dur * 1000.0):
		_pm(at)
		await tool.frames(1)
		var p := cam.global_position
		var b := cam.global_transform.basis
		var q1 := Quaternion(last_b.orthonormalized())
		var q2 := Quaternion(b.orthonormalized())
		var dt := maxf(1.0 / 400.0, float(Time.get_ticks_usec() - _tprev) / 1e6)
		_tprev = Time.get_ticks_usec()
		max_da = maxf(max_da, rad_to_deg(q1.angle_to(q2)) * (1.0 / 60.0) / dt)
		max_dp = maxf(max_dp, p.distance_to(last_p) * (1.0 / 60.0) / dt)
		last_p = p
		last_b = b
		n += 1
	await _hold_at(Vector2(800, 450), 0.6)
	print("V3N EDGEPROBE %s %.1fs cuadros=%d fps=%.0f max_salto_pos(a 60 fps)=%.3f m max_salto_ang(a 60 fps)=%.2f° yaw=%s pos=%s" % [side, dur, n, Engine.get_frames_per_second(), max_dp, max_da, _yaw_s(), str(cam.global_position)])

var _tprev := 0
