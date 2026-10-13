# ui/notebook/tab_diary.gd — pestaña Diario (D36, GDD§7.4, §8.1). Dueño: W3-NOTEBOOK. Contrato: ARCHITECTURE §6.5.
# q_diary agrupado por día (rótulo = schedule.days[].label). Margen: quién dijo la línea (nombre sólo si se presentó) o,
# en cada llegada a la bandeja, el sello «Recibido» con la fecha (cruzar actos y llegadas, JUG-15). El texto se arma con
# TextBuilder (rtl.get_parsed_text() == parsed.plain) y es recortable con la tijera (botón o C): seleccionar sobre un
# renglón y soltar -> SelectionMapper.map -> clip_text {src:{kind:"diary", ref:<id del renglón>}} (el sim conserva el
# origen: escena para una línea dicha, D36 para un acto). Error -> línea de Lisle; éxito -> la tira vuela a Recortes.
# Ningún renglón se distingue por su clase (act/private/line): los actos ciegos van «sin marca alguna» (GDD§7.4).
extends VBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

const SIZE_K := 0.9

var nb
var scissors := false
var _b_tijera: Button
var _hint: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows := {}          # id del renglón -> {rtl, parsed, entry}
var _order: Array = []
var _empty: Label
var _count_before := -1

func _init(p_nb) -> void:
	nb = p_nb
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	_b_tijera = Button.new()
	_b_tijera.name = "Tijera"
	_b_tijera.text = nb.t("nb.diario.tijera")
	_b_tijera.toggle_mode = true
	_b_tijera.focus_mode = Control.FOCUS_NONE
	_b_tijera.toggled.connect(func(on): nb._set_scissors(on))
	bar.add_child(_b_tijera)
	_hint = Widgets.label(nb.t("nb.diario.tijera_ayuda"), "SourceLine")
	_hint.name = "Ayuda"
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.visible = false
	bar.add_child(_hint)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(bar)
	var rule := Widgets.rule()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	add_child(nb.margin_row(null, head))
	_scroll = nb.scroll_box()
	_scroll.name = "Lista"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

func refresh() -> void:
	var vb := _scroll.get_v_scroll_bar()
	var at_end := _count_before < 0 or vb == null or _scroll.scroll_vertical >= int(vb.max_value - vb.page) - 24
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_order.clear()
	var entries = nb.q("q_diary")
	if not entries is Array:
		entries = []
	var r = nb.repo()
	var sched: Dictionary = r.schedule() if r != null else {}
	var known: Dictionary = nb.known_ids()
	var tf: Callable = nb.text_fn()
	var size := int(round(float(TextBuilder.slot_size("imprenta")) * SIZE_K))
	for d in Model.diary_days(entries, sched):
		var head := Widgets.label(String(d.label), "DocTitle")
		head.add_theme_font_size_override("font_size", int(round(nb._px("ui") * 1.12)))
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hrow: HBoxContainer = nb.margin_row(null, head)
		hrow.name = "Dia_%d" % int(d.day)
		if _list.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list.add_child(gap)
		_list.add_child(hrow)
		for e in d.entries:
			var eid := String(e.get("id", ""))
			var kind := String(e.get("kind", ""))
			var margin: Control = null
			if kind == "line":
				margin = nb.margin_text(Model.speaker_label(r, known, String(e.get("who", "")), tf), "SourceLine")
			elif kind == "arrival":
				var stamp := Widgets.stamp(Model.recibido_stamp(tf, sched, int(e.get("day", 0))), "roja", -5.0, true)
				stamp.name = "Sello"
				var sl: Label = stamp.get_meta("label")
				sl.add_theme_font_size_override("font_size", maxi(11, int(round(nb._px("small") * 0.8))))
				sl.add_theme_constant_override("line_spacing", -3)
				var holder := HBoxContainer.new()
				holder.alignment = BoxContainer.ALIGNMENT_END
				holder.add_child(stamp)
				margin = holder
			var parsed: Dictionary = e.get("parsed", {})
			var rtl := TextBuilder.make_rtl("imprenta")
			rtl.name = "Renglon_" + eid.replace(".", "_")
			TextBuilder.build(rtl, parsed, {"slot": "imprenta", "size": size})
			rtl.add_theme_color_override("font_selected_color", Color(0, 0, 0, 0))
			# todos los renglones con la misma tinta: los actos ciegos («private»: en casa, la tienda de Crane) se anotan
			# «sin marca alguna» (GDD§7.4); atenuarlos le diría al jugador qué actos nadie observa.
			rtl.gui_input.connect(_on_rtl_input.bind(eid))
			var row: HBoxContainer = nb.margin_row(margin, rtl)
			row.name = "Fila_" + eid.replace(".", "_")
			_list.add_child(row)
			_rows[eid] = {"rtl": rtl, "parsed": parsed, "entry": e}
			_order.append(eid)
	if _order.is_empty():
		_empty = nb.empty_line(nb.t("nb.vacio.diario"))
		_list.add_child(nb.margin_row(null, _empty))
	else:
		_empty = null
	set_scissors(scissors)
	var grew := _order.size() > _count_before
	_count_before = _order.size()
	_restore.call_deferred(keep, at_end and grew)

func _restore(v: int, to_end: bool) -> void:
	if not is_instance_valid(_scroll):
		return
	if to_end and is_inside_tree():
		# el alto de la lista se conoce un cuadro después; la conexión muere con el nodo
		get_tree().process_frame.connect(_to_end, CONNECT_ONE_SHOT)
	else:
		_scroll.scroll_vertical = v

func _to_end() -> void:
	var vb := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(vb.max_value) if vb != null else 1 << 20

func set_scissors(on: bool) -> void:
	scissors = on
	if _b_tijera != null:
		_b_tijera.set_pressed_no_signal(on)
	if _hint != null:
		_hint.visible = on
	mouse_default_cursor_shape = Control.CURSOR_IBEAM if on else Control.CURSOR_ARROW
	for eid in _rows:
		var rt: RichTextLabel = _rows[eid].rtl
		if not on:
			rt.deselect()
		rt.selection_enabled = on
		rt.mouse_default_cursor_shape = Control.CURSOR_IBEAM if on else Control.CURSOR_ARROW

func _on_rtl_input(ev: InputEvent, eid: String) -> void:
	if not scissors:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var rt: RichTextLabel = _rows[eid].rtl
		if ev.pressed:
			for k in _rows:
				if k != eid:
					(_rows[k].rtl as RichTextLabel).deselect()
		else:
			var pos: Vector2 = rt.get_global_transform_with_canvas() * ev.position
			_try_clip.call_deferred(eid, pos)

func _try_clip(eid: String, pos: Vector2) -> void:
	if not _rows.has(eid):
		return
	var rt: RichTextLabel = _rows[eid].rtl
	var sel := rt.get_selected_text()
	if sel == "":
		return
	var m := SelectionMapper.map(rt, _rows[eid].parsed)
	rt.deselect()
	if not m.ok:
		nb.say(nb.t("reader.no_cuadra"))
		return
	clip_entry(eid, int(m.from), int(m.len), pos)

# Recorta [from, from+len) del renglón eid (también lo usan tests y drivers).
func clip_entry(eid: String, from: int, length: int, pos := Vector2(-1, -1)) -> Dictionary:
	var res: Dictionary = nb.act({"t": "clip_text", "src": {"kind": "diary", "ref": eid}, "from": from, "len": length})
	if bool(res.get("ok", false)):
		nb.on_clipped(res)
		var c = nb.q("q_clip", [String(res.get("clip", ""))])
		var txt := String(c.get("text", "")) if c is Dictionary else ""
		if pos.x < 0.0 and _rows.has(eid):
			var rt: RichTextLabel = _rows[eid].rtl
			pos = rt.get_global_transform_with_canvas() * (rt.size * 0.5)
		nb.fly_strip(txt, pos)
	else:
		nb.say(nb.err_text(String(res.get("err", ""))))
	return res

func rtl_of(eid: String) -> RichTextLabel:
	return _rows[eid].rtl if _rows.has(eid) else null

func parsed_of(eid: String) -> Dictionary:
	return _rows[eid].parsed if _rows.has(eid) else {}

func row_ids() -> Array:
	return _order.duplicate()

func debug_state() -> Dictionary:
	var stamps := 0
	var days: Array = []
	for c in _list.get_children():
		if String(c.name).begins_with("Dia_"):
			days.append(String(c.name).substr(4).to_int())
	for eid in _order:
		if String(_rows[eid].entry.get("kind", "")) == "arrival":
			stamps += 1
	return {"rows": _order.duplicate(), "days": days, "stamps": stamps, "scissors": scissors, "empty": _empty.text if _empty != null else ""}
