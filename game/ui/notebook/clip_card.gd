# ui/notebook/clip_card.gd — tarjeta de un recorte en el cuaderno. Dueño: W3-NOTEBOOK. Contrato: ARCHITECTURE §6.5, §6.3.
# Fila de página: [margen (día de la crónica, a lápiz)] [tira de papel + epígrafe + línea de fuente].
#   La tira es del ancho de una columna (GDD§8.1): texto con la letra y el papel del documento de origen (la Remington
#   conserva sus defectos: TextBuilder con machine), miniatura de lámina (Notebook.thumbs[id] o un grabado de reemplazo
#   que se entiende igual) o la medida. El pie lista hasta tres entidades (Clipper.visible, en su orden, sin destacar
#   ninguna) y «+n» con todas al pasar el mouse (GDD_v2 §C.3: nada abrumador a la vista; nada se oculta).
# Arrastre (DnD nativo, §6.3): datos {"kind":"clip","id"}; vista previa = Chip. Soltar otro recorte (o un par) encima ->
#   nb.request_link(otro, este) (el par/anidado lo decide el sim). Doble clic -> nb.source_requested(id, copy).
# Una tarjeta de par (Cotejos) usa ClipCard.strip_for(nb, clip, ancho) para sus dos tiras.
extends HBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")

const PREVIEW_CHARS := 38
const FOOT_ENTS := 3
const SIZE_K := 0.86
const THUMB_W := 250.0

var nb                      # Notebook
var clip := {}
var id := ""
var margin_label: Label
var body: Container
var strip: PanelContainer
var _drop_hover := false

# Grabado de reemplazo para una lámina sin miniatura: marco, rayado de buril y el epígrafe (se entiende sin la imagen).
class Thumb extends Control:
	var tex: Texture2D = null
	var words := ""
	func _init(p_tex: Texture2D, p_words: String, w: float) -> void:
		tex = p_tex
		words = p_words
		custom_minimum_size = Vector2(w, roundf(w * 0.56))
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var ink := Paper.ink("negra")
		if tex != null:
			draw_texture_rect(tex, r, false)
			draw_rect(r, Color(ink, 0.8), false, 1.0)
			return
		var hc := Paper.hc_on()
		draw_rect(r, Paper.paper("registro"), true)
		var step := 5.0
		var x := -size.y
		var hatch := Color(ink, 0.16 if not hc else 0.3)
		while x < size.x:
			draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), hatch, 1.0)
			x += step
		var inner := r.grow(-7.0)
		draw_rect(inner, Color(ink, 0.55), false, 1.0)
		draw_rect(r.grow(-3.0), Color(ink, 0.8), false, 1.5)
		var f: Font = get_theme_font("font", "Caption")
		var fs: int = get_theme_font_size("font_size", "Caption")
		var txt := words
		var w := inner.size.x - 16.0
		var lines := []
		var cur := ""
		for word in txt.split(" ", false):
			var cand := word if cur == "" else cur + " " + word
			if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
				lines.append(cur)
				cur = word
			else:
				cur = cand
		if cur != "":
			lines.append(cur)
		lines = lines.slice(0, 3)
		var lh := f.get_height(fs)
		var y0 := inner.get_center().y - lh * lines.size() * 0.5 + f.get_ascent(fs)
		for i in lines.size():
			var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var bg := Rect2(Vector2(inner.get_center().x - lw * 0.5 - 6.0, y0 - f.get_ascent(fs) + lh * i - 1.0), Vector2(lw + 12.0, lh + 2.0))
			draw_rect(bg, Paper.paper("registro"), true)
			draw_string(f, Vector2(inner.get_center().x - lw * 0.5, y0 + lh * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

func _init(p_nb, p_clip: Dictionary, wide := true) -> void:
	nb = p_nb
	clip = p_clip
	id = String(clip.get("id", ""))
	name = "Recorte_" + id
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", int(nb.GUTTER))
	margin_label = Widgets.label("", "Marginal")
	margin_label.add_theme_font_size_override("font_size", int(round(nb._px("ui") * 1.25)))
	margin_label.add_theme_color_override("font_color", Paper.ink("lapiz"))
	margin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	margin_label.custom_minimum_size = Vector2(nb.MARGIN_COL, 0)
	margin_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin_label)
	var strip_w: float = nb.strip_width(wide)
	strip = strip_for(nb, clip, strip_w)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 2)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap_text := Model.caption_text(clip)
	if cap_text == "" and String(clip.get("kind", "")) == "plate":
		cap_text = nb.t("nb.lamina.vacia")
	var full := cap_text
	var labels := entity_labels(clip)
	if labels.size() > FOOT_ENTS and String(clip.get("kind", "text")) != "plate":
		cap_text = "; ".join(PackedStringArray(labels.slice(0, FOOT_ENTS))) + "  " + nb.t("v2d.nb.mas", {"n": labels.size() - FOOT_ENTS})
		full = "; ".join(PackedStringArray(labels))
	var cap := Widgets.caption(cap_text)
	cap.name = "Pie"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if full != cap_text:
		cap.tooltip_text = full
		cap.mouse_filter = Control.MOUSE_FILTER_PASS   # el arrastre sigue siendo de la tarjeta (sube por PASS)
	notes.add_child(cap)
	var src := Widgets.source_line(String(clip.get("src_line", "")))
	src.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_child(src)
	if wide:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# la columna de la tira tiene siempre el mismo ancho (los epígrafes quedan alineados aunque la tira sea una lámina)
		var col := HBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.custom_minimum_size = Vector2(strip_w, 0)
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(strip)
		h.add_child(col)
		notes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(notes)
		body = h
	else:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(strip)
		v.add_child(notes)
		body = v
	add_child(body)

func set_margin(text: String) -> void:
	margin_label.text = text

static func entity_labels(c: Dictionary) -> Array:
	var labels: Array = []
	for e in c.get("ents", []):
		var lb := String(e.get("label", "")) if typeof(e) == TYPE_DICTIONARY else ""
		if lb != "" and not labels.has(lb):
			labels.append(lb)
	return labels

# Tira de papel del recorte (también la usan los pares). Ancho fijo = ancho de una columna.
static func strip_for(p_nb, c: Dictionary, w: float) -> PanelContainer:
	var look: Dictionary = p_nb.look_of(c)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(w, 0)
	var sb := Paper.style(String(look.paper), {"margin": 12, "margin_v": 7, "radius": 0, "shadow_size": 2, "shadow_y": 1})
	sb.border_color.a = 0.55
	p.add_theme_stylebox_override("panel", sb)
	var kind := String(c.get("kind", "text"))
	var cid := String(c.get("id", ""))
	if kind == "plate":
		var tex: Texture2D = p_nb.thumb_of(cid)
		var words := String(c.get("caption", ""))
		if words == "":
			words = p_nb.t("nb.lamina")
		var tw := minf(w - 24.0, THUMB_W * (w / 470.0))
		p.custom_minimum_size = Vector2(tw + 24.0, 0)
		p.add_child(Thumb.new(tex, words, tw))
		return p
	var r := TextBuilder.make_rtl(String(look.font))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(w - 24.0, 0)
	var parsed := {"plain": String(c.get("text", "")), "styles": [], "mentions": [], "tramos": []}
	var size := int(round(float(TextBuilder.slot_size(String(look.font))) * SIZE_K))
	TextBuilder.build(r, parsed, {"slot": String(look.font), "machine": String(look.machine), "size": size})
	p.add_child(r)
	return p

static func preview_text(c: Dictionary) -> String:
	var tx := String(c.get("text", ""))
	if tx == "":
		tx = String(c.get("caption", ""))
	if tx.length() > PREVIEW_CHARS:
		tx = tx.left(PREVIEW_CHARS - 1).strip_edges() + "…"
	return "«" + tx + "»" if String(c.get("kind", "text")) != "plate" else tx

func _get_drag_data(_at: Vector2):
	if id == "":
		return null
	if is_inside_tree() and get_viewport().gui_is_dragging():
		set_drag_preview(Widgets.chip(preview_text(clip), {"kind": "clip", "id": id}))
	return {"kind": "clip", "id": id}

func _can_drop_data(_at: Vector2, data) -> bool:
	var ok: bool = typeof(data) == TYPE_DICTIONARY and (String(data.get("kind", "")) in ["clip", "pair"]) and String(data.get("id", "")) != id
	_set_hover(ok)
	return ok

func _drop_data(_at: Vector2, data) -> void:
	_set_hover(false)
	nb.request_link(String(data.get("id", "")), id)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and ev.double_click:
		nb.open_source(id, String(clip.get("copy", "")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_hover(false)

func _set_hover(on: bool) -> void:
	if _drop_hover != on:
		_drop_hover = on
		queue_redraw()

# Durante un arrastre válido, una llave a lápiz junto a la tira (la misma para toda tarjeta: no distingue nada).
func _draw() -> void:
	if not _drop_hover or strip == null:
		return
	var r := Rect2(strip.get_global_rect().position - get_global_rect().position, strip.size)
	var x := r.position.x - 9.0
	var col := Paper.ink("lapiz")
	draw_line(Vector2(x, r.position.y + 2.0), Vector2(x, r.end.y - 2.0), col, 1.5)
	draw_line(Vector2(x, r.position.y + 2.0), Vector2(x + 5.0, r.position.y + 2.0), col, 1.5)
	draw_line(Vector2(x, r.end.y - 2.0), Vector2(x + 5.0, r.end.y - 2.0), col, 1.5)
