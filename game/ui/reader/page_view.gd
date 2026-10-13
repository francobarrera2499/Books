# ui/reader/page_view.gd — una hoja del lector, con geometría en milímetros. Dueño: W2-READER. Contrato: §6.4, GDD§14.3.
# setup(view, page_idx, opts) arma la hoja: papel de época (color §6.2, grano, envejecido de bordes, pliegues de carta,
# verjurado, marco impreso del telegrama, filetes de columna del diario, renglones del registro, borde cortado a mano del
# papel del Diógenes) y un RichTextLabel por bloque (TextBuilder.build). El zoom NO vive aquí: DocumentReader escala
# el escenario con Control.scale; esta hoja sólo conoce px_per_mm (px a zoom 100 %), así la regla mide igual a todo zoom.
# px_per_mm: por defecto se ajusta para una medida de lectura cómoda (TARGET_EM del cuerpo) y para que el texto quepa en
# el papel (fit_scale); opts.px_per_mm lo fija (lupa, páginas hermanas: todas las hojas de una vista usan el mayor).
# Tijera: set_tijera(on) habilita la selección de los bloques; emite block_pressed/block_released (pos = canvas).
# Rasante: set_light(canvas_pos, zoom) mueve la lámpara de todos los bloques con <rasante> (rasante.gdshader).
# opts: px_per_mm (float), interactive (bool, true), hc (bool; por defecto ThemeInstaller.high_contrast).
extends Control

signal block_pressed(idx: int, pos: Vector2)
signal block_released(idx: int, pos: Vector2)

const Paper = preload("res://ui/kit/paper.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const RASANTE = preload("res://ui/reader/rasante.gdshader")

const TARGET_EM := {"imprenta": 27.0, "ui": 27.0, "maquina": 29.0, "manuscrito": 24.0}
const P_MIN := 1.4
const P_MAX := 7.0
const FIT_ITERS := 10
const PRINT_RED := Color("8a2b22")
const LIGHT_H_MM := 5.0
const LIGHT_REACH_MM := 110.0

var view := {}
var page_idx := 0
var paper := "carta"
var paper_mm := Vector2(178, 229)
var slot := "imprenta"
var machine := ""
var px_per_mm := 3.0
var hc := false
var interactive := true
var tijera := false
var blocks: Array = []           # RichTextLabel por bloque
var parsed: Array = []           # ParsedText por bloque
var overflow := false            # el texto no cupo ni con P_MAX (contenido demasiado largo para el papel)
var _mats: Array = []            # ShaderMaterial de bloques con rasante
var _edge_tex: GradientTexture2D = null
var _light_canvas := Vector2(-10000, -10000)
var _light_zoom := 1.0

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
	slot = String(view.get("font", "imprenta"))
	machine = String(view.get("machine", ""))
	interactive = bool(opts.get("interactive", true))
	# una hoja no interactiva (la copia de la lupa) nunca toma el mouse: va encima de la hoja real y se comía los clics
	# de la tijera (epílogo trabado en «tijera», W4)
	mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	var ti := TextBuilder.ti_node()
	hc = bool(opts.get("hc", ti != null and bool(ti.high_contrast)))
	_build_blocks()
	if opts.has("px_per_mm") and float(opts.px_per_mm) > 0.0:
		set_px_per_mm(float(opts.px_per_mm))
	else:
		set_px_per_mm(fit_scale())

# ------------------------------------------------------------------ geometría
func margins_mm() -> Rect2:
	var mx := clampf(paper_mm.x * 0.09, 9.0, 28.0)
	var mt := clampf(paper_mm.y * 0.075, 10.0, 30.0)
	if paper == "telegrama":
		mx = maxf(mx, 14.0)
		mt = maxf(mt, 16.0)
	if paper == "diogenes_recortado":
		mt = clampf(paper_mm.y * 0.05, 7.0, 16.0)   # el membrete se fue con el corte: el texto arranca más arriba
	return Rect2(mx, mt, paper_mm.x - 2.0 * mx, paper_mm.y - 2.0 * mt)

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
	var p := clampf(target_w / maxf(m.size.x, 10.0), P_MIN, P_MAX)
	overflow = false
	for _i in FIT_ITERS:
		_layout(p)
		var need := content_height()
		var avail := m.size.y * p
		if need <= avail + 0.5:
			return p
		if p >= P_MAX:
			overflow = true
			return P_MAX
		p = minf(P_MAX, p * maxf(1.02, sqrt(need / maxf(avail, 1.0)) * 1.01))
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
	var h := 0.0
	for i in blocks.size():
		var r: RichTextLabel = blocks[i]
		h += float(r.get_content_height())
		if i > 0:
			h += gap_px()
	return h

func _layout(p: float) -> void:
	var m := margins_mm()
	var x := m.position.x * p
	var w := maxf(40.0, m.size.x * p)
	var y := m.position.y * p
	for i in blocks.size():
		var r: RichTextLabel = blocks[i]
		r.position = Vector2(x, y)
		r.custom_minimum_size = Vector2(w, 0)
		r.size = Vector2(w, 0)
		var h := float(r.get_content_height())
		r.size = Vector2(w, h)
		y += h + gap_px()

# ------------------------------------------------------------------ bloques
func _build_blocks() -> void:
	for r in blocks:
		r.queue_free()
	blocks.clear()
	parsed.clear()
	_mats.clear()
	var pages: Array = view.get("pages", [])
	if page_idx < 0 or page_idx >= pages.size():
		return
	var i := 0
	for b in pages[page_idx]:
		var pt: Dictionary = b.get("parsed", {})
		var bslot := String(b.get("font", slot)) if b.get("font") != null else slot
		var r := TextBuilder.make_rtl(bslot)
		r.name = "Bloque%d" % i
		add_child(r)
		TextBuilder.build(r, pt, {"slot": bslot, "machine": machine, "hc": hc})
		r.add_theme_color_override("font_selected_color", Color(0, 0, 0, 0))
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

func _draw() -> void:
	var s := size
	var p := px_per_mm
	var pcol := Paper.paper(paper, 1 if hc else 0)
	var pts := outline_points()
	# sombra sobre la mesa
	if not hc:
		for k in 6:
			var g := float(6 - k) * 1.6
			var a := 0.05 + 0.02 * float(k)
			draw_rect(Rect2(Vector2(-g * 0.5, -g * 0.2 + 3.0), s + Vector2(g, g * 0.9)), Color(0.04, 0.03, 0.02, a))
	draw_colored_polygon(pts, pcol)
	if hc:
		draw_polyline(_closed(pts), Color(0, 0, 0, 1), 2.0)
		_draw_printed(true)
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
	_draw_printed(false)
	draw_polyline(_closed(pts), Color(Paper.edge(paper, 0), 0.55), 1.0)

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
		"diario_hueso":
			pass
		"strand":
			pass

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
			if not blocks.is_empty():
				var r0: RichTextLabel = blocks[0]
				if r0.get_line_count() > 0:
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
