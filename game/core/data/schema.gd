# core/data/schema.gd — validación estructural de cada dataset de §4.1. Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8, §4.
# check(dataset, value) -> ["ruta: mensaje"] (vacío = válido). Nunca push_error.
# dataset ∈ DATASETS. "docs"/"scenes"/"dialogue"/"places"/"plates" validan UN archivo (un objeto).
# Reglas comunes: campos que empiezan con "_" se ignoran; campos desconocidos = error (salvo objetos abiertos);
# textos con marcado pasan por Markup.lint (sintaxis; las entidades las verifica DataRepo); condiciones por Cond.validate.
extends RefCounted

const Markup = preload("res://core/text/markup.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const DATASETS := ["fonts", "audio", "ui_text", "lists", "entities", "canon_bible", "docs", "catalog", "schedule",
	"conclusions", "reactions", "endings", "easter_eggs", "scenes", "dialogue", "places", "plates", "map"]

const CLS := {"t": "enum", "v": ["I", "P", "C"]}
const VEC3 := {"t": "list", "of": "num", "min": 3, "max": 3}
const STRS := {"t": "list", "of": "str"}
const ENT_KINDS := ["persona", "lugar", "documento", "objeto", "fecha", "concepto", "suceso"]
const WEEKDAYS := ["lun", "mar", "mie", "mié", "jue", "vie", "sab", "sáb", "dom"]   # = los que acepta Cond (weekday)
const EFFECT_OPS := ["carta", "columna", "noticia", "escena", "linea", "retirar", "cerrar", "silueta", "flag",
	"alterar_lugar", "devolver", "paga", "arrancar", "linea_siguiente_comunicacion", "evento_mundo"]

# ctx (extensión compatible): {abbrev: [..]} = lists.abbrev del repo, para que el lint de oraciones del esquema
# coincida con el de runtime (DataRepo lo pasa). col (opcional): recibe [{path, kind: markup|tpl|tags, v}] de cada
# campo de texto con marcado o lista de etiquetas (DataRepo verifica ahí entidades inexistentes, §4.3).
static func check(dataset: String, value, ctx := {}, col = null) -> Array:
	var errs: Array = []
	var spec = _spec(dataset)
	if spec == null:
		return ["%s: dataset desconocido" % dataset]
	_v(value, spec, dataset, errs, ctx, col)
	_extra(dataset, value, errs)
	return errs

# ---------- especificaciones ----------
static func _obj(f: Dictionary, req: Array = [], open := false) -> Dictionary:
	return {"t": "obj", "f": f, "req": req, "open": open}

static func _list(of, mn := 0) -> Dictionary:
	return {"t": "list", "of": of, "min": mn}

static func _map(of) -> Dictionary:
	return {"t": "map", "of": of}

static func _enum(v: Array) -> Dictionary:
	return {"t": "enum", "v": v}

static func _or(a: Array) -> Dictionary:
	return {"t": "or", "of": a}

static func _spec(ds: String):
	match ds:
		"fonts":
			return _obj({"slots": _map(_obj({"file": "str", "italic": "str"}, ["file"])), "fallback": "str"}, ["slots"], true)
		"audio", "map":
			return {"t": "dict"}
		"ui_text":
			return _obj({"text": _map("tpl")}, ["text"])
		"entities":
			return _obj({"entities": _list(_entity())}, ["entities"])
		"lists":
			return _lists()
		"canon_bible":
			return _obj({"facts": _list(_obj({"id": "id", "event": "?date", "published": "?date", "mark": "str", "src": "str",
				"src_en": "str", "knowable": _map("date"), "text": "str", "hue": "str", "false_lead": "bool"},
				["id", "mark", "knowable", "text"], true))}, ["facts"])
		"docs":
			return _doc()
		"catalog":
			return _obj({"noise": _list(_obj({"label": "str", "entities": STRS}, ["label", "entities"]))}, ["noise"])
		"schedule":
			return _schedule()
		"conclusions":
			return _conclusions()
		"reactions":
			return _obj({"reactions": _list(_reaction())}, ["reactions"])
		"endings":
			return _obj({"rank_note": "str",
				"endings": _list(_obj({"id": "id", "order": "int", "rank": "int", "name": "str", "cond": "cond", "card": "str", "scene": "str"}, ["id", "order", "rank", "cond"])),
				"variants": _list(_obj({"id": "id", "cond": "cond", "card_add": "str", "epilogue": "str"}, ["id", "cond"]))}, ["endings"])
		"easter_eggs":
			return _obj({"eggs": _list(_obj({"id": "id", "name": "str", "trigger": "dict", "note": "markup"}, ["id", "trigger", "note"]))}, ["eggs"])
		"scenes":
			return _scene()
		"dialogue":
			return _dialogue()
		"places", "plates":
			return _place()
	return null

static func _entity() -> Dictionary:
	return _obj({"id": "id", "kind": _enum(ENT_KINDS), "name": "str", "index": "str", "noun": "str", "aliases": STRS, "doc": "str"},
		["id", "kind", "name", "index"])

static func _lists() -> Dictionary:
	var field := _obj({"id": "id", "label": "str", "accept": _obj({"kinds": STRS, "list": "str"})}, ["id", "label", "accept"])
	var tpl := _obj({"name": "str", "lines": _list(_obj({"optional": "bool", "fields": _list(field, 1)}, ["fields"]), 1)}, ["name", "lines"])
	return _obj({
		"verbos": STRS, "relaciones": STRS, "estados": STRS, "abbrev": STRS,
		"medios": _list(_obj({"id": "id", "label": "str", "ch": "str", "entities": STRS}, ["id", "label", "ch"])),
		"templates": _map(tpl),
		"assertions": _list(_obj({"id": "id", "kind": "str", "topic": "str", "requires": STRS, "ad_text": "str", "phrase": "tpl",
			"about_holmes": "bool", "says_alive": "bool", "channels": STRS}, ["id", "kind", "phrase"], true)),
		"ad_forms": _list(_obj({"id": "id", "text": "tpl", "slots": _map({"t": "dict"}), "forbid_tags": STRS,
			"forbid_kinds_lugar_londres": "bool"}, ["id", "text"], true)),
		"src_types": _map("str"), "slip_topics": _map("str"), "topic_groups": _map(STRS),
		"sensors": {"t": "dict"},
		"diary": _map(_obj({"text": "tpl", "tags": "tags"}, ["text"])),
		"report_cats": _list(_obj({"cat": "id"}, ["cat"], true)),
	}, [], true)

static func _doc() -> Dictionary:
	var copy := _obj({"id": "id", "holder": _enum(["L1", "tomo", "Crane", "BM", "L2", "L3", "L4", "L5", "L6", "L7", "L8"]),
		"area": "str", "class": CLS, "via": _enum(["desk", "tome", "shelf", "slip", "counter", "place"]), "from": "tk", "to": "tk"},
		["id", "holder", "via"])
	var part := _obj({"id": "id", "text": "markup", "inserts": _map("str"), "when": "cond"}, ["id", "text"])
	return _obj({
		"id": "id", "entity": "id", "title": "str", "src_type": "id", "class": CLS, "origin": "id", "date": "date",
		"chron_date": "?date", "knowable": "?date", "font": _enum(Markup.FONT_SLOTS), "paper": "id",
		"paper_mm": {"t": "?list", "of": "num", "min": 2, "max": 2}, "machine": "?str", "clip_entities": STRS,
		"measure": {"t": "?obj", "f": {"entity": "id", "tags": STRS}, "req": ["entity"], "open": false},
		"clip_mode": _enum(["normal", "memoria"]), "slip_topic": "?str", "visible_cats": STRS,
		"catalog": {"t": "?obj", "f": {"label": "str", "entities": STRS}, "req": ["label", "entities"], "open": false},
		"copies": _list(copy, 1), "parts": _list(part, 1), "src_en": _map("str"), "plate": "?str", "words": "int",
	}, ["id", "entity", "title", "src_type", "class", "date", "font", "paper", "copies", "parts", "words"])

static func _schedule() -> Dictionary:
	var day := _obj({"day": "int", "key": "str", "date": "date", "weekday": "str", "label": "str", "slots": STRS,
		"mail": "bool", "times": "bool", "fixed": "bool"}, ["day", "key", "date", "weekday", "slots"])
	var window := _obj({"days": _or([_enum(["all"]), _list("int")]), "slots": _or([_enum(["all"]), STRS]), "from": "tk", "to": "tk"})
	var area := _obj({"open": _list(window), "free": "bool", "needs": "cond"}, ["open"])
	return _obj({
		"days": _list(day, 1), "slot_hours": _map("str"), "passes": _map("int"), "lot": _map("int"),
		"reports": _list(_obj({"n": "int", "tk": "tk", "final": "bool"}, ["n", "tk"])),
		"ads": {"t": "dict"}, "places": _map(_obj({"areas": _map(area)}, ["areas"])),
		"column": _list(_obj({"tk": "tk", "r": "id"}, ["tk", "r"])), "voice_b": _map("tk"), "voice_a": {"t": "dict"},
		"money_d": _map("int"), "baedeker": "markup",
	}, ["days"])

static func _conclusions() -> Dictionary:
	var frag := _obj({"ref": "id", "copy": "str"}, ["ref"])
	var deps := _enum(["fija", "columna", "garantizada", "opcional"])
	var route := _obj({"id": "id", "star": "bool", "deps": deps, "from": "tk", "frags": _list(frag), "cut_by": STRS, "pair": STRS}, ["id"])
	var sub := _obj({"star": "bool", "deps": deps, "from": "tk", "frags": _list(frag, 1), "cut_by": STRS}, ["frags"])
	var conc := _obj({
		"id": "id", "kind": _enum(["obligatoria", "practica", "opcional"]), "template": "id", "answers": {"t": "dict"},
		"constraints": _list({"t": "dict"}), "groups": _list(_obj({"id": "id", "line": "int", "tags": STRS}, ["id", "line", "tags"])),
		"tags_extra": STRS, "keys": _obj({"entities": STRS, "kinds": STRS}), "validate": _obj({"from": "tk", "until": "?tk"}),
		"routes": _list(route), "subroutes": _map(sub), "blue_pencil": _obj({"missing": "str", "wrong": "str"}),
		"practice_origins": "str",
	}, ["id", "kind", "template", "answers", "groups", "keys"])
	return _obj({"mandatory": STRS, "lot_counts": STRS,
		"alias_rules": _list(_obj({"when_sealed": "id", "equiv": STRS}, ["when_sealed", "equiv"])),
		"conclusions": _list(conc)}, ["conclusions"])

static func _reaction() -> Dictionary:
	var lat := _obj({"tipo": _enum(["voz_a", "voz_b", "fija", "inmediata", "siguiente_salida", "siguiente_comunicacion", "dias"]),
		"tk": "tk", "n": "int"}, ["tipo"])
	var disp := _obj({"evento": _or(["str", STRS]), "match": {"t": "dict"}, "una_vez_por": STRS, "contador": "str",
		"n_in": _list("int"), "tk": "tk"}, ["evento"], true)
	var eff := _obj({"op": _enum(EFFECT_OPS)}, ["op"], true)
	var rastro := _obj({"tpl": "str", "texto": "tpl", "nodo": "str", "tags": "tags", "when": "cond",
		"tono": _obj({"alto": "tpl", "bajo": "tpl"})}, ["tpl"])
	return _obj({
		"id": "id", "tipo": _enum(["columna", "garantizada_por_acto", "opcional", "respuesta", "silencio"]),
		"garantizada_si": {"t": "dict"}, "lado": _enum(["holmes", "mycroft", "moran", "respuesta"]), "voz": "str",
		"nivel": "int", "canal": "str", "actor": STRS, "disparador": disp, "condiciones": "cond", "ancla": STRS,
		"ancla_de": {"t": "dict"}, "latencia": lat, "efecto": _list(eff), "doc": {"t": "dict"}, "rastro": _list(rastro),
		"corta": _list({"t": "dict"}), "agrega": STRS,
		"variante_blanda": {"t": "?obj", "f": {"efecto": _list(eff), "corta": _list({"t": "dict"})}, "req": ["efecto"], "open": false},
		"exento_d2": "bool", "exento_d2_desde_dia": "int",
	}, ["id", "tipo", "lado", "voz", "nivel", "canal", "disparador", "latencia", "efecto", "rastro", "corta"])

static func _line() -> Dictionary:
	return _obj({"id": "id", "who": "str", "text": "markup", "gen": "str", "tpl": _map("tpl"), "fallback": "markup",
		"when": "cond", "effects": _list({"t": "dict"}), "reaction": "str"}, ["id"])

static func _scene() -> Dictionary:
	return _obj({"id": "id", "place": "id", "area": "str", "tk": "tk", "plate": "str", "origin": "str", "when": "cond",
		"auto": "bool", "lines": _list(_line(), 1),
		"variants": _list(_obj({"when": "cond", "replace": _map("markup"), "append": _list(_line())}, ["when"]))},
		["id", "place", "lines"])

static func _dialogue() -> Dictionary:
	var dl := _obj({"id": "id", "layer": _enum(["afirmacion", "tema", "documento", "entidad", "tipo", "generica"]),
		"match": {"t": "dict"}, "when": "cond", "text": "markup", "effects": _list({"t": "dict"}), "reaction": "str"},
		["id", "layer", "text"])
	return _obj({"char": "id", "label": "str", "intro": "str", "addr": "str", "sensor": "?str", "max_questions": "int",
		"trait": "str", "closing": "markup", "ask_phrase": _map("tpl"), "lines": _list(dl, 1)}, ["char", "label", "lines"])

static func _place() -> Dictionary:
	var frame := _obj({"id": "id", "area": "str", "pos": VEC3, "look": VEC3, "fov": "num",
		"orbit": _obj({"pivot": VEC3, "yaw": "num", "pitch": "num"})}, ["id", "pos", "look"])
	var prop := _obj({"id": "id", "type": "str", "pos": VEC3, "rot": "num", "p": {"t": "dict"}}, ["id", "type", "pos"])
	var node := _obj({"id": "id", "prop": "str", "noun": "str", "anchor": _obj({"c": VEC3, "s": VEC3}, ["c", "s"]),
		"examine": "markup", "tags": "tags", "cls": CLS, "area": "str", "when": "cond"}, ["id", "anchor", "examine"])
	var chr := _obj({"id": "id", "area": "str", "pos": VEC3, "rot": "num", "pose": "str", "trait": "str", "when": "cond"}, ["id", "pos"])
	return _obj({"id": "id", "name": "str", "streets": STRS, "areas": _map(_obj({"desc": "str"}, [], true)), "observers": STRS,
		"epigraph": "str", "frames": _list(frame, 1), "light": _map("str"), "props": _list(prop), "nodes": _list(node),
		"characters": _list(chr), "silhouettes": _map(_obj({"frame": "str", "pos": VEC3, "rot": "num"}, ["frame", "pos"])),
		"variants": {"t": "dict"}, "fixed": "bool", "origin": "str", "doc_variant": _map("str"), "place": "str", "day": "int",
		"slot": "str"}, ["id", "name", "frames", "props", "nodes"])

# ---------- motor ----------
static func _v(v, spec, path: String, errs: Array, ctx := {}, col = null) -> void:
	if typeof(spec) == TYPE_STRING:
		_vs(v, spec, path, errs, ctx, col)
		return
	var t: String = spec.t
	if t.begins_with("?"):
		if v == null:
			return
		t = t.substr(1)
	match t:
		"dict":
			if typeof(v) != TYPE_DICTIONARY:
				errs.append("%s: se esperaba objeto" % path)
		"obj":
			if typeof(v) != TYPE_DICTIONARY:
				errs.append("%s: se esperaba objeto" % path)
				return
			for r in spec.get("req", []):
				if not v.has(r):
					errs.append("%s: falta '%s'" % [path, r])
			var keys: Array = v.keys()
			keys.sort()
			for k in keys:
				var ks := String(k)
				if ks.begins_with("_"):
					continue
				if spec.f.has(ks):
					_v(v[k], spec.f[ks], path + "." + ks, errs, ctx, col)
				elif not spec.get("open", false):
					errs.append("%s: campo desconocido '%s'" % [path, ks])
		"list":
			if typeof(v) != TYPE_ARRAY:
				errs.append("%s: se esperaba lista" % path)
				return
			if v.size() < int(spec.get("min", 0)):
				errs.append("%s: mínimo %d elementos" % [path, int(spec.get("min", 0))])
			if spec.has("max") and v.size() > int(spec.max):
				errs.append("%s: máximo %d elementos" % [path, int(spec.max)])
			for i in v.size():
				_v(v[i], spec.of, "%s[%d]" % [path, i], errs, ctx, col)
		"map":
			if typeof(v) != TYPE_DICTIONARY:
				errs.append("%s: se esperaba objeto" % path)
				return
			var keys2: Array = v.keys()
			keys2.sort()
			for k in keys2:
				if String(k).begins_with("_"):
					continue
				_v(v[k], spec.of, path + "." + String(k), errs, ctx, col)
		"enum":
			if not spec.v.has(v):
				errs.append("%s: valor '%s' no está en %s" % [path, str(v), str(spec.v)])
		"or":
			for alt in spec.of:
				var tmp: Array = []
				_v(v, alt, path, tmp, ctx, null)
				if tmp.is_empty():
					return
			errs.append("%s: valor '%s' no coincide con ninguna forma" % [path, str(v)])
		_:
			errs.append("%s: especificación desconocida %s" % [path, t])

static func _vs(v, t: String, path: String, errs: Array, ctx := {}, col = null) -> void:
	if t.begins_with("?"):
		if v == null:
			return
		t = t.substr(1)
	match t:
		"any":
			pass
		"dict":
			if typeof(v) != TYPE_DICTIONARY:
				errs.append("%s: se esperaba objeto" % path)
		"list":
			if typeof(v) != TYPE_ARRAY:
				errs.append("%s: se esperaba lista" % path)
		"str":
			if typeof(v) != TYPE_STRING:
				errs.append("%s: se esperaba texto" % path)
		"id":
			if typeof(v) != TYPE_STRING or String(v) == "":
				errs.append("%s: se esperaba id no vacío" % path)
		"int":
			if typeof(v) != TYPE_INT:
				errs.append("%s: se esperaba entero" % path)
		"num":
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				errs.append("%s: se esperaba número" % path)
		"bool":
			if typeof(v) != TYPE_BOOL:
				errs.append("%s: se esperaba bool" % path)
		"date":
			if typeof(v) != TYPE_STRING or not Markup._is_date(v):
				errs.append("%s: fecha AAAA-MM-DD inválida '%s'" % [path, str(v)])
		"tk":
			if typeof(v) != TYPE_STRING or TimeKey.parse(v) < 0:
				errs.append("%s: TimeKey inválido '%s'" % [path, str(v)])
		"cond":
			errs.append_array(Cond.validate(v, path))
		"markup", "tpl":
			if typeof(v) != TYPE_STRING:
				errs.append("%s: se esperaba texto" % path)
				return
			var lctx := {"allow_placeholders": t == "tpl"}
			if ctx.has("abbrev"):
				lctx["abbrev"] = ctx.abbrev
			for e in Markup.lint(v, lctx):
				errs.append("%s: %s" % [path, e])
			if col != null:
				col.append({"path": path, "kind": t, "v": v})
		"tags":
			if typeof(v) != TYPE_ARRAY:
				errs.append("%s: se esperaba lista de etiquetas" % path)
				return
			if col != null:
				col.append({"path": path, "kind": "tags", "v": v})
			for i in v.size():
				var s := String(v[i])
				var c := s.find(":")
				if c <= 0 or not Markup.PREFIXES.has(s.substr(0, c)) or c == s.length() - 1:
					errs.append("%s[%d]: etiqueta mal formada '%s' (prefijo:valor)" % [path, i, s])
		_:
			errs.append("%s: tipo desconocido %s" % [path, t])

# ---------- reglas que no son de forma ----------
static func _extra(ds: String, v, errs: Array) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	match ds:
		"reactions":
			for r in v.get("reactions", []):
				if typeof(r) == TYPE_DICTIONARY and not r.get("corta", []).is_empty() and r.get("variante_blanda") == null:
					errs.append("reactions.%s: corta sin variante_blanda (D1)" % r.get("id", "?"))
		"docs":
			var seen := {}
			for p in v.get("parts", []):
				if typeof(p) != TYPE_DICTIONARY or typeof(p.get("text")) != TYPE_STRING:
					continue
				for t in Markup.parse(p.text).tramos:
					if t.id == "":
						continue
					if seen.has(t.id):
						errs.append("docs.%s: tramo #%s duplicado" % [v.get("id", "?"), t.id])
					seen[t.id] = true
			var cids := {}
			for c in v.get("copies", []):
				if typeof(c) == TYPE_DICTIONARY:
					if cids.has(c.get("id")):
						errs.append("docs.%s: ejemplar %s duplicado" % [v.get("id", "?"), c.get("id")])
					cids[c.get("id")] = true
		"places", "plates":
			var nids := {}
			for nd in v.get("nodes", []):
				if typeof(nd) == TYPE_DICTIONARY:
					if nids.has(nd.get("id")):
						errs.append("%s.%s: nodo %s duplicado" % [ds, v.get("id", "?"), nd.get("id")])
					nids[nd.get("id")] = true
					var tp := String(nd.get("prop", ""))
					if tp != "" and not _has_id(v.get("props", []), tp):
						errs.append("%s.%s: nodo %s apunta a prop inexistente %s" % [ds, v.get("id", "?"), nd.get("id"), tp])
			for pr in v.get("props", []):
				if typeof(pr) == TYPE_DICTIONARY and not String(pr.get("type", "")).contains("."):
					errs.append("%s.%s: prop %s: type debe ser <módulo>.<función>" % [ds, v.get("id", "?"), pr.get("id")])
		"schedule":
			var seen_days := {}
			for d in v.get("days", []):
				if typeof(d) != TYPE_DICTIONARY:
					continue
				if not WEEKDAYS.has(String(d.get("weekday", ""))):
					errs.append("schedule.days: día %s: weekday '%s' no está en %s" % [str(d.get("day")), str(d.get("weekday")), str(WEEKDAYS)])
				if seen_days.has(d.get("day")):
					errs.append("schedule.days: día %s duplicado" % str(d.get("day")))
				seen_days[d.get("day")] = true
			for p in v.get("places", {}):
				for a in v.places[p].get("areas", {}):
					for w in v.places[p].areas[a].get("open", []):
						if typeof(w) == TYPE_DICTIONARY and typeof(w.get("slots")) == TYPE_ARRAY:
							for s in w.slots:
								if not TimeKey.ORD.has(String(s)):
									errs.append("schedule.places.%s.%s: franja desconocida %s" % [p, a, s])
		"conclusions":
			var ids := {}
			for c in v.get("conclusions", []):
				if typeof(c) != TYPE_DICTIONARY:
					continue
				if ids.has(c.get("id")):
					errs.append("conclusions: %s duplicada" % c.get("id"))
				ids[c.get("id")] = true
			for k in ["mandatory", "lot_counts"]:
				for cid in v.get(k, []):
					if not ids.has(cid):
						errs.append("conclusions.%s: %s no existe" % [k, cid])

static func _has_id(arr, id: String) -> bool:
	for x in arr:
		if typeof(x) == TYPE_DICTIONARY and String(x.get("id", "")) == id:
			return true
	return false
