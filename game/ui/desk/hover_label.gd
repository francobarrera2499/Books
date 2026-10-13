# ui/desk/hover_label.gd — etiqueta discreta de lo que está bajo el mouse (GDD_v2 §D.2). Dueño: CÁMARA + AFORDANCIAS.
# Tira de papel chica en la capa del HUD, a (18, 22) px del cursor y siempre dentro de la pantalla; aparece a los 0,08 s
# y se va al salir del objeto. Con «mirar alrededor» (show_many): una etiqueta por examinable en el centro proyectado
# de su ancla, con un antisolapamiento simple (se corre hacia abajo). No come el mouse. No es recortable (interfaz).
# API: show_label(text) · hide_label() · show_many([{text, pos}]) · clear_many() · label_text() · many_count().
extends Control

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

const OFFSET := Vector2(18, 22)
const DELAY_S := 0.08
const MARGIN := 6.0

var _single: PanelContainer
var _single_l: Label
var _want := ""
var _wait := 0.0
var _many: Control
var avoid: Array = []         # rectángulos de la interfaz que la etiqueta no tapa (calendario, Pendientes, la banda)
var _last_mouse := Vector2(-1, -1)
const FAST_PX := 6.0          # moviendo rápido el mouse no se ve el nombre de lo que quedó atrás (playtest v2)

func _init() -> void:
	name = "HoverLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	_single = _strip()
	_single.name = "Etiqueta"
	_single_l = _single.get_child(0)
	_single.visible = false
	add_child(_single)
	_many = Control.new()
	_many.name = "Todas"
	_many.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_many.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_many)

func _strip() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(p, func():
		var sb := Paper.style("carta", {"margin": 4, "shadow": true, "shadow_size": 3})
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb))
	var l := Widgets.label("", "SmallLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func show_label(text: String) -> void:
	if text == "":
		hide_label()
		return
	if text == _want and (_single.visible or _wait > 0.0):
		return
	_want = text
	_single_l.text = text
	_single.reset_size()
	if _single.visible:
		_follow()
		return
	_wait = DELAY_S

func hide_label() -> void:
	_want = ""
	_wait = 0.0
	if _single != null:
		_single.visible = false

func label_text() -> String:
	return _single_l.text if _single != null and _single.visible else ""

func set_avoid(rects: Array) -> void:
	avoid = rects

func _hits_avoid(r: Rect2) -> Rect2:
	for a in avoid:
		if a is Rect2 and (a as Rect2).grow(2.0).intersects(r):
			return a
	return Rect2()

func _process(dt: float) -> void:
	var mp := get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
	var fast := _last_mouse.x >= 0.0 and mp.distance_to(_last_mouse) > FAST_PX
	_last_mouse = mp
	if _want == "":
		return
	if fast:
		# se rearma: aparece cuando el mouse se apoya (0,08 s) sobre lo que nombra
		if _single.visible:
			_single.visible = false
		_wait = DELAY_S
		return
	if _wait > 0.0:
		_wait -= dt
		if _wait > 0.0:
			return
		_wait = 0.0
		_single.visible = true
	_follow()

func _follow() -> void:
	var vs := get_viewport().get_visible_rect().size
	var mp := get_viewport().get_mouse_position()
	var sz := _single.get_combined_minimum_size()
	_single.size = sz
	var p := mp + OFFSET
	if p.x + sz.x > vs.x - MARGIN:
		p.x = mp.x - OFFSET.x - sz.x
	if p.y + sz.y > vs.y - MARGIN:
		p.y = mp.y - OFFSET.y - sz.y
	p = Vector2(clampf(p.x, MARGIN, maxf(MARGIN, vs.x - sz.x - MARGIN)), clampf(p.y, MARGIN, maxf(MARGIN, vs.y - sz.y - MARGIN)))
	if _hits_avoid(Rect2(p, sz)).size.x > 0.0:
		for alt in [mp - OFFSET - sz, Vector2(mp.x + OFFSET.x, mp.y - OFFSET.y - sz.y), Vector2(mp.x - OFFSET.x - sz.x, mp.y + OFFSET.y)]:
			var q := Vector2(clampf(alt.x, MARGIN, maxf(MARGIN, vs.x - sz.x - MARGIN)), clampf(alt.y, MARGIN, maxf(MARGIN, vs.y - sz.y - MARGIN)))
			if _hits_avoid(Rect2(q, sz)).size.x <= 0.0:
				p = q
				break
	_single.position = p.floor()

# items = [{text, pos}] (pos: centro proyectado del ancla, en pantalla)
func show_many(items: Array) -> void:
	clear_many()
	var vs := get_viewport().get_visible_rect().size
	var placed: Array = []
	var sorted := items.duplicate()
	sorted.sort_custom(func(a, b): return (a.pos as Vector2).y < (b.pos as Vector2).y)
	for it in sorted:
		var p := _strip()
		(p.get_child(0) as Label).text = String(it.text)
		_many.add_child(p)
		var sz := p.get_combined_minimum_size()
		p.size = sz
		var r := Rect2((it.pos as Vector2) - Vector2(sz.x * 0.5, sz.y * 0.5), sz)
		r.position.x = clampf(r.position.x, MARGIN, maxf(MARGIN, vs.x - sz.x - MARGIN))
		r.position.y = clampf(r.position.y, MARGIN, maxf(MARGIN, vs.y - sz.y - MARGIN))
		# no sobre la interfaz: a la derecha de la columna del calendario o encima de la banda (lo que mueva menos)
		var hit := _hits_avoid(r)
		if hit.size.x > 0.0:
			var right := Vector2(hit.end.x + 4.0, r.position.y)
			var above := Vector2(r.position.x, hit.position.y - sz.y - 4.0)
			r.position = right if right.distance_to(r.position) < above.distance_to(r.position) and right.x + sz.x < vs.x else above
		var guard := 0
		var moved := true
		while moved and guard < 40:
			moved = false
			guard += 1
			for q in placed:
				if (q as Rect2).grow(2.0).intersects(r):
					r.position.y = (q as Rect2).end.y + 3.0
					moved = true
		if r.end.y > vs.y - MARGIN:
			r.position.y = vs.y - MARGIN - sz.y
		p.position = r.position.floor()
		placed.append(r)

func clear_many() -> void:
	if _many == null:
		return
	for c in _many.get_children():
		_many.remove_child(c)
		c.queue_free()

func many_count() -> int:
	return _many.get_child_count() if _many != null else 0

func many_texts() -> Array:
	var out: Array = []
	if _many == null:
		return out
	for c in _many.get_children():
		out.append((c.get_child(0) as Label).text)
	return out
