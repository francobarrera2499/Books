# T04 (W2-DED, GDD§10.6): ningún recorte legal máximo cubre todos los grupos de una conclusión.
# Fuentes: cada parte de cada documento, líneas de escenas (y variantes, plantillas por canal), diálogos, rastros de
# reacciones (texto y nodos), plantillas del diario (la línea entera es un tramo), nodos de lugares y láminas (y sus
# variantes) y etiquetas de medida. Un recorte de texto hereda de UN tramo: se prueban los recortes legales máximos
# (ClipRules.max_legal_clips + inherit) y cada tramo que algún recorte legal cubre ≥50 %. Un recorte de lámina hereda
# las etiquetas de UN nodo (el de mayor cobertura, ajustado): «cada par de nodos» se reduce a cada nodo.
# Se excluyen las conclusiones de práctica (C1) y toda conclusión cuyos grupos llevan TODOS el mismo juego de etiquetas
# (degenerada: un recorte con esa etiqueta «cubre» todo por definición; la exigencia real es una etiqueta por línea y dos
# orígenes, condiciones 2 y 3). Hoy: C1.xx (inc_a/inc_b) y C10a de data (harris/moran = harris_es_moran). Se listan con
# degenerate(repo) para que el informe lo muestre.
extends "res://tests/test_base.gd"

const ClipRules = preload("res://core/text/clip_rules.gd")
const Validator = preload("res://core/deduction/validator.gd")

const CHS := ["kbm", "kw", "kh", "ks", "kt"]
const DUMMY := {"seat": "214", "title": "Título", "hour": "10:00", "phrase": "Frase", "streets": "Strand", "act_day": "1",
	"addr": "señor", "fecha": "Martes 27", "franja": "M", "lugar": "Lugar", "titulo": "Título", "frase": "Frase",
	"texto": "Texto", "que": "sobre", "quien": "Quien", "monto": "un chelín", "encargo": "encargo", "destino": "Bath",
	"n": "1", "resumen": "nada", "topic": "tema", "suceso": "suceso", "fuente": "fuente", "afirmacion": "afirmación"}

func test_fixture_ded_has_no_violations():
	var r = fixture_repo("ded")
	eq(r.errors(), [])
	var v := scan(r)
	eq(v, [], "fixture ded")

func test_detects_violations():
	var r = fixture_repo("ded_t4bad")
	eq(r.errors(), [])
	var v := scan(r)
	ok(v.size() >= 2, str(v))
	ok(str(v).contains("D97/p1"), "el tramo #todo de D97: " + str(v))
	ok(str(v).contains("N:L2.todo"), "el nodo L2.todo: " + str(v))
	no(str(v).contains("Primera oración"), "la oración sin tramo no cuenta")

func test_degenerate_conclusions_are_listed():
	var r = fixture_repo("ded")
	eq(degenerate(r), ["C1.01", "C1.10"], "práctica: inc_a/inc_b comparten etiqueta")

func test_real_data():
	var r = repo()
	if r.conclusions().is_empty():
		pending_content("data/conclusions.json (W2-STRUCT) todavía no existe")
		return
	var v := scan(r)
	for x in v:
		fail(x)

# ---------------- escaneo ----------------
static func degenerate(repo) -> Array:
	var out: Array = []
	for c in repo.conclusions():
		var sets := {}
		for g in c.get("groups", []):
			var ts: Array = g.get("tags", []).duplicate()
			ts.sort()
			sets[str(ts)] = true
		if c.get("groups", []).size() > 1 and sets.size() == 1:
			out.append(String(c.id))
	return out

static func scan(repo) -> Array:
	var cids: Array = []
	var deg := degenerate(repo)
	for c in repo.conclusions():
		if String(c.get("kind", "")) != "practica" and not c.get("groups", []).is_empty() and not deg.has(String(c.id)):
			cids.append(String(c.id))
	var out: Array = []
	if cids.is_empty():
		return out
	var dids: Array = repo.docs().keys()
	dids.sort()
	for did in dids:
		var d: Dictionary = repo.doc(did)
		for p in d.get("parts", []):
			if typeof(p) == TYPE_DICTIONARY:
				_scan_parsed(repo, cids, repo.parsed(did, String(p.id)), "%s/%s" % [did, p.id], out)
		if typeof(d.get("measure")) == TYPE_DICTIONARY:
			_check(repo, cids, _prefixed(d.measure.get("tags", [])), "M:%s" % did, out)
	var sids: Array = repo.scenes().keys()
	sids.sort()
	for sid in sids:
		var sc: Dictionary = repo.scene(sid)
		for ln in sc.get("lines", []):
			_scan_line(repo, cids, ln, "S:%s" % sid, out)
		for v in sc.get("variants", []):
			var rep = v.get("replace", {})
			if typeof(rep) == TYPE_DICTIONARY:
				for k in rep:
					_scan_text(repo, cids, String(rep[k]), "S:%s.%s(variante)" % [sid, k], out)
			for ln in v.get("append", []):
				_scan_line(repo, cids, ln, "S:%s" % sid, out)
		if typeof(sc.get("measure")) == TYPE_DICTIONARY:
			_check(repo, cids, _prefixed(sc.measure.get("tags", [])), "M:%s" % sid, out)
	var chars: Array = repo.dialogues().keys()
	chars.sort()
	for ch in chars:
		var dl: Dictionary = repo.dialogue(ch)
		for ln in dl.get("lines", []):
			_scan_text(repo, cids, String(ln.get("text", "")), "L:%s.%s" % [ch, ln.get("id", "?")], out)
		if dl.has("closing"):
			_scan_text(repo, cids, String(dl.closing), "L:%s.closing" % ch, out)
	for rx in repo.reactions():
		for ra in rx.get("rastro", []):
			var lb := "R:%s.%s" % [rx.get("id", "?"), ra.get("tpl", "?")]
			if ra.has("texto"):
				_scan_text(repo, cids, String(ra.texto), lb, out)
			if typeof(ra.get("tono")) == TYPE_DICTIONARY:
				for k in ra.tono:
					_scan_text(repo, cids, String(ra.tono[k]), "%s(%s)" % [lb, k], out)
			if ra.has("tags"):
				_check_variants(repo, cids, ra.tags, lb, out)
	var diary = repo.lists().get("diary", {})
	if typeof(diary) == TYPE_DICTIONARY:
		var dk: Array = diary.keys()
		dk.sort()
		for k in dk:
			if typeof(diary[k]) == TYPE_DICTIONARY:
				_check_variants(repo, cids, diary[k].get("tags", []), "J:%s" % k, out)
				_scan_text(repo, cids, String(diary[k].get("text", "")), "J:%s(texto)" % k, out)
	for src in [repo.places(), repo.plates()]:
		var pids: Array = src.keys()
		pids.sort()
		for pid in pids:
			var p: Dictionary = src[pid]
			var nodes: Array = []
			nodes.append_array(p.get("nodes", []))
			var vars = p.get("variants", {})
			if typeof(vars) == TYPE_DICTIONARY:
				for vk in vars:
					if typeof(vars[vk]) == TYPE_DICTIONARY:
						nodes.append_array(vars[vk].get("add_nodes", []))
			for n in nodes:
				if typeof(n) == TYPE_DICTIONARY:
					_check(repo, cids, _prefixed(n.get("tags", [])), "N:%s.%s" % [pid, n.get("id", "?")], out)
	return out

static func _scan_line(repo, cids: Array, ln, label: String, out: Array) -> void:
	if typeof(ln) != TYPE_DICTIONARY:
		return
	var lb := "%s.%s" % [label, ln.get("id", "?")]
	if ln.has("text"):
		_scan_text(repo, cids, String(ln.text), lb, out)
	if typeof(ln.get("tpl")) == TYPE_DICTIONARY:
		for k in ln.tpl:
			_scan_text(repo, cids, String(ln.tpl[k]), "%s_%s" % [lb, k], out)
	if ln.has("fallback"):
		_scan_text(repo, cids, String(ln.fallback), lb + "(fallback)", out)

static func _scan_text(repo, cids: Array, text: String, label: String, out: Array) -> void:
	if text == "":
		return
	for ch in (CHS if text.contains("${ch}") else [""]):
		var vars: Dictionary = DUMMY.duplicate()
		vars["ch"] = ch
		_scan_parsed(repo, cids, repo.parse_text(text, vars, "act.0"), label, out)

static func _scan_parsed(repo, cids: Array, parsed: Dictionary, label: String, out: Array) -> void:
	var clips: Array = ClipRules.max_legal_clips(parsed)
	for m in clips:
		var inh: Dictionary = ClipRules.inherit(parsed, m.from, m.to)
		_check(repo, cids, inh.tags, "%s@%d" % [label, m.from], out)
	for t in parsed.get("tramos", []):
		var tl: int = t.to - t.from
		for m in clips:
			var ov: int = mini(m.to, t.to) - maxi(m.from, t.from)
			if ov > 0 and ov * 2 >= tl:
				_check(repo, cids, _tramo_tags(t), "%s#%s" % [label, t.id], out)
				break

static func _tramo_tags(t: Dictionary) -> Array:
	var out: Array = []
	for pre in ClipRules.INHERIT:
		for v in t.tags.get(pre, []):
			out.append("%s:%s" % [pre, v])
	return out

static func _prefixed(tags: Array) -> Array:
	var out: Array = []
	for t in tags:
		var s := String(t)
		out.append(s if s.contains(":") else "a:" + s)
	return out

static func _check_variants(repo, cids: Array, tags: Array, label: String, out: Array) -> void:
	var joined := " ".join(tags.map(func(x): return String(x)))
	for ch in (CHS if joined.contains("${ch}") else [""]):
		var ts: Array = []
		for t in tags:
			ts.append(String(t).replace("${ch}", ch))
		_check(repo, cids, _prefixed(ts), label, out)

static func _check(repo, cids: Array, tags: Array, label: String, out: Array) -> void:
	if tags.is_empty():
		return
	for cid in cids:
		if Validator.covers_all_groups(repo, cid, tags):
			var msg := "%s: un recorte legal cubre todos los grupos de %s (%s)" % [label, cid, ", ".join(tags)]
			if not out.has(msg):
				out.append(msg)
