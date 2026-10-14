# Unit: core/data/schema.gd (CORE-EXPEDIENTE). Un caso válido (fixture data_min) y varios inválidos por dataset de §4.1
# (v3: dossier y corpus en vez de conclusiones; campos nuevos de los otros paquetes: docs.v3, nodos con aviso,
# latencia intrusion, escenas once, dialogue.donde).
extends "res://tests/test_base.gd"

const S = preload("res://core/data/schema.gd")
const J = preload("res://core/util/j.gd")

const FIX := "res://tests/fixtures/data_min/"
const FILES := {
	"fonts": "fonts.json", "audio": "audio.json", "ui_text": "ui_text/core.json", "lists": "lists.json",
	"entities": "entities/core.json", "canon_bible": "canon_bible.json", "docs": "docs/D05.json", "catalog": "catalog/noise.json",
	"schedule": "schedule.json", "dossier": "dossier.json", "corpus": "corpus.json", "reactions": "reactions/moran.json", "endings": "endings.json",
	"easter_eggs": "easter_eggs.json", "scenes": "scenes/M7.json", "dialogue": "dialogue/watson.json", "places": "places/L4.json",
	"plates": "plates/PRO.json", "map": "map.json", "fisica": "fisica.json",
}

func _load(ds: String):
	return J.parse_file(FIX + FILES[ds])

# Aplica fn a una copia profunda del fixture y exige que check informe un error que contenga `sub`.
func _bad(ds: String, fn: Callable, sub: String) -> void:
	var v = _load(ds).duplicate(true)
	fn.call(v)
	var errs := S.check(ds, v)
	var hit := false
	for e in errs:
		if String(e).contains(sub):
			hit = true
	ok(hit, "%s: se esperaba error con «%s»; obtuvo %s" % [ds, sub, str(errs)])

func test_all_datasets_covered():
	for ds in S.DATASETS:
		ok(FILES.has(ds), "fixture para " + ds)

func test_valid_fixtures():
	for ds in FILES:
		var v = _load(ds)
		ok(v != null, "carga " + FILES[ds])
		eq(S.check(ds, v), [], ds)
	for f in ["docs/D02.json", "docs/D03.json", "docs/D29b.json"]:
		eq(S.check("docs", J.parse_file(FIX + f)), [], f)
	for f in ["reactions/holmes.json", "reactions/mycroft.json", "reactions/respuestas.json"]:
		eq(S.check("reactions", J.parse_file(FIX + f)), [], f)
	eq(S.check("dialogue", J.parse_file(FIX + "dialogue/crane.json")), [])
	eq(S.check("places", J.parse_file(FIX + "places/L2.json")), [])

func test_unknown_dataset():
	ok(S.check("nada", {}).size() == 1)

func test_underscore_fields_ignored():
	var v = _load("docs")
	v["_nota"] = "libre"
	v.parts[0]["_x"] = 1
	eq(S.check("docs", v), [])

func test_fonts_audio_map_uitext():
	_bad("fonts", func(v): v.erase("slots"), "falta 'slots'")
	_bad("fonts", func(v): v.slots.imprenta.erase("file"), "falta 'file'")
	eq(S.check("audio", []).size(), 1)
	eq(S.check("map", "x").size(), 1)
	_bad("ui_text", func(v): v.text["n"] = 3, "se esperaba texto")
	_bad("ui_text", func(v): v.text["m"] = "{{a:x|sin cerrar", "sin cerrar")

func test_lists():
	_bad("lists", func(v): v.abbrev = "Sr.", "se esperaba lista")
	_bad("lists", func(v): v.report_cats = [{"cat": "x", "pregunta": [{"respuestas": []}]}], "falta 'q'")
	_bad("lists", func(v): v.medios[0].erase("ch"), "falta 'ch'")
	_bad("lists", func(v): v.diary.go.tags = ["sinprefijo"], "etiqueta mal formada")
	_bad("lists", func(v): v.assertions[0].phrase = "Mal {{a:x|", "sin cerrar")

func test_entities_canon_catalog():
	_bad("entities", func(v): v.entities[0].kind = "planeta", "no está en")
	_bad("entities", func(v): v.entities[1].erase("name"), "falta 'name'")
	_bad("entities", func(v): v.entities[2]["raro"] = 1, "campo desconocido 'raro'")
	_bad("canon_bible", func(v): v.facts[0].erase("knowable"), "falta 'knowable'")
	_bad("canon_bible", func(v): v.facts[0].event = "4-may-1891", "fecha AAAA-MM-DD")
	_bad("catalog", func(v): v.noise[0].erase("label"), "falta 'label'")

func test_docs():
	_bad("docs", func(v): v.erase("words"), "falta 'words'")
	_bad("docs", func(v): v["class"] = "X", "no está en")
	_bad("docs", func(v): v.copies[0].via = "taxi", "no está en")
	_bad("docs", func(v): v.copies[0].from = "11.Z", "TimeKey inválido")
	_bad("docs", func(v): v.copies = [], "mínimo 1")
	_bad("docs", func(v): v.parts[0].text = "{{#x a:y|sin cerrar", "sin cerrar")
	_bad("docs", func(v): v.parts[0].text = "Uno {{#t a:x|cruza. Dos}} fin.", "cruza oraciones")
	_bad("docs", func(v): v["foo"] = 1, "campo desconocido 'foo'")
	_bad("docs", func(v): v.font = "comic", "no está en")
	_bad("docs", func(v): v.paper_mm = [1, 2, 3], "máximo 2")
	_bad("docs", func(v): v.parts[0]["when"] = {"lluvia": 1}, "átomo desconocido")
	_bad("docs", func(v): v.parts.append({"id": "p2", "text": "{{#corniche a:z|Otra.}}"}), "tramo #corniche duplicado")
	_bad("docs", func(v): v.copies.append(v.copies[0].duplicate()), "ejemplar D05@BM duplicado")

func test_schedule():
	_bad("schedule", func(v): v.days[0].erase("date"), "falta 'date'")
	_bad("schedule", func(v): v.places.L2.areas.sala.open[0].slots = ["Q"], "franja desconocida")
	_bad("schedule", func(v): v.places.L4.areas.consulta.needs = {"lluvia": 1}, "átomo desconocido")
	_bad("schedule", func(v): v.reports[0].tk = "dos", "TimeKey inválido")
	_bad("schedule", func(v): v.places.L1.areas.buhardilla.open[0].days = "todos", "no coincide")

# GDD_v3 §1.7: reglas del esquema del Expediente.
func test_dossier():
	_bad("dossier", func(v): v.preguntas[0].invariante = "rara", "no está en")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].grupos.pop_back(), "mínimo 2")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].rutas[0].frags.pop_back(), "mínimo 2")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].rutas[0].frags.append({"ref": "D05#corniche"}), "máximo 2")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].rutas[0].deps = "magia", "no está en")
	_bad("dossier", func(v): v.preguntas.append(v.preguntas[0].duplicate(true)), "duplicada")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].principal = false, "exactamente una variante principal")
	_bad("dossier", func(v): v.preguntas[0].nace[0]["inicio"] = "prologo", "exactamente un disparador")
	_bad("dossier", func(v): v.preguntas[0].nace = [{"llega": "voz:C", "origen": "o"}], "voz:A | voz:B")
	_bad("dossier", func(v): v.preguntas[0].nace = [{"tinta": "Q99", "origen": "o"}], "Q99 no existe")
	_bad("dossier", func(v): v.preguntas[0].variantes[0].rutas[0].frags[0].ref = "M:D05", "refs M: retiradas")
	_bad("dossier", func(v): v.preguntas[0].acepta = ["planeta"], "no está en")
	_bad("corpus", func(v): v.erase("inactivas"), "falta 'inactivas'")

# Campos nuevos que la v3 reparte entre paquetes (el esquema es de CORE).
func test_v3_fields_of_other_packages():
	var d = _load("docs").duplicate(true)
	d["v3"] = {"ficha": {"trata": "a", "cuando": "b", "por_que": "c"}, "nota_cliente": "NC.FINA", "marcas": [{"parte": "p1", "tramo": "corniche"}],
		"margen": [{"doc": "D01N", "tramo": "fina_fo", "junto_a": {"parte": "p1", "tramo": "corniche"}}]}
	eq(S.check("docs", d), [], "docs.v3")
	d.v3.ficha.erase("cuando")
	ok(" ".join(PackedStringArray(S.check("docs", d))).contains("falta 'cuando'"), str(S.check("docs", d)))
	var pl = _load("places").duplicate(true)
	pl.nodes[0]["aviso"] = "HA5"
	eq(S.check("places", pl), [], "nodo con aviso")
	var r = _load("reactions").duplicate(true)
	r.reactions[0].latencia.tipo = "intrusion"
	r.reactions[0]["relacion"] = [{"si": {"channel": "K-T"}, "copias": ["D23@L1"]}]
	eq(S.check("reactions", r), [], "latencia intrusion y relacion")
	var sc = _load("scenes").duplicate(true)
	sc["once"] = true
	eq(S.check("scenes", sc), [], "escena once")
	var dl = _load("dialogue").duplicate(true)
	dl["donde"] = [{"id": "donde.diarios", "frase": "¿Dónde consigo diarios viejos?", "requiere": [], "texto": "En el Museo.", "revela": "L2"}]
	eq(S.check("dialogue", dl), [], "dialogue.donde")

# GDD_v3 §6.2: un examen con etiquetas a:/c: mide ≤30 palabras.
func test_tagged_exam_max_30_words():
	var pl = _load("places").duplicate(true)
	pl.nodes[0]["tags"] = ["a:x"]
	pl.nodes[0]["examine"] = " ".join(PackedStringArray(range(31).map(func(i): return "palabra")))+ "."
	ok(str(S.check("places", pl)).contains("31 palabras con etiquetas"), str(S.check("places", pl)))

func test_reactions():
	_bad("reactions", func(v): v.reactions[0].tipo = "rara", "no está en")
	_bad("reactions", func(v): v.reactions[0].variante_blanda = null, "corta sin variante_blanda")
	_bad("reactions", func(v): v.reactions[0].efecto[0].op = "explotar", "no está en")
	_bad("reactions", func(v): v.reactions[0].condiciones = {"lluvia": 1}, "átomo desconocido")
	_bad("reactions", func(v): v.reactions[0].latencia.tipo = "pronto", "no está en")
	_bad("reactions", func(v): v.reactions[0].rastro[0].tags = ["tirador"], "etiqueta mal formada")
	_bad("reactions", func(v): v.reactions[0].erase("disparador"), "falta 'disparador'")

func test_endings_eggs():
	_bad("endings", func(v): v.endings[0].cond = {"lluvia": 1}, "átomo desconocido")
	_bad("endings", func(v): v.endings[0].erase("rank"), "falta 'rank'")
	_bad("easter_eggs", func(v): v.eggs[0].trigger = "x", "se esperaba objeto")
	_bad("easter_eggs", func(v): v.eggs[0].note = "Mal ‡ glifo.", "glifo prohibido")

func test_scenes_dialogue():
	_bad("scenes", func(v): v.lines[0].text = "Un † aquí.", "glifo prohibido")
	_bad("scenes", func(v): v.lines[0].text = "{{#t a:x|Una. Dos.}}", "cruza oraciones")
	_bad("scenes", func(v): v.variants[0].when = {"lluvia": 1}, "átomo desconocido")
	_bad("scenes", func(v): v.lines = [], "mínimo 1")
	_bad("dialogue", func(v): v.lines[0].layer = "chisme", "no está en")
	_bad("dialogue", func(v): v.lines[0].erase("text"), "falta 'text'")
	_bad("dialogue", func(v): v.lines[1].when = {"event_count": {"gte": 1}}, "requiere type")
	# GDD §10.1 / GDD_v3 §2.1: una línea puede declararse inmutable ("cls": "I"); P no tiene sentido en una línea
	_bad("dialogue", func(v): v.lines[0]["cls"] = "P", "no está en")
	var dl = _load("dialogue").duplicate(true)
	dl.lines[0]["cls"] = "I"
	eq(S.check("dialogue", dl), [], "dialogue: línea declarada inmutable")

func test_places_plates():
	_bad("places", func(v): v.nodes[0].anchor.erase("s"), "falta 's'")
	_bad("places", func(v): v.props[0].type = "room", "<módulo>.<función>")
	_bad("places", func(v): v.nodes.append(v.nodes[0].duplicate(true)), "nodo hueco_estante duplicado")
	_bad("places", func(v): v.frames[0].pos = [0, 1], "mínimo 3")
	_bad("places", func(v): v.nodes[0].prop = "fantasma", "prop inexistente")
	_bad("places", func(v): v.nodes[0].tags = ["sin_prefijo"], "etiqueta mal formada")
	_bad("places", func(v): v.characters[0].when = {"lluvia": 1}, "átomo desconocido")
	_bad("plates", func(v): v.nodes[0].cls = "Z", "no está en")
	_bad("plates", func(v): v.erase("frames"), "falta 'frames'")

func test_abbrev_ctx_from_lists():
	# Schema debe cortar oraciones con lists.abbrev (como el runtime), no sólo con las abreviaturas por defecto.
	var v = _load("docs")
	v.parts[0].text = "{{#gral a:x|El Gral. Moran disparó.}}"
	ok(str(S.check("docs", v)).contains("cruza oraciones"), "sin ctx: «Gral.» corta")
	eq(S.check("docs", v, {"abbrev": ["Gral."]}), [], "con lists.abbrev no corta")

func test_collects_text_and_tag_fields():
	var col: Array = []
	S.check("places", _load("places"), {}, col)
	var kinds := {}
	for f in col:
		kinds[f.kind] = true
		ok(String(f.path).begins_with("places."), f.path)
	ok(kinds.has("markup") and kinds.has("tags"), str(kinds))

func test_schedule_weekdays():
	_bad("schedule", func(v): v.days[1].weekday = "martes", "weekday 'martes'")
	_bad("schedule", func(v): v.days.append(v.days[0].duplicate()), "día 0 duplicado")

# §12.2 (integración ola 2): días de semana ASCII en data/.
func test_schedule_weekday_ascii():
	_bad("schedule", func(v): v.days[2].weekday = "mié", "weekday 'mié'")

# §12.2 (d): place opcional (END.F1–F4, EPI); (e) replace conserva los tramos de la línea base.
func test_scene_place_optional_and_replace_keeps_tramos():
	var v = _load("scenes").duplicate(true)
	v.erase("place")
	v.erase("area")
	eq(S.check("scenes", v), [], "escena sin place (final/epílogo)")
	_bad("scenes", func(x): x.variants[0].replace.inteligente = "Un trabajo inteligente, inteligente. Su procurador ya no nos sirve.", "debe conservar los tramos")
	_bad("scenes", func(x): x.variants[0].replace.inteligente = "{{#adjetivos a:harris_es_moran|Un trabajo inteligente, inteligente.}}", "debe conservar los tramos")
	_bad("scenes", func(x): x.variants[0].replace = {"no_existe": "Hola."}, "no es una línea base")
	_bad("scenes", func(x): x.variants[1].append[0].id = "inteligente", "ya es una línea base")
	_bad("scenes", func(x): x.lines.append(x.lines[0].duplicate()), "línea inteligente duplicada")

# §12.2: inserts del Times a nivel de documento (columna | noticias -> id de parte).
func test_doc_inserts():
	var v = _load("docs").duplicate(true)
	v["inserts"] = {"columna": "p1"}
	eq(S.check("docs", v), [], "inserts válido")
	_bad("docs", func(x): x["inserts"] = {"columna": "p9"}, "parte inexistente")
	_bad("docs", func(x): x["inserts"] = {"avisos": "p1"}, "inserts.avisos desconocido")

# Escenas con medida (M:<escena>.<x>: Clipper.act_clip_measure src scene y RouteDB._measure la leen).
func test_scene_measure():
	var v = _load("scenes").duplicate(true)
	v["measure"] = {"entity": "papel_corto", "tags": ["vinculo_mycroft"]}
	v["paper_mm"] = [203, 244]
	eq(S.check("scenes", v), [], "measure y paper_mm en una escena")
	_bad("scenes", func(x): x["measure"] = {"tags": ["x"]}, "entity")
	_bad("scenes", func(x): x["paper_mm"] = [203], "paper_mm")
