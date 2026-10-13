# core/util/cond.gd — DSL de condiciones (§4.18). Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8.
# eval(cond, ctx): ctx = {st, repo, ev?, anchor?, char?, tk?, counters?, chars_present?} (anchor: ctx.anchor o, si falta, ctx.ev)
#   {} = verdadero. Dict con varias claves = AND de átomos. Combinadores all/any/not/always.
#   ctx.tk (int) fija día y franja (Director.on_time); si no, st.clock.day/slot (phase "night" -> franja night).
# validate(cond) -> ["ruta: msg"]: lo usa Schema; un átomo desconocido es error de esquema, nunca false silencioso.
# Resoluciones de estado ajeno (documentadas; los dueños pueden exponerlas así):
#   counter        -> ctx.counters[name] | st.react.counters[name] | st.flags[name]
#   visited        -> st.world.visits: [String "S.L3.4.M" | "L3" | {place}]
#   char_present   -> ctx.chars_present | st.world.visit.chars ([id | {id}])
#   report_final_cats_any -> eventos públicos "report" con n == schedule.reports[final].n (def. 4): unión de items[].cats
#   sealed*        -> st.ded.sealed (dict cid -> entry)
#   pencil_wrong   -> bool: hay (true) / no hay (false) algún asiento a lápiz erróneo que el lápiz azul marca
#                     (Endings.blue_pencil kind "wrong"; END.F1: «Una de sus entradas no es literalmente cierta»)
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const L = preload("res://core/util/log.gd")

const ATOMS := ["day", "slot", "weekday", "tk", "flag", "flag_eq", "flag_gte", "sealed", "sealed_all", "sealed_count",
	"counter", "event_count", "visited", "channel_closed", "report_final_cats_any", "anchor", "char_present", "pencil_wrong"]
const COMBI := ["all", "any", "not", "always"]
# Datos (validate): sólo códigos ASCII (§12.2). eval tolera «mié»/«sáb» (wd_norm).
const WEEKDAYS_ASCII := ["lun", "mar", "mie", "jue", "vie", "sab", "dom"]

static func eval(cond, ctx: Dictionary) -> bool:
	if cond == null:
		return true
	if typeof(cond) != TYPE_DICTIONARY:
		L.bug("cond", "condición no es objeto: %s" % str(cond))
		return false
	var keys: Array = cond.keys()
	keys.sort()
	for k in keys:
		if String(k).begins_with("_"):
			continue
		if not _atom(String(k), cond[k], ctx):
			return false
	return true

static func _atom(k: String, v, ctx: Dictionary) -> bool:
	var st = ctx.get("st")
	match k:
		"always":
			return bool(v)
		"all":
			for c in v:
				if not eval(c, ctx):
					return false
			return true
		"any":
			for c in v:
				if eval(c, ctx):
					return true
			return false
		"not":
			return not eval(v, ctx)
		"day":
			return _cmp(_cur_day(ctx), v)
		"slot":
			var s := _cur_slot(ctx)
			if typeof(v) == TYPE_ARRAY:
				return v.has(s)
			return s == String(v)
		"weekday":
			var wd := wd_norm(_weekday(ctx))
			if typeof(v) == TYPE_ARRAY:
				for x in v:
					if wd_norm(String(x)) == wd:
						return true
				return false
			return wd == wd_norm(String(v))
		"tk":
			var cur := _cur_tk(ctx)
			if typeof(v) == TYPE_DICTIONARY:
				var vv := {}
				for kk in v:
					vv[kk] = TimeKey.of(v[kk])
				return _cmp(cur, vv)
			return cur == TimeKey.of(v)
		"flag":
			return _truthy(_flags(st).get(String(v)))
		"flag_eq":
			var f := _flags(st)
			for name in v:
				if not _same(f.get(name, _flag_default(v[name])), v[name]):
					return false
			return true
		"flag_gte":
			var f2 := _flags(st)
			for name in v:
				if _num(f2.get(name, 0)) < _num(v[name]):
					return false
			return true
		"sealed":
			return _sealed(st).has(String(v))
		"sealed_all":
			var sd := _sealed(st)
			for c in v:
				if not sd.has(String(c)):
					return false
			return true
		"sealed_count":
			var of = v.get("of", "mandatory")
			var lst: Array = []
			if typeof(of) == TYPE_ARRAY:
				lst = of
			else:
				lst = _conc_list(ctx, String(of))
			var sd2 := _sealed(st)
			var n := 0
			for c in lst:
				if sd2.has(String(c)):
					n += 1
			return _cmp(n, v)
		"counter":
			return _cmp(_counter(ctx, String(v.get("name", ""))), v)
		"event_count":
			return _cmp(_event_count(ctx, v), v)
		"visited":
			return _visited(st, String(v))
		"channel_closed":
			return _truthy(_flags(st).get("canal_cerrado." + String(v)))
		"report_final_cats_any":
			var cats := _final_cats(ctx)
			for c in v:
				if cats.has(c):
					return true
			return false
		"anchor":
			var an = ctx.get("anchor", ctx.get("ev", {}))   # sin ctx.anchor: campos del evento (ctx.ev)
			if typeof(an) != TYPE_DICTIONARY:
				an = {}
			for f3 in v:
				var want = v[f3]
				var got = an.get(f3)
				if typeof(want) == TYPE_ARRAY:
					if not want.has(got):
						return false
				elif not _same(got, want):
					return false
			return true
		"char_present":
			return _chars_present(ctx).has(String(v))
		"pencil_wrong":
			return _pencil_wrong(ctx) == bool(v)
	L.bug("cond", "átomo desconocido: " + k)
	return false

# --- validación (Schema) ---
static func validate(cond, path := "cond") -> Array:
	var errs: Array = []
	_val(cond, path, errs)
	return errs

static func _val(cond, path: String, errs: Array) -> void:
	if cond == null:
		return
	if typeof(cond) != TYPE_DICTIONARY:
		errs.append("%s: la condición debe ser un objeto" % path)
		return
	for k in cond:
		var ks := String(k)
		if ks.begins_with("_"):
			continue
		var v = cond[k]
		var p := path + "." + ks
		match ks:
			"always":
				if typeof(v) != TYPE_BOOL:
					errs.append("%s: debe ser bool" % p)
			"all", "any":
				if typeof(v) != TYPE_ARRAY:
					errs.append("%s: debe ser lista" % p)
				else:
					for i in v.size():
						_val(v[i], "%s[%d]" % [p, i], errs)
			"not":
				_val(v, p, errs)
			"day":
				if typeof(v) == TYPE_DICTIONARY:
					_val_cmp(v, p, errs, [])
				elif typeof(v) != TYPE_INT:
					errs.append("%s: int o {gte,lte,eq}" % p)
			"slot":
				var arr: Array = v if typeof(v) == TYPE_ARRAY else [v]
				for s in arr:
					if not TimeKey.ORD.has(String(s)):
						errs.append("%s: franja desconocida %s" % [p, str(s)])
			"weekday":
				var arr2: Array = v if typeof(v) == TYPE_ARRAY else [v]
				for s in arr2:
					if not WEEKDAYS_ASCII.has(String(s)):
						errs.append("%s: día de semana desconocido %s (códigos ASCII: %s)" % [p, str(s), ", ".join(PackedStringArray(WEEKDAYS_ASCII))])
			"tk":
				if typeof(v) == TYPE_DICTIONARY:
					_val_cmp(v, p, errs, [])
					for kk in v:
						if TimeKey.of(v[kk]) < 0 and not String(kk).begins_with("_"):
							errs.append("%s.%s: tk inválido %s" % [p, kk, str(v[kk])])
				elif TimeKey.of(v) < 0:
					errs.append("%s: tk inválido" % p)
			"flag", "sealed", "visited", "channel_closed", "char_present":
				if typeof(v) != TYPE_STRING or String(v) == "":
					errs.append("%s: debe ser texto no vacío" % p)
			"flag_eq", "flag_gte", "anchor":
				if typeof(v) != TYPE_DICTIONARY or v.is_empty():
					errs.append("%s: debe ser objeto no vacío" % p)
			"pencil_wrong":
				if typeof(v) != TYPE_BOOL:
					errs.append("%s: debe ser bool" % p)
			"sealed_all", "report_final_cats_any":
				if typeof(v) != TYPE_ARRAY:
					errs.append("%s: debe ser lista" % p)
			"sealed_count":
				if typeof(v) != TYPE_DICTIONARY:
					errs.append("%s: debe ser objeto" % p)
				else:
					_val_cmp(v, p, errs, ["of"])
					var of = v.get("of", "mandatory")
					if not (typeof(of) == TYPE_ARRAY or ["mandatory", "lot_counts"].has(String(of))):
						errs.append("%s.of: 'mandatory', 'lot_counts' o lista" % p)
			"counter":
				if typeof(v) != TYPE_DICTIONARY or not v.has("name"):
					errs.append("%s: requiere name" % p)
				else:
					_val_cmp(v, p, errs, ["name"])
			"event_count":
				if typeof(v) != TYPE_DICTIONARY or not v.has("type"):
					errs.append("%s: requiere type" % p)
				else:
					_val_cmp(v, p, errs, ["type", "where"])
					if v.has("where") and typeof(v.where) != TYPE_DICTIONARY:
						errs.append("%s.where: debe ser objeto" % p)
			_:
				errs.append("%s: átomo desconocido '%s'" % [p, ks])

static func _val_cmp(v: Dictionary, p: String, errs: Array, extra: Array) -> void:
	var n := 0
	for k in v:
		var ks := String(k)
		if ks.begins_with("_") or extra.has(ks):
			continue
		if ["gte", "lte", "eq", "lt", "gt"].has(ks):
			n += 1
		else:
			errs.append("%s: comparador desconocido '%s'" % [p, ks])
	if n == 0:
		errs.append("%s: falta comparador (gte/lte/eq/lt/gt)" % p)

# --- helpers ---
# endings.gd se carga en tiempo de ejecución (sim/ -> util/ sin precarga: evita el ciclo Cond <- Endings).
static func _pencil_wrong(ctx: Dictionary) -> bool:
	var st = ctx.get("st")
	var repo = ctx.get("repo")
	if st == null or repo == null:
		return false
	for it in load("res://core/sim/endings.gd").blue_pencil(st, repo):
		if String(it.get("kind", "")) == "wrong":
			return true
	return false

static func _cmp(x, v) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return _num(x) == _num(v)
	var n := _num(x)
	if v.has("eq") and n != _num(v.eq):
		return false
	if v.has("gte") and n < _num(v.gte):
		return false
	if v.has("lte") and n > _num(v.lte):
		return false
	if v.has("lt") and n >= _num(v.lt):
		return false
	if v.has("gt") and n <= _num(v.gt):
		return false
	return true

static func _num(x) -> float:
	match typeof(x):
		TYPE_INT, TYPE_FLOAT:
			return float(x)
		TYPE_BOOL:
			return 1.0 if x else 0.0
		TYPE_STRING:
			return String(x).to_float() if String(x).is_valid_float() else 0.0
	return 0.0

static func _same(a, b) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	return a == b

static func _flag_default(v):
	match typeof(v):
		TYPE_BOOL: return false
		TYPE_INT, TYPE_FLOAT: return 0
		TYPE_STRING: return ""
	return null

static func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING: return String(v) != ""
		TYPE_ARRAY, TYPE_DICTIONARY: return not v.is_empty()
	return true

static func _field(o, field: String, def):
	if o == null:
		return def
	if typeof(o) == TYPE_DICTIONARY:
		return o.get(field, def)
	var v = o.get(field)
	return def if v == null else v

static func _flags(st) -> Dictionary:
	var f = _field(st, "flags", {})
	return f if typeof(f) == TYPE_DICTIONARY else {}

static func _sealed(st) -> Dictionary:
	var ded = _field(st, "ded", {})
	var s = ded.get("sealed", {}) if typeof(ded) == TYPE_DICTIONARY else {}
	return s if typeof(s) == TYPE_DICTIONARY else {}

static func _clock(st) -> Dictionary:
	var c = _field(st, "clock", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

static func _cur_day(ctx: Dictionary) -> int:
	if ctx.has("tk"):
		return TimeKey.day_of(int(ctx.tk))
	return int(_clock(ctx.get("st")).get("day", 0))

static func _cur_slot(ctx: Dictionary) -> String:
	if ctx.has("tk"):
		return TimeKey.slot_of(int(ctx.tk))
	var c := _clock(ctx.get("st"))
	if String(c.get("phase", "")) == "night":
		return "night"
	return String(c.get("slot", ""))

static func _cur_tk(ctx: Dictionary) -> int:
	if ctx.has("tk"):
		return int(ctx.tk)
	var s := _cur_slot(ctx)
	if s == "":
		return _cur_day(ctx) * 10
	return TimeKey.tk(_cur_day(ctx), s)

# "mié" == "mie", "sáb" == "sab" en runtime; en data/ el contrato fija códigos ASCII (§12.2, Schema y validate).
static func wd_norm(s: String) -> String:
	return s.to_lower().replace("é", "e").replace("á", "a")

static func _weekday(ctx: Dictionary) -> String:
	var repo = ctx.get("repo")
	if repo == null:
		return ""
	var day := _cur_day(ctx)
	var sch: Dictionary = repo.schedule()
	for d in sch.get("days", []):
		if int(d.get("day", -1)) == day:
			return String(d.get("weekday", ""))
	return ""

static func _conc_list(ctx: Dictionary, of: String) -> Array:
	var repo = ctx.get("repo")
	if repo == null:
		return []
	if repo.has_method("conclusions_meta"):
		return repo.conclusions_meta().get(of, [])
	return []

static func _counter(ctx: Dictionary, name: String) -> float:
	if ctx.has("counters") and typeof(ctx.counters) == TYPE_DICTIONARY and ctx.counters.has(name):
		return _num(ctx.counters[name])
	var st = ctx.get("st")
	var react = _field(st, "react", {})
	if typeof(react) == TYPE_DICTIONARY and typeof(react.get("counters")) == TYPE_DICTIONARY and react.counters.has(name):
		return _num(react.counters[name])
	return _num(_flags(st).get(name, 0))

static func _event_count(ctx: Dictionary, v: Dictionary) -> int:
	var st = ctx.get("st")
	var evs = _field(st, "events", [])
	var where: Dictionary = v.get("where", {})
	var groups := {}
	var repo = ctx.get("repo")
	if repo != null and where.has("topic_group"):
		groups = repo.lists().get("topic_groups", {})
	var n := 0
	for ev in evs:
		if typeof(ev) != TYPE_DICTIONARY or String(ev.get("type", "")) != String(v.type):
			continue
		var okk := true
		for f in where:
			var want = where[f]
			if f == "topic_group":
				var g: Array = groups.get(String(want), [])
				if not g.has(ev.get("topic", "")):
					okk = false
			elif typeof(want) == TYPE_ARRAY:
				if not want.has(ev.get(f)):
					okk = false
			elif not _same(ev.get(f), want):
				okk = false
			if not okk:
				break
		if okk:
			n += 1
	return n

static func _visited(st, place: String) -> bool:
	var world = _field(st, "world", {})
	var visits = world.get("visits", []) if typeof(world) == TYPE_DICTIONARY else []
	for x in visits:
		if typeof(x) == TYPE_DICTIONARY:
			if String(x.get("place", "")) == place:
				return true
		else:
			var s := String(x)
			if s == place or s.begins_with("S." + place + "."):
				return true
	return false

static func _chars_present(ctx: Dictionary) -> Array:
	var out: Array = []
	var src = ctx.get("chars_present")
	if src == null:
		var world = _field(ctx.get("st"), "world", {})
		var visit = world.get("visit", {}) if typeof(world) == TYPE_DICTIONARY else {}
		src = visit.get("chars", []) if typeof(visit) == TYPE_DICTIONARY else []
	for c in src:
		out.append(String(c.get("id", "")) if typeof(c) == TYPE_DICTIONARY else String(c))
	return out

static func _final_cats(ctx: Dictionary) -> Array:
	var final_n := 4
	var repo = ctx.get("repo")
	if repo != null:
		for r in repo.schedule().get("reports", []):
			if r.get("final", false):
				final_n = int(r.get("n", 4))
	var cats: Array = []
	for ev in _field(ctx.get("st"), "events", []):
		if typeof(ev) == TYPE_DICTIONARY and ev.get("type", "") == "report" and int(ev.get("n", 0)) == final_n:
			for it in ev.get("items", []):
				for c in it.get("cats", []):
					if not cats.has(c):
						cats.append(c)
	return cats
