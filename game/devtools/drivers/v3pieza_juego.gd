# devtools/drivers/v3pieza_juego.gd — REACCIONES-PIEZA (verificación, GDD_v3 §4): las intrusiones en el JUEGO REAL, sin
# --fast, con la ventana. El bot pasivo lleva la partida al día 3 por el sim; desde ahí el driver sale (go/slip/leave por
# Game.act), y en la pieza usa el mouse real (hover → contorno + cursor; clic → tarjeta). Capturas en .work/shots/
# v3pj_<n>.png. Recorre: antes · HA5 (techos, al volver de la Sala de Lectura) · ventana_abierta (Q8) · el estante con
# el faltante · informe con un original P · día 4: FINA de vuelta con «v.» · M1 al volver de la salida (las dos firmas) ·
# ceniza · día 5 sólo registrada · día 6 nada.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3pj res://devtools/drivers/v3pieza_juego.gd --mute
# Salida: «V3M OK|FALLA …» y «V3M RESUMEN n fallas».
extends "res://devtools/drivers/v3mundo_base.gd"

const Pasivo = preload("res://devtools/bots/bot_pasivo.gd")

var captions: Array = []

func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = g.act(a)
	await _settle()
	return r

func _close_panels() -> void:
	for _k in 5:
		if shell.top() == null and not gs().exam.visible: break
		await _click(Vector2(800, 120), MOUSE_BUTTON_RIGHT)
		await _wait(0.3)

# Espera a que la cámara se quede quieta (el riel se desliza: de la puerta al escritorio tarda más de 1,6 s).
func _still() -> void:
	var cam: Camera3D = shell.world.camera()
	var last := cam.global_transform
	var quiet := 0
	for _i in 600:
		await tool.process_frame
		var t := cam.global_transform
		quiet = quiet + 1 if t.is_equal_approx(last) else 0
		last = t
		if quiet >= 12: break
	await _wait(0.2)

func _clock() -> Dictionary:
	return g.sim.q_clock()

# Avanza (como el pasivo: sin hacer nada) hasta el escritorio de day/slot. El informe de cada noche: nada, salvo report.
func _advance_to(day: int, slot := "M", report_items := []) -> bool:
	for _i in 120:
		var c := _clock()
		if int(c.day) == day and String(c.slot) == slot and String(c.phase) == "desk":
			await _settle()
			await _close_panels()
			return true
		if int(c.day) > day:
			return false
		match String(c.phase):
			"desk": await _act({"t": "end_slot"})
			"visit", "scene": await _act({"t": "leave"})
			"night":
				if bool(g.sim.q_report_status().get("due", false)):
					var r := await _act({"t": "report_submit", "mode": "items" if not report_items.is_empty() else "nada", "items": report_items})
					if not report_items.is_empty():
						_check(bool(r.get("ok", false)), "informe con el original P: %s" % str(r))
						report_items = []
				else:
					await _act({"t": "sleep"})
			_:
				await _act({"t": "leave"})
	return false

func _shots(prefix: String, frames: Array) -> void:
	for f in frames:
		if not gs().frames().has(f):
			continue
		gs().go_frame(f)
		await _still()
		await _snap("%s_%s" % [prefix, f])
	gs().go_frame("escritorio")
	await _still()

# Punto del nodo más cerca del centro de todos sus puntos (rejilla de 16 px, toda la pantalla salvo 24 px de borde).
func _pt(id: String) -> Vector2:
	var w = shell.world
	var pts: Array = []
	for y in range(24, 876, 16):
		for x in range(24, 1576, 16):
			if String(w.pick(Vector2(x, y)).get("id", "")) == id:
				pts.append(Vector2(x, y))
	if pts.is_empty():
		return Vector2(-1, -1)
	var c := Vector2.ZERO
	for p in pts: c += p
	c /= float(pts.size())
	pts.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return pts[0]

func _hover_click(id: String, shot: String, want_text: String) -> void:
	var p := _pt(id)
	_check(p.x >= 0.0, "%s a la vista desde %s" % [id, gs().frame])
	if p.x < 0.0:
		return
	await _move(p)
	await _wait(0.4)
	var hc = tool.root.get_viewport().gui_get_hovered_control()
	print("V3M DIAG %s: punto %s pick %s control %s" % [id, str(p), str(shell.world.pick(p)), str(hc.get_path()) if hc != null else "-"])
	_check(String(shell.world.hover_id) == id, "hover sobre %s (%s)" % [id, shell.world.hover_id])
	_check(_cursor_name() == "lupa", "%s se mira: lupa (%s)" % [id, _cursor_name()])
	await _snap(shot + "_hover")
	await _click(p)
	await _wait(0.7)
	_check(gs().exam.visible, "clic en %s: su tarjeta" % id)
	var txt: String = gs().exam.body.get_parsed_text() if gs().exam.body != null else ""
	_check(txt.contains(want_text), "%s: «%s» en la tarjeta (%s)" % [id, want_text, txt.left(120)])
	await _snap(shot + "_tarjeta")
	await _close_panels()

func _born(q: String) -> bool:
	var d = g.sim.st.ded.get("dossier", {})
	return typeof(d) == TYPE_DICTIONARY and typeof(d.get("born")) == TYPE_DICTIONARY and d.born.has(q)

func _missing() -> Array:
	var out: Array = []
	for m in g.sim.q_missing():
		out.append(String(m.copy))
	return out

# Un recorte corto de un original P de casa (D02@L1, la prueba de imprenta): para el informe (M1).
func _clip_original(view: String) -> String:
	var v: Dictionary = g.sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var b: Dictionary = pages[pi][bi]
			if String(b.get("slot", "cuerpo")) != "cuerpo":
				continue
			var words: Array = b.get("parsed", {}).get("words", [])
			for st in range(0, mini(words.size(), 40)):
				for ln in [6, 4, 3]:
					var r: Dictionary = g.sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": st, "len": ln})
					if bool(r.get("ok", false)):
						return String(r.get("clip", ""))
	return ""

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(900.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 900 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3pieza_juego.jsonl"):
		_summary()
		return
	var au = tool.root.get_node_or_null("Audio")
	if au != null:
		au.subtitle.connect(func(t, _s): captions.append(String(t)))
	# día 1 → día 3 por la mañana, sin hacer nada (como el pasivo)
	_check(await _advance_to(3, "M"), "día 3 por la mañana en el escritorio")
	await _focus()
	await _shots("a_antes", ["escritorio", "ventana", "estante", "puerta"])
	_check(not String(shell.world.snap.get("variant", "")).contains("techos"), "antes: la ventana cerrada")
	# HA5: papeleta de «El problema final» en la Sala de Lectura (K-BM, en el momento) → al volver, la ventana abierta
	captions.clear()
	var r1 := await _act({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	_check(bool(r1.get("ok", false)), "ir a la Sala de Lectura: %s" % str(r1))
	var r2 := await _act({"t": "slip", "doc": "D03"})
	_check(bool(r2.get("ok", false)), "papeleta D03: %s" % str(r2))
	await _close_panels()
	var r3 := await _act({"t": "leave"})
	_check(bool(r3.get("ok", false)), "volver a casa: %s" % str(r3))
	await _wait(0.5)
	await _snap("b_techos_entrada")
	_check(String(shell.world.snap.get("variant", "")).contains("techos"), "al volver: variante techos (%s)" % shell.world.snap.get("variant", ""))
	_check(_missing().has("D03@tomo"), "falta FINA del estante (%s)" % str(_missing()))
	# con --mute no suena (ni subtitula): se mira que la pieza pidió la ráfaga una vez (game_screen._techos_key)
	_check(int(gs().get("techos_played")) > 0, "la ráfaga al entrar (intrusion_techos pedida)")
	for c in captions:
		_check(not String(c).to_lower().contains("alguien") and not String(c).to_lower().contains("intrus"), "sin carteles: %s" % c)
	_check(not _born("Q8"), "Q8 no nace sólo por ver la pieza")
	print("V3M DIAG avisos en pantalla al volver: %s" % str(shell.notes()))
	await _close_panels()
	await _wait(4.5)
	await _shots("c_techos", ["escritorio", "ventana", "estante", "mapa", "puerta"])
	await _hover_click("ventana_abierta", "d_ventana_abierta", "Está abierta. Yo no la abrí.")
	_check(_born("Q8"), "examinar la ventana abierta hace nacer Q8")
	await _hover_click("papeles_viento", "d_papeles", "Dos hojas en el piso")
	# el estante: el faltante
	gs().go_frame("estante")
	await _still()
	var pe := _safe_point("estante")
	if pe.x >= 0.0:
		await _click(pe)
		await _wait(0.9)
		await _snap("e_estante_falta")
		await _close_panels()
	gs().go_frame("escritorio")
	await _still()
	# un recorte de un original P para el informe de la noche (M1 al día siguiente)
	var clip := _clip_original("D02@L1")
	_check(clip != "", "recorte de la prueba de imprenta (D02@L1)")
	var items: Array = [{"kind": "clip", "id": clip}] if clip != "" else []
	# día 4: FINA vuelve con la marca «v.»; la ventana sigue abierta
	_check(await _advance_to(4, "M"), "día 4 por la mañana")
	_check(not _missing().has("D03@tomo"), "FINA volvió (%s)" % str(_missing()))
	var v: Dictionary = g.sim.q_view("D03@tomo")
	var mk := false
	for pg in v.get("pages", []):
		for bl in pg:
			if String(bl.get("origin", "")).begins_with("R.HA5") and String(bl.get("parsed", {}).get("plain", "")).contains("v."):
				mk = true
	_check(mk, "la marca «v.» al margen de FINA")
	if shell.open_reader("D03@tomo"):
		await _wait(1.5)
		await _snap("f_fina_marca")
		await _close_panels()
	_check(String(shell.world.snap.get("variant", "")).contains("techos"), "día 4: la ventana sigue abierta")
	await _shots("f_dia4", ["escritorio"])
	# M1: el informe de la noche del 5 lleva el recorte del original P → primera salida del día 6: la puerta forzada
	# el domingo 6 sólo tiene la tarde (schedule): la noche del 5 lleva el informe; M1 en la primera salida o esa noche
	_check(await _advance_to(6, "T", items), "domingo 6 por la tarde (informe del 5 con el original)")
	await _shots("f_dia6_antes", ["escritorio"])
	for _k in 3:
		await _act({"t": "go", "place": "L2", "area": "sala", "seat": 214})
		await _close_panels()
		await _act({"t": "leave"})
		await _wait(0.6)
		if String(shell.world.snap.get("variant", "")).contains("registrada"):
			break
		var c := _clock()
		await _advance_to(int(c.day) + 1, "M")
	var vv := String(shell.world.snap.get("variant", ""))
	_check(vv.contains("registrada"), "M1: variante registrada (%s, día %d)" % [vv, int(_clock().day)])
	await _close_panels()
	await _wait(1.0)
	await _shots("g_" + vv.replace("+", "_"), ["escritorio", "ventana", "puerta", "estante"])
	await _hover_click("ceniza_escritorio", "h_ceniza", "Yo no fumo cigarros.")
	await _hover_click("silla_corrida", "h_silla", "La silla no está donde la dejé.")
	await _hover_click("cajon_entreabierto", "h_cajon", "El cajón está entreabierto.")
	gs().go_frame("puerta")
	await _still()
	await _hover_click("cerradura_rayada", "h_cerradura", "Rayones nuevos")
	gs().go_frame("escritorio")
	await _still()
	# un día después: sólo lo que dure
	var d0 := int(_clock().day)
	_check(await _advance_to(d0 + 1, "M"), "día %d" % (d0 + 1))
	await _shots("i_dia%d" % (d0 + 1), ["escritorio", "puerta"])
	_check(await _advance_to(d0 + 2, "M"), "día %d" % (d0 + 2))
	_check(String(shell.world.snap.get("variant", "")) == "", "dos días después, la pieza como antes (%s)" % shell.world.snap.get("variant", ""))
	await _shots("j_dia%d" % (d0 + 2), ["escritorio"])
	_summary()
