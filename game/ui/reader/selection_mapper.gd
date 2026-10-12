# ui/reader/selection_mapper.gd — selección del RichTextLabel -> {from, len} sobre parsed.plain. Dueño: W2-READER. §6.4.
# map(rtl, parsed): from = get_selection_from(), len = get_selected_text().length() (NO get_selection_to(), cuyo sentido
#   varía); verifica plain.substr(from, len) == seleccionado; si no, busca la ocurrencia más cercana a from (±8).
#   -> {ok, from, len, text, adjusted}. ok=false si no hay selección o no se encuentra.
# map_raw(plain, from, selected): lo mismo sin RichTextLabel (T19 puro).
# preview(parsed, from, len): lo que el sim haría (ClipRules.snap + inherit) -> {ok, err, from, to, text, tramo, tags,
#   ents, frac}; sólo para tests y para el texto de la tira que vuela (la verdad la decide Game.act / clip_text).
extends RefCounted

const ClipRules = preload("res://core/text/clip_rules.gd")

const SEARCH := 8

static func map(rtl: RichTextLabel, parsed: Dictionary) -> Dictionary:
	var sel := rtl.get_selected_text()
	var from := rtl.get_selection_from()
	return map_raw(String(parsed.get("plain", "")), from, sel)

static func map_raw(plain: String, from: int, selected: String) -> Dictionary:
	var n := selected.length()
	if n == 0 or from < 0:
		return {"ok": false, "from": maxi(from, 0), "len": 0, "text": "", "adjusted": false}
	if plain.substr(from, n) == selected:
		return {"ok": true, "from": from, "len": n, "text": selected, "adjusted": false}
	for d in range(1, SEARCH + 1):
		for s in [from - d, from + d]:
			if s >= 0 and s + n <= plain.length() and plain.substr(s, n) == selected:
				return {"ok": true, "from": s, "len": n, "text": selected, "adjusted": true}
	return {"ok": false, "from": from, "len": n, "text": selected, "adjusted": false}

# Posición local (en el rtl, sin zoom) del carácter k: x por medida del prefijo de su línea con la fuente normal del
# bloque (aproximada si la línea mezcla fuentes), y = mitad de la línea. Para tests, drivers y la tira que vuela.
static func char_local_pos(rtl: RichTextLabel, k: int) -> Vector2:
	var plain := rtl.get_parsed_text()
	k = clampi(k, 0, maxi(0, plain.length() - 1))
	var line := rtl.get_character_line(k)
	if line < 0:
		return Vector2.ZERO
	var lr: Vector2i = rtl.get_line_range(line)
	var f: Font = rtl.get_theme_font("normal_font")
	var fs: int = rtl.get_theme_font_size("normal_font_size")
	var x := f.get_string_size(plain.substr(lr.x, maxi(0, k - lr.x)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return Vector2(x, float(rtl.get_line_offset(line)) + float(rtl.get_line_height(line)) * 0.5)

# Puntos (canvas) para arrastrar la tijera sobre [from, to) del bloque: dentro de la primera y la última letra.
static func drag_points(rtl: RichTextLabel, from: int, to: int) -> Array:
	var xf := rtl.get_global_transform_with_canvas()
	var a := char_local_pos(rtl, from) + Vector2(2.0, 0.0)
	var b := char_local_pos(rtl, maxi(from, to - 1))
	var plain := rtl.get_parsed_text()
	var f: Font = rtl.get_theme_font("normal_font")
	var fs: int = rtl.get_theme_font_size("normal_font_size")
	var w := f.get_string_size(plain.substr(maxi(from, to - 1), 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.x += maxf(1.0, w - 2.0)
	return [xf * a, xf * b]

static func preview(parsed: Dictionary, from: int, length: int) -> Dictionary:
	var sn := ClipRules.snap(parsed, from, length)
	var out := {"ok": bool(sn.ok), "err": String(sn.err), "from": int(sn.from), "to": int(sn.to), "text": String(sn.text),
		"tramo": "", "tags": [], "ents": [], "frac": 0.0}
	if sn.ok:
		var inh := ClipRules.inherit(parsed, int(sn.from), int(sn.to))
		out.tramo = inh.tramo
		out.tags = inh.tags
		out.ents = inh.ents
		out.frac = inh.frac
	return out
