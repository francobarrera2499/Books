# T36 (CORE-EXPEDIENTE; GDD_v3 §1, §2.1, §7.2 P1 «Aceptación»): el Expediente Holmes sobre data/ REAL.
#  - Partida nueva: en P.N el expediente abre con Q1; leer la hoja de D03#sheer hace nacer Q2. En un pasivo: Q3 nace el
#    2.dawn (la primera carta a máquina de la voz A), Q5 el 4.dawn (voz B), Q6 y Q7 el 5.dawn, Q9 el 7.night y Q10 a más
#    tardar el 9.dawn. Con 3 abiertas, la cuarta espera y aparece al cerrar una o el 8.dawn.
#  - Cada ruta cierra con recortes LEGALES (≤15 palabras de una oración, herencia ≥50 %, sólo las menciones tocadas).
#  - Cada ruta de §2.1 (todas las variantes de dossier.json), con sus dos fragmentos recortados tal como los describe
#    RouteDB y una respuesta válida: dq_confirm entinta con el texto exacto de la variante; con una respuesta inválida, o
#    una prueba cambiada por otra que no cubre su grupo, «Algo no cierra.»; el orden de los grupos no importa. Los tres
#    errores de forma (falta_respuesta, faltan_pruebas, mismo_papel) no registran intento.
#  - Alias: Q7 con «harris» no cierra antes de Q6 en tinta y sí después.
#  - Un recorte de 16 palabras no se hace (mas_de_15).
# Rutas con fragmentos que el contenido todavía no tiene: pending_content (la lista).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 300.0
const GameSim = preload("res://core/sim/game_sim.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")

static var _passive := {}

# Escritorio de un día (fuera del prólogo) con todas las preguntas nacidas y abiertas.
func _desk(r, day := 8):
	var s = GameSim.new(r, 7)
	s.st.clock.day = day
	s.st.clock.slot = "M"
	s.st.clock.phase = "desk"
	s.st.world.tutorial.done = true
	s.st.world.tutorial.step = 4
	var d: Dictionary = s.st.ded.dossier
	for q in r.questions():
		var qid := String(q.id)
		if not d.born.has(qid):
			d.born[qid] = {"tk": 10, "via": "test", "origin": "", "n": d.born.size()}
		if not d.open.has(qid):
			d.open[qid] = {"tk": 10, "n": d.open.size() + 1}
	d.waiting = []
	return s

func _inject(s, f: Dictionary) -> String:
	var tags: Array = f.tags if not (f.tags as Array).is_empty() else f.tags_any
	return Clipper.inject(s.st, s.repo, {"origin": String(f.origin), "tags": tags.duplicate(), "ents": (f.ents as Array).duplicate(),
		"text": String(f.ref), "doc": String(f.get("doc", "")), "copy": String(f.get("copy", "")), "cls": String(f.get("cls", "I"))})

func _valid_answer(r, v: Dictionary) -> String:
	for a in v.get("respuestas", []):
		if not String(a).begins_with("@alias:"):
			return String(a)
	return ""

# ---------------- nacimiento ----------------
func _passive_births() -> Dictionary:
	if not _passive.is_empty():
		return _passive
	var r = repo()
	var s = GameSim.new(r, 7)
	var b = load("res://devtools/bots/bot_pasivo.gd").new()
	b.setup(s, 7)
	var shown := {}
	for _i in 2000:
		var c: Dictionary = s.q_clock()
		if String(c.phase) == "done" or int(c.day) >= 10:
			break
		for h in s.q_dossier().get("open", []):
			if not shown.has(String(h.id)):
				shown[String(h.id)] = Dossier.shown_tks(s.st)
		b.step()
	var born := {}
	for q in s.st.ded.dossier.born:
		born[String(q)] = int(s.st.ded.dossier.born[q].tk)
	_passive = {"born": born, "sim": s}
	return _passive

func test_new_game_q1_and_q2_on_read():
	var r = repo()
	var s = GameSim.new(r, 7)
	eq(s.q_dossier().open.map(func(h): return String(h.id)), ["Q1"], "P.N: el expediente abre con Q1")
	var tr: Dictionary = r.doc_tramo("D03", "sheer")
	if tr.is_empty():
		pending_content("D03 sin #sheer")
		return
	ok(s.apply({"t": "read", "view": "D23@L1", "part": 0}).ok, "abrir el encargo")
	var parts: Array = r.doc("D03").parts
	var pi := -1
	for i in parts.size():
		if String(parts[i].id) == String(tr.get("part", "")):
			pi = i
	ok(pi >= 0)
	no(Dossier.is_born(s.st, "Q2"))
	ok(s.apply({"t": "read", "view": "D03@tomo", "part": pi}).ok)
	ok(Dossier.is_open(s.st, "Q2"), "leer la hoja de D03#sheer hace nacer Q2")

func test_passive_birth_times():
	var p := _passive_births()
	var born: Dictionary = p.born
	var T := func(k): return TimeKey.parse(k)
	for x in [["Q10", "9.dawn"]]:
		ok(born.has(x[0]) and int(born[x[0]]) <= int(T.call(x[1])), "%s nace a más tardar el %s: %s" % [x[0], x[1], str(born.get(x[0], "no nació"))])
	# §7.2 P1: Q3 el 2.dawn (la primera carta a máquina: HC01, el 1.dawn, es un recorte con «No lo es.» a lápiz, no cuenta
	# como voz A; Dossier.arrival_voice) y Q5 el 4.dawn (HC10), exactos en un pasivo.
	for x in [["Q3", "2.dawn"], ["Q5", "4.dawn"], ["Q6", "5.dawn"], ["Q7", "5.dawn"], ["Q9", "7.night"]]:
		ok(born.has(x[0]), "%s nace en un pasivo: %s" % [x[0], str(born)])
		if born.has(x[0]):
			eq(TimeKey.label(int(born[x[0]])), TimeKey.label(int(T.call(x[1]))), "%s nace el %s" % x)
	no(born.has("Q2") or born.has("Q4") or born.has("Q8"), "un pasivo no lee ni nota nada: ni Q2, ni Q4, ni Q8: %s" % str(born.keys()))

# §1.3 Q8 / §4.4: sin examinar la ventana, leer el original que los de Holmes devolvieron con la marca «v.» al margen
# hace nacer Q8 (`leer R:HA5.*`). Partida real: pasivo hasta el día 3, papeleta de FINA en la Sala (HA5), amanecer del 4.
func test_q8_born_reading_returned_original():
	var r = repo()
	var s = GameSim.new(r, 7)
	var b = load("res://devtools/bots/bot_pasivo.gd").new()
	b.setup(s, 7)
	for _i in 600:
		var c: Dictionary = s.q_clock()
		if (int(c.day) == 3 and String(c.slot) == "M" and String(c.phase) == "desk") or int(c.day) > 3:
			break
		b.step()
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok, "a la Sala")
	ok(s.apply({"t": "slip", "doc": "D03"}).ok, "papeleta de crónicas")
	ok(s.apply({"t": "leave"}).ok)
	if String(s.q_hub_plate().get("variant", "")) != "techos":
		pending_content("HA5 no ocurrió (variante «techos» ausente)")
		return
	for _i in 40:
		var c: Dictionary = s.q_clock()
		if int(c.day) >= 4 and String(c.phase) == "desk":
			break
		match String(c.phase):
			"desk": s.apply({"t": "end_slot"})
			"visit", "scene": s.apply({"t": "leave"})
			"night":
				if bool(s.q_report_status().due):
					s.apply({"t": "report_submit", "mode": "nada", "items": []})
				else:
					s.apply({"t": "sleep"})
	no(Dossier.is_born(s.st, "Q8"), "ver la pieza cambiada no basta")
	var v: Dictionary = s.q_view("D03@tomo")
	var page := -1
	for pi in (v.get("pages", []) as Array).size():
		for bl in v.pages[pi]:
			if String(bl.get("part", "")) == "marca":
				page = pi
	ok(page >= 0, "FINA volvió con la marca del copista")
	if page < 0:
		return
	ok(s.apply({"t": "read", "view": "D03@tomo", "part": page}).ok)
	ok(Dossier.is_born(s.st, "Q8"), "leer la hoja con la marca hace nacer Q8")
	eq(String(s.st.ded.dossier.born.get("Q8", {}).get("via", "")), "leer R:HA5.*")

func test_cap_waiting_and_8_dawn():
	var p := _passive_births()
	var s = p.sim
	var d: Dictionary = s.st.ded.dossier
	ok(d.open.size() > 3 or int(s.q_clock().day) < 8, "desde el 8.dawn se muestra todo aunque pase el tope: %s" % str(d.open.keys()))
	# antes del 8: con tres abiertas la cuarta espera
	var r = repo()
	var s2 = GameSim.new(r, 7)
	var d2: Dictionary = s2.st.ded.dossier
	for k in ["leer D03#sheer", "llega voz:A", "llega voz:B"]:
		d2.seen[k] = 10
	Dossier.update(s2.st, s2.repo)
	eq(d2.open.size(), 3)
	eq(d2.waiting, ["Q5"], "la cuarta espera")
	d2.open.erase("Q2")
	d2.inked["Q2"] = {"tk": 20, "variant": "A", "answer": "cornisa", "proofs": ["", ""], "n": 1}
	Dossier.update(s2.st, s2.repo)
	ok(d2.open.has("Q5"), "al cerrar una, aparece la que esperaba")

# ---------------- cada ruta de §2.1 ----------------
func test_every_route_inks_with_exact_text():
	var r = repo()
	var pending: Array = []
	var n := 0
	for q in r.questions():
		var qid := String(q.id)
		for v in q.get("variantes", []):
			var uid := RouteDB.uid_of(r, qid, String(v.id))
			for rt in RouteDB.routes(r, uid):
				if not (rt.missing as Array).is_empty():
					pending.append("%s %s" % [rt.id, str(rt.missing[0])])
					continue
				if not (rt.get("data_errors", []) as Array).is_empty():
					pending.append("%s %s (T1: retag de CONTENIDO/REACCIONES)" % [rt.id, str(rt.data_errors)])
					continue
				n += 1
				_check_route(r, qid, v, rt)
	print("T36: %d rutas verificadas; %d con contenido pendiente" % [n, pending.size()])
	if not pending.is_empty():
		pending_content("T36: rutas con fragmentos que el contenido todavía no tiene: %s" % str(pending.slice(0, 8)))

func _check_route(r, qid: String, v: Dictionary, rt: Dictionary) -> void:
	var lb := String(rt.id)
	var s = _desk(r, 8)
	var ans := _valid_answer(r, v)
	if ans == "":
		fail(lb + ": la variante no tiene respuesta directa")
		return
	# Q7 con alias, Q8.B / Q10.B: la otra variante; Q7 sólo vale con Q6 si la respuesta es un alias
	Index.add_entities(s.st, s.repo, [ans])
	var a := _inject(s, rt.frags[0])
	var b := _inject(s, rt.frags[1])
	var opts := {"answer": ans, "proofs": [a, b]}
	var ck: Dictionary = Dossier.check(s.st, s.repo, qid, opts)
	ok(bool(ck.get("ok", false)), "%s cierra con %s: %s" % [lb, ans, str(ck)])
	ok(bool(Dossier.check(s.st, s.repo, qid, {"answer": ans, "proofs": [b, a]}).get("ok", false)), lb + ": el orden de los grupos no importa")
	no(bool(Dossier.check(s.st, s.repo, qid, {"answer": "lisle", "proofs": [a, b]}).get("ok", false)), lb + ": con otra respuesta no cierra")
	var junk := Clipper.inject(s.st, s.repo, {"origin": "D99", "tags": ["a:nada_que_ver"], "ents": (rt.frags[1].ents as Array).duplicate(), "text": "x"})
	no(bool(Dossier.check(s.st, s.repo, qid, {"answer": ans, "proofs": [a, junk]}).get("ok", false)), lb + ": con una prueba cambiada no cierra")
	# por apply, como el jugador: «Algo no cierra.» y luego tinta con el texto exacto
	ok(s.apply({"t": "dq_answer", "q": qid, "value": ans}).ok, lb + " dq_answer")
	ok(s.apply({"t": "dq_proof", "q": qid, "slot": 0, "clip": a}).ok, lb + " dq_proof 0")
	ok(s.apply({"t": "dq_proof", "q": qid, "slot": 1, "clip": junk}).ok, lb + " dq_proof 1 (mala)")
	var bad: Dictionary = s.apply({"t": "dq_confirm", "q": qid})
	eq(String(bad.get("msg", "")), "Algo no cierra.", lb)
	ok(s.apply({"t": "dq_proof", "q": qid, "slot": 1, "clip": b}).ok)
	var good: Dictionary = s.apply({"t": "dq_confirm", "q": qid})
	ok(bool(good.get("inked", false)), "%s: %s" % [lb, str(good)])
	if bool(good.get("inked", false)):
		eq(String(good.text), String(Dossier.variant(r.question(qid), String(good.variant)).get("tinta", "")), lb + ": texto en tinta exacto")
		eq(String(good.variant), String(v.id), lb + ": la variante de la ruta")

# Sin atajos: _check_route inyecta los fragmentos con TODAS las entidades del tramo; el jugador sólo recorta ≤15 palabras
# de una oración (hereda las etiquetas si cubre ≥50 % del tramo, y sólo las menciones que toca). Para cada fragmento de
# documento se prueban todas las ventanas legales que tocan el tramo; alguna combinación de las dos pruebas tiene que
# cerrar (cobertura de grupos + enlace por claves, Dossier.proofs_ok). Los demás fragmentos (nodos, líneas, rastros) por su
# descriptor de RouteDB.
func test_every_route_closes_with_legal_clips():
	var r = repo()
	var n := 0
	for q in r.questions():
		for v in q.get("variantes", []):
			for rt in RouteDB.routes(r, RouteDB.uid_of(r, String(q.id), String(v.id))):
				if not (rt.missing as Array).is_empty() or not (rt.get("data_errors", []) as Array).is_empty():
					continue   # lo informa test_every_route_inks_with_exact_text
				n += 1
				var oa := _legal_options(r, rt.frags[0])
				var ob := _legal_options(r, rt.frags[1])
				var closes := false
				for x in oa:
					for y in ob:
						if Dossier.proofs_ok(r, v, x, y, []):
							closes = true
							break
					if closes:
						break
				ok(closes, "%s (%s + %s): ninguna pareja de recortes legales cierra (%d × %d opciones)" % [rt.id, rt.frags[0].ref, rt.frags[1].ref, oa.size(), ob.size()])
	ok(n > 0, "rutas verificadas")

func _legal_options(r, f: Dictionary) -> Array:
	var ref := String(f.ref)
	if String(f.get("kind", "")) != "doc" or not ref.contains("#") or ref.contains(":"):
		return [{"tags": f.tags, "ents": f.ents}]
	var did := ref.get_slice("#", 0)
	var hit := RouteDB.find_tramo(r, did, ref.get_slice("#", 1))
	if hit.is_empty():
		return []
	var pt: Dictionary = hit.parsed
	var words: Array = pt.get("words", [])
	var idx: Array = []
	for k in words.size():
		if int(words[k][1]) > int(hit.tramo.from) and int(words[k][0]) < int(hit.tramo.to):
			idx.append(k)
	var de: Array = RouteDB.doc_ents(r.doc(did))
	var out: Array = []
	for i in idx.size():
		for j in range(i, mini(idx.size(), i + ClipRules.MAX_WORDS)):
			var sn: Dictionary = ClipRules.snap(pt, int(words[idx[i]][0]), int(words[idx[j]][1]) - int(words[idx[i]][0]))
			if not bool(sn.ok):
				continue
			var inh := ClipRules.inherit(pt, int(sn.from), int(sn.to))
			var ents: Array = (inh.ents as Array).duplicate()
			for e in de:
				if not ents.has(e):
					ents.append(e)
			out.append({"tags": inh.tags, "ents": ents})
	return out

func test_formal_errors_do_not_count():
	var r = repo()
	var s = _desk(r, 3)
	eq(String(s.apply({"t": "dq_confirm", "q": "Q1"}).err), "formal")
	var f: Array = s.apply({"t": "dq_confirm", "q": "Q1"}).get("formal", [])
	has(f, "falta_respuesta")
	has(f, "faltan_pruebas")
	var a := Clipper.inject(s.st, s.repo, {"origin": "D03", "tags": ["a:fina_impreso_sin_raspadura"], "ents": ["pared"], "text": "x"})
	var b := Clipper.inject(s.st, s.repo, {"origin": "D03", "tags": ["a:raspadura_registrada"], "ents": ["pared"], "text": "y"})
	Index.add_entities(s.st, s.repo, ["raspadura"])
	s.apply({"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 0, "clip": a})
	s.apply({"t": "dq_proof", "q": "Q1", "slot": 1, "clip": b})
	eq(s.apply({"t": "dq_confirm", "q": "Q1"}).get("formal", []), ["mismo_papel"])
	eq(int(s.st.ded.dossier.attempts.get("Q1", 0)), 0, "los errores de forma no registran intento")

func test_alias_q7_harris_after_q6():
	var r = repo()
	var s = _desk(r, 8)
	var rts: Array = RouteDB.routes(r, "Q7").filter(func(x): return (x.missing as Array).is_empty() and (x.get("data_errors", []) as Array).is_empty())
	if rts.is_empty():
		pending_content("Q7 sin rutas completas en data/")
		return
	Index.add_entities(s.st, s.repo, ["harris", "moran"])
	var a := _inject(s, rts[0].frags[0])
	var b := _inject(s, rts[0].frags[1])
	no(bool(Dossier.check(s.st, s.repo, "Q7", {"answer": "harris", "proofs": [a, b]}).get("ok", false)), "harris no vale antes de Q6 en tinta")
	var d: Dictionary = s.st.ded.dossier
	d.inked["Q6"] = {"tk": 80, "variant": "A", "answer": "moran", "proofs": ["", ""], "n": 1}
	d.open.erase("Q6")
	ok(bool(Dossier.check(s.st, s.repo, "Q7", {"answer": "harris", "proofs": [a, b]}).get("ok", false)), "con Q6 en tinta, harris ≡ moran")

func test_clip_sixteen_words_rejected():
	var r = repo()
	var s = GameSim.new(r, 7)
	var v: Dictionary = s.q_view("D23@L1")
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			var p: Dictionary = v.pages[pi][bi].parsed
			for sen in p.get("sentences", []):
				var idx: Array = []
				for k in (p.words as Array).size():
					if int(p.words[k][0]) >= int(sen[0]) and int(p.words[k][1]) <= int(sen[1]):
						idx.append(k)
				if idx.size() >= 16:
					var f := int(p.words[idx[0]][0])
					var t := int(p.words[idx[15]][1])
					var rr: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pi, "block": bi}, "from": f, "len": t - f})
					eq(String(rr.get("err", "")), "mas_de_15", "16 palabras de una oración")
					var t15 := int(p.words[idx[14]][1])
					ok(s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pi, "block": bi}, "from": f, "len": t15 - f}).ok, "15 palabras sí")
					return
	pending_content("D23 sin una oración de ≥16 palabras")
