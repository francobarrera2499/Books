# core/graph/availability.gd — máscaras de disponibilidad (29 bits de franja jugable, §3.2/§5.6). Dueño: W2-GRAPH.
# Contrato §3.8: open_mask(repo, place, area) · frag_mask(repo, frag) · from_mask(idx). El resto son extensiones.
# Modelo (§5.6): bit i encendido = el fragmento se puede obtener en la franja jugable i.
#  - lugar/área: ventanas de schedule.places (OR; needs = DSL) ∧, si el lugar no es el hub (L1, casa), la franja figura
#    en schedule.days[d].slots y el día no es `fixed` (día 10: sin `go`, §3.2). El hub sólo obedece sus ventanas.
#  - ejemplar: holder → lugar (BM→L2, Crane→L1.tienda, L1/tomo→L1.buhardilla, L3..L8) ∧ ventana from/to ∧ parts[].when.
#  - escena con tk (fija): desde su tk en adelante (inevitable; la línea queda en el diario). Escena de lugar: horario ∧ when.
#  - reacción: desde (acto más temprano posible + latencia) en adelante; columna: desde su tk (§5.6).
#  - diario J:<tipo>: desde el primer acto posible del tipo. Lámina fija: desde su day/slot, su escena o su documento.
# Condiciones (when/needs) en 3 valores (Kleene): tiempo y flags exactos (flags hipotéticos por parámetro, base = {});
#   átomos que dependen del jugador (event_count, visited, counter, sealed*, char_present, anchor, report_final_cats_any)
#   valen "posible". Bit apagado sólo si la condición es FALSA con certeza.
# Fuente (src) = forma concreta de obtener un fragmento: {key, kind, tb, place, area, conds, ck, cls, copy, doc, holder,
#   char, channel, tipo, rid, scene, node, plate, who, unit, mask}; mask = tb ∧ open(place, area, flags) ∧ conds(flags).
#   unit = visita que exige ({} = ninguna: casa, posesión, escena fija, llegada). Registradas en repo.cache["graph"].srcs.
# Sólo lee repo (DataRepo o un envoltorio con los mismos métodos). Sin Time ni azar.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")
const L = preload("res://core/util/log.gd")

const HUB := "L1"
const T_F := 0
const T_T := 1
const T_U := 2
const PLAYER_ATOMS := ["sealed", "sealed_all", "sealed_count", "counter", "event_count", "visited",
	"report_final_cats_any", "anchor", "char_present", "pencil_wrong"]
# flags = {ANY_FLAG: true} → todo átomo de flag vale "posible" (T_U). Lo usan las condiciones de DISPARO de las
# reacciones: un flag que pone otra reacción o el jugador (p. ej. wiggins_aliado de HB8 para HB8b) no impide que la
# reacción ocurra en el peor caso; con flags base {} esas reacciones no se dispararían nunca y sus cortes no se verían.
const ANY_FLAG := "*"

# ---------------- caché por repo ----------------
static func gcache(repo) -> Dictionary:
	if repo == null:
		return {}
	var c = repo.get("cache")
	if typeof(c) != TYPE_DICTIONARY:
		return {}
	if not c.has("graph"):
		c["graph"] = {}
	return c["graph"]

static func sub(repo, name: String) -> Dictionary:
	var g := gcache(repo)
	if not g.has(name):
		g[name] = {}
	return g[name]

static func sorted_keys(d) -> Array:
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var k: Array = d.keys()
	k.sort()
	return k

# ---------------- bits ----------------
static func n() -> int:
	return TimeKey.idx_count()

static func full_mask() -> int:
	return (1 << TimeKey.idx_count()) - 1

# bits >= idx
static func from_mask(idx: int) -> int:
	var nn := TimeKey.idx_count()
	if idx <= 0:
		return (1 << nn) - 1
	if idx >= nn:
		return 0
	return ((1 << nn) - 1) & ~((1 << idx) - 1)

# bits a..b inclusive
static func range_mask(a: int, b: int) -> int:
	if b < a:
		return 0
	return from_mask(a) & ~from_mask(b + 1)

static func lowest(m: int) -> int:
	if m == 0:
		return -1
	for i in TimeKey.idx_count():
		if m & (1 << i):
			return i
	return -1

static func highest(m: int, upto := 1000) -> int:
	if m == 0:
		return -1
	for i in range(mini(TimeKey.idx_count() - 1, upto), -1, -1):
		if m & (1 << i):
			return i
	return -1

static func bits(m: int) -> Array:
	var out: Array = []
	for i in TimeKey.idx_count():
		if m & (1 << i):
			out.append(i)
	return out

static func labels(m: int) -> String:
	var ps := PackedStringArray()
	for i in bits(m):
		var x := TimeKey.from_idx(i)
		ps.append(TimeKey.label(TimeKey.tk(x.day, x.slot)))
	return ",".join(ps)

# último índice jugable con tk <= t (-1 si ninguno)
static func idx_at_or_before(t) -> int:
	var k := TimeKey.of(t)
	var last := -1
	for i in TimeKey.idx_count():
		var x := TimeKey.from_idx(i)
		if TimeKey.tk(x.day, x.slot) <= k:
			last = i
	return last

static func day_bits(day: int) -> int:
	var m := 0
	for i in TimeKey.idx_count():
		if TimeKey.from_idx(i).day == day:
			m |= 1 << i
	return m

# ---------------- calendario ----------------
static func days(repo) -> Dictionary:
	var g := gcache(repo)
	if g.has("days"):
		return g["days"]
	var out := {}
	for d in repo.schedule().get("days", []):
		if typeof(d) == TYPE_DICTIONARY:
			out[int(d.get("day", -1))] = d
	g["days"] = out
	return out

static func infos(repo) -> Array:
	var g := gcache(repo)
	if g.has("infos"):
		return g["infos"]
	var ds := days(repo)
	var out: Array = []
	for i in TimeKey.idx_count():
		var x := TimeKey.from_idx(i)
		var d: Dictionary = ds.get(int(x.day), {})
		var listed := true
		if d.is_empty():
			listed = int(x.day) >= 1 and int(x.day) <= 9
		else:
			listed = d.get("slots", []).has(x.slot)
		out.append({"i": i, "day": int(x.day), "slot": String(x.slot), "tk": TimeKey.tk(x.day, x.slot),
			"weekday": String(d.get("weekday", "")), "fixed": bool(d.get("fixed", false)), "listed": listed})
	g["infos"] = out
	return out

static func info_tk(repo, t: int) -> Dictionary:
	var day := TimeKey.day_of(t)
	var d: Dictionary = days(repo).get(day, {})
	return {"day": day, "slot": TimeKey.slot_of(t), "tk": t, "weekday": String(d.get("weekday", "")),
		"fixed": bool(d.get("fixed", false))}

# franjas jugables en las que se puede salir (no hub): listadas y día no fijo
static func outing_days_mask(repo) -> int:
	var g := gcache(repo)
	if g.has("odm"):
		return g["odm"]
	var m := 0
	for x in infos(repo):
		if x.listed and not x.fixed:
			m |= 1 << int(x.i)
	g["odm"] = m
	return m

# ---------------- condiciones (3 valores) ----------------
static func tri(cond, x: Dictionary, flags: Dictionary) -> int:
	if cond == null:
		return T_T
	if typeof(cond) != TYPE_DICTIONARY:
		return T_U
	var res := T_T
	var keys: Array = cond.keys()
	keys.sort()
	for k in keys:
		var ks := String(k)
		if ks.begins_with("_"):
			continue
		var r := _atom3(ks, cond[k], x, flags)
		if r == T_F:
			return T_F
		if r == T_U:
			res = T_U
	return res

static func _atom3(k: String, v, x: Dictionary, flags: Dictionary) -> int:
	match k:
		"always":
			return T_T if bool(v) else T_F
		"all":
			var res := T_T
			if typeof(v) != TYPE_ARRAY:
				return T_U
			for c in v:
				var r := tri(c, x, flags)
				if r == T_F:
					return T_F
				if r == T_U:
					res = T_U
			return res
		"any":
			var res2 := T_F
			if typeof(v) != TYPE_ARRAY:
				return T_U
			for c in v:
				var r2 := tri(c, x, flags)
				if r2 == T_T:
					return T_T
				if r2 == T_U:
					res2 = T_U
			return res2
		"not":
			var r3 := tri(v, x, flags)
			if r3 == T_U:
				return T_U
			return T_F if r3 == T_T else T_T
		"day":
			return _b(_cmp(int(x.get("day", 0)), v))
		"slot":
			var s := String(x.get("slot", ""))
			if typeof(v) == TYPE_ARRAY:
				return _b(v.has(s))
			return _b(s == String(v))
		"weekday":
			var wd := _wd(String(x.get("weekday", "")))
			if wd == "":
				return T_U
			if typeof(v) == TYPE_ARRAY:
				for y in v:
					if _wd(String(y)) == wd:
						return T_T
				return T_F
			return _b(wd == _wd(String(v)))
		"tk":
			var cur := int(x.get("tk", 0))
			if typeof(v) == TYPE_DICTIONARY:
				var vv := {}
				for kk in v:
					vv[kk] = TimeKey.of(v[kk])
				return _b(_cmp(cur, vv))
			return _b(cur == TimeKey.of(v))
		"flag", "flag_eq", "flag_gte", "channel_closed":
			if flags.has(ANY_FLAG):
				return T_U
			return _flag_atom(k, v, flags)
	return T_U

static func _flag_atom(k: String, v, flags: Dictionary) -> int:
	match k:
		"flag":
			return _b(_truthy(flags.get(String(v))))
		"flag_eq":
			if typeof(v) != TYPE_DICTIONARY:
				return T_U
			for name in v:
				if not _same(flags.get(name, _flag_default(v[name])), v[name]):
					return T_F
			return T_T
		"flag_gte":
			if typeof(v) != TYPE_DICTIONARY:
				return T_U
			for name in v:
				if _num(flags.get(name, 0)) < _num(v[name]):
					return T_F
			return T_T
		"channel_closed":
			return _b(_truthy(flags.get("canal_cerrado." + String(v))))
	return T_U

static func _b(c: bool) -> int:
	return T_T if c else T_F

static func _wd(s: String) -> String:
	return s.to_lower().replace("é", "e").replace("á", "a")

static func _cmp(xv, v) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return _num(xv) == _num(v)
	var nn := _num(xv)
	if v.has("eq") and nn != _num(v.eq):
		return false
	if v.has("gte") and nn < _num(v.gte):
		return false
	if v.has("lte") and nn > _num(v.lte):
		return false
	if v.has("lt") and nn >= _num(v.lt):
		return false
	if v.has("gt") and nn <= _num(v.gt):
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
		TYPE_BOOL:
			return false
		TYPE_INT, TYPE_FLOAT:
			return 0
		TYPE_STRING:
			return ""
	return null

static func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return String(v) != ""
		TYPE_ARRAY, TYPE_DICTIONARY:
			return not v.is_empty()
	return true

static func _fkey(flags: Dictionary) -> String:
	return "" if flags.is_empty() else J.stringify_canon(flags)

# Bits donde la condición es posible (no falsa con certeza).
static func cond_mask(repo, cond, flags := {}) -> int:
	if cond == null or (typeof(cond) == TYPE_DICTIONARY and cond.is_empty()):
		return full_mask()
	var key := J.stringify_canon(cond) + "|" + _fkey(flags)
	var cm := sub(repo, "cond")
	if cm.has(key):
		return cm[key]
	var m := 0
	for x in infos(repo):
		if tri(cond, x, flags) != T_F:
			m |= 1 << int(x.i)
	cm[key] = m
	return m

# ---------------- lugares ----------------
static func areas_of(repo, place: String) -> Array:
	var pl = repo.schedule().get("places", {}).get(place, {})
	if typeof(pl) != TYPE_DICTIONARY:
		return []
	return sorted_keys(pl.get("areas", {}))

static func is_free(repo, place: String, area: String) -> bool:
	var a = repo.schedule().get("places", {}).get(place, {}).get("areas", {}).get(area, {})
	return typeof(a) == TYPE_DICTIONARY and bool(a.get("free", false))

# Áreas concretas para (place, area): área existente → [área]; "" / "*" / desconocida → todas las del lugar
# (sin áreas en schedule → ["*"]).
static func fit_areas(repo, place: String, area: String) -> Array:
	var all := areas_of(repo, place)
	if all.is_empty():
		return [area if area != "" else "*"]
	if all.has(area):
		return [area]
	if area != "" and area != "*":
		var fb := sub(repo, "area_fallback")
		fb[place + "." + area] = true
	return all

static func window_mask(repo, w: Dictionary) -> int:
	var key := "w|" + J.stringify_canon(w)
	var cm := sub(repo, "cond")
	if cm.has(key):
		return cm[key]
	var f := TimeKey.of(w.get("from")) if w.has("from") else -1
	var t := TimeKey.of(w.get("to")) if w.has("to") else -1
	var dd = w.get("days", "all")
	var ss = w.get("slots", "all")
	var m := 0
	for x in infos(repo):
		if typeof(dd) == TYPE_ARRAY and not dd.has(int(x.day)):
			continue
		if typeof(ss) == TYPE_ARRAY and not ss.has(x.slot):
			continue
		if f >= 0 and int(x.tk) < f:
			continue
		if t >= 0 and int(x.tk) > t:
			continue
		m |= 1 << int(x.i)
	cm[key] = m
	return m

static func area_open(repo, place: String, area: String, flags := {}) -> int:
	var key := "o|%s|%s|%s" % [place, area, _fkey(flags)]
	var cm := sub(repo, "cond")
	if cm.has(key):
		return cm[key]
	var m := 0
	var areas = repo.schedule().get("places", {}).get(place, {}).get("areas", {})
	if typeof(areas) != TYPE_DICTIONARY:
		areas = {}
	if area == "" or area == "*":
		for a in sorted_keys(areas):
			m |= area_open(repo, place, String(a), flags)
	elif areas.has(area):
		var ad: Dictionary = areas[area]
		for w in ad.get("open", []):
			if typeof(w) == TYPE_DICTIONARY:
				m |= window_mask(repo, w)
		if ad.has("needs"):
			m &= cond_mask(repo, ad.needs, flags)
		if place != HUB:
			m &= outing_days_mask(repo)
		m &= reveal_mask(repo, place, area)
	cm[key] = m
	return m

# GDD_v2 §B.5/§B.8: garantía de revelado del lugar (schedule.reveal.<L>.by), limitada a `areas` si las nombra. Sólo la
# garantía: los disparadores anticipados (leer, oír, recortar el nombre) sólo suman franjas y la invariante es
# antimonótona en los cortes, así que el grafo los ignora.
static func reveal_mask(repo, place: String, area: String) -> int:
	var rv = repo.schedule().get("reveal", {})
	if typeof(rv) != TYPE_DICTIONARY or typeof(rv.get(place)) != TYPE_DICTIONARY:
		return full_mask()
	var spec: Dictionary = rv[place]
	var areas = spec.get("areas", [])
	if typeof(areas) == TYPE_ARRAY and not areas.is_empty() and not areas.has(area):
		return full_mask()
	return from_mask(TimeKey.idx_at_or_after(spec.get("by", "")))

# Contrato: horario del lugar/área con flags base.
static func open_mask(repo, place: String, area: String) -> int:
	return area_open(repo, place, area, {})

# OR de todos los lugares que no son el hub (franjas con alguna salida posible).
static func outing_mask(repo, flags := {}) -> int:
	var m := 0
	for p in sorted_keys(repo.schedule().get("places", {})):
		if String(p) != HUB:
			m |= area_open(repo, String(p), "*", flags)
	return m

static func non_hub_places(repo) -> Array:
	var out: Array = []
	for p in sorted_keys(repo.schedule().get("places", {})):
		if String(p) != HUB:
			out.append(String(p))
	return out

# ---------------- fuentes ----------------
static func srcs_db(repo) -> Dictionary:
	return sub(repo, "srcs")

static func src(repo, key: String) -> Dictionary:
	return srcs_db(repo).get(key, {})

static func _ck(conds: Array) -> Array:
	var out: Array = []
	for c in conds:
		out.append(J.stringify_canon(c))
	return out

static func _conds(list: Array) -> Array:
	var out: Array = []
	for c in list:
		if typeof(c) == TYPE_DICTIONARY and not c.is_empty():
			out.append(c)
	return out

static func _suffix(conds: Array) -> String:
	if conds.is_empty():
		return ""
	return "|" + J.stringify_canon(conds).md5_text().substr(0, 8)

static func reg(repo, s: Dictionary) -> Dictionary:
	var db := srcs_db(repo)
	var key := String(s.get("key", ""))
	if db.has(key):
		return db[key]
	for f in ["kind", "place", "area", "cls", "copy", "doc", "holder", "char", "channel", "tipo", "rid", "scene", "node", "plate", "who"]:
		if not s.has(f):
			s[f] = ""
	if not s.has("tb"):
		s["tb"] = full_mask()
	if not s.has("conds"):
		s["conds"] = []
	if not s.has("unit"):
		s["unit"] = {}
	if not s.has("gate"):
		s["gate"] = s.place != ""
	s["ck"] = _ck(s.conds)
	s["mask"] = src_mask(repo, s, {})
	db[key] = s
	return s

static func src_mask(repo, s: Dictionary, flags := {}) -> int:
	var m := int(s.get("tb", full_mask()))
	if bool(s.get("gate", false)) and String(s.get("place", "")) != "":
		m &= area_open(repo, String(s.place), String(s.get("area", "*")), flags)
	for c in s.get("conds", []):
		m &= cond_mask(repo, c, flags)
	return m

static func _unit(place: String, area: String, cap := "", capk := "") -> Dictionary:
	if place == HUB or place == "":
		return {}
	return {"place": place, "area": area, "cap": cap, "capk": capk}

# Ejemplar → fuentes (una por área concreta).
static func copy_srcs(repo, copy_id: String, conds := []) -> Array:
	var cp: Dictionary = repo.copy(copy_id)
	if cp.is_empty():
		return []
	var c: Dictionary = cp.get("copy", {})
	var doc_id := String(cp.get("doc", ""))
	var holder := String(c.get("holder", ""))
	var place := HUB
	var area := ""
	var cap := ""
	match holder:
		"L1", "tomo":
			area = String(c.get("area", "buhardilla"))
			if not areas_of(repo, HUB).has(area):
				area = "buhardilla"
		"Crane":
			area = "tienda"
		"BM":
			place = "L2"
			area = String(c.get("area", ""))
			cap = "bm"
		_:
			place = holder
			area = String(c.get("area", ""))
	var tb := full_mask()
	if c.has("from"):
		tb &= from_mask(TimeKey.idx_at_or_after(c.from))
	if c.has("to"):
		tb &= ~from_mask(idx_at_or_before(c.to) + 1)
	var cc := _conds(conds)
	var out: Array = []
	for a in fit_areas(repo, place, area):
		out.append(reg(repo, {"key": "copy:%s@%s.%s%s" % [copy_id, place, a, _suffix(cc)], "kind": "copy",
			"copy": copy_id, "doc": doc_id, "holder": holder, "tb": tb, "place": place, "area": String(a),
			"conds": cc, "cls": String(c.get("class", "I")), "unit": _unit(place, String(a), cap, doc_id)}))
	return out

static func doc_srcs(repo, doc_id: String, copy_id := "", conds := []) -> Array:
	if copy_id != "":
		return copy_srcs(repo, copy_id, conds)
	var out: Array = []
	for c in repo.doc(doc_id).get("copies", []):
		if typeof(c) == TYPE_DICTIONARY:
			out.append_array(copy_srcs(repo, String(c.get("id", "")), conds))
	return out

# Momento de una lámina fija: day/slot propios, o tk de la escena que la usa; si no, desde P.N (archivada).
static func plate_tb(repo, pid: String) -> int:
	var p: Dictionary = repo.plate(pid)
	if p.has("day"):
		return from_mask(TimeKey.idx_at_or_after(TimeKey.tk(int(p.day), String(p.get("slot", "dawn")))))
	var names := [pid, "PL." + pid, String(p.get("origin", ""))]
	if repo.has_method("scenes"):
		for sid in sorted_keys(repo.scenes()):
			var s: Dictionary = repo.scene(String(sid))
			if names.has(String(s.get("plate", ""))) and s.has("tk"):
				return from_mask(TimeKey.idx_at_or_after(TimeKey.of(s.tk)))
	return full_mask()

# Nodo de lugar (por área) o de lámina fija.
static func node_srcs(repo, owner_id: String, node: Dictionary, is_plate: bool, extra_tb := -1) -> Array:
	var cc := _conds([node.get("when", {})])
	var nid := String(node.get("id", ""))
	var cls := String(node.get("cls", "C"))
	var out: Array = []
	if is_plate:
		var tb := plate_tb(repo, owner_id)
		if extra_tb >= 0:
			tb &= extra_tb
		out.append(reg(repo, {"key": "plate:%s.%s%s" % [owner_id, nid, _suffix(cc)], "kind": "plate", "plate": owner_id,
			"node": owner_id + "." + nid, "tb": tb, "conds": cc, "cls": cls}))
		return out
	for a in fit_areas(repo, owner_id, String(node.get("area", "*"))):
		var tb2 := full_mask() if extra_tb < 0 else extra_tb
		out.append(reg(repo, {"key": "node:%s.%s@%s%s" % [owner_id, nid, a, _suffix(cc)], "kind": "node",
			"node": owner_id + "." + nid, "place": owner_id, "area": String(a), "tb": tb2, "conds": cc, "cls": cls,
			"unit": _unit(owner_id, String(a))}))
	return out

# Siluetas: lugares con silhouettes[who]; desde la reacción que la pone (efecto silueta {who, desde}).
static func sil_from(repo, who: String) -> int:
	var best := -1
	for r in repo.reactions():
		for e in r.get("efecto", []):
			if typeof(e) == TYPE_DICTIONARY and String(e.get("op", "")) == "silueta" and String(e.get("who", "")) == who:
				var i := -1
				var abs_t := TimeKey.of(e.get("desde")) if e.has("desde") else -1
				if abs_t >= 0:
					i = TimeKey.idx_at_or_after(abs_t)
				else:
					# sin "desde" o relativo ("+1" = n días después de la entrega, M11): desde la entrega más temprana
					var due := react_due(repo, String(r.get("id", "")))
					if not due.is_empty():
						var plus := 0
						var ds := String(e.get("desde", ""))
						if ds.begins_with("+") and ds.substr(1).is_valid_int():
							plus = ds.substr(1).to_int()
						var t0: int = due[0]
						i = TimeKey.idx_at_or_after(TimeKey.tk(TimeKey.day_of(t0) + plus, "dawn") if plus > 0 else t0)
				if i >= 0 and (best < 0 or i < best):
					best = i
	return best

static func sil_channel(repo, who: String) -> String:
	for r in repo.reactions():
		for e in r.get("efecto", []):
			if typeof(e) == TYPE_DICTIONARY and String(e.get("op", "")) == "silueta" and String(e.get("who", "")) == who:
				return String(r.get("canal", ""))
	return ""

static func sil_srcs(repo, who: String, only_place := "") -> Array:
	var from := sil_from(repo, who)
	var out: Array = []
	if from < 0:
		return out
	for pid in sorted_keys(repo.places()):
		if String(pid) == HUB:
			continue   # la silueta vista desde el escritorio no tiene acto «go» que citar (Clipper._visit_act; archive_hub deja act vacío): no ancla K-S (W4-BALANCE D1; GDD §10.4 K-S: «en la lámina de ese lugar y franja»)
		var p: Dictionary = repo.place(String(pid))
		var sil = p.get("silhouettes", {})
		if typeof(sil) != TYPE_DICTIONARY or not sil.has(who):
			continue
		if only_place != "" and String(pid) != only_place:
			continue
		var area := "*"
		var fr := String(sil[who].get("frame", ""))
		for f in p.get("frames", []):
			if typeof(f) == TYPE_DICTIONARY and String(f.get("id", "")) == fr:
				area = String(f.get("area", "*"))
		for a in fit_areas(repo, String(pid), area):
			out.append(reg(repo, {"key": "sil:%s@%s.%s" % [who, pid, a], "kind": "sil", "who": who, "place": String(pid),
				"area": String(a), "tb": from_mask(from), "cls": "I", "unit": _unit(String(pid), String(a))}))
	return out

# Escena fija (con tk): desde su tk, condiciones evaluadas en su tk. Escena de lugar: horario ∧ when.
static func scene_srcs(repo, sid: String, line: Dictionary) -> Array:
	var s: Dictionary = repo.scene(sid)
	if s.is_empty():
		return []
	var cc := _conds([s.get("when", {}), line.get("when", {})])
	var lid := String(line.get("id", ""))
	if s.has("tk"):
		var t := TimeKey.of(s.tk)
		var tb := from_mask(TimeKey.idx_at_or_after(t))
		for c in cc:
			if tri(c, info_tk(repo, t), {}) == T_F:
				tb = 0
		return [reg(repo, {"key": "fixed:%s.%s" % [sid, lid], "kind": "fixed", "scene": sid, "tb": tb, "cls": "I"})]
	var out: Array = []
	var place := String(s.get("place", ""))
	for a in fit_areas(repo, place, String(s.get("area", "*"))):
		out.append(reg(repo, {"key": "scene:%s.%s@%s.%s%s" % [sid, lid, place, a, _suffix(cc)], "kind": "scene", "scene": sid,
			"place": place, "area": String(a), "conds": cc, "cls": "I", "unit": _unit(place, String(a))}))
	return out

# Presencia de un personaje (lugares y láminas fijas). kind "line" (diálogo, C) o "journal" (diario, I).
static func char_srcs(repo, char_id: String, conds := [], kind := "line", tag := "", cls := "C") -> Array:
	var out: Array = []
	for pid in sorted_keys(repo.places()):
		var p: Dictionary = repo.place(String(pid))
		for ch in p.get("characters", []):
			if typeof(ch) != TYPE_DICTIONARY or String(ch.get("id", "")) != char_id:
				continue
			var cc := _conds(conds + [ch.get("when", {})])
			for a in fit_areas(repo, String(pid), String(ch.get("area", "*"))):
				out.append(reg(repo, {"key": "%s:%s%s@%s.%s%s" % [kind, char_id, tag, pid, a, _suffix(cc)], "kind": kind,
					"char": char_id, "place": String(pid), "area": String(a), "conds": cc, "cls": cls,
					"unit": _unit(String(pid), String(a), "q" if kind == "line" else "", char_id)}))
	if repo.has_method("plates"):
		for pid in sorted_keys(repo.plates()):
			var pl: Dictionary = repo.plate(String(pid))
			for ch in pl.get("characters", []):
				if typeof(ch) == TYPE_DICTIONARY and String(ch.get("id", "")) == char_id:
					var cc2 := _conds(conds + [ch.get("when", {})])
					out.append(reg(repo, {"key": "%s:%s%s@plate.%s%s" % [kind, char_id, tag, pid, _suffix(cc2)], "kind": kind,
						"char": char_id, "plate": String(pid), "tb": plate_tb(repo, String(pid)), "conds": cc2, "cls": cls}))
	out.append_array(_sil_char_srcs(repo, char_id, conds, kind, tag, cls))
	return out

# Silueta con diálogo (HC02: Wiggins desde el día 3): WorldModel.start_visit la suma a los personajes de la visita en
# todo lugar que declara silhouettes[who], en las áreas de silhouettes[who].talk si lo declara (W4: sólo exteriores;
# en un interior se ve por la ventana, sin panel), si no en cualquier área (en el hub, sólo las áreas libres: la tienda), desde
# que una reacción la pone (sil_from). Igual que en el juego: se le puede hablar ahí.
static func _sil_char_srcs(repo, char_id: String, conds: Array, kind: String, tag: String, cls: String) -> Array:
	var out: Array = []
	if not repo.has_method("dialogue") or repo.dialogue(char_id).is_empty():
		return out
	var pids: Array = []
	for pid in sorted_keys(repo.places()):
		var sil = repo.place(String(pid)).get("silhouettes", {})
		if typeof(sil) == TYPE_DICTIONARY and sil.has(char_id):
			pids.append(String(pid))
	if pids.is_empty():
		return out
	var from := sil_from(repo, char_id)
	if from < 0:
		return out
	var cc := _conds(conds)
	for pid in pids:
		var sd = repo.place(String(pid)).get("silhouettes", {}).get(char_id, {})
		var talk = sd.get("talk") if typeof(sd) == TYPE_DICTIONARY and sd.has("talk") else null
		for a in fit_areas(repo, pid, "*"):
			if pid == HUB and not is_free(repo, HUB, String(a)):
				continue
			if typeof(talk) == TYPE_ARRAY and not talk.has(String(a)):
				continue   # W4: sólo en las áreas donde se le habla (silhouettes.<who>.talk; en un interior se ve por la ventana)
			out.append(reg(repo, {"key": "%s:%s%s@sil.%s.%s%s" % [kind, char_id, tag, pid, a, _suffix(cc)], "kind": kind,
				"char": char_id, "place": pid, "area": String(a), "tb": from_mask(from), "conds": cc, "cls": cls,
				"unit": _unit(pid, String(a), "q" if kind == "line" else "", char_id)}))
	return out

static func all_chars(repo) -> Array:
	var seen := {}
	for pid in sorted_keys(repo.places()):
		var pl: Dictionary = repo.place(String(pid))
		for ch in pl.get("characters", []):
			if typeof(ch) == TYPE_DICTIONARY:
				seen[String(ch.get("id", ""))] = true
		# siluetas con diálogo (Wiggins): también son personajes de la visita (_sil_char_srcs)
		var sil = pl.get("silhouettes", {})
		if typeof(sil) == TYPE_DICTIONARY and repo.has_method("dialogue"):
			for who in sil:
				if not repo.dialogue(String(who)).is_empty():
					seen[String(who)] = true
	return sorted_keys(seen)

# ---------------- reacciones: disparo y latencia (estático) ----------------
static func react_cls(r: Dictionary) -> String:
	var d = r.get("doc")
	if typeof(d) == TYPE_DICTIONARY and d.has("class"):
		return String(d["class"])
	for e in r.get("efecto", []):
		if typeof(e) == TYPE_DICTIONARY and ["columna", "noticia"].has(String(e.get("op", ""))):
			return "I"
	var all_nodes: bool = not r.get("rastro", []).is_empty()
	for x in r.get("rastro", []):
		if typeof(x) != TYPE_DICTIONARY or not x.has("nodo"):
			all_nodes = false
	return "C" if all_nodes else "P"

static func _mask_tks(m: int, out: Dictionary) -> void:
	for i in TimeKey.idx_count():
		if m & (1 << i):
			var x := TimeKey.from_idx(i)
			out[TimeKey.tk(x.day, x.slot)] = true

static func _as_list(v) -> Array:
	if v == null:
		return []
	if typeof(v) == TYPE_ARRAY:
		return v
	return [v]

static func _char_mask(repo, chars: Array) -> int:
	var m := 0
	for c in chars:
		for s in char_srcs(repo, String(c), [], "presence", "", "C"):
			m |= int(s.mask)
	return m

# tks en que puede ocurrir el acto que dispara la reacción (sin condiciones).
static func act_tks(repo, disp: Dictionary) -> Array:
	var out := {}
	var mt = disp.get("match", {})
	if typeof(mt) != TYPE_DICTIONARY:
		mt = {}
	for ev in _as_list(disp.get("evento", "")):
		match String(ev):
			"tiempo":
				if disp.has("tk"):
					out[TimeKey.of(disp.tk)] = true
			"slip":
				_mask_tks(area_open(repo, "L2", "*"), out)
			"order_copy":
				_mask_tks(area_open(repo, "L6", "*"), out)
			"go":
				var places: Array = _as_list(mt.get("place"))
				if places.is_empty():
					places = non_hub_places(repo)
				var area := String(mt.get("area", "*"))
				for p in places:
					_mask_tks(area_open(repo, String(p), area), out)
			"say", "show", "pay", "task":
				var chars: Array = _as_list(mt.get("char"))
				if chars.is_empty():
					chars = all_chars(repo)
				var cm := _char_mask(repo, chars)
				if cm == 0:
					cm = outing_mask(repo)
				_mask_tks(cm, out)
			"ad":
				var p0 := int(repo.schedule().get("ads", {}).get("prologue_pub_day", 1))
				var ds := days(repo)
				for d in range(maxi(p0, 1), 11):
					var dd: Dictionary = ds.get(d, {})
					if dd.is_empty() or bool(dd.get("times", true)):
						out[TimeKey.tk(d, "dawn")] = true
			"telegram", "letter":
				for x in infos(repo):
					if int(x.day) >= 1 and not x.fixed:
						out[int(x.tk)] = true
			"report":
				for r in repo.schedule().get("reports", []):
					if typeof(r) == TYPE_DICTIONARY:
						out[TimeKey.of(r.get("tk", ""))] = true
			"reaccion":
				# evento interno de entrega (HB9 ← M3, HB10 ← M1, M11 ← columna «—S.»): cuando puede entregarse la
				# reacción citada en match.rid; sin rid, cualquier amanecer de los días 1–10.
				var rids: Array = _as_list(mt.get("rid"))
				if rids.is_empty():
					for d in range(1, 11):
						out[TimeKey.tk(d, "dawn")] = true
				for rr in rids:
					for t in react_due(repo, String(rr)):
						out[int(t)] = true
			"inactividad":
				# HB13: dos franjas sin actos observados; puede cumplirse en cualquier franja desde el día 1.
				for x in infos(repo):
					if int(x.day) >= 1:
						out[int(x.tk)] = true
	var ks: Array = out.keys()
	ks.erase(-1)
	ks.sort()
	return ks

static func due_of(repo, lat: Dictionary, act_tk: int) -> int:
	var d := TimeKey.day_of(act_tk)
	match String(lat.get("tipo", "")):
		"voz_b":
			var vb = repo.schedule().get("voice_b", {})
			if typeof(vb) == TYPE_DICTIONARY and vb.has(str(d)):
				return TimeKey.of(vb[str(d)])
			return -1
		"fija":
			return TimeKey.of(lat.get("tk", ""))
		"inmediata":
			return act_tk
		"dias":
			return TimeKey.tk(d + int(lat.get("n", 1)), "dawn")
	# voz_a, siguiente_salida, siguiente_comunicacion y por defecto: amanecer siguiente
	return TimeKey.tk(d + 1, "dawn")

# tks (ordenados, únicos, ≤ día 10) en que la reacción puede resolverse/entregarse. Sin `flags` explícitos, los
# átomos de flag de `condiciones` valen "posible" (ANY_FLAG): el disparo depende de lo que hagan el jugador y las
# otras reacciones (HB8b exige wiggins_aliado de HB8), y el peor caso es que ocurra.
static func react_due(repo, rid: String, flags := {}) -> Array:
	var key := rid + "|" + _fkey(flags)
	var dc := sub(repo, "due")
	if dc.has(key):
		return dc[key]
	var busy := sub(repo, "due_busy")
	if busy.has(key):
		return []
	busy[key] = true
	var cflags: Dictionary = flags if not flags.is_empty() else {ANY_FLAG: true}
	var r: Dictionary = repo.reaction(rid)
	var out := {}
	if not r.is_empty():
		var disp = r.get("disparador", {})
		var lat = r.get("latencia", {})
		if typeof(disp) != TYPE_DICTIONARY:
			disp = {}
		if typeof(lat) != TYPE_DICTIONARY:
			lat = {}
		var conds = r.get("condiciones", {})
		for t in act_tks(repo, disp):
			if tri(conds, info_tk(repo, int(t)), cflags) == T_F:
				continue
			var d := due_of(repo, lat, int(t))
			if d < 0 or TimeKey.day_of(d) > 10:
				continue
			out[d] = true
		for c in repo.schedule().get("column", []):
			if typeof(c) == TYPE_DICTIONARY and String(c.get("r", "")) == rid:
				var t2 := TimeKey.of(c.get("tk", ""))
				if t2 >= 0:
					out[t2] = true
	var ks: Array = out.keys()
	ks.sort()
	busy.erase(key)
	dc[key] = ks
	return ks

# Franjas jugables en que puede ocurrir el acto disparador (condiciones de disparo con flags "posibles").
static func trigger_mask(repo, r: Dictionary) -> int:
	var disp = r.get("disparador", {})
	if typeof(disp) != TYPE_DICTIONARY:
		return 0
	var conds = r.get("condiciones", {})
	var m := 0
	for t in act_tks(repo, disp):
		var i := TimeKey.idx_of_tk(int(t))
		if i < 0:
			continue
		if tri(conds, info_tk(repo, int(t)), {ANY_FLAG: true}) == T_F:
			continue
		m |= 1 << i
	return m

# Lugares/áreas donde ocurre el acto disparador (para la visita y para eximir escenas automáticas de ese lugar).
static func trigger_spots(repo, r: Dictionary) -> Array:
	var disp = r.get("disparador", {})
	if typeof(disp) != TYPE_DICTIONARY:
		return []
	var mt = disp.get("match", {})
	if typeof(mt) != TYPE_DICTIONARY:
		mt = {}
	var out: Array = []
	for ev in _as_list(disp.get("evento", "")):
		match String(ev):
			"slip":
				for a in fit_areas(repo, "L2", "*"):
					out.append(["L2", String(a)])
			"order_copy":
				for a in fit_areas(repo, "L6", "*"):
					out.append(["L6", String(a)])
			"go":
				for p in _as_list(mt.get("place")):
					for a in fit_areas(repo, String(p), String(mt.get("area", "*"))):
						out.append([String(p), String(a)])
			"say", "show", "pay", "task":
				for c in _as_list(mt.get("char")):
					for s in char_srcs(repo, String(c), [], "presence", "", "C"):
						if String(s.place) != "":
							out.append([String(s.place), String(s.area)])
	return out

# cls_override: "I" para el rastro impreso en la columna/noticias (el sobre de la misma reacción puede ser P).
static func react_src(repo, rid: String, cls_override := "") -> Dictionary:
	var r: Dictionary = repo.reaction(rid)
	if r.is_empty():
		return {}
	var cls := react_cls(r)
	var key := "react:" + rid
	if cls_override != "" and cls_override != cls:
		cls = cls_override
		key += "|" + cls_override
	var due := react_due(repo, rid)
	var tb := 0
	if not due.is_empty():
		tb = from_mask(TimeKey.idx_at_or_after(due[0]))
	var spots := trigger_spots(repo, r)
	var unit := {}
	if not spots.is_empty():
		unit = _unit(String(spots[0][0]), String(spots[0][1]), "bm" if String(spots[0][0]) == "L2" else "", "")
	return reg(repo, {"key": key, "kind": "react", "rid": rid, "channel": String(r.get("canal", "")),
		"tipo": String(r.get("tipo", "")), "garantizada_si": r.has("garantizada_si"), "tb": tb, "cls": cls, "unit": unit})

# Ejemplar (p. ej. el número del Times) que imprime el rastro de una reacción: copia ∧ disponibilidad de la reacción.
static func react_copy_srcs(repo, rid: String, copy_id: String) -> Array:
	var rs := react_src(repo, rid)
	var out: Array = []
	for s in copy_srcs(repo, copy_id):
		var d: Dictionary = s.duplicate(true)
		d.erase("mask")
		d["key"] = String(s.key) + "|R:" + rid
		d["rid"] = rid
		if not rs.is_empty():
			d["tb"] = int(s.tb) & int(rs.tb)
		out.append(reg(repo, d))
	return out

# Diario J:<clave> (lists.diary): go[.L#[.área]] · slip · order_copy · say|show|pay|task[.char] · ad · arrival · stay
static func journal_srcs(repo, key: String) -> Array:
	var parts := key.split(".")
	var typ := String(parts[0])
	var out: Array = []
	match typ:
		"go":
			var places: Array = [String(parts[1])] if parts.size() > 1 else non_hub_places(repo)
			var area := String(parts[2]) if parts.size() > 2 else "*"
			for p in places:
				for a in fit_areas(repo, String(p), area):
					out.append(reg(repo, {"key": "journal:%s@%s.%s" % [key, p, a], "kind": "journal", "place": String(p),
						"area": String(a), "cls": "I", "unit": _unit(String(p), String(a))}))
		"slip", "order_copy":
			var pl := "L2" if typ == "slip" else "L6"
			for a in fit_areas(repo, pl, "*"):
				out.append(reg(repo, {"key": "journal:%s@%s.%s" % [key, pl, a], "kind": "journal", "place": pl,
					"area": String(a), "cls": "I", "unit": _unit(pl, String(a), "bm" if typ == "slip" else "", "")}))
		"say", "show", "pay", "task":
			var chars: Array = [String(parts[1])] if parts.size() > 1 else all_chars(repo)
			for c in chars:
				out.append_array(char_srcs(repo, String(c), [], "journal", "." + key, "I"))
		"ad":
			var p0 := int(repo.schedule().get("ads", {}).get("prologue_pub_day", 1))
			out.append(reg(repo, {"key": "journal:ad", "kind": "journal", "cls": "I",
				"tb": from_mask(TimeKey.idx_at_or_after(TimeKey.tk(p0, "dawn")))}))
		"arrival", "stay":
			out.append(reg(repo, {"key": "journal:" + typ, "kind": "journal", "cls": "I",
				"tb": from_mask(TimeKey.idx_at_or_after(TimeKey.tk(1, "dawn")))}))
	return out

# Aviso publicado por Lisle sin ejemplar declarado: desde el primer día de publicación.
static func ad_srcs(repo, ad_id: String) -> Array:
	var p0 := int(repo.schedule().get("ads", {}).get("prologue_pub_day", 1))
	var start := TimeKey.tk(p0, "dawn")
	if ad_id != "prologo":
		start = TimeKey.tk(p0 + 1, "dawn")
	return [reg(repo, {"key": "ad:" + ad_id, "kind": "ad", "cls": "I", "tb": from_mask(TimeKey.idx_at_or_after(start))})]

# ---------------- contrato ----------------
# frag: un fragmento de RouteDB (con "srcs" = claves de fuentes) o {ref, copy?} (se resuelve). Máscara base.
static func frag_mask(repo, frag: Dictionary) -> int:
	if frag.has("srcs"):
		var db := srcs_db(repo)
		var m := 0
		for k in frag.srcs:
			if typeof(k) == TYPE_DICTIONARY:
				m |= int(k.get("mask", 0))
			elif db.has(k):
				m |= int(db[k].get("mask", 0))
		return m
	if frag.has("mask"):
		return int(frag.mask)
	if frag.has("ref"):
		var rdb = load("res://core/graph/route_db.gd")
		var f: Dictionary = rdb.resolve(repo, String(frag.ref), String(frag.get("copy", "")))
		if f.has("srcs"):
			return frag_mask(repo, f)
	return 0
