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
	"dossier", "corpus", "reactions", "endings", "easter_eggs", "scenes", "dialogue", "places", "plates", "map", "fisica"]

const CLS := {"t": "enum", "v": ["I", "P", "C"]}
const VEC3 := {"t": "list", "of": "num", "min": 3, "max": 3}
const STRS := {"t": "list", "of": "str"}
const ENT_KINDS := ["persona", "lugar", "documento", "objeto", "fecha", "concepto", "suceso"]
# §12.2: en data/ los días de semana son códigos ASCII (schedule.days[].weekday y átomos weekday de Cond.validate);
# Cond.eval sigue tolerando «mié»/«sáb» en runtime.
const WEEKDAYS := ["lun", "mar", "mie", "jue", "vie", "sab", "dom"]
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
		"audio", "map", "fisica":
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
		"dossier":
			return _dossier()
		"corpus":
			return _obj({"activas": STRS, "inactivas": STRS}, ["activas", "inactivas"])
		"reactions":
			return _obj({"reactions": _list(_reaction())}, ["reactions"])
		"endings":
			return _obj({"rank_note": "str",
				"endings": _list(_obj({"id": "id", "order": "int", "rank": "int", "name": "str", "cond": "cond", "card": "str", "scene": "str"}, ["id", "order", "rank", "cond"])),
				"variants": _list(_obj({"id": "id", "cond": "cond", "card_add": "str", "epilogue": "str"}, ["id", "cond"]))}, ["endings"])
		"easter_eggs":
			return _obj({"eggs": _list(_obj({"id": "id", "name": "str", "trigger": "dict", "note": "markup", "flag": "str"}, ["id", "trigger", "note"]))}, ["eggs"])
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
	return _obj({
		"abbrev": STRS,
		"medios": _list(_obj({"id": "id", "label": "str", "ch": "str", "entities": STRS}, ["id", "label", "ch"])),
		"assertions": _list(_obj({"id": "id", "kind": "str", "topic": "str", "requires": STRS, "ad_text": "str", "phrase": "tpl",
			"about_holmes": "bool", "says_alive": "bool", "channels": STRS}, ["id", "kind", "phrase"], true)),
		"ad_forms": _list(_obj({"id": "id", "text": "tpl", "slots": _map({"t": "dict"}), "forbid_tags": STRS,
			"forbid_kinds_lugar_londres": "bool"}, ["id", "text"], true)),
		"src_types": _map("str"), "slip_topics": _map("str"), "topic_groups": _map(STRS),
		"sensors": {"t": "dict"},
		"diary": _map(_obj({"text": "tpl", "tags": "tags"}, ["text"])),
		# GDD_v3 §6.10: categorías de Moran (recortes y preguntas del Expediente)
		"report_cats": _list(_obj({"cat": "id", "pregunta": _list(_obj({"q": STRS, "respuestas": STRS, "no_respuestas": STRS,
			"kind": "str", "tinta": "bool", "lapiz": "bool"}, ["q"]))}, ["cat"], true)),
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
		"inserts": _map("str"),
		# GDD_v3 §3.4: ficha de Lisle, nota del cliente, marquitas y notas al margen (crónicas); solo_margen (D01N);
		# tarjeta_de (NC.*). Lo lee WorldModel.view.
		"v3": _obj({"ficha": _obj({"trata": "str", "cuando": "str", "por_que": "str"}, ["trata", "cuando", "por_que"]),
			"nota_cliente": "id", "marcas": _list(_obj({"parte": "id", "tramo": "id"}, ["tramo"])),
			"margen": _list(_obj({"doc": "id", "tramo": "id", "firma": "str", "junto_a": _obj({"parte": "id", "tramo": "id"}, ["tramo"])}, ["doc", "tramo"])),
			"solo_margen": "bool", "tarjeta_de": "id"}, [], true),
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
		# GDD_v2 §B.5: garantía de revelado de lugares (by) con disparadores anticipados (ents / ents_all) y novedades de
		# la tienda de Crane (DataRepo atrasa el `from` de esos ejemplares a la franja siguiente a tk).
		"reveal": _map(_obj({"by": "tk", "ents": STRS, "ents_all": STRS, "areas": STRS}, ["by"])),
		"stock": _list(_obj({"tk": "tk", "copies": STRS, "line": "str"}, ["tk", "copies"])),
	}, ["days"])

# GDD_v3 §1.7: data/dossier.json.
static func _dossier() -> Dictionary:
	var frag := _obj({"ref": "id", "copy": "str"}, ["ref"])
	var deps := _enum(["fija", "columna", "garantizada", "opcional"])
	var route := _obj({"id": "id", "star": "bool", "deps": deps, "from": "tk", "frags": {"t": "list", "of": frag, "min": 2, "max": 2},
		"cut_by": STRS}, ["id", "deps", "frags"])
	var grupo := _obj({"id": "id", "tags": STRS}, ["id", "tags"])
	var variante := _obj({"id": "id", "principal": "bool", "respuestas": STRS,
		"grupos": {"t": "list", "of": grupo, "min": 2, "max": 2}, "claves": _obj({"entities": STRS, "kinds": STRS}),
		"valida": _obj({"desde": "?tk", "hasta": "?tk"}), "tinta": "str", "rutas": _list(route)},
		["id", "respuestas", "grupos", "claves", "tinta", "rutas"])
	# origen_columna (playtest v3): la línea de origen cuando lo que llegó vino en los avisos del Times (columna insertada)
	var nace := _obj({"inicio": "str", "leer": "str", "llega": "str", "dicho": "str", "tinta": "id", "nota": "id", "origen": "str",
		"origen_columna": "str"}, ["origen"])
	var preg := _obj({"id": "id", "orden": "int", "obligatoria": "bool", "texto": "str", "nace": _list(nace, 1),
		"dudas": {"t": "list", "of": "str", "min": 2, "max": 3}, "acepta": _list(_enum(ENT_KINDS), 1),
		# playtest v3: el rótulo de cada ranura de prueba, en voz de Lisle (qué mitad muestra cada una; el orden no importa)
		"pruebas": {"t": "list", "of": "str", "min": 2, "max": 2},
		"variantes": {"t": "list", "of": variante, "min": 1, "max": 2},
		"blue_pencil": _obj({"missing": "str", "wrong": "str"}, ["missing", "wrong"]),
		"invariante": _enum(["normal", "desde_nacimiento"])},
		["id", "orden", "obligatoria", "texto", "nace", "dudas", "acepta", "variantes", "blue_pencil", "invariante"])
	return _obj({"max_abiertas": "int", "mostrar_todas": "tk",
		"alias": _list(_obj({"cuando_tinta": "id", "equiv": STRS}, ["cuando_tinta", "equiv"])),
		# ley de la huella (T5): {holmes: [preguntas], moran: [preguntas]}; sin la clave, la tabla de GDD_v3 §4.2
		"huella": _map(STRS),
		"preguntas": _list(preg, 1)}, ["preguntas"])

static func _reaction() -> Dictionary:
	var lat := _obj({"tipo": _enum(["voz_a", "voz_b", "fija", "inmediata", "siguiente_salida", "siguiente_comunicacion", "dias",
		"intrusion"]), "tk": "tk", "n": "int"}, ["tipo"])
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
		# GDD_v3 §4.2 (HA5/HA6): original relacionado con el acto que la dispara
		"relacion": "any",
	}, ["id", "tipo", "lado", "voz", "nivel", "canal", "disparador", "latencia", "efecto", "rastro", "corta"])

static func _line() -> Dictionary:
	return _obj({"id": "id", "who": "str", "text": "markup", "gen": "str", "tpl": _map("tpl"), "fallback": "markup",
		"when": "cond", "effects": _list({"t": "dict"}), "reaction": "str"}, ["id"])

# place es opcional (§12.2): los finales y el epílogo (END.F1–F4, EPI) no ocurren en un lugar del mapa. Sin place, el
# motor la trata como escena de la buhardilla (WorldModel.start_scene) y nunca como escena fija de columna.
static func _scene() -> Dictionary:
	# measure/paper_mm: medida de la escena (M:<escena>.<x>; Clipper.act_clip_measure src scene, RouteDB._measure)
	return _obj({"id": "id", "place": "id", "area": "str", "tk": "tk", "plate": "str", "origin": "str", "when": "cond",
		"auto": "bool", "once": "bool", "lines": _list(_line(), 1),
		"measure": {"t": "?obj", "f": {"entity": "id", "tags": STRS}, "req": ["entity"], "open": false},
		"paper_mm": {"t": "?list", "of": "num", "min": 2, "max": 2},
		"variants": _list(_obj({"when": "cond", "replace": _map("markup"), "append": _list(_line())}, ["when"]))},
		["id", "lines"])

static func _dialogue() -> Dictionary:
	var dl := _obj({"id": "id", "layer": _enum(["afirmacion", "tema", "documento", "entidad", "tipo", "generica"]),
		"match": {"t": "dict"}, "when": "cond", "text": "markup", "effects": _list({"t": "dict"}), "reaction": "str",
		# GDD §10.1 / GDD_v3 §2.1: una línea que ninguna reacción corta puede declararse inmutable ("I"; por defecto "C",
		# testimonio de campo). RouteDB._dlg la usa como clase del fragmento L:<char>.<línea> (T2 la protege).
		"cls": _enum(["I", "C"])},
		["id", "layer", "text"])
	# GDD_v3 §5.2: «¿Dónde consigo…?» (Crane). Motor: Dialogue.donde_items / act_ask_donde (CORE). Abierto: el motor
	# también acepta phrase/requires/text/reveals.
	var donde := _obj({"id": "id", "frase": "str", "requiere": STRS, "texto": "markup", "revela": "?str",
		"variantes": _list(_obj({"when": "cond", "texto": "markup"}, ["when", "texto"]))}, ["id"], true)
	return _obj({"char": "id", "label": "str", "intro": "str", "addr": "str", "addr_anon": "str", "sensor": "?str", "max_questions": "int",
		"trait": "str", "closing": "markup", "ask_phrase": _map("tpl"), "lines": _list(dl, 1), "known": "bool",
		"donde": _list(donde)}, ["char", "label", "lines"])

static func _place() -> Dictionary:
	var frame := _obj({"id": "id", "area": "str", "pos": VEC3, "look": VEC3, "fov": "num",
		"orbit": _obj({"pivot": VEC3, "yaw": "num", "pitch": "num"})}, ["id", "pos", "look"])
	var prop := _obj({"id": "id", "type": "str", "pos": VEC3, "rot": "num", "p": {"t": "dict"}}, ["id", "type", "pos"])
	var node := _obj({"id": "id", "prop": "str", "noun": "str", "anchor": _obj({"c": VEC3, "s": VEC3}, ["c", "s"]),
		"examine": "markup", "tags": "tags", "cls": CLS, "area": "str", "when": "cond", "on_clip_flag": "str",
		"aviso": "id"}, ["id", "anchor", "examine"])
	var chr := _obj({"id": "id", "area": "str", "pos": VEC3, "rot": "num", "pose": "str", "trait": "str", "when": "cond"}, ["id", "pos"])
	return _obj({"id": "id", "name": "str", "streets": STRS, "areas": _map(_obj({"desc": "str"}, [], true)), "observers": STRS,
		"epigraph": "str", "epigraph_by_area": _map("str"), "frames": _list(frame, 1), "light": _map("str"), "props": _list(prop), "nodes": _list(node),
		"characters": _list(chr), "silhouettes": _map(_obj({"frame": "str", "pos": VEC3, "rot": "num", "talk": STRS, "where": "str"}, ["frame", "pos"])),
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
			# inserts (§12.2): {"columna"|"noticias": id de parte existente} a nivel de documento (o, por compatibilidad, de parte)
			var pids := {}
			for p in v.get("parts", []):
				if typeof(p) == TYPE_DICTIONARY:
					pids[String(p.get("id", ""))] = true
			var ins_maps: Array = [v.get("inserts", {})]
			for p in v.get("parts", []):
				if typeof(p) == TYPE_DICTIONARY:
					ins_maps.append(p.get("inserts", {}))
			for im in ins_maps:
				if typeof(im) != TYPE_DICTIONARY:
					continue
				for k in im:
					if String(k).begins_with("_"):
						continue
					if not ["columna", "noticias"].has(String(k)):
						errs.append("docs.%s: inserts.%s desconocido (columna | noticias)" % [v.get("id", "?"), k])
					elif not pids.has(String(im[k])):
						errs.append("docs.%s: inserts.%s apunta a una parte inexistente '%s'" % [v.get("id", "?"), k, im[k]])
		"scenes":
			_scene_variants(v, errs)
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
			# GDD_v3 §6.2: lo del 3D se recorta del texto de su examen; con etiquetas a:/c:, ≤30 palabras
			var all_nodes: Array = (v.get("nodes", []) as Array).duplicate() if typeof(v.get("nodes")) == TYPE_ARRAY else []
			var vs = v.get("variants", {})
			if typeof(vs) == TYPE_DICTIONARY:
				for vk in vs:
					if typeof(vs[vk]) == TYPE_DICTIONARY and typeof(vs[vk].get("add_nodes")) == TYPE_ARRAY:
						all_nodes.append_array(vs[vk].add_nodes)
			for nd in all_nodes:
				if typeof(nd) != TYPE_DICTIONARY or typeof(nd.get("tags")) != TYPE_ARRAY or typeof(nd.get("examine")) != TYPE_STRING:
					continue
				var tagged := false
				for tg in nd.tags:
					if String(tg).begins_with("a:") or String(tg).begins_with("c:"):
						tagged = true
				if tagged:
					var wn := (Markup.parse(nd.examine).words as Array).size()
					if wn > Markup.MAX_TAGGED_WORDS:
						errs.append("%s.%s: nodo %s: examen de %d palabras con etiquetas a:/c: (máx. %d, GDD_v3 §6.2)" % [ds, v.get("id", "?"), nd.get("id"), wn, Markup.MAX_TAGGED_WORDS])
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
		"dossier":
			var qids := {}
			for q in v.get("preguntas", []):
				if typeof(q) != TYPE_DICTIONARY:
					continue
				var qid := String(q.get("id", ""))
				if qids.has(qid):
					errs.append("dossier: %s duplicada" % qid)
				qids[qid] = true
				var prin := 0
				for va in q.get("variantes", []):
					if typeof(va) != TYPE_DICTIONARY:
						continue
					if bool(va.get("principal", false)):
						prin += 1
					for r in va.get("rutas", []):
						if typeof(r) != TYPE_DICTIONARY:
							continue
						for f in r.get("frags", []):
							if typeof(f) == TYPE_DICTIONARY and String(f.get("ref", "")).begins_with("M:"):
								errs.append("dossier.%s.%s: refs M: retiradas en v3" % [qid, r.get("id", "?")])
				if prin != 1:
					errs.append("dossier.%s: exactamente una variante principal (hay %d)" % [qid, prin])
				for n in q.get("nace", []):
					if typeof(n) != TYPE_DICTIONARY:
						continue
					var nk := 0
					for k in ["inicio", "leer", "llega", "dicho", "tinta", "nota"]:
						if n.has(k):
							nk += 1
					if nk != 1:
						errs.append("dossier.%s.nace: exactamente un disparador por objeto (hay %d)" % [qid, nk])
					if n.has("llega"):
						var lg := String(n.llega)
						if not (lg == "voz:A" or lg == "voz:B" or (lg.begins_with("R:") and lg.ends_with(".*")) or (not lg.contains(":") and lg != "")):
							errs.append("dossier.%s.nace.llega: '%s' (voz:A | voz:B | R:<rid>.* | id de documento)" % [qid, lg])
			for q in v.get("preguntas", []):
				if typeof(q) != TYPE_DICTIONARY:
					continue
				for n in q.get("nace", []):
					if typeof(n) == TYPE_DICTIONARY and n.has("tinta") and not qids.has(String(n.tinta)):
						errs.append("dossier.%s.nace.tinta: %s no existe" % [q.get("id", "?"), n.tinta])
			for al in v.get("alias", []):
				if typeof(al) == TYPE_DICTIONARY and not qids.has(String(al.get("cuando_tinta", ""))):
					errs.append("dossier.alias: cuando_tinta %s no existe" % al.get("cuando_tinta", ""))

# §12.2: una variante `replace` cambia el texto de una línea base pero conserva sus tramos: los mismos #id con las
# mismas etiquetas (las rutas citan S:<escena>.<línea> y el grafo toma la intersección de las versiones). La línea
# reemplazada debe existir entre las líneas base (no generadas). Ids de línea únicos (base + append).
static func _scene_variants(v: Dictionary, errs: Array) -> void:
	var sid := String(v.get("id", "?"))
	var base := {}
	var seen := {}
	for ln in v.get("lines", []):
		if typeof(ln) != TYPE_DICTIONARY:
			continue
		var lid := String(ln.get("id", ""))
		if seen.has(lid):
			errs.append("scenes.%s: línea %s duplicada" % [sid, lid])
		seen[lid] = true
		if not ln.has("gen") and typeof(ln.get("text")) == TYPE_STRING:
			base[lid] = String(ln.text)
	var vs = v.get("variants", [])
	if typeof(vs) != TYPE_ARRAY:
		return
	for i in vs.size():
		var var_d = vs[i]
		if typeof(var_d) != TYPE_DICTIONARY:
			continue
		for ap in var_d.get("append", []):
			if typeof(ap) == TYPE_DICTIONARY and seen.has(String(ap.get("id", ""))):
				errs.append("scenes.%s: variants[%d].append: la línea %s ya es una línea base (usar replace)" % [sid, i, ap.get("id", "")])
		var rep = var_d.get("replace", {})
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		for lid in rep:
			if String(lid).begins_with("_"):
				continue
			if not base.has(String(lid)):
				errs.append("scenes.%s: variants[%d].replace.%s: no es una línea base de la escena" % [sid, i, lid])
				continue
			if typeof(rep[lid]) != TYPE_STRING:
				continue
			var want := _tramo_sig(base[String(lid)])
			var got := _tramo_sig(String(rep[lid]))
			if want != got:
				errs.append("scenes.%s: variants[%d].replace.%s: debe conservar los tramos de la línea base %s (tiene %s)" % [sid, i, lid, str(want), str(got)])

# Firma de tramos de un texto: ["#id a:x e:y …"] ordenada (id y etiquetas; el texto puede cambiar).
static func _tramo_sig(text: String) -> Array:
	var out: Array = []
	for t in Markup.parse(text, {"allow_placeholders": true}).tramos:
		var tags: Array = []
		for p in Markup.PREFIXES:
			for x in t.tags.get(p, []):
				tags.append(p + ":" + String(x))
		tags.sort()
		out.append(("#" + String(t.id) + " " if String(t.id) != "" else "") + " ".join(PackedStringArray(tags)))
	out.sort()
	return out

static func _has_id(arr, id: String) -> bool:
	for x in arr:
		if typeof(x) == TYPE_DICTIONARY and String(x.get("id", "")) == id:
			return true
	return false
