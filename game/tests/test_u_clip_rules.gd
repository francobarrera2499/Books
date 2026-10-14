# Unit: core/text/clip_rules.gd (CORE-EXPEDIENTE). §5.1 / GDD§8.1 / GDD_v3 §6.2: snap, oración (salvo un bloque corto,
# ≤15 palabras en total, que se recorta entero), 15 palabras (mas_de_15), herencia ≥50 % con empate.
extends "res://tests/test_base.gd"

const M = preload("res://core/text/markup.gd")
const CR = preload("res://core/text/clip_rules.gd")

func _pp(src: String) -> Dictionary:
	return M.parse(src)

func _sel(p: Dictionary, needle: String, occurrence := 0) -> Array:
	var i := -1
	for k in occurrence + 1:
		i = p.plain.find(needle, i + 1)
	return [i, needle.length()]

func test_snap_expands_to_whole_words():
	var p := _pp("Dos viajeros subieron por el sendero de la cascada.")
	var s := _sel(p, "ajeros subieron po")
	var r := CR.snap(p, s[0], s[1])
	ok(r.ok, str(r))
	eq(r.text, "viajeros subieron por")
	eq(r.words, 3)
	eq(p.plain.substr(r.from, r.to - r.from), r.text)

func test_snap_trailing_punctuation_attached():
	var p := _pp("Dijo: «la cascada.» Luego calló.")
	var s := _sel(p, "casc")
	var r := CR.snap(p, s[0], s[1])
	eq(r.text, "cascada.»", "puntuación pegada al final")
	var s2 := _sel(p, "la casc")
	eq(CR.snap(p, s2[0], s2[1]).text, "la cascada.»")
	var s3 := _sel(p, "«la")
	eq(CR.snap(p, s3[0], s3[1]).text, "la", "la puntuación de apertura no entra")

func test_snap_comma_and_semicolon():
	var p := _pp("Uno, dos; tres.")
	var r := CR.snap(p, 0, 2)
	eq(r.text, "Uno,")
	var s := _sel(p, "do")
	eq(CR.snap(p, s[0], s[1]).text, "dos;")

func test_snap_empty():
	var p := _pp("Hola — «» mundo.")
	eq(CR.snap(p, 0, 0).err, "vacio", "largo 0")
	var s := _sel(p, " — «» ")
	eq(CR.snap(p, s[0], s[1]).err, "vacio", "sólo puntuación y espacios")
	no(CR.snap(p, 999, 5).ok, "fuera de rango")

const LONG := " Relleno uno dos tres cuatro cinco seis siete ocho nueve diez once doce."

func test_snap_cross_sentence():
	var p := _pp("Primera oración aquí. Segunda oración allá." + LONG)
	var s := _sel(p, "aquí. Segunda")
	var r := CR.snap(p, s[0], s[1])
	no(r.ok)
	eq(r.err, "cruza_oracion")
	var s2 := _sel(p, "aquí.")
	ok(CR.snap(p, s2[0], s2[1]).ok, "el punto propio no cruza")
	var s3 := _sel(p, "aquí. ")
	ok(CR.snap(p, s3[0], s3[1]).ok, "el espacio tras el punto tampoco")

func test_snap_newline_cuts():
	var p := _pp("línea uno\nlínea dos" + LONG)
	var s := _sel(p, "uno\nlínea")
	eq(CR.snap(p, s[0], s[1]).err, "cruza_oracion")

func test_snap_abbreviation_inside_ok():
	var p := _pp("El Dr. Watson y Mrs. Hudson lo vieron. Fin.")
	var s := _sel(p, "Dr. Watson y Mrs. Hudson lo")
	var r := CR.snap(p, s[0], s[1])
	ok(r.ok, str(r))
	eq(r.words, 6)

func test_snap_15_words():
	var w := PackedStringArray()
	for i in 45:
		w.append("p%d" % i)
	var p := _pp(" ".join(w) + ".")
	var all := CR.snap(p, 0, p.plain.length())
	eq(all.err, "mas_de_15")
	eq(all.words, 45)
	var fifteen := CR.snap(p, 0, p.plain.find("p14") + 3)
	ok(fifteen.ok, str(fifteen))
	eq(fifteen.words, 15)
	eq(CR.snap(p, 0, p.plain.find("p15") + 1).err, "mas_de_15")

# GDD_v3 §2.4 (T4): un bloque corto (una tarjeta de examen de ≤15 palabras) se recorta entero aunque tenga dos oraciones.
func test_short_block_crosses_sentences():
	var p := _pp("Está abierta. Yo no la abrí.")
	var r := CR.snap(p, 0, p.plain.length())
	ok(r.ok, str(r))
	eq(r.text, "Está abierta. Yo no la abrí.")
	var cl := CR.max_legal_clips(p)
	eq([cl[0].from, cl[0].to], [0, p.plain.length()], "el bloque entero es un recorte máximo")

func _clip(src: String, needle: String) -> Dictionary:
	var p := _pp(src)
	var s := _sel(p, needle)
	var r := CR.snap(p, s[0], s[1])
	return CR.inherit(p, r.from, r.to)

func test_inherit_full_tramo():
	var src := "{{#corniche a:cornisa_existe c:verdadero f:ruido x:EE09 d:1891-05-04 p:reichenbach e:reichenbach q:cita h:F.x w:dudoso|Hay una [[cornisa]] arriba.}} Otra cosa."
	var h := _clip(src, "Hay una cornisa arriba.")
	eq(h.tramo, "corniche")
	eq(h.tags, ["a:cornisa_existe", "c:verdadero", "d:1891-05-04", "f:ruido", "p:reichenbach", "x:EE09"], "q: h: w: no se heredan; ordenadas")
	eq(h.ents, ["cornisa", "reichenbach"])
	eq(h.date, "1891-05-04")
	eq(h.place, "reichenbach")
	near(h.frac, 1.0)

func test_inherit_half_threshold():
	# tramo de 4 palabras "uno dos tres cuatro" (19 chars); recortar "uno dos" (+ espacio) cubre < 0,5 del largo
	var src := "Antes {{#t a:x e:ent_e|uno dos tres cuatro}} y [[m1|mención]] después."
	var p := _pp(src)
	var t = p.tramos[0]
	var half_to: int = t.from + int(ceil((t.to - t.from) / 2.0))
	var h_ok := CR.inherit(p, t.from, half_to)
	ok(h_ok.frac >= 0.5)
	eq(h_ok.tags, ["a:x"], "≥ 0,5 hereda")
	var h_no := CR.inherit(p, t.from, half_to - 1)
	ok(h_no.frac < 0.5)
	eq(h_no.tags, [], "< 0,5 no hereda afirmaciones")
	eq(h_no.ents, ["ent_e"], "pero sí la e: del tramo ganador")
	eq(h_no.tramo, "t")
	var h_m := CR.inherit(p, p.plain.find("mención"), p.plain.find("mención") + 3)
	eq(h_m.ents, ["m1"], "mención que interseca")
	eq(h_m.tramo, "")

# playtest v3: la línea física (#fisica) hereda con ≥25 % («Papel crema grueso, 20 × 24 cm; escrito a máquina»)
func test_inherit_fisica_quarter():
	var src := "{{#fisica a:me_vigila_de_cerca e:papel_crema_grueso|Papel crema grueso, 20 × 24 cm; escrito a máquina (la «s» queda algo alzada, la «t» sale pálida); el borde de arriba, cortado a tijera.}}"
	var h := _clip(src, "Papel crema grueso, 20 × 24 cm; escrito a máquina")
	ok(h.frac < 0.5 and h.frac >= 0.25, "cubre entre 25 y 50 %% (%.2f)" % h.frac)
	eq(h.tags, ["a:me_vigila_de_cerca"], "y hereda: describe un solo objeto")
	ok(bool(h.inherited))
	var h2 := _clip(src, "Papel crema")
	eq(h2.tags, [], "dos palabras (<25 %) no")
	var src2 := "{{#otro a:x|Papel crema grueso, 20 × 24 cm; escrito a máquina (la «s» queda algo alzada, la «t» sale pálida); el borde de arriba, cortado a tijera.}}"
	eq(_clip(src2, "Papel crema grueso, 20 × 24 cm; escrito a máquina").tags, [], "otro tramo: sigue el 50 por ciento")

func test_inherit_winner_max_fraction():
	# A corto (2 palabras) totalmente cubierto gana sobre B largo parcialmente cubierto
	var src := "{{#a a:ga|uno dos}} {{#b a:gb|tres cuatro cinco seis siete ocho nueve diez}}."
	var p := _pp(src)
	var ta = p.tramos[0]
	var tb = p.tramos[1]
	var h := CR.inherit(p, ta.from, tb.from + 11)
	eq(h.tramo, "a")
	eq(h.tags, ["a:ga"])

func test_inherit_tie_lower_from():
	var src := "{{#a a:ga|uno dos}} {{#b a:gb|tres cu}}."
	var p := _pp(src)
	var ta = p.tramos[0]
	var tb = p.tramos[1]
	eq(ta.to - ta.from, tb.to - tb.from, "mismo largo")
	var h := CR.inherit(p, ta.from, tb.to)
	near(h.frac, 1.0)
	eq(h.tramo, "a", "empate -> menor from")
	eq(h.tags, ["a:ga"])

func test_inherit_no_tramos():
	var p := _pp("Texto con [[x|equis]] y nada más.")
	var h := CR.inherit(p, 0, p.plain.length())
	eq(h.tramo, "")
	eq(h.tags, [])
	eq(h.ents, ["x"])
	eq(h.date, "")

func test_max_legal_clips():
	var w := PackedStringArray()
	for i in 45:
		w.append("p%d" % i)
	var src := "Corta uno. " + " ".join(w) + ". Otra corta aquí."
	var p := _pp(src)
	var cl := CR.max_legal_clips(p)
	eq(cl.size(), 1 + 31 + 1, "1 + ventanas de 15 en 45 palabras + 1")
	eq(p.plain.substr(cl[0].from, cl[0].to - cl[0].from), "Corta uno.")
	for c in cl:
		var r := CR.snap(p, c.from, c.to - c.from)
		ok(r.ok, "todo recorte máximo es legal: " + str(c))
		eq([r.from, r.to], [c.from, c.to], "y es punto fijo de snap")

func test_d05_fixture_marque():
	var repo = fixture_repo()
	var p: Dictionary = repo.parsed("D05", "p1")
	var s := _sel(p, "En la pared, «une marque récente».")
	var r := CR.snap(p, s[0], s[1])
	ok(r.ok, str(r))
	var h := CR.inherit(p, r.from, r.to)
	eq(h.tramo, "marque")
	has(h.tags, "a:raspadura_registrada")
	has(h.ents, "pared")
	has(h.ents, "raspadura")

# GDD_v3 §6.2 / §7.2 P1: un recorte de 15 palabras tiene que poder heredar las etiquetas de cualquier tramo etiquetado,
# así que un tramo con a:/c: de 31 palabras es error de datos (Markup.lint); 30 se admite, y sin etiquetas hasta 40.
func test_tagged_tramo_max_30_words_lint():
	var w := func(n: int) -> String: return " ".join(PackedStringArray(range(n).map(func(i): return "palabra")))
	var e31 := M.lint("{{#t a:x|%s.}}" % w.call(31))
	ok(str(e31).contains("31 palabras con etiquetas a:/c:"), str(e31))
	ok(str(M.lint("{{#t c:verdadero|%s.}}" % w.call(31))).contains("con etiquetas a:/c:"), "también c:")
	eq(M.lint("{{#t a:x|%s.}}" % w.call(30)), [], "30 palabras etiquetadas: legal")
	eq(M.lint("{{#t e:roca|%s.}}" % w.call(31)), [], "sin a:/c:, el tope es el general")
	# y con 30, una ventana legal de 15 hereda (≥50 %)
	var p := _pp("{{#t a:x|%s.}}" % w.call(30))
	var best := 0.0
	for c in CR.max_legal_clips(p):
		best = maxf(best, float(CR.inherit(p, int(c.from), int(c.to)).frac))
	ok(best >= 0.5, "ventana de 15 sobre 30 palabras hereda: %.2f" % best)
