# Unit: core/scenes/dialogue.gd (W2-SCENES). Capas de respaldo (§4.12), preguntar/afirmar/presentar/pagar/encargar
# (§5.7, GDD §8.7), resultados especiales HB4/HB6/M4/HB8/HB12, líneas dichas y escenas (§4.13).
# Dependencias de W2-DED/W2-REACT reemplazadas por dobles (tests/fixtures/scenes/fakes.gd); datos: fixtures/scenes/data.
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Deps = preload("res://core/scenes/deps.gd")
const J = preload("res://core/util/j.gd")

var rp

func before_each() -> void:
	Fakes.install()
	rp = Fakes.repo()

func after_each() -> void:
	Fakes.uninstall()

func _st(opts := {}):
	return Fakes.state(rp, opts)

func _ids(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		out.append(String(l.get("id", "")))
	return out

func _canon(st) -> String:
	return J.stringify_canon({"s": st.scenes, "f": st.flags, "d": st.ded, "p": st.pending_events, "q": st.seq})

# ---------------- datos ----------------
func test_fixture_valid():
	eq(rp.errors(), [], "fixture de W2-SCENES válido")
	eq(Deps.Index, Fakes.FIndex, "dobles instalados")
	var real: Dictionary = J.parse_file("res://data/ui_text/scenes.json")
	var fix: Dictionary = J.parse_file("res://tests/fixtures/scenes/data/ui_text/scenes.json")
	eq(J.stringify_canon(fix.text), J.stringify_canon(real.text), "la copia del fixture de ui_text/scenes.json no se desvía de data/")

# ---------------- capas ----------------
func test_layers_in_order():
	var st = _st()
	eq(Dialogue.respond(st, rp, "watson", {"assertion": "as.pared", "topic": "pared", "ents": ["reichenbach", "pared"]}).id, "af.pared", "afirmacion")
	eq(Dialogue.respond(st, rp, "watson", {"topic": "pared", "ents": ["pared"], "kind": "concepto"}).id, "pared", "tema")
	eq(Dialogue.respond(st, rp, "watson", {"ents": [{"id": "journal_de_geneve", "label": "x"}], "docs": ["D05"]}).id, "doc.journal", "documento")
	eq(Dialogue.respond(st, rp, "watson", {"ents": ["cornisa", "perro"]}).id, "ent.cornisa", "entidad")
	eq(Dialogue.respond(st, rp, "watson", {"topic": "moran", "ents": ["moran"], "kind": "persona"}).id, "tipo.persona", "tipo persona")
	eq(Dialogue.respond(st, rp, "watson", {"topic": "meiringen", "ents": ["meiringen"], "kind": "lugar"}).id, "tipo.lugar", "tipo lugar")
	var g: Dictionary = Dialogue.respond(st, rp, "watson", {"topic": "perro", "ents": ["perro"], "kind": "objeto"})
	eq(g.layer, "generica")
	has(["gen.1", "gen.2", "gen.3"], g.id, "genérica")
	# hb4.1 (reaction sin match) nunca sale por capas; tampoco las líneas reservadas
	ne(Dialogue.respond(st, rp, "watson", {"topic": "duelo", "ents": ["duelo"], "kind": "concepto"}).id, "hb4.1")
	for i in 20:
		var r: Dictionary = Dialogue.respond(load("res://core/sim/game_state.gd").new(), rp, "wiggins", {"topic": "x%d" % i, "ents": []})
		ok(not ["pago", "tarea.seguir_parker", "hb8"].has(r.id), "reservadas fuera de la genérica: " + r.id)
	eq(Dialogue.respond(st, rp, "nadie", {"topic": "pared"}), {}, "sin datos -> {}")

func test_when_reads_world_state():
	var st = _st()
	var v := {"topic": "mycroft", "ents": ["mycroft"], "kind": "persona"}
	eq(Dialogue.respond(st, rp, "watson", v).id, "tipo.persona", "antes de hablarle de la roca")
	st.events.append({"type": "say", "char": "watson", "topic": "pared", "seq": 1})
	eq(Dialogue.respond(st, rp, "watson", v).id, "escribi_mycroft", "when event_count")

func test_generic_is_deterministic_and_varies_by_seed():
	var seen := {}
	for s in range(12):
		var st = _st({"seed": s})
		var v := {"topic": "perro", "ents": ["perro"], "kind": "objeto"}
		var a: Dictionary = Dialogue.respond(st, rp, "watson", v)
		eq(Dialogue.respond(st, rp, "watson", v), a, "misma semilla y mismo visible -> misma línea")
		seen[a.id] = true
	ok(seen.size() >= 2, "Det.pick reparte entre genéricas: " + str(seen.keys()))

# ---------------- preguntar ----------------
func test_ask_flow_budget_closing_and_event():
	var st = _st({"chars": ["watson"], "index": ["pared", "reichenbach", "perro", "cornisa"]})
	var r: Dictionary = Dialogue.act_ask(st, rp, {"char": "watson", "topic": "pared"})
	ok(r.ok, str(r))
	eq(r.line.id, "pared")
	eq(r.line.who, "watson")
	eq(r.lines[0].who, "lisle")
	eq(r.lines[0].text, "¿Qué sabe usted de la pared, doctor?")
	eq(r.phrase, "¿Qué sabe usted de la pared, doctor?")
	eq(r.lines[0].uid, "LN.0001")
	eq(r.line.uid, "LN.0002")
	eq(r.line.origin, "S.L4.3.M", "origen = la visita")
	eq(st.scenes.lines["LN.0002"].text, "Era un sendero de tres pies, señor Lisle; no tengo más que decir.")
	eq(st.pending_events.size(), 1)
	var ev: Dictionary = st.pending_events[0]
	eq(ev.type, "say")
	eq(ev.kind, "ask")
	eq(ev.char, "watson")
	eq(ev.topic, "pared")
	eq(ev.ents, ["pared"])
	eq(ev.phrase, r.phrase)
	eq(ev.bait, false)
	no(ev.has("tags"), "nada oculto en el evento")
	eq(st.react.imm_calls.size(), 1, "Director.immediate siempre")
	eq(st.react.imm_calls[0]._reaction, "")
	eq(int(st.react.imm_calls[0].tk), 31)
	# Director.sig ignora seq/act/tk/day/slot y claves «_»: lo que recibe immediate() debe ser el mismo evento que
	# después llega a on_public_event (si no, la observación se cuenta dos veces: Ley 2, HB12…)
	var imm: Dictionary = st.react.imm_calls[0].duplicate()
	for k in imm.keys():
		if ["tk", "day", "slot"].has(String(k)) or String(k).begins_with("_"):
			imm.erase(k)
	eq(J.stringify_canon(imm), J.stringify_canon(ev), "immediate y el evento público tienen la misma firma")
	has(st.react.get("added", []), "watson", "se presenta: Index.add_entities")
	eq(Dialogue.budget_left(st, rp, "watson"), 2)
	no(Dialogue.act_ask(st, rp, {"char": "watson", "topic": "perro"}).closing)
	var r3: Dictionary = Dialogue.act_ask(st, rp, {"char": "watson", "topic": "cornisa"})
	ok(r3.closing, "la 3.ª agota: cierre")
	eq(r3.lines[-1].kind, "cierre")
	eq(r3.lines[-1].text, "Tengo pacientes, señor Lisle.")
	var before := _canon(st)
	eq(Dialogue.act_ask(st, rp, {"char": "watson", "topic": "pared"}).err, "sin_preguntas")
	eq(_canon(st), before, "un error no muta")
	eq(Dialogue.topics(st, rp, "watson"), [], "sin preguntas no hay temas")
	st.world.visit["id"] = "S.L4.4.M"
	eq(Dialogue.budget_left(st, rp, "watson"), 3, "3 por visita")

func test_ask_errors():
	var st = _st({"chars": ["watson"], "index": ["pared"]})
	eq(Dialogue.act_ask(st, rp, {"char": "crane", "topic": "pared"}).err, "no_esta")
	eq(Dialogue.act_ask(st, rp, {"char": "watson", "topic": "cornisa"}).err, "no_indexado")
	st.ded.index["act.3"] = true
	eq(Dialogue.act_ask(st, rp, {"char": "watson", "topic": "act.3"}).err, "no_indexado", "un acto no es tema")
	eq(Dialogue.act_ask(st, rp, {"char": "", "topic": "pared"}).err, "no_esta")
	eq(st.pending_events, [])

func test_ask_phrase_contractions_and_overrides():
	var st = _st({"chars": ["watson", "crane"], "index": ["journal_de_geneve", "fina"]})
	eq(Dialogue.preview(st, rp, {"t": "ask", "char": "watson", "topic": "journal_de_geneve"}), "¿Qué sabe usted del Journal de Genève, doctor?")
	eq(Dialogue.preview(st, rp, {"t": "ask", "char": "crane", "topic": "fina"}), "¿Se vendió bien «El problema final», señor Crane?", "ask_phrase por tema")
	eq(Dialogue.preview(st, rp, {"t": "ask", "char": "crane", "topic": "journal_de_geneve"}), "¿Qué me dice del Journal de Genève, señor Crane?")
	eq(Dialogue.budget_left(st, rp, "crane"), 99, "Crane: sin límite práctico")

# ---------------- afirmar ----------------
func test_assert_bait_canary_and_says_alive():
	var st = _st({"chars": ["watson", "ujier"], "index": ["reichenbach", "pared", "holmes"]})
	var r: Dictionary = Dialogue.act_assert(st, rp, {"char": "watson", "assertion": "as.pared"})
	ok(r.ok, str(r))
	eq(r.line.id, "af.pared")
	eq(r.phrase, "La pared era a pique, ¿no, doctor?")
	var ev: Dictionary = st.pending_events[0]
	eq([ev.kind, ev.assertion, ev.bait, ev.bait_topic, ev.canary, ev.says_alive], ["assert", "as.pared", true, "pared", "", false])
	eq(ev.ents, ["reichenbach", "pared"])
	var r2: Dictionary = Dialogue.act_assert(st, rp, {"char": "watson", "assertion": "cn.chelsea"})
	eq(st.pending_events[1].canary, "cn.chelsea")
	eq(st.pending_events[1].bait, false)
	var r3: Dictionary = Dialogue.act_assert(st, rp, {"char": "watson", "assertion": "as.vive"})
	eq(r3.outcome, "HB4", "decirle a Watson que Holmes vive -> HB4")
	eq(r3.line.id, "hb4.1")
	eq(st.pending_events[2].says_alive, true)
	eq(st.react.imm_calls[2]._reaction, "HB4")
	eq(Dialogue.budget_left(st, rp, "watson"), 0, "afirmar cuenta como pregunta")
	var st2 = _st({"chars": ["watson", "ujier"], "index": ["holmes"]})
	eq(Dialogue.act_assert(st2, rp, {"char": "watson", "assertion": "as.testamento"}).err, "no_indexado")
	eq(Dialogue.act_assert(st2, rp, {"char": "ujier", "assertion": "cn.chelsea"}).err, "forma", "canal del personaje")
	eq(Dialogue.act_assert(st2, rp, {"char": "watson", "assertion": "as.nada"}).err, "forma")
	var avail: Array = Dialogue.assertions(st2, rp, "watson").map(func(x): return x.id)
	eq(avail, ["as.vive", "cn.chelsea"], "requires en el índice")
	eq(Dialogue.assertions(st2, rp, "ujier"), [], "el ujier (K-BM) no es canal de ninguna afirmación")
	eq(Dialogue.assertions(st2, rp).map(func(x): return x.id), ["as.vive", "cn.chelsea"], "sin personaje: todas las disponibles")

# ---------------- presentar: especiales ----------------
func test_present_hb4_first_and_second():
	var st = _st({"chars": ["watson"]})
	Fakes.clip(st, "RC1", "Mary llamaba James a su marido.", ["mary_watson"], ["a:x", "x:EE01"], "D01N")
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "clip", "id": "RC1"}})
	ok(r.ok, str(r))
	eq(r.outcome, "HB4")
	eq(r.line.text, "Se toca el crespón del sombrero. —Prefiero no hablar de eso, señor Lisle.")
	eq(r.phrase, "Mire esto, doctor: «Mary llamaba James a su marido.»")
	var r2: Dictionary = Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "clip", "id": "RC1"}})
	eq(r2.outcome, "HB4")
	eq(r2.line.id, "hb4.2", "2.ª vez: ui_text scenes.hb4.2")
	eq(r2.line.text, "Mi amigo está muerto, señor Lisle, y yo tengo pacientes. Vuelva usted el lunes.", "cerrada hasta el 5; el 6 es domingo")
	# Director real: HB4 es voz A, el cierre (consulta_cerrada_hasta) recién se escribe al amanecer -> hoy + 2, sin domingo
	Deps.Director = NoDirector
	for dc in [[2, "Vuelva usted el sábado."], [3, "Vuelva usted el lunes."], [4, "Vuelva usted el lunes."]]:
		var sx = _st({"chars": ["watson"], "day": dc[0]})
		sx.flags["hb4_veces"] = 1
		Fakes.clip(sx, "RC1", "Mary.", ["mary_watson"], [], "D01N")
		var rx: Dictionary = Dialogue.act_present(sx, rp, {"char": "watson", "item": {"kind": "clip", "id": "RC1"}})
		ok(String(rx.line.text).ends_with(dc[1]), "día %d: %s" % [dc[0], rx.line.text])
	Fakes.install()
	# asiento que afirma que vive (T7 holmes/vivo)
	var st2 = _st({"chars": ["watson"]})
	Fakes.entry(st2, "AS1", "T7", [{"fields": {"persona": "holmes"}, "support": []}, {"fields": {"estado": "vivo"}, "support": []}])
	eq(Dialogue.act_present(st2, rp, {"char": "watson", "item": {"kind": "entry", "id": "AS1"}}).outcome, "HB4")
	# sólo Holmes, sin «vive»: no
	var st3 = _st({"chars": ["watson"]})
	Fakes.clip(st3, "RC2", "Holmes.", ["holmes"], [], "D03")
	eq(Dialogue.act_present(st3, rp, {"char": "watson", "item": {"kind": "clip", "id": "RC2"}}).outcome, "")

func test_present_hb6_hudson_with_immediate_line():
	var st = _st({"chars": ["mrs_hudson"], "place": "L3"})
	st.react["imm_lines"] = {"HB6": [{"line": "Dobla los «sir». —Órdenes del empleado, sir."}]}
	Fakes.clip(st, "RC1", "Los cuartos del 221B.", ["221b"], [], "D30")
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "mrs_hudson", "item": {"kind": "clip", "id": "RC1"}})
	eq(r.outcome, "HB6")
	eq(r.line.id, "cuartos", "HB6 no trae línea propia: respuesta por capas")
	eq(r.lines[-1].kind, "inmediata")
	eq(r.lines[-1].text, "Dobla los «sir». —Órdenes del empleado, sir.")
	eq(st.react.imm_calls[0]._reaction, "HB6")
	eq(st.react.imm_calls[0].type, "show")

func test_present_m4_pell():
	var st = _st({"chars": ["pell"], "place": "L1"})
	Fakes.clip(st, "RC1", "Moran mató a Adair.", ["moran"], [], "D15.0403")
	st.react["cats"] = {"RC1": ["moran_autor"]}
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "pell", "item": {"kind": "clip", "id": "RC1"}})
	eq(r.outcome, "M4")
	eq(r.line.id, "m4")
	eq(st.pending_events[0].item.get("cats"), ["moran_autor"], "show a Pell lleva las categorías de Moran (regla M4 del Director)")
	var st2 = _st({"chars": ["pell"], "place": "L1"})
	Fakes.clip(st2, "RC1", "Moran mató a Adair.", ["moran"], [], "D15.0403")
	eq(Dialogue.act_present(st2, rp, {"char": "pell", "item": {"kind": "clip", "id": "RC1"}}).outcome, "")

func test_present_and_pay_hb8_wiggins():
	var st = _st({"chars": ["wiggins"], "day": 3})
	Fakes.clip(st, "RC1", "The old scale of pay.", ["vieja_tarifa"], [], "D44")
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "wiggins", "item": {"kind": "clip", "id": "RC1"}})
	eq(r.outcome, "HB8")
	eq(r.line.id, "hb8")
	var st2 = _st({"chars": ["wiggins"], "day": 2})
	Fakes.clip(st2, "RC1", "The old scale of pay.", ["vieja_tarifa"], [], "D44")
	eq(Dialogue.act_present(st2, rp, {"char": "wiggins", "item": {"kind": "clip", "id": "RC1"}}).outcome, "", "antes del día 3 no")
	var st3 = _st({"chars": ["wiggins"], "day": 4})
	var p: Dictionary = Dialogue.act_pay(st3, rp, {"char": "wiggins", "amount_d": 12})
	eq(p.outcome, "HB8", "un chelín")
	eq(st3.pending_events[0], {"type": "pay", "amount_d": 12, "char": "wiggins"})
	eq(p.phrase, "Tome, muchacho: 1s.")
	st3.flags["wiggins_aliado"] = true
	var p2: Dictionary = Dialogue.act_pay(st3, rp, {"char": "wiggins", "amount_d": 6})
	eq(p2.outcome, "")
	eq(p2.line.id, "pago", "línea fija de pago")
	eq(Dialogue.act_pay(st3, rp, {"char": "wiggins", "amount_d": 0}).err, "forma")

func test_task_wiggins():
	var st = _st({"chars": ["wiggins", "crane"], "day": 4})
	eq(Dialogue.act_task(st, rp, {"char": "wiggins", "task": "seguir_parker"}).err, "no_aliado")
	st.flags["wiggins_aliado"] = true
	var r: Dictionary = Dialogue.act_task(st, rp, {"char": "wiggins", "task": "seguir_parker"})
	ok(r.ok, str(r))
	eq(r.line.id, "tarea.seguir_parker")
	eq(r.phrase, "Siga usted al hombrecito del arpa, muchacho, y dígame dónde duerme.")
	eq(st.pending_events[-1], {"type": "task", "task": "seguir_parker", "char": "wiggins"})
	eq(Dialogue.act_task(st, rp, {"char": "wiggins", "task": "seguir_chico_pell"}).err, "uno_por_dia")
	st.clock.day = 5
	var r2: Dictionary = Dialogue.act_task(st, rp, {"char": "wiggins", "task": "seguir_chico_pell"})
	eq(r2.line.text, "Hecho, jefe. Mañana le cuento.", "sin línea propia: ui_text")
	eq(Dialogue.act_task(st, rp, {"char": "wiggins", "task": "robar"}).err, "forma")
	eq(Dialogue.act_task(st, rp, {"char": "crane", "task": "seguir_parker"}).err, "forma")
	st.flags["wiggins_quemado"] = true
	st.clock.day = 7
	eq(Dialogue.act_task(st, rp, {"char": "wiggins", "task": "seguir_parker"}).err, "no_aliado")

# ---------------- HB12 (Mycroft) ----------------
func _mycroft_state():
	var st = _st({"chars": ["mycroft"], "day": 8, "slot": "T", "place": "L5", "visit_id": "S.L5.8.T"})
	Fakes.clip(st, "RC1", "Asiento 214.", [{"id": "act.3", "label": "asiento 214, mar. 27"}], ["a:ancla_kbm"], "R.HA1.1")
	Fakes.clip(st, "RC2", "Pedí el Journal.", [{"id": "act.3", "label": "asiento 214, mar. 27"}], ["a:acto_kbm"], "D36")
	Fakes.clip(st, "RC3", "El mismo asiento.", [{"id": "act.3", "label": "asiento 214, mar. 27"}], ["a:ancla_kbm"], "S.HC06")
	Fakes.clip(st, "RC4", "Otra cosa.", ["reichenbach"], ["a:acto_kbm"], "S.M7")
	Fakes.clip(st, "RCX", "Camden.", ["camden_house"], ["a:tirador", "f:secreto_camden"], "N.L8")
	return st

func test_hb12_success_offers_errata():
	var st = _mycroft_state()
	Fakes.entry(st, "AS1", "T6", [{"fields": {"persona": "mycroft", "relacion": "lee_a", "a_quien": "lisle", "por_medio": "sala_lectura"}, "support": ["RC1", "RC2"]}], "tinta")
	st.ded.sealed["C6"] = "AS1"
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS1"}})
	eq(r.outcome, "HB12")
	eq(r.line.id, "hb12.ok")
	eq(st.flags.errata_ofrecida, "mycroft")
	ok(st.scenes.mycroft.ok)
	eq(st.react.imm_calls[0]._reaction, "HB12")
	var r2: Dictionary = Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "clip", "id": "RC4"}})
	eq(r2.outcome, "", "ya ofrecida: respuesta normal")
	eq(int(st.scenes.mycroft.errors), 0)

func test_hb12_errors_close_forasteros():
	var st = _mycroft_state()
	Fakes.entry(st, "AS2", "T6", [{"fields": {"persona": "holmes"}, "support": ["RC1", "RC4"]}])
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "clip", "id": "RC1"}})
	eq(r.outcome, "HB12_error")
	eq(r.line.text, "Otra vez, señor Lisle; no tengo toda la tarde.")
	no(st.flags.has("forasteros_cerrada"))
	var r2: Dictionary = Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS2"}})
	eq(r2.outcome, "HB12_cerrada", "asiento sin sellar = error")
	eq(r2.line.id, "hb12.err2")
	eq(st.flags.forasteros_cerrada, true)
	no(st.flags.has("errata_ofrecida"))
	eq(Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "clip", "id": "RC1"}}).err, "no_esta", "Mycroft se fue")
	eq(Dialogue.act_ask(st, rp, {"char": "mycroft", "topic": "reichenbach"}).err, "no_esta")
	no(Dialogue.present_ok(st, rp, "mycroft"))

func test_hb12_camden_is_error_and_withheld():
	var st = _mycroft_state()
	Fakes.entry(st, "AS3", "T6", [{"fields": {"persona": "amigo_de_la_exactitud"}, "support": ["RC1", "RCX"]}], "tinta")
	st.ded.sealed["C7"] = "AS3"
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS3"}})
	eq(r.outcome, "HB12_error", "secreto_camden: error sin leerlo")
	var item: Dictionary = st.pending_events[0].item
	eq(item.withheld, true)
	eq(item.ents, [])
	no(item.has("entry_values"), "nada de Camden llega al evento")

func test_hb12_ignores_hc06_clips():
	var st = _mycroft_state()
	# sólo vale por RC3 (S.HC06): sin él queda un origen -> no sostiene
	Fakes.entry(st, "AS4", "T6", [{"fields": {"persona": "mycroft"}, "support": ["RC1", "RC3"]}], "tinta", {"fake_cid": "C6"})
	st.ded.sealed["C6"] = "AS4"
	eq(Dialogue.act_present(st, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS4"}}).outcome, "HB12_error")
	# con un par (RC3 + RC4): se descarta RC3 y queda RC4 (S.M7) -> 2 orígenes
	var st2 = _mycroft_state()
	st2.ded.pairs["PR001"] = {"id": "PR001", "a": "RC3", "b": "RC4", "note": ""}
	Fakes.entry(st2, "AS5", "T6", [{"fields": {"persona": "mycroft"}, "support": ["RC1", "PR001"]}], "tinta", {"fake_cid": "C6"})
	st2.ded.sealed["C6"] = "AS5"
	eq(Dialogue.act_present(st2, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS5"}}).outcome, "HB12")
	# línea dicha en la escena HC06 (origen = visita): también se excluye por el registro de la línea
	var st3 = _mycroft_state()
	st3.world["lines"] = {"LN.0042": {"uid": "LN.0042", "scene": "HC06", "origin": "S.L5.8.T"}}
	Fakes.clip(st3, "RC5", "Mi hermano detesta las erratas.", ["mycroft"], ["a:ancla_kbm"], "S.L5.8.T", {"src_kind": "line", "view": "LN.0042"})
	Fakes.entry(st3, "AS6", "T6", [{"fields": {"persona": "mycroft"}, "support": ["RC1", "RC5"]}], "tinta", {"fake_cid": "C6"})
	st3.ded.sealed["C6"] = "AS6"
	eq(Dialogue.act_present(st3, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS6"}}).outcome, "HB12_error")
	eq(st3.ded.entries.AS6.lines[0].support, ["RC1", "RC5"], "la revalidación no muta el asiento real")
	# recortado desde el diario: Clipper guarda `scene` de la línea (view = id de diario, no uid)
	var st4 = _mycroft_state()
	Fakes.clip(st4, "RC6", "Mi hermano detesta las erratas.", ["mycroft"], ["a:ancla_kbm"], "S.L5.8.T", {"src_kind": "diary", "view": "DI.0007", "scene": "HC06"})
	Fakes.entry(st4, "AS7", "T6", [{"fields": {"persona": "mycroft"}, "support": ["RC1", "RC6"]}], "tinta", {"fake_cid": "C6"})
	st4.ded.sealed["C6"] = "AS7"
	eq(Dialogue.act_present(st4, rp, {"char": "mycroft", "item": {"kind": "entry", "id": "AS7"}}).outcome, "HB12_error")

# Ids de líneas especiales: los de W2-SCENES (hb12.ok…) o los que declara la reacción en su efecto `linea`
# (reactions/*.json: HB12 hb12_exito/hb12_error_1/hb12_error_2 por `resultado`; HB8 vieja_tarifa, §4.8 L:wiggins.vieja_tarifa).
class NoDirector:
	static func immediate(_st, _repo, _ev: Dictionary) -> Array:
		return []

class StubRepo:
	var base
	var dl := {}
	var rx := {}
	func dialogue(c: String) -> Dictionary:
		return dl.get(c, base.dialogue(c))
	func reaction(id: String) -> Dictionary:
		return rx.get(id, {})
	func texts() -> Dictionary:
		return base.texts()

func test_special_line_ids_follow_reaction_data():
	var R := StubRepo.new()
	R.base = rp
	R.dl["mycroft"] = {"char": "mycroft", "lines": [
		{"id": "hb12_exito", "layer": "tema", "reaction": "HB12", "text": "Éxito."},
		{"id": "hb12_error_1", "layer": "tema", "reaction": "HB12", "text": "Error uno."},
		{"id": "hb12_error_2", "layer": "tema", "reaction": "HB12", "text": "Error dos."}]}
	R.dl["wiggins"] = {"char": "wiggins", "lines": [{"id": "vieja_tarifa", "layer": "tema", "text": "La vieja tarifa, jefe."}]}
	var st = _st()
	# sin la regla: el éxito puede salir por la línea genérica de la reacción; los errores, NUNCA por la del éxito
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.ok").id, "hb12_exito")
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.err1").id, "hb12.err1", "error sin regla: ui_text, no la del éxito")
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.err2").id, "hb12.err2")
	R.rx["HB12"] = {"id": "HB12", "efecto": [
		{"op": "linea", "char": "mycroft", "line": "hb12_exito", "resultado": "exito"},
		{"op": "flag", "name": "errata_ofrecida", "value": "mycroft", "resultado": "exito"},
		{"op": "linea", "char": "mycroft", "line": "hb12_error_1", "resultado": "error_1"},
		{"op": "linea", "char": "mycroft", "line": "hb12_error_2", "resultado": "error_2"}]}
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.ok").id, "hb12_exito")
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.err1").id, "hb12_error_1")
	eq(Dialogue._special_line(st, R, "mycroft", "HB12", "hb12.err2").id, "hb12_error_2")
	R.rx["HB8"] = {"id": "HB8", "efecto": [{"op": "flag", "name": "wiggins_aliado", "value": true}, {"op": "linea", "char": "wiggins", "line": "vieja_tarifa"}]}
	eq(Dialogue._special_line(st, R, "wiggins", "HB8", "hb8").id, "vieja_tarifa", "HB8 por el id del contrato aunque no lleve reaction")
	# HB4: una línea genérica de la reacción sirve para la 1.ª, nunca para la 2.ª
	R.dl["watson"] = {"char": "watson", "lines": [{"id": "crespon", "layer": "tema", "reaction": "HB4", "text": "Se toca el crespón."}]}
	eq(Dialogue._special_line(st, R, "watson", "HB4", "hb4.1").id, "crespon")
	eq(Dialogue._special_line(st, R, "watson", "HB4", "hb4.2").id, "hb4.2")

# ---------------- evento visible, efectos, temas ----------------
func test_show_event_carries_only_visible():
	var st = _st({"chars": ["watson"]})
	Fakes.clip(st, "RC1", "Una cornisa que no se ve desde el sendero.", ["cornisa", "journal_de_geneve", "guillotina"], ["a:cornisa_existe", "c:verdadero"], "D05", {"copy": "D05@BM", "cls": "I"})
	var r: Dictionary = Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "clip", "id": "RC1"}})
	eq(r.line.id, "doc.journal", "documento visible (entidad con doc)")
	var it: Dictionary = st.pending_events[0].item
	eq(it.keys().size(), 5, str(it))
	eq(it.kind, "clip")
	eq(it.doc_ids, ["D05"])
	eq(it.ents, ["cornisa", "journal_de_geneve"], "sin entidades de Camden")
	eq(it.origins, ["D05"])
	eq(it.src_types, [], "D05 no está en este fixture")
	Fakes.entry(st, "AS1", "T8", [{"fields": {"persona": "holmes"}, "support": ["RC1"]}, {"fields": {"lugar": "meiringen"}, "support": []}])
	Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "entry", "id": "AS1"}})
	var it2: Dictionary = st.pending_events[1].item
	eq(it2.entry_values, {"lugar": "meiringen", "persona": "holmes"})
	eq(it2.ents, ["holmes", "meiringen"])
	eq(it2.origins, ["D05"])
	eq(Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "clip", "id": "NADA"}}).err, "no_existe")
	eq(Dialogue.act_present(st, rp, {"char": "watson", "item": {"kind": "pair", "id": "RC1"}}).err, "forma")

func test_line_effects_go_to_effects():
	var st = _st({"chars": ["watson"], "index": ["baston"]})
	var r: Dictionary = Dialogue.act_ask(st, rp, {"char": "watson", "topic": "baston"})
	eq(r.line.id, "baston")
	eq(st.react.eff_calls.size(), 1)
	var inst: Dictionary = st.react.eff_calls[0]
	eq(inst.iid, "LINE." + String(r.line.uid))
	eq(inst.rid, "")
	eq(inst.efecto, [{"op": "flag", "name": "fixture_baston", "value": true}])

func test_topics_and_scene_chars():
	var st = _st({"chars": ["watson", "crane"], "index": ["pared", "act.3", "holmes", "cornisa"]})
	eq(Dialogue.topics(st, rp, "watson").map(func(x): return x.id), ["cornisa", "holmes", "pared"], "sin act_ref; por etiqueta")
	eq(Dialogue.topics(st, rp, "nadie"), [])
	var sc: Array = Dialogue.scene_chars(st, rp)
	eq(sc[0].label, "médico", "sin presentarse: sustantivo")
	Dialogue.act_ask(st, rp, {"char": "watson", "topic": "pared"})
	eq(Dialogue.scene_chars(st, rp)[0].label, "el doctor Watson")
	eq(Dialogue.scene_chars(st, rp)[0].trait, "bombin_crespon")
	ok(Dialogue.scene_chars(st, rp)[0].can_ask)

# ---------------- escenas ----------------
func test_scene_lines_variants():
	var st = _st({"day": 7})
	eq(_ids(Dialogue.scene_lines(st, rp, "M7")), ["inteligente", "donde_duerme", "trichinopolis"])
	st.flags["pell_despedido"] = true
	st.flags["informes_vacios"] = 2
	var ls: Array = Dialogue.scene_lines(st, rp, "M7")
	eq(_ids(ls), ["inteligente", "donde_duerme", "trichinopolis", "mudo"])
	ok(String(ls[0].text).contains("Su procurador ya no nos sirve."))
	eq(_ids(Dialogue.scene_lines(st, rp, "HC07")), ["compra"], "conf.* no se dicen como escena")

func test_scene_acts_by_channel():
	var st = _st({"day": 8})
	eq(_ids(Dialogue.scene_lines(st, rp, "HC06")), ["a", "b", "g"], "sin actos: fallback")
	st.events.append({"type": "slip", "seq": 4, "act": "act.4", "day": 1, "slot": "M", "seat": 214, "title": "el Journal de Genève"})
	st.events.append({"type": "say", "seq": 5, "act": "act.5", "day": 2, "slot": "T", "char": "watson", "topic": "pared", "phrase": "La pared era a pique, ¿no, doctor?"})
	st.events.append({"type": "say", "seq": 6, "act": "act.6", "day": 2, "slot": "T", "char": "watson", "topic": "perro", "phrase": "otra"})
	var ls: Array = Dialogue.scene_lines(st, rp, "HC06")
	eq(_ids(ls), ["a", "b_kbm", "b_kw", "g"])
	var p: Dictionary = rp.parse_text(String(ls[1].text))
	eq(p.errors, [], String(ls[1].text))
	eq(p.mentions[0].ent, "act.4")
	ok(String(p.plain).contains("asiento 214"), p.plain)
	ok(String(p.plain).contains("miércoles 28") == false and String(p.plain).contains("martes 27"), p.plain)
	eq(p.tramos[0].tags.a, ["ancla_kbm"])
	ok(String(ls[2].text).contains("[[act.5|"), "cita el primer acto del canal")
	st.clock.day = 7
	eq(Dialogue.scene_lines(st, rp, "HC06"), [], "when de la escena")
	st.clock.day = 8
	var said: Array = Dialogue.play_scene(st, rp, "HC06")
	eq(said.size(), 4)
	eq(said[0].origin, "S.HC06")
	eq(said[0].scene, "HC06")
	eq(said[0].kind, "escena")
	eq(Dialogue.said(st, {"scene": "HC06"}).size(), 4)

func test_said_lines_are_found_by_clipper():
	var st = _st({"chars": ["watson"], "index": ["pared"]})
	var r: Dictionary = Dialogue.act_ask(st, rp, {"char": "watson", "topic": "pared"})
	eq(Dialogue.line(st, r.line.uid).text, r.line.text)
	var real = load("res://core/deduction/clipper.gd")
	if not real.has_method("find_record"):
		skip("Clipper.find_record aún no existe (W2-DED)")
		return
	var rec: Dictionary = real.find_record(st, String(r.line.uid))
	eq(String(rec.get("text", "")), String(r.line.text), "Clipper (W2-DED) encuentra la línea en st.scenes.lines")
	eq(String(rec.get("origin", "")), "S.L4.3.M")
