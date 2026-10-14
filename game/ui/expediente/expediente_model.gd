# ui/expediente/expediente_model.gd — vista-modelo del Expediente Holmes (pura: sin nodos, sólo lee la GameSim).
# Dueño: UI-EXPEDIENTE (GDD_v3 §1.6, §1.7, §6.1, §6.10). Todo lo que la carpeta y el lápiz azul muestran sale de aquí
# (testeable headless). Nunca muestra etiquetas ocultas, variantes, intentos ni nada que distinga lo importante: sólo lo
# que GameSim.q_dossier() entrega (texto, origen, dudas, borrador, tinta) y la forma (chequeo formal en voz de Lisle).
#   dossier(sim) -> {open:[H], inked:[H]}            (vacío si la partida no tiene expediente)
#   sheet(sim, qid) -> H | {}                         · ids(sim) -> [abiertas…, en tinta…]
#   full(H) -> bool                                   respuesta + dos pruebas (aparece «Pasar en limpio»)
#   can_pass(H, flags) -> bool                        full y en lápiz (y la bandera exp.pasar, si la partida la da)
#   answer_options(sim, qid) -> [{id, text}]          q_answer_options (índice del jugador por los tipos que acepta)
#   encargo_view(sim) -> String                       la vista del encargo (D23) si está a mano, o ""
#   formal_text(sim, code) · err_text(sim, code) · tx(sim, key, vars)
#   pencil(sim) -> {...}                              el expediente devuelto con el lápiz azul (post-créditos)
#   words(text) -> int · clip_words(clip) -> int      (ningún recorte mostrado pasa de 15 palabras)
# H = {id, text, origin, doubts:[], proof_labels:[r1, r2]|[], looked, state:"lapiz"|"tinta", answer:{id,label}|null,
#      proofs:[clip|null, clip|null], formal:[códigos], ink_text, variant} (GDD_v3 §1.7 q_dossier; proof_labels y looked:
#      playtest v3).
extends RefCounted

const UiFlags = preload("res://ui/kit/ui_flags.gd")

const MAX_OPEN := 3
const ENCARGO_DOC := "D23"
const ENCARGO_VIEW := "D23@L1"
const FORMAL_CODES := ["falta_respuesta", "faltan_pruebas", "mismo_papel"]

# ---------------------------------------------------------------- textos
static func repo_of(sim):
	if sim != null and "repo" in sim and sim.repo != null:
		return sim.repo
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null and ml.root.get_node_or_null("Data") != null:
		return ml.root.get_node("Data").repo()
	return null

static func tx(sim, key: String, vars := {}) -> String:
	var r = repo_of(sim)
	if r == null:
		return key
	return String(r.text(key, vars))

static func has_tx(sim, key: String) -> bool:
	var r = repo_of(sim)
	return r != null and r.texts().has(key)

# Primer texto que exista entre varias claves (las de este paquete primero; las de CORE como respaldo).
static func tx_any(sim, keys: Array, vars := {}) -> String:
	for k in keys:
		if has_tx(sim, String(k)):
			return tx(sim, String(k), vars)
	return ""

static func formal_text(sim, code: String) -> String:
	var s := tx_any(sim, ["exp.formal." + code, "v3core.formal." + code])
	return s if s != "" else tx(sim, "exp.formal.desconocido")

static func err_text(sim, code: String) -> String:
	if code == "":
		return ""
	var s := tx_any(sim, ["exp.err." + code, "v3core.err." + code, "sim.err." + code, "core.err." + code])
	return s if s != "" else tx_any(sim, ["core.err.desconocido"])

# ---------------------------------------------------------------- expediente
static func available(sim) -> bool:
	return sim != null and sim.has_method("q_dossier")

static func dossier(sim) -> Dictionary:
	if not available(sim):
		return {"open": [], "inked": []}
	var d = sim.q_dossier()
	if typeof(d) != TYPE_DICTIONARY:
		return {"open": [], "inked": []}
	var out := {"open": [], "inked": []}
	for k in ["open", "inked"]:
		var arr = d.get(k, [])
		if typeof(arr) == TYPE_ARRAY:
			for h in arr:
				if typeof(h) == TYPE_DICTIONARY and String(h.get("id", "")) != "":
					out[k].append(norm(h, k == "inked"))
	return out

# Normaliza una hoja (campos que falten, valores nulos) para que la vista no tenga que preguntar.
static func norm(h: Dictionary, inked := false) -> Dictionary:
	var o := h.duplicate(true)
	o["id"] = String(h.get("id", ""))
	o["text"] = String(h.get("text", ""))
	o["origin"] = String(h.get("origin", "")) if h.get("origin") != null else ""
	var dd: Array = []
	var src = h.get("doubts", [])
	if typeof(src) == TYPE_ARRAY:
		for x in src:
			if String(x) != "":
				dd.append(String(x))
	o["doubts"] = dd.slice(0, 3)
	# rótulo de cada ranura de prueba (playtest v3: qué mitad muestra cada una); [] si la pregunta no los trae
	var pl: Array = []
	var pls = h.get("proof_labels", [])
	if typeof(pls) == TYPE_ARRAY and pls.size() >= 2:
		pl = [String(pls[0]), String(pls[1])]
	o["proof_labels"] = pl
	o["looked"] = bool(h.get("looked", true))
	var state := String(h.get("state", "tinta" if inked else "lapiz"))
	o["state"] = "tinta" if state == "tinta" or inked else "lapiz"
	var a = h.get("answer", null)
	o["answer"] = a if typeof(a) == TYPE_DICTIONARY and String(a.get("id", "")) != "" else null
	var pr: Array = [null, null]
	var ps = h.get("proofs", [])
	if typeof(ps) == TYPE_ARRAY:
		for i in mini(2, ps.size()):
			if typeof(ps[i]) == TYPE_DICTIONARY and String(ps[i].get("id", "")) != "":
				pr[i] = ps[i]
	o["proofs"] = pr
	var fm: Array = []
	var fs = h.get("formal", [])
	if typeof(fs) == TYPE_ARRAY:
		for c in fs:
			var code := String(c.get("code", "")) if typeof(c) == TYPE_DICTIONARY else String(c)
			if code != "":
				fm.append(code)
	o["formal"] = fm
	o["ink_text"] = String(h.get("ink_text", "")) if h.get("ink_text") != null else ""
	o["variant"] = String(h.get("variant", "")) if h.get("variant") != null else ""
	return o

static func ids(sim) -> Array:
	var d := dossier(sim)
	var out: Array = []
	for k in ["open", "inked"]:
		for h in d[k]:
			out.append(String(h.id))
	return out

static func open_ids(sim) -> Array:
	return dossier(sim).open.map(func(h): return String(h.id))

static func inked_ids(sim) -> Array:
	return dossier(sim).inked.map(func(h): return String(h.id))

static func sheet(sim, qid: String) -> Dictionary:
	var d := dossier(sim)
	for k in ["open", "inked"]:
		for h in d[k]:
			if String(h.id) == qid:
				return h
	return {}

static func is_inked(h: Dictionary) -> bool:
	return String(h.get("state", "")) == "tinta"

static func full(h: Dictionary) -> bool:
	if h.is_empty() or h.get("answer") == null:
		return false
	var p: Array = h.get("proofs", [])
	return p.size() >= 2 and p[0] != null and p[1] != null

static func empty_draft(h: Dictionary) -> bool:
	if h.is_empty():
		return true
	var p: Array = h.get("proofs", [null, null])
	return h.get("answer") == null and (p.size() < 1 or p[0] == null) and (p.size() < 2 or p[1] == null)

# «Pasar en limpio» se ve con las tres ranuras llenas (GDD_v3 §6.1); si la partida da la bandera exp.pasar (q_ui), se
# respeta: bool para todas, o {qid: bool} por hoja.
static func can_pass(h: Dictionary, flags := {}) -> bool:
	if h.is_empty() or is_inked(h) or not full(h):
		return false
	if flags.has("exp.pasar"):
		var f = flags["exp.pasar"]
		if typeof(f) == TYPE_BOOL:
			return f
		if typeof(f) == TYPE_DICTIONARY:
			return bool(f.get(String(h.id), true))
	return true

# Mensaje de forma junto a las pruebas: sólo «mismo papel» se dice antes de intentar (las otras dos son evidentes a la
# vista: la ranura vacía). Nunca contenido.
static func live_formal(h: Dictionary) -> Array:
	var out: Array = []
	for c in h.get("formal", []):
		if String(c) == "mismo_papel":
			out.append("mismo_papel")
	return out

# ---------------------------------------------------------------- respuesta
static func answer_label(h: Dictionary) -> String:
	var a = h.get("answer")
	if typeof(a) != TYPE_DICTIONARY:
		return ""
	var lb := String(a.get("label", ""))
	return lb if lb != "" else String(a.get("id", ""))

static func answer_options(sim, qid: String) -> Array:
	if sim == null or not sim.has_method("q_answer_options"):
		return []
	var out: Array = []
	var arr = sim.q_answer_options(qid)
	if typeof(arr) != TYPE_ARRAY:
		return out
	for o in arr:
		if typeof(o) != TYPE_DICTIONARY or String(o.get("id", "")) == "":
			continue
		var lb := String(o.get("label", o.get("id", "")))
		out.append({"id": String(o.id), "text": lb, "kind": String(o.get("kind", ""))})
	return out

# ---------------------------------------------------------------- recortes
static func words(text: String) -> int:
	return text.strip_edges().split(" ", false).size()

static func clip_text(c: Dictionary) -> String:
	if c.is_empty():
		return ""
	var t := String(c.get("text", ""))
	if t == "" or String(c.get("kind", "text")) == "plate":
		t = String(c.get("caption", t))
	return t

static func clip_words(c: Dictionary) -> int:
	return words(clip_text(c))

# ---------------------------------------------------------------- el encargo
static func encargo_view(sim) -> String:
	if sim == null or not sim.has_method("q_accessible"):
		return ""
	var acc = sim.q_accessible()
	if typeof(acc) != TYPE_ARRAY:
		return ""
	for a in acc:
		if typeof(a) == TYPE_DICTIONARY and String(a.get("doc", "")) == ENCARGO_DOC:
			return String(a.get("view", ""))
	for a in acc:
		if typeof(a) == TYPE_DICTIONARY and String(a.get("view", "")) == ENCARGO_VIEW:
			return ENCARGO_VIEW
	return ""

# ---------------------------------------------------------------- lápiz azul (post-créditos, GDD_v3 §6.10)
# {title, header, rows:[{q, text, state, answer, ink_text, proofs:[texto], wrong, missing, notes:[nota], note}],
#  extra:[notas sin pregunta], nothing, nada, sign, empty}. Las notas azules salen de q_blue_pencil (CORE: {kind:
#  "missing"|"wrong", q|cid, note}; una hoja completa que no cierra trae las dos); una nota sin pregunta conocida va al
#  pie.
static func pencil(sim) -> Dictionary:
	var bp: Array = []
	if sim != null and sim.has_method("q_blue_pencil"):
		var x = sim.q_blue_pencil()
		if typeof(x) == TYPE_ARRAY:
			bp = x
	var notes := {}
	var extra: Array = []
	var d := dossier(sim)
	var known := {}
	for k in ["inked", "open"]:
		for h in d[k]:
			known[String(h.id)] = true
	for it in bp:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var q := String(it.get("q", it.get("qid", it.get("cid", it.get("id", "")))))
		var kind := String(it.get("kind", ""))
		var note := String(it.get("note", ""))
		if note == "":
			continue
		if q != "" and known.has(q):
			if not notes.has(q):
				notes[q] = []
			notes[q].append({"kind": kind, "note": note})
		elif not extra.has(note):
			extra.append(note)
	var rows: Array = []
	for k in ["inked", "open"]:
		for h in d[k]:
			var qid := String(h.id)
			var pr: Array = []
			for c in h.proofs:
				if c != null:
					pr.append(clip_text(c))
			var ns: Array = notes.get(qid, [])
			var texts: Array = []
			var wrong := false
			var miss := false
			for n in ns:
				wrong = wrong or String(n.kind) == "wrong"
				miss = miss or String(n.kind) == "missing"
				if not texts.has(String(n.note)):
					texts.append(String(n.note))
			rows.append({"q": qid, "text": String(h.text), "state": String(h.state), "answer": answer_label(h),
				"ink_text": String(h.ink_text), "proofs": pr, "wrong": wrong, "missing": miss, "notes": texts,
				"note": String(texts[0]) if not texts.is_empty() else ""})
	var nothing := bp.is_empty()
	return {"title": tx(sim, "epilogo.lapiz.titulo"), "header": tx_any(sim, ["exp.lapiz.encabezado", "epilogo.lapiz.encabezado"]), "rows": rows,
		"extra": extra, "nothing": nothing, "nada": tx(sim, "epilogo.lapiz.nada"),
		"sign": tx(sim, "epilogo.lapiz.firma_tirese" if nothing else "epilogo.lapiz.firma_corrijase"),
		"empty": tx(sim, "exp.lapiz.sin_preguntas"), "wrong_n": rows.filter(func(r): return bool(r.wrong)).size()}

# Resumen en lápiz de una hoja (lápiz azul y confirmaciones): «Respuesta: X · «prueba 1» · «prueba 2»».
static func draft_summary(sim, row: Dictionary) -> String:
	var parts: Array = []
	if String(row.get("answer", "")) != "":
		parts.append("%s %s" % [tx(sim, "exp.respuesta.rotulo"), String(row.answer)])
	for p in row.get("proofs", []):
		parts.append("«%s»" % String(p))
	return " · ".join(PackedStringArray(parts))

static func flags_of(sim) -> Dictionary:
	return UiFlags.of(sim)
