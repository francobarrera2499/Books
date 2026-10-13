# W3-INT (integrador de UI): el juego real de punta a punta, con data/ real y SOLO con el mouse real (warp_mouse +
# Input.parse_input_event; ninguna llamada a la API de los paneles para actuar). Captura cada paso.
#   título -> prólogo (encargo -> lector -> tijera; tomos -> dos recortes; cuaderno: juntar; libro mayor: folio, asiento,
#   campos, «según», práctica; tintero -> aviso; calendario -> dormir) -> amanecer -> bandeja -> lector -> recortar ->
#   cuaderno -> libro mayor -> mapa -> Kensington -> preguntar a Watson -> presentar un recorte -> salir -> cerrar
#   franjas -> dormir -> día 2 -> noche de informe -> informe -> dormir -> amanecer.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3int res://devtools/drivers/w3int_flow.gd --mute
# Salida: «W3INT OK|FALLA <paso>», «W3INT RESPALDO <paso>» (el clic no alcanzó y se siguió por la API para no cortar el
# recorrido: cuenta como falla de UI) y «W3INT RESUMEN n fallas, m respaldos». Capturas: .work/shots/w3int_NN_<paso>.png
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

var tool
var shell
var g
var vp: Viewport
var fails := 0
var fallbacks := 0
var _shot := 0
var _last := Vector2.ZERO
var clips := {}                 # nombre -> id de recorte

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("W3INT sin Shell")
		return
	g.save_path = "user://saves/w3int.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	shell.show_title()   # vuelve a armar el menú con el registro de esta corrida (sin «Continuar»)
	await tool.frames(30)
	await _title()
	if g.sim == null:
		_summary()
		return
	await _prologue()
	await _sleep_and_dawn("prologo")
	await _day1_tray()
	await _day1_books()
	await _day1_map()
	await _day1_visit()
	await _close_slots_until_night()
	await _sleep_and_dawn("noche1")
	await _close_tray()
	await _close_slots_until_night()
	await _night_report()
	await _sleep_and_dawn("noche2")
	await _snap("fin_dia3")
	_summary()
	g.end_session()

# ================================================================== pasos
func _title() -> void:
	var title = shell.screen
	await _snap("titulo")
	var bn := _button(title, Widgets.t("shell.title.nueva"))
	_check(bn != null, "título: «Partida nueva»")
	if bn == null:
		return
	await _click(_c(bn))
	await tool.frames(8)
	if title != null and is_instance_valid(title) and title.get("_confirm") != null and is_instance_valid(title._confirm):
		await _click(_c(_button(title._confirm, Widgets.t("shell.title.nueva_ok"))))
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 1200)
	await tool.frames(30)
	_check(g.sim != null and String(g.sim.q_clock().phase) == "prologue", "clic -> prólogo")

func gs():
	return shell.game_screen

func _prologue() -> void:
	await _snap("prologo")
	# --- 1. el encargo (D23) en la lámina -> tarjeta -> «Leer» -> lector -> tijera sobre el aviso
	await _read_from_node("encargo", "D23")
	await _snap("prologo_lector_d23")
	clips["aviso"] = await _clip_tramo("aviso", "prologo_tijera")
	await _close_reader()
	await _snap("prologo_tras_recorte")
	# --- 2. los tomos (D01.REDH@tomo): abril y octubre
	await _read_from_node("tomos", String(g.sim.q_view("D01.REDH@tomo").get("title", "REDH")))
	clips["abril"] = await _clip_tramo("abril", "")
	clips["octubre"] = await _clip_tramo("octubre", "prologo_tijera_octubre")
	await _close_reader()
	_respaldo_clip("abril", "D01.REDH@tomo")
	_respaldo_clip("octubre", "D01.REDH@tomo")
	# --- 3. cuaderno: juntar abril con octubre (arrastrar una tarjeta sobre la otra)
	await _click_ribbon("notebook")
	var nb = shell.panel("notebook")
	_check(nb != null and shell.is_open("notebook"), "cinta «Cuaderno» abre el cuaderno")
	await tool.frames(20)
	await _snap("prologo_cuaderno")
	var pairs0: int = g.sim.q_pairs().size()
	var ca = _card(nb, clips.get("abril", ""))
	var co = _card(nb, clips.get("octubre", ""))
	_check(ca != null and co != null, "tarjetas de abril y octubre en el cuaderno")
	if ca != null and co != null:
		await _drag(_c(ca), _c(co))
		await tool.frames(16)
		var form = nb.overlay_panel() if nb.has_method("overlay_panel") else null
		_check(form != null, "soltar una tarjeta sobre otra abre el formulario de cotejo")
		await _snap("prologo_cotejo")
		if form != null and "ok_button" in form:
			await _click(_c(form.ok_button))
			await tool.frames(16)
	var linked: bool = g.sim.q_pairs().size() > pairs0
	_check(linked, "cotejo hecho con el mouse")
	if not linked:
		_respaldo("link", {"t": "link", "a": clips.get("abril", ""), "b": clips.get("octubre", ""), "note": ""})
	# Volver del cuaderno (su botón)
	await _click_named(nb, "Volver")
	await tool.frames(12)
	_check(not shell.is_open("notebook"), "«Volver» cierra el cuaderno")
	# --- 4. libro mayor: «Nuevo folio» -> elegir abril; «Nuevo asiento» -> T1; campos; según; práctica
	await _click_ribbon("ledger")
	var lg = shell.panel("ledger")
	_check(lg != null and shell.is_open("ledger"), "cinta «Libro mayor» abre el libro")
	await tool.frames(20)
	await _snap("prologo_libro_reglas")
	var nfo = _find(lg, "NuevoFolio")
	await _click_ctrl(nfo)
	await tool.frames(10)
	if lg.picker() != null:
		await _snap("prologo_elegir_recorte")
		var rr = lg.picker().row_rect(clips.get("abril", ""))
		await _click(rr.get_center() if rr.size.x > 0 else Vector2(-1, -1))
		await tool.frames(12)
	var folio := ""
	for fo in g.sim.q_ledger().get("folios", []):
		if String(fo.get("head_clip", "")) == clips.get("abril", ""):
			folio = String(fo.id)
	_check(folio != "", "«Nuevo folio» -> elegir el recorte de abril")
	if folio == "":
		var r: Dictionary = _respaldo("folio_open", {"t": "folio_open", "clip": clips.get("abril", "")})
		folio = String(r.get("folio", ""))
		lg.show_page(folio)
		await tool.frames(8)
	await _click_ctrl(_find(lg, "NuevoAsiento"))
	await tool.frames(10)
	if lg.picker() != null:
		await _snap("prologo_plantillas")
		var tr = lg.picker().row_rect("T1")
		await _click(tr.get_center() if tr.size.x > 0 else Vector2(-1, -1))
		await tool.frames(12)
	var e := String(lg.selected)
	_check(e != "" and String(g.sim.q_entry(e).get("template", "")) == "T1", "asiento T1 por clic: %s" % e)
	if e == "" or String(g.sim.q_entry(e).get("template", "")) != "T1":
		e = String(_respaldo("entry_new", {"t": "entry_new", "folio": folio, "template": "T1"}).get("entry", ""))
		lg.select_entry(e)
		await tool.frames(8)
	for x in [[0, "fuente_a", "redh"], [0, "dice_a", "abril_27_1890"], [1, "fuente_b", "redh"], [1, "dice_b", "octubre_9_1890"]]:
		await _ledger_field(lg, e, int(x[0]), String(x[1]), String(x[2]))
	await _snap("prologo_campos")
	await _ledger_support(lg, e, 0, clips.get("abril", ""))
	await _ledger_support(lg, e, 1, clips.get("octubre", ""))
	await _snap("prologo_asiento")
	var pr = _find(_find(lg, "Pie"), "Practicar")
	_check(pr != null and pr.is_visible_in_tree(), "botón de práctica en el pie del asiento")
	await _click_ctrl(pr)
	await _wait(0.8)
	var step := _tut_index()
	_check(step >= 5, "práctica hecha por clic (paso del tutorial %d)" % step)
	await _snap("prologo_practica")
	if step < 5:
		_respaldo("practice", {"t": "practice", "entry": e})
	await _rclick(Vector2(800, 450))
	await tool.frames(16)
	if shell.is_open("ledger"):
		await _key(KEY_ESCAPE)
		await tool.frames(10)
	_check(not shell.is_open("ledger"), "clic derecho cierra el libro mayor")
	# --- 5. el aviso (Harris): tintero -> «Redactar un aviso» -> forma -> hueco -> enviar
	await _snap("prologo_harris")
	await _compose_ad_prologue()
	# --- 6. dormir (calendario)
	_check(bool(g.sim.q_tutorial().get("complete", false)), "tutorial completo")

func _compose_ad_prologue() -> void:
	var ok := await _click_3d("tintero")
	await tool.frames(16)
	var link := _link_button(gs().exam, Widgets.t("shell.compose.ad"))
	_check(ok and link != null, "tintero -> tarjeta con «%s»" % Widgets.t("shell.compose.ad"))
	if link != null:
		await _click(_c(link))
		await tool.frames(20)
	var ac = shell.top()
	var is_ad: bool = ac != null and shell.top_kind() == "ad"
	_check(is_ad, "compositor de avisos abierto")
	if not is_ad:
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
		return
	await _snap("prologo_aviso")
	# forma «testigo»: su pestaña de forma (si no es ya la elegida)
	print("[w3int] formas: ", ac.forms_available())
	if String(ac.form_id) != "testigo" and ac._form_btns.has("testigo"):
		await _click(_c(ac._form_btns["testigo"]))
		await tool.frames(8)
	_check(String(ac.form_id) == "testigo", "forma «testigo» elegida")
	# huecos: abrir el menú del hueco con un clic y elegir la opción pasando el mouse por el menú
	for slot in ac._blanks.keys():
		var bl = ac._blanks[slot]
		if String(bl.value) != "":
			continue
		var want := "suceso_reichenbach" if String(slot) == "suceso" else ""
		await _choose_popup(bl, want)
	await tool.frames(8)
	await _snap("prologo_aviso_lleno")
	var send := _button(ac, Widgets.t("sceneui.ad.send"))
	_check(send != null and not send.disabled, "«Enviar a la oficina» habilitado")
	if send != null:
		await _click(_c(send))
		await tool.frames(12)
		await _snap("prologo_aviso_confirma")
		var cf = _find(ac, "Confirmacion")
		if cf != null and "ok_button" in cf:
			await _click(_c(cf.ok_button))
			await _wait(0.3)
			await _snap("prologo_aviso_recibido")
			await _wait(0.9)   # el sello «Recibido» se ve un momento y el compositor se cierra solo
	var sent := _tut_index() >= 6
	_check(sent, "aviso enviado por clic")
	if not sent:
		_respaldo("compose_ad", {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_check(shell.top_kind() != "ad", "el compositor se cierra solo tras el sello")
	await _clear_top()

# Cierra lo que quede arriba (clic derecho en el centro, como el jugador) hasta que no haya paneles.
func _clear_top() -> void:
	for _i in 4:
		if shell.top() == null and gs().modal() == null:
			return
		print("[w3int] queda abierto: ", shell.top_kind(), " modal=", gs().modal() != null)
		await _rclick(Vector2(800, 450))
		await _wait(0.5)

func _sleep_and_dawn(tag: String) -> void:
	var day0 := int(g.sim.q_clock().day)
	await _idle()
	await _clear_top()
	await _click_ctrl(gs().hud.card)
	await tool.frames(14)
	var m = gs().modal()
	_check(m != null, "%s: el calendario pide confirmación para dormir" % tag)
	await _snap(tag + "_dormir")
	if m != null:
		await _click(_c(_button(m, Widgets.t("shell.cal.dormir"), true)))
	# el ritual del amanecer: capturas en medio
	await _wait(0.7)
	await _snap(tag + "_amanecer_a")
	await _wait(1.2)
	await _snap(tag + "_amanecer_b")
	await _until(func(): return int(g.sim.q_clock().day) > day0 and String(g.sim.q_clock().phase) == "desk", 1500)
	await _idle()
	await tool.frames(30)
	_check(int(g.sim.q_clock().day) == day0 + 1, "%s: amanece el día %d" % [tag, day0 + 1])
	await _snap(tag + "_bandeja")

func _day1_tray() -> void:
	_check(shell.is_open("tray"), "día 1: la bandeja abierta al amanecer")
	var rows: Array = gs().tray.list.get_children() if gs().tray.visible else []
	print("[w3int] bandeja: ", g.sim.q_tray(int(g.sim.q_clock().day)).map(func(it): return String(it.view)))
	if rows.is_empty():
		_check(false, "papeles en la bandeja")
		return
	await _click(_c(rows[0]))
	await tool.frames(24)
	_check(shell.reader_open(), "clic en un papel -> lector")
	await _snap("dia1_lector")
	var v: Dictionary = shell.reader.view
	var tid := _first_tramo(v)
	print("[w3int] recortar en %s: %s" % [String(v.get("view", "")), tid])
	clips["dia1"] = await _clip_tramo(tid, "dia1_tijera")
	await _close_reader()
	_check(gs().tray.visible, "al cerrar el lector se vuelve a la bandeja")
	await _close_tray()

func _day1_books() -> void:
	await _click_ribbon("notebook")
	await tool.frames(20)
	var nb = shell.panel("notebook")
	_check(nb != null and _card(nb, clips.get("dia1", "")) != null, "el recorte del día en el cuaderno")
	await _snap("dia1_cuaderno")
	# Índice
	await _click_named(nb, "Tab_indice")
	await tool.frames(12)
	await _snap("dia1_indice")
	await _click_named(nb, "Tab_recortes")
	await tool.frames(8)
	# el recorte del día sobre la cinta «Libro mayor» del canto del cuaderno: folio nuevo, los dos libros abiertos
	var card = _card(nb, clips.get("dia1", ""))
	var rib = _find(nb, "CintaLibroMayor")
	_check(rib != null and rib.is_visible_in_tree(), "cinta «Libro mayor» en el canto del cuaderno")
	var nfo0: int = g.sim.q_ledger().get("folios", []).size()
	if card != null and rib != null:
		await _scroll_into_view(card)
		await _drag(_c(card), _c(rib))
		await _wait(0.5)
	_check(g.sim.q_ledger().get("folios", []).size() == nfo0 + 1 and shell.is_open("ledger") and shell.is_open("notebook"), "recorte sobre la cinta -> folio nuevo, dos libros")
	await _snap("dia1_dos_libros")
	await _rclick(Vector2(1200, 450))
	await tool.frames(16)
	_check(not shell.is_open("ledger") and shell.is_open("notebook"), "clic derecho sobre el libro mayor lo cierra; queda el cuaderno")
	await _click_named(nb, "Volver")
	await tool.frames(12)
	await _click_ribbon("ledger")
	await tool.frames(20)
	await _snap("dia1_libro")
	var ot = _find(shell.panel("ledger"), "Pestana_cuaderno")
	_check(ot != null and ot.is_visible_in_tree(), "pestaña «Cuaderno» en el libro mayor")
	await _click_ctrl(ot)
	await tool.frames(20)
	_check(shell.is_open("notebook") and shell.is_open("ledger"), "pestaña «Cuaderno»: los dos libros")
	await _snap("dia1_dos_libros_b")
	await _key(KEY_ESCAPE)
	await tool.frames(12)
	await _rclick(Vector2(800, 450))
	await tool.frames(16)
	_check(shell.top() == null, "libros cerrados; nada abierto")

func _day1_map() -> void:
	# el mapa de la pared: a la vista con los chevrones; si no, la tecla M
	var mp := Vector2(-1, -1)
	for i in 4:
		mp = _node_pos("mapa")
		if mp.x >= 0.0 and String(shell.world.pick(mp).get("id", "")) == "mapa":
			break
		mp = Vector2(-1, -1)
		await _click(_c(gs()._chev_r))
		await _wait(0.9)
		await _snap("dia1_encuadre_" + String(gs().frame))
	await _snap("dia1_pared")
	if mp.x >= 0.0:
		await _click(mp)
	else:
		_check(false, "el mapa de la pared a la vista")
		await _key(KEY_M)
	await tool.frames(30)
	var ms = shell.panel("map")
	_check(ms != null and ms.visible, "clic en el mapa de la pared -> mapa")
	await _snap("dia1_mapa")
	if ms == null:
		return
	var mk = ms.marker("L4")
	await _click(mk.get_global_rect().position + mk.get_meta("origin", Vector2(12, 12)))
	await tool.frames(12)
	if ms._popup != null and is_instance_valid(ms._popup) and _button(ms._popup, Widgets.t("shell.map.ir"), true) == null:
		await _snap("dia1_areas")
		var b := _first_enabled_button(ms._popup)
		if b != null:
			await _click(_c(b))
			await tool.frames(12)
	var ir := _button(ms._popup, Widgets.t("shell.map.ir"), true) if ms._popup != null and is_instance_valid(ms._popup) else null
	_check(ir != null, "Kensington: confirmación con «Ir»")
	await _snap("dia1_ir")
	if ir != null:
		await _click(_c(ir))
		await tool.frames(30)
		await _snap("dia1_viaje")
	await _until(func(): return String(g.sim.q_clock().phase) == "visit", 900)
	await _idle()
	await tool.frames(40)
	_check(gs().cur_place == "L4", "visita a Kensington")
	await _snap("dia1_visita")

func _day1_visit() -> void:
	var wp: Vector2 = gs().char_screen_pos("watson")
	_check(wp.x >= 0.0, "Watson a la vista %s" % str(wp))
	if wp.x < 0.0:
		return
	await _click(wp)
	await tool.frames(20)
	var sp = shell.panel("scene")
	_check(sp != null and shell.is_open("scene"), "clic en Watson -> panel de escena")
	if sp == null:
		return
	await _snap("dia1_watson")
	var ap = sp.ask_panel
	if not ap.visible:
		await _click_ctrl(_find(sp, "Verbo_ask"))
		await tool.frames(10)
	_check(ap.visible, "«Preguntar» abierto")
	await _snap("dia1_preguntar")
	if ap.visible and ap._list.item_count > 0:
		var r: Rect2 = ap._list.get_item_rect(0)
		var p: Vector2 = ap._list.get_global_transform_with_canvas() * r.get_center()
		await _click(p)
		await tool.frames(8)
		await _snap("dia1_frase")
		var n0: int = (g.sim.q_scene().get("lines", []) as Array).size()
		await _click(_c(ap._ok))
		await tool.frames(30)
		_check((g.sim.q_scene().get("lines", []) as Array).size() > n0, "pregunta hecha: Watson contesta")
		await _snap("dia1_respuesta")
	else:
		_check(false, "temas para preguntar")
	# presentar: arrastrar una tarjeta del cuaderno sobre Watson
	await _click_ribbon("notebook")
	await tool.frames(24)
	var nb = shell.panel("notebook")
	var card = _card(nb, clips.get("aviso", "")) if nb != null else null
	if card == null and nb != null:
		card = _card(nb, clips.get("dia1", ""))
	if card != null:
		await _scroll_into_view(card)
	wp = gs().char_screen_pos("watson")
	await _snap("dia1_cuaderno_visita")
	_check(card != null and wp.x >= 0.0, "tarjeta y Watson a la vista para presentar")
	if card != null and wp.x >= 0.0:
		await _drag(_c(card), wp)
		await tool.frames(16)
		var pb = sp.present_bar
		_check(pb != null and pb.visible, "soltar sobre Watson -> «Presentar» con la frase")
		await _snap("dia1_presentar")
		if pb != null and pb.visible:
			var n1: int = g.sim.actions_log().size()
			await _click(_c(_button(pb, Widgets.t("sceneui.present.ok"))))
			await tool.frames(30)
			_check(g.sim.actions_log().size() > n1, "«Mostrar»: presentado")
			await _snap("dia1_presentado")
	# con el cuaderno abierto a la izquierda, «Preguntar» se abre a la derecha (no tapa el cuaderno)
	if shell.is_open("notebook"):
		await _click_ctrl(_find(sp, "Verbo_ask"))
		await tool.frames(12)
		var nbr: Rect2 = shell.panel("notebook").book_rect()
		_check(sp.ask_panel.visible and not sp.ask_panel.get_global_rect().intersects(nbr), "con el cuaderno abierto, «Preguntar» va a la derecha")
		await _snap("dia1_preguntar_con_cuaderno")
		await _click(_c(_button(sp.ask_panel, Widgets.t("sceneui.back"))))
		await tool.frames(10)
		await _click_named(shell.panel("notebook"), "Volver")
		await tool.frames(12)
	# salir de la visita: «Salir» del panel -> confirmación
	var sal := _button(sp, Widgets.t("sceneui.leave"), true)
	_check(sal != null, "«Salir» en el panel de escena")
	await _snap("dia1_antes_de_salir")
	if sal != null:
		await _click(_c(sal))
		await tool.frames(12)
		await _snap("dia1_salir")
		var ok := _button(tool.root, Widgets.t("sceneui.leave.ok"), true)
		if ok != null and ok != sal:
			await _click(_c(ok))
	else:
		await _click_ctrl(gs().hud.card)
		await tool.frames(12)
		if gs().modal() != null:
			await _click(_c(_button(gs().modal(), Widgets.t("shell.leave.ok"), true)))
	await _until(func(): return String(g.sim.q_clock().phase) != "visit", 600)
	await _idle()
	await tool.frames(30)
	_check(String(g.sim.q_clock().phase) == "desk" and gs().mode == "hub", "de vuelta en casa")
	await _snap("dia1_casa")

func _close_slots_until_night() -> void:
	for i in 4:
		var c: Dictionary = g.sim.q_clock()
		if String(c.phase) != "desk":
			break
		await _click_ctrl(gs().hud.card)
		await tool.frames(12)
		var m = gs().modal()
		if m == null:
			_check(false, "calendario: cerrar la franja pide confirmación")
			break
		if i == 0:
			await _snap("cerrar_franja_d%d" % int(c.day))
		var b := _first_enabled_button(m, true)
		await _click(_c(b))
		await _until(func(): return g.sim.q_clock() != c, 300)
		await _idle()
		await tool.frames(20)
	_check(String(g.sim.q_clock().phase) == "night", "la noche del día %d" % int(g.sim.q_clock().day))
	await _snap("noche_d%d" % int(g.sim.q_clock().day))

func _night_report() -> void:
	var st: Dictionary = g.sim.q_report_status()
	_check(bool(st.get("due", false)), "noche de informe")
	await _click_ctrl(gs().hud.card)
	await tool.frames(20)
	var rc = shell.top()
	_check(rc != null and shell.top_kind() == "report", "calendario -> el sobre del informe")
	if rc == null or shell.top_kind() != "report":
		return
	await _snap("informe")
	var ch := _button(rc, Widgets.t("sceneui.rep.choose"))
	if ch != null:
		await _click(_c(ch))
		await tool.frames(14)
		await _snap("informe_elegir")
		var pk = rc.picker
		var cards: Array = pk.cards() if pk != null and pk.visible else []
		if not cards.is_empty():
			await _click(_c(cards[0].node))
			await tool.frames(12)
	_check(rc.items.size() >= 1, "un recorte en el sobre (%d)" % rc.items.size())
	await _snap("informe_lleno")
	var send := _button(rc, Widgets.t("sceneui.rep.send"), true)
	if send != null:
		await _click(_c(send))
		await tool.frames(12)
		await _snap("informe_confirma")
		var cf = _find(rc, "Confirmacion")
		if cf != null and "ok_button" in cf:
			await _click(_c(cf.ok_button))
			await _wait(0.3)
			await _snap("informe_entregado")
			await _wait(0.9)
	_check(not bool(g.sim.q_report_status().get("due", false)), "informe entregado")
	_check(shell.top_kind() != "report", "el sobre se cierra solo tras el sello")
	await _clear_top()

# ================================================================== piezas de UI
# Clic en un objeto del 3D -> tarjeta de examen -> enlace «Leer …» (el primero cuyo texto contenga hint) -> lector.
func _read_from_node(node: String, hint: String) -> void:
	await _idle()
	var ok := await _click_3d(node)
	await tool.frames(16)
	_check(ok and gs().exam.visible, "clic en «%s» -> tarjeta de examen" % node)
	await _snap("examen_" + node)
	var links: Array = gs().exam.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
	print("[w3int] enlaces de %s: %s" % [node, str(links.map(func(b): return b.text))])
	var target: Button = null
	for b in links:
		if target == null:
			target = b
	for b in links:
		if String(b.text).to_lower().contains(hint.to_lower()):
			target = b
	if target != null:
		await _scroll_into_view(target)
		await tool.frames(4)
		await _snap("examen_" + node + "_enlace")
		await _click(_c(target))
		await tool.frames(24)
	_check(shell.reader_open(), "enlace -> lector (%s)" % (String(shell.reader.view.get("view", "")) if shell.reader_open() else "-"))

# Recorta el tramo tid de la vista abierta en el lector: hoja (botones de hoja), tijera (botón), arrastre real.
func _clip_tramo(tid: String, shot: String) -> String:
	if not shell.reader_open() or tid == "":
		return ""
	var r = shell.reader
	var v: Dictionary = r.view
	var where := _find_tramo(v, tid)
	if where.is_empty():
		_check(false, "tramo #%s en %s" % [tid, String(v.get("view", ""))])
		return ""
	# hoja
	var guard := 0
	while int(r.page_idx) != int(where.part) and guard < 12:
		var b: Button = r._b_next if int(r.page_idx) < int(where.part) else r._b_prev
		await _click(_c(b))
		await tool.frames(8)
		guard += 1
	_check(int(r.page_idx) == int(where.part), "hoja %d de %s" % [int(where.part), String(v.get("view", ""))])
	if not r.tijera:
		await _click(_c(r._b_tijera))
		await tool.frames(6)
	_check(r.tijera, "botón «Tijera» del lector")
	var rtl: RichTextLabel = r.block_rtl(int(where.block))
	if rtl == null:
		_check(false, "bloque %d" % int(where.block))
		return ""
	# a la vista: arrastrar el papel con el botón del medio hasta que el tramo quede dentro del área de lectura
	var pts: Array = SelectionMapper.drag_points(rtl, int(where.from), int(where.to))
	var area: Rect2 = r._read_rect() if r.has_method("_read_rect") else Rect2(Vector2(0, 0), Vector2(1600, 900))
	for _i in 6:
		pts = SelectionMapper.drag_points(rtl, int(where.from), int(where.to))
		var lo: float = minf(pts[0].y, pts[1].y)
		var hi: float = maxf(pts[0].y, pts[1].y)
		var dy := 0.0
		if hi > area.end.y - 40.0:
			dy = -minf(hi - (area.end.y - 120.0), 500.0)
		elif lo < area.position.y + 40.0:
			dy = minf((area.position.y + 120.0) - lo, 500.0)
		if dy == 0.0:
			break
		await _pan(area.get_center(), Vector2(0, dy))
	# primero desde el comienzo exacto del tramo; si la métrica falla (versalitas delante: los encabezados del Times
	# corren SelectionMapper.char_local_pos a la izquierda), otra vez unas letras adentro
	var id := ""
	var span := int(where.to) - int(where.from)
	for a0 in [int(where.from), int(where.from) + mini(3, span / 4), int(where.from) + mini(6, span / 3), int(where.from) + mini(10, span / 3)]:
		id = await _drag_select(rtl, a0, int(where.to), shot)
		if id != "":
			break
		shot = ""
	_check(id != "", "tijera sobre #%s -> recorte %s «%s»" % [tid, id, String(g.sim.q_clip(id).get("text", "")).left(48) if id != "" else ""])
	return id

func _drag_select(rtl: RichTextLabel, from: int, to: int, shot: String) -> String:
	var pts: Array = SelectionMapper.drag_points(rtl, from, to)
	var n0: int = g.sim.q_clips().size()
	_mm(pts[0])
	await tool.frames(2)
	await _sync_mouse(pts[0])
	_btn(pts[0], true)
	await tool.frames(2)
	for i in range(1, 13):
		_mm(pts[0].lerp(pts[1], float(i) / 12.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	await _sync_mouse(pts[1], MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(3)
	if shot != "":
		await _snap(shot)
	_btn(pts[1], false)
	await tool.frames(12)
	var cl: Array = g.sim.q_clips()
	return String(cl[-1].get("id", "")) if cl.size() > n0 else ""

func _respaldo_clip(name: String, view: String) -> void:
	if String(clips.get(name, "")) != "":
		return
	var v: Dictionary = g.sim.q_view(view)
	var w := _find_tramo(v, name)
	if w.is_empty():
		return
	var r := _respaldo("clip " + name, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": int(w.part), "block": int(w.block)}, "from": int(w.from), "len": int(w.to) - int(w.from)})
	clips[name] = String(r.get("clip", ""))

func _close_reader() -> void:
	for _i in 3:
		if not shell.reader_open():
			break
		await _rclick(Vector2(800, 450))
		await tool.frames(14)
	_check(not shell.reader_open(), "clic derecho: deja la tijera y cierra el lector")

func _close_tray() -> void:
	if gs().tray.visible:
		await _click(_c(_button(gs().tray, Widgets.t("kit.close"))))
		await tool.frames(14)
	_check(not gs().tray.visible, "«Cerrar» la bandeja")

func _click_ribbon(kind: String) -> void:
	var rb: Control = gs().hud.ribbon(kind)
	_check(rb != null and rb.is_visible_in_tree(), "cinta «%s» a la vista" % kind)
	await _click_ctrl(rb)
	await tool.frames(8)

# Campo de plantilla: clic en el blanco -> elector -> fila.
func _ledger_field(lg, e: String, line: int, field: String, value: String) -> void:
	var row = _find(lg, "Linea%d" % line)
	var f = _find(row if row != null else lg, "Campo_" + field)
	var b = f.get_node_or_null("Valor") if f != null else null
	if b != null:
		await _click_ctrl(b)
		await tool.frames(10)
		if lg.picker() != null:
			var rr: Rect2 = lg.picker().row_rect(value)
			if rr.size.x > 0.0:
				await _click(rr.get_center())
			else:
				print("[w3int] %s sin opción %s; opciones=%s" % [field, value, str(lg.picker().get("ids") if "ids" in lg.picker() else "")])
				await _rclick(Vector2(800, 450))
			await tool.frames(10)
	var got := String(g.sim.q_entry(e).lines[line].fields.get(field, ""))
	_check(got == value, "campo «%s» por clic: %s" % [field, got])
	if got != value:
		_respaldo("entry_set " + field, {"t": "entry_set", "entry": e, "line": line, "field": field, "value": value})
		await tool.frames(6)

func _ledger_support(lg, e: String, line: int, clip: String) -> void:
	var row = _find(lg, "Linea%d" % line)
	var add = _find(row, "Anadir") if row != null else null
	if add != null:
		await _click_ctrl(add)
		await tool.frames(10)
		if lg.picker() != null:
			var rr: Rect2 = lg.picker().row_rect(clip)
			if rr.size.x > 0.0:
				await _click(rr.get_center())
			else:
				await _rclick(Vector2(800, 450))
			await tool.frames(10)
	var ok: bool = (g.sim.q_entry(e).lines[line].support as Array).has(clip)
	_check(ok, "«según» de la línea %d por clic" % line)
	if not ok:
		_respaldo("support %d" % line, {"t": "entry_support_add", "entry": e, "line": line, "item": clip})
		await tool.frames(6)

# Un hueco (Button con PopupMenu): clic abre el menú; se recorre con el mouse hasta enfocar la opción y clic.
func _choose_popup(bl: Button, want_id: String) -> void:
	await _click(_c(bl))
	await tool.frames(8)
	var pm: PopupMenu = bl._popup if "_popup" in bl else null
	if pm == null or not pm.visible:
		_check(false, "menú del hueco abierto")
		return
	var oi := 0
	if want_id != "":
		for i in bl.options.size():
			if String(bl.options[i].get("id", "")) == want_id:
				oi = i
	var idx := pm.get_item_index(oi)   # el id de cada ítem es el índice de la opción (puede haber «dejar en blanco» antes)
	var r := Rect2(Vector2(pm.position), Vector2(pm.size))
	print("[w3int] menú: rect=%s ítems=%d idx=%d" % [r, pm.item_count, idx])
	var hit := false
	for k in range(2, int(r.size.y) - 2, 4):
		var p := Vector2(r.position.x + r.size.x * 0.5, r.position.y + k)
		_mm(p)
		await tool.frames(2)
		if pm.get_focused_item() == idx:
			await tool.frames(2)
			_btn(p, true)
			await tool.frames(1)
			_btn(p, false)
			hit = true
			break
	if not hit and pm.visible:
		# el foco por hover no se reporta: clic en el centro estimado del renglón (sin separadores: alto parejo)
		var p2 := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * (float(idx) + 0.5) / float(maxi(1, pm.item_count)))
		_mm(p2)
		await tool.frames(3)
		_btn(p2, true)
		await tool.frames(1)
		_btn(p2, false)
		await tool.frames(4)
		hit = want_id == "" or String(bl.value) == want_id
	await tool.frames(8)
	_check(hit, "opción %d del menú por clic (%s) -> %s" % [idx, want_id, String(bl.value)])

# Índice del paso del tutorial (99 = completo).
func _tut_index() -> int:
	var t: Dictionary = g.sim.q_tutorial()
	if bool(t.get("complete", false)):
		return 99
	var s = t.get("step", {})
	return int(s.get("index", 0)) if typeof(s) == TYPE_DICTIONARY and not s.is_empty() else 99

func _first_tramo(v: Dictionary) -> String:
	for pi in (v.get("pages", []) as Array).size():
		for blk in v.pages[pi]:
			for tr in blk.get("parsed", {}).get("tramos", []):
				return String(tr.id)
	return ""

func _find_tramo(v: Dictionary, tid: String) -> Dictionary:
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					return {"part": pi, "block": bi, "from": int(tr.from), "to": int(tr.to)}
	return {}

func _card(nb, id: String):
	if nb == null or id == "":
		return null
	var pg = nb.page("recortes")
	return pg.card(id) if pg != null and pg.has_method("card") else null

func _link_button(card: Node, text: String) -> Button:
	return _button(card, text, false, true)

# ================================================================== mouse
func _click_3d(id: String) -> bool:
	var p := _node_pos(id)
	if p.x < 0.0 or String(shell.world.pick(p).get("id", "")) != id:
		print("[w3int] «%s» no está a la vista (pick=%s)" % [id, str(shell.world.pick(p)) if p.x >= 0 else "-"])
		return false
	await _click(p)
	return true

func _node_pos(id: String) -> Vector2:
	var b: Node3D = shell.world.node_body(id)
	var cam: Camera3D = shell.world.camera()
	if b == null or cam == null or cam.is_position_behind(b.global_position):
		return Vector2(-1, -1)
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 160, 6):
		for k in 16:
			var p := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if String(shell.world.pick(p).get("id", "")) == id:
				return p
			if r == 0:
				break
	return c

func _c(c) -> Vector2:
	return (c as Control).get_global_rect().get_center() if c is Control and is_instance_valid(c) else Vector2(-1, -1)

# Rueda del mouse sobre el desplazable que contiene a c hasta que c quede entero a la vista.
func _scroll_into_view(c: Control) -> void:
	var sc: Node = c.get_parent()
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc == null:
		return
	var box := (sc as Control).get_global_rect()
	for _i in 60:
		var r := c.get_global_rect()
		if r.position.y >= box.position.y - 0.5 and r.end.y <= box.end.y + 0.5:
			return
		var down := r.end.y > box.end.y
		var at := box.get_center()
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
		await tool.frames(2)
	print("[w3int] no se pudo desplazar hasta ", c.text if c is Button else c.name)

func _click_ctrl(c) -> void:
	if not (c is Control) or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
		_check(false, "control para el clic (%s)" % (str(c.name) if c is Node and is_instance_valid(c) else "nulo"))
		return
	await _click(_c(c))

func _click_named(root: Node, nm: String) -> void:
	await _click_ctrl(_find(root, nm))

func _button(root: Node, text: String, last := false, prefix := false) -> Button:
	if root == null or not is_instance_valid(root):
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

func _first_enabled_button(root: Node, last := false) -> Button:
	var hit: Button = null
	for b in root.find_children("*", "Button", true, false):
		var bt := b as Button
		if bt.is_visible_in_tree() and not bt.disabled:
			hit = bt
			if not last:
				return hit
	return hit

func _find(n: Node, nm: String) -> Node:
	if n == null or not is_instance_valid(n):
		return null
	return n.find_child(nm, true, false)

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
	print("[w3int] ventana ", DisplayServer.window_get_size(), " foco=", DisplayServer.window_is_focused())

func _sync_mouse(pos: Vector2, mask := 0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		_mm(pos, mask)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(pos) < 1.5:
			return
	print("[w3int] aviso: el cursor no llegó a %s (está en %s)" % [pos, vp.get_mouse_position()])

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
	var m := MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else (MOUSE_BUTTON_MASK_RIGHT if idx == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_MIDDLE)
	ev.button_mask = m if pressed else 0
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	if p.x < 0.0:
		print("[w3int] clic sin destino")
		return
	_mm(p)
	await tool.frames(2)
	await _sync_mouse(p)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(4)

func _rclick(p: Vector2) -> void:
	_mm(p)
	await tool.frames(2)
	_btn(p, true, MOUSE_BUTTON_RIGHT)
	await tool.frames(1)
	_btn(p, false, MOUSE_BUTTON_RIGHT)
	await tool.frames(4)

func _drag(a: Vector2, b: Vector2) -> void:
	_mm(a)
	await tool.frames(2)
	await _sync_mouse(a)
	_btn(a, true)
	await tool.frames(2)
	for k in range(1, 21):
		_mm(a.lerp(b, float(k) / 20.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	await _sync_mouse(b, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(3)
	_btn(b, false)
	await tool.frames(8)

func _pan(at: Vector2, d: Vector2) -> void:
	_mm(at)
	await tool.frames(2)
	_btn(at, true, MOUSE_BUTTON_MIDDLE)
	await tool.frames(1)
	for k in range(1, 9):
		_mm(at + d * float(k) / 8.0, MOUSE_BUTTON_MASK_MIDDLE)
		await tool.frames(1)
	_btn(at + d, false, MOUSE_BUTTON_MIDDLE)
	await tool.frames(4)

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await tool.frames(2)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await tool.frames(4)

func _wait(sec: float) -> void:
	await tool.create_timer(sec).timeout
	await tool.frames(2)

func _idle(max_frames := 1500) -> void:
	await tool.frames(3)
	await _until(func(): return gs() != null and gs().idle(), max_frames)

func _until(f: Callable, max_frames: int) -> void:
	var i := 0
	while not f.call() and i < max_frames:
		await tool.frames(1)
		i += 1
	if i >= max_frames:
		print("[w3int] timeout")

# ================================================================== registro
func _snap(name: String) -> void:
	_shot += 1
	await tool.snap("%02d_%s" % [_shot, name])

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("W3INT %s %s" % ["OK" if c else "FALLA", what])

func _respaldo(what: String, a: Dictionary) -> Dictionary:
	fallbacks += 1
	var r: Dictionary = g.act(a)
	print("W3INT RESPALDO %s -> %s" % [what, "ok" if bool(r.get("ok", false)) else str(r.get("err", ""))])
	return r

func _summary() -> void:
	print("W3INT RESUMEN %d fallas, %d respaldos, %d capturas" % [fails, fallbacks, _shot])
