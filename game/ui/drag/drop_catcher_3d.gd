# ui/drag/drop_catcher_3d.gd — capa 5: recibe lo que se suelta sobre el 3D (presentar). Dueño: W3-SHELL. §6.3, GDD§14.4.
# Control a pantalla completa por encima del 3D y debajo de todo panel. mouse_filter IGNORE salvo durante un arrastre
# (NOTIFICATION_DRAG_BEGIN) en fase visit/scene/confront: entonces STOP y resuelve el destino 3D con la misma selección
# por proyección que el clic (WorldRoot.pick_character). _drop_data no actúa: emite present_requested(char, data) y
# quien lo hospeda (GameScreen) abre la confirmación en dos pasos (frase de Lisle -> «Mostrar» / «Guardar»).
# Config: world (WorldRoot) · phase_fn (Callable() -> String; por defecto Game.sim.q_clock().phase).
extends Control

signal present_requested(char_id: String, data: Dictionary)

const Chips = preload("res://ui/drag/chips.gd")
const PHASES := ["visit", "scene", "confront"]

var world = null
var phase_fn: Callable = Callable()
var armed := false

func _init() -> void:
	name = "DropCatcher3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _phase() -> String:
	if phase_fn.is_valid():
		return String(phase_fn.call())
	var ml = Engine.get_main_loop()
	var g = ml.root.get_node_or_null("Game") if ml is SceneTree else null
	if g != null and g.get("sim") != null:
		return String(g.sim.q_clock().get("phase", ""))
	return ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var d = get_viewport().gui_get_drag_data()
		armed = world != null and Chips.presentable(d) and PHASES.has(_phase())
		mouse_filter = Control.MOUSE_FILTER_STOP if armed else Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		armed = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func char_at(pos: Vector2) -> String:
	if world == null or not is_instance_valid(world):
		return ""
	return String(world.pick_character(pos))

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not armed or not Chips.presentable(data):
		return false
	return char_at(at_position + global_position) != ""

func _drop_data(at_position: Vector2, data) -> void:
	var cid := char_at(at_position + global_position)
	if cid == "" or not Chips.presentable(data):
		return
	present_requested.emit(cid, (data as Dictionary).duplicate())
