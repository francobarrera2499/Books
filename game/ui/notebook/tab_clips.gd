# ui/notebook/tab_clips.gd — pestaña Recortes. Dueño: W3-NOTEBOOK. Contrato: ARCHITECTURE §6.5 (GDD§14.1, §8.1).
# Arriba: búsqueda por texto y tres filtros (Persona, Lugar, Fecha de la crónica) con sólo lo que hay en los recortes;
# los filtros activos se ven como chips que se quitan con un clic (y un chip del índice soltado en la barra filtra).
# Abajo: los recortes (tarjetas, GDD_v3 §6.2, 10 px entre sí) agrupados por el calendario de la crónica (mes y año; lo
# que no trae fecha, al final), cada uno
# con el día de la crónica en el margen. Filtrar sólo oculta tarjetas (no reconstruye). Sin contadores (§6.1).
# GDD_v2 §C.2 (revelado progresivo): la búsqueda aparece con nb.buscar (≥10 recortes), los filtros con nb.filtros (≥20; y
#   cada filtro sólo si tiene ≥2 opciones), los encabezados por mes con nb.agrupar (≥2 meses de crónica). Con pocos
#   recortes la página es sólo la lista.
extends VBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")

const MENU_KEYS := ["persona", "lugar", "fecha"]
const EDGE_PX := 46.0
const EDGE_SPEED := 900.0

var nb
var scissors := false
var _search: LineEdit
var _menus := {}
var _menu_opts := {}
var _chips_row: Control
var _chips: HFlowContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _cards := {}          # id -> ClipCard
var _groups: Array = []   # [{key, head:Control, cards:[ClipCard]}]
var _empty: Label
var _clips: Array = []
var _kinds := {}
var _labels := {}
var _row1: HBoxContainer
var _row2: HFlowContainer         # angosto: los filtros debajo, y si no caben en un renglón, en dos (texto 1,6×)
var _bar_row: Control

func _init(p_nb) -> void:
	nb = p_nb
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# --- barra: búsqueda y filtros
	var bar := VBoxContainer.new()
	bar.name = "Barra"
	bar.add_theme_constant_override("separation", 6)
	_row1 = HBoxContainer.new()
	_row1.add_theme_constant_override("separation", 8)
	bar.add_child(_row1)
	_row2 = HFlowContainer.new()
	_row2.add_theme_constant_override("h_separation", 8)
	_row2.add_theme_constant_override("v_separation", 6)
	bar.add_child(_row2)
	_search = LineEdit.new()
	_search.name = "Buscar"
	_search.placeholder_text = nb.t("nb.buscar")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(s):
		nb.filters["q"] = s
		_apply())
	_row1.add_child(_search)
	for k in MENU_KEYS:
		var mb := MenuButton.new()
		mb.name = "Filtro_" + k
		mb.text = nb.t("nb.filtro." + k)
		mb.flat = false
		mb.focus_mode = Control.FOCUS_NONE
		mb.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mb.switch_on_hover = true
		Widgets.restyle(mb, func(): mb.icon = Paper.icon("chevron_down", maxi(12, nb._px("small")), Paper.ink("negra")))
		mb.about_to_popup.connect(_fill_menu.bind(k))
		mb.get_popup().id_pressed.connect(_on_menu.bind(k))
		_row1.add_child(mb)
		_menus[k] = mb
	var drop := DropBar.new()
	drop.tab = self
	drop.add_child(bar)
	_bar_row = nb.margin_row(null, drop)
	_bar_row.name = "FilaBarra"
	add_child(_bar_row)
	# --- filtros activos
	_chips = HFlowContainer.new()
	_chips.name = "Filtros"
	_chips.add_theme_constant_override("h_separation", 6)
	_chips.add_theme_constant_override("v_separation", 4)
	_chips_row = nb.margin_row(null, _chips)
	_chips_row.visible = false
	add_child(_chips_row)
	# --- lista
	_scroll = nb.scroll_box()
	_scroll.name = "Lista"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", ClipCard.CARD_SEP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)
	set_process(false)

# Barra de filtros: recibe un chip del índice.
class DropBar extends MarginContainer:
	var tab
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _can_drop_data(_at: Vector2, data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "ent"
	func _drop_data(_at: Vector2, data) -> void:
		tab.nb.filter_entity(String(data.get("id", "")))

func refresh() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_cards.clear()
	_groups.clear()
	_clips = nb.clips()
	var rows: Array = nb.index_rows()
	_kinds = Model.kinds_of(rows)
	_labels.clear()
	for r in rows:
		_labels[String(r.get("id", ""))] = String(r.get("label", ""))
	_menu_opts = Model.filter_options(_clips, rows)
	# un lugar `p:` que no está en el índice: su etiqueta del repo, no el id
	for o in _menu_opts.get("lugar", []):
		if String(o.label) == String(o.id):
			o.label = nb.ent_label(String(o.id))
			_labels[String(o.id)] = String(o.label)
	var wide: bool = nb.is_wide()
	_layout_bar(wide)
	# sin un solo recorte no hay nada que buscar ni filtrar: la página sólo dice cómo se recorta. Después, la búsqueda y
	# los filtros aparecen con sus banderas (y un filtro con una sola opción no se ofrece)
	var any_menu := false
	for k in MENU_KEYS:
		var on: bool = not _clips.is_empty() and nb.flag("nb.filtros") and (_menu_opts.get(k, []) as Array).size() >= 2
		(_menus[k] as Control).visible = on
		any_menu = any_menu or on
	_search.visible = not _clips.is_empty() and nb.flag("nb.buscar")
	_bar_row.visible = _search.visible or any_menu
	_row2.visible = _row2.visible and any_menu
	var grouped: bool = nb.flag("nb.agrupar")
	for g in Model.groups(_clips):
		var head := Widgets.label(Model.month_label(nb.text_fn(), String(g.key)), "DocTitle")
		head.add_theme_font_size_override("font_size", int(round(nb._px("ui") * 1.18)))
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 0)
		hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hv.add_child(head)
		var rule := HSeparator.new()
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hv.add_child(rule)
		var hrow: HBoxContainer = nb.margin_row(null, hv)
		hrow.name = "Mes_" + (String(g.key) if String(g.key) != "" else "sin_fecha")
		_list.add_child(hrow)
		var grp := {"key": String(g.key), "head": hrow, "cards": [], "grouped": grouped}
		for c in g.clips:
			var card := ClipCard.new(nb, c, wide)
			_list.add_child(card)
			_cards[String(c.id)] = card
			grp.cards.append(card)
		_groups.append(grp)
	_empty = nb.empty_line("")
	_empty.name = "Vacio"
	_list.add_child(nb.margin_row(null, _empty))
	sync_filters()
	_restore_scroll.call_deferred(keep)

# Ancho: búsqueda y filtros en un renglón; angosto (acoplado junto a la carpeta del Expediente): los filtros debajo.
func _layout_bar(wide: bool) -> void:
	var dest: Container = _row1 if wide else _row2
	for k in MENU_KEYS:
		var mb: MenuButton = _menus[k]
		if mb.get_parent() != dest:
			mb.get_parent().remove_child(mb)
			dest.add_child(mb)
	_row2.visible = not wide

func _restore_scroll(v: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v

# Pone la búsqueda y los chips al día con nb.filters y aplica.
func sync_filters() -> void:
	if _search.text != String(nb.filters.get("q", "")):
		_search.text = String(nb.filters.get("q", ""))
	_apply()

func _apply() -> void:
	var f: Dictionary = nb.filters
	var vis := {}
	for c in Model.apply_filters(_clips, f, _kinds):
		vis[String(c.id)] = true
	var any := false
	for g in _groups:
		var shown := 0
		var last_date := ""
		for card in g.cards:
			var on := vis.has(card.id)
			card.visible = on
			if on:
				shown += 1
				var d := String(card.clip.get("chron_date", ""))
				# playtest v3: el número suelto del margen no se entendía; «día 4» tampoco (se leía como el día 4 de la
				# partida): es la fecha de la crónica, «4 may.»; sin el encabezado del mes (antes de nb.agrupar), con el año
				var ml := ""
				if d.length() >= 10 and d != last_date:
					ml = Model.day_label(nb.text_fn(), d)
					if not bool(g.get("grouped", true)):
						ml += "\n" + d.substr(0, 4)
				card.set_margin(ml)
				last_date = d
		g.head.visible = shown > 0 and bool(g.get("grouped", true))
		any = any or shown > 0
	if _empty != null:
		_empty.get_parent().visible = not any
		_empty.text = nb.t("nb.vacio.recortes") if _clips.is_empty() else nb.t("nb.vacio.filtro")
	_sync_chips()

func _sync_chips() -> void:
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var act: Array = Model.active_filters(nb.filters)
	_chips_row.visible = not act.is_empty()
	for k in act:
		var v := String(nb.filters[k])
		var label := v
		if k == "fecha":
			label = Model.month_label(nb.text_fn(), v)
		else:
			label = String(_labels.get(v, v))
		var b := Button.new()
		b.name = "Quitar_" + k
		b.text = label
		b.focus_mode = Control.FOCUS_NONE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.icon = Paper.icon("cross", maxi(10, nb._px("small") - 2), Paper.ink("lapiz"))
		b.add_theme_font_size_override("font_size", nb._px("small"))
		var chip_sb := Paper.style("diario_hueso", {"margin": 9, "margin_v": 3, "radius": 1, "shadow_size": 2, "shadow_y": 1})
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, chip_sb)
		b.pressed.connect(func():
			nb.filters[k] = ""
			_apply())
		_chips.add_child(b)
	if not act.is_empty():
		var clr := Widgets.ink_button(nb.t("nb.filtro.quitar"), func():
			for kk in Model.FILTER_KEYS:
				nb.filters[kk] = ""
			_apply())
		clr.name = "QuitarTodo"
		clr.add_theme_font_size_override("font_size", nb._px("small"))
		_chips.add_child(clr)

func _fill_menu(k: String) -> void:
	var pm: PopupMenu = _menus[k].get_popup()
	pm.clear()
	var opts: Array = _menu_opts.get(k, [])
	if opts.is_empty():
		pm.add_item(nb.t("nb.filtro.nada"), 0)
		pm.set_item_disabled(0, true)
		return
	for i in opts.size():
		var o: Dictionary = opts[i]
		var lab := Model.month_label(nb.text_fn(), String(o.key)) if k == "fecha" else String(o.label)
		pm.add_radio_check_item(lab, i)
		var cur := String(nb.filters.get(k, ""))
		pm.set_item_checked(i, cur != "" and cur == (String(o.key) if k == "fecha" else String(o.id)))

func _on_menu(i: int, k: String) -> void:
	var opts: Array = _menu_opts.get(k, [])
	if i < 0 or i >= opts.size():
		return
	var v := String(opts[i].key) if k == "fecha" else String(opts[i].id)
	nb.filters[k] = "" if String(nb.filters.get(k, "")) == v else v
	if k == "persona" or k == "lugar":
		nb.filters["ent"] = ""
	_apply()

# Elegir desde fuera (tests, drivers): opción por id/clave.
func choose(k: String, v: String) -> void:
	nb.filters[k] = v
	_apply()

func menu_options(k: String) -> Array:
	return _menu_opts.get(k, []).duplicate(true)

func visible_ids() -> Array:
	var out: Array = []
	for g in _groups:
		for card in g.cards:
			if card.visible:
				out.append(card.id)
	return out

func card(id: String):
	return _cards.get(id)

func debug_state() -> Dictionary:
	var heads: Array = []
	for g in _groups:
		if g.head.visible:
			heads.append(String(g.key))
	var menus: Array = []
	for k in MENU_KEYS:
		if (_menus[k] as Control).visible:
			menus.append(k)
	return {"cards": _cards.keys(), "visible": visible_ids(), "groups": heads, "empty": _empty.text if _empty != null and _empty.get_parent().visible else "",
		"chips": _chips.get_child_count(), "search": _search.visible and _bar_row.visible, "menus": menus}

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())

# Arrastre cerca del borde de la lista: desplaza (para llegar con el recorte a lo que no se ve).
func _process(delta: float) -> void:
	if not is_inside_tree() or not get_viewport().gui_is_dragging():
		return
	var r := _scroll.get_global_rect()
	var m := _scroll.get_global_mouse_position()
	if m.x < r.position.x or m.x > r.end.x:
		return
	if m.y < r.position.y + EDGE_PX and m.y > r.position.y - EDGE_PX:
		_scroll.scroll_vertical -= int(EDGE_SPEED * delta)
	elif m.y > r.end.y - EDGE_PX and m.y < r.end.y + EDGE_PX:
		_scroll.scroll_vertical += int(EDGE_SPEED * delta)
