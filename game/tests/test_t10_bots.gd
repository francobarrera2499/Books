# T10 (W3-BOTS; GDD §15.5, §8.9, §11, §7.7; ARCHITECTURE §9.2/§9.3): bots. Los 11 bots de §9.3 juegan partidas
# completas (prólogo → epílogo) por GameSim.apply. Verifica: el deductor (oráculo de rutas ★) alcanza el mejor final y
# es la cota: ningún bot logra un `rank` mejor que el del deductor con la misma semilla; el pasivo termina en F4; la pesca
# (fundamentos correctos, valores al azar) no sella C6, C7 y C10 en la misma partida en más del 5 % (15 partidas; con
# --slow las 200 del criterio y más semillas por bot); el novato mide el Acto III (palabras/180 × 1,3). Cada bot además hace lo
# que lo define (si no, la cota sería vacía): cebo pone avisos, informa-todo entrega ítems, sólo-BM sólo va a la Sala,
# el acusador al azar nunca calla, el presentador al azar le muestra cosas a Mycroft, etc.
# Dataset «fixture» (estructura real de data/ + contenido mínimo de tests/fixtures/{integ,bots}); sobre data/ real
# cuando el contenido esté completo (si no: pending_content con lo que falta): el deductor debe sellar todas las
# obligatorias sin fallas del oráculo (una ruta ★ que el plan da por obtenible y no lo es, falla) y ser la cota; fuerza
# bruta y recorta-todo sobre data/ real sólo con --slow (minutos de CPU). Presupuesto de reloj por partida
# (salvaguarda contra bucles): 120 s (600 s para los pesados sobre data/ real).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 1200.0
const BotData = preload("res://devtools/bots/bot_data.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const SEEDS := [1]
const SEEDS_SLOW := [1, 2, 3]
const RANDOM_SEEDS := [1, 2]
const RANDOM_SEEDS_SLOW := [1, 2, 3, 4, 5]
const RANDOM := ["pesca", "fuerza_bruta", "confront_azar", "mycroft_azar"]
const HEAVY := ["fuerza_bruta"]   # ~10 s por partida (estado grande: cada apply copia el estado); una semilla salvo --slow
# Sobre data/ real, recortar todo cuesta minutos (≈2.600 apply, ~60 ms cada uno al final: GameSim._apply copia el estado):
# sólo con --slow y con más presupuesto de reloj (carga del PC: la suite normal no los corre).
const HEAVY_REAL := ["fuerza_bruta", "recorta_todo"]
const HEAVY_REAL_BUDGET_MS := 600000
const PESCA_N := 15
const PESCA_N_SLOW := 200
const PESCA_BUDGET := 0.05
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
	eq(RunBots.BOTS.size(), 11)
	for name in ["deductor", "novato", "pasivo", "pesca", "fuerza_bruta", "recorta_todo", "cebo", "informa_todo", "solo_bm",
			"confront_azar", "mycroft_azar"]:
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
			has(d.sealed, String(cid), lb + " sella")
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
		eq(p.sealed, [], "pasivo/s%d no sella" % seed)

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
			eq(b.get("blocked", {}), {}, lb + " verbos no enseñados que necesitó")
			ok(float(b.est_minutes_act.get("III", 0.0)) > 0.0, lb + " mide el Acto III")
		"pesca":
			ok(int(b.passes) >= 3, lb + " pasa en limpio (%d)" % int(b.passes))
		"fuerza_bruta":
			ok(int(b.passes) >= 3, lb + " pasa en limpio (%d)" % int(b.passes))
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

func test_t10_pesca_budget():
	var r = _fixture()
	var n := PESCA_N_SLOW if slow else PESCA_N
	var hits := 0
	var sealed_any := 0
	for i in n:
		var seed := 1000 + i
		var p := RunBots.run_one(r, "pesca", seed, 20000, 120000)
		eq(String(p.get("runaway", "")), "", "pesca/s%d salvaguarda" % seed)
		eq(String(p.get("phase", "")), "done", "pesca/s%d termina" % seed)
		var s: Array = p.get("sealed", [])
		if s.has("C6") and s.has("C7") and s.has("C10"):
			hits += 1
		if not s.is_empty():
			sealed_any += 1
		ok(int(p.rank) >= _best_rank(r), "pesca/s%d" % seed)
	var rate := float(hits) / float(n)
	print("T10 pesca: %d partidas, C6+C7+C10 en %d (%.1f %%), alguna conclusión sellada en %d" % [n, hits, rate * 100.0, sealed_any])
	ok(rate <= PESCA_BUDGET, "pesca sella C6, C7 y C10 en %.1f %% de %d partidas (> 5 %%)" % [rate * 100.0, n])

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
	s3.review_doc("D09")
	eq(int(s3.fails), 0, "\n".join(s3.out))
	ok("\n".join(s3.out).contains("C5.R1 D09#desague"), "lista los fragmentos de contrato")
	s3.fails = 0
	s3.review_doc("NO_EXISTE")
	eq(int(s3.fails), 1)
	var pt: Dictionary = r.parse_text("{{#x a:foo|Uno dos. Tres cuatro.}}")
	ok(String(s3.tramo_check(pt, pt.tramos[0])).contains("cruza_oracion"), "tramo que cruza oraciones: el recorte de prueba no es legal")

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
	var a3 := float(nv.get("est_minutes_act", {}).get("III", 0.0))
	print("T10 novato (data/ real): Acto III %.1f min (tope %.0f; GDD §7.7 → §15.7)" % [a3, ACT3_MAX_MIN])
	ok(a3 <= ACT3_MAX_MIN, "Acto III del novato: %.1f min > %.0f (adelantar material, GDD §15.7)" % [a3, ACT3_MAX_MIN])
	var hits := 0
	var n := 50 if slow else 10
	for i in n:
		var s: Array = RunBots.run_one(r, "pesca", 2000 + i, 20000, 120000).get("sealed", [])
		if s.has("C6") and s.has("C7") and s.has("C10"):
			hits += 1
	ok(float(hits) / n <= PESCA_BUDGET, "real/pesca: %d de %d" % [hits, n])
