# W4-SLICE · rebanada vertical (GDD §15.6 H3; ARCHITECTURE §10 ola 4) sobre data/ REAL, con el guion
# devtools/scripts/slice_f1.jsonl (el mismo que juega la partida completa hasta F1): prólogo y días 1–3 hasta el amanecer
# del 4. Verifica, con lo que el jugador ve (q_*) y el estado público (eventos, reacciones entregadas):
#   tutorial completo (práctica C1 en tinta) y el aviso del prólogo publicado el día 1 (AD:prologo, columna del 27);
#   las cinco reacciones de la rebanada: HC01 (1.dawn), HA1 (papeleta → 2.dawn), HB1 DESDE WATSON (cebo K-W del día 1 →
#   carta «—S.» del 4), HC02 (silueta de Wiggins, 3.dawn) y HC10 (columna del 30 que cita el aviso);
#   un lote pasado en limpio que sella; el informe 1 con M1 (original P: la buhardilla «registrada», HB10 lo devuelve);
#   el diario (actos, llegadas y líneas dichas, cada una con su sello) y el guardado por compromiso (Game: el registro en
#   disco reproduce el mismo estado; continuar la partida lo recupera byte a byte).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120
const S = preload("res://devtools/drivers/slice_script.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")
const Effects = preload("res://core/react/effects.gd")

static var _cache := {}

func _script() -> Dictionary:
	if not _cache.has("f1"):
		_cache["f1"] = S.load_script(S.path("f1"))
	return _cache["f1"]

# Acciones del guion hasta el amanecer del día 4 (la primera que se aplicaría con el reloj en el día 4, excluida).
func _prefix(repo, sc: Dictionary) -> Dictionary:
	var sim = GameSim.new(repo, int(sc.seed))
	var acts: Array = []
	var rejected: Array = []
	for a in sc.actions:
		if int(sim.q_clock().day) >= 4:
			break
		var r: Dictionary = sim.apply(a)
		if not bool(r.get("ok", false)):
			rejected.append("%s -> %s" % [J.stringify_canon(a).left(140), String(r.get("err", ""))])
		acts.append(a)
	return {"sim": sim, "actions": acts, "rejected": rejected}

static func _delivered(sim, rid: String) -> Array:
	return (sim.st.react.delivered as Array).filter(func(i): return String(i.rid) == rid)

static func _tray(sim, day: int) -> Array:
	return sim.q_tray(day).map(func(x): return String(x.view))

func test_scripts_parse() -> void:
	for k in S.KEYS:
		var sc := S.load_script(S.path(k))
		ok(bool(sc.ok), "guion %s: %s" % [k, String(sc.err)])
		if not bool(sc.ok):
			continue
		eq(int(sc.seed), 1, "%s: semilla" % k)
		ne(String(sc.expect), "", "%s: final esperado" % k)
		ok((sc.actions as Array).size() > 50, "%s: acciones %d" % [k, (sc.actions as Array).size()])

func test_h3_vertical_slice() -> void:
	var repo = repo()
	if not repo.errors().is_empty():
		fail("data/ con errores de carga: %s" % str(repo.errors().slice(0, 5)))
		return
	var sc := _script()
	if not bool(sc.ok):
		fail(String(sc.err))
		return
	var p := _prefix(repo, sc)
	var sim = p.sim
	eq(p.rejected, [], "el guion se reproduce sin rechazos hasta el día 4 (si cambió el contenido a propósito: ./godot.sh --headless -s devtools/drivers/slice_record.gd -- all)")
	var c: Dictionary = sim.q_clock()
	eq([int(c.day), String(c.slot), String(c.phase)], [4, "M", "desk"], "la rebanada termina en el escritorio del viernes 30")
	# prólogo: tutorial y aviso
	ok(bool(sim.q_tutorial().get("complete", false)), "tutorial completo")
	var prac: Array = (sim.st.ded.entries.values() as Array).filter(func(e): return bool(e.get("practice", false)) and String(e.get("ink", "")) == "tinta")
	ok(prac.size() >= 1 and String(prac[0].get("cid", "")).begins_with("C1."), "práctica de C1 en tinta: %s" % str(prac.map(func(e): return e.get("cid", ""))))
	var ad_ev: Array = (sim.st.events as Array).filter(func(e): return String(e.type) == "ad" and String(e.get("ad", "")) == "AD:prologo")
	ok(ad_ev.size() == 1 and int(ad_ev[0].tk) == TimeKey.tk(1, "dawn"), "aviso del prólogo publicado al amanecer del día 1: %s" % str(ad_ev))
	ok(_tray(sim, 1).has("D15.0327@L1"), "el Times del 27 en la bandeja del día 1")
	# las cinco reacciones de la rebanada
	var hc01 := _delivered(sim, "HC01")
	ok(hc01.size() == 1 and int(hc01[0].delivered_tk) == TimeKey.tk(1, "dawn") and _tray(sim, 1).has(String(hc01[0].get("view", ""))), "HC01 en la bandeja del día 1: %s" % str(hc01.map(func(i): return [i.get("view"), i.delivered_tk])))
	var slips: Array = (sim.st.events as Array).filter(func(e): return String(e.type) == "slip" and int(e.day) == 1)
	ok(not slips.is_empty(), "papeletas en la Sala de Lectura el día 1")
	var ha1 := _delivered(sim, "HA1")
	ok(not ha1.is_empty() and int(ha1[0].delivered_tk) == TimeKey.tk(2, "dawn"), "HA1 (la papeleta, K-BM) al amanecer del 2: %s" % str(ha1.map(func(i): return i.delivered_tk)))
	var bait: Array = (sim.st.events as Array).filter(func(e): return String(e.type) == "say" and String(e.get("char", "")) == "watson" and String(e.get("bait_topic", "")) == "pared")
	ok(bait.size() == 1 and int(bait[0].day) == 1, "cebo «a pique» dicho a Watson el día 1: %s" % str(bait))
	var hb1 := _delivered(sim, "HB1")
	ok(hb1.size() == 1, "HB1 entregada: %s" % str(hb1.map(func(i): return [i.get("tpl"), i.delivered_tk])))
	if hb1.size() == 1:
		eq(String(hb1[0].get("tpl", "")), "pared.1.kw", "HB1 desde Watson (K-W, cebo 1)")
		eq(int(hb1[0].delivered_tk), TimeKey.tk(4, "dawn"), "HB1 con la demora de la voz B (día 1 → día 4)")
		ok(_tray(sim, 4).has(String(hb1[0].get("view", ""))), "la carta «—S.» en la bandeja del 4")
		var txt := String(hb1[0].get("text", ""))
		ok(txt.contains("doctor") or txt.contains("watson"), "la carta cita lo que se le dijo al doctor: %s" % txt.left(160))
	var hc02 := _delivered(sim, "HC02")
	ok(hc02.size() == 1 and int(hc02[0].delivered_tk) == TimeKey.tk(3, "dawn"), "HC02 al amanecer del 3")
	ok(Effects.silhouettes(sim.st, "L3", 3).has("wiggins"), "Wiggins en la calle desde HC02")
	var sil_clips: Array = (sim.st.ded.clips.values() as Array).filter(func(cl): return (cl.get("tags", []) as Array).has("a:ancla_ks"))
	ok(not sil_clips.is_empty(), "la silueta de Wiggins recortada (ancla K-S)")
	var hc10 := _delivered(sim, "HC10")
	ok(hc10.size() == 1 and String(hc10[0].get("how", "")) == "columna" and int(hc10[0].delivered_tk) == TimeKey.tk(4, "dawn"), "HC10 en la columna del 30: %s" % str(hc10.map(func(i): return [i.get("how"), i.delivered_tk])))
	ok((sim.st.world.get("inserts", {}).get("D15.0330", {}).get("p2", []) as Array).size() >= 1, "HC10 insertada en la columna del Times del 30")
	# un lote en limpio que sella
	var inked: Array = (sim.st.ded.get("passes", []) as Array).filter(func(x): return bool(x.get("inked", false)))
	ok(not inked.is_empty(), "al menos una pasada en limpio en tinta: %s" % str(sim.st.ded.get("passes", [])))
	ok(sim.st.ded.sealed.size() >= 2, "conclusiones selladas en la rebanada: %s" % str(sim.st.ded.sealed.keys()))
	# informe 1 con M1 (y HB10)
	var rep: Array = (sim.st.events as Array).filter(func(e): return String(e.type) == "report" and int(e.get("n", 0)) == 1)
	ok(rep.size() == 1, "informe 1 entregado")
	if rep.size() == 1:
		var cats: Array = []
		for it in rep[0].get("items", []):
			cats.append_array(it.get("cats", []))
		ok(cats.has("original_p") and cats.has("verdadero"), "el informe 1 lleva un original P y un dato verdadero: %s" % str(cats))
	var m1 := _delivered(sim, "M1")
	var m3 := _delivered(sim, "M3")
	ok(m1.size() + m3.size() >= 1, "el informe 1 dispara M1 o M3")
	eq(String(sim.q_hub_plate().get("variant", "")), "registrada", "la buhardilla quedó registrada (M1), como la ve el jugador")
	var hb10 := _delivered(sim, "HB10")
	ok(hb10.size() == 1 and String(hb10[0].get("how", "")) == "mostrador_crane", "HB10 devuelve el original por el mostrador de Crane: %s" % str(hb10.map(func(i): return i.get("how"))))
	ok(bool(sim.st.flags.get("moran_credito", false)), "crédito ante Moran desde el informe 1")
	# diario
	var dia: Array = sim.q_diary()
	var kinds := {}
	for e in dia:
		kinds[String(e.kind)] = int(kinds.get(String(e.kind), 0)) + 1
		if String(e.get("stamp", "")) == "":
			fail("línea del diario sin sello: %s" % str(e).left(160))
	ok(int(kinds.get("act", 0)) >= 8 and int(kinds.get("arrival", 0)) >= 4 and int(kinds.get("line", 0)) >= 3, "diario con actos, llegadas y líneas: %s" % str(kinds))
	var go_l4: Array = dia.filter(func(e): return String(e.get("type", "")) == "go" and int(e.day) == 1 and String(e.get("text", "")).contains("Kensington"))
	ok(not go_l4.is_empty(), "el diario registra la visita a Kensington del día 1")

# Guardado por compromiso con el autoload Game y el registro en disco (GDD §7.6): la rebanada termina con «dormir»
# (comprometida), así que el disco tiene todo; continuar reproduce el mismo estado.
func test_h3_save_and_continue() -> void:
	var sc := _script()
	if not bool(sc.ok):
		fail(String(sc.err))
		return
	var p := _prefix(repo(), sc)
	var acts: Array = p.actions
	var old := [Game.save_path, Game.repo_override]
	Game.save_path = tmp_dir().path_join("slice_h3.jsonl")
	Game.repo_override = null
	ok(Game.new_session(int(sc.seed)), "partida nueva")
	var bad := 0
	for a in acts:
		if not bool(Game.act(a).get("ok", false)):
			bad += 1
	eq(bad, 0, "Game.act acepta todo el prefijo")
	var h: String = Game.sim.state_hash()
	eq(h, p.sim.state_hash(), "Game y GameSim llegan al mismo estado")
	# «matar» el proceso: sin flush; lo que está en disco
	var r: Dictionary = EventLog.read(Game.save_path)
	ok(bool(r.get("ok", false)), "registro legible: %s" % str(r.get("err", "")))
	if bool(r.get("ok", false)):
		eq(int(r.header.seed), int(sc.seed), "semilla en la cabecera")
		var re = GameSim.replay(repo(), int(r.header.seed), r.actions)
		eq(int(re.replay_errors), 0, "el registro en disco se reproduce sin rechazos")
		eq(re.state_hash(), h, "el disco reproduce el estado de la última acción comprometida")
	Game._dirty = false
	Game.end_session()
	ok(Game.continue_session(), "continuar la partida")
	if Game.sim != null:
		eq(Game.sim.state_hash(), h, "continuar recupera el estado byte a byte")
		eq(String(Game.sim.q_clock().phase), "desk", "se continúa en el escritorio del 30")
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
