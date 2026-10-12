# ui/reader/fx_smallcaps.gd — versalitas (<sc>) sin cambiar el texto. Dueño: W2-READER. Contrato: §4.2, §6.4.
# Ninguna de las fuentes aprobadas trae la función OpenType smcp; TextBuilder empuja una FontVariation con
# spacing_glyph = env.sp (px) y este efecto cambia cada minúscula por el glifo de su mayúscula a K (0,78) del cuerpo,
# comprimido en x si no cabe en su celda (avance de la minúscula + sp) y centrado en ella. Mayúsculas y signos
# quedan iguales, centrados en su celda. El texto (get_parsed_text) no cambia: sólo el dibujo.
extends RichTextEffect

var bbcode := "versalita"

const K := 0.78

var _info := {}   # Vector3i(font_id, glyph, size) -> {} | {g, al, au}

func info(font: RID, glyph: int, size: int) -> Dictionary:
	var key := Vector3i(font.get_id(), glyph, size)
	if _info.has(key):
		return _info[key]
	var ts := TextServerManager.get_primary_interface()
	var out := {}
	var c := ts.font_get_char_from_glyph_index(font, size, glyph)
	if c > 0:
		var s := String.chr(c)
		var up := s.to_upper()
		if up != s and up.length() == 1:
			var ug := ts.font_get_glyph_index(font, size, up.unicode_at(0), 0)
			if ug > 0:
				var fs := maxf(1.0, float(size))
				out = {"g": ug, "al": ts.font_get_glyph_advance(font, size, glyph).x / fs,
					"au": ts.font_get_glyph_advance(font, size, ug).x / fs}
	_info[key] = out
	return out

func _process_custom_fx(fx: CharFXTransform) -> bool:
	if fx.glyph_index <= 0:
		return true
	var size := float(fx.env.get("size", 20))
	var sp := float(fx.env.get("sp", 0))
	var inf := info(fx.font, fx.glyph_index, int(size))
	if inf.is_empty():
		if sp > 0.0:
			fx.transform = fx.transform * Transform2D(0.0, Vector2(sp * 0.5, 0.0))
		return true
	var adv_u := maxf(0.01, float(inf.au) * size)
	var cell := float(inf.al) * size + sp
	var sx := minf(K * 1.1, cell * 0.97 / adv_u)
	var dx := (cell - adv_u * sx) * 0.5
	fx.glyph_index = int(inf.g)
	fx.transform = fx.transform * Transform2D(Vector2(sx, 0.0), Vector2(0.0, K), Vector2(dx, 0.0))
	return true
