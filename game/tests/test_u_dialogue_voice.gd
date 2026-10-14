# Voz de los diálogos y escenas (GDD_v2 §A.3, §F.3 TEXTOS-DIÁLOGOS). Dueño: CONTENIDO (GDD_v3 §7.2 P6; antes TEXTOS-DIÁLOGOS).
# - Texto visible de data/dialogue/*.json y data/scenes/*.json: sin vosotros, sin peninsularismos, sin latinismos ni
#   jerga de corrector sin explicar, y sin los términos viejos del glosario §A.1 que el jugador no entendía.
# - Los tics de personaje se conservan: el «sir» contable de Mrs. Hudson crece con HB6 (hudson_cerrada), los adjetivos
#   repetidos de Harris van en tramos a:rasgo_de_harris (GDD_v3 §1.8; también el #tic de las seis tarjetas NC.*), «Le ahorraré el trabajo» de Mycroft, «Hum» del librero, «jefe»
#   y «la vieja tarifa» de Wiggins, y «en debida forma» de Pell a lo sumo una vez por escena.
# - Disparadores de la v2: el bibliotecario nombra Somerset House (U5, §B.3) sin etiquetas de conclusión, y
#   papel_crema_grueso es alias de papel_corto en Mycroft, Crane y el portero (§C.5.4).
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Markup = preload("res://core/text/markup.gd")

# [patrón, sensible a mayúsculas]. Se buscan en el texto plano (sin marcas, sin ids, sin etiquetas).
const BANNED := [
	["\\bvosotr[oa]s\\b|\\bvuestr[oa]s?\\b|\\bos\\b", false],
	["\\bvale\\b[.!,]", false], ["\\bcog(e|er|i|ió|ía)\\w*", false], ["\\bacera", false], ["\\bordenador", false],
	["\\bgafas\\b", false], ["\\bzumo\\b", false], ["\\bpatatas?\\b", false], ["\\bchaval", false], ["\\benfad", false],
	["\\baparc", false], ["\\bconduc(ir|e|ía)\\b", false], ["\\bmóvil\\b", false], ["\\bescaparate", false], ["\\bdeprisa\\b", false],
	["in extenso|ad cautelam|ad fontes|bona fide|tempus fugit|verba volant", false], ["\\bsic\\b", false],
	["\\bdele\\b|\\bvéase\\b|\\bgalerada|\\bcajista|\\bpliego", false],
	["\\berratas?\\b|\\bprocurador|\\bujier|Sala de Forasteros|libro mayor|pasad[oa]s? en limpio|\\bpapeleta|agente de fincas", false],
	# RAE vigente: «solo», «este», «ese», «aquel» sin tilde (los límites de palabra, a mano: \b no ve letras con tilde)
	["(?<![A-Za-zÀ-ÿ])(sólo|[Éé]st[aeo]s?|[Éé]s[aeo]s?|[Aa]quél(l[aeo]s?)?)(?![A-Za-zÀ-ÿ])", false],
]

const MRS_HUDSON_PAIRS := [["hb6.cerrada", "hb6"], ["holmes.cerrada", "holmes"], ["tipo.persona.cerrada", "tipo.persona"],
	["tipo.cerrada", "tipo.otro"], ["gen.cerrada", "gen.2"]]

func before_each() -> void:
	Fakes.install()

func after_each() -> void:
	Fakes.uninstall()

func _plain(text: String) -> String:
	return String(Markup.parse(text, {"allow_placeholders": true}).get("plain", ""))

# Textos visibles: [ref, texto]. Diálogos: label, intro, closing, ask_phrase y text de cada línea. Escenas: text, tpl,
# fallback, replace y append de variantes.
func _visible_texts() -> Array:
	var r = repo()
	var out: Array = []
	var cids: Array = r.dialogues().keys()
	cids.sort()
	for cid in cids:
		var dl: Dictionary = r.dialogue(cid)
		for k in ["label", "intro", "closing"]:
			if typeof(dl.get(k)) == TYPE_STRING:
				out.append(["dialogue/%s.%s" % [cid, k], String(dl[k])])
		var ph = dl.get("ask_phrase", {})
		if typeof(ph) == TYPE_DICTIONARY:
			for k in ph:
				out.append(["dialogue/%s.ask_phrase.%s" % [cid, k], String(ph[k])])
		for ln in dl.get("lines", []):
			out.append(["dialogue/%s.%s" % [cid, ln.get("id", "?")], String(ln.get("text", ""))])
	var sids: Array = r.scenes().keys()
	sids.sort()
	for sid in sids:
		var sc: Dictionary = r.scene(sid)
		var lines: Array = sc.get("lines", []).duplicate()
		for v in sc.get("variants", []):
			lines.append_array(v.get("append", []))
			var rep = v.get("replace", {})
			if typeof(rep) == TYPE_DICTIONARY:
				for lid in rep:
					out.append(["scenes/%s.%s (variante)" % [sid, lid], String(rep[lid])])
		for ln in lines:
			if ln.has("text"):
				out.append(["scenes/%s.%s" % [sid, ln.get("id", "?")], String(ln.text)])
			if typeof(ln.get("tpl")) == TYPE_DICTIONARY:
				for code in ln.tpl:
					out.append(["scenes/%s.%s_%s" % [sid, ln.get("id", "?"), code], String(ln.tpl[code])])
			if ln.has("fallback"):
				out.append(["scenes/%s.%s_fallback" % [sid, ln.get("id", "?")], String(ln.fallback)])
	return out

func test_no_peninsular_latin_or_old_terms():
	var rxs: Array = []
	for b in BANNED:
		var rx := RegEx.new()
		# (*UCP): \b y \w con letras con tilde y ñ («años» no contiene «os»)
		rx.compile("(*UCP)" + ("" if b[1] else "(?i)") + String(b[0]))
		rxs.append(rx)
	var texts := _visible_texts()
	ok(texts.size() > 300, "hay textos de diálogo y escena (%d)" % texts.size())
	var bad: Array = []
	for t in texts:
		var p := _plain(String(t[1]))
		for rx in rxs:
			var m: RegExMatch = rx.search(p)
			if m != null:
				bad.append("%s: «%s»" % [t[0], m.get_string(0)])
	eq(bad, [], "estilo v2 (GDD_v2 §A.3)")

func _hits(s: String) -> bool:
	for b in BANNED:
		var rx := RegEx.new()
		rx.compile("(*UCP)" + ("" if b[1] else "(?i)") + String(b[0]))
		if rx.search(s) != null:
			return true
	return false

func test_patterns_precise():
	for bad in ["Os lo ruego.", "Vale, señor.", "Sólo eso.", "Ésta es la casa.", "Ese es aquél.", "la acera de enfrente",
			"una errata", "el procurador", "Sala de Forasteros", "in extenso", "Bona fide", "seis asientos pasados en limpio"]:
		ok(_hits(bad), "detecta: " + bad)
	for good in ["Diecinueve años en esta Sala.", "Ese vale plata.", "Esta es una casa decente.", "Solo eso.", "aquel año",
			"la vereda de enfrente", "Lo copié entero.", "el asiento 214", "Ellos y nosotros."]:
		no(_hits(good), "no es hallazgo: " + good)

# sir por oración de una línea de Mrs. Hudson.
func _sir_rate(text: String) -> float:
	var pt: Dictionary = Markup.parse(text, {"allow_placeholders": true})
	var n := maxi(1, (pt.get("sentences", []) as Array).size())
	var rx := RegEx.new()
	rx.compile("\\bsir\\b")
	return float(rx.search_all(String(pt.plain)).size()) / float(n)

func _line(cid: String, lid: String) -> Dictionary:
	for ln in repo().dialogue(cid).get("lines", []):
		if String(ln.get("id", "")) == lid:
			return ln
	return {}

func test_mrs_hudson_sir_grows_with_hb6():
	for pr in MRS_HUDSON_PAIRS:
		var closed := _line("mrs_hudson", pr[0])
		var open := _line("mrs_hudson", pr[1])
		ok(not closed.is_empty() and not open.is_empty(), "existen %s y %s" % pr)
		ok(_sir_rate(String(closed.get("text", ""))) > _sir_rate(String(open.get("text", ""))), "más «sir» por oración en %s que en %s" % pr)
	var hb6_closed := _sir_rate(String(_line("mrs_hudson", "hb6.cerrada").get("text", "")))
	for ln in repo().dialogue("mrs_hudson").get("lines", []):
		if String(ln.get("layer", "")) == "generica" and (ln.get("when", {}) as Dictionary).is_empty():
			ok(hb6_closed > _sir_rate(String(ln.get("text", ""))), "hb6.cerrada dobla los «sir» de la genérica " + String(ln.id))
	# HC05: la variante hudson_cerrada sólo dobla los «sir» y conserva los tramos
	var sc: Dictionary = repo().scene("HC05")
	var base := {}
	for ln in sc.get("lines", []):
		base[String(ln.id)] = String(ln.get("text", ""))
	var n := 0
	for v in sc.get("variants", []):
		if str(v.get("when", {})).contains("hudson_cerrada"):
			for lid in v.get("replace", {}):
				n += 1
				ok(_sir_rate(String(v.replace[lid])) > _sir_rate(String(base.get(lid, ""))), "HC05.%s: más «sir» con hudson_cerrada" % lid)
	ok(n >= 3, "HC05 tiene sus tres variantes cerradas")
	# lo que dice con franqueza lleva al menos un «sir»
	for lid in ["mycroft_paga", "empleado", "watson", "parker", "baker_street"]:
		ok(_sir_rate(String(_line("mrs_hudson", lid).get("text", ""))) > 0.0, "«sir» en mrs_hudson." + lid)

func test_character_tics_kept():
	var r = repo()
	# Harris: los adjetivos repetidos, siempre dentro de un tramo a:rasgo_de_harris (GDD_v3 §1.8)
	var rep := RegEx.new()
	# «inteligente, inteligente», «a estos, a estos», «las dos cosas, las dos» (hasta tres palabras repetidas tras la coma)
	rep.compile("(*UCP)(?i)\\b((?:\\w+ ){0,2}\\w{3,})\\b[^.]*?, \\1\\b")
	for ref in [["M7", "inteligente"], ["M7", "exactitud"], ["PRO", "fresco"]]:
		var txt := ""
		for ln in r.scene(ref[0]).get("lines", []):
			if String(ln.id) == ref[1]:
				txt = String(ln.text)
		var pt: Dictionary = Markup.parse(txt, {})
		var found := false
		for tr in pt.tramos:
			var s := String(pt.plain).substr(int(tr.from), int(tr.to) - int(tr.from))
			if rep.search(s) != null and (tr.tags.get("a", []) as Array).has("rasgo_de_harris"):
				found = true
		ok(found, "adjetivo repetido en tramo a:rasgo_de_harris: %s.%s" % ref)
	# las tarjetas del cliente (GDD_v3 §3.2): cada una repite un adjetivo en su #tic
	for code in ["FINA", "GREE", "STUD", "SIGN", "SCAN", "TWIS"]:
		var tr2: Dictionary = r.doc_tramo("NC." + code, "tic")
		ok(not tr2.is_empty() and (tr2.get("tags", {}).get("a", []) as Array).has("rasgo_de_harris"), "NC.%s#tic con a:rasgo_de_harris" % code)
		if not tr2.is_empty():
			var pt2: Dictionary = r.parsed("NC." + code, String(tr2.part))
			ok(rep.search(String(pt2.plain).substr(int(tr2.from), int(tr2.to) - int(tr2.from))) != null, "NC.%s#tic repite un adjetivo" % code)
	# Mycroft
	var a := ""
	for ln in r.scene("HC06").lines:
		if String(ln.id) == "a":
			a = String(ln.text)
	ok(_plain(a).contains("Le ahorraré el trabajo"), "HC06 (a): «Le ahorraré el trabajo»")
	ok(_plain(String(r.dialogue("mycroft").get("closing", ""))).contains("Le ahorraré el trabajo"), "cierre de Mycroft")
	# Holmes disfrazado
	var hum := 0
	for ln in r.dialogue("librero").lines:
		if String(ln.text).contains("Hum"):
			hum += 1
	ok(hum >= 2, "el librero dice «Hum» (%d)" % hum)
	# Wiggins: «jefe» en casi todo lo que habla; «la vieja tarifa» en su línea
	var talk := 0
	var jefe := 0
	for ln in r.dialogue("wiggins").lines:
		talk += 1
		if String(ln.text).contains("jefe"):
			jefe += 1
	ok(float(jefe) / float(maxi(1, talk)) >= 0.9, "Wiggins dice «jefe» (%d de %d)" % [jefe, talk])
	ok(_plain(String(_line("wiggins", "vieja_tarifa").get("text", ""))).contains("vieja tarifa"), "«la vieja tarifa»")
	# Pell: «en debida forma» como mucho una vez por escena, y aparece
	var total := 0
	for sid in r.scenes():
		var k := 0
		for ln in r.scene(sid).get("lines", []):
			if String(ln.get("who", "")) == "pell":
				k += String(ln.get("text", "")).count("en debida forma")
		ok(k <= 1, "Pell: «en debida forma» una vez por escena (%s: %d)" % [sid, k])
		total += k
	ok(total >= 1, "Pell conserva su tic")
	# Mrs. Hudson: «sir», nunca «señor» como vocativo propio
	for ln in r.dialogue("mrs_hudson").lines:
		no(_plain(String(ln.text)).contains(", señor."), "Mrs. Hudson dice «sir»: " + String(ln.id))

func test_librarian_names_somerset_house():
	var r = repo()
	var st = Fakes.state(r, {"day": 1, "place": "L2"})
	for topic in ["testamento", "herencia", "bienes", "sucesion"]:
		var res: Dictionary = Dialogue.respond(st, r, "ujier", {"topic": topic, "ents": [topic], "kind": "concepto"})
		eq(String(res.get("id", "")), "testamento", "el bibliotecario contesta por " + topic)
	var ln := _line("ujier", "testamento")
	var pt: Dictionary = r.parse_text(String(ln.get("text", "")), {})
	var ents: Array = pt.mentions.map(func(m): return String(m.ent))
	has(ents, "somerset_house", "menciona somerset_house (U5)")
	eq(pt.tramos.size(), 0, "sin tramos ni etiquetas de conclusión: no es una pista marcada")
	eq(String(r.dialogue("ujier").get("label", "")), "el bibliotecario")

func test_papel_crema_grueso_alias():
	var r = repo()
	var st = Fakes.state(r, {"day": 8})
	eq(String(Dialogue.respond(st, r, "mycroft", {"topic": "papel_crema_grueso", "ents": ["papel_crema_grueso"], "kind": "objeto"}).get("id", "")), "maquina")
	eq(String(Dialogue.respond(st, r, "portero", {"topic": "papel_crema_grueso", "ents": ["papel_crema_grueso"], "kind": "objeto"}).get("id", "")), "papel")
	eq(String(Dialogue.respond(st, r, "crane", {"ents": [{"id": "papel_crema_grueso", "label": "papel crema grueso"}]}).get("id", "")), "ent.papel")
	eq(String(Dialogue.respond(st, r, "crane", {"ents": [{"id": "papel_corto", "label": "papel"}]}).get("id", "")), "ent.papel", "papel_corto sigue como alias")
