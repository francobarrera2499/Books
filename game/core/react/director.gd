# core/react/director.gd — ReactionDirector (ARCHITECTURE §5.3, GDD§9.8). Dueño: W2-REACT.
# Lo sabe todo, pero sólo recibe eventos públicos (§3.6) y el paso del tiempo; nunca lee st.ded (T8).
# st.react = {queue:[inst], delivered:[inst], strong_days:{"d":true}, channels_seen:{K-x: día},
#             inactivity:{slots, checked_tk, acts:[tk]}, counters:{}, once:{}, imm_pending:{}, world:{…}, holmes:{}, moran:{}}
# inst = {iid "R.<rid>.<n>", rid, due_tk, prio, channel, voice, level, strong, anchor:{…, act}, tpl, vars, soft,
#         src_ev, merged_into, lado, tipo, n, guaranteed, act_tk, mode ("" | "salida"), deferred, (al entregar) view,
#         how, text, words, applied, blocks, delivered_tk, overflow, en_persona}
# on_public_event(ev): Sensors → HolmesAgent/MoranAgent (+ respuestas ciegas) → Latency → cola (dedup una_vez_por).
#   Inmediatas (no de diálogo) y siguiente_comunicacion se aplican en el acto; las de diálogo las aplica Dialogue
#   llamando a immediate(ev) ANTES de emitir el evento (y aquí no se repiten). Un acto observado pone en 0 la inactividad.
#   Un go resuelve las instancias «siguiente_salida» (M1, M2) ya vencidas.
# on_time(tk): reacciones de columna/tiempo de ese tk; en dawn resuelve la mañana (orden prio → iid; D3 canales de a uno
#   y fusión de cartas de voz A; D2 una fuerte por mañana y calma después, difiere primero Moran y luego cortes de voz A;
#   D1 variante blanda si Invariant.runtime_guard viola; Effects.apply); en M/T/N resuelve lo vencido (p. ej. 10.M voz B
#   en persona); en night: «siguiente_salida» que no hubo salida, escenas fijas (M7) y HB13 si inactividad ≥ 2 franjas.
#   Lo que vencería después del día 10 se aplica en el acto sin documento (sólo flags: «fusionar con el día 10»).
# Entregar encadena un evento interno «reaccion» (HB9 tras M3, HB10 tras M1, M11 tras una respuesta «—S.» en la columna).
# Nunca emite un aviso de «reacción»: sólo tray (WorldModel.deliver), flag y scene (Effects).
extends RefCounted

const L = preload("res://core/util/log.gd")
const J = preload("res://core/util/j.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Sensors = preload("res://core/react/sensors.gd")
const Latency = preload("res://core/react/latency.gd")
const HolmesAgent = preload("res://core/react/holmes_agent.gd")
const MoranAgent = preload("res://core/react/moran_agent.gd")
const Effects = preload("res://core/react/effects.gd")
# graph/ se carga en tiempo de ejecución (sólo D1): un módulo ajeno a medio hacer no rompe la compilación de react/.
const INVARIANT_PATH := "res://core/graph/invariant.gd"
const CUT_MODEL_PATH := "res://core/graph/cut_model.gd"

const LAST_DAY := 10
const ALL_SIDES := ["holmes", "mycroft", "moran", "respuesta"]
# Contenido que identifica un evento (sin numeración ni claves que Dialogue agrega sólo para immediate: reaction, visit…).
const SIG_FIELDS := ["type", "char", "kind", "topic", "assertion", "bait_topic", "canary", "phrase", "item", "amount_d", "task",
	"place", "area", "doc", "seat", "ad", "form", "to", "n", "mode"]
const MAX_CHAIN := 4

# Sólo tests: Callable(st, repo, rid, runtime_cuts) -> {ok, violated} en lugar de CutModel.cuts_for + Invariant.runtime_guard.
static var guard_hook = null
static var _depth := 0

static func init_state(st, repo) -> void:
	if typeof(st.react) != TYPE_DICTIONARY:
		st.react = {}
	var r: Dictionary = st.react
	for k in ["queue", "delivered"]:
		if typeof(r.get(k)) != TYPE_ARRAY:
			r[k] = []
	for k in ["strong_days", "channels_seen", "counters", "once", "imm_pending"]:
		if typeof(r.get(k)) != TYPE_DICTIONARY:
			r[k] = {}
	if typeof(r.get("inactivity")) != TYPE_DICTIONARY:
		r["inactivity"] = {"slots": 0, "checked_tk": -1, "acts": []}
	HolmesAgent.init_state(st, repo)
	MoranAgent.init_state(st, repo)
	Effects.init_world(st)

static func _ensure(st, repo) -> void:
	if typeof(st.react) != TYPE_DICTIONARY or not st.react.has("inactivity") or not st.react.has("world"):
		init_state(st, repo)

# ---------------- eventos públicos ----------------
static func on_public_event(st, repo, ev: Dictionary) -> void:
	_ensure(st, repo)
	_depth = 0
	var et := String(ev.get("type", ""))
	var bumped := {}
	var skip: Array = []
	var ip: Dictionary = st.react.imm_pending
	var e2: Dictionary = ev
	if not ip.is_empty() and String(ip.get("sig", "")) == sig(ev):
		bumped = ip.get("bumped", {}).duplicate()
		skip = RDB._as_arr(ip.get("rids", [])).duplicate()
		if String(ip.get("forced", "")) != "" and not ev.has("reaction") and not ev.has("_reaction"):
			e2 = ev.duplicate(true)
			e2["reaction"] = String(ip.forced)
	st.react.imm_pending = {}
	var obs_list := Sensors.observe(st, repo, ev)
	if not obs_list.is_empty():
		_mark_act(st, int(ev.get("tk", 0)))
	var cands: Array = []
	for obs in obs_list:
		obs["_bumped"] = bumped
		obs["_skip"] = skip
		cands.append_array(HolmesAgent.observe(st, repo, obs, e2))
	cands.append_array(MoranAgent.observe(st, repo, e2, {"bumped": bumped, "skip": skip}))
	cands.append_array(RDB.collect(st, repo, e2, null, ["respuesta"], bumped, "all", skip))
	cands.append_array(RDB.collect(st, repo, e2, null, ALL_SIDES, bumped, "all", skip, "only"))
	if et == "report":
		HolmesAgent.on_report(st, repo, ev)
	_enqueue_all(st, repo, cands, int(ev.get("tk", 0)))
	if et == "go":
		_resolve_salida(st, repo, int(ev.get("tk", 0)), false)

# Reacciones en escena (HB4 gesto, HB6, HB8, M4 ante Pell…): Dialogue la llama ANTES de emitir el evento (ev sin seq).
# Las aplica en el acto y devuelve [{rid, iid, line, effects, soft}]; on_public_event no las repite.
static func immediate(st, repo, ev: Dictionary) -> Array:
	_ensure(st, repo)
	var e2: Dictionary = ev.duplicate(true)
	if not e2.has("tk"):
		var cday := int(st.clock.get("day", 0)) if typeof(st.clock) == TYPE_DICTIONARY else 0
		var cslot := String(st.clock.get("slot", "M")) if typeof(st.clock) == TYPE_DICTIONARY else "M"
		e2["tk"] = TimeKey.tk(cday, cslot if TimeKey.ORD.has(cslot) else "M")
	if not e2.has("day"):
		e2["day"] = TimeKey.day_of(int(e2.tk))
	var bumped := {}
	var cands: Array = []
	for obs in Sensors.observe(st, repo, e2):
		obs["_bumped"] = bumped
		obs["_mode"] = "imm"
		cands.append_array(HolmesAgent.observe(st, repo, obs, e2))
	cands.append_array(MoranAgent.observe(st, repo, e2, {"bumped": bumped, "mode": "imm"}))
	cands.append_array(RDB.collect(st, repo, e2, null, ALL_SIDES, bumped, "imm", [], "only"))
	var out: Array = []
	var rids: Array = []
	for c in cands:
		if c.has("accumulate_into"):
			continue
		var rule: Dictionary = repo.reaction(String(c.rid))
		var inst := _make_inst(st, repo, rule, c, int(e2.get("tk", 0)))
		if inst.is_empty():
			continue
		_register(st, repo, inst, c)
		_deliver(st, repo, inst, int(inst.due_tk))
		rids.append(String(c.rid))
		out.append({"rid": String(inst.rid), "iid": String(inst.iid), "line": String(inst.get("text", Effects.instance_text(st, repo, inst))),
			"effects": RDB._as_arr(inst.get("applied", [])).duplicate(), "soft": bool(inst.get("soft", false))})
	st.react.imm_pending = {"sig": sig(ev), "bumped": bumped, "rids": rids, "forced": String(ev.get("reaction", ev.get("_reaction", "")))}
	return out

static func debug_queue(st) -> Array:
	if typeof(st.react) != TYPE_DICTIONARY:
		return []
	return RDB._as_arr(st.react.get("queue", [])).duplicate(true)

# Firma de contenido de un evento (sin numeración): empareja immediate() con su on_public_event.
static func sig(ev: Dictionary) -> String:
	var d := {}
	for k in SIG_FIELDS:
		if ev.has(k) and ev[k] != null:
			d[k] = ev[k]
	return J.stringify_canon(d).md5_text()

# ---------------- tiempo ----------------
static func on_time(st, repo, tk: int) -> void:
	_ensure(st, repo)
	_depth = 0
	st.react.imm_pending = {}
	var slot := TimeKey.slot_of(tk)
	_inactivity_step(st, repo, tk)
	_time_reactions(st, repo, tk)
	if slot == "dawn":
		_resolve_morning(st, repo, tk)
	else:
		_resolve_due(st, repo, tk)
	if slot == "night":
		_resolve_salida(st, repo, tk, true)
		_hb13(st, repo, tk)

static func _time_reactions(st, repo, tk: int) -> void:
	for rid in RDB.time_rids(repo, tk):
		var rule: Dictionary = repo.reaction(String(rid))
		if rule.is_empty():
			L.i("director", "columna sin reacción en datos: %s" % rid)
			continue
		var ok := "%s|@%d" % [rid, tk]
		if st.react.once.has(ok):
			continue
		var anchor := _ancla_de(st, repo, rule, tk)
		var ctx := {"st": st, "repo": repo, "anchor": anchor, "tk": tk, "ev": anchor}
		if not Cond.eval(rule.get("condiciones", {}), ctx):
			continue
		var c := {"rid": String(rid), "channel": String(rule.get("canal", "")) if RDB.CHANNELS.has(String(rule.get("canal", ""))) else "",
			"anchor": anchor, "n": 0, "guaranteed": true, "once": ok, "src_ev": int(anchor.get("seq", 0)), "act_tk": tk, "imm": false, "counter": "",
			"fixed_due": tk}
		_enqueue_all(st, repo, [c], tk)

static func _ancla_de(st, repo, rule: Dictionary, tk: int) -> Dictionary:
	var base := {"tk": tk, "day": TimeKey.day_of(tk), "type": "tiempo"}
	var ad = rule.get("ancla_de")
	if typeof(ad) != TYPE_DICTIONARY or ad.is_empty():
		return base
	for ev in st.events:
		if typeof(ev) != TYPE_DICTIONARY or String(ev.get("type", "")) != String(ad.get("evento", "")):
			continue
		if int(ev.get("tk", 0)) > tk:
			continue
		if RDB.match_ok(repo, ad.get("match", {}), ev, null, st):
			var a := RDB.build_anchor(repo, rule, ev, null)
			a["anchored"] = true
			return a
	return base

# ---------------- cola ----------------
static func _enqueue_all(st, repo, cands: Array, now_tk: int) -> void:
	for c in cands:
		if c.has("accumulate_into"):
			_accumulate(st, String(c.accumulate_into), c.anchor)
			continue
		var rule: Dictionary = repo.reaction(String(c.rid))
		if rule.is_empty():
			continue
		var inst := _make_inst(st, repo, rule, c, now_tk)
		if inst.is_empty():
			continue
		_register(st, repo, inst, c)
		var lt := RDB.latency_type(rule)
		if lt == "inmediata" or lt == "siguiente_comunicacion":
			_deliver(st, repo, inst, now_tk)
		elif TimeKey.day_of(int(inst.due_tk)) > LAST_DAY:
			inst["overflow"] = true
			_deliver(st, repo, inst, now_tk)
		else:
			st.react.queue.append(inst)

static func _register(st, repo, inst: Dictionary, c: Dictionary) -> void:
	if String(c.get("once", "")) != "":
		st.react.once[String(c.once)] = true
	var k := "fired." + String(inst.rid)
	st.react.counters[k] = int(st.react.counters.get(k, 0)) + 1
	HolmesAgent.on_enqueued(st, repo, inst)

static func _make_inst(st, repo, rule: Dictionary, c: Dictionary, now_tk: int) -> Dictionary:
	if rule.is_empty():
		return {}
	var rid := String(rule.get("id", ""))
	var due := int(c.get("fixed_due", -1))
	if due < 0:
		due = Latency.due_tk(st, repo, rule, int(c.get("act_tk", now_tk)))
	if due < 0:
		L.i("director", "%s: sin fecha de entrega (latencia %s, acto %s)" % [rid, RDB.latency_type(rule), TimeKey.label(int(c.get("act_tk", now_tk)))])
		return {}
	var iid: String = st.next_id("inst", "R.%s." % rid, 1)
	var inst := {"iid": iid, "rid": rid, "due_tk": due, "prio": RDB.prio(rule), "channel": String(c.get("channel", "")),
		"voice": RDB.voice(rule), "level": int(rule.get("nivel", 0)), "strong": RDB.is_strong(rule, TimeKey.day_of(due)),
		"anchor": c.get("anchor", {}), "tpl": "", "vars": {}, "soft": false, "src_ev": int(c.get("src_ev", 0)), "merged_into": "",
		"lado": RDB.lado(rule), "tipo": String(rule.get("tipo", "")), "n": int(c.get("n", 0)), "guaranteed": bool(c.get("guaranteed", false)),
		"act_tk": int(c.get("act_tk", now_tk)), "mode": "salida" if RDB.latency_type(rule) == "siguiente_salida" else "", "deferred": 0}
	if RDB.voice(rule) == "B" and TimeKey.slot_of(due) != "dawn" and not RDB.is_column(rule):
		inst["en_persona"] = true
	inst.vars = RDB.vars_for(st, repo, rule, inst)
	inst.tpl = String(RDB.select_rastro(st, repo, rule, inst).get("tpl", ""))
	return inst

static func _accumulate(st, iid: String, anchor: Dictionary) -> void:
	for inst in st.react.queue:
		if String(inst.iid) == iid:
			var a: Dictionary = inst.anchor
			if typeof(a.get("itinerary")) != TYPE_ARRAY:
				a["itinerary"] = []
			a.itinerary.append({"streets": anchor.get("streets", []), "hour": anchor.get("hour", ""), "act": anchor.get("act", "")})
			return

static func _sort(arr: Array) -> void:
	arr.sort_custom(func(a, b):
		if int(a.prio) != int(b.prio):
			return int(a.prio) < int(b.prio)
		return String(a.iid).naturalnocasecmp_to(String(b.iid)) < 0)

static func _defer(inst: Dictionary, why: String) -> void:
	inst.due_tk = int(inst.due_tk) + 10
	inst.deferred = int(inst.get("deferred", 0)) + 1
	L.i("director", "%s diferida a %s (%s)" % [inst.iid, TimeKey.label(int(inst.due_tk)), why])

# ---------------- resolución ----------------
static func _resolve_morning(st, repo, tk: int) -> void:
	var day := TimeKey.day_of(tk)
	var due: Array = []
	for inst in st.react.queue:
		if int(inst.due_tk) <= tk and String(inst.get("mode", "")) == "":
			due.append(inst)
	if due.is_empty():
		return
	_sort(due)
	due = _d3(st, repo, due, day)
	due = _d2(st, repo, due, day)
	_merge_letters(st, repo, due)
	for inst in due:
		_deliver(st, repo, inst, tk)

static func _resolve_due(st, repo, tk: int) -> void:
	var due: Array = []
	for inst in st.react.queue:
		if int(inst.due_tk) <= tk and String(inst.get("mode", "")) == "":
			due.append(inst)
	_sort(due)
	for inst in due:
		_deliver(st, repo, inst, tk)

# M1/M2: en la primera salida del día siguiente o, si no sale, a la noche. D2 vale también aquí.
static func _resolve_salida(st, repo, tk: int, at_night: bool) -> void:
	var due: Array = []
	for inst in st.react.queue:
		if String(inst.get("mode", "")) == "salida" and int(inst.due_tk) <= tk:
			due.append(inst)
	_sort(due)
	var day := TimeKey.day_of(tk)
	for inst in due:
		var rule: Dictionary = repo.reaction(String(inst.rid))
		if RDB.is_strong(rule, day) and day < LAST_DAY:
			if st.react.strong_days.has(str(day)) or st.react.strong_days.has(str(day - 1)):
				_defer(inst, "D2 (salida)")
				continue
		_deliver(st, repo, inst, tk)

# D3: un canal nuevo por mañana. Las cartas de voz A se fusionan (nunca se difieren) y la columna no se difiere.
static func _d3(st, repo, due: Array, day: int) -> Array:
	var seen: Dictionary = st.react.channels_seen
	var newch := {}
	for inst in due:
		var ch := String(inst.get("channel", ""))
		if not RDB.CHANNELS.has(ch) or seen.has(ch):
			continue
		if String(inst.lado) == "moran" or String(inst.lado) == "respuesta":
			continue
		if not newch.has(ch):
			newch[ch] = []
		newch[ch].append(inst)
	if newch.size() < 2 or day >= LAST_DAY:
		return due
	var allowed := {}
	var chs: Array = newch.keys()
	chs.sort()
	for ch in chs:
		for inst in newch[ch]:
			if String(inst.tipo) == "columna" or String(inst.voice) == "A":
				allowed[ch] = true
	if allowed.is_empty():
		var best = null
		for ch in chs:
			var first = newch[ch][0]
			if best == null or int(first.prio) < int(best.prio) or (int(first.prio) == int(best.prio) and String(first.iid).naturalnocasecmp_to(String(best.iid)) < 0):
				best = first
		allowed[String(best.channel)] = true
	var out: Array = []
	for inst in due:
		var ch := String(inst.get("channel", ""))
		if newch.has(ch) and not allowed.has(ch):
			# La voz B nunca se difiere a un día en que no contesta (GDD§9.3: domingo sin Times, miércoles «nada»;
			# HC03): ahí la latencia es la evidencia y prevalece sobre D3.
			if String(inst.voice) == "B" and not Latency.voice_b_delivers_on(repo, day + 1):
				L.i("director", "%s: D3 no la difiere (la voz B no contesta el día %d)" % [inst.iid, day + 1])
				out.append(inst)
				continue
			_defer(inst, "D3")
			continue
		out.append(inst)
	return out

# D2: ≤1 disparada fuerte por mañana y calma la mañana siguiente; choque → se difiere primero Moran, luego voz A.
static func _d2(st, repo, due: Array, day: int) -> Array:
	var strongs: Array = []
	for inst in due:
		if RDB.is_strong(repo.reaction(String(inst.rid)), day):
			strongs.append(inst)
	if strongs.is_empty() or day >= LAST_DAY:
		return due
	var blocked: bool = st.react.strong_days.has(str(day - 1))
	var keep = null
	if not blocked:
		# se difiere primero Moran, después los cortes de voz A: se queda la primera que no es de Moran ni corta
		# (una carta de voz A sin corte conserva su demora de una noche), si no la primera que no es de Moran.
		for inst in strongs:
			if String(inst.lado) != "moran" and not _cuts(st, repo, inst):
				keep = inst
				break
		if keep == null:
			for inst in strongs:
				if String(inst.lado) != "moran":
					keep = inst
					break
		if keep == null:
			keep = strongs[0]
	var out: Array = []
	for inst in due:
		if strongs.has(inst) and not is_same(inst, keep):
			_defer(inst, "D2")
			continue
		out.append(inst)
	return out

static func _cuts(st, repo, inst: Dictionary) -> bool:
	for e in RDB.effects_for(st, repo, repo.reaction(String(inst.rid)), inst, false):
		if RDB.CUT_OPS.has(String(e.get("op", ""))):
			return true
	return false

# Una sola carta por mañana y voz (A; también B «—S.»): el primero en orden lleva los demás como bloques.
static func _merge_letters(st, repo, due: Array) -> void:
	var groups := {}
	for inst in due:
		var rule: Dictionary = repo.reaction(String(inst.rid))
		if RDB.is_column(rule) or String(inst.lado) == "moran" or String(inst.lado) == "respuesta":
			continue
		var v := String(inst.voice)
		if v != "A" and v != "B":
			continue
		var de := RDB.doc_effect(st, repo, rule, inst, false)
		if String(de.get("op", "")) != "carta" or bool(inst.get("en_persona", false)):
			continue
		var how := Latency.how_for(st, repo, rule, inst, de)
		if how != "correo" and how != "en_mano":
			continue
		var key := v + "|" + how
		if not groups.has(key):
			groups[key] = []
		groups[key].append(inst)
	for v in groups:
		var g: Array = groups[v]
		if g.size() < 2:
			continue
		var head: Dictionary = g[0]
		head["blocks"] = []
		for i in range(1, g.size()):
			head.blocks.append(String(g[i].iid))
			g[i]["merged_into"] = String(head.iid)
			# el texto de los bloques se arma al entregar la cabeza: llevan ya el tono de esta mañana
			g[i]["tono"] = HolmesAgent.tone(st)

# D1: guardia de rutas antes de aplicar un corte.
# Deja en inst.cuts los cortes de runtime que la entrega aplica de verdad ([] si no corta o si va la variante blanda):
# Invariant.active_cuts puede leerlos en lugar de CutModel.cuts_for (que no conoce si_n, los ejemplares informados ni
# la variante elegida).
static func _d1(st, repo, rule: Dictionary, inst: Dictionary) -> bool:
	inst["cuts"] = []
	if RDB._as_arr(rule.get("corta", [])).is_empty() or bool(inst.get("overflow", false)):
		return false
	var cuts_any := false
	for e in RDB.effects_for(st, repo, rule, inst, false):
		if RDB.CUT_OPS.has(String(e.get("op", ""))):
			cuts_any = true
	if not cuts_any:
		return false
	var rc := _runtime_cuts(st, repo, rule, inst)
	inst["cuts"] = rc.duplicate(true)
	var res = null
	if guard_hook != null:
		res = guard_hook.call(st, repo, String(inst.rid), rc)
	else:
		var cm = load(CUT_MODEL_PATH)
		var inv = load(INVARIANT_PATH)
		if cm == null or inv == null:
			return false
		var cuts: Array = RDB._as_arr(cm.cuts_for(repo, String(inst.rid))).duplicate(true)
		cuts.append_array(rc)
		res = inv.runtime_guard(st, repo, cuts)
	if typeof(res) == TYPE_DICTIONARY and not bool(res.get("ok", true)):
		L.i("director", "D1: %s viola %s; variante blanda" % [inst.iid, str(res.get("violated", []))])
		if typeof(rule.get("variante_blanda")) == TYPE_DICTIONARY:
			inst["cuts"] = []
			return true
	return false

static func _runtime_cuts(st, repo, rule: Dictionary, inst: Dictionary) -> Array:
	var out: Array = []
	var tk := int(inst.get("due_tk", 0))
	var from_idx := TimeKey.idx_at_or_after(tk)
	var last := TimeKey.idx_count() - 1
	for c in RDB._as_arr(rule.get("corta", [])):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		# los filtros de efecto (si_n, si_canal, si_cond) valen también para corta[] (HB4: sólo la 2.ª cierra)
		if not RDB.effect_applies(st, repo, c, inst):
			continue
		var to_idx := last
		var ven = c.get("ventana", {})
		if typeof(ven) == TYPE_DICTIONARY and ven.has("dias") and ven.dias != null:
			to_idx = TimeKey.idx_at_or_after(TimeKey.tk(TimeKey.day_of(tk) + int(ven.dias), "dawn")) - 1
		if String(c.get("copias", "")) == "informadas":
			for cp in RDB._as_arr(inst.get("anchor", {}).get("copies", [])):
				out.append({"target": {"copy": String(cp)}, "from_idx": from_idx, "to_idx": to_idx})
		elif c.has("copy"):
			out.append({"target": {"copy": String(c.copy)}, "from_idx": from_idx, "to_idx": to_idx})
		elif c.has("acceso"):
			var acc := String(c.acceso).replace("canal:*", "canal:" + String(inst.get("channel", "")))
			out.append({"target": {"access": acc}, "from_idx": from_idx, "to_idx": to_idx})
	return out

static func _deliver(st, repo, inst: Dictionary, tk: int) -> void:
	var rule: Dictionary = repo.reaction(String(inst.rid))
	var day := TimeKey.day_of(tk)
	inst["strong"] = RDB.is_strong(rule, day) and not bool(inst.get("overflow", false))
	var soft := _d1(st, repo, rule, inst)
	inst["tono"] = HolmesAgent.tone(st)
	inst["vars"] = RDB.vars_for(st, repo, rule, inst)
	inst["delivered_tk"] = tk
	Effects.apply(st, repo, inst, soft)
	if String(inst.get("merged_into", "")) != "":
		var head := Effects.find(st, String(inst.merged_into))
		inst["view"] = String(head.get("view", inst.merged_into))
	var q: Array = st.react.queue
	for i in range(q.size() - 1, -1, -1):
		if String(q[i].iid) == String(inst.iid):
			q.remove_at(i)
	st.react.delivered.append(inst)
	var ch := String(inst.get("channel", ""))
	if RDB.CHANNELS.has(ch) and not st.react.channels_seen.has(ch) and not bool(inst.get("overflow", false)):
		st.react.channels_seen[ch] = day
	if inst.strong:
		st.react.strong_days[str(day)] = true
	var k := "delivered." + String(inst.rid)
	st.react.counters[k] = int(st.react.counters.get(k, 0)) + 1
	HolmesAgent.on_delivered(st, repo, inst)
	_chain(st, repo, inst, tk)

# Evento interno «reaccion»: lo que los agentes ven de una entrega (HB9 ← M3, HB10 ← M1, M11 ← columna «—S.»).
static func _chain(st, repo, inst: Dictionary, tk: int) -> void:
	if _depth >= MAX_CHAIN:
		L.w("director", "cadena de reacciones demasiado larga en %s" % inst.iid)
		return
	var day := TimeKey.day_of(tk)
	var a: Dictionary = inst.get("anchor", {})
	var rev := {"type": "reaccion", "rid": String(inst.rid), "iid": String(inst.iid), "voice": String(inst.voice), "lado": String(inst.lado),
		"channel": String(inst.get("channel", "")), "how": String(inst.get("how", "")), "soft": bool(inst.get("soft", false)),
		"reply_to_ad": String(a.get("type", "")) == "ad", "copies": RDB._as_arr(inst.get("withdrawn", a.get("copies", []))).duplicate(),
		"tk": tk, "day": day, "seq": 0, "act": String(a.get("act", "")), "overflow": bool(inst.get("overflow", false))}
	var obs := {"channel": "K-S" if day >= 3 else "", "sensor": "calle", "to_holmes": true, "to_mycroft": true, "content": rev.duplicate(true)}
	_depth += 1
	var cands: Array = []
	cands.append_array(HolmesAgent.observe(st, repo, obs, rev))
	cands.append_array(MoranAgent.observe(st, repo, rev, {}))
	_enqueue_all(st, repo, cands, tk)
	_depth -= 1

# ---------------- inactividad (HB13) ----------------
static func _mark_act(st, tk: int) -> void:
	var ia: Dictionary = st.react.inactivity
	ia.slots = 0
	var acts: Array = ia.get("acts", [])
	if not acts.has(tk):
		acts.append(tk)
	while acts.size() > 8:
		acts.remove_at(0)
	ia["acts"] = acts

static func _inactivity_step(st, repo, tk: int) -> void:
	var ia: Dictionary = st.react.inactivity
	var checked := int(ia.get("checked_tk", -1))
	for i in TimeKey.idx_count():
		var f := TimeKey.from_idx(i)
		var stk := TimeKey.tk(int(f.day), String(f.slot))
		if stk <= checked or stk >= tk:
			continue
		ia.checked_tk = stk
		if int(f.day) < 1 or int(f.day) > 9:
			continue
		if RDB._as_arr(ia.get("acts", [])).has(stk):
			ia.slots = 0
		else:
			ia.slots = int(ia.slots) + 1

static func _hb13(st, repo, tk: int) -> void:
	var day := TimeKey.day_of(tk)
	var ia: Dictionary = st.react.inactivity
	if day < 1 or day > 9 or int(ia.slots) < 2:
		return
	var ev := {"type": "inactividad", "tk": tk, "day": day, "slot": "night", "seq": 0, "act": "", "slots": int(ia.slots)}
	var obs := {"channel": "", "sensor": "director", "to_holmes": true, "to_mycroft": true, "content": {"slots": int(ia.slots)}}
	ia.slots = 0
	_enqueue_all(st, repo, HolmesAgent.observe(st, repo, obs, ev), tk)
