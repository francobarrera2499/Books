# Unit: core/text/markup.gd (W1-ENG). §4.3: tramos, menciones, estilos, escapes, oraciones, palabras, lint.
extends "res://tests/test_base.gd"

const M = preload("res://core/text/markup.gd")

const NAMES := {"watson": "el doctor Watson", "roca": "la roca", "cornisa": "la cornisa", "mycroft": "Mycroft Holmes"}

func _p(src: String, ctx := {}) -> Dictionary:
	return M.parse(src, ctx)

func _sents(src: String) -> Array:
	var p := _p(src)
	var out: Array = []
	for s in p.sentences:
		out.append(p.plain.substr(s[0], s[1] - s[0]))
	return out

func _words(src: String) -> Array:
	var p := _p(src)
	var out: Array = []
	for w in p.words:
		out.append(p.plain.substr(w[0], w[1] - w[0]))
	return out

func _has_err(errs: Array, sub: String) -> bool:
	for e in errs:
		if String(e).contains(sub):
			return true
	return false

# 1
func test_plain_text():
	var p := _p("Texto sin marcas.")
	eq(p.plain, "Texto sin marcas.")
	eq(p.errors, [])
	eq(p.tramos, [])
	eq(p.mentions, [])
	eq(p.styles, [])

# 2
func test_tramo_id_tags():
	var p := _p("Antes. {{#corniche a:cornisa_existe e:reichenbach d:1891-05-04|Hay una cornisa.}} Después.")
	eq(p.errors, [])
	eq(p.tramos.size(), 1)
	var t = p.tramos[0]
	eq(t.id, "corniche")
	eq(p.plain.substr(t.from, t.to - t.from), "Hay una cornisa.")
	eq(t.tags.a, ["cornisa_existe"])
	eq(t.tags.e, ["reichenbach"])
	eq(t.tags.d, ["1891-05-04"])
	eq(t.tags.keys().size(), 10, "todas las claves de prefijo")
	eq(t.tags.x, [])

# 3
func test_tramo_without_id():
	var p := _p("{{a:x c:y|Uno dos.}}")
	eq(p.tramos[0].id, "")
	eq(p.tramos[0].tags.c, ["y"])
	eq(p.plain, "Uno dos.")

# 4
func test_tramo_only_id():
	var p := _p("{{#pastor|Un pastor oyó caer piedras.}}")
	eq(p.errors, [])
	eq(p.tramos[0].id, "pastor")
	eq(p.tramos[0].tags.a, [])

# 5
func test_repeated_prefix():
	var p := _p("{{a:uno a:dos a:uno|Texto.}}")
	eq(p.tramos[0].tags.a, ["uno", "dos"], "sin duplicados, en orden")

# 6
func test_mention_with_surface():
	var p := _p("Vio la [[reichenbach|cascada del Reichenbach]] ayer.")
	eq(p.plain, "Vio la cascada del Reichenbach ayer.")
	eq(p.mentions.size(), 1)
	var m = p.mentions[0]
	eq(m.ent, "reichenbach")
	eq(p.plain.substr(m.from, m.to - m.from), "cascada del Reichenbach")

# 7
func test_mention_default_surface_from_names():
	var p := _p("Habló con [[watson]].", {"names": NAMES})
	eq(p.plain, "Habló con el doctor Watson.")
	eq(p.mentions[0].to - p.mentions[0].from, "el doctor Watson".length())

# 8
func test_mention_without_names_uses_id():
	eq(_p("Ver [[roca]].").plain, "Ver roca.")

# 9
func test_act_replacement():
	var p := _p("[[@act|Asiento 214]]: nada.", {"act": "act.17"})
	eq(p.mentions[0].ent, "act.17")
	eq(p.plain, "Asiento 214: nada.")
	eq(_p("[[@act|x]]").mentions[0].ent, "@act", "sin ctx.act queda @act")

# 10
func test_simple_styles():
	var p := _p("<i>uno</i> <b>dos</b> <sc>tres</sc> <del>cuatro</del>")
	eq(p.plain, "uno dos tres cuatro")
	eq(p.errors, [])
	var kinds: Array = []
	for s in p.styles:
		kinds.append(s.kind)
		ok(p.plain.substr(s.from, s.to - s.from) in ["uno", "dos", "tres", "cuatro"])
	eq(kinds, ["i", "b", "sc", "del"])

# 11
func test_font_and_ink():
	var p := _p("<f=manuscrito>nota</f> <ink=lapiz>gris</ink>")
	eq(p.styles[0], {"from": 0, "to": 4, "kind": "font", "val": "manuscrito"})
	eq(p.styles[1], {"from": 5, "to": 9, "kind": "ink", "val": "lapiz"})

# 12
func test_nested_styles_outer_first():
	var p := _p("<f=manuscrito><ink=lapiz>marca</ink></f>")
	eq(p.styles.size(), 2)
	eq(p.styles[0].kind, "font", "exterior primero")
	eq(p.styles[1].kind, "ink")
	eq([p.styles[0].from, p.styles[0].to], [0, 5])
	eq([p.styles[1].from, p.styles[1].to], [0, 5])

# 13
func test_rasante():
	var p := _p("Hoja. <rasante>surcos del papel</rasante>")
	eq(p.styles[0].kind, "rasante")
	eq(p.plain.substr(p.styles[0].from, p.styles[0].to - p.styles[0].from), "surcos del papel")

# 14
func test_escapes():
	var p := _p("a\\{b\\}c\\[d\\]e\\<f\\\\g")
	eq(p.plain, "a{b}c[d]e<f\\g")
	eq(p.errors, [])

# 15
func test_escaped_dot_does_not_break():
	eq(_sents("Págs\\. 3 y 4 del tomo. Fin.").size(), 2)
	eq(_sents("Págs. 3 y 4 del tomo. Fin.").size(), 3, "sin escape sí corta")

# 16
func test_unknown_escape_error():
	var p := _p("a\\qb")
	ok(_has_err(p.errors, "escape desconocido"))
	eq(p.plain, "a\\qb")

# 17
func test_newline_breaks_sentence():
	var s := _sents("Primera línea sin punto\nsegunda línea")
	eq(s, ["Primera línea sin punto", "segunda línea"])
	ok(_p("a\nb").plain.contains("\n"))

# 18
func test_basic_sentences():
	eq(_sents("Uno. ¿Dos? ¡Tres! Cuatro"), ["Uno.", "¿Dos?", "¡Tres!", "Cuatro"])

# 19
func test_abbreviations():
	eq(_sents("El Dr. Watson llegó con Mrs. Hudson. Luego se fue."), ["El Dr. Watson llegó con Mrs. Hudson.", "Luego se fue."])
	eq(_sents("Vol. VI, cap. 3. Fin.").size(), 3, "«Vol.» con mayúscula no está en la lista")
	eq(_sents("vol. VI, cap. 3. Fin.").size(), 2)
	eq(_sents("Fin.", ).size(), 1)

# 20
func test_initials():
	eq(_sents("Escribir a E. L., Holywell Street. Gracias."), ["Escribir a E. L., Holywell Street.", "Gracias."])
	eq(_sents("Firmado J. H. Watson. Nada más.").size(), 2)

# 21
func test_closing_quotes_stay():
	eq(_sents("Dijo: «Hola.» Adiós."), ["Dijo: «Hola.»", "Adiós."])
	eq(_sents("(Así fue.) Luego."), ["(Así fue.)", "Luego."])

# 22
func test_ellipsis():
	eq(_sents("Pues… nada. Y bien."), ["Pues…", "nada.", "Y bien."])
	eq(_sents("Y entonces...").size(), 1)

# 23
func test_decimal_dot_no_break():
	eq(_sents("Pesaba 3.5 libras. Sí.").size(), 2)

# 24
func test_words_internal_apostrophe_hyphen():
	eq(_words("on n'a retrouvé l'on anglo-sajón 1891, ¿qué?"), ["on", "n'a", "retrouvé", "l'on", "anglo-sajón", "1891", "qué"])
	eq(_words("— «Hola» —dijo—."), ["Hola", "dijo"])
	eq(_words("--- ... «»"), [])

# 25
func test_mention_inside_tramo_and_style():
	var p := _p("{{#t a:x|La <i>[[roca|roca]]</i> cayó.}}")
	eq(p.errors, [])
	eq(p.plain, "La roca cayó.")
	eq(p.mentions[0].from, 3)
	eq(p.styles[0].from, 3)
	eq(p.styles[0].to, 7)
	eq([p.tramos[0].from, p.tramos[0].to], [0, 13])

# 26
func test_structural_errors():
	ok(_has_err(_p("{{#a x:y|sin cerrar").errors, "sin cerrar"), "tramo sin cerrar")
	ok(_has_err(_p("[[roca sin cerrar").errors, "mención sin cerrar"))
	ok(_has_err(_p("<i>abierto").errors, "sin cerrar"), "estilo sin cerrar")
	ok(_has_err(_p("<i>a<b>b</i></b>").errors, "sin pareja"), "cierre cruzado")
	ok(_has_err(_p("{{a:x|uno {{a:y|dos}} tres}}").errors, "anidado"))
	ok(_has_err(_p("texto}} suelto").errors, "sin apertura"))
	ok(_has_err(_p("texto]] suelto").errors, "sin apertura"))
	ok(_has_err(_p("<u>x</u>").errors, "estilo desconocido"))
	ok(_has_err(_p("<f=comic>x</f>").errors, "estilo desconocido"), "ranura desconocida")
	ok(_has_err(_p("<ink=verde>x</ink>").errors, "estilo desconocido"), "tinta desconocida")

# 27
func test_tag_errors():
	ok(_has_err(_p("{{z:x|t.}}").errors, "prefijo desconocido"))
	ok(_has_err(_p("{{suelto|t.}}").errors, "mal formada"))
	ok(_has_err(_p("{{a:|t.}}").errors, "sin valor"))
	ok(_has_err(_p("{{#|t.}}").errors, "id de tramo vacío"))
	ok(_has_err(_p("{{a:x t.}}").errors, "sin separador"))

# 28
func test_placeholders():
	ok(_has_err(_p("Asiento ${seat}.").errors, "placeholder sin resolver"))
	eq(_p("Asiento ${seat}.", {"allow_placeholders": true}).errors, [])
	eq(M.fill("Asiento ${seat}, ${x}.", {"seat": 214.0}), "Asiento 214, ${x}.")
	eq(M.fill("sin nada", {"a": 1}), "sin nada")
	eq(M.fill("${a}${a}", {"a": "b"}), "bb")
	eq(M.fill("${l}", {"l": ["a", "b"]}), "a, b")
	eq(_p(M.fill("[[@act|asiento ${seat}]]", {"seat": 7})).plain, "asiento 7")

# 29
func test_lint_rules():
	ok(_has_err(M.lint("{{#t a:x|Uno. Dos.}}"), "cruza oraciones"))
	var long_t := "{{#largo a:x|" + " ".join(PackedStringArray(range(41).map(func(i): return "palabra"))) + ".}}"
	ok(_has_err(M.lint(long_t), "41 palabras"))
	ok(_has_err(M.lint("Un glifo † prohibido."), "glifo prohibido"))
	ok(_has_err(M.lint("{{#a x:1|Uno.}} {{#a x:2|Dos.}}"), "duplicado"))
	ok(_has_err(M.lint("{{d:1891-5-4|Fecha.}}"), "fecha d: inválida"))
	ok(_has_err(M.lint("{{#v|}}"), "vacío"))
	eq(M.lint("{{#t a:x|Uno dos tres.}} Otra."), [])

# 30
func test_lint_entities():
	var ents := {"roca": {}, "watson": {}}
	ok(_has_err(M.lint("Ver [[pared]].", {"entities": ents}), "inexistente"))
	ok(_has_err(M.lint("{{e:pared|Ver.}}", {"entities": ents}), "e:pared inexistente"))
	ok(_has_err(M.lint("{{p:lugar_raro|Ver.}}", {"entities": ents}), "p:lugar_raro inexistente"))
	eq(M.lint("Ver [[roca]] y [[@act|esto]] con {{e:watson|él.}}", {"entities": ents}), [])

# 31
func test_lint_article_duplicate():
	ok(_has_err(M.lint("Apoyado contra la [[roca]].", {"names": NAMES}), "artículo duplicado"))
	ok(_has_err(M.lint("Hay una [[cornisa]] arriba.", {"names": NAMES}), "artículo duplicado"))
	eq(M.lint("Apoyado contra [[roca]] y [[cornisa|una cornisa]].", {"names": NAMES}), [])
	eq(M.lint("Escribió a [[mycroft]].", {"names": NAMES}), [], "nombre sin artículo")

# 32
func test_literal_brackets_and_lt():
	var p := _p("a < b, {x} y [y] 3<4")
	eq(p.plain, "a < b, {x} y [y] 3<4")
	eq(p.errors, [])

# 33
func test_escape_roundtrip():
	var s := "Texto {raro} con [[x]] y <i> y \\ barra."
	var p := _p(M.escape(s))
	eq(p.plain, s)
	eq(p.errors, [])
	eq(p.mentions, [])

# 34
func test_deterministic():
	var src := "{{#a a:x e:y|La [[roca]] <i>cayó</i>.}} Fin\\. sí.\n<ink=roja>Dele.</ink>"
	eq(_p(src, {"names": NAMES}), _p(src, {"names": NAMES}))

# 35
func test_architecture_d05_example():
	var src := "MEIRINGEN, 5 de mayo. — {{#viajeros d:1891-05-04 p:reichenbach|Dos viajeros ingleses subieron ayer por el sendero de la [[reichenbach|cascada del Reichenbach]]; uno solo volvió a la posada.}} {{#pastor|Un pastor oyó caer piedras «à la tombée de la nuit».}}\n<f=manuscrito><ink=lapiz>marque = marca, raspadura</ink></f>"
	var p := _p(src)
	eq(p.errors, [])
	eq(p.tramos.size(), 2)
	eq(p.tramos[0].tags.p, ["reichenbach"])
	eq(p.sentences.size(), 4)
	eq(M.lint(src), [])

# 36
func test_custom_abbrev_ctx():
	eq(M.parse("Lo dijo Cnel. Moran. Fin.").sentences.size(), 2)
	eq(M.parse("Lo dijo Xyz. Moran. Fin.", {"abbrev": ["Xyz."]}).sentences.size(), 2)
	eq(M.parse("Lo dijo Cnel. Moran. Fin.", {"abbrev": []}).sentences.size(), 3)

# 37
func test_escaped_bracket_inside_mention():
	var bs := char(92)
	var p := _p("Ver [[x|corchete " + bs + "]]] fin.")
	eq(p.errors, [])
	eq(p.plain, "Ver corchete ] fin.")
	eq(p.mentions[0].to - p.mentions[0].from, "corchete ]".length())
	eq(_p("[[x|a" + bs + "]b]] c").plain, "a]b c")

# 38
func test_placeholders_in_mentions_and_tags():
	ok(_has_err(_p("[[@act|asiento ${seat}]] y nada.").errors, "placeholder sin resolver"), "superficie estática")
	ok(_has_err(_p("{{#a a:ancla_${ch}|Texto.}}").errors, "placeholder sin resolver"), "etiqueta estática")
	eq(_p("{{#a a:ancla_${ch}|[[@act|asiento ${seat}]].}}", {"allow_placeholders": true}).errors, [], "plantilla runtime")

func test_contract_word_boundary():
	var pairs := [["de el ", "del "], ["De el ", "Del "], ["a el ", "al "], ["A el ", "Al "], ["..", "."]]
	eq(M.contract("A propósito de el Journal..", pairs), "A propósito del Journal.")
	eq(M.contract("para el doctor, puede el mayor, toca el crespón", pairs), "para el doctor, puede el mayor, toca el crespón")
	eq(M.contract("—a el fondo; (de el otro)", pairs), "—al fondo; (del otro)")
	eq(M.contract("a el a el", pairs), "al a el", "el segundo «a el» no termina en espacio")
	eq(M.contract("sin pares", null), "sin pares")
