# ui/map/map_draw.gd — el plano de Londres dibujado por código desde data/map.json (ARCHITECTURE §4.17, §6.7). Dueño: W3-SHELL.
# Hoja en milímetros (size_mm) escalada a px: zonas con las tintas de Booth, parques rayados, el Támesis, calles con su
# nombre en itálica, cartela con título, rosa de los vientos y escala de una milla. Sin imágenes. Alto contraste: hoja
# blanca, tinta negra, zonas sólo rayadas. mm_to_px(p) / px_per_mm para ubicar marcadores (map_screen.gd).
extends Control

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

const MILE_KM := 1.609
const KM_MM := 78.6          # 600 mm = 7,63 km (proyección de map.json)

var mapdata := {}
var px_per_mm := 1.0
var route := {}              # {from: Vector2 mm, to: Vector2 mm, t: 0..1} trayecto del coche (map_screen)

func _init() -> void:
	name = "MapDraw"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func setup(p_map: Dictionary) -> void:
	mapdata = p_map
	queue_redraw()

func size_mm() -> Vector2:
	var s = mapdata.get("size_mm", [600, 420])
	return Vector2(float(s[0]), float(s[1]))

func fit(px_size: Vector2) -> void:
	var smm := size_mm()
	px_per_mm = minf(px_size.x / smm.x, px_size.y / smm.y)
	custom_minimum_size = (smm * px_per_mm).floor()
	size = custom_minimum_size
	queue_redraw()

func mm_to_px(p) -> Vector2:
	if typeof(p) == TYPE_ARRAY and p.size() >= 2:
		return Vector2(float(p[0]), float(p[1])) * px_per_mm
	if p is Vector2:
		return p * px_per_mm
	return Vector2.ZERO

func _pts(arr) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(mm_to_px(p))
	return out

func _font(italic := false) -> Font:
	var ti := Widgets.ti()
	if ti != null:
		return ti.font("imprenta", italic)
	return ThemeDB.fallback_font

func _fs(base: float) -> int:
	var ti := Widgets.ti()
	var k: float = 1.0 if ti == null else float(ti.text_scale)
	return maxi(8, int(round(base * px_per_mm * k)))

# GDD_v2 §C.3: las zonas de color de Booth bajan al 30 % de lo que eran (0,30 -> 0,09): sabor de fondo, no información.
const BOOTH_ALPHA := 0.09

func _draw() -> void:
	var hc := Paper.hc_on()
	var r := Rect2(Vector2.ZERO, size)
	var sheet := Color("e8dec4") if not hc else Color(1, 1, 1)
	var ink := Paper.ink("negra")
	draw_rect(r, sheet)
	if not hc:
		draw_texture_rect(Paper.mottle_texture(), r, true, Color(1, 1, 1, 0.10))
		draw_texture_rect(Paper.grain_texture(), r, true, Color(1, 1, 1, 0.07))
	var colors: Dictionary = mapdata.get("booth_colors", {})
	# zonas de Booth
	for z in mapdata.get("booth_zones", []):
		var poly := _pts(z.get("poly", []))
		if poly.size() < 3:
			continue
		var cls := String(z.get("class", ""))
		if hc:
			_hatch(poly, Color(0, 0, 0, 0.25), 7.0, 0.6)
		else:
			var col := Color(String(colors.get(cls, "c8b89a")))
			col.a = BOOTH_ALPHA
			draw_colored_polygon(poly, col)
	# parques
	for pk in mapdata.get("parks", []):
		var poly := _pts(pk.get("pts", []))
		if poly.size() < 3:
			continue
		if not hc:
			draw_colored_polygon(poly, Color("a3ad84", 0.42))
		_hatch(poly, Color(ink, 0.18), 5.0, 0.7, true)
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(ink, 0.45), 1.0, true)
	# río
	var rv: Dictionary = mapdata.get("river", {})
	var rp := _pts(rv.get("pts", []))
	if rp.size() >= 2:
		var w := float(rv.get("w", 16)) * px_per_mm
		draw_polyline(rp, Color(ink, 0.55), w + 2.0, true)
		draw_polyline(rp, Color("aebfc4") if not hc else Color(1, 1, 1), w, true)
		for k in range(1, 4):
			draw_polyline(_offset(rp, w * (0.18 * k - 0.36)), Color(ink, 0.10), 0.8, true)
	# calles
	for s in mapdata.get("streets", []):
		var sp := _pts(s.get("pts", []))
		if sp.size() < 2:
			continue
		var sw := maxf(1.2, float(s.get("w", 2.0)) * px_per_mm)
		draw_polyline(sp, Color(ink, 0.75), sw + 1.6, true)
		draw_polyline(sp, sheet.lightened(0.25), maxf(0.6, sw - 0.8), true)
	# nombres de calles, parques y río
	for s in mapdata.get("streets", []):
		var nm := String(s.get("name", ""))
		if nm == "":
			continue
		var sp := _pts(s.get("pts", []))
		var i := clampi(int(s.get("label_at", 0)), 0, sp.size() - 2)
		_label_along(nm, sp[i], sp[i + 1], _fs(4.6), Color(ink, 0.7))
	for pk in mapdata.get("parks", []):
		var nm := String(pk.get("name", ""))
		var poly := _pts(pk.get("pts", []))
		if nm != "" and poly.size() >= 3:
			var c := Vector2.ZERO
			for p in poly:
				c += p
			c /= poly.size()
			var vis := Rect2(Vector2.ZERO, size).grow(-10)
			if vis.has_point(c):
				_text_center(nm.to_upper(), c, _fs(4.4), Color(ink, 0.55), true)
	if rp.size() >= 5:
		var a := rp[3]
		var b := rp[4]
		_label_along(String(rv.get("name", "")).to_upper(), a, b, _fs(6.0), Color(ink, 0.6), true)
	# cartela, rosa y escala
	_cartouche(ink)
	_compass(ink)
	_scale_bar(ink)
	# trayecto del coche
	if not route.is_empty():
		var a2 := mm_to_px(route.from)
		var b2 := mm_to_px(route.to)
		var t := clampf(float(route.get("t", 0.0)), 0.0, 1.0)
		var e := a2.lerp(b2, t)
		_dash(a2, e, Paper.ink("roja"), 2.2)
		draw_circle(e, 4.0, Paper.ink("roja"))
	# marco doble
	draw_rect(r.grow(-3), Color(ink, 0.9), false, 2.0)
	draw_rect(r.grow(-8), Color(ink, 0.6), false, 1.0)

func _offset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var a := pts[maxi(0, i - 1)]
		var b := pts[mini(pts.size() - 1, i + 1)]
		var n := (b - a).orthogonal().normalized()
		out.append(pts[i] + n * d)
	return out

func _hatch(poly: PackedVector2Array, col: Color, step: float, w: float, cross := false) -> void:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var s := step * maxf(1.0, px_per_mm * 0.6)
	var x := bb.position.x - bb.size.y
	while x < bb.end.x:
		var a := Vector2(x, bb.end.y)
		var b := Vector2(x + bb.size.y, bb.position.y)
		_clip_seg(poly, a, b, col, w)
		if cross:
			_clip_seg(poly, Vector2(x, bb.position.y), Vector2(x + bb.size.y, bb.end.y), col, w)
		x += s

func _clip_seg(poly: PackedVector2Array, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var segs := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), poly)
	for sg in segs:
		if sg.size() >= 2:
			draw_line(sg[0], sg[sg.size() - 1], col, w, true)

func _label_along(text: String, a: Vector2, b: Vector2, fs: int, col: Color, italic := true) -> void:
	var f := _font(italic)
	var ang := (b - a).angle()
	if ang > PI * 0.5:
		ang -= PI
	elif ang < -PI * 0.5:
		ang += PI
	var mid := (a + b) * 0.5
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(mid, ang, Vector2.ONE)
	draw_string(f, Vector2(-w * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text_center(text: String, c: Vector2, fs: int, col: Color, italic := false) -> void:
	var f := _font(italic)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _cartouche(ink: Color) -> void:
	var t := String(mapdata.get("title", ""))
	if t == "":
		return
	var fs := _fs(10.0)
	var fs2 := _fs(4.6)
	var f := _font(false)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sub := String(mapdata.get("subtitle", ""))
	var w2 := _font(true).get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var bw := maxf(w, w2) + 40.0
	var box := Rect2(Vector2(22, 22), Vector2(bw, fs + fs2 + 30.0))
	draw_rect(box, Color("efe6cf") if not Paper.hc_on() else Color(1, 1, 1))
	draw_rect(box, Color(ink, 0.85), false, 1.5)
	draw_rect(box.grow(-4), Color(ink, 0.5), false, 0.8)
	draw_string(f, box.position + Vector2((bw - w) * 0.5, 12 + fs), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if sub != "":
		draw_string(_font(true), box.position + Vector2((bw - w2) * 0.5, 20 + fs + fs2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(ink, 0.75))

func _compass(ink: Color) -> void:
	var c := Vector2(size.x - 44.0, 56.0)
	var r := 18.0
	draw_arc(c, r, 0, TAU, 32, Color(ink, 0.6), 1.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r - 6), c + Vector2(5, 0), c + Vector2(-5, 0)]), Color(ink, 0.85))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r + 6), c + Vector2(5, 0), c + Vector2(-5, 0)]), Color(ink, 0.3))
	_text_center("N", c + Vector2(0, -r - 14), _fs(4.6), ink)

func _scale_bar(ink: Color) -> void:
	var mile_px := MILE_KM * KM_MM * px_per_mm
	var o := Vector2(size.x - mile_px - 40.0, size.y - 34.0)
	draw_line(o, o + Vector2(mile_px, 0), ink, 1.5)
	for k in 5:
		var x := o.x + mile_px * k / 4.0
		draw_line(Vector2(x, o.y - 4), Vector2(x, o.y + 4), ink, 1.0)
		if k < 4 and k % 2 == 0:
			draw_rect(Rect2(Vector2(x, o.y - 2), Vector2(mile_px / 4.0, 4)), Color(ink, 0.8))
	_text_center(Widgets.t("shell.map.milla"), o + Vector2(mile_px * 0.5, -10), _fs(4.0), Color(ink, 0.8), true)

func _dash(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var l := a.distance_to(b)
	if l <= 0.5:
		return
	var d := (b - a) / l
	var t := 0.0
	while t < l:
		draw_line(a + d * t, a + d * minf(t + 8.0, l), c, w, true)
		t += 13.0
