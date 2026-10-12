# Arnés de W2-REACT: maneja el Director como lo haría GameSim (§3.4 pasos 5–6) sin depender de W2-SIM.
# - Eventos públicos numerados (seq, tk, day, slot, act "act.<seq>") agregados a st.events y despachados.
# - Línea de tiempo: P.N, P.night, y por día dawn → franjas de schedule → night. Un evento en dawn (aviso publicado)
#   se procesa ANTES de on_time(dawn), como cuando lo emite `sleep`; un evento en franja, DESPUÉS de on_time(franja).
# - Effects.sink = Sink: registra documentos y entregas (WorldModel queda fuera de la prueba).
extends RefCounted

const GameState = preload("res://core/sim/game_state.gd")
const Director = preload("res://core/react/director.gd")
const Effects = preload("res://core/react/effects.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")

class Sink:
	var docs := {}
	var deliveries: Array = []
	var returns: Array = []
	func instantiate_doc(st, repo, tpl: Dictionary, vars: Dictionary, meta: Dictionary) -> String:
		docs[String(meta.iid)] = {"tpl": tpl.duplicate(true), "vars": vars.duplicate(true), "meta": meta.duplicate(true)}
		return String(meta.iid)
	func deliver(st, repo, view: String, how: String) -> void:
		# como WorldModel.deliver: sólo instancias runtime creadas con instantiate_doc
		if not docs.has(view):
			push_error("Sink.deliver de una instancia inexistente: " + view)
		deliveries.append({"view": view, "how": how, "day": int(st.clock.get("day", -1)), "slot": String(st.clock.get("slot", ""))})
	func return_copy(st, copy_id: String) -> void:
		returns.append({"copy": copy_id, "day": int(st.clock.get("day", -1)), "slot": String(st.clock.get("slot", ""))})

var st
var repo
var sink: Sink
var seq := 0
var now := -1
var tl: Array = []

func _init(p_repo, p_seed := 7) -> void:
	repo = p_repo
	st = GameState.new()
	st.seed = p_seed
	st.clock = {"day": 0, "slot": "N", "phase": "prologue"}
	st.world = {"visits": []}
	st.ded = {"clips": {}, "entries": {}, "sealed": {}}
	sink = Sink.new()
	Effects.sink = sink
	# D1 aislado de W2-GRAPH: por defecto la guardia no viola (los tests de D1 ponen su propio hook)
	Director.guard_hook = func(_st, _repo, _rid, _cuts): return {"ok": true, "violated": []}
	Director.init_state(st, repo)
	tl = timeline(repo)

static func timeline(r) -> Array:
	var out: Array = [TimeKey.tk(0, "N"), TimeKey.tk(0, "night")]
	for d in range(1, 11):
		out.append(TimeKey.tk(d, "dawn"))
		var slots: Array = ["M", "T", "N"]
		for row in r.schedule().get("days", []):
			if int(row.get("day", -1)) == d:
				slots = row.get("slots", slots)
		for s in slots:
			out.append(TimeKey.tk(d, String(s)))
		out.append(TimeKey.tk(d, "night"))
	return out

func _set_clock(t: int) -> void:
	var s := TimeKey.slot_of(t)
	st.clock.day = TimeKey.day_of(t)
	st.clock.slot = s
	st.clock.phase = "night" if s == "night" else ("prologue" if TimeKey.day_of(t) == 0 else "desk")

# Avanza llamando on_time en cada tk de la línea de tiempo hasta t (inclusive).
func advance_to(t) -> void:
	var target := TimeKey.of(t)
	for k in tl:
		if k <= now:
			continue
		if k > target:
			break
		now = k
		_set_clock(k)
		Director.on_time(st, repo, k)

# Evento público en su tk (ver encabezado sobre dawn).
func ev(type: String, fields := {}, t = null) -> Dictionary:
	var tk := TimeKey.of(t) if t != null else now
	if TimeKey.slot_of(tk) == "dawn":
		advance_to(tk - 1)
	else:
		advance_to(tk)
	_set_clock(tk)
	seq += 1
	var e := {"seq": seq, "tk": tk, "day": TimeKey.day_of(tk), "slot": TimeKey.slot_of(tk), "type": type, "act": "act.%d" % seq}
	for k in fields:
		e[k] = fields[k]
	st.events.append(e)
	if type == "go":
		st.world.visits.append({"place": String(fields.get("place", "")), "tk": tk})
	Director.on_public_event(st, repo, e)
	return e

# Guion: [{tk, type, …campos}] (JSONL de tests/fixtures/react). Termina en `until`.
func play(script: Array, until = "10.night") -> void:
	for line in script:
		var f: Dictionary = line.duplicate()
		var t = f.get("tk")
		var ty := String(f.get("type", ""))
		f.erase("tk")
		f.erase("type")
		ev(ty, f, t)
	advance_to(until)

static func load_jsonl(path: String) -> Array:
	var out: Array = []
	var txt := FileAccess.get_file_as_string(path)
	for ln in txt.split("\n"):
		var s := ln.strip_edges()
		if s == "" or s.begins_with("#") or s.begins_with("//"):
			continue
		var v = J.parse_str(s)
		if typeof(v) == TYPE_DICTIONARY:
			out.append(v)
	return out

func delivered() -> Array:
	return st.react.delivered

func ids() -> Array:
	var out: Array = []
	for i in st.react.delivered:
		out.append(String(i.rid))
	return out

func find(rid: String) -> Array:
	var out: Array = []
	for i in st.react.delivered:
		if String(i.rid) == rid:
			out.append(i)
	return out

func first(rid: String) -> Dictionary:
	var f := find(rid)
	return f[0] if not f.is_empty() else {}

func queued(rid: String) -> Array:
	var out: Array = []
	for i in st.react.queue:
		if String(i.rid) == rid:
			out.append(i)
	return out

func day_of_delivery(rid: String) -> int:
	var f := first(rid)
	return TimeKey.day_of(int(f.get("delivered_tk", -10))) if not f.is_empty() else -1

func text(rid: String) -> String:
	return String(first(rid).get("text", ""))

# Instantánea comparable de lo entregado (T8): iid, rid, día, cómo, texto, flags.
func signature() -> String:
	var rows: Array = []
	for i in st.react.delivered:
		rows.append([String(i.iid), String(i.rid), int(i.get("delivered_tk", -1)), String(i.get("how", "")), String(i.get("text", "")), bool(i.get("soft", false)), RDBs(i.get("applied", []))])
	return J.stringify_canon({"rows": rows, "flags": st.flags, "queue": st.react.queue, "world": st.react.world})

static func RDBs(a) -> String:
	return str(a)

static func cleanup() -> void:
	Effects.sink = null
	Director.guard_hook = null
