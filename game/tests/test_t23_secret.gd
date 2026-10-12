# T23 (W2-REACT): el secreto de Holmes (GDD§2.4, §3.3, §9.4 Ley 5). Nada público (columna del Times, noticias) lleva
# afirma_que_vive; nada público cita lo que Lisle dijo a Watson (K-W) ni a Mrs. Hudson (se contesta en privado); ninguna
# frase pública traduce «not literally true».
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Markup = preload("res://core/text/markup.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const PUBLIC_OPS := ["columna", "noticia"]
const LITERAL := ["literalmente", "literally", "al pie de la letra", "en sentido literal", "a la letra"]

func after_each() -> void:
	H.cleanup()

func _reps() -> Dictionary:
	var out := {"fixture": fixture_repo("react/data")}
	if not repo().reactions().is_empty():
		out["data"] = repo()
	return out

static func public_texts(rule: Dictionary) -> Array:
	var pub := false
	for e in RDB.effects_of(rule, false) + RDB.effects_of(rule, true):
		if typeof(e) == TYPE_DICTIONARY and PUBLIC_OPS.has(String(e.get("op", ""))):
			pub = true
	if not pub:
		return []
	var out: Array = []
	for rs in RDB._as_arr(rule.get("rastro", [])):
		if typeof(rs) != TYPE_DICTIONARY:
			continue
		if rs.has("texto"):
			out.append(String(rs.texto))
		if typeof(rs.get("tono")) == TYPE_DICTIONARY:
			for k in rs.tono:
				out.append(String(rs.tono[k]))
	return out

static func text_violations(text: String) -> Array:
	var out: Array = []
	var p := Markup.parse(Markup.fill(text, {"ch": "kt", "seat": "1", "phrase": "x", "text": "x"}))
	for t in p.tramos:
		if t.tags.f.has("afirma_que_vive"):
			out.append("afirma_que_vive")
		if t.tags.f.has("privado_kw"):
			out.append("privado_kw")
	var low := String(p.plain).to_lower()
	for w in LITERAL:
		if low.contains(w):
			out.append("«%s»" % w)
	return out

func test_static_public_rastros():
	if not _reps().has("data"):
		pending_content("data/reactions (W2-STRUCT)")
	for label in _reps():
		var r = _reps()[label]
		var n := 0
		for rule in r.reactions():
			for tx in public_texts(rule):
				n += 1
				for v in text_violations(tx):
					fail("%s %s: texto público con %s: %s" % [label, rule.id, v, tx.left(120)])
			if not public_texts(rule).is_empty():
				ne(String(rule.get("canal", "")), "K-W", "%s %s: lo público nunca es del canal de Watson" % [label, rule.id])
		ok(n >= 3, "%s: hay textos públicos que revisar (%d)" % [label, n])

func test_private_acts_never_answered_in_public():
	for label in _reps():
		var r = _reps()[label]
		var h = H.new(r)
		for d in [1, 2, 3, 4, 5]:
			var tk := "%d.M" % d
			for topic in ["pared", "cayeron", "nota_falsa", "testamento", "mintio"]:
				h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as." + topic, "topic": topic, "bait_topic": topic, "phrase": "x", "ents": [topic]}, tk)
			h.ev("say", {"char": "mrs_hudson", "kind": "assert", "assertion": "as.vive", "topic": "vive", "phrase": "Holmes vive, sir."}, "%d.T" % d)
			h.ev("say", {"char": "watson", "kind": "assert", "assertion": "as.vive", "topic": "vive", "phrase": "Holmes vive, doctor.", "ents": ["holmes"]}, "%d.T" % d)
		h.advance_to("10.night")
		var priv := 0
		for i in h.delivered():
			var how := String(i.get("how", ""))
			var ch := String(i.get("channel", ""))
			if ch == "K-W" or ch == "K-H" or bool(i.anchor.get("privado_kw", false)):
				priv += 1
				ok(how != "columna" and how != "noticias", "%s %s (%s): contesta en privado, no en %s" % [label, i.iid, ch, how])
			if how == "columna" or how == "noticias":
				eq(text_violations(String(i.get("text", ""))), [], "%s %s" % [label, i.iid])
				no(bool(i.anchor.get("privado_kw", false)), "%s %s: la columna no cita K-W" % [label, i.iid])
		ok(priv > 3, "%s: hubo respuestas privadas (%d)" % [label, priv])

func test_says_alive_ad_answer_is_not_an_assertion():
	for label in _reps():
		var h = H.new(_reps()[label])
		h.ev("ad", {"ad": "AD.2", "form": "a_proposito", "text": "A propósito de El problema final: Holmes vive. —E. L.", "assertion": "as.vive",
			"says_alive": true, "pub_day": 2}, "2.dawn")
		h.advance_to("10.night")
		var hb7: Dictionary = h.first("HB7")
		ok(not hb7.is_empty(), label + ": HB7 contesta en la columna")
		eq(String(hb7.get("how", "")), "columna", label)
		eq(text_violations(String(hb7.get("text", ""))), [], label)

func test_detector_negative():
	ok(text_violations("{{#x f:afirma_que_vive|Vive.}}").has("afirma_que_vive"))
	ok(not text_violations("Eso no es literalmente cierto.").is_empty())
	eq(text_violations("AL LECTOR. — Hubo tres guías. —S."), [])
