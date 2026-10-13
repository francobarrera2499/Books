# ui/scene/item_picker.gd — selector de recortes y asientos (presentar, refutar, informe). Dueño: W3-SCENEUI.
# Uso: var p = ItemPicker.new(link); add_child(p); p.open("Presentar al doctor Watson"); p.picked.connect(func(item): …)
#   open(title, kinds := ["clip","entry"]) · close() · picked(item {kind, id}) · closed (Volver / fe_volver).
# Pestañas «Recortes» / «Asientos» (InkTab), búsqueda por texto, tarjetas en orden de más reciente a más viejo. Recorte:
#   su texto entre «» (o el epígrafe si es de lámina) y su línea de fuente. Asiento: nombre de plantilla, resumen con los
#   rótulos «Campo: valor» y «a lápiz» / «en tinta». Nada distingue lo importante (§6.1): todas las tarjetas son iguales.
# Las tarjetas también se arrastran (DnD §6.3: {"kind","id"}; vista previa = Chip).
# Extras (tests/drivers): cards() -> [{kind, id, node}], pick(kind, id), set_tab(kind), set_query(text).
# fit_height(max_h): achica la lista para que el panel entero no pase de max_h (la confrontación: no tapar la afirmación).
extends PanelContainer

signal picked(item: Dictionary)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")

const BODY_CHARS := 150
const LIST_H := 300.0
const LIST_MIN_H := 140.0

class Card extends PanelContainer:
	signal chosen(item: Dictionary)
	var item := {}
	var chip_text := ""
	var _hover := false
	func _init(p_item: Dictionary, p_chip: String) -> void:
		item = p_item
		chip_text = p_chip
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; _restyle())
		mouse_exited.connect(func(): _hover = false; _restyle())
		Widgets.restyle(self, _restyle)
	func _restyle() -> void:
		var sb := Paper.style("diario_hueso", {"margin": 14, "margin_v": 8, "radius": 1, "shadow_size": 3 if not _hover else 6, "shadow_y": 1 if not _hover else 2})
		if _hover:
			sb.bg_color = Paper.shade("diario_hueso", 0.04)
		add_theme_stylebox_override("panel", sb)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			if get_global_rect().has_point(get_global_mouse_position()) or not is_inside_tree():
				chosen.emit(item)
				accept_event()
	func _get_drag_data(_at: Vector2):
		set_drag_preview(Widgets.chip(chip_text, item))
		return item.duplicate()

var link
var kinds: Array = ["clip", "entry"]
var tab := "clip"
var _title: Label
var _tabs := {}
var _search: LineEdit
var _list: VBoxContainer
var _scroll: ScrollContainer
var _empty: Label
var _cards: Array = []

func _init(p_link = null) -> void:
	link = p_link if p_link != null else SimLink.new()
	name = "Selector"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 22, "margin_v": 18, "shadow_size": 12, "shadow_y": 5})))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	_title = Widgets.doc_title("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# un renglón (sin autowrap): con autowrap el mínimo se mide con el ancho de antes del layout (una palabra por renglón)
	# y fit_height achicaba la lista de más; un título largo se corta con «…»
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	var back := Widgets.ink_button(link.t("sceneui.back"), _on_back)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(back)
	v.add_child(head)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for k in ["clip", "entry"]:
		var b := Widgets.ink_tab(link.t("sceneui.picker.clips") if k == "clip" else link.t("sceneui.picker.entries"), group)
		b.pressed.connect(set_tab.bind(k))
		_tabs[k] = b
		bar.add_child(b)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(18, 0)
	bar.add_child(sp)
	_search = LineEdit.new()
	_search.placeholder_text = link.t("sceneui.picker.search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _fill())
	bar.add_child(_search)
	v.add_child(bar)
	v.add_child(Widgets.rule())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, LIST_H)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	_empty = Widgets.caption("")
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	_list.add_child(_empty)

func open(title: String, p_kinds: Array = ["clip", "entry"]) -> void:
	kinds = p_kinds.duplicate()
	_title.text = title
	_search.text = ""
	for k in _tabs:
		_tabs[k].visible = kinds.has(k) and kinds.size() > 1
	if not kinds.has(tab):
		tab = String(kinds[0])
	# primera vez: la pestaña con material (recortes si hay)
	if kinds.has("clip") and link.qa("q_clips").is_empty() and kinds.has("entry") and not _entry_ids().is_empty():
		tab = "entry"
	_tabs[tab].button_pressed = true
	visible = true
	_fill()
	link.play("sfx.papel")

func close() -> void:
	visible = false

func fit_height(max_h: float) -> void:
	var other := get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var h := LIST_H if max_h <= 0.0 else clampf(max_h - other, LIST_MIN_H, LIST_H)
	if not is_equal_approx(_scroll.custom_minimum_size.y, h):
		_scroll.custom_minimum_size.y = h
		# acoplado abajo y creciendo hacia arriba (grow BEGIN): rect de alto cero y el mínimo lo vuelve a levantar
		offset_top = offset_bottom

func list_height() -> float:
	return _scroll.custom_minimum_size.y

func set_tab(k: String) -> void:
	tab = k
	if _tabs.has(k):
		_tabs[k].set_pressed_no_signal(true)
	_fill()

func set_query(text: String) -> void:
	_search.text = text
	_fill()

func cards() -> Array:
	return _cards.duplicate()

func pick(kind: String, id: String) -> void:
	_on_chosen({"kind": kind, "id": id})

func _on_back() -> void:
	close()
	closed.emit()

func _on_chosen(item: Dictionary) -> void:
	close()
	picked.emit({"kind": String(item.get("kind", "")), "id": String(item.get("id", ""))})

func _entry_ids() -> Array:
	var led: Dictionary = link.qd("q_ledger")
	var ids: Array = []
	for k in ["varios", "erratas"]:
		for e in led.get(k, []):
			ids.append(String(e))
	for f in led.get("folios", []):
		for e in f.get("entries", []):
			ids.append(String(e))
	ids.sort()
	ids.reverse()
	return ids

func _fill() -> void:
	for c in _list.get_children():
		if c != _empty:
			_list.remove_child(c)
			c.queue_free()
	_cards.clear()
	var q := _search.text.strip_edges().to_lower()
	var items: Array = []
	if tab == "clip":
		var cl: Array = link.qa("q_clips")
		cl.reverse()
		for c in cl:
			items.append({"kind": "clip", "id": String(c.get("id", ""))})
	else:
		for e in _entry_ids():
			items.append({"kind": "entry", "id": e})
	for it in items:
		var info: Dictionary = link.item_info(it)
		if not bool(info.get("ok", false)):
			continue
		var hay := (String(info.title) + " " + String(info.body) + " " + String(info.source) + " " + String(info.get("caption", ""))).to_lower()
		if q != "" and not hay.contains(q):
			continue
		var card := _make_card(it, info)
		_list.add_child(card)
		_cards.append({"kind": it.kind, "id": it.id, "node": card})
	if _cards.is_empty():
		if q != "":
			_empty.text = link.t("sceneui.picker.nada_busqueda")
		else:
			_empty.text = link.t("sceneui.picker.no_clips") if tab == "clip" else link.t("sceneui.picker.no_entries")
	_empty.visible = _cards.is_empty()
	_scroll.scroll_vertical = 0

func _make_card(it: Dictionary, info: Dictionary) -> Control:
	var card := Card.new(it, SimLink.short(String(info.body), 48))
	card.chosen.connect(_on_chosen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	if String(info.title) != "":
		var tl := Widgets.small(String(info.title))
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tl)
	var body := Label.new()
	body.text = SimLink.short(String(info.body), BODY_CHARS)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_override("font", SimLink.font("imprenta"))
	body.add_theme_font_size_override("font_size", int(round(SimLink.px("doc") * 0.86)))
	body.add_theme_color_override("font_color", Paper.ink("negra") if String(info.ink) != "lapiz" else Paper.ink("lapiz"))
	v.add_child(body)
	if String(info.source) != "":
		var src := Widgets.source_line(String(info.source))
		src.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(src)
	return card

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_on_back()
		accept_event()
