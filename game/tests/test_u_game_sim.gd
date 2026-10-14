# CORE-EXPEDIENTE (antes W2-SIM): GameSim (§3.4, §3.7; GDD_v3 §1.7): tubería de apply, sin mutación ante error, numeración de eventos, eventos diferidos,
# señales changed, can() en seco, replay, consultas y el recorrido prólogo -> día 3 por JSONL sobre fixtures.
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Fakes = preload("res://tests/fixtures/sim/fakes.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func test_fixture_repo_is_valid():
	var r = Kit.repo()
	eq(r.errors(), [], "errores del fixture")

func test_initial_state():
	var s = Kit.new_sim()
	var c: Dictionary = s.q_clock()
	eq(c.day, 0)
	eq(c.phase, "prologue")
	eq(c.slot, "N")
	no(c.has("passes_left"), "v3: sin pasadas por franja")
	eq(c.date_label, "Lunes de Pascua")
	var open: Array = s.q_dossier().open
	eq(open.size(), 1, "una sola pregunta al empezar")
	eq(String(open[0].id), "Q1")
	ok(s.st.world.plates.has("PL.prologo"), "lámina del prólogo archivada")
	# líneas del prólogo (no las t_*) + la del primer paso del tutorial
	var ids: Array = []
	for l in s.q_scene().lines:
		ids.append(l.id)
	ok(ids.has("encargo") and ids.has("cace_india"), str(ids))
	ok(ids.has("t_read"), "línea del primer paso (GDD_v2 §B.7: abrir el encargo)")
	no(ids.has("t_clip"), "línea de un paso futuro")
	no(ids.has("t_link"), "línea que ya no existe en el prólogo")
	eq(s.q_tutorial().step.id, "read")
	eq(s.actions_log(), [])
	eq(s.st.events, [])

func test_walk_prologue_to_day3_jsonl():
	var s = Kit.new_sim()
	var acts := Kit.load_jsonl(Kit.WALK)
	ok(acts.size() > 20, "guion cargado")
	var res := Kit.run(s, acts)
	eq(Kit.first_fail(res), "", "todas las acciones del guion se aceptan")
	var c: Dictionary = s.q_clock()
	eq(c.day, 3)
	eq(c.phase, "desk")
	eq(c.slot, "M")
	ok(c.outing_done, "salió en 3.M")
	eq(s.actions_log().size(), acts.size())
	var types: Array = []
	for ev in s.st.events:
		types.append(ev.type)
	# go L2, slip, go L3 (la tienda no emite), say, ad (prólogo, al amanecer del 1), telegram, go L4, say, report, ad (día 3), go
	eq(types.count("go"), 4, str(types))
	eq(types.count("slip"), 1)
	eq(types.count("say"), 2)
	eq(types.count("telegram"), 1)
	eq(types.count("report"), 1)
	eq(types.count("ad"), 2, str(types))
	# numeración y acto
	for i in s.st.events.size():
		var ev: Dictionary = s.st.events[i]
		eq(ev.seq, i + 1)
		eq(ev.act, "act.%d" % (i + 1))
		eq(ev.day, TimeKey.day_of(ev.tk))
	# el aviso del prólogo se emite al amanecer del día 1; el del día 2, al amanecer del 3 (siguiente con Times)
	var ads: Array = []
	for ev in s.st.events:
		if ev.type == "ad":
			ads.append(ev)
	eq(ads[0].tk, TimeKey.parse("1.dawn"))
	eq(ads[0].pub_day, 1)
	eq(ads[1].tk, TimeKey.parse("3.dawn"))
	eq(ads[1].assertion, "as.pared")
	eq(ads[1].bait_topic, "pared")
	# telegrama: sale al cerrar la franja N del día 1
	for ev in s.st.events:
		if ev.type == "telegram":
			eq(ev.tk, TimeKey.parse("1.N"))
			eq(ev.to, "reichenbach")
	# tutorial completo y verbos en contexto
	var taught: Array = s.q_tutorial().taught
	for v in ["read", "clip_text", "compose_ad", "sleep", "go", "slip", "ask", "report_submit"]:
		has(taught, v, "verbo enseñado")
	for v in ["link", "folio_open", "entry_set", "practice", "pass_clean"]:
		no(taught.has(v), "verbo retirado: " + v)
	# diario: actos, llegadas (el Times del 27) y líneas dichas
	var kinds := {}
	for d in s.q_diary():
		kinds[d.kind] = int(kinds.get(d.kind, 0)) + 1
	ok(int(kinds.get("act", 0)) >= 8, str(kinds))
	ok(int(kinds.get("arrival", 0)) >= 1, str(kinds))
	ok(int(kinds.get("line", 0)) >= 3, str(kinds))
	# visitas archivadas como láminas
	ok(s.st.world.plates.has("PL.L2.1.M"), str(s.st.world.plates.keys()))
	ok(s.st.world.plates.has("PL.L1.1.T"), "tienda archivada")
	ok(s.st.world.plates.has("PL.L3.1.T"))

func test_failed_action_does_not_mutate():
	var s = Kit.new_sim()
	var h0: String = s.state_hash()
	for a in [{"t": "sleep"}, {"t": "go", "place": "L2", "seat": 1}, {"t": "nope"}, {"t": "link", "a": "X", "b": "Y"},
			{"t": "clip_text", "src": {"kind": "doc", "ref": "D05@BM", "part": 0, "block": 0}, "from": 0, "len": 5},
			{"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": 0, "block": 0}, "from": 0, "len": 0}]:
		var r: Dictionary = s.apply(a)
		no(r.ok, str(a))
		ok(String(r.get("err", "")) != "", "código de error")
		eq(s.state_hash(), h0, "sin mutación: " + str(a))
	eq(s.actions_log().size(), 0)
	var r2: Dictionary = s.apply({"t": "sleep"})
	eq(r2.err, "tutorial")

func test_errors_codes():
	var s = Kit.new_sim()
	eq(s.apply({"t": "x"}).err, "accion_desconocida")
	eq(s.apply({"t": "slip"}).err, "falta:doc")
	eq(s.apply({"t": "slip", "doc": 3}).err, "tipo:doc")
	eq(s.apply({"t": "end_slot"}).err, "fase", "end_slot no existe en el prólogo")
	eq(s.apply({"t": "compose_ad", "form": "testigo", "fields": {}}).err, "tutorial", "un verbo por paso")
	for t in ["link", "unlink", "folio_open", "entry_new", "entry_set", "practice", "pass_clean", "clip_measure"]:
		eq(s.apply({"t": t}).err, "accion_desconocida", "v3 retira " + t)

func test_changed_signal_and_no_reaction_kind():
	var s = Kit.new_sim()
	var got: Array = []
	s.changed.connect(func(k, p): got.append(k))
	for a in Kit.prologue():
		ok(s.apply(a).ok, str(a))
	ok(got.has("clock"), str(got))
	ok(got.has("diary"), str(got))
	ok(got.has("tray"), "llegó el Times al amanecer")
	no(got.has("reaction"), "nunca 'reaction'")

func test_can_is_dry():
	var s = Kit.new_sim()
	var h0: String = s.state_hash()
	var got: Array = []
	s.changed.connect(func(k, p): got.append(k))
	eq(s.can(Kit.prologue()[0]), {"ok": true, "err": ""})
	eq(s.can({"t": "sleep"}), {"ok": false, "err": "tutorial"})
	eq(s.state_hash(), h0)
	eq(got, [], "can no emite señales")
	eq(s.actions_log(), [])

func test_replay_same_hash():
	var s = Kit.new_sim(11)
	Kit.run(s, Kit.load_jsonl(Kit.WALK))
	var f := Fakes.new()
	var r = GameSim.replay(Kit.repo(), 11, s.actions_log(), f.handlers())
	eq(r.replay_errors, 0)
	eq(r.state_hash(), s.state_hash())
	eq(r.actions_log(), s.actions_log())

func test_queries_shapes():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	var c: Dictionary = s.q_clock()
	for k in ["day", "slot", "phase", "date_label", "weekday", "outing_done", "report_due"]:
		ok(c.has(k), "q_clock." + k)
	eq(c.date_label, "martes 27 de marzo")
	eq(c.weekday, "mar")
	var tray: Array = s.q_tray()
	eq(tray.size(), 1, str(tray))
	eq(tray[0].view, "D15.0327@L1")
	eq(tray[0].stamp, "Recibido: 27-mar, amanecer")
	var acc: Array = []
	for v in s.q_accessible():
		acc.append(v.view)
	ok(acc.has("D23@L1") and acc.has("D02@L1") and acc.has("D03@tomo") and acc.has("D15.0327@L1"), str(acc))
	no(acc.has("D03@Crane"), "la tienda no está a la vista desde la buhardilla")
	var v: Dictionary = s.q_view("D15.0327@L1")
	eq(v.pages.size(), 2)
	eq(s.q_view("D05@BM"), {}, "BM sin papeleta: inaccesible")
	var cat: Array = s.q_catalog("reichenbach")
	ok(cat.size() >= 2 and cat.size() <= 5, str(cat))
	eq(s.q_catalog("reichenbach"), cat, "determinista")
	ok(s.q_lists().has("medios"))
	var dv: Dictionary = s.q_dossier()
	ok(dv.has("open") and dv.has("inked"), str(dv.keys()))
	for k in ["id", "text", "origin", "doubts", "state", "answer", "proofs", "formal", "ink_text", "variant"]:
		ok((dv.open[0] as Dictionary).has(k), "q_dossier H." + k)
	ok(typeof(s.q_answer_options("Q1")) == TYPE_ARRAY)
	eq(s.q_donde(), [], "Crane todavía no se presentó")
	eq(s.q_missing(), [])
	var p: Array = s.q_places()
	ok(p.size() > 5, str(p))
	for x in p:
		for k in ["id", "area", "name", "open", "reason", "streets"]:
			ok(x.has(k), "q_places." + k)
		ok(x.has("que_hay") and x.has("por_que"), "q_places v3")
	eq(s.q_ending(), {}, "sin informe final, sin final")
	eq(s.q_blue_pencil(), [])

# Escena fija abierta en el mismo tk en que el director resuelve su reacción (M7 a las 22 h, fixture reactions/moran.json):
# las líneas que el director le agrega después de abrirla (siguiente comunicación de Moran, M10–M12) se dicen en la
# escena, una sola vez, y quedan en el diario con el origen de la escena.
func test_fixed_scene_gets_lines_added_by_director():
	var s = Kit.new_sim()
	ok(not s.repo.reaction("M7").is_empty(), "fixture con M7")
	eq(Kit.advance_to(s, 7, "N"), "")
	var line := "Me dicen que fue usted a Baker Street, señor Lisle."
	s.st.react.moran.next_lines.append(line)
	ok(s.end_slot().ok)
	eq(s.q_clock().phase, "scene")
	eq(s.q_clock().scene, "M7")
	var texts: Array = []
	for l in s.q_scene().lines:
		texts.append(l.parsed.plain)
	eq(texts.count(line), 1, str(texts))
	eq(texts[-2], line, "antes de la despedida de la escena (hallazgo del lector: no como un recado olvidado)")
	var n := 0
	var dl: Array = []
	for d in s.q_diary():
		if d.kind == "line":
			dl.append(d.parsed.plain)
		if d.kind == "line" and d.parsed.plain == line:
			n += 1
			eq(d.origin, "S.M7")
	eq(n, 1)
	eq(dl.find(line), dl.find(texts[-1]) - 1, "también en el diario, antes de la despedida")
	ok(s.leave().ok)
	eq(s.q_clock().phase, "night")

# q_preview (§3.7): texto final del telegrama y del informe, igual al que produce la acción (módulos reales).
func test_preview_mail_and_report_real_modules():
	var s = GameSim.new(Kit.repo(), 7)
	var seen := {}
	for a in Kit.load_jsonl(Kit.WALK):
		var t := String(a.t)
		var pv := ""
		if t == "compose_telegram" or t == "report_submit":
			pv = s.q_preview(a)
		var r: Dictionary = s.apply(a)
		ok(r.ok, "%s -> %s" % [str(a), str(r)])
		if pv != "":
			eq(pv, String(r.get("text", "")), "vista previa = texto final de " + t)
			seen[t] = true
	ok(seen.has("compose_telegram") and seen.has("report_submit"), str(seen))

# GDD_v3 §1.7: clip_measure se retira del SPEC (la regla no existe); la línea física se recorta como cualquier texto.
func test_clip_measure_retired():
	var s = GameSim.new(repo(), 7)
	eq(s.apply({"t": "clip_measure", "src": {"kind": "doc", "ref": "D23@L1"}}).err, "accion_desconocida")
	var v: Dictionary = s.q_view("D23@L1")
	var first: Dictionary = v.pages[0][0].parsed.tramos[0]
	eq(String(first.id), "fisica", "la primera línea de todo documento es su descripción física")

# Expediente por la puerta de la simulación (fixture): el día 1 guiado hace nacer Q2 al leer FINA y registra el intento.
func test_day1_guide_through_apply():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	eq(s.q_clock().phase, "desk")
	var res := Kit.run(s, Kit.day1_guide())
	eq(Kit.first_fail(res), "", "el día 1 guiado se acepta")
	var ids: Array = []
	for h in s.q_dossier().open + s.q_dossier().inked:
		ids.append(String(h.id))
	ok(ids.has("Q2"), "leer FINA hace nacer Q2: " + str(ids))
	eq(int(s.st.ded.dossier.attempts.get("Q1", 0)), 1)
	eq(s.q_tutorial().day1, {}, "día 1 guiado completo")
