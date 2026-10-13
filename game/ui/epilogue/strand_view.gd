# ui/epilogue/strand_view.gd — la Strand de octubre de 1903 vista por Lisle (W4-EPILOGUE; GDD §12.3, ARCHITECTURE §6.4).
# Una hoja de q_view (PageView de W2-READER, sin tocarlo) cubierta por la «vista» de Lisle (sight.gdshader: borrosa,
# velada) y una lupa (Loupe: segunda hoja nítida, aumentada, recortada en un disco con aro de latón) que sigue al mouse
# sobre la hoja; fuera de la hoja, la lupa queda posada donde Lisle está leyendo (park). Tijera: selección nativa del
# RichTextLabel (arrastrar) o un clic sobre una oración (Lisle corta «entre punto y punto»): emite cut_requested(page,
# from, len) con la oración entera bajo el clic si no hubo arrastre. Marcas de variante (GDD §12.2): subraya (lápiz bajo
# el desmayo, watson_expuesto) y nota_azul (F1: esquina doblada, corchete y nota azul de S. H.), en la hoja y en la lupa.
# Sin brillos ni resaltados de interés: la lupa no distingue lo importante, sólo enfoca. Animaciones ≤0,4 s.
#   setup(view, avail: Vector2) · show_page(i) · page_count() · park(t:{page,from,to}, instant) · set_scissors(on)
#   set_marks(marks, note_text) · park_note() · follow(canvas_pos) · tramo_rect(from, to) -> Rect2 (canvas) · char_at(rtl, p)
#   Hojas: ‹ Hoja n de m › bajo la hoja (Widgets.ink_button). lens_on = false guarda la lupa (confirmaciones encima).
extends Control

signal cut_requested(page: int, from: int, length: int)
signal page_turned(idx: int)

const Paper = preload("res://ui/kit/paper.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Markup = preload("res://core/text/markup.gd")
const SIGHT = preload("res://ui/epilogue/sight.gdshader")

const MAG := 1.75
const RADIUS := 150.0
const GLIDE_S := 0.4
const NAV_INK := Color("d8ccb0")

var view := {}
var page_idx := 0
var px_per_mm := 3.0
var page: Control = null            # PageView visible (borrosa)
var sight: ColorRect
var loupe: Loupe
var scissors := false
var lens_on := true                  # false: la lupa se guarda (p. ej. con una confirmación encima)
var marks: Array = []
var note_text := ""
var fast := false
var _holder: Control
var _nav: HBoxContainer
var _nav_label: Label
var _b_prev: Button
var _b_next: Button
const NAV_H := 40.0
var _parked := Vector2.ZERO          # punto de lectura (local de la hoja)
var _over := false
var _glide: Tween = null
var _pressed_at := Vector2.ZERO

# ------------------------------------------------------------------ lupa
class StrandViewIgnore:
	static func all(n: Node) -> void:
		if n is Control:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in n.get_children():
			all(c)

class Disc extends Control:
	var radius := 150.0
	func _draw() -> void:
		draw_circle(Vector2(radius, radius), radius, Color(1, 1, 1) if Paper.hc_on() else Paper.MESA.lightened(0.12))

class Rim extends Control:
	var radius := 150.0
	func _draw() -> void:
		var c := Vector2(radius, radius)
		if Paper.hc_on():
			draw_arc(c, radius + 3.0, 0.0, TAU, 96, Color(0, 0, 0), 6.0, true)
			return
		var brass := Color("9a7a3c")
		draw_arc(c, radius + 10.0, 0.0, TAU, 128, Color(0, 0, 0, 0.20), 7.0, true)
		draw_arc(c, radius + 4.5, 0.0, TAU, 128, brass.darkened(0.38), 10.0, true)
		draw_arc(c, radius + 3.0, 0.0, TAU, 128, brass, 5.0, true)
		draw_arc(c, radius + 1.5, PI * 1.05, PI * 1.55, 40, Color(1, 0.95, 0.75, 0.55), 2.0, true)
		draw_arc(c, radius * 0.84, PI * 1.12, PI * 1.36, 28, Color(1, 1, 1, 0.13), radius * 0.06, true)
		var d := Vector2(0.72, 0.69).normalized()
		var a := c + d * (radius + 9.0)
		var b := c + d * (radius + 104.0)
		draw_line(a + Vector2(2, 3), b + Vector2(2, 3), Color(0, 0, 0, 0.25), 18.0, true)
		draw_line(a, a + d * 15.0, brass.darkened(0.2), 14.0, true)
		draw_line(a + d * 15.0, b, Color("3b2416"), 16.0, true)
		draw_line(a + d * 17.0, b - d * 2.0, Color("5a3a24"), 6.0, true)

class Loupe extends Control:
	var radius := 150.0
	var mag := 1.75
	var source: Control = null
	var copy: Control = null
	var center := Vector2.ZERO
	var _mask: Control
	var _content: Control
	var _rim: Control
	func _init() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mask = Disc.new()
		_mask.radius = radius
		_mask.size = Vector2(radius, radius) * 2.0
		_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_mask)
		_content = Control.new()
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mask.add_child(_content)
		_rim = Rim.new()
		_rim.radius = radius
		_rim.size = Vector2(radius, radius) * 2.0
		_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rim)
	func setup(p_view: Dictionary, idx: int, ppm: float, src: Control) -> Control:
		if copy != null:
			copy.queue_free()
		source = src
		copy = PageView.new()
		copy.name = "LupaHoja"
		_content.add_child(copy)
		copy.setup(p_view, idx, {"px_per_mm": ppm, "interactive": false})
		# la copia va encima de la hoja (top_level) y sigue al mouse: nunca recibe un clic (si no, la tijera no corta)
		StrandViewIgnore.all(copy)
		return copy
	func follow(canvas_pos: Vector2) -> void:
		center = canvas_pos
		if copy == null or source == null or not is_instance_valid(source):
			return
		var local: Vector2 = source.get_global_transform().affine_inverse() * canvas_pos
		var tl := canvas_pos - Vector2(radius, radius)
		_mask.position = tl
		_rim.position = tl
		_content.scale = Vector2(mag, mag)
		_content.position = Vector2(radius, radius) - local * mag
		_mask.queue_redraw()
		_rim.queue_redraw()

# ------------------------------------------------------------------ marcas (subraya, nota azul) — en la hoja y en la lupa
class Marks extends Control:
	var host = null                     # StrandView
	var items: Array = []               # [{kind, from, to}]
	var note := ""
	var _note_label: Label = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func rebuild(pv: Control) -> void:
		size = pv.size
		if _note_label != null:
			_note_label.queue_free()
			_note_label = null
		for it in items:
			if String(it.kind) == "nota_azul" and note != "":
				var r: Rect2 = host.content_rect_of(pv)
				var l := Label.new()
				l.text = note
				l.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ti := TextBuilder.ti_node()
				if ti != null:
					l.add_theme_font_override("font", ti.font("manuscrito"))
				l.add_theme_font_size_override("font_size", int(round(float(TextBuilder.slot_size("manuscrito")) * 0.95)))
				l.add_theme_color_override("font_color", Paper.ink("azul"))
				l.rotation_degrees = -2.5
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(host.note_width(pv), 0)
				l.size = Vector2(host.note_width(pv), 0)
				l.position = host.note_local(pv)
				add_child(l)
				_note_label = l
		queue_redraw()
	func _draw() -> void:
		var pv = get_parent()
		if pv == null or host == null:
			return
		for it in items:
			if String(it.kind) == "esquina":
				# esquina doblada (arriba a la derecha): «Una esquina de página viene doblada»
				var w: float = pv.size.x
				var k := 48.0
				draw_colored_polygon(PackedVector2Array([Vector2(w - k, 0), Vector2(w, k), Vector2(w - k, k)]), Paper.paper("strand").darkened(0.2))
				draw_colored_polygon(PackedVector2Array([Vector2(w - k, 0), Vector2(w, 0), Vector2(w, k)]), Paper.MESA.darkened(0.2))
				draw_line(Vector2(w - k, 0), Vector2(w, k), Color(0.25, 0.18, 0.1, 0.55), 1.5, true)
				draw_line(Vector2(w - k, 0), Vector2(w - k, k), Color(0.3, 0.22, 0.12, 0.35), 1.0, true)
				draw_line(Vector2(w - k, k), Vector2(w, k), Color(0.3, 0.22, 0.12, 0.35), 1.0, true)
				continue
			var segs: Array = host.line_segments(pv, int(it.from), int(it.to))
			if segs.is_empty():
				continue
			match String(it.kind):
				"subraya":
					var c := Paper.ink("lapiz")
					c.a = 0.85
					for s in segs:
						var y: float = s.y1 - 2.0
						draw_line(Vector2(s.x0, y), Vector2(s.x1, y + 0.6), c, 1.6, true)
				"nota_azul":
					var b := Paper.ink("azul")
					# corchete en el margen izquierdo, a lo largo del tramo, y un trazo hasta la nota
					var top: float = segs[0].y0
					var bot: float = segs[-1].y1
					var r: Rect2 = host.content_rect_of(pv)
					var x := r.position.x - 9.0
					draw_line(Vector2(x + 5, top + 2), Vector2(x, top + 4), b, 1.6, true)
					draw_line(Vector2(x, top + 4), Vector2(x - 1, bot - 3), b, 1.6, true)
					draw_line(Vector2(x - 1, bot - 3), Vector2(x + 5, bot - 1), b, 1.6, true)
					# trazo del corchete hasta la nota
					var np: Vector2 = host.note_local(pv)
					var ny := np.y + 14.0
					draw_line(Vector2(x - 1, bot - 6), Vector2(x - 8, ny), Color(b, 0.8), 1.2, true)
					draw_line(Vector2(x - 8, ny), Vector2(np.x - 6.0, ny), Color(b, 0.8), 1.2, true)

# ------------------------------------------------------------------ armado
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_holder = Control.new()
	_holder.name = "Hoja"
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_holder)
	sight = ColorRect.new()
	sight.name = "Vista"
	sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SIGHT
	sight.material = m
	add_child(sight)
	loupe = Loupe.new()
	loupe.name = "Lupa"
	loupe.radius = RADIUS
	loupe.mag = MAG
	add_child(loupe)
	loupe.visible = false
	# hojas: ‹ Hoja n de m › (mouse; la lupa no se mete)
	_nav = HBoxContainer.new()
	_nav.name = "Hojas"
	_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav.add_theme_constant_override("separation", 14)
	add_child(_nav)
	_b_prev = Widgets.ink_button("‹", func(): show_page(page_idx - 1))
	_nav.add_child(_b_prev)
	_nav_label = Widgets.label("", "SourceLine")
	_nav_label.add_theme_color_override("font_color", NAV_INK)
	_nav.add_child(_nav_label)
	_b_next = Widgets.ink_button("›", func(): show_page(page_idx + 1))
	_nav.add_child(_b_next)
	# la mesa es oscura: los botones de tinta negra no se veían (el «›» era la única forma de llegar a la segunda hoja)
	for b in [_b_prev, _b_next]:
		b.add_theme_font_size_override("font_size", 26)
		for c in ["font_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, NAV_INK)
		for c in ["font_hover_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color("f4ecd8"))
		b.add_theme_color_override("font_disabled_color", Color(NAV_INK, 0.22))

func setup(p_view: Dictionary, avail: Vector2) -> void:
	view = p_view
	var mm: Array = view.get("paper_mm", [170, 250])
	var pm := Vector2(float(mm[0]), float(mm[1]))
	var ay := avail.y - (NAV_H if (view.get("pages", []) as Array).size() > 1 else 0.0)
	px_per_mm = clampf(minf(ay / maxf(pm.y, 1.0), avail.x / maxf(pm.x, 1.0)), 1.6, 6.0)
	_apply_hc()
	show_page(0)

func _apply_hc() -> void:
	var hc := Paper.hc_on()
	var mat: ShaderMaterial = sight.material
	mat.set_shader_parameter("blur_lod", 1.2 if hc else 2.3)
	mat.set_shader_parameter("veil", 0.06 if hc else 0.18)
	mat.set_shader_parameter("vignette", 0.0 if hc else 0.35)

func page_count() -> int:
	return (view.get("pages", []) as Array).size()

func show_page(idx: int) -> void:
	if view.is_empty():
		return
	idx = clampi(idx, 0, maxi(0, page_count() - 1))
	var turned := page != null and idx != page_idx
	page_idx = idx
	if page != null:
		page.queue_free()
	page = PageView.new()
	page.name = "Pagina%d" % idx
	_holder.add_child(page)
	page.setup(view, idx, {"px_per_mm": px_per_mm, "interactive": true})
	page.block_pressed.connect(_on_pressed)
	page.block_released.connect(_on_released)
	page.set_tijera(scissors)
	_holder.custom_minimum_size = page.size
	_holder.size = page.size
	var lc: Control = loupe.setup(view, idx, px_per_mm, page)
	_mark_page(page)
	_mark_page(lc)
	_layout()
	_parked = Vector2(page.size.x * 0.5, page.size.y * 0.25)
	_refresh_loupe()
	if turned:
		page_turned.emit(idx)
		if not fast:
			page.modulate.a = 0.0
			create_tween().tween_property(page, "modulate:a", 1.0, 0.3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

func _layout() -> void:
	if page == null:
		return
	# la hoja cabe entera: si el texto la alarga (PageView crece con el contenido), se achica toda la hoja
	var k := 1.0
	var room := size - Vector2(0, NAV_H if page_count() > 1 else 0.0)
	if room.x > 10.0 and room.y > 10.0 and page.size.x > 0.0 and page.size.y > 0.0:
		k = minf(1.0, minf(room.x / page.size.x, room.y / page.size.y))
	_holder.scale = Vector2(k, k)
	var shown := page.size * k
	_holder.position = ((room - shown) * 0.5).floor()
	_nav.visible = page_count() > 1
	_nav.size = Vector2(shown.x, NAV_H)
	_nav.position = Vector2(_holder.position.x, _holder.position.y + shown.y + 4.0)
	_nav_label.text = _t("epilogue.hoja", {"n": page_idx + 1, "total": page_count()})
	_b_prev.disabled = page_idx <= 0
	_b_next.disabled = page_idx >= page_count() - 1
	sight.position = _holder.position
	sight.size = shown
	_refresh_loupe()

func page_rect() -> Rect2:
	if page == null:
		return Rect2()
	return Rect2(page.get_global_transform().origin, page.size * _holder.scale.x)

func content_rect_of(pv: Control) -> Rect2:
	if pv != null and pv.has_method("content_rect_px"):
		return pv.content_rect_px()
	return Rect2(Vector2.ZERO, pv.size if pv != null else Vector2.ZERO)

# ------------------------------------------------------------------ lupa: seguir al mouse o posarse donde se lee
func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or page == null:
		return
	if ev is InputEventMouseMotion:
		follow((ev as InputEventMouseMotion).position)

func follow(canvas_pos: Vector2) -> void:
	if page == null:
		return
	var inside := page_rect().grow(RADIUS * 0.35).has_point(canvas_pos)
	if inside:
		_over = true
		if _glide != null and _glide.is_valid():
			_glide.kill()
		_parked = page.get_global_transform().affine_inverse() * canvas_pos
		loupe.follow(canvas_pos)
	else:
		_over = false
	loupe.visible = loupe.copy != null and lens_on

func _refresh_loupe() -> void:
	if page == null or not is_inside_tree():
		return
	loupe.visible = loupe.copy != null and lens_on
	loupe.follow(page.get_global_transform() * _parked)

# Posa la lupa sobre un tramo (dar vuelta la hoja si hace falta). t = {page, from, to}.
func park(t: Dictionary, instant := false) -> void:
	if t.is_empty() or page == null:
		return
	if int(t.page) != page_idx:
		show_page(int(t.page))
		instant = true
	var rtl: RichTextLabel = _block(page, 0)
	if rtl == null:
		return
	var k := int(t.from) + mini(16, maxi(0, (int(t.to) - int(t.from)) / 3))
	var target: Vector2 = rtl.position + SelectionMapper.char_local_pos(rtl, k) + Vector2(RADIUS * 0.25, 0)
	target.x = clampf(target.x, 0.0, page.size.x)
	_glide_to(target, instant)

# Posa la lupa sobre la nota azul (F1): lo primero que Lisle lee tres veces.
func park_note() -> void:
	if page == null:
		return
	var p := note_local(page)
	_glide_to(p + Vector2(RADIUS * 0.55, 14.0), false)

# Dónde va la nota azul en una hoja (local): en el blanco bajo el texto (si no cabe, en el margen de cabeza).
func note_local(pv: Control) -> Vector2:
	var r := content_rect_of(pv)
	var rtl := _block(pv, 0)
	if rtl != null:
		var y := rtl.position.y + float(rtl.get_content_height()) + 26.0
		if y + 90.0 < pv.size.y:
			return Vector2(r.position.x + r.size.x * 0.08, y)
	return Vector2(r.position.x + r.size.x * 0.10, maxf(4.0, r.position.y * 0.18))

func note_width(pv: Control) -> float:
	return content_rect_of(pv).size.x * 0.84

func _glide_to(target: Vector2, instant: bool) -> void:
	if _over:
		_parked = target
		return
	if _glide != null and _glide.is_valid():
		_glide.kill()
	if instant or fast or not is_inside_tree():
		_parked = target
		_refresh_loupe()
		return
	var from := _parked
	_glide = create_tween()
	_glide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glide.tween_method(func(v: Vector2):
		_parked = v
		_refresh_loupe(), from, target, GLIDE_S)

static func _block(pv: Control, i: int) -> RichTextLabel:
	if pv == null or not ("blocks" in pv) or i >= (pv.blocks as Array).size():
		return null
	return pv.blocks[i]

# ------------------------------------------------------------------ marcas
func set_marks(p_marks: Array, p_note: String) -> void:
	marks = p_marks.duplicate(true)
	note_text = p_note
	if page != null:
		_mark_page(page)
		_mark_page(loupe.copy)

func _mark_page(pv: Control) -> void:
	if pv == null:
		return
	for c in pv.get_children():
		if c is Marks:
			c.queue_free()
	var items: Array = []
	for m in marks:
		if int(m.get("page", -1)) == page_idx:
			items.append(m)
	if items.is_empty():
		return
	var mk := Marks.new()
	mk.name = "Marcas"
	mk.host = self
	mk.items = items
	mk.note = note_text
	pv.add_child(mk)
	mk.rebuild.call_deferred(pv)

# Segmentos por renglón de [from, to) del bloque 0 de una hoja (local de la hoja): [{x0, x1, y0, y1}]
func line_segments(pv: Control, from: int, to: int) -> Array:
	var out: Array = []
	var rtl := _block(pv, 0)
	if rtl == null or to <= from:
		return out
	var plain := rtl.get_parsed_text()
	var f: Font = rtl.get_theme_font("normal_font")
	var fs: int = rtl.get_theme_font_size("normal_font_size")
	var l0 := rtl.get_character_line(from)
	var l1 := rtl.get_character_line(maxi(from, to - 1))
	if l0 < 0 or l1 < 0:
		return out
	for ln in range(l0, l1 + 1):
		var lr: Vector2i = rtl.get_line_range(ln)
		var a := maxi(from, lr.x)
		var b := mini(to, lr.y)
		var seg := plain.substr(a, maxi(0, b - a)).strip_edges(false, true)
		var x0 := f.get_string_size(plain.substr(lr.x, a - lr.x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x1 := x0 + f.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y0 := float(rtl.get_line_offset(ln))
		var y1 := y0 + float(rtl.get_line_height(ln))
		out.append({"x0": rtl.position.x + x0, "x1": rtl.position.x + x1, "y0": rtl.position.y + y0, "y1": rtl.position.y + y1})
	return out

# Rectángulo (canvas) que ocupan los renglones de [from, to) en la hoja visible.
func tramo_rect(from: int, to: int) -> Rect2:
	var segs := line_segments(page, from, to)
	if segs.is_empty():
		return Rect2(page_rect().get_center(), Vector2.ONE)
	var cr := content_rect_of(page)
	var tl := page.get_global_transform() * Vector2(cr.position.x, float(segs[0].y0))
	var br := page.get_global_transform() * Vector2(cr.end.x, float(segs[-1].y1))
	return Rect2(tl, br - tl)

func plain_of_page() -> String:
	var rtl := _block(page, 0)
	return rtl.get_parsed_text() if rtl != null else ""

func doc_px() -> int:
	var rtl := _block(page, 0)
	return rtl.get_theme_font_size("normal_font_size") if rtl != null else 21

# ------------------------------------------------------------------ tijera
func set_scissors(on: bool) -> void:
	scissors = on
	if page != null:
		page.set_tijera(on)

func _on_pressed(_idx: int, pos: Vector2) -> void:
	_pressed_at = pos

func _on_released(idx: int, pos: Vector2) -> void:
	if not scissors or page == null:
		return
	var rtl := _block(page, idx)
	if rtl == null:
		return
	var parsed: Dictionary = page.parsed[idx] if idx < (page.parsed as Array).size() else {}
	var m := SelectionMapper.map(rtl, parsed)
	if bool(m.ok) and int(m.len) > 0 and pos.distance_to(_pressed_at) > 3.0:
		rtl.deselect()
		cut_requested.emit(page_idx, int(m.from), int(m.len))
		return
	rtl.deselect()
	var local: Vector2 = rtl.get_global_transform_with_canvas().affine_inverse() * pos
	var k := char_at(rtl, local)
	if k < 0:
		return
	var sents: Array = parsed.get("sentences", [])
	var si := Markup.sentence_index(sents, k)
	if si < 0:
		return
	cut_requested.emit(page_idx, int(sents[si][0]), int(sents[si][1]) - int(sents[si][0]))

# Carácter bajo un punto (local del RichTextLabel); -1 si no hay texto ahí.
static func char_at(rtl: RichTextLabel, local: Vector2) -> int:
	var plain := rtl.get_parsed_text()
	if plain == "":
		return -1
	var f: Font = rtl.get_theme_font("normal_font")
	var fs: int = rtl.get_theme_font_size("normal_font_size")
	for ln in rtl.get_line_count():
		var y0 := float(rtl.get_line_offset(ln))
		var y1 := y0 + float(rtl.get_line_height(ln))
		if local.y < y0 or local.y >= y1:
			continue
		var lr: Vector2i = rtl.get_line_range(ln)
		var best := -1
		for k in range(lr.x, lr.y):
			var x := f.get_string_size(plain.substr(lr.x, k - lr.x + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if x >= local.x:
				best = k
				break
		if best < 0:
			best = maxi(lr.x, lr.y - 1)
		if plain[best] == "\n" or plain[best] == " ":
			best = maxi(lr.x, best - 1)
		return best
	return -1

static func _t(key: String, vars := {}) -> String:
	return Widgets.t(key, vars)
