# core/graph/route_db.gd — rutas y fragmentos (contrato de refs §4.8; modelo §5.6). Dueño: W2-GRAPH.
# Contrato §3.8: routes(repo, cid) -> [{id, star, deps, from_idx, frags:[{ref, copy, kind, cls, place, area, mask}]}]
#                frag(repo, ref) -> {ref, kind, tags, ents, origin, cls, copies}
# Extensiones: resolve(repo, ref, copy, vars) (descriptor completo con claves de fuentes), route_by_id, mandatory,
#   final_idx, last_idx, conc_tags, channel_codes, sub_channel, is_pair_conclusion, common_exemplars, lint (T1),
#   all_frags (universo de fragmentos de data/) y false_leads (T17).
# Ruta: {id, star (calculado: todo fragmento de clase I y resuelto), star_decl, deps, eligible (deps ∈ fija/columna/
#   garantizada, §5.6 cond. 3), from_idx, earliest, frags, missing:[...], subs:[a,b], implicit, cut_by}.
# Conclusiones por pares de canal (subroutes + constraint `distinct`, C6): además de las rutas declaradas se generan los
#   pares implícitos de subrutas de canal distinto («se aceptan los diez pares», GDD§10.4 C6) con id "C6.<a>+<b>".
# Descriptor de fragmento: {key, ref, copy, kind, tags:["a:x",...], tags_any, ents, origin, cls, srcs:[claves], mask,
#   exemplar, missing, place, area, doc, char, sub, notes}. kind ∈ doc node sil scene line react journal ad measure.
# v2 (GDD_v2 §C.5): R:<rid>.fisica = línea física del papel que entrega la reacción; D#fisica = la de un documento
# estático (DataRepo la inyecta como tramo #fisica). Las refs M: (regla) siguen soportadas, sin uso.
# Ejemplar (cond. 4, §10.3): "copy:<id>" · "lamina:<lugar>.<área>" / "lamina:<lámina>" · "scene:<id>" · "char:<id>" ·
#   "react:<rid>" · "ad:<id>" · "" (líneas del diario J:, o documento sin ejemplar fijo con varias copias: no fuerza).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const J = preload("res://core/util/j.gd")
const Av = preload("res://core/graph/availability.gd")
const Fisica = preload("res://core/text/fisica.gd")

const ELIGIBLE := ["fija", "columna", "garantizada"]
const DEPS_ORDER := {"fija": 0, "columna": 1, "garantizada": 2, "opcional": 3}
const ACT := "@act"
const DUMMY := {"seat": "214", "hour": "10:00", "title": "un título", "phrase": "una frase", "streets": "una calle",
	"text": "un texto", "act_day": "el martes", "addr": "señor", "fecha": "27 de marzo", "franja": "mañana",
	"lugar": "un lugar", "titulo": "un título", "frase": "una frase", "texto": "un texto", "que": "algo",
	"quien": "alguien", "monto": "un chelín", "encargo": "un encargo", "h": "203", "w": "244"}

# ---------------- utilidades ----------------
static func flat_tags(tags) -> Array:
	var out: Array = []
	if typeof(tags) == TYPE_DICTIONARY:
		for p in Markup.PREFIXES:
			for v in tags.get(p, []):
				out.append(p + ":" + String(v))
	elif typeof(tags) == TYPE_ARRAY:
		for t in tags:
			out.append(String(t))
	return out

static func tag_ents(tags: Array) -> Array:
	var out: Array = []
	for t in tags:
		var s := String(t)
		if s.begins_with("e:"):
			out.append(s.substr(2))
	return out

static func uniq(a: Array) -> Array:
	var seen := {}
	var out: Array = []
	for x in a:
		var s := String(x)
		if s == "" or seen.has(s):
			continue
		seen[s] = true
		out.append(s)
	return out

static func _ctx(repo) -> Dictionary:
	var c := {}
	if repo.has_method("markup_ctx"):
		c = repo.markup_ctx().duplicate()
	c["allow_placeholders"] = true
	return c

static func _parse(repo, text: String, vars: Dictionary) -> Dictionary:
	var v := DUMMY.duplicate()
	for k in vars:
		v[k] = vars[k]
	return Markup.parse(Markup.fill(text, v), _ctx(repo))

static func _mentions(pt: Dictionary, a: int, b: int) -> Array:
	var out: Array = []
	for m in pt.get("mentions", []):
		if int(m.from) < b and int(m.to) > a:
			out.append(String(m.ent))
	return out

static func ent_kind(repo, e: String) -> String:
	if e == ACT or e.begins_with("act."):
		return "act_ref"
	return String(repo.entity(e).get("kind", ""))

static func _desc(ref: String, copy: String, kind: String) -> Dictionary:
	return {"key": "", "ref": ref, "copy": copy, "kind": kind, "tags": [], "tags_any": [], "ents": [], "origin": "",
		"cls": "I", "srcs": [], "mask": 0, "exemplar": "", "missing": "", "place": "", "area": "", "doc": "", "char": "",
		"sub": "", "notes": [], "_s": []}

static func _finish(d: Dictionary) -> void:
	var keys: Array = []
	var m := 0
	for s in d.get("_s", []):
		if typeof(s) != TYPE_DICTIONARY or s.is_empty():
			continue
		if not keys.has(s.key):
			keys.append(s.key)
			m |= int(s.mask)
	d.erase("_s")
	d["srcs"] = keys
	d["mask"] = m
	if d.missing == "" and keys.is_empty():
		d["missing"] = "sin fuente (lugar, personaje o reacción que lo entregue)"
	if d.tags_any.is_empty():
		d["tags_any"] = d.tags.duplicate()

# ---------------- resolución de refs (§4.8) ----------------
static func resolve(repo, ref: String, copy := "", vars := {}) -> Dictionary:
	var key := ref + "|" + copy + ("" if vars.is_empty() else "|" + J.stringify_canon(vars))
	var fc := Av.sub(repo, "frags")
	if fc.has(key):
		return fc[key]
	var d: Dictionary
	if ref.begins_with("N:"):
		d = _node(repo, ref, copy)
	elif ref.begins_with("S:"):
		d = _scene(repo, ref, copy, vars)
	elif ref.begins_with("L:"):
		d = _dlg(repo, ref, copy, vars)
	elif ref.begins_with("R:"):
		d = _rastro(repo, ref, copy, vars)
	elif ref.begins_with("J:"):
		d = _journal(repo, ref, copy)
	elif ref.begins_with("AD:"):
		d = _ad(repo, ref, copy)
	elif ref.begins_with("M:"):
		d = _measure(repo, ref, copy, vars)
	elif ref.contains("#"):
		d = _doc(repo, ref, copy)
	else:
		d = _desc(ref, copy, "?")
		d.missing = "ref desconocido"
	d["key"] = key
	_finish(d)
	if not d.srcs.is_empty():
		var s0: Dictionary = Av.src(repo, d.srcs[0])
		d["place"] = String(s0.get("place", ""))
		d["area"] = String(s0.get("area", ""))
	fc[key] = d
	return d

# Contrato: {ref, kind, tags, ents, origin, cls, copies} (+ el resto del descriptor).
static func frag(repo, ref: String) -> Dictionary:
	var d := resolve(repo, ref)
	var out: Dictionary = d.duplicate(true)
	var copies: Array = []
	for sk in d.srcs:
		var c := String(Av.src(repo, sk).get("copy", ""))
		if c != "" and not copies.has(c):
			copies.append(c)
	out["copies"] = copies
	return out

static func find_tramo(repo, did: String, tid: String) -> Dictionary:
	for p in repo.doc(did).get("parts", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pt: Dictionary = repo.parsed(did, String(p.get("id", "")))
		for t in pt.get("tramos", []):
			if String(t.get("id", "")) == tid:
				return {"part": p, "tramo": t, "ents": _mentions(pt, int(t.from), int(t.to)), "parsed": pt}
	return {}

static func _best_class(doc: Dictionary) -> String:
	var seen := {}
	for c in doc.get("copies", []):
		if typeof(c) == TYPE_DICTIONARY:
			seen[String(c.get("class", doc.get("class", "I")))] = true
	for k in ["I", "P", "C"]:
		if seen.has(k):
			return k
	return String(doc.get("class", "I"))

static func _doc(repo, ref: String, copy: String) -> Dictionary:
	var d := _desc(ref, copy, "doc")
	var h := ref.find("#")
	var did := ref.substr(0, h)
	var tid := ref.substr(h + 1)
	var doc: Dictionary = repo.doc(did)
	d.doc = did
	if doc.is_empty():
		d.missing = "documento %s inexistente" % did
		return d
	var hit := find_tramo(repo, did, tid)
	if hit.is_empty():
		d.missing = "%s no tiene el tramo #%s" % [did, tid]
		return d
	d.tags = flat_tags(hit.tramo.tags)
	d.ents = uniq(hit.ents + tag_ents(d.tags) + doc_ents(doc))
	d.origin = String(doc.get("origin", did))
	var conds: Array = []
	if typeof(hit.part.get("when")) == TYPE_DICTIONARY:
		conds.append(hit.part.when)
	if copy != "":
		var cp: Dictionary = repo.copy(copy)
		if cp.is_empty() or String(cp.get("doc", "")) != did:
			d.missing = "ejemplar %s inexistente" % copy
			return d
		d.cls = String(cp.copy.get("class", doc.get("class", "I")))
		d.exemplar = "copy:" + copy
	else:
		d.cls = _best_class(doc)
		var cps: Array = doc.get("copies", [])
		if cps.size() == 1 and typeof(cps[0]) == TYPE_DICTIONARY:
			d.exemplar = "copy:" + String(cps[0].get("id", ""))
	d._s = Av.doc_srcs(repo, did, copy, conds)
	return d

static func _find_node(od: Dictionary, nid: String, variant: String) -> Dictionary:
	if variant == "":
		for n in od.get("nodes", []):
			if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == nid:
				return {"node": n, "variant": ""}
	var vs = od.get("variants", {})
	if typeof(vs) == TYPE_DICTIONARY:
		for v in Av.sorted_keys(vs):
			if variant != "" and String(v) != variant:
				continue
			var vd = vs[v]
			if typeof(vd) != TYPE_DICTIONARY:
				continue
			for lst in ["add_nodes", "nodes"]:
				for n in vd.get(lst, []):
					if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == nid:
						return {"node": n, "variant": String(v)}
	if variant != "":
		for n in od.get("nodes", []):
			if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == nid:
				return {"node": n, "variant": variant}
	return {}

static func _sil_desc(repo, d: Dictionary, who: String, owner: String) -> Dictionary:
	d.kind = "sil"
	d._s = Av.sil_srcs(repo, who, owner)
	if d._s.is_empty():
		d.missing = "silueta %s sin lugar que la declare o sin reacción que la ponga (efecto silueta)" % who
	var ch := sub_channel(repo, Av.sil_channel(repo, who))
	d.tags = ["a:ancla_" + ch] if ch != "" else []
	d.ents = [ACT, who]
	d.origin = "PL." + (owner if owner != "" else "*")
	d.cls = "I"
	d.exemplar = ("lamina:" + owner) if owner != "" else ""
	return d

static func _variant_tb(repo, owner: String, variant: String) -> int:
	var m := 0
	for r in repo.reactions():
		var effs: Array = r.get("efecto", []).duplicate()
		var vb = r.get("variante_blanda")
		if typeof(vb) == TYPE_DICTIONARY:
			effs.append_array(vb.get("efecto", []))
		for e in effs:
			if typeof(e) == TYPE_DICTIONARY and String(e.get("op", "")) == "alterar_lugar" and String(e.get("place", "")) == owner and String(e.get("variant", "")) == variant:
				m |= int(Av.react_src(repo, String(r.get("id", ""))).get("tb", 0))
	return m

static func _node(repo, ref: String, copy: String) -> Dictionary:
	var d := _desc(ref, copy, "node")
	var rest := ref.substr(2)
	if rest.begins_with("*."):
		var nid0 := rest.substr(2)
		if nid0.begins_with("sil_"):
			return _sil_desc(repo, d, nid0.substr(4), "")
		d.missing = "nodo comodín sólo para siluetas (N:*.sil_<who>)"
		return d
	var parts := rest.split(".")
	var owner := ""
	var is_plate := false
	var k := 0
	for kk in range(parts.size() - 1, 0, -1):
		var pid := ".".join(parts.slice(0, kk))
		if not repo.place(pid).is_empty():
			owner = pid
			k = kk
			break
		if not repo.plate(pid).is_empty():
			owner = pid
			is_plate = true
			k = kk
			break
	if owner == "":
		d.missing = "lugar o lámina inexistente"
		return d
	var restp: Array = Array(parts.slice(k))
	var variant := ""
	var nid := String(restp[0])
	if restp.size() > 1:
		variant = String(restp[0])
		nid = ".".join(PackedStringArray(restp.slice(1)))
	var od: Dictionary = repo.plate(owner) if is_plate else repo.place(owner)
	if nid.begins_with("sil_") and not is_plate:
		return _sil_desc(repo, d, nid.substr(4), owner)
	var found := _find_node(od, nid, variant)
	if found.is_empty():
		d.missing = "nodo %s inexistente en %s" % [nid, owner]
		return d
	var node: Dictionary = found.node
	variant = String(found.variant)
	d.tags = flat_tags(node.get("tags", []))
	var pt := _parse(repo, String(node.get("examine", "")), {})
	d.ents = uniq(_mentions(pt, 0, String(pt.get("plain", "")).length()) + tag_ents(d.tags))
	d.cls = String(node.get("cls", "C"))
	d.origin = String(od.get("origin", "PL." + owner))
	var area := String(node.get("area", "*"))
	d.exemplar = "lamina:" + owner + ("" if is_plate else "." + area)
	var conds: Array = [node.get("when", {})]
	if copy != "" and repo.copy(copy).is_empty():
		# §4.8: en un nodo, "copy" puede nombrar la lámina misma ("PL.prologo"): no es un ejemplar de documento.
		if copy.begins_with("PL.") or copy == String(od.get("origin", "")):
			copy = ""
		else:
			d.missing = "ejemplar %s inexistente" % copy
			return d
	if copy != "":
		d._s = Av.copy_srcs(repo, copy, conds)
		d.exemplar = "copy:" + copy
		return d
	var dv = od.get("doc_variant", {})
	if is_plate and variant != "" and typeof(dv) == TYPE_DICTIONARY and not dv.is_empty():
		var absent: Array = []
		for did in Av.sorted_keys(dv):
			if String(dv[did]) == variant:
				if repo.doc(String(did)).is_empty():
					absent.append(String(did))
				d._s.append_array(Av.doc_srcs(repo, String(did), "", conds))
		if d._s.is_empty() and not absent.is_empty():
			d.missing = "la lámina %s (variante %s) se ve con %s, inexistente" % [owner, variant, ", ".join(PackedStringArray(absent))]
		return d
	if variant != "" and not is_plate:
		d._s = Av.node_srcs(repo, owner, node, false, _variant_tb(repo, owner, variant))
		return d
	d._s = Av.node_srcs(repo, owner, node, is_plate)
	return d

static func _find_line(s: Dictionary, lid: String) -> Dictionary:
	for l in s.get("lines", []):
		if typeof(l) == TYPE_DICTIONARY and String(l.get("id", "")) == lid and not l.has("gen"):
			return {"line": l, "text": String(l.get("text", ""))}
	for v in s.get("variants", []):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		for l in v.get("append", []):
			if typeof(l) == TYPE_DICTIONARY and String(l.get("id", "")) == lid:
				var ll: Dictionary = l.duplicate()
				var w = v.get("when", {})
				if typeof(w) == TYPE_DICTIONARY and not w.is_empty():
					ll["when"] = {"all": [w, l.get("when", {})]}
				return {"line": ll, "text": String(l.get("text", ""))}
	for l in s.get("lines", []):
		if typeof(l) == TYPE_DICTIONARY and l.has("gen") and lid.begins_with(String(l.get("id", "")) + "_"):
			var ch := lid.substr(String(l.id).length() + 1)
			var tpl = l.get("tpl", {})
			if typeof(tpl) == TYPE_DICTIONARY and tpl.has(ch):
				return {"line": {"id": lid, "when": l.get("when", {})}, "text": String(tpl[ch])}
	return {}

# Una o varias líneas: "b_*" = toda variante de la línea generada "b" (HC06 (b) por cualquier canal).
static func _find_lines(s: Dictionary, lid: String) -> Array:
	if lid.ends_with("_*"):
		var base := lid.trim_suffix("_*")
		var out: Array = []
		for l in s.get("lines", []):
			if typeof(l) == TYPE_DICTIONARY and l.has("gen") and String(l.get("id", "")) == base:
				for ch in Av.sorted_keys(l.get("tpl", {})):
					out.append({"line": {"id": base + "_" + String(ch), "when": l.get("when", {})}, "text": String(l.tpl[ch])})
		return out
	var one := _find_line(s, lid)
	if one.is_empty():
		return []
	# variantes que reemplazan el texto de la línea (§4.13 variants[].replace, p. ej. M7 «inteligente» con
	# pell_despedido): el fragmento debe valer en todas, así que cuentan como otra versión (etiquetas = intersección).
	var out2: Array = [one]
	for v in s.get("variants", []):
		if typeof(v) == TYPE_DICTIONARY and typeof(v.get("replace")) == TYPE_DICTIONARY and v.replace.has(lid):
			out2.append({"line": one.line, "text": String(v.replace[lid])})
	return out2

static func _scene(repo, ref: String, copy: String, vars: Dictionary) -> Dictionary:
	var d := _desc(ref, copy, "scene")
	var rest := ref.substr(2)
	var dot := rest.find(".")
	if dot <= 0:
		d.missing = "ref de escena mal formado"
		return d
	var sid := rest.substr(0, dot)
	var lid := rest.substr(dot + 1)
	var s: Dictionary = repo.scene(sid)
	if s.is_empty():
		d.missing = "escena %s inexistente" % sid
		return d
	var hits := _find_lines(s, lid)
	if hits.is_empty():
		d.missing = "escena %s sin la línea %s" % [sid, lid]
		return d
	var inter = null
	var union: Array = []
	var ents: Array = []
	for hit in hits:
		var pt := _parse(repo, String(hit.text), vars)
		var tags: Array = []
		for t in pt.get("tramos", []):
			tags.append_array(flat_tags(t.tags))
		tags = uniq(tags)
		if inter == null:
			inter = tags
		else:
			var keep: Array = []
			for t in inter:
				if tags.has(t):
					keep.append(t)
			inter = keep
		union.append_array(tags)
		ents.append_array(_mentions(pt, 0, String(pt.get("plain", "")).length()) + tag_ents(tags))
		d._s.append_array(Av.scene_srcs(repo, sid, hit.line))
	d.tags = inter
	d.tags_any = uniq(union)
	d.ents = uniq(ents)
	d.origin = String(s.get("origin", "S." + sid))
	d.cls = "I"
	d.exemplar = "scene:" + sid
	return d

static func dialogue_of(repo, char_id: String) -> Dictionary:
	var dl: Dictionary = repo.dialogue(char_id)
	if not dl.is_empty():
		return {"id": char_id, "dl": dl}
	if repo.has_method("dialogues"):
		for k in Av.sorted_keys(repo.dialogues()):
			var ks := String(k)
			if ks.ends_with("_" + char_id) or ks.begins_with(char_id + "_"):
				return {"id": ks, "dl": repo.dialogue(ks)}
	return {}

static func _dlg(repo, ref: String, copy: String, vars: Dictionary) -> Dictionary:
	var d := _desc(ref, copy, "line")
	var rest := ref.substr(2)
	var dot := rest.find(".")
	if dot <= 0:
		d.missing = "ref de diálogo mal formado"
		return d
	var cname := rest.substr(0, dot)
	var lid := rest.substr(dot + 1)
	var found := dialogue_of(repo, cname)
	if found.is_empty():
		d.missing = "diálogo de %s inexistente" % cname
		return d
	var real := String(found.id)
	if real != cname:
		d.notes.append("L:%s resuelto como dialogue/%s.json" % [cname, real])
	var line := {}
	for l in found.dl.get("lines", []):
		if typeof(l) == TYPE_DICTIONARY and String(l.get("id", "")) == lid:
			line = l
	if line.is_empty():
		d.missing = "diálogo de %s sin la línea %s" % [real, lid]
		return d
	var pt := _parse(repo, String(line.get("text", "")), vars)
	var tags: Array = []
	for t in pt.get("tramos", []):
		tags.append_array(flat_tags(t.tags))
	d.tags = uniq(tags)
	d.ents = uniq(_mentions(pt, 0, String(pt.get("plain", "")).length()) + tag_ents(d.tags))
	d.cls = "C"
	d.char = real
	d.exemplar = "char:" + real
	d._s = Av.char_srcs(repo, real, [line.get("when", {})], "line", "." + lid, "C")
	if d._s.is_empty():
		d.missing = "el personaje %s no figura en ningún lugar" % real
		return d
	var s0: Dictionary = d._s[0]
	d.origin = "S." + (String(s0.place) if String(s0.place) != "" else (String(s0.plate) if String(s0.plate) != "" else real))
	return d

static func _rastro(repo, ref: String, copy: String, vars: Dictionary) -> Dictionary:
	var d := _desc(ref, copy, "react")
	var rest := ref.substr(2)
	var dot := rest.find(".")
	if dot <= 0:
		d.missing = "ref de reacción mal formado"
		return d
	var rid := rest.substr(0, dot)
	var x := rest.substr(dot + 1)
	if x == Fisica.TRAMO_ID and not rid.contains("*"):
		return _rastro_fisica(repo, d, rid, copy)
	var rids: Array = []
	if rid.contains("*"):
		for rr in repo.reactions():
			if String(rr.get("id", "")).match(rid):
				rids.append(String(rr.id))
	elif not repo.reaction(rid).is_empty():
		rids.append(rid)
	if rids.is_empty():
		d.missing = "reacción %s inexistente" % rid
		return d
	var want_ch := ""
	if vars.has("ch") and String(vars.ch) != "":
		want_ch = "K-" + String(vars.ch).substr(1).to_upper()
	var sets: Array = []
	for one in rids:
		var r: Dictionary = repo.reaction(one)
		var v: Dictionary = vars.duplicate()
		if not v.has("ch"):
			var cc := sub_channel(repo, String(r.get("canal", "")))
			v["ch"] = cc if cc != "" else "kx"
		var rast: Array = r.get("rastro", [])
		var mine: Array = []
		for t in rast:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var op := tpl_op(r, t)
			if x == "*" or String(t.get("tpl", "")) == x or (SEL_OPS.has(x) and op == SEL_OPS[x]):
				var st := _rastro_set(repo, t, v, "")
				st["op"] = op
				st["ch"] = tpl_channel(t)
				st["rid"] = one
				mine.append(st)
		if mine.is_empty() and not SEL_OPS.has(x) and x != "*":
			for t in rast:
				if typeof(t) == TYPE_DICTIONARY and t.has("texto"):
					var st2 := _rastro_set(repo, t, v, x)
					if st2.found:
						st2["op"] = tpl_op(r, t)
						st2["ch"] = tpl_channel(t)
						st2["rid"] = one
						mine.append(st2)
		sets.append_array(mine)
	if want_ch != "":
		var keep_ch: Array = []
		var any_ch := false
		for st in sets:
			if String(st.ch) != "":
				any_ch = true
			if String(st.ch) == want_ch or String(st.ch) == "":
				keep_ch.append(st)
		if any_ch and not keep_ch.is_empty():
			sets = keep_ch
	if sets.is_empty():
		d.missing = "%s sin plantilla ni tramo '%s' en su rastro" % [rid, x]
		return d
	var inter: Array = sets[0].tags.duplicate()
	var union: Array = []
	var ents: Array = []
	var all_printed := true
	var used := {}
	for st3 in sets:
		var keep: Array = []
		for t2 in inter:
			if st3.tags.has(t2):
				keep.append(t2)
		inter = keep
		union.append_array(st3.tags)
		ents.append_array(st3.ents)
		if not ["columna", "noticia"].has(String(st3.op)):
			all_printed = false
		used[String(st3.rid)] = true
	var used_ids := Av.sorted_keys(used)
	for one2 in used_ids:
		ents.append_array(doc_ents(repo.reaction(String(one2)).get("doc")))
	d.tags = uniq(inter)
	d.tags_any = uniq(union)
	d.ents = uniq(ents)
	if copy != "":
		var cp: Dictionary = repo.copy(copy)
		if cp.is_empty():
			d.missing = "ejemplar %s inexistente" % copy
			return d
		d.cls = String(cp.copy.get("class", "I"))
		d.origin = String(repo.doc(String(cp.doc)).get("origin", cp.doc))
		d.exemplar = "copy:" + copy
		for one3 in used_ids:
			d._s.append_array(Av.react_copy_srcs(repo, String(one3), copy))
	else:
		d.cls = "I" if all_printed else Av.react_cls(repo.reaction(String(used_ids[0])))
		d.origin = "R." + rid
		d.exemplar = "react:" + rid
		for one4 in used_ids:
			d._s.append(Av.react_src(repo, String(one4), "I" if all_printed else ""))
	return d

# R:<rid>.fisica (GDD_v2 §C.5.2): la línea de descripción física del documento que entrega la reacción (data/fisica.json
# plantillas por doc.entity; Effects la antepone al crear el papel). Etiquetas y entidades de la plantilla (+ las del
# documento), origen de la instancia, clase del documento y disponibilidad de la reacción.
static func _rastro_fisica(repo, d: Dictionary, rid: String, copy: String) -> Dictionary:
	var r: Dictionary = repo.reaction(rid)
	if r.is_empty():
		d.missing = "reacción %s inexistente" % rid
		return d
	var doc = r.get("doc")
	var ent := String(doc.get("entity", "")) if typeof(doc) == TYPE_DICTIONARY else ""
	var fis: Dictionary = repo.fisica() if repo.has_method("fisica") else {}
	var spec := Fisica.spec_tpl(fis, ent)
	if spec.is_empty():
		d.missing = "%s: sin descripción física de la plantilla «%s» (data/fisica.json)" % [rid, ent]
		return d
	d.tags = uniq(Fisica.tags(spec))
	d.ents = uniq(Fisica.ents(spec, fis) + tag_ents(d.tags) + doc_ents(doc))
	d.cls = Av.react_cls(r)
	d.origin = "R." + rid
	d.exemplar = "react:" + rid
	d._s = [Av.react_src(repo, rid)]
	return d

const SEL_OPS := {"col": "columna", "columna": "columna", "carta": "carta", "noticia": "noticia"}
const CH_SUFFIX := {"col": "K-T", "kt": "K-T", "kw": "K-W", "kh": "K-H", "ks": "K-S", "kbm": "K-BM"}
const MACHINE_ENTS := {"remington_cotter": "remington_s_alzada"}

# Entidades que todo recorte de un documento lleva (§4.4): entity, clip_entities y la de la máquina.
static func doc_ents(doc) -> Array:
	var out: Array = []
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	if String(doc.get("entity", "")) != "":
		out.append(String(doc.entity))
	for e in doc.get("clip_entities", []):
		out.append(String(e))
	var m = doc.get("machine")
	if m != null and MACHINE_ENTS.has(String(m)):
		out.append(MACHINE_ENTS[String(m)])
	return out

static func _anchor_channel(c) -> String:
	if typeof(c) == TYPE_ARRAY:
		for y in c:
			var r := _anchor_channel(y)
			if r != "":
				return r
		return ""
	if typeof(c) != TYPE_DICTIONARY:
		return ""
	for k in c:
		if String(k) == "anchor" and typeof(c[k]) == TYPE_DICTIONARY and c[k].has("channel"):
			return String(c[k].channel)
		var r2 := _anchor_channel(c[k])
		if r2 != "":
			return r2
	return ""

# Canal de una plantilla de rastro: sufijo del tpl (".col"/".kw"/".kh"...) o when.anchor.channel. "" = cualquiera.
static func tpl_channel(t: Dictionary) -> String:
	var name := String(t.get("tpl", ""))
	if name.begins_with("K-") and not name.contains("."):
		return name
	if name.contains("."):
		var last := name.get_slice(".", name.get_slice_count(".") - 1)
		if CH_SUFFIX.has(last):
			return CH_SUFFIX[last]
	return _anchor_channel(t.get("when"))

# Efecto con el que se entrega la plantilla (columna | carta | noticia | ""): por si_canal del efecto.
static func tpl_op(r: Dictionary, t: Dictionary) -> String:
	var ch := tpl_channel(t)
	var fallback := ""
	for e in r.get("efecto", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var op := String(e.get("op", ""))
		if not ["carta", "columna", "noticia"].has(op):
			continue
		var sc = e.get("si_canal")
		if sc == null:
			if fallback == "":
				fallback = op
			continue
		var lst: Array = sc if typeof(sc) == TYPE_ARRAY else [sc]
		if ch != "" and lst.has(ch):
			return op
	return fallback

static func _rastro_set(repo, t: Dictionary, vars: Dictionary, only_tramo: String) -> Dictionary:
	var tags: Array = flat_tags(t.get("tags", []))
	var ents: Array = []
	var found := only_tramo == ""
	if t.has("texto"):
		var pt := _parse(repo, String(t.texto), vars)
		for tr in pt.get("tramos", []):
			if only_tramo != "" and String(tr.get("id", "")) != only_tramo:
				continue
			found = true
			tags.append_array(flat_tags(tr.tags))
			ents.append_array(_mentions(pt, int(tr.from), int(tr.to)))
		if only_tramo == "":
			ents.append_array(_mentions(pt, 0, String(pt.get("plain", "")).length()))
	ents.append_array(tag_ents(tags))
	return {"tags": uniq(tags), "ents": uniq(ents), "found": found}

static func _journal(repo, ref: String, copy: String) -> Dictionary:
	var d := _desc(ref, copy, "journal")
	var key := ref.substr(2)
	var dj = repo.lists().get("diary", {})
	var e = null
	if typeof(dj) == TYPE_DICTIONARY:
		e = dj.get(key)
		if e == null:
			e = dj.get(key.get_slice(".", 0))
	if typeof(e) != TYPE_DICTIONARY:
		d.missing = "lists.diary sin '%s'" % key
		return d
	d.tags = flat_tags(e.get("tags", []))
	var pt := _parse(repo, String(e.get("text", "")), {})
	d.ents = uniq([ACT] + _mentions(pt, 0, String(pt.get("plain", "")).length()))
	d.origin = "D36"
	d.cls = "I"
	d.exemplar = ""
	d._s = Av.journal_srcs(repo, key)
	return d

static func _ad(repo, ref: String, copy: String) -> Dictionary:
	var d := _desc(ref, copy, "ad")
	var aid := ref.substr(3)
	var dj = repo.lists().get("diary", {})
	if typeof(dj) == TYPE_DICTIONARY and typeof(dj.get("ad")) == TYPE_DICTIONARY:
		d.tags = flat_tags(dj.ad.get("tags", []))
	d.ents = [ACT]
	d.cls = "I"
	if copy != "":
		var cp: Dictionary = repo.copy(copy)
		if cp.is_empty():
			d.missing = "ejemplar %s inexistente" % copy
			return d
		d.origin = String(repo.doc(String(cp.doc)).get("origin", cp.doc))
		d.exemplar = "copy:" + copy
		d._s = Av.copy_srcs(repo, copy)
	else:
		d.origin = "AD." + aid
		d.exemplar = "ad:" + aid
		d._s = Av.ad_srcs(repo, aid)
	return d

# M:<doc> · M:<escena>.<x> · M:<reacción>.<x>: como Clipper.act_clip_measure, lee `measure` {entity, tags} y
# `paper_mm` del documento, de la escena (scene.measure; HC06 (f), el papel del club) o del doc de la reacción; sin
# measure o sin paper_mm la regla no mide (Clipper: sin_medida) y el fragmento queda pendiente.
static func _measure(repo, ref: String, copy: String, _vars: Dictionary) -> Dictionary:
	var x := ref.substr(2)
	var d := _desc(ref, copy, "measure")
	var doc: Dictionary = repo.doc(x)
	var m = null
	var paper = null
	if not doc.is_empty():
		m = doc.get("measure")
		paper = doc.get("paper_mm")
		if typeof(m) != TYPE_DICTIONARY:
			d.missing = "%s sin measure" % x
			return d
		d.origin = String(doc.get("origin", x))
		d.cls = _best_class(doc) if copy == "" else String(repo.copy(copy).get("copy", {}).get("class", "I"))
		d._s = Av.doc_srcs(repo, x, copy)
		d.exemplar = ("copy:" + copy) if copy != "" else ""
	elif x.contains("."):
		var sid := x.get_slice(".", 0)
		var sc: Dictionary = repo.scene(sid)
		var r: Dictionary = repo.reaction(sid)
		if not sc.is_empty():
			m = sc.get("measure")
			paper = sc.get("paper_mm")
			if typeof(m) != TYPE_DICTIONARY:
				d.missing = "escena %s sin measure (el recorte de medida lee scene.measure y scene.paper_mm)" % sid
				return d
			d.origin = String(sc.get("origin", "S." + sid))
			d.cls = "I"
			d.exemplar = "scene:" + sid
			d._s = Av.scene_srcs(repo, sid, {})
		elif not r.is_empty() and typeof(r.get("doc")) == TYPE_DICTIONARY and typeof(r.doc.get("measure")) == TYPE_DICTIONARY:
			m = r.doc.measure
			paper = r.doc.get("paper_mm")
			d.origin = "R." + sid
			d.cls = Av.react_cls(r)
			d.exemplar = "react:" + sid
			d._s = [Av.react_src(repo, sid)]
		else:
			d.missing = "medida %s: sin escena %s con measure%s" % [x, sid, "" if r.is_empty() else " ni doc.measure en la reacción " + sid]
			return d
	else:
		d.missing = "medida %s inexistente" % x
		return d
	if typeof(paper) != TYPE_ARRAY or paper.size() < 2:
		d.missing = "%s sin paper_mm: la regla no puede medir" % x
		return d
	var tags: Array = []
	for t in m.get("tags", []):
		var s := String(t)
		tags.append(s if s.contains(":") else "a:" + s)
	d.tags = tags
	d.ents = uniq([String(m.get("entity", ""))] + tag_ents(tags))
	return d

# ---------------- conclusiones ----------------
static func mandatory(repo) -> Array:
	var out: Array = []
	if repo.has_method("conclusions_meta"):
		for c in repo.conclusions_meta().get("mandatory", []):
			out.append(String(c))
	if out.is_empty():
		for c in repo.conclusions():
			if String(c.get("kind", "")) == "obligatoria":
				out.append(String(c.get("id", "")))
	return out

# Índice de la última pasada útil (informe final, schedule.reports[final]); por defecto 10.M.
static func final_idx(repo) -> int:
	for r in repo.schedule().get("reports", []):
		if typeof(r) == TYPE_DICTIONARY and bool(r.get("final", false)):
			var t := TimeKey.of(r.get("tk", ""))
			if t >= 0:
				return Av.idx_at_or_before(t)
	return TimeKey.idx(10, "M")

static func last_idx(repo, cid: String) -> int:
	var li := final_idx(repo)
	var v = repo.conclusion(cid).get("validate", {})
	if typeof(v) == TYPE_DICTIONARY and v.get("until") != null and String(v.get("until")) != "":
		var u := Av.idx_at_or_before(TimeKey.of(v.until))
		if u >= 0:
			li = mini(li, u)
	return li

static func channel_codes(repo) -> Array:
	var out: Array = []
	for m in repo.lists().get("medios", []):
		if typeof(m) == TYPE_DICTIONARY and String(m.get("ch", "")) != "":
			out.append(String(m.ch))
	return out

# "K-BMx" → "kbm", "K-T'" → "kt", "K-S" → "ks"; "" si no es un canal.
static func sub_channel(repo, key: String) -> String:
	var s := key.to_lower().replace("-", "")
	var best := ""
	for c in channel_codes(repo):
		if s.begins_with(c) and c.length() > best.length():
			best = c
	return best

static func is_pair_conclusion(c: Dictionary) -> bool:
	var subs = c.get("subroutes", {})
	if typeof(subs) != TYPE_DICTIONARY or subs.is_empty():
		return false
	for k in c.get("constraints", []):
		if typeof(k) == TYPE_DICTIONARY and k.has("distinct"):
			return true
	return false

static func _expand_ch(t: String, codes: Array) -> Array:
	var i := t.find("${ch:")
	if i < 0:
		return [t]
	var e := t.find("}", i)
	var out: Array = []
	for c in codes:
		out.append_array(_expand_ch(t.substr(0, i) + String(c) + t.substr(e + 1), codes))
	return out

# Etiquetas a: de la conclusión (valores sin prefijo): grupos (con ${ch:x} expandido) + tags_extra.
static func conc_tags(repo, cid: String) -> Array:
	var c: Dictionary = repo.conclusion(cid)
	var codes := channel_codes(repo)
	var out: Array = []
	for g in c.get("groups", []):
		for t in g.get("tags", []):
			out.append_array(_expand_ch(String(t), codes))
	for t in c.get("tags_extra", []):
		out.append(String(t))
	return uniq(out)

static func _deps_max(a: String, b: String) -> String:
	return a if int(DEPS_ORDER.get(a, 0)) >= int(DEPS_ORDER.get(b, 0)) else b

static func _bad(rid: String, why: String) -> Dictionary:
	return {"id": rid, "star": false, "star_decl": false, "deps": "opcional", "eligible": false, "from_idx": -1,
		"earliest": -1, "frags": [], "missing": [why], "subs": [], "implicit": false, "cut_by": []}

static func _rfrag(repo, spec, vars: Dictionary, subkey: String) -> Dictionary:
	if typeof(spec) != TYPE_DICTIONARY:
		var dd := _desc("?", "", "?")
		dd.missing = "fragmento mal formado"
		_finish(dd)
		return dd
	var d: Dictionary = resolve(repo, String(spec.get("ref", "")), String(spec.get("copy", "")), vars).duplicate()
	d["sub"] = subkey
	return d

static func _sub_frags(repo, key: String, sub: Dictionary) -> Array:
	var ch := sub_channel(repo, key)
	var vars := {"ch": ch} if ch != "" else {}
	var out: Array = []
	for spec in sub.get("frags", []):
		out.append(_rfrag(repo, spec, vars, key))
	return out

static func _mk_route(rid: String, frs: Array, deps: String, star_decl: bool, p_from, subs: Array, implicit: bool, cut_by) -> Dictionary:
	var missing: Array = []
	var star := not frs.is_empty()
	var earliest := 0
	for f in frs:
		if String(f.missing) != "":
			missing.append("%s: %s" % [f.ref, f.missing])
		if String(f.cls) != "I":
			star = false
		var lo := Av.lowest(int(f.mask))
		if lo < 0:
			earliest = 999
		else:
			earliest = maxi(earliest, lo)
	if not missing.is_empty():
		star = false
	var from_idx := earliest
	if p_from != null and String(p_from) != "":
		from_idx = TimeKey.idx_at_or_after(TimeKey.of(p_from))
	return {"id": rid, "star": star, "star_decl": star_decl, "deps": deps, "eligible": ELIGIBLE.has(deps),
		"from_idx": from_idx, "earliest": earliest, "frags": frs, "missing": missing, "subs": subs,
		"implicit": implicit, "cut_by": cut_by if typeof(cut_by) == TYPE_ARRAY else []}

static func _later_tk(a, b):
	if a == null or String(a) == "":
		return b
	if b == null or String(b) == "":
		return a
	return a if TimeKey.of(a) >= TimeKey.of(b) else b

static func _pair_route(repo, c: Dictionary, rid: String, a: String, b: String, decl: Dictionary, implicit: bool) -> Dictionary:
	var subs = c.get("subroutes", {})
	if not subs.has(a) or not subs.has(b):
		return _bad(rid, "subruta inexistente (%s, %s)" % [a, b])
	var sa: Dictionary = subs[a]
	var sb: Dictionary = subs[b]
	var frs := _sub_frags(repo, a, sa) + _sub_frags(repo, b, sb)
	var deps := String(decl.get("deps", _deps_max(String(sa.get("deps", "fija")), String(sb.get("deps", "fija")))))
	var star_decl := bool(decl.get("star", bool(sa.get("star", false)) and bool(sb.get("star", false))))
	var pfrom = decl.get("from", _later_tk(sa.get("from"), sb.get("from")))
	var cut: Array = []
	for x in [decl.get("cut_by", []), sa.get("cut_by", []), sb.get("cut_by", [])]:
		if typeof(x) == TYPE_ARRAY:
			cut.append_array(x)
	return _mk_route(rid, frs, deps, star_decl, pfrom, [a, b], implicit, uniq(cut))

static func _pk(a, b) -> String:
	var x := [String(a), String(b)]
	x.sort()
	return "+".join(x)

static func routes(repo, cid: String) -> Array:
	var rc := Av.sub(repo, "routes")
	if rc.has(cid):
		return rc[cid]
	var out: Array = []
	rc[cid] = out
	var c: Dictionary = repo.conclusion(cid)
	if c.is_empty():
		return out
	var subs = c.get("subroutes", {})
	if typeof(subs) != TYPE_DICTIONARY:
		subs = {}
	var seen := {}
	for r in c.get("routes", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rid := String(r.get("id", ""))
		if r.has("pair"):
			var pr: Array = r.pair
			if pr.size() != 2:
				out.append(_bad(rid, "pair debe nombrar 2 subrutas"))
				continue
			out.append(_pair_route(repo, c, rid, String(pr[0]), String(pr[1]), r, false))
			seen[_pk(pr[0], pr[1])] = true
		else:
			var frs: Array = []
			for spec in r.get("frags", []):
				frs.append(_rfrag(repo, spec, {}, ""))
			out.append(_mk_route(rid, frs, String(r.get("deps", "fija")), bool(r.get("star", false)), r.get("from"), [], false, r.get("cut_by", [])))
	if is_pair_conclusion(c):
		var ks := Av.sorted_keys(subs)
		for i in ks.size():
			for j in range(i + 1, ks.size()):
				var a := String(ks[i])
				var b := String(ks[j])
				if seen.has(_pk(a, b)):
					continue
				var ca := sub_channel(repo, a)
				if ca == "" or ca == sub_channel(repo, b):
					continue
				out.append(_pair_route(repo, c, "%s.%s+%s" % [cid, a, b], a, b, {}, true))
	return out

# Ruta o subruta por id ("C2.R4", "C10.Id"). {} si no existe.
static func route_by_id(repo, id: String) -> Dictionary:
	var cid := id.get_slice(".", 0)
	for r in routes(repo, cid):
		if String(r.id) == id:
			return r
	var c: Dictionary = repo.conclusion(cid)
	var sk := id.substr(cid.length() + 1)
	var subs = c.get("subroutes", {})
	if typeof(subs) == TYPE_DICTIONARY and subs.has(sk):
		var s: Dictionary = subs[sk]
		return _mk_route(id, _sub_frags(repo, sk, s), String(s.get("deps", "fija")), bool(s.get("star", false)), s.get("from"), [sk], false, s.get("cut_by", []))
	return {}

static func common_exemplars(rs: Array) -> Array:
	if rs.is_empty():
		return []
	var common: Array = []
	for f in rs[0].frags:
		if String(f.exemplar) != "" and not common.has(f.exemplar):
			common.append(f.exemplar)
	for i in range(1, rs.size()):
		var have := {}
		for f in rs[i].frags:
			have[String(f.exemplar)] = true
		var keep: Array = []
		for e in common:
			if have.has(e):
				keep.append(e)
		common = keep
	return common

# ---------------- T1 (por conclusión) ----------------
static func _ch_fields(c: Dictionary) -> Array:
	var out: Array = []
	for g in c.get("groups", []):
		for t in g.get("tags", []):
			var s := String(t)
			var i := s.find("${ch:")
			while i >= 0:
				var e := s.find("}", i)
				var f := s.substr(i + 5, e - i - 5)
				if not out.has(f):
					out.append(f)
				i = s.find("${ch:", e)
	return out

static func _subst(t: String, asg: Dictionary) -> String:
	for f in asg:
		t = t.replace("${ch:" + String(f) + "}", String(asg[f]))
	return t

static func _assignments(fields: Array, codes: Array) -> Array:
	if fields.is_empty():
		return [{}]
	var rest := _assignments(fields.slice(1), codes)
	var out: Array = []
	for c in codes:
		for r in rest:
			if r.values().has(c):
				continue
			var x: Dictionary = r.duplicate()
			x[fields[0]] = c
			out.append(x)
	return out

# Grupos sin cubrir por la ruta (mejor asignación de canales). [] = cubre todo.
static func missing_groups(repo, c: Dictionary, r: Dictionary) -> Array:
	var fields := _ch_fields(c)
	var codes: Array = channel_codes(repo)
	if r.subs.size() == 2:
		var sc: Array = [sub_channel(repo, r.subs[0]), sub_channel(repo, r.subs[1])]
		if sc[0] != "" and sc[1] != "":
			codes = sc
	var asgs := _assignments(fields, codes)
	if asgs.is_empty():
		asgs = [{}]
	var have := {}
	for f in r.frags:
		for t in f.tags:
			have[String(t)] = true
	var best = null
	for asg in asgs:
		var miss: Array = []
		for g in c.get("groups", []):
			var okg := false
			for t in g.get("tags", []):
				if have.has("a:" + _subst(String(t), asg)):
					okg = true
					break
			if not okg:
				miss.append(String(g.get("id", "?")))
		if miss.is_empty():
			return []
		if best == null or miss.size() < best.size():
			best = miss
	return best if best != null else []

static func _find(p: Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i

# Grafo de fragmentos conexo con aristas «comparten entidad de keys» / «entidad de un kind listado» / «mismo origen».
static func linked(repo, c: Dictionary, frs: Array) -> bool:
	var n := frs.size()
	if n <= 1:
		return true
	var keys = c.get("keys", {})
	var kents: Array = keys.get("entities", []) if typeof(keys) == TYPE_DICTIONARY else []
	var kinds: Array = keys.get("kinds", []) if typeof(keys) == TYPE_DICTIONARY else []
	var p: Array = []
	for i in n:
		p.append(i)
	for i in n:
		for j in range(i + 1, n):
			var a: Dictionary = frs[i]
			var b: Dictionary = frs[j]
			var edge := String(a.origin) == String(b.origin) and String(a.origin) != ""
			if not edge:
				for e in a.ents:
					if b.ents.has(e) and (kents.has(e) or kinds.has(ent_kind(repo, String(e)))):
						edge = true
						break
			if edge:
				p[_find(p, i)] = _find(p, j)
	var r0 := _find(p, 0)
	for i in n:
		if _find(p, i) != r0:
			return false
	return true

static func route_errors(repo, c: Dictionary, r: Dictionary, ctags: Array, last: int) -> Array:
	var errs: Array = []
	var origins := {}
	for f in r.frags:
		origins[String(f.origin)] = true
	if origins.size() < 2:
		errs.append("un solo origen (%s)" % ", ".join(PackedStringArray(origins.keys())))
	if not linked(repo, c, r.frags):
		errs.append("fragmentos no enlazados por claves ni por origen")
	var mg := missing_groups(repo, c, r)
	if not mg.is_empty():
		errs.append("no cubre los grupos %s" % str(mg))
	for f in r.frags:
		var has_tag := false
		for t in f.tags:
			var s := String(t)
			if s.begins_with("a:") and ctags.has(s.substr(2)):
				has_tag = true
			if s == "f:refutado":
				errs.append("%s lleva f:refutado" % f.ref)
		if not has_tag:
			errs.append("%s sin etiqueta de la conclusión" % f.ref)
		if int(f.mask) & Av.range_mask(0, last) == 0:
			errs.append("%s no se puede obtener antes de la última pasada útil" % f.ref)
	if int(r.from_idx) > last:
		errs.append("«desde» (%s) después de la última pasada útil" % _lab(int(r.from_idx)))
	return errs

static func _lab(i: int) -> String:
	var x := TimeKey.from_idx(i)
	if x.is_empty():
		return "fuera de calendario"
	return TimeKey.label(TimeKey.tk(x.day, x.slot))

# T1 de una conclusión: {cid, errors, pending, notes}.
static func lint(repo, cid: String) -> Dictionary:
	var res := {"cid": cid, "errors": [], "pending": [], "notes": []}
	var c: Dictionary = repo.conclusion(cid)
	if c.is_empty():
		res.pending.append("%s: conclusión inexistente" % cid)
		return res
	var rs := routes(repo, cid)
	if rs.is_empty():
		res.errors.append("%s: sin rutas" % cid)
		return res
	var last := last_idx(repo, cid)
	var ctags := conc_tags(repo, cid)
	var stars: Array = []
	for r in rs:
		if not r.missing.is_empty():
			for m in r.missing:
				res.pending.append("%s %s: %s" % [cid, r.id, m])
			continue
		for e in route_errors(repo, c, r, ctags, last):
			res.errors.append("%s %s: %s" % [cid, r.id, e])
		if bool(r.star_decl) and not bool(r.star):
			var bad: Array = []
			for f in r.frags:
				if String(f.cls) != "I":
					bad.append("%s (%s)" % [f.ref, f.cls])
			res.errors.append("%s %s: declarada ★ con fragmentos no I: %s" % [cid, r.id, ", ".join(PackedStringArray(bad))])
		for f in r.frags:
			for nt in f.notes:
				if not res.notes.has(nt):
					res.notes.append(nt)
		if bool(r.star) and bool(r.eligible):
			stars.append(r)
	if not res.pending.is_empty():
		return res
	if not mandatory(repo).has(cid):
		# conclusiones opcionales (C10a, C14): cada ruta debe valer (arriba), pero la invariante de ≥2 rutas ★ sin
		# ejemplar común es sólo de las obligatorias (GDD §10.3, T1); C14 tiene una sola ★ a propósito (C14.R1 usa ⚠).
		if stars.is_empty():
			res.notes.append("%s: opcional sin ruta ★" % cid)
		return res
	if stars.size() < 2:
		res.errors.append("%s: %d ruta(s) ★ (sólo-I, deps fija/columna/garantizada); se exigen ≥2" % [cid, stars.size()])
	else:
		var common := common_exemplars(stars)
		if not common.is_empty():
			res.errors.append("%s: todas las rutas ★ comparten %s" % [cid, str(common)])
		if is_pair_conclusion(c):
			var sets := {}
			for r in stars:
				var s: Array = r.subs.duplicate()
				s.sort()
				sets[str(s)] = true
			if sets.size() < 2:
				res.errors.append("%s: menos de 2 pares ★ que difieran en una subruta" % cid)
	return res

# ---------------- universo de fragmentos y T17 ----------------
static func all_frags(repo) -> Array:
	var g := Av.gcache(repo)
	if g.has("all_frags"):
		return g["all_frags"]
	var out: Array = []
	for did in Av.sorted_keys(repo.docs()):
		for p in repo.doc(String(did)).get("parts", []):
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var pt: Dictionary = repo.parsed(String(did), String(p.get("id", "")))
			for t in pt.get("tramos", []):
				if String(t.get("id", "")) != "":
					out.append(resolve(repo, "%s#%s" % [did, t.id]))
	for pid in Av.sorted_keys(repo.places()):
		var pl: Dictionary = repo.place(String(pid))
		for nd in pl.get("nodes", []):
			if typeof(nd) == TYPE_DICTIONARY:
				out.append(resolve(repo, "N:%s.%s" % [pid, nd.get("id", "")]))
		var vs = pl.get("variants", {})
		if typeof(vs) == TYPE_DICTIONARY:
			for v in Av.sorted_keys(vs):
				for nd in vs[v].get("add_nodes", []):
					if typeof(nd) == TYPE_DICTIONARY:
						out.append(resolve(repo, "N:%s.%s.%s" % [pid, v, nd.get("id", "")]))
	if repo.has_method("plates"):
		for pid in Av.sorted_keys(repo.plates()):
			for nd in repo.plate(String(pid)).get("nodes", []):
				if typeof(nd) == TYPE_DICTIONARY:
					out.append(resolve(repo, "N:%s.%s" % [pid, nd.get("id", "")]))
	if repo.has_method("scenes"):
		for sid in Av.sorted_keys(repo.scenes()):
			var s: Dictionary = repo.scene(String(sid))
			var lines: Array = s.get("lines", []).duplicate()
			for v in s.get("variants", []):
				if typeof(v) == TYPE_DICTIONARY:
					lines.append_array(v.get("append", []))
			for l in lines:
				if typeof(l) != TYPE_DICTIONARY:
					continue
				if l.has("gen"):
					for ch in Av.sorted_keys(l.get("tpl", {})):
						out.append(resolve(repo, "S:%s.%s_%s" % [sid, l.get("id", ""), ch]))
				else:
					out.append(resolve(repo, "S:%s.%s" % [sid, l.get("id", "")]))
	if repo.has_method("dialogues"):
		for ch in Av.sorted_keys(repo.dialogues()):
			for l in repo.dialogue(String(ch)).get("lines", []):
				if typeof(l) == TYPE_DICTIONARY:
					out.append(resolve(repo, "L:%s.%s" % [ch, l.get("id", "")]))
	for r in repo.reactions():
		for t in r.get("rastro", []):
			if typeof(t) == TYPE_DICTIONARY:
				out.append(resolve(repo, "R:%s.%s" % [r.get("id", ""), t.get("tpl", "")]))
	g["all_frags"] = out
	return out

# Pistas falsas declaradas por W2-STRUCT en conclusions.json `_pistas_falsas` (nota de autor: lista de GDD§10.5 con
# sus orígenes y refutaciones). [] si el repo no expone el archivo.
static func declared_false_leads(repo) -> Array:
	if not repo.has_method("files"):
		return []
	var cf = repo.files().get("conclusions.json", {})
	var pf = cf.get("_pistas_falsas", []) if typeof(cf) == TYPE_DICTIONARY else []
	return pf if typeof(pf) == TYPE_ARRAY else []

static func _lead_of(tag: String) -> String:
	if tag.begins_with("a:falsa_"):
		return tag.substr(8)
	if tag.begins_with("a:") and not tag.begins_with("a:refuta_"):
		return tag.substr(2)
	return ""

# T17: toda pista falsa con ≥2 refutaciones alcanzables (≥2 orígenes), ninguna ⚠ (w:).
# Convención (la de W2-STRUCT): pista falsa `f:refutado` + `a:falsa_<x>` (también se acepta `a:<x>`); refutación
#   `a:refuta_<x>`. Si conclusions.json declara `_pistas_falsas`, sus refs se resuelven: las que faltan son contenido
#   pendiente (res.pending) y las presentes deben llevar la etiqueta; una pista con refs pendientes no falla por conteo.
static func false_leads(repo) -> Dictionary:
	var res := {"leads": {}, "errors": [], "falsas": [], "unreachable": [], "pending": []}
	var upto := Av.range_mask(0, final_idx(repo))
	var refs := {}
	var falsas: Array = []
	var pend_x := {}
	for d in all_frags(repo):
		if String(d.missing) != "":
			continue
		var tags: Array = d.tags_any
		for t in tags:
			var s := String(t)
			if s.begins_with("a:refuta_"):
				var x := s.substr(9)
				if not refs.has(x):
					refs[x] = []
				refs[x].append(d)
		if tags.has("f:refutado"):
			falsas.append(d)
	for decl in declared_false_leads(repo):
		if typeof(decl) != TYPE_DICTIONARY:
			continue
		var lid := String(decl.get("id", ""))
		var x2 := lid.trim_prefix("falsa_")
		if not refs.has(x2):
			refs[x2] = []
		for ref in decl.get("refutaciones", []):
			var dd := resolve(repo, String(ref))
			if String(dd.missing) != "":
				res.pending.append("%s: refutación %s: %s" % [lid, ref, dd.missing])
				pend_x[x2] = true
				continue
			if not dd.tags_any.has("a:refuta_" + x2):
				res.errors.append("%s: la refutación %s no lleva a:refuta_%s" % [lid, ref, x2])
				continue
		for o in decl.get("origen", []):
			var os := String(o)
			if not os.contains("#") and not os.contains(":"):
				if repo.doc(os).is_empty():
					res.pending.append("%s: origen %s (documento) inexistente" % [lid, os])
				continue
			var od := resolve(repo, os)
			if String(od.missing) != "":
				res.pending.append("%s: origen %s: %s" % [lid, os, od.missing])
			elif not od.tags_any.has("f:refutado"):
				res.errors.append("%s: el origen %s no lleva f:refutado" % [lid, os])
	for x in Av.sorted_keys(refs):
		var valid: Array = []
		var origins := {}
		for d in refs[x]:
			var warn := false
			for t in d.tags_any:
				if String(t).begins_with("w:"):
					warn = true
			if warn:
				res.errors.append("refutación ⚠ (w:) de '%s': %s" % [x, d.ref])
				continue
			if int(d.mask) & upto == 0:
				res.unreachable.append(String(d.ref))
				continue
			if not valid.has(d.ref):
				valid.append(d.ref)
			origins[String(d.origin)] = true
		var okx := valid.size() >= 2 and origins.size() >= 2
		res.leads[x] = {"refs": valid, "origins": Av.sorted_keys(origins), "ok": okx, "pending": pend_x.has(x)}
		if not okx:
			var msg := "pista falsa '%s': %d refutación(es) alcanzable(s) de %d origen(es); se exigen ≥2 y ≥2" % [x, valid.size(), origins.size()]
			if pend_x.has(x):
				res.pending.append(msg + " (refutaciones pendientes de contenido)")
			else:
				res.errors.append(msg)
	for d in falsas:
		var lead := ""
		var pend := ""
		for t in d.tags_any:
			var x3 := _lead_of(String(t))
			if x3 == "" or not res.leads.has(x3):
				continue
			if res.leads[x3].ok:
				lead = x3
			elif res.leads[x3].pending:
				pend = x3
		res.falsas.append({"ref": d.ref, "lead": lead})
		if lead == "" and pend != "":
			res.pending.append("pista falsa %s: refutaciones de '%s' pendientes" % [d.ref, pend])
		elif lead == "":
			res.errors.append("pista falsa %s (f:refutado) sin refutaciones a:refuta_<x> de ninguna de sus etiquetas a:" % d.ref)
	return res
