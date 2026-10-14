# CORE-EXPEDIENTE: el Expediente Holmes (GDD_v3 §1): nacimiento de preguntas, tope de abiertas, respuesta + dos pruebas,
# pasar en limpio de a una («Algo no cierra.» sin decir qué falló), chequeo de forma sin intento, alias por Q6, examine.
# Sobre data/ real: GameSim por apply (como el jugador). Reemplaza a test_u_ledger y test_u_validator.
extends "res://tests/test_base.gd"

const GameSim = preload("res://core/sim/game_sim.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func _sim(seed := 7):
	return GameSim.new(repo(), seed)

# Escritorio del día 1 (fuera del prólogo: el tutorial no filtra).
func _desk(seed := 7):
	var s = _sim(seed)
	s.st.clock.day = 1
	s.st.clock.slot = "M"
	s.st.clock.phase = "desk"
	s.st.world.tutorial.done = true
	s.st.world.tutorial.step = 4
	return s

func _open_ids(s) -> Array:
	var out: Array = []
	for h in s.q_dossier().open:
		out.append(String(h.id))
	return out

# Recorte inyectado (como si se hubiera recortado) con origen, etiquetas y entidades.
func _clip(s, origin: String, tags: Array, ents: Array, text := "x") -> String:
	return Clipper.inject(s.st, s.repo, {"origin": origin, "tags": tags, "ents": ents, "text": text, "doc": origin})

func test_data_loads():
	var r = repo()
	ok(r.questions().size() == 10, "diez preguntas")
	eq(String(r.questions()[0].id), "Q1")
	ok(not r.dossier().is_empty())
	ok(r.inactive_docs().size() == 20, "veinte crónicas inactivas")
	ok(r.doc("D01.REDH").is_empty(), "una crónica inactiva no se carga")
	ok(not r.doc("D01.GREE").is_empty(), "una activa sí")

func test_q1_at_start():
	var s = _sim()
	eq(_open_ids(s), ["Q1"], "al empezar hay una sola pregunta")
	var h: Dictionary = s.q_dossier().open[0]
	eq(h.text, "¿Qué no contó Watson?")
	eq(h.state, "lapiz")
	eq((h.doubts as Array).size(), 3)
	eq(h.origin, "La pregunta del cliente, en el encargo.")
	eq(h.proofs, [null, null])
	eq(h.formal, ["falta_respuesta", "faltan_pruebas"])

func test_births_blind():
	# dos estados que sólo difieren en etiquetas ocultas de los recortes nacen lo mismo (T8)
	var a = _sim()
	var b = _sim()
	_clip(a, "D05", ["a:raspadura_registrada"], ["raspadura"])
	_clip(b, "D05", [], ["raspadura"])
	Dossier.update(a.st, a.repo)
	Dossier.update(b.st, b.repo)
	eq(a.st.ded.dossier.born.keys(), b.st.ded.dossier.born.keys())

# GDD_v3 §1.3 Q8 / §4.4: «leer R:HA5.*» = leer el original devuelto con la marca del copista al margen. El bloque de la
# marca lleva el id de la instancia de la reacción («R.HA5.<n>»), que no está en st.world.docs (verificador v3: el
# disparador no se cumplía nunca).
func test_reading_copyist_mark_is_leer_reaction():
	eq(Dossier.instance_rid("R.HA5.8"), "HA5")
	eq(Dossier.instance_rid("R.HB2b.12"), "HB2b")
	eq(Dossier.instance_rid("R.marca"), "", "sin número de instancia")
	eq(Dossier.instance_rid("D03"), "")
	var s = _desk()
	no(Dossier.is_born(s.st, "Q8"))
	var mark := {"doc": "R.HA5.3", "origin": "R.HA5.3", "part": "marca", "slot": "margen", "parsed": s.repo.parse_text("v.")}
	Dossier.on_read(s.st, s.repo, "D03@tomo", [mark])
	Dossier.update(s.st, s.repo)
	ok(Dossier.is_born(s.st, "Q8"), "leer la marca del copista hace nacer Q8")
	eq(String(s.st.ded.dossier.born.Q8.via), "leer R:HA5.*")

# GDD_v3 §1.3 Q3 / §7.2 P1: «llega voz:A» = la primera carta a máquina. HC01 (voz A, 1.dawn) es un recorte de imprenta
# con «No lo es.» a lápiz: no hace nacer Q3 (sólo su lectura hace nacer Q2); HA0/HA1 (a máquina) sí. La voz B, siempre.
func test_arrival_voice_is_the_typed_letter():
	var r = repo()
	eq(Dossier.arrival_voice(r.reaction("HC01"), {}), "", "HC01 no es una carta a máquina")
	eq(Dossier.arrival_voice(r.reaction("HA1"), {}), "A", "HA1 es la carta a máquina de la voz A")
	eq(Dossier.arrival_voice(r.reaction("HA0"), {}), "A")
	eq(Dossier.arrival_voice(r.reaction("HC10"), {}), "B", "la voz B cuenta siempre (HC10 en la columna)")
	eq(Dossier.arrival_voice({"voz": "A"}, {"font": "maquina"}), "A", "por la letra del ejemplar entregado")
	eq(Dossier.arrival_voice({}, {}), "")

func test_cap_and_waiting():
	var s = _sim()
	var d: Dictionary = s.st.ded.dossier
	for k in ["leer D03#sheer", "llega voz:A", "llega voz:B"]:
		d.seen[k] = 10
	Dossier.update(s.st, s.repo)
	eq(_open_ids(s), ["Q1", "Q2", "Q3"], "tope de 3 abiertas")
	eq(d.waiting, ["Q5"], "la cuarta espera")
	ok(not s.q_dossier().open.any(func(h): return h.id == "Q5"), "en espera no aparece")
	# al llegar a mostrar_todas se muestra todo
	s.st.now_tk = TimeKey.parse("8.dawn")
	Dossier.update(s.st, s.repo)
	s.st.now_tk = -1
	ok(_open_ids(s).has("Q5"), "el 8.dawn se muestra todo aunque pase el tope")

func test_answer_errors():
	var s = _sim()
	eq(Dossier.act_answer(s.st, s.repo, {"q": "Q2", "value": "cornisa"}).err, "no_abierta")
	eq(Dossier.act_answer(s.st, s.repo, {"q": "Q1", "value": "raspadura"}).err, "no_indexado")
	Index.add_entities(s.st, s.repo, ["raspadura", "holmes"])
	eq(Dossier.act_answer(s.st, s.repo, {"q": "Q1", "value": "holmes"}).err, "fuera_de_lista", "Q1 acepta concepto u objeto")
	ok(Dossier.act_answer(s.st, s.repo, {"q": "Q1", "value": "raspadura"}).ok)
	eq(String(s.q_dossier().open[0].answer.id), "raspadura")

func test_proof_moves_between_slots():
	var s = _sim()
	var c1 := _clip(s, "D03", [], [])
	ok(Dossier.act_proof(s.st, s.repo, {"q": "Q1", "slot": 0, "clip": c1}).ok)
	ok(Dossier.act_proof(s.st, s.repo, {"q": "Q1", "slot": 1, "clip": c1}).ok)
	eq(s.st.ded.dossier.drafts.Q1.proofs, ["", c1], "el recorte se mueve a la otra ranura")
	eq(Dossier.act_proof(s.st, s.repo, {"q": "Q1", "slot": 0, "clip": "RC9999"}).err, "no_existe")

func test_confirm_formal_and_content():
	var s = _desk()
	Index.add_entities(s.st, s.repo, ["raspadura"])
	# forma: sin respuesta ni pruebas -> formal, sin intento
	var r0: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	no(r0.ok)
	eq(r0.err, "formal")
	eq(int(s.st.ded.dossier.attempts.get("Q1", 0)), 0, "la forma no gasta intento")
	var a := _clip(s, "D03", ["a:fina_impreso_sin_raspadura"], ["fina", "pared"])
	var b := _clip(s, "D05", ["a:raspadura_registrada"], ["raspadura", "pared"])
	var same := _clip(s, "D03", ["a:raspadura_registrada"], ["raspadura"])
	ok(s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"}).ok)
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a}).ok)
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": same}).ok)
	var r1: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	eq(r1.get("formal", []), ["mismo_papel"])
	# contenido: falta el enlace (otra pared) o una prueba equivocada -> «Algo no cierra.»
	var c := _clip(s, "D08", ["a:cornisa_existe"], ["pared"])
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": c}).ok)
	var r2: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	ok(r2.ok)
	no(r2.inked)
	eq(r2.msg, "Algo no cierra.")
	eq(int(s.st.ded.dossier.attempts.Q1), 1)
	# las pruebas en cualquier orden
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": b}).ok)
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": a}).ok)
	var r3: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	ok(r3.inked, str(r3))
	ok(String(r3.text).begins_with("Watson vio en la roca"), "el texto en tinta de Lisle")
	ok(r3.first, "primera tinta de la partida")
	eq(s.q_dossier().inked[0].state, "tinta")
	eq(s.apply({"t": "dq_answer", "q": "Q1", "value": ""}).err, "en_tinta")
	# tinta Q1 hace nacer Q4
	ok(s.st.ded.dossier.born.has("Q4"), "Q4 nace de la tinta de Q1")

func test_refuted_proof_never_closes():
	var s = _desk()
	Index.add_entities(s.st, s.repo, ["raspadura"])
	var a := _clip(s, "D03", ["a:fina_impreso_sin_raspadura", "f:refutado"], ["pared"])
	var b := _clip(s, "D05", ["a:raspadura_registrada"], ["pared"])
	s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": b})
	no(bool(s.apply({"t": "dq_confirm", "q": "Q1"}).get("inked", false)))

func test_alias_q7_after_q6():
	var s = _sim()
	var d: Dictionary = s.st.ded.dossier
	d.seen["llega D15.0331"] = 50
	d.seen["dicho S:M6.donde"] = 50
	s.st.now_tk = TimeKey.parse("8.M")
	Dossier.update(s.st, s.repo)
	s.st.now_tk = -1
	# libera lugar: Q1 sale de en medio
	d.open.erase("Q1")
	d.inked["Q1"] = {"tk": 1, "variant": "A", "answer": "raspadura", "proofs": ["", ""], "n": 1}
	Dossier.update(s.st, s.repo)
	ok(Dossier.is_open(s.st, "Q7") and Dossier.is_open(s.st, "Q6"), str(_open_ids(s)))
	Index.add_entities(s.st, s.repo, ["harris", "moran"])
	var j := _clip(s, "D15.0403", ["a:junto_a_adair"], ["moran", "ronald_adair"])
	var t := _clip(s, "D10", ["a:tiro_de_cazador"], ["moran", "bala"])
	s.st.clock.day = 8
	s.st.clock.slot = "M"
	s.st.clock.phase = "desk"
	s.apply({"t": "dq_answer", "q": "Q7", "value": "harris"})
	s.apply({"t": "dq_proof", "q": "Q7", "slot": 0, "clip": j})
	s.apply({"t": "dq_proof", "q": "Q7", "slot": 1, "clip": t})
	no(bool(Dossier.check(s.st, s.repo, "Q7").ok), "harris no vale antes de Q6 en tinta")
	d.inked["Q6"] = {"tk": 80, "variant": "A", "answer": "moran", "proofs": ["", ""], "n": 2}
	d.open.erase("Q6")
	ok(bool(Dossier.check(s.st, s.repo, "Q7").ok), "con Q6 en tinta, harris ≡ moran")

func test_examine_notes_intrusion():
	var s = _sim()
	s.st.ded.dossier.noticed["HA5"] = 30
	Dossier.update(s.st, s.repo)
	ok(s.st.ded.dossier.born.has("Q8"), "notar la intrusión hace nacer Q8")
	eq(String(s.st.ded.dossier.born.Q8.via), "nota HA5")
	var s2 = _desk()
	eq(s2.apply({"t": "examine", "ref": "nada"}).err, "forma")
	ok(s2.apply({"t": "examine", "ref": "hub/escritorio"}).ok, "examinar lo que no avisa no hace nada")
	no(s2.st.ded.dossier.born.has("Q8"))

func test_answer_options_sorted_and_filtered():
	var s = _sim()
	Index.add_entities(s.st, s.repo, ["raspadura", "holmes", "cornisa", "marca_en_la_roca"])
	var ids: Array = []
	for o in s.q_answer_options("Q1"):
		ids.append(String(o.id))
	ok(ids.has("raspadura") and ids.has("cornisa") and not ids.has("holmes"), str(ids))

func test_item_view_and_blue_pencil():
	var s = _desk()
	Index.add_entities(s.st, s.repo, ["raspadura"])
	var a := _clip(s, "D03", ["a:fina_impreso_sin_raspadura"], ["pared"])
	var b := _clip(s, "D08", ["a:cornisa_existe"], ["pared"])
	s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": b})
	var iv := Dossier.item_view(s.st, s.repo, "Q1")
	eq(iv.answer, "raspadura")
	no(iv.inked)
	ok((iv.tags as Array).has("a:cornisa_existe"))
	var bp := Dossier.blue_pencil(s.st, s.repo)
	var kinds: Array = []
	for x in bp:
		kinds.append("%s:%s" % [x.kind, x.q])
	ok(kinds.has("missing:Q1") and kinds.has("wrong:Q1"), str(kinds))

# ---------------- playtest v3 (corrector final) ----------------
# Cada ranura de prueba lleva su rótulo (qué mitad muestra), en todas las preguntas.
func test_proof_labels_on_every_sheet():
	var r = repo()
	for q in r.questions():
		var pl: Array = q.get("pruebas", [])
		eq(pl.size(), 2, "%s: dos rótulos" % q.id)
		for x in pl:
			ok(String(x).begins_with("Prueba"), "%s: «%s»" % [q.id, x])
	var s = _sim()
	var h: Dictionary = s.q_dossier().open[0]
	eq(h.proof_labels, ["Prueba de lo que dice la revista", "Prueba de lo que alguien anotó y la revista calla"], "Q1")

# El selector ofrece todo lo que el jugador conoce (leído/oído), no sólo lo recortado; y acepta elegirlo.
func test_answer_options_use_world_known():
	var s = _desk()
	Dossier.update(s.st, s.repo)
	s.st.world.known["moriarty"] = 1
	s.st.world.known["harris"] = 1
	s.st.world.known["raspadura"] = 1
	var ids: Array = s.q_answer_options("Q1").map(func(o): return String(o.id))
	ok(ids.has("raspadura"), "lo leído sirve de respuesta aunque no esté recortado: %s" % str(ids))
	no(ids.has("harris"), "una persona no responde Q1")
	ok(s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"}).ok, "se puede elegir lo leído")
	eq(s.apply({"t": "dq_answer", "q": "Q1", "value": "cornisa"}).err, "no_indexado", "lo que no conoce, no")

# Al leer la primera hoja de días reales el selector de Q1 ya ofrece más que los recortes (≥10 opciones con FINA leída).
func test_answer_options_grow_with_reading():
	var s = _desk()
	var n0: int = s.q_answer_options("Q1").size()
	var v: Dictionary = s.q_view("D03@tomo")
	for i in (v.get("pages", []) as Array).size():
		s.apply({"t": "read", "view": "D03@tomo", "part": i})
	var n1: int = s.q_answer_options("Q1").size()
	ok(n1 > n0 and n1 >= 8, "leer FINA suma opciones (%d -> %d)" % [n0, n1])

# Abrir una hoja (examine «sheet/<qid>») la marca como vista: Pendientes no la anuncia más.
func test_looked_sheet_leaves_pendientes():
	var s = _desk()
	Dossier.update(s.st, s.repo)
	ok(not Dossier.news_tks(s.st).is_empty(), "Q1 sin abrir")
	eq(s.apply({"t": "examine", "ref": "sheet/Q9"}).err, "no_abierta", "una hoja que no está en la carpeta")
	ok(s.apply({"t": "examine", "ref": "sheet/Q1"}).ok)
	ok(bool(s.q_dossier().open[0].looked), "vista")
	eq(Dossier.news_tks(s.st), [], "ya no es novedad")

# Lo que llega en los avisos del Times (columna insertada) dice dónde está en la línea de origen (Q5).
func test_column_arrival_origin():
	var s = _desk()
	s.st.world.docs["HC10.x"] = {"rid": "HC10", "where": "insert", "meta": {}}
	Dossier.on_arrival(s.st, s.repo, "HC10.x")
	Dossier.update(s.st, s.repo)
	ok(Dossier.is_born(s.st, "Q5"), "nace Q5")
	ok(String(s.st.ded.dossier.born.Q5.origin).contains("avisos del Times"), String(s.st.ded.dossier.born.Q5.origin))
	var s2 = _desk()
	s2.st.world.docs["HB1.x"] = {"rid": "HB1", "where": "tray", "meta": {}}
	Dossier.on_arrival(s2.st, s2.repo, "HB1.x")
	Dossier.update(s2.st, s2.repo)
	eq(String(s2.st.ded.dossier.born.Q5.origin), "Me lo pregunté cuando alguien que firma «S.» me contestó.", "por correo, la línea de siempre")

# Tirar un recorte: sale de q_clips y de las hojas a lápiz; no sirve de prueba; lo que es prueba en tinta no se tira.
func test_clip_drop():
	var s = _desk()
	Index.add_entities(s.st, s.repo, ["raspadura"])
	var a := _clip(s, "D03", ["a:fina_impreso_sin_raspadura"], ["pared"])
	var b := _clip(s, "D05", ["a:raspadura_registrada"], ["pared"])
	var c := _clip(s, "D08", [], ["pared"], "Más arriba del")
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": c}).ok)
	var r: Dictionary = s.apply({"t": "clip_drop", "clip": c})
	ok(r.ok, str(r))
	no(s.q_clips().any(func(x): return String(x.id) == c), "ya no se ofrece")
	eq(s.st.ded.dossier.drafts.Q1.proofs, ["", ""], "sale de la hoja a lápiz")
	eq(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": c}).err, "no_existe", "no sirve de prueba")
	eq(s.apply({"t": "clip_drop", "clip": c}).err, "no_existe", "dos veces no")
	s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": b})
	ok(bool(s.apply({"t": "dq_confirm", "q": "Q1"}).get("inked", false)), "Q1 en tinta")
	eq(s.apply({"t": "clip_drop", "clip": a}).err, "en_tinta", "una prueba en tinta no se tira")

# El recorte de la nota a lápiz al margen de FINA dice que es una nota a lápiz (otra mano, otro papel), va en grafito y se
# agrupa con su crónica (mayo de 1891), no en «Sin fecha de crónica».
func test_margin_note_clip_source():
	var s = _desk()
	var v: Dictionary = s.q_view("D03@tomo")
	var pages: Array = v.get("pages", [])
	var got := ""
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var b: Dictionary = pages[pi][bi]
			if String(b.get("slot", "")) != "margen" or String(b.get("doc", "")) != "D01N":
				continue
			for tr in b.get("parsed", {}).get("tramos", []):
				if String(tr.id) == "fina_fo":
					var r: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D03@tomo", "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
					got = String(r.get("clip", ""))
	ok(got != "", "se recorta la nota al margen")
	var c: Dictionary = s.q_clip(got)
	eq(String(c.src_line), "Nota a lápiz al margen de «El problema final» (J.)")
	eq(String(c.chron_date).substr(0, 7), "1891-05", "con su crónica")
	eq(String(c.hand), "lapiz", "tarjeta en grafito")
	eq(String(c.origin), "D01N", "otro papel que el impreso")

# Playtest v3: la regla del enlace es pública; dos pruebas que no comparten NADA no cierran y Lisle dice por qué
# («no se tocan»): cuenta como intento (no es forma) y no dice nada de la respuesta ni de los rótulos.
func test_no_link_message():
	var s = _desk()
	Index.add_entities(s.st, s.repo, ["raspadura"])
	var a := _clip(s, "D03", ["a:fina_impreso_sin_raspadura"], ["fina"])
	var b := _clip(s, "D05", ["a:raspadura_registrada"], ["journal_de_geneve"])
	var a2 := _clip(s, "D04", ["a:fina_impreso_sin_raspadura"], ["journal_de_geneve"])
	ok(s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"}).ok)
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a}).ok)
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": b}).ok)
	var r: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	ok(r.ok)
	no(r.inked)
	eq(String(r.msg), s.repo.text("v3core.no_se_tocan"), "no comparten nada: «no se tocan»")
	eq(int(s.st.ded.dossier.attempts.get("Q1", 0)), 1, "cuenta como intento")
	# comparten algo (aunque no sea una clave de la variante): sólo «Algo no cierra.»
	ok(s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a2}).ok)
	var r2: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
	eq(String(r2.msg), s.repo.text("v3core.no_cierra"))

# Playtest v3: Lisle no llama «Mrs. Hudson» a la casera hasta que ella se presenta (el panel la nombra «Casera con
# cofia»): mientras tanto, «señora».
func test_hudson_address_until_known():
	var s = _desk()
	var p0 := String(s.q_preview({"t": "ask", "char": "mrs_hudson", "topic": "holmes"}))
	ok(p0.contains("señora") and not p0.contains("Mrs. Hudson"), "sin presentarse: «señora» (%s)" % p0)
	Index.add_entities(s.st, s.repo, ["mrs_hudson"])
	var p1 := String(s.q_preview({"t": "ask", "char": "mrs_hudson", "topic": "holmes"}))
	ok(p1.contains("Mrs. Hudson"), "presentada: por su nombre (%s)" % p1)
