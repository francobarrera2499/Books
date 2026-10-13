# PROGRESIÓN (GDD_v2 §B.6): guía indirecta. Pendientes (q_guide): ≤3 líneas, en orden de prioridad, deterministas y
# ciegas a lo oculto (etiquetas, lo sellado); nunca nombran conclusiones ni cuentan progreso. «Lo que me preguntaron»
# (q_questions): citas textuales que aparecen cuando su fuente se dijo o se entregó. Datos reales.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const GameSim = preload("res://core/sim/game_sim.gd")
const Guide = preload("res://core/sim/guide.gd")
const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const J = preload("res://core/util/j.gd")

const KEYS := ["pend.informe_hoy", "pend.informe_manana", "pend.informe_final", "pend.visitas", "pend.confirmar_noche",
	"pend.lugar_nuevo", "pend.crane.s1", "pend.crane.s2", "pend.crane.s3", "pend.practica", "pend.sin_abrir",
	"pend.sin_visitar", "pend.pregunta", "tut.d1.clip", "tut.d1.link", "tut.d1.folio", "tut.d1.entry", "tut.d1.practice"]

func _clip_tramo(s, view: String, tid: String) -> String:
	var v: Dictionary = s.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					var r: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
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
		for cid in ["C1", "C2", "C7", "C12"]:
			no(txt.contains(cid + " ") or txt.ends_with(cid), "nunca nombra conclusiones")
	eq(s.q_guide(), g, label + " determinista")

func test_prologue_has_no_guide():
	var s = GameSim.new(repo(), 7)
	eq(s.q_guide(), [], "en el prólogo guía el instructor")

func test_day1_lines():
	var s = _sim()
	var k := _keys(s.q_guide())
	# §B.6.3 (día 1): el paso en curso de la primera conclusión (§B.7: «los pasos quedan en Pendientes hasta que se
	# hagan»), las novedades del plano y el informe de mañana. La interfaz reemplaza la 3.ª línea por la ayuda de «mirar
	# alrededor» hasta su primer uso: la práctica no puede ir tercera.
	eq(k, ["tut.d1.clip", "pend.lugar_nuevo", "pend.informe_manana"], "día 1: primer paso de la práctica, plano nuevo, informe de mañana")
	var g: Array = s.q_guide()
	var plano: String = s.repo.text(String(g[1].key), g[1].vars)
	ok(plano.contains(" y "), "los lugares nuevos en una línea: " + plano)
	for L in ["L2", "L4"]:
		ok(plano.contains(String(s.repo.map().places[L].label)), "con el rótulo del plano (%s): %s" % [L, plano])
	no(k.has("pend.mirar"), "la ayuda de mirar alrededor la pone la interfaz (hasta su primer uso)")
	_check_lines(s, "1.M")

func test_practice_line_follows_steps_and_goes_away():
	var s = _sim()
	eq(_keys(s.q_guide())[0], "tut.d1.clip")
	s.st.seq["clip"] = 3
	s.st.seq["pair"] = 1
	eq(_keys(s.q_guide())[0], "tut.d1.folio", "el paso en curso: abrir una hoja")
	# los días siguientes, con dos novedades, la práctica pendiente sigue a la vista (sin ella no hay sello)
	eq(Kit.advance_to(s, 2, "M"), "")
	ok(_keys(s.q_guide()).has("tut.d1.folio"), "día 2: %s" % str(_keys(s.q_guide())))
	s.st.world.tutorial.d1["practice"] = 11
	for k in _keys(s.q_guide()):
		no(String(k).begins_with("tut.d1.") or k == "pend.practica", "práctica hecha: ya no se pide")

func test_reaction_question_skips_fisica_line():
	var s = _sim()
	var r = s.repo
	var fl := String(r.fisica_tpl_line("notas_de_pell", [180, 115]))
	var txt := "[[harris|El mayor]] exige el lugar antes del jueves a mediodía."
	s.st.world.docs["R.M8.1"] = {"rid": "M8", "delivered": true, "created_tk": 90, "day": 9,
		"blocks": [{"text": (fl + "\n" if fl != "" else "") + txt + "\n—H.", "act": ""}]}
	var q := Guide._q_react(s.st, r, "M8")
	eq(String(q.get("text", "")), "El mayor exige el lugar antes del jueves a mediodía.", "la cita no es la descripción física")
	eq(String(q.get("who", "")), "harris", "firmada «—H.»: la dice el mayor")

func test_walk_days():
	var s = _sim()
	s.st.world.tutorial.d1["practice"] = 11   # quien hizo la práctica el día 1 (quien no la hizo: test_practice_line_*)
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

func test_blind_to_hidden_tags_and_sealed():
	var s = _sim()
	eq(Kit.advance_to(s, 3, "M"), "")
	var c := _clip_tramo(s, "D01.REDH@tomo", "abril")
	ok(c != "")
	var g0: Array = s.q_guide()
	var q0: Array = s.q_questions()
	var s2 = GameSim.replay(s.repo, 7, s.actions_log())
	for id in s2.st.ded.clips:
		s2.st.ded.clips[id]["tags"] = ["a:otra_cosa", "c:falso"]
	s2.st.ded["sealed"] = {"C2": "AS001", "C7": "AS002"}
	eq(s2.q_guide(), g0, "Pendientes no lee etiquetas ocultas ni lo sellado")
	eq(s2.q_questions(), q0)

func test_questions_quote_sources():
	var s = _sim()
	var qs: Array = s.q_questions()
	eq(qs.map(func(x): return String(x.id)), ["q.pell.1", "q.pell.2", "q.pell.3"], "las tres preguntas del encargo")
	for q in qs:
		ok(String(q.text).begins_with("Uno") or String(q.text).begins_with("Dos") or String(q.text).begins_with("Tres"), "cita textual: " + String(q.text))
		ok(String(q.quien) != "" and String(q.dia) != "", str(q))
		no(q.has("resuelta") or q.has("done"), "nunca se marcan resueltas")
	# M6 (amanecer del 5): «pregunta dónde» aparece cuando Pell lo dice
	eq(Kit.advance_to(s, 5, "M"), "")
	var ids: Array = s.q_questions().map(func(x): return String(x.id))
	ok(ids.has("q.m6"), "la pregunta del mayor (M6) ya se dijo: %s" % str(ids))
	for q in s.q_questions():
		if String(q.id) == "q.m6":
			ok(String(q.text).contains("dónde"), String(q.text))

func test_stock_now():
	var s = _sim()
	eq(s.q_stock(), [], "día 1: sin novedades")
	eq(Kit.advance_to(s, 3, "M"), "")
	var st: Array = s.q_stock()
	eq(st.size(), 2)
	eq(String(st[0].line), "pend.crane.s2", "lo más nuevo primero")
	ok(bool(st[0].new) and not bool(st[1].new))
