# W4-SLICE · partida completa por guion (ARCHITECTURE §10 ola 4; GDD §12) sobre data/ REAL: cada guion de
# devtools/scripts/slice_<final>.jsonl se reproduce del prólogo al epílogo SIN un solo rechazo y termina en su final:
#   f1  F1 «Al menos un lector» (C6, C7, C10 y ≥8 obligatorias; crédito ante Moran; errata a medida del librero;
#       confrontación completa; noche en Baker Street; variantes de §12.2 y lápiz azul)
#   f2  la misma investigación, informe final fiel → F2, y en 1903 publica la fe de erratas (V.publica)
#   f3a la misma investigación, informe final quemado → F3a
#   f4  un lector distraído (tres conclusiones) → F4
# Además: los guiones f2/f3a son f1 hasta el informe final (sólo cambia la decisión: determinismo del autor); cada día
# del 1 al 9 de f1 tiene una salida, llega algo a la bandeja o hay escena; el reloj recorre las fases de §3.2 en orden; la
# reproducción es determinista (dos replays = mismo hash).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240
const S = preload("res://devtools/drivers/slice_script.gd")

# CORE-EXPEDIENTE (v3): los guiones grabados con el libro de conclusiones (pares, asientos, pasadas por lote) ya no se
# reproducen. Hasta regenerarlos con devtools/drivers/slice_record.gd sobre data/ v3 completa (CONTENIDO y REACCIONES),
# la rebanada queda como contenido pendiente.
const V2_ACTS := ["link", "unlink", "folio_open", "entry_new", "entry_set", "entry_support_add", "entry_delete", "practice", "pass_clean", "clip_measure"]

func _stale() -> bool:
	for key in ["f1", "f4"]:
		var sc := S.load_script(S.path(key))
		if not bool(sc.ok):
			continue
		for a in sc.actions:
			if V2_ACTS.has(String(a.get("t", ""))):
				pending_content("devtools/scripts/slice_%s.jsonl es un guion v2 (%s): regenerar con slice_record.gd cuando data/ v3 esté completa" % [key, String(a.t)])
				return true
	return false
const GameSim = preload("res://core/sim/game_sim.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const J = preload("res://core/util/j.gd")

static var _runs := {}

# Reproduce un guion acción por acción (sin push_error: los rechazos se cuentan aquí) y anota el recorrido de fases.
func _run(key: String) -> Dictionary:
	if _runs.has(key):
		return _runs[key]
	var sc := S.load_script(S.path(key))
	var out := {"ok": bool(sc.ok), "err": String(sc.err), "sc": sc, "sim": null, "rejected": [], "phases": [], "days": {}}
	if not bool(sc.ok):
		_runs[key] = out
		return out
	var sim = GameSim.new(repo(), int(sc.seed))
	var last := ""
	for i in (sc.actions as Array).size():
		var a: Dictionary = sc.actions[i]
		var c: Dictionary = sim.q_clock()
		var ph := String(c.phase)
		if ph != last:
			out.phases.append(ph)
			last = ph
		var d := str(int(c.day))
		if not out.days.has(d):
			out.days[d] = {"go": 0, "acts": 0, "scene": false}
		out.days[d].acts += 1
		if String(a.t) == "go":
			out.days[d].go += 1
		if ["scene", "confront", "parklane"].has(ph):
			out.days[d].scene = true
		var r: Dictionary = sim.apply(a)
		if not bool(r.get("ok", false)):
			out.rejected.append("#%d (línea %d) %s -> %s" % [i, int(sc.lines[i]), J.stringify_canon(a).left(140), String(r.get("err", ""))])
	out.phases.append(String(sim.q_clock().phase))
	out.sim = sim
	_runs[key] = out
	return out

func _check_common(key: String) -> Dictionary:
	var r := _run(key)
	if not bool(r.ok):
		fail("guion %s: %s" % [key, String(r.err)])
		return {}
	eq(r.rejected, [], "%s: el guion se reproduce sin rechazos (si cambió el contenido a propósito: ./godot.sh --headless -s devtools/drivers/slice_record.gd -- all, y revisar el diff del guion)" % key)
	var sim = r.sim
	eq(String(sim.q_clock().phase), "done", "%s: llega al final de la partida" % key)
	var en: Dictionary = sim.q_ending()
	eq(String(en.get("ending", "")), String(r.sc.expect), "%s: final" % key)
	if String(r.sc.content) != String(repo().content_hash()):
		print("  (aviso) %s: el guion se grabó con otro contenido (%s); se reproduce igual" % [key, String(r.sc.content)])
	return en

static func _mandatory_sealed(sim, repo) -> Array:
	var out: Array = []
	for cid in RouteDB.mandatory(repo) + RouteDB.from_birth(repo):
		if sim.st.ded.dossier.inked.has(String(cid)):
			out.append(String(cid))
	return out

static func _var_ids(en: Dictionary) -> Array:
	return (en.get("variants", []) as Array).map(func(v): return String(v.get("id", "")))

func test_f1_best_ending() -> void:
	if _stale():
		return
	var en := _check_common("f1")
	if en.is_empty():
		return
	var sim = _run("f1").sim
	var sealed: Array = _mandatory_sealed(sim, repo())
	for cid in ["Q3", "Q6", "Q9"]:
		ok(sealed.has(cid), "F1 exige %s en tinta: %s" % [cid, str(sealed)])
	ok(sealed.size() >= 7, "F1 exige ≥7 preguntas en tinta: %d" % sealed.size())
	var fl: Dictionary = sim.st.flags
	eq(String(fl.get("informe_final", "")), "errata", "informe final = errata a medida")
	eq(String(fl.get("errata_ofrecida", "")), "librero", "la ofreció el librero al completar la confrontación")
	eq(String(fl.get("confront_estado", "")), "completa", "confrontación completa (cuatro de cuatro)")
	ok(bool(fl.get("moran_credito", false)) and not bool(fl.get("moran_credito_perdido", false)), "crédito ante Moran")
	no(bool(fl.get("holmes_entregado", false)), "nunca entregó a Holmes")
	no(bool(fl.get("watson_expuesto", false)), "Watson no quedó expuesto")
	eq(String(fl.get("noche_final", "")), "baker_street", "la noche final en Baker Street")
	var vids := _var_ids(en)
	for v in ["V.F1", "V.confront_completa", "V.noche_baker_street"]:
		has(vids, v, "variante del epílogo")
	eq(int(en.get("rank", 0)), 1, "rank del mejor final")
	var ep: Dictionary = sim.q_epilogue()
	ok(not ep.is_empty() and String(ep.get("ending", {}).get("ending", "")) == "F1", "q_epilogue con el final")
	var bp: Array = sim.q_blue_pencil()
	ok(typeof(bp) == TYPE_ARRAY, "lápiz azul disponible tras el informe final")
	# escenas de la partida completa: M6, M7, HC05–HC09 y el epílogo
	var fired: Array = (sim.st.react.delivered as Array).map(func(i): return String(i.rid))
	for rid in ["HC01", "HA1", "HB1", "HC02", "HC10", "M1", "HB10", "M6", "M7", "HC04", "HC05", "HC06", "HC07", "HC08", "HC09", "D27", "D28", "L6copia"]:
		has(fired, rid, "reacción/escena de la partida")
	# cada día jugable deja rastro (salida, bandeja o escena) y las fases van en orden
	var days: Dictionary = _run("f1").days
	for d in range(1, 10):
		var k := str(d)
		var info: Dictionary = days.get(k, {})
		ok(int(info.get("go", 0)) >= 1 or bool(info.get("scene", false)) or not sim.q_tray(d).is_empty(), "día %d sin nada que ver: %s" % [d, str(info)])
	var ph: Array = _run("f1").phases
	for want in ["prologue", "desk", "visit", "night", "scene", "confront", "final_report", "parklane", "night_choice", "epilogue", "done"]:
		has(ph, want, "fase recorrida")
	ok(ph.find("confront") < ph.find("final_report") and ph.find("final_report") < ph.find("parklane") and ph.find("parklane") < ph.find("night_choice") and ph.find("night_choice") < ph.find("epilogue"), "día 10 en orden: %s" % str(ph.slice(ph.find("confront"))))

func test_f2_faithful_report() -> void:
	if _stale():
		return
	var en := _check_common("f2")
	if en.is_empty():
		return
	var sim = _run("f2").sim
	var rep: Array = (sim.st.events as Array).filter(func(e): return String(e.type) == "report" and int(e.get("n", 0)) == 4)
	ok(rep.size() == 1, "informe final entregado")
	if rep.size() == 1:
		var cats: Array = []
		for it in rep[0].get("items", []):
			cats.append_array(it.get("cats", []))
		ok(cats.has("holmes_vive"), "el informe final dice que Holmes vive: %s" % str(cats))
	ok(bool(sim.st.flags.get("publica_errata", false)), "en 1903 publica la fe de erratas")
	has(_var_ids(en), "V.publica", "variante: «un romance muy entretenido»")

func test_f3a_burnt_report() -> void:
	if _stale():
		return
	var en := _check_common("f3a")
	if en.is_empty():
		return
	var sim = _run("f3a").sim
	eq(String(sim.st.flags.get("informe_final", "")), "quemar", "el informe final se quema")
	no(bool(sim.st.flags.get("publica_errata", false)), "no publica")

func test_f4_distracted_reader() -> void:
	if _stale():
		return
	var en := _check_common("f4")
	if en.is_empty():
		return
	var sim = _run("f4").sim
	ok(_mandatory_sealed(sim, repo()).size() < 6, "menos de seis obligatorias: %s" % str(_mandatory_sealed(sim, repo())))
	eq(int(en.get("rank", 0)), 5, "rank de F4")

# f2 y f3a son f1 hasta el informe final: sólo cambia la decisión (y, después, la noche y la errata de 1903).
func test_branches_share_the_investigation() -> void:
	if _stale():
		return
	var f1: Dictionary = _run("f1").sc
	if not bool(f1.get("ok", false)):
		fail("f1 ilegible")
		return
	var cut := -1
	for i in (f1.actions as Array).size():
		var a: Dictionary = f1.actions[i]
		if String(a.t) == "report_submit" and String(a.get("mode", "")) == "errata":
			cut = i
	ok(cut > 100, "f1 tiene el informe final (errata) en %d" % cut)
	for k in ["f2", "f3a"]:
		var o: Dictionary = _run(k).sc
		if not bool(o.get("ok", false)):
			fail(k + " ilegible")
			continue
		var same := true
		for i in cut:
			if i >= (o.actions as Array).size() or J.stringify_canon(o.actions[i]) != J.stringify_canon(f1.actions[i]):
				same = false
				fail("%s se aparta de f1 antes del informe final, en la acción %d" % [k, i])
				break
		ok(same and J.stringify_canon(o.actions[cut]) != J.stringify_canon(f1.actions[cut]), "%s decide distinto en el informe final" % k)

func test_replay_is_deterministic() -> void:
	if _stale():
		return
	var r := _run("f1")
	if not bool(r.ok):
		fail(String(r.err))
		return
	var again = GameSim.replay(repo(), int(r.sc.seed), r.sc.actions)
	eq(int(again.replay_errors), 0, "replay sin rechazos")
	eq(again.state_hash(), r.sim.state_hash(), "dos reproducciones = mismo estado")
