# ui/desk/dawn.gd — ritual del amanecer (GDD§7.1, ARCHITECTURE §2.3). Dueño: W3-SHELL. Control en la capa de fundido.
# Tras sleep (el director ya resolvió dentro de apply): tarjeta con la fecha sobre la tinta del fundido, las campanas de
# St Clement Danes, el lechero y el golpe de Crane (Audio.play_event "dawn"; el domingo sin persiana: "dawn_domingo"),
# con sus subtítulos. Ninguna alerta: lo que haya llegado está en la bandeja. Clic o tecla: saltar.
# play(info) es corrutina: info = {label, slot_label, sunday, fast, sounds}. skip() lo corta.
extends Control

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

const HOLD_MIN := 2.2
const HOLD_MAX := 4.6

var shell = null
var _skip := false
var _card: VBoxContainer
var _date: Label
var _slot: Label
var _sounds: VBoxContainer

func _init() -> void:
	name = "Dawn"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0

func _ready() -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 6)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_card)
	_date = Widgets.heading("")
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_date)
	_slot = Widgets.label("", "Caption")
	_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_slot)
	# lo que se oye (subtítulos del ritual): la capa de subtítulos queda debajo del fundido
	_sounds = VBoxContainer.new()
	_sounds.alignment = BoxContainer.ALIGNMENT_BEGIN
	_sounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sounds.custom_minimum_size = Vector2(0, 76)
	_sounds.add_theme_constant_override("separation", 2)
	_card.add_child(_sounds)
	Widgets.restyle(_date, func(): _date.add_theme_color_override("font_color", Paper.paper("cuaderno")))
	Widgets.restyle(_slot, func(): _slot.add_theme_color_override("font_color", Color(Paper.paper("cuaderno"), 0.75)))

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_skip = true
		accept_event()

# Una tecla también salta (las teclas no llegan a _gui_input sin foco). Sólo mientras dura el ritual.
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.is_echo() and is_visible_in_tree():
		_skip = true
		get_viewport().set_input_as_handled()

func skip() -> void:
	_skip = true

func play(info: Dictionary) -> void:
	_skip = false
	_date.text = String(info.get("label", ""))
	_slot.text = String(info.get("slot_label", ""))
	var fast := bool(info.get("fast", false))
	if fast:
		modulate.a = 1.0
		await get_tree().process_frame
		modulate.a = 0.0
		return
	var dur := 0.0
	var au = get_tree().root.get_node_or_null("Audio")
	if au != null and au.has_signal("subtitle") and not au.subtitle.is_connected(_on_sound):
		au.subtitle.connect(_on_sound)
	if bool(info.get("sounds", true)) and shell != null:
		dur = float(shell.play_event("dawn_domingo" if bool(info.get("sunday", false)) else "dawn"))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	await tw.finished
	var hold := clampf(dur * 0.8, HOLD_MIN, HOLD_MAX)
	var t := 0.0
	while t < hold and not _skip and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw2.finished
	if au != null and au.subtitle.is_connected(_on_sound):
		au.subtitle.disconnect(_on_sound)

func _on_sound(text: String, _seconds: float) -> void:
	if _sounds == null or text == "":
		return
	for c in _sounds.get_children():
		if c is Label and (c as Label).text == text:
			return
	var l := Widgets.label(text, "Caption")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(l, func(): l.add_theme_color_override("font_color", Color(Paper.paper("cuaderno"), 0.6)))
	l.modulate.a = 0.0
	_sounds.add_child(l)
	while _sounds.get_child_count() > 3:
		var old := _sounds.get_child(0)
		_sounds.remove_child(old)
		old.queue_free()
	create_tween().tween_property(l, "modulate:a", 1.0, 0.4)

func sounds_shown() -> Array:
	return _sounds.get_children().map(func(c): return (c as Label).text) if _sounds != null else []
