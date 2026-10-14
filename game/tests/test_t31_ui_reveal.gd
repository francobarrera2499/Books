# T31 (GDD_v2 §C, §F.3 DESPEJE-UI): revelado progresivo de la interfaz, vista por vista, con la partida REAL (Game +
# data/). Al empezar cada vista sólo muestra lo de «Al principio» (§C.3) y cada control aparece con su bandera de q_ui
# (§C.2), nunca antes. Sin pantalla: las vistas se arman headless (el driver con ventana y capturas es
# devtools/drivers/v2despeje_vistas.gd).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120
const Reader = preload("res://ui/reader/document_reader.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")
const Expediente = preload("res://ui/expediente/expediente.gd")
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

# v3 (GDD_v3 §6.2): ≤15 palabras; el tramo entero si cabe, si no la ventana legal que más lo cubre.
func clip_tramo(view: String, tid: String) -> String:
	var v: Dictionary = g.sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for t in v.pages[pi][bi].parsed.tramos:
				if String(t.id) == tid:
					var span: Array = load("res://tests/fixtures/w3shell/walk.gd").best_window(v.pages[pi][bi].parsed, int(t.from), int(t.to))
					var r: Dictionary = g.act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi},
						"from": int(span[0]), "len": int(span[1]) - int(span[0])})
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
	ok(rd.open("D01.GREE@tomo"), "abre un tomo (una crónica activa, GDD_v3 §3.5)")
	await frames()
	no(bool(g.sim.q_ui().get("desk.tijera", true)), "prólogo, paso «leer»: la tijera todavía no")
	var t0: Array = rd.tool_names()
	no(t0.has("Tijera"), "sin «Tijera»: %s" % str(t0))
	no(t0.has("Zoom"), "sin indicador de zoom")
	ok(t0.has("Volver"), "«Volver»")
	for m in ["set_lupa", "set_regla"]:
		no(rd.has_method(m), "sin " + m)
	has(g.sim.q_read("D01.GREE@tomo"), 0, "el lector anotó la lectura (read)")
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
	no(Notebook.TABS.has("cotejos"), "v3: sin pares ni pestaña de pares")
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

# ------------------------------------------------------------------ expediente (GDD_v3 §6.1; UI-EXPEDIENTE)
# Día 1: la carpeta muestra «El encargo» y sólo las preguntas ya nacidas (≤3, con la del cliente), cada hoja con su
# origen y sus dudas; «Pasar en limpio» no está hasta llenar las tres ranuras; «En tinta» no existe sin nada en tinta;
# ningún contador (ni de preguntas, ni de intentos).
func test_expediente_day1_only_born_questions_no_counters() -> void:
	to_day1()
	if not g.sim.has_method("q_dossier"):
		pending_content("la GameSim todavía no tiene q_dossier (CORE)")
		return
	var ex = add(Expediente.new())
	ex.sounds = false
	ex.open()
	await frames()
	var d: Dictionary = g.sim.q_dossier()
	var st: Dictionary = ex.debug_state()
	eq(st.open_ids, d.open.map(func(h): return String(h.id)), "la carpeta lista las abiertas del sim")
	ok((st.open_ids as Array).size() <= 3, "como mucho tres abiertas")
	has(st.open_ids, "Q1", "la pregunta del cliente está desde el principio")
	ok(ex.rect_of("encargo").size.x > 0.0, "«El encargo» a la vista")
	eq(st.has_ink_fold, not (d.inked as Array).is_empty(), "«En tinta» sólo si hay algo en tinta")
	no(st.pass, "sin las tres ranuras llenas no hay «Pasar en limpio»")
	var txt: Array = []
	_all_text(ex, txt)
	var digits := RegEx.new()
	digits.compile("[0-9]")
	for t in txt:
		no(digits.search(String(t)) != null, "sin contadores: «%s»" % String(t))

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
	# v3 (GDD_v3 §6.10): se muestra o se informa un recorte o una pregunta del expediente
	p.open("Responder", ["clip"])
	await frames()
	no(p._tabs["pregunta"].visible, "sólo recortes: sin pestaña «Preguntas»")
	no(p._tabs["clip"].visible, "una sola pestaña posible: no se dibuja")
	no(p._search.visible, "pocas tarjetas: sin buscador")
	p.open("Responder", ["clip", "pregunta"])
	await frames()
	var both: bool = not g.sim.q_clips().is_empty() and not (g.sim.q_dossier().open as Array).is_empty()
	eq(p._tabs["pregunta"].visible, both, "«Preguntas» sólo si hay recortes y preguntas")
	p.open("Responder", ["pregunta", "clip"], {"merged": true})
	await frames()
	var kinds: Array = p.cards().map(func(c): return String(c.kind))
	ok(not kinds.is_empty() and kinds[0] == "clip", "sin nada en tinta, primero los recortes: %s" % str(kinds))
	ok(kinds.is_empty() or kinds[-1] == "pregunta" or (g.sim.q_dossier().open as Array).is_empty(), "y al final las preguntas a lápiz: %s" % str(kinds))

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

# v3 (GDD_v3 §5.4, §6.4; UI-MUNDO): no hay cinta del plano (está en la pared) ni del libro mayor; las cintas «Cuaderno» y
# «Expediente» sólo fuera de la buhardilla (hud.cintas), cada una con su bandera; Pendientes con viñetas, plegada a los
# 4 s en la primera línea (GDD_v2 §B.6.2) y desplegada al pasar el mouse.
func test_hud_map_ribbon_and_folding_guide() -> void:
	var DeskHud = load("res://ui/desk/desk_hud.gd")
	var hud = add(DeskHud.new())
	await frames(2)
	ok(hud.ribbon("map") == null, "sin cinta del plano")
	ok(hud.ribbon("ledger") == null, "sin cinta del libro mayor")
	hud.set_flags({"hud.cintas": false, "hud.cuaderno": true, "desk.expediente": true})
	hud.refresh({"phase": "desk", "slot": "M", "day": 1})
	no(hud.books_box.visible, "en la buhardilla: sin cintas (todo está sobre la mesa)")
	hud.set_flags({"hud.cintas": true, "hud.cuaderno": false, "desk.expediente": true})
	hud.refresh({"phase": "visit", "slot": "M", "day": 1})
	ok(hud.books_box.visible and hud.ribbon("dossier").visible, "fuera de casa: «Expediente»")
	no(hud.ribbon("notebook").visible, "«Cuaderno» con su bandera")
	eq(hud.ribbon("dossier").tooltip_text, "E", "con su tecla")
	hud.set_flags({"hud.cintas": true, "hud.cuaderno": true, "desk.expediente": true})
	hud.refresh({"phase": "scene", "slot": "N", "day": 7})
	ok(hud.ribbon("notebook").visible and hud.ribbon("dossier").visible, "en una escena, las dos")
	var got: Array = []
	hud.book_pressed.connect(func(k): got.append(k))
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	hud.ribbon("dossier").gui_input.emit(e)
	eq(got, ["dossier"], "clic en la cinta: el expediente")
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
	# playtest v3: ya no se pliega sola (escondía el resto detrás de «…»)
	eq(vis.call(), 3, "a los 4 s sigue desplegada")
	no(hud.guide_v.get_node("Mas").visible, "sin «…»")
	hud._set_folded(true)
	eq(vis.call(), 1, "plegada a mano: la primera línea")
	hud.guide_box.mouse_entered.emit()
	eq(vis.call(), 3, "al pasar el mouse se despliega")
