# core/deduction/validator.gd — validación de asientos y pasadas en limpio (§5.2, GDD§8.5). Dueño: W2-DED. Contrato §3.8.
# Un asiento es correcto para cid = which_conclusion(entry) si:
#   1 valores ∈ answers (+ constraints + alias_rules vigentes: "@alias:x" sólo con la regla activa; con C10a sellada los
#     miembros de equiv valen igual en todo campo y como clave);
#   2 cada grupo: la línea group.line tiene en su «según» ≥1 recorte con una etiqueta del grupo (${ch:campo} = canal del
#     medio elegido en ese campo; etiqueta sin prefijo = "a:<x>");
#   3 ≥2 orígenes distintos (práctica C1: ≥2 pasajes distintos);
#   4 todo recorte lleva ≥1 etiqueta de la conclusión (grupos resueltos + tags_extra) y ninguno f:refutado;
#   5 grafo de recortes conexo: arista si comparten una entidad de keys.entities (alias canónico), si ambos llevan alguna
#     entidad de un kind de keys.kinds (act_ref: cada recorte cita un acto; así se unen las subrutas de canal de C6) o si
#     tienen el mismo origen.
# Pasada (pass_clean): passes_left > 0 · len == lot_size · formal (no gasta) · gasta; todo o nada; cids distintos y no
#   sellados; ventana conclusions[].validate {from, until}. Devuelve spent:true: el sim (W2-SIM) cuenta la pasada usada
#   (st.clock.passes_used) — este módulo no escribe st.clock. Registro propio: st.ded.passes [{tk, entries, inked}].
# lot_size = min(schedule.lot.default (2) | day10 (1), lot_counts sin sellar cuya ventana validate está abierta ahora):
#   sólo calendario y sellados (GDD §8.5); C12 (10.M) no cuenta antes del día 10.
# Práctica (C1, kind "practica"): de a uno, sin pasada, no sella ni cuenta; el asiento queda en tinta con su cid.
# Extensiones: evaluate(st, repo, entry, opts) (opts: practice, sealed, cid, exclude_origins:[prefijos de origen o de
#   escena, p. ej. "S.HC06" — HB12]),
#   covers_all_groups(repo, cid, tags) (T4), group_tags(repo, cid, entry), passes_spent(st, tk).
# Costura de tests: test_passes_left (Callable(st, repo) -> int) reemplaza a Clock.passes_left.
extends RefCounted

const L = preload("res://core/util/log.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Index = preload("res://core/deduction/index.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Ledger = preload("res://core/deduction/ledger.gd")

const CLOCK := "res://core/sim/clock.gd"
const PRACTICE_KIND := "practica"
const REFUTADO := "f:refutado"

static var test_passes_left: Callable = Callable()

static var _rx_ch: RegEx = null

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}

static func _note(st, kind: String, payload: Dictionary) -> void:
	if st is Object and st.has_method("note"):
		st.note(kind, payload)

# ---------------- valores ----------------
static func _values(entry: Dictionary) -> Dictionary:
	var out := {}
	for ln in entry.get("lines", []):
		var fs = ln.get("fields", {})
		for f in fs:
			if String(fs[f]) != "":
				out[String(f)] = String(fs[f])
	return out

static func alias_groups(repo, sealed: Dictionary) -> Array:
	var out: Array = []
	for r in repo.conclusions_meta().get("alias_rules", []):
		if typeof(r) == TYPE_DICTIONARY and sealed.has(String(r.get("when_sealed", ""))):
			var g: Array = []
			for x in r.get("equiv", []):
				g.append(String(x))
			g.sort()
			if not g.is_empty():
				out.append(g)
	return out

static func canon(v: String, groups: Array) -> String:
	for g in groups:
		if g.has(v):
			return g[0]
	return v

static func _in_groups(v: String, groups: Array) -> bool:
	for g in groups:
		if g.has(v):
			return true
	return false

static func medio_of(repo, v: String) -> Dictionary:
	for m in repo.lists().get("medios", []):
		if typeof(m) == TYPE_DICTIONARY and (String(m.get("id", "")) == v or m.get("entities", []).has(v)):
			return m
	return {}

static func _in_list(repo, name: String, v: String) -> bool:
	var lst = repo.lists().get(name, [])
	if typeof(lst) != TYPE_ARRAY:
		return false
	for x in lst:
		if typeof(x) == TYPE_DICTIONARY:
			if String(x.get("id", "")) == v or x.get("entities", []).has(v):
				return true
		elif String(x) == v:
			return true
	return false

static func _accepts(repo, acc, v: String, groups: Array) -> bool:
	if typeof(acc) == TYPE_DICTIONARY:
		if acc.has("list"):
			return _in_list(repo, String(acc.list), v)
		return false
	var arr: Array = acc if typeof(acc) == TYPE_ARRAY else [acc]
	var cv := canon(v, groups)
	for a in arr:
		var s := String(a)
		if s.begins_with("@alias:"):
			var x := s.substr(7)
			if _in_groups(x, groups) and canon(x, groups) == cv:
				return true
			continue
		if s == v or canon(s, groups) == cv:
			return true
	return false

static func _norm_for_distinct(repo, v: String, groups: Array) -> String:
	var m := medio_of(repo, v)
	if not m.is_empty():
		return "medio:" + String(m.id)
	return canon(v, groups)

static func values_match(repo, entry: Dictionary, cid: String, sealed: Dictionary) -> bool:
	var c: Dictionary = repo.conclusion(cid)
	if c.is_empty() or String(c.get("template", "")) != String(entry.get("template", "")):
		return false
	var vals := _values(entry)
	var groups := alias_groups(repo, sealed)
	var ans = c.get("answers", {})
	if typeof(ans) != TYPE_DICTIONARY:
		return false
	var fs: Array = ans.keys()
	fs.sort()
	for f in fs:
		if String(f).begins_with("_"):
			continue
		var v := String(vals.get(f, ""))
		if v == "" or not _accepts(repo, ans[f], v, groups):
			return false
	for con in c.get("constraints", []):
		if typeof(con) == TYPE_DICTIONARY and con.has("distinct"):
			var seen := {}
			for f in con.distinct:
				var v2 := String(vals.get(String(f), ""))
				if v2 == "":
					continue
				var k := _norm_for_distinct(repo, v2, groups)
				if seen.has(k):
					return false
				seen[k] = true
		else:
			L.w("validator", "%s: restricción desconocida %s" % [cid, str(con)])
			return false
	return true

static func _is_practice(c: Dictionary) -> bool:
	return String(c.get("kind", "")) == PRACTICE_KIND

static func which_conclusion(repo, entry: Dictionary, sealed: Dictionary) -> String:
	return _which(repo, entry, sealed, bool(entry.get("practice", false)))

static func _which(repo, entry: Dictionary, sealed: Dictionary, practice: bool) -> String:
	for c in repo.conclusions():
		if _is_practice(c) != practice:
			continue
		if values_match(repo, entry, String(c.id), sealed):
			return String(c.id)
	return ""

# ---------------- etiquetas de grupos ----------------
static func _ch_rx() -> RegEx:
	if _rx_ch == null:
		_rx_ch = RegEx.new()
		_rx_ch.compile("\\$\\{ch:([A-Za-z0-9_]+)\\}")
	return _rx_ch

# Etiqueta de grupo resuelta con los valores del asiento; "" si un ${ch:campo} no tiene medio.
static func _resolve_tag(repo, t: String, vals: Dictionary) -> String:
	var out := t
	for m in _ch_rx().search_all(t):
		var m2 := medio_of(repo, String(vals.get(m.get_string(1), "")))
		if m2.is_empty():
			return ""
		out = out.replace(m.get_string(0), String(m2.get("ch", "")))
	return out

static func tag_match(clip_tags: Array, t: String) -> bool:
	if t == "":
		return false
	if t.contains(":"):
		return clip_tags.has(t)
	return clip_tags.has("a:" + t)

# {groups:[{id, line, tags:[resueltas]}], all:[todas las etiquetas de la conclusión]} para un asiento.
static func group_tags(repo, cid: String, entry: Dictionary) -> Dictionary:
	var c: Dictionary = repo.conclusion(cid)
	var vals := _values(entry)
	var groups: Array = []
	var all: Array = []
	for g in c.get("groups", []):
		var ts: Array = []
		for t in g.get("tags", []):
			var r := _resolve_tag(repo, String(t), vals)
			if r != "" and not ts.has(r):
				ts.append(r)
			if r != "" and not all.has(r):
				all.append(r)
		groups.append({"id": String(g.get("id", "")), "line": int(g.get("line", 0)), "tags": ts})
	for t in c.get("tags_extra", []):
		if not all.has(String(t)):
			all.append(String(t))
	return {"groups": groups, "all": all}

# ---------------- condiciones 2–5 ----------------
static func evaluate(st, repo, entry: Dictionary, opts := {}) -> Dictionary:
	var d := Index.ensure(st)
	var practice := bool(opts.get("practice", entry.get("practice", false)))
	var sealed: Dictionary = opts.get("sealed", d.sealed)
	var cid := String(opts.get("cid", ""))
	if cid == "":
		cid = _which(repo, entry, sealed, practice)
	elif not values_match(repo, entry, cid, sealed):
		cid = ""
	if cid == "":
		return {"ok": false, "cid": "", "failed": [1]}
	var excl: Array = opts.get("exclude_origins", [])
	var keep := func(cl_id: String) -> bool:
		var cd: Dictionary = d.clips.get(cl_id, {})
		var o := String(cd.get("origin", ""))
		var sc := String(cd.get("scene", ""))
		for p in excl:
			var ps := String(p)
			if o.begins_with(ps) or (sc != "" and (sc == ps or ("S." + sc).begins_with(ps))):
				return false
		return true
	var clips: Array = Ledger.entry_clips_of(st, entry).filter(keep)
	var gt := group_tags(repo, cid, entry)
	var failed: Array = []
	# 2
	for g in gt.groups:
		var hit := false
		for cl in Ledger.line_clips(st, entry, int(g.line)).filter(keep):
			var tags: Array = d.clips[cl].get("tags", [])
			for t in g.tags:
				if tag_match(tags, String(t)):
					hit = true
					break
			if hit:
				break
		if not hit:
			failed.append(2)
			break
	# 3
	var srcs: Array = Ledger.passages_of(st, clips) if practice else Ledger.origins_of(st, clips)
	if srcs.size() < 2:
		failed.append(3)
	# 4
	for cl in clips:
		var tags2: Array = d.clips[cl].get("tags", [])
		if tags2.has(REFUTADO):
			failed.append(4)
			break
		var any := false
		for t in gt.all:
			if tag_match(tags2, String(t)):
				any = true
				break
		if not any:
			failed.append(4)
			break
	# 5
	if not _connected(st, repo, cid, clips, sealed):
		failed.append(5)
	return {"ok": failed.is_empty(), "cid": cid, "failed": failed}

static func _connected(st, repo, cid: String, clips: Array, sealed: Dictionary) -> bool:
	if clips.size() <= 1:
		return true
	var d := Index.ensure(st)
	var c: Dictionary = repo.conclusion(cid)
	var keys = c.get("keys", {})
	var groups := alias_groups(repo, sealed)
	var kents := {}
	for e in keys.get("entities", []):
		kents[canon(String(e), groups)] = true
	var kinds: Array = keys.get("kinds", [])
	var info: Array = []
	for cl in clips:
		var cd: Dictionary = d.clips[cl]
		var ks := {}
		var has_kind := false
		for e in cd.get("ents", []):
			var ce := canon(String(e), groups)
			if kents.has(ce):
				ks[ce] = true
			if not kinds.is_empty() and kinds.has(Index.kind(repo, String(e))):
				has_kind = true
		info.append({"origin": String(cd.get("origin", "")), "keys": ks, "kind": has_kind})
	var n := clips.size()
	var seen := [0]
	var reached := {0: true}
	while not seen.is_empty():
		var i: int = seen.pop_back()
		for j in n:
			if reached.has(j):
				continue
			var linked: bool = (info[i].origin == info[j].origin and info[i].origin != "") or (info[i].kind and info[j].kind)
			if not linked:
				for k in info[i].keys:
					if info[j].keys.has(k):
						linked = true
						break
			if linked:
				reached[j] = true
				seen.append(j)
	return reached.size() == n

static func entry_ok(st, repo, entry_id: String) -> Dictionary:
	var e = Index.ensure(st).entries.get(entry_id)
	if typeof(e) != TYPE_DICTIONARY:
		return {"ok": false, "cid": "", "failed": [1]}
	return evaluate(st, repo, e)

static func lot_size(st, repo) -> int:
	var d := Index.ensure(st)
	var lot = repo.schedule().get("lot", {})
	if typeof(lot) != TYPE_DICTIONARY:
		lot = {}
	var c = st.clock if typeof(st.clock) == TYPE_DICTIONARY else {}
	var n := int(lot.get("day10", 1)) if int(c.get("day", 0)) == 10 else int(lot.get("default", 2))
	# sólo cuentan las conclusiones sin sellar que AHORA se pueden validar (ventana validate abierta): C12 (10.M) no
	# puede ser compañera de lote antes del día 10, así que no obliga a esperarla (GDD §8.5: calendario y sellados,
	# nunca el inventario del jugador).
	var now := Clipper.now_tk(st)
	var unsealed := 0
	for cid in repo.conclusions_meta().get("lot_counts", []):
		if not d.sealed.has(String(cid)) and _in_window(repo, String(cid), now):
			unsealed += 1
	return mini(n, unsealed)

static func entry_tags(st, entry_id: String) -> Array:
	var d := Index.ensure(st)
	var e = d.entries.get(entry_id)
	if typeof(e) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for cl in Ledger.entry_clips_of(st, e):
		for t in d.clips[cl].get("tags", []):
			if not out.has(t):
				out.append(t)
	out.sort()
	return out

# ---------------- pasadas ----------------
static func _passes_left(st, repo) -> int:
	if test_passes_left.is_valid():
		return int(test_passes_left.call(st, repo))
	var ck: Script = load(CLOCK)
	return int(ck.call("passes_left", st, repo))

static func passes_spent(st, tk: int) -> int:
	var n := 0
	for p in Index.ensure(st).passes:
		if int(p.get("tk", -1)) == tk:
			n += 1
	return n

static func _in_window(repo, cid: String, tk: int) -> bool:
	if tk <= 0:
		return true
	var v = repo.conclusion(cid).get("validate", {})
	if typeof(v) != TYPE_DICTIONARY:
		return true
	if v.get("from") != null and String(v.get("from", "")) != "" and tk < TimeKey.parse(String(v.from)):
		return false
	if v.get("until") != null and String(v.get("until", "")) != "" and tk > TimeKey.parse(String(v.until)):
		return false
	return true

static func act_pass_clean(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var raw = a.get("entries", [])
	if typeof(raw) != TYPE_ARRAY:
		return _err("lote")
	var ids: Array = []
	for x in raw:
		ids.append(String(x))
	if _passes_left(st, repo) <= 0:
		return _err("sin_pasada")
	var n := lot_size(st, repo)
	var uniq := {}
	for id in ids:
		uniq[id] = true
	if n <= 0 or ids.size() != n or uniq.size() != ids.size():
		return {"ok": false, "err": "lote", "lot_size": n}
	for id in ids:
		var e = d.entries.get(id)
		if typeof(e) != TYPE_DICTIONARY:
			return _err("no_existe")
		if String(e.get("ink", "")) == "tinta":
			return _err("en_tinta")
	var formal: Array = []
	for id in ids:
		for code in Ledger.formal_codes(st, repo, d.entries[id], false):
			formal.append({"entry": id, "code": code})
	if not formal.is_empty():
		return {"ok": false, "err": "formal", "formal": formal}
	var tk := Clipper.now_tk(st)
	var good := true
	var cids: Array = []
	for id in ids:
		var r := evaluate(st, repo, d.entries[id], {"practice": false})
		if not r.ok or cids.has(r.cid) or d.sealed.has(r.cid) or not _in_window(repo, String(r.cid), tk):
			good = false
			break
		cids.append(r.cid)
	d.passes.append({"tk": tk, "entries": ids.duplicate(), "inked": good})
	if good:
		for i in ids.size():
			var e: Dictionary = d.entries[ids[i]]
			e["ink"] = "tinta"
			e["cid"] = cids[i]
			d.sealed[cids[i]] = ids[i]
			_note(st, "entry", {"id": ids[i]})
		L.i("validator", "pasada en limpio: %s -> %s" % [str(ids), str(cids)])
	# el aviso "pass" lo emite el despachador (W2-SIM) junto con passes_used; aquí sólo "entry" por asiento entintado.
	return {"ok": true, "inked": good, "msg": repo.text("pass.ok" if good else "pass.fail"),
		"sealed": cids.duplicate() if good else [], "spent": true}

static func act_practice(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var id := String(a.get("entry", ""))
	var e = d.entries.get(id)
	if typeof(e) != TYPE_DICTIONARY:
		return _err("no_existe")
	if String(e.get("ink", "")) == "tinta":
		return _err("en_tinta")
	var formal: Array = []
	for code in Ledger.formal_codes(st, repo, e, true):
		formal.append({"entry": id, "code": code})
	if not formal.is_empty():
		return {"ok": false, "err": "formal", "formal": formal}
	var r := evaluate(st, repo, e, {"practice": true})
	d.practice.append({"entry": id, "cid": r.cid, "ok": r.ok, "tk": Clipper.now_tk(st)})
	if r.ok:
		e["ink"] = "tinta"
		e["cid"] = r.cid
		e["practice"] = true
		_note(st, "entry", {"id": id})
	return {"ok": true, "inked": r.ok, "msg": repo.text("practice.ok" if r.ok else "practice.fail")}

# ---------------- T4 ----------------
# ¿Cubre este conjunto de etiquetas TODOS los grupos de la conclusión? (${ch:campo}: alguna asignación de medios
# compatible con constraints.distinct).
static func covers_all_groups(repo, cid: String, tags: Array) -> bool:
	var c: Dictionary = repo.conclusion(cid)
	var gs: Array = c.get("groups", [])
	if gs.is_empty():
		return false
	var fields: Array = []
	for g in gs:
		for t in g.get("tags", []):
			for m in _ch_rx().search_all(String(t)):
				if not fields.has(m.get_string(1)):
					fields.append(m.get_string(1))
	var medios: Array = []
	for m in repo.lists().get("medios", []):
		if typeof(m) == TYPE_DICTIONARY:
			medios.append(String(m.id))
	var assigns: Array = [{}]
	for f in fields:
		var nxt: Array = []
		for asg in assigns:
			for mid in medios:
				var a2: Dictionary = asg.duplicate()
				a2[f] = mid
				nxt.append(a2)
		assigns = nxt
	for asg in assigns:
		var fake := {"lines": [{"fields": asg, "support": []}]}
		if fields.size() > 1 and not _distinct_ok(c, asg):
			continue
		var all := true
		for g in gs:
			var hit := false
			for t in g.get("tags", []):
				if tag_match(tags, _resolve_tag(repo, String(t), _values(fake))):
					hit = true
					break
			if not hit:
				all = false
				break
		if all:
			return true
	return false

static func _distinct_ok(c: Dictionary, asg: Dictionary) -> bool:
	for con in c.get("constraints", []):
		if typeof(con) == TYPE_DICTIONARY and con.has("distinct"):
			var seen := {}
			for f in con.distinct:
				if asg.has(f):
					if seen.has(asg[f]):
						return false
					seen[asg[f]] = true
	return true
