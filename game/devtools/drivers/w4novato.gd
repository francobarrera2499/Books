# devtools/drivers/w4novato.gd — W4 PLAYTEST «jugador novato con el mouse» (sólo diagnóstico; no arregla nada).
# Juega el juego REAL (data/ real, main.tscn, autoload Game) SOLO con eventos reales de mouse/teclado (warp_mouse +
# Input.parse_input_event, utilidades de w3int_flow.gd), como alguien que no leyó el GDD:
#   título -> prólogo explorado a ciegas (pasar las líneas, barrer el escritorio con el mouse buscando qué responde,
#   probar el calendario antes de tiempo, atajos, clic en cada cosa) -> el tutorial siguiendo lo que pide Pell
#   (w3int_flow._prologue) -> días 1–10 deambulando: cada mañana la bandeja (clic en cada papel, recortar el primero),
#   el mapa (M) a un lugar abierto distinto cada franja, clic en los personajes, «Preguntar» el primer tema, salir;
#   noches de informe con el primer papel; la confrontación refutando con lo primero que haya; el informe final; la
#   noche del jueves; el epílogo con «Seguir» y la tijera a ciegas. Cada paso: captura y volcado del texto visible.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4nov res://devtools/drivers/w4novato.gd --mute
# Salida: «NOV …» (OK/FALLA, TEXTO, CARGA ms, ATASCO, RESPALDO) y «NOV RESUMEN». Capturas: .work/shots/w4nov_NN_<paso>.png
extends "res://devtools/drivers/w3int_flow.gd"

const TimeKey = preload("res://core/util/timekey.gd")

var _day_seen := {}
var _visit_seen := {}
var _place_i := 0
var _topic_i := 0
var _report_n := 0
var _stuck := 0
var _last_sig := ""
var _t_dawn := 0
var _api := 0
var _epi_sig := ""
var _epi_same := 0
var _epi_how := ""

var _deadline := 0
var _cont := false

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("NOV sin Shell")
		return
	var budget := 520
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s == "--nov-cont":
			_cont = true
		elif s.begins_with("--nov-budget="):
			budget = s.substr(13).to_int()
	_deadline = Time.get_ticks_msec() + budget * 1000
	g.save_path = "user://saves/w4novato.jsonl"
	if not _cont:
		for suf in ["", ".bak", ".tmp"]:
			var p := ProjectSettings.globalize_path(g.save_path + suf)
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	await _settle_window()
	shell.show_title()
	await tool.frames(30)
	await _snap("titulo")
	_dump("titulo")
	# el novato pasa el mouse por el título antes de decidir
	for b in shell.screen.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			_mm(_c(b))
			await tool.frames(4)
	var t0 := Time.get_ticks_msec()
	if _cont:
		var bc := _button(shell.screen, Widgets.t("shell.title.continuar"))
		_check(bc != null, "título: «Continuar» con partida guardada")
		if bc == null:
			_summary()
			return
		await _click(_c(bc))
		await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 1500)
		await tool.frames(30)
		print("NOV CARGA «Continuar» -> juego ms=%d" % (Time.get_ticks_msec() - t0))
		if g.sim == null:
			_summary()
			return
		await _snap("continuar")
		_dump("continuar")
		var c0: Dictionary = g.sim.q_clock()
		if gs() == null or not gs().tray.visible:
			_day_seen[int(c0.day)] = true
	else:
		await _title()
		print("NOV CARGA título->prólogo jugable ms=%d" % (Time.get_ticks_msec() - t0))
		if g.sim == null:
			_summary()
			return
		await _explore_prologue()
		await _find_frame_with("encargo")
		await _prologue()
		await _snap("tutorial_hecho")
		_dump("tutorial_hecho")
		var ts := Time.get_ticks_msec()
		await _sleep_and_dawn("prologo")
		print("NOV CARGA dormir->bandeja ms=%d" % (Time.get_ticks_msec() - ts))
	await _play_days()
	_summary()
	if g.sim != null:
		g.end_session()
# ================================================================== prólogo a ciegas
func _explore_prologue() -> void:
	await _wait(1.2)
	await _snap("nov_prologo_inicio")
	_dump("prologo_inicio")
	# 1. la tarjeta de lo dicho: clic para seguir mientras haya líneas en cola
	var n := 0
	while gs().speech.visible and n < 24:
		var before := String(gs().speech.text.get_parsed_text())
		await _click(_c(gs().speech))
		await tool.frames(10)
		n += 1
		if n == 1:
			await _snap("nov_prologo_linea2")
		if String(gs().speech.text.get_parsed_text()) == before and gs().speech.visible:
			print("NOV la tarjeta de lo dicho no avanza con el clic (texto igual): ", before.left(80))
			break
	print("NOV clics para pasar las líneas del prólogo: %d (speech visible=%s)" % [n, gs().speech.visible])
	await _snap("nov_prologo_lineas_leidas")
	_dump("tras_lineas")
	# 2. barrido con el mouse: qué responde al pasar (pick y forma del cursor)
	await _sweep("prologo")
	# 3. el calendario antes de terminar lo que piden
	await _click_ctrl(gs().hud.card)
	await tool.frames(16)
	await _snap("nov_calendario_antes")
	_dump("calendario_antes")
	# 4. atajos de teclado que el novato no conoce (los prueba al azar): Tab, L, M, C
	for k in [[KEY_TAB, "tab"], [KEY_L, "l"], [KEY_M, "m"]]:
		await _key(k[0])
		await _wait(0.6)
		await _snap("nov_tecla_" + String(k[1]))
		_dump("tecla_" + String(k[1]))
		await _key(KEY_ESCAPE)
		await _wait(0.4)
		if shell.top() != null:
			await _rclick(Vector2(800, 450))
			await _wait(0.4)
	# 5. clic en cada cosa que respondió al barrido (tarjeta de examen) y en los personajes
	for id in _found.keys():
		var p: Vector2 = _found[id]
		await _click(p)
		await _wait(0.5)
		await _snap("nov_clic_" + String(id))
		_dump("clic_" + String(id))
		if shell.reader_open():
			await _close_reader()
		for _j in 3:
			if not gs().exam.visible and not shell.world.is_examining():
				break
			await _rclick(Vector2(800, 120))
			await _wait(0.6)
		if shell.top() != null:
			await _key(KEY_ESCAPE)
			await _wait(0.3)
		await _clear_top()
	# 6. «recortar» como lo haría alguien sin saber de la tijera: arrastrar sobre el texto de la nota del instructor
	if gs().tutor.visible:
		var r: Rect2 = gs().tutor.text.get_global_rect()
		await _drag(r.position + Vector2(10, 12), r.position + Vector2(r.size.x * 0.7, 12))
		await _wait(0.4)
		await _snap("nov_arrastre_sin_tijera")
		print("NOV arrastrar sobre el texto sin tijera: recortes=%d" % g.sim.q_clips().size())
	# 7. la tecla C (tijera) sobre la lámina y un rectángulo cualquiera
	await _key(KEY_C)
	await _wait(0.4)
	await _snap("nov_tijera_lamina")
	_dump("tijera_lamina")
	var nc: int = g.sim.q_clips().size()
	await _drag(Vector2(700, 470), Vector2(860, 560))
	await _wait(0.6)
	await _snap("nov_tijera_rect")
	_dump("tijera_rect")
	print("NOV rectángulo con la tijera sobre el escritorio: recortes %d -> %d · tutorial paso %d" % [nc, g.sim.q_clips().size(), _tut_index()])
	await _rclick(Vector2(800, 450))
	await _wait(0.4)
	await _clear_top()

# El novato busca el objeto pasando de encuadre con los chevrones (clic real) hasta que el mouse lo «encuentra».
func _find_frame_with(id: String) -> void:
	await _clear_top()
	for i in 4:
		var p := _node_pos(id)
		if p.x >= 0.0 and String(shell.world.pick(p).get("id", "")) == id:
			print("NOV «%s» alcanzable en el encuadre %s tras %d clics de chevrón" % [id, gs().frame, i])
			await _snap("encuadre_con_" + id)
			return
		print("NOV «%s» no se alcanza en el encuadre %s (pick=%s)" % [id, gs().frame, str(shell.world.pick(p)) if p.x >= 0 else "-"])
		await _click(_c(gs()._chev_r))
		await _wait(1.2)
		await _snap("chevron_%d_%s" % [i, gs().frame])

# Prólogo trabado (el aviso no se pudo componer): recorte del borrador del aviso y aviso por la API; si no, dormir.
func _unstick_prologue() -> void:
	await _clear_top()
	var tut: Dictionary = g.sim.q_tutorial()
	print("NOV PRÓLOGO TRABADO tutorial=%s" % str(tut).left(200))
	if not bool(tut.get("complete", false)):
		if String(clips.get("aviso", "")) == "":
			_respaldo_clip("aviso", "D23@L1")
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
		await _idle()
		await tool.frames(20)
	await _sleep_and_dawn("prologo_tarde")

var _found := {}
func _sweep(tag: String) -> void:
	var kinds := {}
	var shapes := {}
	var hits := 0
	for y in range(80, 880, 50):
		for x in range(40, 1580, 50):
			var p := Vector2(x, y)
			_mm(p)
			await tool.frames(1)
			var hov = vp.gui_get_hovered_control()
			if hov != null and hov.mouse_filter == Control.MOUSE_FILTER_STOP:
				continue   # sobre la UI
			var pk: Dictionary = shell.world.pick(p)
			var id := String(pk.get("id", ""))
			var cs := DisplayServer.cursor_get_shape()
			shapes[cs] = int(shapes.get(cs, 0)) + 1
			if id != "":
				hits += 1
				if not _found.has(id):
					_found[id] = p
					kinds[id] = String(pk.get("kind", ""))
	print("NOV BARRIDO %s: %d puntos sobre algo; objetos=%s; formas de cursor vistas=%s" % [tag, hits, str(kinds), str(shapes)])

# ================================================================== días
func _play_days() -> void:
	var guard := 0
	while g.sim != null and guard < 400:
		guard += 1
		var c: Dictionary = g.sim.q_clock()
		var ph := String(c.phase)
		if Time.get_ticks_msec() > _deadline and ((ph == "desk" and _day_seen.has(int(c.day)) and not bool(c.get("outing_done", false))) or (ph == "night" and not bool(g.sim.q_report_status().get("due", false)))):
			await _clear_top()
			print("NOV PAUSA (presupuesto de tiempo) en %s fase=%s; seguir con --nov-cont" % [TimeKey.label(int(c.tk)), ph])
			return
		var sig := "%s|%s|%d" % [ph, str(c.get("tk", "")), g.sim.actions_log().size()]
		if sig == _last_sig:
			_stuck += 1
		else:
			_stuck = 0
		_last_sig = sig
		if _stuck >= 3:
			await _snap("atasco_" + ph)
			_dump("atasco")
			print("NOV ATASCO fase=%s tk=%s pantalla=%s arriba=%s modal=%s" % [ph, str(c.get("tk", "")), shell.screen_id, shell.top_kind(), gs().modal() != null if gs() != null else false])
			await _unstick(ph)
			_stuck = 0
			continue
		match ph:
			"desk":
				await _nov_desk(c)
			"visit":
				await _nov_visit()
			"scene", "parklane":
				await _nov_scene(ph)
			"night":
				await _nov_night()
			"confront":
				await _nov_confront()
			"final_report":
				await _nov_report(true)
			"night_choice":
				await _nov_night_choice()
			"prologue":
				await _unstick_prologue()
			"epilogue":
				await _nov_epilogue()
				return
			"done":
				return
			_:
				print("NOV fase desconocida ", ph)
				await _wait(1.0)

func _unstick(ph: String) -> void:
	await _clear_top()
	var a := {}
	match ph:
		"desk":
			a = {"t": "end_slot"}
		"visit", "scene", "parklane":
			a = {"t": "leave"}
		"night":
			a = {"t": "sleep"} if not bool(g.sim.q_report_status().get("due", false)) else {"t": "report_submit", "mode": "nada", "items": []}
		"final_report":
			a = {"t": "report_submit", "mode": "nada", "items": []}
		"night_choice":
			a = {"t": "night_choice", "where": "baker_street"}
		"confront":
			a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
	if not a.is_empty():
		_api += 1
		_respaldo("atasco " + ph, a)
	await _idle()
	await tool.frames(20)

# ---------------------------------------------------------------- escritorio
func _nov_desk(c: Dictionary) -> void:
	var day := int(c.day)
	await _idle()
	if not _day_seen.has(day):
		_day_seen[day] = true
		await _morning(day)
	c = g.sim.q_clock()
	if String(c.phase) != "desk":
		return
	# un vistazo a los libros algunos días (curiosidad del novato)
	if (day == 2 or day == 6) and String(c.slot) == "M":
		await _peek_books(day)
	if bool(c.get("outing_done", false)):
		await _end_slot_click(c)
		return
	var went := await _go_somewhere(c)
	if not went:
		await _end_slot_click(c)

func _morning(day: int) -> void:
	var items: Array = g.sim.q_tray(day)
	print("NOV MAÑANA día %d (%s): %d papeles: %s" % [day, String(g.sim.q_clock().get("date_label", "")), items.size(), str(items.map(func(it): return "%s<%s>" % [String(it.get("view", it.get("id", ""))), String(it.get("how", it.get("kind", "")))]))])
	if not gs().tray.visible:
		if not items.is_empty():
			print("NOV FALLA día %d: la bandeja no se abrió sola con %d papeles" % [day, items.size()])
		return
	await _snap("d%02d_bandeja" % day)
	_dump("bandeja_d%d" % day)
	var rows: Array = gs().tray.list.get_children().filter(func(r): return r is Control and (r as Control).is_visible_in_tree())
	var k := 0
	for row in rows:
		if k >= 7:
			break
		if not is_instance_valid(row) or not gs().tray.visible:
			break
		await _scroll_into_view(row)
		await _click(_c(row))
		await _wait(0.5)
		if not shell.reader_open():
			print("NOV día %d: clic en el papel %d no abrió el lector" % [day, k])
			k += 1
			continue
		var v: Dictionary = shell.reader.view
		var title := String(v.get("title", v.get("view", "")))
		var words := 0
		for pg in v.get("pages", []):
			for blk in pg:
				words += String(blk.get("parsed", {}).get("plain", "")).split(" ", false).size()
		print("NOV lee día %d #%d: %s · %s · %d palabras · %d hojas" % [day, k, String(v.get("view", "")), title, words, (v.get("pages", []) as Array).size()])
		await _snap("d%02d_lee_%d" % [day, k])
		if k == 0:
			var tid := _first_tramo(v)
			if tid != "":
				var cid := await _clip_tramo(tid, "")
				print("NOV recorte del día %d: %s" % [day, cid])
		await _close_reader()
		await _wait(0.2)
		k += 1
	if gs().tray.visible:
		await _close_tray()

func _peek_books(day: int) -> void:
	await _key(KEY_TAB)
	await _wait(0.6)
	await _snap("d%02d_cuaderno" % day)
	_dump("cuaderno_d%d" % day)
	var nb = shell.panel("notebook")
	if nb != null:
		for t in ["Tab_indice", "Tab_cotejos", "Tab_diario", "Tab_marginalia"]:
			var tb = _find(nb, t)
			if tb != null and (tb as Control).is_visible_in_tree():
				await _click_ctrl(tb)
				await _wait(0.4)
				await _snap("d%02d_cuaderno_%s" % [day, t.to_lower()])
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	await _clear_top()
	await _key(KEY_L)
	await _wait(0.6)
	await _snap("d%02d_libro_mayor" % day)
	_dump("libro_d%d" % day)
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	await _clear_top()

func _end_slot_click(c: Dictionary) -> void:
	await _clear_top()
	await _click_ctrl(gs().hud.card)
	await tool.frames(14)
	var m = gs().modal()
	if m == null:
		print("NOV FALLA el calendario no pidió confirmación en %s" % TimeKey.label(int(c.tk)))
		return
	if not _day_seen.has("cal_" + str(c.day)):
		_day_seen["cal_" + str(c.day)] = true
		await _snap("d%02d_calendario_%s" % [int(c.day), String(c.slot)])
		_dump("calendario")
	var b := _first_enabled_button(m, true)
	await _click(_c(b))
	await _until(func(): return g.sim == null or g.sim.q_clock() != c, 400)
	await _idle()
	await tool.frames(20)

# El mapa con la tecla M; un lugar abierto distinto cada vez; la primera área que se pueda; «Ir».
func _go_somewhere(c: Dictionary) -> bool:
	await _clear_top()
	await _key(KEY_M)
	await _wait(0.7)
	var ms = shell.panel("map")
	if ms == null or not shell.is_open("map"):
		print("NOV FALLA la tecla M no abrió el mapa (%s)" % TimeKey.label(int(c.tk)))
		return false
	if not _day_seen.has("map_" + str(c.day)):
		_day_seen["map_" + str(c.day)] = true
		await _snap("d%02d_mapa_%s" % [int(c.day), String(c.slot)])
		_dump("mapa")
	var ids: Array = []
	for m in ms.markers.get_children():
		if "place_id" in m and not bool(m.home) and bool(m.state.get("open", false)):
			ids.append(String(m.place_id))
	ids.sort()
	if ids.is_empty():
		print("NOV mapa sin lugares abiertos en %s" % TimeKey.label(int(c.tk)))
		await _click_ctrl(ms.close_btn)
		await _wait(0.3)
		return false
	var pid: String = ids[_place_i % ids.size()]
	_place_i += 1
	var mk = ms.marker(pid)
	await _click(mk.get_global_rect().position + mk.get_meta("origin", Vector2(12, 12)))
	await _wait(0.4)
	if ms._popup != null and is_instance_valid(ms._popup) and _button(ms._popup, Widgets.t("shell.map.ir"), true) == null:
		var b := _first_enabled_button(ms._popup)
		if b != null:
			await _click(_c(b))
			await _wait(0.4)
	var ir := _button(ms._popup, Widgets.t("shell.map.ir"), true) if ms._popup != null and is_instance_valid(ms._popup) else null
	if ir == null:
		print("NOV FALLA %s: sin «Ir» tras el marcador %s" % [TimeKey.label(int(c.tk)), pid])
		await _snap("sin_ir_" + pid)
		await _rclick(Vector2(800, 450))
		await _clear_top()
		return false
	var t0 := Time.get_ticks_msec()
	await _click(_c(ir))
	await _until(func(): return g.sim != null and String(g.sim.q_clock().phase) != "desk", 900)
	await _idle()
	print("NOV CARGA «Ir» %s -> visita jugable ms=%d" % [pid, Time.get_ticks_msec() - t0])
	return String(g.sim.q_clock().phase) != "desk"

# ---------------------------------------------------------------- visita
func _nov_visit() -> void:
	await _idle()
	await tool.frames(20)
	var sc: Dictionary = g.sim.q_scene()
	var c: Dictionary = g.sim.q_clock()
	var vid := "%s_%s" % [String(sc.get("id", "")), str(c.tk)]
	if not _visit_seen.has(vid):
		_visit_seen[vid] = true
		await _wait(0.6)
		await _snap("d%02d_%s_%s_%s" % [int(c.day), String(c.slot), String(sc.get("place", "")), String(sc.get("area", ""))])
		_dump("visita")
		print("NOV VISITA %s %s.%s chars=%s líneas=%d" % [TimeKey.label(int(c.tk)), String(sc.get("place", "")), String(sc.get("area", "")), str((sc.get("chars", []) as Array).map(func(ch): return String(ch.get("id", "")))), (sc.get("lines", []) as Array).size()])
	# líneas automáticas en la tarjeta de lo dicho: clic para seguir
	var n := 0
	while gs().speech.visible and n < 12:
		await _click(_c(gs().speech))
		await tool.frames(8)
		n += 1
	# hablar con los presentes
	var talked := 0
	for ch in sc.get("chars", []):
		if talked >= 2 or g.sim == null or String(g.sim.q_clock().phase) != "visit":
			break
		var cid := String(ch.get("id", ""))
		var wp: Vector2 = gs().char_screen_pos(cid)
		if wp.x < 0.0:
			print("NOV %s no está a la vista" % cid)
			continue
		await _click(wp)
		await _wait(0.5)
		var sp = shell.panel("scene")
		if sp == null or not shell.is_open("scene"):
			print("NOV clic en %s no abrió el panel de escena" % cid)
			continue
		talked += 1
		await _talk(sp, cid)
	await _leave_visit()

func _talk(sp, cid: String) -> void:
	var verb = _find(sp, "Personaje_" + cid)
	var ask = _find(verb if verb != null else sp, "Verbo_ask")
	if ask == null or not (ask as Control).is_visible_in_tree():
		print("NOV %s: sin «Preguntar» a la vista" % cid)
		await _snap("sin_preguntar_" + cid)
		return
	await _click_ctrl(ask)
	await _wait(0.4)
	var ap = sp.ask_panel
	if not ap.visible or ap._list.item_count == 0:
		print("NOV %s: «Preguntar» sin temas" % cid)
		await _snap("preguntar_vacio_" + cid)
		if ap.visible:
			await _click(_c(_button(ap, Widgets.t("sceneui.back"))))
		return
	var idx: int = _topic_i % ap._list.item_count
	_topic_i += 1
	var r: Rect2 = ap._list.get_item_rect(idx)
	var p: Vector2 = ap._list.get_global_transform_with_canvas() * r.get_center()
	if p.y > ap._list.get_global_rect().end.y - 4.0:
		idx = 0
		r = ap._list.get_item_rect(0)
		p = ap._list.get_global_transform_with_canvas() * r.get_center()
	await _click(p)
	await _wait(0.3)
	if not _visit_seen.has("ask_snap_" + cid):
		_visit_seen["ask_snap_" + cid] = true
		await _snap("preguntar_" + cid)
		_dump("preguntar_" + cid)
	var n0: int = (g.sim.q_scene().get("lines", []) as Array).size()
	await _click(_c(ap._ok))
	await _wait(1.4)
	var lines: Array = g.sim.q_scene().get("lines", [])
	print("NOV pregunta a %s (%s): %d líneas nuevas; última: %s" % [cid, String(ap._list.get_item_text(idx)), lines.size() - n0, String(lines[-1].get("parsed", {}).get("plain", lines[-1].get("text", ""))).left(160) if not lines.is_empty() else "-"])
	await _snap("respuesta_" + cid)

func _leave_visit() -> void:
	if g.sim == null or String(g.sim.q_clock().phase) != "visit":
		return
	var sp = shell.panel("scene")
	var c: Dictionary = g.sim.q_clock()
	if sp != null and shell.is_open("scene"):
		if sp.sub_open() != "":
			sp.close_sub()
		var sal := _button(sp, Widgets.t("sceneui.leave"), true)
		if sal == null:
			sal = _button(sp, Widgets.t("sceneui.leave.free"), true)
		if sal != null:
			await _click(_c(sal))
			await _wait(0.4)
			var ok := _button(tool.root, Widgets.t("sceneui.leave.ok"), true)
			if ok != null and ok != sal:
				await _click(_c(ok))
	else:
		var lb = gs()._leave_btn
		if lb != null and lb.is_visible_in_tree():
			await _click(_c(lb))
			await _wait(0.4)
			if gs().modal() != null:
				await _click(_c(_button(gs().modal(), Widgets.t("shell.leave.ok"), true)))
		else:
			await _click_ctrl(gs().hud.card)
			await _wait(0.4)
			if gs().modal() != null:
				await _click(_c(_first_enabled_button(gs().modal(), true)))
	var t0 := Time.get_ticks_msec()
	await _until(func(): return g.sim == null or g.sim.q_clock() != c, 600)
	await _idle()
	await tool.frames(10)
	print("NOV CARGA salir -> escritorio ms=%d" % (Time.get_ticks_msec() - t0))

# ---------------------------------------------------------------- escenas fijas (M6, M7, HC06, Park Lane…)
func _nov_scene(ph: String) -> void:
	await _idle()
	await tool.frames(20)
	var sc: Dictionary = g.sim.q_scene()
	var c: Dictionary = g.sim.q_clock()
	var key := "esc_%s_%s" % [String(sc.get("id", "")), str(c.tk)]
	if not _visit_seen.has(key):
		_visit_seen[key] = true
		await _wait(0.8)
		await _snap("d%02d_escena_%s" % [int(c.day), String(sc.get("id", ph))])
		_dump("escena")
		print("NOV ESCENA %s %s chars=%s" % [TimeKey.label(int(c.tk)), String(sc.get("id", "")), str((sc.get("chars", []) as Array).map(func(ch): return String(ch.get("id", ""))))])
	var n := 0
	while gs().speech.visible and n < 16:
		await _click(_c(gs().speech))
		await tool.frames(8)
		n += 1
	var sp = shell.panel("scene")
	if sp != null and shell.is_open("scene"):
		# preguntar a quien haya (una vez por escena)
		for ch in sc.get("chars", []):
			var cid := String(ch.get("id", ""))
			if not _visit_seen.has(key + cid):
				_visit_seen[key + cid] = true
				var verb = _find(sp, "Personaje_" + cid)
				if verb != null and _find(verb, "Verbo_ask") != null:
					await _talk(sp, cid)
		await _wait(0.6)
		await _snap("d%02d_escena_%s_fin" % [int(c.day), String(sc.get("id", ph))])
		var cont := _button(sp, Widgets.t("sceneui.continue"), true)
		if cont == null:
			cont = _button(sp, Widgets.t("sceneui.leave"), true)
		if cont != null:
			await _click(_c(cont))
			await _wait(0.4)
			var ok := _button(tool.root, Widgets.t("sceneui.leave.ok"), true)
			if ok != null and ok != cont:
				await _click(_c(ok))
	else:
		var lb = gs()._leave_btn
		if lb != null and lb.is_visible_in_tree():
			await _click(_c(lb))
		else:
			await _click_ctrl(gs().hud.card)
	await _until(func(): return g.sim == null or g.sim.q_clock() != c, 600)
	await _idle()
	await tool.frames(10)

# ---------------------------------------------------------------- noche
func _nov_night() -> void:
	await _idle()
	var c: Dictionary = g.sim.q_clock()
	if bool(g.sim.q_report_status().get("due", false)):
		_report_n += 1
		await _snap("d%02d_noche_informe" % int(c.day))
		_dump("noche_informe")
		await _nov_report(false)
		return
	var day0 := int(c.day)
	var t0 := Time.get_ticks_msec()
	await _sleep_and_dawn("noche_d%d" % day0)
	print("NOV CARGA dormir día %d -> bandeja ms=%d" % [day0, Time.get_ticks_msec() - t0])

# Informe: calendario (noche) o ya abierto (final); «Elegir…» -> primera tarjeta; Entregar; confirmar.
func _nov_report(final: bool) -> void:
	await _idle()
	if shell.top_kind() != "report":
		await _clear_top()
		await _click_ctrl(gs().hud.card)
		await _wait(0.6)
	var rc = shell.top()
	if rc == null or shell.top_kind() != "report":
		print("NOV FALLA informe: el calendario no abrió el sobre (arriba=%s)" % shell.top_kind())
		await _snap("informe_no_abre")
		return
	var tag := "informe_final" if final else "informe_%d" % _report_n
	await _snap(tag)
	_dump(tag)
	var ch := _button(rc, Widgets.t("sceneui.rep.choose"))
	if ch != null:
		await _click(_c(ch))
		await _wait(0.5)
		await _snap(tag + "_elegir")
		var pk = rc.picker
		var cards: Array = pk.cards() if pk != null and pk.visible else []
		if not cards.is_empty():
			var pick_i := 0 if _report_n != 2 else mini(1, cards.size() - 1)
			await _click(_c(cards[pick_i].node))
			await _wait(0.4)
	await _snap(tag + "_lleno")
	_dump(tag + "_lleno")
	var send := _button(rc, Widgets.t("sceneui.rep.send"), true)
	if send == null or send.disabled:
		print("NOV FALLA %s: «Entregar» no disponible" % tag)
		return
	await _click(_c(send))
	await _wait(0.5)
	await _snap(tag + "_confirma")
	_dump(tag + "_confirma")
	var cf = _find(rc, "Confirmacion")
	if cf != null and "ok_button" in cf:
		await _click(_c(cf.ok_button))
		await _wait(1.4)
	await _idle()
	print("NOV %s entregado: %s" % [tag, str(not bool(g.sim.q_report_status().get("due", false))) if g.sim != null else "?"])

# ---------------------------------------------------------------- confrontación
func _nov_confront() -> void:
	await _idle()
	await _wait(0.8)
	var cv = shell.panel("confront")
	if cv == null or not shell.is_open("confront"):
		print("NOV FALLA confrontación sin su vista")
		await _snap("confront_sin_vista")
		_stuck = 3
		return
	for k in 8:
		if g.sim == null or String(g.sim.q_clock().phase) != "confront":
			break
		if not is_instance_valid(cv):
			break
		var st: Dictionary = cv.debug_state()
		if bool(st.get("done", false)):
			break
		await _wait(0.6)
		await _snap("confront_%d" % int(st.get("step", 0)))
		_dump("confront_%d" % int(st.get("step", 0)))
		var step0 := int(st.get("step", 0))
		if k % 2 == 1:
			# callar (dos pasos)
			await _click(_c(cv._b_silence))
			await _wait(0.4)
			await _snap("confront_%d_callar" % step0)
			var cb := _button(cv.root if "root" in cv else null, Widgets.t("sceneui.conf.callar"), true)
			if cb != null:
				await _click(_c(cb))
		else:
			await _click(_c(cv._b_refute))
			await _wait(0.5)
			var cards: Array = cv.picker.cards() if cv.picker.visible else []
			await _snap("confront_%d_elegir" % step0)
			if cards.is_empty():
				print("NOV confrontación: el selector no tiene nada")
				await _rclick(Vector2(800, 450))
				continue
			await _click(_c(cards[mini(k, cards.size() - 1)].node))
			await _wait(0.5)
			await _snap("confront_%d_frase" % step0)
			var ok := _button(cv.confirm_bar, Widgets.t("sceneui.present.ok"))
			if ok != null:
				await _click(_c(ok))
		await _wait(2.0)
		await _snap("confront_%d_respuesta" % step0)
		_dump("confront_%d_respuesta" % step0)
	await _wait(0.6)
	if not is_instance_valid(cv):
		await _idle()
		return
	var seg := _button(cv.root, Widgets.t("sceneui.conf.seguir"), true)
	await _snap("confront_fin")
	if seg != null:
		await _click(_c(seg))
	await _idle()
	await tool.frames(20)

# ---------------------------------------------------------------- noche del jueves
func _nov_night_choice() -> void:
	await _idle()
	await _wait(0.6)
	var m = gs().modal()
	if m == null:
		await _click_ctrl(gs().hud.card)
		await _wait(0.5)
		m = gs().modal()
	await _snap("noche_jueves")
	_dump("noche_jueves")
	if m == null:
		_stuck = 3
		return
	var b := _button(m, Widgets.t("shell.noche.baker"))
	await _click(_c(b))
	await _wait(0.5)
	await _snap("noche_jueves_confirma")
	var m2 = gs().modal()
	if m2 != null:
		await _click(_c(_button(m2, Widgets.t("shell.noche.ir"), true)))
	await _idle()
	await tool.frames(30)

# ---------------------------------------------------------------- epílogo
func _nov_epilogue() -> void:
	await _until(func(): return String(shell.screen_id) == "epilogue", 600)
	await _wait(1.0)
	var epi = shell.screen
	if epi == null or not epi.has_method("state"):
		print("NOV FALLA sin pantalla de epílogo")
		return
	var seen := {}
	var tries_cut := 0
	for k in 260:
		if not is_instance_valid(epi) or String(shell.screen_id) != "epilogue":
			break
		var st: Dictionary = epi.state()
		var stg := String(st.get("stage", ""))
		if not seen.has(stg):
			seen[stg] = true
			await _wait(0.5)
			await _snap("epilogo_" + stg)
			_dump("epilogo_" + stg)
			print("NOV EPÍLOGO estadio %s · diario=%s" % [stg, str(st.get("diary", [])).left(300)])
		if bool(st.get("modal", false)):
			var cfs := _confirms(epi)
			if not cfs.is_empty():
				await _snap("epilogo_modal")
				await _click(_c(cfs[-1].ok_button))
				await _wait(0.6)
				continue
		if bool(st.get("offer", false)):
			await _snap("epilogo_oferta")
			_dump("epilogo_oferta")
			var ob := _first_enabled_button(epi._offer)
			await _click(_c(ob))
			await _wait(0.6)
			continue
		if stg == "tijera":
			tries_cut += 1
			if tries_cut > 6:
				print("NOV FALLA el novato no logra el corte del epílogo; respaldo con do_cut")
				var ct: Dictionary = epi.cut
				epi.do_cut(int(ct.get("page", 0)), int(ct.get("from", 0)), int(ct.get("to", 0)) - int(ct.get("from", 0)))
				_api += 1
				await _wait(1.0)
				continue
			if not bool(st.get("scissors", false)):
				await _click(_c(epi._b_tijera))
				await _wait(0.4)
				await _snap("epilogo_tijera_on")
			var sv = epi._strand
			var pr: Rect2 = sv.page_rect()
			var p := pr.get_center()
			if tries_cut >= 2:
				var ct2: Dictionary = epi.cut
				if int(sv.page_idx) != int(ct2.get("page", 0)):
					var nav_b := _button(sv, "›")
					if nav_b != null:
						await _click(_c(nav_b))
						await _wait(0.5)
					continue
				var tr: Rect2 = sv.tramo_rect(int(ct2.get("from", 0)), int(ct2.get("to", 0)))
				p = tr.get_center()
			await _click(p)
			await _wait(0.8)
			await _snap("epilogo_corte_%d" % tries_cut)
			_dump("epilogo_corte_%d" % tries_cut)
			continue
		if stg == "lapiz":
			var close_b: Button = null
			for b in epi.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and String((b as Button).text).to_lower().contains("cerrar"):
					close_b = b
			if close_b != null:
				await _wait(1.0)
				await _snap("epilogo_lapiz_cerrar")
				await _click(_c(close_b))
				await _wait(1.0)
				continue
		var sig2 := "%s|%d|%s" % [stg, int(st.get("beat", -1)), str(st.get("diary", [])).length()]
		if sig2 == _epi_sig:
			_epi_same += 1
		else:
			if _epi_same > 0:
				print("NOV EPÍLOGO avanzó tras %d intentos (último: %s)" % [_epi_same + 1, _epi_how])
			_epi_same = 0
		_epi_sig = sig2
		if _epi_same >= 2 and _epi_same < 4:
			_epi_how = "clic en el fondo"
			await _click(Vector2(120, 820))
			await _wait(0.5)
			continue
		if _epi_same >= 4:
			_epi_how = "Espacio"
			if _epi_same == 4:
				await _snap("epilogo_trabado_" + stg)
			await _key(KEY_SPACE)
			await _wait(0.5)
			continue
		_epi_how = "Seguir" if (epi._b_next != null and epi._b_next.is_visible_in_tree()) else "clic en el centro"
		var nb: Button = epi._b_next
		if nb != null and is_instance_valid(nb) and nb.is_visible_in_tree():
			await _click(_c(nb))
		else:
			await _click(Vector2(800, 450))
		await _wait(0.5)
	await _wait(1.5)
	await _snap("fin_" + String(shell.screen_id))
	_dump("fin")
	print("NOV EPÍLOGO terminado: pantalla=%s estadios=%s" % [shell.screen_id, str(seen.keys())])

# Confirmaciones (Widgets.confirm) visibles bajo root.
func _confirms(root) -> Array:
	var out: Array = []
	if root == null or not is_instance_valid(root):
		return out
	for c in root.find_children("*", "", true, false):
		if c.get("ok_button") is Button and (c as CanvasItem).is_visible_in_tree():
			out.append(c)
	return out

# ================================================================== registro
func _texts(n, maxlen := 700) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var parts: Array = []
	var all: Array = [n]
	all.append_array(n.find_children("*", "", true, false))
	for c in all:
		if not (c is CanvasItem) or not (c as CanvasItem).is_visible_in_tree():
			continue
		var s := ""
		if c is RichTextLabel:
			s = (c as RichTextLabel).get_parsed_text()
		elif c is Label:
			s = (c as Label).text
		elif c is Button:
			s = "[" + (c as Button).text + "]"
		elif c is LineEdit:
			s = "{" + (c as LineEdit).text + "}"
		s = s.strip_edges().replace("\n", " / ")
		if s != "" and s != "[]":
			parts.append(s)
	return " · ".join(parts).left(maxlen)

func _dump(tag: String) -> void:
	var out: Array = []
	if g.sim != null:
		var c: Dictionary = g.sim.q_clock()
		out.append("%s fase=%s" % [TimeKey.label(int(c.get("tk", 0))) if c.has("tk") else "?", String(c.get("phase", ""))])
	out.append("pantalla=%s arriba=%s" % [shell.screen_id, shell.top_kind()])
	var gsc = gs()
	if gsc != null and is_instance_valid(gsc) and String(shell.screen_id) == "game":
		if gsc.tutor.visible:
			out.append("TUTOR: " + String(gsc.tutor.text.get_parsed_text()))
		if gsc.speech.visible:
			out.append("DICHO: " + _texts(gsc.speech, 300))
		if gsc.exam.visible:
			out.append("EXAMEN: " + _texts(gsc.exam, 500))
		if gsc.modal() != null:
			out.append("MODAL: " + _texts(gsc.modal(), 500))
		if gsc.caption.modulate.a > 0.05:
			out.append("EPÍGRAFE: " + _texts(gsc.caption, 200))
	for nt in shell.notes():
		out.append("NOTA: " + str(nt))
	var top = shell.top()
	if top != null and is_instance_valid(top) and not ["tray"].has(shell.top_kind()):
		out.append("PANEL: " + _texts(top, 600))
	if shell.reader_open():
		out.append("LECTOR: " + String(shell.reader.view.get("title", "")))
	print("NOV TEXTO [%s] %s" % [tag, " | ".join(out)])

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("NOV %s %s" % ["OK" if c else "FALLA", what])

func _respaldo(what: String, a: Dictionary) -> Dictionary:
	fallbacks += 1
	var r: Dictionary = g.act(a)
	print("NOV RESPALDO %s -> %s" % [what, "ok" if bool(r.get("ok", false)) else str(r.get("err", ""))])
	return r

func _summary() -> void:
	var fin := ""
	if g.sim != null:
		fin = str(g.sim.q_ending())
	print("NOV RESUMEN %d fallas, %d respaldos, %d capturas, final=%s" % [fails, fallbacks, _shot, fin])
