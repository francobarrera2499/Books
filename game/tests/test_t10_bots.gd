# T10 (W3-BOTS; CORE-EXPEDIENTE, GDD_v3 §2.4, §1.9; GDD §15.5, §8.9, §11, §7.7; ARCHITECTURE §9.2/§9.3): bots. Los 12
# bots de §9.3 (+ sabelotodo, v3) juegan partidas completas (prólogo → epílogo) por GameSim.apply. Verifica: el deductor
# (oráculo de rutas ★, hojas verificadas con Dossier.check) alcanza el mejor final y es la cota: ningún bot logra un `rank`
# mejor que el del deductor con la misma semilla; el pasivo termina en F4; presupuestos (§1.9): fuerza bruta (respuesta y
# par al azar, 100 intentos por pregunta) cierra ≤5 % de las preguntas que intenta (3 semillas; --slow: las 20 del
# criterio); sabelotodo (respuesta correcta, par al azar, 50 intentos) se mide y se imprime, sin umbral; el novato emite
# read, examine y dq_* y mide el Acto III (palabras/180 × 1,3). Cada bot además hace lo que lo define (si no, la cota
# sería vacía): cebo pone avisos, informa-todo entrega ítems, sólo-BM sólo va a la Sala, el acusador al azar nunca calla,
# el presentador al azar le muestra cosas a Mycroft, etc.
# Dataset «fixture» (estructura real de data/ + contenido mínimo de tests/fixtures/{integ,bots}); sobre data/ real
# cuando el contenido esté completo (si no: pending_content con lo que falta). Presupuesto de reloj por partida
# (salvaguarda contra bucles): 120 s (600 s para los pesados).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 1200.0
const BotData = preload("res://devtools/bots/bot_data.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const SEEDS := [1]
const SEEDS_SLOW := [1, 2, 3]
const RANDOM_SEEDS := [1, 2]
const RANDOM_SEEDS_SLOW := [1, 2, 3, 4, 5]
const RANDOM := ["pesca", "fuerza_bruta", "sabelotodo", "confront_azar", "mycroft_azar"]
const HEAVY := ["fuerza_bruta", "sabelotodo"]   # ~35 s por partida (cientos de dq_confirm); una semilla salvo --slow
# Sobre data/ real, recortar todo cuesta minutos (≈2.600 apply, ~60 ms cada uno al final: GameSim._apply copia el estado):
# sólo con --slow y con más presupuesto de reloj (carga del PC: la suite normal no los corre).
const HEAVY_REAL := ["fuerza_bruta", "sabelotodo", "recorta_todo"]
const HEAVY_REAL_BUDGET_MS := 600000
const BRUTE_N := 3
const BRUTE_N_SLOW := 20
const BRUTE_BUDGET := 0.05
const ACT3_MAX_MIN := 60.0

static var _fx = null
static var _real = null
static var _runs := {}

func _seeds() -> Array:
	return SEEDS_SLOW if slow else SEEDS

func _fixture():
	if _fx == null:
		_fx = BotData.repo("fixture")
	return _fx

func _real_repo():
	if _real == null:
		_real = BotData.repo("real")
	return _real

func _run(r, key: String, bot: String, seed: int, budget_ms := 120000) -> Dictionary:
	var k := "%s|%s|%d" % [key, bot, seed]
	if not _runs.has(k):
		_runs[k] = RunBots.run_one(r, bot, seed, 20000, budget_ms)
	return _runs[k]

func _best_rank(r) -> int:
	var best := 99
	for e in r.endings().get("endings", []):
		if int(e.get("rank", 0)) > 0:
			best = mini(best, int(e.rank))
	return best

func _clean(res: Dictionary, label: String) -> void:
	eq(String(res.get("runaway", "")), "", label + " salvaguarda (bucle)")
	eq(String(res.get("phase", "")), "done", label + " la partida debe terminar")
	eq(res.get("errors", []), [], label + " acciones rechazadas inesperadas")
	ok(int(res.get("rank", 0)) > 0, label + " sin final: " + str(res.get("ending", "")))

# ------------------------------------------------------------------ registro
func test_t10_registry():
	eq(RunBots.BOTS.size(), 12)
	for name in ["deductor", "novato", "pasivo", "pesca", "fuerza_bruta", "sabelotodo", "recorta_todo", "cebo", "informa_todo",
			"solo_bm", "confront_azar", "mycroft_azar"]:
		has(RunBots.BOTS, name)
		var b = RunBots.make(name)
		ok(b != null, "bot " + name)
		if b != null:
			for m in ["setup", "step", "play", "act", "read", "clip_ref"]:
				ok(b.has_method(m), "%s.%s (contrato §9.3)" % [name, m])
			b._init_bot()
			eq(String(b.bot_name), name)
	ok(RunBots.make("no_existe") == null)

# ------------------------------------------------------------------ fixture
func test_t10_fixture_playable():
	var rep := BotData.content_report(_fixture())
	ok(bool(rep.ok), "dataset fixture jugable: " + str(rep))
	# reconstruir con las mismas fuentes reusa el mismo directorio (firma estable)
	eq(BotData.fixture_sig(), BotData.fixture_sig())

func test_t10_deductor_is_upper_bound():
	var r = _fixture()
	var best := _best_rank(r)
	for seed in _seeds():
		var d := _run(r, "fx", "deductor", seed)
		var lb := "deductor/s%d" % seed
		_clean(d, lb)
		eq(d.get("oracle", []), [], lb + " fallas del oráculo")
		eq(int(d.rank), best, lb + " el deductor alcanza el mejor final (%s)" % d.ending)
		for cid in RouteDB.mandatory(r):
			has(d.sealed, String(cid), lb + " pasa en limpio")
		ok(int(d.confirms) - int(d.confirms_inked) <= 1, lb + " sólo pasa en limpio hojas verificadas (salvo, quizá, la del día 1 guiado): %d de %d" % [int(d.confirms_inked), int(d.confirms)])
		ok(bool(d.flags.get("moran_credito", false)), lb + " crédito ante Moran")
		eq(String(d.flags.get("informe_final", "")), "errata", lb + " errata a medida")
		# determinismo del bot: misma semilla, mismo resultado
		if seed == SEEDS[0]:
			var d2 := RunBots.run_one(r, "deductor", seed)
			eq(d2.sealed, d.sealed, lb + " determinista")
			eq(int(d2.acts), int(d.acts), lb + " determinista")

func test_t10_pasivo_f4():
	var r = _fixture()
	for seed in _seeds():
		var p := _run(r, "fx", "pasivo", seed)
		_clean(p, "pasivo/s%d" % seed)
		eq(String(p.ending), "F4", "pasivo/s%d" % seed)
		eq(p.sealed, [], "pasivo/s%d nada en tinta" % seed)

func test_t10_no_bot_beats_deductor():
	var r = _fixture()
	var lines: PackedStringArray = []
	for name in RunBots.BOTS:
		if name == "deductor":
			continue
		var seeds: Array = (RANDOM_SEEDS_SLOW if slow else RANDOM_SEEDS) if RANDOM.has(name) and (slow or not HEAVY.has(name)) else _seeds()
		var endings: PackedStringArray = []
		for seed in seeds:
			var d := _run(r, "fx", "deductor", seed)
			var b := _run(r, "fx", String(name), seed)
			var lb := "%s/s%d" % [name, seed]
			_clean(b, lb)
			ok(int(b.rank) >= int(d.rank), "%s: rank %d (%s) mejor que el del deductor %d (%s)" % [lb, b.rank, b.ending, d.rank, d.ending])
			_behaves(String(name), b, d, lb)
			endings.append("%s(%d sellos)" % [b.ending, (b.sealed as Array).size()])
		lines.append("%s: %s" % [name, ", ".join(endings)])
	print("T10 fixture — finales por bot:\n  " + "\n  ".join(lines))

# Lo que define a cada bot efectivamente ocurrió.
func _behaves(name: String, b: Dictionary, d: Dictionary, lb: String) -> void:
	var v: Dictionary = b.get("verbs", {})
	match name:
		"novato":
			ok(int(b.words_read) > 0, lb + " lee")
			for t in ["read", "dq_answer", "dq_proof", "dq_confirm"]:
				ok(v.has(t), lb + " emite " + t)
			eq(b.get("blocked", {}), {}, lb + " verbos no enseñados que necesitó")
			ok(float(b.est_minutes_act.get("III", 0.0)) > 0.0, lb + " mide el Acto III")
		"pesca":
			ok(int(b.confirms) >= 3, lb + " pasa en limpio (%d)" % int(b.confirms))
		"fuerza_bruta", "sabelotodo":
			ok(int(b.confirms) >= 10, lb + " pasa en limpio (%d)" % int(b.confirms))
			ok(int(v.get("clip_text", {}).get("free", 0)) > int(d.verbs.get("clip_text", {}).get("free", 0)), lb + " recorta más que el deductor")
		"recorta_todo":
			ok(int(v.get("clip_text", {}).get("free", 0)) > int(d.verbs.get("clip_text", {}).get("free", 0)), lb + " recorta más que el deductor")
		"cebo":
			ok(int(b.get("ads", 0)) >= 4, lb + " avisos-cebo: %d" % int(b.get("ads", 0)))
		"informa_todo":
			var n := 0
			for rp in b.get("reports", []):
				n += int(rp.get("items", 0))
			ok(n >= 3, lb + " ítems entregados a Moran: %d" % n)
		"solo_bm":
			for pk in b.get("places", {}):
				eq(String(pk), "L2.sala", lb + " sólo sale a la Sala de Lectura")
			ok(b.get("places", {}).has("L2.sala"), lb + " va a la Sala")
		"confront_azar":
			var steps: Array = b.get("confront", [])
			ok(not steps.is_empty(), lb + " llega a la confrontación")
			for s in steps:
				ok(not (s.get("item", {}) as Dictionary).is_empty(), lb + " nunca calla")
		"mycroft_azar":
			ok((b.get("mycroft", []) as Array).size() >= 1, lb + " presenta ante Mycroft")
			for m in b.get("mycroft", []):
				ok(bool(m.get("ok", false)), lb + " presentación aceptada por el sim: " + str(m))

# GDD_v3 §1.9 / §2.4: fuerza bruta cierra ≤5 % de las preguntas que intenta; sabelotodo se mide (sin umbral).
func test_t10_brute_force_budget():
	var r = _fixture()
	var n := BRUTE_N_SLOW if slow else BRUTE_N
	var tried := 0
	var closed := 0
	for i in n:
		var seed := 1000 + i
		var p := RunBots.run_one(r, "fuerza_bruta", seed, 40000, 600000)
		eq(String(p.get("runaway", "")), "", "fuerza_bruta/s%d salvaguarda" % seed)
		eq(String(p.get("phase", "")), "done", "fuerza_bruta/s%d termina" % seed)
		tried += (p.get("attempts", {}) as Dictionary).size()
		closed += (p.get("sealed", []) as Array).size()
		ok(int(p.rank) >= _best_rank(r), "fuerza_bruta/s%d" % seed)
	var rate := float(closed) / float(maxi(tried, 1))
	print("T10 fuerza bruta: %d partidas, %d preguntas intentadas, %d cerradas (%.1f %%)" % [n, tried, closed, rate * 100.0])
	ok(tried > 0, "intenta")
	ok(rate <= BRUTE_BUDGET, "fuerza bruta cierra %.1f %% de las preguntas (> 5 %%)" % [rate * 100.0])
	var sb := _run(r, "fx", "sabelotodo", 1, 600000)
	_clean(sb, "sabelotodo")
	var st := (sb.get("attempts", {}) as Dictionary).size()
	print("T10 sabelotodo (respuesta correcta, par al azar, 50 intentos): %d de %d preguntas en tinta, %d confirmaciones" % [(sb.sealed as Array).size(), st, int(sb.confirms)])

func test_t10_novato_act3():
	var r = _fixture()
	var nv := _run(r, "fx", "novato", SEEDS[0])
	_clean(nv, "novato")
	var em: Dictionary = nv.get("est_minutes_act", {})
	print("T10 novato (fixture): %.1f min de lectura; por tramo %s" % [float(nv.est_minutes), str(em)])
	ok(float(em.get("III", 0.0)) > 0.0, "Acto III medido")
	near(float(nv.est_minutes), float(nv.words_read) / 180.0 * 1.3, 0.2, "minutos = palabras/180 × 1,3")

# ------------------------------------------------------------------ play_cli (lógica en devtools/bots/play_session.gd)
func test_t10_play_cli_session():
	var PS = load("res://devtools/bots/play_session.gd")
	var r = _fixture()
	var s = PS.new(r, 1)
	s.echo = false
	s.strict = true
	s.exec("state")
	ok("\n".join(s.out).contains("ESTADO"), "state")
	ok("\n".join(s.out).contains("prologue"), "estado inicial = prólogo")
	s.exec("read D23@L1")
	ok("\n".join(s.out).contains("D23@L1:0:0"), "read numera páginas y bloques")
	s.exec("tags D23@L1")
	s.exec("q clock")
	ok("\n".join(s.out).contains("\"phase\": \"prologue\""), "q clock en JSON")
	var f0: int = s.fails
	s.exec("{\"t\": \"sleep\"}")
	eq(int(s.fails), f0 + 1, "acción rechazada (tutorial) cuenta con --strict")
	s.fails = 0
	var n0: int = s.sim.st.ded.get("clips", {}).size()
	s.exec("clip D23@L1 Un aviso de testigos")
	eq(int(s.sim.st.ded.get("clips", {}).size()), n0 + 1, "clip por texto exacto")
	s.exec("clip D23@L1 texto que no está")
	eq(int(s.fails), 1, "texto no encontrado")
	s.fails = 0
	s.exec("bot deductor hasta 2.M")
	eq(int(s.sim.q_clock().day), 2, "bot hasta 2.M")
	var h: String = s.sim.state_hash()
	s.exec("save t10_cli.json")
	var s2 = PS.new(r, 1)
	s2.echo = false
	s2.exec("load t10_cli.json")
	eq(s2.sim.state_hash(), h, "save/load reproduce el estado")
	s.exec("bot deductor")
	eq(String(s.sim.q_clock().phase), "done", "el bot termina la partida")
	ok(not (s.sim.q_ending() as Dictionary).is_empty(), "q ending")
	s.exec("comando_inexistente")
	ok(int(s.fails) >= 1, "comando desconocido")
	# revisión de documento (--doc)
	var s3 = PS.new(r, 1)
	s3.echo = false
	s3.review_doc("D16")
	eq(int(s3.fails), 0, "\n".join(s3.out))
	ok("\n".join(s3.out).contains("Q7.R2 D16#moran"), "lista los fragmentos de contrato: " + "\n".join(s3.out))
	s3.fails = 0
	s3.review_doc("NO_EXISTE")
	eq(int(s3.fails), 1)
	var long_t := " ".join(PackedStringArray(range(32).map(func(i): return "palabra")))
	var pt: Dictionary = r.parse_text("{{#x a:foo|%s.}}" % long_t)
	ok(String(s3.tramo_check(pt, pt.tramos[0])) != "", "tramo de 32 palabras: ninguna ventana de 15 lo hereda (GDD_v3 §6.2)")
	var pt2: Dictionary = r.parse_text("{{#x a:foo|Uno dos tres cuatro.}}")
	eq(String(s3.tramo_check(pt2, pt2.tramos[0])), "", "tramo corto: el recorte de prueba lo hereda")

# ------------------------------------------------------------------ data/ real
func test_t10_real_data():
	var r = _real_repo()
	var rep := BotData.content_report(r)
	if not bool(rep.ok):
		pending_content("T10 sobre data/ real: faltan rutas ★ completas de %s; errores de carga %d" % [str(rep.missing), (rep.errors as Array).size()])
		return
	var d := _run(r, "real", "deductor", 1)
	_clean(d, "real/deductor")
	eq(d.get("oracle", []), [], "real/deductor fallas del oráculo")
	eq(d.get("unsealed", {}), {}, "real/deductor obligatorias sin sellar")
	eq(int(d.rank), _best_rank(r), "real/deductor alcanza el mejor final (%s; informe final %s, confrontación %s)" % [d.ending,
		String(d.flags.get("informe_final", "")), str((d.get("confront", []) as Array).map(func(x): return bool(x.get("hit", false))))])
	var p := _run(r, "real", "pasivo", 1)
	_clean(p, "real/pasivo")
	eq(String(p.ending), "F4", "real/pasivo")
	for name in RunBots.BOTS:
		if name == "deductor" or name == "pasivo":
			continue
		if HEAVY_REAL.has(name) and not slow:
			print("T10 data/ real: %s sólo con --slow (carga)" % name)
			continue
		var b := _run(r, "real", String(name), 1, HEAVY_REAL_BUDGET_MS if HEAVY_REAL.has(name) else 120000)
		_clean(b, "real/" + String(name))
		ok(int(b.rank) >= int(d.rank), "real/%s: rank %d (%s) mejor que el del deductor %d" % [name, b.rank, b.ending, d.rank])
	var nv := _run(r, "real", "novato", 1)
	# Acto III con minutos de JUEGO (lectura + interacción + deliberación; modelo de bot_base T_ACT), no sólo de lectura:
	# con la lectura sola la cota pasaba siempre (W4-BALANCE).
	var a3 := float(nv.get("play_minutes_act", {}).get("III", 0.0))
	print("T10 novato (data/ real): juego %.1f min en total, por tramo %s; lectura %.1f min, por tramo %s (tope Acto III %.0f; GDD §7.7 → §15.7)" % [
		float(nv.get("play_minutes", 0.0)), str(nv.get("play_minutes_act", {})), float(nv.get("est_minutes", 0.0)), str(nv.get("est_minutes_act", {})), ACT3_MAX_MIN])
	ok(a3 > 0.0, "Acto III medido en minutos de juego")
	ok(a3 <= ACT3_MAX_MIN, "Acto III del novato: %.1f min de juego > %.0f (adelantar material, GDD §15.7)" % [a3, ACT3_MAX_MIN])
	if slow:
		var tried := 0
		var closed := 0
		for i in 5:
			var fb := RunBots.run_one(r, "fuerza_bruta", 2000 + i, 40000, HEAVY_REAL_BUDGET_MS)
			tried += (fb.get("attempts", {}) as Dictionary).size()
			closed += (fb.get("sealed", []) as Array).size()
		ok(float(closed) / float(maxi(tried, 1)) <= BRUTE_BUDGET, "real/fuerza bruta: %d de %d" % [closed, tried])

# Sondas del oráculo sobre data/ real (W4-BALANCE): partidas del deductor que la estándar no recorre. Un foco sin
# compañeras opcionales y un jugador que deja pasar los primeros días. Cada una: sin fallas del oráculo (una ruta ★ que
# el plan da por obtenible y no lo es) y partida limpia.
func test_t10_real_oracle_probes():
	var r = _real_repo()
	if not bool(BotData.content_report(r).ok):
		pending_content("T10 sondas del oráculo: contenido incompleto")
		return
	var probes := [
		{"label": "foco Q1-Q2-Q3-Q5-Q6-Q9", "focus": ["Q1", "Q2", "Q3", "Q5", "Q6", "Q9"], "idle": 0},
		{"label": "tardío día 5", "focus": [], "idle": 5},
		{"label": "tardío día 8", "focus": [], "idle": 8},
	]
	for pr in probes:
		var b = RunBots.make("deductor")
		var sim = load("res://core/sim/game_sim.gd").new(r, 1)
		b.budget_ms = 600000
		b.setup(sim, 1)
		if not (pr.focus as Array).is_empty():
			b.focus = (pr.focus as Array).duplicate()
			b.fillers = false
		b.idle_until_day = int(pr.idle)
		var res: Dictionary = b.play(20000)
		print("T10 sonda %s: %s (rank %d) sellos %s oráculo %s" % [pr.label, res.ending, int(res.rank), str(res.sealed), str(res.oracle)])
		_clean(res, "sonda " + String(pr.label))
		eq(res.get("oracle", []), [], "sonda %s: fallas del oráculo" % pr.label)


# Sondas con guion sobre data/ real (hallazgo del playtest: cobertura sin verificar). Ningún bot de §9.3 recorre los
# canarios a Watson (HA4), pagar a Wiggins (HB8) ni entregar notas privadas de Watson dos veces (M3 → HB9 →
# watson_expuesto, V.expuesto). Guiones de la auditoría (.work/audit_sys/beats_canary.json, ab_m3.gd) en bot_guion.
const BEATS_CANARY := [
	{"tk": "1.M", "go": ["L4", "consulta"], "acts": [{"t": "assert", "char": "watson", "assertion": "cn.chelsea"}]},
	{"tk": "4.M", "go": ["L4", "consulta"], "acts": [{"t": "assert", "char": "watson", "assertion": "cn.boda"}]},
	{"tk": "3.T", "go": ["L3", "calle"], "acts": [{"t": "pay", "char": "wiggins", "amount_d": 12}]},
	{"tk": "5.M", "go": ["L3", "calle"], "acts": [{"t": "assert", "char": "wiggins", "assertion": "cn.edimburgo"}]},
]

func _guion(r, beats: Array, leak: Array) -> Array:
	var b = load("res://devtools/bots/bot_guion.gd").new()
	var sim = load("res://core/sim/game_sim.gd").new(r, 1)
	b.budget_ms = 600000
	b.setup(sim, 1)
	b.beats = beats.duplicate(true)
	b.leak_reports = leak.duplicate()
	var res: Dictionary = b.play(20000)
	return [b, res, sim]

func test_t10_real_scripted_probes():
	var r = _real_repo()
	if not bool(BotData.content_report(r).ok):
		pending_content("T10 sondas con guion: contenido incompleto")
		return
	var g := _guion(r, BEATS_CANARY, [])
	var res: Dictionary = g[1]
	print("T10 guion canarios: %s; entregadas %s; golpes %s" % [res.ending, str(g[0].delivered()), str(g[0].beat_log)])
	_clean(res, "guion canarios")
	eq(res.get("oracle", []), [], "guion canarios: fallas del oráculo")
	for st_beat in g[0].beat_log:
		ok(bool(st_beat.ok), "golpe %s %s: %s" % [st_beat.tk, st_beat.a, st_beat.err])
	has(g[0].delivered(), "HA4", "canario a Watson → HA4")
	has(g[0].delivered(), "HB8", "pagarle a Wiggins → HB8")
	ok(bool(g[2].st.flags.get("wiggins_aliado", false)), "wiggins_aliado")
	var g2 := _guion(r, [], [1, 2])
	var res2: Dictionary = g2[1]
	print("T10 guion notas de Watson: %s; variantes %s; entregadas %s" % [res2.ending, str(res2.variants), str(g2[0].delivered())])
	_clean(res2, "guion notas de Watson")
	eq(res2.get("oracle", []), [], "guion notas de Watson: fallas del oráculo")
	ok(g2[0].delivered().count("M3") >= 2, "dos entregas de material privado → M3 dos veces")
	has(g2[0].delivered(), "HB9")
	ok(bool(g2[2].st.flags.get("watson_expuesto", false)), "la segunda entrega tras HB9 expone a Watson")
	has(res2.variants, "V.expuesto", "variante del epílogo")
	ok(String(res2.ending) != "F1", "watson_expuesto impide F1")
