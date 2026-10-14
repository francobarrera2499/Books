# core/sim/clock.gd — calendario, fases y horarios (§3.2). Dueño: CORE-EXPEDIENTE. Contrato: ARCHITECTURE §3.8.
# v3 (GDD_v3 §5.4): cada salida es pieza -> lugar -> pieza: `go` desde una visita (o la tienda) responde «desde_casa»;
#   `leave` siempre vuelve a la buhardilla y avisa a Director.on_leave(st, repo, visit_id) (latencia «intrusion», §4.2).
# st.clock = {day, slot, phase, outing_done, ads_by_day:{"<día>": {ad, pub_day, form, text}}, d10:{},
#             scene:"" (escena fija en curso), deferred:[{tk, ev}] (eventos públicos a emitir al cruzar tk),
#             reports_done:{"<n>": true}, errata_decided: bool}
# slot ∈ dawn|M|T|N|night: "dawn" sólo durante una escena fija del amanecer (M6); "night" = 22 h (fase night, escena M7,
# night_choice usa N). tk actual = TimeKey.tk(day, slot).
# Fases y salidas (§3.2): prologue -sleep-> día 1 · desk -go-> visit -leave-> desk · desk -end_slot-> franja siguiente o
# night (o escena fija a las 22 h) · night -sleep-> día siguiente (desk M; día 6 desk T; escena fija al amanecer; día
# `fixed` -> confront) · confront -(hecha)-> final_report -report_submit-> parklane -leave-> night_choice
# -night_choice-> epilogue -leave-> done.
# Escena fija = entrada de schedule.column en ese tk cuyo `r` es una escena de data/scenes con place L1 y sin auto.
# Errores esperados: {"ok": false, "err": código} sin mutar (GameSim restaura igual ante cualquier ok:false).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Det = preload("res://core/util/det.gd")
const Cond = preload("res://core/util/cond.gd")
const L = preload("res://core/util/log.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const Diary = preload("res://core/sim/diary.gd")
const Tutorial = preload("res://core/sim/tutorial.gd")
const Confrontation = preload("res://core/scenes/confrontation.gd")
const Composers = preload("res://core/scenes/composers.gd")
const Reveal = preload("res://core/sim/reveal.gd")

const HOME := "L1"
const SEAT_MAX := 999
# Flags de §3.9 que cierran un área hasta un día INCLUSIVE (Effects escribe día del acto + días; Dialogue reabre al
# día siguiente que no sea domingo).
const CLOSE_UNTIL_FLAGS := {"L4.consulta": "consulta_cerrada_hasta"}
# Flags de §3.9 que cierran un área mientras sean verdaderos.
const CLOSE_FLAGS := {"L5.forasteros": "forasteros_cerrada"}
const NIGHT_CHOICES := ["baker_street", "casa"]
const EPILOGUE_SCENE := "EPI"
const DIRECTOR := "res://core/react/director.gd"   # sin preload: sim no depende de react en tiempo de carga   # scenes/EPI.json (W3-CT-DLG-B): se dice al entrar al epílogo

static func init_state(st, repo) -> void:
	st.clock = {"day": TimeKey.DAY_P, "slot": "N", "phase": "prologue", "outing_done": false,
		"ads_by_day": {}, "d10": {}, "scene": "", "deferred": [], "reports_done": {}, "errata_decided": false}
	st.flags["noche_final"] = ""
	st.flags["publica_errata"] = false

# ---------------- consultas de tiempo ----------------
static func cur_tk(st) -> int:
	return tk_of(st.clock)

static func tk_of(c: Dictionary) -> int:
	if c.is_empty():
		return -1
	return TimeKey.tk(int(c.get("day", 0)), String(c.get("slot", "N")))

static func day_info(repo, day: int) -> Dictionary:
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == day:
			return d
	return {}

static func day_slots(repo, day: int) -> Array:
	return day_info(repo, day).get("slots", [])

static func is_fixed_day(repo, day: int) -> bool:
	return bool(day_info(repo, day).get("fixed", false))

static func last_day(repo) -> int:
	var m := 0
	for d in repo.schedule().get("days", []):
		if (d.get("slots", []) as Array).size() > 0:
			m = maxi(m, int(d.day))
	return m

# Franjas cruzadas al pasar del reloj `before` al `after`: tks t con before < t <= after (dawn y night siempre;
# M/T/N sólo si son franjas jugables, §3.2). Orden creciente.
static func crossed_tks(before: Dictionary, after: Dictionary) -> Array:
	var b := tk_of(before)
	var a := tk_of(after)
	var out: Array = []
	if a <= b:
		return out
	for t in range(b + 1, a + 1):
		var s := TimeKey.slot_of(t)
		if s == "dawn" or s == "night" or TimeKey.idx(TimeKey.day_of(t), s) >= 0:
			out.append(t)
	return out

# ---------------- lugares ----------------
static func areas_of(repo, place: String) -> Array:
	var sp = repo.schedule().get("places", {}).get(place, {})
	if typeof(sp) != TYPE_DICTIONARY:
		return []
	var ks: Array = sp.get("areas", {}).keys()
	ks.sort()
	return ks

static func area_spec(repo, place: String, area: String) -> Dictionary:
	var sp = repo.schedule().get("places", {}).get(place, {})
	if typeof(sp) != TYPE_DICTIONARY:
		return {}
	var a = sp.get("areas", {}).get(area, {})
	return a if typeof(a) == TYPE_DICTIONARY else {}

static func is_free(repo, place: String, area: String) -> bool:
	return bool(area_spec(repo, place, area).get("free", false))

# Destinos del mapa: todo (lugar, área) con horario, salvo el hogar (L1 que no sea `free`).
static func destinations(repo) -> Array:
	var out: Array = []
	var ps: Array = repo.schedule().get("places", {}).keys()
	ps.sort()
	for p in ps:
		for a in areas_of(repo, p):
			if p == HOME and not is_free(repo, p, a):
				continue
			out.append({"place": p, "area": a})
	return out

static func _window_ok(w: Dictionary, day: int, slot: String) -> bool:
	var days = w.get("days", "all")
	if typeof(days) == TYPE_ARRAY:
		var hit := false
		for d in days:
			if int(d) == day:
				hit = true
		if not hit:
			return false
	elif String(days) != "all":
		return false
	var slots = w.get("slots", "all")
	if typeof(slots) == TYPE_ARRAY:
		if not slots.has(slot):
			return false
	elif String(slots) != "all":
		return false
	var t := TimeKey.tk(day, slot)
	if w.has("from") and t < TimeKey.of(w.from):
		return false
	if w.has("to") and t > TimeKey.of(w.to):
		return false
	return true

# {open, reason}. reason ∈ "" | "sin_horario" | "desconocido" (todavía no está en el mapa, GDD_v2 §B.4) | "dia" (no hay
# franja ese día) | "horario" | "needs" | "cerrado" | "orden".
static func place_open(repo, st, place: String, area: String, day: int, slot: String) -> Dictionary:
	var sp = area_spec(repo, place, area)
	if sp.is_empty():
		return {"open": false, "reason": "sin_horario"}
	if st != null and not Reveal.place_known(st, repo, place):
		return {"open": false, "reason": "desconocido"}
	if not day_slots(repo, day).has(slot):
		return {"open": false, "reason": "dia"}
	var ok := false
	for w in sp.get("open", []):
		if typeof(w) == TYPE_DICTIONARY and _window_ok(w, day, slot):
			ok = true
			break
	if not ok:
		return {"open": false, "reason": "horario"}
	if st != null:
		var t := TimeKey.tk(day, slot)
		if sp.has("needs") and not Cond.eval(sp.needs, {"st": st, "repo": repo, "tk": t}):
			return {"open": false, "reason": "needs"}
		var key := place + "." + area
		if CLOSE_UNTIL_FLAGS.has(key):
			var v = st.flags.get(CLOSE_UNTIL_FLAGS[key], 0)
			if typeof(v) in [TYPE_INT, TYPE_FLOAT] and int(v) > 0 and day <= int(v):
				return {"open": false, "reason": "orden"}
		if CLOSE_FLAGS.has(key) and _truthy(st.flags.get(CLOSE_FLAGS[key])):
			return {"open": false, "reason": "orden"}
		if WorldModel.closed(st, place, area, t):
			return {"open": false, "reason": "cerrado"}
	return {"open": true, "reason": ""}

static func default_area(repo, st, place: String, day: int, slot: String) -> String:
	var areas := areas_of(repo, place)
	for a in areas:
		if place == HOME and not is_free(repo, place, a):
			continue
		if place_open(repo, st, place, a, day, slot).open:
			return a
	for a in areas:
		if not (place == HOME and not is_free(repo, place, a)):
			return a
	return ""

static func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING: return String(v) != ""
	return true

# ---------------- informes, anuncios (v3: sin pasadas por franja; se pasa en limpio de a una, sin límite) ----------------
# Informe que corresponde ahora (fase night en su tk, o final_report): {n, tk, final} o {}.
static func report_now(st, repo) -> Dictionary:
	var c: Dictionary = st.clock
	var ph := String(c.get("phase", ""))
	if ph != "night" and ph != "final_report":
		return {}
	var t := TimeKey.tk(int(c.day), "night" if ph == "night" else String(c.slot))
	for r in repo.schedule().get("reports", []):
		var final := bool(r.get("final", false))
		if (ph == "final_report") != final:
			continue
		if TimeKey.of(r.get("tk", "")) == t or (final and int(TimeKey.day_of(TimeKey.of(r.get("tk", "")))) == int(c.day)):
			return {"n": int(r.get("n", 0)), "tk": TimeKey.of(r.get("tk", "")), "final": final}
	return {}

static func report_done(st, n: int) -> bool:
	return bool(st.clock.get("reports_done", {}).get(str(n), false))

static func report_due(st, repo) -> Dictionary:
	var r := report_now(st, repo)
	if r.is_empty() or report_done(st, int(r.n)):
		return {}
	return r

# Día de publicación de un aviso redactado el día `day` (prólogo -> ads.prologue_pub_day; si no, el siguiente día con Times).
static func ad_pub_day(repo, day: int) -> int:
	var ads: Dictionary = repo.schedule().get("ads", {})
	if day == TimeKey.DAY_P:
		return int(ads.get("prologue_pub_day", 1))
	var days: Array = repo.schedule().get("days", [])
	var best := -1
	for d in days:
		var dd := int(d.get("day", -1))
		if dd > day and bool(d.get("times", false)) and (best < 0 or dd < best):
			best = dd
	return best

# "" si se puede redactar un aviso ahora; si no "oficina_cerrada" | "uno_por_dia".
static func ad_error(st, repo) -> String:
	var c: Dictionary = st.clock
	var ads: Dictionary = repo.schedule().get("ads", {})
	if String(c.phase) == "desk":
		if not (ads.get("office_slots", ["M", "T"]) as Array).has(String(c.slot)):
			return "oficina_cerrada"
	elif String(c.phase) != "prologue":
		return "oficina_cerrada"
	var per_day := int(ads.get("per_day", 1))
	var n := 0
	if c.get("ads_by_day", {}).has(str(int(c.day))):
		n = 1
	if n >= per_day:
		return "uno_por_dia"
	if ad_pub_day(repo, int(c.day)) < 0:
		return "oficina_cerrada"
	return ""

# Hora legible del acto (anclas de K-S/K-BM): comienzo de la franja + minutos sembrados (D7).
static func hour_of(st, repo, day: int, slot: String, salt: String, extra_min := 0) -> String:
	var h0: int = {"M": 9, "T": 13, "N": 18}.get(slot, 22)
	var sh = repo.schedule().get("slot_hours", {}).get(slot, "")
	if typeof(sh) == TYPE_STRING and sh != "":
		var digits := ""
		for ch in String(sh):
			if ch >= "0" and ch <= "9":
				digits += ch
			else:
				break
		if digits != "":
			h0 = digits.to_int()
	var mins: int = Det.pick(int(st.seed), ["hora", day, slot, salt], [30, 45, 60, 75, 90, 105]) + extra_min
	var h: int = h0 + int(mins / 60)
	return "%d:%02d" % [h, mins % 60]

# ---------------- escenas fijas ----------------
static func column_scenes(repo, t: int) -> Array:
	var out: Array = []
	for e in repo.schedule().get("column", []):
		if TimeKey.of(e.get("tk", "")) != t:
			continue
		var sid := String(e.get("r", ""))
		var sc: Dictionary = repo.scene(sid)
		if not sc.is_empty() and not out.has(sid):
			out.append(sid)
	return out

static func fixed_scene(st, repo, t: int) -> String:
	for sid in column_scenes(repo, t):
		var sc: Dictionary = repo.scene(sid)
		if bool(sc.get("auto", false)) or String(sc.get("place", "")) != HOME:
			continue
		if sc.has("when") and not Cond.eval(sc.when, {"st": st, "repo": repo, "tk": t}):
			continue
		return sid
	return ""

# ---------------- acciones ----------------
static func act_go(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	if String(c.get("phase", "")) != "desk":
		return {"ok": false, "err": "desde_casa"}
	var place := String(a.get("place", ""))
	var day := int(c.day)
	var slot := String(c.slot)
	if place == "" or areas_of(repo, place).is_empty():
		return {"ok": false, "err": "cerrado", "reason": "sin_horario"}
	var area := String(a.get("area", ""))
	if area == "":
		area = default_area(repo, st, place, day, slot)
	if not areas_of(repo, place).has(area):
		return {"ok": false, "err": "cerrado", "reason": "sin_horario"}
	var free := is_free(repo, place, area)
	if place == HOME and not free:
		return {"ok": false, "err": "cerrado", "reason": "hogar"}
	var op := place_open(repo, st, place, area, day, slot)
	if not op.open:
		return {"ok": false, "err": "cerrado", "reason": op.reason}
	if not free and bool(c.outing_done):
		return {"ok": false, "err": "ya_salio"}
	var seat := int(a.get("seat", 0))
	var needs_seat := WorldModel.place_needs_seat(repo, place)
	if needs_seat and (seat < 1 or seat > SEAT_MAX):
		return {"ok": false, "err": "asiento"}
	var hour := hour_of(st, repo, day, slot, place)
	var act := ""
	if not free:
		c.outing_done = true
		var pl: Dictionary = repo.place(place)
		var ev := {"type": "go", "place": place, "area": area, "streets": (pl.get("streets", []) as Array).duplicate(), "hour": hour}
		if needs_seat:
			ev["seat"] = seat
		st.push_event(ev)
		act = st.pending_act()
		ev["act"] = act
		var money: Dictionary = repo.schedule().get("money_d", {})
		var lo := int(money.get("cab_min", 12))
		var hi := maxi(lo, int(money.get("cab_max", 24)))
		WorldModel.add_coins(st, -(lo + Det.h32([int(st.seed), "coche", day, slot]) % (hi - lo + 1)))
	if needs_seat:
		st.world["seat"] = seat
	if free:
		# acto ciego (GDD§7.4): sin evento público; línea del diario sólo si lists.diary tiene go.<lugar>.<área>
		Diary.on_private(st, repo, "go.%s.%s" % [place, area], {"lugar": Diary.place_name(repo, place)}, TimeKey.tk(day, slot))
	var visit := WorldModel.start_visit(st, repo, place, area, {"act": act, "hour": hour, "seat": seat if needs_seat else 0, "free": free})
	c.phase = "visit"
	st.note("clock", {})
	return {"ok": true, "visit": visit.get("id", ""), "plate": visit.get("plate", "")}

static func act_leave(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	match String(c.phase):
		"visit":
			var vid := String(st.world.get("visit", {}).get("id", ""))
			WorldModel.end_visit(st)
			c.phase = "desk"
			var dir = load(DIRECTOR)
			if dir != null and dir.has_method("on_leave"):
				dir.call("on_leave", st, repo, vid)
		"scene":
			WorldModel.end_visit(st)
			c.scene = ""
			if String(c.slot) == "night":
				c.phase = "night"
			else:
				var slots := day_slots(repo, int(c.day))
				c.slot = slots[0] if slots.size() > 0 else "M"
				c.phase = "desk"
		"parklane":
			WorldModel.end_visit(st)
			c.slot = "N"
			c.phase = "night_choice"
		"epilogue":
			WorldModel.end_visit(st)
			c.phase = "done"
		_:
			return {"ok": false, "err": "fase"}
	st.note("clock", {})
	return {"ok": true, "phase": c.phase}

static func act_end_slot(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	if String(c.phase) != "desk":
		return {"ok": false, "err": "fase"}
	if not report_due(st, repo).is_empty():
		return {"ok": false, "err": "informe_pendiente"}
	var day := int(c.day)
	var t := cur_tk(st)
	if not bool(c.outing_done):
		Diary.on_private(st, repo, "stay", {}, t)
	# telegramas y cartas pendientes salen al cerrar la franja
	if not st.handlers.has("compose_telegram") and not st.handlers.has("compose_letter"):
		Composers.on_end_slot(st, repo)
	var outbox: Array = st.world.get("outbox", [])
	for ev in outbox:
		var e: Dictionary = ev.duplicate(true)
		e["tk"] = t
		st.push_event(e)
	st.world["outbox"] = []
	c.outing_done = false
	var slots := day_slots(repo, day)
	var i := slots.find(String(c.slot))
	if i >= 0 and i + 1 < slots.size():
		c.slot = slots[i + 1]
		c.phase = "desk"
	else:
		c.slot = "night"
		var sid := fixed_scene(st, repo, TimeKey.tk(day, "night"))
		if sid != "":
			c.phase = "scene"
			c.scene = sid
			WorldModel.start_scene(st, repo, sid)
		else:
			c.phase = "night"
	st.note("clock", {})
	return {"ok": true, "clock": c.duplicate(true)}

static func act_sleep(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	match String(c.phase):
		"prologue":
			if not Tutorial.complete(st):
				return {"ok": false, "err": "tutorial"}
		"night":
			if not report_due(st, repo).is_empty():
				return {"ok": false, "err": "informe_pendiente"}
		_:
			return {"ok": false, "err": "fase"}
	var nd := int(c.day) + 1
	if day_slots(repo, nd).is_empty():
		return {"ok": false, "err": "fase"}
	enter_day(st, repo, nd)
	return {"ok": true, "clock": c.duplicate(true), "arrivals": 0}

# Abre el día nd: día fijo -> confront; escena fija al amanecer -> scene (slot dawn); si no, desk en la primera franja.
static func enter_day(st, repo, nd: int) -> void:
	var c: Dictionary = st.clock
	WorldModel.end_visit(st)
	c.day = nd
	c.outing_done = false
	c.scene = ""
	var slots := day_slots(repo, nd)
	var first: String = slots[0] if slots.size() > 0 else "M"
	if is_fixed_day(repo, nd):
		c.slot = first
		c.phase = "confront"
		# primero la escena (Crane llama a Lisle, entra el anciano), después la primera afirmación: así se leen en la
		# transcripción (W4: la afirmación I quedaba antes de que el anciano entrara)
		_say_column(st, repo, TimeKey.tk(nd, first))
		Confrontation.start(st, repo)
	else:
		var sid := fixed_scene(st, repo, TimeKey.tk(nd, "dawn"))
		if sid != "":
			c.slot = "dawn"
			c.phase = "scene"
			c.scene = sid
			WorldModel.start_scene(st, repo, sid)
		else:
			c.slot = first
			c.phase = "desk"
	st.note("clock", {})

# Escenas de columna de un tk del día fijo (HC07 a las 9:30, HC08 en Park Lane, HC09 a la noche): se dicen al entrar.
static func _say_column(st, repo, t: int) -> void:
	var ids := column_scenes(repo, t)
	if ids.is_empty():
		return
	WorldModel.start_scene(st, repo, ids[0])
	for k in range(1, ids.size()):
		WorldModel.say_scene_lines(st, repo, ids[k])

# Confrontación terminada (Confrontation devolvió done): pasa al informe final.
static func on_confront_done(st, repo) -> void:
	var c: Dictionary = st.clock
	if String(c.phase) != "confront":
		return
	WorldModel.end_visit(st)
	c.phase = "final_report"
	c.d10["confront_done"] = true
	st.note("clock", {})

# Informe entregado. El final lleva a Park Lane (18 h).
static func on_report_submitted(st, repo, n: int, final: bool) -> void:
	var c: Dictionary = st.clock
	c.reports_done[str(n)] = true
	st.note("report", {"n": n})
	if final and String(c.phase) == "final_report":
		c.d10["final_done"] = true
		var slots := day_slots(repo, int(c.day))
		c.slot = "T" if slots.has("T") else String(slots[-1] if slots.size() > 0 else "T")
		c.phase = "parklane"
		_say_column(st, repo, TimeKey.tk(int(c.day), String(c.slot)))
		st.note("clock", {})

static func act_night_choice(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	if String(c.phase) != "night_choice":
		return {"ok": false, "err": "fase"}
	var where := String(a.get("where", ""))
	if not NIGHT_CHOICES.has(where):
		return {"ok": false, "err": "forma"}
	st.flags["noche_final"] = where
	st.note("flag", {"name": "noche_final"})
	# la noche (HC09) se dice con la elección ya hecha (variantes por flag)
	WorldModel.end_visit(st)
	for sid in column_scenes(repo, TimeKey.tk(int(c.day), "N")):
		WorldModel.say_scene_lines(st, repo, sid)
	c.day = TimeKey.DAY_E
	c.slot = "dawn"
	c.phase = "epilogue"
	if not repo.scene(EPILOGUE_SCENE).is_empty():
		WorldModel.start_scene(st, repo, EPILOGUE_SCENE)
	st.note("clock", {})
	return {"ok": true}

static func act_publish_errata(st, repo, a) -> Dictionary:
	var c: Dictionary = st.clock
	if String(c.phase) != "epilogue":
		return {"ok": false, "err": "fase"}
	if bool(c.get("errata_decided", false)):
		return {"ok": false, "err": "ya_decidido"}
	c.errata_decided = true
	st.flags["publica_errata"] = bool(a.get("yes", false))
	st.note("flag", {"name": "publica_errata"})
	return {"ok": true}
