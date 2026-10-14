# Tests de W4-EPILOGUE (ui/epilogue/*; ARCHITECTURE §2.3, §4.15; GDD §12.1–12.3): vista-modelo (variantes acumulables
# de epilogo.json según el final, la noche del jueves, la escena del final, el corte, el lápiz azul, láminas y tomos del
# estante) y la pantalla completa en headless (noche -> final -> ficha -> 1903 -> lectura -> tijera -> concordancia ->
# colofón -> lápiz azul -> leave). Data real; las partidas las juegan los bots (deductor -> F1, pasivo -> F4).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const GameSim = preload("res://core/sim/game_sim.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const Model = preload("res://ui/epilogue/epilogue_model.gd")
const Screen = preload("res://ui/epilogue/epilogue_screen.gd")
const Credits = preload("res://ui/epilogue/credits.gd")
const BluePencil = preload("res://ui/epilogue/blue_pencil.gd")
const ExpModel = preload("res://ui/expediente/expediente_model.gd")
const ExpFake = preload("res://devtools/drivers/v3exp_fake.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const SelMap = preload("res://ui/reader/selection_mapper.gd")

static var _cache := {}

func _to_epilogue(bot: String, seed: int):
	var r = repo()
	var b = RunBots.make(bot)
	var sim = GameSim.new(r, seed)
	b.budget_ms = 120000
	b.setup(sim, seed)
	for i in 20000:
		if String(sim.q_clock().phase) == "epilogue":
			break
		if not b.step():
			break
	return sim

# Partida fresca (las que mutan) o la cacheada (sólo lectura).
func _sim(bot: String, seed := 1, fresh := false):
	if fresh:
		return _to_epilogue(bot, seed)
	var k := "%s.%d" % [bot, seed]
	if not _cache.has(k):
		_cache[k] = _to_epilogue(bot, seed)
	return _cache[k]

func _ready_or_skip(sim) -> bool:
	if sim == null or String(sim.q_clock().phase) != "epilogue":
		skip("el bot no llegó al epílogo")
		return false
	if not repo().texts().has("epilogo.03.leer") or repo().doc("D38").is_empty():
		pending_content("falta el texto del epílogo (epilogo.json / D38)")
		return false
	return true

func _keys(beats: Array) -> Array:
	return beats.map(func(b): return String(b.key))

# ------------------------------------------------------------------ vista-modelo
func test_f1_paragraphs_and_variants() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var inf := Model.info(sim)
	eq(String(inf.ending), "F1", "el deductor llega a F1")
	no(bool(inf.offer), "F1: no se ofrece publicar")
	var b := Model.reading_beats(sim)
	var k := _keys(b)
	eq(String(b[0].kind), "date", "la fecha encabeza el diario")
	has(k, "epilogo.02.llega@nota_de_s_h", "F1: la Strand llega por correo (reemplazo @)")
	no(k.has("epilogo.02.llega"), "el reemplazo quita la base")
	var i_llega := k.find("epilogo.02.llega@nota_de_s_h")
	eq(String(b[i_llega + 1].kind), "line", "después de la llegada, Crane (escena EPI)")
	var i04 := k.find("epilogo.04.park_lane")
	ok(i04 >= 0, "Park Lane")
	for v in ["teoria_correcta", "nota_de_s_h"]:
		ok(k.find("epilogo.04.park_lane+" + v) > i04, "variante agregada después de la base: " + v)
	# GDD_v3 §1.4/§3.6: el librero (V.C12) y los tomos (V.C14) ya no son preguntas: sus variantes siguen a sus flags
	var fl: Dictionary = sim.st.flags
	eq(k.has("epilogo.04.park_lane+reconoce_los_libros"), bool(fl.get("vio_libros_park", false)), "V.C12 sigue a vio_libros_park")
	if k.has("epilogo.04.park_lane+reconoce_los_libros"):
		ok(k.find("epilogo.04.park_lane+reconoce_los_libros") < k.find("epilogo.04.park_lane+teoria_correcta"), "orden de endings.json")
	eq(k.has("epilogo.05.hueco+tomos_devueltos"), bool(fl.get("curiosidad_tomos", false)), "V.C14 sigue a curiosidad_tomos")
	has(k, "epilogo.11.noche+noche_baker_street", "la noche que eligió")
	no(k.has("epilogo.11.noche+times_del_viernes"))
	has(k, "epilogo.12.publicar+nota_de_s_h", "F1: silencio hasta que el autor lo autorice")
	no(k.has("epilogo.06.desmayo+subraya_first_and_last"), "sin watson_expuesto no subraya")
	for x in b:
		no(String(x.kind) == "offer", "sin oferta en F1")
		ok(String(x.parsed.get("plain", "")) != "" and (x.parsed.get("errors", []) as Array).is_empty(), "texto parseado: %s" % x.key)
	eq(String(b[k.find("epilogo.04.park_lane")].lens), "hombre_alto", "la lupa se posa en el hombre alto")
	var c := _keys(Model.closing_beats(sim))
	eq(c, ["epilogo.13.tijera", "epilogo.14.ficha"], "cierre sin posdata (no publicó)")
	eq(String(Model.closing_beats(sim)[1].kind), "ficha")

func test_f4_offer_and_publish_yes() -> void:
	var sim = _sim("pasivo", 1, true)
	if not _ready_or_skip(sim):
		return
	var inf := Model.info(sim)
	eq(String(inf.ending), "F4")
	ok(bool(inf.offer), "F4: se ofrece publicar")
	var b := Model.reading_beats(sim)
	var k := _keys(b)
	has(k, "epilogo.02.llega")
	has(k, "epilogo.11.noche+times_del_viernes", "noche en casa")
	var off := b.filter(func(x): return String(x.kind) == "offer")
	eq(off.size(), 1, "una oferta")
	eq(String(off[0].yes), repo().text("epilogo.12.publicar.si"))
	no(k.has("epilogo.12.publicar+nota_de_s_h"))
	ok(bool(sim.apply({"t": "publish_errata", "yes": true}).ok))
	no(bool(Model.info(sim).offer), "decidido: ya no se ofrece")
	var c := _keys(Model.closing_beats(sim))
	has(c, "epilogo.15.posdata+resena_romance", "publicar -> reseña: la verdad se lee como ficción")
	no(_keys(Model.reading_beats(sim)).has("epilogo.12.publicar.guardada"))

func test_f4_publish_no() -> void:
	var sim = _sim("pasivo", 2, true)
	if not _ready_or_skip(sim):
		return
	ok(bool(sim.apply({"t": "publish_errata", "yes": false}).ok))
	var k := _keys(Model.reading_beats(sim))
	has(k, "epilogo.12.publicar.guardada", "no publicar -> la deja en el cajón")
	no(_keys(Model.closing_beats(sim)).has("epilogo.15.posdata+resena_romance"))

func test_cut_target_and_hits() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var t := Model.cut_target(sim)
	ok(String(t.get("text", "")).begins_with("Un hombre alto y delgado"), "el corte es el hombre alto: %s" % str(t))
	eq(String(t.view), "D38@L1")
	var v := Model.strand_view(sim)
	var plain := String(v.pages[int(t.page)][0].parsed.plain)
	eq(plain.substr(int(t.from), int(t.to) - int(t.from)), String(t.text), "mismos índices en la vista y en el documento")
	ok(Model.hits_cut(sim, int(t.page), int(t.from) + 4, 6), "una palabra basta")
	var cur := Model.tramo_at(sim, "curiosos")
	no(Model.hits_cut(sim, int(cur.page), int(cur.from), int(cur.to) - int(cur.from)), "otra oración no")
	no(Model.hits_cut(sim, int(t.page) + 1, int(t.from), 10), "otra hoja no")
	var hueco := Model.tramo_at(sim, "hueco")
	eq(int(hueco.page), 1, "el hueco está en la segunda hoja")

func test_night_lines() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var n := Model.night(sim)
	eq(String(n.place), "L3", "Baker Street")
	eq(int(n.tk), TimeKey.tk(10, "night"))
	var ids: Array = n.lines.map(func(l): return String(l.id))
	eq(ids, ["bs_frio", "bs_ventana", "bs_arpa", "bs_vidrio", "bs_silbato", "bs_inspector"])
	eq(n.lines[3].sounds, ["shot.silbido", "glass.tintineo"], "el silbido y el vidrio")
	eq(String(n.lines[4].frame), "camden", "el silbato: la casa vacía de enfrente")
	var au := tree.root.get_node_or_null("Audio")
	if au != null:
		for l in n.lines:
			for s in l.sounds:
				ok(au.has_sound(String(s)), "sonido existe: " + String(s))
	var p = _sim("pasivo")
	var n2 := Model.night(p)
	eq(String(n2.place), "L1")
	eq(n2.lines.size(), 4, "noche en casa")

func test_end_scene_lines() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var ids: Array = Model.end_lines(sim).map(func(l): return String(l.id))
	has(ids, "nada", "las doce selladas: «Hum. Nada que corregir»")
	no(ids.has("corrige"))
	var p = _sim("pasivo")
	eq(Model.end_lines(p).size(), 5, "END.F4")

# ------------------------------------------------------------------ lápiz azul (UI-EXPEDIENTE, GDD_v3 §6.10)
# El expediente devuelto: cada hoja nacida (en tinta: el texto de Lisle; a lápiz: respuesta y pruebas), con las notas
# azules de q_blue_pencil al margen de su pregunta ({kind, q, note}; una hoja completa que no cierra trae «Falta» y
# «Corríjalo»), tachado en la que no cierra, firma según haya o no algo que corregir. Doble suelto (sin bots).
func _pencil_fake():
	var f = ExpFake.new(null, repo())
	var a: String = f.add_clip({"text": "La senda termina de pronto en la pared.", "origin": "D03", "doc": "D03", "src_line": "x"})
	var b: String = f.add_clip({"text": "Une marque fraîche sur la roche.", "origin": "D05", "doc": "D05", "src_line": "y"})
	f.options = [{"id": "raspadura", "label": "Raspadura", "kind": "concepto"}, {"id": "sendero", "label": "Sendero", "kind": "lugar"}]
	f.add_question({"id": "Q1", "text": "¿Qué no contó Watson?", "ink_text": "Watson vio en la roca una raspadura fresca."})
	f.add_question({"id": "Q2", "text": "¿Qué pasó en la cascada?"})
	f.add_question({"id": "Q3", "text": "¿Quién me escribe las cartas sin firma?"})
	f.ink("Q1", "raspadura", [a, b])
	f.drafts["Q2"] = {"answer": "sendero", "proofs": [a, b]}
	f.blue = [{"kind": "missing", "q": "Q2", "note": "Falta: lo que no se ve desde el sendero."},
		{"kind": "wrong", "q": "Q2", "note": "Corríjalo: la cornisa no se ve desde el sendero."},
		{"kind": "missing", "q": "Q3", "note": "Falta: de quién es la mano que escribe a máquina."}]
	return f

func test_pencil() -> void:
	var f = _pencil_fake()
	var v := ExpModel.pencil(f)
	eq(v.rows.map(func(r): return r.q), ["Q1", "Q2", "Q3"], "toda hoja nacida: primero las de tinta")
	eq(String(v.rows[0].state), "tinta")
	eq(String(v.rows[0].ink_text), "Watson vio en la roca una raspadura fresca.", "en tinta, el texto de Lisle")
	eq(v.rows[1].notes, ["Falta: lo que no se ve desde el sendero.", "Corríjalo: la cornisa no se ve desde el sendero."], "las dos notas de la hoja que no cierra")
	ok(bool(v.rows[1].wrong), "Q2 no cierra")
	no(bool(v.rows[2].wrong), "Q3 sólo falta")
	eq(int(v.wrong_n), 1)
	eq(String(v.sign), repo().text("epilogo.lapiz.firma_corrijase"))
	eq(String(v.header), repo().text("exp.lapiz.encabezado"), "el encabezado habla del expediente")
	no(String(v.header).to_lower().contains("conclusi"), "sin «libro de conclusiones» (GDD_v3 §0.2)")
	no(bool(v.nothing))
	ok(ExpModel.draft_summary(f, v.rows[1]).contains("Sendero"), "el borrador a lápiz con su respuesta")
	f.blue = []
	var w := ExpModel.pencil(f)
	ok(bool(w.nothing), "nada que corregir")
	eq(String(w.sign), repo().text("epilogo.lapiz.firma_tirese"))
	var e := ExpModel.pencil(ExpFake.new(null, repo()))
	eq(e.rows, [], "sin preguntas")
	eq(String(e.empty), repo().text("exp.lapiz.sin_preguntas"))

func test_pencil_wrong_entries_get_notes() -> void:
	var f = _pencil_fake()
	var bp = BluePencil.new()
	bp.fast = true
	tree.root.add_child(bp)
	bp.open(f, null)
	bp.start()
	for n in ["Falta: lo que no se ve desde el sendero.", "Corríjalo: la cornisa no se ve desde el sendero.", "Falta: de quién es la mano que escribe a máquina."]:
		has(bp.notes(), n, "la nota azul se muestra")
	var strikes: Array = bp.find_children("Tachado", "", true, false)
	eq(strikes.size(), 1, "un tachado: la hoja que no cierra")
	ok(bp.find_child("Hoja_Q2", true, false).is_ancestor_of(strikes[0]), "sobre Q2")
	var strike = strikes[0]
	if strike.label != null and strike.label.has_method("get_character_bounds"):
		for _f in 3:
			await tree.process_frame
		var rs: Array = strike.rows()
		eq(rs.size(), strike.label.get_line_count(), "un trazo por renglón (no uno entre renglones)")
		for r in rs:
			ok(float(r.x1) > float(r.x0) + 20.0, "el trazo cubre el texto del renglón: %s" % str(r))
	ok(bp.close_rect().size.x > 0.0, "«Cerrar» a la vista")
	bp.free()

func test_page_marks_and_snapshot_and_shelf() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var marks := Model.page_marks(sim)
	eq(marks.map(func(m): return String(m.kind)), ["nota_azul"], "F1: la nota azul de S. H.")
	eq(String(marks[0].tramo), "hombre_alto")
	var snap := Model.snapshot(sim, "L3", "calle", TimeKey.tk(10, "night"), "night", "221b")
	has(snap.nodes, "silueta_ventana", "la silueta en la persiana la noche del 5")
	has(snap.nodes, "parker")
	var day := Model.snapshot(sim, "L3", "calle", TimeKey.tk(9, "M"), "M", "221b")
	no(day.nodes.has("silueta_ventana"))
	var vols := Model.shelf_volumes(repo().place("L4"), "biblioteca", 5)
	eq(vols.size(), 5, "cinco tomos")
	for b in vols:
		ok(b.pos.x > 0.12 and b.pos.x < 0.45, "dentro del hueco: %s" % str(b.pos))
		ok(b.pos.y - b.size.y / 2.0 > 1.3 and b.pos.y + b.size.y / 2.0 < 1.75, "sobre el segundo estante: %s" % str(b.pos))

func test_credits_strips() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var c = Credits.new()
	tree.root.add_child(c)
	c.fast = true
	c.open(sim, null)
	c.fast = true
	var fin := [false]
	c.finished.connect(func(): fin[0] = true)
	c.start()
	eq(c.strips().size(), 1, "una tira por corte")
	c.click()
	eq(c.strips().size(), 2)
	c.skip()
	eq(c.strips().size(), Model.credits(sim).size(), "todo el colofón")
	ok(c.strips().size() >= 10)
	ok(fin[0], "termina")
	# el colofón entero cabe en la pantalla (1600×900 lógicos como mínimo, stretch canvas_items/expand)
	var box: Control = c._box
	for _f in 8:
		await tree.process_frame
	# (la vista headless no es 1600×900: se mide el alto del colofón, que se centra)
	ok(box.get_combined_minimum_size().y <= 900.0 - 2.0 * 36.0, "el colofón cabe en 900 px de alto: %s" % str(box.get_combined_minimum_size()))
	c.free()

# ------------------------------------------------------------------ pantalla completa (headless, sin Shell)
func _screen(sim):
	var s = Screen.new()
	s.sim = sim
	s.fast = true
	s.sounds = false
	tree.root.add_child(s)
	s.start()
	return s

func _run_beats(s, until_stage: String, seen: Array, guard := 200) -> void:
	for i in guard:
		if not seen.has(String(s.stage)):
			seen.append(String(s.stage))
		if String(s.stage) == until_stage or bool(s.done):
			return
		s.advance()
		await tree.process_frame

func test_screen_f1_full_flow() -> void:
	var sim = _sim("deductor", 4, true)
	if not _ready_or_skip(sim):
		return
	var s = _screen(sim)
	var seen: Array = []
	eq(String(s.stage), "noche", "empieza la noche del jueves")
	ok(String(s.state().caption).contains("Baker Street"), "primera línea de la noche: %s" % s.state().caption)
	await _run_beats(s, "ficha", seen)
	eq(String(s.stage), "ficha")
	ok(String(s.card_text()).contains("Lector") and String(s.card_text()).contains("Cuatro de cuatro."), "ficha L + variante: %s" % s.card_text())
	var prev: Label = s.find_child("Anterior", true, false)
	ok(prev != null and prev.text.contains("Lestrade"), "EE12: la ficha de Lisle va justo después de la de Lestrade")
	await _run_beats(s, "lectura", seen)
	eq(seen, ["noche", "final", "ficha", "tiempo", "lectura"], "orden de estadios")
	no(bool(s.state().strand), "la revista todavía no está abierta")
	await _run_beats(s, "tijera", seen)
	var st: Dictionary = s.state()
	ok(st.keys.has("epilogo.04.park_lane+nota_de_s_h"))
	ok((st.marks as Array).has("esquina") and (st.marks as Array).has("nota_azul"), "esquina doblada y nota azul: %s" % str(st.marks))
	ok(bool(st.strand), "la revista abierta")
	eq(int(st.page), 0, "de vuelta en la primera hoja para el corte")
	# un corte equivocado no avanza
	s.set_scissors(true)
	ok(bool(s.state().scissors))
	var cur := Model.tramo_at(sim, "curiosos")
	s.do_cut(int(cur.page), int(cur.from), 8)
	eq(String(s.stage), "tijera", "otra oración: Lisle no la corta")
	eq(int(s.misses), 1)
	var before: int = sim.st.ded.clips.size()
	var t := Model.cut_target(sim)
	s.do_cut(int(t.page), int(t.from) + 10, 5)
	eq(String(s.stage), "concordancia", "el último gesto")
	eq(sim.st.ded.clips.size(), before + 1, "un recorte real")
	var last: Dictionary = sim.st.ded.clips[sim.st.ded.clips.keys().max()]
	eq(String(last.get("tramo", "")), "hombre_alto", "el recorte es el hombre alto (tramo corto, GDD_v3 §6.2)")
	eq(String(last.get("text", "")), String(t.text), "el tramo entero")
	for _f in 6:
		await tree.process_frame
	ok(bool(s.state().strip), "la tira pegada en la concordancia")
	eq(s.diary_keys(), ["epilogo.13.tijera"])
	s.advance()
	ok(String(s.state().ficha).contains("Yo estaba."), "la ficha escrita: %s" % s.state().ficha)
	await _run_beats(s, "creditos", seen)
	eq(String(s.stage), "creditos", "sin Shell no hay lámina del estante: directo al colofón")
	await _run_beats(s, "lapiz", seen)
	eq(String(s.stage), "lapiz")
	var closed := [false]
	s.closed.connect(func(): closed[0] = true)
	var b: Button = s.find_child("Cerrar", true, false)
	ok(b != null, "botón para cerrar el libro")
	b.pressed.emit()
	ok(bool(s.done))
	ok(closed[0], "closed")
	eq(String(sim.q_clock().phase), "done", "leave -> done")
	s.free()

func test_screen_f4_publish_two_steps() -> void:
	var sim = _sim("pasivo", 6, true)
	if not _ready_or_skip(sim):
		return
	var s = _screen(sim)
	var seen: Array = []
	for i in 200:
		if bool(s.state().offer) or String(s.stage) == "tijera":
			break
		s.advance()
		await tree.process_frame
	ok(bool(s.state().offer), "llega la oferta")
	var n_before: int = (s.state().diary as Array).size()
	s.advance()
	eq((s.state().diary as Array).size(), n_before, "con la oferta abierta, Seguir no avanza")
	s.choose_publish(true)
	ok(bool(s.state().modal), "segundo paso: confirmación")
	no(bool(sim.st.flags.get("publica_errata", false)), "todavía no")
	s.confirm(false)
	no(bool(s.state().modal))
	ok(bool(s.state().offer), "volver: la oferta sigue")
	s.choose_publish(true)
	s.confirm(true)
	ok(bool(sim.st.flags.get("publica_errata", false)), "publicada")
	no(bool(s.state().offer))
	await _run_beats(s, "tijera", seen)
	var t := Model.cut_target(sim)
	s.set_scissors(true)
	s.do_cut(int(t.page), int(t.from), int(t.to) - int(t.from))
	for _f in 6:
		await tree.process_frame
	await _run_beats(s, "creditos", seen)
	has(s.diary_keys(), "epilogo.15.posdata+resena_romance", "la posdata de enero de 1904")
	s.free()

func test_screen_without_epilogue_data_is_safe() -> void:
	# --screen=epilogue sobre una partida que no llegó al final: no rompe, muestra lo que hay y termina.
	var sim = GameSim.new(repo(), 7)
	var s = _screen(sim)
	ok(["tiempo", "lectura"].has(String(s.stage)), "arranca sin noche ni final: %s" % s.stage)
	for i in 300:
		if bool(s.done) or String(s.stage) == "lapiz":
			break
		if String(s.stage) == "tijera":
			var t := Model.cut_target(sim)
			s.do_cut(int(t.page), int(t.from), 4)
		s.advance()
		await tree.process_frame
	ok(String(s.stage) == "lapiz" or bool(s.done), "llega al lápiz azul: %s" % s.stage)
	s.free()

func test_marks_drawn_on_page_and_loupe() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var s = _screen(sim)
	for i in 200:
		if String(s.stage) == "tijera":
			break
		s.advance()
		await tree.process_frame
	await tree.process_frame
	var sv = s._strand
	var found := []
	for pv in [sv.page, sv.loupe.copy]:
		for c in pv.get_children():
			if c.get_class() == "Control" and "items" in c:
				found.append([pv.name, (c.items as Array).map(func(m): return String(m.kind)), c.get_child_count(), c.size])
	eq(found.size(), 2, "marcas en la hoja y en la lupa")
	s.free()

# La tijera con el mouse: un clic sobre una oración (sin arrastrar) la corta entera, entre punto y punto; y las hojas
# se pasan con ‹ ›; Esc deja la tijera.
func test_click_cuts_whole_sentence_and_pages() -> void:
	var sim = _sim("deductor")
	if not _ready_or_skip(sim):
		return
	var s = _screen(sim)
	for i in 200:
		if String(s.stage) == "tijera":
			break
		s.advance()
		await tree.process_frame
	await tree.process_frame
	var sv = s._strand
	eq(sv.page_count(), 2)
	ok(sv._nav.visible, "‹ Hoja n de m › con dos hojas")
	sv._b_next.pressed.emit()
	eq(int(sv.page_idx), 1, "pasa la hoja")
	ok(sv._b_next.disabled, "última hoja")
	sv._b_prev.pressed.emit()
	eq(int(sv.page_idx), 0)
	s.set_scissors(true)
	ok(s.back(), "Esc deja la tijera")
	no(bool(sv.scissors))
	s.set_scissors(true)
	var t := Model.cut_target(sim)
	var rtl: RichTextLabel = sv.page.blocks[0]
	var local: Vector2 = SelMap.char_local_pos(rtl, int(t.from) + 20)
	var k: int = sv.char_at(rtl, local)
	ok(k >= int(t.from) and k < int(t.to), "el clic cae dentro de la oración: %d en [%d, %d)" % [k, t.from, t.to])
	var got := []
	sv.cut_requested.connect(func(p, f, l): got.append([p, f, l]))
	var canvas: Vector2 = rtl.get_global_transform_with_canvas() * local
	sv._on_pressed(0, canvas)
	sv._on_released(0, canvas)
	eq(got.size(), 1, "un corte")
	if got.size() == 1:
		eq(int(got[0][1]), int(t.from), "desde el principio de la oración")
		eq(int(got[0][1]) + int(got[0][2]), int(t.to), "hasta el punto")
	eq(String(s.stage), "concordancia", "y es el último gesto")
	s.free()

# Shell mínimo (duck typing de lo que la pantalla usa): registra el alto que pide para subir los subtítulos.
class FakeShell extends RefCounted:
	var fast := true
	var sounds := false
	var world = null
	var sim = null
	var insets: Array = []
	func act(a: Dictionary) -> Dictionary:
		return sim.apply(a)
	func set_subs_inset(px: float) -> void:
		insets.append(px)
	func subs_rect() -> Rect2:
		return Rect2(Vector2(1198, 796), Vector2(380, 104))

# La noche: los subtítulos de sus sonidos suben justo por encima de la leyenda (nunca fuera de la pantalla); la hoja
# de la concordancia no se mete en la zona de los subtítulos ni con la ficha escrita.
func test_night_subs_inset_and_sheets_clear_subs() -> void:
	var sim = _sim("deductor", 4, true)
	if not _ready_or_skip(sim):
		return
	var sh := FakeShell.new()
	sh.sim = sim
	var s = Screen.new()
	s.sim = sim
	s.shell = sh
	s.fast = true
	s.sounds = false
	tree.root.add_child(s)
	s.start()
	for _f in 3:
		await tree.process_frame
	eq(String(s.stage), "noche")
	var vs: Vector2 = s._vs()
	var checked := 0
	for i in 12:
		await tree.process_frame
		if String(s.stage) != "noche":
			break
		var last: float = float(sh.insets[-1]) if not sh.insets.is_empty() else -1.0
		var cap_top: float = s._caption.position.y
		ok(last > 0.0 and last < vs.y * 0.5, "inset razonable en la línea %d: %s (leyenda en y=%s, vista %s)" % [i, str(last), str(cap_top), str(vs)])
		ok(vs.y - last - 18.0 <= cap_top + 1.0, "los subtítulos quedan encima de la leyenda: inset %s, leyenda %s" % [str(last), str(cap_top)])
		checked += 1
		s.advance()
	ok(checked >= 4, "se revisaron las líneas de la noche: %d" % checked)
	eq(float(sh.insets[-1]), 0.0, "pasada la noche, los subtítulos vuelven al pie")
	for i in 300:
		if String(s.stage) == "tijera":
			break
		s.advance()
		await tree.process_frame
	var t := Model.cut_target(sim)
	s.set_scissors(true)
	s.do_cut(int(t.page), int(t.from), 5)
	for _f in 6:
		await tree.process_frame
	s.advance()
	for _f in 4:
		await tree.process_frame
	ok(String(s.state().ficha) != "", "ficha escrita")
	var conc: Control = s._conc
	var bottom: float = conc.position.y + conc.size.y * conc.scale.y
	ok(bottom <= sh.subs_rect().position.y + 0.5, "la concordancia termina sobre los subtítulos: %s > %s" % [str(bottom), str(sh.subs_rect().position.y)])
	s.free()

# El camino lento (sin --fast): fundidos, planeo de la lupa, vuelo de la tira, escritura de la ficha, colofón con
# temporizador. Sin Shell (sin fundidos de pantalla); se avanza con clics espaciados. Ningún error del motor.
func test_screen_slow_path_no_errors() -> void:
	var sim = _sim("deductor", 9, true)
	if not _ready_or_skip(sim):
		return
	var s = Screen.new()
	s.sim = sim
	s.fast = false
	s.sounds = false
	tree.root.add_child(s)
	s.start()
	var seen: Array = []
	for i in 900:
		if not seen.has(String(s.stage)):
			seen.append(String(s.stage))
		if String(s.stage) == "lapiz" or bool(s.done):
			break
		if String(s.stage) == "tijera" and not bool(s._busy):
			var t := Model.cut_target(sim)
			s.set_scissors(true)
			s.do_cut(int(t.page), int(t.from), 5)
		else:
			s.advance()
		await tree.create_timer(0.03).timeout
	eq(String(s.stage), "lapiz", "llega al lápiz azul: %s" % str(seen))
	for st in ["noche", "final", "ficha", "tiempo", "lectura", "tijera", "concordancia", "creditos", "lapiz"]:
		has(seen, st)
	s.free()
