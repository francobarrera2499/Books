# core/deduction/clipper.gd — recortes y pares (§5.1, GDD§8.1, §8.3). Dueño: W2-DED. Contrato: ARCHITECTURE §3.8.
# Recorte interno (st.ded.clips[id]; get_clip lo devuelve CON etiquetas):
#   {id, kind:"text"|"plate"|"measure", src_kind, text, ents:[id], tags:["a:x", ...], tramo, origin, passage, copy, cls,
#    doc, src_type, src_line, title, chron_date, place, view, part, block, from, to, caption, visible_cats, voice, mode,
#    visit, who, scene, plate, nodes, touched, labels:{ent: etiqueta}, tk}
#   origin = documento o escena (D03 recortado en Crane o en el BM es un solo origen); passage = origin|parte|tramo (C1).
# Par: st.ded.pairs[id] = {id, a, b, note}. Los pares no se anidan; un par vale por sus dos recortes.
# Resolución de fuentes (sim está aguas abajo de deduction: sin preload; load() en tiempo de llamada, sin ciclo):
#   doc   -> WorldModel.view_accessible(view) y WorldModel.view(view).pages[part][block] = {doc, origin, copy, parsed};
#            si view() no trae páginas: datos estáticos (repo.copy(view) o id de doc; part = índice o id de parte).
#   line / diary -> registro en st.world.diary | st.world.lines | st.scenes.lines con id o uid == ref:
#            {parsed | text (+act), origin | scene, who?, place?, cls?, src_type?, title?, voice?}. diario sin origen -> D36.
#   node  -> "<lámina>/<nodo>": examen del nodo como un único tramo con las etiquetas del nodo (T29, accesibilidad).
#   lámina -> instantánea st.world.plates[id] ({id, place, area, day, slot, variant, nodes, silhouettes, origin?, copy?,
#            doc?, act?, node_defs?}) o, si no existe, lámina fija de data/plates (id u origin) o "PL.<L>.<d>.<s>" estático.
#   Si WorldModel define clip_source(st, repo, src) -> {ok, err, parsed, doc, origin, copy, ...}, se usa primero.
# Costura de tests: test_access (Callable(st, repo, kind, ref) -> bool) decide accesibilidad y apaga WorldModel.
# Errores extra (además de §3.5): forma, no_esta (fuente/nodo inexistente), sin_medida, mismo (link a sí mismo),
#   no_existe (link/unlink), en_tinta (unlink de un par que sostiene un asiento en tinta).
extends RefCounted

const L = preload("res://core/util/log.gd")
const Markup = preload("res://core/text/markup.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Cond = preload("res://core/util/cond.gd")
const Index = preload("res://core/deduction/index.gd")

const WORLD_MODEL := "res://core/sim/world_model.gd"
const MAX_PLATE_FRAC := 0.125
const MAX_PLATE_HITS := 2
const MIN_COVER := 0.5
const MEMORY_MAX := 3
const MACHINE_ENTS := {"remington_cotter": "remington_s_alzada"}   # §4.4 machine
const KS_SIL := "wiggins"                                         # contrato §4.8: N:*.sil_wiggins (canal K-S)

static var test_access: Callable = Callable()

# ---------------- estado ----------------
static func init_state(st, repo) -> void:
	Index.ensure(st)
	# «A quién: yo (Lisle)» (GDD§10.4 C6, C10): el jugador se conoce; si la entidad existe entra al índice desde el inicio.
	if not repo.entity("lisle").is_empty():
		Index.add(st, repo, ["lisle"], false)

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}

static func _note(st, kind: String, payload: Dictionary) -> void:
	if st is Object and st.has_method("note"):
		st.note(kind, payload)

static func _new_id(st, kind: String, prefix: String, width: int) -> String:
	return st.next_id(kind, prefix, width)

static func _world(st) -> Dictionary:
	return st.world if typeof(st.world) == TYPE_DICTIONARY else {}

static func now_tk(st) -> int:
	var c = st.clock if typeof(st.clock) == TYPE_DICTIONARY else {}
	if c.is_empty():
		return 0
	var day := int(c.get("day", 0))
	var slot := String(c.get("slot", ""))
	if String(c.get("phase", "")) == "night":
		slot = "night"
	if not TimeKey.ORD.has(slot):
		return day * 10
	return TimeKey.tk(day, slot)

static func _visit_key(st) -> String:
	var v = _world(st).get("visit")
	if typeof(v) == TYPE_DICTIONARY:
		for k in ["id", "scene", "plate"]:
			if String(v.get(k, "")) != "":
				return String(v[k])
	elif typeof(v) == TYPE_STRING and v != "":
		return v
	return "tk:%d" % now_tk(st)

# ---------------- accesibilidad y fuentes ----------------
static func _wm() -> Script:
	return load(WORLD_MODEL)

# kind: doc (vista) · plate (lámina) · scene (escena en curso, medida) · line / diary (existencia del registro).
static func accessible(st, repo, kind: String, ref: String) -> bool:
	if test_access.is_valid():
		return bool(test_access.call(st, repo, kind, ref))
	match kind:
		"line", "diary":
			return true
		"plate":
			if plate_snapshot(st, repo, ref).is_empty():
				return false
			var plates = _world(st).get("plates", {})
			if typeof(plates) == TYPE_DICTIONARY and plates.has(ref):
				return true
			for v in _wm().call("accessible", st, repo):
				var did := String(v.get("doc", ""))
				if String(_doc_meta(st, repo, did).get("plate", "")) == ref:
					return true
			return false
		"scene":
			var vis = _world(st).get("visit", {})
			if typeof(vis) == TYPE_DICTIONARY and (String(vis.get("id", "")) == ref or String(vis.get("scene", "")) == ref):
				return true
			var vs = _world(st).get("visits", [])
			return typeof(vs) == TYPE_ARRAY and vs.has(ref)
	return bool(_wm().call("view_accessible", st, repo, ref))

static func _doc_meta(st, repo, did: String) -> Dictionary:
	var d: Dictionary = repo.doc(did)
	if not d.is_empty():
		return d
	# instancia runtime (W2-SIM): st.world.docs[iid] = {meta:{title, src_type, class, ...}, origin, ...}
	var docs = _world(st).get("docs", {})
	if typeof(docs) == TYPE_DICTIONARY and typeof(docs.get(did)) == TYPE_DICTIONARY:
		var inst: Dictionary = docs[did]
		var m: Dictionary = inst.get("meta", inst).duplicate() if typeof(inst.get("meta", inst)) == TYPE_DICTIONARY else {}
		if not m.has("origin") and inst.has("origin"):
			m["origin"] = inst.origin
		return m
	return {}

static func _src_type_label(repo, src_type: String, lugar := "") -> String:
	var t := String(repo.lists().get("src_types", {}).get(src_type, src_type))
	return Markup.fill(t, {"lugar": lugar})

static func _place_label(repo, place: String) -> String:
	if place == "":
		return ""
	var p: Dictionary = repo.place(place)
	if not p.is_empty():
		return String(p.get("name", place))
	var pl: Dictionary = repo.plate(place)
	if not pl.is_empty():
		return String(pl.get("name", place))
	var e: Dictionary = repo.entity(place)
	if not e.is_empty():
		return String(e.get("name", place))
	return place

# Resuelve la fuente de clip_text a un bloque normalizado:
# {ok, err, parsed, doc, origin, copy, cls, src_type, title, chron_date, src_line, view, part, block, mode, entity,
#  clip_entities, machine, visible_cats, voice, who, place, src_kind}
static func resolve_text_src(st, repo, src: Dictionary) -> Dictionary:
	var kind := String(src.get("kind", ""))
	var ref := String(src.get("ref", ""))
	if ref == "" or not ["doc", "line", "diary", "node"].has(kind):
		return _err("forma")
	if not test_access.is_valid() and _wm().has_method("clip_source"):
		var r = _wm().call("clip_source", st, repo, src)
		if typeof(r) == TYPE_DICTIONARY and not r.is_empty():
			if not bool(r.get("ok", true)):
				return _err(String(r.get("err", "inaccesible")))
			return _norm_block(st, repo, r, kind, ref)
	match kind:
		"doc":
			if not accessible(st, repo, "doc", ref):
				return _err("inaccesible")
			var blk := {}
			if not test_access.is_valid():
				blk = _block_from_view(_wm().call("view", st, repo, ref), src)
			if blk.is_empty():
				blk = _static_block(st, repo, ref, src)
			if blk.is_empty():
				return _err("no_esta")
			blk["view"] = ref
			return _norm_block(st, repo, blk, kind, ref)
		"line", "diary":
			var rec := find_record(st, ref)
			if rec.is_empty() or not accessible(st, repo, kind, ref):
				return _err("inaccesible")
			var parsed = rec.get("parsed")
			if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("plain"):
				parsed = repo.parse_text(String(rec.get("text", "")), {}, String(rec.get("act", "")))
			var origin := String(rec.get("origin", rec.get("scene", "")))
			if origin == "":
				origin = "D36" if kind == "diary" else ref
			var scene := String(rec.get("scene", ""))
			if scene == "" and String(rec.get("line", "")) != "":
				scene = String(find_record(st, String(rec.line)).get("scene", ""))
			var blk2 := {"parsed": parsed, "doc": String(rec.get("doc", "")), "origin": origin,
				"copy": String(rec.get("copy", "")), "cls": String(rec.get("cls", "I")),
				"src_type": String(rec.get("src_type", "escena" if kind == "line" else "diario")),
				"title": String(rec.get("title", "")), "who": String(rec.get("who", "")), "place": String(rec.get("place", "")),
				"voice": String(rec.get("voice", "")), "view": ref, "part": ref, "block": 0, "scene": scene}
			return _norm_block(st, repo, blk2, kind, ref)
		"node":
			var cut := ref.rfind("/")
			if cut <= 0:
				return _err("forma")
			var plate := ref.substr(0, cut)
			var node := ref.substr(cut + 1)
			if not accessible(st, repo, "plate", plate):
				return _err("inaccesible")
			var snap := plate_snapshot(st, repo, plate)
			if snap.is_empty() or not snap_has(snap, node):
				return _err("no_esta")
			var nd := node_def(st, repo, snap, node)
			if nd.is_empty():
				return _err("no_esta")
			var p: Dictionary = repo.parse_text(String(nd.get("examine", "")))
			var tg := Markup.empty_tags()
			for t in nd.get("tags", []):
				var s := String(t)
				var pre := s.get_slice(":", 0)
				if tg.has(pre):
					tg[pre].append(s.substr(pre.length() + 1))
			for e in nd.get("ents", []):
				if not tg.e.has(e):
					tg.e.append(e)
			var pp: Dictionary = p.duplicate(true)
			pp["tramos"] = [{"id": node, "from": 0, "to": String(p.get("plain", "")).length(), "tags": tg}]
			var blk3 := {"parsed": pp, "doc": String(snap.get("doc", "")), "origin": snap_origin(repo, snap, plate),
				"copy": String(snap.get("copy", plate)), "cls": String(nd.get("cls", "I")), "src_type": "lugar",
				"place": String(snap.get("place", "")), "view": plate, "part": node, "block": 0,
				"title": _place_label(repo, String(snap.get("place", "")))}
			return _norm_block(st, repo, blk3, kind, ref)
	return _err("forma")

static func _block_from_view(v, src: Dictionary) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY or typeof(v.get("pages")) != TYPE_ARRAY or v.pages.is_empty():
		return {}
	var pages: Array = v.pages
	var part = src.get("part", 0)
	var page = null
	if typeof(part) == TYPE_STRING:
		for pg in pages:
			if typeof(pg) == TYPE_ARRAY and not pg.is_empty() and typeof(pg[0]) == TYPE_DICTIONARY and String(pg[0].get("part", "")) == part:
				page = pg
				break
	else:
		var i := int(part)
		if i >= 0 and i < pages.size():
			page = pages[i]
	if typeof(page) != TYPE_ARRAY:
		return {}
	var b := int(src.get("block", 0))
	if b < 0 or b >= page.size() or typeof(page[b]) != TYPE_DICTIONARY:
		return {}
	var blk: Dictionary = page[b].duplicate()
	if typeof(blk.get("parsed")) != TYPE_DICTIONARY:
		return {}
	blk["part"] = part
	blk["block"] = b
	if v.has("src_line") and not blk.has("src_line"):
		blk["src_line"] = v.src_line
	if v.has("title") and not blk.has("title"):
		blk["title"] = v.title
	blk["view_doc"] = String(v.get("doc", ""))
	return blk

static func _static_block(st, repo, ref: String, src: Dictionary) -> Dictionary:
	# instancia runtime (W2-SIM: st.world.docs[iid] = {blocks:[{text, act}], origin, meta}): una página, un bloque por texto
	var wdocs = _world(st).get("docs", {})
	if typeof(wdocs) == TYPE_DICTIONARY and typeof(wdocs.get(ref)) == TYPE_DICTIONARY:
		var inst: Dictionary = wdocs[ref]
		var part0 = src.get("part", 0)
		if (typeof(part0) == TYPE_STRING and part0 != "p1") or (typeof(part0) != TYPE_STRING and int(part0) != 0):
			return {}
		var blocks: Array = inst.get("blocks", []) if typeof(inst.get("blocks")) == TYPE_ARRAY else []
		var bi := int(src.get("block", 0))
		if bi < 0 or bi >= blocks.size() or typeof(blocks[bi]) != TYPE_DICTIONARY:
			return {}
		return {"doc": ref, "origin": String(inst.get("origin", ref)), "copy": ref, "part": "p1", "block": bi,
			"parsed": repo.parse_text(String(blocks[bi].get("text", "")), {}, String(blocks[bi].get("act", "")))}
	var did := ""
	var copy_id := ""
	var cp: Dictionary = repo.copy(ref)
	if not cp.is_empty():
		did = String(cp.doc)
		copy_id = ref
	elif not repo.doc(ref).is_empty():
		did = ref
	else:
		return {}
	var d: Dictionary = repo.doc(did)
	var parts: Array = []
	for p in d.get("parts", []):
		if typeof(p) == TYPE_DICTIONARY and (p.get("when") == null or Cond.eval(p.when, {"st": st, "repo": repo})):
			parts.append(p)
	if parts.is_empty():
		return {}
	var part = src.get("part", 0)
	var sel := {}
	if typeof(part) == TYPE_STRING:
		for p in parts:
			if String(p.get("id", "")) == part:
				sel = p
	else:
		var i := int(part)
		if i >= 0 and i < parts.size():
			sel = parts[i]
	if sel.is_empty() or int(src.get("block", 0)) != 0:
		return {}
	return {"doc": did, "origin": String(d.get("origin", did)), "copy": copy_id, "parsed": repo.parsed(did, String(sel.id)),
		"part": String(sel.id), "block": 0}

# Completa un bloque con la meta del documento (o del registro) y arma la línea de fuente.
static func _norm_block(st, repo, blk: Dictionary, kind: String, ref: String) -> Dictionary:
	var did := String(blk.get("doc", ""))
	var meta: Dictionary = _doc_meta(st, repo, did) if did != "" else {}
	var out := {"ok": true, "err": "", "src_kind": kind, "view": String(blk.get("view", ref))}
	out["parsed"] = blk.get("parsed", {})
	out["doc"] = did
	out["origin"] = String(blk.get("origin", meta.get("origin", did)))
	if out.origin == "":
		out.origin = ref
	out["copy"] = String(blk.get("copy", ""))
	var cls := String(blk.get("cls", ""))
	if cls == "" and out.copy != "":
		cls = String(repo.copy(out.copy).get("copy", {}).get("class", ""))
	if cls == "":
		cls = String(meta.get("class", "I"))
	out["cls"] = cls
	out["src_type"] = String(blk.get("src_type", meta.get("src_type", "")))
	out["title"] = String(blk.get("title", meta.get("title", "")))
	out["chron_date"] = String(blk.get("chron_date", meta.get("chron_date", "") if meta.get("chron_date") != null else ""))
	out["part"] = blk.get("part", 0)
	out["block"] = int(blk.get("block", 0))
	out["mode"] = String(meta.get("clip_mode", "normal")) if meta.get("clip_mode") != null else "normal"
	out["entity"] = String(meta.get("entity", "")) if meta.get("entity") != null else ""
	var vdoc := String(blk.get("view_doc", ""))
	if out.entity == "" and vdoc != "" and vdoc != did:
		# bloque runtime insertado en un número (columna del Times): lleva la entidad del documento que se lee
		out.entity = String(repo.doc(vdoc).get("entity", ""))
	out["clip_entities"] = meta.get("clip_entities", []) if typeof(meta.get("clip_entities")) == TYPE_ARRAY else []
	out["machine"] = String(meta.get("machine", "")) if meta.get("machine") != null else ""
	out["visible_cats"] = meta.get("visible_cats", []) if typeof(meta.get("visible_cats")) == TYPE_ARRAY else []
	out["voice"] = String(blk.get("voice", meta.get("voice", meta.get("voz", ""))))
	if out.voice == "" and did != "":
		# documento runtime: voz de su reacción (W2-REACT: report_cats clip_voice, «respuesta_s»)
		var inst = _world(st).get("docs", {}).get(did) if typeof(_world(st).get("docs")) == TYPE_DICTIONARY else null
		if typeof(inst) == TYPE_DICTIONARY and String(inst.get("rid", "")) != "":
			out.voice = String(repo.reaction(String(inst.rid)).get("voz", ""))
	out["scene"] = String(blk.get("scene", ""))
	out["who"] = String(blk.get("who", ""))
	out["place"] = String(blk.get("place", ""))
	var line := String(blk.get("src_line", ""))
	if line == "":
		var lugar := _place_label(repo, out.place)
		var t := _src_type_label(repo, out.src_type, lugar)
		var parts: Array = []
		if out.who != "":
			parts.append(_who_label(repo, out.who))
		if out.title != "":
			parts.append(out.title)
		if t != "":
			parts.append(t)
		line = ", ".join(parts)
	out["src_line"] = line
	return out

static func _who_label(repo, who: String) -> String:
	var e: Dictionary = repo.entity(who)
	if not e.is_empty():
		return String(e.get("name", who))
	var dl: Dictionary = repo.dialogue(who)
	if not dl.is_empty():
		return String(dl.get("label", who))
	return who

static func find_record(st, ref: String) -> Dictionary:
	var sources: Array = [_world(st).get("diary"), _world(st).get("lines")]
	if typeof(st.scenes) == TYPE_DICTIONARY:
		sources.append(st.scenes.get("lines"))
	for col in sources:
		if typeof(col) == TYPE_ARRAY:
			for r in col:
				if typeof(r) == TYPE_DICTIONARY and (String(r.get("id", "")) == ref or String(r.get("uid", "")) == ref):
					return r
		elif typeof(col) == TYPE_DICTIONARY and typeof(col.get(ref)) == TYPE_DICTIONARY:
			return col[ref]
	return {}

# ---------------- láminas ----------------
static func plate_snapshot(st, repo, plate: String) -> Dictionary:
	if not test_access.is_valid() and _wm().has_method("plate_snapshot"):
		var ws = _wm().call("plate_snapshot", st, repo, plate)
		if typeof(ws) == TYPE_DICTIONARY and not ws.is_empty():
			if String(ws.get("id", "")) == "":
				ws["id"] = plate
			return ws
	var plates = _world(st).get("plates")
	if typeof(plates) == TYPE_DICTIONARY and typeof(plates.get(plate)) == TYPE_DICTIONARY:
		var s: Dictionary = plates[plate].duplicate(true)
		if not s.has("id"):
			s["id"] = plate
		return s
	if typeof(plates) == TYPE_ARRAY:
		for s in plates:
			if typeof(s) == TYPE_DICTIONARY and String(s.get("id", "")) == plate:
				return s.duplicate(true)
	# lámina fija de data/plates (por id o por origin)
	var pids: Array = repo.plates().keys()
	pids.sort()
	for pid in pids:
		var p: Dictionary = repo.plate(pid)
		if pid == plate or String(p.get("origin", "")) == plate:
			return {"id": plate, "place": pid, "fixed": true, "origin": String(p.get("origin", plate)), "area": "*",
				"nodes": _static_nodes(st, repo, p, -1), "silhouettes": []}
	# instantánea estática de un lugar: PL.<L>.<d>.<s>
	var ps := plate.split(".")
	if ps.size() == 4 and ps[0] == "PL" and not repo.place(ps[1]).is_empty() and TimeKey.ORD.has(ps[3]):
		var day := int(ps[2])
		var t := TimeKey.tk(day, ps[3])
		var pl: Dictionary = repo.place(ps[1])
		var sils: Array = []
		if day >= 3 and typeof(pl.get("silhouettes")) == TYPE_DICTIONARY and pl.silhouettes.has(KS_SIL):
			sils.append(KS_SIL)
		return {"id": plate, "place": ps[1], "day": day, "slot": ps[3], "origin": plate, "area": "*",
			"nodes": _static_nodes(st, repo, pl, t), "silhouettes": sils}
	return {}

static func _static_nodes(st, repo, p: Dictionary, t: int) -> Array:
	var out: Array = []
	for n in p.get("nodes", []):
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var w = n.get("when")
		var ctx := {"st": st, "repo": repo}
		if t >= 0:
			ctx["tk"] = t
		if w == null or Cond.eval(w, ctx):
			out.append(String(n.id))
	return out

# Origen de un recorte de lámina (GDD§10.2: la lámina hereda el origen del lugar y la visita): el de la instantánea si
# lo trae; si no, el "origin" declarado por la lámina fija de data/plates de la que sale (§4.11: "origin": "PL.prologo";
# las variantes RB.foto/RB.journal/RB.fina son la misma lámina); si no, el id de la instantánea (visita PL.<L>.<d>.<s>).
# Igual criterio que W2-GRAPH (RouteDB: origin del dueño del nodo).
static func snap_origin(repo, snap: Dictionary, plate: String) -> String:
	var o := String(snap.get("origin", "")) if snap.get("origin") != null else ""
	if o != "":
		return o
	var pid := String(snap.get("place", ""))
	if pid != "" and repo.place(pid).is_empty():
		var fp: Dictionary = repo.plate(pid)
		if not fp.is_empty() and fp.get("origin") != null and String(fp.get("origin", "")) != "":
			return String(fp.origin)
	return plate

static func snap_has(snap: Dictionary, node: String) -> bool:
	if snap.get("nodes", []).has(node):
		return true
	if node.begins_with("sil_"):
		return snap.get("silhouettes", []).has(node.substr(4)) or snap.get("silhouettes", []).has(node)
	return false

static func _place_src(repo, snap: Dictionary) -> Dictionary:
	var pid := String(snap.get("place", ""))
	var p: Dictionary = repo.place(pid)
	if p.is_empty():
		p = repo.plate(pid)
	return p

# {id, noun, tags:[prefijadas], cls, examine, ents}
static func node_def(st, repo, snap: Dictionary, node: String) -> Dictionary:
	var defs = snap.get("node_defs")
	if typeof(defs) == TYPE_DICTIONARY and typeof(defs.get(node)) == TYPE_DICTIONARY:
		var dd: Dictionary = defs[node].duplicate(true)
		dd["id"] = node
		return _fill_def(repo, dd)
	var p := _place_src(repo, snap)
	var nodes: Array = []
	nodes.append_array(p.get("nodes", []))
	var variant := String(snap.get("variant", ""))
	if variant != "" and typeof(p.get("variants")) == TYPE_DICTIONARY and typeof(p.variants.get(variant)) == TYPE_DICTIONARY:
		nodes.append_array(p.variants[variant].get("add_nodes", []))
	for n in nodes:
		if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == node:
			return _fill_def(repo, {"id": node, "noun": String(n.get("noun", "")), "tags": n.get("tags", []),
				"cls": String(n.get("cls", "I")), "examine": String(n.get("examine", ""))})
	if node.begins_with("sil_"):
		var who := node.substr(4)
		var ents: Array = []
		var ch := sil_channel(repo, who)
		if who == KS_SIL:
			for m in repo.lists().get("medios", []):
				if typeof(m) == TYPE_DICTIONARY and String(m.get("ch", "")) == "ks":
					ents.append_array(m.get("entities", []))
		elif not repo.entity(who).is_empty():
			ents.append(who)
		var noun := ""
		if not ents.is_empty():
			noun = String(repo.entity(String(ents[0])).get("noun", ""))
		if noun == "":
			noun = String(repo.entity(who).get("noun", who))
		var act := String(snap.get("act", ""))
		if act == "":
			act = _visit_act(st, snap)
		if act != "":
			ents.append(act)
		return {"id": node, "noun": noun, "tags": ["a:ancla_" + ch] if ch != "" else [], "cls": "I", "examine": "", "ents": ents}
	return {}

# Canal del vigía de una silueta (código de medio: "ks"…) = canal de la reacción que la pone (op "silueta", who);
# GDD§10.4 C6: K-S es la silueta de Wiggins (HB8b cambia de muchacho, el canal sigue). Las siluetas de Moran (M3, M11:
# canal informe/columna) no citan un acto ante Holmes: sin ancla. Sin reacción que la ponga: wiggins = ks (§4.8
# N:*.sil_wiggins); cualquier otra, "". Igual criterio que W2-GRAPH (Availability.sil_channel).
static func sil_channel(repo, who: String) -> String:
	var codes: Array = []
	for m in repo.lists().get("medios", []):
		if typeof(m) == TYPE_DICTIONARY and String(m.get("ch", "")) != "":
			codes.append(String(m.ch))
	var found := ""
	for r in repo.reactions():
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var effs: Array = []
		if typeof(r.get("efecto")) == TYPE_ARRAY:
			effs.append_array(r.efecto)
		var vb = r.get("variante_blanda")
		if typeof(vb) == TYPE_DICTIONARY and typeof(vb.get("efecto")) == TYPE_ARRAY:
			effs.append_array(vb.efecto)
		for e in effs:
			if typeof(e) != TYPE_DICTIONARY or String(e.get("op", "")) != "silueta" or String(e.get("who", "")) != who:
				continue
			var s := String(r.get("canal", "")).to_lower().replace("-", "")
			var best := ""
			for c in codes:
				if s.begins_with(c) and c.length() > best.length():
					best = c
			if best != "" and (found == "" or best < found):
				found = best
	if found == "" and who == KS_SIL:
		found = "ks"
	return found

static func _fill_def(repo, d: Dictionary) -> Dictionary:
	var ents: Array = []
	for t in d.get("tags", []):
		var s := String(t)
		if s.begins_with("e:"):
			ents.append(s.substr(2))
	var ex := String(d.get("examine", ""))
	if ex != "":
		for m in repo.parse_text(ex).get("mentions", []):
			if not ents.has(m.ent):
				ents.append(m.ent)
	for e in d.get("ents", []):
		if not ents.has(e):
			ents.append(e)
	d["ents"] = ents
	if String(d.get("noun", "")) == "" and not ents.is_empty():
		d["noun"] = String(repo.entity(String(ents[0])).get("noun", ""))
	return d

# Acto «go» de la visita de la instantánea (para la silueta: §4.11 «entidad del acto go de esa visita»).
static func _visit_act(st, snap: Dictionary) -> String:
	var place := String(snap.get("place", ""))
	var day := int(snap.get("day", -1))
	var slot := String(snap.get("slot", ""))
	var best := ""
	if typeof(st.events) != TYPE_ARRAY:
		return ""
	for ev in st.events:
		if typeof(ev) != TYPE_DICTIONARY or String(ev.get("type", "")) != "go" or String(ev.get("place", "")) != place:
			continue
		if day >= 0 and int(ev.get("day", -2)) != day:
			continue
		if slot != "" and String(ev.get("slot", "")) != slot:
			continue
		best = String(ev.get("act", "act.%d" % int(ev.get("seq", 0))))
	return best

# ---------------- acciones ----------------
static func act_clip_text(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var src = a.get("src", {})
	if typeof(src) != TYPE_DICTIONARY:
		return _err("forma")
	var b := resolve_text_src(st, repo, src)
	if not b.ok:
		return _err(b.err)
	var visit := _visit_key(st)
	if b.mode == "memoria" and memory_count(st, visit) >= MEMORY_MAX:
		return _err("memoria_agotada")
	var parsed: Dictionary = b.parsed
	var sn := ClipRules.snap(parsed, int(a.get("from", 0)), int(a.get("len", 0)))
	if not sn.ok:
		return _err(String(sn.err))
	var inh := ClipRules.inherit(parsed, sn.from, sn.to)
	var ents: Array = inh.ents.duplicate()
	var extra: Array = []
	if b.entity != "":
		extra.append(b.entity)
	extra.append_array(b.clip_entities)
	if b.machine != "":
		extra.append(MACHINE_ENTS.get(b.machine, b.machine))
	if b.who != "" and not repo.entity(b.who).is_empty():
		extra.append(b.who)
	if b.place != "" and not repo.entity(b.place).is_empty():
		extra.append(b.place)
	for e in extra:
		if not ents.has(e) and (Index.is_runtime(String(e)) or not repo.entity(String(e)).is_empty()):
			ents.append(e)
	var tramo_key := String(inh.tramo) if String(inh.tramo) != "" and float(inh.frac) >= 0.5 else "@%d" % sn.from
	var clip := {
		"kind": "text", "src_kind": b.src_kind, "text": sn.text, "ents": ents, "tags": inh.tags,
		"tramo": inh.tramo if float(inh.frac) >= 0.5 else "", "origin": b.origin,
		"passage": "%s|%s|%s" % [b.origin, str(b.part), tramo_key], "copy": b.copy, "cls": b.cls, "doc": b.doc,
		"src_type": b.src_type, "src_line": b.src_line, "title": b.title,
		"chron_date": inh.date if String(inh.date) != "" else b.chron_date, "place": inh.place, "view": b.view,
		"part": b.part, "block": b.block, "from": sn.from, "to": sn.to, "visible_cats": b.visible_cats,
		"voice": b.voice, "mode": b.mode, "visit": visit, "who": b.who, "tk": now_tk(st), "place_label_src": b.place,
		"scene": b.scene,
	}
	var labels := _act_labels(parsed, sn.from, sn.to)
	var id := _store(st, repo, clip, labels)
	return {"ok": true, "clip": id}

# Etiqueta de las entidades runtime (act.<n>) = superficie de su mención (recortada al tamaño de la tira).
static func _act_labels(parsed: Dictionary, from: int, to: int) -> Dictionary:
	var out := {}
	var plain := String(parsed.get("plain", ""))
	for m in parsed.get("mentions", []):
		var ent := String(m.ent)
		if Index.is_runtime(ent) and m.from < to and m.to > from and not out.has(ent):
			out[ent] = plain.substr(m.from, m.to - m.from).strip_edges().left(60)
	return out

static func memory_count(st, visit: String) -> int:
	var n := 0
	var clips: Dictionary = Index.ensure(st).clips
	for id in clips:
		var c: Dictionary = clips[id]
		if String(c.get("mode", "")) == "memoria" and String(c.get("visit", "")) == visit:
			n += 1
	return n

static func _store(st, repo, clip: Dictionary, act_labels := {}) -> String:
	var d := Index.ensure(st)
	var id := String(clip.get("id", ""))
	if id == "":
		id = _new_id(st, "clip", "RC", 4)
	clip["id"] = id
	var labels := {}
	for e in clip.get("ents", []):
		var s := String(e)
		var lb := Index.label(st, repo, s)
		if Index.is_runtime(s) and lb == s and String(act_labels.get(s, "")) != "":
			lb = String(act_labels[s])
		labels[s] = lb
	clip["labels"] = labels
	if String(clip.get("caption", "")) == "":
		clip["caption"] = _caption(st, repo, clip, act_labels)
	d.clips[id] = clip
	var items: Array = []
	for e in clip.get("ents", []):
		var s := String(e)
		items.append({"id": s, "label": act_labels.get(s, "")} if Index.is_runtime(s) else s)
	Index.add_entities(st, repo, items)
	_note(st, "clip", {"id": id})
	return id

static func _caption(st, repo, clip: Dictionary, act_labels: Dictionary) -> String:
	var parts: Array = []
	for e in clip.get("ents", []):
		var lb := String(clip.get("labels", {}).get(String(e), String(e)))
		if not parts.has(lb):
			parts.append(lb)
	var pl := _place_label(repo, String(clip.get("place_label_src", "")))
	if pl != "" and not parts.has(pl):
		parts.append(pl)
	return ", ".join(parts)

static func act_clip_plate(st, repo, a) -> Dictionary:
	Index.ensure(st)
	var plate := String(a.get("plate", ""))
	if plate == "":
		return _err("forma")
	if float(a.get("area_frac", 0.0)) > MAX_PLATE_FRAC + 1e-9:
		return _err("rect_grande")
	if not accessible(st, repo, "plate", plate):
		return _err("inaccesible")
	var snap := plate_snapshot(st, repo, plate)
	if snap.is_empty():
		return _err("inaccesible")
	var hits: Array = []
	for h in a.get("hits", []):
		if typeof(h) != TYPE_DICTIONARY:
			return _err("forma")
		var nid := String(h.get("node", ""))
		if not snap_has(snap, nid):
			return _err("no_esta")
		hits.append({"node": nid, "cover": float(h.get("cover", 0.0)), "tight": bool(h.get("tight", false))})
	var cap: Array = []
	for h in hits:
		if h.cover >= MIN_COVER:
			cap.append(h)
	cap.sort_custom(func(x, y):
		if x.cover == y.cover:
			return x.node < y.node
		return x.cover > y.cover)
	if cap.size() > MAX_PLATE_HITS:
		return _err("demasiados_nodos")
	var defs := {}
	var ents: Array = []
	var tags: Array = []
	var cls := "I"
	var place_tag := ""
	for i in cap.size():
		var nd := node_def(st, repo, snap, cap[i].node)
		defs[cap[i].node] = nd
		for e in nd.get("ents", []):
			if not ents.has(e):
				ents.append(e)
		if i == 0:
			cls = String(nd.get("cls", "I"))
			if cap[0].tight:
				for t in nd.get("tags", []):
					var s := String(t)
					var pre := s.get_slice(":", 0)
					if ClipRules.INHERIT.has(pre) and not tags.has(s):
						tags.append(s)
					if pre == "p" and place_tag == "":
						place_tag = s.substr(2)
	tags.sort()
	var touched: Array = []
	for t in a.get("touched", []):
		var nid := String(t)
		if snap_has(snap, nid) and not touched.has(nid):
			touched.append(nid)
	for h in cap:
		if not touched.has(h.node):
			touched.append(h.node)
	var nouns: Array = []
	for nid in touched:
		var nd2: Dictionary = defs[nid] if defs.has(nid) else node_def(st, repo, snap, nid)
		var nn := String(nd2.get("noun", ""))
		if nn != "" and not nouns.has(nn):
			nouns.append(nn)
	var pl := _place_label(repo, String(snap.get("place", "")))
	var cap_parts: Array = nouns.duplicate()
	if pl != "" and not cap_parts.has(pl):
		cap_parts.append(pl)
	var origin := snap_origin(repo, snap, plate)
	var main := String(cap[0].node) if not cap.is_empty() else ""
	var doc := String(snap.get("doc", ""))
	var src_line := ", ".join([pl, _src_type_label(repo, "lugar")]) if pl != "" else _src_type_label(repo, "lugar")
	var clip := {
		"kind": "plate", "src_kind": "plate", "text": "", "ents": ents, "tags": tags, "tramo": main if not tags.is_empty() else "",
		"origin": origin, "passage": "%s|%s" % [origin, main], "copy": String(snap.get("copy", plate)), "cls": cls,
		"doc": doc, "src_type": "lugar", "src_line": src_line, "title": pl, "chron_date": "", "place": place_tag,
		"view": plate, "plate": plate, "nodes": cap.map(func(h): return h.node), "touched": touched,
		"caption": ", ".join(cap_parts), "visible_cats": [], "voice": "", "mode": "normal", "visit": _visit_key(st),
		"who": "", "tk": now_tk(st), "part": main, "block": 0, "from": 0, "to": 0,
	}
	var id := _store(st, repo, clip)
	return {"ok": true, "clip": id}

static func act_clip_measure(st, repo, a) -> Dictionary:
	Index.ensure(st)
	var src = a.get("src", {})
	if typeof(src) != TYPE_DICTIONARY:
		return _err("forma")
	var kind := String(src.get("kind", ""))
	var ref := String(src.get("ref", ""))
	var measure = null
	var paper = null
	var origin := ""
	var doc := ""
	var copy := ""
	var title := ""
	var src_type := ""
	var ents: Array = []
	var cls := "I"
	if kind == "doc":
		if not accessible(st, repo, "doc", ref):
			return _err("inaccesible")
		var cp: Dictionary = repo.copy(ref)
		doc = String(cp.get("doc", ""))
		copy = ref if doc != "" else ""
		if doc == "":
			var blk := {}
			if not test_access.is_valid():
				blk = _block_from_view(_wm().call("view", st, repo, ref), {"part": 0, "block": 0})
			doc = String(blk.get("doc", ref))
			copy = String(blk.get("copy", ""))
		var meta := _doc_meta(st, repo, doc)
		if meta.is_empty():
			return _err("no_esta")
		measure = meta.get("measure")
		paper = meta.get("paper_mm")
		origin = String(meta.get("origin", doc)) if meta.get("origin") != null else doc
		title = String(meta.get("title", ""))
		src_type = String(meta.get("src_type", ""))
		if meta.get("entity") != null and String(meta.get("entity", "")) != "":
			ents.append(String(meta.entity))
		cls = String(repo.copy(copy).get("copy", {}).get("class", meta.get("class", "I"))) if copy != "" else String(meta.get("class", "I"))
	elif kind == "scene":
		if not accessible(st, repo, "scene", ref):
			return _err("inaccesible")
		var sc: Dictionary = repo.scene(ref)
		if sc.is_empty():
			return _err("no_esta")
		measure = sc.get("measure")
		paper = sc.get("paper_mm")
		origin = String(sc.get("origin", ref))
		src_type = "escena"
	else:
		return _err("forma")
	if typeof(measure) != TYPE_DICTIONARY or typeof(paper) != TYPE_ARRAY or paper.size() < 2:
		return _err("sin_medida")
	var w := int(paper[0])
	var h := int(paper[1])
	var txt: String = repo.text("clip.mide", {"h": h, "w": w})
	if txt == "clip.mide":
		txt = "Mide %d por %d milímetros." % [h, w]
	var me := String(measure.get("entity", ""))
	if me != "" and not ents.has(me):
		ents.insert(0, me)
	var tags: Array = []
	for t in measure.get("tags", []):
		var s := String(t)
		if not s.contains(":"):
			s = "a:" + s
		if not tags.has(s):
			tags.append(s)
	tags.sort()
	var clip := {
		"kind": "measure", "src_kind": kind, "text": txt, "ents": ents, "tags": tags, "tramo": "M:" + (doc if doc != "" else ref),
		"origin": origin, "passage": "%s|M" % origin, "copy": copy, "cls": cls, "doc": doc, "src_type": src_type,
		"src_line": ", ".join([title, _src_type_label(repo, src_type)]) if title != "" else _src_type_label(repo, src_type),
		"title": title, "chron_date": "", "place": "", "view": ref, "visible_cats": [], "voice": "", "mode": "normal",
		"visit": _visit_key(st), "who": "", "tk": now_tk(st), "part": "M", "block": 0, "from": 0, "to": 0,
	}
	var id := _store(st, repo, clip)
	return {"ok": true, "clip": id}

static func act_link(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var ca := String(a.get("a", ""))
	var cb := String(a.get("b", ""))
	if d.pairs.has(ca) or d.pairs.has(cb):
		return _err("anidado")
	if not d.clips.has(ca) or not d.clips.has(cb):
		return _err("no_existe")
	if ca == cb:
		return _err("mismo")
	var ks: Array = d.pairs.keys()
	ks.sort()
	for pid in ks:
		var p: Dictionary = d.pairs[pid]
		if (p.a == ca and p.b == cb) or (p.a == cb and p.b == ca):
			return {"ok": true, "pair": pid}
	var id := _new_id(st, "pair", "PR", 3)
	d.pairs[id] = {"id": id, "a": ca, "b": cb, "note": String(a.get("note", ""))}
	_note(st, "pair", {"id": id})
	return {"ok": true, "pair": id}

static func act_unlink(st, repo, a) -> Dictionary:
	var d := Index.ensure(st)
	var pid := String(a.get("pair", ""))
	if not d.pairs.has(pid):
		return _err("no_existe")
	var eids: Array = d.entries.keys()
	eids.sort()
	for eid in eids:
		var e: Dictionary = d.entries[eid]
		if String(e.get("ink", "")) != "tinta":
			continue
		for ln in e.get("lines", []):
			if ln.get("support", []).has(pid):
				return _err("en_tinta")
	for eid in eids:
		for ln in d.entries[eid].get("lines", []):
			ln.support.erase(pid)
	d.pairs.erase(pid)
	_note(st, "pair", {"id": pid, "removed": true})
	return {"ok": true}

# Interno, CON etiquetas (validator, confrontación, Moran). Copia.
static func get_clip(st, id: String) -> Dictionary:
	if typeof(st.ded) != TYPE_DICTIONARY:
		return {}
	var c = st.ded.get("clips", {}).get(id)
	return c.duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}

static func get_pair(st, id: String) -> Dictionary:
	if typeof(st.ded) != TYPE_DICTIONARY:
		return {}
	var p = st.ded.get("pairs", {}).get(id)
	return p.duplicate(true) if typeof(p) == TYPE_DICTIONARY else {}

# Lo que ve el jugador (q_clip, diálogo T20b, informes, UI): SIN etiquetas ocultas.
static func visible(st, id: String) -> Dictionary:
	var c := get_clip(st, id)
	if c.is_empty():
		return {}
	var ents: Array = []
	for e in c.get("ents", []):
		var lb := String(c.get("labels", {}).get(String(e), ""))
		ents.append({"id": String(e), "label": lb if lb != "" else _label_no_repo(st, String(e))})
	var doc := String(c.get("doc", ""))
	return {
		"id": id, "kind": String(c.get("kind", "text")), "text": String(c.get("text", "")), "ents": ents,
		"caption": String(c.get("caption", "")), "src_line": String(c.get("src_line", "")),
		"origin": String(c.get("origin", "")), "origins": [String(c.get("origin", ""))],
		"chron_date": String(c.get("chron_date", "")), "place": String(c.get("place", "")),
		"doc": doc, "doc_ids": [doc] if doc != "" else [], "src_type": String(c.get("src_type", "")),
		"src_types": [String(c.get("src_type", ""))], "copy": String(c.get("copy", "")),
		"who": String(c.get("who", "")), "visible_cats": c.get("visible_cats", []).duplicate(), "mode": String(c.get("mode", "normal")),
	}

# visible() no recibe repo (firma del contrato): etiqueta = runtime del índice o el id; la UI resuelve con Index.label.
static func _label_no_repo(st, ent: String) -> String:
	var idx = st.ded.get("index", {}) if typeof(st.ded) == TYPE_DICTIONARY else {}
	if Index.is_runtime(ent) and idx.has(ent):
		var lb := String(idx[ent].get("label", ""))
		if lb != "":
			return lb
	return ent

# Sólo tests/devtools: guarda un recorte ya armado (campos faltantes con valores neutros). Devuelve su id.
static func inject(st, repo, clip: Dictionary) -> String:
	Index.ensure(st)
	var c := {"kind": "text", "src_kind": "doc", "text": "", "ents": [], "tags": [], "tramo": "", "origin": "", "passage": "",
		"copy": "", "cls": "I", "doc": "", "src_type": "", "src_line": "", "title": "", "chron_date": "", "place": "",
		"view": "", "part": 0, "block": 0, "from": 0, "to": 0, "visible_cats": [], "voice": "", "mode": "normal",
		"visit": "", "who": "", "scene": "", "tk": now_tk(st)}
	for k in clip:
		c[k] = clip[k]
	if String(c.passage) == "":
		c.passage = "%s|%s|%s" % [c.origin, str(c.part), c.tramo if String(c.tramo) != "" else str(c.from)]
	var tg: Array = c.tags.duplicate()
	tg.sort()
	c.tags = tg
	return _store(st, repo, c)
