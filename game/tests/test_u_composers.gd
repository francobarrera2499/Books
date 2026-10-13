# Unit: core/scenes/composers.gd (W2-SCENES). Formas de anuncio (sin lugares de Londres ni secreto_camden, también
# sobre los datos reales), oficina/uno por día/publicación, telegramas y cartas, informes (modos, errores, evento).
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Composers = preload("res://core/scenes/composers.gd")
const Markup = preload("res://core/text/markup.gd")
const J = preload("res://core/util/j.gd")

const TIMEOUT_S := 60.0

var rp

func before_each() -> void:
	Fakes.install()
	rp = Fakes.repo()

func after_each() -> void:
	Fakes.uninstall()

func _st(opts := {}):
	var o := {"phase": "desk", "day": 1, "slot": "M", "index": ["suceso_reichenbach", "journal_de_geneve", "reichenbach", "pared", "holmes",
		"meiringen", "bath", "baker_street", "paraguas", "guillotina", "camden_house", "cornisa", "testamento"]}
	o.merge(opts, true)
	return Fakes.state(rp, o)

# ---------------- formas ----------------
func test_forms_and_preview_text():
	var ids: Array = Composers.forms(rp).map(func(f): return f.id)
	eq(ids, ["testigo", "a_proposito", "al_corresponsal", "perdido", "prueba_lugar"])
	var st = _st()
	eq(Composers.preview_ad(st, rp, "testigo", {"suceso": "suceso_reichenbach"}),
		{"ok": true, "err": "", "text": "Se busca testigo de lo ocurrido en el Reichenbach el 4 de mayo de 1891. Escribir a E. L., Holywell Street."})
	eq(Composers.preview_ad(st, rp, "a_proposito", {"fuente": "journal_de_geneve", "afirmacion": "as.pared"}).text,
		"A propósito del Journal de Genève: la pared era a pique. —E. L.", "contracción sólo en la juntura")
	eq(Composers.preview_ad(st, rp, "perdido", {"objeto": "paraguas"}).text, "Perdido: un paraguas. Se gratificará a quien lo devuelva a E. L., Holywell Street.")

func test_preview_rejections():
	var st = _st()
	eq(Composers.preview_ad(st, rp, "testigo", {"suceso": "suceso_park_lane"}).err, "forma", "fuera del índice")
	eq(Composers.preview_ad(st, rp, "prueba_lugar", {"lugar": "baker_street"}).err, "forma", "lugar de Londres")
	eq(Composers.preview_ad(st, rp, "prueba_lugar", {"lugar": "camden_house"}).err, "forma", "Londres y Camden")
	eq(Composers.preview_ad(st, rp, "prueba_lugar", {"lugar": "guillotina"}).err, "forma", "secreto_camden")
	ok(Composers.preview_ad(st, rp, "prueba_lugar", {"lugar": "meiringen"}).ok)
	eq(Composers.preview_ad(st, rp, "perdido", {"objeto": "guillotina"}).err, "forma", "secreto_camden en perdido")
	eq(Composers.preview_ad(st, rp, "perdido", {"objeto": "cornisa"}).err, "forma", "kind")
	eq(Composers.preview_ad(st, rp, "a_proposito", {"fuente": "journal_de_geneve"}).err, "forma", "falta slot")
	eq(Composers.preview_ad(st, rp, "a_proposito", {"fuente": "journal_de_geneve", "afirmacion": "cn.chelsea"}).err, "forma", "kind de afirmación")
	eq(Composers.preview_ad(st, rp, "nada", {}).err, "forma")
	var st2 = _st({"index": ["journal_de_geneve", "reichenbach"]})
	eq(Composers.preview_ad(st2, rp, "a_proposito", {"fuente": "journal_de_geneve", "afirmacion": "as.pared"}).err, "forma", "requires fuera del índice")
	eq(Composers.preview_ad(st, rp, "al_corresponsal", {"frase": "as.pared"}).err, "forma", "antes del día 4")
	var st4 = _st({"day": 4})
	eq(Composers.preview_ad(st4, rp, "al_corresponsal", {"frase": "as.pared"}).text, "Al corresponsal S.: la pared era a pique. —E. L.")

func test_options_exclude_london_and_camden():
	var st = _st()
	var ids: Array = Composers.options(st, rp, "prueba_lugar", "lugar").map(func(x): return x.id)
	ok(ids.has("meiringen") and ids.has("bath") and ids.has("paraguas"), str(ids))
	for bad in ["baker_street", "camden_house", "guillotina", "park_lane"]:
		no(ids.has(bad), "excluye " + bad)
	eq(Composers.options(st, rp, "testigo", "suceso").map(func(x): return x.id), ["suceso_reichenbach"], "sólo del índice")
	eq(Composers.options(st, rp, "a_proposito", "afirmacion").map(func(x): return x.id), ["as.pared", "as.testamento", "as.vive"])
	eq(Composers.options(st, rp, "a_proposito", "afirmacion")[0].label, "La pared era a pique")

# Aceptación W2-SCENES sobre los datos reales: con TODO el índice, ninguna forma ofrece un lugar de Londres ni una
# entidad secreto_camden, y toda forma declara ambas prohibiciones.
func test_real_forms_never_offer_london_or_camden():
	var r = repo()
	var fs: Array = Composers.forms(r)
	if fs.is_empty():
		pending_content("lists.ad_forms (W1-BIBLE)")
		return
	var london: Array = r.lists().get("london_places", [])
	var camden: Array = r.lists().get("camden_entities", [])
	ok(not london.is_empty() and not camden.is_empty(), "lists.london_places y lists.camden_entities")
	var st = Fakes.state(r, {"day": 9, "phase": "desk", "index": r.entities().keys()})
	for f in fs:
		ok(bool(f.get("forbid_kinds_lugar_londres", false)), "forbid_kinds_lugar_londres en " + f.id)
		ok(f.get("forbid_tags", []).has("secreto_camden"), "forbid_tags secreto_camden en " + f.id)
		for slot in f.get("slots", {}):
			var opts: Array = Composers.options(st, r, f.id, slot)
			ok(not opts.is_empty(), "%s.%s ofrece algo" % [f.id, slot])
			for o in opts:
				no(london.has(o.id), "%s.%s ofrece un lugar de Londres: %s" % [f.id, slot, o.id])
				no(camden.has(o.id), "%s.%s ofrece secreto_camden: %s" % [f.id, slot, o.id])
				var asr: Dictionary = Composers._assertion(r, o.id)
				for q in asr.get("requires", []):
					no(london.has(q) or camden.has(q), "afirmación con requisito prohibido: " + o.id)
		for e in r.entities():
			if london.has(e) or camden.has(e):
				for slot in f.get("slots", {}):
					var fields := {slot: e}
					no(Composers.preview_ad(st, r, f.id, fields).ok, "%s acepta %s" % [f.id, e])

# ---------------- redactar ----------------
func test_compose_ad_office_rules_and_record():
	var st = _st()
	var r: Dictionary = Composers.act_compose_ad(st, rp, {"form": "a_proposito", "fields": {"fuente": "journal_de_geneve", "afirmacion": "as.pared"}})
	ok(r.ok, str(r))
	eq([r.ad, r.ad_id, r.ref, r.pub_day, r.cost_d], ["AD:1", "AD.1", "AD:1", 2, 30])
	eq(r.event.type, "ad")
	eq([r.event.ad, r.event.assertion, r.event.bait, r.event.bait_topic, r.event.says_alive, r.event.to_s], ["AD:1", "as.pared", true, "pared", false, false])
	eq(st.pending_events, [], "el evento sale al publicarse")
	eq(Composers.act_compose_ad(st, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).err, "uno_por_dia")
	var stn = _st({"slot": "N"})
	eq(Composers.act_compose_ad(stn, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).err, "oficina_cerrada")
	var stv = _st({"phase": "visit"})
	eq(Composers.act_compose_ad(stv, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).err, "oficina_cerrada")
	var sts = _st({"day": 5, "slot": "T"})
	eq(Composers.act_compose_ad(sts, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).pub_day, 7, "sáb -> lun")
	var stp = _st({"day": 0, "slot": "N", "phase": "prologue"})
	var rp0: Dictionary = Composers.act_compose_ad(stp, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	eq([rp0.ad, rp0.ad_id, rp0.pub_day], ["AD:prologo", "AD.1", 1], "prólogo -> día 1; event.ad = AD:prologo (HC10)")
	eq(rp0.event.ad, "AD:prologo")
	var st4 = _st({"day": 4})
	var rv: Dictionary = Composers.act_compose_ad(st4, rp, {"form": "al_corresponsal", "fields": {"frase": "as.vive"}})
	eq([rv.event.to_s, rv.event.says_alive, rv.event.bait], [true, true, false])
	var stc = _st({"day": 3})
	eq(Composers.act_compose_ad(stc, rp, {"form": "perdido", "fields": {"objeto": "paraguas"}}).event.canary, "perdido:paraguas")
	var bad = _st()
	var before := J.stringify_canon(bad.scenes)
	eq(Composers.act_compose_ad(bad, rp, {"form": "perdido", "fields": {"objeto": "guillotina"}}).err, "forma")
	eq(J.stringify_canon(bad.scenes), before, "error no muta")

func test_publication_on_dawn():
	var st = _st()
	Composers.act_compose_ad(st, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	eq(Composers.due_ads(st, 1), [])
	eq(Composers.due_ads(st, 2).size(), 1)
	var evs: Array = Composers.on_dawn(st, rp, 2)
	eq(evs.size(), 1)
	eq(st.pending_events.size(), 1)
	var ev: Dictionary = st.pending_events[0]
	eq([ev.type, ev.ad, ev.pub_day, ev.day, ev.slot, ev.tk], ["ad", "AD:1", 2, 2, "dawn", 20])
	eq(ev.text, "Se busca testigo de lo ocurrido en el Reichenbach el 4 de mayo de 1891. Escribir a E. L., Holywell Street.")
	eq(Composers.on_dawn(st, rp, 2), [], "una sola vez")
	eq(Composers.due_ads(st, 2), [])

func test_ad_markup_for_the_times():
	var st = _st()
	Composers.act_compose_ad(st, rp, {"form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	var m := Composers.ad_markup(st, rp, "AD.1", "act.9")
	var p: Dictionary = rp.parse_text(m)
	eq(p.errors, [], m)
	eq(Markup.lint(m), [], "tramo dentro de una oración")
	eq(p.plain, Composers.ads(st)[0].text)
	eq(p.tramos.size(), 1)
	eq(p.tramos[0].tags.a, ["acto_kt"])
	eq(p.mentions[0].ent, "act.9")
	eq(Composers.ad_markup(st, rp, "AD:1", "act.9"), m, "por ref también")
	eq(Composers.ad_markup(st, rp, "AD.7", "act.9"), "")

func test_telegram_and_letter():
	var st = _st()
	var t: Dictionary = Composers.act_compose_telegram(st, rp, {"to": "meiringen", "parts": ["as.pared", "cornisa"]})
	ok(t.ok, str(t))
	eq(t.id, "TG.1")
	eq(t.text, "MEIRINGEN. RUEGO NOTICIAS SOBRE «LA PARED ERA A PIQUE» Y LA CORNISA. E. L., HOLYWELL STREET, LONDRES.")
	eq(t.cost_d, 3 * Markup.words_of(t.text).size())
	eq(t.event, {"type": "telegram", "to": "meiringen", "text": t.text, "id": "TG.1", "parts": ["as.pared", "cornisa"]})
	var l: Dictionary = Composers.act_compose_letter(st, rp, {"to": "bath", "parts": ["holmes"]})
	eq(l.id, "LT.1")
	ok(String(l.text).begins_with("Muy señor mío: me permito escribirle a propósito de Sherlock Holmes."), l.text)
	eq(l.cost_d, 1)
	eq(Composers.act_compose_telegram(st, rp, {"to": "baker_street", "parts": ["cornisa"]}).err, "forma", "Londres")
	eq(Composers.act_compose_telegram(st, rp, {"to": "montpellier", "parts": ["cornisa"]}).err, "forma", "fuera del índice")
	eq(Composers.act_compose_telegram(st, rp, {"to": "meiringen", "parts": ["guillotina"]}).err, "forma", "secreto_camden")
	eq(Composers.act_compose_telegram(st, rp, {"to": "meiringen", "parts": []}).err, "forma")
	eq(Composers.act_compose_telegram(st, rp, {"to": "meiringen", "parts": ["cornisa", "cornisa"]}).err, "forma")
	eq(Composers.act_compose_telegram(st, rp, {"to": "meiringen", "parts": ["cornisa", "pared", "holmes", "bath"]}).err, "forma", "≤3 piezas")
	eq(Composers.act_compose_letter(st, rp, {"to": "cornisa", "parts": ["holmes"]}).err, "forma", "destino persona o lugar")
	eq(Composers.pending_mail(st).size(), 2)
	eq(Composers.preview(st, rp, {"t": "compose_telegram", "to": "meiringen", "parts": ["cornisa"]}), "MEIRINGEN. RUEGO NOTICIAS SOBRE LA CORNISA. E. L., HOLYWELL STREET, LONDRES.")
	var evs: Array = Composers.on_end_slot(st, rp)
	eq(evs.map(func(e): return [e.type, e.to]), [["telegram", "meiringen"], ["letter", "bath"]])
	eq(st.pending_events.size(), 2)
	eq(Composers.pending_mail(st), [])
	eq(Composers.on_end_slot(st, rp), [], "una sola vez")
	var tos: Array = Composers.mail_options(st, rp, "to").map(func(x): return x.id)
	ok(tos.has("meiringen") and tos.has("bath") and tos.has("holmes"), str(tos))
	no(tos.has("baker_street") or tos.has("camden_house") or tos.has("cornisa"))

# ---------------- informes ----------------
func _report_st(opts := {}):
	var st = _st(opts)
	Fakes.clip(st, "RC1", "En la pared, una marca reciente.", ["pared"], ["a:raspadura_registrada", "c:verdadero"], "D05", {"copy": "D05@BM", "cls": "I", "src_line": "Journal de Genève, prensa extranjera"})
	Fakes.clip(st, "RC2", "Lo atribuí a algún cabrero.", ["raspadura"], ["a:raspadura_registrada"], "D02", {"copy": "D02@L1", "cls": "P"})
	Fakes.entry(st, "AS1", "T8", [{"fields": {"persona": "holmes"}, "support": ["RC1"]}, {"fields": {"lugar": "meiringen"}, "support": ["RC2"]}])
	st.react["cats"] = {"RC1": ["verdadero"], "RC2": ["original_p"], "AS1": ["paradero_extranjero"]}
	return st

func test_report_due_and_errors():
	var st = _report_st()
	eq(Composers.report_status(st, rp).due, false)
	eq(Composers.act_report_submit(st, rp, {"mode": "nada", "items": []}).err, "sin_informe")
	st.clock.day = 2
	st.clock.phase = "night"
	var s: Dictionary = Composers.report_status(st, rp)
	eq([s.due, s.n, s.final, s.offered_erratum], [true, 1, false, false])
	var before := J.stringify_canon({"s": st.scenes, "f": st.flags, "p": st.pending_events})
	eq(Composers.act_report_submit(st, rp, {"mode": "quemar", "items": []}).err, "quemar_solo_final")
	eq(Composers.act_report_submit(st, rp, {"mode": "errata", "items": []}).err, "errata_no_ofrecida")
	eq(Composers.act_report_submit(st, rp, {"mode": "items", "items": [{"kind": "clip", "id": "RC1"}, {"kind": "clip", "id": "RC1"}]}).err, "forma", "repetido")
	eq(Composers.act_report_submit(st, rp, {"mode": "items", "items": [{"kind": "clip", "id": "X"}]}).err, "no_existe")
	eq(Composers.act_report_submit(st, rp, {"mode": "nada", "items": [{"kind": "clip", "id": "RC1"}]}).err, "forma")
	eq(Composers.act_report_submit(st, rp, {"mode": "items", "items": [{"kind": "clip", "id": "RC1"}, {"kind": "clip", "id": "RC2"}, {"kind": "entry", "id": "AS1"}, {"kind": "clip", "id": "RC1"}]}).err, "forma", "≤3")
	eq(Composers.act_report_submit(st, rp, {"mode": "otro", "items": []}).err, "forma")
	eq(J.stringify_canon({"s": st.scenes, "f": st.flags, "p": st.pending_events}), before, "errores no mutan")

func test_report_items_event():
	var st = _report_st({"day": 2, "phase": "night", "slot": "N"})
	var a := {"t": "report_submit", "mode": "items", "items": [{"kind": "clip", "id": "RC1"}, {"kind": "entry", "id": "AS1"}]}
	var pv := Composers.preview(st, rp, a)
	var r: Dictionary = Composers.act_report_submit(st, rp, a)
	ok(r.ok, str(r))
	eq([r.report, r.n, r.mode], ["RP.1", 1, "items"])
	eq(r.text, pv, "el texto final es el de la vista previa")
	ok(String(r.text).begins_with("Informe n.º 1, para el mayor Harris"), r.text)
	ok(String(r.text).contains("1. «En la pared, una marca reciente.» (Journal de Genève, prensa extranjera)"), r.text)
	ok(String(r.text).contains("2. Persona: Sherlock Holmes · Lugar: Meiringen"), r.text)
	var ev: Dictionary = st.pending_events[0]
	eq([ev.type, ev.n, ev.mode, ev.final], ["report", 1, "items", false])
	eq(ev.items[0], {"kind": "clip", "cats": ["verdadero"], "copies": ["D05@BM"], "cls": ["I"]})
	eq(ev.items[1], {"kind": "entry", "cats": ["paradero_extranjero"], "copies": ["D05@BM", "D02@L1"], "cls": ["I", "P"], "values": {"lugar": "meiringen", "persona": "holmes"}})
	no(str(ev).contains("raspadura_registrada"), "sin etiquetas ocultas en el evento")
	no(st.flags.has("informe_final"))
	eq(Composers.report_status(st, rp).due, false, "ya entregado")
	eq(Composers.act_report_submit(st, rp, {"mode": "nada", "items": []}).err, "sin_informe")

func test_report_empty_items_is_nada_and_pell_fired():
	var st = _report_st({"day": 5, "phase": "night", "slot": "N"})
	st.flags["pell_despedido"] = true
	var r: Dictionary = Composers.act_report_submit(st, rp, {"mode": "items", "items": []})
	eq([r.n, r.mode], [2, "nada"])
	eq(r.text, "Informe n.º 2, a la lista de correos de Charing Cross, a nombre de H.\nSin novedad.")

func test_final_report_modes():
	var st = _report_st({"day": 10, "phase": "final_report"})
	var s: Dictionary = Composers.report_status(st, rp)
	eq([s.due, s.n, s.final], [true, 4, true])
	eq(Composers.act_report_submit(st, rp, {"mode": "errata", "items": []}).err, "errata_no_ofrecida")
	st.flags["errata_ofrecida"] = "librero"
	var r: Dictionary = Composers.act_report_submit(st, rp, {"mode": "errata", "items": []})
	ok(r.ok, str(r))
	eq(st.flags.informe_final, "errata")
	ok(String(r.text).contains("El jueves a la noche va a estar en su ventana."))
	eq(st.pending_events[0].final, true)
	eq(st.pending_events[0].items, [])
	eq(st.scenes.final.mode, "errata")
	var st2 = _report_st({"day": 10, "phase": "final_report"})
	ok(Composers.act_report_submit(st2, rp, {"mode": "quemar", "items": []}).ok)
	eq(st2.flags.informe_final, "quemar")
	var st3 = _report_st({"day": 10, "phase": "final_report"})
	ok(Composers.act_report_submit(st3, rp, {"mode": "items", "items": [{"kind": "clip", "id": "RC1"}]}).ok)
	eq(st3.flags.informe_final, "items")
