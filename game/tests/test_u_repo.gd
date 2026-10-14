# Unit: core/data/data_repo.gd (W1-ENG). Accesores §3.8 sobre tests/fixtures/data_min + detección de errores.
extends "res://tests/test_base.gd"

const R = preload("res://core/data/data_repo.gd")
const J = preload("res://core/util/j.gd")

var rp

func before_each() -> void:
	rp = fixture_repo()

func test_fixture_has_no_errors():
	eq(rp.errors(), [], "data_min debe ser válido")
	eq(rp.root, "res://tests/fixtures/data_min")

func test_docs_and_copies():
	eq(rp.docs().size(), 4)
	eq(rp.doc("D05").entity, "journal_de_geneve")
	eq(rp.doc("nada"), {})
	var c: Dictionary = rp.copy("D05@BM")
	eq(c.doc, "D05")
	eq(c.copy.holder, "BM")
	eq(rp.copy("D03@tomo").copy["class"], "P", "clase propia del ejemplar")
	eq(rp.copy("D02@L1").copy["class"], "P", "sin clase -> la del documento")
	eq(rp.copy("D99@X"), {})

func test_parsed_and_cache():
	var p: Dictionary = rp.parsed("D05", "p1")
	ok(p.plain.begins_with("MEIRINGEN, 5 de mayo."))
	eq(p.errors, [])
	var ids: Array = []
	for t in p.tramos:
		ids.append(t.id)
	eq(ids, ["viajeros", "aucun_corps", "baton", "corniche", "marque", "pastor"])
	ok(p.plain.contains("contra la roca"), "superficie por defecto = entities.name")
	ok(is_same(rp.parsed("D05", "p1"), p), "cacheado")
	eq(rp.parsed("D05", "p9"), {})
	eq(rp.parsed("D99", "p1"), {})

func test_doc_tramo():
	var t: Dictionary = rp.doc_tramo("D03", "sheer")
	eq(t.part, "p7")
	eq(t.tags.q, ["sheer"])
	eq(rp.doc_tramo("D03", "nada"), {})

func test_entities_lists_templates():
	eq(rp.entity("watson").kind, "persona")
	ok(rp.entities().size() > 60)
	eq(rp.entity("nadie"), {})
	no(rp.has_method("template"), "v3: sin plantillas")

# GDD_v3 §1.7, §3.5: preguntas en orden (`orden`), el archivo entero y el corpus.
func test_dossier_order_and_corpus():
	var ids: Array = []
	for q in rp.questions():
		ids.append(q.id)
	eq(ids, ["Q1", "Q2", "Q6"], "orden por `orden`")
	eq(rp.question("Q2").texto, "¿Qué pasó en la cascada?")
	eq(rp.question("Q99"), {})
	eq(rp.dossier().alias[0].cuando_tinta, "Q6")
	eq(rp.inactive_docs(), ["D01.REDH"])
	ok(rp.is_inactive("D01.REDH"))
	no(rp.has_method("conclusions"), "v3: sin conclusiones")

func test_reactions_and_rest():
	var ids: Array = []
	for r in rp.reactions():
		ids.append(r.id)
	eq(ids, ["D27", "HA1", "HB1", "HC10", "M1"])
	eq(rp.reaction("M1").lado, "moran")
	eq(rp.schedule().days.size(), 12)
	eq(rp.schedule().days[6].weekday, "dom")
	eq(rp.place("L4").nodes.size(), 3)
	eq(rp.places().size(), 2)
	eq(rp.plate("PRO").origin, "PL.prologo")
	eq(rp.plates().size(), 1)
	eq(rp.dialogue("watson").addr, "doctor")
	eq(rp.dialogues().size(), 2)
	eq(rp.scene("M7").tk, "7.night")
	eq(rp.scenes().size(), 1)
	eq(rp.canon().size(), 3)
	eq(rp.endings().endings.size(), 5)
	eq(rp.eggs().size(), 2)
	eq(rp.map().places.size(), 3)
	eq(rp.fonts().slots.size(), 4)
	ok(rp.audio().has("captions"))

func test_catalog():
	var cat: Dictionary = rp.catalog()
	eq(cat.reichenbach, [{"doc": "D03", "label": "The Strand Magazine, vol. VI"}, {"doc": "D05", "label": "Journal de Genève, mayo de 1891"}, {"doc": "", "label": "Tratado de las abejas (1889)"}])
	eq(cat.meiringen.size(), 2)
	eq(cat.meiringen[1].doc, "", "ruido con doc vacío")
	ok(not cat.has("watson"))

func test_text():
	eq(rp.text("saludo", {"addr": "doctor"}), "Buenos días, doctor.")
	eq(rp.text("formal.falta_segun"), "Falta un <i>según</i>.")
	eq(rp.text("no.existe"), "no.existe")

func test_parse_text_runtime():
	var p: Dictionary = rp.parse_text("[[@act|Asiento ${seat}]]: lo vio [[watson]].", {"seat": 214}, "act.9")
	eq(p.plain, "Asiento 214: lo vio el doctor Watson.")
	eq(p.mentions[0].ent, "act.9")
	eq(p.errors, [])

func test_content_hash_and_cache():
	var h: String = rp.content_hash()
	eq(h.length(), 32)
	var f = R.fresh("res://tests/fixtures/data_min")
	ok(not is_same(f, rp), "fresh no usa caché")
	eq(f.content_hash(), h, "hash estable")
	ok(is_same(R.load_dir("res://tests/fixtures/data_min"), rp), "load_dir cachea por root")
	R.clear_cache("res://tests/fixtures/data_min")
	ok(not is_same(R.load_dir("res://tests/fixtures/data_min"), rp), "clear_cache")

func test_missing_root_is_empty():
	var e = R.fresh("res://no/existe")
	eq(e.errors(), [])
	eq(e.docs(), {})
	eq(e.questions(), [])
	eq(e.text("x"), "x")
	eq(e.content_hash().length(), 32)

func _write(root: String, rel: String, v) -> void:
	var p := root.path_join(rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(v if typeof(v) == TYPE_STRING else J.stringify_canon(v))
	f.close()

func _has(errs: Array, sub: String) -> bool:
	for e in errs:
		if String(e).contains(sub):
			return true
	return false

func test_error_detection():
	var root := tmp_dir()
	_write(root, "entities/a.json", {"entities": [{"id": "x", "kind": "objeto", "name": "x", "index": "x"}, {"id": "y", "kind": "objeto", "name": "la y", "index": "y"}]})
	_write(root, "entities/b.json", {"entities": [{"id": "x", "kind": "objeto", "name": "x", "index": "x"}]})
	_write(root, "docs/D01/SCAN.json", {"id": "D01.SCAN", "entity": "x", "title": "t", "src_type": "cronica", "class": "I", "date": "1891-01-01", "font": "imprenta", "paper": "strand", "words": 3,
		"copies": [{"id": "C@1", "holder": "BM", "via": "slip"}], "parts": [{"id": "p1", "text": "Ver [[zzz]] y la [[y]]. {{#q1 q:falta|Cita.}}"}]})
	_write(root, "docs/D07.json", {"id": "D06", "entity": "nope", "title": "t", "src_type": "x", "class": "I", "date": "1891-01-01", "font": "imprenta", "paper": "p", "words": 1,
		"copies": [{"id": "C@1", "holder": "BM", "via": "slip"}], "parts": [{"id": "p1", "text": "Hola."}], "raro": 1})
	_write(root, "ui_text/a.json", {"text": {"k": "uno"}})
	_write(root, "ui_text/b.json", {"text": {"k": "dos"}})
	_write(root, "rotos.json", "{mal")
	_write(root, "otro/x.json", {})
	_write(root, "corpus.json", {"activas": ["D01.SCAN"], "inactivas": ["D01.REDH"]})
	_write(root, "docs/D01/REDH.json", {"id": "D01.REDH", "entity": "x", "title": "t", "src_type": "cronica", "class": "I", "date": "1891-01-01", "font": "imprenta", "paper": "strand", "words": 1,
		"copies": [{"id": "D01.REDH@BM", "holder": "BM", "via": "slip"}], "parts": [{"id": "p1", "text": "{{#fecha a:x|Hola.}}"}]})
	_write(root, "dossier.json", {"preguntas": [{"id": "Q1", "orden": 1, "obligatoria": true, "texto": "¿?", "nace": [{"inicio": "prologo", "origen": "o"}],
		"dudas": ["a", "b"], "acepta": ["concepto"], "variantes": [{"id": "A", "principal": true, "respuestas": ["x"], "grupos": [{"id": "g1", "tags": ["a"]}, {"id": "g2", "tags": ["b"]}],
		"claves": {"entities": [], "kinds": []}, "tinta": "t", "rutas": [{"id": "Q1.R1", "deps": "fija", "frags": [{"ref": "D01.REDH#fecha", "copy": "D01.REDH@BM"}, {"ref": "D01.SCAN#q1", "copy": "C@1"}]}]}],
		"blue_pencil": {"missing": "m", "wrong": "w"}, "invariante": "normal"}]})
	_write(root, "reactions/r.json", {"reactions": [{"id": "M1", "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "informe",
		"disparador": {"evento": "report"}, "latencia": {"tipo": "siguiente_salida"}, "efecto": [{"op": "retirar"}], "rastro": [], "corta": [{"copias": "informadas"}]}]})
	var e: Array = R.fresh(root).errors()
	ok(_has(e, "entidad duplicada 'x'"), "entidad duplicada")
	ok(_has(e, "mención [[zzz]] inexistente"), "mención inexistente")
	ok(_has(e, "artículo duplicado"), "artículo duplicado")
	ok(_has(e, "q:falta sin src_en"), "q: sin src_en")
	ok(_has(e, "no coincide con el nombre de archivo"), "id vs nombre")
	ok(_has(e, "ejemplar duplicado 'C@1'"), "ejemplar duplicado global")
	ok(_has(e, "campo desconocido 'raro'"), "campo desconocido")
	ok(_has(e, "entidad 'nope' inexistente"), "entity del doc")
	ok(_has(e, "clave de ui_text duplicada 'k'"), "ui_text duplicada")
	ok(_has(e, "rotos.json: JSON inválido"), "JSON roto")
	ok(_has(e, "otro/x.json: carpeta desconocida"), "carpeta desconocida")
	ok(_has(e, "nombra un documento inactivo (D01.REDH)"), "GDD_v3 §3.5: ruta a un documento inactivo")
	ok(R.fresh(root).doc("D01.REDH").is_empty(), "el documento inactivo no se carga")
	ok(_has(e, "corta sin variante_blanda"), "D1: variante_blanda obligatoria")

func test_real_data():
	var errs: Array = R.fresh("res://data").errors()
	if errs.is_empty():
		ok(true)
		return
	pending_content("res://data tiene %d errores de esquema/marcado (devtools/lint.gd data). Primeros: %s" % [errs.size(), "; ".join(PackedStringArray(errs.slice(0, 6)))])

func test_entities_checked_in_every_text_field():
	# §4.3: «entidad inexistente» vale para todo campo de texto de data/, no sólo partes de documentos.
	var root := tmp_dir()
	_write(root, "entities/a.json", {"entities": [{"id": "x", "kind": "objeto", "name": "x", "index": "x"}]})
	_write(root, "lists.json", {"abbrev": ["Gral."], "src_types": {"cronica": "crónica"}, "slip_topics": {"holmes_cronicas": "holmes"},
		"diary": {"go": {"text": "${fecha}: [[@act|${lugar}]] con [[fantasma_diario]].", "tags": ["a:acto_ks", "e:fantasma_tag"]}}})
	_write(root, "dialogue/w.json", {"char": "w", "label": "W", "closing": "Adiós a [[fantasma_cierre]].", "lines": [{"id": "g", "layer": "generica", "text": "Hola [[x]]."}]})
	_write(root, "scenes/S1.json", {"id": "S1", "place": "L1", "lines": [{"id": "a", "text": "Uno."}], "variants": [{"when": {}, "replace": {"a": "Dos [[fantasma_variante]]."}}]})
	_write(root, "easter_eggs.json", {"eggs": [{"id": "EE1", "trigger": {}, "note": "Sic [[fantasma_huevo]]."}]})
	_write(root, "docs/D09.json", {"id": "D09", "entity": "x", "title": "t", "src_type": "rara", "slip_topic": "nada", "class": "I", "date": "1891-01-01", "font": "imprenta", "paper": "p", "words": 4,
		"copies": [{"id": "D09@BM", "holder": "BM", "via": "slip"}], "parts": [{"id": "p1", "text": "{{#g a:y|El Gral. [[x]] habló.}}"}]})
	var e: Array = R.fresh(root).errors()
	for ghost in ["fantasma_diario", "fantasma_cierre", "fantasma_variante", "fantasma_huevo"]:
		ok(_has(e, "[[%s]] inexistente" % ghost), ghost + ": " + str(e))
	ok(_has(e, "etiqueta e:fantasma_tag inexistente"), "e: en listas de etiquetas")
	ok(_has(e, "src_type 'rara' no está en lists.src_types"), "src_type")
	ok(_has(e, "slip_topic 'nada' no está en lists.slip_topics"), "slip_topic")
	no(_has(e, "cruza oraciones"), "el esquema usa lists.abbrev («Gral.» no corta): " + str(e))
