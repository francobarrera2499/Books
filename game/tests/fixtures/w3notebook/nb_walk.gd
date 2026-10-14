# tests/fixtures/w3notebook/nb_walk.gd — GameSim del cuaderno para test_u_notebook (UI-EXPEDIENTE; antes W3-NOTEBOOK).
# v3 (GDD_v3 §7.1: «las UI trabajan contra tests/fixtures/v3/»): el escenario se arma sobre el fixture de CORE
# (tests/fixtures/v3/v3_fixture.gd: día 1 en el escritorio, prólogo hecho, sus recortes de ejemplo) más lo que el
# cuaderno necesita mostrar, sin depender del recorrido de integración (que cambia con el contenido):
#   recortes con fecha de crónica (mayo de 1891 dos veces el mismo día, abril de 1890, septiembre de 1888), personas y
#   lugares del índice (Watson en tres), uno legible (D03@tomo), uno de lámina (PL.prologo) y los del fixture (sin fecha);
#   el índice con ≥12 entradas (pestaña Índice); diario: las líneas del prólogo (Pell, Harris), dos de Watson (escena S.L4.1.M, la primera con dos oraciones), una de
#   Lisle y una llegada a la bandeja (el Times del 27, con su sello «Recibido»).
# Cada sim() es una GameSim nueva (los tests pueden mutarla). ids(sim) -> {nombre: id de recorte}.
extends RefCounted

const V3 := "res://tests/fixtures/v3/v3_fixture.gd"
const CLIPPER := "res://core/deduction/clipper.gd"
const DIARY := "res://core/sim/diary.gd"
const SEED := 7

static var errs: Array = []

static func repo():
	return load("res://core/data/data_repo.gd").load_dir("res://data")

static func ok() -> bool:
	return sim() != null

static func sim():
	var F = load(V3)
	if F == null or not F.can_instantiate():
		errs = ["falta o no compila " + V3 + " (CORE)"]
		return null
	var r = repo()
	var s = F.sim(r, 1894)
	if s == null:
		errs = ["el fixture v3 no armó la GameSim"]
		return null
	var C = load(CLIPPER)
	var D = load(DIARY)
	var ids := {}
	var mk := func(name: String, c: Dictionary) -> void:
		var d := {"kind": "text", "src_type": "cronica", "src_line": "«%s», crónica" % String(c.get("title", "El problema final"))}
		d.merge(c, true)
		ids[name] = C.inject(s.st, r, d)
	mk.call("watson_a", {"text": "Holmes estaba de pie junto al borde del sendero.", "origin": "D03", "doc": "D03", "copy": "D03@tomo",
		"chron_date": "1891-05-04", "ents": ["watson", "reichenbach"]})
	mk.call("watson_b", {"text": "Watson volvió corriendo por el mismo camino.", "origin": "D03", "doc": "D03", "copy": "D03@tomo",
		"chron_date": "1891-05-04", "ents": ["watson"]})
	mk.call("holmes_mayo", {"text": "Partimos de Meiringen a primera hora.", "origin": "D03", "doc": "D03", "copy": "D03@tomo",
		"chron_date": "1891-05-01", "ents": ["holmes", "reichenbach", "meiringen", "suiza"]})
	mk.call("watson_abril", {"text": "Mi mujer estaba de visita en casa de su tía.", "origin": "D01.TWIS", "doc": "D01.TWIS", "copy": "D01.TWIS@tomo",
		"chron_date": "1890-04-27", "ents": ["watson", "kensington", "londres"], "title": "El hombre del labio retorcido"})
	mk.call("mycroft_sep", {"text": "Mi hermano ocupa un sillón en el club Diógenes.", "origin": "D01.GREE", "doc": "D01.GREE", "copy": "D01.GREE@tomo",
		"chron_date": "1888-09-01", "ents": ["mycroft", "club_diogenes", "pall_mall"], "title": "El intérprete griego"})
	mk.call("encargo", {"text": "Aviso: se busca testigo de lo ocurrido en el Reichenbach.", "origin": "D23", "doc": "D23", "copy": "D23@L1",
		"src_type": "papel_privado", "src_line": "Encargo del señor Pell · papel privado", "ents": ["reichenbach"]})
	mk.call("lamina", {"kind": "plate", "text": "", "caption": "mesa, cesto, mozo con gorra", "origin": "PL.prologo", "doc": "", "copy": "PL.prologo",
		"src_type": "lugar", "src_line": "Holywell Street, lugar", "ents": []})
	var tk := int(s.q_clock().get("tk", 11))
	D.on_line(s.st, r, {"text": "Era un sendero estrecho, señor Lisle. A un lado subía la roca negra y al otro caía el agua con un ruido que tapaba todo.", "origin": "S.L4.1.M", "who": "watson", "uid": "L4.1.M.a", "tk": tk})
	D.on_line(s.st, r, {"text": "Le escribí al hermano esa misma noche.", "origin": "S.L4.1.M", "who": "watson", "uid": "L4.1.M.b", "tk": tk})
	D.on_line(s.st, r, {"text": "La pared era a pique, sin salida.", "origin": "S.L4.1.M", "who": "lisle", "uid": "L4.1.M.c", "tk": tk})
	D.on_arrival(s.st, r, "D15.0327@L1")
	s.st.notes.clear()
	s.set_meta("nb_ids", ids)
	errs = []
	return s

static func ids(s) -> Dictionary:
	return s.get_meta("nb_ids", {}) if s != null else {}
