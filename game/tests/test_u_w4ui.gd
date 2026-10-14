# Tests de la corrección W4-UI (playtest de la ola 4): lo que el jugador hace con el MOUSE, con eventos reales
# (Input.parse_input_event) sobre la Shell real. Propuesta para game/tests/ (dueño: el de ui/, §9.2).
#   - lupa del epílogo / del lector: nunca toma el clic (la tijera corta la oración; otra oración = un error)
#   - lápiz azul: «Cerrar el libro» siempre a la vista; Esc / Intro cierran; la ficha avanza con un clic sobre ella
#   - clic derecho = volver sobre cada panel (tijera 3D, tarjeta de examen, bandeja, mapa, lector con tijera)
#   - nota del instructor: espera a la presentación y no queda debajo de los libros
#   - bandeja una vez por día con papeles; el día 10, antes de la confrontación; sin tarjeta flotante en la confrontación
#   - mapa: marcadores sin superponerse a ninguna escala en uso; el abierto gana el clic
#   - catálogo: «Pedir» en toda ficha, fichas dentro de la hoja; título sin «Continuar» tras el epílogo
#   - rótulos: presentado en una línea, Park Lane como voz de Lisle, el librero sin cambiar de nombre; transcripción a la
#     primera línea nueva; eventos del mundo (ladrillo) una vez; copia certificada en Somerset House; tijera sobre la
#     tienda en la confrontación; objetos del tutorial con área de clic de al menos 24×24 px.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240
const Shell = preload("res://ui/shell.gd")
const Layers = preload("res://ui/layers.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const Model = preload("res://ui/epilogue/epilogue_model.gd")
const Screen = preload("res://ui/epilogue/epilogue_screen.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const MapScreen = preload("res://ui/map/map_screen.gd")
const Transcript = preload("res://ui/scene/transcript.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const Markup = preload("res://core/text/markup.gd")

var sh = null
var g = null
var old_size := Vector2i.ZERO
static var _epi := {}

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

func boot_game(extra := {}, real := false) -> void:
	g.repo_override = null if real else W.repo()
	var opts := {"new": true, "seed": 1894, "fast": true, "mute": true, "save": tmp_dir().path_join("partida.jsonl")}
	opts.merge(extra, true)
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(1)
	await sh.boot(opts)
	await settle()

func phase() -> String:
	return String(g.sim.q_clock().phase)

func move(p: Vector2) -> void:
	Input.warp_mouse(p)
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(1)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = p
		e.global_position = p
		e.button_mask = 0 if not pressed else (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT)
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await frames(2)

func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func through_tutorial_and_sleep() -> void:
	W.tutorial(g.sim, act)
	eq(W.errs, [], "tutorial")
	act({"t": "sleep"})
	await settle()

# Epílogo con una partida real del deductor (cacheada por semilla; fresh para las que mutan).
func epi_sim(seed: int, fresh := false):
	var k := str(seed)
	if not fresh and _epi.has(k):
		return _epi[k]
	var b = RunBots.make("deductor")
	var sim = GameSim.new(repo(), seed)
	b.budget_ms = 120000
	b.setup(sim, seed)
	for i in 20000:
		if String(sim.q_clock().phase) == "epilogue":
			break
		if not b.step():
			break
	if not fresh:
		_epi[k] = sim
	return sim

func epi_screen(sim):
	var s = Screen.new()
	s.sim = sim
	s.fast = true
	s.sounds = false
	tree.root.add_child(s)
	s.start()
	return s

func epi_ok(sim) -> bool:
	if sim == null or String(sim.q_clock().phase) != "epilogue":
		skip("el bot no llegó al epílogo")
		return false
	if Model.cut_target(sim).is_empty() or Model.strand_view(sim).is_empty():
		pending_content("falta la Strand de 1903 o su corte")
		return false
	return true

func to_stage(s, st: String, guard := 300) -> void:
	for i in guard:
		if String(s.stage) == st or bool(s.done):
			return
		if String(s.stage) == "tijera":
			var t := Model.cut_target(s.sim)
			s.do_cut(int(t.page), int(t.from), int(t.to) - int(t.from))
		elif String(s.stage) == "creditos" and s._credits != null:
			s._credits.skip()
		else:
			s.advance()
		await tree.process_frame

# ------------------------------------------------------------------ lupa y tijera (bloqueante)
func test_page_view_copy_ignores_mouse() -> void:
	var pv = PageView.new()
	tree.root.add_child(pv)
	pv.setup({"paper": "carta", "paper_mm": [120, 160], "pages": [[{"parsed": {"plain": "Una línea.", "styles": []}}]]}, 0, {"interactive": false})
	eq(pv.mouse_filter, Control.MOUSE_FILTER_IGNORE, "hoja no interactiva (lupa): no toma el mouse")
	for c in pv.get_children():
		if c is Control:
			eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "ni sus bloques: " + String(c.name))
	pv.free()
	var pv2 = PageView.new()
	tree.root.add_child(pv2)
	pv2.setup({"paper": "carta", "paper_mm": [120, 160], "pages": [[{"parsed": {"plain": "Una línea.", "styles": []}}]]}, 0, {})
	eq(pv2.mouse_filter, Control.MOUSE_FILTER_PASS, "la hoja del lector sí")
	pv2.free()

func test_epilogue_scissors_cut_with_real_clicks() -> void:
	var sim = epi_sim(4, true)
	if not epi_ok(sim):
		return
	var s = epi_screen(sim)
	await to_stage(s, "tijera")
	eq(String(s.stage), "tijera")
	await frames(3)
	var sv = s._strand
	var t := Model.cut_target(sim)
	if int(t.page) != int(sv.page_idx):
		sv.show_page(int(t.page))
		await frames(2)
	s.set_scissors(true)
	await frames(1)
	# una oración que NO es la del corte: «Ésa no es la mía.» (un error) y sigue la tijera
	var plain: String = sv.plain_of_page()
	var parsed: Dictionary = sv.page.parsed[0]
	var other := -1
	for se in parsed.get("sentences", []):
		if int(se[1]) <= int(t.from) or int(se[0]) >= int(t.to):
			if int(se[1]) - int(se[0]) > 30 and plain.substr(int(se[0]), int(se[1]) - int(se[0])).strip_edges() != "":
				other = int(se[0]) + 8
				break
	if other >= 0:
		var r_other: Rect2 = sv.tramo_rect(other, other + 2)
		var p_other := r_other.position + Vector2(minf(40.0, r_other.size.x * 0.5), r_other.size.y * 0.5)
		# el punto exacto del carácter
		var rtl: RichTextLabel = sv.page.blocks[0]
		var SelMap = load("res://ui/reader/selection_mapper.gd")
		p_other = rtl.get_global_transform_with_canvas() * (SelMap.char_local_pos(rtl, other) + Vector2(2, 0))
		move(p_other)
		await frames(2)
		var hov := tree.root.gui_get_hovered_control()
		ok(hov == null or not String(hov.get_path()).contains("Lupa"), "bajo el mouse no está la lupa: %s" % (str(hov.get_path()) if hov != null else "nada"))
		await click(p_other)
		eq(int(s.misses), 1, "otra oración: un error (Ésa no es la mía.)")
		eq(String(s.stage), "tijera", "y la tijera sigue")
	var rtl2: RichTextLabel = sv.page.blocks[0]
	var SelMap2 = load("res://ui/reader/selection_mapper.gd")
	var k := int(t.from) + mini(12, (int(t.to) - int(t.from)) / 2)
	var p: Vector2 = rtl2.get_global_transform_with_canvas() * (SelMap2.char_local_pos(rtl2, k) + Vector2(2, 0))
	await click(p)
	await frames(3)
	eq(String(s.stage), "concordancia", "un clic real sobre la oración del hombre alto y delgado: corta y sigue")
	await tree.create_timer(0.6).timeout   # la tira termina de posarse (corrutinas de la pantalla)
	s.free()

# ------------------------------------------------------------------ ficha y lápiz azul
func test_ficha_click_advances_and_pencil_always_closable() -> void:
	var sim = epi_sim(4, true)
	if not epi_ok(sim):
		return
	var s = epi_screen(sim)
	await to_stage(s, "ficha")
	if String(s.stage) == "ficha":
		await frames(2)
		var chip: Control = s.find_child("SeguirFicha", true, false)
		ok(chip != null and chip.is_visible_in_tree(), "la ficha lleva «Seguir» a la vista")
		var card: Control = s.find_child("Tarjeta", true, false)
		ok(card != null, "la ficha")
		if card != null:
			await click(center(card))
			await frames(2)
			ne(String(s.stage), "ficha", "un clic sobre la ficha avanza")
	await to_stage(s, "lapiz", 600)
	eq(String(s.stage), "lapiz", "llega al lápiz azul")
	if String(s.stage) != "lapiz":
		s.free()
		return
	await frames(3)
	for sz in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		tree.root.size = sz
		await frames(3)
		var vr := Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
		var cr: Rect2 = s._pencil.close_rect()
		ok(cr.size.x > 0 and vr.encloses(cr), "«Cerrar el libro» a la vista a %s: %s en %s" % [str(sz), str(cr), str(vr)])
	tree.root.size = Vector2i(1600, 900)
	await frames(2)
	var closed := [false]
	s.closed.connect(func(): closed[0] = true)
	ok(s.back(), "Esc / clic derecho en el lápiz: cierra el libro")
	await frames(2)
	ok(bool(s.done) and closed[0], "terminado (vuelta al título)")
	s.free()

# ------------------------------------------------------------------ clic derecho sobre cada panel
func test_right_click_over_panels_goes_back() -> void:
	await boot_game()
	await through_tutorial_and_sleep()
	var gs = sh.game_screen
	eq(phase(), "desk")
	# bandeja (se abre sola el día 1)
	if not sh.is_open("tray"):
		gs.open_tray()
		await frames(3)
	ok(sh.is_open("tray"), "bandeja")
	await click(center(gs.tray.sheet), MOUSE_BUTTON_RIGHT)
	no(sh.is_open("tray"), "clic derecho sobre la bandeja: se cierra")
	await settle()
	# tarjeta de examen
	gs.on_node("tomos")
	await frames(3)
	ok(gs.exam.visible, "tarjeta de examen")
	await click(center(gs.exam), MOUSE_BUTTON_RIGHT)
	no(gs.exam.visible, "clic derecho sobre la tarjeta: se cierra")
	# tijera en la mano (v3: para las tarjetas; no hay rectángulo sobre el 3D)
	gs.set_scissors(true)
	await frames(2)
	ok(gs.scissors_on, "tijera en la mano")
	await click(Vector2(800, 420), MOUSE_BUTTON_RIGHT)
	no(gs.scissors_on, "clic derecho con la tijera: se deja")
	# mapa
	sh.open_panel("map")
	await frames(4)
	ok(sh.is_open("map"), "mapa")
	var ms = sh.panel("map")
	await click(center(ms.map), MOUSE_BUTTON_RIGHT)
	no(sh.is_open("map"), "clic derecho sobre el mapa: se cierra")
	await tree.create_timer(0.5).timeout
	# lector con la tijera
	ok(sh.open_reader("D23@L1"), "lector")
	await frames(4)
	sh.reader.set_tijera(true)
	await frames(1)
	await click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
	no(bool(sh.reader.tijera), "clic derecho en el lector: primero deja la tijera")
	ok(sh.reader_open(), "y el papel sigue")
	await click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
	no(sh.reader_open(), "otro clic derecho: cierra el lector")

# ------------------------------------------------------------------ nota del instructor
func test_tutor_waits_for_presentation_and_docks_beside_books() -> void:
	await boot_game()
	var gs = sh.game_screen
	eq(phase(), "prologue")
	if gs.speech.visible:
		no(gs.tutor.visible, "la nota espera a que termine la presentación")
	for i in 40:
		if not gs.speech.visible:
			break
		gs.speech.advance()
	await frames(3)
	ok(gs.tutor.visible, "terminada la presentación, la nota del instructor")
	ok(gs.tutor.get_parent().get_parent() is CanvasLayer and (gs.tutor.get_parent().get_parent() as CanvasLayer).layer > sh.layers.books.layer, "encima de los libros")
	sh.open_panel("notebook")
	await frames(6)
	var nb = sh.panel("notebook")
	ok(gs.tutor.is_visible_in_tree(), "con el cuaderno abierto se sigue viendo")
	var br: Rect2 = nb.book_rect()
	no(gs.tutor.get_global_rect().intersects(br), "y no tapa el cuaderno: %s / %s" % [str(gs.tutor.get_global_rect()), str(br)])
	sh.close_kind("notebook")
	await frames(2)
	# v3: el expediente (la carpeta) en lugar del libro mayor; la nota se acopla en la solapa del índice
	sh.open_panel("dossier")
	await frames(6)
	var ex = sh.panel("dossier")
	ok(gs.tutor.is_visible_in_tree(), "con el expediente abierto se sigue viendo")
	var tr: Rect2 = gs.tutor.get_global_rect()
	if ex != null and ex.has_method("rect_of"):
		for what in ["respuesta", "prueba", "encargo"]:
			var r: Rect2 = ex.rect_of(what)
			if r.size.x > 0.0:
				no(tr.intersects(r), "no tapa «%s» de la carpeta: %s / %s" % [what, str(tr), str(r)])
	ok(Rect2(Vector2.ZERO, tree.root.get_visible_rect().size).encloses(tr), "entera en pantalla")

# ------------------------------------------------------------------ bandeja, confrontación y calendario completo
func test_tray_once_per_day_and_before_confront() -> void:
	await boot_game()
	var gs = sh.game_screen
	await through_tutorial_and_sleep()
	var days_with := {}
	var shown := {}
	var confront_checked := false
	for i in 500:
		if sh.screen_id != "game":
			break
		var c: Dictionary = g.sim.q_clock()
		var ph := String(c.phase)
		var d := int(c.day)
		if not g.sim.q_tray(d).is_empty():
			days_with[d] = true
		if is_instance_valid(gs):
			shown = gs._tray_shown.duplicate()
		if sh.is_open("tray"):
			sh.close_kind("tray")
			await settle()
			continue
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			"confront":
				ok(sh.is_open("confront"), "después de la bandeja, la confrontación")
				no(gs.speech.visible, "sin la tarjeta flotante de las líneas en la confrontación")
				confront_checked = true
				a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			"night_choice":
				a = {"t": "night_choice", "where": "casa"}
			"epilogue", "done":
				break
		var r: Dictionary = act(a)
		if not bool(r.get("ok", false)):
			fail("%s en %s -> %s" % [str(a), ph, str(r.get("err", ""))])
			break
		await settle()
	ok(confront_checked, "pasó por la confrontación")
	for d in days_with:
		ok(shown.has(d), "la bandeja del día %d (con papeles) se mostró" % d)

# ------------------------------------------------------------------ mapa
func test_map_markers_never_overlap() -> void:
	var r = repo()
	var mp: Dictionary = r.map().get("places", {})
	for ppm in [1.738, 1.867, 2.17, 2.45]:
		var ms: Array = []
		for id in mp.keys():
			var m = MapScreen.Marker.new()
			m.place_id = String(id)
			m.data = mp[id]
			m.home = bool(mp[id].get("home", false))
			m.label_text = String(mp[id].get("label", id))
			m.state = {"open": true}
			tree.root.add_child(m)
			var xy: Array = mp[id].get("xy", [0, 0])
			m.place_at(Vector2(float(xy[0]), float(xy[1])) * ppm, ppm)
			ms.append(m)
		for i in ms.size():
			for j in range(i + 1, ms.size()):
				var a: Control = ms[i]
				var b: Control = ms[j]
				no(Rect2(a.position, a.size).intersects(Rect2(b.position, b.size)), "%.2f px/mm: %s y %s no se pisan" % [ppm, a.place_id, b.place_id])
		for m in ms:
			m.free()
	# si dos se pisan, el abierto gana el clic
	var parent := Control.new()
	tree.root.add_child(parent)
	var op = MapScreen.Marker.new()
	op.data = {"label_off": [-9, -8], "align": "right"}
	op.label_text = "Abierto"
	op.state = {"open": true}
	parent.add_child(op)
	op.place_at(Vector2(200, 200), 1.8)
	var cl = MapScreen.Marker.new()
	cl.data = {"label_off": [9, 7]}
	cl.label_text = "Cerrado"
	cl.state = {"open": false}
	parent.add_child(cl)
	cl.place_at(Vector2(206, 204), 1.8)
	var p := Vector2(202, 201)
	ok(op._has_point(p - op.position), "el abierto toma el punto")
	no(cl._has_point(p - cl.position), "la persiana encima no se lo come")
	parent.free()

# ------------------------------------------------------------------ catálogo y título
func test_catalog_every_card_asks_and_fits() -> void:
	await boot_game()
	await through_tutorial_and_sleep()
	var gs = sh.game_screen
	sh.close_kind("tray")
	await settle()
	var r: Dictionary = act({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	if not bool(r.get("ok", false)):
		skip("la Sala de Lectura no abre en este momento del dataset: %s" % str(r))
		return
	await settle()
	# v3: el prólogo ya no deja recortes de la Strand en el índice (sólo el aviso): se le dan temas con fichas
	preload("res://core/deduction/index.gd").add_entities(g.sim.st, g.sim.repo, ["fina", "reichenbach", "holmes", "watson", "moriarty"])
	gs.open_catalog()
	await frames(4)
	var cat = gs.catalog
	var tried := 0
	for x in g.sim.q_index():
		if String(x.get("kind", "")) == "act_ref":
			continue
		var rs: Array = g.sim.q_catalog(String(x.get("id", "")))
		if rs.is_empty():
			continue
		cat._search(String(x.get("id", "")))
		await frames(5)
		tried += 1
		for card in cat.results.get_children():
			var btns: Array = card.find_children("*", "Button", true, false)
			ok(btns.size() == 1, "cada ficha con un solo botón")
			for b in btns:
				ok([Widgets.t("shell.cat.pedir"), Widgets.t("shell.cat.leer")].has(String(b.text)), "«Pedir» o «Leer», nunca «No se sirve»: %s" % b.text)
		var vs: Vector2 = tree.root.get_visible_rect().size
		var sr: Rect2 = cat.sheet.get_global_rect()
		ok(sr.end.y <= vs.y - float(gs._band_inset()) + 1.0, "la hoja del catálogo cabe sobre la banda: %s" % str(sr))
		if tried >= 3:
			break
	ok(tried > 0, "hubo búsquedas con varias fichas")

func test_title_without_continue_after_the_end() -> void:
	await boot_game()
	ok(sh.can_continue(), "partida en curso: se continúa")
	sh.mark_finished(true)
	no(sh.can_continue(), "terminada: el título no ofrece «Continuar»")
	sh.mark_finished(false)
	ok(sh.can_continue())

# Continuar un guardado de otra versión del texto: el título lo dice antes y se elige «Seguir» o «Volver al título».
func test_continue_other_version_asks_first() -> void:
	await boot_game()
	g.flush()
	var path := ProjectSettings.globalize_path(String(g.save_path))
	g.end_session()
	var lines := FileAccess.get_file_as_string(path).split("
")
	var head = JSON.parse_string(lines[0])
	ok(typeof(head) == TYPE_DICTIONARY, "cabecera legible")
	head["content"] = "otra_version_del_texto"
	lines[0] = JSON.stringify(head)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("
".join(lines))
	f.close()
	ok(g.save_other_version(), "la cabecera es de otra versión")
	sh.show_title()
	await settle()
	var t = sh.screen
	eq(String(sh.screen_id), "title")
	t._continue()
	await frames(2)
	var cf = t._confirm
	ok(cf != null and is_instance_valid(cf), "pregunta antes de cargar")
	eq(g.sim, null, "todavía no cargó")
	cf.decided.emit(false)
	await settle()
	eq(String(sh.screen_id), "title", "Volver al título: sigue en el título")
	eq(g.sim, null)
	t._continue()
	await frames(2)
	t._confirm.decided.emit(true)
	await settle()
	eq(String(sh.screen_id), "game", "Seguir: carga la partida")
	ok(g.sim != null)

# ------------------------------------------------------------------ rótulos y transcripción
class FakeSim extends RefCounted:
	var lines := {}
	func q_line(u: String) -> Dictionary:
		return lines.get(u, {})
	func q_index() -> Array:
		return []

func test_self_introduction_names_the_speaker() -> void:
	var sim = GameSim.new(repo(), 3)
	var sc: Dictionary = sim.q_scene()
	if sc.is_empty() or (sc.get("lines", []) as Array).is_empty():
		pending_content("el prólogo no dice líneas al empezar")
		return
	var speaks := {}
	for ln in sc.lines:
		speaks[String(ln.who)] = true
	if speaks.has("pell"):
		ok(SimLink.introduced_by_line(sim, "pell"), "Pell se presenta en su primera línea")
	if speaks.has("harris"):
		ok(SimLink.introduced_by_line(sim, "harris"), "Pell presenta al mayor Harris en la misma escena")
	no(SimLink.introduced_by_line(sim, "watson"), "Watson no se presentó")

func test_transcript_scrolls_to_first_new_line_and_narrates_park_lane() -> void:
	var fs := FakeSim.new()
	for i in 14:
		fs.lines["u%d" % i] = {"who": "mycroft" if i % 3 != 0 else "watson", "parsed": Markup.parse("Renglón %d de una deducción larga, larga, que no cabe entera en la banda de la escena." % i)}
	var link = SimLink.new()
	link.sim_override = fs
	var tr = Transcript.new(link)
	tr.animate = false
	var box := Control.new()
	tree.root.add_child(box)
	box.add_child(tr)
	tr.position = Vector2(20, 20)
	tr.size = Vector2(1100, 170)
	tr.set_lines(["u0", "u1"])
	await frames(4)
	var more: Array = []
	for i in 11:
		more.append("u%d" % i)
	tr.set_lines(more)
	await frames(5)
	var row2: Control = tr.rows()[2].row
	near(float(tr.scroll_pos()), row2.position.y, 2.0, "la primera línea nueva arriba de la ventana del rollo")
	tr.set_narration(true)
	await frames(1)
	for r in tr.rows():
		ok(String(r.who_label.text) == "" or String(r.who_label.text) == link.t("sceneui.who.lisle"), "Park Lane: voz de Lisle, sin el nombre de quien pasa (%s)" % r.who_label.text)
	link.who_override["mycroft"] = "caballero corpulento"
	tr.set_narration(false)
	await frames(1)
	ok(link.who_label("mycroft") == "Caballero corpulento", "rótulo fijo de la escena (la confrontación lo usa para el librero)")
	box.free()

# ------------------------------------------------------------------ eventos del mundo
func test_world_event_brick_once() -> void:
	await boot_game()
	await through_tutorial_and_sleep()
	var gs = sh.game_screen
	var w = g.sim.st.react.get("world") if typeof(g.sim.st.react) == TYPE_DICTIONARY else null
	if typeof(w) != TYPE_DICTIONARY:
		skip("sin estado de efectos")
		return
	var now := int(g.sim.q_clock().tk)
	w.events.append({"id": "ladrillo", "tk": now, "rid": "test"})
	w.events.append({"id": "vigilancia_watson", "tk": now, "rid": "test"})
	eq(gs._world_events("amanecer"), [], "el ladrillo es al salir, no al amanecer")
	eq(gs._world_events("salida"), ["ladrillo"], "al salir: el ladrillo (sonido y polvo)")
	eq(gs._world_events("salida"), [], "una sola vez")
	w.events.pop_back()
	w.events.pop_back()

# ------------------------------------------------------------------ confrontación: tijera sobre la tienda
func test_confront_plate_scissors_and_back() -> void:
	await boot_game()
	await through_tutorial_and_sleep()
	var gs = sh.game_screen
	for i in 500:
		if phase() == "confront" or sh.screen_id != "game":
			break
		if sh.is_open("tray"):
			sh.close_kind("tray")
			await settle()
			continue
		var c: Dictionary = g.sim.q_clock()
		var a := {}
		match String(c.phase):
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			_:
				break
		if not bool(act(a).get("ok", false)):
			break
		await settle()
	if phase() != "confront":
		skip("no se llegó a la confrontación")
		return
	if sh.is_open("tray"):
		sh.close_kind("tray")
		await settle()
	ok(sh.is_open("confront"), "confrontación")
	no(gs.speech.visible, "sin tarjeta flotante")
	var cv = sh.panel("confront")
	cv._plate_scissors()
	await frames(2)
	ok(gs.scissors_on, "«Tijera sobre la tienda»: la tijera en la mano para las tarjetas de la tienda")
	ok(sh.router.shortcut("fe_volver"))
	no(gs.scissors_on, "volver deja la tijera")
	ok(sh.is_open("confront"), "y la confrontación sigue")

# ------------------------------------------------------------------ copia certificada (Somerset House) y tutorial con datos reales
func test_order_copy_at_somerset_house() -> void:
	await boot_game({}, true)
	var res := W.tutorial(g.sim, act)
	if not W.errs.is_empty():
		skip("el tutorial por acciones no corre sobre data/: %s" % str(W.errs))
		return
	act({"t": "sleep"})
	await settle()
	var gs = sh.game_screen
	sh.close_kind("tray")
	await settle()
	# v3 (GDD_v3 §5.2): Somerset House entra al plano cuando Crane dice dónde se ven los testamentos
	if not g.sim.q_place_known("L6"):
		g.sim.st.world.known["testamento"] = int(g.sim.q_clock().tk)
		act({"t": "go", "place": "L1", "area": "tienda"})
		await settle()
		act({"t": "ask_donde", "char": "crane", "item": "donde.registros"})
		act({"t": "leave"})
		await settle()
		sh.close_all()
		await settle()
		ok(g.sim.q_place_known("L6"), "Somerset House en el plano (Crane)")
	var r: Dictionary = act({"t": "go", "place": "L6", "area": "sala"})
	if not bool(r.get("ok", false)):
		skip("Somerset House cerrada: %s" % str(r))
		return
	await settle()
	var nid := ""
	for n in gs._place_def("L6").get("nodes", []):
		if String(n.get("_doc", "")).begins_with("D18") and String(n.get("examine", "")).contains("indices_somerset"):
			nid = String(n.id)
	ok(nid != "", "un nodo de los índices")
	gs.on_node(nid)
	await frames(3)
	var btn: Button = null
	for b in gs.exam.find_children("*", "Button", true, false):
		if String(b.text).begins_with(Widgets.t("shell.copia.corto")):
			btn = b
	ok(btn != null, "«Pedir copia certificada» junto a «Leer»")
	if btn == null:
		return
	var coins := int(g.sim.q_clock().coins_d)
	btn.pressed.emit()
	await frames(2)
	var m = gs.modal()
	ok(m != null, "en dos pasos")
	for ch in m.find_children("*", "", true, false):
		if ch.has_signal("decided"):
			ch.decided.emit(true)
			break
	await settle()
	eq(int(g.sim.q_clock().coins_d), coins - 12, "un chelín")
	var last: Dictionary = g.sim.actions_log()[-1]
	eq(String(last.get("t", "")), "order_copy", "acción order_copy por la UI")

func test_tutorial_objects_have_a_clickable_area() -> void:
	await boot_game({}, true)
	var gs = sh.game_screen
	for i in 40:
		if not gs.speech.visible:
			break
		gs.speech.advance()
	await frames(4)
	await tree.create_timer(0.6).timeout
	ok(gs.tutor.visible, "nota del instructor")
	var ents: Array = gs.tutor.links().map(func(l): return String(l.ent))
	ok(ents.has("encargo"), "el encargo se puede tocar desde la nota: %s" % str(ents))
	var w = sh.world
	var cam: Camera3D = w.camera()
	var idx: Dictionary = w.diorama.get_meta("nodes_index", {})
	for e in ents:
		var nid: String = gs._node_for_ent(String(e))
		if not idx.has(nid):
			continue
		var pr := cam.unproject_position((idx[nid] as Node3D).global_position)
		var hits := 0
		for dx in range(-60, 61, 4):
			for dy in range(-60, 61, 4):
				if String(w.pick(pr + Vector2(dx, dy)).get("id", "")) == nid:
					hits += 1
		ok(hits * 16 >= 24 * 24, "«%s» con área de clic ≥ 24×24 px en el encuadre «%s» (%d px²)" % [nid, gs.frame, hits * 16])
	gs._on_tutor_link("encargo")
	await frames(3)
	ok(gs.exam.visible or sh.is_open("dossier"), "un clic en «encargo» de la nota lo muestra (GDD_v3 §3.1: el encargo va en la carpeta)")

# «Continuar» una partida guardada en el epílogo: la pantalla de juego cede el fundido a la Shell y la corrutina vuelve
# (antes gs.start() quedaba colgado al liberarse la pantalla, con un error del motor).
func test_continue_into_epilogue_returns() -> void:
	await boot_game()
	await through_tutorial_and_sleep()
	for i in 500:
		if sh.screen_id != "game":
			break
		if sh.is_open("tray"):
			sh.close_kind("tray")
			await settle()
			continue
		var c: Dictionary = g.sim.q_clock()
		var a := {}
		match String(c.phase):
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			"confront":
				a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			"night_choice":
				a = {"t": "night_choice", "where": "casa"}
			_:
				break
		if not bool(act(a).get("ok", false)):
			break
		await settle()
	await settle()
	eq(sh.screen_id, "epilogue", "llegó al epílogo")
	g.flush()
	g.end_session()
	sh.show_title()
	await frames(3)
	ok(sh.can_continue(), "el título ofrece continuar (el epílogo no se cerró)")
	await sh.continue_game()
	await settle()
	eq(sh.screen_id, "epilogue", "continuar vuelve al epílogo y la corrutina termina")

# Elenco de dos personajes (con «Pagar»): la banda crece y todos los verbos quedan a la vista, sin desplazar.
class CastSim extends RefCounted:
	var repo = null
	func q_clock() -> Dictionary:
		return {"phase": "visit", "day": 3, "slot": "M", "date_label": "jueves 29 de marzo", "slot_label": "mañana"}
	func q_scene() -> Dictionary:
		return {"id": "V1", "place": "L3", "area": "interior", "lines": [], "present_ok": true,
			"chars": [{"id": "mrs_hudson", "label": "casera con cofia", "can_ask": true}, {"id": "wiggins", "label": "muchacho con gorra", "can_ask": true}]}
	func q_topics(_c: String) -> Array:
		return [{"id": "holmes", "label": "Holmes"}]
	func q_assertions() -> Array:
		return [{"id": "A1", "phrase": "Una afirmación."}]
	func q_index() -> Array:
		return []
	func q_preview(_a: Dictionary) -> String:
		return "Una frase."
	func can(_a: Dictionary) -> Dictionary:
		return {"ok": true}

func test_scene_cast_fits_with_two_characters() -> void:
	var cs := CastSim.new()
	cs.repo = repo()
	var SP = load("res://ui/scene/scene_panel.gd")
	var sp = SP.new()
	sp.sim = cs
	sp.sounds = false
	sp.show_leave = true
	tree.root.add_child(sp)
	sp.refresh()
	for i in 6:
		await tree.process_frame
	var br: Rect2 = sp.band.get_global_rect()
	var n := 0
	for b in sp.band.find_children("Verbo_*", "Button", true, false):
		n += 1
		ok(br.encloses((b as Button).get_global_rect()), "verbo a la vista dentro de la banda: %s %s / %s" % [b.name, str((b as Button).get_global_rect()), str(br)])
	ok(n >= 7, "los verbos de los dos personajes (%d)" % n)
	no(sp._cast_scroll.get_v_scroll_bar().visible, "sin barra de desplazamiento en el elenco")
	sp.free()

# Wiggins (silueta con diálogo desde el día 3) se toca y recibe lo que se suelta como cualquier personaje.
func test_wiggins_silhouette_is_a_character() -> void:
	await boot_game({}, true)
	W.tutorial(g.sim, act)
	if not W.errs.is_empty():
		skip("el tutorial por acciones no corre sobre data/")
		return
	act({"t": "sleep"})
	await settle()
	for i in 300:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= 3 and String(c.phase) == "desk":
			break
		if sh.is_open("tray"):
			sh.close_kind("tray")
			await settle()
			continue
		var a := {}
		match String(c.phase):
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			_:
				break
		if not bool(act(a).get("ok", false)):
			break
		await settle()
	sh.close_kind("tray")
	await settle()
	var r: Dictionary = act({"t": "go", "place": "L3", "area": "calle"})
	if not bool(r.get("ok", false)):
		skip("Baker Street no abre: %s" % str(r))
		return
	await settle()
	var ids: Array = g.sim.q_scene().get("chars", []).map(func(c): return String(c.id))
	if not ids.has("wiggins"):
		pending_content("Wiggins no está en la calle de Baker Street el día 3")
		return
	var gs = sh.game_screen
	var body = sh.world.node_body("sil_wiggins")
	ok(body != null, "su silueta en la lámina")
	if body == null:
		return
	var cam: Camera3D = sh.world.camera()
	var p := cam.unproject_position((body as Node3D).global_position + Vector3(0, 0.9, 0))
	var hit := ""
	for dy in range(-80, 81, 8):
		var q := p + Vector2(0, dy)
		if String(sh.world.pick(q).get("id", "")) == "sil_wiggins":
			p = q
			hit = "sil_wiggins"
			break
	eq(hit, "sil_wiggins", "la silueta se puede tocar")
	eq(sh.drop_catcher.char_at(p), "wiggins", "soltar sobre su figura = presentarle (DropCatcher3D)")
	sh.close_kind("scene")
	await settle()
	gs.on_node("sil_wiggins")
	await frames(3)
	ok(sh.is_open("scene"), "clic en su figura: la conversación, no una tarjeta de examen")
	no(gs.exam.visible)

# Playtest v3: al «Continuar» (sesión nueva: _tray_shown vacío), la bandeja se abre sola sólo si tiene papeles sin leer.
func test_tray_reopens_only_with_unread_papers() -> void:
	await boot_game()
	var gs = sh.game_screen
	await through_tutorial_and_sleep()
	var d := int(g.sim.q_clock().day)
	var items: Array = g.sim.q_tray(d)
	ok(not items.is_empty(), "hay papeles el día %d" % d)
	if sh.is_open("tray"):
		sh.close_kind("tray")
		await settle()
	gs._tray_shown.clear()   # como al continuar en otra sesión
	ok(gs._tray_pending(d), "con papeles sin leer, se abre sola")
	for it in items:
		var v: Dictionary = g.sim.q_view(String(it.view))
		for pi in (v.get("pages", []) as Array).size():
			act({"t": "read", "view": String(it.view), "part": pi})
	ok(g.sim.q_tray(d).all(func(x): return bool(x.get("read", false))), "todo leído")
	gs._tray_shown.clear()
	no(gs._tray_pending(d), "todo leído: al continuar no se vuelve a abrir sola")
