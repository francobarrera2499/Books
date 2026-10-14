# devtools/drivers/v3integ_partida.gd — INTEGRACIÓN v3 (GDD_v3 §7.3): una partida REAL, SIN --fast, con data/ real y el
# mouse y el teclado reales (warp_mouse + Input.parse_input_event; helpers de w3int_flow), desde el título hasta el día 2.
#   título «Partida nueva» -> prólogo: lo dicho (clics) -> la nota de Pell: el expediente -> «El encargo» -> lector ->
#   tijera sobre el aviso -> Harris: el tintero -> aviso «testigo» -> calendario: dormir -> amanecer del día 1: bandeja ->
#   Pendientes y notas de Lisle -> estante: «El problema final» (ficha, marquitas, nota al margen, tarjeta del cliente) ->
#   recortes (FINA #sheer, la prueba de imprenta #clausula) -> la carpeta del escritorio: Q1, respuesta con el selector,
#   dos pruebas arrastradas del cuaderno, «Pasar en limpio» -> la puerta: Crane se presenta, «¿Dónde consigo…?» ->
#   «Subir» -> el plano de la pared -> cerrar franjas -> noche -> dormir -> amanecer del día 2: bandeja -> el plano: el
#   Museo Británico -> la Sala de Lectura -> volver a la pieza.
#   Corrector final (playtest v3): + la carpeta de cerca en el prólogo, la nota al margen de FINA recortada (tarjeta en
#   grafito), Q2 con sus rótulos de prueba, clic derecho sobre un recorte («Tirar este recorte»), el plano con la tarjeta
#   de áreas de Kensington, el tintero de noche (las dos líneas), el informe de la noche 2 con la prueba de imprenta (un
#   original: M1), el día 3 (bandeja, Kensington, vuelta a la pieza registrada por los de Moran, la ceniza: nace Q8).
#   V3I_HASTA=prologo | dia2 corta antes.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3i res://devtools/drivers/v3integ_partida.gd --mute
# La cámara se gira con set_frame (lo mismo que llegar girando con el borde; T32 y v3mundo_general prueban el giro real).
# Salida: «W3INT OK|FALLA|RESPALDO …» (respaldo = el clic no alcanzó y se siguió por Game.act: cuenta como falla de UI) y
# «W3INT RESUMEN n fallas, m respaldos, k capturas». Capturas: .work/shots/v3i_NN_<paso>.png. Guardado aparte:
# user://saves/v3integ.jsonl (nunca .work/jugador/).
extends "res://devtools/drivers/w3int_flow.gd"

const Walk = preload("res://tests/fixtures/w3shell/walk.gd")

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(1500.0).timeout.connect(func():
		print("W3INT VIGIA: se corta a los 1500 s")
		tool.quit(2))
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("W3INT sin Shell")
		return
	g.save_path = "user://saves/v3integ.jsonl"
	# V3I_DESDE=dia2: segunda sesión de la MISMA partida («Continuar» desde el título, como el jugador; la corrida entera
	# no entra en los 10 min de una llamada): noche 2 -> informe -> día 3
	var desde := OS.get_environment("V3I_DESDE")
	if desde == "":
		for suf in ["", ".bak", ".tmp", ".fin"]:
			var p := ProjectSettings.globalize_path(g.save_path + suf)
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	await _settle_window()
	shell.show_title()
	await tool.frames(30)
	if desde == "dia2":
		await _title_continue()
		if g.sim == null:
			_summary()
			return
		_restore_clips()
		await _seguir_dia2()
		_dump_state("fin")
		_summary()
		g.end_session()
		return
	await _title()
	if g.sim == null:
		_summary()
		return
	await _prologo()
	if OS.get_environment("V3I_HASTA") == "prologo":
		_summary()
		g.end_session()
		return
	await _sleep_and_dawn("prologo")
	await _dia1()
	await _close_slots_until_night()
	await _tintero_noche("noche1")
	await _sleep_and_dawn("noche1")
	await _dia2()
	if OS.get_environment("V3I_HASTA") != "dia2":
		await _seguir_dia2()
	_dump_state("fin")
	_summary()
	g.end_session()

# ================================================================== prólogo
func _prologo() -> void:
	await _wait(1.0)
	await _snap("prologo")
	await _speech_through("prologo")
	await _wait(0.5)
	_tutor("lectura")
	await _wait(1.6)   # la cámara se desliza a la carpeta (playtest v3: «Holmes» en la tapa)
	print("W3INT encuadre del primer paso: %s" % String(gs().frame))
	_check(String(gs().frame) == "expediente", "prólogo: el primer paso encuadra la carpeta de cerca")
	await _snap("prologo_nota_pell")
	# «abra el expediente y lea el encargo»: la carpeta (si es un objeto de la lámina) o las hojas del encargo
	var read_ok := false
	if await _click_3d("expediente"):
		await _wait(0.8)
		print("W3INT tras clic en la carpeta: arriba=%s dossier=%s tarjeta=%s fase=%s" % [shell.top_kind(), shell.is_open("dossier"), gs().exam.visible, String(g.sim.q_clock().phase)])
		await _snap("prologo_tras_clic_carpeta")
		if shell.is_open("dossier"):
			await _snap("prologo_expediente")
			var ex = shell.panel("dossier")
			var r: Rect2 = ex.rect_of("encargo")
			_check(r.size.x > 0.0, "«El encargo» en la carpeta")
			if r.size.x > 0.0:
				await _click(r.get_center())
				await _wait(1.0)
				read_ok = shell.reader_open()
	else:
		print("W3INT la carpeta no es un objeto de la lámina del prólogo: se prueba con las hojas del encargo")
		await _read_from_node("encargo", "")
		read_ok = shell.reader_open()
	_check(read_ok, "prólogo: el encargo se abre en el lector")
	if not read_ok:
		_respaldo("read", {"t": "read", "view": "D23@L1", "part": 0})
	else:
		await _read_all_pages("encargo")
		clips["aviso"] = await _clip_window("aviso", "prologo_tijera_aviso")
	await _wait(0.6)
	await _snap("prologo_tras_recorte")
	await _close_reader()
	await _clear_top()
	if clips.get("aviso", "") == "":
		_respaldo_clip("aviso", "D23@L1")
	await _speech_through("harris")
	_tutor("aviso")
	await _ad_tintero()
	await _speech_through("despedida")
	_tutor("dormir")
	await _snap("prologo_antes_de_dormir")

func _ad_tintero() -> void:
	var ok := await _click_3d("tintero")
	await tool.frames(20)
	if ok and shell.top_kind() != "ad" and gs().exam.visible:
		var link := _link_button(gs().exam, Widgets.t("shell.compose.ad"))
		if link != null:
			await _click(_c(link))
			await tool.frames(20)
	var ac = shell.top()
	var is_ad: bool = ac != null and shell.top_kind() == "ad"
	_check(is_ad, "tintero -> compositor de avisos")
	if not is_ad:
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
		return
	await _snap("prologo_aviso")
	if String(ac.form_id) != "testigo" and ac._form_btns.has("testigo"):
		await _click(_c(ac._form_btns["testigo"]))
		await tool.frames(8)
	for slot in ac._blanks.keys():
		var bl = ac._blanks[slot]
		if String(bl.value) != "":
			continue
		await _choose_popup(bl, "suceso_reichenbach" if String(slot) == "suceso" else "")
	await tool.frames(8)
	await _snap("prologo_aviso_lleno")
	var send := _button(ac, Widgets.t("sceneui.ad.send"))
	_check(send != null and not send.disabled, "«Enviar» habilitado")
	if send != null:
		await _click(_c(send))
		await tool.frames(12)
		var cf = _find(ac, "Confirmacion")
		if cf != null and "ok_button" in cf:
			await _snap("prologo_aviso_confirma")
			await _click(_c(cf.ok_button))
			await _wait(1.4)
	var sent := (g.sim.actions_log() as Array).any(func(a): return String(a.get("t", "")) == "compose_ad")
	_check(sent, "aviso enviado con el mouse")
	if not sent:
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	await _clear_top()

# ================================================================== día 1
func _dia1() -> void:
	_check(shell.is_open("tray") or gs().tray.visible, "día 1: la bandeja abierta al amanecer")
	print("W3INT bandeja 1: ", g.sim.q_tray(1).map(func(it): return String(it.view)))
	await _close_tray()
	await _wait(0.6)
	_tutor("dia1")
	_guide("dia1")
	await _snap("dia1_escritorio")
	_dossier_dump("dia1_inicio")
	# «El problema final» desde el estante
	shell.world.set_frame("estante")
	await _wait(1.6)
	await _snap("dia1_estante")
	await _read_from_node("estante", "problema final")
	var fina_ok: bool = shell.reader_open() and String(shell.reader.view.get("view", "")).begins_with("D03")
	_check(fina_ok, "estante -> «El problema final» en el lector")
	if not fina_ok:
		await _close_reader()
		_respaldo("read FINA", {"t": "read", "view": "D03@tomo", "part": 0})
	else:
		await _read_all_pages("fina")
		clips["sheer"] = await _clip_window("sheer", "dia1_tijera_sheer")
		# la nota a lápiz al margen (D01N#fina_fo): otro papel, su tarjeta en grafito y con su crónica (playtest v3)
		clips["fina_fo"] = await _clip_window("fina_fo", "dia1_tijera_nota_margen")
		if String(clips.get("fina_fo", "")) != "":
			var cm: Dictionary = g.sim.q_clip(String(clips.fina_fo))
			print("W3INT nota al margen: «%s» · %s · %s" % [String(cm.get("text", "")), String(cm.get("src_line", "")), String(cm.get("chron_date", ""))])
			_check(String(cm.get("src_line", "")).begins_with("Nota a lápiz al margen"), "la nota al margen dice que es una nota a lápiz")
		await _close_reader()
	if clips.get("sheer", "") == "":
		_respaldo_window("sheer", "D03@tomo")
	_dossier_dump("tras_fina")
	_check(_open_ids().has("Q2"), "Q2 nace al leer «El problema final»")
	# la prueba de imprenta (D02), del mismo estante
	await _clear_top()
	await _read_from_shelf("prueba de imprenta")
	var d02_ok: bool = shell.reader_open() and String(shell.reader.view.get("view", "")).begins_with("D02")
	_check(d02_ok, "estante -> la prueba de imprenta en el lector")
	if d02_ok:
		await _snap("dia1_d02")
		clips["clausula"] = await _clip_window("clausula", "dia1_tijera_clausula")
	await _close_reader()
	if clips.get("clausula", "") == "":
		_respaldo_window("clausula", "D02@L1")
	await _clear_top()
	_tutor("tras_recortes")
	# la carpeta del escritorio
	shell.world.set_frame("escritorio")
	await _wait(1.6)
	await _answer_q1()
	await _clear_top()
	# la tienda de Crane
	await _crane()
	# el plano de la pared
	await _plano("dia1")
	await _clear_top()

func _answer_q1() -> void:
	var ok := await _click_3d("expediente")
	await _wait(1.0)
	_check(ok and shell.is_open("dossier"), "clic en la carpeta del escritorio -> el expediente")
	if not shell.is_open("dossier"):
		_respaldo_q1()
		return
	var ex = shell.panel("dossier")
	var nb = shell.panel("notebook") if shell.is_open("notebook") else null
	await _snap("dia1_expediente")
	var rr: Rect2 = ex.row_rect("Q1")
	if rr.size.x > 0.0:
		await _click(rr.get_center())
		await _wait(0.5)
	await _snap("dia1_hoja_q1")
	# respuesta: el selector, el buscador y el renglón
	await _click(ex.rect_of("respuesta").get_center())
	await _wait(0.6)
	var pk = ex.picker()
	_check(pk != null, "«Respuesta» abre el selector")
	if pk != null:
		await _snap("dia1_selector")
		if pk.filter != null:
			await _type("rasp")
			await _wait(0.4)
		var r2: Rect2 = pk.row_rect("raspadura")
		if r2.size.x > 0.0:
			await _click(r2.get_center())
			await _wait(0.6)
		else:
			print("W3INT el selector no muestra «raspadura»: %s" % str(pk.visible_ids()))
			await _key(KEY_ESCAPE)
	var h: Dictionary = _sheet("Q1")
	_check(h.get("answer") != null and String(h.answer.get("id", "")) == "raspadura", "respuesta «raspadura» elegida con el mouse")
	if h.get("answer") == null:
		_respaldo("dq_answer", {"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	# pruebas: arrastrar los dos recortes desde el cuaderno
	if nb == null and shell.is_open("notebook"):
		nb = shell.panel("notebook")
	_check(nb != null, "el cuaderno acoplado a la izquierda")
	var want := [String(clips.get("sheer", "")), String(clips.get("clausula", ""))]
	for i in 2:
		var cid: String = want[i]
		if cid == "" or nb == null:
			continue
		nb.show_tab("recortes")
		await tool.frames(6)
		var card = nb.page("recortes").card(cid)
		if card == null:
			_check(false, "tarjeta %s en el cuaderno" % cid)
			continue
		await _scroll_into_view(card.strip)
		await tool.frames(4)
		await _drag((card.strip as Control).get_global_rect().get_center(), ex.rect_of("prueba", i).get_center())
		await _wait(0.5)
		var got := String(ex.debug_state().proofs[i])
		_check(got == cid, "prueba %d arrastrada desde el cuaderno (%s)" % [i + 1, got])
		if got != cid:
			_respaldo("dq_proof %d" % i, {"t": "dq_proof", "q": "Q1", "slot": i, "clip": cid})
	await _wait(0.4)
	await _snap("dia1_hoja_llena")
	var pr: Rect2 = ex.rect_of("pasar")
	_check(pr.size.x > 0.0, "«Pasar en limpio» a la vista con las tres ranuras llenas")
	if pr.size.x > 0.0:
		await _click(pr.get_center())
		await _wait(0.8)
		await _snap("dia1_tinta_a")
		await _wait(2.4)
		await _snap("dia1_tinta_b")
	var inked: bool = g.sim.q_dossier().inked.any(func(x): return String(x.id) == "Q1")
	_check(inked, "Q1 en tinta: «%s»" % String(_sheet_any("Q1").get("ink_text", "")).left(80))
	if not inked and pr.size.x <= 0.0:
		_respaldo("dq_confirm", {"t": "dq_confirm", "q": "Q1"})
	_dossier_dump("tras_q1")
	# Q2: la pregunta con sus dudas y los rótulos de las ranuras (playtest v3)
	var r2q: Rect2 = ex.row_rect("Q2")
	if r2q.size.x > 0.0:
		await _click(r2q.get_center())
		await _wait(0.6)
		var h2: Dictionary = _sheet("Q2")
		_check((h2.get("proof_labels", []) as Array).size() == 2, "Q2 con los rótulos de sus dos pruebas: %s" % str(h2.get("proof_labels", [])))
		await _snap("dia1_hoja_q2")
	# clic derecho sobre un recorte del cuaderno: «Tirar este recorte» (se cierra sin tirar nada)
	if nb != null and nb.is_open():
		nb.show_tab("recortes")
		await tool.frames(6)
		var cid0 := String(clips.get("sheer", ""))
		var card0 = nb.page("recortes").card(cid0) if cid0 != "" else null
		if card0 != null:
			await _scroll_into_view(card0.strip)
			await _rclick((card0.strip as Control).get_global_rect().get_center())
			await _wait(0.4)
			var dm = nb.drop_menu()
			_check(dm != null and dm.visible and nb.is_open(), "clic derecho sobre un recorte: «Tirar este recorte» (el cuaderno sigue abierto)")
			await _snap("dia1_recorte_menu")
			if dm != null and dm.visible:
				dm.hide()
				await tool.frames(4)
	# playtest v3 (MAJOR cámara): cerrar con «Volver» (arriba a la derecha, dentro de la franja del borde) no gira la vista
	var vb: Button = _button(ex, Widgets.t("exp.volver"), true)
	if vb != null:
		var yaw0: float = shell.world.rig.yaw_off
		var pt := _c(vb)
		await _click(pt)
		await _wait(2.0)
		var in_band: bool = shell.world.edge_vector(pt, vp.get_visible_rect().size) != Vector2.ZERO
		print("W3INT cerrar el expediente con «Volver» en %s (en la franja: %s): yaw %.1f -> %.1f" % [str(pt), str(in_band), yaw0, shell.world.rig.yaw_off])
		_check(not shell.is_open("dossier"), "«Volver» cierra el expediente")
		_check(absf(shell.world.rig.yaw_off - yaw0) < 1.0, "tras cerrar, la vista no sale disparada aunque el mouse quede en la franja")
		await _snap("dia1_tras_volver")
		_mm(Vector2(800, 450))
		await _wait(0.4)
	else:
		await _key(KEY_ESCAPE)
		await _wait(0.6)

func _respaldo_q1() -> void:
	_respaldo("dq_answer", {"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	_respaldo("dq_proof 0", {"t": "dq_proof", "q": "Q1", "slot": 0, "clip": String(clips.get("sheer", ""))})
	_respaldo("dq_proof 1", {"t": "dq_proof", "q": "Q1", "slot": 1, "clip": String(clips.get("clausula", ""))})
	_respaldo("dq_confirm", {"t": "dq_confirm", "q": "Q1"})

func _crane() -> void:
	shell.world.set_frame("puerta")
	await _wait(1.6)
	var ok := await _click_3d("puerta")
	await _idle()
	await _wait(1.2)
	_check(ok and String(g.sim.q_scene().get("area", "")) == "tienda", "la puerta baja a la tienda")
	await _snap("dia1_tienda")
	var sp = shell.panel("scene")
	if sp == null:
		_check(false, "la banda de la escena con Crane")
		return
	var intro := false
	for r in sp.transcript.rows():
		if String(r.who) == "crane":
			intro = true
	_check(intro, "Crane se presenta al bajar")
	var vb: Button = sp.band.find_child("Verbo_donde", true, false)
	_check(vb != null and vb.is_visible_in_tree(), "«¿Dónde consigo…?» en el bloque de Crane")
	if vb != null and vb.is_visible_in_tree():
		await _click_ctrl(vb)
		await _wait(0.6)
		var ap = sp.ask_panel
		var ids: Array = ap.shown_ids()
		print("W3INT donde: %s" % str(ids))
		await _snap("dia1_donde_lista")
		var i := ids.find("donde.diarios")
		if i < 0 and not ids.is_empty():
			i = 0
		if i >= 0:
			var rr: Rect2 = ap._list.get_item_rect(i)
			await _click(ap._list.get_global_rect().position + rr.get_center())
			await _wait(0.4)
			await _click_ctrl(ap._ok)
			await _wait(1.2)
			await _snap("dia1_crane_contesta")
	await _leave_scene("dia1_subir")
	_check(String(g.sim.q_clock().phase) == "desk", "«Subir»: de vuelta en la pieza")
	# otra bajada: Crane no se presenta dos veces (CRANE.intro once)
	var n0 := _crane_intro_count()
	shell.world.set_frame("puerta")
	await _wait(1.2)
	if await _click_3d("puerta"):
		await _idle()
		await _wait(0.8)
		_check(_crane_intro_count() == n0, "la segunda vez Crane no se vuelve a presentar")
		await _leave_scene("dia1_subir_2")

func _crane_intro_count() -> int:
	var n := 0
	for uid in g.sim.st.world.get("lines", {}):
		var rec = g.sim.st.world.lines[uid]
		if String(rec.get("scene", "")) == "CRANE":
			n += 1
	return n

func _plano(tag: String) -> void:
	shell.world.set_frame("mapa")
	await _wait(1.6)
	var ok := await _click_3d("mapa")
	await _wait(1.0)
	_check(ok and shell.is_open("map"), "%s: el plano de la pared" % tag)
	if not shell.is_open("map"):
		return
	var ms = shell.panel("map")
	await _snap(tag + "_plano")
	for pid in ["L2", "L3", "L4"]:
		var m = ms.marker(pid) if ms.has_method("marker") else null
		if m == null:
			continue
		var c: Vector2 = (m as Control).get_global_rect().position + (m as Control).get_meta("origin", Vector2(12, 12))
		await _move_to(c)
		await _wait(0.5)
		print("W3INT plano %s: %s" % [pid, String(ms._hover.text).replace("\n", " | ")])
		await _snap("%s_plano_%s" % [tag, pid])
		break
	# Kensington tiene dos áreas: la tarjeta de áreas se abre y la ayuda del marcador no queda debajo (playtest v3)
	var m4 = ms.marker("L4") if ms.has_method("marker") else null
	if m4 != null and bool(m4.state.get("open", false)):
		var c4: Vector2 = (m4 as Control).get_global_rect().position + (m4 as Control).get_meta("origin", Vector2(12, 12))
		await _move_to(c4)
		await _wait(0.4)
		await _click(c4)
		await _wait(0.6)
		_check(ms._popup != null and not ms._hover.visible, "tarjeta de áreas abierta, sin la ayuda debajo")
		await _snap("%s_plano_tarjeta_L4" % tag)
		ms._close_popup()
		await tool.frames(4)

# ================================================================== día 2
func _dia2() -> void:
	_check(int(g.sim.q_clock().day) == 2, "amanece el día 2")
	print("W3INT bandeja 2: ", g.sim.q_tray(2).map(func(it): return String(it.view)))
	await _snap("dia2_bandeja_detalle")
	await _close_tray()
	await _wait(0.5)
	_tutor("dia2")
	_guide("dia2")
	_dossier_dump("dia2")
	await _snap("dia2_escritorio")
	# una salida: el plano -> el Museo Británico -> la Sala de Lectura -> volver
	shell.world.set_frame("mapa")
	await _wait(1.6)
	if not await _click_3d("mapa"):
		_check(false, "día 2: el plano")
		return
	await _wait(1.0)
	var ms = shell.panel("map")
	var m = ms.marker("L2") if ms != null and ms.has_method("marker") else null
	_check(m != null, "el Museo Británico en el plano")
	if m == null:
		return
	var c: Vector2 = (m as Control).get_global_rect().position + (m as Control).get_meta("origin", Vector2(12, 12))
	await _click(c)
	await _wait(0.8)
	await _snap("dia2_plano_l2")
	# la tarjeta de áreas -> confirmar el viaje (los botones que ofrezca el plano)
	for _k in 4:
		if String(g.sim.q_clock().phase) == "visit":
			break
		var b := _first_enabled_button(ms, true)
		var top = shell.top()
		var cf = gs().modal()
		if cf != null:
			b = _first_enabled_button(cf, true)
		if b == null:
			break
		print("W3INT plano: clic en «%s»" % b.text)
		await _click(_c(b))
		await _wait(1.0)
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 1200)
	await _idle()
	await _wait(1.5)
	_check(String(g.sim.q_clock().phase) == "visit", "viaje al Museo Británico")
	await _snap("dia2_sala_de_lectura")
	_dump_state("visita")
	await _leave_scene("dia2_salir")
	_check(String(g.sim.q_clock().phase) == "desk", "de vuelta en la pieza (departamento → lugar → departamento)")
	await _snap("dia2_de_vuelta")

# ================================================================== noche y día 3 (corrector final)
func _seguir_dia2() -> void:
	await _close_slots_until_night()
	await _wait(1.8)
	print("W3INT noche 2 al llegar: encuadre «%s», fase %s, informe %s" % [String(shell.world.rig.cur), String(g.sim.q_clock().phase), str(g.sim.q_report_status().get("due", false))])
	if bool(g.sim.q_report_status().get("due", false)):
		_check(String(shell.world.rig.cur) == "puerta", "22 h con informe: la vista mira la puerta, donde espera el chico")
	await _snap("noche2_puerta")
	await _tintero_noche("noche2")
	await _informe_original()
	await _sleep_and_dawn("noche2")
	await _dia3()

# «Continuar» desde el título (la partida guardada en user://saves/v3integ.jsonl).
func _title_continue() -> void:
	var title = shell.screen
	await _snap("titulo_continuar")
	var bc := _button(title, Widgets.t("shell.title.continuar"))
	_check(bc != null, "título: «Continuar»")
	if bc == null:
		return
	await _click(_c(bc))
	await tool.frames(8)
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 1500)
	await tool.frames(40)
	var c: Dictionary = g.sim.q_clock() if g.sim != null else {}
	print("W3INT continuar: día %s %s %s" % [str(c.get("day", "")), str(c.get("slot", "")), str(c.get("phase", ""))])
	_check(g.sim != null and int(c.get("day", 0)) == 2, "«Continuar» -> el día 2")
	# playtest v3: al continuar, la bandeja se abre sola sólo si tiene papeles sin leer
	var unread := false
	for it in g.sim.q_tray(int(c.get("day", 0))):
		if not bool(it.get("read", false)):
			unread = true
	print("W3INT continuar: bandeja %s, sin leer: %s" % ["abierta" if gs().tray.visible else "cerrada", str(unread)])
	_check(gs().tray.visible == unread, "al continuar, la bandeja se abre sola sólo con papeles sin leer (sin leer: %s)" % str(unread))
	await _snap("continuar_pieza")
	if gs().tray.visible:
		await _close_tray()
		await _wait(0.4)

# Los recortes de la primera sesión (por texto: la prueba de imprenta, para el informe con un original).
func _restore_clips() -> void:
	for c in g.sim.q_clips():
		var t := String(c.get("text", ""))
		if String(c.get("doc", "")) == "D02" and t.contains("raspadura"):
			clips["clausula"] = String(c.id)
		elif String(c.get("doc", "")) == "D03" and t.contains("pique"):
			clips["sheer"] = String(c.id)
	print("W3INT recortes recuperados: %s" % str(clips))
# El tintero de noche: lupa y una línea de Lisle que dice por qué ya no sirve (playtest v3).
func _tintero_noche(tag: String) -> void:
	await _clear_top()
	shell.world.set_frame("escritorio")
	await _wait(1.4)
	var ok := await _click_3d("tintero")
	await tool.frames(16)
	var note := String(gs().exam.note_label.text) if gs().exam.visible else ""
	print("W3INT tintero de noche [%s]: %s" % [tag, note])
	_check(ok and gs().exam.visible and note.begins_with("A esta hora ya no escribo"), "%s: el tintero explica por qué ya no escribo" % tag)
	await _snap(tag + "_tintero")
	await _clear_top()
	gs().exam.hide_card()
	await tool.frames(4)

# Informe de la noche 2 con la prueba de imprenta (un original de la pieza): los de Moran entran el día 3 (M1).
func _informe_original() -> void:
	var st: Dictionary = g.sim.q_report_status()
	_check(bool(st.get("due", false)), "noche 2: hay informe")
	# playtest v3: a las 22 la vista mira la puerta (el chico de Pell) y el chico lleva la mano
	print("W3INT 22 h: encuadre %s, el chico usable: %s" % [String(shell.world.rig.cur), str(shell.world.usable.has("c:chico_de_pell"))])
	_check(shell.world.usable.has("c:chico_de_pell"), "22 h: el chico de Pell con cursor de mano")
	await _click_ctrl(gs().hud.card)
	await tool.frames(20)
	var rc = shell.top()
	_check(rc != null and shell.top_kind() == "report", "calendario -> el sobre del informe")
	if rc == null or shell.top_kind() != "report":
		_respaldo("report_submit", {"t": "report_submit", "mode": "items", "items": [{"kind": "clip", "id": String(clips.get("clausula", ""))}]})
		return
	var ch := _button(rc, Widgets.t("sceneui.rep.choose"))
	if ch != null:
		await _click(_c(ch))
		await tool.frames(14)
		var pk = rc.picker
		if pk != null and pk.visible:
			pk.set_tab("clip")
			await tool.frames(6)
			var want := String(clips.get("clausula", ""))
			for cd in pk.cards():
				if String(cd.kind) == "clip" and String(cd.id) == want:
					await _scroll_into_view(cd.node)
					await tool.frames(4)
					await _snap("informe_elegir")
					await _click(_c(cd.node))
					await tool.frames(12)
					break
	_check(rc.items.size() >= 1, "la prueba de imprenta en el sobre (%d)" % rc.items.size())
	await _snap("informe_lleno")
	var send := _button(rc, Widgets.t("sceneui.rep.send"), true)
	if send != null and not send.disabled:
		await _click(_c(send))
		await tool.frames(12)
		var cf = _find(rc, "Confirmacion")
		if cf != null and "ok_button" in cf:
			await _click(_c(cf.ok_button))
			await _wait(1.2)
	_check(not bool(g.sim.q_report_status().get("due", false)), "informe entregado")
	if bool(g.sim.q_report_status().get("due", false)):
		_respaldo("report_submit", {"t": "report_submit", "mode": "items", "items": [{"kind": "clip", "id": String(clips.get("clausula", ""))}]})
	await _clear_top()

func _dia3() -> void:
	_check(int(g.sim.q_clock().day) == 3, "amanece el día 3")
	print("W3INT bandeja 3: ", g.sim.q_tray(3).map(func(it): return String(it.view)))
	await _close_tray()
	await _wait(0.6)
	_guide("dia3")
	_dossier_dump("dia3")
	await _snap("dia3_escritorio")
	# el expediente: la pregunta de las cartas a máquina (Q3) con sus rótulos
	if await _click_3d("expediente"):
		await _wait(1.0)
		var ex = shell.panel("dossier")
		if ex != null and shell.is_open("dossier"):
			var rr: Rect2 = ex.row_rect("Q3")
			if rr.size.x > 0.0:
				await _click(rr.get_center())
				await _wait(0.6)
			await _snap("dia3_expediente_q3")
		await _key(KEY_ESCAPE)
		await _wait(0.6)
	await _clear_top()
	# salida: Kensington (el consultorio de Watson tiene su propio sonido)
	shell.world.set_frame("mapa")
	await _wait(1.6)
	if not await _click_3d("mapa"):
		_check(false, "día 3: el plano")
		return
	await _wait(1.0)
	var ms = shell.panel("map")
	var m = ms.marker("L4") if ms != null and ms.has_method("marker") else null
	_check(m != null, "Kensington en el plano")
	if m == null:
		return
	var c: Vector2 = (m as Control).get_global_rect().position + (m as Control).get_meta("origin", Vector2(12, 12))
	await _click(c)
	await _wait(0.8)
	for _k in 4:
		if String(g.sim.q_clock().phase) == "visit":
			break
		var b := _first_enabled_button(ms, true)
		var cf = gs().modal()
		if cf != null:
			b = _first_enabled_button(cf, true)
		if b == null:
			break
		print("W3INT plano: clic en «%s»" % b.text)
		await _click(_c(b))
		await _wait(1.0)
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 1200)
	await _idle()
	await _wait(1.5)
	_check(String(g.sim.q_clock().phase) == "visit", "viaje a Kensington")
	var au = tool.root.get_node_or_null("Audio")
	# con --mute el bucle no suena: se mira qué ambiente le toca al lugar (data/audio.json), y el que sonaría
	var amb := String(au.ambience_for(String(gs().cur_place), "%d.%s" % [int(g.sim.q_clock().day), String(g.sim.q_clock().slot)]).get("id", "")) if au != null else ""
	if au != null and String(au.current_amb()) != "":
		amb = String(au.current_amb())
	print("W3INT ambiente en Kensington: %s" % amb)
	_check(amb == "amb.consultorio", "el consultorio de Watson suena distinto de la tienda (%s)" % amb)
	await _snap("dia3_kensington")
	await _leave_scene("dia3_salir")
	_check(String(g.sim.q_clock().phase) == "desk", "de vuelta en la pieza")
	await _wait(0.2)
	await _snap("dia3_vuelta_a")
	var yv0: float = shell.world.rig.yaw_off
	var pv0: float = shell.world.rig.pitch_off
	await _wait(2.5)
	await _snap("dia3_vuelta_b")
	print("W3INT de vuelta (mouse en %s): yaw %.1f -> %.1f, cabeceo %.1f -> %.1f" % [str(vp.get_mouse_position()), yv0, shell.world.rig.yaw_off, pv0, shell.world.rig.pitch_off])
	_check(absf(shell.world.rig.yaw_off - yv0) < 1.0 and absf(shell.world.rig.pitch_off - pv0) < 1.0, "al volver a la pieza la vista no gira sola (el mouse quedó sobre «Salir»)")
	_check(not gs().tray.visible, "la pieza revuelta se ve: la bandeja no se abre sola encima")
	var snap: Dictionary = g.sim.q_hub_plate() if g.sim.has_method("q_hub_plate") else {}
	print("W3INT pieza al volver: variante «%s»" % String(snap.get("variant", "")))
	_check(String(snap.get("variant", "")).contains("registrada"), "los de Moran entraron por la puerta (variante registrada)")
	# la ceniza sobre el escritorio: notarla hace nacer «¿Quién entró a mi pieza?» (Q8)
	shell.world.set_frame("escritorio")
	await _wait(1.4)
	await _snap("dia3_escritorio_registrado")
	if await _click_3d("ceniza_escritorio"):
		await tool.frames(16)
		await _snap("dia3_ceniza")
		gs().exam.hide_card()
	_check(Dossier_born("Q8"), "Q8 nace al notar la intrusión")
	await _clear_top()
	shell.world.set_frame("puerta")
	await _wait(1.4)
	await _snap("dia3_puerta_registrada")
	shell.world.set_frame("escritorio")
	await _wait(1.2)
	if await _click_3d("expediente"):
		await _wait(1.0)
		var ex2 = shell.panel("dossier")
		if ex2 != null and shell.is_open("dossier"):
			var r8: Rect2 = ex2.row_rect("Q8")
			if r8.size.x > 0.0:
				await _click(r8.get_center())
				await _wait(0.6)
			await _snap("dia3_expediente_q8")
		await _key(KEY_ESCAPE)
		await _wait(0.6)
	_guide("dia3_fin")
	_dossier_dump("dia3_fin")

func Dossier_born(qid: String) -> bool:
	var d = g.sim.st.ded.get("dossier", {})
	return typeof(d) == TYPE_DICTIONARY and (d.get("born", {}) as Dictionary).has(qid)

# ================================================================== piezas
# Clic en un objeto del 3D: el punto se recalcula justo antes de apretar (la cámara del riel puede estar deslizándose) y
# el botón va en el mismo cuadro que el último movimiento (el cursor del sistema puede no obedecer a warp_mouse).
func _click_3d(id: String) -> bool:
	for _try in 6:
		var p := _node_pos(id)
		if p.x < 0.0 or String(shell.world.pick(p).get("id", "")) != id:
			await _wait(0.3)
			continue
		_mm(p)
		await tool.frames(2)
		p = _node_pos(id)
		if p.x < 0.0 or String(shell.world.pick(p).get("id", "")) != id:
			continue
		_mm(p)
		_btn(p, true)
		await tool.frames(1)
		_btn(p, false)
		await tool.frames(4)
		return true
	print("[w3int] «%s» no está a la vista" % id)
	return false

# Estante -> tarjeta -> el enlace que contenga hint (si está plegado en «Mis papeles», primero ese renglón) -> lector.
func _read_from_shelf(hint: String) -> void:
	await _idle()
	shell.world.set_frame("estante")
	await _wait(1.2)
	var ok := await _click_3d("estante")
	await tool.frames(16)
	_check(ok and gs().exam.visible, "clic en el estante -> su tarjeta")
	var target: Button = _button(gs().exam, hint, false, false)
	if target == null:
		for b in gs().exam.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and String((b as Button).text).to_lower().contains(hint.to_lower()):
				target = b
	if target == null:
		var fold: Button = _button(gs().exam, Widgets.t("mundo.estante.mis_papeles"), false, true) if Widgets.t("mundo.estante.mis_papeles") != "mundo.estante.mis_papeles" else null
		if fold == null:
			for b in gs().exam.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and String((b as Button).text).begins_with("Mis papeles"):
					fold = b
		if fold != null:
			await _click_ctrl(fold)
			await tool.frames(12)
			await _snap("estante_mis_papeles")
			for b in gs().exam.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and String((b as Button).text).to_lower().contains(hint.to_lower()):
					target = b
	_check(target != null, "en el estante: «%s»" % hint)
	if target != null:
		await _scroll_into_view(target)
		await _click_ctrl(target)
		await tool.frames(24)

func _speech_through(tag: String, maxn := 30) -> void:
	var n := 0
	var gsc = gs()
	while gsc != null and gsc.speech.visible and n < maxn:
		var before := String(gsc.speech.text.get_parsed_text())
		print("W3INT DICHO [%s] %s" % [tag, before.replace("\n", " / ").left(220)])
		if n == 0:
			await _snap("dicho_" + tag)
		await _click(_c(gsc.speech))
		await _wait(0.35)
		n += 1
		if String(gsc.speech.text.get_parsed_text()) == before and gsc.speech.visible:
			await _wait(0.8)
			if String(gsc.speech.text.get_parsed_text()) == before and gsc.speech.visible:
				print("W3INT lo dicho no avanza con el clic")
				break

func _tutor(tag: String) -> void:
	var gsc = gs()
	var t := ""
	if gsc != null and gsc.tutor.visible:
		t = String(gsc.tutor.text.get_parsed_text())
	print("W3INT NOTA [%s] %s" % [tag, t.replace("\n", " / ")])

func _guide(tag: String) -> void:
	var gsc = gs()
	if gsc == null:
		return
	var lines: Array = gsc.hud.guide_lines() if gsc.hud.has_method("guide_lines") else []
	print("W3INT PENDIENTES [%s] %s" % [tag, str(lines)])

func _open_ids() -> Array:
	return g.sim.q_dossier().open.map(func(h): return String(h.id))

func _sheet(qid: String) -> Dictionary:
	for h in g.sim.q_dossier().open:
		if String(h.id) == qid:
			return h
	return {}

func _sheet_any(qid: String) -> Dictionary:
	var d: Dictionary = g.sim.q_dossier()
	for k in ["open", "inked"]:
		for h in d[k]:
			if String(h.id) == qid:
				return h
	return {}

func _dossier_dump(tag: String) -> void:
	var d: Dictionary = g.sim.q_dossier()
	print("W3INT EXPEDIENTE [%s] abiertas=%s tinta=%s" % [tag, str(d.open.map(func(h): return "%s «%s»" % [h.id, h.text])), str(d.inked.map(func(h): return h.id))])

func _dump_state(tag: String) -> void:
	var c: Dictionary = g.sim.q_clock()
	print("W3INT ESTADO [%s] día %s %s %s · recortes %d · lugares %s" % [tag, str(c.day), str(c.slot), str(c.phase), g.sim.q_clips().size(), str(g.sim.q_places().map(func(p): return String(p.get("id", ""))))])

# Todas las hojas del documento abierto, con las flechas de abajo (la acción read de cada hoja).
func _read_all_pages(tag: String) -> void:
	var r = shell.reader
	var n: int = r.page_count()
	await _snap("lector_%s_1" % tag)
	for i in range(1, n):
		if r._b_next == null or not r._b_next.is_visible_in_tree() or r._b_next.disabled:
			break
		await _click(_c(r._b_next))
		await _wait(0.5)
		await _snap("lector_%s_%d" % [tag, i + 1])
	# de vuelta a la primera
	for _i in n:
		if int(r.page_idx) == 0 or r._b_prev == null or r._b_prev.disabled:
			break
		await _click(_c(r._b_prev))
		await tool.frames(6)

# Recorta del documento abierto la ventana legal (≤15 palabras, una oración) que más cubre el tramo tid.
func _clip_window(tid: String, shot: String) -> String:
	if not shell.reader_open():
		return ""
	var r = shell.reader
	var v: Dictionary = r.view
	var where := _find_tramo(v, tid)
	if where.is_empty():
		_check(false, "tramo #%s en %s" % [tid, String(v.get("view", ""))])
		return ""
	var parsed: Dictionary = v.pages[int(where.part)][int(where.block)].get("parsed", {})
	var span: Array = Walk.best_window(parsed, int(where.from), int(where.to))
	var guard := 0
	while int(r.page_idx) != int(where.part) and guard < 12:
		var b: Button = r._b_next if int(r.page_idx) < int(where.part) else r._b_prev
		await _click(_c(b))
		await tool.frames(8)
		guard += 1
	if not r.tijera:
		await _click(r.scissors_rect().get_center())
		await tool.frames(6)
	_check(r.tijera, "la tijera en la mano (ícono)")
	var rtl: RichTextLabel = r.block_rtl(int(where.block))
	if rtl == null:
		return ""
	var area: Rect2 = r._read_rect()
	for _i in 6:
		var pts: Array = SelectionMapper.drag_points(rtl, int(span[0]), int(span[1]))
		var lo: float = minf(pts[0].y, pts[1].y)
		var hi: float = maxf(pts[0].y, pts[1].y)
		var dy := 0.0
		if hi > area.end.y - 60.0:
			dy = -minf(hi - (area.end.y - 160.0), 500.0)
		elif lo < area.position.y + 40.0:
			dy = minf((area.position.y + 120.0) - lo, 500.0)
		if dy == 0.0:
			break
		await _pan(area.get_center(), Vector2(0, dy))
	var id := ""
	for k in 3:
		id = await _drag_select(rtl, int(span[0]) + k, int(span[1]), shot if k == 0 else "")
		# el recorte tiene que ser la ventana buscada: con el cursor del sistema en otro lado, RichTextLabel puede dejar una
		# selección parcial que el juego acepta (un recorte corto y sin las etiquetas): no sirve de prueba
		if id != "":
			var want_txt := rtl.get_parsed_text().substr(int(span[0]), int(span[1]) - int(span[0])).strip_edges()
			var got_txt := String(g.sim.q_clip(id).get("text", "")).strip_edges()
			if got_txt != want_txt:
				print("W3INT recorte parcial «%s» (buscado «%s»)" % [got_txt, want_txt])
				id = ""
				cursor_bad = true
		if id != "":
			break
	if id == "" and cursor_bad:
		# el cursor del sistema no obedece a warp_mouse (el usuario está usando el mouse o la ventana no tiene el foco):
		# RichTextLabel estira la selección hasta el cursor real; no es una falla del juego (lo cubren test_u_reader_v3 y
		# test_u_reader_v3_window con eventos reales)
		entorno += 1
		_env_pending += 1
		print("W3INT AVISO (entorno) tijera sobre #%s: el cursor del sistema no obedece; se sigue por Game.act" % tid)
	else:
		_check(id != "", "tijera sobre #%s -> «%s»" % [tid, String(g.sim.q_clip(id).get("text", "")) if id != "" else ""])
	return id

# Arrastre de la tijera como v3lector_shots: con ventana, RichTextLabel estira la selección cada 50 ms hasta el cursor
# del sistema (que el usuario puede estar moviendo); el último movimiento y el soltar van en el mismo cuadro.
func _drag_select(rtl: RichTextLabel, from: int, to: int, shot: String) -> String:
	var pts: Array = SelectionMapper.drag_points(rtl, from, to)
	var n0: int = g.sim.q_clips().size()
	var want := rtl.get_parsed_text().substr(from, to - from).strip_edges()
	_mm(pts[0])
	await tool.frames(2)
	await _sync_mouse(pts[0])
	_mm(pts[0])
	_btn(pts[0], true)
	await tool.frames(1)
	for i in range(1, 13):
		_mm(pts[0].lerp(pts[1], float(i) / 12.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	# con el botón apretado, se insiste en el punto final hasta que la selección sea la buscada (o 40 cuadros)
	var sel := ""
	for _k in 40:
		_mm(pts[1], MOUSE_BUTTON_MASK_LEFT)
		sel = rtl.get_selected_text().strip_edges()
		if sel != "" and (sel == want or (absi(sel.length() - want.length()) <= 2 and want.begins_with(sel.left(8)))):
			break
		await tool.frames(1)
	print("W3INT seleccionado: «%s»%s" % [sel, "" if sel == want else " (buscado «%s»)" % want])
	_btn(pts[1], false)
	await tool.frames(12)
	if shot != "":
		await _snap(shot)
	var cl: Array = g.sim.q_clips()
	return String(cl[-1].get("id", "")) if cl.size() > n0 else ""

# Un respaldo de recorte que sigue a un aviso de entorno (cursor del sistema) no cuenta como respaldo de UI.
func _respaldo(what: String, a: Dictionary) -> Dictionary:
	if what.begins_with("clip ") and _env_pending > 0:
		_env_pending -= 1
		env_resp += 1
	return super(what, a)

func _respaldo_window(tid: String, view: String) -> void:
	var v: Dictionary = g.sim.q_view(view)
	var w := _find_tramo(v, tid)
	if w.is_empty():
		return
	var parsed: Dictionary = v.pages[int(w.part)][int(w.block)].get("parsed", {})
	var span: Array = Walk.best_window(parsed, int(w.from), int(w.to))
	var r := _respaldo("clip " + tid, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": int(w.part), "block": int(w.block)}, "from": int(span[0]), "len": int(span[1]) - int(span[0])})
	clips[tid] = String(r.get("clip", ""))

func _move_to(p: Vector2) -> void:
	for _i in 10:
		_mm(p)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(p) < 1.5:
			return

func _type(text: String) -> void:
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

var cursor_bad := false
var entorno := 0
var env_resp := 0       # respaldos de recorte causados por un aviso de entorno
var _env_pending := 0

func _sync_mouse(pos: Vector2, mask := 0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		_mm(pos, mask)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(pos) < 1.5:
			return
	cursor_bad = true

func _summary() -> void:
	print("W3INT RESUMEN %d fallas, %d respaldos, %d capturas, %d avisos de entorno (cursor del sistema)" % [fails, fallbacks - env_resp, _shot, entorno])

# «Salir» / «Subir a casa» del panel de la escena (con su confirmación si la pide), como el jugador.
func _leave_scene(tag: String) -> void:
	var sp = shell.panel("scene")
	var b: Button = null
	if sp != null:
		for key in ["sceneui.leave.free", "sceneui.leave"]:
			if b == null:
				b = _button(sp, Widgets.t(key), true)
	_check(b != null, "%s: el botón para salir en el panel" % tag)
	if b != null:
		await _click_ctrl(b)
		await _wait(0.6)
		var okb: Button = _button(sp, Widgets.t("sceneui.leave.ok"), true) if is_instance_valid(sp) else null
		if okb != null:
			await _snap(tag + "_confirma")
			await _click_ctrl(okb)
	await _until(func(): return String(g.sim.q_clock().phase) != "visit", 900)
	await _idle()
	await _wait(0.8)
