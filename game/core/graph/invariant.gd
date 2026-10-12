# core/graph/invariant.gd — invariante acotada (§5.6, GDD§10.3; T1, T3, D1). Dueño: W2-GRAPH.
# Contrato §3.8:
#   check(repo, cid, from_idx, cuts, clipped := {}) -> {ok, intact, star, reason}
#   runtime_guard(st, repo, extra_cuts) -> {ok, violated:[cid]}        (D1; lo llama Director antes de aplicar un corte)
#   t3(repo, opts := {}) -> {ok, states, failures, ms}                 (+ pending, k, softened, fuzz, plan)
# Invariante en la franja i (conclusión obligatoria sin sellar): rutas elegibles (deps fija/columna/garantizada) intactas
#   = cada fragmento recortado o con algún bit en [i, última pasada útil] tras los cortes; ok ⇔ ≥2 intactas ∧ ≥1 sólo-I
#   ∧ ningún ejemplar común a todas las intactas (salvo diario J:).
# clipped: {clave de fragmento | ref: true} (cuentan como obtenidos).
# T3 (acotación §5.6): por conclusión, K_C = reacciones cuyos cortes tocan alguna fuente de sus rutas (|K_C| ≤ 5);
#   se enumeran subconjuntos × momento {más temprano, más tardío, +1 por D2} con D1 modelado (si el corte duro empeora
#   la invariante en alguna franja de [su momento, max(momento, eval_to)] → variante_blanda; sin variante_blanda =
#   falla; si sólo la blanda toca la conclusión, se aplica: D1 puede elegirla por otra) y se evalúa cada franja
#   P.N … 8.N (opts.eval_to). Control: todos los cortes de K_C en todos sus momentos. Factibilidad global
#   (Feasibility.plan desde opts.feas_from, def. 0, con los cortes duros de toda reacción en todos sus momentos como
#   recursos perdidos: consulta, Forasteros, encargos…; opts.feas_worst = false los omite). Fuzzing sembrado (opts.fuzz partidas, def. 300; opts.seed) con
#   D1 = el mismo código que runtime_guard (_worse_from), verificando la invariante tras cada amanecer hasta 8.N.
# D1 (runtime_guard): «empeora» = rompe la invariante o quita rutas intactas/sólo-I donde ya estaba rota, en alguna
#   franja desde la actual hasta max(actual, 8.N) (D1_UNTIL; los días 9–10 sólo la franja real, §12.1.9).
# ms: core/ no usa Time; opts.clock (Callable que devuelve ms) lo mide si se pasa.
# runtime_guard lee (sin escribir) st.clock, st.flags (máscaras con los flags reales), st.react.delivered (cortes ya
#   aplicados: {rid, due_tk, soft, cuts?}; cuts = los de runtime de Director), st.ded.sealed y st.ded.clips (recorte = {origin, tags}; cubre un fragmento si
#   comparte origen y alguna etiqueta a:). Cortes extra con rel:true se re-anclan a la franja actual.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")
const L = preload("res://core/util/log.gd")
const Det = preload("res://core/util/det.gd")
const Av = preload("res://core/graph/availability.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const CutModel = preload("res://core/graph/cut_model.gd")
const Feasibility = preload("res://core/graph/feasibility.gd")

const MAX_K := 5
const MAX_FAILS := 6
const NO_LIMIT := 1000

# ---------------- compilación por conclusión ----------------
static func compile(repo, cid: String) -> Dictionary:
	var cc := Av.sub(repo, "comp")
	if cc.has(cid):
		return cc[cid]
	var comp := {"cid": cid, "last": RouteDB.last_idx(repo, cid), "routes": [], "srcs": {}, "frags": {}, "pending": []}
	if repo.conclusion(cid).is_empty():
		comp.pending.append("conclusión %s inexistente" % cid)
	for r in RouteDB.routes(repo, cid):
		if not r.missing.is_empty():
			for m in r.missing:
				comp.pending.append("%s: %s" % [r.id, m])
			continue
		if not bool(r.eligible):
			continue
		var fr: Array = []
		var ex: Array = []
		for f in r.frags:
			var fk := String(f.key)
			if not fr.has(fk):
				fr.append(fk)
			if not comp.frags.has(fk):
				var at: Array = []
				for t in f.tags:
					if String(t).begins_with("a:"):
						at.append(String(t))
				comp.frags[fk] = {"ref": String(f.ref), "srcs": f.srcs, "origin": String(f.origin), "atags": at}
			for sk in f.srcs:
				comp.srcs[sk] = int(Av.src(repo, String(sk)).get("mask", 0))
			if String(f.exemplar) != "" and not ex.has(f.exemplar):
				ex.append(String(f.exemplar))
		comp.routes.append({"id": String(r.id), "star": bool(r.star), "frags": fr, "ex": ex})
	cc[cid] = comp
	return comp

static func _lab(i: int) -> String:
	var x := TimeKey.from_idx(i)
	if x.is_empty():
		return "idx%d" % i
	return TimeKey.label(TimeKey.tk(x.day, x.slot))

# Por ruta: último bit útil (≤ last) del fragmento más corto; recortado = sin límite.
static func _lims(comp: Dictionary, masks: Dictionary, clipped: Dictionary) -> Array:
	var last := int(comp.last)
	var fl := {}
	var out: Array = []
	for r in comp.routes:
		var lim := NO_LIMIT
		for fk in r.frags:
			var h := 0
			if fl.has(fk):
				h = fl[fk]
			else:
				var f: Dictionary = comp.frags[fk]
				if clipped.has(fk) or clipped.has(f.ref):
					h = NO_LIMIT
				else:
					var m := 0
					for sk in f.srcs:
						m |= int(masks.get(sk, 0))
					h = Av.highest(m, last)
				fl[fk] = h
			lim = mini(lim, h)
		out.append(lim)
	return out

static func _eval_lims(comp: Dictionary, lims: Array, i: int) -> Dictionary:
	var intact: Array = []
	var star: Array = []
	var common = null
	for k in comp.routes.size():
		if int(lims[k]) < i or i > int(comp.last):
			continue
		var r: Dictionary = comp.routes[k]
		intact.append(r.id)
		if r.star:
			star.append(r.id)
		if common == null:
			common = r.ex.duplicate()
		else:
			var keep: Array = []
			for e in common:
				if r.ex.has(e):
					keep.append(e)
			common = keep
	if common == null:
		common = []
	var ok: bool = intact.size() >= 2 and star.size() >= 1 and common.is_empty()
	var reason := ""
	if intact.size() < 2:
		reason = "%d ruta(s) intacta(s) %s" % [intact.size(), str(intact)]
	elif star.is_empty():
		reason = "ninguna ruta intacta es sólo-I %s" % str(intact)
	elif not common.is_empty():
		reason = "las rutas intactas %s comparten %s" % [str(intact), str(common)]
	return {"ok": ok, "intact": intact, "star": star, "reason": reason, "common": common}

static func _eval(comp: Dictionary, masks: Dictionary, i: int, clipped: Dictionary) -> Dictionary:
	return _eval_lims(comp, _lims(comp, masks, clipped), i)

# D1: el candidato empeora la invariante (la rompe, o quita rutas intactas / sólo-I cuando ya estaba rota).
static func _worse(before: Dictionary, after: Dictionary) -> bool:
	if after.ok:
		return false
	return before.ok or after.intact.size() < before.intact.size() or after.star.size() < before.star.size()

# D1 (§5.6: «paso 3 con el estado real … desde la franja actual»): el candidato empeora la invariante en ALGUNA franja
# de [from, max(from, until)] (until = horizonte de T3, 8.N por defecto; en los días 9–10 sólo la franja real, §12.1.9).
# Mirar sólo `from` no alcanza: con tres rutas intactas, un corte que vence una deja dos en `from`, pero si otra vence
# sola más tarde sólo queda una, cuando sin el corte quedaban dos.
# Es el mismo código para runtime_guard, la enumeración de T3 y el fuzzing.
const D1_UNTIL := "8.N"

static func d1_until() -> int:
	return Av.idx_at_or_before(TimeKey.parse(D1_UNTIL))

static func _worse_from(comp: Dictionary, before_masks: Dictionary, after_masks: Dictionary, from: int, until: int, clipped: Dictionary) -> bool:
	var lb := _lims(comp, before_masks, clipped)
	var la := _lims(comp, after_masks, clipped)
	if lb == la:
		return false
	var to := mini(maxi(from, until), int(comp.last))
	for i in range(maxi(from, 0), to + 1):
		if _worse(_eval_lims(comp, lb, i), _eval_lims(comp, la, i)):
			return true
	return false

# Aplica cortes con ventana propia (from_idx/to_idx). Devuelve si alguno tocó una fuente de la conclusión.
static func _apply_cuts_comp(repo, comp: Dictionary, masks: Dictionary, cuts: Array) -> bool:
	var touched := false
	for c in cuts:
		var f := int(c.get("from_idx", -1))
		if f < 0:
			continue
		var win := Av.range_mask(f, int(c.get("to_idx", f)))
		for sk in comp.srcs:
			var lost := CutModel.hit(c, Av.src(repo, String(sk)))
			if lost != 0:
				touched = true
				masks[sk] = int(masks.get(sk, 0)) & ~(win & lost)
	return touched

static func _hits(repo, comp: Dictionary, cuts: Array) -> Array:
	var out: Array = []
	for c in cuts:
		for sk in comp.srcs:
			var lost := CutModel.hit(c, Av.src(repo, String(sk)))
			if lost != 0:
				out.append([String(sk), lost, int(c.get("days", -1))])
	return out

static func _apply_hits(masks: Dictionary, hits: Array, start: int) -> void:
	for h in hits:
		var win := Av.range_mask(start, CutModel.window_end(start, int(h[2])))
		masks[h[0]] = int(masks.get(h[0], 0)) & ~(win & int(h[1]))

# ---------------- contrato ----------------
static func check(repo, cid: String, from_idx: int, cuts: Array, clipped := {}) -> Dictionary:
	var comp := compile(repo, cid)
	if not comp.pending.is_empty():
		return {"ok": false, "intact": [], "star": [], "reason": "contenido pendiente: %s" % str(comp.pending[0]), "pending": comp.pending}
	var masks: Dictionary = comp.srcs.duplicate()
	_apply_cuts_comp(repo, comp, masks, cuts)
	var ev := _eval(comp, masks, from_idx, clipped)
	return {"ok": ev.ok, "intact": ev.intact, "star": ev.star, "reason": ev.reason}

static func _stget(st, field: String) -> Dictionary:
	if st == null:
		return {}
	var v = null
	if typeof(st) == TYPE_DICTIONARY:
		v = st.get(field)
	elif typeof(st) == TYPE_OBJECT:
		v = st.get(field)
	return v if typeof(v) == TYPE_DICTIONARY else {}

static func current_idx(st) -> int:
	var clock := _stget(st, "clock")
	var day := int(clock.get("day", 0))
	var slot := String(clock.get("slot", ""))
	var t := TimeKey.tk(day, "dawn")
	if String(clock.get("phase", "")) == "night":
		t = TimeKey.tk(day, "night")
	elif TimeKey.ORD.has(slot) and slot != "dawn":
		t = TimeKey.tk(day, slot)
	return TimeKey.idx_at_or_after(t)

# Cortes ya aplicados en el mundo (instancias entregadas con corta/efecto que corta), anclados a su entrega.
# Si Director dejó inst.cuts (cortes de runtime que aplicó de verdad: filtros si_n/resultado, originales informados
# concretos; [] con variante blanda), los objetivos que Director resuelve (copy, copies, access, place, channel, task)
# salen de ahí; los demás (ref de ruta, flags traducidos) siguen saliendo de cuts_for. Sin inst.cuts: peor caso.
const RUNTIME_KINDS := ["copy", "copies", "access", "place", "channel", "task"]

static func active_cuts(st, repo) -> Array:
	var out: Array = []
	var react := _stget(st, "react")
	for inst in react.get("delivered", []):
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		var rid := String(inst.get("rid", ""))
		var due := TimeKey.of(inst.get("due_tk", -1))
		if rid == "" or due < 0:
			continue
		var start := TimeKey.idx_at_or_after(due)
		var soft := bool(inst.get("soft", false))
		var rc = inst.get("cuts")
		var exact: bool = typeof(rc) == TYPE_ARRAY and not soft
		for c in CutModel.cuts_for(repo, rid, soft):
			if exact:
				var skip := false
				for k in RUNTIME_KINDS:
					if c.target.has(k):
						skip = true
				if skip:
					continue
			out.append(CutModel.at(c, start))
		if exact:
			for c2 in rc:
				if typeof(c2) == TYPE_DICTIONARY and typeof(c2.get("target")) == TYPE_DICTIONARY:
					out.append(c2)
	return out

static func clipped_for(comp: Dictionary, clips) -> Dictionary:
	var out := {}
	if typeof(clips) != TYPE_DICTIONARY or clips.is_empty():
		return out
	var cl: Array = []
	for id in Av.sorted_keys(clips):
		var c = clips[id]
		if typeof(c) == TYPE_DICTIONARY:
			cl.append({"origin": String(c.get("origin", "")), "tags": RouteDB.flat_tags(c.get("tags", []))})
	for fk in comp.frags:
		var f: Dictionary = comp.frags[fk]
		for c in cl:
			if c.origin != f.origin:
				continue
			var hit: bool = f.atags.is_empty()
			for t in f.atags:
				if c.tags.has(t):
					hit = true
					break
			if hit:
				out[fk] = true
				break
	return out

static func _masks_flags(repo, comp: Dictionary, flags: Dictionary) -> Dictionary:
	if flags.is_empty():
		return comp.srcs.duplicate()
	var out := {}
	for sk in comp.srcs:
		out[sk] = Av.src_mask(repo, Av.src(repo, String(sk)), flags)
	return out

static func runtime_guard(st, repo, extra_cuts: Array) -> Dictionary:
	var cur := current_idx(st)
	var flags := _stget(st, "flags")
	var active := active_cuts(st, repo)
	var extra: Array = []
	# Si el llamador pasa cortes de runtime ya resueltos (ventana absoluta, sin rel: Director._runtime_cuts con sus
	# filtros si_n/resultado, los originales informados concretos y canal:* resuelto al canal del acto), ésos mandan para
	# los objetivos que Director resuelve (RUNTIME_KINDS); los genéricos de cuts_for (rel) de esos tipos sobran
	# ({copies:"informadas"} = todo P en posesión; {channel:"*"} = todos los canales). Ref de ruta y flags siguen.
	var has_abs := false
	for c in extra_cuts:
		if typeof(c) == TYPE_DICTIONARY and typeof(c.get("target")) == TYPE_DICTIONARY and not bool(c.get("rel", false)) and int(c.get("from_idx", -1)) >= 0:
			has_abs = true
	for c in extra_cuts:
		if typeof(c) != TYPE_DICTIONARY or typeof(c.get("target")) != TYPE_DICTIONARY:
			continue
		if has_abs and bool(c.get("rel", false)):
			var sup := false
			for k in RUNTIME_KINDS:
				if c.target.has(k):
					sup = true
			if sup:
				continue
		if bool(c.get("rel", false)) or int(c.get("from_idx", -1)) < 0:
			extra.append(CutModel.at(c, cur))
		else:
			extra.append(c)
	var ded := _stget(st, "ded")
	var sealed = ded.get("sealed", {})
	if typeof(sealed) != TYPE_DICTIONARY:
		sealed = {}
	var violated: Array = []
	for cid in RouteDB.mandatory(repo):
		if sealed.has(cid):
			continue
		var comp := compile(repo, String(cid))
		if not comp.pending.is_empty():
			continue
		var before := _masks_flags(repo, comp, flags)
		_apply_cuts_comp(repo, comp, before, active)
		var after: Dictionary = before.duplicate()
		if not _apply_cuts_comp(repo, comp, after, extra):
			continue
		var clipped := clipped_for(comp, ded.get("clips", {}))
		if _worse_from(comp, before, after, cur, d1_until(), clipped):
			violated.append(String(cid))
	if not violated.is_empty():
		L.i("graph", "D1: el corte violaría la invariante de %s en %s" % [str(violated), _lab(cur)])
	return {"ok": violated.is_empty(), "violated": violated}

# ---------------- T3 ----------------
static func _prio(r: Dictionary) -> int:
	if String(r.get("tipo", "")) == "columna":
		return 0
	match String(r.get("voz", "")):
		"B":
			return 1
		"A":
			return 2
	if String(r.get("lado", "")) == "moran":
		return 3
	if String(r.get("lado", "")) == "respuesta":
		return 4
	return 5

# Reacciones con cortes: {rid, hard, soft (null si no hay variante_blanda), moments, due, prio, repeat, hits}.
static func cut_units(repo) -> Array:
	var out: Array = []
	for r in repo.reactions():
		var rid := String(r.get("id", ""))
		var hard := CutModel.cuts_for(repo, rid, false)
		if hard.is_empty():
			continue
		var tm := CutModel.timing(repo, rid)
		var soft = null
		if CutModel.has_soft(repo, rid):
			soft = CutModel.cuts_for(repo, rid, true)
		var disp = r.get("disparador", {})
		var evs: Array = Av._as_list(disp.get("evento", "")) if typeof(disp) == TYPE_DICTIONARY else []
		out.append({"rid": rid, "hard": hard, "soft": soft, "moments": tm.moments, "due": tm.due, "prio": _prio(r),
			"repeat": evs.has("report"), "hits": {}})
	return out

static func _unit_hits(repo, comp: Dictionary, u: Dictionary, soft: bool) -> Array:
	var key := String(comp.cid) + ("|s" if soft else "|h")
	if u.hits.has(key):
		return u.hits[key]
	var cuts = u.soft if soft else u.hard
	var h: Array = [] if cuts == null else _hits(repo, comp, cuts)
	u.hits[key] = h
	return h

static func _fail(res: Dictionary, key: String, msg: String) -> void:
	var n := int(res.fails_by.get(key, 0))
	res.fails_by[key] = n + 1
	if n < MAX_FAILS:
		res.failures.append(msg)
	elif n == MAX_FAILS:
		res.failures.append("%s: (más fallas omitidas)" % key)

static func _enum_states(kc: Array, k: int, cur: Array, out: Array) -> void:
	if k == kc.size():
		if not cur.is_empty():
			out.append(cur.duplicate())
		return
	_enum_states(kc, k + 1, cur, out)
	for m in kc[k].moments:
		cur.append({"u": kc[k], "m": int(m)})
		_enum_states(kc, k + 1, cur, out)
		cur.pop_back()

static func _seq_less(a: Dictionary, b: Dictionary) -> bool:
	if a.m != b.m:
		return a.m < b.m
	if a.u.prio != b.u.prio:
		return a.u.prio < b.u.prio
	return String(a.u.rid) < String(b.u.rid)

static func _run_state(repo, comp: Dictionary, st: Array, eval_to: int, res: Dictionary, control: bool) -> void:
	var cid := String(comp.cid)
	var seq: Array = st.duplicate()
	seq.sort_custom(_seq_less)
	var masks: Dictionary = comp.srcs.duplicate()
	var label: Array = []
	for x in seq:
		var u: Dictionary = x.u
		var m := int(x.m)
		var hh := _unit_hits(repo, comp, u, false)
		var used := "%s@%s" % [u.rid, _lab(m)]
		if hh.is_empty():
			# El corte duro no toca esta conclusión, pero D1 puede aplicar la variante blanda por OTRA (runtime_guard
			# mira todas): peor caso para ésta = la blanda aplicada, y nada la protege después.
			var hs := _unit_hits(repo, comp, u, true)
			if not hs.is_empty():
				var st3: Dictionary = masks.duplicate()
				_apply_hits(st3, hs, m)
				if _worse_from(comp, masks, st3, m, eval_to, {}):
					_fail(res, cid, "%s: la variante_blanda de %s en %s viola la invariante (D1 puede aplicarla por otra conclusión)" % [cid, u.rid, _lab(m)])
				masks = st3
				used += "(blanda por otra)"
			label.append(used)
			continue
		var trial: Dictionary = masks.duplicate()
		_apply_hits(trial, hh, m)
		if _worse_from(comp, masks, trial, m, eval_to, {}):
			if u.soft == null:
				_fail(res, cid, "%s: %s en %s viola la invariante y no tiene variante_blanda (D1)" % [cid, u.rid, _lab(m)])
				masks = trial
			else:
				var st2: Dictionary = masks.duplicate()
				_apply_hits(st2, _unit_hits(repo, comp, u, true), m)
				res.softened += 1
				if _worse_from(comp, masks, st2, m, eval_to, {}):
					_fail(res, cid, "%s: la variante_blanda de %s en %s también viola la invariante" % [cid, u.rid, _lab(m)])
				masks = st2
				used += "(blanda)"
		else:
			masks = trial
		label.append(used)
	var lims := _lims(comp, masks, {})
	for i in range(eval_to + 1):
		res.states += 1
		var ev := _eval_lims(comp, lims, i)
		if not ev.ok:
			_fail(res, cid, "%s en %s con cortes [%s]%s: %s" % [cid, _lab(i), ", ".join(PackedStringArray(label)), " (control)" if control else "", ev.reason])
			break

static func _t3_conclusion(repo, comp: Dictionary, units: Array, eval_to: int, res: Dictionary) -> void:
	var cid := String(comp.cid)
	var lims := _lims(comp, comp.srcs, {})
	for i in range(eval_to + 1):
		res.states += 1
		var ev := _eval_lims(comp, lims, i)
		if not ev.ok:
			_fail(res, cid, "%s en %s, sin cortes: %s" % [cid, _lab(i), ev.reason])
			break
	var kc: Array = []
	for u in units:
		if not _unit_hits(repo, comp, u, false).is_empty() or not _unit_hits(repo, comp, u, true).is_empty():
			kc.append(u)
	var ids: Array = []
	for u in kc:
		ids.append(u.rid)
	res.k[cid] = ids
	if kc.size() > MAX_K:
		_fail(res, cid, "%s: |K_C| = %d > %d %s: partir la conclusión o quitar cortes" % [cid, kc.size(), MAX_K, str(ids)])
		return
	var states: Array = []
	_enum_states(kc, 0, [], states)
	for st in states:
		_run_state(repo, comp, st, eval_to, res, false)
	var all: Array = []
	for u in kc:
		for m in u.moments:
			all.append({"u": u, "m": int(m)})
	if not all.is_empty():
		_run_state(repo, comp, all, eval_to, res, true)

# xorshift32 sembrado con Det (sin RNG global).
static func _rnd(stt: Array) -> float:
	var x: int = stt[0]
	if x == 0:
		x = 0x9E3779B9
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	stt[0] = x
	return float(x) / 4294967296.0

static func _inst_less(a: Dictionary, b: Dictionary) -> bool:
	if a.day != b.day:
		return a.day < b.day
	if a.u.prio != b.u.prio:
		return a.u.prio < b.u.prio
	return String(a.u.rid) < String(b.u.rid)

static func _fuzz(repo, comps: Dictionary, units: Array, n: int, seed: int, eval_to: int, res: Dictionary) -> void:
	var cids := Av.sorted_keys(comps)
	var rel: Array = []
	for u in units:
		for cid in cids:
			if not _unit_hits(repo, comps[cid], u, false).is_empty():
				rel.append(u)
				break
	var nidx := TimeKey.idx_count()
	for g in n:
		var rng := [Det.h32([seed, "fuzz", g])]
		var inst: Array = []
		for u in rel:
			var dd := {}
			for t in u.due:
				dd[TimeKey.day_of(int(t))] = true
			var picked := false
			for d in Av.sorted_keys(dd):
				if picked and not u.repeat:
					break
				if _rnd(rng) < 0.45:
					var day := int(d)
					if day < 10 and CutModel.deferrable(repo.reaction(u.rid), day) and _rnd(rng) < 0.3:
						day += 1
					inst.append({"u": u, "day": day})
					picked = true
		inst.sort_custom(_inst_less)
		var masks := {}
		for cid in cids:
			masks[cid] = comps[cid].srcs.duplicate()
		var clipped := {}
		var applied: Array = []
		var k := 0
		for day in range(1, 11):
			var start := TimeKey.idx_at_or_after(TimeKey.tk(day, "dawn"))
			if start >= nidx:
				break
			while k < inst.size() and int(inst[k].day) == day:
				var u: Dictionary = inst[k].u
				k += 1
				var viol := false
				var trials := {}
				for cid in cids:
					var hh := _unit_hits(repo, comps[cid], u, false)
					if hh.is_empty():
						continue
					var tr: Dictionary = masks[cid].duplicate()
					_apply_hits(tr, hh, start)
					trials[cid] = tr
					if _worse_from(comps[cid], masks[cid], tr, start, eval_to, clipped):
						viol = true
				if viol and u.soft != null:
					res.softened += 1
					for cid in cids:
						var hs := _unit_hits(repo, comps[cid], u, true)
						if not hs.is_empty():
							_apply_hits(masks[cid], hs, start)
					applied.append("%s(blanda)@%d" % [u.rid, day])
				else:
					for cid in trials:
						masks[cid] = trials[cid]
					applied.append("%s@%d" % [u.rid, day])
			if start <= eval_to:
				for cid in cids:
					res.states += 1
					var ev := _eval(comps[cid], masks[cid], start, clipped)
					if not ev.ok:
						_fail(res, "fuzz", "fuzz #%d (semilla %d) amanecer del día %d, %s: %s; cortes %s" % [g, seed, day, cid, ev.reason, str(applied)])
			var dbits := Av.day_bits(day)
			for cid in cids:
				var comp: Dictionary = comps[cid]
				for fk in Av.sorted_keys(comp.frags):
					if clipped.has(fk):
						continue
					var m := 0
					for sk in comp.frags[fk].srcs:
						m |= int(masks[cid].get(sk, 0))
					if (m & dbits) != 0 and _rnd(rng) < 0.12:
						clipped[fk] = true
	res.fuzz = int(res.fuzz) + n

static func t3(repo, opts := {}) -> Dictionary:
	var clock = opts.get("clock")
	var t0 := 0
	if clock is Callable:
		t0 = int(clock.call())
	var res := {"ok": true, "states": 0, "failures": [], "ms": 0, "pending": [], "k": {}, "softened": 0, "fuzz": 0,
		"plan": {}, "fails_by": {}}
	var eval_to := Av.idx_at_or_before(TimeKey.of(String(opts.get("eval_to", "8.N"))))
	var mand := RouteDB.mandatory(repo)
	if opts.has("only"):
		var keep: Array = []
		for c in mand:
			if opts.only.has(c):
				keep.append(c)
		mand = keep
	var comps := {}
	for cid in mand:
		var comp := compile(repo, String(cid))
		if not comp.pending.is_empty():
			res.pending.append("%s: %s" % [cid, comp.pending[0]])
			continue
		comps[String(cid)] = comp
	var units := cut_units(repo)
	for cid in Av.sorted_keys(comps):
		_t3_conclusion(repo, comps[cid], units, eval_to, res)
	if bool(opts.get("feasibility", true)) and not comps.is_empty():
		# Recursos (§5.6 acotación 4: consulta cerrada, Forasteros, encargos…) = cortes duros de toda reacción en todos sus
		# momentos (peor caso, sin D1); opts.feas_worst = false planifica sin cortes.
		var fcuts: Array = []
		if bool(opts.get("feas_worst", true)):
			for u in units:
				for c in u.hard:
					for m in u.moments:
						fcuts.append(CutModel.at(c, int(m)))
		var p := Feasibility.plan(repo, int(opts.get("feas_from", 0)), fcuts, Av.sorted_keys(comps))
		res.plan = p
		if not p.ok:
			_fail(res, "plan", "factibilidad global desde %s: %s" % [_lab(int(opts.get("feas_from", 0))), str(p.unmet)])
	var nf := int(opts.get("fuzz", 300))
	if nf > 0 and not comps.is_empty():
		_fuzz(repo, comps, units, nf, int(opts.get("seed", 1894)), eval_to, res)
	res.ok = res.failures.is_empty()
	if clock is Callable:
		res.ms = int(clock.call()) - t0
	L.i("graph", "T3: %d estados, %d fallas, %d pendientes, %d suavizados por D1, %d ms" % [res.states, res.failures.size(), res.pending.size(), res.softened, res.ms])
	return res
