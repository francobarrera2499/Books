# T24 (W3-BOTS; CORE-EXPEDIENTE, GDD_v3 §2.4, §6.9; GDD §15.5, §3.2, §7.7; ARCHITECTURE §9.2/§9.3): rampa de enseñanza. El
# bot novato (sólo verbos ya enseñados por Tutorial; lee todo) toca read, clip_text, compose_ad y sleep en el prólogo y
# dq_answer, dq_proof y dq_confirm en el día 1 guiado antes de cualquier otro uso de esos verbos; cada verbo con costo se
# toca antes en un contexto guiado (prólogo) o gratuito (la tienda de Crane); nunca necesita un verbo que la rampa no le
# enseñó (stats.blocked vacío); los verbos retirados (pares, hojas, plantillas, práctica, pasadas por lote) no existen; y
# aun así termina la partida investigando (pasa en limpio preguntas).
# Dataset: «fixture» (estructura real + contenido mínimo de tests/fixtures/{integ,bots}); sobre data/ real cuando el
# contenido esté completo (si no: pending_content con lo que falta).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 300.0
const BotData = preload("res://devtools/bots/bot_data.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const Novato = preload("res://devtools/bots/bot_novato.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const Actions = preload("res://core/sim/actions.gd")
const RETIRED := ["link", "unlink", "folio_open", "entry_new", "entry_set", "entry_support_add", "practice", "pass_clean",
	"clip_measure"]

static var _fx = null
static var _runs := {}

func _fixture():
	if _fx == null:
		_fx = BotData.repo("fixture")
	return _fx

# {res, log, taught} del novato con esa semilla (cacheado por archivo).
func _novato(r, seed: int, key: String) -> Dictionary:
	var k := "%s|%d" % [key, seed]
	if not _runs.has(k):
		var bo: Array = []
		var res := RunBots.run_one(r, "novato", seed, 20000, 120000, bo)
		var b = bo[0] if not bo.is_empty() else null
		_runs[k] = {"res": res, "log": b.log if b != null else [], "taught": b.sim.q_tutorial().get("taught", []) if b != null else []}
	return _runs[k]

func _check_ramp(run: Dictionary, label: String) -> void:
	var res: Dictionary = run.res
	eq(res.get("errors", []), [], label + " errores del bot")
	eq(String(res.get("runaway", "")), "", label + " salvaguarda")
	eq(String(res.get("phase", "")), "done", label + " la partida termina")
	eq(Novato.prologue_missing(run.log), [], label + " pasos del prólogo sin tocar")
	# GDD_v3 §6.9: el día 1 guiado (leer, respuesta, pruebas) antes de pasar en limpio por primera vez, y ese mismo día
	eq(Novato.day1_violations(run.log), [], label + " día 1 guiado")
	for e in run.log:
		ok(not RETIRED.has(String(e.t)), label + " verbo retirado en el registro: " + String(e.t))
	var reads := 0
	for e in run.log:
		if bool(e.ok) and String(e.t) == "read":
			reads += 1
	ok(reads > 0, label + " el novato emite `read` al leer")
	var v := Novato.ramp_violations(run.log)
	ok(v.is_empty(), label + " rampa:\n  " + "\n  ".join(PackedStringArray(v)))
	eq(res.get("blocked", {}), {}, label + " verbos que el novato necesitó sin que la rampa los enseñara")
	# todo verbo con costo usado figura en lo que enseñó Tutorial
	var used := {}
	for e in run.log:
		if bool(e.ok) and bool(e.get("costly", false)):
			used[String(e.t)] = true
	for t in used:
		has(run.taught, t, label + " Tutorial.verbs_taught")
	# contextos gratuitos efectivamente usados (no basta con que estén enseñados)
	var free_seen := {}
	for e in run.log:
		if bool(e.ok) and bool(e.get("free", false)) and String(e.phase) != "prologue":
			free_seen[String(e.t)] = true
	for t in ["go", "ask", "assert", "present"]:
		if used.has(t):
			ok(free_seen.has(t), "%s %s: se usó con costo pero nunca gratis fuera del prólogo" % [label, t])

func test_retired_verbs_do_not_exist():
	for t in RETIRED:
		if t == "clip_measure":
			continue   # se admite para reproducir partidas viejas (Tutorial.CLIP_ACTS), pero no se enseña
		no(Actions.SPEC.has(t), "v3: la acción %s no existe" % t)
	for t in ["dq_answer", "dq_proof", "dq_confirm", "examine", "ask_donde"]:
		ok(Actions.SPEC.has(t), "v3: la acción %s existe" % t)

func test_t24_checker_detects_violations():
	# registro sintético: preguntar con costo antes que gratis; papeleta sin enseñanza
	var lg := [
		{"t": "clip_text", "ok": true, "free": true, "costly": false, "taught": true, "phase": "prologue", "tk": 3},
		{"t": "ask", "ok": true, "free": false, "costly": true, "taught": true, "phase": "visit", "tk": 11},
		{"t": "ask", "ok": true, "free": true, "costly": false, "taught": true, "phase": "visit", "tk": 12},
		{"t": "slip", "ok": true, "free": false, "costly": true, "taught": false, "phase": "visit", "tk": 12},
		{"t": "dq_confirm", "ok": true, "free": true, "costly": false, "taught": true, "phase": "desk", "tk": 13},
	]
	var v := Novato.ramp_violations(lg)
	eq(v.size(), 2, str(v))
	# y el orden correcto no da violaciones
	var good := [
		{"t": "clip_text", "ok": true, "free": true, "costly": false, "taught": true, "phase": "prologue", "tk": 3},
		{"t": "go", "ok": true, "free": true, "costly": false, "taught": true, "phase": "desk", "tk": 11},
		{"t": "ask", "ok": true, "free": true, "costly": false, "taught": true, "phase": "visit", "tk": 11},
		{"t": "go", "ok": true, "free": false, "costly": true, "taught": true, "phase": "desk", "tk": 12},
		{"t": "ask", "ok": true, "free": false, "costly": true, "taught": true, "phase": "visit", "tk": 12},
		{"t": "slip", "ok": true, "free": false, "costly": true, "taught": true, "phase": "visit", "tk": 12},
		{"t": "dq_confirm", "ok": true, "free": true, "costly": false, "taught": true, "phase": "desk", "tk": 13},
	]
	eq(Novato.ramp_violations(good), [])
	# un uso fallido no cuenta como «tocado»
	var failed := [
		{"t": "go", "ok": false, "free": true, "costly": false, "taught": true, "phase": "desk", "tk": 11},
		{"t": "go", "ok": true, "free": false, "costly": true, "taught": true, "phase": "desk", "tk": 11},
	]
	eq(Novato.ramp_violations(failed).size(), 1)
	eq(Novato.prologue_missing([]).size(), Novato.PROLOGUE_TOUCH.size())
	# día 1 guiado: pasar en limpio sin leer, responder y poner pruebas antes es violación; hacerlo recién el día 2, también
	var d1_bad := [{"t": "dq_confirm", "ok": true, "phase": "desk", "day": 1}]
	eq(Novato.day1_violations(d1_bad).size(), Novato.DAY1_TOUCH.size())
	var d1_good: Array = []
	for t in ["read", "dq_answer", "dq_proof", "dq_confirm"]:
		d1_good.append({"t": t, "ok": true, "phase": "desk", "day": 1})
	eq(Novato.day1_violations(d1_good), [])
	d1_good[3]["day"] = 2
	eq(Novato.day1_violations(d1_good).size(), 1, "la primera vez que pasa en limpio no es el día 1")
	eq(Novato.day1_violations([{"t": "dq_answer", "ok": true, "phase": "prologue", "day": 0}] + d1_good.slice(0, 3) + [{"t": "dq_confirm", "ok": true, "phase": "desk", "day": 1}]).size(), 1, "dq_* antes del día 1")

func test_t24_ramp_fixture():
	var r = _fixture()
	var rep := BotData.content_report(r)
	ok(bool(rep.ok), "el dataset fixture debe ser jugable: " + str(rep))
	for seed in [1, 2]:
		var run := _novato(r, seed, "fx")
		_check_ramp(run, "fixture/s%d" % seed)
		# investiga de verdad: pasa en limpio preguntas (si no, la rampa sería trivial)
		ok((run.res.get("sealed", []) as Array).size() >= 4, "fixture/s%d preguntas en tinta del novato: %s" % [seed, str(run.res.get("sealed", []))])
		ok(int(run.res.get("words_read", 0)) > 0, "el novato lee")

func test_t24_ramp_real_data():
	var r = BotData.repo("real")
	var rep := BotData.content_report(r)
	if not bool(rep.ok):
		pending_content("T24 sobre data/ real: faltan rutas ★ completas de %s; errores de carga %d" % [str(rep.missing), (rep.errors as Array).size()])
		return
	var run := _novato(r, 1, "real")
	_check_ramp(run, "real/s1")
