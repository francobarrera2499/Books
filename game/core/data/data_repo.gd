# core/data/data_repo.gd — único lector de data/ (§4.1–§4.2). Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8.
# Instancia cacheada por root: load_dir(root). Nunca push_error: los problemas quedan en errors() ("ruta: mensaje").
# Accesores devuelven las estructuras internas (NO mutar; duplicar si hace falta). Faltante -> {} / [] / "".
# Extensiones (compatibles, fuera del contrato mínimo): fresh(), clear_cache(), conclusions_meta(), plates(), scenes(),
#   dialogues(), map(), fonts(), audio(), texts(), parse_text(), markup_ctx(), doc_tramo(), files(), cache (dict libre
#   para cachés de otros módulos, p. ej. ReactionDB.compile).
# Nota de dependencias: data -> text (Markup) por preload; text no depende de data (recibe ctx). Sin ciclos.
extends RefCounted

const J = preload("res://core/util/j.gd")
const Markup = preload("res://core/text/markup.gd")
const Schema = preload("res://core/data/schema.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Fisica = preload("res://core/text/fisica.gd")

const SELF_PATH := "res://core/data/data_repo.gd"

static var _cache := {}

var root: String = ""
var cache := {}

var _errors: Array = []
var _files := {}            # ruta relativa -> JSON parseado
var _docs := {}
var _doc_file := {}         # id -> ruta relativa
var _copies := {}           # copy id -> {copy, doc}
var _parsed := {}           # "doc|part" -> ParsedText
var _entities := {}
var _lists := {}
var _conc_file := {}
var _conclusions := {}
var _conc_list: Array = []
var _reactions := {}
var _react_list: Array = []
var _schedule := {}
var _places := {}
var _plates := {}
var _dialogue := {}
var _scenes := {}
var _canon: Array = []
var _endings := {}
var _eggs: Array = []
var _noise: Array = []
var _catalog = null
var _texts := {}
var _map := {}
var _fonts := {}
var _audio := {}
var _fisica := {}           # data/fisica.json (GDD_v2 §C.5; dueño de los datos: DESPEJE-UI)
var _hash := ""
var _names = null
var _schema_ctx := {}       # {abbrev} de lists.json para Schema.check
var _fields: Array = []     # campos de marcado/etiquetas recogidos por Schema: {rel, path, kind, v}

static func load_dir(root := "res://data"):
	if _cache.has(root):
		return _cache[root]
	var r = fresh(root)
	_cache[root] = r
	return r

static func fresh(root := "res://data"):
	var r = load(SELF_PATH).new()
	r._load(root)
	return r

static func clear_cache(root := "") -> void:
	if root == "":
		_cache.clear()
	else:
		_cache.erase(root)

# ---------------- carga ----------------
func _load(p_root: String) -> void:
	root = p_root.trim_suffix("/")
	var rels: Array = []
	if DirAccess.dir_exists_absolute(root):
		_scan(root, "", rels)
	rels.sort()
	for rel in rels:
		var data = J.parse_file(root + "/" + rel)
		if data == null:
			_errors.append("%s: JSON inválido (%s)" % [rel, J.last_error()])
			continue
		_files[rel] = data
	# lists.abbrev antes de validar: el lint de oraciones del esquema debe cortar igual que el runtime.
	var lj = _files.get("lists.json")
	if typeof(lj) == TYPE_DICTIONARY and typeof(lj.get("abbrev")) == TYPE_ARRAY:
		_schema_ctx = {"abbrev": lj.abbrev}
	for rel in rels:
		if _files.has(rel):
			_ingest(rel, _files[rel])
	_apply_stock()
	_apply_fisica()
	_cross_checks()

# GDD_v2 §B.5: schedule.stock atrasa el `from` de esos ejemplares a la franja jugable siguiente a tk (nunca lo
# adelanta). Se escribe en el ejemplar del documento y en el índice de ejemplares: WorldModel, Availability y los bots
# leen lo mismo.
func _apply_stock() -> void:
	var stock = _schedule.get("stock", [])
	if typeof(stock) != TYPE_ARRAY:
		return
	for e in stock:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var t := TimeKey.of(e.get("tk", ""))
		var i := TimeKey.idx_at_or_after(t)
		var at := TimeKey.from_idx(i)
		if t < 0 or at.is_empty():
			_errors.append("schedule.json: stock tk '%s' sin franja jugable" % str(e.get("tk", "")))
			continue
		var frm := TimeKey.label(TimeKey.tk(int(at.day), String(at.slot)))
		for cid in e.get("copies", []):
			var c = _copies.get(String(cid))
			if typeof(c) != TYPE_DICTIONARY:
				continue   # dataset parcial (fixtures): el ejemplar no está; test_u_reveal lo exige en data/ real
			var cur := TimeKey.of(c.copy.get("from", "")) if c.copy.has("from") else -1
			if cur >= TimeKey.tk(int(at.day), String(at.slot)):
				continue
			c.copy["from"] = frm
			for dc in _docs.get(String(c.doc), {}).get("copies", []):
				if typeof(dc) == TYPE_DICTIONARY and String(dc.get("id", "")) == String(cid):
					dc["from"] = frm

# GDD_v2 §C.5.2: descripción física de cada documento estático. Se antepone la línea (un tramo #fisica, mismo formato
# para todos; core/text/fisica.gd) y un salto de renglón al texto de parts[0]; si la descripción trae mm, reemplaza paper_mm (el papel
# del lector tiene la misma forma). Así D46#fisica se resuelve como cualquier tramo (doc_tramo, RouteDB, T4). Antes de
# _cross_checks (tramos del contrato) y de toda caché de parsed.
func _apply_fisica() -> void:
	if _fisica.is_empty():
		return
	for id in _sorted_keys(_docs):
		var d: Dictionary = _docs[id]
		var spec := Fisica.spec_doc(_fisica, String(id))
		if spec.is_empty():
			continue
		var parts = d.get("parts", [])
		if typeof(parts) != TYPE_ARRAY or parts.is_empty() or typeof(parts[0]) != TYPE_DICTIONARY:
			continue
		var mm = d.get("paper_mm", [])
		var ln := Fisica.line(spec, mm if typeof(mm) == TYPE_ARRAY else [], _fisica)
		if ln == "":
			continue
		parts[0]["text"] = Fisica.prepend(String(parts[0].get("text", "")), ln)
		if typeof(spec.get("mm")) == TYPE_ARRAY and (spec.mm as Array).size() == 2:
			d["paper_mm"] = (spec.mm as Array).duplicate()

func fisica() -> Dictionary:
	return _fisica

# Línea física de la plantilla de un documento generado (doc.entity): marcado listo para anteponer; "" si no hay.
func fisica_tpl_line(entity: String, mm) -> String:
	var spec := Fisica.spec_tpl(_fisica, entity)
	if spec.is_empty():
		return ""
	return Fisica.line(spec, mm if typeof(mm) == TYPE_ARRAY else [], _fisica)

# Ejemplar -> tk de su entrada en schedule.stock (-1 si no es novedad). Mesa de novedades de Crane.
func stock_tk(copy_id: String) -> int:
	for e in _schedule.get("stock", []):
		if typeof(e) == TYPE_DICTIONARY and (e.get("copies", []) as Array).has(copy_id):
			return TimeKey.of(e.get("tk", ""))
	return -1

func _scan(dir: String, rel: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json") and not f.begins_with("_") and not f.begins_with("."):
			out.append(rel + f)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d.begins_with("_"):
			continue
		_scan(dir + "/" + d, rel + d + "/", out)

func _schema(ds: String, rel: String, data) -> bool:
	var col: Array = []
	var errs := Schema.check(ds, data, _schema_ctx, col)
	for e in errs:
		_errors.append("%s: %s" % [rel, e])
	for f in col:
		f["rel"] = rel
		_fields.append(f)
	return errs.is_empty()

func _ingest(rel: String, data) -> void:
	var top := rel.get_slice("/", 0)
	var stem := rel.get_file().get_basename()
	var nested := rel.contains("/")
	if not nested:
		match rel:
			"fonts.json":
				_schema("fonts", rel, data)
				_fonts = data if typeof(data) == TYPE_DICTIONARY else {}
			"audio.json":
				_schema("audio", rel, data)
				_audio = data if typeof(data) == TYPE_DICTIONARY else {}
			"lists.json":
				_schema("lists", rel, data)
				_lists = data if typeof(data) == TYPE_DICTIONARY else {}
			"canon_bible.json":
				_schema("canon_bible", rel, data)
				if typeof(data) == TYPE_DICTIONARY:
					_canon = data.get("facts", [])
			"schedule.json":
				_schema("schedule", rel, data)
				_schedule = data if typeof(data) == TYPE_DICTIONARY else {}
			"conclusions.json":
				_schema("conclusions", rel, data)
				if typeof(data) == TYPE_DICTIONARY:
					_conc_file = data
					for c in data.get("conclusions", []):
						if typeof(c) == TYPE_DICTIONARY and c.has("id"):
							_conclusions[c.id] = c
					_conc_list = _conclusions.keys()
					_conc_list.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
			"endings.json":
				_schema("endings", rel, data)
				_endings = data if typeof(data) == TYPE_DICTIONARY else {}
			"easter_eggs.json":
				_schema("easter_eggs", rel, data)
				if typeof(data) == TYPE_DICTIONARY:
					_eggs = data.get("eggs", [])
			"map.json":
				_schema("map", rel, data)
				_map = data if typeof(data) == TYPE_DICTIONARY else {}
			"fisica.json":
				_schema("fisica", rel, data)
				_fisica = data if typeof(data) == TYPE_DICTIONARY else {}
			_:
				_errors.append("%s: archivo desconocido en data/" % rel)
		return
	match top:
		"ui_text":
			_schema("ui_text", rel, data)
			if typeof(data) == TYPE_DICTIONARY and typeof(data.get("text")) == TYPE_DICTIONARY:
				for k in data.text:
					if _texts.has(k):
						_errors.append("%s: clave de ui_text duplicada '%s'" % [rel, k])
					_texts[k] = data.text[k]
		"entities":
			_schema("entities", rel, data)
			if typeof(data) == TYPE_DICTIONARY and typeof(data.get("entities")) == TYPE_ARRAY:
				for e in data.entities:
					if typeof(e) != TYPE_DICTIONARY or not e.has("id"):
						continue
					if _entities.has(e.id):
						_errors.append("%s: entidad duplicada '%s'" % [rel, e.id])
					_entities[e.id] = e
		"docs":
			var did := rel.substr(5).trim_suffix(".json").replace("/", ".")
			_schema("docs", rel, data)
			if typeof(data) != TYPE_DICTIONARY:
				return
			if String(data.get("id", "")) != did:
				_errors.append("%s: id '%s' no coincide con el nombre de archivo (%s)" % [rel, data.get("id", ""), did])
			var id := String(data.get("id", did))
			if _docs.has(id):
				_errors.append("%s: documento duplicado '%s'" % [rel, id])
			_docs[id] = data
			_doc_file[id] = rel
			for c in data.get("copies", []):
				if typeof(c) != TYPE_DICTIONARY or not c.has("id"):
					continue
				if _copies.has(c.id):
					_errors.append("%s: ejemplar duplicado '%s'" % [rel, c.id])
				var cc: Dictionary = c.duplicate()
				if not cc.has("class"):
					cc["class"] = data.get("class", "I")
				_copies[c.id] = {"copy": cc, "doc": id}
		"catalog":
			_schema("catalog", rel, data)
			if typeof(data) == TYPE_DICTIONARY and typeof(data.get("noise")) == TYPE_ARRAY:
				for nz in data.noise:
					if typeof(nz) == TYPE_DICTIONARY:
						_noise.append(nz)
		"reactions":
			_schema("reactions", rel, data)
			if typeof(data) == TYPE_DICTIONARY and typeof(data.get("reactions")) == TYPE_ARRAY:
				for r in data.reactions:
					if typeof(r) != TYPE_DICTIONARY or not r.has("id"):
						continue
					if _reactions.has(r.id):
						_errors.append("%s: reacción duplicada '%s'" % [rel, r.id])
					_reactions[r.id] = r
		"scenes":
			_one(rel, "scenes", data, "id", stem, _scenes)
		"dialogue":
			_one(rel, "dialogue", data, "char", stem, _dialogue)
		"places":
			_one(rel, "places", data, "id", stem, _places)
		"plates":
			_one(rel, "plates", data, "id", stem, _plates)
		_:
			_errors.append("%s: carpeta desconocida en data/" % rel)

func _one(rel: String, ds: String, data, key: String, stem: String, into: Dictionary) -> void:
	_schema(ds, rel, data)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var id := String(data.get(key, stem))
	if id != stem:
		_errors.append("%s: %s '%s' no coincide con el nombre de archivo" % [rel, key, id])
	if into.has(id):
		_errors.append("%s: duplicado '%s'" % [rel, id])
	into[id] = data

func _cross_checks() -> void:
	_react_list = _reactions.keys()
	_react_list.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	var ents = _entities if not _entities.is_empty() else null
	var ctx := markup_ctx()
	if ents != null:
		ctx["entities"] = ents
	var tctx := ctx.duplicate()
	tctx["allow_placeholders"] = true
	# documentos
	var dids: Array = _docs.keys()
	dids.sort()
	for id in dids:
		var d: Dictionary = _docs[id]
		var rel: String = _doc_file[id]
		if ents != null:
			for f in ["entity"]:
				if d.has(f) and not ents.has(d[f]):
					_errors.append("%s: entidad '%s' inexistente (%s)" % [rel, d[f], f])
			for e in d.get("clip_entities", []):
				if not ents.has(e):
					_errors.append("%s: clip_entities '%s' inexistente" % [rel, e])
			if typeof(d.get("catalog")) == TYPE_DICTIONARY:
				for e in d.catalog.get("entities", []):
					if not ents.has(e):
						_errors.append("%s: catalog.entities '%s' inexistente" % [rel, e])
			if typeof(d.get("measure")) == TYPE_DICTIONARY and not ents.has(d.measure.get("entity", "")):
				_errors.append("%s: measure.entity '%s' inexistente" % [rel, d.measure.get("entity", "")])
		var srcs = _lists.get("src_types", {})
		if typeof(srcs) == TYPE_DICTIONARY and not srcs.is_empty() and typeof(d.get("src_type")) == TYPE_STRING and not srcs.has(d.src_type):
			_errors.append("%s: src_type '%s' no está en lists.src_types" % [rel, d.src_type])
		var slips = _lists.get("slip_topics", {})
		if typeof(slips) == TYPE_DICTIONARY and not slips.is_empty() and typeof(d.get("slip_topic")) == TYPE_STRING and not slips.has(d.slip_topic):
			_errors.append("%s: slip_topic '%s' no está en lists.slip_topics" % [rel, d.slip_topic])
		var qids := {}
		for p in d.get("parts", []):
			if typeof(p) != TYPE_DICTIONARY or typeof(p.get("text")) != TYPE_STRING:
				continue
			for t in Markup.parse(p.text, ctx).tramos:
				for q in t.tags.q:
					qids[q] = true
		for q in qids:
			if not d.get("src_en", {}).has(q):
				_errors.append("%s: q:%s sin src_en" % [rel, q])
	# entidades (menciones, e:, p:) en TODO campo de texto con marcado y en toda lista de etiquetas de data/
	# (§4.3: «entidad inexistente» es error de lint). Los campos los recoge Schema.check (kind markup|tpl|tags).
	if ents != null:
		for f in _fields:
			match String(f.kind):
				"markup", "tpl":
					for e in _ent_errors(String(f.v), ctx if f.kind == "markup" else tctx):
						_errors.append("%s: %s: %s" % [f.rel, f.path, e])
				"tags":
					for tg in f.v:
						var s := String(tg)
						var pre := s.get_slice(":", 0)
						var val := s.substr(pre.length() + 1)
						if (pre == "e" or pre == "p") and val != "" and not val.contains("${") and not ents.has(val):
							_errors.append("%s: %s: etiqueta %s inexistente" % [f.rel, f.path, s])
	# conclusiones: plantilla y fragmentos de documentos existentes
	var tpls: Dictionary = _lists.get("templates", {})
	for cid in _conc_list:
		var c: Dictionary = _conclusions[cid]
		if not tpls.is_empty() and not tpls.has(c.get("template", "")):
			_errors.append("conclusions %s: plantilla '%s' inexistente" % [cid, c.get("template", "")])
		var frs: Array = []
		for r in c.get("routes", []):
			frs.append_array(r.get("frags", []))
		for s in c.get("subroutes", {}).values():
			frs.append_array(s.get("frags", []))
		for f in frs:
			var ref := String(f.get("ref", ""))
			var h := ref.find("#")
			if h > 0 and not ref.contains(":"):
				var did := ref.substr(0, h)
				if _docs.has(did) and doc_tramo(did, ref.substr(h + 1)).is_empty():
					_errors.append("conclusions %s: %s: el documento no tiene el tramo #%s" % [cid, ref, ref.substr(h + 1)])
			var cp := String(f.get("copy", ""))
			if cp != "" and cp.contains("@") and _docs.has(cp.get_slice("@", 0)) and not _copies.has(cp):
				_errors.append("conclusions %s: ejemplar '%s' inexistente" % [cid, cp])

func _ent_errors(text: String, ctx: Dictionary) -> Array:
	var out: Array = []
	for e in Markup.lint(text, ctx):
		if e.contains("inexistente") or e.begins_with("artículo duplicado"):
			out.append(e)
	return out

static func _sorted_keys(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k

# ---------------- contrato §3.8 ----------------
func errors() -> Array:
	return _errors.duplicate()

func doc(id: String) -> Dictionary:
	return _docs.get(id, {})

func docs() -> Dictionary:
	return _docs

# {copy: {id, holder, area?, class (resuelta), via, from, to}, doc: "D05"}; {} si no existe.
func copy(copy_id: String) -> Dictionary:
	return _copies.get(copy_id, {})

func parsed(doc_id: String, part_id: String) -> Dictionary:
	var key := doc_id + "|" + part_id
	if _parsed.has(key):
		return _parsed[key]
	var d: Dictionary = _docs.get(doc_id, {})
	for p in d.get("parts", []):
		if typeof(p) == TYPE_DICTIONARY and String(p.get("id", "")) == part_id:
			var pt := Markup.parse(String(p.get("text", "")), markup_ctx())
			_parsed[key] = pt
			return pt
	return {}

func entity(id: String) -> Dictionary:
	return _entities.get(id, {})

func entities() -> Dictionary:
	return _entities

func lists() -> Dictionary:
	return _lists

func template(id: String) -> Dictionary:
	return _lists.get("templates", {}).get(id, {})

func conclusion(id: String) -> Dictionary:
	return _conclusions.get(id, {})

func conclusions() -> Array:
	var out: Array = []
	for id in _conc_list:
		out.append(_conclusions[id])
	return out

func reaction(id: String) -> Dictionary:
	return _reactions.get(id, {})

func reactions() -> Array:
	var out: Array = []
	for id in _react_list:
		out.append(_reactions[id])
	return out

func schedule() -> Dictionary:
	return _schedule

func place(id: String) -> Dictionary:
	return _places.get(id, {})

func places() -> Dictionary:
	return _places

func plate(id: String) -> Dictionary:
	return _plates.get(id, {})

func dialogue(char_id: String) -> Dictionary:
	return _dialogue.get(char_id, {})

func scene(id: String) -> Dictionary:
	return _scenes.get(id, {})

func canon() -> Array:
	return _canon

func endings() -> Dictionary:
	return _endings

func eggs() -> Array:
	return _eggs

# entidad -> [{doc, label}]: docs cuyo catalog.entities la contiene (doc = id) + ruido de catalog/*.json (doc = "").
# Orden estable: docs por id, luego ruido por etiqueta. q_catalog mezcla con Det.shuffle.
func catalog() -> Dictionary:
	if _catalog != null:
		return _catalog
	var out := {}
	for id in _sorted_keys(_docs):
		var c = _docs[id].get("catalog")
		if typeof(c) != TYPE_DICTIONARY:
			continue
		for e in c.get("entities", []):
			if not out.has(e):
				out[e] = []
			out[e].append({"doc": id, "label": String(c.get("label", ""))})
	var noise := _noise.duplicate()
	noise.sort_custom(func(a, b): return String(a.get("label", "")) < String(b.get("label", "")))
	for nz in noise:
		for e in nz.get("entities", []):
			if not out.has(e):
				out[e] = []
			out[e].append({"doc": "", "label": String(nz.get("label", ""))})
	_catalog = out
	return out

func text(key: String, vars := {}) -> String:
	if not _texts.has(key):
		return key
	return Markup.fill(String(_texts[key]), vars)

func content_hash() -> String:
	if _hash == "":
		_hash = J.stringify_canon(_files).md5_text()
	return _hash

# ---------------- extensiones ----------------
func conclusions_meta() -> Dictionary:
	return {"mandatory": _conc_file.get("mandatory", []), "lot_counts": _conc_file.get("lot_counts", []),
		"alias_rules": _conc_file.get("alias_rules", [])}

func plates() -> Dictionary:
	return _plates

func scenes() -> Dictionary:
	return _scenes

func dialogues() -> Dictionary:
	return _dialogue

func map() -> Dictionary:
	return _map

func fonts() -> Dictionary:
	return _fonts

func audio() -> Dictionary:
	return _audio

func texts() -> Dictionary:
	return _texts

func files() -> Dictionary:
	return _files

# Contexto de Markup con superficies de entidades y abreviaturas de lists.abbrev.
func markup_ctx() -> Dictionary:
	if _names == null:
		_names = {}
		for id in _entities:
			_names[id] = String(_entities[id].get("name", id))
	return {"names": _names, "abbrev": _lists.get("abbrev", Markup.DEFAULT_ABBREV)}

# Plantilla runtime -> ParsedText: Markup.fill(src, vars) y parse con el contexto del repo; act reemplaza @act.
func parse_text(src: String, vars := {}, act := "") -> Dictionary:
	var ctx := markup_ctx().duplicate()
	if act != "":
		ctx["act"] = act
	return Markup.parse(Markup.fill(src, vars), ctx)

# Tramo #tid de un documento: {part, from, to, tags, id} o {}.
func doc_tramo(doc_id: String, tid: String) -> Dictionary:
	var d: Dictionary = _docs.get(doc_id, {})
	for p in d.get("parts", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pt := parsed(doc_id, String(p.get("id", "")))
		for t in pt.get("tramos", []):
			if t.id == tid:
				var r: Dictionary = t.duplicate()
				r["part"] = p.id
				return r
	return {}
