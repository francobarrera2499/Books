# ui/desk/speech.gd — líneas dichas en la escena (fixed scenes, líneas automáticas de un lugar, respuestas) cuando el
# panel de escena de W3-SCENEUI no las muestra, y nota del instructor del prólogo (pinned). Dueño: W3-SHELL.
# Cada línea: quién la dice (nombre sólo si se presentó: lo resuelve q_scene) y el texto, recortable con la tijera
# (src {kind:"line", ref:uid}). Cola: clic en la tarjeta o en «›» pasa a la siguiente. Sin brillos ni contadores.
# push_lines([{uid, who_label, parsed}]) · clear() · set_scissors(on) · showing() -> bool · señal clipped(result).
extends PanelContainer

signal clipped(result: Dictionary)
signal emptied

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const ClipLabel = preload("res://ui/desk/clip_label.gd")

var pinned := false
var max_w := 660.0
var queue: Array = []
var current := {}
var who_label: Label
var text: RichTextLabel
var more: Button
var _scissors := false
var bottom_inset := 0.0:
	set(v):
		bottom_inset = v
		if visible and is_inside_tree():
			_place()

func _init(p_pinned := false) -> void:
	pinned = p_pinned
	name = "Tutor" if pinned else "Speech"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if pinned:
		max_w = 360.0
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("cuaderno" if pinned else "carta", {"margin": 16 if pinned else 22, "shadow": true, "shadow_size": 6 if pinned else 10})))

func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	who_label = Widgets.label("", "SourceLine")
	who_label.uppercase = true
	who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(who_label)
	more = Widgets.ink_button("›", advance)
	more.visible = false
	top.add_child(more)
	text = ClipLabel.new()
	text.custom_minimum_size = Vector2(max_w - 44.0, 0)
	text.clipped.connect(func(r): clipped.emit(r))
	v.add_child(text)
	gui_input.connect(_on_input)
	get_viewport().size_changed.connect(_place)

func _on_input(ev: InputEvent) -> void:
	if pinned or _scissors:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		accept_event()
		advance()

func showing() -> bool:
	return visible

func push_lines(lines: Array) -> void:
	if pinned:
		if lines.is_empty():
			return
		current = lines[-1]
		_show_current()
		return
	queue.append_array(lines)
	if not visible or current.is_empty():
		advance()
	else:
		more.visible = not queue.is_empty()

func advance() -> void:
	if queue.is_empty():
		current = {}
		visible = false
		emptied.emit()
		return
	current = queue.pop_front()
	_show_current()

func clear() -> void:
	queue.clear()
	current = {}
	visible = false

func _show_current() -> void:
	who_label.text = String(current.get("who_label", ""))
	who_label.visible = who_label.text != ""
	var src := {"kind": "line", "ref": String(current.get("uid", ""))} if String(current.get("uid", "")) != "" else {}
	(text as ClipLabel).setup(current.get("parsed", {}), src, "imprenta", 0)
	(text as ClipLabel).set_scissors(_scissors)
	more.visible = not pinned and not queue.is_empty()
	visible = true
	modulate.a = 0.0
	Widgets.fade(self, 1.0, 0.2)
	_place.call_deferred()

func set_scissors(on: bool) -> void:
	_scissors = on
	if text != null:
		(text as ClipLabel).set_scissors(on)

func _place() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	reset_size()
	if pinned:
		size.x = minf(max_w, vs.x * 0.3)
		position = Vector2(22, 230)
	else:
		size.x = minf(max_w, vs.x - 80.0)
		position = Vector2((vs.x - size.x) * 0.5, vs.y - size.y - 34.0 - bottom_inset)
