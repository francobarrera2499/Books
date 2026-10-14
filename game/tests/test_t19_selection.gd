# T19 (W2-READER, ARCHITECTURE §6.4, §9.2): selección -> {from, len} -> tramos.
# Puro: SelectionMapper.map_raw(plain, from, seleccionado) y preview (ClipRules.snap + inherit) sobre docs de data_min y
#   del fixture reader. Integración (sin ventana, root 1600×900): arrastre por Input.parse_input_event sobre el
#   DocumentReader en modo tijera -> Game.act({"t":"clip_text",…}) con src/from/len correctos -> tramo esperado.
# Con ventana: devtools/drivers/w2reader_t19.gd (mismo recorrido, con capturas).
extends "res://tests/test_base.gd"

const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const Reader = preload("res://ui/reader/document_reader.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Markup = preload("res://core/text/markup.gd")

var rd = null
var acts: Array = []
var old_size := Vector2i.ZERO

func before_each() -> void:
	acts = []
	old_size = tree.root.size

func after_each() -> void:
	if rd != null:
		rd.free()
	rd = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

# ------------------------------------------------------------------ puro
func test_map_raw_exact_and_recovery() -> void:
	var plain := "MEIRINGEN, 5 de mayo. Dos viajeros ingleses subieron ayer por el sendero."
	var k := plain.find("viajeros")
	var m := SelectionMapper.map_raw(plain, k, "viajeros")
	ok(m.ok and m.from == k and m.len == 8 and not m.adjusted, "exacto")
	for d in [-8, -3, -1, 1, 5, 8]:
		var m2 := SelectionMapper.map_raw(plain, k + d, "viajeros")
		ok(m2.ok and m2.from == k and m2.adjusted, "recupera a %d" % d)
	no(SelectionMapper.map_raw(plain, k + 9, "viajeros").ok, "más allá de ±8 no se adivina")
	no(SelectionMapper.map_raw(plain, 4, "").ok, "vacío")
	no(SelectionMapper.map_raw(plain, -1, "Dos").ok, "from negativo")
	no(SelectionMapper.map_raw(plain, 0, "no está").ok, "texto ajeno")
	# la ocurrencia MÁS CERCANA cuando el texto se repite
	var rep := "la casa y la casa y la casa"
	eq(SelectionMapper.map_raw(rep, 11, "la casa").from, 10, "la más cercana")

func test_selection_to_tramos_d05() -> void:
	var pt: Dictionary = fixture_repo("data_min").parsed("D05", "p1")
	var plain: String = pt.plain
	var cases := [
		# [texto seleccionado, tramo esperado, etiqueta a: esperada o "" (sin herencia), entidad esperada]
		["Los guías no hallaron ningún cuerpo", "aucun_corps", "a:refuta_rio_cuerpo", "guias"],
		["El bastón herrado seguía apoyado contra la roca, «le bâton ferré appuyé", "baton", "a:refuta_baston", "roca"],
		["Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que", "corniche", "a:cornisa_existe", "cornisa"],
		["une marque récente", "marque", "a:raspadura_registrada", "raspadura"],
		# menos de la mitad del tramo: entidades de lo recortado, sin afirmaciones ni fecha/lugar heredados
		["herrado seguía apoyado contra la roca", "baton", "", "roca"],
		["por el sendero de la cascada del Reichenbach", "viajeros", "", "reichenbach"],
	]
	for c in cases:
		var from := plain.find(c[0])
		ok(from >= 0, "está en el texto: " + c[0])
		var m := SelectionMapper.map_raw(plain, from, c[0])
		ok(m.ok, "mapea")
		var pv := SelectionMapper.preview(pt, m.from, m.len)
		ok(pv.ok, "recorte legal: " + c[0])
		eq(pv.tramo, c[1], "tramo de «%s»" % c[0])
		if c[2] == "":
			eq(pv.tags, [], "menos de la mitad del tramo: sin etiquetas heredadas («%s»)" % c[0])
		else:
			has(pv.tags, c[2], "afirmación heredada")
		has(pv.ents, c[3], "entidad")
	# selección que cruza un punto
	var a := plain.find("uno solo")
	var b := plain.find("guías") + 5
	var pvx := SelectionMapper.preview(pt, a, b - a)
	no(pvx.ok, "cruza oración")
	eq(pvx.err, "cruza_oracion", "error de oración")
	# GDD_v3 §6.2: una frase corta, ≤15 palabras
	var long_s := "Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que l'on"
	var pvl := SelectionMapper.preview(pt, plain.find(long_s), long_s.length())
	no(pvl.ok, "16 palabras: no se recorta")
	eq(pvl.err, "mas_de_15", "error de largo")
	# palabra cortada a la mitad: se extiende a palabras completas
	var k := plain.find("hallaron")
	var pvh := SelectionMapper.preview(pt, k + 2, 4)
	eq(pvh.text, "hallaron", "snap a palabra completa")

func test_selection_rasante_and_typed() -> void:
	var pt: Dictionary = fixture_repo("data_min").parsed("D29b", "p1")
	var s := "Recibí del señor Mycroft los papeles del 3 de mayo"
	var from := String(pt.plain).find(s)
	var pv := SelectionMapper.preview(pt, from, s.length())
	eq(pv.tramo, "surcos", "texto rasante recortable")
	has(pv.tags, "a:dispuso_bienes", "hereda del surco")
	has(pv.ents, "mycroft", "mención")
	var pt2: Dictionary = fixture_repo("reader").parsed("D25", "p1")
	var s2 := "Le ahorraré el trabajo: lea a Reuter."
	var pv2 := SelectionMapper.preview(pt2, String(pt2.plain).find(s2), s2.length())
	eq(pv2.tramo, "ahorro", "carta a máquina")
	has(pv2.ents, "reuter", "entidad de la carta")

# ------------------------------------------------------------------ integración (sin ventana)
func fake_act(a: Dictionary) -> Dictionary:
	if a.t == "read":
		return {"ok": true}   # GDD_v2 §B.4: el lector anota la lectura de cada hoja (acción libre); aquí sólo cuentan los recortes
	acts.append(a)
	if a.t != "clip_text":
		return {"ok": false, "err": "desconocido"}
	var pt: Dictionary = rd.view.pages[int(a.src.part)][int(a.src.block)].parsed
	var pv := SelectionMapper.preview(pt, int(a.from), int(a.len))
	if not pv.ok:
		return {"ok": false, "err": pv.err}
	return {"ok": true, "clip": "RC%04d" % acts.size(), "text": pv.text, "tramo": pv.tramo, "tags": pv.tags}

func open_reader(view: Dictionary) -> void:
	tree.root.size = Vector2i(1600, 900)
	rd = Reader.new()
	rd.sounds = false
	rd.act_fn = fake_act
	tree.root.add_child(rd)
	ok(rd.open_view(view), "abre la vista")
	rd.set_tijera(true)

func mb(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = mask
	Input.parse_input_event(e)

func drag(block: int, text: String, steps := 10) -> void:
	var r: RichTextLabel = rd.block_rtl(block)
	var plain := r.get_parsed_text()
	var from := plain.find(text)
	ok(from >= 0, "el bloque contiene «%s»" % text)
	var pts := SelectionMapper.drag_points(r, from, from + text.length())
	mm(pts[0], 0)
	await tree.process_frame
	mb(pts[0], true)
	await tree.process_frame
	for i in range(1, steps + 1):
		mm(pts[0].lerp(pts[1], float(i) / float(steps)))
		await tree.process_frame
	# RichTextLabel actualiza la selección arrastrada con un temporizador mientras el botón sigue apretado:
	# se deja que alcance la posición final antes de soltar (como hace una mano real).
	await tree.create_timer(0.15).timeout
	await tree.process_frame
	mb(pts[1], false)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

func test_drag_clips_d05() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	await drag(0, "Los guías no hallaron ningún cuerpo")
	eq(acts.size(), 1, "una acción clip_text")
	if acts.is_empty():
		return
	var a: Dictionary = acts[0]
	eq(a.t, "clip_text", "tipo")
	eq(a.src, {"kind": "doc", "ref": "D05@BM", "part": 0, "block": 0}, "src del bloque")
	var plain: String = fixture_repo("data_min").parsed("D05", "p1").plain
	var raw := String(plain).substr(int(a.from), int(a.len))
	ok(raw.begins_with("Los guías") and raw.contains("ningún cuerp"), "lo arrastrado: «%s»" % raw)
	var pv := SelectionMapper.preview(fixture_repo("data_min").parsed("D05", "p1"), int(a.from), int(a.len))
	eq(pv.text, "Los guías no hallaron ningún cuerpo:", "la tira, a palabras completas")
	eq(pv.tramo, "aucun_corps", "tramo correcto")
	has(pv.tags, "a:refuta_rio_cuerpo", "etiqueta correcta")
	eq(rd.block_rtl(0).get_selected_text(), "", "la selección se limpia tras recortar")

# Arrastre de derecha a izquierda: get_selection_from() sigue siendo el comienzo (el sentido no importa).
func test_drag_right_to_left() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	var r: RichTextLabel = rd.block_rtl(0)
	var text := "El bastón herrado seguía apoyado contra la roca"
	var from := r.get_parsed_text().find(text)
	var pts := SelectionMapper.drag_points(r, from, from + text.length())
	mm(pts[1], 0)
	await tree.process_frame
	mb(pts[1], true)
	await tree.process_frame
	for i in range(1, 11):
		mm(pts[1].lerp(pts[0], float(i) / 10.0))
		await tree.process_frame
	await tree.create_timer(0.15).timeout
	mb(pts[0], false)
	for _i in 3:
		await tree.process_frame
	eq(acts.size(), 1, "una acción")
	if acts.is_empty():
		return
	var pv := SelectionMapper.preview(fixture_repo("data_min").parsed("D05", "p1"), int(acts[0].from), int(acts[0].len))
	ok(pv.text.begins_with("El bastón herrado") and pv.text.contains("contra la roca"), "la tira: «%s»" % pv.text)
	eq(pv.tramo, "baton", "tramo")

func test_drag_clips_zoomed_and_typed() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("reader"), "D25@L1"))
	await tree.process_frame
	var r: RichTextLabel = rd.block_rtl(0)
	var k := r.get_parsed_text().find("Le ahorraré")
	rd.set_zoom(2.2, r.get_global_transform_with_canvas() * SelectionMapper.char_local_pos(r, k))
	await tree.process_frame
	await drag(0, "Le ahorraré el trabajo: lea a Reuter")
	eq(acts.size(), 1, "una acción con zoom 220 %")
	if acts.is_empty():
		return
	var pv := SelectionMapper.preview(fixture_repo("reader").parsed("D25", "p1"), int(acts[0].from), int(acts[0].len))
	eq(pv.tramo, "ahorro", "tramo con zoom y efecto Remington")

func test_drag_rasante_block() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D29b@L4"))
	await tree.process_frame
	await drag(0, "Recibí del señor Mycroft los papeles")
	eq(acts.size(), 1, "los surcos se recortan aunque no se vean")
	if acts.is_empty():
		return
	var pv := SelectionMapper.preview(fixture_repo("data_min").parsed("D29b", "p1"), int(acts[0].from), int(acts[0].len))
	eq(pv.tramo, "surcos", "tramo rasante")

func test_drag_cross_sentence_says_lisle() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	await drag(0, "uno solo volvió a la posada. Los guías")
	eq(acts.size(), 1, "se intenta")
	ok(rd._note.visible, "aparece la línea de Lisle")
	eq(rd._note_label.text, Data.repo().text("clip.cruza_oracion"), "la tira no cruza un punto")

# GDD_v3 §6.2: más de 15 palabras -> la línea de Lisle «Me alcanza una frase corta.» (v3core.clip.mas_de_15).
func test_drag_too_long_says_lisle() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	await drag(0, "Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que l'on ne voit")
	eq(acts.size(), 1, "se intenta")
	ok(rd._note.visible, "aparece la línea de Lisle")
	eq(rd._note_label.text, Data.repo().text("v3core.clip.mas_de_15"), "una frase corta")

func test_multi_block_page_reports_block_index() -> void:
	var names := {"watson": "el doctor Watson"}
	var b0 := Markup.parse("{{#uno a:x|Primer bloque de la columna, sin nada que ver.}}", {"names": names})
	var b1 := Markup.parse("{{#dos a:y e:watson|AL LECTOR DE HOLYWELL STREET: lo dijo [[watson]] en Ginebra.}}", {"names": names})
	var v := {"view": "D15.0330@L1", "title": "The Times", "src_line": "prensa de Londres", "paper": "diario_hueso",
		"paper_mm": [300, 420], "font": "imprenta", "machine": null,
		"pages": [[{"doc": "D15.0330", "origin": "D15.0330", "copy": "D15.0330@L1", "parsed": b0},
			{"doc": "R.HA1.1", "origin": "D15.0330", "copy": "", "parsed": b1}]]}
	open_reader(v)
	await tree.process_frame
	await drag(1, "lo dijo el doctor Watson en Ginebra")
	eq(acts.size(), 1, "una acción")
	if acts.is_empty():
		return
	eq(acts[0].src, {"kind": "doc", "ref": "D15.0330@L1", "part": 0, "block": 1}, "bloque 1 de la hoja 0")
	var pv := SelectionMapper.preview(b1, int(acts[0].from), int(acts[0].len))
	eq(pv.tramo, "dos", "tramo del bloque insertado")
	has(pv.ents, "watson", "mención del bloque insertado")

# De punta a punta con el sim real (W2-SIM/W2-DED) sobre data_min: q_view -> lector -> arrastre -> sim.apply(clip_text).
func test_end_to_end_with_game_sim() -> void:
	var mini = fixture_repo("data_min")
	var sim = load("res://core/sim/game_sim.gd").new(mini, 7)
	var v: Dictionary = sim.q_view("D02@L1")
	if v.is_empty() or v.get("pages", []).is_empty():
		skip("q_view todavía no entrega D02@L1 (W2-SIM)")
		return
	tree.root.size = Vector2i(1600, 900)
	rd = Reader.new()
	rd.sounds = false
	rd.act_fn = func(a):
		if a.t != "read":
			acts.append(a)
		return sim.apply(a)
	tree.root.add_child(rd)
	ok(rd.open_view(v), "abre la vista del sim")
	rd.set_tijera(true)
	await tree.process_frame
	await drag(0, "En la roca, a la altura del hombro, una raspadura reciente")
	eq(acts.size(), 1, "una acción")
	if acts.is_empty():
		return
	var clips: Array = sim.q_clips()
	if clips.is_empty():
		skip("el sim no registró el recorte (W2-DED en curso)")
		return
	var c: Dictionary = sim.q_clip(String(clips[-1].id))
	ok(String(c.text).begins_with("En la roca, a la altura del hombro, una raspadura reciente"), "texto del recorte: «%s»" % c.text)
	var internal: Dictionary = load("res://core/deduction/clipper.gd").get_clip(sim.st, String(clips[-1].id))
	has(internal.get("tags", []), "a:raspadura_registrada", "el sim hereda la afirmación del tramo")
	eq(String(c.get("copy", "")), "D02@L1", "ejemplar")

# Rueda (fe_zoom_*) = zoom en el puntero; clic derecho (fe_volver): primero deja la tijera, después cierra.
func test_wheel_zoom_and_right_click_back() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	var r: RichTextLabel = rd.block_rtl(0)
	var p: Vector2 = r.get_global_transform_with_canvas() * SelectionMapper.char_local_pos(r, 40)
	var z0: float = rd.zoom
	var before: Vector2 = r.get_global_transform_with_canvas().affine_inverse() * p
	# playtest v3: la rueda sola desplaza; Ctrl + rueda acerca
	var sp0: Vector2 = rd._stage.position
	wheel(p, MOUSE_BUTTON_WHEEL_DOWN, false)
	await tree.process_frame
	near(rd.zoom, z0, 1e-6, "la rueda sola no cambia el zoom")
	ok(rd._stage.position.y <= sp0.y, "la rueda sola baja la hoja (o no se mueve si ya cabe)")
	rd._stage.position = sp0
	rd._clamp_pan()
	for _i in 3:
		wheel(p, MOUSE_BUTTON_WHEEL_UP)
		await tree.process_frame
	ok(rd.zoom > z0 * 1.3, "Ctrl + rueda acerca (%.2f -> %.2f)" % [z0, rd.zoom])
	var after: Vector2 = r.get_global_transform_with_canvas().affine_inverse() * p
	ok(before.distance_to(after) < 1.0, "el punto bajo el puntero queda quieto")
	for _i in 30:
		wheel(p, MOUSE_BUTTON_WHEEL_DOWN)
		await tree.process_frame
	near(rd.zoom, 0.8, 1e-6, "tope de 80 %")
	var closed := [0]
	rd.closed.connect(func(): closed[0] += 1)
	ok(rd.tijera, "tijera en la mano")
	click(p, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	no(rd.tijera, "clic derecho: deja la tijera")
	ok(rd.visible, "y no cierra todavía")
	click(p, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	eq(closed[0], 1, "segundo clic derecho: cierra")

func wheel(pos: Vector2, button: MouseButton, ctrl := true) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		e.factor = 1.0
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)

func click(pos: Vector2, button: MouseButton) -> void:
	mm(pos, 0)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)

func test_no_tijera_no_clip() -> void:
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	rd.set_tijera(false)
	await tree.process_frame
	await drag(0, "Los guías no hallaron")
	eq(acts.size(), 0, "sin tijera, arrastrar desplaza la hoja y no recorta")
