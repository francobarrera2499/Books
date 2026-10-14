# ui/reader/page_view.gd — una hoja del lector, con geometría en milímetros. Dueño: LECTOR (antes W2-READER). §6.4, GDD§14.3.
# setup(view, page_idx, opts) arma la hoja: papel de época (color §6.2, grano, envejecido de bordes, pliegues de carta,
# verjurado, marco impreso del telegrama, filetes de columna del diario, renglones del registro, borde cortado a mano del
# papel del Diógenes) y un RichTextLabel por bloque (TextBuilder.build). El zoom NO vive aquí: DocumentReader escala
# el escenario con Control.scale; esta hoja sólo conoce px_per_mm (px a zoom 100 %).
# px_per_mm: por defecto se ajusta para una medida de lectura cómoda (TARGET_EM del cuerpo) y para que el texto quepa en
# el papel (fit_scale); opts.px_per_mm lo fija (páginas hermanas: todas las hojas de una vista usan el mayor).
# Tijera: set_tijera(on) habilita la selección de los bloques; emite block_pressed/block_released (pos = canvas).
# Rasante: set_light(canvas_pos, zoom) mueve la lámpara de todos los bloques con <rasante> (rasante.gdshader).
# opts: px_per_mm (float), interactive (bool, true), hc (bool; por defecto ThemeInstaller.high_contrast),
#   floating (bool, false: el lector v3 la pone en true -> sombra en perspectiva y luz de arriba a la izquierda).
#
# v3 (GDD_v3 §6.7; forma de q_view: bloques con slot "cuerpo"|"margen"|"tarjeta", anchor {block, tramo}, hand;
#   view.ficha {trata, cuando, por_que} | null; view.marks [{page, block, tramo}]):
#   - Si alguna hoja de la vista tiene bloques "margen", TODAS sus hojas (salvo la tarjeta) dejan a la derecha una columna
#     de 38 mm para las notas a lápiz, separada del cuerpo por 6 mm de papel en blanco; cada nota se alinea con la primera
#     línea de su tramo ancla y, si choca con la anterior, baja. Letra manuscrita gris, más chica que el cuerpo.
#   - A la izquierda del cuerpo, una columna de 14 mm para las marquitas del cliente: raya doble a lápiz grueso a la
#     altura del tramo marcado (dibujo, no texto; mark_rects()).
#   - Hoja 0 con view.ficha: tres renglones de Lisle en tinta tenue arriba del texto, NO recortables (no son bloques).
#   - Hoja hecha sólo de bloques "tarjeta": la tarjeta del cliente, en cartulina (Paper "tarjeta"), más chica (127×76 mm o
#     el paper_mm del bloque), con un clip dibujado arriba; el texto se recorta como cualquier bloque. Conserva su forma:
#     si a la escala de la crónica el texto no cabe, baja la letra hasta 72 % y después crece entera (_fit_card).
#   Los índices de blocks/parsed son los de q_view.pages[i] (el recorte usa ese índice), sea cual sea el slot.
extends Control

signal block_pressed(idx: int, pos: Vector2)
signal block_released(idx: int, pos: Vector2)

const Paper = preload("res://ui/kit/paper.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const RASANTE = preload("res://ui/reader/rasante.gdshader")

const TARGET_EM := {"imprenta": 27.0, "ui": 27.0, "maquina": 29.0, "manuscrito": 24.0}
const P_MIN := 1.4
const P_MAX := 7.0
const MIN_W_MM := 90.0
const FIT_ITERS := 10
const PRINT_RED := Color("8a2b22")
const LIGHT_H_MM := 5.0
const LIGHT_REACH_MM := 110.0
# v3
const MARK_COL_MM := 14.0
const NOTE_COL_MM := 38.0
const NOTE_GAP_MM := 6.0
const NOTE_EDGE_MM := 6.0
const CARD_MM := Vector2(127, 76)
const NOTE_K := 0.86            # letra de las notas al margen (× cuerpo)
const CARD_K := 1.32            # letra de la tarjeta (lápiz grueso, grande)
const CARD_K_STEPS := [0.92, 0.85, 0.78, 0.72]   # si no cabe en 127×76 a la escala de la crónica, la letra baja así
const FICHA_K := 0.86           # letra de la ficha de Lisle
const FICHA_INK := Color("6a5d4b")   # tinta tenue, pero legible sobre el papel (contraste ≥ 4,5:1)
const CARD_INK := Color("343230")    # lápiz grueso
const SHADOW_DEG := 2.0
const SHADOW_OFF := Vector2(10, 14)

var view := {}
var page_idx := 0
var paper := "carta"
var paper_mm := Vector2(178, 229)
var slot := "imprenta"
var machine := ""
var px_per_mm := 3.0
var hc := false
var interactive := true
var floating := false
var measure_cap := 0.0          # opts.measure_cap (> 0: tope de la medida de línea, × la cómoda)
var tijera := false
var blocks: Array = []           # RichTextLabel por bloque (índice = el de q_view.pages[i])
var parsed: Array = []           # ParsedText por bloque
var slots: Array = []            # "cuerpo" | "margen" | "tarjeta" por bloque
var anchors: Array = []          # {block, tramo} por bloque ({} si no tiene)
var overflow := false            # el texto no cupo ni con P_MAX (contenido demasiado largo para el papel)
var card := false                # hoja = tarjeta del cliente
var margin_col := false          # la vista tiene notas al margen: columna derecha de 38 mm
var ficha: Dictionary = {}       # sólo la hoja 0
var marks: Array = []            # [{block, tramo}] de esta hoja
var ficha_rtl: RichTextLabel = null
var card_k := 1.0                # escala de la letra de la tarjeta (× CARD_K; < 1 si el texto no cabía en la cartulina)
var _need := 0.0                # alto del contenido (px) en el último _layout
var _mats: Array = []            # ShaderMaterial de bloques con rasante
var _edge_tex: GradientTexture2D = null
var _light_canvas := Vector2(-10000, -10000)
var _light_zoom := 1.0
static var _light_tex: GradientTexture2D = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	clip_contents = false

func setup(p_view: Dictionary, p_page := 0, opts := {}) -> void:
	view = p_view
	page_idx = p_page
	paper = String(view.get("paper", "carta"))
	var mm: Array = view.get("paper_mm", [178, 229])
	paper_mm = Vector2(float(mm[0]), float(mm[1]))
	# playtest v3: una tira angosta (el señalador de HA2, 22 × 190 mm) salía de a 1–4 letras por renglón. Una tira se
	# muestra ACOSTADA (como se la deja sobre la mesa para leerla) y ningún papel se dibuja más angosto que MIN_W_MM (la
	# medida real sigue en su línea de descripción física).
	if paper_mm.x < MIN_W_MM and paper_mm.y >= paper_mm.x * 3.0:
		paper_mm = Vector2(paper_mm.y, paper_mm.x)
	paper_mm.x = maxf(paper_mm.x, MIN_W_MM)
	slot = String(view.get("font", "imprenta"))
	machine = String(view.get("machine", ""))
	interactive = bool(opts.get("interactive", true))
	floating = bool(opts.get("floating", false))
	measure_cap = float(opts.get("measure_cap", 0.0))
	# una hoja no interactiva (la copia de la lupa) nunca toma el mouse: va encima de la hoja real y se comía los clics
	# de la tijera (epílogo trabado en «tijera», W4)
	mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	var ti := TextBuilder.ti_node()
	hc = bool(opts.get("hc", ti != null and bool(ti.high_contrast)))
	var pages: Array = view.get("pages", [])
	var pg: Array = pages[page_idx] if page_idx >= 0 and page_idx < pages.size() else []
	card = is_card_page(pg)
	margin_col = (not card) and view_has_margin(view)
	if card:
		paper = "tarjeta"
		var bmm = pg[0].get("paper_mm")
		paper_mm = Vector2(float(bmm[0]), float(bmm[1])) if typeof(bmm) == TYPE_ARRAY and bmm.size() == 2 else CARD_MM
		machine = ""
	ficha = {}
	var fi = view.get("ficha")
	if page_idx == 0 and not card and typeof(fi) == TYPE_DICTIONARY and ficha_text(fi) != "":
		ficha = fi
	marks = []
	for m in view.get("marks", []):
		if typeof(m) == TYPE_DICTIONARY and int(m.get("page", -1)) == page_idx:
			marks.append({"block": int(m.get("block", 0)), "tramo": String(m.get("tramo", ""))})
	card_k = 1.0
	_build_blocks()
	if opts.has("px_per_mm") and float(opts.px_per_mm) > 0.0:
		set_px_per_mm(float(opts.px_per_mm))
	else:
		set_px_per_mm(fit_scale())
	if card and overflow:
		_fit_card()

# La tarjeta conserva su forma (127 × 76 mm: su descripción dice «13 × 8 cm»). Con la escala de una crónica angosta
# (sin columna de notas) el texto del cliente no cabía y la cartulina se estiraba hacia abajo hasta quedar cuadrada:
# primero baja la letra (hasta 72 % de la grande) y, si aún no cabe, la tarjeta entera crece con sus proporciones.
func _fit_card() -> void:
	var p := px_per_mm
	var pages: Array = view.get("pages", [])
	var pg: Array = pages[page_idx]
	for k in CARD_K_STEPS:
		card_k = float(k)
		for i in blocks.size():
			if slots[i] == "tarjeta":
				var b: Dictionary = pg[i]
				var bslot := String(b.get("font")) if b.get("font") != null else "manuscrito"
				TextBuilder.build(blocks[i], parsed[i], {"slot": bslot, "machine": "", "hc": hc, "size": _card_px(bslot)})
		set_px_per_mm(p)
		if not overflow:
			return
	var guard := 0
	while overflow and p < P_MAX and guard < 40:
		p = minf(P_MAX, p * 1.05)
		guard += 1
		set_px_per_mm(p)

func _card_px(bslot: String) -> int:
	return int(round(doc_px() * CARD_K * card_k * float(TextBuilder.SLOT_FACTOR.get(bslot, 1.0))))

# ------------------------------------------------------------------ consultas de forma (estáticas: el lector las usa)
static func block_slot(b: Dictionary) -> String:
	var s := String(b.get("slot", "cuerpo")) if b.get("slot") != null else "cuerpo"
	return s if s in ["margen", "tarjeta"] else "cuerpo"

static func is_card_page(pg: Array) -> bool:
	if pg.is_empty():
		return false
	for b in pg:
		if typeof(b) != TYPE_DICTIONARY or block_slot(b) != "tarjeta":
			return false
	return true

static func view_has_margin(v: Dictionary) -> bool:
	for pg in v.get("pages", []):
		if typeof(pg) != TYPE_ARRAY:
			continue
		for b in pg:
			if typeof(b) == TYPE_DICTIONARY and block_slot(b) == "margen":
				return true
	return false

static func ficha_text(fi: Dictionary) -> String:
	var lines: Array = []
	for k in ["trata", "cuando", "por_que"]:
		var s := String(fi.get(k, "")).strip_edges() if fi.get(k) != null else ""
		if s != "":
			lines.append(s)
	return "\n".join(PackedStringArray(lines))

static func tramo_range(pt: Dictionary, tramo: String) -> Vector2i:
	if tramo == "":
		return Vector2i(-1, -1)
	for t in pt.get("tramos", []):
		if typeof(t) == TYPE_DICTIONARY and String(t.get("id", "")) == tramo:
			return Vector2i(int(t.get("from", 0)), int(t.get("to", 0)))
	return Vector2i(-1, -1)

# ------------------------------------------------------------------ geometría
func margins_mm() -> Rect2:
	if card:
		return Rect2(11.0, 17.0, paper_mm.x - 22.0, paper_mm.y - 17.0 - 9.0)
	var mx := clampf(paper_mm.x * 0.09, 9.0, 28.0)
	var mt := clampf(paper_mm.y * 0.075, 10.0, 30.0)
	if paper == "telegrama":
		mx = maxf(mx, 14.0)
		mt = maxf(mt, 16.0)
	if paper == "diogenes_recortado":
		mt = clampf(paper_mm.y * 0.05, 7.0, 16.0)   # el membrete se fue con el corte: el texto arranca más arriba
	if margin_col or not (view.get("marks", []) as Array).is_empty():
		var left := maxf(mx, MARK_COL_MM + 2.0)
		var right := (NOTE_EDGE_MM + NOTE_COL_MM + NOTE_GAP_MM) if margin_col else mx
		return Rect2(left, mt, maxf(20.0, paper_mm.x - left - right), paper_mm.y - 2.0 * mt)
	return Rect2(mx, mt, paper_mm.x - 2.0 * mx, paper_mm.y - 2.0 * mt)

# Columna de las notas al margen (mm); vacía si la vista no tiene notas.
func note_col_mm() -> Rect2:
	if not margin_col:
		return Rect2()
	var m := margins_mm()
	return Rect2(paper_mm.x - NOTE_EDGE_MM - NOTE_COL_MM, m.position.y, NOTE_COL_MM, m.size.y)

func paper_px() -> Vector2:
	return paper_mm * px_per_mm

func content_rect_px() -> Rect2:
	var m := margins_mm()
	return Rect2(m.position * px_per_mm, m.size * px_per_mm)

func doc_px() -> float:
	var ti := TextBuilder.ti_node()
	return 21.0 if ti == null else float(ti.px("doc"))

func gap_px() -> float:
	return roundf(doc_px() * 0.9)

func fit_scale() -> float:
	var m := margins_mm()
	var target_w := float(TARGET_EM.get(slot, 27.0)) * doc_px() * float(TextBuilder.SLOT_FACTOR.get(slot, 1.0))
	if card:
		target_w *= CARD_K * 0.8
	var p := clampf(target_w / maxf(m.size.x, 10.0), P_MIN, P_MAX)
	# measure_cap (lector flotante): la línea no se estira más que esa proporción de la medida cómoda; si el texto no
	# cabe, la hoja se alarga hacia abajo (se lee desplazando) en vez de ensancharse.
	var p_top := P_MAX if measure_cap <= 0.0 else clampf(p * measure_cap, P_MIN, P_MAX)
	overflow = false
	for _i in FIT_ITERS:
		_layout(p)
		var need := content_height()
		var avail := m.size.y * p
		if need <= avail + 0.5:
			return p
		if p >= p_top:
			overflow = true
			return p_top
		p = minf(p_top, p * maxf(1.02, sqrt(need / maxf(avail, 1.0)) * 1.01))
	_layout(p)
	overflow = content_height() > m.size.y * p + 0.5
	return p

func set_px_per_mm(p: float) -> void:
	px_per_mm = p
	_layout(p)
	var need := content_height()
	overflow = need > margins_mm().size.y * p + 0.5
	var sz := paper_px()
	if overflow:
		sz.y = (margins_mm().position.y * 2.0) * p + need
	custom_minimum_size = sz
	size = sz
	queue_redraw()

func content_height() -> float:
	return _need

func _layout(p: float) -> void:
	var m := margins_mm()
	var x := m.position.x * p
	var w := maxf(40.0, m.size.x * p)
	var top := m.position.y * p
	var y := top
	if ficha_rtl != null:
		ficha_rtl.position = Vector2(x, y)
		ficha_rtl.custom_minimum_size = Vector2(w, 0)
		ficha_rtl.size = Vector2(w, 0)
		var fh := float(ficha_rtl.get_content_height())
		ficha_rtl.size = Vector2(w, fh)
		y += fh + gap_px() * 1.4
	var body_end := y
	var any_body := false
	for i in blocks.size():
		if slots[i] == "margen":
			continue
		var r: RichTextLabel = blocks[i]
		r.position = Vector2(x, y)
		r.custom_minimum_size = Vector2(w, 0)
		r.size = Vector2(w, 0)
		var h := float(r.get_content_height())
		r.size = Vector2(w, h)
		body_end = y + h
		any_body = true
		y += h + gap_px()
	if not any_body and ficha_rtl != null:
		body_end = y
	# notas al margen: alineadas con su ancla, apiladas hacia abajo si chocan
	var notes_end := top
	if margin_col:
		var nc := note_col_mm()
		var nx := nc.position.x * p
		var nw := maxf(30.0, nc.size.x * p)
		var order: Array = []
		for i in blocks.size():
			if slots[i] == "margen":
				var r: RichTextLabel = blocks[i]
				r.custom_minimum_size = Vector2(nw, 0)
				r.size = Vector2(nw, 0)
				r.size = Vector2(nw, float(r.get_content_height()))
				order.append([_anchor_y(i, top), i])
		order.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var floor_y := top
		for o in order:
			var r: RichTextLabel = blocks[o[1]]
			var yy := maxf(float(o[0]), floor_y)
			r.position = Vector2(nx, yy)
			floor_y = yy + r.size.y + gap_px() * 0.5
			notes_end = yy + r.size.y
	_need = maxf(body_end, notes_end) - top

# y (px de la hoja) de la primera línea del tramo ancla de la nota i; arriba del contenido si no se encuentra.
func _anchor_y(i: int, top: float) -> float:
	var a = anchors[i]
	if typeof(a) != TYPE_DICTIONARY or a.is_empty():
		return top
	var bi := int(a.get("block", 0))
	if bi < 0 or bi >= blocks.size() or slots[bi] == "margen":
		return top
	var r: RichTextLabel = blocks[bi]
	var rg := tramo_range(parsed[bi], String(a.get("tramo", "")))
	if rg.x < 0:
		return r.position.y
	var ln := r.get_character_line(rg.x)
	if ln < 0:
		return r.position.y
	return r.position.y + float(r.get_line_offset(ln))

# Rectángulos (px de la hoja) de las marquitas del cliente: [{tramo, rect}] (la raya doble ocupa la columna izquierda,
# desde la primera hasta la última línea del tramo, como mucho 6 líneas).
func mark_rects() -> Array:
	var out: Array = []
	var p := px_per_mm
	var m := margins_mm()
	var cx := (m.position.x - MARK_COL_MM * 0.5) * p
	for mk in marks:
		var bi := int(mk.block)
		if bi < 0 or bi >= blocks.size() or slots[bi] == "margen":
			continue
		var r: RichTextLabel = blocks[bi]
		var rg := tramo_range(parsed[bi], String(mk.tramo))
		if rg.x < 0:
			continue
		var l0 := r.get_character_line(rg.x)
		var l1 := r.get_character_line(maxi(rg.x, rg.y - 1))
		if l0 < 0:
			continue
		if l1 < l0:
			l1 = l0
		l1 = mini(l1, l0 + 5)
		var y0 := r.position.y + float(r.get_line_offset(l0)) + float(r.get_line_height(l0)) * 0.12
		var y1 := r.position.y + float(r.get_line_offset(l1)) + float(r.get_line_height(l1)) * 0.88
		out.append({"tramo": String(mk.tramo), "rect": Rect2(cx - 1.3 * p, y0, 2.6 * p, maxf(y1 - y0, 4.0))})
	return out

# ------------------------------------------------------------------ bloques
func _build_blocks() -> void:
	for r in blocks:
		r.queue_free()
	blocks.clear()
	parsed.clear()
	slots.clear()
	anchors.clear()
	_mats.clear()
	if ficha_rtl != null:
		ficha_rtl.queue_free()
		ficha_rtl = null
	var pages: Array = view.get("pages", [])
	if page_idx < 0 or page_idx >= pages.size():
		return
	var dpx := doc_px()
	if not ficha.is_empty():
		ficha_rtl = TextBuilder.make_rtl("manuscrito")
		ficha_rtl.name = "Ficha"
		ficha_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ficha_rtl.selection_enabled = false
		ficha_rtl.clip_contents = false   # ver abajo (glifos manuscritos que salen de la caja)
		add_child(ficha_rtl)
		TextBuilder.build(ficha_rtl, {"plain": ficha_text(ficha), "styles": []},
			{"slot": "manuscrito", "hc": hc, "size": int(round(dpx * FICHA_K * float(TextBuilder.SLOT_FACTOR["manuscrito"])))})
		ficha_rtl.add_theme_color_override("default_color", Paper.ink("tenue", 1) if hc else FICHA_INK)
		ficha_rtl.add_theme_constant_override("line_separation", -int(round(dpx * 0.18)))
	var i := 0
	for b in pages[page_idx]:
		var pt: Dictionary = b.get("parsed", {})
		var bs := block_slot(b)
		var bslot := String(b.get("font", slot)) if b.get("font") != null else slot
		var opts := {"slot": bslot, "machine": machine, "hc": hc}
		if bs == "margen":
			bslot = String(b.get("font")) if b.get("font") != null else "manuscrito"
			opts = {"slot": bslot, "machine": "", "hc": hc, "size": int(round(dpx * NOTE_K * float(TextBuilder.SLOT_FACTOR.get(bslot, 1.0))))}
		elif bs == "tarjeta":
			bslot = String(b.get("font")) if b.get("font") != null else "manuscrito"
			opts = {"slot": bslot, "machine": "", "hc": hc, "size": _card_px(bslot)}
		var r := TextBuilder.make_rtl(bslot)
		r.name = "Bloque%d" % i
		# RichTextLabel recorta a su caja por defecto: la «j» manuscrita a principio de renglón (la ficha: «juntos») y los
		# rasgos bajos del último renglón con interlineado negativo salían mochos. Los bloques miden su contenido
		# (fit_content), así que no hace falta recortar nada.
		r.clip_contents = false
		add_child(r)
		TextBuilder.build(r, pt, opts)
		r.add_theme_color_override("font_selected_color", Color(0, 0, 0, 0))
		if bs == "margen":
			r.add_theme_color_override("default_color", Paper.ink("lapiz", 1 if hc else 0))
			r.add_theme_constant_override("line_separation", -int(round(dpx * 0.2)))
		elif bs == "tarjeta":
			r.add_theme_color_override("default_color", Paper.ink("negra", 1) if hc else CARD_INK)
			r.add_theme_constant_override("line_separation", -int(round(dpx * 0.15)))
		if bool(r.get_meta("fe_has_rasante", false)) and not hc:
			var mat := ShaderMaterial.new()
			mat.shader = RASANTE
			r.material = mat
			_mats.append(mat)
		if interactive:
			r.gui_input.connect(_on_block_input.bind(i))
		else:
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocks.append(r)
		parsed.append(pt)
		slots.append(bs)
		var an = b.get("anchor")
		anchors.append(an if typeof(an) == TYPE_DICTIONARY else {})
		i += 1
	_apply_light()

func block_count() -> int:
	return blocks.size()

func has_rasante() -> bool:
	return not _mats.is_empty()

func set_tijera(on: bool) -> void:
	tijera = on
	# toda la hoja muestra la tijera (no sólo los renglones): el cursor IBEAM es el de la tijera mientras está en la mano
	mouse_default_cursor_shape = Control.CURSOR_IBEAM if (on and interactive) else Control.CURSOR_ARROW
	for r in blocks:
		var rt: RichTextLabel = r
		if not on:
			rt.deselect()
		rt.selection_enabled = on and interactive
		rt.mouse_default_cursor_shape = Control.CURSOR_IBEAM if on else Control.CURSOR_ARROW

func deselect_all(except := -1) -> void:
	for i in blocks.size():
		if i != except:
			(blocks[i] as RichTextLabel).deselect()

func selected_block() -> int:
	for i in blocks.size():
		if (blocks[i] as RichTextLabel).get_selected_text() != "":
			return i
	return -1

func _on_block_input(ev: InputEvent, idx: int) -> void:
	if not tijera:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var r: RichTextLabel = blocks[idx]
		var pos: Vector2 = r.get_global_transform_with_canvas() * ev.position
		if ev.pressed:
			deselect_all(idx)
			block_pressed.emit(idx, pos)
		else:
			block_released.emit(idx, pos)

# ------------------------------------------------------------------ luz rasante
func set_light(canvas_pos: Vector2, zoom := 1.0) -> void:
	_light_canvas = canvas_pos
	_light_zoom = zoom
	_apply_light()

func _apply_light() -> void:
	# la lámpara: 5 mm sobre el papel, alumbra hasta 110 mm (en px de pantalla: mm × px_per_mm × zoom)
	var k := px_per_mm * _light_zoom
	for m in _mats:
		var mat: ShaderMaterial = m
		mat.set_shader_parameter("light_pos", _light_canvas)
		mat.set_shader_parameter("light_height", LIGHT_H_MM * k)
		mat.set_shader_parameter("reach", LIGHT_REACH_MM * k)

# ------------------------------------------------------------------ papel
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _edge() -> GradientTexture2D:
	if _edge_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		g.colors = PackedColorArray([Color(0.42, 0.30, 0.15, 0.0), Color(0.42, 0.30, 0.15, 0.0), Color(0.42, 0.30, 0.15, 0.20)])
		_edge_tex = GradientTexture2D.new()
		_edge_tex.gradient = g
		_edge_tex.fill = GradientTexture2D.FILL_SQUARE
		_edge_tex.fill_from = Vector2(0.5, 0.5)
		_edge_tex.fill_to = Vector2(1.0, 0.5)
		_edge_tex.width = 128
		_edge_tex.height = 128
	return _edge_tex

# Luz muy leve de arriba a la izquierda (hoja levantada frente a la cara).
static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.99, 0.95, 0.10), Color(1.0, 0.99, 0.95, 0.0), Color(0.30, 0.22, 0.12, 0.07)])
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_LINEAR
		_light_tex.fill_from = Vector2(0.0, 0.0)
		_light_tex.fill_to = Vector2(1.0, 1.0)
		_light_tex.width = 128
		_light_tex.height = 128
	return _light_tex

func outline_points() -> PackedVector2Array:
	var s := size
	if paper == "diogenes_recortado" and not hc:
		# corte a mano con cuchilla: el filo superior baja ~0,7 mm de izquierda a derecha, con dos mellas mínimas
		var p := px_per_mm
		var pts := PackedVector2Array()
		pts.append(Vector2(0, 0.15 * p))
		var n := 9
		for k in range(1, n):
			var t := float(k) / float(n)
			var nick := 0.0
			if k == 3 or k == 7:
				nick = 0.22 * p
			pts.append(Vector2(s.x * t, (0.15 + 0.7 * t) * p + nick))
		pts.append(Vector2(s.x, 0.85 * p))
		pts.append(Vector2(s.x, s.y))
		pts.append(Vector2(0, s.y))
		return pts
	return PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])

# Sombra de la hoja levantada: la luz viene de arriba a la izquierda, así que la sombra cae abajo a la derecha, corrida
# SHADOW_OFF y con el borde derecho inclinado SHADOW_DEG (más lejos abajo: perspectiva de una hoja que se separa de la
# mesa); en capas que se esfuman. El papel no se inclina: sólo su sombra. Nunca asoma por arriba ni por la izquierda.
func shadow_polygons() -> Array:
	var s := size
	var slant := minf(tan(deg_to_rad(SHADOW_DEG)) * s.y, 30.0)
	var out: Array = []
	for k in 7:
		var g := float(k) * 2.4
		var o := SHADOW_OFF
		out.append(PackedVector2Array([
			Vector2(o.x + g * 0.4, o.y + g * 0.4),
			Vector2(s.x + o.x + g, o.y + g * 0.4),
			Vector2(s.x + o.x + slant + g, s.y + o.y + g),
			Vector2(o.x + g * 0.4, s.y + o.y + g * 0.8)]))
	return out

func _draw() -> void:
	var s := size
	var p := px_per_mm
	var pcol := Paper.paper(paper, 1 if hc else 0)
	var pts := outline_points()
	if not hc:
		if floating:
			var polys := shadow_polygons()
			for k in range(polys.size() - 1, -1, -1):
				draw_colored_polygon(polys[k], Color(0.02, 0.015, 0.01, 0.03 + 0.012 * float(polys.size() - 1 - k)))
		else:
			# sombra sobre la mesa
			for k in 6:
				var g := float(6 - k) * 1.6
				var a := 0.05 + 0.02 * float(k)
				draw_rect(Rect2(Vector2(-g * 0.5, -g * 0.2 + 3.0), s + Vector2(g, g * 0.9)), Color(0.04, 0.03, 0.02, a))
	draw_colored_polygon(pts, pcol)
	if hc:
		draw_polyline(_closed(pts), Color(0, 0, 0, 1), 2.0)
		_draw_printed(true)
		_draw_v3(true)
		return
	# grano y manchas (en mm: el grano es del papel, crece con el zoom como el papel)
	var tile := 110.0 * p / 3.0
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	for q in pts:
		uvs.append(q / tile)
		uvs2.append(q / (tile * 2.6))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.10), uvs2, Paper.mottle_texture())
	draw_colored_polygon(pts, Color(1, 1, 1, 0.07), uvs, Paper.grain_texture())
	_draw_paper_details()
	# envejecido de bordes
	draw_texture_rect(_edge(), Rect2(Vector2.ZERO, s), false)
	if floating:
		draw_texture_rect(light_texture(), Rect2(Vector2.ZERO, s), false)
	_draw_printed(false)
	draw_polyline(_closed(pts), Color(Paper.edge(paper, 0), 0.55), 1.0)
	_draw_v3(false)

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c

func _fold(y: float, strength := 1.0) -> void:
	var w := size.x
	draw_line(Vector2(0, y - 1.0), Vector2(w, y - 1.0), Color(1, 1, 1, 0.20 * strength), 1.0)
	draw_line(Vector2(0, y), Vector2(w, y), Color(0.35, 0.25, 0.12, 0.10 * strength), 1.0)
	draw_line(Vector2(0, y + 1.0), Vector2(w, y + 1.0), Color(0.35, 0.25, 0.12, 0.04 * strength), 1.0)

func _draw_paper_details() -> void:
	var s := size
	var p := px_per_mm
	match paper:
		"carta", "diogenes_recortado":
			# verjurado: corondeles cada 25 mm
			var x := 12.0 * p
			while x < s.x:
				draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.45, 0.35, 0.2, 0.035), maxf(1.0, 0.25 * p))
				x += 25.0 * p
			_fold(s.y / 3.0)
			_fold(s.y * 2.0 / 3.0)
		"telegrama":
			_fold(s.y * 0.5, 0.8)
		"tarjeta":
			# cartulina: fibra un poco más marcada
			var y := 3.0 * p
			while y < s.y:
				draw_line(Vector2(0, y), Vector2(s.x, y + 0.6 * p), Color(0.45, 0.35, 0.2, 0.025), 1.0)
				y += 2.2 * p

# Lo «impreso» en el papel (no es texto del documento): filetes, marcos, renglones. También en alto contraste.
func _draw_printed(hcm: bool) -> void:
	var p := px_per_mm
	var cr := content_rect_px()
	var ink := Color(0, 0, 0, 0.8) if hcm else Color(Paper.INKS["negra"], 0.55)
	match paper:
		"diario_hueso":
			# filetes de columna a ambos lados y filete doble de cabeza
			var gx := 3.5 * p
			var top := cr.position.y - 4.0 * p
			draw_line(Vector2(cr.position.x - gx, top), Vector2(cr.position.x - gx, size.y - 6.0 * p), ink, 1.0)
			draw_line(Vector2(cr.end.x + gx, top), Vector2(cr.end.x + gx, size.y - 6.0 * p), ink, 1.0)
			draw_line(Vector2(cr.position.x - gx, top), Vector2(cr.end.x + gx, top), ink, maxf(1.0, 0.5 * p))
			draw_line(Vector2(cr.position.x - gx, top + 1.2 * p), Vector2(cr.end.x + gx, top + 1.2 * p), ink, 1.0)
		"strand":
			var y := cr.position.y - 4.5 * p
			draw_line(Vector2(cr.position.x, y), Vector2(cr.end.x, y), ink, 1.0)
		"telegrama":
			var red := Color(0, 0, 0, 0.7) if hcm else Color(PRINT_RED, 0.55)
			var r1 := Rect2(Vector2(5.0, 5.0) * p, size - Vector2(10.0, 10.0) * p)
			var r2 := r1.grow(-1.1 * p)
			draw_rect(r1, red, false, maxf(1.0, 0.45 * p))
			draw_rect(r2, red, false, 1.0)
		"registro", "libro_mayor", "cuaderno":
			var blue := Color(0, 0, 0, 0.3) if hcm else Color(Paper.RULE_BLUE, 0.45)
			var step := doc_px() * 1.0
			var y0 := cr.position.y
			var r0: RichTextLabel = null
			for i in blocks.size():
				if slots[i] != "margen":
					r0 = blocks[i]
					break
			if r0 != null and r0.get_line_count() > 0:
				step = maxf(8.0, float(r0.get_line_height(0)))
				if r0.get_line_count() > 1:
					step = maxf(8.0, float(r0.get_line_offset(1) - r0.get_line_offset(0)))
				var f: Font = r0.get_theme_font("normal_font")
				var fs: int = r0.get_theme_font_size("normal_font_size")
				y0 = r0.position.y + float(r0.get_line_offset(0)) + f.get_ascent(fs) + float(fs) * 0.16
			var yy := y0
			while yy - step > 8.0 * p:
				yy -= step
			while yy < size.y - 4.0 * p:
				if yy > 6.0 * p:
					draw_line(Vector2(4.0 * p, yy), Vector2(size.x - 4.0 * p, yy), blue, 1.0)
				yy += step
			var red2 := Color(0, 0, 0, 0.5) if hcm else Color(Paper.INKS["roja"], 0.45)
			var mx := cr.position.x - 3.0 * p
			draw_line(Vector2(mx, 0), Vector2(mx, size.y), red2, 1.0)
			draw_line(Vector2(mx - 0.9 * p, 0), Vector2(mx - 0.9 * p, size.y), red2, 1.0)

# Marquitas del cliente y el clip de la tarjeta.
func _draw_v3(hcm: bool) -> void:
	var p := px_per_mm
	var lap := Color(0, 0, 0, 0.9) if hcm else Color(Paper.INKS["lapiz"], 0.78)
	for mr in mark_rects():
		var r: Rect2 = mr.rect
		var lw := maxf(1.5, 0.5 * p)
		var seed := float(r.position.y) * 0.013
		for k in 2:
			var x := r.position.x + (0.45 + 1.7 * float(k)) * p
			var pts := PackedVector2Array()
			var n := 6
			var y_end := r.end.y - float(k) * 0.6 * p
			for j in n + 1:
				var t := float(j) / float(n)
				var wob := sin(seed + t * 5.1 + float(k) * 1.7) * 0.22 * p
				pts.append(Vector2(x + wob, lerpf(r.position.y + float(k) * 0.4 * p, y_end, t)))
			draw_polyline(pts, lap, lw, true)
			if not hcm:
				# grafito: un segundo trazo más fino y claro, apenas corrido
				var pts2 := PackedVector2Array()
				for q in pts:
					pts2.append(q + Vector2(0.25 * p, 0.15 * p))
				draw_polyline(pts2, Color(lap, 0.28), lw * 0.6, true)
	if card:
		_draw_clip(hcm)

# Clip de alambre sobre el borde de arriba de la tarjeta (dos lazos alargados, uno dentro del otro).
func _draw_clip(hcm: bool) -> void:
	var p := px_per_mm
	var cx := size.x * 0.16
	var steel := Color(0, 0, 0, 1) if hcm else Color(0.43, 0.44, 0.46, 1.0)
	var shine := Color(0.9, 0.91, 0.93, 0.7)
	var lw := maxf(2.0, 0.75 * p)
	var outer := _stadium(Vector2(cx, -8.0 * p), Vector2(cx, 10.5 * p), 3.2 * p, 0.0)
	var inner := _stadium(Vector2(cx + 0.2 * p, -5.0 * p), Vector2(cx + 0.2 * p, 6.5 * p), 1.8 * p, 0.12)
	if not hcm:
		var sh := PackedVector2Array()
		for q in outer:
			sh.append(q + Vector2(0.7 * p, 0.9 * p))
		draw_polyline(sh, Color(0.1, 0.07, 0.04, 0.22), lw * 1.3, true)
	draw_polyline(outer, steel, lw, true)
	draw_polyline(inner, steel, lw, true)
	if not hcm:
		var hi := PackedVector2Array()
		for q in outer:
			hi.append(q + Vector2(-0.18 * p, -0.18 * p))
		draw_polyline(hi, shine, lw * 0.3, true)

# Contorno de un «estadio» vertical entre a (arriba) y b (abajo), radio r; gap = fracción del contorno que queda abierta.
func _stadium(a: Vector2, b: Vector2, r: float, gap: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for j in n + 1:
		var t := PI + PI * float(j) / float(n)
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	for j in n + 1:
		var t := PI * float(j) / float(n)
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	pts.append(pts[0])
	if gap > 0.0:
		var keep := int(round(float(pts.size()) * (1.0 - gap)))
		pts = pts.slice(0, maxi(2, keep))
	return pts
