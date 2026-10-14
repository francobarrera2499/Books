# test_u_reader_v3.gd — LECTOR (GDD_v3 §6.7, §7.2 P5), sin ventana: el lector flotante. Fondo = la pieza desenfocada
# (shader de pantalla, 25 % más oscura; gris liso en alto contraste); papel recto con sombra en perspectiva; tijera como
# ícono suelto (sin recuadro ni palabra) arriba a la derecha; paginación abajo al centro; notas a lápiz EN el margen
# derecho, alineadas con su tramo; marquitas del cliente en el margen izquierdo; ficha de Lisle (no recortable) arriba
# de la primera hoja; tarjeta del cliente en cartulina con clip como última hoja (recortable). Recortar la nota del
# margen da un recorte de origen D01N; la tarjeta, de NC.FINA.
# Vista: tests/fixtures/v3 (V3Fixture.fina_view: FINA del cliente; equivalente sintética mientras CONTENIDO no traiga el
# bloque v3). Eventos de mouse y teclado reales (Input.parse_input_event). Con ventana: devtools/drivers/v3lector_shots.gd.
extends "res://tests/test_base.gd"

const Reader = preload("res://ui/reader/document_reader.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const V3Fixture = preload("res://tests/fixtures/v3/v3_fixture.gd")
const Paper = preload("res://ui/kit/paper.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

var rd = null
var acts: Array = []
var old_size := Vector2i.ZERO
static var _fina := {}

func before_each() -> void:
	acts = []
	old_size = tree.root.size
	Reader.reset_read_memory()

func after_each() -> void:
	if rd != null:
		rd.free()
	rd = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti != null and ti.high_contrast:
		ti.set_high_contrast(false)
	Reader.reset_read_memory()

func fina() -> Dictionary:
	if _fina.is_empty():
		_fina = V3Fixture.fina_view(repo())
	return _fina.duplicate(true)

# El sim de verdad recorta el bloque de q_view (WorldModel.block): acá, el mismo bloque de la vista del lector.
func fake_act(a: Dictionary) -> Dictionary:
	if a.t == "read":
		return {"ok": true}
	if a.t != "clip_text":
		return {"ok": false, "err": "desconocido"}
	var blk: Dictionary = rd.view.pages[int(a.src.part)][int(a.src.block)]
	var rec := a.duplicate(true)
	rec["origin"] = String(blk.get("origin", ""))
	acts.append(rec)
	var pv := SelectionMapper.preview(blk.parsed, int(a.from), int(a.len))
	if not pv.ok:
		return {"ok": false, "err": pv.err}
	return {"ok": true, "clip": "RV%d" % acts.size(), "text": pv.text}

func open_reader(v: Dictionary) -> void:
	tree.root.size = Vector2i(1600, 900)
	rd = Reader.new()
	rd.sounds = false
	rd.act_fn = fake_act
	tree.root.add_child(rd)
	ok(rd.open_view(v), "abre la vista")

func vp_size() -> Vector2:
	return tree.root.get_visible_rect().size

func margin_page(v: Dictionary) -> int:
	for i in v.pages.size():
		for b in v.pages[i]:
			if String(b.get("slot", "")) == "margen":
				return i
	return -1

func margin_block(pg) -> int:
	for j in pg.slots.size():
		if pg.slots[j] == "margen":
			return j
	return -1

# ------------------------------------------------------------------ eventos reales
func mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = mask
	Input.parse_input_event(e)

func mb(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	Input.parse_input_event(e)

func click(pos: Vector2) -> void:
	mm(pos, 0)
	await tree.process_frame
	mb(pos, true)
	await tree.process_frame
	mb(pos, false)
	await tree.process_frame

func key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await tree.process_frame

func drag(r: RichTextLabel, text: String) -> void:
	var plain := r.get_parsed_text()
	var from := plain.find(text)
	ok(from >= 0, "el bloque contiene «%s»" % text)
	if from < 0:
		return
	var pts := SelectionMapper.drag_points(r, from, from + text.length())
	mm(pts[0], 0)
	await tree.process_frame
	mb(pts[0], true)
	await tree.process_frame
	for i in range(1, 11):
		mm(pts[0].lerp(pts[1], float(i) / 10.0))
		await tree.process_frame
	await tree.create_timer(0.15).timeout
	await tree.process_frame
	mb(pts[1], false)
	for _i in 3:
		await tree.process_frame

# ------------------------------------------------------------------ tests
func test_fixture_view_has_v3_shape() -> void:
	var v := fina()
	ok(not v.is_empty(), "hay vista de FINA del cliente")
	ok(typeof(v.get("ficha")) == TYPE_DICTIONARY, "con ficha")
	ok(not (v.get("marks", []) as Array).is_empty(), "con marquitas")
	ok(margin_page(v) >= 0, "con nota al margen")
	ok(PageView.is_card_page(v.pages[-1]), "la última hoja es la tarjeta")
	var n := ViewModel.normalize(v)
	eq(n.ficha, v.ficha, "normalize conserva la ficha")
	eq(n.marks, v.marks, "normalize conserva las marquitas")
	eq(n.pages.size(), v.pages.size(), "y las hojas")
	for i in v.pages.size():
		eq(n.pages[i].size(), v.pages[i].size(), "hoja %d: mismos bloques (los índices del recorte no cambian)" % i)

func test_backdrop_is_blurred_scene() -> void:
	open_reader(fina())
	var m = rd._back.material
	ok(m is ShaderMaterial and m.shader == Reader.BACKDROP, "el fondo es el shader de desenfoque")
	var code: String = (m as ShaderMaterial).shader.code
	ok(code.contains("hint_screen_texture") and code.contains("filter_linear_mipmap"), "lee la pantalla con mipmaps")
	near(float(m.get_shader_parameter("dim")), 0.25, 1e-6, "oscurecida un 25 %")
	near(float(m.get_shader_parameter("blur_lod")), 2.5, 1e-6, "desenfoque lod 2,5")
	eq(rd._back.mouse_filter, Control.MOUSE_FILTER_IGNORE, "el fondo no toma el mouse")
	var ti = tree.root.get_node("ThemeInstaller")
	ti.set_high_contrast(true)
	ok(rd._back.material == null, "alto contraste: sin desenfoque")
	ok(rd._back.color.r < 0.3 and rd._back.color.a > 0.99, "alto contraste: gris liso oscuro")
	ti.set_high_contrast(false)
	ok(rd._back.material == m, "vuelve el desenfoque")

func test_paper_straight_with_perspective_shadow() -> void:
	open_reader(fina())
	await tree.process_frame
	ok(rd.page.floating, "la hoja del lector flota")
	near(rd._stage.rotation, 0.0, 1e-6, "el escenario no se rota")
	near(rd.page.rotation, 0.0, 1e-6, "la hoja no se rota")
	for b in rd.page.blocks:
		near((b as Control).get_global_transform_with_canvas().get_rotation(), 0.0, 1e-6, "el texto no se rota")
	var polys: Array = rd.page.shadow_polygons()
	ok(polys.size() >= 3, "sombra en capas")
	var s: Vector2 = rd.page.size
	for pts in polys:
		for q in pts:
			ok(q.x >= 0.0 and q.y >= 0.0, "la sombra no asoma arriba ni a la izquierda")
	var p0: PackedVector2Array = polys[0]
	ok(p0[1].x > s.x and p0[2].y > s.y, "asoma abajo a la derecha")
	ok(p0[2].x > p0[1].x + 1.0, "borde derecho inclinado (perspectiva)")
	near(rad_to_deg(atan2(p0[2].x - p0[1].x, p0[2].y - p0[1].y)), PageView.SHADOW_DEG, 0.6 if s.y * tan(deg_to_rad(PageView.SHADOW_DEG)) <= 30.0 else 2.0, "≈2°")

func test_scissors_is_a_bare_icon_top_right() -> void:
	open_reader(fina())
	await tree.process_frame
	await tree.process_frame
	var ic: Control = rd._b_tijera
	no(ic is Button, "no es un botón con texto")
	eq(ic.get_child_count(), 0, "sin recuadro ni rótulo adentro")
	eq(String(ic.name), "Tijera", "nombre de nodo (revelado progresivo)")
	for n in rd.find_children("*", "Control", true, false):
		if n is Label or n is Button:
			ne(String(n.get("text")).strip_edges(), "Tijera", "ninguna etiqueta dice «Tijera» (%s)" % n.name)
	var vp := vp_size()
	var r: Rect2 = rd.scissors_rect()
	var pr: Rect2 = rd.paper_rect()
	# playtest v3: anclada a la esquina de arriba a la derecha del papel (no a la de la pantalla), sin salir de la pantalla
	ok(r.position.x >= pr.end.x - 1.0 and r.position.x - pr.end.x <= 16.0 or r.end.x >= vp.x - 10.0, "junto al borde derecho del papel (%s, papel %s)" % [r, pr])
	ok(absf(r.position.y - maxf(pr.position.y, 16.0)) <= 2.0, "a la altura del borde de arriba del papel (%s, papel %s)" % [r, pr])
	ok(r.end.x <= vp.x and r.position.y >= 0.0, "dentro de la pantalla")
	ok(r.size.x <= 56.0, "chica: un ícono")
	no(pr.intersects(r), "afuera del papel")
	no(rd.tijera, "al abrir, sin tijera")
	await click(r.get_center())
	ok(rd.tijera, "clic: toma la tijera")
	ok(rd.page.blocks[0].selection_enabled, "y la hoja se puede recortar")
	ok(rd._b_tijera.on, "el ícono queda como hueco")
	await click(r.get_center())
	no(rd.tijera, "otro clic: la deja")
	await key(KEY_C)
	ok(rd.tijera, "C la toma")
	await key(KEY_C)
	no(rd.tijera, "C la deja")

func test_pager_bottom_center() -> void:
	var v := fina()
	open_reader(v)
	await tree.process_frame
	await tree.process_frame
	var n: int = v.pages.size()
	ok(n > 1, "varias hojas")
	ok(rd.tool_names().has("Hojas"), "paginación a la vista")
	var vp := vp_size()
	var pr: Rect2 = rd.pager_rect()
	near(pr.get_center().x, vp.x * 0.5, 2.0, "al centro")
	ok(pr.end.y <= vp.y and pr.position.y > vp.y - 90.0, "abajo (%s)" % pr)
	eq(rd._page_label.text, "1 / %d" % n, "«1 / N»")
	eq(rd._b_prev.get_parent().get_parent(), rd._pager, "las flechas están en la paginación")
	ok(rd._b_prev.disabled, "en la primera hoja, ‹ apagada")
	await click(rd._b_next.get_global_rect().get_center())
	eq(rd.page_idx, 1, "› pasa de hoja")
	eq(rd._page_label.text, "2 / %d" % n, "«2 / N»")
	await key(KEY_LEFT)
	eq(rd.page_idx, 0, "← vuelve")
	await key(KEY_RIGHT)
	eq(rd.page_idx, 1, "→ avanza")
	await click(rd._b_prev.get_global_rect().get_center())
	eq(rd.page_idx, 0, "‹ vuelve")
	rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	await tree.process_frame
	no(rd.tool_names().has("Hojas"), "una sola hoja: sin paginación")

func test_ficha_first_page_not_clippable() -> void:
	var v := fina()
	open_reader(v)
	await tree.process_frame
	var pg = rd.page
	ok(pg.ficha_rtl != null, "ficha en la primera hoja")
	if pg.ficha_rtl == null:
		return
	var f: Dictionary = v.ficha
	eq(pg.ficha_rtl.get_parsed_text(), "%s\n%s\n%s" % [f.trata, f.cuando, f.por_que], "los tres renglones")
	no(pg.blocks.has(pg.ficha_rtl), "no es un bloque (no se recorta)")
	eq(pg.ficha_rtl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no toma el mouse")
	rd.set_tijera(true)
	no(pg.ficha_rtl.selection_enabled, "ni con la tijera se selecciona")
	ok(pg.ficha_rtl.position.y + pg.ficha_rtl.size.y < (pg.blocks[0] as Control).position.y, "arriba del texto")
	ne(pg.ficha_rtl.get_theme_color("default_color"), (pg.blocks[0] as RichTextLabel).get_theme_color("default_color"), "en otra tinta")
	rd.go_page(1)
	ok(rd.page.ficha_rtl == null, "las otras hojas no la llevan")
	eq(rd.page.blocks.size(), v.pages[1].size(), "bloques = los de la vista")

func test_margin_note_in_right_margin_aligned() -> void:
	var v := fina()
	var sp := margin_page(v)
	ok(sp >= 0, "hoja con nota al margen")
	if sp < 0:
		return
	open_reader(v)
	var cr0: Rect2 = rd.page.content_rect_px()
	ok(rd.page.margin_col, "la vista con notas deja la columna en todas sus hojas")
	rd.go_page(sp)
	await tree.process_frame
	var pg = rd.page
	eq(pg.content_rect_px(), cr0, "el cuerpo mide lo mismo en todas las hojas")
	var mi := margin_block(pg)
	ok(mi >= 0, "bloque de margen")
	var r: RichTextLabel = pg.blocks[mi]
	var p: float = pg.px_per_mm
	var cr: Rect2 = pg.content_rect_px()
	ok(r.position.x >= cr.end.x + PageView.NOTE_GAP_MM * p - 0.5, "separada del cuerpo por 6 mm de papel")
	near(r.size.x, PageView.NOTE_COL_MM * p, 1.0, "columna de 38 mm")
	ok(r.position.x + r.size.x <= pg.size.x, "dentro del papel")
	var a: Dictionary = pg.anchors[mi]
	var bi := int(a.block)
	var body: RichTextLabel = pg.blocks[bi]
	var rg: Vector2i = PageView.tramo_range(pg.parsed[bi], String(a.tramo))
	ok(rg.x >= 0, "el tramo ancla está en la hoja")
	var ly := body.position.y + float(body.get_line_offset(body.get_character_line(rg.x)))
	near(r.position.y, ly, 1.0, "a la altura de la primera línea de su tramo")
	ok(r.get_theme_font_size("normal_font_size") < body.get_theme_font_size("normal_font_size"), "letra más chica que el cuerpo")
	eq(r.get_theme_color("default_color"), Paper.ink("lapiz"), "gris de lápiz")
	eq(r.get_parsed_text(), String(pg.parsed[mi].plain), "texto == plain")
	ok(r.get_theme_font("normal_font") == tree.root.get_node("ThemeInstaller").font("manuscrito"), "letra manuscrita")

func test_margin_notes_stack_when_they_collide() -> void:
	var v := fina()
	var sp := margin_page(v)
	if sp < 0:
		return
	# una segunda nota con la misma ancla: baja debajo de la primera
	var extra: Dictionary = (v.pages[sp][margin_block_of_view(v, sp)] as Dictionary).duplicate(true)
	v.pages[sp].append(extra)
	open_reader(v)
	rd.go_page(sp)
	await tree.process_frame
	var ids: Array = []
	for j in rd.page.slots.size():
		if rd.page.slots[j] == "margen":
			ids.append(j)
	eq(ids.size(), 2, "dos notas")
	var a: RichTextLabel = rd.page.blocks[ids[0]]
	var b: RichTextLabel = rd.page.blocks[ids[1]]
	ok(b.position.y >= a.position.y + a.size.y, "la segunda se apila debajo (%.0f ≥ %.0f)" % [b.position.y, a.position.y + a.size.y])

func margin_block_of_view(v: Dictionary, sp: int) -> int:
	for j in v.pages[sp].size():
		if String(v.pages[sp][j].get("slot", "")) == "margen":
			return j
	return -1

func test_client_marks_in_left_column() -> void:
	var v := fina()
	open_reader(v)
	var seen := 0
	for m in v.marks:
		rd.go_page(int(m.page))
		await tree.process_frame
		var rects: Array = rd.page.mark_rects()
		var found := false
		for mr in rects:
			if String(mr.tramo) == String(m.tramo):
				found = true
				var rr: Rect2 = mr.rect
				var cr: Rect2 = rd.page.content_rect_px()
				ok(rr.end.x <= cr.position.x, "%s: en el margen izquierdo" % m.tramo)
				ok(rr.position.x >= 0.0, "%s: dentro del papel" % m.tramo)
				var body: RichTextLabel = rd.page.blocks[int(m.block)]
				var rg: Vector2i = PageView.tramo_range(rd.page.parsed[int(m.block)], String(m.tramo))
				var l0 := body.get_character_line(rg.x)
				var y0 := body.position.y + float(body.get_line_offset(l0))
				ok(absf(rr.position.y - y0) < float(body.get_line_height(l0)), "%s: a la altura de su primera línea" % m.tramo)
		ok(found, "marquita de %s dibujada" % m.tramo)
		seen += 1
	ok(seen >= 2, "las dos marquitas de FINA (#sheer, #a_mycroft)")

func test_client_card_is_last_page() -> void:
	var v := fina()
	open_reader(v)
	var p0: float = rd.px_per_mm
	var big: Vector2 = rd.page.size
	rd.go_page(v.pages.size() - 1)
	await tree.process_frame
	var pg = rd.page
	ok(pg.card, "tarjeta")
	eq(pg.paper, "tarjeta", "en cartulina")
	eq(Paper.paper("tarjeta", 0), Color("e9dcb8"), "color de cartulina #e9dcb8")
	near(pg.px_per_mm, p0, 1e-6, "la misma escala que la crónica")
	near(pg.size.x, PageView.CARD_MM.x * p0, 0.5, "127 mm de ancho")
	ok(pg.size.x < big.x and pg.size.y < big.y, "más chica que la hoja")
	ok(rd.page.ficha_rtl == null and pg.marks.is_empty(), "sin ficha ni marquitas")
	no(pg.margin_col, "sin columna de notas")
	for j in pg.blocks.size():
		eq((pg.blocks[j] as RichTextLabel).get_parsed_text(), String(pg.parsed[j].plain), "texto == plain")
	rd.set_tijera(true)
	ok(pg.blocks[0].selection_enabled, "se recorta")

func test_clip_margin_note_is_d01n_and_card_is_nc() -> void:
	var v := fina()
	var sp := margin_page(v)
	open_reader(v)
	rd.go_page(sp)
	await tree.process_frame
	rd.set_tijera(true)
	var mi := margin_block(rd.page)
	var r: RichTextLabel = rd.block_rtl(mi)
	var words := r.get_parsed_text().split(" ", false)
	await drag(r, " ".join(PackedStringArray([words[0], words[1], words[2]])))
	eq(acts.size(), 1, "un recorte")
	if acts.size() == 1:
		eq(acts[0].src, {"kind": "doc", "ref": String(rd.view.view), "part": sp, "block": mi}, "src: la hoja y el bloque de la nota")
		eq(String(acts[0].origin), "D01N", "origen: la nota a lápiz, no la crónica")
	rd.go_page(v.pages.size() - 1)
	await tree.process_frame
	var cr: RichTextLabel = rd.block_rtl(0)
	var cw := cr.get_parsed_text().split(" ", false)
	await drag(cr, " ".join(PackedStringArray([cw[0], cw[1], cw[2], cw[3]])))
	eq(acts.size(), 2, "otro recorte")
	if acts.size() == 2:
		eq(int(acts[1].src.part), v.pages.size() - 1, "de la última hoja")
		eq(String(acts[1].origin), "NC.FINA", "origen: la tarjeta del cliente")

func test_every_block_plain_and_unrotated() -> void:
	var v := fina()
	open_reader(v)
	for i in v.pages.size():
		rd.go_page(i)
		for j in rd.page.blocks.size():
			var r: RichTextLabel = rd.page.blocks[j]
			eq(r.get_parsed_text(), String(rd.page.parsed[j].plain), "hoja %d bloque %d (%s)" % [i, j, rd.page.slots[j]])
			near(r.rotation, 0.0, 1e-6, "sin rotar")
	for hc in [true]:
		var ti = tree.root.get_node("ThemeInstaller")
		ti.set_high_contrast(hc)
		for i in v.pages.size():
			rd.go_page(i)
			for j in rd.page.blocks.size():
				eq((rd.page.blocks[j] as RichTextLabel).get_parsed_text(), String(rd.page.parsed[j].plain), "alto contraste h%d b%d" % [i, j])
		ti.set_high_contrast(false)

# Una hoja más alta que la pantalla se lee con ↓/↑ (o arrastrando) hasta sus bordes y no más: el último renglón queda
# arriba de la paginación, y la hoja nunca se va de la pantalla dejando fondo vacío.
func test_long_page_scroll_stops_at_its_edges() -> void:
	open_reader(fina())
	await tree.process_frame
	var vp := vp_size()
	var pr0: Rect2 = rd.paper_rect()
	ok(pr0.size.y > vp.y, "la hoja 1 de FINA es más alta que la pantalla (%.0f)" % pr0.size.y)
	for _i in 80:
		await key(KEY_DOWN)
	var pr: Rect2 = rd.paper_rect()
	near(pr.end.y, vp.y - Reader.BOTTOM_BAND, 1.0, "↓ llega al pie de la hoja y se detiene")
	var last: RichTextLabel = null
	for j in rd.page.blocks.size():
		if rd.page.slots[j] == "cuerpo":
			last = rd.page.blocks[j]
	var bottom_y: float = (last.get_global_transform_with_canvas() * Vector2(0, last.size.y)).y
	ok(bottom_y < rd.pager_rect().position.y, "el último renglón, arriba de la paginación (%.0f < %.0f)" % [bottom_y, rd.pager_rect().position.y])
	for _i in 80:
		await key(KEY_UP)
	near(rd.paper_rect().position.y, pr0.position.y, 1.0, "↑ vuelve a la cabeza de la hoja y se detiene")
	# arrastrar muy arriba tampoco la pierde
	var at := Vector2(vp.x * 0.5, vp.y * 0.6)
	mm(at, 0)
	await tree.process_frame
	mb(at, true)
	await tree.process_frame
	mm(at + Vector2(0, -3000))
	await tree.process_frame
	mb(at + Vector2(0, -3000), false)
	await tree.process_frame
	near(rd.paper_rect().end.y, vp.y - Reader.BOTTOM_BAND, 1.0, "arrastrada, tampoco se va")

# Las seis tarjetas del cliente (datos reales) conservan la forma de 127 × 76 mm («13 × 8 cm», dice su descripción) y su
# texto cabe: con la escala de una crónica angosta (STUD, SIGN, GREE…) la cartulina se estiraba hasta quedar cuadrada.
func test_every_client_card_keeps_its_shape() -> void:
	var s = V3Fixture.sim(repo())
	var seen := 0
	for ref in ["D03@tomo", "D01.GREE@tomo", "D43@tomo", "D44@tomo", "D01.SCAN@tomo", "D01.TWIS@tomo"]:
		var v: Dictionary = WorldModel.view_any(s.st, repo(), ref)
		if v.is_empty() or v.get("ficha") == null:
			continue   # sin el bloque v3 de CONTENIDO
		if rd != null:
			rd.free()
			rd = null
		open_reader(v)
		await tree.process_frame
		var big: Vector2 = rd.page.size
		rd.go_page(rd.page_count() - 1)
		await tree.process_frame
		var pg = rd.page
		ok(pg.card, "%s: la última hoja es la tarjeta" % ref)
		if not pg.card:
			continue
		seen += 1
		no(pg.overflow, "%s: el texto cabe en la cartulina" % ref)
		near(pg.size.y / pg.size.x, PageView.CARD_MM.y / PageView.CARD_MM.x, 0.01, "%s: 127 × 76 (%s)" % [ref, pg.size])
		ok(pg.size.x <= big.x + 0.5, "%s: no más ancha que la hoja de la crónica (%.0f ≤ %.0f)" % [ref, pg.size.x, big.x])
		var body := 0
		for j in pg.blocks.size():
			eq((pg.blocks[j] as RichTextLabel).get_parsed_text(), String(pg.parsed[j].plain), "%s: texto == plain" % ref)
			body = maxi(body, (pg.blocks[j] as RichTextLabel).get_theme_font_size("normal_font_size"))
		ok(body >= int(round(pg.doc_px() * 0.85)), "%s: la letra del cliente sigue grande (%d px)" % [ref, body])
	ok(seen > 0 or repo().doc("NC.FINA").is_empty(), "hay tarjetas con datos reales")

# El velo oscuro de abajo sólo cuando la hoja sigue por debajo de la paginación: ni sobre una hoja que cabe (la tarjeta),
# ni al pie de una hoja larga, ni en alto contraste (bajaba el contraste de los últimos renglones).
func test_bottom_scrim_only_when_the_page_continues() -> void:
	open_reader(fina())
	await tree.process_frame
	await tree.process_frame
	var vp := vp_size()
	ok(rd.paper_rect().end.y > vp.y, "la hoja 1 sigue por debajo de la pantalla")
	ok(rd._scrim.visible, "velo: la hoja sigue")
	for _i in 80:
		await key(KEY_DOWN)
	await tree.process_frame
	no(rd._scrim.visible, "al pie de la hoja, sin velo")
	rd.go_page(rd.page_count() - 1)
	await tree.process_frame
	await tree.process_frame
	ok(rd.page.card, "la tarjeta")
	no(rd._scrim.visible, "la tarjeta cabe: sin velo")
	rd.go_page(0)
	await tree.process_frame
	await tree.process_frame
	ok(rd._scrim.visible, "de vuelta en la hoja 1: velo")
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti != null:
		ti.set_high_contrast(true)
		await tree.process_frame
		await tree.process_frame
		no(rd._scrim.visible, "alto contraste: sin velo")

# RichTextLabel recorta a su caja por defecto: la «j» manuscrita al principio de un renglón (la ficha: «juntos en la
# cascada») salía como «i». Los bloques miden su contenido, así que no recortan.
func test_blocks_do_not_clip_glyphs() -> void:
	open_reader(fina())
	await tree.process_frame
	ok(rd.page.ficha_rtl != null and not rd.page.ficha_rtl.clip_contents, "la ficha no recorta")
	for b in rd.page.blocks:
		no((b as Control).clip_contents, "%s no recorta" % b.name)

# La línea de Lisle de un recorte fallido no queda flotando al cerrar el papel ni al abrir otro; el bloque del título
# sigue a mano para GameScreen._tutor_dock (alias _header y caption_rect()).
func test_lisle_line_goes_with_the_paper_and_caption_for_tutor() -> void:
	open_reader(fina())
	await tree.process_frame
	rd._say("Un recorte no puede pasar de una oración a otra.")
	ok(rd._note.visible, "la línea aparece")
	rd.close()
	no(rd._note.visible, "al cerrar, se va")
	ok(rd.open_view(fina()), "abre de nuevo")
	no(rd._note.visible, "y no vuelve sola")
	rd._say("x")
	ok(rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM")), "abre otro papel")
	no(rd._note.visible, "otro papel: sin la línea del anterior")
	await tree.process_frame
	ok(rd.get("_header") is Control and rd.get("_header") == rd._caption, "alias _header (GameScreen._tutor_dock)")
	var cr: Rect2 = rd.caption_rect()
	ok(cr.size.x > 0.0 and cr.position.x < vp_size().x * 0.25, "caption_rect arriba a la izquierda (%s)" % cr)
	ok(cr.end.x <= rd.paper_rect().position.x, "no pisa el papel")

func test_layout_keeps_old_views() -> void:
	# una vista sin v3 (Biblioteca, data_min) conserva la geometría de antes: sin columnas ni ficha
	open_reader(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	var pg = rd.page
	no(pg.margin_col, "sin columna de notas")
	ok(pg.ficha_rtl == null, "sin ficha")
	var m: Rect2 = pg.margins_mm()
	near(m.position.x, clampf(pg.paper_mm.x * 0.09, 9.0, 28.0), 1e-4, "margen de siempre")
	near(m.size.x, pg.paper_mm.x - 2.0 * m.position.x, 1e-4, "ancho de siempre")

# Con los datos v3 reales (paquete CONTENIDO) y el sim de verdad: recortar la nota del margen y la tarjeta.
func test_real_sim_clip_origins_when_content_ready() -> void:
	var r0 = repo()
	var sim = V3Fixture.sim(r0)
	var v: Dictionary = sim.q_view("D03@tomo")
	if v.is_empty() or v.get("ficha") == null or margin_page(v) < 0:
		# depende del paquete CONTENIDO (data/docs v3); mientras no llegue, el resto de este archivo prueba con la vista del fixture
		skip("D03@tomo todavía sin bloque v3 en data (ficha, marcas, margen, NC.FINA): paquete CONTENIDO")
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
	var sp := margin_page(v)
	rd.go_page(sp)
	await tree.process_frame
	rd.set_tijera(true)
	var mi := margin_block(rd.page)
	var r: RichTextLabel = rd.block_rtl(mi)
	var words := r.get_parsed_text().split(" ", false)
	var n0: int = sim.q_clips().size()
	await drag(r, " ".join(PackedStringArray([words[0], words[1], words[2]])))
	var cl: Array = sim.q_clips()
	ok(cl.size() == n0 + 1, "el sim registró el recorte de la nota")
	if cl.size() == n0 + 1:
		eq(String(sim.q_clip(String(cl[-1].id)).get("origin", "")), "D01N", "origen D01N")
	rd.go_page(v.pages.size() - 1)
	await tree.process_frame
	var cr: RichTextLabel = rd.block_rtl(0)
	var cw := cr.get_parsed_text().split(" ", false)
	await drag(cr, " ".join(PackedStringArray([cw[0], cw[1], cw[2]])))
	var cl2: Array = sim.q_clips()
	ok(cl2.size() == n0 + 2, "el sim registró el recorte de la tarjeta")
	if cl2.size() == n0 + 2:
		eq(String(sim.q_clip(String(cl2[-1].id)).get("origin", "")), "NC.FINA", "origen NC.FINA")

# Con la partida REAL (Game + data/): el lector sigue las banderas de q_ui (la tijera aparece con desk.tijera, nunca
# antes), anota la lectura de cada hoja (acción read) y, cerrado, no muestra controles.
func test_real_session_flags_and_read() -> void:
	tree.root.size = Vector2i(1600, 900)
	var g = tree.root.get_node("Game")
	var prev_repo = g.repo_override
	var prev_path: String = g.save_path
	g.repo_override = repo()
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/tests/reader_v3").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	g.save_path = dir.path_join("partida.jsonl")
	ok(g.new_session(7), "partida nueva")
	rd = Reader.new()
	rd.sounds = false
	tree.root.add_child(rd)
	eq(rd.tool_names(), [], "cerrado: sin controles")
	var opened := false
	for ref in ["D03@tomo", "D01.TWIS@tomo", "D01.GREE@tomo"]:
		if rd.open(ref):
			opened = true
			break
	ok(opened, "abre una crónica del cliente")
	if opened:
		await tree.process_frame
		var flags: Dictionary = g.sim.q_ui()
		eq(rd.tool_names().has("Tijera"), bool(flags.get("desk.tijera", true)), "la tijera sigue a desk.tijera (%s)" % str(rd.tool_names()))
		ok(rd.tool_names().has("Volver"), "«Volver»")
		no(rd.tool_names().has("Zoom"), "sin indicador de zoom al abrir")
		has(g.sim.q_read(String(rd.view.view)), 0, "anotó la lectura de la hoja 1")
		if rd.page_count() > 1:
			rd.go_page(1)
			has(g.sim.q_read(String(rd.view.view)), 1, "y la de la hoja 2")
	ok(rd.open("D23@L1"), "abre el encargo")
	await tree.process_frame
	eq(rd.tool_names().has("Tijera"), bool(g.sim.q_ui().get("desk.tijera", true)), "tras leer el encargo, la tijera según la bandera")
	rd.close()
	eq(rd.tool_names(), [], "cerrado otra vez: sin controles")
	rd.free()
	rd = null
	g.end_session()
	g.repo_override = prev_repo
	g.save_path = prev_path
