# ui/ledger/ledger_model.gd — vista-modelo del libro mayor (pura: sin nodos, sólo lee la GameSim). Dueño: W3-LEDGER.
# Contrato: ARCHITECTURE §6.6, §3.7 (q_ledger, q_entry, q_templates, q_lists, q_index, q_clip, q_pairs, q_clock), GDD§8.
# Todo lo que la UI muestra del libro sale de aquí (testeable sin ventana): páginas, renglones de asiento, rótulos
# «Campo: ___», opciones de cada campo (índice filtrado por los tipos que acepta la plantilla —forma, no contenido— o
# su lista cerrada), tarjetas de recortes/pares, notas del chequeo formal por línea, estado del sello y del lote.
# Nunca muestra etiquetas ocultas ni la conclusión de un asiento (entry.cid no se usa).
# `sim` = GameSim (sim.repo = DataRepo). Textos: ui_text (ledger.*, rules.*, formal.*, pass.*, practice.*, entry.*).
extends RefCounted

const Tutorial = preload("res://core/sim/tutorial.gd")

const PAGE_RULES := "reglas"
const PAGE_VARIOS := "varios"
const PAGE_ERRATAS := "erratas"
const STAMP_PHASES := ["desk", "final_report"]
const AWAY_PHASES := ["visit", "scene", "parklane", "confront"]

# ---------------------------------------------------------------- textos
static func tx(sim, key: String, vars := {}) -> String:
	var repo = sim.repo if sim != null else null
	if repo == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree and ml.root != null and ml.root.get_node_or_null("Data") != null:
			repo = ml.root.get_node("Data").repo()
	if repo == null:
		return key
	return String(repo.text(key, vars))

static func has_text(sim, key: String) -> bool:
	return sim != null and sim.repo != null and sim.repo.texts().has(key)

# "AS005" -> 5 · "FO012" -> 12
static func num_of(id: String) -> int:
	var digits := ""
	for i in id.length():
		var c := id[i]
		if c >= "0" and c <= "9":
			digits += c
	return digits.to_int() if digits != "" else 0

# ---------------------------------------------------------------- plantillas
static func templates(sim) -> Array:
	var all: Dictionary = sim.q_templates()
	var ids: Array = all.keys()
	ids.sort_custom(func(a, b): return num_of(String(a)) < num_of(String(b)))
	var out: Array = []
	for tid in ids:
		var t: Dictionary = all[tid]
		out.append({"id": String(tid), "name": String(t.get("name", tid)), "shape": template_shape(t)})
	return out

static func template(sim, tid: String) -> Dictionary:
	return sim.q_templates().get(tid, {})

# "Persona: ___" -> "Persona:" (el rótulo conserva el artículo y los dos puntos, GDD§8.4)
static func field_label(label: String) -> String:
	return label.replace("___", "").strip_edges()

static func _bare(label: String) -> String:
	var s := field_label(label)
	return s.trim_suffix(":").strip_edges()

# «Persona · Hizo · Qué o a quién / (A o contra) / (Con)…»: la forma de la plantilla, sin contenido.
static func template_shape(t: Dictionary) -> String:
	var parts: Array = []
	for ln in t.get("lines", []):
		var fs: Array = []
		for f in ln.get("fields", []):
			fs.append(_bare(String(f.get("label", f.get("id", "")))))
		var s := " · ".join(PackedStringArray(fs))
		if bool(ln.get("optional", false)):
			s = "(" + s + ")"
		parts.append(s)
	return " / ".join(PackedStringArray(parts))

# ---------------------------------------------------------------- etiquetas de valores
static func ent_name(sim, id: String) -> String:
	if id.begins_with("act."):
		return index_label(sim, id)
	var e: Dictionary = sim.repo.entity(id)
	if e.is_empty():
		return id
	var n := String(e.get("name", ""))
	return n if n != "" else String(e.get("index", id))

static func index_label(sim, id: String) -> String:
	for r in sim.q_index():
		if String(r.get("id", "")) == id:
			return String(r.get("label", id))
	var e: Dictionary = sim.repo.entity(id)
	return String(e.get("index", e.get("name", id))) if not e.is_empty() else id

static func list_items(sim, name: String) -> Array:
	var l = sim.repo.lists().get(name, [])
	return l if typeof(l) == TYPE_ARRAY else []

# Valor de un campo tal como se lee en el libro: lista -> su rótulo («separarse de», «la Sala de Lectura»);
# entidad -> su nombre («el doctor Watson»).
static func value_text(sim, accept: Dictionary, v: String) -> String:
	if v == "":
		return ""
	if accept.has("list"):
		for x in list_items(sim, String(accept.list)):
			if typeof(x) == TYPE_DICTIONARY:
				if String(x.get("id", "")) == v:
					return String(x.get("label", v))
				if (x.get("entities", []) as Array).has(v):
					return ent_name(sim, v)
			elif String(x) == v:
				return v.replace("_", " ")
		return v.replace("_", " ")
	return ent_name(sim, v)

# Opciones de un campo: la lista cerrada (medios: también sus vigías ya indexados) o las entidades del índice cuyo tipo
# acepta la plantilla. [{id, text, sub, clear?}]. El primer renglón «Dejar en blanco» sólo si el campo tiene valor.
static func field_options(sim, accept: Dictionary, current := "") -> Array:
	var out: Array = []
	if current != "":
		out.append({"id": "", "text": tx(sim, "ledger.picker.borrar"), "sub": "", "clear": true})
	if accept.has("list"):
		var ents: Array = []
		var idx := {}
		for r in sim.q_index():
			idx[String(r.get("id", ""))] = String(r.get("label", ""))
		for x in list_items(sim, String(accept.list)):
			if typeof(x) == TYPE_DICTIONARY:
				out.append({"id": String(x.get("id", "")), "text": String(x.get("label", x.get("id", ""))), "sub": ""})
				for e in x.get("entities", []):
					if idx.has(String(e)):
						ents.append({"id": String(e), "text": String(idx[String(e)]), "sub": String(x.get("label", ""))})
			else:
				out.append({"id": String(x), "text": String(x).replace("_", " "), "sub": ""})
		out.append_array(ents)
		return out
	var kinds: Array = accept.get("kinds", [])
	for r in sim.q_index():
		if kinds.is_empty() or kinds.has(String(r.get("kind", ""))):
			out.append({"id": String(r.id), "text": String(r.get("label", r.id)), "sub": ""})
	return out

# ---------------------------------------------------------------- recortes y pares
static func _clip_text(v: Dictionary) -> String:
	var t := String(v.get("text", "")).strip_edges()
	if t == "":
		t = String(v.get("caption", "")).strip_edges()
	return t

# Tarjeta de un ítem de «según» (recorte o par): {id, kind, text, sub, missing}
static func card(sim, id: String) -> Dictionary:
	var v: Dictionary = sim.q_clip(id)
	if not v.is_empty():
		return {"id": id, "kind": "clip", "text": _clip_text(v), "sub": String(v.get("src_line", "")), "missing": false}
	for p in sim.q_pairs():
		if String(p.get("id", "")) == id:
			var a: Dictionary = sim.q_clip(String(p.get("a", "")))
			var b: Dictionary = sim.q_clip(String(p.get("b", "")))
			var note := String(p.get("note", "")).strip_edges()
			return {"id": id, "kind": "pair", "text": "%s / %s" % [short(_clip_text(a), 48), short(_clip_text(b), 48)],
				"sub": (tx(sim, "ledger.par") + (": " + note if note != "" else "")), "missing": a.is_empty() or b.is_empty()}
	return {"id": id, "kind": "clip", "text": id, "sub": "", "missing": true}

static func short(s: String, n: int) -> String:
	s = s.strip_edges()
	if s.length() <= n:
		return s
	var cut := s.left(n - 1)
	var sp := cut.rfind(" ")
	if sp > n * 0.6:
		cut = cut.left(sp)
	return cut.strip_edges().trim_suffix(",").trim_suffix(";") + "…"

# Recortes (más nuevos primero) y luego pares, para elegir el «según» o el encabezado de un folio.
static func support_options(sim, exclude: Array = [], with_pairs := true) -> Array:
	var out: Array = []
	var clips: Array = sim.q_clips()
	for i in range(clips.size() - 1, -1, -1):
		var v: Dictionary = clips[i]
		var id := String(v.get("id", ""))
		if exclude.has(id):
			continue
		out.append({"id": id, "kind": "clip", "text": _clip_text(v), "sub": String(v.get("src_line", ""))})
	if with_pairs:
		var pairs: Array = sim.q_pairs()
		for i in range(pairs.size() - 1, -1, -1):
			var id2 := String(pairs[i].get("id", ""))
			if exclude.has(id2):
				continue
			var c := card(sim, id2)
			out.append({"id": id2, "kind": "pair", "text": c.text, "sub": c.sub})
	return out

# ---------------------------------------------------------------- páginas
static func pages(sim) -> Array:
	var out: Array = [{"id": PAGE_RULES, "kind": "rules", "tab": tx(sim, "ledger.tab.reglas"), "title": tx(sim, "rules.title")}]
	if sim == null:
		return out
	var q: Dictionary = sim.q_ledger()
	out.append({"id": PAGE_VARIOS, "kind": "varios", "tab": tx(sim, "ledger.tab.varios"), "title": tx(sim, "ledger.tab.varios"),
		"sub": tx(sim, "ledger.varios.sub")})
	for fo in q.get("folios", []):
		var fid := String(fo.get("id", ""))
		var n := num_of(fid)
		var head := card(sim, String(fo.get("head_clip", "")))
		out.append({"id": fid, "kind": "folio", "n": n, "tab": tx(sim, "ledger.tab.folio", {"n": n}), "title": tx(sim, "ledger.folio", {"n": n}),
			"head": head, "head_short": short(String(head.text), 30)})
	out.append({"id": PAGE_ERRATAS, "kind": "erratas", "tab": tx(sim, "ledger.tab.erratas"), "title": tx(sim, "ledger.tab.erratas"),
		"sub": tx(sim, "ledger.erratas.sub")})
	return out

static func page_info(sim, pid: String) -> Dictionary:
	for p in pages(sim):
		if String(p.id) == pid:
			return p
	return {}

static func page_entries(sim, pid: String) -> Array:
	if sim == null:
		return []
	var q: Dictionary = sim.q_ledger()
	if pid == PAGE_VARIOS:
		return (q.get("varios", []) as Array).duplicate()
	if pid == PAGE_ERRATAS:
		return (q.get("erratas", []) as Array).duplicate()
	for fo in q.get("folios", []):
		if String(fo.get("id", "")) == pid:
			return (fo.get("entries", []) as Array).duplicate()
	return []

static func page_of_entry(sim, eid: String) -> String:
	var e: Dictionary = sim.q_entry(eid)
	var f := String(e.get("folio", ""))
	return f if f != "" else PAGE_VARIOS

static func rules(sim) -> Array:
	var out: Array = []
	for k in range(1, 7):
		out.append(tx(sim, "rules.%d" % k))
	return out

static func how_to(sim) -> Array:
	var out: Array = []
	for k in range(1, 5):
		out.append(tx(sim, "ledger.modo.%d" % k))
	return out

# ---------------------------------------------------------------- asientos
static func entry_vm(sim, eid: String) -> Dictionary:
	var e: Dictionary = sim.q_entry(eid)
	if e.is_empty():
		return {}
	var tid := String(e.get("template", ""))
	var tpl := template(sim, tid)
	var tlines: Array = tpl.get("lines", [])
	var elines: Array = e.get("lines", [])
	var lines: Array = []
	var started := false
	for i in tlines.size():
		var tl: Dictionary = tlines[i]
		var el: Dictionary = elines[i] if i < elines.size() else {"fields": {}, "support": []}
		var vals: Dictionary = el.get("fields", {})
		var fields: Array = []
		var filled := false
		for f in tl.get("fields", []):
			var fid := String(f.get("id", ""))
			var v := String(vals.get(fid, ""))
			var acc: Dictionary = f.get("accept", {})
			if v != "":
				filled = true
			fields.append({"id": fid, "label": field_label(String(f.get("label", fid))), "value": v, "text": value_text(sim, acc, v),
				"accept": acc})
		var sup: Array = []
		var valid := 0
		for it in el.get("support", []):
			var c := card(sim, String(it))
			if not c.missing:
				valid += 1
			sup.append(c)
		if filled or not sup.is_empty():
			started = true
		lines.append({"i": i, "optional": bool(tl.get("optional", false)), "fields": fields, "support": sup, "filled": filled,
			"falta_segun": filled and valid == 0})
	var formal: Array = e.get("formal", [])
	var notes: Array = []
	if started:
		for code in formal:
			if String(code) != "falta_segun":
				notes.append(String(code))
	var ink := String(e.get("ink", "lapiz"))
	return {"id": eid, "n": num_of(eid), "template": tid, "tname": String(tpl.get("name", tid)), "ink": ink,
		"practice": bool(e.get("practice", false)), "folio": String(e.get("folio", "")), "lines": lines, "started": started,
		"formal": formal.duplicate(), "notes": notes, "editable": ink != "tinta"}

# Resumen de un renglón de la página: «Fuente: «El problema final» · Calla: la raspadura / Consta en: …»
static func entry_summary(vm: Dictionary) -> String:
	var parts: Array = []
	for ln in vm.get("lines", []):
		var fs: Array = []
		for f in ln.fields:
			if String(f.value) != "":
				fs.append("%s %s" % [String(f.label), String(f.text)])
		if not fs.is_empty():
			parts.append(" · ".join(PackedStringArray(fs)))
	return " / ".join(PackedStringArray(parts))

# ---------------------------------------------------------------- sello y lote
static func lot_eligible(sim, eid: String) -> bool:
	var e: Dictionary = sim.q_entry(eid)
	return not e.is_empty() and String(e.get("ink", "")) != "tinta" and not bool(e.get("practice", false))

# Asientos que se pueden marcar para el sello (a lápiz, sin práctica, no marcados), en el orden del libro: Varios, folios.
# [{id, text, sub}] para el elector de la ranura vacía del sello.
static func lot_options(sim, lot: Array) -> Array:
	var out: Array = []
	if sim == null:
		return out
	for p in pages(sim):
		if not ["varios", "folio"].has(String(p.get("kind", ""))):
			continue
		for eid in page_entries(sim, String(p.id)):
			var id := String(eid)
			if lot.has(id) or not lot_eligible(sim, id):
				continue
			var vm := entry_vm(sim, id)
			var where := String(p.get("title", ""))
			var summ := entry_summary(vm)
			out.append({"id": id, "text": "%s · %s" % [tx(sim, "ledger.asiento", {"n": int(vm.n)}), String(vm.tname)],
				"sub": where + (" — " + short(summ, 90) if summ != "" else "")})
	return out

# Sólo ids que siguen existiendo y a lápiz (sin práctica), sin pasar del tamaño del lote.
static func clean_lot(sim, lot: Array) -> Array:
	var out: Array = []
	var n := int(sim.q_clock().get("lot_size", 2)) if sim != null else 0
	for id in lot:
		if out.size() >= n:
			break
		if lot_eligible(sim, String(id)) and not out.has(String(id)):
			out.append(String(id))
	return out

# {phase, passes_left, lot_size, dry, reason, ready}. reason: "" (se puede estampar) · "practica" (prólogo) · "fuera"
# (no está en el escritorio) · "seco" (sin pasada en esta franja) · "nada" (lote de cero: todo lo que cuenta, sellado) ·
# "lote" (no hay exactamente lot_size marcados).
static func seal_state(sim, lot: Array) -> Dictionary:
	if sim == null:
		return {"phase": "", "passes_left": 0, "lot_size": 2, "dry": true, "reason": "seco", "ready": false}
	var c: Dictionary = sim.q_clock()
	var phase := String(c.get("phase", ""))
	var left := int(c.get("passes_left", 0))
	var n := int(c.get("lot_size", 2))
	var reason := ""
	if phase == "prologue":
		reason = "practica"
	elif AWAY_PHASES.has(phase):
		reason = "fuera"
	elif n <= 0:
		# lote de cero (todo lo que cuenta ya está sellado): el sello no tiene qué pasar, ni en esta franja ni en la que
		# viene (antes que «seco», que prometería otra pasada)
		reason = "nada"
	elif left <= 0 or not STAMP_PHASES.has(phase):
		reason = "seco"
	elif lot.size() != n:
		reason = "lote"
	return {"phase": phase, "passes_left": left, "lot_size": n, "dry": left <= 0, "reason": reason, "ready": reason == ""}

static func seal_reason_text(sim, st: Dictionary) -> String:
	match String(st.get("reason", "")):
		"practica":
			return tx(sim, "ledger.sello.practica")
		"fuera":
			return tx(sim, "ledger.sello.fuera")
		"seco":
			return tx(sim, "pass.sin_pasada")
		"nada", "lote":
			return lot_text(sim, int(st.get("lot_size", 2)))
	return ""

# «Se pasa de dos en dos…» (o de uno en uno); con lote de cero, que el sello no tiene qué pasar (nunca «ledger.n.0»).
static func lot_text(sim, n: int) -> String:
	if n <= 0:
		return tx(sim, "ledger.sello.nada")
	return tx(sim, "pass.lote", {"n": tx(sim, "ledger.n.%d" % n)})

# ---------------------------------------------------------------- tutorial (prólogo: un verbo por paso)
static func tut_allows(sim, t: String) -> bool:
	if sim == null:
		return false
	var c: Dictionary = sim.q_clock()
	if String(c.get("phase", "")) == "done":
		return false
	if String(c.get("phase", "")) != "prologue":
		return true
	var i := Tutorial.step_index_of(t)
	if i < 0:
		return false
	var st = c.get("tutorial", {})
	return i <= int(st.get("index", 0)) if typeof(st) == TYPE_DICTIONARY else false

# ---------------------------------------------------------------- errores -> voz de Lisle
static func err_text(sim, err: String, extra := {}) -> String:
	match err:
		"no_indexado", "fuera_de_lista", "en_tinta":
			return tx(sim, "entry." + err)
		"formal":
			return tx(sim, "pass.formal")
		"sin_pasada":
			return tx(sim, "pass.sin_pasada")
		"lote":
			var n := int(extra.get("lot_size", sim.q_clock().get("lot_size", 2) if sim != null else 2))
			return lot_text(sim, n)
		"fase":
			return tx(sim, "ledger.sello.fuera") if String(extra.get("t", "")) == "pass_clean" else tx(sim, "ledger.err.tutorial")
		"tutorial":
			return tx(sim, "ledger.err.tutorial")
		"anidado":
			return tx(sim, "clip." + err)
	if has_text(sim, "core.err." + err):
		return tx(sim, "core.err." + err)
	return tx(sim, "core.err.desconocido")
