# ui/reader/lens.gd — lupa de 3× (GDD§14.3: comparar tipos). Dueño: W2-READER. Contrato: ARCHITECTURE §6.4.
# NO amplía la textura de la pantalla: arma una SEGUNDA hoja (PageView no interactiva) con el mismo builder y la misma
# px_per_mm que la hoja visible (mismos cortes de línea), y la escala a MAG × zoom con Control.scale (MSDF: nítida a
# cualquier escala). Un disco recortado (clip_children) sigue al mouse; el punto bajo el mouse queda en el centro.
# La copia también lleva la Remington y la luz rasante (la lámpara está en el mouse = centro de la lupa).
# setup(view, page_idx, px_per_mm, source_page) · follow(canvas_pos, zoom) · clear(). mouse_filter = IGNORE.
extends Control

const Paper = preload("res://ui/kit/paper.gd")
const PageView = preload("res://ui/reader/page_view.gd")

const MAG := 3.0
const RADIUS := 128.0

var source: Control = null       # PageView visible
var copy: Control = null         # PageView de la lupa
var _mask: Control
var _content: Control
var _rim: Control
var _zoom := 1.0

class Disc extends Control:
	var radius := 128.0
	func _draw() -> void:
		var hc := Paper.hc_on()
		draw_circle(Vector2(radius, radius), radius, Color(1, 1, 1) if hc else Paper.MESA.lightened(0.08))

class Rim extends Control:
	var radius := 128.0
	func _draw() -> void:
		var hc := Paper.hc_on()
		var c := Vector2(radius, radius)
		if hc:
			draw_arc(c, radius + 3.0, 0.0, TAU, 96, Color(0, 0, 0), 6.0, true)
			return
		var brass := Color("9a7a3c")
		draw_arc(c, radius + 9.0, 0.0, TAU, 96, Color(0, 0, 0, 0.18), 6.0, true)
		draw_arc(c, radius + 4.0, 0.0, TAU, 96, brass.darkened(0.35), 9.0, true)
		draw_arc(c, radius + 3.0, 0.0, TAU, 96, brass, 5.0, true)
		draw_arc(c, radius + 1.5, PI * 1.05, PI * 1.55, 32, Color(1, 0.95, 0.75, 0.55), 2.0, true)
		# reflejo del vidrio
		draw_arc(c, radius * 0.82, PI * 1.12, PI * 1.38, 24, Color(1, 1, 1, 0.16), radius * 0.07, true)
		# mango
		var d := Vector2(0.72, 0.69).normalized()
		var a := c + d * (radius + 8.0)
		var b := c + d * (radius + 92.0)
		draw_line(a + Vector2(2, 3), b + Vector2(2, 3), Color(0, 0, 0, 0.25), 17.0, true)
		draw_line(a, a + d * 14.0, brass.darkened(0.2), 13.0, true)
		draw_line(a + d * 14.0, b, Color("3b2416"), 15.0, true)
		draw_line(a + d * 16.0, b - d * 2.0, Color("5a3a24"), 6.0, true)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask = Disc.new()
	_mask.radius = RADIUS
	_mask.size = Vector2(RADIUS, RADIUS) * 2.0
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_content)
	_rim = Rim.new()
	_rim.radius = RADIUS
	_rim.size = Vector2(RADIUS, RADIUS) * 2.0
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rim)
	visible = false

func setup(view: Dictionary, page_idx: int, px_per_mm: float, source_page: Control) -> void:
	clear()
	source = source_page
	copy = PageView.new()
	copy.name = "LupaHoja"
	_content.add_child(copy)
	copy.setup(view, page_idx, {"px_per_mm": px_per_mm, "interactive": false})

func clear() -> void:
	if copy != null:
		copy.queue_free()
	copy = null
	source = null

func follow(canvas_pos: Vector2, zoom: float) -> void:
	_zoom = zoom
	if copy == null or source == null:
		return
	var local: Vector2 = source.get_global_transform().affine_inverse() * canvas_pos
	var s := MAG * zoom
	var top_left := canvas_pos - Vector2(RADIUS, RADIUS)
	_mask.position = top_left
	_rim.position = top_left
	_content.scale = Vector2(s, s)
	_content.position = Vector2(RADIUS, RADIUS) - local * s
	copy.set_light(canvas_pos, zoom * MAG)
	_mask.queue_redraw()
	_rim.queue_redraw()
