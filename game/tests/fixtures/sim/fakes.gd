# Dobles de prueba (W2-SIM) para los manejadores de OTROS paquetes (W2-DED, W2-SCENES). Deterministas y mínimos:
# escriben en st.ded / st.scenes con un formato propio. Sólo para tests de la simulación (GameSim(..., handlers)).
# El juego nunca los usa. Semántica:
#   clip_text: texto del bloque (WorldModel.block) o de la línea/diario; tags "p:v" de los tramos que toca; ents de menciones.
#   (v3: el Expediente es real, sin dobles; clip_text además indexa sus entidades y anota el origen)
#   present: a "mycroft" = error (2.º error -> flags.forasteros_cerrada) [doble de HB12].
#   confront: pasos 1..4 en orden; item {} = callar; id que empieza con "ok" = acierto; 3 errores o paso 4 = done.
extends RefCounted

const WorldModel = preload("res://core/sim/world_model.gd")
const Diary = preload("res://core/sim/diary.gd")
const Markup = preload("res://core/text/markup.gd")

var calls := {}

func handlers() -> Dictionary:
	return {"clip_text": clip_text, "clip_plate": clip_plate, "ask": ask, "assert": assert_, "present": present, "pay": pay, "task": task,
		"compose_ad": compose_ad, "compose_telegram": compose_mail, "compose_letter": compose_mail, "report_submit": report_submit,
		"confront": confront, "_keep": self}   # _keep: los Callable no retienen al objeto RefCounted

func _count(t: String) -> void:
	calls[t] = int(calls.get(t, 0)) + 1

func _ded(st, k: String) -> Dictionary:
	if not st.ded.has(k):
		st.ded[k] = {}
	return st.ded[k]

# Estado propio de los dobles en st.scenes (prefijo _fake_: no choca con el init real de W2-SCENES).
func _sc(st, k: String) -> Dictionary:
	var key := "_fake_" + k
	if not st.scenes.has(key):
		st.scenes[key] = {}
	return st.scenes[key]

func _parsed_of(st, repo, src: Dictionary) -> Dictionary:
	match String(src.get("kind", "")):
		"doc":
			var b := WorldModel.block(st, repo, String(src.ref), src.get("part", 0), int(src.get("block", 0)))
			return b.get("parsed", {})
		"line":
			return WorldModel.line(st, repo, String(src.ref)).get("parsed", {})
		"diary":
			return Diary.get_line(st, repo, String(src.ref)).get("parsed", {})
	return {}

func clip_text(st, repo, a) -> Dictionary:
	_count("clip_text")
	var p := _parsed_of(st, repo, a.src)
	var plain := String(p.get("plain", ""))
	var f := int(a.from)
	var n := int(a.len)
	if n <= 0 or f < 0 or f + n > plain.length():
		return {"ok": false, "err": "vacio"}
	var tags: Array = []
	for t in p.get("tramos", []):
		if int(t.from) < f + n and int(t.to) > f:
			for pre in t.tags:
				for v in t.tags[pre]:
					tags.append(pre + ":" + String(v))
	var ents: Array = []
	for m in p.get("mentions", []):
		if int(m.from) < f + n and int(m.to) > f and not ents.has(String(m.ent)):
			ents.append(String(m.ent))
	var id: String = st.next_id("clip", "RC", 4)
	var ref := String(a.src.get("ref", ""))
	var origin := String(repo.copy(ref).get("doc", ref)) if not repo.copy(ref).is_empty() else ref
	_ded(st, "clips")[id] = {"id": id, "kind": "text", "text": plain.substr(f, n), "tags": tags, "ents": ents, "src": a.src.duplicate(true),
		"origin": origin}
	load("res://core/deduction/index.gd").add_entities(st, repo, ents)
	st.note("clip", {"id": id})
	return {"ok": true, "clip": id}

func clip_plate(st, repo, a) -> Dictionary:
	_count("clip_plate")
	if float(a.get("area_frac", 0.0)) > 0.125:
		return {"ok": false, "err": "rect_grande"}
	var id: String = st.next_id("clip", "RC", 4)
	_ded(st, "clips")[id] = {"id": id, "kind": "plate", "plate": String(a.plate), "tags": [], "ents": []}
	return {"ok": true, "clip": id}

func clip_measure(st, repo, a) -> Dictionary:
	_count("clip_measure")
	var id: String = st.next_id("clip", "RC", 4)
	_ded(st, "clips")[id] = {"id": id, "kind": "measure", "text": "Mide 203 por 244 milímetros.", "tags": [], "ents": []}
	return {"ok": true, "clip": id}

func link(st, repo, a) -> Dictionary:
	_count("link")
	var clips := _ded(st, "clips")
	if not clips.has(String(a.a)) or not clips.has(String(a.b)):
		return {"ok": false, "err": "no_existe"}
	var id: String = st.next_id("pair", "PR", 3)
	_ded(st, "pairs")[id] = {"a": String(a.a), "b": String(a.b), "note": String(a.get("note", ""))}
	return {"ok": true, "pair": id}

func unlink(st, repo, a) -> Dictionary:
	_count("unlink")
	var pairs := _ded(st, "pairs")
	if not pairs.has(String(a.pair)):
		return {"ok": false, "err": "no_existe"}
	pairs.erase(String(a.pair))
	return {"ok": true}

func folio_open(st, repo, a) -> Dictionary:
	_count("folio_open")
	if not _ded(st, "clips").has(String(a.clip)):
		return {"ok": false, "err": "no_existe"}
	var id: String = st.next_id("folio", "FO", 3)
	_ded(st, "folios")[id] = {"head_clip": String(a.clip)}
	return {"ok": true, "folio": id}

func entry_new(st, repo, a) -> Dictionary:
	_count("entry_new")
	var tpl: Dictionary = repo.template(String(a.template))
	if tpl.is_empty():
		return {"ok": false, "err": "plantilla"}
	var lines: Array = []
	for _l in tpl.get("lines", []):
		lines.append({"fields": {}, "support": []})
	var id: String = st.next_id("entry", "AS", 3)
	_ded(st, "entries")[id] = {"folio": String(a.folio), "template": String(a.template), "lines": lines, "ink": "lapiz"}
	return {"ok": true, "entry": id}

func entry_set(st, repo, a) -> Dictionary:
	_count("entry_set")
	var e = _ded(st, "entries").get(String(a.entry))
	if e == null or int(a.line) >= e.lines.size():
		return {"ok": false, "err": "no_existe"}
	if e.ink == "tinta":
		return {"ok": false, "err": "en_tinta"}
	e.lines[int(a.line)].fields[String(a.field)] = String(a.value)
	return {"ok": true}

func entry_support_add(st, repo, a) -> Dictionary:
	_count("entry_support_add")
	var e = _ded(st, "entries").get(String(a.entry))
	if e == null or int(a.line) >= e.lines.size():
		return {"ok": false, "err": "no_existe"}
	e.lines[int(a.line)].support.append(String(a.item))
	return {"ok": true}

func _supports(e: Dictionary) -> int:
	var n := 0
	for l in e.lines:
		n += (l.support as Array).size()
	return n

func practice(st, repo, a) -> Dictionary:
	_count("practice")
	var e = _ded(st, "entries").get(String(a.entry))
	if e == null:
		return {"ok": false, "err": "no_existe"}
	return {"ok": true, "inked": _supports(e) >= 2, "msg": "practica"}

func pass_clean(st, repo, a) -> Dictionary:
	_count("pass_clean")
	var lot := 1 if int(st.clock.day) == 10 else 2
	var ids: Array = a.entries
	if ids.size() != lot:
		return {"ok": false, "err": "lote"}
	var all_ok := true
	for id in ids:
		var e = _ded(st, "entries").get(String(id))
		if e == null:
			return {"ok": false, "err": "formal", "formal": [{"entry": String(id), "code": "falta_segun"}]}
		if _supports(e) < 2:
			all_ok = false
	var sealed: Array = []
	if all_ok:
		for id in ids:
			_ded(st, "entries")[String(id)].ink = "tinta"
			var cid := "C%d" % (_ded(st, "sealed").size() + 2)
			_ded(st, "sealed")[cid] = String(id)
			sealed.append(cid)
	if typeof(st.ded.get("passes")) != TYPE_ARRAY:
		st.ded["passes"] = []
	st.ded.passes.append({"inked": all_ok, "entries": ids.duplicate()})
	return {"ok": true, "inked": all_ok, "msg": "Visto." if all_ok else "Alguno no se sostiene.", "sealed": sealed}

func _say(st, repo, a, kind: String, phrase: String) -> Dictionary:
	st.push_event({"type": "say", "char": String(a.char), "kind": kind, "topic": String(a.get("topic", a.get("assertion", ""))),
		"assertion": String(a.get("assertion", "")), "phrase": phrase, "ents": []})
	return {"ok": true, "line": {"id": "gen.1", "who": String(a.char), "text": "Lo que imprimí, lo imprimí de buena fe."}}

func ask(st, repo, a) -> Dictionary:
	_count("ask")
	return _say(st, repo, a, "ask", "¿Qué sabe usted de eso, doctor?")

func assert_(st, repo, a) -> Dictionary:
	_count("assert")
	var phrase := ""
	for x in repo.lists().get("assertions", []):
		if String(x.id) == String(a.assertion):
			phrase = Markup.fill(String(x.phrase), {"addr": String(repo.dialogue(String(a.char)).get("addr", "señor"))})
	return _say(st, repo, a, "assert", phrase)

func present(st, repo, a) -> Dictionary:
	_count("present")
	st.push_event({"type": "show", "char": String(a.char), "item": {"kind": String(a.item.get("kind", "")), "doc_ids": [], "ents": ["fina"], "origins": [], "src_types": []}})
	# v3: una pregunta que no está en tinta es un error ante Mycroft (doble de HB12)
	if String(a.char) == "mycroft" and String(a.item.get("kind", "")) == "pregunta" and not _ded(st, "dossier").get("inked", {}).has(String(a.item.get("id", ""))):
		var m := _sc(st, "mycroft")
		m["errors"] = int(m.get("errors", 0)) + 1
		if int(m.errors) >= 2:
			st.flags["forasteros_cerrada"] = true
		return {"ok": true, "outcome": "error", "line": {"id": "error", "who": "mycroft", "text": "Otra vez, señor Lisle; no tengo toda la tarde."}}
	return {"ok": true, "outcome": "", "line": {"id": "gen.1", "who": String(a.char), "text": "Mira el papel largo rato."}}

func pay(st, repo, a) -> Dictionary:
	_count("pay")
	st.push_event({"type": "pay", "char": String(a.char), "amount_d": int(a.amount_d)})
	return {"ok": true, "line": {"id": "tarifa", "who": String(a.char), "text": "La vieja tarifa, jefe."}}

func task(st, repo, a) -> Dictionary:
	_count("task")
	st.push_event({"type": "task", "char": String(a.char), "task": String(a.task)})
	return {"ok": true, "line": {"id": "encargo", "who": String(a.char), "text": "Hecho, jefe."}}

func compose_ad(st, repo, a) -> Dictionary:
	_count("compose_ad")
	for f in repo.lists().get("ad_forms", []):
		if String(f.id) == String(a.form):
			var vars := {}
			for k in a.fields:
				var v := String(a.fields[k])
				var en: Dictionary = repo.entity(v)
				vars[k] = String(en.get("name", v))
				for x in repo.lists().get("assertions", []):
					if String(x.id) == v:
						vars[k] = String(x.get("ad_text", v))
			var n := int(st.seq.get("ad", 0)) + 1
			st.seq["ad"] = n
			return {"ok": true, "ad": "AD.%d" % n, "text": Markup.fill(String(f.text), vars)}
	return {"ok": false, "err": "forma"}

func compose_mail(st, repo, a) -> Dictionary:
	_count("compose_" + String(a.t))
	var parts := PackedStringArray()
	for p in a.get("parts", []):
		parts.append(String(p))
	var pre := "TG" if String(a.t) == "compose_telegram" else "LT"
	var n := int(st.seq.get(pre, 0)) + 1
	st.seq[pre] = n
	return {"ok": true, "id": "%s.%d" % [pre, n], "text": " ".join(parts).to_upper() if pre == "TG" else " ".join(parts)}

func report_submit(st, repo, a) -> Dictionary:
	_count("report_submit")
	var mode := String(a.mode)
	if not ["items", "nada", "quemar", "errata"].has(mode):
		return {"ok": false, "err": "forma"}
	if (a.get("items", []) as Array).size() > 3:
		return {"ok": false, "err": "forma"}
	var items: Array = []
	for it in a.get("items", []):
		items.append({"kind": String(it.get("kind", "")), "cats": [], "copies": [], "cls": []})
	var n := (_sc(st, "reports") as Dictionary).size() + 1
	_sc(st, "reports")[str(n)] = {"mode": mode}
	st.push_event({"type": "report", "n": n, "mode": mode, "items": items})
	return {"ok": true, "report": "RP.%d" % n}

func confront(st, repo, a) -> Dictionary:
	_count("confront")
	var c := _sc(st, "confront")
	var expected := int(c.get("step", 0)) + 1
	if bool(c.get("done", false)) or int(a.step) != expected:
		return {"ok": false, "err": "paso"}
	c["step"] = expected
	var hit := false
	if not (a.get("item", {}) as Dictionary).is_empty():
		hit = String(a.item.get("id", "")).begins_with("ok")
		if not hit:
			c["errors"] = int(c.get("errors", 0)) + 1
	c["done"] = expected >= 4 or int(c.get("errors", 0)) >= 3
	return {"ok": true, "hit": hit, "line": "", "errors": int(c.get("errors", 0)), "done": bool(c.done)}
