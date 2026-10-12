# ui/reader/ruler.gd — regla de boj en milímetros. Dueño: W2-READER. Contrato: ARCHITECTURE §6.4 (GDD§14.3, §9.9).
# Una regla (horizontal o vertical) apoyada contra el borde de la hoja, con el 0 en la esquina superior izquierda del
# papel. Vive dentro del escenario del lector, al lado de PageView, con la misma px_per_mm: el zoom (Control.scale del
# escenario) la escala igual que al papel, así que mide lo mismo a cualquier zoom. Marcas: mm, medio centímetro y cm
# (con su número). Se arrastra sobre su eje perpendicular para medir otra cosa (doble clic: vuelve al borde).
# setup(px_per_mm, paper_mm: Vector2, vertical: bool). Sin texto de interfaz; los números son marcas de la regla.
extends Control

const Paper = preload("res://ui/kit/paper.gd")

const WIDTH_MM := 15.0
const LEAD_MM := 6.0          # regla que sobra antes del 0
const TAIL_MM := 4.0          # regla que sobra después de la última marca (para que su número no quede cortado)
const WOOD := Color("e2cd98")
const WOOD_DARK := Color("c9ae72")
const TICK := Color("2a2016")

var px_per_mm := 3.0
var paper_mm := Vector2(178, 229)
var vertical := false
var length_mm := 200.0
var slide := 0.0              # desplazamiento perpendicular (mm) desde el borde
var _drag := false
var _drag_from := 0.0
var _slide_from := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE

func setup(p_px_per_mm: float, p_paper_mm: Vector2, p_vertical: bool) -> void:
	px_per_mm = p_px_per_mm
	paper_mm = p_paper_mm
	vertical = p_vertical
	var span := paper_mm.y if vertical else paper_mm.x
	length_mm = ceilf((span + 12.0) / 10.0) * 10.0 + LEAD_MM + TAIL_MM
	_place()

func _place() -> void:
	var p := px_per_mm
	if vertical:
		size = Vector2(WIDTH_MM, length_mm) * p
		position = Vector2(-WIDTH_MM + slide, -LEAD_MM) * p
	else:
		size = Vector2(length_mm, WIDTH_MM) * p
		position = Vector2(-LEAD_MM, -WIDTH_MM + slide) * p
	custom_minimum_size = size
	queue_redraw()

func reset() -> void:
	slide = 0.0
	_place()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.double_click:
			reset()
		elif ev.pressed:
			_drag = true
			var gp: Vector2 = get_parent_control().get_local_mouse_position() if get_parent_control() != null else ev.position
			_drag_from = gp.x if vertical else gp.y
			_slide_from = slide
		else:
			_drag = false
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		var gp2: Vector2 = get_parent_control().get_local_mouse_position() if get_parent_control() != null else ev.position
		var d := ((gp2.x if vertical else gp2.y) - _drag_from) / px_per_mm
		var lim := (paper_mm.x if vertical else paper_mm.y) + WIDTH_MM
		slide = clampf(_slide_from + d, -20.0, lim)
		_place()
		accept_event()

func _draw() -> void:
	var p := px_per_mm
	var hc := Paper.hc_on()
	var body := Color(1, 1, 1) if hc else WOOD
	var ink := Color(0, 0, 0) if hc else TICK
	var r := Rect2(Vector2.ZERO, size)
	if not hc:
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.28))
	draw_rect(r, body)
	if not hc:
		# veta de la madera: líneas suaves a lo largo de la regla
		var n := 7
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var c := Color(WOOD_DARK, 0.18 + 0.1 * float(k % 2))
			if vertical:
				draw_line(Vector2(size.x * t, 0), Vector2(size.x * t + 1.5, size.y), c, 1.0)
			else:
				draw_line(Vector2(0, size.y * t), Vector2(size.x, size.y * t + 1.5), c, 1.0)
		var bev := Color(1, 1, 1, 0.35)
		draw_line(Vector2(0, 0), Vector2(size.x, 0), bev, 1.0)
		draw_line(Vector2(0, 0), Vector2(0, size.y), bev, 1.0)
	draw_rect(r, Color(ink, 0.8), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	var ti = Paper._ti()
	if ti != null:
		font = ti.font("imprenta")
	var fs := maxi(7, int(round(3.5 * p)))
	var mm := 0
	var span := int(length_mm - LEAD_MM - TAIL_MM)
	var lw := maxf(1.0, 0.16 * p)
	while mm <= span:
		var t := (float(mm) + LEAD_MM) * p
		var tl := 2.2
		if mm % 10 == 0:
			tl = 5.2
		elif mm % 5 == 0:
			tl = 3.5
		var a: Vector2
		var b: Vector2
		if vertical:
			# marcas desde el borde derecho (el que toca el papel) hacia la izquierda
			a = Vector2(size.x, t)
			b = Vector2(size.x - tl * p, t)
		else:
			a = Vector2(t, size.y)
			b = Vector2(t, size.y - tl * p)
		draw_line(a, b, ink, lw if mm % 10 != 0 else lw * 1.4)
		if mm % 10 == 0 and mm > 0:
			var label := str(mm / 10)
			var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			if vertical:
				var pos := Vector2(size.x - 6.0 * p - ts.x, t + ts.y * 0.32)
				draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			else:
				var pos2 := Vector2(t - ts.x * 0.5, size.y - 6.1 * p)
				draw_string(font, pos2, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		mm += 1
