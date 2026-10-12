# core/sim/game_sim.gd — la única puerta de la simulación (§3.1, §3.4, §3.7). Dueño: W2-SIM. Contrato: ARCHITECTURE §3.8.
# apply(a): 1 Actions.normalize + shape_error · 2 fase permitida · 3 Tutorial.allowed · 4 PlayerActions.dispatch
#   (ok:false -> se restaura el estado previo: nada muta ni se registra) · 5 numerar st.pending_events -> st.events y,
#   por cada uno, Diary.on_event + Director.on_public_event; líneas automáticas de la visita · 6 por cada tk cruzado
#   (Clock.crossed_tks): eventos diferidos de ese tk (anuncios al amanecer de su publicación), llegadas estáticas,
#   Director.on_time(tk) · 7 registro de la acción; changed(kind, payload) por cada st.notes; se vacían.
# Nunca emite "reaction" (no existe registro de reacciones).
# Costura de tests: _init/replay aceptan `handlers` (t -> Callable) que reemplazan manejadores de OTROS paquetes.
extends RefCounted

signal changed(kind: String, payload: Dictionary)

const SELF := "res://core/sim/game_sim.gd"
const J = preload("res://core/util/j.gd")
const L = preload("res://core/util/log.gd")
const Det = preload("res://core/util/det.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const GameState = preload("res://core/sim/game_state.gd")
const Actions = preload("res://core/sim/actions.gd")
const PlayerActions = preload("res://core/sim/player_actions.gd")
const Clock = preload("res://core/sim/clock.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const Diary = preload("res://core/sim/diary.gd")
const Tutorial = preload("res://core/sim/tutorial.gd")
const Endings = preload("res://core/sim/endings.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const Ledger = preload("res://core/deduction/ledger.gd")
const Validator = preload("res://core/deduction/validator.gd")
const Director = preload("res://core/react/director.gd")
const HolmesAgent = preload("res://core/react/holmes_agent.gd")
const MoranAgent = preload("res://core/react/moran_agent.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Confrontation = preload("res://core/scenes/confrontation.gd")
const Composers = preload("res://core/scenes/composers.gd")

const MAX_EVENT_ROUNDS := 32
# Manejadores propios que validan todo antes de mutar (no necesitan la copia de seguridad del estado).
const VALIDATE_FIRST := ["go", "leave", "end_slot", "sleep", "night_choice", "publish_errata", "slip", "order_copy"]

var repo        # DataRepo
var st          # GameState
var replay_errors := 0
var _log: Array = []

func _init(p_repo, p_seed: int, handlers := {}) -> void:
	repo = p_repo
	st = GameState.new()
	st.seed = p_seed
	st.handlers = handlers
	Clock.init_state(st, repo)
	WorldModel.init_state(st, repo)
	Tutorial.init_state(st, repo)
	Clipper.init_state(st, repo)
	Ledger.init_state(st, repo)
	HolmesAgent.init_state(st, repo)
	MoranAgent.init_state(st, repo)
	Director.init_state(st, repo)
	Dialogue.init_state(st, repo)
	Confrontation.init_state(st, repo)
	WorldModel.start_prologue(st, repo)
	WorldModel.sync_scene_lines(st, repo)
	_say_tutorial_line()
	st.pending_events.clear()
	st.notes.clear()

static func replay(p_repo, p_seed: int, actions: Array, handlers := {}):
	var s = load(SELF).new(p_repo, p_seed, handlers)
	for a in actions:
		var r: Dictionary = s.apply(a)
		if not r.get("ok", false):
			s.replay_errors += 1
			L.bug("sim", "replay: acción rechazada (registro corrupto o de otra versión): %s -> %s" % [J.stringify_canon(a), r.get("err", "")])
	return s

func apply(a: Dictionary) -> Dictionary:
	return _apply(a, true)

func can(a: Dictionary) -> Dictionary:
	var saved = st
	st = st.clone()
	var r := _apply(a, false)
	st = saved
	return {"ok": bool(r.get("ok", false)), "err": String(r.get("err", ""))}

func actions_log() -> Array:
	return _log.duplicate(true)

func canon() -> Dictionary:
	return st.canon()

func state_hash() -> String:
	return J.stringify_canon(canon()).md5_text()

func _apply(a: Dictionary, live: bool) -> Dictionary:
	var na := Actions.normalize(a)
	var e := Actions.shape_error(na)
	if e != "":
		return {"ok": false, "err": e}
	var t := String(na.t)
	var phase := String(st.clock.get("phase", ""))
	if phase == "done":
		return {"ok": false, "err": "fin"}
	if not Actions.phases_of(t).has(phase):
		return {"ok": false, "err": "fase"}
	if not Tutorial.allowed(st, na):
		return {"ok": false, "err": "tutorial"}
	var snap: Dictionary = {} if VALIDATE_FIRST.has(t) else st.snapshot()
	var clock_before: Dictionary = st.clock.duplicate(true)
	var step_before := String(Tutorial.step(st).get("id", ""))
	var tray_before := (st.world.get("tray", []) as Array).size()
	st.notes.clear()
	st.pending_events.clear()
	var res := PlayerActions.dispatch(st, repo, na)
	if not bool(res.get("ok", false)):
		if not snap.is_empty():
			st.load_canon(snap)
		st.pending_events.clear()
		st.notes.clear()
		if not res.has("err"):
			res["err"] = "rechazada"
		res["ok"] = false
		return res
	Tutorial.after(st, repo, na, res)
	_flush_events(Clock.tk_of(clock_before))
	WorldModel.sync_scene_lines(st, repo)
	WorldModel.sync_scene_extra(st, repo)
	WorldModel.after_events(st, repo)
	for tk in Clock.crossed_tks(clock_before, st.clock):
		st.now_tk = tk
		WorldModel.arrivals_at(st, repo, tk)
		_emit_deferred(tk)
		if TimeKey.slot_of(tk) == "dawn" and not st.handlers.has("compose_ad"):
			Composers.on_dawn(st, repo, TimeKey.day_of(tk))
		_flush_events(tk)
		Director.on_time(st, repo, tk)
		_flush_events(tk)
		WorldModel.sync_scene_lines(st, repo)
		# escena fija abierta en este mismo tk (M6 al amanecer, M7 a las 22 h): líneas que el director le agregó
		WorldModel.sync_scene_extra(st, repo)
		st.now_tk = -1
	WorldModel.after_events(st, repo)
	WorldModel.sync_scene_lines(st, repo)
	WorldModel.sync_scene_extra(st, repo)
	WorldModel.check_eggs(st, repo)
	var step_after := String(Tutorial.step(st).get("id", ""))
	if step_after != step_before:
		_say_tutorial_line()
	if res.has("arrivals"):
		res["arrivals"] = (st.world.get("tray", []) as Array).size() - tray_before
	if st.clock != clock_before:
		st.note("clock", {})
	if live:
		_log.append(na)
		L.d("sim", "%s ok" % t)
		var seen := {}
		for n in st.notes:
			var key := J.stringify_canon(n)
			if seen.has(key):
				continue
			seen[key] = true
			changed.emit(String(n.kind), n.payload)
	st.notes.clear()
	res["ok"] = true
	return res

func _flush_events(default_tk: int) -> void:
	var rounds := 0
	while not st.pending_events.is_empty():
		rounds += 1
		if rounds > MAX_EVENT_ROUNDS:
			L.bug("sim", "eventos en cascada sin fin")
			st.pending_events.clear()
			return
		var evs: Array = st.pending_events
		st.pending_events = []
		for ev in evs:
			var n := int(st.seq.get("ev", 0)) + 1
			st.seq["ev"] = n
			var act := "act.%d" % n
			if ev.has("act") and String(ev.act) != act:
				L.bug("sim", "act previsto %s != %s" % [ev.act, act])
			ev["seq"] = n
			ev["act"] = act
			if not ev.has("tk"):
				ev["tk"] = default_tk
			ev["day"] = TimeKey.day_of(int(ev.tk))
			ev["slot"] = TimeKey.slot_of(int(ev.tk))
			st.events.append(ev)
			Diary.on_event(st, repo, ev)
			Director.on_public_event(st, repo, ev)
			if String(ev.type) == "ad":
				WorldModel.print_ad(st, repo, ev)

func _emit_deferred(tk: int) -> void:
	var keep: Array = []
	for d in st.clock.get("deferred", []):
		if int(d.get("tk", 0)) <= tk:
			st.push_event(d.ev)
		else:
			keep.append(d)
	st.clock["deferred"] = keep

func _say_tutorial_line() -> void:
	var s := Tutorial.step(st)
	if s.is_empty():
		return
	var lid := String(s.line_id)
	WorldModel.say_scene_line(st, repo, lid.get_slice(".", 0), lid.get_slice(".", 1))

# ---------------- azúcar 1:1 sobre apply (§3.4) ----------------
func clip_text(src: Dictionary, from: int, length: int) -> Dictionary:
	return apply({"t": "clip_text", "src": src, "from": from, "len": length})

func clip_plate(plate: String, hits: Array, touched: Array, area_frac: float) -> Dictionary:
	return apply({"t": "clip_plate", "plate": plate, "hits": hits, "touched": touched, "area_frac": area_frac})

func clip_measure(src: Dictionary) -> Dictionary:
	return apply({"t": "clip_measure", "src": src})

func link(a: String, b: String, note := "") -> Dictionary:
	return apply({"t": "link", "a": a, "b": b, "note": note})

func folio_open(clip: String) -> Dictionary:
	return apply({"t": "folio_open", "clip": clip})

func entry_new(folio: String, template: String) -> Dictionary:
	return apply({"t": "entry_new", "folio": folio, "template": template})

func entry_set(entry: String, line: int, field: String, value: String) -> Dictionary:
	return apply({"t": "entry_set", "entry": entry, "line": line, "field": field, "value": value})

func entry_support_add(entry: String, line: int, item: String) -> Dictionary:
	return apply({"t": "entry_support_add", "entry": entry, "line": line, "item": item})

func pass_clean(entries: Array) -> Dictionary:
	return apply({"t": "pass_clean", "entries": entries})

func go(place: String, area := "", seat := 0) -> Dictionary:
	return apply({"t": "go", "place": place, "area": area, "seat": seat})

func slip(doc: String) -> Dictionary:
	return apply({"t": "slip", "doc": doc})

func ask(char_id: String, topic: String) -> Dictionary:
	return apply({"t": "ask", "char": char_id, "topic": topic})

func assert_claim(char_id: String, assertion: String) -> Dictionary:
	return apply({"t": "assert", "char": char_id, "assertion": assertion})

func present(char_id: String, kind: String, id: String) -> Dictionary:
	return apply({"t": "present", "char": char_id, "item": {"kind": kind, "id": id}})

func leave() -> Dictionary:
	return apply({"t": "leave"})

func end_slot() -> Dictionary:
	return apply({"t": "end_slot"})

func sleep() -> Dictionary:
	return apply({"t": "sleep"})

func compose_ad(form: String, fields: Dictionary) -> Dictionary:
	return apply({"t": "compose_ad", "form": form, "fields": fields})

func report_submit(mode: String, items: Array) -> Dictionary:
	return apply({"t": "report_submit", "mode": mode, "items": items})

func confront(step: int, kind := "", id := "") -> Dictionary:
	return apply({"t": "confront", "step": step, "item": ({} if kind == "" else {"kind": kind, "id": id})})

# ---------------- consultas §3.7 (sólo lectura; devuelven copias) ----------------
func _day_label(day: int) -> String:
	var info := Clock.day_info(repo, day)
	if day == TimeKey.DAY_P:
		return String(info.get("label", repo.text("core.dia.P")))
	if day == TimeKey.DAY_E:
		return String(info.get("label", repo.text("core.dia.E")))
	var date := String(info.get("date", ""))
	if date.length() < 10:
		return String(info.get("label", str(day)))
	return repo.text("core.fecha.dia", {"wd": repo.text("core.wd." + String(info.get("weekday", ""))),
		"d": date.substr(8, 2).to_int(), "mes": repo.text("core.mes." + str(date.substr(5, 2).to_int()))})

func q_clock() -> Dictionary:
	var c: Dictionary = st.clock
	var day := int(c.day)
	var rep := Clock.report_due(st, repo)
	return {"day": day, "slot": String(c.slot), "phase": String(c.phase), "date_label": _day_label(day),
		"weekday": String(Clock.day_info(repo, day).get("weekday", "")), "outing_done": bool(c.outing_done),
		"passes_left": Clock.passes_left(st, repo), "lot_size": int(Validator.lot_size(st, repo)),
		"report_due": not rep.is_empty(), "report_n": int(rep.get("n", 0)), "tk": Clock.cur_tk(st),
		"slot_label": repo.text("core.slot." + String(c.slot)), "scene": String(c.get("scene", "")),
		"coins_d": int(st.world.get("coins_d", 0)), "tutorial": Tutorial.step(st)}

func q_places() -> Array:
	var c: Dictionary = st.clock
	var out: Array = []
	for d in Clock.destinations(repo):
		var p := String(d.place)
		var a := String(d.area)
		var op := Clock.place_open(repo, st, p, a, int(c.day), String(c.slot))
		var pl: Dictionary = repo.place(p)
		var free := Clock.is_free(repo, p, a)
		var ad = pl.get("areas", {}).get(a, {})
		out.append({"id": p, "area": a, "name": Diary.place_name(repo, p), "area_name": String(ad.get("desc", a)) if typeof(ad) == TYPE_DICTIONARY else a,
			"open": bool(op.open), "reason": String(op.reason), "streets": (pl.get("streets", []) as Array).duplicate(), "free": free,
			"can_go": bool(op.open) and String(c.phase) == "desk" and (free or not bool(c.outing_done)),
			"needs_seat": WorldModel.place_needs_seat(repo, p)})
	return out

func q_tray(day := -1) -> Array:
	var d := int(st.clock.day) if day < 0 else day
	var out: Array = []
	for it in st.world.get("tray", []):
		if int(it.get("day", -1)) != d:
			continue
		var v := String(it.view)
		var title := ""
		if st.world.docs.has(v):
			title = String(st.world.docs[v].get("meta", {}).get("title", ""))
		else:
			var cp: Dictionary = repo.copy(v)
			title = String(repo.doc(String(cp.get("doc", ""))).get("title", "")) if not cp.is_empty() else v
		out.append({"view": v, "title": title, "stamp": _stamp(int(it.tk)), "how": String(it.get("how", "")), "tk": int(it.tk)})
	return out

func _stamp(tk: int) -> String:
	var day := TimeKey.day_of(tk)
	var date := String(Clock.day_info(repo, day).get("date", ""))
	var sello := date
	if date.length() >= 10:
		sello = repo.text("core.fecha.sello", {"d": date.substr(8, 2).to_int(), "mes_corto": repo.text("core.mes_corto." + str(date.substr(5, 2).to_int()))})
	return repo.text("core.fecha.recibido", {"fecha": sello, "franja": repo.text("core.slot." + TimeKey.slot_of(tk))})

func q_accessible() -> Array:
	return WorldModel.accessible(st, repo)

func q_view(view: String) -> Dictionary:
	return WorldModel.view(st, repo, view)

func q_catalog(entity: String) -> Array:
	var all: Array = repo.catalog().get(entity, [])
	var docs: Array = []
	var noise: Array = []
	for x in all:
		if String(x.get("doc", "")) != "":
			docs.append({"doc": String(x.doc), "label": String(x.get("label", ""))})
		else:
			noise.append({"doc": "", "label": String(x.get("label", ""))})
	var out: Array = docs.slice(0, 5)
	for nz in Det.shuffle(int(st.seed), ["catalogo_ruido", entity], noise):
		if out.size() >= 5:
			break
		out.append(nz)
	return Det.shuffle(int(st.seed), [entity], out)

func q_clips() -> Array:
	var out: Array = []
	var clips = st.ded.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY:
		return out
	var ids: Array = clips.keys()
	ids.sort()
	for id in ids:
		var v := Clipper.visible(st, String(id))
		if not v.is_empty():
			out.append(v)
	return out

func q_clip(id: String) -> Dictionary:
	return Clipper.visible(st, id)

func q_index() -> Array:
	var out: Array = []
	for x in Index.known(st, repo):
		var it: Dictionary = x.duplicate() if typeof(x) == TYPE_DICTIONARY else {"id": String(x)}
		var id := String(it.get("id", ""))
		if not it.has("label") or not it.has("kind"):
			if st.world.acts.has(id):
				it["label"] = String(st.world.acts[id].label)
				it["kind"] = "act_ref"
			else:
				var en: Dictionary = repo.entity(id)
				it["label"] = String(en.get("index", en.get("name", id)))
				it["kind"] = String(en.get("kind", ""))
		out.append(it)
	return out

func q_act(id: String) -> Dictionary:
	var a = st.world.get("acts", {}).get(id)
	return a.duplicate() if typeof(a) == TYPE_DICTIONARY else {}

func q_line(uid: String) -> Dictionary:
	return WorldModel.line(st, repo, uid)

func q_pairs() -> Array:
	var out: Array = []
	var pairs = st.ded.get("pairs", {})
	if typeof(pairs) != TYPE_DICTIONARY:
		return out
	var ids: Array = pairs.keys()
	ids.sort()
	for id in ids:
		var p = pairs[id]
		if typeof(p) == TYPE_DICTIONARY:
			var o: Dictionary = p.duplicate(true)
			o["id"] = String(id)
			out.append(o)
	return out

func q_diary() -> Array:
	return Diary.entries(st, repo)

func q_marginalia() -> Array:
	var out: Array = []
	var found: Dictionary = st.world.get("eggs", {})
	for egg in repo.eggs():
		var id := String(egg.get("id", ""))
		if found.has(id):
			out.append({"id": id, "name": String(egg.get("name", "")), "note": String(egg.get("note", "")),
				"parsed": repo.parse_text(String(egg.get("note", ""))), "tk": int(found[id].get("tk", 0))})
	out.sort_custom(func(a, b):
		if a.tk != b.tk:
			return a.tk < b.tk
		return a.id < b.id)
	return out

func q_ledger() -> Dictionary:
	var rules: Array = []
	for k in ["rules.1", "rules.2", "rules.3", "rules.4", "rules.5", "rules.6"]:
		rules.append(repo.text(k))
	var entries = st.ded.get("entries", {})
	var folios = st.ded.get("folios", {})
	if typeof(entries) != TYPE_DICTIONARY:
		entries = {}
	if typeof(folios) != TYPE_DICTIONARY:
		folios = {}
	var varios: Array = []
	var by_folio := {}
	var eids: Array = entries.keys()
	eids.sort()
	for eid in eids:
		var f := String(entries[eid].get("folio", "varios"))
		if f == "varios" or f == "":
			varios.append(String(eid))
		else:
			if not by_folio.has(f):
				by_folio[f] = []
			by_folio[f].append(String(eid))
	var fl: Array = []
	var fids: Array = folios.keys()
	fids.sort()
	for fid in fids:
		var fo = folios[fid]
		fl.append({"id": String(fid), "head_clip": String(fo.get("head_clip", fo.get("clip", ""))) if typeof(fo) == TYPE_DICTIONARY else "",
			"entries": by_folio.get(String(fid), [])})
	return {"rules_title": repo.text("rules.title"), "rules_page": rules, "varios": varios, "folios": fl}

func q_entry(id: String) -> Dictionary:
	var entries = st.ded.get("entries", {})
	if typeof(entries) != TYPE_DICTIONARY or not entries.has(id):
		return {}
	var e: Dictionary = entries[id].duplicate(true)
	e["id"] = id
	if not e.has("ink"):
		e["ink"] = "lapiz"
	e["formal"] = Ledger.formal_check(st, repo, id)
	return e

func q_templates() -> Dictionary:
	return repo.lists().get("templates", {}).duplicate(true)

func q_lists() -> Dictionary:
	var l: Dictionary = repo.lists()
	return {"verbos": l.get("verbos", []).duplicate(), "relaciones": l.get("relaciones", []).duplicate(),
		"medios": l.get("medios", []).duplicate(true), "estados": l.get("estados", []).duplicate()}

func q_scene() -> Dictionary:
	var v: Dictionary = st.world.get("visit", {})
	if v.is_empty():
		return {}
	var chars: Array = []
	for c in v.get("chars", []):
		var cid := String(c.get("id", "")) if typeof(c) == TYPE_DICTIONARY else String(c)
		var known := Index.has(st, cid)
		var dl: Dictionary = repo.dialogue(cid)
		var en: Dictionary = repo.entity(cid)
		var label := Diary.char_label(repo, cid) if known else String(en.get("noun", dl.get("trait", cid)))
		chars.append({"id": cid, "label": label, "trait": String(c.get("trait", dl.get("trait", ""))) if typeof(c) == TYPE_DICTIONARY else String(dl.get("trait", "")),
			"can_ask": String(st.clock.phase) == "visit" and not dl.is_empty() and PlayerActions.questions_used(st, cid) < PlayerActions.max_questions(repo, cid)})
	var lines: Array = []
	for uid in v.get("lines", []):
		var ln := WorldModel.line(st, repo, String(uid))
		if not ln.is_empty():
			lines.append({"uid": String(uid), "who": String(ln.who), "parsed": ln.parsed, "id": String(ln.id)})
	return {"id": String(v.get("id", "")), "scene": String(v.get("scene", "")), "place": String(v.get("place", "")), "area": String(v.get("area", "")),
		"chars": chars, "lines": lines, "present_ok": String(st.clock.phase) == "visit" and not chars.is_empty(), "plate": String(v.get("plate", ""))}

func q_topics(char_id: String) -> Array:
	return Dialogue.topics(st, repo, char_id)

func q_assertions() -> Array:
	var out: Array = []
	for x in repo.lists().get("assertions", []):
		var ok := true
		for r in x.get("requires", []):
			if not Index.has(st, String(r)):
				ok = false
		if ok:
			out.append(x.duplicate(true))
	return out

func q_preview(action: Dictionary) -> String:
	var na := Actions.normalize(action)
	match String(na.get("t", "")):
		"ask", "assert", "present", "pay", "task":
			return Dialogue.preview(st, repo, na)
		"compose_ad":
			return String(Composers.preview_ad(st, repo, String(na.get("form", "")), na.get("fields", {})).get("text", ""))
		"compose_telegram", "compose_letter", "report_submit":
			# texto final del telegrama, la carta o el informe (§3.7); con dobles de test no hay vista previa
			if st.handlers.has(String(na.t)):
				return ""
			return String(Composers.preview(st, repo, na))
	return ""

func q_visit_plate() -> Dictionary:
	var v: Dictionary = st.world.get("visit", {})
	var pid := String(v.get("plate", ""))
	if pid == "":
		return {}
	return WorldModel.plate_snapshot(st, repo, pid)

func q_plate(id: String) -> Dictionary:
	return WorldModel.plate_snapshot(st, repo, id)

# Instantánea del hub (buhardilla) ahora: siluetas en la ventana, variante tras un registro (no se archiva).
func q_hub_plate() -> Dictionary:
	var snap := WorldModel.snapshot(st, repo, "L1", "", String(st.world.get("place_variants", {}).get("L1", "")))
	snap["id"] = "hub"
	return snap

func q_report_status() -> Dictionary:
	var r := Clock.report_now(st, repo)
	var due := not r.is_empty() and not Clock.report_done(st, int(r.n))
	return {"due": due, "n": int(r.get("n", 0)), "final": bool(r.get("final", false)),
		"offered_erratum": String(st.flags.get("errata_ofrecida", "")) != ""}

func q_confront() -> Dictionary:
	return Confrontation.status(st)

func q_tutorial() -> Dictionary:
	return {"step": Tutorial.step(st), "taught": Tutorial.verbs_taught(st), "complete": Tutorial.complete(st)}

func _after_final() -> bool:
	return bool(st.clock.get("d10", {}).get("final_done", false))

func q_ending() -> Dictionary:
	return Endings.evaluate(st, repo) if _after_final() else {}

func q_epilogue() -> Dictionary:
	if not _after_final():
		return {}
	var e := Endings.evaluate(st, repo)
	return {"ending": e, "noche_final": String(st.flags.get("noche_final", "")), "publica_errata": bool(st.flags.get("publica_errata", false)),
		"scene": q_scene()}

func q_blue_pencil() -> Array:
	return Endings.blue_pencil(st, repo) if _after_final() else []
