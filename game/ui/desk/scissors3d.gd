# ui/desk/scissors3d.gd — tijera sobre el diorama: rectángulo de recorte (GDD§8.1, ARCHITECTURE §5.1, §7.6). Dueño: W3-SHELL.
# Control a pantalla completa en la capa del HUD (debajo de todo panel). Activo: el mouse dibuja un rectángulo a lápiz;
# el área se limita a 1/8 del viewport (la UI no deja crecer más; el sim valida igual) -> rect_done(rect) al soltar.
# Un rectángulo mínimo (< 10 px) no recorta. Clic derecho / Esc los maneja la Shell (dejar la tijera).
extends Control

signal rect_done(rect: Rect2)

const Paper = preload("res://ui/kit/paper.gd")
const Reader = preload("res://ui/reader/document_reader.gd")

const MAX_FRAC := 1.0 / 8.0
const MIN_PX := 10.0

var active := false
var _dragging := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _cursor_set := false

func _init() -> void:
	name = "Scissors3D"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_active(on: bool) -> void:
	active = on
	visible = on
	_dragging = false
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_cursor(on)
	queue_redraw()

func _exit_tree() -> void:
	_cursor(false)

func _cursor(on: bool) -> void:
	if on and not _cursor_set:
		Input.set_custom_mouse_cursor(Reader.scissors_texture(), Input.CURSOR_ARROW, Vector2(4, 4))
		_cursor_set = true
	elif not on and _cursor_set:
		Input.set_custom_mouse_cursor(null)
		_cursor_set = false

func current_rect() -> Rect2:
	return Rect2(_from, _to - _from).abs()

static func clamp_rect(from: Vector2, to: Vector2, vp: Vector2) -> Rect2:
	var r := Rect2(from, to - from).abs()
	var max_area := vp.x * vp.y * MAX_FRAC
	var area := r.size.x * r.size.y
	if area > max_area and area > 0.0:
		var k := sqrt(max_area / area)
		var sz := r.size * k
		var dir := (to - from).sign()
		if dir.x == 0.0:
			dir.x = 1.0
		if dir.y == 0.0:
			dir.y = 1.0
		var end := from + sz * dir
		r = Rect2(from, end - from).abs()
	return r

func _gui_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dragging = true
			_from = ev.position
			_to = ev.position
		elif _dragging:
			_dragging = false
			var r := clamp_rect(_from, _to, size)
			queue_redraw()
			accept_event()
			if r.size.x >= MIN_PX and r.size.y >= MIN_PX:
				rect_done.emit(Rect2(r.position + global_position, r.size))
			return
		accept_event()
		queue_redraw()
	elif ev is InputEventMouseMotion and _dragging:
		_to = ev.position
		var r := clamp_rect(_from, _to, size)
		_to = _from + (r.size * (_to - _from).sign())
		accept_event()
		queue_redraw()

func _draw() -> void:
	if not active:
		return
	# marco de corte tenue en el borde: la tijera está en la mano (además del cursor)
	var fr := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	var dim := Color(Paper.paper("cuaderno"), 0.55)
	_rect_dashed(fr, dim, 1.2)
	if not _dragging:
		return
	var r := Rect2(_from, _to - _from).abs()
	# lo que queda fuera del corte se vela (se lee qué entra en la tira sobre cualquier grabado)
	var veil := Color(Paper.ink("negra"), 0.28)
	draw_rect(Rect2(0, 0, size.x, r.position.y), veil)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), veil)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), veil)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), veil)
	draw_rect(r, Color(Paper.paper("cuaderno"), 0.9), false, 3.0)
	_rect_dashed(r, Paper.ink("negra"), 1.6)

func _rect_dashed(r: Rect2, c: Color, w: float) -> void:
	_dashed(r.position, Vector2(r.end.x, r.position.y), c, w)
	_dashed(Vector2(r.end.x, r.position.y), r.end, c, w)
	_dashed(r.end, Vector2(r.position.x, r.end.y), c, w)
	_dashed(Vector2(r.position.x, r.end.y), r.position, c, w)

func _dashed(a: Vector2, b: Vector2, c: Color, w := 1.6) -> void:
	var l := a.distance_to(b)
	if l <= 0.0:
		return
	var d := (b - a) / l
	var t := 0.0
	while t < l:
		draw_line(a + d * t, a + d * minf(t + 7.0, l), c, w)
		t += 12.0
