# core/react/sensors.gd — los ojos de Holmes (GDD§9.2, ARCHITECTURE §5.4). Dueño: W2-REACT.
# observe(st, repo, ev) -> [{channel, sensor, to_holmes, to_mycroft, content}] ya filtrado:
#   K-T  ve anuncios publicados (texto y forma).                  sensor: mycroft (lee el Times)
#   K-BM ve papeletas (asiento, título, hora, tema), no lo leído.  sensor: cotter (canastilla)
#   K-W  ve lo dicho/mostrado a Watson si toca sus grupos (roca, mary, vive) o es una afirmación de assertion_kinds;
#        Mary y «vive» (to_holmes_exclude) sólo llegan a Mycroft (voz A). Contenido marcado privado_kw (T23).
#   K-H  ve visitas al interior de 221B y lo dicho/mostrado a Mrs. Hudson de su grupo (221b) o afirmaciones.
#   K-S  ve calles y hora de cada go desde from_day (3), nunca la casa ni lo consultado; y los tratos con Wiggins.
# Todos quitan lo de Camden House (lists.camden_entities, etiquetas secreto_camden; D10, T22). Telegramas, cartas,
# copias de Somerset House e informes son ciegos para Holmes.
# Extensión: acts_by_channel(st, repo) -> {código: [eventos observados]} (para HC06 (b): cita un acto por canal).
extends RefCounted

const RDB = preload("res://core/react/reaction_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const DEF := {
	"K-W": {"char": "watson", "topics": ["roca", "mary", "vive"], "assertion_kinds": ["cebo", "vive", "canario"], "show": true, "to_holmes_exclude": ["mary", "vive"]},
	"K-H": {"char": "mrs_hudson", "place": "L3", "topics": ["221b"], "assertion_kinds": ["cebo", "vive", "canario"], "visits": true, "show": true},
	"K-S": {"fields": ["streets", "hour"], "from_day": 3, "char": "wiggins"},
	"K-BM": {"fields": ["seat", "title", "hour"]},
	"K-T": {"fields": ["text"]},
}
const SENSOR_NAME := {"K-W": "watson", "K-H": "mrs_hudson", "K-S": "wiggins", "K-BM": "cotter", "K-T": "mycroft"}
const NOT_INTERIOR := ["calle", "agente", "exterior", "oficina", "oficina_del_agente"]

static func conf(repo, ch: String) -> Dictionary:
	var out: Dictionary = DEF.get(ch, {}).duplicate(true)
	var s = repo.lists().get("sensors", {}) if repo != null else {}
	if typeof(s) == TYPE_DICTIONARY and typeof(s.get(ch)) == TYPE_DICTIONARY:
		for k in s[ch]:
			out[k] = s[ch][k]
	return out

static func strip_list(repo) -> Dictionary:
	var ents := {}
	var tags := ["secreto_camden"]
	if repo != null:
		for e in repo.lists().get("camden_entities", []):
			ents[String(e)] = true
		var s = repo.lists().get("sensors", {})
		if typeof(s) == TYPE_DICTIONARY:
			for t in s.get("strip_tags", []):
				if not tags.has(String(t)):
					tags.append(String(t))
	return {"ents": ents, "tags": tags}

static func observe(st, repo, ev: Dictionary) -> Array:
	var out: Array = []
	var t := String(ev.get("type", ""))
	var day := int(ev.get("day", TimeKey.day_of(int(ev.get("tk", 0)))))
	match t:
		"go":
			var ks := conf(repo, "K-S")
			if day >= int(ks.get("from_day", 3)):
				out.append(_obs("K-S", true, true, {"streets": ev.get("streets", []), "hour": ev.get("hour", "")}))
			var kh := conf(repo, "K-H")
			if bool(kh.get("visits", true)) and String(ev.get("place", "")) == String(kh.get("place", "L3")) and _interior(ev, kh):
				out.append(_obs("K-H", true, true, {"place": String(ev.get("place", "")), "area": String(ev.get("area", "")), "hour": ev.get("hour", ""), "visit": true}))
		"slip":
			out.append(_obs("K-BM", true, true, {"seat": ev.get("seat", 0), "title": ev.get("title", ""), "hour": ev.get("hour", ""),
				"topic": ev.get("topic", ""), "doc": ev.get("doc", "")}))
		"say", "show":
			for ch in ["K-W", "K-H"]:
				var o := _talk(repo, ch, ev)
				if not o.is_empty():
					out.append(o)
			var o2 := _wiggins(repo, ev, day)
			if not o2.is_empty():
				out.append(o2)
		"pay", "task":
			var o3 := _wiggins(repo, ev, day)
			if not o3.is_empty():
				out.append(o3)
		"ad":
			out.append(_obs("K-T", true, true, {"ad": ev.get("ad", ""), "form": ev.get("form", ""), "text": ev.get("text", ""),
				"assertion": ev.get("assertion", ""), "bait_topic": ev.get("bait_topic", ""), "canary": ev.get("canary", ""),
				"to_s": bool(ev.get("to_s", false)), "says_alive": bool(ev.get("says_alive", false)), "pub_day": ev.get("pub_day", day),
				"prologue": bool(ev.get("prologue", false))}))
	var sl := strip_list(repo)
	for o in out:
		_strip(o.content, sl)
	return out

static func _obs(ch: String, to_h: bool, to_m: bool, content: Dictionary) -> Dictionary:
	return {"channel": ch, "sensor": SENSOR_NAME.get(ch, ""), "to_holmes": to_h, "to_mycroft": to_m, "content": content}

static func _interior(ev: Dictionary, kh: Dictionary) -> bool:
	var area := String(ev.get("area", ""))
	if kh.has("areas") and typeof(kh.areas) == TYPE_ARRAY:
		return kh.areas.has(area)
	return not NOT_INTERIOR.has(area)

static func _visible(ev: Dictionary) -> Dictionary:
	var c := {"char": String(ev.get("char", "")), "kind": String(ev.get("kind", ""))}
	if String(ev.get("type", "")) == "say":
		for k in ["topic", "assertion", "bait_topic", "canary", "phrase"]:
			c[k] = ev.get(k, "")
		c["ents"] = RDB._as_arr(ev.get("ents", [])).duplicate()
	else:
		var it = ev.get("item", {})
		var item := {}
		if typeof(it) == TYPE_DICTIONARY:
			for k in ["kind", "id", "doc_ids", "ents", "src_types", "entry_values", "origins"]:
				if it.has(k):
					item[k] = it[k].duplicate(true) if typeof(it[k]) in [TYPE_ARRAY, TYPE_DICTIONARY] else it[k]
		c["item"] = item
	return c

static func _talk(repo, ch: String, ev: Dictionary) -> Dictionary:
	var k := conf(repo, ch)
	if String(ev.get("char", "")) != String(k.get("char", "")):
		return {}
	var t := String(ev.get("type", ""))
	if t == "show" and not bool(k.get("show", true)):
		return {}
	var c := _visible(ev)
	var sl := strip_list(repo)
	_strip(c, sl)
	var hits := RDB.groups_hit(repo, c, RDB._as_arr(k.get("topics", [])))
	var akind := ""
	if t == "say" and String(ev.get("kind", "")) == "assert":
		akind = String(RDB.assertion(repo, ev.get("assertion", "")).get("kind", ""))
		if akind == "" and String(ev.get("bait_topic", "")) != "":
			akind = "cebo"
		if akind == "" and String(ev.get("canary", "")) != "":
			akind = "canario"
	var asserted: bool = akind != "" and RDB._as_arr(k.get("assertion_kinds", [])).has(akind)
	if hits.is_empty() and not asserted:
		return {}
	# to_holmes: algún grupo no excluido, o una afirmación cebo/canario. Mary y «vive» sólo llegan a Mycroft (HB4).
	var excl := RDB._as_arr(k.get("to_holmes_exclude", []))
	var to_h := false
	for g in hits:
		if not excl.has(g):
			to_h = true
	if asserted and akind != "vive":
		to_h = true
	c["groups"] = hits
	if ch == "K-W":
		c["privado_kw"] = true
	return _obs(ch, to_h, true, c)

static func _wiggins(repo, ev: Dictionary, day: int) -> Dictionary:
	var ks := conf(repo, "K-S")
	if String(ev.get("char", "")) != String(ks.get("char", "wiggins")) or day < int(ks.get("from_day", 3)):
		return {}
	var c := _visible(ev)
	for k in ["amount_d", "task"]:
		if ev.has(k):
			c[k] = ev[k]
	return _obs("K-S", true, true, c)

# Quita entidades de Camden House y etiquetas secreto_camden en todo el contenido (recursivo).
static func _strip(c, sl: Dictionary) -> void:
	if typeof(c) == TYPE_DICTIONARY:
		var ks: Array = c.keys()
		for k in ks:
			var v = c[k]
			if typeof(v) == TYPE_STRING and _bad(String(v), sl):
				c[k] = ""
			elif typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
				_strip(v, sl)
	elif typeof(c) == TYPE_ARRAY:
		for i in range(c.size() - 1, -1, -1):
			var v = c[i]
			if typeof(v) == TYPE_STRING and _bad(String(v), sl):
				c.remove_at(i)
			elif typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
				_strip(v, sl)

static func _bad(s: String, sl: Dictionary) -> bool:
	if sl.ents.has(s):
		return true
	for t in sl.tags:
		if s == t or s.ends_with(":" + String(t)):
			return true
	return false

# Para HC06 (b) y depuración: eventos de st.events observados por cada canal, en orden.
static func acts_by_channel(st, repo) -> Dictionary:
	var out := {}
	for ev in st.events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		for o in observe(st, repo, ev):
			var code := RDB.ch_code(String(o.channel))
			if not out.has(code):
				out[code] = []
			out[code].append(ev)
	return out
