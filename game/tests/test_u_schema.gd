# Unit: core/data/schema.gd (W1-ENG). Un caso válido (fixture data_min) y varios inválidos por dataset de §4.1.
extends "res://tests/test_base.gd"

const S = preload("res://core/data/schema.gd")
const J = preload("res://core/util/j.gd")

const FIX := "res://tests/fixtures/data_min/"
const FILES := {
	"fonts": "fonts.json", "audio": "audio.json", "ui_text": "ui_text/core.json", "lists": "lists.json",
	"entities": "entities/core.json", "canon_bible": "canon_bible.json", "docs": "docs/D05.json", "catalog": "catalog/noise.json",
	"schedule": "schedule.json", "conclusions": "conclusions.json", "reactions": "reactions/moran.json", "endings": "endings.json",
	"easter_eggs": "easter_eggs.json", "scenes": "scenes/M7.json", "dialogue": "dialogue/watson.json", "places": "places/L4.json",
	"plates": "plates/PRO.json", "map": "map.json",
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
	_bad("lists", func(v): v.verbos = "matar", "se esperaba lista")
	_bad("lists", func(v): v.templates.T2.lines[0].erase("fields"), "falta 'fields'")
	_bad("lists", func(v): v.templates.T2.lines[0].fields[0].erase("accept"), "falta 'accept'")
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

func test_conclusions():
	_bad("conclusions", func(v): v.conclusions[0].kind = "rara", "no está en")
	_bad("conclusions", func(v): v.conclusions[0].groups[0].line = "0", "se esperaba entero")
	_bad("conclusions", func(v): v.mandatory.append("C99"), "C99 no existe")
	_bad("conclusions", func(v): v.conclusions[0].routes[0].deps = "magia", "no está en")
	_bad("conclusions", func(v): v.conclusions.append(v.conclusions[0].duplicate(true)), "C2 duplicada")
	_bad("conclusions", func(v): v.conclusions[1].subroutes["K-S"].frags = [], "mínimo 1")

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
