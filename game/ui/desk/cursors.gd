# ui/desk/cursors.gd — cursores dibujados por código, sin archivos (GDD_v2 §D.2; GDD_v3 §6.5). Dueño: UI-MUNDO. Estática.
# Una lupa (lo que se mira) y una mano (lo que se usa) de 32×32 en tinta sobre papel, con un halo de papel para que se
# lean sobre cualquier lavado. install() los asigna con Input.set_custom_mouse_cursor a CURSOR_HELP (lupa) y
# CURSOR_POINTING_HAND (mano); WorldRoot elige la forma con Input.set_default_cursor_shape según lo que hay bajo el
# mouse. En alto contraste, negro sobre blanco. scissors(): la tijera (cursor sobre el texto recortable de las tarjetas
# con la tijera en la mano) y scissors_icon(px): el ícono suelto de la tijera (sin recuadro ni palabra, §6.7).
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

static var _sc_tex: ImageTexture = null
static var _sc_icons := {}

static func scissors() -> ImageTexture:
	if _sc_tex == null:
		_sc_tex = ImageTexture.create_from_image(scissors_img(SIZE))
	return _sc_tex

static func scissors_icon(px := 28) -> ImageTexture:
	if not _sc_icons.has(px):
		_sc_icons[px] = ImageTexture.create_from_image(scissors_img(px))
	return _sc_icons[px]

# Botón de la tijera: el ícono suelto (sin recuadro ni la palabra), de alternar; tenue si no está en la mano.
static func scissors_button(px := 28) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Tijera"
	b.texture_normal = scissors_icon(px)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(px, px)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "C"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pivot_offset = Vector2(px, px) * 0.5
	paint_scissors(b, false)
	b.toggled.connect(func(on): paint_scissors(b, on))
	return b

# Estado del ícono sin emitir toggled: «tomada» (tinta llena, inclinada) o tenue.
static func paint_scissors(b: BaseButton, on: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
	b.set_pressed_no_signal(on)
	b.modulate = Color(1, 1, 1, 1.0) if on else Color(1, 1, 1, 0.62)
	b.rotation_degrees = -18.0 if on else 0.0

# Tijera de tinta abierta, de n×n, con halo de papel: dos hojas que se cruzan en el eje y dos ojos redondos abajo.
static func scissors_img(n: int, ink := INK, pap := PAPER) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var k := float(n) / 32.0
	var piv := Vector2(14.0, 14.0) * k
	var blades := [[Vector2(3.0, 5.0) * k, piv], [Vector2(5.0, 3.0) * k, piv]]
	var arms := [[piv, Vector2(20.5, 23.5) * k], [piv, Vector2(23.5, 20.5) * k]]
	var rings := [Vector2(22.5, 26.0) * k, Vector2(26.0, 22.5) * k]
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := 1e9
			for s in blades:
				d = minf(d, _sd_capsule(p, s[0], s[1], 1.1 * k))
			for s2 in arms:
				d = minf(d, _sd_capsule(p, s2[0], s2[1], 0.8 * k))
			for c in rings:
				d = minf(d, absf(p.distance_to(c) - 3.4 * k) - 0.9 * k)
			d = minf(d, _sd_circle(p, piv, 1.3 * k))
			_paint(img, x, y, pap, _cov(d - 1.4 * k) * 0.9)
			_paint(img, x, y, ink, _cov(d))
	return img

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
