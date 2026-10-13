# ui/notebook/tab_marginalia.gd — pestaña Marginalia (huevos de pascua, GDD§13). Dueño: W3-NOTEBOOK. Contrato: §6.5.
# Las notas de q_marginalia en el orden en que se hallaron: en el margen, el día en que Lisle las anotó; en el cuerpo,
# el título en cursiva y la nota a lápiz, con su letra. SIN contador ni total, sin huecos que delaten cuántas faltan:
# una página vacía es sólo una página vacía.
extends VBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const TimeKey = preload("res://core/util/timekey.gd")

var nb
var scissors := false
var _scroll: ScrollContainer
var _list: VBoxContainer
var _ids: Array = []

func _init(p_nb) -> void:
	nb = p_nb
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll = nb.scroll_box()
	_scroll.name = "Lista"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 22)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_ids.clear()
	var notes = nb.q("q_marginalia")
	if not notes is Array:
		notes = []
	var r = nb.repo()
	var sched: Dictionary = r.schedule() if r != null else {}
	var size := int(round(float(TextBuilder.slot_size("manuscrito")) * 1.0))
	var max_w := minf(nb.body_width(), 640.0 * nb._scale())
	for n in notes:
		var id := String(n.get("id", ""))
		var day := TimeKey.day_of(int(n.get("tk", 0)))
		var date := ""
		for d in sched.get("days", []):
			if int(d.get("day", -1)) == day:
				date = String(d.get("date", ""))
		var margin: Label = nb.margin_text(Model.day_label(nb.text_fn(), date))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := Widgets.label(String(n.get("name", "")), "Caption")
		title.add_theme_font_size_override("font_size", nb._px("ui"))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(title)
		var rtl := TextBuilder.make_rtl("manuscrito")
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.custom_minimum_size = Vector2(max_w, 0)
		rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var parsed: Dictionary = n.get("parsed", {})
		if parsed.is_empty():
			parsed = {"plain": String(n.get("note", "")), "styles": []}
		TextBuilder.build(rtl, parsed, {"slot": "manuscrito", "size": size})
		rtl.add_theme_color_override("default_color", Paper.ink("lapiz"))
		body.add_child(rtl)
		var row: HBoxContainer = nb.margin_row(margin, body)
		row.name = "Nota_" + id
		_list.add_child(row)
		_ids.append(id)

func debug_state() -> Dictionary:
	return {"notes": _ids.duplicate()}
