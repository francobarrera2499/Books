# PROGRESIÓN (GDD_v2 §B.6; GDD_v3 §6.9): guía indirecta. Pendientes (q_guide): ≤3 líneas, en orden de prioridad,
# deterministas y ciegas a lo oculto (etiquetas, lo entintado); nunca nombran preguntas ni cuentan progreso. El día 1
# guiado (notas de Lisle, v3core.d1.*) va segundo; «Una pregunta nueva en el expediente.» la mañana después. «Lo que me
# preguntaron» (q_questions) ya no existe: las preguntas viven en el expediente. Datos reales.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const GameSim = preload("res://core/sim/game_sim.gd")
const Guide = preload("res://core/sim/guide.gd")
const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const J = preload("res://core/util/j.gd")

const KEYS := ["pend.informe_hoy", "pend.informe_manana", "pend.informe_final", "pend.visitas", "pend.confirmar_noche",
	"pend.lugar_nuevo", "pend.crane.s1", "pend.crane.s2", "pend.crane.s3", "pend.sin_abrir", "pend.sin_visitar",
	"v3core.pend.pregunta_nueva", "v3core.d1.leer", "v3core.d1.pruebas", "v3core.d1.pasar", "v3core.pend.sin_abiertas"]

func _clip_tramo(s, view: String, tid: String) -> String:
	var v: Dictionary = s.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					var sp: Array = load("res://devtools/bots/bot_base.gd").best_window(pages[pi][bi].parsed, int(tr.from), int(tr.to))
					var r: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])})
					return String(r.get("clip", ""))
	return ""

func _sim(seed := 7):
	var s = GameSim.new(repo(), seed)
	ok(s.apply({"t": "read", "view": "D23@L1", "part": 0}).ok)
	ok(_clip_tramo(s, "D23@L1", "aviso") != "")
	ok(s.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok)
	ok(s.apply({"t": "sleep"}).ok)
	return s

func _keys(lines: Array) -> Array:
	return lines.map(func(x): return String(x.key))

func _check_lines(s, label: String) -> void:
	var g: Array = s.q_guide()
	ok(g.size() <= 3, "%s: ≤3 líneas: %s" % [label, str(g)])
	for x in g:
		has(KEYS, String(x.key), label + " clave conocida")
		var txt: String = s.repo.text(String(x.key), x.get("vars", {}))
		no(txt == String(x.key), "%s: texto de %s en ui_text" % [label, x.key])
		no(txt.contains("${"), "%s: sin variables sin llenar: %s" % [label, txt])
		for cid in ["Q1", "Q2", "Q7", "Q10"]:
			no(txt.contains(cid + " ") or txt.ends_with(cid), "nunca nombra preguntas")
	eq(s.q_guide(), g, label + " determinista")

func test_prologue_has_no_guide():
	var s = GameSim.new(repo(), 7)
	eq(s.q_guide(), [], "en el prólogo guía el instructor")

func test_day1_lines():
	var s = _sim()
	var k := _keys(s.q_guide())
	# GDD_v3 §6.9: el paso en curso del día 1 guiado (la nota de Lisle) va antes de las novedades.
	eq(k[0], "v3core.d1.leer", "día 1: primero, leer «El problema final»: %s" % str(k))
	no(k.has("pend.mirar"), "la ayuda de mirar alrededor la pone la interfaz (hasta su primer uso)")
	_check_lines(s, "1.M")

func test_day1_step_follows_state():
	var s = _sim()
	eq(_keys(s.q_guide())[0], "v3core.d1.leer")
	ok(s.apply({"t": "read", "view": "D03@tomo", "part": 0}).ok)
	eq(_keys(s.q_guide())[0], "v3core.d1.pruebas", "leída FINA: una hoja con respuesta y dos pruebas")
	# los días siguientes la nota sigue a la vista hasta pasar en limpio una pregunta (cierre o no)
	eq(Kit.advance_to(s, 2, "M"), "")
	ok(_keys(s.q_guide()).has("v3core.d1.pruebas"), "día 2: %s" % str(_keys(s.q_guide())))
	s.st.seq["clip"] = 2
	s.st.ded.dossier.inked["Q2"] = {"tk": 90}
	s.st.ded.dossier.attempts["Q2"] = 1
	for k in _keys(s.q_guide()):
		no(String(k).begins_with("v3core.d1."), "pasó en limpio: ya no se pide")

# La mañana después de que una pregunta se muestra: «Una pregunta nueva en el expediente.» (sin decir cuál). Lo mostrado
# al amanecer se anuncia ese mismo día (Q5 nace el 4.dawn con la respuesta de «S.», GDD_v3 §1.3).
func test_question_news_next_morning():
	var s = _sim()
	eq(Kit.advance_to(s, 4, "M"), "")
	var TK = load("res://core/util/timekey.gd")
	var shown: Array = load("res://core/deduction/dossier.gd").shown_tks(s.st)
	ok(shown.has(TK.tk(4, "dawn")), "Q5 se muestra el 4.dawn: %s" % str(shown))
	ok(Guide._question_news(s.st, 4), "anunciada el mismo día (se mostró al amanecer)")
	if not shown.any(func(x): return int(x) > TK.tk(1, "night") and int(x) < TK.tk(3, "dawn")):
		no(Guide._question_news(s.st, 3), "nada mostrado el 2: sin novedad el 3")

# Quien ya hizo el día 1 guiado (leyó FINA, armó una hoja y la pasó en limpio): sin la nota de Lisle.
func _day1_done(s) -> void:
	s.st.world.read["D03@tomo"] = [0]
	s.st.seq["clip"] = maxi(int(s.st.seq.get("clip", 0)), 2)
	s.st.ded.dossier.attempts["Q1"] = 1
	s.st.ded.dossier.drafts["Q1"] = {"answer": "x", "proofs": ["RC0001", "RC0002"]}

func test_walk_days():
	var s = _sim()
	_day1_done(s)
	eq(s.q_tutorial().day1, {}, "día 1 guiado hecho")
	var seen := {}
	for d in [2, 3, 4, 5, 7, 8, 9]:
		eq(Kit.advance_to(s, d, "M"), "")
		_check_lines(s, "%d.M" % d)
		for x in s.q_guide():
			seen[String(x.key)] = true
		if d == 2:
			eq(_keys(s.q_guide())[0], "pend.informe_hoy", "día 2: el informe de las 22")
	for k in ["pend.informe_hoy", "pend.lugar_nuevo", "pend.crane.s1"]:
		ok(seen.has(k), "a lo largo de la partida aparece " + k)

func test_unopened_papers():
	var s = _sim()
	eq(Kit.advance_to(s, 2, "M"), "")
	var tray: Array = s.q_tray()
	ok(not tray.is_empty(), "llegó algo el día 2")
	var line := Guide._unopened(s.st, s.repo, 2)
	ok(not line.is_empty(), "sin abrir: %s" % str(tray))
	for it in tray:
		var v: Dictionary = s.q_view(String(it.view))
		for pi in (v.get("pages", []) as Array).size():
			s.apply({"t": "read", "view": String(it.view), "part": pi})
	eq(Guide._unopened(s.st, s.repo, 2), {}, "leído todo: ya no está")

func test_blind_to_hidden_tags_and_inked():
	var s = _sim()
	eq(Kit.advance_to(s, 3, "M"), "")
	var c := _clip_tramo(s, "D03@tomo", "sheer")
	ok(c != "")
	var g0: Array = s.q_guide()
	var s2 = GameSim.replay(s.repo, 7, s.actions_log())
	for id in s2.st.ded.clips:
		s2.st.ded.clips[id]["tags"] = ["a:otra_cosa", "c:falso"]
	eq(s2.q_guide(), g0, "Pendientes no lee etiquetas ocultas")
	var shown_before: Array = load("res://core/deduction/dossier.gd").shown_tks(s2.st)
	# en tinta con el mismo tk de aparición: lo visible no cambia
	var d: Dictionary = s2.st.ded.dossier
	for qid in d.open.keys():
		d.inked[qid] = {"shown_tk": int(d.open[qid].get("tk", -1)), "tk": 200}
		d.open.erase(qid)
	eq(load("res://core/deduction/dossier.gd").shown_tks(s2.st).size(), shown_before.size())

# playtest v3: con todo lo visible en tinta (ninguna hoja abierta) Pendientes empuja a buscar algo nuevo
func test_idle_dossier_line():
	var s = _sim()
	ok(s.apply({"t": "read", "view": "D03@tomo", "part": 0}).ok)
	eq(Kit.advance_to(s, 2, "M"), "")
	no(_keys(s.q_guide()).has("v3core.pend.sin_abiertas"), "con preguntas abiertas, no")
	s.st.seq["clip"] = 2
	var d: Dictionary = s.st.ded.dossier
	for qid in d.open.keys():
		d.inked[qid] = {"shown_tk": int(d.open[qid].get("tk", -1)), "tk": 100, "variant": "A", "answer": "", "proofs": ["", ""], "n": d.inked.size() + 1}
		d.open.erase(qid)
		d.attempts[qid] = 1
	ok(_keys(s.q_guide()).has("v3core.pend.sin_abiertas"), "todo en tinta: %s" % str(_keys(s.q_guide())))

func test_stock_now():
	var s = _sim()
	eq(s.q_stock(), [], "día 1: sin novedades")
	eq(Kit.advance_to(s, 3, "M"), "")
	var st: Array = s.q_stock()
	eq(st.size(), 2)
	eq(String(st[0].line), "pend.crane.s2", "lo más nuevo primero")
	ok(bool(st[0].new) and not bool(st[1].new))
