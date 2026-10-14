# ui/epilogue/blue_pencil.gd — el Expediente Holmes devuelto, corregido a lápiz azul (post-créditos). Dueño: UI-EXPEDIENTE
# (GDD_v3 §6.10 «Lápiz azul»; antes W4-EPILOGUE con el libro mayor). Lee el expediente (ExpedienteModel.pencil: q_dossier
# + q_blue_pencil), no el libro mayor: cada hoja tal como la dejó el jugador (en tinta, con el texto de Lisle en letra
# de imprenta negra; a lápiz, la respuesta y las pruebas en letra de mano gris). Encima, con la letra de S. H. en azul:
# tachado y nota al margen en cada hoja en lápiz completa que no cierra («Corríjalo: …»), y en el margen de cada pregunta
# nacida sin tinta «Falta: …»; las notas sin pregunta conocida, al pie; la firma («Tírese. —S. H.» o «Corríjase y
# vuelva a pruebas. —S. H.»; «Hum. Nada que corregir.» si no hay nada). Revela al terminar; no entrega nada durante el
# juego. Rueda = desplazar; «Cerrar el libro» (pie fijo al borde de abajo, siempre a la vista) o Esc / clic derecho /
# Intro (close_book) -> finished.
#   open(sim, shell) · start() · finished · notes() -> Array (tests: textos azules mostrados) · close_book() · close_rect()
extends Control

signal finished

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Model = preload("res://ui/expediente/expediente_model.gd")

const SHEET_W := 940.0
const NOTE_W := 270.0
const STAGGER_S := 0.22
const FOOT_H := 78.0

var sim = null
var shell = null
var fast := false
var vm := {}
var _scroll: ScrollContainer
var _sheet: PanelContainer
var _list: VBoxContainer
var _blue: Array = []          # nodos azules (aparecen de a uno)
var _close: Button
var _done := false

# Tachado azul sobre una hoja errónea (dibujado encima del texto): un trazo por renglón, a media altura de la letra y
# sólo hasta donde llega el texto.
class Strike extends Control:
	var label: Label = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func rows() -> Array:
		var acc := {}
		if label == null or not label.has_method("get_character_bounds"):
			return []
		var t := label.text
		for k in t.length():
			if t[k] == " " or t[k] == "\n":
				continue
			var r: Rect2 = label.get_character_bounds(k)
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			var key := int(round(r.position.y))
			if acc.has(key):
				acc[key] = [minf(acc[key][0], r.position.x), maxf(acc[key][1], r.end.x), maxf(acc[key][2], r.size.y)]
			else:
				acc[key] = [r.position.x, r.end.x, r.size.y]
		var out: Array = []
		var ks := acc.keys()
		ks.sort()
		for key in ks:
			out.append({"y": float(key), "x0": float(acc[key][0]), "x1": float(acc[key][1]), "h": float(acc[key][2])})
		return out
	func _draw() -> void:
		var c := Paper.ink("azul")
		var rs := rows()
		if rs.is_empty():
			var y := size.y * 0.52
			draw_line(Vector2(0, y + 2), Vector2(size.x, y - 3), c, 2.0, true)
			return
		var off := label.position
		var i := 0
		for r in rs:
			var y: float = off.y + float(r.y) + float(r.h) * 0.44
			var x0: float = off.x + float(r.x0) - 4.0
			var x1: float = off.x + float(r.x1) + 4.0
			var tilt := -2.0 + 1.2 * float(i % 2)
			draw_line(Vector2(x0, y + 1.0), Vector2(x1, y + tilt), c, 2.0, true)
			i += 1

func _init() -> void:
	name = "LapizAzul"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Paper.MESA
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scroll = ScrollContainer.new()
	_scroll.name = "Desplazar"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_bottom = -FOOT_H   # el pie con «Cerrar el libro» queda fijo debajo, siempre a la vista
	add_child(_scroll)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	cc.add_child(col)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 26)
	col.add_child(top)
	_sheet = Widgets.sheet("carta", {"margin_line": 40, "margin_double": true, "pad": 58})
	_sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	col.add_child(_sheet)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	_sheet.add_child(_list)
	var bot := Control.new()
	bot.custom_minimum_size = Vector2(0, 30)
	col.add_child(bot)
	# pie FIJO al borde de abajo (fuera del desplazable): la única salida del juego siempre a la vista.
	var foot := CenterContainer.new()
	foot.name = "PieFijo"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -FOOT_H
	foot.offset_bottom = 0
	add_child(foot)
	var chip := Widgets.paper_panel("carta", null, {"margin": 8, "shadow": true})
	chip.name = "Pie"
	foot.add_child(chip)
	_close = Widgets.ink_button(Model.tx(null, "epilogue.cerrar"), _on_close)
	_close.name = "Cerrar"
	chip.add_child(_close)

func open(p_sim = null, p_shell = null) -> void:
	sim = p_sim
	shell = p_shell
	if shell != null and "fast" in shell:
		fast = bool(shell.fast)
	_close.text = Model.tx(sim, "epilogue.cerrar")
	vm = Model.pencil(sim)
	_build()

func _hand(text: String, ink: String, k := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ti := TextBuilder.ti_node()
	if ti != null:
		l.add_theme_font_override("font", ti.font("manuscrito"))
	l.add_theme_font_size_override("font_size", int(round(float(TextBuilder.slot_size("manuscrito")) * k)))
	l.add_theme_color_override("font_color", Paper.ink(ink))
	return l

func _print(text: String, variation := "", k := 1.0) -> Label:
	var l := Widgets.label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation == "":
		var ti := TextBuilder.ti_node()
		if ti != null:
			l.add_theme_font_override("font", ti.font("imprenta"))
			l.add_theme_font_size_override("font_size", int(round(float(ti.px("doc")) * k)))
		l.add_theme_color_override("font_color", Paper.ink("negra"))
	return l

func _blue_label(text: String, k := 0.95, angle := -1.5) -> Control:
	var l := _hand(text, "azul", k)
	l.rotation_degrees = angle
	_blue.append(l)
	return l

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	_blue.clear()
	# cabecera de S. H.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.add_child(_blue_label(String(vm.get("title", "")), 1.35, -1.0))
	head.add_child(_blue_label(String(vm.get("header", "")), 0.85, -0.6))
	_list.add_child(head)
	var rows: Array = vm.get("rows", [])
	if rows.is_empty():
		_list.add_child(_hand(String(vm.get("empty", "")), "lapiz", 0.9))
	for row in rows:
		_list.add_child(_row(row))
	# notas sin pregunta conocida, al pie
	var extra: Array = vm.get("extra", [])
	if not extra.is_empty():
		_list.add_child(Widgets.rule())
		var mv := VBoxContainer.new()
		mv.add_theme_constant_override("separation", 6)
		var i := 0
		for n in extra:
			mv.add_child(_blue_label(String(n), 0.9, -1.2 + 0.5 * float(i % 3)))
			i += 1
		_list.add_child(mv)
	if bool(vm.get("nothing", false)):
		_list.add_child(_blue_label(String(vm.get("nada", "")), 1.05, -2.0))
	var sign_row := HBoxContainer.new()
	sign_row.alignment = BoxContainer.ALIGNMENT_END
	var sg := _blue_label(String(vm.get("sign", "")), 1.1, -3.0)
	(sg as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	sign_row.add_child(sg)
	_list.add_child(sign_row)

# Una hoja: la pregunta (letra de Lisle, negra) y, debajo, la tinta o el borrador a lápiz; al margen, lo azul.
func _row(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.name = "Hoja_" + String(row.q)
	h.add_theme_constant_override("separation", 16)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	var q := _hand(String(row.text), "negra", 0.95)
	q.name = "Pregunta"
	body.add_child(q)
	var inked := String(row.state) == "tinta"
	var txt := String(row.ink_text) if inked else Model.draft_summary(sim, row)
	if txt == "":
		txt = "—"
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l: Label = _print(txt, "", 0.9) if inked else _hand(txt, "lapiz", 0.8)
	l.name = "Texto"
	holder.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.resized.connect(func(): holder.custom_minimum_size = Vector2(0, l.size.y))
	body.add_child(holder)
	if bool(row.wrong) and not inked:
		var s := Strike.new()
		s.name = "Tachado"
		s.label = l
		holder.add_child(s)
		s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.resized.connect(s.queue_redraw)
		_blue.append(s)
	h.add_child(body)
	var margin := VBoxContainer.new()
	margin.custom_minimum_size = Vector2(NOTE_W, 0)
	var i := 0
	for n in row.get("notes", [row.note] if String(row.get("note", "")) != "" else []):
		margin.add_child(_blue_label(String(n), 0.82, -2.2 + 0.6 * float(i % 2)))
		i += 1
	h.add_child(margin)
	return h

func start() -> void:
	_done = false
	if fast or not is_inside_tree():
		return
	for b in _blue:
		(b as CanvasItem).modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	for b in _blue:
		tw.tween_property(b, "modulate:a", 1.0, 0.3)
		tw.tween_interval(STAGGER_S)

# Textos azules visibles (tests).
func notes() -> Array:
	var out: Array = []
	for b in _blue:
		if b is Label:
			out.append(String((b as Label).text))
	return out

func _on_close() -> void:
	if _done:
		return
	_done = true
	finished.emit()

# Cerrar desde afuera (EpilogueScreen.back(): Esc / clic derecho; Intro). true si cerró.
func close_book() -> bool:
	if _done:
		return false
	_on_close()
	return true

# Rect del botón «Cerrar el libro» en pantalla (tests: siempre a la vista).
func close_rect() -> Rect2:
	return _close.get_global_rect() if _close != null else Rect2()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		close_book()

func _unhandled_input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or _done:
		return
	if ev.is_action_pressed("ui_accept") and not ev.is_echo():
		get_viewport().set_input_as_handled()
		close_book()
