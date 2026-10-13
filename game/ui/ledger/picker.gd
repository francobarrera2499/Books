# ui/ledger/picker.gd — elector superpuesto del libro mayor (plantillas, listas cerradas, índice, recortes). Dueño: W3-LEDGER.
# Control de pantalla completa: un papel de carta junto al ancla con un renglón por opción ({id, text, sub, clear?});
# clic en un renglón -> chosen(id, opt); clic fuera, clic derecho o Esc -> dismissed. Con más de FILTER_MIN opciones
# muestra «Buscar…» (filtra por texto y subtítulo, sin tildes). Sin brillos: el renglón bajo el mouse sólo se sombrea
# como un botón del kit. No toma el foco salvo que el jugador haga clic en «Buscar…».
extends Control

signal chosen(id: String, opt: Dictionary)
signal dismissed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

const FILTER_MIN := 10
const MAX_H := 620.0
const MIN_W := 340.0
const MAX_W := 560.0

var options: Array = []
var title_text := ""
var empty_text := ""
var filter_hint := ""
var anchor := Rect2()
var panel: PanelContainer
var list: VBoxContainer
var filter: LineEdit = null
var _scroll: ScrollContainer
var _rows: Array = []      # [{row, opt, key}]
var _empty: Label
var _done := false

class Row extends PanelContainer:
	signal picked
	var hover := false
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

func setup(p_title: String, p_options: Array, p_anchor: Rect2, p_empty := "", p_filter_hint := "") -> void:
	title_text = p_title
	options = p_options
	anchor = p_anchor
	empty_text = p_empty
	filter_hint = p_filter_hint

func _ready() -> void:
	name = "Elector"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
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
	if options.size() > FILTER_MIN:
		filter = LineEdit.new()
		filter.placeholder_text = filter_hint
		filter.clear_button_enabled = true
		filter.text_changed.connect(_on_filter)
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
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 0)
		rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rv)
		var l := Widgets.label(String(o.get("text", "")), "")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w - 60.0, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(o.get("clear", false)):
			l.add_theme_color_override("font_color", Paper.ink("lapiz"))
			l.add_theme_font_override("font", _ti_font("ui", true))
		rv.add_child(l)
		var sub := String(o.get("sub", ""))
		if sub != "":
			var s := Widgets.label(sub, "SourceLine")
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s.custom_minimum_size = Vector2(w - 60.0, 0)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rv.add_child(s)
		row.picked.connect(_pick.bind(o))
		list.add_child(row)
		_rows.append({"row": row, "opt": o, "key": fold(String(o.get("text", "")) + " " + sub)})
	_empty = Widgets.label(empty_text, "SmallLabel")
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(w - 40.0, 0)
	_empty.visible = options.is_empty()
	list.add_child(_empty)
	panel.custom_minimum_size = Vector2(w, 0)
	_place.call_deferred()

func _ti_font(slot: String, italic := false) -> Font:
	var ti := Widgets.ti()
	return ti.font(slot, italic) if ti != null else ThemeDB.fallback_font

static func fold(s: String) -> String:
	var t := s.to_lower()
	for k in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["à", "a"], ["è", "e"], ["ç", "c"], ["«", ""], ["»", ""]]:
		t = t.replace(k[0], k[1])
	return t

func _on_filter(q: String) -> void:
	var f := fold(q.strip_edges())
	var any := false
	for r in _rows:
		var vis: bool = f == "" or String(r.key).contains(f) or bool(r.opt.get("clear", false))
		r.row.visible = vis
		if vis and not bool(r.opt.get("clear", false)):
			any = true
	_empty.text = empty_text if options.is_empty() else Widgets.t("ledger.picker.nada")
	_empty.visible = not any
	_place.call_deferred()

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

# Pruebas y drivers: elige por id como si se hiciera clic.
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
