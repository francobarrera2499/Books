# ui/scene/lisle_note.gd — nota de Lisle a lápiz (errores de forma y avisos) que aparece y se desvanece. Dueño: W3-SCENEUI.
# Uso: var n = LisleNote.new(); parent.add_child(n); n.say("Un aviso por día.")
# Papel chico con letra manuscrita (variación Marginal). 0,25 s de entrada, HOLD_S a la vista, 0,4 s de salida (§6.1).
# No es un tooltip ni una alerta: sin sonido, sin color de alarma. text() devuelve lo último dicho (tests).
extends PanelContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

const HOLD_S := 3.4

var _label: Label
var _tw: Tween = null
var _last := ""

func _init() -> void:
	name = "NotaLisle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 16, "margin_v": 8, "radius": 2, "shadow_size": 6, "shadow_y": 2})))
	_label = Widgets.marginal("")
	_label.custom_minimum_size = Vector2(280, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func say(text: String) -> void:
	if text == "":
		return
	_last = text
	_label.text = text
	visible = true
	reset_size()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, 0.25)
	_tw.tween_interval(HOLD_S)
	_tw.tween_property(self, "modulate:a", 0.0, 0.4)
	_tw.tween_callback(func(): visible = false)

func hide_now() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 0.0
	visible = false

func text() -> String:
	return _last
