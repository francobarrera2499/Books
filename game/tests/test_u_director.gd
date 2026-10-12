# Unit: core/react/director.gd + reaction_db.gd (W2-REACT). Cola, prioridades, D1/D2/D3, columna, encadenado,
# reacciones en escena (immediate), desborde tras el día 10, determinismo.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Director = preload("res://core/react/director.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const GameState = preload("res://core/sim/game_state.gd")
const EFFECTS_PATH := "res://core/react/effects.gd"

func after_each() -> void:
	H.cleanup()

func R():
	return fixture_repo("react/data")

func _find(h, iid: String) -> Dictionary:
	return load(EFFECTS_PATH).find(h.st, iid)

func _day(h, inst: Dictionary) -> int:
	return TimeKey.day_of(int(_find(h, String(inst.iid)).get("delivered_tk", -10)))

# Instancia sintética en la cola (para D2/D3 sin depender de disparadores).
func _q(h, rid: String, due: String, extra := {}) -> Dictionary:
	var rule: Dictionary = h.repo.reaction(rid)
	var due_tk := TimeKey.parse(due)
	var canal := String(rule.get("canal", ""))
	var c := {"rid": rid, "channel": String(extra.get("channel", canal if RDB.CHANNELS.has(canal) else "")),
		"anchor": extra.get("anchor", {"tk": due_tk - 10, "day": TimeKey.day_of(due_tk) - 1, "copies": extra.get("copies", [])}),
		"n": int(extra.get("n", 1)), "guaranteed": false, "once": "", "src_ev": 0, "act_tk": due_tk - 10, "fixed_due": due_tk}
	var inst: Dictionary = Director._make_inst(h.st, h.repo, rule, c, due_tk - 10)
	inst.mode = ""
	h.st.react.queue.append(inst)
	return inst

func test_fixture_repo_valid():
	var r = R()
	for e in r.errors():
		fail("fixture: " + e)
	eq(RDB.lint(r), [], "gramática del fixture")
	ok(r.reactions().size() >= 40, "fixture con la tabla completa (%d)" % r.reactions().size())

func test_real_data_grammar():
	var r = repo()
	if r.reactions().is_empty():
		pending_content("data/reactions/*.json (W2-STRUCT)")
		return
	for e in RDB.lint(r):
		fail("data/reactions: " + e)

func test_passive_timeline():
	var h = H.new(R())
	h.advance_to("10.night")
	eq(h.day_of_delivery("HC01"), 1)
	eq(h.day_of_delivery("HA0"), 2, "HA0 si no hubo HA1 el día 1")
	eq(h.day_of_delivery("HC02"), 3)
	eq(h.day_of_delivery("HC10"), 4)
	eq(h.day_of_delivery("M6"), 5)
	eq(h.day_of_delivery("HC03"), 6)
	eq(h.day_of_delivery("M7"), 7)
	eq(TimeKey.slot_of(int(h.first("M7").delivered_tk)), "night", "M7 a las 22 h")
	eq(h.day_of_delivery("HC04"), 8)
	eq(h.day_of_delivery("M8"), 9)
	eq(int(h.first("HC07").delivered_tk), TimeKey.parse("10.M"), "HC07 a las 9:30")
	eq(int(h.first("HC09").delivered_tk), TimeKey.parse("10.N"))
	ok(h.find("HB13").size() >= 5, "el pasivo recibe empujones (HB13)")
	for i in h.delivered():
		ne(String(i.rid), "HB1", "nadie contesta lo que no se hizo")

func test_iid_and_prio_order():
	var h = H.new(R())
	var a := _q(h, "HB13", "5.dawn")
	var b := _q(h, "HB7", "5.dawn", {"channel": "K-T"})
	var c := _q(h, "D27", "5.dawn")
	ok(String(a.iid).begins_with("R.HB13."), a.iid)
	eq(int(a.prio), 2)
	eq(int(b.prio), 1)
	eq(int(c.prio), 4)
	h.advance_to("5.dawn")
	var mine := [String(a.iid), String(b.iid), String(c.iid)]
	var order: Array = []
	for i in h.delivered():
		if mine.has(String(i.iid)) or (String(i.rid) == "M6"):
			order.append(String(i.rid))
	eq(order, ["M6", "HB7", "HB13", "D27"], "columna → voz B → voz A → respuestas")
	eq(Director.debug_queue(h.st), [])

# ---------------- D3: canales de a uno ----------------
func test_d3_voice_a_merged_not_deferred():
	var h = H.new(R())
	h.ev("slip", {"seat": 214, "doc": "D05", "title": "t", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "cn.chelsea", "topic": "lisle_mudanza", "canary": "lisle_mudanza", "phrase": "x"}, "1.T")
	h.advance_to("2.dawn")
	eq(h.day_of_delivery("HA1"), 2)
	eq(h.day_of_delivery("HA4"), 2, "voz A: nunca se difiere, se fusiona")
	eq(String(h.first("HA4").merged_into), String(h.first("HA1").iid))

func test_d3_voice_b_deferred_against_voice_a_first():
	var h = H.new(R())
	h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, "1.T")
	h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "cn.chelsea", "topic": "lisle_mudanza", "canary": "lisle_mudanza", "phrase": "x"}, "3.T")
	h.advance_to("6.night")
	eq(h.day_of_delivery("HA4"), 4)
	eq(h.day_of_delivery("HB1"), 5, "la primera de K-W espera un día (D3)")
	eq(int(h.first("HB1").deferred), 1)
	eq(int(h.st.react.channels_seen["K-H"]), 4)
	eq(int(h.st.react.channels_seen["K-W"]), 5)

func test_d3_never_pushes_voice_b_to_mute_day():
	# GDD§9.3/HC03: la voz B no contesta el domingo (6) ni el miércoles (9). Si D3 la difiriera a esos días, se queda.
	for c in [{"bait": "4.M", "canary": "7.M", "want": 8}, {"bait": "2.M", "canary": "4.M", "want": 5}]:
		var h = H.new(R())
		h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, c.bait)
		h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "cn.chelsea", "topic": "lisle_mudanza", "canary": "lisle_mudanza", "phrase": "x"}, c.canary)
		h.advance_to("10.night")
		eq(h.day_of_delivery("HA4"), int(c.want), "HA4 (voz A, K-H) " + str(c))
		eq(h.day_of_delivery("HB1"), int(c.want), "HB1 (voz B, K-W) no pasa a un día mudo " + str(c))
		eq(int(h.first("HB1").get("deferred", -1)), 0)

func test_d3_two_non_a_keep_lowest():
	var h = H.new(R())
	h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, "1.M")
	h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "as.cayeron", "topic": "cayeron", "bait_topic": "cayeron", "phrase": "x"}, "1.T")
	h.advance_to("6.night")
	var w := {}
	for i in h.find("HB1"):
		w[String(i.channel)] = TimeKey.day_of(int(i.delivered_tk))
	eq(w, {"K-W": 4, "K-H": 5}, "se queda la de menor iid; la otra, al día siguiente")

func test_d3_seen_channels_free():
	var h = H.new(R())
	h.ev("ad", {"ad": "AD.1", "form": "testigo", "text": "Se busca testigo", "pub_day": 1, "prologue": true}, "1.dawn")
	h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, "1.T")
	h.advance_to("4.night")
	eq(h.day_of_delivery("HC10"), 4)
	eq(h.day_of_delivery("HB1"), 4, "K-T ya visto (HC01): sólo K-W es nuevo")

# ---------------- D2: ritmo ----------------
func test_d2_one_strong_then_calm():
	var h = H.new(R())
	var a := _q(h, "HB9", "5.dawn", {"channel": "K-S", "n": 1})
	var b := _q(h, "HB3", "5.dawn", {"channel": "K-BM"})
	h.advance_to("10.night")
	# orden fijo prio → iid: R.HB3.* < R.HB9.*; la otra espera: el 6 es calma, sale el 7
	eq([_day(h, b), _day(h, a)], [5, 7], "una fuerte por mañana y calma después")
	ok(h.st.react.strong_days.has("5") and h.st.react.strong_days.has("7"))
	no(h.st.react.strong_days.has("6"))

func test_d2_moran_deferred_first():
	var h = H.new(R())
	var m := _q(h, "M2", "5.dawn")
	var a := _q(h, "HB9", "5.dawn", {"channel": "K-S", "n": 1})
	h.advance_to("10.night")
	eq(_day(h, a), 5, "la de voz A se queda")
	eq(_day(h, m), 7, "Moran se difiere primero (y respeta la calma)")

func test_d2_voice_a_cut_deferred_before_letter():
	var h = H.new(R())
	var cut := _q(h, "HB4", "5.dawn", {"channel": "K-W", "n": 2, "anchor": {"tk": 41, "day": 4}})   # HB4 2.ª: cierra la consulta
	var letter := _q(h, "HB9", "5.dawn", {"channel": "K-S", "n": 1})                                  # carta sin corte
	ok(RDB.is_strong(h.repo.reaction("HB4"), 5), "HB4 es fuerte (nivel 3)")
	h.advance_to("10.night")
	eq(_day(h, letter), 5, "la carta sin corte conserva su noche")
	eq(_day(h, cut), 7, "el corte de voz A se difiere")

func test_d2_exemptions():
	var h = H.new(R())
	var a := _q(h, "HB9", "5.dawn", {"channel": "K-S", "n": 1})
	var b := _q(h, "HB2", "5.dawn", {"channel": "K-T", "anchor": {"tk": 41, "day": 4, "bait_topic": "pared"}})
	var c := _q(h, "HB10", "5.dawn", {"channel": "K-S"})
	var d := _q(h, "M1", "9.dawn", {"copies": ["D02@L1"]})
	var e := _q(h, "HB3", "9.dawn", {"channel": "K-BM"})
	h.advance_to("10.night")
	for x in [a, b, c]:
		eq(_day(h, x), 5, String(x.rid) + " no se difiere (voz B y HB10 exentas)")
	eq(_day(h, d), 9, "M1 desde el día 8 no cuenta")
	eq(_day(h, e), 9)
	no(bool(_find(h, b.iid).strong))

func test_d2_day10_merges():
	var h = H.new(R())
	var a := _q(h, "HB9", "10.dawn", {"channel": "K-S", "n": 1})
	var b := _q(h, "HB3", "10.dawn", {"channel": "K-BM"})
	h.advance_to("10.night")
	eq(_day(h, a), 10)
	eq(_day(h, b), 10, "más allá del 10 se fusiona con el 10")

# ---------------- D1: guardia de rutas ----------------
func test_d1_soft_variant():
	var calls: Array = []
	var hook := func(_st, _repo, rid, cuts):
		calls.append([rid, cuts])
		return {"ok": false, "violated": ["C2"]}
	# HB4: la segunda vez cortaría la consulta (C2.R4…): variante blanda
	var h = H.new(R())
	Director.guard_hook = hook
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "x", "ents": ["mary_watson"]}, "1.M")
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "duelo", "phrase": "x", "ents": ["duelo"]}, "2.M")
	h.advance_to("6.night")
	var hb4: Array = h.find("HB4")
	eq(hb4.size(), 2)
	if hb4.size() == 2:
		no(bool(hb4[0].soft), "la primera no corta: no consulta la guardia")
		ok(bool(hb4[1].soft), "la segunda cortaría la consulta: blanda")
	no(h.st.flags.has("consulta_cerrada_hasta"), "no cierra la consulta")
	has(load(EFFECTS_PATH).lines(h.st, "watson"), "vuelva_usted")
	# M1: registran sin llevarse originales
	var h2 = H.new(R())
	Director.guard_hook = hook
	h2.ev("report", {"n": 1, "mode": "items", "items": [{"kind": "clip", "id": "RC1", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]}]}, "2.night")
	h2.advance_to("3.night")
	var m1: Dictionary = h2.first("M1")
	ok(bool(m1.get("soft", false)))
	eq(load(EFFECTS_PATH).withdrawn(h2.st, TimeKey.parse("3.N")), [], "no se lleva originales")
	eq(load(EFFECTS_PATH).place_variant(h2.st, "L1"), "registrada", "pero registran la buhardilla")
	eq(load(EFFECTS_PATH).extra_nodes(h2.st, "L1", TimeKey.parse("3.N")).size(), 1, "y dejan la ceniza (§12.1.3)")
	h2.advance_to("5.night")
	eq(h2.find("HB10").size() + h2.queued("HB10").size(), 0, "sin robo no hay devolución")
	var rids: Array = []
	var m1cuts: Array = []
	for c in calls:
		rids.append(c[0])
		if c[0] == "M1":
			m1cuts = c[1]
	ok(rids.has("HB4") and rids.has("M1"), str(rids))
	eq(m1cuts.size(), 1)
	if m1cuts.size() == 1:
		eq(m1cuts[0].target, {"copy": "D02@L1"}, "corte de runtime sobre el original informado")

func test_runtime_cuts_filters_and_record():
	var h = H.new(R())
	var rule := {"id": "X", "corta": [{"acceso": "L4.consulta", "ventana": {"dias": 2}, "si_n": [2]}, {"acceso": "canal:*", "ventana": {"permanente": true}}]}
	var i1 := {"iid": "R.X.1", "rid": "X", "n": 1, "channel": "K-W", "due_tk": TimeKey.parse("4.dawn"), "anchor": {}}
	var c1: Array = Director._runtime_cuts(h.st, h.repo, rule, i1)
	eq(c1.size(), 1, "si_n [2]: la 1.ª no cierra la consulta")
	eq(c1[0].target, {"access": "canal:K-W"})
	i1.n = 2
	var c2: Array = Director._runtime_cuts(h.st, h.repo, rule, i1)
	eq(c2.size(), 2)
	eq(c2[0].target, {"access": "L4.consulta"})
	eq(int(c2[0].to_idx), TimeKey.idx(5, "N"), "dos días: hasta el 5 inclusive")
	# la entrega deja constancia de los cortes que aplicó (para Invariant.active_cuts)
	var h2 = H.new(R())
	h2.ev("report", {"n": 1, "mode": "items", "items": [{"kind": "clip", "id": "RC1", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]}]}, "2.night")
	h2.advance_to("3.night")
	var m1: Dictionary = h2.first("M1")
	eq(m1.get("cuts", []).size(), 1)
	eq(m1.cuts[0].target, {"copy": "D02@L1"})
	eq(h2.first("HC01").get("cuts", null), [], "sin corta: []")

func test_d1_real_graph_guard_runs():
	# Integración con W2-GRAPH (CutModel.cuts_for + Invariant.runtime_guard) sin hook.
	var h = H.new(R())
	Director.guard_hook = null
	h.ev("report", {"n": 1, "mode": "items", "items": [{"kind": "clip", "id": "RC1", "cats": ["original_p"], "copies": ["D02@L1"], "cls": ["P"]}]}, "2.night")
	h.advance_to("3.night")
	eq(h.find("M1").size(), 1)

# ---------------- reacciones en escena ----------------
func test_immediate_then_public_event():
	var h = H.new(R())
	h.advance_to("3.M")
	var out: Array = Director.immediate(h.st, h.repo, {"type": "pay", "char": "wiggins", "amount_d": 12})
	eq(out.size(), 1, str(out))
	if out.size() == 1:
		eq(String(out[0].rid), "HB8")
		has(out[0].effects, "flag")
	ok(bool(h.st.flags.get("wiggins_aliado", false)))
	h.ev("pay", {"char": "wiggins", "amount_d": 12}, "3.M")
	eq(int(h.st.react.counters["fired.HB8"]), 1, "no se aplica dos veces")
	var h2 = H.new(R())
	h2.ev("pay", {"char": "wiggins", "amount_d": 12}, "3.T")
	ok(bool(h2.st.flags.get("wiggins_aliado", false)), "sin immediate() previo, el Director la aplica igual")

func test_forced_reaction_from_dialogue():
	# Dialogue decide el resultado especial (M4: presentar a Pell algo que nombra a Moran) y lo pasa en ev.reaction.
	var h = H.new(R())
	h.advance_to("4.M")
	var ev := {"type": "show", "char": "pell", "item": {"kind": "entry", "id": "AS003", "ents": ["moran"]}, "_reaction": "M4", "_visit": "S.L1.4.M"}
	eq(Director.immediate(h.st, h.repo, ev), [], "M4 no es inmediata: se encola al recibir el evento")
	h.ev("show", {"char": "pell", "item": {"kind": "entry", "id": "AS003", "ents": ["moran"]}}, "4.M")
	eq(h.queued("M4").size(), 1, "el evento público (sin reaction) hereda el resultado decidido por Dialogue")
	h.advance_to("5.dawn")
	ok(bool(h.st.flags.get("pell_despedido", false)))
	var h2 = H.new(R())
	h2.ev("show", {"char": "pell", "item": {"kind": "entry", "id": "AS003", "ents": ["moran"]}}, "4.M")
	eq(h2.queued("M4").size(), 0, "sin el resultado de Dialogue (ni cats), Pell no reacciona")

func test_immediate_shares_counters():
	var h = H.new(R())
	h.advance_to("1.M")
	Director.immediate(h.st, h.repo, {"type": "say", "char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "x", "ents": ["mary_watson"]})
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "x", "ents": ["mary_watson"]}, "1.M")
	eq(int(h.st.react.counters.get("hb4=watson", 0)), 1, "el contador sube una vez por evento")

# ---------------- desborde, encadenado, determinismo ----------------
func test_overflow_after_day10_sets_flags():
	var h = H.new(R())
	h.ev("report", {"n": 1, "mode": "items", "items": [{"kind": "clip", "id": "RC1", "cats": ["watson_privado"], "copies": [], "cls": []}]}, "2.night")
	h.advance_to("10.M")
	ok(bool(h.st.flags.get("watson_avisado", false)))
	no(bool(h.st.flags.get("watson_expuesto", false)))
	h.ev("report", {"n": 4, "mode": "items", "items": [{"kind": "clip", "id": "RC2", "cats": ["watson_privado"], "copies": [], "cls": []}]}, "10.M")
	ok(bool(h.st.flags.get("watson_expuesto", false)), "el informe final también expone a Watson, aunque el efecto caiga el 11")
	var m3: Array = h.find("M3")
	ok(bool(m3[m3.size() - 1].get("overflow", false)))

func test_determinism():
	var lines: Array = H.load_jsonl("res://tests/fixtures/react/t11_activo.jsonl")
	ok(lines.size() > 10)
	var a = H.new(R(), 11)
	a.play(lines)
	var b = H.new(R(), 11)
	b.play(lines)
	eq(a.signature(), b.signature(), "D7: misma semilla y actos → mismas entregas")
	ok(a.delivered().size() > 25, "el guion activo produce muchas entregas (%d)" % a.delivered().size())

func test_sig_ignores_numbering():
	var e1 := {"type": "say", "char": "watson", "topic": "pared"}
	var e2 := {"type": "say", "char": "watson", "topic": "pared", "seq": 7, "act": "act.7", "tk": 12, "day": 1, "slot": "T"}
	eq(Director.sig(e1), Director.sig(e2))
	ne(Director.sig(e1), Director.sig({"type": "say", "char": "watson", "topic": "roca"}))

func test_data_min_compatible():
	var h = H.new(fixture_repo("data_min"))
	h.ev("slip", {"seat": 3, "doc": "D05", "title": "t", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	h.ev("ad", {"ad": "AD.1", "form": "a_proposito", "text": "x", "assertion": "as.pared", "bait_topic": "pared", "pub_day": 2}, "2.dawn")
	h.advance_to("10.night")
	eq(h.find("HC10").size(), 1)
	eq(h.find("HA1").size(), 1)
	eq(h.find("HB1").size(), 1)

func test_init_state_shape():
	var st = GameState.new()
	Director.init_state(st, R())
	for k in ["queue", "delivered", "strong_days", "channels_seen", "inactivity", "holmes", "moran", "counters", "once", "world"]:
		ok(st.react.has(k), "st.react." + k)
	var before: Dictionary = st.react.duplicate(true)
	Director.init_state(st, R())
	eq(st.react, before, "idempotente")
