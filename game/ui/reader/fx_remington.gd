# ui/reader/fx_remington.gd — defectos de la Remington de Cotter (GDD§14.3, §9.9). Dueño: W2-READER. Contrato: §6.4.
# RichTextEffect estático (no usa elapsed_time): el carácter real sale de
#   TextServerManager.get_primary_interface().font_get_char_from_glyph_index(char_fx.font, size, char_fx.glyph_index)
# Defectos de tipo (la misma barra lleva minúscula y mayúscula):
#   «s» alzada 0,08 em · «t» pálida (alfa × 0,65) · «e» girada 3° sobre su centro.
# Jitter de tecleo sembrado por char_fx.range.x (posición absoluta del carácter): ±0,012 em en x, ±0,028 em en y,
# giro ±0,5°, densidad de cinta 0,84–1,0. Todo proporcional al tamaño (env.size en px). Se conserva en alto contraste.
# El TextBuilder sólo lo aplica a texto en ranura "maquina" de un documento con `machine`.
extends RichTextEffect

var bbcode := "remington"

const S_UP_EM := 0.08
const T_ALPHA := 0.65
const E_DEG := 3.0
const JX_EM := 0.012
const JY_EM := 0.028
const JR_DEG := 0.5
const INK_MIN := 0.84

var _chars := {}     # Vector3i(font_id, glyph, size) -> codepoint
var _adv := {}       # Vector3i(...) -> advance / size

static func h01(n: int, k: int) -> float:
	var x := (n * 374761393 + k * 668265263 + 1013904223) & 0xffffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff
	x = x ^ (x >> 16)
	return float(x & 0xffff) / 65535.0

func char_of(font: RID, glyph: int, size: int) -> int:
	var key := Vector3i(font.get_id(), glyph, size)
	if _chars.has(key):
		return _chars[key]
	var c := TextServerManager.get_primary_interface().font_get_char_from_glyph_index(font, size, glyph)
	_chars[key] = c
	return c

func adv_em(font: RID, glyph: int, size: int) -> float:
	var key := Vector3i(font.get_id(), glyph, size)
	if _adv.has(key):
		return _adv[key]
	var a := TextServerManager.get_primary_interface().font_get_glyph_advance(font, size, glyph).x / maxf(1.0, float(size))
	a = clampf(a, 0.2, 1.2)
	_adv[key] = a
	return a

# Defecto (sin jitter) de un carácter: {"dy_em", "alpha", "deg"}. Puro: lo usan los tests.
static func defect(c: int) -> Dictionary:
	var s := String.chr(c).to_lower() if c > 0 else ""
	match s:
		"s":
			return {"dy_em": -S_UP_EM, "alpha": 1.0, "deg": 0.0}
		"t":
			return {"dy_em": 0.0, "alpha": T_ALPHA, "deg": 0.0}
		"e":
			return {"dy_em": 0.0, "alpha": 1.0, "deg": E_DEG}
	return {"dy_em": 0.0, "alpha": 1.0, "deg": 0.0}

func _process_custom_fx(fx: CharFXTransform) -> bool:
	if fx.glyph_index <= 0:
		return true
	var size := float(fx.env.get("size", 20))
	var isz := int(size)
	var c := char_of(fx.font, fx.glyph_index, isz)
	var d := defect(c)
	var n := fx.range.x
	var jx := (h01(n, 1) - 0.5) * 2.0 * JX_EM * size
	var jy := (h01(n, 2) - 0.5) * 2.0 * JY_EM * size
	var deg := float(d.deg) + (h01(n, 3) - 0.5) * 2.0 * JR_DEG
	fx.offset += Vector2(jx, jy + float(d.dy_em) * size)
	if absf(deg) > 0.01:
		var piv := Vector2(adv_em(fx.font, fx.glyph_index, isz) * size * 0.5, -size * 0.32)
		fx.transform = fx.transform * Transform2D(0.0, piv) * Transform2D(deg_to_rad(deg), Vector2.ZERO) * Transform2D(0.0, -piv)
	var ink := INK_MIN + (1.0 - INK_MIN) * h01(n, 4)
	fx.color.a *= ink * float(d.alpha)
	return true
