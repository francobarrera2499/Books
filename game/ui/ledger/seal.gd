# ui/ledger/seal.gd — el sello «Visto» y su tampón, junto al libro mayor (§6.6, GDD§8.5). Dueño: W3-LEDGER.
# Un papel con: el sello (clic -> stamp_pressed), el tampón dibujado por código (entintado o seco: seco mientras
# passes_left == 0, así se ve que la pasada de la franja se usó) y las ranuras «Al sello» (tantas como el lote:
# 2, o 1 el último día) con los asientos marcados. No cuenta nada ni avisa: el estado se lee en el tampón y las ranuras.
# Ranura vacía «+ un asiento a lápiz»: clic -> slot_add_pressed(ranura) (el libro ofrece los asientos a lápiz).
# Ranura llena: clic en el texto -> slot_pressed(eid) (abre el asiento); la cruz -> slot_remove_pressed(eid).
# sync(state, cards): state = LedgerModel.seal_state; cards = [{id, text}] de los marcados. En el prólogo (reason
#   «practica») las ranuras dan lugar a la línea de Lisle: esta noche sólo se practica, cada errata con su sello. Con
#   lote de cero (reason «nada»: todo lo que cuenta ya está sellado) tampoco hay ranuras: lo dice Lisle.
# press(inked): golpe del sello (≤0,4 s, sin rebote); la impresión (roja con tinta, pálida en seco) cae sobre los
#   papelitos de los asientos que se pasaron: mientras dura, las ranuras los conservan (holding()) y después se vacían.
# GDD_v2 §C.3: el tampón dibujado se fue; el estado de la tinta se lee en UNA línea bajo el sello («Con tinta.» / «El
#   sello no tiene tinta hasta el próximo turno.»). El panel entero aparece recién con la bandera lg.sello (lo decide el
#   libro).
extends PanelContainer

signal stamp_pressed
signal slot_pressed(eid: String)
signal slot_add_pressed(anchor: Control)
signal slot_remove_pressed(eid: String)

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

var state := {}
var cards: Array = []
var stamp_box: Control
var pad: Control
var _stamp: Control
var _slots: VBoxContainer
var _caption: Label
var _fx: Control
var _tw: Tween = null
var _hold := false              # la impresión está sobre los papelitos: no se rehacen las ranuras
var _pending := false           # hubo un sync durante la impresión
var _imp: Control = null
var ink_line: Label

class Pad extends Control:
	var dry := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(150, 46)
	func _draw() -> void:
		var hc := Paper.hc_on()
		var w := size.x
		var h := size.y
		var tin := Rect2(Vector2(w * 0.5 - 70.0, 4.0), Vector2(140.0, h - 8.0))
		# lata
		var rim := Color(0, 0, 0) if hc else Color("4d4a44")
		var tin_c := Color(1, 1, 1) if hc else Color("6b675f")
		draw_style_box(Paper.flat(tin_c, rim, [2, 2, 2, 2], 6), tin)
		var felt := tin.grow(-7.0)
		var felt_c: Color
		if hc:
			felt_c = Color(0.15, 0.15, 0.15) if not dry else Color(0.85, 0.85, 0.85)
		else:
			felt_c = Color("3a1916") if not dry else Color("bcae97")
		draw_style_box(Paper.flat(felt_c, Color(0, 0, 0, 0), [0, 0, 0, 0], 3), felt)
		if not dry and not hc:
			# brillo húmedo de la tinta: una veta más clara
			draw_line(felt.position + Vector2(10, 6), felt.position + Vector2(felt.size.x * 0.55, 6), Color(1, 0.8, 0.75, 0.18), 2.0)
		elif dry:
			# grietas del fieltro seco
			var cc := Color(0, 0, 0, 0.5) if hc else Color("8e7f69")
			var p := felt.position
			var s := felt.size
			draw_polyline(PackedVector2Array([p + Vector2(s.x * 0.12, s.y * 0.3), p + Vector2(s.x * 0.3, s.y * 0.45), p + Vector2(s.x * 0.36, s.y * 0.8)]), cc, 1.0)
			draw_polyline(PackedVector2Array([p + Vector2(s.x * 0.55, s.y * 0.15), p + Vector2(s.x * 0.62, s.y * 0.5), p + Vector2(s.x * 0.8, s.y * 0.62)]), cc, 1.0)
			draw_polyline(PackedVector2Array([p + Vector2(s.x * 0.7, s.y * 0.85), p + Vector2(s.x * 0.86, s.y * 0.35)]), cc, 1.0)

class StampButton extends Control:
	signal pressed_stamp
	var label: Label
	var ink := "roja"
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(170, 64)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			accept_event()
			pressed_stamp.emit()

func _init() -> void:
	name = "Sello"
	add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 14, "margin_v": 12, "shadow_size": 7}))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	stamp_box = StampButton.new()
	stamp_box.name = "Estampar"
	stamp_box.pressed_stamp.connect(func(): stamp_pressed.emit())
	v.add_child(stamp_box)
	_stamp = Widgets.stamp(Widgets.t("ledger.sello"), "roja", -4.0)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_box.add_child(_stamp)
	stamp_box.label = _stamp.get_meta("label")
	stamp_box.resized.connect(_center_stamp)
	_stamp.minimum_size_changed.connect(_center_stamp)
	pad = Pad.new()
	pad.name = "Tampon"
	pad.visible = false
	v.add_child(pad)
	ink_line = Widgets.label("", "SourceLine")
	ink_line.name = "Tinta"
	ink_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ink_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ink_line.custom_minimum_size = Vector2(176, 0)
	v.add_child(ink_line)
	v.add_child(Widgets.rule())
	_caption = Widgets.label(Widgets.t("ledger.sello.lote"), "SourceLine")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_caption)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 4)
	v.add_child(_slots)
	_fx = Control.new()
	_fx.name = "FX"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

func _center_stamp() -> void:
	if _stamp == null or stamp_box == null:
		return
	var ms := _stamp.get_combined_minimum_size()
	_stamp.size = ms
	_stamp.position = (stamp_box.size - ms) * 0.5
	_stamp.pivot_offset = ms * 0.5

func sync(p_state: Dictionary, p_cards: Array) -> void:
	state = p_state
	cards = p_cards
	add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 14, "margin_v": 12, "shadow_size": 7}))
	var dry := bool(state.get("dry", true))
	pad.dry = dry
	pad.queue_redraw()
	var lab: Label = _stamp.get_meta("label")
	var c := Paper.ink("tenue" if dry else "roja")
	lab.add_theme_color_override("font_color", c)
	var sb := Paper.flat(Color(0, 0, 0, 0), c, [3, 3, 3, 3], 7, [14, 1, 14, 3])
	lab.add_theme_stylebox_override("normal", sb)
	lab.modulate.a = 0.55 if dry else 0.92
	# explicación de la forma al pasar el ratón (qué es cada cosa), nunca del contenido
	stamp_box.tooltip_text = Widgets.t("ledger.sello.tip")
	match String(state.get("reason", "")):
		"practica":
			pad.tooltip_text = Widgets.t("ledger.sello.practica")
		"fuera":
			pad.tooltip_text = Widgets.t("ledger.sello.fuera")
		"nada":
			pad.tooltip_text = Widgets.t("ledger.sello.nada")
		_:
			pad.tooltip_text = Widgets.t("ledger.tampon.seco" if dry else "ledger.tampon.tinta")
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	ink_line.text = Widgets.t("v2d.lg.sello.seco" if dry else "v2d.lg.sello.tinta")
	ink_line.add_theme_color_override("font_color", Paper.ink("tenue" if dry else "lapiz"))
	ink_line.add_theme_font_size_override("font_size", _small_px())
	ink_line.visible = String(state.get("reason", "")) != "practica"
	_center_stamp.call_deferred()
	if _hold:
		_pending = true
		return
	_rebuild_slots()

func _rebuild_slots() -> void:
	_pending = false
	for ch in _slots.get_children():
		_slots.remove_child(ch)
		ch.queue_free()
	var why := String(state.get("reason", ""))
	if why == "practica" or why == "nada":
		# prólogo (sólo práctica) o lote de cero (nada que pasar): no hay ranuras; lo dice Lisle donde irían
		_caption.visible = false
		var m := Widgets.marginal(Widgets.t("ledger.sello.practica" if why == "practica" else "ledger.sello.nada"))
		m.name = "SoloPractica" if why == "practica" else "SinLote"
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.custom_minimum_size = Vector2(176, 0)   # ancho fijo: con autowrap y ancho 0 pediría un alto enorme
		m.add_theme_font_size_override("font_size", _small_px())
		m.add_theme_color_override("font_color", Paper.ink("lapiz"))
		_slots.add_child(m)
		return
	var n := int(state.get("lot_size", 2))
	_caption.visible = n > 0
	for i in n:
		var eid := ""
		var txt := Widgets.t("ledger.sello.hueco")
		if i < cards.size():
			txt = String(cards[i].get("text", ""))
			eid = String(cards[i].get("id", ""))
		_slots.add_child(_slip(i, txt, eid))

static func _small_px() -> int:
	var ti := Widgets.ti()
	return ti.px("small") if ti != null else 15

func holding() -> bool:
	return _hold

# Termina la impresión: se quita la marca y las ranuras se ponen al día (lo llama el tween; tests y drivers, también).
func release_hold() -> void:
	if _imp != null and is_instance_valid(_imp):
		_imp.queue_free()
	_imp = null
	_hold = false
	_rebuild_slots()

# Una ranura del lote: papelito con el asiento marcado (y su cruz) o vacío, con trazo tenue.
func _slip(i: int, txt: String, eid: String) -> Control:
	var slip := PanelContainer.new()
	slip.name = "Ranura%d" % i
	slip.theme_type_variation = "Chip"
	slip.mouse_filter = Control.MOUSE_FILTER_STOP
	slip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if eid == "":
		var sb := Paper.flat(Color(Paper.paper("cuaderno"), 0.0), Color(Paper.ink("tenue"), 0.7), [1, 1, 1, 1], 2, [8, 4, 8, 5])
		slip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.add_child(h)
	var l := Widgets.label(txt, "ChipLabel")
	l.name = "Texto"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# una sola línea: una etiqueta con autowrap nace con ancho 0, pide un alto enorme y el papel del sello crecía sin
	# volver a encoger (quedaba vacío a la vista tras acoplarse). Lo largo se corta con «…»; el texto entero, al pasar.
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(60, 0)
	l.add_theme_font_size_override("font_size", _small_px())   # «Asiento 12 · Propósito» entra entero
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slip.tooltip_text = txt if eid != "" else ""
	h.add_child(l)
	if eid == "":
		l.add_theme_color_override("font_color", Paper.ink("tenue"))
		slip.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
				slip.accept_event()
				slot_add_pressed.emit(slip))
		return slip
	slip.set_meta("eid", eid)
	slip.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			slip.accept_event()
			slot_pressed.emit(eid))
	var x := Button.new()
	x.name = "Quitar"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.icon = Paper.icon("cross", 12, Paper.ink("lapiz"))
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		x.add_theme_stylebox_override(k, Paper.empty([3, 0, 1, 0]))   # sin el relleno de botón: el texto entra entero
	x.tooltip_text = Widgets.t("ledger.sello.quitar")
	x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(func(): slot_remove_pressed.emit(eid))
	h.add_child(x)
	return slip

func slot_node(i: int) -> Control:
	return _slots.get_node_or_null("Ranura%d" % i) if _slots != null else null

# Golpe del sello. inked: impresión roja que queda un momento sobre los papelitos; seco: marca pálida. Las ranuras
# conservan los asientos pasados mientras dura la impresión (el libro ya vació el lote) y luego se vacían.
func press(inked: bool) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if _hold:
		release_hold()
	_hold = true
	_stamp.scale = Vector2.ONE
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_stamp, "scale", Vector2(0.93, 0.93), 0.1)
	_tw.tween_property(_stamp, "scale", Vector2.ONE, 0.18)
	var imp := Widgets.stamp(Widgets.t("ledger.sello"), "roja" if inked else "tenue", -9.0)
	imp.name = "Impresion"
	imp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(imp)
	imp.modulate.a = 0.0
	var ms := imp.get_combined_minimum_size()
	imp.size = ms
	# sobre las ranuras (los asientos que se pasan), sin salirse del papel del sello (coordenadas locales: el sello puede
	# estar escalado dentro del escenario del libro)
	var box: Control = _slots.get_parent()
	var at := _slots.position + _slots.size * 0.5
	if _slots.get_child_count() == 0:
		at = stamp_box.position + stamp_box.size * 0.5
	at += box.position - _fx.position
	var lim := _fx.size
	at.x = clampf(at.x, ms.x * 0.5, maxf(ms.x * 0.5, lim.x - ms.x * 0.5))
	at.y = clampf(at.y, ms.y * 0.5, maxf(ms.y * 0.5, lim.y - ms.y * 0.5))
	imp.position = at - ms * 0.5
	imp.pivot_offset = ms * 0.5
	imp.scale = Vector2(1.18, 1.18)
	_imp = imp
	var t2 := imp.create_tween()
	t2.set_parallel(true)
	t2.tween_property(imp, "modulate:a", 0.9 if inked else 0.4, 0.22).set_delay(0.1)
	t2.tween_property(imp, "scale", Vector2.ONE, 0.25).set_delay(0.1)
	t2.chain().tween_interval(1.6 if inked else 1.0)
	t2.chain().tween_property(imp, "modulate:a", 0.0, 0.4)
	t2.chain().tween_callback(func(): if _imp == imp: release_hold())
