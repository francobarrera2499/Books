# T31 (GDD_v2 §C, §F.3 DESPEJE-UI): revelado progresivo de la interfaz, vista por vista, con la partida REAL (Game +
# data/). Al empezar cada vista sólo muestra lo de «Al principio» (§C.3) y cada control aparece con su bandera de q_ui
# (§C.2), nunca antes. Sin pantalla: las vistas se arman headless (el driver con ventana y capturas es
# devtools/drivers/v2despeje_vistas.gd).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120
const Reader = preload("res://ui/reader/document_reader.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")
const Ledger = preload("res://ui/ledger/ledger.gd")
const ScenePanel = preload("res://ui/scene/scene_panel.gd")
const ItemPicker = preload("res://ui/scene/item_picker.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const AdComposer = preload("res://ui/compose/ad_composer.gd")
const Tray = preload("res://ui/desk/tray.gd")
const Catalog = preload("res://ui/desk/catalog.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

var g = null
var _prev_repo = null
var _prev_path := ""
var _nodes: Array = []

func before_each() -> void:
	tree.root.size = Vector2i(1600, 900)
	g = tree.root.get_node("Game")
	_prev_repo = g.repo_override
	_prev_path = g.save_path
	g.repo_override = repo()
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/tests/t31").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	g.save_path = dir.path_join("partida.jsonl")
	Reader.reset_read_memory()

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	if g != null:
		g.end_session()
		g.repo_override = _prev_repo
		g.save_path = _prev_path

func add(n: Node) -> Node:
	tree.root.add_child(n)
	_nodes.append(n)
	return n

func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

func act(a: Dictionary) -> Dictionary:
	var r: Dictionary = g.act(a)
	ok(bool(r.get("ok", false)), "%s -> %s" % [str(a).left(120), str(r)])
	return r

func clip_tramo(view: String, tid: String) -> String:
	var v: Dictionary = g.sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for t in v.pages[pi][bi].parsed.tramos:
				if String(t.id) == tid:
					var r: Dictionary = g.act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi},
						"from": int(t.from), "len": int(t.to) - int(t.from)})
					return String(r.get("clip", ""))
	return ""

# Prólogo mínimo (GDD_v2 §B.7: leer, recortar el aviso, el aviso, dormir) -> día 1, escritorio.
func to_day1() -> void:
	ok(g.new_session(7), "partida nueva")
	act({"t": "read", "view": "D23@L1", "part": 0})
	ok(clip_tramo("D23@L1", "aviso") != "", "recorte del aviso")
	var idx: Array = g.sim.q_index()
	var suceso := ""
	for o in g.sim.q_index():
		if String(o.id) == "suceso_reichenbach":
			suceso = "suceso_reichenbach"
	act({"t": "compose_ad", "form": "testigo", "fields": {"suceso": suceso if suceso != "" else String(idx[0].id)}})
	act({"t": "sleep"})
	eq(String(g.sim.q_clock().phase), "desk", "día 1, escritorio")

# Termina los turnos que queden y duerme (el calendario): el día siguiente al amanecer.
func next_day() -> void:
	var d0 := int(g.sim.q_clock().day)
	for i in 12:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) != d0:
			break
		var ph := String(c.phase)
		var r: Dictionary = g.act({"t": "sleep"})
		if not bool(r.get("ok", false)):
			r = g.act({"t": "end_slot"})
		if not bool(r.get("ok", false)) and ph == "visit":
			g.act({"t": "leave"})
	ok(int(g.sim.q_clock().day) == d0 + 1, "pasa al día siguiente (fase %s)" % String(g.sim.q_clock().phase))

func inject_clips(n: int) -> void:
	var people := ["watson", "holmes", "mycroft", "moran", "pell", "harris"]
	var places := ["londres", "suiza", "meiringen", "baker_street", "pall_mall", "reichenbach"]
	var months := ["1891-05-04", "1893-12-01", "1894-03-27"]
	var ents: Dictionary = g.sim.repo.entities()
	for i in n:
		var es: Array = []
		for e in [people[i % people.size()], places[i % places.size()]]:
			if ents.has(e):
				es.append(e)
		Clipper.inject(g.sim.st, g.sim.repo, {"text": "Recorte de prueba %d." % i, "ents": es, "origin": "T31.%d" % i,
			"chron_date": months[i % months.size()], "src_line": "prueba"})

# ------------------------------------------------------------------ lector
func test_reader_minimal_then_scissors_with_its_flag() -> void:
	ok(g.new_session(7), "partida nueva")
	var rd = add(Reader.new())
	rd.sounds = false
	# antes del paso «recortar»: sin tijera; un tomo con dos hojas trae las flechas
	ok(rd.open("D01.REDH@tomo"), "abre un tomo")
	await frames()
	no(bool(g.sim.q_ui().get("desk.tijera", true)), "prólogo, paso «leer»: la tijera todavía no")
	var t0: Array = rd.tool_names()
	no(t0.has("Tijera"), "sin «Tijera»: %s" % str(t0))
	no(t0.has("Zoom"), "sin indicador de zoom")
	ok(t0.has("Volver"), "«Volver»")
	for m in ["set_lupa", "set_regla"]:
		no(rd.has_method(m), "sin " + m)
	has(g.sim.q_read("D01.REDH@tomo"), 0, "el lector anotó la lectura (read)")
	# abrir el encargo es el paso «leer»: aparece la tijera
	ok(rd.open("D23@L1"), "abre el encargo")
	await frames()
	ok(bool(g.sim.q_ui().get("desk.tijera", false)), "paso «recortar»: bandera de la tijera")
	ok(rd.tool_names().has("Tijera"), "aparece «Tijera»: %s" % str(rd.tool_names()))
	# la primera línea del papel es la descripción física, recortable
	var first: Dictionary = {}
	for t in rd.view.pages[0][0].parsed.tramos:
		if int(t.from) == 0:
			first = t
	eq(String(first.get("id", "")), "fisica", "el encargo empieza con su descripción física")

# ------------------------------------------------------------------ cuaderno
func test_notebook_tabs_search_and_filters_by_flags() -> void:
	to_day1()
	var nb = add(Notebook.new())
	nb.sounds = false
	nb.open("recortes")
	await frames()
	var st: Dictionary = nb.debug_state()
	ok(g.sim.q_clips().size() <= 3, "pocos recortes")
	var want_tabs: Array = nb.available_tabs()
	eq(st.tabs, want_tabs if want_tabs.size() > 1 else [], "pestañas = las que tienen bandera: %s" % str(st.tabs))
	no(st.recortes.search, "con pocos recortes, sin buscador")
	eq(st.recortes.menus, [], "sin filtros")
	no(nb.tab_available("cotejos"), "sin pares, sin pestaña de pares")
	no(nb.tab_available("marginalia"), "sin curiosidades, sin su pestaña")
	inject_clips(12)
	nb.refresh()
	await frames()
	ok(nb.page("recortes").debug_state().search, "≥10 recortes: aparece el buscador")
	eq(nb.page("recortes").debug_state().menus, [], "<20: todavía sin filtros")
	inject_clips(20)
	nb.refresh()
	await frames()
	var ps: Dictionary = nb.page("recortes").debug_state()
	ok(g.sim.q_clips().size() >= 30, "30 recortes")
	ok(ps.search, "buscador")
	ok(not (ps.menus as Array).is_empty(), "≥20: filtros (los que tienen ≥2 opciones): %s" % str(ps.menus))
	for k in ps.menus:
		ok((nb.page("recortes").menu_options(String(k)) as Array).size() >= 2, "filtro %s con ≥2 opciones" % k)
	ok(nb.tab_available("indice"), "el índice ya tiene ≥12 entradas: pestaña Índice")

# ------------------------------------------------------------------ libro de conclusiones
func test_ledger_day1_first_page_quotes_pell() -> void:
	to_day1()
	var lg = add(Ledger.new())
	lg.sounds = false
	lg.open()
	await frames()
	var qs: Array = g.sim.q_questions()
	ok(qs.size() >= 3, "día 1: las tres preguntas del encargo (%d)" % qs.size())
	var txt: Array = []
	_all_text(lg, txt)
	var all := "\n".join(PackedStringArray(txt))
	for q in qs:
		ok(all.contains(String(q.text).strip_edges()), "cita textual: %s" % String(q.text).left(40))
	var st: Dictionary = lg.debug_state()
	eq(st.tabs, ["reglas"], "una sola página al empezar")
	no(st.seal, "sin sello antes de la práctica")
	eq(st.new_folio, bool(g.sim.q_ui().get("lg.hoja_nueva", false)), "«Nueva hoja» con su bandera")
	no(st.nb_tab, "sin pestaña «Cuaderno»")

func _all_text(n: Node, out: Array) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append(String(n.text))
	elif n is RichTextLabel and (n as RichTextLabel).is_visible_in_tree():
		out.append(n.get_parsed_text())
	for c in n.get_children():
		_all_text(c, out)

# ------------------------------------------------------------------ bandeja
func test_tray_previous_days_folded_from_day2() -> void:
	to_day1()
	var tr = add(Tray.new())
	await frames()
	tr.open()
	await frames()
	no(tr.prev_toggle.visible, "día 1: sin «Días anteriores»")
	no(tr.days_row.visible, "ni fila de días")
	next_day()
	await frames()
	tr.open()
	await frames()
	eq(int(g.sim.q_clock().day), 2, "día 2")
	ok(tr.prev_toggle.visible, "día 2: «Días anteriores»")
	no(tr.days_row.visible, "plegado")
	tr.prev_toggle.pressed.emit()
	await frames()
	ok(tr.days_row.visible, "se despliega")

# ------------------------------------------------------------------ catálogo
func test_catalog_search_recent_and_desk_after_first_slip() -> void:
	to_day1()
	act({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	var cat = add(Catalog.new())
	await frames()
	cat.open(214)
	await frames()
	ok(cat.filter_edit.visible, "buscador")
	var n := 0
	for c in cat.index_list.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	ok(n <= Catalog.RECENT_N, "«Recientes»: ≤8 entradas (%d)" % n)
	no(cat._mid.visible, "sin entrada elegida: sin fichas")
	no(cat._right.visible, "antes del primer pedido: sin «Sobre mi mesa»")
	ok(cat._seat_btn.visible, "«Asiento 214 · cambiar»")
	act({"t": "slip", "doc": "D05"})
	cat.refresh()
	await frames()
	ok(cat._right.visible, "después del primer pedido: «Sobre mi mesa»")
	eq(Catalog.next_seat(g.sim), 214, "el asiento por defecto: el último usado")
	Catalog.seat_pref = 300
	eq(Catalog.next_seat(g.sim), 300, "«cambiar» vale para la próxima visita")
	Catalog.seat_pref = 0

# ------------------------------------------------------------------ escena y selector
func test_scene_verbs_follow_flags_and_topics_are_sectioned() -> void:
	to_day1()
	act({"t": "go", "place": "L4", "area": ""})
	var sp = add(ScenePanel.new())
	sp.sounds = false
	await frames()
	sp.refresh()
	await frames()
	var fl: Dictionary = g.sim.q_ui()
	for ch in sp.chars:
		var vs: Array = sp._verbs(String(ch.id))
		eq(vs.has("present"), bool(fl.get("sc.mostrar", false)), "«Mostrar» con sc.mostrar ante %s" % ch.id)
		if vs.has("assert"):
			ok(bool(fl.get("sc.decir", false)), "«Decir» sólo con algo que decir")
	eq(sp._tijera_btn.visible, bool(fl.get("desk.tijera", false)), "«Tijera» con su bandera")
	if sp.chars.is_empty():
		return
	var cid := String(sp.chars[0].id)
	if not sp._verbs(cid).has("ask"):
		return
	sp.open_ask(cid, "ask")
	await frames()
	var topics: Array = g.sim.q_topics(cid)
	var shown: Array = sp.ask_panel.shown_ids()
	eq(sp.ask_panel._search.visible, topics.size() > 7, "buscador sólo con más de siete temas")
	if topics.size() > 7:
		ok(shown.has(sp.ask_panel.ALL_ID), "«Todo el índice» plegado")
		ok(shown.size() < topics.size() + 4, "no se despliega el índice entero de entrada")

func test_picker_confrontation_order_and_no_empty_tabs() -> void:
	to_day1()
	var link := SimLink.new()
	var p = add(ItemPicker.new(link))
	p.open("Responder", ["clip", "entry"])
	await frames()
	no(p._tabs["entry"].visible, "sin conclusiones: sin pestaña «Conclusiones»")
	no(p._tabs["clip"].visible, "una sola pestaña posible: no se dibuja")
	no(p._search.visible, "pocas tarjetas: sin buscador")
	p.open("Responder", ["entry", "clip"], {"merged": true})
	await frames()
	var kinds: Array = p.cards().map(func(c): return String(c.kind))
	ok(not kinds.is_empty() and kinds[0] == "clip", "sin conclusiones, los recortes: %s" % str(kinds))

# ------------------------------------------------------------------ compositor de avisos
func test_ad_composer_prologue_only_witness_form() -> void:
	ok(g.new_session(7), "partida nueva")
	act({"t": "read", "view": "D23@L1", "part": 0})
	ok(clip_tramo("D23@L1", "aviso") != "", "recorte del aviso")
	var ac = add(AdComposer.new())
	await frames()
	ac.open()
	await frames()
	eq(ac.forms_available(), ["testigo"], "prólogo: sólo «Se busca testigo»")
	no(ac._forms_row.visible, "una sola forma: sin fila de formas")

# Playtest v2: el plano no se descubría el día 1 -> cinta «Plano» (M) en el HUD con desk.mapa, sólo en el escritorio;
# Pendientes con viñetas, plegada a los 4 s en la primera línea (GDD_v2 §B.6.2) y desplegada al pasar el mouse.
func test_hud_map_ribbon_and_folding_guide() -> void:
	var DeskHud = load("res://ui/desk/desk_hud.gd")
	var hud = add(DeskHud.new())
	await frames(2)
	hud.set_flags({"desk.mapa": false, "hud.cuaderno": false, "hud.libro": false})
	hud.refresh({"phase": "prologue", "slot": "N", "day": 0})
	no(hud.ribbon("map").visible, "prólogo: sin plano")
	hud.set_flags({"desk.mapa": true, "hud.cuaderno": true, "hud.libro": true})
	hud.refresh({"phase": "desk", "slot": "M", "day": 1})
	ok(hud.ribbon("map").visible, "escritorio con desk.mapa: cinta «Plano»")
	eq(hud.ribbon("map").tooltip_text, "M", "con su tecla")
	hud.refresh({"phase": "visit", "slot": "M", "day": 1})
	no(hud.ribbon("map").visible, "en una visita no suma nada")
	hud.set_guide(["Uno.", "Dos.", "Tres."])
	await frames(1)
	var vis := func() -> int:
		var n := 0
		for ch in hud.guide_v.get_children():
			if String(ch.name).begins_with("Linea") and (ch as Control).visible:
				n += 1
		return n
	eq(vis.call(), 3, "desplegada al llegar")
	ok(String(hud.guide_v.get_node("Linea0").text).begins_with("· "), "con viñeta")
	hud._process(4.1)
	eq(vis.call(), 1, "plegada a los 4 s: la primera línea")
	ok(hud.guide_v.get_node("Mas").visible, "«…» si hay más")
	hud.guide_box.mouse_entered.emit()
	eq(vis.call(), 3, "al pasar el mouse se despliega")
