# ui/drag/drag_layer.gd — capa 120: vista previa del chip arrastrado (ARCHITECTURE §2.3, §6.3). Dueño: W3-SHELL.
# El arrastre es el DnD nativo de Godot. La vista previa de set_drag_preview vive en la capa 0 del viewport y quedaría
# debajo de los libros (20) y los modales (60); por eso esta capa dibuja el chip encima de todo mientras dure un arrastre
# cuyos datos son de ui/drag/chips.gd ({"kind","id"}). Si la fuente puso su propia vista previa (set_drag_preview con
# un Widgets.chip: Control top_level con meta "data"), esta capa la ADOPTA (la pasa a la capa 120; el motor la sigue
# moviendo y la libera al soltar): un solo chip, siempre encima. Si no hay vista previa nativa, dibuja Chips.preview.
# API: start(source: Control, data) -> fuerza un arrastre desde código (force_drag) · dragging() -> bool ·
#   current() -> Dictionary · señales started(data), ended(data, dropped).
extends CanvasLayer

signal started(data: Dictionary)
signal ended(data: Dictionary, dropped: bool)

const Layers = preload("res://ui/layers.gd")
const Chips = preload("res://ui/drag/chips.gd")

const OFFSET := Vector2(14, 10)

var _root: Control
var _chip: Control = null
var _data := {}
var _active := false
var _adopted: Control = null

class Watcher extends Control:
	var owner_layer
	func _init(o) -> void:
		owner_layer = o
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			owner_layer._on_drag_begin()
		elif what == NOTIFICATION_DRAG_END:
			owner_layer._on_drag_end()

func _init() -> void:
	layer = Layers.DRAG
	name = "DragLayer"

func _ready() -> void:
	_root = Watcher.new(self)
	_root.name = "Root"
	add_child(_root)
	set_process(false)

func dragging() -> bool:
	return _active

func current() -> Dictionary:
	return _data.duplicate()

func start(source: Control, d: Dictionary) -> void:
	if source == null or not Chips.valid(d):
		return
	source.force_drag(d, Chips.ghost())

func _on_drag_begin() -> void:
	var d = get_viewport().gui_get_drag_data()
	if not Chips.valid(d):
		return
	_data = (d as Dictionary).duplicate()
	_active = true
	if _chip != null:
		_chip.queue_free()
		_chip = null
	_adopted = null
	set_process(true)
	started.emit(_data)
	_adopt.call_deferred()

# Busca la vista previa nativa (la pone set_drag_preview en la capa de la fuente, debajo de libros y modales).
func native_preview() -> Control:
	if not is_inside_tree():
		return null
	for c in get_tree().root.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc.top_level and cc.has_meta("data") and cc.is_visible_in_tree() and not is_ancestor_of(cc) and not cc.is_queued_for_deletion():
			return cc
	return null

func _adopt() -> void:
	if not _active:
		return
	var n := native_preview()
	if n != null:
		n.reparent(_root, true)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_adopted = n
		return
	if _chip == null:
		_chip = Chips.preview(_data)
		_root.add_child(_chip)
		_follow()

func adopted() -> bool:
	return _adopted != null and is_instance_valid(_adopted)

func _on_drag_end() -> void:
	if not _active:
		return
	_active = false
	_adopted = null
	set_process(false)
	if _chip != null:
		_chip.queue_free()
		_chip = null
	var ok := get_viewport().gui_is_drag_successful()
	var d := _data
	_data = {}
	ended.emit(d, ok)

func _process(_dt: float) -> void:
	_follow()

func _follow() -> void:
	if _chip == null:
		return
	_chip.position = _root.get_local_mouse_position() + OFFSET
