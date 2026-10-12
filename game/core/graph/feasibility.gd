# core/graph/feasibility.gd — factibilidad global (§5.6 acotación 4). Dueño: W2-GRAPH.
# Contrato §3.8: plan(repo, from_idx, cuts, need) -> {ok, plan:[{idx, place}], unmet}
#   need = ids de conclusiones; ¿existe un plan de salidas que complete ≥1 ruta ★ elegible (fija/columna/garantizada) de
#   cada una entre from_idx y la última pasada útil? Extra en el resultado: routes {cid: ruta elegida}, units.
# Unidad de visita = (lugar, área, máscara de franjas). Una salida por franja (`go`, §3.2); el hub (L1, casa y tienda de
#   Crane, `free`), los originales en posesión, las escenas fijas y lo que llega por correo no gastan salida.
#   Fusión: misma (lugar, área) con franjas en común, respetando 3 papeletas por visita a la Sala (BM) y 3 preguntas por
#   personaje y visita. Búsqueda: conclusiones por menor número de rutas ★, DFS sobre la ruta elegida con matching
#   bipartito (Kuhn) unidades ↔ franjas y memo de fracasos por (conclusión, firma de unidades).
# Recursos (tarjeta HC04, consulta cerrada, Forasteros, chico del agente) = cortes recibidos en `cuts`.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Av = preload("res://core/graph/availability.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const CutModel = preload("res://core/graph/cut_model.gd")

const BM_SLIPS := 3
const QUESTIONS := 3

static func _src_mask(repo, sk: String, cuts: Array) -> int:
	var s := Av.src(repo, sk)
	var m := int(s.get("mask", 0))
	for c in cuts:
		var f := int(c.get("from_idx", -1))
		if f < 0:
			continue
		var lost := CutModel.hit(c, s)
		if lost != 0:
			m &= ~(Av.range_mask(f, int(c.get("to_idx", f))) & lost)
	return m

# Unidades que exige una ruta (null si algún fragmento no se puede obtener en la ventana).
static func route_units(repo, r: Dictionary, cuts: Array, from_idx: int, last: int):
	var win := Av.range_mask(from_idx, last)
	var units: Array = []
	for f in r.frags:
		var free := false
		var opts: Array = []
		for sk in f.srcs:
			var s := Av.src(repo, String(sk))
			var m := _src_mask(repo, String(sk), cuts) & win
			if m == 0:
				continue
			var u: Dictionary = s.get("unit", {})
			if u.is_empty():
				free = true
				break
			opts.append({"place": String(u.place), "area": String(u.area), "mask": m, "cap": String(u.get("cap", "")), "capk": String(u.get("capk", ""))})
		if free:
			continue
		if opts.is_empty():
			return null
		units.append({"opts": opts, "ref": String(f.ref)})
	return units

static func _caps_ok(u: Dictionary, o: Dictionary) -> bool:
	if o.cap == "bm":
		var docs: Array = u.bm.duplicate()
		if o.capk != "" and not docs.has(o.capk):
			docs.append(o.capk)
		return docs.size() <= BM_SLIPS
	if o.cap == "q":
		return int(u.q.get(o.capk, 0)) + 1 <= QUESTIONS
	return true

static func _add_cap(u: Dictionary, o: Dictionary) -> void:
	if o.cap == "bm" and o.capk != "" and not u.bm.has(o.capk):
		u.bm.append(o.capk)
	if o.cap == "q":
		u.q[o.capk] = int(u.q.get(o.capk, 0)) + 1

static func _new_unit(o: Dictionary) -> Dictionary:
	var u := {"place": o.place, "area": o.area, "mask": int(o.mask), "bm": [], "q": {}, "refs": []}
	_add_cap(u, o)
	return u

# Fusiona los requisitos de una ruta en la lista de visitas (copia).
static func merge(units: Array, req: Array) -> Array:
	var out: Array = []
	for u in units:
		out.append({"place": u.place, "area": u.area, "mask": u.mask, "bm": u.bm.duplicate(), "q": u.q.duplicate(), "refs": u.refs.duplicate()})
	for rq in req:
		var done := false
		for o in rq.opts:
			for u in out:
				if u.place == o.place and u.area == o.area and (int(u.mask) & int(o.mask)) != 0 and _caps_ok(u, o):
					u.mask = int(u.mask) & int(o.mask)
					_add_cap(u, o)
					u.refs.append(rq.ref)
					done = true
					break
			if done:
				break
		if done:
			continue
		if rq.opts.size() == 1:
			var nu := _new_unit(rq.opts[0])
			nu.refs.append(rq.ref)
			out.append(nu)
		else:
			# varias alternativas (p. ej. «una salida cualquiera»): cualquier franja de cualquiera de ellas
			var m := 0
			for o in rq.opts:
				m |= int(o.mask)
			out.append({"place": "*", "area": "*", "mask": m, "bm": [], "q": {}, "refs": [rq.ref]})
	return out

static func _aug(ui: int, units: Array, slot_of: Dictionary, seen: Dictionary, smask: int) -> bool:
	var m: int = int(units[ui].mask) & smask
	for i in TimeKey.idx_count():
		if (m & (1 << i)) == 0 or seen.has(i):
			continue
		seen[i] = true
		if not slot_of.has(i) or _aug(int(slot_of[i]), units, slot_of, seen, smask):
			slot_of[i] = ui
			return true
	return false

# Kuhn: {franja: unidad} o null.
static func match_units(units: Array, smask: int):
	var slot_of := {}
	for ui in units.size():
		if not _aug(ui, units, slot_of, {}, smask):
			return null
	return slot_of

static func _sig(units: Array) -> String:
	var ps: Array = []
	for u in units:
		ps.append("%s.%s:%d:%s:%s" % [u.place, u.area, u.mask, str(u.bm), str(u.q)])
	ps.sort()
	return "|".join(PackedStringArray(ps))

static func _dfs(order: Array, k: int, units: Array, opts: Dictionary, smask: int, memo: Dictionary, chosen: Dictionary):
	if k == order.size():
		var m = match_units(units, smask)
		if m == null:
			return null
		return {"units": units, "slots": m}
	var key := str(k) + "#" + _sig(units)
	if memo.has(key):
		return null
	var cid: String = order[k]
	for o in opts[cid]:
		var merged := merge(units, o.units)
		if match_units(merged, smask) == null:
			continue
		var r = _dfs(order, k + 1, merged, opts, smask, memo, chosen)
		if r != null:
			chosen[cid] = o.rid
			return r
	memo[key] = true
	return null

static func plan(repo, from_idx: int, cuts: Array, need: Array) -> Dictionary:
	var last := RouteDB.final_idx(repo)
	var smask := Av.outing_mask(repo) & Av.range_mask(from_idx, last)
	var opts := {}
	var unmet: Array = []
	for cid in need:
		var o: Array = []
		var lc := mini(last, RouteDB.last_idx(repo, String(cid)))
		for r in RouteDB.routes(repo, String(cid)):
			if not bool(r.star) or not bool(r.eligible) or not r.missing.is_empty():
				continue
			var us = route_units(repo, r, cuts, from_idx, lc)
			if us == null:
				continue
			o.append({"rid": String(r.id), "units": us, "n": us.size()})
		o.sort_custom(func(a, b): return a.n < b.n or (a.n == b.n and a.rid < b.rid))
		if o.is_empty():
			unmet.append(String(cid))
		else:
			opts[String(cid)] = o
	if not unmet.is_empty():
		return {"ok": false, "plan": [], "unmet": unmet, "routes": {}}
	var order: Array = opts.keys()
	order.sort_custom(func(a, b): return opts[a].size() < opts[b].size() or (opts[a].size() == opts[b].size() and String(a).naturalnocasecmp_to(String(b)) < 0))
	var chosen := {}
	var found = _dfs(order, 0, [], opts, smask, {}, chosen)
	if found == null:
		return {"ok": false, "plan": [], "unmet": ["(ninguna combinación de rutas ★ cabe en las salidas restantes)"], "routes": {}}
	var pl: Array = []
	var slots: Array = found.slots.keys()
	slots.sort()
	for i in slots:
		var u: Dictionary = found.units[int(found.slots[i])]
		pl.append({"idx": int(i), "place": String(u.place), "area": String(u.area), "refs": u.refs})
	return {"ok": true, "plan": pl, "unmet": [], "routes": chosen, "units": found.units.size()}
