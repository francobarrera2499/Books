# ui/notebook/clip_card.gd — el recorte como TARJETA (GDD_v3 §6.2). Dueño: UI-EXPEDIENTE (antes W3-NOTEBOOK).
# Tarjeta (cuaderno, ranuras del expediente, informe, mostrar): papel claro con borde de 1 px y 8 px de margen interno;
#   el texto en la letra del documento de origen (la Remington conserva sus defectos); abajo, en letra chica (≈70 %), la
#   línea de fuente; las entidades, sólo al pasar el mouse (tooltip). Entre tarjetas, 10 px (lo pone la lista).
#   Ningún recorte mostrado pasa de MAX_WORDS palabras (el sim ya lo garantiza; esto es la última red).
#   Un recorte de lámina muestra la miniatura (o un grabado de reemplazo que se entiende igual) y su epígrafe.
# Uso estático (cualquier panel): ClipCard.tarjeta(sim, clip, ancho, opts) -> PanelContainer
#   opts: thumb (Texture2D) · size_k (escala de la letra, 0.86) · tooltip (true: entidades al pasar el mouse) ·
#   name. look_for(sim, clip) -> {font, paper, machine} (cacheado). entity_labels(clip). preview_text(clip).
# Fila del cuaderno (instancia): [margen (día de la crónica, a lápiz)] [tarjeta]. Arrastre (DnD nativo, §6.3): datos
#   {"kind":"clip","id"}; vista previa = Chip. Ya no recibe nada (sin pares). Doble clic -> nb.open_source(id, copy).
extends HBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")

const PREVIEW_CHARS := 38
const SIZE_K := 0.86
const SRC_K := 0.7
const PAD := 8
const THUMB_W := 250.0
const MAX_WORDS := 15
const CARD_W := 600.0           # ancho máximo de la tarjeta en el cuaderno (diseño, × escala de texto)
const CARD_SEP := 10            # separación entre tarjetas (la usan las listas)

static var _looks := {}

var nb                      # Notebook
var clip := {}
var id := ""
var margin_label: Label
var body: Control
var strip: PanelContainer   # la tarjeta (nombre histórico: los drivers buscan .strip)

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
		var w := inner.size.x - 16.0
		var lines := []
		var cur := ""
		for word in words.split(" ", false):
			var cand: String = word if cur == "" else cur + " " + word
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
	margin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # «día 12» con letra grande: en dos renglones, no ensancha
	margin_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin_label)
	var w: float = nb.card_width(wide) if nb.has_method("card_width") else nb.strip_width(wide)
	strip = tarjeta(nb.sim(), clip, w, {"thumb": nb.thumb_of(id), "name": "Tarjeta"})
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	strip.mouse_filter = Control.MOUSE_FILTER_PASS   # el tooltip de las entidades; el arrastre sube a la fila
	body = strip
	add_child(strip)

func set_margin(text: String) -> void:
	margin_label.text = text

# ---------------------------------------------------------------- tarjeta (estática)
static func entity_labels(c: Dictionary) -> Array:
	var labels: Array = []
	for e in c.get("ents", []):
		var lb := String(e.get("label", "")) if typeof(e) == TYPE_DICTIONARY else ""
		if lb != "" and not labels.has(lb):
			labels.append(lb)
	return labels

# El texto que se muestra (≤ MAX_WORDS palabras; lo de más, con «…»).
static func shown_text(c: Dictionary) -> String:
	var t := String(c.get("text", ""))
	var ws := t.strip_edges().split(" ", false)
	if ws.size() <= MAX_WORDS:
		return t
	return " ".join(ws.slice(0, MAX_WORDS)) + "…"

static func clear_looks() -> void:
	_looks.clear()

static func _repo_of(sim):
	if sim != null and "repo" in sim and sim.repo != null:
		return sim.repo
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null and ml.root.get_node_or_null("Data") != null:
		return ml.root.get_node("Data").repo()
	return null

# Letra y papel del documento de origen (cacheado por copia/doc/tipo). Líneas dichas: papel de carta; diario: el
# del cuaderno; lugares y láminas: papel de registro.
static func look_for(sim, c: Dictionary) -> Dictionary:
	var st := String(c.get("src_type", ""))
	var key := String(c.get("copy", "")) + "|" + String(c.get("doc", "")) + "|" + st + "|" + String(c.get("hand", "")) + "|" + String(c.get("font", ""))
	if _looks.has(key):
		return _looks[key]
	var out := {"font": "imprenta", "paper": "diario_hueso", "machine": ""}
	match st:
		"escena":
			out.paper = "carta"
		"diario":
			out.paper = "cuaderno"
		"lugar":
			out.paper = "registro"
		_:
			var r = _repo_of(sim)
			var d: Dictionary = {}
			if r != null:
				var cp := String(c.get("copy", ""))
				var did := String(c.get("doc", ""))
				if did != "" and not r.doc(did).is_empty():
					d = r.doc(did)
				elif cp != "" and not r.copy(cp).is_empty():
					d = r.doc(String(r.copy(cp).get("doc", "")))
			if d.is_empty() and sim != null and sim.has_method("q_view"):
				var view := String(c.get("copy", ""))
				if view == "":
					view = String(c.get("doc", ""))
				var v = sim.q_view(view) if view != "" else null
				if v is Dictionary and not v.is_empty():
					d = v
			if not d.is_empty():
				out.font = String(d.get("font", "imprenta")) if d.get("font") != null else "imprenta"
				out.paper = String(d.get("paper", "diario_hueso")) if d.get("paper") != null and String(d.get("paper", "")) != "" else "diario_hueso"
				out.machine = String(d.get("machine", "")) if d.get("machine") != null else ""
	# el tramo recortado tiene su propia letra (<f=…>: el aviso manuscrito de Pell en el encargo a máquina)
	if String(c.get("font", "")) != "":
		out.font = String(c.font)
		if String(c.font) != "maquina":
			out.machine = ""
	# nota o marca a lápiz al margen de una crónica (playtest v3): la tarjeta va en grafito, con letra de mano
	if String(c.get("hand", "")) != "":
		out.font = "manuscrito"
		out["ink"] = "lapiz"
	if not ["imprenta", "maquina", "manuscrito", "ui"].has(String(out.font)):
		out.font = "imprenta"
	if not Paper.PAPERS.has(String(out.paper)):
		out.paper = "diario_hueso"
	_looks[key] = out
	return out

# Papel claro: el del documento, aclarado (se reconoce la fuente y se lee igual en todas).
static func card_style(paper: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var hc := Paper.hc_on()
	sb.bg_color = Paper.paper(paper) if hc else Paper.paper(paper).lerp(Color(1, 1, 1), 0.38)
	sb.border_color = Color(0, 0, 0) if hc else Color(Paper.ink("tenue"), 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.anti_aliasing = true
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = PAD
	sb.content_margin_bottom = PAD
	if not hc:
		sb.shadow_color = Color(0, 0, 0, 0.16)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 1)
	return sb

static func tarjeta(sim, c: Dictionary, w: float, opts := {}) -> PanelContainer:
	var look := look_for(sim, c)
	var p := PanelContainer.new()
	p.name = String(opts.get("name", "Tarjeta_" + String(c.get("id", ""))))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(w, 0)
	p.add_theme_stylebox_override("panel", card_style(String(look.paper)))
	p.set_meta("clip", String(c.get("id", "")))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var kind := String(c.get("kind", "text"))
	var k := float(opts.get("size_k", SIZE_K))
	var base_px := int(round(float(TextBuilder.slot_size(String(look.font))) * k))
	var inner := maxf(40.0, w - PAD * 2.0)
	if kind == "plate":
		var tex: Texture2D = opts.get("thumb", null)
		var words := String(c.get("caption", ""))
		var tw := minf(inner, THUMB_W * (w / 470.0))
		v.add_child(Thumb.new(tex, words if words != "" else Widgets.t("nb.lamina"), tw))
	else:
		var r := TextBuilder.make_rtl(String(look.font))
		r.name = "Texto"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.custom_minimum_size = Vector2(inner, 0)
		var parsed := {"plain": shown_text(c), "styles": [], "mentions": [], "tramos": []}
		TextBuilder.build(r, parsed, {"slot": String(look.font), "machine": String(look.machine), "size": base_px})
		if String(look.get("ink", "")) != "":
			r.add_theme_color_override("default_color", Paper.ink(String(look.ink)))
		v.add_child(r)
	var src_txt := String(c.get("src_line", ""))
	if src_txt != "":
		var s := Label.new()
		s.name = "Fuente"
		s.text = src_txt
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(inner, 0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ti := TextBuilder.ti_node()
		var doc_px := int(ti.px("doc")) if ti != null else 21
		if ti != null:
			s.add_theme_font_override("font", ti.font("imprenta", true))
		s.add_theme_font_size_override("font_size", maxi(11, int(round(float(doc_px) * SIZE_K * SRC_K))))
		s.add_theme_color_override("font_color", Paper.ink("tenue") if not Paper.hc_on() else Paper.ink("lapiz"))
		v.add_child(s)
	if bool(opts.get("tooltip", true)):
		var labels := entity_labels(c)
		if not labels.is_empty():
			p.tooltip_text = "; ".join(PackedStringArray(labels))
	return p

static func preview_text(c: Dictionary) -> String:
	var tx := String(c.get("text", ""))
	if tx == "":
		tx = String(c.get("caption", ""))
	if tx.length() > PREVIEW_CHARS:
		tx = tx.left(PREVIEW_CHARS - 1).strip_edges() + "…"
	return "«" + tx + "»" if String(c.get("kind", "text")) != "plate" else tx

# ---------------------------------------------------------------- fila del cuaderno
func _get_drag_data(_at: Vector2):
	if id == "":
		return null
	if is_inside_tree() and get_viewport().gui_is_dragging():
		set_drag_preview(Widgets.chip(preview_text(clip), {"kind": "clip", "id": id}))
	return {"kind": "clip", "id": id}

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and ev.double_click:
		nb.open_source(id, String(clip.get("copy", "")))
