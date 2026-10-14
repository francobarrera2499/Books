# T15 (W2-REACT): Ley 2 (GDD§9.4) y reacciones garantizadas por acto (GDD§10.3).
#   Contadores por tema de cebo, globales entre canales: 1.ª y 2.ª verdaderas (remiten a una fuente), 3.ª falsa con
#   f:refutado, 4.ª en adelante silencio. Garantizadas (HA1, HA3, HB1 en su primer cebo publicado en la columna):
#   deterministas, sin condiciones extra (sólo de calendario), y nada las bloquea (ni HB9 ni HB11 ni cierres).
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Markup = preload("res://core/text/markup.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const CALENDAR_ATOMS := ["day", "weekday", "slot", "tk", "all", "any", "not", "always"]
const TOPICS := ["pared", "cayeron", "nota_falsa", "testamento", "mintio"]
const BLOCKING_FLAGS := {"watson_expuesto": true, "canal_cerrado.K-T": true, "canal_cerrado.K-BM": true, "canal_cerrado.K-S": true,
	"canal_cerrado.K-W": true, "canal_cerrado.K-H": true, "wiggins_quemado": true, "hudson_cerrada": true, "pell_despedido": true}

func after_each() -> void:
	H.cleanup()

func _repos() -> Dictionary:
	var out := {"fixture": fixture_repo("react/data")}
	var r = repo()
	if not r.reactions().is_empty() and not r.schedule().is_empty():
		out["data"] = r
	return out

func _ads(h, topic: String, days: Array) -> void:
	for d in days:
		h.ev("ad", {"ad": "AD.%d" % d, "form": "a_proposito", "text": "A propósito: %s. —E. L." % topic, "assertion": "as." + topic,
			"bait_topic": topic, "pub_day": d}, "%d.dawn" % d)

func _all(h, rid: String) -> Array:
	return h.find(rid) + h.queued(rid)

func _tags(text: String) -> Array:
	var out: Array = []
	for t in Markup.parse(text).tramos:
		for p in ["a", "f"]:
			for v in t.tags[p]:
				out.append(p + ":" + String(v))
	return out

func test_ley2_counts_per_topic():
	var reps := _repos()
	if not reps.has("data"):
		pending_content("data/reactions (W2-STRUCT)")
	for label in reps:
		var r = reps[label]
		for topic in TOPICS:
			var h = H.new(r)
			_ads(h, topic, [1, 2, 3, 4, 5])
			h.advance_to("10.night")
			var hb1 := _all(h, "HB1")
			var hb2 := _all(h, "HB2")
			eq(hb1.size(), 2, "%s %s: dos verdaderas" % [label, topic])
			eq(hb2.size(), 1, "%s %s: la tercera falsa" % [label, topic])
			eq(h.find("HB2b").size(), 0, "silencio: nunca instancia")
			eq(int(h.st.react.holmes.bait.get(topic, 0)), 5, "%s %s: contador" % [label, topic])
			for i in hb1:
				eq(_tags(String(i.get("text", ""))).has("f:refutado"), false, "%s %s: HB1 verdadera" % [label, topic])
				ne(String(i.get("text", "")), "", "%s %s: HB1 con texto" % [label, topic])
			for i in hb2:
				ok(_tags(String(i.get("text", ""))).has("f:refutado"), "%s %s: HB2 lleva f:refutado: %s" % [label, topic, i.get("text", "")])
			if hb1.size() == 2:
				ne(String(hb1[0].text), String(hb1[1].text), "%s %s: la 2.ª no repite la 1.ª" % [label, topic])

func test_ley2_global_across_channels():
	for label in _repos():
		var h = H.new(_repos()[label])
		h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, "1.M")
		_ads(h, "pared", [2])
		h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x"}, "2.T")
		h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.pared", "topic": "pared", "bait_topic": "pared", "phrase": "x", "ents": ["pared"]}, "3.M")
		h.advance_to("10.night")
		eq(_all(h, "HB1").size(), 2, label)
		eq(_all(h, "HB2").size(), 1, label)
		eq(String(_all(h, "HB2")[0].channel) if _all(h, "HB2").size() > 0 else "", "K-H", label + ": la falsa por el canal del 3.er cebo")

func test_guaranteed_are_calendar_only():
	for label in _repos():
		var r = _repos()[label]
		var gar: Array = []
		for rule in r.reactions():
			if String(rule.get("tipo", "")) == "garantizada_por_acto":
				gar.append(String(rule.id))
				var atoms: Array = []
				_atoms(rule.get("condiciones", {}), atoms)
				for a in atoms:
					ok(CALENDAR_ATOMS.has(a), "%s %s: condición extra «%s»" % [label, rule.id, a])
				# v3 (GDD_v3 §4.2): la única garantizada que corta es la intrusión por los techos (HA5): un original P
				# relacionado con el acto, un día, con variante blanda (D1). Ninguna otra garantizada corta.
				for c in RDB._as_arr(rule.get("corta", [])):
					ok(typeof(c) == TYPE_DICTIONARY and String(c.get("copias", "")) == "relacionada" and int(c.get("ventana", {}).get("dias", 0)) == 1,
						"%s %s: una garantizada sólo corta el original relacionado, un día: %s" % [label, rule.id, str(c)])
				if not RDB._as_arr(rule.get("corta", [])).is_empty():
					ok(typeof(rule.get("variante_blanda")) == TYPE_DICTIONARY, "%s %s: corta con variante blanda" % [label, rule.id])
		for want in ["HA1", "HA3"]:
			has(gar, want, label)
		var hb1: Dictionary = r.reaction("HB1")
		eq(String(hb1.get("garantizada_si", {}).get("canal", "")), "K-T", label + ": HB1 garantizada en la columna")
		eq(int(hb1.get("garantizada_si", {}).get("n", 0)), 1, label)

func _atoms(c, out: Array) -> void:
	if typeof(c) == TYPE_DICTIONARY:
		for k in c:
			out.append(String(k))
			if ["all", "any", "not"].has(String(k)):
				_atoms(c[k], out)
	elif typeof(c) == TYPE_ARRAY:
		for x in c:
			_atoms(x, out)

func _guaranteed_run(r, flags: Dictionary) -> Dictionary:
	var h = H.new(r, 13)
	for k in flags:
		h.st.flags[k] = flags[k]
	h.ev("slip", {"seat": 214, "doc": "D05", "title": "el Journal", "topic": "holmes_prensa_1891", "hour": "10:00"}, "1.M")
	_ads(h, "testamento", [2])
	h.ev("go", {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "10:00"}, "3.M")
	h.advance_to("10.night")
	var out := {}
	for rid in ["HA1", "HA3", "HB1"]:
		var f: Dictionary = h.first(rid)
		out[rid] = [TimeKey.label(int(f.get("delivered_tk", -1))), String(f.get("text", ""))]
	return out

func test_guaranteed_not_blockable_and_deterministic():
	for label in _repos():
		var r = _repos()[label]
		var free := _guaranteed_run(r, {})
		var blocked := _guaranteed_run(r, BLOCKING_FLAGS)
		for rid in ["HA1", "HA3", "HB1"]:
			ne(String(free[rid][0]), "?", "%s %s se entrega" % [label, rid])
			eq(blocked[rid], free[rid], "%s %s: no la bloquean HB9/HB11/cierres" % [label, rid])
		eq(_guaranteed_run(r, {}), free, label + ": determinista")
		eq(String(free.HA1[0]), "2.dawn", label + ": HA1 a la mañana siguiente")
		eq(String(free.HA3[0]), "4.dawn", label + ": HA3 a la mañana siguiente del primer go desde el día 3")
		eq(String(free.HB1[0]), "5.dawn", label + ": HB1 (publicado el 2) el día 5")

func test_optional_hb1_is_blockable():
	# Control: la segunda respuesta (no garantizada) sí calla tras watson_expuesto.
	var h = H.new(fixture_repo("react/data"))
	h.st.flags["watson_expuesto"] = true
	_ads(h, "pared", [1, 2])
	h.advance_to("10.night")
	eq(_all(h, "HB1").size(), 1, "sólo la garantizada")

# Hallazgo del playtest (sistemas, M4): sobre data/ real, un asiento T4 a lápiz sin «según» que nombra a Moran como
# redactor despide a Pell en el informe 1 sea cual sea el documento (El problema final o las cartas del coronel), y
# ninguno de los dos da crédito ante Moran (un lápiz sin fundamento no es un dato comprobable).
func test_m4_by_visible_fields_not_oracle():
	# v3 (GDD_v3 §6.10): una pregunta informada que nombra a Moran (Q6/Q7 en lápiz, sin pruebas) es moran_autor por lo que
	# DICE, cierre o no: M4 despide a Pell; ninguna da crédito ante Moran.
	var r = repo()
	if r.reactions().is_empty() or r.question("Q7").is_empty():
		skip("sin reacciones o sin dossier.json en data/")
		return
	var MoranAgent = load("res://core/react/moran_agent.gd")
	var outcome := {}
	for q in ["Q7", "Q6"]:
		var h = H.new(r, 3)
		h.st.ded = {"clips": {}, "dossier": {"born": {q: {"tk": 41, "via": "t", "origin": "", "n": 1}}, "open": {}, "waiting": [],
			"drafts": {q: {"answer": "moran", "proofs": ["", ""]}}, "inked": {}, "attempts": {}, "noticed": {}, "seen": {}, "shown_n": 1}}
		var item: Dictionary = MoranAgent.report_item(h.st, r, {"kind": "pregunta", "id": q})
		h.ev("report", {"n": 1, "mode": "items", "items": [item]}, "2.night")
		h.advance_to("4.M")
		outcome[q] = [bool(h.st.flags.get("pell_despedido", false)), bool(h.st.flags.get("moran_credito", false))]
		H.cleanup()
	eq(outcome["Q7"], [true, false], "¿Quién mató a Ronald Adair? · Moran: M4, sin crédito")
	eq(outcome["Q6"], [true, false], "¿Quién es mi cliente? · Moran: lo mismo (Moran no confirma respuestas)")
