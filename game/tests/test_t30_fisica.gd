# T30 (GDD_v2 §C.5.7): la DESCRIPCIÓN FÍSICA uniforme reemplaza la lupa y la regla del lector. Dueño: DESPEJE-UI.
# - Cobertura: todo documento de data/docs y toda plantilla de documento de reacción (doc.entity) tiene descripción.
# - Formato fijo para todos (core/text/fisica.gd): una oración, ≤40 palabras, un solo tramo #fisica con e:<papel>, lint
#   limpio; papeles y medios de tablas cerradas.
# - No marca pistas: sólo D46 y las plantillas de cartas de la Remington llevan etiquetas ocultas, y sólo a:/c:.
# - Inyección (gancho de PROGRESIÓN): cada documento estático empieza con su línea; D46#fisica y R:HA1.fisica se resuelven.
# - Recortable: el tramo #fisica de D46 da papel_crema_grueso y a:vinculo_mycroft; un recorte real (D23 en el prólogo)
#   lleva la entidad del papel en el pie.
extends "res://tests/test_base.gd"

const Fisica = preload("res://core/text/fisica.gd")
const Markup = preload("res://core/text/markup.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

const TAGGED := ["D46", "cartas_a_maquina", "respuestas_s"]

func _fis() -> Dictionary:
	return Fisica.load_fis()

func test_coverage_docs_and_templates() -> void:
	var r = repo()
	var fis := _fis()
	ok(not fis.is_empty(), "data/fisica.json existe")
	var ids: Array = r.docs().keys()
	ids.sort()
	ok(ids.size() >= 70, "documentos: %d" % ids.size())
	for id in ids:
		ok(not Fisica.spec_doc(fis, String(id)).is_empty(), "%s tiene descripción física" % id)
	var ents := {}
	for rr in r.reactions():
		var d = rr.get("doc")
		if typeof(d) == TYPE_DICTIONARY and String(d.get("entity", "")) != "":
			ents[String(d.entity)] = true
	ok(ents.size() >= 12, "plantillas de reacción: %d" % ents.size())
	for e in ents:
		ok(not Fisica.spec_tpl(fis, String(e)).is_empty(), "plantilla %s tiene descripción física" % e)
	for id in fis.get("docs", {}):
		ok(r.docs().has(String(id)), "fisica.docs.%s es un documento" % id)

func test_fixed_format_one_sentence_one_tramo() -> void:
	var r = repo()
	var fis := _fis()
	var ctx: Dictionary = r.markup_ctx()
	ctx["entities"] = r.entities()
	var papers: Dictionary = fis.get("papeles", {})
	var medios: Dictionary = fis.get("medios", {})
	for p in papers:
		ok(r.entities().has(String(papers[p].get("ent", ""))), "entidad del papel %s" % p)
	for sec in ["docs", "plantillas"]:
		for id in fis[sec]:
			var spec: Dictionary = fis[sec][id]
			ok(papers.has(String(spec.get("papel", ""))), "%s: papel de la tabla" % id)
			for m in spec.get("medio", []):
				ok(medios.has(String(m)), "%s: medio %s de la tabla" % [id, m])
			var ln := Fisica.line(spec, [203, 244], fis)
			ok(ln.begins_with("<f=ui><i><ink=tenue>{{#fisica "), "%s: mismo comienzo para todos" % id)
			var p := Markup.parse(ln, ctx)
			eq(Markup.lint(ln, ctx), [], "%s: lint" % id)
			eq(p.tramos.size(), 1, "%s: un tramo" % id)
			eq(p.sentences.size(), 1, "%s: una oración" % id)
			ok(Markup.count_words(p.words, 0, String(p.plain).length()) <= 40, "%s: ≤40 palabras" % id)
			if p.tramos.size() == 1:
				var t: Dictionary = p.tramos[0]
				eq(String(t.id), "fisica", "%s: tramo #fisica" % id)
				eq(t.tags.e, Fisica.ents(spec, fis), "%s: e: sólo el papel" % id)
				for pre in ["f", "d", "p", "q", "h", "w", "x"]:
					eq(t.tags[pre], [], "%s: sin etiquetas %s:" % [id, pre])
				var hidden: Array = t.tags.a + t.tags.c
				eq(not hidden.is_empty(), TAGGED.has(String(id)), "%s: etiquetas ocultas sólo en D46 y la Remington" % id)
			ok(String(p.plain).ends_with("."), "%s: termina en punto" % id)
	eq(Fisica.cm([203, 244]), "20 × 24 cm", "redondeo a centímetros")
	eq(Fisica.tags(Fisica.spec_doc(fis, "D46")), ["a:vinculo_mycroft"], "D46: vinculo_mycroft")

func test_injected_and_resolvable() -> void:
	var r = repo()
	var ids: Array = r.docs().keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = r.doc(String(id))
		var p0 := String(d.parts[0].get("id", ""))
		var pt: Dictionary = r.parsed(String(id), p0)
		var first := {}
		for t in pt.get("tramos", []):
			if int(t.from) == 0:
				first = t
		eq(String(first.get("id", "")), "fisica", "%s empieza con su descripción física" % id)
	var t46: Dictionary = r.doc_tramo("D46", "fisica")
	ok(not t46.is_empty(), "D46#fisica se resuelve como cualquier tramo")
	if not t46.is_empty():
		has(t46.get("tags", {}).get("a", []), "vinculo_mycroft", "D46#fisica lleva vinculo_mycroft")
	near(float(r.doc("D46").paper_mm[1]), 254.0, 0.01, "D46: la medida de fisica.json manda (20 × 25 cm)")
	var RouteDB = load("res://core/graph/route_db.gd")
	var rf: Dictionary = RouteDB.resolve(r, "R:HA1.fisica")
	ok(String(rf.get("missing", "")) == "", "R:HA1.fisica se resuelve: %s" % str(rf.get("missing", "")))

func test_d46_clip_carries_paper_entity() -> void:
	var r = repo()
	var pt: Dictionary = r.parsed("D46", String(r.doc("D46").parts[0].id))
	var t: Dictionary = {}
	for x in pt.tramos:
		if String(x.id) == "fisica":
			t = x
	ok(not t.is_empty(), "tramo #fisica de D46")
	if t.is_empty():
		return
	var pv := SelectionMapper.preview(pt, int(t.from), int(t.to) - int(t.from))
	ok(bool(pv.ok), "se puede recortar entero")
	eq(String(pv.tramo), "fisica", "recorte del tramo #fisica")
	has(pv.ents, "papel_crema_grueso", "el pie del recorte: papel crema grueso")

func test_real_clip_of_the_physical_line() -> void:
	var sim = GameSim.new(repo(), 7)
	var v: Dictionary = sim.q_view("D23@L1")
	if v.is_empty() or (v.get("pages", []) as Array).is_empty():
		skip("D23@L1 no está a la vista en el prólogo")
		return
	var blk: Dictionary = v.pages[0][0]
	var pt: Dictionary = blk.parsed
	var t: Dictionary = {}
	for x in pt.tramos:
		if String(x.id) == "fisica":
			t = x
	ok(not t.is_empty(), "la vista del encargo trae su línea física")
	if t.is_empty():
		return
	var res: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": 0, "block": 0},
		"from": int(t.from), "len": int(t.to) - int(t.from)})
	ok(bool(res.get("ok", false)), "recortar la descripción física: %s" % str(res))
	if bool(res.get("ok", false)):
		var c: Dictionary = sim.q_clip(String(res.clip))
		var ids: Array = (c.get("ents", []) as Array).map(func(e): return String(e.get("id", "")))
		has(ids, "papel_de_carta", "el recorte lleva el papel en el pie")
