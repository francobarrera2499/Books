# ui/expediente/answer_picker.gd — selector de la Respuesta de una hoja del expediente (GDD_v3 §6.1). Dueño: UI-EXPEDIENTE.
# Control de pantalla completa: un papel de carta junto al ancla con un renglón por opción ({id, text, clear?}); clic en
# un renglón -> chosen(id, opt); clic fuera, clic derecho o Esc -> dismissed. A la vista, como mucho MAX_SHOWN opciones
# (GDD_v2 §C.1); con más, el buscador (ya con el cursor puesto: se escribe y filtra, sin tildes) y una línea que avisa
# que hay más (sin número). Sin brillos: el renglón bajo el mouse sólo se sombrea. Nada distingue lo importante: el
# orden es el de q_answer_options (alfabético).
#   setup(title, options, anchor_rect, texts) · visible_ids() · pick_id(id) · row_rect(id) · dismiss() · filter_text(q)
extends Control

signal chosen(id: String, opt: Dictionary)
signal dismissed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

const MAX_SHOWN := 7
const MAX_H := 520.0
const MIN_W := 340.0
const MAX_W := 520.0

var options: Array = []
var title_text := ""
var texts := {}              # {empty, search, more, none}
var anchor := Rect2()
var panel: PanelContainer
var list: VBoxContainer
var filter: LineEdit = null
var _scroll: ScrollContainer
var _rows: Array = []        # [{row, opt, key}]
var _more: Label
var _empty: Label
var _done := false

class Row extends PanelContainer:
	signal picked
	var _n: StyleBox
	var _h: StyleBox
	func _init(n: StyleBox, h: StyleBox) -> void:
		_n = n
		_h = h
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("panel", _n)
		mouse_entered.connect(func(): add_theme_stylebox_override("panel", _h))
		mouse_exited.connect(func(): add_theme_stylebox_override("panel", _n))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			accept_event()
			picked.emit()

func setup(p_title: String, p_options: Array, p_anchor: Rect2, p_texts := {}) -> void:
	title_text = p_title
	options = p_options
	anchor = p_anchor
	texts = p_texts

func _ready() -> void:
	name = "ElectorRespuesta"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.name = "Papel"
	panel.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 14, "margin_v": 12, "shadow_size": 10, "shadow_y": 4}))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if title_text != "":
		var t := Widgets.label(title_text, "Caption")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	var real := options.filter(func(o): return not bool(o.get("clear", false)))
	if real.size() > MAX_SHOWN:
		filter = LineEdit.new()
		filter.name = "Buscar"
		filter.placeholder_text = String(texts.get("search", ""))
		filter.clear_button_enabled = true
		filter.text_changed.connect(_on_filter)
		filter.text_submitted.connect(func(_t): _submit())
		v.add_child(filter)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	_scroll.add_child(list)
	var w := clampf(anchor.size.x, MIN_W, MAX_W)
	var n := Paper.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), [0, 0, 0, 0], 2, [10, 5, 10, 6])
	var h := Paper.flat(Paper.shade("carta", 0.07), Color(0, 0, 0, 0), [0, 0, 0, 0], 2, [10, 5, 10, 6])
	for o in options:
		var row := Row.new(n, h)
		var l := Widgets.label(String(o.get("text", "")), "")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w - 60.0, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(o.get("clear", false)):
			l.add_theme_color_override("font_color", Paper.ink("lapiz"))
			var ti := Widgets.ti()
			if ti != null:
				l.add_theme_font_override("font", ti.font("ui", true))
		row.add_child(l)
		row.picked.connect(_pick.bind(o))
		row.name = "Opcion_" + String(o.get("id", "")).replace(".", "_")
		list.add_child(row)
		_rows.append({"row": row, "opt": o, "key": fold(String(o.get("text", "")) + " " + String(o.get("id", "")))})
	_more = Widgets.label(String(texts.get("more", "")), "SmallLabel")
	_more.name = "HayMas"
	_more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_more.custom_minimum_size = Vector2(w - 40.0, 0)
	_more.add_theme_color_override("font_color", Paper.ink("lapiz"))
	list.add_child(_more)
	_empty = Widgets.label(String(texts.get("empty", "")), "SmallLabel")
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(w - 40.0, 0)
	list.add_child(_empty)
	panel.custom_minimum_size = Vector2(w, 0)
	_on_filter("")
	if filter != null:
		filter.grab_focus.call_deferred()

static func fold(s: String) -> String:
	var t := s.to_lower()
	for k in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["à", "a"], ["è", "e"], ["ç", "c"], ["«", ""], ["»", ""]]:
		t = t.replace(k[0], k[1])
	return t

# Sin texto: las primeras MAX_SHOWN (y «Dejar en blanco» si está); con texto: todas las que lo contengan.
func _on_filter(q: String) -> void:
	var f := fold(q.strip_edges())
	var shown := 0
	var hidden := 0
	for r in _rows:
		if bool(r.opt.get("clear", false)):
			r.row.visible = f == ""
			continue
		var hit: bool = f == "" or String(r.key).contains(f)
		var vis: bool = hit and (f != "" or shown < MAX_SHOWN)
		if hit and not vis:
			hidden += 1
		r.row.visible = vis
		if vis:
			shown += 1
	_more.visible = hidden > 0 and f == ""
	var real := _rows.filter(func(r): return not bool(r.opt.get("clear", false)))
	_empty.text = String(texts.get("empty", "")) if real.is_empty() else String(texts.get("none", ""))
	_empty.visible = shown == 0
	_place.call_deferred()

func filter_text(q: String) -> void:
	if filter != null:
		filter.text = q
	_on_filter(q)

# Ubica el papel debajo del ancla (o encima si no cabe), dentro de la pantalla.
func _place() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var content_h: float = list.get_combined_minimum_size().y
	var chrome := panel.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var h := clampf(content_h, 40.0, MAX_H)
	_scroll.custom_minimum_size = Vector2(0, h)
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	sz.y = h + chrome
	var below := anchor.position.y + anchor.size.y + 6.0
	var y := below
	if below + sz.y > vp.y - 12.0:
		y = maxf(12.0, anchor.position.y - sz.y - 6.0)
		if y + sz.y > vp.y - 12.0:
			y = maxf(12.0, vp.y - 12.0 - sz.y)
	var x := clampf(anchor.position.x, 12.0, maxf(12.0, vp.x - sz.x - 12.0))
	panel.position = Vector2(x, y)
	panel.size = sz

func _pick(o: Dictionary) -> void:
	if _done:
		return
	_done = true
	chosen.emit(String(o.get("id", "")), o)

func visible_ids() -> Array:
	var out: Array = []
	for r in _rows:
		if r.row.visible:
			out.append(String(r.opt.get("id", "")))
	return out

func more_visible() -> bool:
	return _more != null and _more.visible

func dismiss() -> void:
	if _done:
		return
	_done = true
	dismissed.emit()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if not panel.get_global_rect().has_point(ev.global_position):
			accept_event()
			dismiss()

# Intro en el buscador con una sola opción a la vista: la elige.
func _submit() -> void:
	if _done:
		return
	var vis := visible_ids().filter(func(i): return i != "")
	if vis.size() == 1:
		pick_id(String(vis[0]))

func pick_id(id: String) -> bool:
	for r in _rows:
		if String(r.opt.get("id", "")) == id:
			_pick(r.opt)
			return true
	return false

func row_rect(id: String) -> Rect2:
	for r in _rows:
		if String(r.opt.get("id", "")) == id:
			return r.row.get_global_rect()
	return Rect2()
