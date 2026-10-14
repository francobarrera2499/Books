# Tests del cuaderno (UI-EXPEDIENTE; GDD_v3 §6.1–§6.3; antes W3-NOTEBOOK, ARCHITECTURE §6.5, §6.1, §6.3).
# Modelo puro (ui/notebook/notebook_model.gd), la UI headless sobre la GameSim REAL del recorrido de integración
# (datos estructurales de data/ + tests/fixtures/integ: recortes, diario con llegadas y líneas dichas) y, para las
# tarjetas (GDD_v3 §6.2: borde de 1 px, 8 px de margen, la fuente en chico, entidades sólo al pasar el mouse, 10 px
# entre tarjetas, ≤15 palabras; sin pares), el doble suelto devtools/drivers/v3exp_fake.gd sobre data/ real.
# Capturas: devtools/drivers/v3exp_vista.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const Model = preload("res://ui/notebook/notebook_model.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")
const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Fake = preload("res://devtools/drivers/v3exp_fake.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")

var nb = null
var sim = null
var old_size := Vector2i.ZERO

func before_each() -> void:
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)

func after_each() -> void:
	if nb != null and is_instance_valid(nb):
		nb.free()
	nb = null
	sim = null
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti != null and (ti.high_contrast or ti.text_scale != 1.0):
		ti.high_contrast = false
		ti.set_text_scale(1.0)
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

# GameSim real del escenario del cuaderno (tests/fixtures/w3notebook/nb_walk.gd, sobre el fixture v3 de CORE): cada
# test recibe una GameSim nueva.
func walk():
	var s = NbWalk.sim()
	if s == null:
		pending_content("escenario del cuaderno no disponible: %s" % str(NbWalk.errs))
	return s

# Partida recién empezada (prólogo) sobre el mismo dataset.
func fresh_sim():
	var r = NbWalk.repo()
	if r == null:
		pending_content("dataset del recorrido no disponible: %s" % str(NbWalk.errs))
	return GameSim.new(r, 7) if r != null else null

# false = sin sim (el test se salta: pending_content ya lo dijo).
func make(p_sim = null) -> bool:
	sim = p_sim if p_sim != null else walk()
	if sim == null:
		return false
	nb = Notebook.new()
	nb.sim_override = sim
	nb.act_fn = func(a): return sim.apply(a)
	nb.sounds = false
	tree.root.add_child(nb)
	return true

func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

func ui_text(key: String) -> String:
	return repo().text(key)

# ------------------------------------------------------------------ modelo puro
func test_model_fold_and_search() -> void:
	eq(Model.fold("Genève ÑANDÚ Ü"), "geneve nandu u", "minúsculas sin tildes")
	var c := {"id": "RC0001", "text": "Más arriba hay una cornisa.", "caption": "cornisa, Reichenbach", "src_line": "Journal de Genève · prensa extranjera",
		"ents": [{"id": "cornisa", "label": "cornisa"}]}
	ok(Model.matches(c, "CORNISA"), "sin mayúsculas")
	ok(Model.matches(c, "ginebra") == false, "sólo lo que está escrito")
	ok(Model.matches(c, "geneve mas"), "todas las palabras, sin tildes, en texto y fuente")
	no(Model.matches(c, "geneve cascada"), "una palabra ausente: no")
	ok(Model.matches(c, "  "), "búsqueda vacía: todo")

func _syn() -> Array:
	return [
		{"id": "RC0003", "chron_date": "1891-05-04", "text": "a", "ents": [{"id": "watson", "label": "Watson"}, {"id": "reichenbach", "label": "Reichenbach"}], "place": ""},
		{"id": "RC0001", "chron_date": "1891-05-04", "text": "b", "ents": [{"id": "holmes", "label": "Holmes"}], "place": ""},
		{"id": "RC0002", "chron_date": "1890-04-27", "text": "c", "ents": [{"id": "watson", "label": "Watson"}], "place": "londres"},
		{"id": "RC0004", "chron_date": "", "text": "d", "ents": [{"id": "act.3", "label": "asiento 214"}], "place": ""},
		{"id": "RC0005", "chron_date": "1891-05-01", "text": "zeta", "ents": [], "place": ""},
	]

func test_model_groups_by_chronicle_calendar() -> void:
	var g := Model.groups(_syn())
	eq(g.map(func(x): return x.key), ["1890-04", "1891-05", ""], "meses en orden y sin fecha al final")
	eq(g[1].clips.map(func(x): return x.id), ["RC0005", "RC0001", "RC0003"], "por fecha de la crónica y luego por recorte")
	var tf := func(k: String, v: Dictionary) -> String: return repo().text(k, v)
	eq(Model.month_label(tf, "1891-05"), "Mayo de 1891", "rótulo del mes")
	eq(Model.month_label(tf, ""), ui_text("nb.sin_fecha"), "sin fecha")

func test_model_filters() -> void:
	var kinds := {"watson": "persona", "holmes": "persona", "reichenbach": "lugar", "londres": "lugar", "act.3": "act_ref"}
	var ids := func(f: Dictionary) -> Array: return Model.apply_filters(_syn(), f, kinds).map(func(x): return x.id)
	eq(ids.call({"persona": "watson"}), ["RC0003", "RC0002"], "persona")
	eq(ids.call({"lugar": "reichenbach"}), ["RC0003"], "lugar por entidad")
	eq(ids.call({"lugar": "londres"}), ["RC0002"], "lugar por p: de la crónica")
	eq(ids.call({"fecha": "1891-05"}), ["RC0003", "RC0001", "RC0005"], "fecha de la crónica (mes)")
	eq(ids.call({"ent": "act.3"}), ["RC0004"], "cualquier entidad del índice")
	eq(ids.call({"persona": "watson", "fecha": "1891-05"}), ["RC0003"], "AND entre filtros")
	eq(ids.call({"q": "ZETA"}), ["RC0005"], "búsqueda")
	eq(ids.call({}).size(), 5, "sin filtros")
	var rows := [{"id": "holmes", "label": "Holmes", "kind": "persona"}, {"id": "reichenbach", "label": "Reichenbach", "kind": "lugar"},
		{"id": "watson", "label": "Watson", "kind": "persona"}, {"id": "act.3", "label": "asiento 214", "kind": "act_ref"}]
	var o := Model.filter_options(_syn(), rows)
	eq(o.persona.map(func(x): return x.id), ["holmes", "watson"], "personas presentes, en el orden del índice")
	eq(o.lugar.map(func(x): return x.id), ["reichenbach", "londres"], "lugares presentes (también los de p:)")
	eq(o.fecha.map(func(x): return x.key), ["1890-04", "1891-05"], "meses presentes")

# Las etiquetas del índice llevan comas («Holmes, Sherlock»): el epígrafe las separa con «; » para que se vea dónde
# termina cada entidad; todas, en el mismo orden. El lugar del final (línea dicha) queda como última pieza.
func test_model_caption_semicolons() -> void:
	var c := {"kind": "text", "caption": "bienes, Holmes, Mycroft, Holmes, Sherlock",
		"ents": [{"id": "bienes", "label": "bienes"}, {"id": "mycroft", "label": "Holmes, Mycroft"}, {"id": "holmes", "label": "Holmes, Sherlock"}]}
	eq(Model.caption_text(c), "bienes; Holmes, Mycroft; Holmes, Sherlock", "entidades separadas por punto y coma")
	var ln := {"kind": "text", "caption": "Watson, John H., doctor, Consultorio del doctor Watson, Kensington",
		"ents": [{"id": "watson", "label": "Watson, John H., doctor"}]}
	eq(Model.caption_text(ln), "Watson, John H., doctor; Consultorio del doctor Watson, Kensington", "y el lugar al final")
	var pl := {"kind": "plate", "caption": "mesa, cesto, mozo con gorra", "ents": [{"id": "cesto", "label": "cesto"}]}
	eq(Model.caption_text(pl), "mesa, cesto, mozo con gorra", "lámina: los sustantivos tal cual")
	var other := {"kind": "text", "caption": "algo distinto", "ents": [{"id": "x", "label": "equis"}]}
	eq(Model.caption_text(other), "algo distinto", "un caption que no es la lista de entidades queda tal cual")
	eq(Model.caption_text({"caption": "", "ents": []}), "", "vacío")
	# sobre la sim real: cada tarjeta de texto muestra la versión con «; » y nombra todas sus entidades (la de lámina lista
	# los sustantivos que tocó, como los compone Clipper)
	var s = walk()
	if s != null:
		for cl in s.q_clips():
			if String(cl.get("kind", "")) == "plate":
				continue
			var txt := Model.caption_text(cl)
			for e in cl.ents:
				ok(txt.contains(String(e.label)), "%s: el epígrafe nombra %s" % [cl.id, e.label])

func test_model_index_sections() -> void:
	var tf := func(k: String, v: Dictionary) -> String: return repo().text(k, v)
	var rows := [{"id": "d1", "label": "27 de abril de 1890"}, {"id": "a", "label": "a pique"}, {"id": "b", "label": "«asiento 214»"},
		{"id": "c", "label": "Ébano"}, {"id": "e", "label": "escalera"}]
	var s := Model.index_sections(rows, tf)
	eq(s.map(func(x): return x.letter), ["A", "E", ui_text("nb.indice.cifras")], "letras; las cifras al final")
	eq(s[0].rows.size(), 2, "la comilla no cuenta para la letra")
	eq(s[1].rows.size(), 2, "É va con E")
	eq(Model.index_sections(rows, tf, "ESCAL").size(), 1, "búsqueda en el índice")

func test_model_diary_days_and_stamp() -> void:
	var sched: Dictionary = repo().schedule()
	var tf := func(k: String, v: Dictionary) -> String: return repo().text(k, v)
	var days := Model.diary_days([{"id": "DY.1", "day": 0}, {"id": "DY.2", "day": 1}, {"id": "DY.3", "day": 1}], sched)
	eq(days.size(), 2, "un grupo por día")
	eq(days[1].label, "Martes 27 de marzo de 1894", "rótulo del día del calendario")
	eq(Model.recibido_stamp(tf, sched, 2), ui_text("nb.diario.recibido") + "\n28-mar", "sello «Recibido» con la fecha")

# ------------------------------------------------------------------ cuaderno sobre la sim real
func test_builds_every_tab_from_real_sim() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	# GDD_v2 §C.2: cada pestaña existe sólo con su bandera; la que no existe no se muestra ni se puede abrir
	var fl: Dictionary = sim.q_ui()
	for t in Notebook.TABS:
		var want: bool = t == "recortes" or bool(fl.get(Notebook.TAB_FLAG[t], false))
		eq(nb.tab_available(t), want, "pestaña %s según su bandera" % t)
		nb.show_tab(t)
		await frames(1)
		if want:
			eq(nb.tab, t, "pestaña " + t)
		else:
			ok(nb.tab != t, "sin bandera no se abre: " + t)
		eq(nb._tab_buttons[t].text, ui_text("nb.tab." + t), "rótulo de la pestaña sin contadores: " + t)
	eq(nb.debug_state().tabs, nb.available_tabs() if nb.available_tabs().size() > 1 else [], "a la vista, las pestañas que existen")
	var st: Dictionary = nb.debug_state()
	eq(st.recortes.cards.size(), sim.q_clips().size(), "una tarjeta por recorte")
	eq(st.indice.entries.size(), sim.q_index().size(), "una entrada por entidad del índice")
	no(Notebook.TABS.has("cotejos"), "v3: sin pares ni cotejos")
	eq(st.diario.rows.size(), sim.q_diary().size(), "un renglón por línea del diario")
	var arrivals: int = sim.q_diary().filter(func(e): return String(e.kind) == "arrival").size()
	ok(arrivals > 0, "hay llegadas en el recorrido")
	eq(st.diario.stamps, arrivals, "cada llegada lleva su sello «Recibido»")
	eq(st.marginalia.notes, [], "sin huevos hallados, Curiosidades vacía")
	no(nb._tab_buttons["marginalia"].visible, "sin huevos hallados, la pestaña de Curiosidades no está a la vista")

func test_clips_grouped_and_margin_dates() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	var page = nb.page("recortes")
	var st: Dictionary = page.debug_state()
	var keys: Array = Model.groups(sim.q_clips()).map(func(x): return x.key)
	eq(st.groups, keys, "grupos del calendario de la crónica")
	ok(keys.has("1891-05") and keys[keys.size() - 1] == "", "mayo de 1891 presente; lo sin fecha al final")
	# el día de la crónica en el margen, una sola vez por día
	var seen := {}
	for id in page.visible_ids():
		var card = page.card(id)
		var d := String(card.clip.chron_date)
		if d == "":
			eq(card.margin_label.text, "", "sin fecha: margen en blanco")
		elif seen.has(d):
			eq(card.margin_label.text, "", "el día no se repite")
		else:
			# integración v3: «día 4» se leía como el día 4 de la partida -> «4 may.» (y el año si no hay encabezado del mes)
			var want := Model.day_label(nb.text_fn(), d)
			if not nb.flag("nb.agrupar"):
				want += "\n" + d.substr(0, 4)
			eq(card.margin_label.text, want, "fecha de la crónica en el margen («4 may.»)")
			seen[d] = true
	# la línea de fuente en la tarjeta; las entidades, sólo al pasar el mouse (GDD_v3 §6.2)
	var ids: Array = page.visible_ids()
	ok(not ids.is_empty(), "hay tarjetas")
	if not ids.is_empty():
		var c0 = page.card(String(ids[0]))
		var texts := _labels_text(c0)
		ok(texts.contains(String(sim.q_clip(String(ids[0])).src_line)), "línea de fuente visible")
		var labels: Array = ClipCard.entity_labels(sim.q_clip(String(ids[0])))
		if not labels.is_empty():
			no(texts.contains(Model.caption_text(sim.q_clip(String(ids[0])))) and Model.caption_text(sim.q_clip(String(ids[0]))) != String(sim.q_clip(String(ids[0])).text), "el epígrafe no está a la vista")
			eq(c0.strip.tooltip_text, "; ".join(PackedStringArray(labels)), "las entidades, al pasar el mouse")

func _labels_text(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	if n is RichTextLabel:
		out += (n as RichTextLabel).get_parsed_text() + "\n"
	for c in n.get_children():
		out += _labels_text(c)
	return out

func test_filters_search_and_index_click() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	var page = nb.page("recortes")
	var with_watson: Array = sim.q_clips().filter(func(c): return c.ents.any(func(e): return e.id == "watson")).map(func(c): return c.id)
	ok(with_watson.size() >= 2, "hay recortes con Watson")
	# clic en el índice -> Recortes filtrado
	nb.show_tab("indice")
	await frames()
	var ch = nb.page("indice").chip("watson")
	ok(ch != null, "Watson en el índice")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	ch._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	ch._gui_input(up)
	await frames()
	eq(nb.tab, "recortes", "el clic en el índice lleva a Recortes")
	eq(nb.filters.persona, "watson", "filtro de persona")
	eq(page.visible_ids(), Model.groups(sim.q_clips()).reduce(func(acc, g): return acc + g.clips.map(func(c): return c.id), []).filter(func(i): return with_watson.has(i)), "sólo los recortes con Watson, en orden")
	eq(page.debug_state().chips, 2, "un chip del filtro y «Quitar los filtros»")
	# fecha de la crónica
	nb.clear_filters()
	var months: Array = page.menu_options("fecha").map(func(o): return o.key)
	ok(months.has("1891-05"), "mayo de 1891 en el menú de fechas")
	page.choose("fecha", "1891-05")
	for id in page.visible_ids():
		ok(String(sim.q_clip(id).chron_date).begins_with("1891-05"), "%s es de mayo de 1891" % id)
	# búsqueda por texto
	nb.clear_filters()
	page._search.text = "pared"
	page._search.text_changed.emit("pared")
	var expect: Array = Model.apply_filters(sim.q_clips(), {"q": "pared"}, Model.kinds_of(sim.q_index())).map(func(c): return c.id)
	ok(expect.size() >= 2, "la búsqueda halla algo")
	var got: Array = page.visible_ids()
	got.sort()
	expect.sort()
	eq(got, expect, "búsqueda")
	page._search.text = "zzzz"
	page._search.text_changed.emit("zzzz")
	eq(page.visible_ids(), [], "nada responde")
	eq(page.debug_state().empty, ui_text("nb.vacio.filtro"), "Lisle lo dice")

# Un lugar de la crónica (`p:`, visible como filtro) que no está en el índice del jugador: el menú y el chip lo
# rotulan con su etiqueta del repo, nunca con el id crudo.
func test_place_filter_label_from_repo() -> void:
	var s = walk()
	if s == null:
		return
	var Clipper = load("res://core/deduction/clipper.gd")
	var known := {}
	for r in s.q_index():
		known[String(r.id)] = true
	var ents: Dictionary = s.repo.entities()
	var place := ""
	for id in ents:
		var e: Dictionary = ents[id]
		if place == "" and String(e.get("kind", "")) == "lugar" and not known.has(String(id)) and String(e.get("index", e.get("name", id))) != String(id):
			place = String(id)
	ok(place != "", "hay un lugar fuera del índice")
	if place == "":
		return
	Clipper.inject(s.st, s.repo, {"text": "Una línea cualquiera.", "place": place, "chron_date": "1891-05-04"})
	if not make(s):
		return
	nb.open("recortes")
	await frames()
	var page = nb.page("recortes")
	var want := String(ents[place].get("index", ents[place].get("name", place)))
	var lab := ""
	for o in page.menu_options("lugar"):
		if String(o.id) == place:
			lab = String(o.label)
	eq(lab, want, "el lugar fuera del índice se rotula como en el repo, no con su id")
	page.choose("lugar", place)
	var chip_texts: Array = page._chips.get_children().filter(func(b): return b is Button).map(func(b): return String(b.text))
	has(chip_texts, want, "también el chip del filtro")
	eq(nb.ent_label("no_existe_zz"), "no_existe_zz", "una entidad desconocida queda como está")

# GDD_v3 §6.3: sin pares. La tarjeta se arrastra como recorte (a las ranuras del expediente, al informe, a mostrar) y no
# recibe nada; el cuaderno no tiene formulario de cotejo ni la cinta del otro libro.
func test_cards_drag_but_never_link() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	var page = nb.page("recortes")
	var ids: Array = page.visible_ids()
	ok(ids.size() >= 2, "hay recortes")
	if ids.size() < 2:
		return
	var a = page.card(String(ids[0]))
	var b = page.card(String(ids[1]))
	var data = a._get_drag_data(Vector2.ZERO)
	eq(data, {"kind": "clip", "id": String(ids[0])}, "datos de arrastre §6.3")
	no(b.get_script().get_script_method_list().any(func(m): return String(m.name) == "_can_drop_data"), "nada se suelta sobre un recorte")
	no(nb.has_method("request_link"), "sin cotejos")
	no(nb.has_signal("linked"), "sin señal de pares")
	no(nb.find_child("CintaLibroMayor", true, false) != null, "sin la cinta del otro libro")
	eq(nb.overlay_panel(), null, "sin formulario")

func _line_by(who: String, text: String) -> String:
	for e in sim.q_diary():
		if String(e.kind) == "line" and String(e.get("who", "")) == who and String(e.parsed.plain).contains(text):
			return String(e.id)
	return ""

func _line_with(text: String) -> String:
	for e in sim.q_diary():
		if String(e.parsed.plain).contains(text):
			return String(e.id)
	return ""

func test_diary_rtl_matches_plain_and_speakers() -> void:
	if not make():
		return
	nb.open("diario")
	await frames()
	var d = nb.page("diario")
	for eid in d.row_ids():
		eq(d.rtl_of(eid).get_parsed_text(), d.parsed_of(eid).plain, "renglón %s idéntico al texto del sim" % eid)
	# los actos ciegos («private»: en casa, la tienda de Crane) van «sin marca alguna» (GDD§7.4): misma tinta que todos
	var kinds := {}
	for eid in d.row_ids():
		var k := String(d._rows[eid].entry.get("kind", ""))
		kinds[k] = true
		var rt: RichTextLabel = d.rtl_of(eid)
		eq(rt.modulate, Color(1, 1, 1, 1), "renglón %s (%s) sin atenuar" % [eid, k])
		eq(rt.self_modulate, Color(1, 1, 1, 1), "renglón %s (%s) sin tinte" % [eid, k])
		no(rt.has_theme_color_override("default_color"), "renglón %s (%s) sin color propio" % [eid, k])
	ok(kinds.has("line") and kinds.has("arrival"), "el diario tiene líneas dichas y llegadas: %s" % str(kinds.keys()))
	var w := _line_with("Era un sendero")
	ok(w != "", "línea de Watson en el diario")
	var row: Node = d._list.get_node("Fila_" + w.replace(".", "_"))
	ok(_labels_text(row).contains("Watson"), "quién habla, en el margen")
	var lis := _line_by("lisle", "La pared era a pique")
	var row2: Node = d._list.get_node("Fila_" + lis.replace(".", "_"))
	ok(_labels_text(row2).begins_with(ui_text("nb.diario.yo")), "Lisle es «Yo»")
	var arr := ""
	for e in sim.q_diary():
		if String(e.kind) == "arrival":
			arr = String(e.id)
	var row3: Node = d._list.get_node("Fila_" + arr.replace(".", "_"))
	ok(row3.find_child("Sello", true, false) != null, "sello en la llegada")

func test_diary_scissors_clip_keeps_origin() -> void:
	if not make():
		return
	nb.open("diario")
	await frames()
	var d = nb.page("diario")
	var eid := _line_with("Era un sendero")
	var plain: String = d.parsed_of(eid).plain
	var k := plain.find("Era un")
	var e := plain.find(".", k) + 1
	var got := []
	nb.clipped.connect(func(r): got.append(r))
	var n0: int = sim.q_clips().size()
	var r: Dictionary = d.clip_entry(eid, k, e - k)
	ok(r.ok, "recorte del diario: %s" % str(r))
	eq(sim.q_clips().size(), n0 + 1, "un recorte más")
	var c: Dictionary = sim.q_clip(String(r.clip))
	eq(c.text, "Era un sendero estrecho, señor Lisle.", "la tira")
	eq(c.origin, "S.L4.1.M", "conserva el origen de la escena (GDD§8.1)")
	eq(got.size(), 1, "señal clipped")
	# un error de forma se dice en la voz de Lisle
	var r2: Dictionary = d.clip_entry(eid, 0, plain.length())
	no(r2.ok, "dos oraciones y más de quince palabras: no se recorta")
	ok(nb.debug_state().note != "", "Lisle explica la forma")
	eq(nb.debug_state().note, nb.err_text(String(r2.get("err", ""))), "con el texto del error de forma")

func test_diary_scissors_by_mouse_drag() -> void:
	if not make():
		return
	nb.open("diario")
	nb._set_scissors(true)
	await frames(3)
	var d = nb.page("diario")
	ok(d.scissors, "tijera en la mano")
	# los días anteriores están plegados (GDD_v2 §C.3): se despliegan todos para encontrar el renglón
	for dd in d.debug_state().days:
		d._open_days[int(dd)] = true
	d.refresh()
	await frames(3)
	var eid := _line_with("Era un sendero")
	var rt: RichTextLabel = d.rtl_of(eid)
	d._scroll.ensure_control_visible(rt)
	await frames(3)
	ok(rt.selection_enabled, "con tijera, los renglones se seleccionan")
	var plain := rt.get_parsed_text()
	var k := plain.find("Era un")
	var e := plain.find(".", k) + 1
	var pts := SelectionMapper.drag_points(rt, k, e)
	var n0: int = sim.q_clips().size()
	_mm(pts[0], 0)
	await frames(1)
	_mb(pts[0], true)
	await frames(1)
	for i in range(1, 11):
		_mm(pts[0].lerp(pts[1], float(i) / 10.0))
		await frames(1)
	await tree.create_timer(0.15).timeout
	await frames(1)
	_mb(pts[1], false)
	await frames(4)
	eq(sim.q_clips().size(), n0 + 1, "arrastrar y soltar recorta el renglón")
	if sim.q_clips().size() > n0:
		var c: Dictionary = sim.q_clips()[sim.q_clips().size() - 1]
		ok(String(c.text).begins_with("Era un sendero"), "lo arrastrado: «%s»" % c.text)
	eq(d.rtl_of(eid).get_selected_text(), "", "la selección se limpia (y el diario se rehízo)")
	ok(nb.back(), "volver")
	no(d.scissors, "primero se deja la tijera")
	ok(nb.is_open(), "el cuaderno sigue abierto")

func _mb(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

var _last_mouse := Vector2.ZERO

func _mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last_mouse
	ev.button_mask = mask
	_last_mouse = pos
	Input.parse_input_event(ev)

func test_marginalia_without_counter() -> void:
	if not make():
		return
	var eggs: Array = repo().eggs()
	ok(eggs.size() >= 3, "hay huevos de pascua definidos")
	sim.st.world.eggs[String(eggs[0].id)] = {"tk": 41}
	sim.st.world.eggs[String(eggs[1].id)] = {"tk": 31}
	nb.open("marginalia")
	await frames()
	var st: Dictionary = nb.page("marginalia").debug_state()
	eq(st.notes, [String(eggs[1].id), String(eggs[0].id)], "en el orden en que se hallaron")
	var txt := _labels_text(nb.page("marginalia"))
	no(txt.contains(str(eggs.size())), "ningún total ni contador")
	no(txt.contains("/"), "nada de «n/m»")
	ok(txt.contains(String(eggs[0].name)), "título de la nota")

func test_back_order_and_close() -> void:
	if not make():
		return
	var closed := []
	nb.closed.connect(func(): closed.append(1))
	nb.open("recortes")
	await frames()
	ok(nb.is_open(), "abierto")
	ok(nb.back(), "volver")
	no(nb.is_open(), "cerrado")
	eq(closed.size(), 1, "señal closed")
	no(nb.back(), "cerrado: nada que volver")
	nb.toggle("indice")
	ok(nb.is_open() and nb.tab == "indice", "toggle abre en la pestaña pedida")

func test_layouts_and_theme() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	ok(nb.is_wide(), "a 1600×900 el libro es ancho")
	var r: Rect2 = nb.book_rect()
	ok(r.position.x > 100.0 and r.end.x < 1500.0, "centrado")
	nb.set_layout("left")
	await frames()
	var rl: Rect2 = nb.book_rect()
	ok(rl.end.x <= 800.0, "a la izquierda, junto al expediente (dos paneles como mucho)")
	no(nb.is_wide(), "angosto")
	var pst: Dictionary = nb.page("recortes").debug_state()
	eq(nb.page("recortes")._row2.visible, not (pst.menus as Array).is_empty(), "los filtros (si existen) pasan al segundo renglón")
	ok(nb.card_width() <= nb.body_width(), "las tarjetas caben en la hoja angosta")
	nb.set_layout("right")
	ok(nb.book_rect().position.x >= 800.0, "a la derecha")
	nb.set_layout("full")
	var ti = tree.root.get_node("ThemeInstaller")
	ti.set_high_contrast(true)
	await frames(3)
	eq(nb.debug_state().recortes.cards.size(), sim.q_clips().size(), "alto contraste: se rehace sin errores")
	ti.set_high_contrast(false)
	ti.set_text_scale(1.3)
	await frames(3)
	no(nb.is_wide(), "texto 1,3×: el epígrafe pasa debajo de la tira")
	eq(nb.debug_state().recortes.cards.size(), sim.q_clips().size(), "escala: se rehace sin errores")
	ti.set_text_scale(1.0)

# Nada se sale del libro: pestañas, «Volver» y barra de filtros caben en el ancho del libro en todas las disposiciones,
# también con el texto al máximo de accesibilidad (1,6×) y el libro acoplado a la izquierda (al lado del libro mayor).
func test_fits_book_at_every_scale_and_layout() -> void:
	if not make():
		return
	var ti = tree.root.get_node("ThemeInstaller")
	for sc in [1.0, 1.3, 1.6]:
		ti.set_text_scale(sc)
		for lay in ["full", "left"]:
			nb.set_layout(lay)
			nb.open("recortes")
			await frames(3)
			var bw: float = nb.book_rect().size.x
			var tabs_w: float = nb._tabs_row.get_combined_minimum_size().x
			ok(tabs_w <= bw + 0.5, "%s a %.1f×: pestañas y «Volver» caben (%d <= %d)" % [lay, sc, tabs_w, bw])
			var page = nb.page("recortes")
			var bar_w: float = page._bar_row.get_combined_minimum_size().x
			var avail: float = bw - nb.PAD * 2.0
			ok(bar_w <= avail + 0.5, "%s a %.1f×: búsqueda y filtros caben (%d <= %d)" % [lay, sc, bar_w, avail])
			ok(nb._close_btn.get_global_rect().end.x <= nb._book.get_global_rect().end.x + 0.5, "%s a %.1f×: «Volver» dentro del libro" % [lay, sc])
			for tb in Notebook.TABS:
				nb.show_tab(tb)
				await frames(2)
				var page_w: float = nb.page(tb).get_combined_minimum_size().x
				ok(page_w <= avail + 0.5, "%s a %.1f×: la página %s cabe (%d <= %d)" % [lay, sc, tb, page_w, avail])
			for tb in Notebook.TABS:
				ok(nb._tab_buttons[tb].get_theme_font_size("font_size") >= Notebook.TAB_FONT_MIN, "%s a %.1f×: pestaña %s legible" % [lay, sc, tb])
			if sc == 1.0:
				eq(nb._tabs_lead.custom_minimum_size.x, Notebook.TAB_LEAD, "%s a 1×: las pestañas empiezan en la línea roja" % lay)
				no(nb._tab_buttons["recortes"].has_theme_font_size_override("font_size"), "%s a 1×: letra del tema" % lay)
	ti.set_text_scale(1.0)
	nb.set_layout("full")

func test_empty_and_without_sim() -> void:
	var fresh = fresh_sim()
	if not make(fresh):
		return
	nb.open("recortes")
	await frames()
	eq(nb.debug_state().recortes.empty, ui_text("nb.vacio.recortes"), "cuaderno vacío: Lisle explica la tijera")
	eq(nb.debug_state().tabs, [], "partida nueva: sin pestañas, sólo la lista")
	no(nb.page("recortes").debug_state().search, "sin buscador")
	nb.show_tab("cotejos")
	await frames()
	eq(nb.tab, "recortes", "no hay pestaña de pares (v3)")
	nb.free()
	# sin partida (pantalla de título): nada se rompe
	nb = Notebook.new()
	nb.sounds = false
	tree.root.add_child(nb)
	for tb in Notebook.TABS:
		nb.open(tb)
		await frames(1)
	eq(nb.debug_state().recortes.cards, [], "sin sim: sin tarjetas")

func test_index_chip_drag_and_drop_on_tab() -> void:
	if not make():
		return
	nb.open("indice")
	await frames()
	var ch = nb.page("indice").chip("reichenbach")
	ok(ch != null, "Reichenbach en el índice")
	eq(ch._get_drag_data(Vector2.ZERO), {"kind": "ent", "id": "reichenbach"}, "chip del índice: {kind: ent}")
	var tb = nb._tab_buttons["recortes"]
	ok(tb._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"}), "se suelta en la pestaña Recortes")
	no(nb._tab_buttons["diario"]._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"}), "no en otra")
	tb._drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"})
	await frames()
	eq(nb.tab, "recortes", "va a Recortes")
	eq(nb.filters.lugar, "reichenbach", "filtra por lugar")
	nb.page("indice")._search.text = "watson"
	nb.page("indice")._search.text_changed.emit("watson")
	eq(nb.page("indice").debug_state().entries, ["watson"], "búsqueda en el índice")

func test_refreshes_on_game_signal() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames()
	var n0: int = nb.debug_state().recortes.cards.size()
	# acción hecha por fuera del cuaderno (p. ej. el lector): llega por Game.sim_changed
	var eid := _line_with("Le escribí")
	var plain := String(sim.q_diary().filter(func(e): return e.id == eid)[0].parsed.plain)
	var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "diary", "ref": eid}, "from": 0, "len": plain.length()})
	ok(r.ok, "recorte por fuera")
	nb._on_sim_changed("clip", {"id": r.clip})
	await frames(3)
	eq(nb.debug_state().recortes.cards.size(), n0 + 1, "la tarjeta nueva aparece")

# Arrastre nativo de verdad (eventos de mouse): recorte sobre recorte -> nada (sin pares); chip del índice -> pestaña.
func test_real_dnd_with_mouse_events() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames(3)
	var page = nb.page("recortes")
	var vis: Array = page.visible_ids()
	ok(vis.size() >= 2, "hay dos tarjetas a la vista")
	if vis.size() < 2:
		return
	var a: Control = page.card(String(vis[0])).strip
	var b: Control = page.card(String(vis[1])).strip
	var pa := a.get_global_rect().get_center()
	var pb := b.get_global_rect().get_center()
	_mm(pa, 0)
	await frames(1)
	_mb(pa, true)
	await frames(1)
	for i in range(1, 13):
		_mm(pa.lerp(pb, float(i) / 12.0))
		await frames(1)
	ok(tree.root.gui_is_dragging(), "arrastre nativo en curso")
	_mb(pb, false)
	await frames(3)
	eq(nb.overlay_panel(), null, "al soltar sobre otro recorte no pasa nada (v3: sin pares)")
	# chip del índice soltado en la pestaña Recortes
	nb.show_tab("indice")
	await frames(3)
	var ch: Control = nb.page("indice").chip("watson")
	var tb: Control = nb._tab_buttons["recortes"]
	var p0 := ch.get_global_rect().get_center()
	var p1 := tb.get_global_rect().get_center()
	_mm(p0, 0)
	await frames(1)
	_mb(p0, true)
	await frames(1)
	for i in range(1, 13):
		_mm(p0.lerp(p1, float(i) / 12.0))
		await frames(1)
	_mb(p1, false)
	await frames(3)
	eq(nb.tab, "recortes", "la pestaña recibió el chip")
	eq(nb.filters.persona, "watson", "y filtra")

# Volver: Esc y clic derecho sobre el cuaderno.
func _first_card_center() -> Vector2:
	var page = nb.page("recortes")
	for c in page.find_children("Recorte_*", "", true, false):
		if c is Control and (c as Control).is_visible_in_tree() and c.get("strip") != null:
			var r: Rect2 = (c.strip as Control).get_global_rect()
			if nb.book_rect().has_point(r.get_center()):
				return r.get_center()
	return Vector2(-1, -1)

func test_escape_and_right_click_back() -> void:
	if not make():
		return
	nb.open("recortes")
	await frames(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	var esc_up := InputEventKey.new()
	esc_up.keycode = KEY_ESCAPE
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	await frames(2)
	no(nb.is_open(), "Esc cierra")
	nb.open("recortes")
	await frames(2)
	# playtest v3: clic derecho SOBRE una tarjeta = «Tirar este recorte»; fuera de las tarjetas, volver
	var card_c := _first_card_center()
	if card_c.x >= 0.0:
		_mm(card_c, 0)
		await frames(2)
		var rcc := InputEventMouseButton.new()
		rcc.button_index = MOUSE_BUTTON_RIGHT
		rcc.pressed = true
		rcc.position = card_c
		rcc.global_position = card_c
		Input.parse_input_event(rcc)
		await frames(2)
		var rcc_up := rcc.duplicate()
		rcc_up.pressed = false
		Input.parse_input_event(rcc_up)
		await frames(2)
		ok(nb.is_open(), "clic derecho sobre una tarjeta no cierra el cuaderno")
		ok(nb.drop_menu() != null and nb.drop_menu().visible, "ofrece «Tirar este recorte»")
		if nb.drop_menu() != null:
			eq(nb.drop_menu().get_item_text(0), "Tirar este recorte")
			nb.drop_menu().hide()
		await frames(2)
	var p: Vector2 = nb.book_rect().position + Vector2(nb.PAD * 0.5, nb.book_rect().size.y - 12.0)
	_mm(p, 0)
	await frames(2)
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	rc.position = p
	rc.global_position = p
	Input.parse_input_event(rc)
	await frames(2)
	var rc_up := InputEventMouseButton.new()
	rc_up.button_index = MOUSE_BUTTON_RIGHT
	rc_up.pressed = false
	rc_up.position = p
	rc_up.global_position = p
	Input.parse_input_event(rc_up)
	await frames(2)
	no(nb.is_open(), "clic derecho cierra")

# Doble de Shell (protocolo por duck typing de ui/shell.gd): paneles abiertos y lector.
class FakeShell extends Node:
	signal panel_opened(kind: String)
	signal panel_closed(kind: String)
	var open_kinds := {}
	var reader_calls: Array = []
	func is_open(kind: String) -> bool:
		return open_kinds.has(kind)
	func open_reader(view: String) -> bool:
		reader_calls.append(view)
		return true

func test_shell_layout_and_source() -> void:
	if not make():
		return
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	nb.set_shell(sh)
	nb.open("recortes")
	await frames(2)
	eq(nb.layout, "full", "solo: centrado")
	ok(nb._velo.visible, "con velo")
	sh.open_kinds["dossier"] = true
	sh.panel_opened.emit("dossier")
	await frames(3)
	eq(nb.layout, "left", "con el expediente: a la izquierda")
	ok(nb.narrow, "y más angosto (la carpeta lleva dos páginas)")
	ok(nb.book_rect().end.x <= 1600.0 * 0.5, "deja más de media pantalla a la carpeta")
	no(nb._velo.visible, "sin velo (los dos a la vista)")
	no(nb._close_btn.visible, "junto a la carpeta, un solo «Volver» (el de la carpeta)")
	sh.open_kinds.erase("dossier")
	sh.panel_closed.emit("dossier")
	await frames(3)
	eq(nb.layout, "full", "se vuelve a centrar")
	no(nb.narrow)
	ok(nb._close_btn.visible, "solo, vuelve su «Volver»")
	# doble clic en una tarjeta: el original legible se abre en el lector; si no, Lisle
	var acc: Array = sim.q_accessible()
	var legible := ""
	for c in sim.q_clips():
		for a in acc:
			if String(a.view) == String(c.copy) and legible == "":
				legible = String(c.id)
	ok(legible != "", "algún recorte con su original a mano")
	var card = nb.page("recortes").card(legible)
	var dc := InputEventMouseButton.new()
	dc.button_index = MOUSE_BUTTON_LEFT
	dc.pressed = true
	dc.double_click = true
	card._gui_input(dc)
	eq(sh.reader_calls, [String(sim.q_clip(legible).copy)], "abre el lector en el original")
	nb.open_source("RC9999", "NO.EXISTE@BM")
	eq(nb.debug_state().note, ui_text("clip.inaccesible"), "lo que no está delante: Lisle")
	# un recorte de lámina: lo abre el Shell (source_requested -> open_plate); Lisle no lo da por inaccesible
	var plate := ""
	for c in sim.q_clips():
		if String(c.get("kind", "")) == "plate" and plate == "":
			plate = String(c.id)
	ok(plate != "", "hay un recorte de lámina en el recorrido")
	if plate != "":
		var pcopy := String(sim.q_clip(plate).copy)
		ok(not sim.q_plate(pcopy).is_empty(), "la lámina del recorte existe (%s)" % pcopy)
		nb._note.visible = false
		var reqs := []
		nb.source_requested.connect(func(i, cp): reqs.append([i, cp]))
		sh.reader_calls.clear()
		nb.page("recortes").card(plate)._gui_input(dc)
		eq(reqs, [[plate, pcopy]], "la lámina se pide al Shell")
		eq(sh.reader_calls, [], "no va al lector")
		eq(nb.debug_state().note, "", "Lisle no la da por inaccesible")
	# durante un arrastre el velo deja pasar el mouse (presentar sobre el 3D)
	nb.notification(Control.NOTIFICATION_DRAG_BEGIN)
	eq(nb._velo.mouse_filter, Control.MOUSE_FILTER_IGNORE, "velo transparente al arrastre")
	nb.notification(Control.NOTIFICATION_DRAG_END)
	eq(nb._velo.mouse_filter, Control.MOUSE_FILTER_STOP, "y vuelve")
	sh.free()

func test_ui_text_keys_exist() -> void:
	var keys := {}
	var re := RegEx.new()
	re.compile("\"(nb\\.[a-z_.0-9]+)\"")
	for f in DirAccess.get_files_at("res://ui/notebook"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://ui/notebook/" + f)
		for m in re.search_all(src):
			keys[m.get_string(1)] = true
	ok(keys.size() >= 20, "claves usadas: %d" % keys.size())
	var texts: Dictionary = repo().texts()
	for k in keys:
		if String(k).ends_with("."):
			continue
		if Notebook.TAB_FLAG.values().has(k) or ["nb.buscar", "nb.filtros", "nb.agrupar"].has(k) and not texts.has(k):
			continue   # banderas de q_ui (GDD_v2 §C.2), no claves de texto
		ok(texts.has(k), "ui_text tiene " + String(k))

# Doble de Shell con un panel de escena (banda al pie, capa 40) y su tijera.
class FakeScene extends CanvasLayer:
	var band: PanelContainer
	var cuts := 0
	func _init() -> void:
		layer = 40
		band = PanelContainer.new()
		band.anchor_left = 0.0
		band.anchor_right = 1.0
		band.anchor_top = 1.0
		band.anchor_bottom = 1.0
		band.offset_left = 24.0
		band.offset_right = -24.0
		band.offset_top = -286.0
		band.offset_bottom = -24.0
		add_child(band)
	func toggle_tijera() -> void:
		cuts += 1

class FakeShell2 extends FakeShell:
	var panels := {}
	func panel(kind: String):
		return panels.get(kind)

func test_shell_scene_band_scissors_and_right_click() -> void:
	if not make():
		return
	var sh := FakeShell2.new()
	tree.root.add_child(sh)
	var sc := FakeScene.new()
	tree.root.add_child(sc)
	await frames(2)
	nb.set_shell(sh)
	nb.handle_back = false
	nb.open("recortes")
	await frames(2)
	eq(nb.book_rect().end.y, 900.0 - 24.0, "sin escena: alto completo")
	# visita: la banda de la escena tapa el pie; el cuaderno acoplado termina arriba de ella
	sh.open_kinds["scene"] = true
	sh.panels["scene"] = sc
	sh.panel_opened.emit("scene")
	await frames(3)
	eq(nb.layout, "left", "con escena: a la izquierda (presentar = soltar sobre el 3D)")
	var top: float = sc.band.get_global_rect().position.y
	ok(nb.book_rect().end.y <= top - 8.0, "el libro no queda debajo de la banda (%s <= %s)" % [nb.book_rect().end.y, top])
	ok(nb._book.get_global_rect().end.y <= top - 8.0, "también el nodo del libro")
	# C con la escena debajo: la tijera es la de sus líneas
	nb.toggle_tijera()
	eq(sc.cuts, 1, "la tijera pasa a la escena")
	eq(nb.tab, "recortes", "el cuaderno no cambia de pestaña")
	sh.open_kinds.erase("scene")
	sh.panel_closed.emit("scene")
	await frames(3)
	eq(nb.layout, "full", "sin escena: centrado otra vez")
	eq(nb.book_rect().end.y, 900.0 - 24.0, "y alto completo")
	# C sin escena: el único papel recortable del cuaderno es el Diario
	nb.toggle_tijera()
	await frames(2)
	eq(nb.tab, "diario", "va al Diario")
	ok(nb.tijera, "con la tijera en la mano")
	nb.toggle_tijera()
	no(nb.tijera, "C otra vez la deja")
	nb.set_tijera(true)
	ok(nb.page("diario").scissors, "set_tijera")
	# con Shell (handle_back = false) el clic derecho sobre el cuaderno sigue siendo volver: primero la tijera
	var p: Vector2 = nb.book_rect().get_center()
	_mm(p, 0)
	await frames(2)
	_rclick(p)
	await frames(2)
	no(nb.tijera, "clic derecho: deja la tijera")
	ok(nb.is_open(), "y el cuaderno sigue abierto")
	_rclick(p)
	await frames(2)
	no(nb.is_open(), "clic derecho otra vez: cierra")
	# Esc con Shell: lo maneja la pila (no el cuaderno)
	nb.open("recortes")
	await frames(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	ok(nb.is_open(), "Esc con Shell: no lo cierra el cuaderno solo (la pila llama a back())")
	sh.free()
	sc.free()

func _rclick(p: Vector2) -> void:
	for pressed in [true, false]:
		var rc := InputEventMouseButton.new()
		rc.button_index = MOUSE_BUTTON_RIGHT
		rc.pressed = pressed
		rc.position = p
		rc.global_position = p
		Input.parse_input_event(rc)

func test_plate_thumb_and_empty_bar() -> void:
	if not make():
		return
	var plate := ""
	for c in sim.q_clips():
		if String(c.get("kind", "")) == "plate" and plate == "":
			plate = String(c.id)
	ok(plate != "", "hay un recorte de lámina en el recorrido")
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.2))
	var tex := ImageTexture.create_from_image(img)
	Notebook.store_thumb(plate, tex)
	nb.open("recortes")
	await frames(2)
	var card = nb.page("recortes").card(plate)
	var th: Node = card.strip.get_child(0).get_child(0)
	eq(th.get("tex"), tex, "la tarjeta usa la miniatura guardada (captura del rectángulo)")
	Notebook.thumbs.erase(plate)
	ok(nb.page("recortes")._bar_row.visible, "con recortes: búsqueda y filtros")
	nb.free()
	var fresh = fresh_sim()
	if not make(fresh):
		return
	nb.open("recortes")
	await frames(2)
	no(nb.page("recortes")._bar_row.visible, "sin recortes: nada que buscar (la página sólo dice cómo se recorta)")

# ------------------------------------------------------------------ tarjetas (GDD_v3 §6.2), con el doble suelto
func _fake_nb() -> Array:
	var f = Fake.new(null, repo())
	var ids: Array = []
	ids.append(f.add_clip({"text": "Una ojeada me bastó para ver que la senda terminaba de pronto en la pared.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», crónica", "ents": ["reichenbach", "watson"]}))
	ids.append(f.add_clip({"text": "uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince dieciséis",
		"origin": "D05", "doc": "D05", "src_line": "Journal de Genève · prensa extranjera", "ents": []}))
	ids.append(f.add_clip({"text": "Aviso: se busca testigo.", "origin": "D23", "doc": "D23", "src_line": "Encargo del señor Pell", "ents": ["reichenbach"]}))
	nb = Notebook.new()
	nb.sim_override = f
	nb.act_fn = func(a): return f.apply(a)
	nb.sounds = false
	tree.root.add_child(nb)
	return [f, ids]

func test_cards_look_like_cards() -> void:
	var fx := _fake_nb()
	var ids: Array = fx[1]
	nb.open("recortes")
	await frames(3)
	var page = nb.page("recortes")
	eq(page._list.get_theme_constant("separation"), 10, "10 px entre tarjetas")
	var card = page.card(String(ids[0]))
	var sb: StyleBox = card.strip.get_theme_stylebox("panel")
	ok(sb is StyleBoxFlat, "papel con borde")
	if sb is StyleBoxFlat:
		eq((sb as StyleBoxFlat).border_width_left, 1, "borde de 1 px")
		eq((sb as StyleBoxFlat).border_width_top, 1)
		eq(int(sb.content_margin_left), 8, "8 px de margen interno")
		eq(int(sb.content_margin_top), 8)
	var body: RichTextLabel = card.strip.find_child("Texto", true, false)
	var src: Label = card.strip.find_child("Fuente", true, false)
	ok(body != null and src != null, "texto y línea de fuente")
	if body != null and src != null:
		eq(body.get_parsed_text(), "Una ojeada me bastó para ver que la senda terminaba de pronto en la pared.", "el texto entero")
		eq(src.text, "«El problema final», crónica", "la fuente")
		var k := float(src.get_theme_font_size("font_size")) / float(body.get_meta("fe_size", body.get_theme_font_size("normal_font_size")))
		ok(k > 0.6 and k < 0.8, "la fuente en letra chica (≈70 %%): %.2f" % k)
	var labels: Array = ClipCard.entity_labels(nb.sim().q_clip(String(ids[0])))
	eq(labels.size(), 2)
	eq(card.strip.tooltip_text, "; ".join(PackedStringArray(labels)), "las entidades, sólo al pasar el mouse")
	no(_labels_text(card).contains(String(labels[1])), "no a la vista")
	var long_card = page.card(String(ids[1]))
	var lt: RichTextLabel = long_card.strip.find_child("Texto", true, false)
	eq(lt.get_parsed_text().replace("…", "").strip_edges().split(" ", false).size(), 15, "ningún recorte mostrado pasa de 15 palabras")
	eq(page.card(String(ids[2])).strip.tooltip_text, ClipCard.entity_labels(nb.sim().q_clip(String(ids[2])))[0])

func test_cards_fit_and_no_pair_tab_with_fake() -> void:
	_fake_nb()
	nb.open("recortes")
	await frames(3)
	no(nb.available_tabs().has("cotejos"), "sin pestaña de pares")
	for lay in ["full", "left"]:
		nb.set_layout(lay)
		await frames(2)
		for id in nb.page("recortes").visible_ids():
			var c = nb.page("recortes").card(String(id))
			ok(c.strip.size.x <= nb.body_width() + 0.5, "%s: la tarjeta cabe en la hoja" % lay)
