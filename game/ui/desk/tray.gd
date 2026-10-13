# ui/desk/tray.gd — la bandeja (GDD§7.1: «la mañana es la respuesta»). Dueño: W3-SHELL. Panel en la capa de libros.
# Lo que llegó un día (Game.sim.q_tray(día)): cada papel con su color, su título y el sello «Recibido: <fecha>, <franja>»;
# también el ruido y las cuentas (todo igual, sin aviso). Pestañas de días anteriores (sólo días con algo). Clic en un
# papel -> read_requested(view). open(day := -1) · close() · señal closed. Sin contadores ni «nuevo».
extends Control

signal read_requested(view: String)
signal closed

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

const W := 640.0

var shell = null
var day := -1
var sheet: PanelContainer
var list: VBoxContainer
var days_row: HBoxContainer
var head: Label
var empty_label: Label
var _scroll: ScrollContainer
var _remeasure := 0

func _init() -> void:
	name = "Tray"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _sim():
	var g = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return g.sim if g != null else null

func _ready() -> void:
	sheet = Widgets.sheet("libro_mayor", {"pad": 26})
	sheet.custom_minimum_size = Vector2(W, 0)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	head = Widgets.heading("")
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var x := Widgets.ink_button(Widgets.t("kit.close"), close)
	top.add_child(x)
	days_row = HBoxContainer.new()
	days_row.add_theme_constant_override("separation", 4)
	v.add_child(days_row)
	v.add_child(Widgets.rule())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 120)
	v.add_child(_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	_scroll.add_child(list)
	empty_label = Widgets.marginal("")
	empty_label.visible = false
	v.add_child(empty_label)
	get_viewport().size_changed.connect(_place)
	set_process(false)

func open(p_day := -1) -> void:
	var sim = _sim()
	if sim == null:
		return
	var c: Dictionary = sim.q_clock()
	day = int(c.day) if p_day == null or int(p_day) < 0 else int(p_day)
	_fill(sim)
	visible = true
	modulate.a = 0.0
	Widgets.fade(self, 1.0, 0.2)
	_place.call_deferred()
	_remeasure = 2
	set_process(true)

# El alto de las filas con autowrap se conoce recién con el ancho: se vuelve a medir dos cuadros después.
func _process(_dt: float) -> void:
	if _remeasure > 0:
		_remeasure -= 1
		if _remeasure == 0:
			if visible:
				_place()
			set_process(false)

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _place() -> void:
	if sheet == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var h := minf(vs.y - 120.0, 640.0)
	var need := 0.0
	for c in list.get_children():
		if c is Control and not c.is_queued_for_deletion():
			need += maxf((c as Control).size.y, (c as Control).get_combined_minimum_size().y) + 12.0
	_scroll.custom_minimum_size.y = clampf(need, 90.0, maxf(90.0, h - 190.0))
	sheet.reset_size()
	sheet.position = Vector2((vs.x - sheet.size.x) * 0.5, maxf(40.0, (vs.y - sheet.size.y) * 0.45))

func days_with_items(sim) -> Array:
	var out: Array = []
	var cur := int(sim.q_clock().day)
	for d in range(0, cur + 1):
		if not sim.q_tray(d).is_empty():
			out.append(d)
	return out

func _fill(sim) -> void:
	for c in days_row.get_children():
		c.queue_free()
	for c in list.get_children():
		c.queue_free()
	var repo = sim.repo
	var cur := int(sim.q_clock().day)
	head.text = Widgets.t("shell.tray.title")
	var ds := days_with_items(sim)
	if not ds.has(cur):
		ds.append(cur)
	ds.sort()
	var group := ButtonGroup.new()
	for d in ds:
		var b := Widgets.ink_tab(_day_short(repo, d), group)
		b.button_pressed = d == day
		b.pressed.connect(func(): open(d))
		days_row.add_child(b)
	days_row.visible = ds.size() > 1
	var items: Array = sim.q_tray(day)
	empty_label.visible = items.is_empty()
	if items.is_empty():
		var wd := _weekday(repo, day)
		empty_label.text = Widgets.t("shell.tray.domingo") if wd == "dom" else Widgets.t("shell.tray.vacia")
	for it in items:
		list.add_child(_item(sim, it))

func _item(sim, it: Dictionary) -> Control:
	var view := String(it.get("view", ""))
	var v: Dictionary = sim.q_view(view)
	var paper := String(v.get("paper", "carta")) if v.get("paper") != null else "carta"
	if paper == "":
		paper = "carta"
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Widgets.restyle(row, func(): row.add_theme_stylebox_override("panel", Paper.style(paper if Paper.PAPERS.has(paper) else "carta", {"margin": 14, "shadow": true, "shadow_size": 4})))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	var t := Widgets.label(String(it.get("title", view)), "DocTitle")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(t)
	var how := String(it.get("how", ""))
	var hl := Widgets.source_line(Widgets.t("shell.tray.how." + how) if how != "" else "")
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(hl)
	var st := Widgets.stamp(String(it.get("stamp", "")), "roja", -4.0, true)
	h.add_child(st)
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			row.accept_event()
			read_requested.emit(view))
	return row

static func _info(repo, d: int) -> Dictionary:
	for x in repo.schedule().get("days", []):
		if int(x.get("day", -1)) == d:
			return x
	return {}

static func _weekday(repo, d: int) -> String:
	return String(_info(repo, d).get("weekday", ""))

static func _day_short(repo, d: int) -> String:
	var i := _info(repo, d)
	var date := String(i.get("date", ""))
	if date.length() < 10:
		return String(i.get("label", str(d)))
	return Widgets.t("shell.tray.dia", {"wd": Widgets.t("core.wd_corto." + String(i.get("weekday", ""))), "d": date.substr(8, 2).to_int()})
