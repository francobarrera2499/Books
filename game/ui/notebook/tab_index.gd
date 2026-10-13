# ui/notebook/tab_index.gd — pestaña Índice. Dueño: W3-NOTEBOOK. Contrato: ARCHITECTURE §6.5, §6.3 (GDD§8.2).
# El índice del jugador (q_index, ya ordenado por la etiqueta `index`) por letras: la letra en el margen y las entradas
# como chips. Clic en un chip = Recortes filtrado por esa entidad. Arrastre = {"kind":"ent","id"} (campos de plantilla
# del libro mayor, «Preguntar», compositores, barra de filtros). Búsqueda propia para índices largos. Sin contadores y
# sin marcar nada: las entidades de ruido entran igual que las demás.
extends VBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")

var nb
var scissors := false
var _search: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array = []
var _chips := {}
var _empty: Label

# Entrada del índice: chip de papel que se arrastra y se pulsa.
class EntChip extends PanelContainer:
	var nb
	var ent := ""
	var label_text := ""
	var _press := false
	var _sb_n: StyleBox
	var _sb_h: StyleBox
	func _init(p_nb, p_ent: String, p_label: String) -> void:
		nb = p_nb
		ent = p_ent
		label_text = p_label
		name = "Ent_" + p_ent.replace(".", "_")
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		theme_type_variation = "Chip"
		var l := Label.new()
		l.theme_type_variation = "ChipLabel"
		l.text = p_label
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		mouse_entered.connect(func(): _hover(true))
		mouse_exited.connect(func(): _hover(false))
	func _hover(on: bool) -> void:
		if on:
			var sb := Paper.style("diario_hueso", {"margin": 9, "margin_v": 3, "radius": 1, "shadow_size": 3, "shadow_y": 2})
			sb.bg_color = Paper.shade("diario_hueso", 0.06)
			add_theme_stylebox_override("panel", sb)
		else:
			remove_theme_stylebox_override("panel")
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_press = true
			elif _press:
				_press = false
				if Rect2(Vector2.ZERO, size).has_point(ev.position):
					nb.filter_entity(ent)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			_press = false
	func _get_drag_data(_at: Vector2):
		_press = false
		if is_inside_tree() and get_viewport().gui_is_dragging():
			set_drag_preview(Widgets.chip(label_text, {"kind": "ent", "id": ent}))
		return {"kind": "ent", "id": ent}

func _init(p_nb) -> void:
	nb = p_nb
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_search = LineEdit.new()
	_search.name = "Buscar"
	_search.placeholder_text = nb.t("nb.indice.buscar")
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_s): _rebuild_list())
	var top := HBoxContainer.new()
	_search.custom_minimum_size = Vector2(360, 0)
	top.add_child(_search)
	add_child(nb.margin_row(null, top))
	_scroll = nb.scroll_box()
	_scroll.name = "Lista"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

func refresh() -> void:
	_rows = nb.index_rows()
	_rebuild_list()

func _rebuild_list() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_chips.clear()
	var secs: Array = Model.index_sections(_rows, nb.text_fn(), _search.text)
	for s in secs:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.mouse_filter = Control.MOUSE_FILTER_PASS
		for r in s.rows:
			var id := String(r.get("id", ""))
			var ch := EntChip.new(nb, id, String(r.get("label", id)))
			flow.add_child(ch)
			_chips[id] = ch
		var letter: Label = nb.margin_text(String(s.letter), "DocTitle")
		letter.add_theme_font_size_override("font_size", int(round(nb._px("ui") * 1.25)) if String(s.letter).length() == 1 else nb._px("small"))
		var row: HBoxContainer = nb.margin_row(letter, flow)
		row.name = "Letra_" + String(s.letter)
		_list.add_child(row)
	if secs.is_empty():
		_empty = nb.empty_line(nb.t("nb.vacio.indice") if _search.text == "" else nb.t("nb.vacio.filtro"))
		_list.add_child(nb.margin_row(null, _empty))
	else:
		_empty = null
	_restore.call_deferred(keep)

func _restore(v: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v

func chip(id: String):
	return _chips.get(id)

func debug_state() -> Dictionary:
	var letters: Array = []
	for c in _list.get_children():
		if String(c.name).begins_with("Letra_"):
			letters.append(String(c.name).substr(6))
	return {"entries": _chips.keys(), "letters": letters, "empty": _empty.text if _empty != null else ""}
