# Tests del cuaderno (W3-NOTEBOOK, ARCHITECTURE §6.5, §6.1, §6.3; GDD§14.1, §8.1–8.3, §7.4, §13).
# Modelo puro (ui/notebook/notebook_model.gd) y la UI headless sobre la GameSim REAL del recorrido de integración
# (datos estructurales de data/ + tests/fixtures/integ: 17 recortes, un par, diario con llegadas y líneas dichas).
# Capturas: devtools/drivers/w3notebook_shots.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const Model = preload("res://ui/notebook/notebook_model.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")
const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

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

# GameSim real del recorrido de integración (prólogo -> amanecer del día 4): el recorrido se hace una vez por proceso
# (tests/fixtures/w3notebook/nb_walk.gd, dataset temporal propio del proceso) y cada test recibe un replay nuevo.
func walk():
	var s = NbWalk.sim()
	ok(s != null, "recorrido de integración sin errores: %s" % str(NbWalk.errs))
	return s

# Partida recién empezada (prólogo) sobre el mismo dataset.
func fresh_sim():
	var r = NbWalk.repo()
	ok(r != null, "dataset del recorrido: %s" % str(NbWalk.errs))
	return GameSim.new(r, 7) if r != null else null

func make(p_sim = null) -> void:
	sim = p_sim if p_sim != null else walk()
	nb = Notebook.new()
	nb.sim_override = sim
	nb.act_fn = func(a): return sim.apply(a)
	nb.sounds = false
	tree.root.add_child(nb)

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
	make()
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
	eq(st.cotejos.pairs.size(), sim.q_pairs().size(), "un cotejo por par")
	eq(st.diario.rows.size(), sim.q_diary().size(), "un renglón por línea del diario")
	var arrivals: int = sim.q_diary().filter(func(e): return String(e.kind) == "arrival").size()
	ok(arrivals > 0, "hay llegadas en el recorrido")
	eq(st.diario.stamps, arrivals, "cada llegada lleva su sello «Recibido»")
	eq(st.marginalia.notes, [], "sin huevos hallados, Curiosidades vacía")
	no(nb._tab_buttons["marginalia"].visible, "sin huevos hallados, la pestaña de Curiosidades no está a la vista")

func test_clips_grouped_and_margin_dates() -> void:
	make()
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
			eq(card.margin_label.text, str(d.substr(8, 2).to_int()), "día de la crónica en el margen")
			seen[d] = true
	# epígrafe y línea de fuente de cada tarjeta
	var c0 = page.card("RC0007")
	ok(c0 != null, "RC0007 tiene tarjeta")
	if c0 != null:
		var texts := _labels_text(c0)
		ok(texts.contains(Model.caption_text(sim.q_clip("RC0007"))), "epígrafe visible")
		ok(texts.contains(String(sim.q_clip("RC0007").src_line)), "línea de fuente visible")

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
	make()
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
	make(s)
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

func test_drag_clip_onto_clip_links_with_note() -> void:
	make()
	nb.open("recortes")
	await frames()
	var page = nb.page("recortes")
	var a = page.card("RC0007")
	var b = page.card("RC0002")
	var data = a._get_drag_data(Vector2.ZERO)
	eq(data, {"kind": "clip", "id": "RC0007"}, "datos de arrastre §6.3")
	ok(b._can_drop_data(Vector2.ZERO, data), "se suelta sobre otro recorte")
	no(a._can_drop_data(Vector2.ZERO, data), "no sobre sí mismo")
	no(b._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "watson"}), "un chip del índice no se coteja")
	var linked := []
	nb.linked.connect(func(p): linked.append(p))
	var before: int = sim.q_pairs().size()
	b._drop_data(Vector2.ZERO, data)
	await frames()
	var form = nb.overlay_panel()
	ok(form != null and String(form.name) == "FormCotejo", "formulario del cotejo")
	eq(sim.q_pairs().size(), before, "nada se vincula antes de confirmar")
	form.get_meta("note_edit").text = "contradice"
	form._decide(true)
	await frames(3)
	eq(sim.q_pairs().size(), before + 1, "par creado")
	var p: Dictionary = sim.q_pairs()[sim.q_pairs().size() - 1]
	eq([p.a, p.b, p.note], ["RC0007", "RC0002", "contradice"], "par con su nota libre")
	eq(linked, [p.id], "señal linked")
	nb.show_tab("cotejos")
	await frames()
	has(nb.page("cotejos").debug_state().pairs, p.id, "el par está en Cotejos")
	var pc = nb.page("cotejos").card(p.id)
	eq(pc._get_drag_data(Vector2.ZERO), {"kind": "pair", "id": p.id}, "el par se arrastra (ranura «según», presentar)")
	ok(_labels_text(pc).contains("contradice"), "la nota a lápiz se ve")
	# volver sin cotejar
	b = nb.page("recortes").card("RC0003")
	nb.request_link("RC0004", "RC0003")
	await frames()
	nb.overlay_panel()._decide(false)
	await frames()
	eq(sim.q_pairs().size(), before + 1, "«Volver» no vincula")

func test_link_errors_in_lisle_voice() -> void:
	make()
	nb.open("recortes")
	await frames()
	nb.request_link("RC0002", "RC0002")
	eq(nb.debug_state().note, ui_text("nb.err.mismo"), "consigo mismo")
	var pid := String(sim.q_pairs()[0].id)
	nb.request_link(pid, "RC0002")
	await frames()
	eq(nb.debug_state().note, ui_text("clip.anidado"), "los pares no se anidan (lo decide el sim)")
	no(nb.debug_state().overlay, "sin formulario")

func test_unlink_needs_confirmation() -> void:
	make()
	nb.open("cotejos")
	await frames()
	var pid := String(sim.q_pairs()[0].id)
	var tinta := false
	for eid in sim.st.ded.entries:
		var e: Dictionary = sim.st.ded.entries[eid]
		for ln in e.lines:
			if ln.support.has(pid) and String(e.get("ink", "")) == "tinta":
				tinta = true
	nb.request_unlink(pid)
	await frames()
	eq(String(nb.overlay_panel().name), "FormSeparar", "confirmación en dos pasos")
	nb.overlay_panel()._decide(false)
	await frames()
	eq(sim.q_pairs().size(), 1, "«Volver» no separa")
	nb.request_unlink(pid)
	await frames()
	nb.overlay_panel()._decide(true)
	await frames()
	if tinta:
		eq(sim.q_pairs().size(), 1, "un par que sostiene tinta no se separa")
		eq(nb.debug_state().note, ui_text("nb.err.en_tinta"), "Lisle lo dice")
	else:
		eq(sim.q_pairs().size(), 0, "separado")
		if nb.tab_available("cotejos"):
			eq(nb.page("cotejos").debug_state().empty, ui_text("nb.vacio.cotejos"), "página vacía explica la forma")
		else:
			eq(nb.tab, "recortes", "sin pares (bandera apagada): vuelve a Recortes")

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
	make()
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
	ok(kinds.has("private") and kinds.has("act"), "el recorrido tiene actos públicos y ciegos: %s" % str(kinds.keys()))
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
	make()
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
	no(r2.ok, "cruza un punto")
	eq(nb.debug_state().note, ui_text("clip.cruza_oracion"), "Lisle explica la forma")

func test_diary_scissors_by_mouse_drag() -> void:
	make()
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
	make()
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
	make()
	var closed := []
	nb.closed.connect(func(): closed.append(1))
	nb.open("recortes")
	await frames()
	ok(nb.is_open(), "abierto")
	nb.request_link("RC0002", "RC0003")
	await frames()
	ok(nb.debug_state().overlay, "formulario")
	ok(nb.back(), "volver")
	no(nb.debug_state().overlay, "primero se cierra el formulario")
	ok(nb.is_open(), "sigue abierto")
	ok(nb.back(), "volver otra vez")
	no(nb.is_open(), "cerrado")
	eq(closed.size(), 1, "señal closed")
	no(nb.back(), "cerrado: nada que volver")
	nb.toggle("indice")
	ok(nb.is_open() and nb.tab == "indice", "toggle abre en la pestaña pedida")

func test_layouts_and_theme() -> void:
	make()
	nb.open("recortes")
	await frames()
	ok(nb.is_wide(), "a 1600×900 el libro es ancho")
	var r: Rect2 = nb.book_rect()
	ok(r.position.x > 100.0 and r.end.x < 1500.0, "centrado")
	nb.set_layout("left")
	await frames()
	var rl: Rect2 = nb.book_rect()
	ok(rl.end.x <= 800.0, "a la izquierda, junto al libro mayor (dos paneles como mucho)")
	no(nb.is_wide(), "angosto")
	var pst: Dictionary = nb.page("recortes").debug_state()
	eq(nb.page("recortes")._row2.visible, not (pst.menus as Array).is_empty(), "los filtros (si existen) pasan al segundo renglón")
	# angosto: las tiras del par una bajo la otra, y el sujetapapeles en el margen (se ve qué dos tiras forman el par)
	nb.show_tab("cotejos")
	await frames()
	var pid0 := String(sim.q_pairs()[0].id)
	ok(nb.page("cotejos").card(pid0).find_child("Sujetapapeles", true, false) != null, "sujetapapeles en el margen")
	nb.show_tab("recortes")
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
	make()
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
	make(fresh)
	nb.open("recortes")
	await frames()
	eq(nb.debug_state().recortes.empty, ui_text("nb.vacio.recortes"), "cuaderno vacío: Lisle explica la tijera")
	eq(nb.debug_state().tabs, [], "partida nueva: sin pestañas, sólo la lista")
	no(nb.page("recortes").debug_state().search, "sin buscador")
	nb.show_tab("cotejos")
	await frames()
	eq(nb.tab, "recortes", "sin pares no hay pestaña de pares")
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
	make()
	nb.open("indice")
	await frames()
	var ch = nb.page("indice").chip("reichenbach")
	ok(ch != null, "Reichenbach en el índice")
	eq(ch._get_drag_data(Vector2.ZERO), {"kind": "ent", "id": "reichenbach"}, "chip del índice: {kind: ent}")
	var tb = nb._tab_buttons["recortes"]
	ok(tb._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"}), "se suelta en la pestaña Recortes")
	no(nb._tab_buttons["cotejos"]._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"}), "no en otra")
	tb._drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"})
	await frames()
	eq(nb.tab, "recortes", "va a Recortes")
	eq(nb.filters.lugar, "reichenbach", "filtra por lugar")
	nb.page("indice")._search.text = "watson"
	nb.page("indice")._search.text_changed.emit("watson")
	eq(nb.page("indice").debug_state().entries, ["watson"], "búsqueda en el índice")

func test_refreshes_on_game_signal() -> void:
	make()
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

# Arrastre nativo de verdad (eventos de mouse): recorte sobre recorte -> formulario -> par; chip del índice -> pestaña.
func test_real_dnd_with_mouse_events() -> void:
	make()
	nb.open("recortes")
	await frames(3)
	var page = nb.page("recortes")
	var a: Control = page.card("RC0003").strip
	var b: Control = page.card("RC0004").strip
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
	var form = nb.overlay_panel()
	ok(form != null and String(form.name) == "FormCotejo", "al soltar, el formulario del cotejo")
	if form != null:
		eq(form.get_meta("pair"), ["RC0003", "RC0004"], "arrastrado sobre destino")
		nb.back()
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
func test_escape_and_right_click_back() -> void:
	make()
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
	var p: Vector2 = nb.book_rect().get_center()
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
	make()
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	nb.set_shell(sh)
	nb.open("recortes")
	await frames(2)
	eq(nb.layout, "full", "solo: centrado")
	ok(nb._velo.visible, "con velo")
	sh.open_kinds["ledger"] = true
	sh.panel_opened.emit("ledger")
	await frames(3)
	eq(nb.layout, "left", "con el libro mayor: a la izquierda")
	no(nb._velo.visible, "sin velo (los dos libros a la vista)")
	sh.open_kinds.erase("ledger")
	sh.panel_closed.emit("ledger")
	await frames(3)
	eq(nb.layout, "full", "se vuelve a centrar")
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
	make()
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
	make()
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
	var th: Node = card.strip.get_child(0)
	eq(th.get("tex"), tex, "la tarjeta usa la miniatura guardada (captura del rectángulo)")
	Notebook.thumbs.erase(plate)
	ok(nb.page("recortes")._bar_row.visible, "con recortes: búsqueda y filtros")
	nb.free()
	var fresh = fresh_sim()
	make(fresh)
	nb.open("recortes")
	await frames(2)
	no(nb.page("recortes")._bar_row.visible, "sin recortes: nada que buscar (la página sólo dice cómo se recorta)")
