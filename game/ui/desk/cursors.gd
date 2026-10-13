# ui/desk/cursors.gd — cursores dibujados por código, sin archivos (GDD_v2 §D.2). Dueño: CÁMARA + AFORDANCIAS. Estática.
# Una lupa (examinable) y una mano (usable) de 32×32 en tinta sobre papel, con un halo de papel para que se lean sobre
# cualquier lavado. install() los asigna con Input.set_custom_mouse_cursor a CURSOR_HELP (lupa) y CURSOR_POINTING_HAND
# (mano); WorldRoot elige la forma con Input.set_default_cursor_shape según lo que hay bajo el mouse. En alto contraste,
# negro sobre blanco.
extends RefCounted

const SIZE := 32
const INK := Color("2a1a10")
const PAPER := Color("f3ead6")

static var _installed := false

static func install(force := false) -> void:
	if _installed and not force:
		return
	if DisplayServer.get_name() == "headless":
		return
	var hc := false
	var ti = Engine.get_main_loop().root.get_node_or_null("ThemeInstaller") if Engine.get_main_loop() is SceneTree else null
	if ti != null and "high_contrast" in ti:
		hc = bool(ti.high_contrast)
	var ink := Color.BLACK if hc else INK
	var pap := Color.WHITE if hc else PAPER
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(lens(ink, pap)), Input.CURSOR_HELP, Vector2(12, 12))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(hand(ink, pap)), Input.CURSOR_POINTING_HAND, Vector2(11, 2))
	_installed = true

# Suelta los cursores (al salir de la pantalla de juego y al cerrar): Input retiene sus texturas y al terminar el
# proceso quedaban sin liberar («RIDs of type Texture were leaked»).
static func uninstall() -> void:
	if not _installed:
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_HELP)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_installed = false

# --- distancias con signo (negativo adentro)
static func _sd_circle(p: Vector2, c: Vector2, r: float) -> float:
	return p.distance_to(c) - r

static func _sd_capsule(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 1e-6), 0.0, 1.0)
	return (pa - ba * h).length() - r

static func _sd_rbox(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

static func _paint(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if a <= 0.0:
		return
	var o := img.get_pixel(x, y)
	var na := a + o.a * (1.0 - a)
	if na <= 0.0:
		return
	var rgb := (Color(c.r, c.g, c.b) * a + Color(o.r, o.g, o.b) * o.a * (1.0 - a)) / na
	img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, na))

static func _cov(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)

# Lupa: aro de tinta (r 8,5) con el vidrio de papel translúcido y el mango en diagonal.
static func lens(ink := INK, pap := PAPER) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(12.5, 12.5)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var ring := absf(_sd_circle(p, c, 8.5)) - 1.6
			var handle := _sd_capsule(p, Vector2(19.0, 19.0), Vector2(27.5, 27.5), 2.4)
			var glass := _sd_circle(p, c, 7.2)
			var shape := minf(ring, handle)
			_paint(img, x, y, pap, _cov(shape - 1.6) * 0.95)          # halo de papel
			_paint(img, x, y, pap, _cov(glass) * 0.55)                 # vidrio
			_paint(img, x, y, ink, _cov(shape))
	return img

# Mano que señala: índice arriba, palma redondeada, tres nudillos y el pulgar.
static func hand(ink := INK, pap := PAPER) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _sd_capsule(p, Vector2(11.5, 4.5), Vector2(11.5, 16.0), 2.7)
			d = minf(d, _sd_rbox(p, Vector2(15.5, 21.5), Vector2(6.8, 6.0), 3.5))
			d = minf(d, _sd_capsule(p, Vector2(15.4, 13.6), Vector2(15.4, 17.0), 2.3))
			d = minf(d, _sd_capsule(p, Vector2(19.0, 14.6), Vector2(19.0, 18.0), 2.3))
			d = minf(d, _sd_capsule(p, Vector2(22.2, 16.0), Vector2(22.2, 19.5), 2.1))
			d = minf(d, _sd_capsule(p, Vector2(6.5, 17.5), Vector2(9.5, 22.0), 2.3))
			_paint(img, x, y, ink, _cov(d - 1.3))                       # contorno
			_paint(img, x, y, pap, _cov(d + 0.2))                       # relleno de papel
	# líneas de los dedos
	for seg in [[Vector2(13.6, 15.5), Vector2(13.6, 19.0)], [Vector2(17.2, 16.0), Vector2(17.2, 19.5)], [Vector2(20.6, 17.0), Vector2(20.6, 20.0)]]:
		for y in SIZE:
			for x in SIZE:
				var d2 := _sd_capsule(Vector2(x + 0.5, y + 0.5), seg[0], seg[1], 0.45)
				_paint(img, x, y, ink, _cov(d2) * 0.8)
	return img
