# ui/desk/desk_hud.gd — el único HUD (GDD§14.1, ARCHITECTURE §6.1): calendario de escritorio (fecha y franja) y monedas.
# Dueño: W3-SHELL. Control en la capa 10. refresh(q_clock) actualiza; clic en el calendario -> calendar_pressed (cerrar
# la franja, dormir, volver de una visita: lo decide GameScreen con confirmación en dos pasos). Sin contadores.
# Bajo las monedas, las cintas de los dos libros que Lisle lleva siempre (Cuaderno, Libro mayor): el acceso con el
# mouse cuando el escritorio no está a la vista (visitas, escenas, la lámina del prólogo); Tab y L hacen lo mismo.
# book_pressed(kind) con kind "notebook" | "ledger". Soltar un recorte sobre la cinta «Libro mayor» (libro cerrado) abre
# un folio con él: folio_dropped(data) (GDD§8.3, ARCHITECTURE §6.3).
# set_covered(on): un panel acoplado tapa la esquina (cuaderno a la izquierda, «Preguntar» de una escena): la columna se
# desvanece entera y no come el mouse, en vez de asomarse entre las pestañas.
# v2 (GDD_v2 §C.3): las monedas dejan el HUD (quedan sobre la mesa, con su cuenta en el examen); cada cinta aparece con
# su bandera (set_flags: hud.cuaderno, hud.libro); bajo el calendario, la tira «Pendientes» de Lisle (set_guide: ≤3
# líneas de Game.sim.q_guide(), sin marcas de hecho ni progreso; no es recortable).
extends Control

signal calendar_pressed
signal book_pressed(kind: String)
signal folio_dropped(data: Dictionary)

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

var card: PanelContainer
var wd_label: Label
var day_label: Label
var month_label: Label
var slot_label: Label
var coins_label: Label
var coins_box: Control
var books_box: HBoxContainer
var guide_box: PanelContainer
var guide_v: VBoxContainer
var _flags := {}
var _guide: Array = []
var col: VBoxContainer
var covered := false
var _clock := {}
var _cover_tw: Tween = null

func _init() -> void:
	name = "DeskHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	col = VBoxContainer.new()
	col.name = "Columna"
	col.position = Vector2(22, 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	card = PanelContainer.new()
	card.name = "Calendar"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = Vector2(132, 0)
	Widgets.restyle(card, _style_card)
	col.add_child(card)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	wd_label = _lab("SourceLine", HORIZONTAL_ALIGNMENT_CENTER)
	wd_label.uppercase = true
	v.add_child(wd_label)
	day_label = _lab("Heading", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(day_label)
	month_label = _lab("Caption", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(month_label)
	var r := Widgets.rule()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r)
	slot_label = _lab("SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(slot_label)
	# monedas: una tirita de papel bajo el calendario (legible sobre cualquier fondo del grabado)
	coins_box = PanelContainer.new()
	coins_box.name = "Coins"
	coins_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Widgets.restyle(coins_box, func():
		var sb := Paper.style("carta", {"margin": 6, "shadow": true, "shadow_size": 3})
		sb.content_margin_left = 8
		sb.content_margin_right = 10
		coins_box.add_theme_stylebox_override("panel", sb))
	col.add_child(coins_box)
	coins_box.visible = false   # v2: las monedas están sobre la mesa
	var crow := HBoxContainer.new()
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_theme_constant_override("separation", 6)
	coins_box.add_child(crow)
	var glyph := Coins.new()
	crow.add_child(glyph)
	coins_label = _lab("SmallLabel", HORIZONTAL_ALIGNMENT_LEFT)
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(coins_label)
	books_box = HBoxContainer.new()
	books_box.name = "Books"
	books_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	books_box.add_theme_constant_override("separation", 6)
	col.add_child(books_box)
	books_box.add_child(_ribbon("notebook", Widgets.t("shell.hud.cuaderno"), "Tab"))
	books_box.add_child(_ribbon("ledger", Widgets.t("shell.hud.libro"), "L"))
	# playtest v2: el plano (en la pared de atrás) no se descubría el día 1; su cinta, con la tecla M, desde que existe
	books_box.add_child(_ribbon("map", Widgets.t("cam.hud.plano"), "M"))
	guide_box = PanelContainer.new()
	guide_box.name = "Pendientes"
	# STOP: es interfaz. Transparente al mouse, leerla (está dentro de la banda izquierda del borde) giraba la vista y
	# realzaba lo que hay detrás en el 3D (§E.2: nunca gira sobre un control)
	guide_box.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	guide_box.custom_minimum_size = Vector2(132, 0)
	Widgets.restyle(guide_box, func():
		var sb := Paper.style("cuaderno", {"margin": 6, "shadow": true, "shadow_size": 3})
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		guide_box.add_theme_stylebox_override("panel", sb))
	guide_v = VBoxContainer.new()
	guide_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_v.add_theme_constant_override("separation", 4)
	guide_box.add_child(guide_v)
	guide_box.visible = false
	guide_box.mouse_entered.connect(func():
		_hovering_guide = true
		_set_folded(false))
	guide_box.mouse_exited.connect(func():
		_hovering_guide = false
		_fold_t = 0.6)
	col.add_child(guide_box)
	col.move_child(guide_box, 1)
	_apply_flags()
	_apply_guide()
	card.gui_input.connect(_on_card_input)
	card.mouse_entered.connect(func(): card.modulate = Color(1, 1, 1, 1))
	card.mouse_exited.connect(func(): card.modulate = Color(1, 1, 1, 0.94))
	card.modulate = Color(1, 1, 1, 0.94)
	if not _clock.is_empty():
		refresh(_clock)

# Cinta de un libro: tirita de papel con el nombre en versalita; tenue hasta que pasa el mouse.
func _ribbon(kind: String, text: String, key: String) -> Control:
	var p := PanelContainer.new()
	p.name = "Book_" + kind
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.tooltip_text = key
	Widgets.restyle(p, func():
		var sb := Paper.style("cuaderno" if kind == "notebook" else ("carta" if kind == "map" else "libro_mayor"), {"margin": 5, "shadow": true, "shadow_size": 3})
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.border_width_left = 4
		sb.border_color = Paper.ink("roja") if kind == "ledger" and not Paper.hc_on() else Paper.ink("negra")
		p.add_theme_stylebox_override("panel", sb))
	var l := _lab("SourceLine", HORIZONTAL_ALIGNMENT_CENTER)
	l.text = text
	p.add_child(l)
	p.modulate = Color(1, 1, 1, 0.82)
	p.mouse_entered.connect(func(): p.modulate = Color(1, 1, 1, 1))
	p.mouse_exited.connect(func(): p.modulate = Color(1, 1, 1, 0.82))
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			p.accept_event()
			book_pressed.emit(kind))
	if kind == "ledger":
		p.set_drag_forwarding(Callable(),
			func(_at, d): return not covered and typeof(d) == TYPE_DICTIONARY and String(d.get("kind", "")) == "clip" and String(d.get("id", "")) != "",
			func(_at, d): folio_dropped.emit(d))
	return p

# Banderas de revelado (Game.sim.q_ui()): cada cinta aparece cuando su libro existe para Lisle.
func set_flags(f: Dictionary) -> void:
	_flags = f.duplicate()
	_apply_flags()

func _apply_flags() -> void:
	if books_box == null:
		return
	var nb := ribbon("notebook")
	var lg := ribbon("ledger")
	var mp := ribbon("map")
	if nb != null:
		nb.visible = bool(_flags.get("hud.cuaderno", true))
	if lg != null:
		lg.visible = bool(_flags.get("hud.libro", true))
	if mp != null:
		# sólo en el escritorio (es para salir): en visitas y escenas no suma nada
		mp.visible = bool(_flags.get("desk.mapa", true)) and String(_clock.get("phase", "desk")) == "desk"
	books_box.visible = (nb != null and nb.visible) or (lg != null and lg.visible) or (mp != null and mp.visible)

# Tira «Pendientes»: textos ya resueltos (≤3). Vacía → no se ve.
func set_guide(lines: Array) -> void:
	var nl := lines.slice(0, 3)
	var changed := nl != _guide
	_guide = nl
	_apply_guide()
	if changed:
		_unfold(FOLD_S)

const FOLD_S := 4.0
var folded := false
var _fold_t := 0.0
var _hovering_guide := false

# Desplegada: todas las líneas; plegada: sólo la primera (la más urgente) y «…» si hay más (GDD_v2 §B.6.2).
func _set_folded(on: bool) -> void:
	folded = on
	if guide_v == null:
		return
	var i := 0
	for ch in guide_v.get_children():
		if ch.name == "Mas":
			(ch as Control).visible = on and _guide.size() > 1
		elif String(ch.name).begins_with("Linea"):
			(ch as Control).visible = not on or i == 0
			i += 1

func _unfold(secs: float) -> void:
	_set_folded(false)
	_fold_t = secs

func _process(dt: float) -> void:
	if _fold_t > 0.0 and not _hovering_guide:
		_fold_t -= dt
		if _fold_t <= 0.0:
			_set_folded(true)

func guide_lines() -> Array:
	return _guide.duplicate()

func _apply_guide() -> void:
	if guide_v == null:
		return
	for ch in guide_v.get_children():
		guide_v.remove_child(ch)
		ch.queue_free()
	var head := Widgets.label(Widgets.t("cam.pendientes"), "SourceLine")
	head.uppercase = true
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_v.add_child(head)
	var n := 0
	for t in _guide:
		# viñeta y aire entre líneas: no se pegan entre sí (playtest v2)
		var l := Widgets.label("· " + String(t), "SmallLabel")
		l.name = "Linea%d" % n
		n += 1
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(210, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide_v.add_child(l)
	var more := Widgets.label("…", "SmallLabel")
	more.name = "Mas"
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	more.visible = false
	guide_v.add_child(more)
	guide_box.visible = not _guide.is_empty()
	_set_folded(folded)

func ribbon(kind: String) -> Control:
	return books_box.get_node_or_null("Book_" + kind) if books_box != null else null

func _lab(variation: String, al: int) -> Label:
	var l := Widgets.label("", variation)
	l.horizontal_alignment = al
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _style_card() -> void:
	var sb := Paper.style("carta", {"margin": 10, "shadow": true})
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	sb.border_width_top = 6
	sb.border_color = Paper.ink("roja") if not Paper.hc_on() else Paper.ink("negra")
	card.add_theme_stylebox_override("panel", sb)

func _on_card_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		card.accept_event()
		calendar_pressed.emit()

# Rectángulo (canvas) de la columna: calendario, monedas y cintas.
func cover_rect() -> Rect2:
	return col.get_global_rect() if col != null and col.is_inside_tree() else Rect2()

func set_covered(on: bool) -> void:
	if on == covered or col == null:
		return
	covered = on
	var mf := Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	card.mouse_filter = mf
	if guide_box != null:
		guide_box.mouse_filter = mf
	for c in books_box.get_children():
		(c as Control).mouse_filter = mf
	if _cover_tw != null and _cover_tw.is_valid():
		_cover_tw.kill()
	if not is_inside_tree():
		col.modulate.a = 0.0 if on else 1.0
		return
	_cover_tw = col.create_tween()
	_cover_tw.tween_property(col, "modulate:a", 0.0 if on else 1.0, 0.15)

# clock = Game.sim.q_clock() (+ date, weekday de schedule). Fecha de época: «martes / 27 / de marzo».
func refresh(clock: Dictionary, info := {}) -> void:
	_clock = clock.duplicate()
	if card == null:
		return
	_apply_flags()
	var date := String(info.get("date", ""))
	var wd := String(info.get("weekday", clock.get("weekday", "")))
	wd_label.text = Widgets.t("core.wd." + wd) if wd != "" else ""
	if date.length() >= 10:
		day_label.text = str(date.substr(8, 2).to_int())
		month_label.text = Widgets.t("shell.hud.mes", {"mes": Widgets.t("core.mes." + str(date.substr(5, 2).to_int())), "a": date.substr(0, 4)})
	else:
		day_label.text = ""
		month_label.text = String(clock.get("date_label", ""))
	var slot := String(clock.get("slot", ""))
	var ph := String(clock.get("phase", ""))
	var sl := Widgets.t("core.slot." + slot) if slot != "" else ""
	var hrs := Widgets.t("core.slot_horas." + slot)
	if ph == "night" or ph == "night_choice":
		sl = Widgets.t("core.slot.night")   # «noche, 22 h»: ya trae la hora
		hrs = ""
	slot_label.text = sl if hrs == "" or hrs.begins_with("core.") else Widgets.t("shell.hud.franja", {"franja": sl, "horas": hrs})
	coins_label.text = money(int(clock.get("coins_d", 0)))

# Peniques -> «£1 1s. 6d.» (sin componentes en cero salvo todo cero).
static func money(d: int) -> String:
	var l := int(d / 240)
	var s := int((d % 240) / 12)
	var p := d % 12
	var parts: Array = []
	if l > 0:
		parts.append(Widgets.t("shell.money.l", {"n": l}))
	if s > 0:
		parts.append(Widgets.t("shell.money.s", {"n": s}))
	if p > 0 or parts.is_empty():
		parts.append(Widgets.t("shell.money.d", {"n": p}))
	return " ".join(parts)

# Pila de monedas dibujada (sin imágenes).
class Coins extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(26, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Paper.ink("negra")
		var gold := Color("b8963f") if not Paper.hc_on() else Color(1, 1, 1)
		for i in 3:
			var c := Vector2(9 + i * 5, 12 - i * 2)
			draw_circle(c, 6.5, gold)
			draw_arc(c, 6.5, 0, TAU, 20, ink, 1.0, true)
			draw_arc(c, 4.2, 0, TAU, 16, Color(ink, 0.45), 0.8, true)
