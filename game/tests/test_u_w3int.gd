# Tests del integrador de UI (W3-INT): lo que une los paquetes de UI dentro de la Shell real (autoload Game, dataset
# «fixture» de tests/fixtures/w3shell/walk.gd). Headless.
#   · dos libros con el mouse: cinta «Libro mayor» en el canto del cuaderno, pestaña «Cuaderno» en el libro mayor
#   · soltar un recorte sobre la cinta del libro mayor (HUD, libro cerrado) o sobre la del cuaderno -> folio nuevo
#   · el HUD (calendario, monedas, cintas) se desvanece cuando lo tapa el cuaderno acoplado; vuelve al cerrarlo
#   · en una visita con el cuaderno abierto, «Preguntar» se acopla a la derecha (no tapa el cuaderno)
#   · tarjeta de examen con muchos enlaces: lista de alto acotado, dentro de la pantalla
#   · Shell.subs_rect() (vacío con --mute) y el libro mayor lo usa; sin comillas dobles en el elector de recortes
# Recorrido con el mouse real y capturas: devtools/drivers/w3int_flow.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 150
const Shell = preload("res://ui/shell.gd")
const Layers = preload("res://ui/layers.gd")
const Chips = preload("res://ui/drag/chips.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const ExamineCard = preload("res://ui/desk/examine_card.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")

var sh = null
var g = null
var old_size := Vector2i.ZERO

func before_each() -> void:
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)
	g = tree.root.get_node("Game")
	W.errs = []

func after_each() -> void:
	if g != null and g.sim != null:
		g.end_session()
	if sh != null and is_instance_valid(sh):
		sh.free()
	sh = null
	if g != null:
		g.repo_override = null
		g.save_path = g.SAVE_PATH
	if tree.root.gui_is_dragging():
		tree.root.gui_cancel_drag()
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

# ------------------------------------------------------------------ utilidades
func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

func settle(max_frames := 900) -> void:
	for i in max_frames:
		await tree.process_frame
		if i < 3:
			continue
		var gs = sh.game_screen if sh != null else null
		if sh != null and not sh.is_busy() and (gs == null or gs.idle()):
			return
	fail("la Shell no quedó quieta")

func act(a: Dictionary) -> Dictionary:
	return g.act(a)

# Partida del fixture en el escritorio del martes (tutorial hecho, dormido, bandeja cerrada). Devuelve los recortes.
func boot_desk() -> Dictionary:
	g.repo_override = W.repo()
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(1)
	await sh.boot({"new": true, "seed": 1894, "fast": true, "mute": true, "save": tmp_dir().path_join("partida.jsonl")})
	await settle()
	var t: Dictionary = W.tutorial(g.sim, act)
	eq(W.errs, [], "tutorial")
	ok(bool(act({"t": "sleep"}).get("ok", false)), "dormir")
	await settle()
	sh.close_all()
	await frames(2)
	eq(String(g.sim.q_clock().phase), "desk")
	return t

func click(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = c.size * 0.5
	var u := e.duplicate()
	u.pressed = false
	for ev in [e, u]:
		c.gui_input.emit(ev)              # cintas: gui_input conectado
		if c.has_method("_gui_input"):
			c._gui_input(ev)              # pestañas del libro mayor: _gui_input propio (suelta = clic)

func motion(p: Vector2) -> void:
	Input.warp_mouse(p)
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func release(p: Vector2) -> void:
	Input.warp_mouse(p)
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()

# Arrastre nativo de un recorte hasta el centro de target (DnD de Godot con eventos de Input, como el mouse real).
func drag_clip_to(clip: String, target: Control) -> void:
	var src := Control.new()
	src.size = Vector2(30, 20)
	Layers.root_of(sh.layers.hud).add_child(src)
	var data := Chips.data("clip", clip)
	src.force_drag(data, Widgets.chip("«x»", data))
	await frames(2)
	var p := target.get_global_rect().get_center()
	motion(p)
	await frames(2)
	release(p)
	await frames(4)
	src.queue_free()

func folios() -> int:
	return (g.sim.q_ledger().get("folios", []) as Array).size()

# ------------------------------------------------------------------ tests
func test_two_books_by_mouse() -> void:
	await boot_desk()
	var gs = sh.game_screen
	click(gs.hud.ribbon("notebook"))
	await frames(4)
	var nb = sh.panel("notebook")
	ok(sh.is_open("notebook"), "cinta «Cuaderno»")
	var rb: Control = nb.find_child("CintaLibroMayor", true, false)
	ok(rb != null and rb.visible, "el cuaderno muestra la cinta del libro mayor en su canto")
	if rb != null:
		ok(rb.get_global_rect().position.x >= nb.book_rect().end.x - 4.0, "la cinta asoma por el canto derecho")
		click(rb)
		await frames(4)
	ok(sh.is_open("ledger") and sh.is_open("notebook"), "clic en la cinta: los dos libros")
	eq(String(nb.layout), "left", "el cuaderno a la izquierda")
	ok(sh.panel("ledger").side, "el libro mayor a la derecha")
	no(rb.visible, "con el libro abierto la cinta se va")
	ok(sh.panel("ledger").find_child("Pestana_cuaderno", true, false) == null, "con el cuaderno abierto el libro no ofrece su pestaña")
	ok(sh.stack.size() <= 2, "nunca más de dos paneles")
	# se cierra el cuaderno: el libro ofrece la pestaña «Cuaderno»
	sh.close_kind("notebook")
	await frames(4)
	var tab: Control = sh.panel("ledger").find_child("Pestana_cuaderno", true, false)
	ok(tab != null and tab.is_visible_in_tree(), "pestaña «Cuaderno» en el libro mayor")
	if tab != null:
		click(tab)
		await frames(4)
	ok(sh.is_open("notebook") and sh.is_open("ledger"), "la pestaña abre el cuaderno al lado")

func test_hud_covered_by_docked_notebook() -> void:
	await boot_desk()
	var gs = sh.game_screen
	await frames(3)
	no(gs.hud.covered, "escritorio sin paneles: el HUD a la vista")
	sh.open_panel("notebook")
	await frames(3)
	no(gs.hud.covered, "cuaderno centrado (con velo): el HUD queda a su lado")
	sh.open_panel("ledger")
	await frames(4)
	eq(String(sh.panel("notebook").layout), "left")
	ok(gs.hud.covered, "cuaderno acoplado a la izquierda: el HUD se desvanece")
	eq(gs.hud.card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "y no come el mouse")
	sh.close_all()
	await frames(4)
	no(gs.hud.covered, "al cerrar los libros vuelve")
	eq(gs.hud.card.mouse_filter, Control.MOUSE_FILTER_STOP)

func test_drop_clip_on_ledger_ribbons() -> void:
	var t: Dictionary = await boot_desk()
	var gs = sh.game_screen
	var n0 := folios()
	await drag_clip_to(String(t.aviso), gs.hud.ribbon("ledger"))
	ok(sh.is_open("ledger"), "soltar sobre la cinta del HUD abre el libro mayor")
	eq(folios(), n0 + 1, "con un folio nuevo")
	var fo: Dictionary = (g.sim.q_ledger().folios as Array)[-1]
	eq(String(fo.head_clip), String(t.aviso), "encabezado por el recorte soltado")
	eq(String(sh.panel("ledger").page), String(fo.id), "el libro se abre en ese folio")
	sh.close_all()
	await frames(4)
	# la cinta del canto del cuaderno
	sh.open_panel("notebook")
	await frames(4)
	var rb: Control = sh.panel("notebook").find_child("CintaLibroMayor", true, false)
	ok(rb != null and rb.visible)
	var c2 := String(g.sim.q_clips()[-1].id)
	for c in g.sim.q_clips():
		var used := false
		for f in g.sim.q_ledger().folios:
			if String(f.head_clip) == String(c.id):
				used = true
		if not used:
			c2 = String(c.id)
	await drag_clip_to(c2, rb)
	ok(sh.is_open("ledger") and sh.is_open("notebook"), "soltar sobre la cinta del cuaderno: los dos libros")
	eq(folios(), n0 + 2, "otro folio")

func test_ask_docks_right_with_notebook() -> void:
	await boot_desk()
	var gs = sh.game_screen
	var ms = sh.open_panel("map")
	await frames(2)
	var consulta := {}
	for a in ms.place_state("L4").areas:
		if String(a.area) == "consulta":
			consulta = a
	ok(not consulta.is_empty(), "Kensington, consulta")
	var r: Dictionary = await ms.travel("L4", "consulta")
	ok(bool(r.get("ok", false)), "viaje: %s" % str(r.get("err", "")))
	await settle()
	eq(String(g.sim.q_clock().phase), "visit")
	ok(sh.is_open("scene"), "panel de escena")
	sh.open_panel("notebook")
	await frames(4)
	var nb = sh.panel("notebook")
	eq(String(nb.layout), "left", "en la visita el cuaderno va a la izquierda")
	var sp = sh.panel("scene")
	sp.open_ask("watson", "ask")
	await frames(4)
	ok(sp.ask_panel.visible, "«Preguntar» abierto")
	no(sp.dock_left, "con el cuaderno abierto se acopla a la derecha")
	no(sp.ask_panel.get_global_rect().intersects(nb.book_rect()), "no tapa el cuaderno")
	ok(gs.hud.covered, "el cuaderno acoplado tapa la esquina del HUD")

func test_examine_card_long_list() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	tree.root.add_child(host)
	var card = ExamineCard.new()
	host.add_child(card)
	await frames(1)
	var links: Array = []
	for i in 25:
		links.append({"text": "Leer: Título número %d, The Strand Magazine" % i, "short": "Título número %d" % i, "cb": Callable()})
	card.show_card("Tomos", {"plain": "Cinco tomos.", "styles": [], "tramos": [], "mentions": []}, links, {}, "tomos", "Para leer")
	await frames(3)
	ok(card.links_scroll.visible and not card.links_box.visible, "muchos enlaces: lista desplazable")
	ok(card.links_scroll.size.y <= ExamineCard.LIST_MAX_H + 1.0, "lista de alto acotado (%s)" % card.links_scroll.size.y)
	var r: Rect2 = card.get_global_rect()
	ok(r.position.y >= 0.0 and r.end.y <= 900.0, "la tarjeta entra en la pantalla: %s" % str(r))
	eq(card.links_head.text, "Para leer")
	eq((card.links_list.get_child(0) as Button).text, "Título número 0", "en la lista, el título sin «Leer:»")
	card.show_card("Encargo", {"plain": "Un pliego.", "styles": [], "tramos": [], "mentions": []}, [{"text": "Leer: Encargo", "cb": Callable()}], {}, "encargo", "Para leer")
	await frames(3)
	ok(card.links_box.visible and not card.links_scroll.visible, "pocos enlaces: en fila")
	no(card.links_head.visible, "sin encabezado de lista")
	host.free()

func test_subs_rect_and_quotes() -> void:
	await boot_desk()
	eq(sh.subs_rect(), Rect2(), "con --mute no hay subtítulos: zona vacía")
	sh.open_panel("ledger")
	await frames(3)
	eq(sh.panel("ledger").subs_reserve(), 0.0, "el libro mayor no reserva el pie sin subtítulos")
	sh.sounds = true
	var au = tree.root.get_node("Audio")
	var was: bool = au.subtitles_on
	au.subtitles_on = true
	var sr: Rect2 = sh.subs_rect()
	ok(sr.size.y > 40.0 and sr.end.y <= 900.5 and sr.end.x <= 1600.5, "zona de subtítulos abajo a la derecha: %s" % str(sr))
	eq(sh.panel("ledger").subs_reserve(), sr.size.y, "el libro mayor reserva lo que dice la Shell")
	au.subtitles_on = was
	sh.sounds = false
	# elector de recortes: un recorte que ya trae comillas no se envuelve otra vez
	var link = SimLink.new()
	link.sim_override = g.sim
	for c in g.sim.q_clips():
		var body := String(link.item_info({"kind": "clip", "id": String(c.id)}).body)
		no(body.contains("»»") or body.contains("««"), "sin comillas dobles: %s" % body)

func test_composer_sheet_frozen_under_stamp() -> void:
	var t: Dictionary = await boot_desk()
	for i in 20:
		var c: Dictionary = g.sim.q_clock()
		if String(c.phase) == "night" and bool(g.sim.q_report_status().get("due", false)):
			break
		ok(W.step(g.sim, act), "avanza: %s" % str(c))
	await settle()
	sh.close_all()
	ok(bool(g.sim.q_report_status().get("due", false)), "noche de informe")
	var rc = sh.open_panel("report")
	await frames(2)
	ok(rc.add_item({"kind": "clip", "id": String(t.aviso)}), "un recorte en el sobre")
	rc.refresh()
	var before := String(rc.final_rtl.get_parsed_text())
	ok(before != "", "texto final a la vista")
	var r: Dictionary = rc.confirm_send()
	ok(bool(r.get("ok", false)), "informe entregado")
	await frames(3)
	no(bool(g.sim.q_report_status().get("due", false)))
	eq(String(rc.final_rtl.get_parsed_text()), before, "bajo el sello, la hoja queda como se envió (no «n.º 0»)")
	ok(rc.send_button.disabled, "«Entregar» deshabilitado bajo el sello")
