# ui/kit/paper.gd — papeles, tintas e íconos del kit. Dueño: W1-THEME. Contrato: ARCHITECTURE §6.2.
# Uso: const Paper = preload("res://ui/kit/paper.gd")
#   Paper.paper("telegrama") -> Color        Paper.ink("azul") -> Color       (alto contraste automático; hc=0/1 lo fuerza)
#   Paper.style("libro_mayor", {shadow, border, radius, margin}) -> StyleBoxFlat
#   Hoja con grano y renglones: ui/kit/sheet.gd (Widgets.sheet)
# Alto contraste (GDD§14.7): todo papel #fff, tinta negra #000; las demás tintas oscurecidas conservan el matiz
# (azul/roja siguen distinguibles; tenue = gris 7:1). Nada aquí lee data/ ni hace push_error.
extends RefCounted

const PAPERS := {
	"diario_hueso": Color("ece3cf"),
	"strand": Color("f0e8d6"),
	"diogenes_recortado": Color("f3ead6"),
	"telegrama": Color("e6d3b0"),
	"carta": Color("f1ead9"),
	"registro": Color("e9e2d0"),
	"libro_mayor": Color("efe6d2"),
	"cuaderno": Color("f2ecdc"),
}
const INKS := {
	"negra": Color("1b1712"),
	"lapiz": Color("4a4a4a"),
	"azul": Color("2b4a8a"),
	"roja": Color("8a2b22"),
	"tenue": Color("8c8270"),
}
const HC_PAPER := Color("ffffff")
const HC_INKS := {
	"negra": Color("000000"),
	"lapiz": Color("2e2e2e"),
	"azul": Color("1a3a8a"),
	"roja": Color("8a0f0a"),
	"tenue": Color("595959"),
}
# Colores auxiliares del kit (no son papeles del mundo).
const RULE_BLUE := Color("8ea2b6")        # renglones del libro mayor
const MESA := Color("3a2f26")             # fondo neutro (galería, pantallas sin 3D)
const SHADOW := Color(0.106, 0.09, 0.07, 0.30)
const SELECTION := Color(0.72, 0.64, 0.47, 0.55)

static func _ti() -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null("ThemeInstaller")
	return null

static func hc_on(hc := -1) -> bool:
	if hc >= 0:
		return hc == 1
	var ti := _ti()
	return ti != null and bool(ti.high_contrast)

static func paper(name: String, hc := -1) -> Color:
	if hc_on(hc):
		return HC_PAPER
	return PAPERS.get(name, PAPERS["cuaderno"])

static func ink(name: String, hc := -1) -> Color:
	if hc_on(hc):
		return HC_INKS.get(name, HC_INKS["negra"])
	return INKS.get(name, INKS["negra"])

# Borde del papel: el mismo papel oscurecido (en alto contraste, negro).
static func edge(name: String, hc := -1) -> Color:
	if hc_on(hc):
		return Color("000000")
	return paper(name, 0).darkened(0.22)

# Un tono de papel más oscuro (pestañas sin elegir, botones apretados).
static func shade(name: String, amount := 0.06, hc := -1) -> Color:
	if hc_on(hc):
		# gris proporcional: normal / hover / pulsado siguen distinguiéndose en alto contraste
		return HC_PAPER.darkened(minf(amount * 1.6, 0.5)) if amount > 0.0 else HC_PAPER
	return paper(name, 0).darkened(amount)

static func style(name := "cuaderno", opts := {}, hc := -1) -> StyleBoxFlat:
	var on := hc_on(hc)
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper(name, 1 if on else 0)
	var bw := int(opts.get("border", 1))
	sb.set_border_width_all(bw)
	sb.border_color = edge(name, 1 if on else 0)
	if not on:
		sb.border_color.a = 0.85
	sb.set_corner_radius_all(int(opts.get("radius", 2)))
	sb.anti_aliasing = true
	var m := float(opts.get("margin", 16))
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = float(opts.get("margin_v", m * 0.8))
	sb.content_margin_bottom = float(opts.get("margin_v", m * 0.8))
	if bool(opts.get("shadow", true)) and not on:
		sb.shadow_color = SHADOW
		sb.shadow_size = int(opts.get("shadow_size", 7))
		sb.shadow_offset = Vector2(0, int(opts.get("shadow_y", 3)))
	return sb

static func flat(bg: Color, border := Color(0, 0, 0, 0), widths := [0, 0, 0, 0], radius := 0, margins := [-1, -1, -1, -1]) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = int(widths[0])
	sb.border_width_top = int(widths[1])
	sb.border_width_right = int(widths[2])
	sb.border_width_bottom = int(widths[3])
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = radius > 0
	if margins[0] >= 0: sb.content_margin_left = margins[0]
	if margins[1] >= 0: sb.content_margin_top = margins[1]
	if margins[2] >= 0: sb.content_margin_right = margins[2]
	if margins[3] >= 0: sb.content_margin_bottom = margins[3]
	return sb

static func empty(margins := [0, 0, 0, 0]) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margins[0]
	sb.content_margin_top = margins[1]
	sb.content_margin_right = margins[2]
	sb.content_margin_bottom = margins[3]
	return sb

# ---------------------------------------------------------------- grano de papel (tileable, determinista, perezoso)
static var _grain: ImageTexture = null
static var _mottle: ImageTexture = null

# Textura RGBA de media neutra: la mitad oscura del ruido mancha con tinta parda, la clara aclara con blanco cálido;
# así el papel conserva en promedio su color exacto (§6.2) y sólo gana textura. Se dibuja con modulate alfa bajo.
static func grain_texture() -> ImageTexture:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.seed = 1894
		n.noise_type = FastNoiseLite.TYPE_VALUE
		n.frequency = 0.5
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		_grain = _neutral_tex(n, 128, Color8(70, 52, 30), 0.8)
	return _grain

static func mottle_texture() -> ImageTexture:
	if _mottle == null:
		var n := FastNoiseLite.new()
		n.seed = 1903
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.011
		n.fractal_octaves = 4
		_mottle = _neutral_tex(n, 256, Color8(120, 92, 52), 0.9)
	return _mottle

static func _neutral_tex(n: FastNoiseLite, sz: int, dark: Color, light_k: float) -> ImageTexture:
	var src := n.get_seamless_image(sz, sz).get_data()   # L8 normalizado 0..255
	var out := PackedByteArray()
	out.resize(sz * sz * 4)
	var dr := dark.r8
	var dg := dark.g8
	var db := dark.b8
	for i in src.size():
		var v := int(src[i]) - 128
		var o := i * 4
		if v >= 0:
			out[o] = dr
			out[o + 1] = dg
			out[o + 2] = db
			out[o + 3] = mini(255, v * 2)
		else:
			out[o] = 255
			out[o + 1] = 251
			out[o + 2] = 240
			out[o + 3] = mini(255, int(-v * 2 * light_k))
	return ImageTexture.create_from_image(Image.create_from_data(sz, sz, false, Image.FORMAT_RGBA8, out))

# ---------------------------------------------------------------- íconos dibujados por SDF (sin archivos)
static var _icons := {}

static func icon(kind: String, size: int, col: Color) -> ImageTexture:
	var key := "%s|%d|%s" % [kind, size, col.to_html()]
	if _icons.has(key):
		return _icons[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	var c := Vector2(s, s) * 0.5
	var lw := maxf(1.2, s / 13.0)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _icon_sdf(kind, p, c, s, lw)
			var a := clampf(0.5 - d, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()

static func _box(p: Vector2, c: Vector2, half: float) -> float:
	var q := (p - c).abs() - Vector2(half, half)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)

static func _icon_sdf(kind: String, p: Vector2, c: Vector2, s: float, lw: float) -> float:
	match kind:
		"box":
			return absf(_box(p, c, s * 0.33)) - lw * 0.5
		"box_checked":
			var b := absf(_box(p, c, s * 0.33)) - lw * 0.5
			var a1 := c + Vector2(-s * 0.2, 0.0)
			var a2 := c + Vector2(-s * 0.05, s * 0.17)
			var a3 := c + Vector2(s * 0.24, -s * 0.2)
			var k := minf(_seg(p, a1, a2), _seg(p, a2, a3)) - lw * 0.75
			return minf(b, k)
		"radio":
			return absf((p - c).length() - s * 0.32) - lw * 0.5
		"radio_checked":
			return minf(absf((p - c).length() - s * 0.32) - lw * 0.5, (p - c).length() - s * 0.15)
		"chevron_down":
			var l := c + Vector2(-s * 0.22, -s * 0.1)
			var m := c + Vector2(0.0, s * 0.12)
			var r := c + Vector2(s * 0.22, -s * 0.1)
			return minf(_seg(p, l, m), _seg(p, m, r)) - lw * 0.5
		"chevron_right":
			var t := c + Vector2(-s * 0.1, -s * 0.22)
			var m2 := c + Vector2(s * 0.12, 0.0)
			var bt := c + Vector2(-s * 0.1, s * 0.22)
			return minf(_seg(p, t, m2), _seg(p, m2, bt)) - lw * 0.5
		"dot":
			return (p - c).length() - s * 0.28
		"dot_ring":
			return minf((p - c).length() - s * 0.2, absf((p - c).length() - s * 0.36) - lw * 0.4)
		"cross":
			var e := s * 0.22
			return minf(_seg(p, c + Vector2(-e, -e), c + Vector2(e, e)), _seg(p, c + Vector2(-e, e), c + Vector2(e, -e))) - lw * 0.5
	return 1e9

