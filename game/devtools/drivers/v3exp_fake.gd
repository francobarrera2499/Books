# devtools/drivers/v3exp_fake.gd — doble del Expediente para probar la UI (UI-EXPEDIENTE; GDD_v3 §1.6–§1.7, §7.3: «las
# UI trabajan contra fixtures con sim_override»). Contesta lo del expediente con el contrato de CORE: q_dossier,
# q_answer_options, q_blue_pencil y las acciones dq_answer / dq_proof / dq_confirm (mismos resultados y errores que
# GDD_v3 §1.7). Lo que cierra lo decide el test: cada pregunta trae sus respuestas válidas y sus pares de recortes
# válidos (el validador real es de CORE: test_u_dossier, T36).
# Dos modos:
#   suelto  new(null, repo)      recortes, índice, reloj y lector propios (no carga core/sim: la UI se prueba aunque CORE
#                                esté a medio hacer)
#   sobre   new(game_sim)        envuelve una GameSim REAL (recortes inyectados con Clipper.inject en su estado; el
#                                cuaderno de la partida los ve); sólo el expediente es del doble.
# Uso:
#   var c1 = f.add_clip({"text": "…", "origin": "D03", "doc": "D03", "src_line": "…", "ents": ["reichenbach"]})
#   f.add_question({"id": "Q1", "text": "¿…?", "origin": "…", "doubts": [...], "acepta": [...], "ok_answers": [...],
#       "ok_pairs": [[c1, c2]], "ink_text": "…"})          (nace al agregarla; born:false = en espera)
#   f.options = [{"id", "label", "kind"}, …]   (q_answer_options; si no, el índice) · f.ink(qid, answer, [a, b]) ·
#   f.blue = [...] (q_blue_pencil) · f.attempts · f.acts_log
extends RefCounted

signal changed(kind: String, payload: Dictionary)

var base = null                # GameSim real (modo «sobre») o null
var repo
var st = null
var questions := {}            # qid -> def
var order: Array = []          # nacidas, en orden
var drafts := {}               # qid -> {answer, proofs:[a, b]}
var inked_q := {}              # qid -> orden de tinta
var attempts := {}
var options: Array = []        # opciones de respuesta (vacío = el índice del jugador)
var blue: Array = []
var acts_log: Array = []
var clock := {"phase": "desk", "day": 1, "slot": "M"}
var accessible: Array = [{"view": "D23@L1", "doc": "D23", "title": "Encargo", "holder": "L1", "via": "desk"}]
var flags := {}
var _clips := {}               # modo suelto: id -> recorte visible
var _seq := 0

func _init(p_base = null, p_repo = null) -> void:
	base = p_base
	if base != null:
		repo = base.repo
		st = base.st
		if base.has_signal("changed"):
			base.changed.connect(func(k, p): changed.emit(k, p))
	else:
		repo = p_repo

# ---------------------------------------------------------------- armado
func add_clip(c: Dictionary) -> String:
	var d := c.duplicate(true)
	if not d.has("kind"):
		d["kind"] = "text"
	if not d.has("src_type"):
		d["src_type"] = "cronica"
	if d.has("origin") and not d.has("copy"):
		d["copy"] = String(d.origin) + "@tomo"
	var id := ""
	if base != null:
		id = load("res://core/deduction/clipper.gd").inject(st, repo, d)
	else:
		_seq += 1
		id = "RC%04d" % _seq
		var ents: Array = []
		for e in d.get("ents", []):
			ents.append({"id": String(e), "label": _label(String(e))})
		var o := String(d.get("origin", ""))
		var doc := String(d.get("doc", ""))
		_clips[id] = {"id": id, "kind": String(d.kind), "text": String(d.get("text", "")), "ents": ents,
			"caption": String(d.get("caption", "")), "src_line": String(d.get("src_line", "")), "origin": o, "origins": [o],
			"chron_date": String(d.get("chron_date", "")), "place": "", "doc": doc, "doc_ids": [doc] if doc != "" else [],
			"src_type": String(d.src_type), "src_types": [String(d.src_type)], "copy": String(d.get("copy", "")), "who": "",
			"visible_cats": [], "mode": "normal"}
	changed.emit("clip", {"id": id})
	return id

func add_question(def: Dictionary) -> void:
	var qid := String(def.id)
	questions[qid] = def.duplicate(true)
	drafts[qid] = {"answer": "", "proofs": ["", ""]}
	if bool(def.get("born", true)):
		order.append(qid)
	changed.emit("dossier", {"q": qid})

func ink(qid: String, answer: String, proofs: Array) -> void:
	drafts[qid] = {"answer": answer, "proofs": [String(proofs[0]), String(proofs[1])]}
	inked_q[qid] = inked_q.size()
	changed.emit("dossier", {"q": qid})

# ---------------------------------------------------------------- consultas (contrato GDD_v3 §1.7)
func _label(id: String) -> String:
	for o in options:
		if String(o.get("id", "")) == id:
			return String(o.get("label", id))
	if base != null:
		for r in base.q_index():
			if String(r.get("id", "")) == id:
				return String(r.get("label", id))
	if repo != null:
		var e: Dictionary = repo.entity(id)
		if not e.is_empty():
			var n := String(e.get("name", id))
			return n.left(1).to_upper() + n.substr(1) if n != "" else id
	return id

func _sheet(qid: String) -> Dictionary:
	var def: Dictionary = questions[qid]
	var dr: Dictionary = drafts[qid]
	var a := String(dr.answer)
	var pr: Array = []
	for cid in dr.proofs:
		var c := q_clip(String(cid)) if String(cid) != "" else {}
		pr.append(c if not c.is_empty() else null)
	var inked := inked_q.has(qid)
	return {"id": qid, "text": String(def.get("text", qid)), "origin": String(def.get("origin", "")),
		"doubts": (def.get("doubts", []) as Array).duplicate(), "state": "tinta" if inked else "lapiz",
		"answer": {"id": a, "label": _label(a)} if a != "" else null, "proofs": pr, "formal": [] if inked else _formal(qid),
		"ink_text": String(def.get("ink_text", "")) if inked else "", "variant": "A" if inked else ""}

func open_ids() -> Array:
	var out: Array = []
	for qid in order:
		if not inked_q.has(qid) and out.size() < 3:
			out.append(qid)
	return out

func q_dossier() -> Dictionary:
	var open: Array = []
	for qid in open_ids():
		open.append(_sheet(qid))
	var ids := inked_q.keys()
	ids.sort_custom(func(a, b): return int(inked_q[a]) < int(inked_q[b]))
	var ink_list: Array = []
	for qid in ids:
		ink_list.append(_sheet(qid))
	return {"open": open, "inked": ink_list}

func q_answer_options(qid: String) -> Array:
	var acc: Array = questions.get(qid, {}).get("acepta", [])
	var out: Array = []
	if not options.is_empty():
		for o in options:
			if acc.is_empty() or acc.has(String(o.get("kind", ""))):
				out.append(o.duplicate())
	else:
		for r in q_index():
			if acc.is_empty() or acc.has(String(r.get("kind", ""))):
				out.append({"id": String(r.id), "label": String(r.get("label", r.id)), "kind": String(r.get("kind", ""))})
	out.sort_custom(func(a, b): return String(a.label).naturalnocasecmp_to(String(b.label)) < 0)
	return out

func q_blue_pencil() -> Array:
	return blue.duplicate(true)

func _formal(qid: String) -> Array:
	var dr: Dictionary = drafts[qid]
	var out: Array = []
	if String(dr.answer) == "":
		out.append("falta_respuesta")
	if String(dr.proofs[0]) == "" or String(dr.proofs[1]) == "":
		out.append("faltan_pruebas")
	else:
		var a: Dictionary = q_clip(String(dr.proofs[0]))
		var b: Dictionary = q_clip(String(dr.proofs[1]))
		if String(a.get("origin", "")) != "" and String(a.get("origin", "")) == String(b.get("origin", "")):
			out.append("mismo_papel")
	return out

# ---------------------------------------------------------------- acciones
func apply(a: Dictionary) -> Dictionary:
	var t := String(a.get("t", ""))
	if not t.begins_with("dq_"):
		return base.apply(a) if base != null else {"ok": false, "err": "accion"}
	acts_log.append(a.duplicate(true))
	var qid := String(a.get("q", ""))
	if inked_q.has(qid):
		return {"ok": false, "err": "en_tinta"}
	if not open_ids().has(qid):
		return {"ok": false, "err": "no_abierta"}
	var dr: Dictionary = drafts[qid]
	var r := {}
	match t:
		"dq_answer":
			var v := String(a.get("value", ""))
			if v != "" and not q_answer_options(qid).map(func(o): return String(o.id)).has(v):
				var known: Array = q_index().map(func(x): return String(x.id))
				var listed: bool = known.has(v) or options.map(func(o): return String(o.id)).has(v)
				return {"ok": false, "err": "fuera_de_lista" if listed else "no_indexado"}
			dr.answer = v
			r = {"ok": true}
		"dq_proof":
			var slot := int(a.get("slot", 0))
			var cid := String(a.get("clip", ""))
			if cid != "" and q_clip(cid).is_empty():
				return {"ok": false, "err": "no_existe"}
			if cid != "" and String(dr.proofs[1 - slot]) == cid:
				dr.proofs[1 - slot] = ""
			dr.proofs[slot] = cid
			r = {"ok": true}
		"dq_confirm":
			var f := _formal(qid)
			if not f.is_empty():
				return {"ok": false, "err": "formal", "formal": f}
			attempts[qid] = int(attempts.get(qid, 0)) + 1
			var def: Dictionary = questions[qid]
			var good: bool = (def.get("ok_answers", []) as Array).has(String(dr.answer))
			var pair_ok := false
			for pp in def.get("ok_pairs", []):
				var s1 := [String(pp[0]), String(pp[1])]
				if s1.has(String(dr.proofs[0])) and s1.has(String(dr.proofs[1])):
					pair_ok = true
			if good and pair_ok:
				var first := inked_q.is_empty()
				inked_q[qid] = inked_q.size()
				r = {"ok": true, "inked": true, "msg": "", "text": String(def.get("ink_text", "")), "first": first}
			else:
				r = {"ok": true, "inked": false, "msg": String(repo.text("exp.no_cierra")) if repo != null else "", "text": ""}
		_:
			return {"ok": false, "err": "accion"}
	changed.emit("dossier", {"q": qid})
	return r

# ---------------------------------------------------------------- lo demás (de la GameSim real, o propio en modo suelto)
func q_clips() -> Array:
	if base != null:
		return base.q_clips()
	var ids := _clips.keys()
	ids.sort()
	return ids.map(func(i): return (_clips[i] as Dictionary).duplicate(true))

func q_clip(id: String) -> Dictionary:
	if base != null:
		return base.q_clip(id)
	return (_clips.get(id, {}) as Dictionary).duplicate(true)

func q_index() -> Array:
	if base != null:
		return base.q_index()
	var out: Array = []
	var seen := {}
	for c in _clips.values():
		for e in c.ents:
			if not seen.has(String(e.id)):
				seen[String(e.id)] = true
				var k := String(repo.entity(String(e.id)).get("kind", "")) if repo != null else ""
				out.append({"id": String(e.id), "label": String(e.label), "kind": k, "index": String(e.label)})
	return out

func q_view(v: String) -> Dictionary: return base.q_view(v) if base != null else {}
func q_accessible() -> Array: return base.q_accessible() if base != null else accessible.duplicate(true)
func q_clock() -> Dictionary: return base.q_clock() if base != null else clock.duplicate()
func q_plate(id: String) -> Dictionary: return base.q_plate(id) if base != null else {}
func q_tutorial() -> Dictionary: return base.q_tutorial() if base != null else {"complete": true}
func q_diary() -> Array: return base.q_diary() if base != null else []
func q_marginalia() -> Array: return base.q_marginalia() if base != null else []
func q_read(v: String) -> Array: return base.q_read(v) if base != null else []
func q_known() -> Dictionary: return base.q_known() if base != null else {}
func q_scene() -> Dictionary: return base.q_scene() if base != null else {}

# Banderas reales (salvo las del expediente, que la UI calcula con este doble); en modo suelto, las de `flags`.
func q_ui() -> Dictionary:
	if base == null:
		return flags.duplicate()
	var f: Dictionary = base.q_ui().duplicate()
	for k in f.keys():
		if String(k).begins_with("exp."):
			f.erase(k)
	return f
