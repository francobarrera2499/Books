# core/graph/route_db.gd — rutas y fragmentos (contrato de refs §4.8; modelo §5.6; GDD_v3 §2). Dueño: CORE-EXPEDIENTE.
# v3: lee data/dossier.json. Una «unidad» es una variante de una pregunta: id = "Q1" (variante principal) o "Q8.B"
#   (otra variante): {id, q, variant, principal, obligatoria, invariante, groups:[{id, tags}] (2), keys (claves),
#   routes (rutas), validate {from, until}, answers}. Sin subrutas, pares ni refs M:.
# Contrato: routes(repo, qid, variant := "") -> [{id, star, deps, from_idx, frags:[{ref, copy, kind, cls, place, area, mask}]}]
#           frag(repo, ref) -> {ref, kind, tags, ents, origin, cls, copies}
# Extensiones: unit(repo, uid), units(repo), questions_units, resolve(repo, ref, copy, vars) (descriptor completo con
#   claves de fuentes), route_by_id, mandatory (principales obligatorias con invariante normal), final_idx, last_idx,
#   conc_tags, common_exemplars, lint (T1), all_frags (universo de fragmentos de data/) y false_leads (T17).
# Ruta: {id, star (calculado: todo fragmento de clase I y resuelto), star_decl, deps, eligible (deps ∈ fija/columna/
#   garantizada, §5.6 cond. 3), from_idx, earliest, frags, missing:[...], cut_by}.
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
	# GDD_v3 §1.8: las etiquetas del rastro que declara la silueta (HC02: a:chicos_de_holmes, e:muchacho…), como
	# Clipper.node_def
	for t in load("res://core/deduction/clipper.gd").sil_rastro_tags(repo, who):
		var ts := String(t)
		if ts.begins_with("e:"):
			if not d.ents.has(ts.substr(2)):
				d.ents.append(ts.substr(2))
		elif not d.tags.has(ts):
			d.tags.append(ts)
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
		# el nodo puede estar en varias variantes (GDD_v3 §4.3: «techos», «registrada+techos»): vale cualquiera de ellas;
		# una variante compuesta («a+b», Effects la arma con dos alterar_lugar) existe cuando existen sus partes
		var tb := 0
		var vs = od.get("variants", {})
		var names: Array = [variant]
		if typeof(vs) == TYPE_DICTIONARY and String(restp[0]) == nid:
			for v in Av.sorted_keys(vs):
				if typeof(vs[v]) != TYPE_DICTIONARY or names.has(String(v)):
					continue
				for lst in ["add_nodes", "nodes"]:
					for n in vs[v].get(lst, []):
						if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == nid and not names.has(String(v)):
							names.append(String(v))
		for vn in names:
			var vt := -1
			for vpart in String(vn).split("+"):
				var vtb := _variant_tb(repo, owner, String(vpart))
				vt = vtb if vt < 0 else (vt & vtb)
			tb |= maxi(vt, 0)
		d._s = Av.node_srcs(repo, owner, node, false, tb)
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
	# testimonio de campo (C) salvo que la línea se declare inmutable ("cls": "I", GDD §10.1; p. ej. L:crane.pasos_techo,
	# Q8.R2 ★ de GDD_v3 §2.1: a Crane no lo corta ninguna reacción). T2 protege los fragmentos I.
	d.cls = "I" if String(line.get("cls", "C")) == "I" else "C"
	d.char = real
	d.exemplar = "char:" + real
	d._s = Av.char_srcs(repo, real, [line.get("when", {})], "line", "." + lid, String(d.cls))
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

# ---------------- unidades (GDD_v3 §1.7) ----------------
static func _q_principal(q: Dictionary) -> Dictionary:
	for v in q.get("variantes", []):
		if typeof(v) == TYPE_DICTIONARY and bool(v.get("principal", false)):
			return v
	var vs: Array = q.get("variantes", [])
	return vs[0] if not vs.is_empty() and typeof(vs[0]) == TYPE_DICTIONARY else {}

static func _questions(repo) -> Array:
	return repo.questions() if repo.has_method("questions") else []

# Unidad de una pregunta y variante ("" = principal).
static func uid_of(repo, qid: String, variant := "") -> String:
	if variant == "":
		return qid
	var q: Dictionary = repo.question(qid) if repo.has_method("question") else {}
	if String(_q_principal(q).get("id", "")) == variant:
		return qid
	return "%s.%s" % [qid, variant]

static func unit(repo, uid: String) -> Dictionary:
	var uc := Av.sub(repo, "units")
	if uc.has(uid):
		return uc[uid]
	var out := {}
	var qid := uid.get_slice(".", 0)
	var vid := uid.substr(qid.length() + 1) if uid.contains(".") else ""
	var q: Dictionary = repo.question(qid) if repo.has_method("question") else {}
	if not q.is_empty():
		var v: Dictionary = _q_principal(q) if vid == "" else {}
		if vid != "":
			for x in q.get("variantes", []):
				if typeof(x) == TYPE_DICTIONARY and String(x.get("id", "")) == vid:
					v = x
		if not v.is_empty():
			var w = v.get("valida", {})
			if typeof(w) != TYPE_DICTIONARY:
				w = {}
			out = {"id": uid, "q": qid, "variant": String(v.get("id", "")), "principal": bool(v.get("principal", false)),
				"obligatoria": bool(q.get("obligatoria", false)), "invariante": String(q.get("invariante", "normal")),
				"groups": v.get("grupos", []), "keys": v.get("claves", {}), "routes": v.get("rutas", []),
				"validate": {"from": w.get("desde"), "until": w.get("hasta")}, "answers": v.get("respuestas", [])}
	uc[uid] = out
	return out

# Todas las unidades (todas las variantes de todas las preguntas), en orden.
static func units(repo) -> Array:
	var out: Array = []
	for q in _questions(repo):
		for v in q.get("variantes", []):
			if typeof(v) == TYPE_DICTIONARY:
				out.append(uid_of(repo, String(q.id), String(v.get("id", ""))))
	return out

# Unidades de una pregunta (todas sus variantes).
static func question_units(repo, qid: String) -> Array:
	var out: Array = []
	for u in units(repo):
		if String(u).get_slice(".", 0) == qid:
			out.append(u)
	return out

# Invariante «normal» (T3, D1): variantes principales de las preguntas obligatorias con invariante normal (Q8, que nace
# de una reacción, se evalúa aparte: desde_nacimiento, §2.2).
static func mandatory(repo) -> Array:
	var out: Array = []
	for q in _questions(repo):
		if bool(q.get("obligatoria", false)) and String(q.get("invariante", "normal")) == "normal":
			out.append(String(q.id))
	return out

# Preguntas con invariante desde_nacimiento (Q8).
static func from_birth(repo) -> Array:
	var out: Array = []
	for q in _questions(repo):
		if bool(q.get("obligatoria", false)) and String(q.get("invariante", "normal")) == "desde_nacimiento":
			out.append(String(q.id))
	return out

# Índice de la última pasada útil (informe final, schedule.reports[final]); por defecto 10.M.
static func final_idx(repo) -> int:
	for r in repo.schedule().get("reports", []):
		if typeof(r) == TYPE_DICTIONARY and bool(r.get("final", false)):
			var t := TimeKey.of(r.get("tk", ""))
			if t >= 0:
				return Av.idx_at_or_before(t)
	return TimeKey.idx(10, "M")

static func last_idx(repo, uid: String) -> int:
	var li := final_idx(repo)
	var v = unit(repo, uid).get("validate", {})
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

# Etiquetas a: de la unidad (valores sin prefijo): las de sus dos grupos.
static func conc_tags(repo, uid: String) -> Array:
	var out: Array = []
	for g in unit(repo, uid).get("groups", []):
		for t in g.get("tags", []):
			out.append(String(t))
	return uniq(out)

# Etiquetas de todas las variantes de una pregunta (ley de la huella, T5).
static func question_tags(repo, qid: String) -> Array:
	var out: Array = []
	for u in question_units(repo, qid):
		out.append_array(conc_tags(repo, String(u)))
	return uniq(out)

static func _bad(rid: String, why: String) -> Dictionary:
	return {"id": rid, "star": false, "star_decl": false, "deps": "opcional", "eligible": false, "from_idx": -1,
		"earliest": -1, "frags": [], "missing": [why], "cut_by": []}

static func _rfrag(repo, spec) -> Dictionary:
	if typeof(spec) != TYPE_DICTIONARY:
		var dd := _desc("?", "", "?")
		dd.missing = "fragmento mal formado"
		_finish(dd)
		return dd
	var ref := String(spec.get("ref", ""))
	var d: Dictionary = resolve(repo, ref, String(spec.get("copy", ""))).duplicate()
	# GDD_v3 §3.5: un documento inactivo no se carga; nombrarlo es error de datos (no contenido pendiente)
	var did := ref.get_slice("#", 0) if ref.contains("#") and not ref.contains(":") else ""
	var cdid := String(spec.get("copy", "")).get_slice("@", 0) if String(spec.get("copy", "")).contains("@") else ""
	for x in [did, cdid]:
		if x != "" and repo.has_method("is_inactive") and repo.is_inactive(x):
			d["inactive"] = x
	return d

static func _mk_route(rid: String, frs: Array, deps: String, star_decl: bool, p_from, cut_by) -> Dictionary:
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
		"from_idx": from_idx, "earliest": earliest, "frags": frs, "missing": missing,
		"cut_by": cut_by if typeof(cut_by) == TYPE_ARRAY else []}

# Rutas de una pregunta y variante ("" = principal) o de una unidad ("Q8.B").
static func routes(repo, qid: String, variant := "") -> Array:
	var uid := uid_of(repo, qid, variant) if not qid.contains(".") else qid
	var rc := Av.sub(repo, "routes")
	if rc.has(uid):
		return rc[uid]
	var out: Array = []
	rc[uid] = out
	var u := unit(repo, uid)
	if u.is_empty():
		return out
	for r in u.get("routes", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var frs: Array = []
		for spec in r.get("frags", []):
			frs.append(_rfrag(repo, spec))
		var mr := _mk_route(String(r.get("id", "")), frs, String(r.get("deps", "fija")), bool(r.get("star", false)), r.get("from"), r.get("cut_by", []))
		# Una ruta con errores de datos (T1: no enlazada, no cubre los dos grupos, un origen…) no la puede cerrar el jugador:
		# no cuenta para la invariante, la factibilidad ni el oráculo de los bots (T1 la informa).
		mr["data_errors"] = []
		if (mr.missing as Array).is_empty():
			mr.data_errors = route_errors(repo, u, mr, [], last_idx(repo, uid))
			if not (mr.data_errors as Array).is_empty():
				mr.eligible = false
				mr.star = false
		out.append(mr)
	return out

# Ruta por id ("Q1.R4", "Q9.Ca"), en cualquier variante. {} si no existe.
static func route_by_id(repo, id: String) -> Dictionary:
	var qid := id.get_slice(".", 0)
	for u in question_units(repo, qid):
		for r in routes(repo, String(u)):
			if String(r.id) == id:
				return r
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

# Escenas comunes a todas las rutas (GDD_v3 §2.2 cond. 4: «ningún ejemplar ni escena común»).
static func common_scenes(rs: Array) -> Array:
	var sets: Array = []
	for r in rs:
		var sc := {}
		for f in r.frags:
			var ex := String(f.exemplar)
			if ex.begins_with("scene:"):
				sc[ex] = true
		sets.append(sc)
	if sets.is_empty():
		return []
	var out: Array = []
	for k in Av.sorted_keys(sets[0]):
		var all := true
		for i in range(1, sets.size()):
			if not sets[i].has(k):
				all = false
		if all:
			out.append(k)
	return out

# ---------------- T1 (por unidad) ----------------
static func _has_group(tags: Array, group: Array) -> bool:
	for t in group:
		var s := String(t)
		if tags.has(s if s.contains(":") else "a:" + s):
			return true
	return false

# ¿Cubren los dos fragmentos los dos grupos (en alguna asignación)? [] = sí; si no, los grupos que faltan.
static func missing_groups(repo, c: Dictionary, r: Dictionary) -> Array:
	var gs: Array = c.get("groups", [])
	if gs.size() != 2 or r.frags.size() != 2:
		var ids: Array = []
		for g in gs:
			ids.append(String(g.get("id", "?")))
		return ids
	var g1: Array = gs[0].get("tags", [])
	var g2: Array = gs[1].get("tags", [])
	var ta: Array = r.frags[0].tags
	var tb: Array = r.frags[1].tags
	if (_has_group(ta, g1) and _has_group(tb, g2)) or (_has_group(ta, g2) and _has_group(tb, g1)):
		return []
	var miss: Array = []
	if not (_has_group(ta, g1) or _has_group(tb, g1)):
		miss.append(String(gs[0].get("id", "?")))
	if not (_has_group(ta, g2) or _has_group(tb, g2)):
		miss.append(String(gs[1].get("id", "?")))
	if miss.is_empty():
		miss.append("%s/%s en el mismo fragmento" % [gs[0].get("id", "?"), gs[1].get("id", "?")])
	return miss

# Enlace (GDD_v3 §1.6 cond. 5): los dos comparten una entidad de keys.entities, o ambos llevan una entidad de un kind
# de keys.kinds. (Con más de dos fragmentos, grafo conexo con esas aristas.)
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
			var edge := false
			for e in a.ents:
				if b.ents.has(e) and kents.has(e):
					edge = true
					break
			if not edge and not kinds.is_empty():
				var ka := false
				var kb := false
				for e in a.ents:
					if kinds.has(ent_kind(repo, String(e))):
						ka = true
				for e in b.ents:
					if kinds.has(ent_kind(repo, String(e))):
						kb = true
				edge = ka and kb
			if edge:
				p[_find(p, i)] = _find(p, j)
	var r0 := _find(p, 0)
	for i in n:
		if _find(p, i) != r0:
			return false
	return true

static func _find(p: Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i

static func route_errors(repo, c: Dictionary, r: Dictionary, ctags: Array, last: int) -> Array:
	var errs: Array = []
	if r.frags.size() != 2:
		errs.append("%d fragmentos (se exigen exactamente 2)" % r.frags.size())
	var origins := {}
	for f in r.frags:
		origins[String(f.origin)] = true
	if origins.size() < 2:
		errs.append("un solo origen (%s)" % ", ".join(PackedStringArray(origins.keys())))
	if not linked(repo, c, r.frags):
		errs.append("fragmentos no enlazados por claves")
	var mg := missing_groups(repo, c, r)
	if not mg.is_empty():
		errs.append("no cubre los grupos %s" % str(mg))
	for f in r.frags:
		if f.has("inactive"):
			errs.append("%s nombra un documento inactivo (%s)" % [f.ref, f.inactive])
		for t in f.tags:
			if String(t) == "f:refutado":
				errs.append("%s lleva f:refutado" % f.ref)
		if int(f.mask) & Av.range_mask(0, last) == 0:
			errs.append("%s no se puede obtener antes del informe final" % f.ref)
	if int(r.from_idx) > last:
		errs.append("«desde» (%s) después del informe final" % _lab(int(r.from_idx)))
	return errs

static func _lab(i: int) -> String:
	var x := TimeKey.from_idx(i)
	if x.is_empty():
		return "fuera de calendario"
	return TimeKey.label(TimeKey.tk(x.day, x.slot))

# T1 de una unidad: {cid, errors, pending, notes}. Rutas que nombran contenido que todavía no existe = pending.
static func lint(repo, uid: String) -> Dictionary:
	var res := {"cid": uid, "errors": [], "pending": [], "notes": []}
	var c := unit(repo, uid)
	if c.is_empty():
		res.pending.append("%s: pregunta o variante inexistente" % uid)
		return res
	var rs := routes(repo, uid)
	if rs.is_empty():
		res.errors.append("%s: sin rutas" % uid)
		return res
	var last := last_idx(repo, uid)
	var ctags := conc_tags(repo, uid)
	var stars: Array = []
	for r in rs:
		var inact := false
		for f in r.frags:
			if f.has("inactive"):
				inact = true
				res.errors.append("%s %s: %s nombra un documento inactivo (%s)" % [uid, r.id, f.ref, f.inactive])
		if inact:
			continue
		if not r.missing.is_empty():
			for m in r.missing:
				res.pending.append("%s %s: %s" % [uid, r.id, m])
			continue
		for e in route_errors(repo, c, r, ctags, last):
			res.errors.append("%s %s: %s" % [uid, r.id, e])
		if bool(r.star_decl) and not bool(r.star):
			var bad: Array = []
			for f in r.frags:
				if String(f.cls) != "I":
					bad.append("%s (%s)" % [f.ref, f.cls])
			if not bad.is_empty():   # (una ★ con errores de datos ya figura arriba)
				res.errors.append("%s %s: declarada ★ con fragmentos no I: %s" % [uid, r.id, ", ".join(PackedStringArray(bad))])
		for f in r.frags:
			for nt in f.notes:
				if not res.notes.has(nt):
					res.notes.append(nt)
		if bool(r.star) and bool(r.eligible):
			stars.append(r)
	if not res.pending.is_empty():
		return res
	if not bool(c.get("principal", false)) or not bool(c.get("obligatoria", false)) or String(c.get("invariante", "normal")) != "normal":
		# variantes no principales y Q8 (desde_nacimiento): cada ruta debe valer (arriba); la exigencia de ≥2 rutas ★ sin
		# ejemplar común es de las principales con invariante normal (GDD_v3 §2.4 T1).
		if stars.is_empty() and bool(c.get("principal", false)):
			res.notes.append("%s: sin ruta ★ elegible" % uid)
		return res
	if stars.size() < 2:
		res.errors.append("%s: %d ruta(s) ★ (sólo-I, deps fija/columna/garantizada); se exigen ≥2" % [uid, stars.size()])
	else:
		# ≥2 rutas ★ sin ejemplar ni escena común (basta un par)
		var okp := false
		for i in stars.size():
			for j in range(i + 1, stars.size()):
				if common_exemplars([stars[i], stars[j]]).is_empty() and common_scenes([stars[i], stars[j]]).is_empty():
					okp = true
		if not okp:
			res.errors.append("%s: ningún par de rutas ★ sin ejemplar ni escena común" % uid)
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

# Pistas falsas declaradas en dossier.json `_pistas_falsas` (nota de autor: lista de GDD§10.5 con sus orígenes y
# refutaciones). [] si el repo no expone el archivo.
static func declared_false_leads(repo) -> Array:
	if not repo.has_method("files"):
		return []
	var cf = repo.files().get("dossier.json", {})
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
#   `a:refuta_<x>`. Si dossier.json declara `_pistas_falsas`, sus refs se resuelven: las que faltan son contenido
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
