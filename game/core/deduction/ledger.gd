# core/deduction/ledger.gd — libro mayor: folios y asientos a lápiz (§5.2, GDD§8.3–8.5). Dueño: W2-DED. Contrato §3.8.
# Folio: st.ded.folios[id] = {id, head_clip, entries:[id]}. Páginas fijas sin folio: "varios" y "erratas" (práctica C1,
#   «Erratas inocentes», extensión: entry.practice = true; su chequeo formal pide 2 pasajes distintos en vez de 2 orígenes).
# Asiento: st.ded.entries[id] = {id, folio, template, lines:[{fields:{campo: valor}, support:[clip|par]}], ink:"lapiz"|"tinta",
#   practice:bool, cid:""}  (cid = conclusión sellada o practicada; vacío a lápiz).
# entry_set exige valor ∈ índice (accept.kinds, con el kind correcto) o ∈ lista cerrada (accept.list; para «medios» valen
#   también sus entities si están en el índice). "" borra. Errores: no_indexado, fuera_de_lista, en_tinta (+ no_existe,
#   campo, folio, plantilla: forma de la acción).
# Chequeo formal (visible, no gasta): falta_segun · una_fuente (C1: pasajes) · demasiado_papel (>4 recortes únicos).
# T14: create_folio sólo lo llama core/sim/player_actions.gd (act_folio_open). Este archivo no la llama.
# Extensiones: formal_codes(st, repo, entry, practice), entry_clips_of(st, entry), origins_of(st, clips), passages_of,
#   ledger_view(st, repo) (= q_ledger), entry_view(st, repo, id) (= q_entry).
extends RefCounted

const Index = preload("res://core/deduction/index.gd")

const MAX_CLIPS := 4
const PAGES := ["varios", "erratas"]

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}

static func _note(st, kind: String, payload: Dictionary) -> void:
	if st is Object and st.has_method("note"):
		st.note(kind, payload)

static func init_state(st, repo) -> void:
	Index.ensure(st)

# SÓLO desde player_actions.gd (T14). Recorte (o par) inexistente -> "". El mismo encabezado reabre su folio.
static func create_folio(st, repo, head_clip: String) -> String:
	var d := Index.ensure(st)
	if not d.clips.has(head_clip) and not d.pairs.has(head_clip):
		return ""
	var ks: Array = d.folios.keys()
	ks.sort()
	for fid in ks:
		if String(d.folios[fid].get("head_clip", "")) == head_clip:
			return fid
	var id: String = st.next_id("folio", "FO", 3)
	d.folios[id] = {"id": id, "head_clip": head_clip, "entries": []}
	return id   # el aviso "folio" lo emite act_folio_open (W2-SIM)

static func act_entry_new(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var folio := String(a.get("folio", "varios"))
	if folio == "":
		folio = "varios"
	if not PAGES.has(folio) and not d.folios.has(folio):
		return _err("folio")
	var tid := String(a.get("template", ""))
	var tpl: Dictionary = repo.template(tid)
	if tpl.is_empty():
		return _err("plantilla")
	var lines: Array = []
	for ln in tpl.get("lines", []):
		lines.append({"fields": {}, "support": []})
	var id: String = st.next_id("entry", "AS", 3)
	d.entries[id] = {"id": id, "folio": folio, "template": tid, "lines": lines, "ink": "lapiz",
		"practice": folio == "erratas", "cid": ""}
	if d.folios.has(folio):
		d.folios[folio].entries.append(id)
	_note(st, "entry", {"id": id})
	return {"ok": true, "entry": id}

static func _entry(st, id: String) -> Dictionary:
	var d := Index.ensure(st)
	var e = d.entries.get(id)
	return e if typeof(e) == TYPE_DICTIONARY else {}

static func _field_def(repo, e: Dictionary, line: int, field: String) -> Dictionary:
	var tpl: Dictionary = repo.template(String(e.get("template", "")))
	var tl: Array = tpl.get("lines", [])
	if line < 0 or line >= tl.size():
		return {}
	for f in tl[line].get("fields", []):
		if String(f.get("id", "")) == field:
			return f
	return {}

# "" si el valor es admisible para accept; si no, el código de error.
static func accept_error(st, repo, accept: Dictionary, v: String) -> String:
	if accept.has("list"):
		var name := String(accept.list)
		var lst = repo.lists().get(name, [])
		if typeof(lst) != TYPE_ARRAY:
			return "fuera_de_lista"
		for x in lst:
			if typeof(x) == TYPE_DICTIONARY:
				if String(x.get("id", "")) == v:
					return ""
				if x.get("entities", []).has(v):
					return "" if Index.has(st, v) else "no_indexado"
			elif String(x) == v:
				return ""
		return "fuera_de_lista"
	if not Index.has(st, v):
		return "no_indexado"
	if accept.has("kinds") and not accept.kinds.has(Index.kind(repo, v)):
		return "fuera_de_lista"
	return ""

static func act_entry_set(st, repo, a) -> Dictionary:
	var e := _entry(st, String(a.get("entry", "")))
	if e.is_empty():
		return _err("no_existe")
	if String(e.ink) == "tinta":
		return _err("en_tinta")
	var line := int(a.get("line", -1))
	var field := String(a.get("field", ""))
	var fd := _field_def(repo, e, line, field)
	if fd.is_empty():
		return _err("campo")
	var v := String(a.get("value", ""))
	if v == "":
		e.lines[line].fields.erase(field)
	else:
		var er := accept_error(st, repo, fd.get("accept", {}), v)
		if er != "":
			return _err(er)
		e.lines[line].fields[field] = v
	_note(st, "entry", {"id": e.id})
	return {"ok": true}

static func act_entry_support_add(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var e := _entry(st, String(a.get("entry", "")))
	if e.is_empty():
		return _err("no_existe")
	if String(e.ink) == "tinta":
		return _err("en_tinta")
	var line := int(a.get("line", -1))
	if line < 0 or line >= e.lines.size():
		return _err("campo")
	var item := String(a.get("item", ""))
	if not d.clips.has(item) and not d.pairs.has(item):
		return _err("no_existe")
	if not e.lines[line].support.has(item):
		e.lines[line].support.append(item)
	_note(st, "entry", {"id": e.id})
	return {"ok": true}

static func act_entry_support_remove(st, repo, a) -> Dictionary:
	var e := _entry(st, String(a.get("entry", "")))
	if e.is_empty():
		return _err("no_existe")
	if String(e.ink) == "tinta":
		return _err("en_tinta")
	var line := int(a.get("line", -1))
	if line < 0 or line >= e.lines.size():
		return _err("campo")
	e.lines[line].support.erase(String(a.get("item", "")))
	_note(st, "entry", {"id": e.id})
	return {"ok": true}

static func act_entry_delete(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var id := String(a.get("entry", ""))
	var e := _entry(st, id)
	if e.is_empty():
		return _err("no_existe")
	if String(e.ink) == "tinta":
		return _err("en_tinta")
	var f := String(e.get("folio", ""))
	if d.folios.has(f):
		d.folios[f].entries.erase(id)
	d.entries.erase(id)
	_note(st, "entry", {"id": id, "removed": true})
	return {"ok": true}

# ---------------- chequeo formal ----------------
static func formal_check(st, repo, entry_id: String) -> Array:
	var e := _entry(st, entry_id)
	if e.is_empty():
		return []
	return formal_codes(st, repo, e, bool(e.get("practice", false)))

static func formal_codes(st, repo, e: Dictionary, practice: bool) -> Array:
	var out: Array = []
	for ln in e.get("lines", []):
		var filled := false
		for f in ln.get("fields", {}):
			if String(ln.fields[f]) != "":
				filled = true
		if filled and _line_clips(st, ln).is_empty():
			out.append("falta_segun")
			break
	var clips := entry_clips_of(st, e)
	var srcs: Array = passages_of(st, clips) if practice else origins_of(st, clips)
	if srcs.size() < 2:
		out.append("una_fuente")
	if clips.size() > MAX_CLIPS:
		out.append("demasiado_papel")
	return out

static func _line_clips(st, ln: Dictionary) -> Array:
	var d := Index.ensure(st)
	var out: Array = []
	for it in ln.get("support", []):
		var s := String(it)
		if d.pairs.has(s):
			for c in [String(d.pairs[s].a), String(d.pairs[s].b)]:
				if d.clips.has(c) and not out.has(c):
					out.append(c)
		elif d.clips.has(s) and not out.has(s):
			out.append(s)
	return out

static func line_clips(st, e: Dictionary, line: int) -> Array:
	var lines: Array = e.get("lines", [])
	if line < 0 or line >= lines.size():
		return []
	return _line_clips(st, lines[line])

static func entry_clips(st, entry_id: String) -> Array:
	return entry_clips_of(st, _entry(st, entry_id))

static func entry_clips_of(st, e: Dictionary) -> Array:
	var out: Array = []
	for ln in e.get("lines", []):
		for c in _line_clips(st, ln):
			if not out.has(c):
				out.append(c)
	return out

static func origins_of(st, clips: Array) -> Array:
	var d := Index.ensure(st)
	var out: Array = []
	for c in clips:
		var o := String(d.clips.get(c, {}).get("origin", ""))
		if not out.has(o):
			out.append(o)
	return out

static func passages_of(st, clips: Array) -> Array:
	var d := Index.ensure(st)
	var out: Array = []
	for c in clips:
		var cl: Dictionary = d.clips.get(c, {})
		var p := String(cl.get("passage", ""))
		if p == "":
			p = "%s|%s" % [cl.get("origin", ""), c]
		if not out.has(p):
			out.append(p)
	return out

# ---------------- vistas (q_ledger, q_entry) ----------------
static func ledger_view(st, repo) -> Dictionary:
	var d := Index.ensure(st)
	var rules: Array = []
	for k in range(1, 7):
		var key := "rules.%d" % k
		if repo.texts().has(key):
			rules.append(repo.text(key))
	var varios: Array = []
	var erratas: Array = []
	var ks: Array = d.entries.keys()
	ks.sort()
	for id in ks:
		var f := String(d.entries[id].get("folio", ""))
		if f == "varios":
			varios.append(id)
		elif f == "erratas":
			erratas.append(id)
	var folios: Array = []
	var fs: Array = d.folios.keys()
	fs.sort()
	for fid in fs:
		var fo: Dictionary = d.folios[fid]
		folios.append({"id": fid, "head_clip": String(fo.head_clip), "entries": fo.entries.duplicate()})
	return {"rules_page": rules, "varios": varios, "erratas": erratas, "folios": folios}

static func entry_view(st, repo, id: String) -> Dictionary:
	var e := _entry(st, id)
	if e.is_empty():
		return {}
	var lines: Array = []
	for ln in e.lines:
		lines.append({"fields": ln.fields.duplicate(), "support": ln.support.duplicate()})
	return {"id": id, "folio": String(e.folio), "template": String(e.template), "ink": String(e.ink), "lines": lines,
		"formal": formal_codes(st, repo, e, bool(e.get("practice", false))), "practice": bool(e.get("practice", false))}
