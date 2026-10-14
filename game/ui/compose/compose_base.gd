# ui/compose/compose_base.gd — marco común de los compositores (anuncio, telegrama/carta, informe). Dueño: W3-SCENEUI.
# CanvasLayer modal (capa 60, ARCHITECTURE §2.3): fondo atenuado que no deja pasar el mouse, una hoja centrada con título,
# subtítulo, cuerpo (lo arma cada compositor), la caja «texto final» (lo que se publica o envía tal cual, §6.1) y el pie
# con «Volver» y la acción principal. La acción comprometida pide un segundo paso (Widgets.confirm con el texto final).
# API común: open(arg := "") (arg: lo usa el telegrama, "telegram"|"letter") · close() · is_open() · final_text() ·
#   send() (abre la confirmación) · confirm_send() (envía sin la confirmación visual: tests/drivers) · debug_state() ·
#   back() -> bool (Shell: consume un fe_volver interno —confirmación abierta, selector— o false para que la pila cierre).
# Config: sim, act_fn, sounds (SimLink) · handle_back (fe_volver propio; Shell lo pone en false). El clic derecho sobre el
#   compositor siempre vuelve (lo consume la GUI).
# Señales: sent(res) (acción aceptada) · closed.
# Subclases: _paper() · _width() · _title_text() · _sub_text() · _build_body(v) · _refresh_body() · _action() -> Dictionary
#   (vacío = incompleto) · _send_label() · _final_slot() (ranura de fuente del texto final) · _confirm_extra() · _after_sent(res)
#   · _incomplete_text() (lo que se ve en la caja del texto final mientras falta algo).
extends CanvasLayer

signal sent(res: Dictionary)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const LisleNote = preload("res://ui/scene/lisle_note.gd")

const LAYER := 60

# Campo «___» que se llena eligiendo de una lista cerrada (o soltando un chip del índice: {"kind":"ent","id"}).
class Blank extends Button:
	signal changed(value: String)
	var options: Array = []      # [{id, label}]
	var value := ""
	var placeholder := "___"
	var none_text := ""
	var clear_text := ""         # si no está vacío, primera opción del menú para dejar el campo en blanco
	var shown_fn: Callable = Callable()   # (value) -> String: cómo se lee el campo lleno (el menú sigue con options.label)
	# playtest v3: vacío, un hueco ancho con borde punteado y «elegir…» (como la respuesta del expediente); lleno, se lee
	# como parte del renglón. empty_w = ancho mínimo del hueco vacío.
	var dashed := false
	var empty_w := 170.0
	var _popup: PopupMenu
	func _init(p_placeholder := "___") -> void:
		placeholder = p_placeholder
		theme_type_variation = "InkButton"
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_popup = PopupMenu.new()
		_popup.max_size = Vector2i(640, 420)
		_popup.id_pressed.connect(_on_id)
		add_child(_popup)
		pressed.connect(_open)
		_sync()
	func set_options(opts: Array) -> void:
		options = opts.duplicate(true)
		var ok := false
		for o in options:
			if String(o.id) == value:
				ok = true
		if not ok and value != "":
			value = ""
		_sync()
	func set_value(v: String) -> bool:
		if v == "":
			value = ""
			_sync()
			changed.emit(value)
			return true
		for o in options:
			if String(o.id) == v:
				value = v
				_sync()
				changed.emit(value)
				return true
		return false
	func label_of(v: String) -> String:
		for o in options:
			if String(o.id) == v:
				return String(o.get("label", v))
		return v
	func _sync() -> void:
		var shown := ""
		if value != "" and shown_fn.is_valid():
			shown = String(shown_fn.call(value))
		text = (shown if shown != "" else label_of(value)) if value != "" else placeholder
		modulate = Color(1, 1, 1, 1)
		add_theme_color_override("font_color", Paper.ink("negra") if value != "" else Paper.ink("tenue"))
		if dashed:
			custom_minimum_size.x = empty_w if value == "" else 0.0
			alignment = HORIZONTAL_ALIGNMENT_CENTER if value == "" else HORIZONTAL_ALIGNMENT_LEFT
			queue_redraw()
	func set_dashed(on: bool, w := 170.0) -> void:
		dashed = on
		empty_w = w
		_sync()
	func _draw() -> void:
		if not dashed or value != "":
			return
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var c := Color(Paper.ink("lapiz"), 0.85 if is_hovered() else 0.6)
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(2, int(a.distance_to(b) / 8.0))
			for k in n:
				if k % 2 == 0:
					draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, 1.3)
	func _open() -> void:
		_popup.clear()
		if options.is_empty():
			_popup.add_item(none_text if none_text != "" else "—", -2)
			_popup.set_item_disabled(0, true)
		elif clear_text != "" and value != "":
			_popup.add_item(clear_text, -1)
			_popup.add_separator()
		for i in options.size():
			_popup.add_item(String(options[i].get("label", options[i].id)), i)
		_popup.reset_size()
		var vp := get_viewport()
		if vp != null and vp.gui_embed_subwindows:
			_popup.position = Vector2i(get_global_transform_with_canvas() * Vector2(0, size.y + 2))
		else:
			_popup.position = Vector2i(get_screen_transform() * Vector2(0, size.y + 2))
		_popup.popup()
	func _on_id(i: int) -> void:
		if i == -1:
			set_value("")
		elif i >= 0 and i < options.size():
			set_value(String(options[i].id))
	func _can_drop_data(_at: Vector2, data) -> bool:
		if typeof(data) != TYPE_DICTIONARY or String(data.get("kind", "")) != "ent":
			return false
		for o in options:
			if String(o.id) == String(data.get("id", "")):
				return true
		return false
	func _drop_data(_at: Vector2, data) -> void:
		set_value(String(data.get("id", "")))

var link
var handle_back := true
var _sealed := false             # enviado y con el sello a la vista: refresh() no rehace la hoja
var close_delay := 0.75          # s que se ve el sello antes de cerrar (0 = cerrar en el acto; tests)
var root: Control
var dim: ColorRect
var sheet: PanelContainer
var body: VBoxContainer
var note
var final_box: VBoxContainer
var final_label: Label
var final_rtl: RichTextLabel
var send_button: Button
var back_button: Button
var _title: Label
var _sub: Label
var _confirm: Control = null
var _built := false
var _refresh_queued := false
var _connected := false

var sim:
	get: return link.sim_override
	set(v): link.sim_override = v
var act_fn: Callable:
	get: return link.act_fn
	set(v): link.act_fn = v
var sounds: bool:
	get: return link.sounds
	set(v): link.sounds = v

func _init() -> void:
	layer = LAYER
	link = SimLink.new()
	visible = false

func _ready() -> void:
	_ensure_built()

func _exit_tree() -> void:
	var g := SimLink.autoload("Game")
	if _connected and g != null and g.sim_changed.is_connected(_on_sim_changed):
		g.sim_changed.disconnect(_on_sim_changed)
	_connected = false

# ------------------------------------------------------------------ armado
func _ensure_built() -> void:
	if _built:
		return
	_built = true
	root = Control.new()
	root.name = "Raiz"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.name = "Atenuado"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	Widgets.restyle(dim, func(): dim.color = Color(0.08, 0.06, 0.04, 0.55) if not Paper.hc_on() else Color(0, 0, 0, 0.7))
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	sheet = Widgets.sheet(_paper(), {"pad": 34})
	sheet.name = "Hoja"
	sheet.custom_minimum_size = Vector2(_width(), 0)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.gui_input.connect(_on_dim_input)
	center.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	sheet.add_child(v)
	_title = Widgets.heading("")
	v.add_child(_title)
	_sub = Widgets.source_line("")
	v.add_child(_sub)
	v.add_child(Widgets.rule())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	_build_body(body)
	final_box = VBoxContainer.new()
	final_box.add_theme_constant_override("separation", 6)
	final_label = Widgets.small(link.t("sceneui.final"))
	final_box.add_child(final_label)
	var fp := PanelContainer.new()
	Widgets.restyle(fp, func(): fp.add_theme_stylebox_override("panel", Paper.flat(Color(1, 1, 1, 0.0) if Paper.hc_on() else Color(1, 1, 1, 0.28), Color(Paper.ink("tenue"), 0.8), [1, 1, 1, 1], 1, [18, 12, 18, 12])))
	final_rtl = RichTextLabel.new()
	final_rtl.bbcode_enabled = false
	# playtest v3: con tres ítems el informe (texto final manuscrito) ocupaba toda la altura de la pantalla: la caja crece
	# con el texto hasta FINAL_MAX_K de la pantalla y después se desplaza (rueda)
	final_rtl.fit_content = false
	final_rtl.scroll_active = true
	final_rtl.resized.connect(func(): _fit_final.call_deferred())
	final_rtl.finished.connect(func(): _fit_final.call_deferred())
	final_rtl.selection_enabled = false
	final_rtl.context_menu_enabled = false
	final_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp.add_child(final_rtl)
	final_box.add_child(fp)
	v.add_child(final_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 20)
	back_button = Widgets.ink_button(link.t("sceneui.back"), close)
	row.add_child(back_button)
	send_button = Widgets.button(_send_label(), send)
	row.add_child(send_button)
	v.add_child(row)
	note = LisleNote.new()
	note.anchor_left = 0.5
	note.anchor_right = 0.5
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = -170
	note.offset_bottom = -26
	note.offset_top = -26
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(note)
	Widgets.restyle(final_rtl, _style_final)

# Fuente del texto final. La manuscrita (Homemade Apple) tiene el espacio muy angosto: «darme.Su» se lee pegado; se le
# agrega aire con una FontVariation local (spacing_space) sin tocar el Theme.
var _hand_cache := {}
func _final_font() -> Font:
	var slot := _final_slot()
	var f: Font = SimLink.font(slot)
	if slot != "manuscrito" or f == null:
		return f
	var key := f.get_instance_id()
	if not _hand_cache.has(key):
		var fv := FontVariation.new()
		fv.base_font = f
		# 0,28 × doc no alcanzaba: la «S» mayúscula de Homemade Apple arranca con un rasgo hacia atrás que se come el
		# espacio («darme.Su», «HolywellStreet» en la captura de la carta); con 0,5 se lee separado
		fv.spacing_space = int(round(SimLink.px("doc") * 0.5))
		_hand_cache.clear()
		_hand_cache[key] = fv
	return _hand_cache[key]

func _style_final() -> void:
	var slot := _final_slot()
	final_rtl.add_theme_font_override("normal_font", _final_font())
	var k := {"imprenta": 1.0, "maquina": 0.92, "manuscrito": 0.95, "ui": 1.0}
	final_rtl.add_theme_font_size_override("normal_font_size", int(round(SimLink.px("doc") * float(k.get(slot, 1.0)))))
	final_rtl.add_theme_color_override("default_color", Paper.ink("negra"))
	final_rtl.add_theme_constant_override("line_separation", int(round(SimLink.px("doc") * (0.42 if slot == "maquina" else 0.2))))

# ------------------------------------------------------------------ API
func open(arg := "") -> void:
	_ensure_built()
	_set_arg(String(arg) if arg != null else "")
	if link.uses_game() and not _connected:
		var g := SimLink.autoload("Game")
		if g != null and g.has_signal("sim_changed"):
			g.sim_changed.connect(_on_sim_changed)
			_connected = true
	_close_confirm()
	_sealed = false
	note.hide_now()
	_title.text = _title_text()
	_sub.text = _sub_text()
	_sub.visible = _sub.text != ""
	send_button.text = _send_label()
	_on_open()
	refresh()
	visible = true
	link.play("sfx.papel")

func close() -> void:
	if not visible:
		return
	_close_confirm()
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func refresh() -> void:
	if _sealed:
		return   # enviado: mientras se ve el sello, la hoja queda como se envió (el sim ya cambió: n.º, debido…)
	_refresh_body()
	var a := _action()
	var txt := final_text()
	final_rtl.clear()
	_style_final()
	if txt == "":
		final_rtl.add_theme_color_override("default_color", Paper.ink("tenue"))
		final_rtl.add_text(_incomplete_text())
	else:
		final_rtl.add_text(display_text(txt))
	send_button.disabled = a.is_empty() or txt == ""
	_fit_final.call_deferred()

const FINAL_MAX_K := 0.26   # alto máximo de la caja del texto final, × alto de la pantalla
func _fit_final() -> void:
	if final_rtl == null or not is_instance_valid(final_rtl) or not final_rtl.is_inside_tree():
		return
	var cap := maxf(120.0, get_viewport().get_visible_rect().size.y * FINAL_MAX_K)
	var h := float(final_rtl.get_content_height())
	if h <= 0.0:
		h = float(SimLink.px("doc")) * 1.6
	var want := roundf(minf(h + 2.0, cap))
	if absf(final_rtl.custom_minimum_size.y - want) > 1.0:
		final_rtl.custom_minimum_size.y = want

# Sólo para mostrar (el texto enviado es el de q_preview, intacto): la raya pegada a lo que sigue (U+2060) y «E. L.» sin
# corte (U+00A0), para que la firma «—E. L.» no quede partida en dos renglones.
static func display_text(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		out += ch
		if ch == "—" and i + 1 < s.length() and s[i + 1] != " " and s[i + 1] != "\n":
			out += "⁠"
	return out.replace("E. L.", "E. L.")

# Inversa de display_text (tests: lo que se ve es, letra por letra, lo que se envía).
static func undisplay(s: String) -> String:
	return s.replace("⁠", "").replace(" ", " ")

func final_text() -> String:
	var a := _action()
	return link.preview(a) if not a.is_empty() else ""

func send() -> void:
	var a := _action()
	var txt := final_text()
	if a.is_empty() or txt == "":
		return
	_close_confirm()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.custom_minimum_size = Vector2(520, 0)
	r.add_theme_font_override("normal_font", _final_font())
	r.add_theme_font_size_override("normal_font_size", SimLink.px("doc"))
	r.add_theme_color_override("default_color", Paper.ink("negra"))
	r.add_text(display_text(txt))
	box.add_child(r)
	var extra := _confirm_extra()
	if extra != "":
		var ex := Widgets.source_line(extra)
		box.add_child(ex)
	var cf = Widgets.confirm(box, _send_label(), link.t("sceneui.back"), _confirm_title())
	cf.name = "Confirmacion"
	cf.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cf.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cf.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(cf)
	_confirm = cf
	# mientras se confirma, los botones del compositor no se repiten debajo (playtest v2: dos «Volver» y dos «Enviar»)
	_set_foot_visible(false)
	cf.decided.connect(func(ok):
		_close_confirm()
		if ok:
			confirm_send())
	link.play("sfx.papel")

func confirm_send() -> Dictionary:
	var a := _action()
	if a.is_empty():
		return {"ok": false, "err": "forma"}
	var res: Dictionary = link.act(a)
	if bool(res.get("ok", false)):
		_after_sent(res)
		sent.emit(res)
		var stx := _stamp_text(res)
		if stx != "" and close_delay > 0.0 and is_inside_tree():
			_sealed = true
			_show_stamp(stx)
			send_button.disabled = true
			var tw := create_tween()
			tw.tween_interval(close_delay)
			tw.tween_callback(func():
				visible = false
				closed.emit())
		else:
			visible = false
			closed.emit()
	else:
		note.say(link.err_text(String(res.get("err", ""))))
	return res

func _show_stamp(text: String) -> void:
	var stp := Widgets.stamp(text, "roja", -9.0)
	stp.name = "Sello"
	root.add_child(stp)
	var ms := stp.custom_minimum_size
	var c := sheet.get_global_rect().get_center() if sheet.is_inside_tree() else Vector2(800, 450)
	stp.position = c - ms * 0.5 + Vector2(120, 40)
	stp.scale = Vector2(1.25, 1.25)
	stp.pivot_offset = ms * 0.5
	stp.modulate.a = 0.0
	var tw := stp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stp, "modulate:a", 1.0, 0.12)
	tw.tween_property(stp, "scale", Vector2(1, 1), 0.12)
	link.play("sfx.sello")

func confirm_open() -> bool:
	return _confirm != null

func debug_state() -> Dictionary:
	return {"open": visible, "final": final_text(), "action": _action(), "confirm": _confirm != null, "note": note.text(),
		"send_disabled": send_button.disabled}

func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
	_set_foot_visible(true)

func _set_foot_visible(on: bool) -> void:
	for b in [send_button, back_button]:
		if b != null and is_instance_valid(b):
			b.modulate.a = 1.0 if on else 0.0
			b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE

func _on_sim_changed(kind: String, _p: Dictionary) -> void:
	if visible and ["index", "clock", "clip", "dossier", "report"].has(kind) and not _refresh_queued:
		_refresh_queued = true
		(func():
			_refresh_queued = false
			if visible:
				refresh()).call_deferred()

func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_back()
		root.accept_event()

func _back() -> void:
	if not back():
		close()

func back() -> bool:
	if _confirm != null:
		_close_confirm()
		return true
	return false

func _unhandled_input(ev: InputEvent) -> void:
	if visible and handle_back and ev.is_action_pressed("fe_volver"):
		_back()
		get_viewport().set_input_as_handled()

# Una línea de Blank (rótulo + campo) para los cuerpos.
func blank_row(label: String, blank: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label + ":"
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(blank)
	return h

func make_blank(placeholder := "___", on_change: Callable = Callable()) -> Blank:
	var b := Blank.new(placeholder)
	b.none_text = link.t("sceneui.blank.none")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on_change.is_valid():
		b.changed.connect(on_change)
	b.changed.connect(func(_v): refresh())
	return b

# ------------------------------------------------------------------ para las subclases
func _paper() -> String:
	return "carta"

func _width() -> float:
	return 760.0

func _title_text() -> String:
	return ""

func _sub_text() -> String:
	return ""

func _build_body(_v: VBoxContainer) -> void:
	pass

func _set_arg(_arg: String) -> void:
	pass

func _on_open() -> void:
	pass

func _refresh_body() -> void:
	pass

func _action() -> Dictionary:
	return {}

func _send_label() -> String:
	return link.t("sceneui.mail.send")

func _incomplete_text() -> String:
	return link.t("sceneui.final.incompleto")

func _confirm_title() -> String:
	return ""

func _final_slot() -> String:
	return "imprenta"

func _confirm_extra() -> String:
	return ""

func _after_sent(_res: Dictionary) -> void:
	pass

func _stamp_text(_res: Dictionary) -> String:
	return ""
