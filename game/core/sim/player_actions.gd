# core/sim/player_actions.gd — despacho de acciones a sus manejadores (§3.5; GDD_v3 §1.7). Dueño: CORE-EXPEDIENTE.
# Hace cumplir lo que es del reloj y del mundo alrededor de los manejadores de otros módulos:
#   - accesibilidad de la fuente antes de recortar (§5.1) y tope de recortes «de memoria» por visita;
#   - Expediente (dq_answer, dq_proof, dq_confirm: core/deduction/dossier.gd) y examine (intrusión notada, §4.4);
#   - oficina y día de publicación de anuncios (el evento `ad` se difiere al amanecer de la publicación);
#   - telegramas y cartas: su evento sale al cerrar la franja (outbox);
#   - informes: el que corresponde ahora, una vez; el final lleva a Park Lane;
#   - preguntas por personaje y visita; líneas dichas -> mundo y diario; monedas.
# st.handlers (sólo tests) reemplaza el manejador de OTRO paquete por un doble; nunca los propios (clock/world).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const L = preload("res://core/util/log.gd")
const Clock = preload("res://core/sim/clock.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const Diary = preload("res://core/sim/diary.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Confrontation = preload("res://core/scenes/confrontation.gd")
const Composers = preload("res://core/scenes/composers.gd")
const Reveal = preload("res://core/sim/reveal.gd")
const Tutorial = preload("res://core/sim/tutorial.gd")

const DEFAULT_MAX_QUESTIONS := 3

static func dispatch(st, repo, a: Dictionary) -> Dictionary:
	var t := String(a.get("t", ""))
	match t:
		"clip_text", "clip_plate":
			return _clip(st, repo, a)
		"clip_drop":
			return _res(Clipper.act_drop(st, repo, a))
		"read":
			var v := WorldModel.view(st, repo, String(a.get("view", "")))
			var rr := Reveal.act_read(st, repo, a, v)
			if bool(rr.get("ok", false)):
				var part := int(a.get("part", 0))
				var pages: Array = v.get("pages", [])
				if part >= 0 and part < pages.size():
					Dossier.on_read(st, repo, String(a.get("view", "")), pages[part])
			return rr
		"dq_answer", "dq_proof", "dq_confirm", "ask_donde":
			return _ext(st, repo, a)
		"examine":
			return act_examine(st, repo, a)
		"go":
			return Clock.act_go(st, repo, a)
		"leave":
			return Clock.act_leave(st, repo, a)
		"end_slot":
			return Clock.act_end_slot(st, repo, a)
		"sleep":
			return Clock.act_sleep(st, repo, a)
		"night_choice":
			return Clock.act_night_choice(st, repo, a)
		"publish_errata":
			return Clock.act_publish_errata(st, repo, a)
		"slip":
			return WorldModel.act_slip(st, repo, a)
		"order_copy":
			return WorldModel.act_order_copy(st, repo, a)
		"ask", "assert", "present", "pay", "task":
			return _talk(st, repo, a)
		"compose_ad":
			return _compose_ad(st, repo, a)
		"compose_telegram", "compose_letter":
			return _compose_mail(st, repo, a)
		"report_submit":
			return _report(st, repo, a)
		"confront":
			var rc := _ext(st, repo, a)
			if rc.get("ok", false):
				var done := bool(rc.get("done", false))
				if not done:
					var stt: Dictionary = Confrontation.status(st) if not st.handlers.has("confront") else {}
					done = bool(stt.get("done", false))
				if done:
					Clock.on_confront_done(st, repo)
			return rc
	return {"ok": false, "err": "accion_desconocida"}

# Manejadores de otros paquetes (o su doble de test).
static func _ext(st, repo, a: Dictionary) -> Dictionary:
	var t := String(a.get("t", ""))
	if st.handlers.has(t):
		return _res(st.handlers[t].call(st, repo, a))
	match t:
		"clip_text": return _res(Clipper.act_clip_text(st, repo, a))
		"clip_plate": return _res(Clipper.act_clip_plate(st, repo, a))
		"dq_answer": return _res(Dossier.act_answer(st, repo, a))
		"dq_proof": return _res(Dossier.act_proof(st, repo, a))
		"dq_confirm": return _res(Dossier.act_confirm(st, repo, a))
		"ask_donde": return _res(Dialogue.act_ask_donde(st, repo, a))
		"ask": return _res(Dialogue.act_ask(st, repo, a))
		"assert": return _res(Dialogue.act_assert(st, repo, a))
		"present": return _res(Dialogue.act_present(st, repo, a))
		"pay": return _res(Dialogue.act_pay(st, repo, a))
		"task": return _res(Dialogue.act_task(st, repo, a))
		"compose_ad": return _res(Composers.act_compose_ad(st, repo, a))
		"compose_telegram": return _res(Composers.act_compose_telegram(st, repo, a))
		"compose_letter": return _res(Composers.act_compose_letter(st, repo, a))
		"report_submit": return _res(Composers.act_report_submit(st, repo, a))
		"confront": return _res(Confrontation.act_confront(st, repo, a))
	return {"ok": false, "err": "accion_desconocida"}

static func _res(r) -> Dictionary:
	if typeof(r) != TYPE_DICTIONARY:
		return {"ok": false, "err": "manejador"}
	if not r.has("ok"):
		r["ok"] = not r.has("err")
	return r

# examine {ref: "hub/<nodo>" | "missing/<copia>" | "sheet/<qid>"} (GDD_v3 §4.4; sheet: playtest v3): ciega y libre. Un nodo con `aviso` (o un original que
# falta) registra la intrusión notada de esa reacción; lo demás no hace nada.
static func act_examine(st, repo, a: Dictionary) -> Dictionary:
	var ref := String(a.get("ref", ""))
	var kind := ref.get_slice("/", 0)
	var x := ref.substr(kind.length() + 1)
	if x == "":
		return {"ok": false, "err": "forma"}
	var rid := ""
	match kind:
		"hub":
			rid = node_aviso(st, repo, x)
		"missing":
			rid = missing_by(st, repo, x)
		"sheet":
			# playtest v3: abrir una hoja del expediente (Pendientes deja de anunciarla como nueva)
			return Dossier.act_look(st, repo, x)
		_:
			return {"ok": false, "err": "forma"}
	return Dossier.act_examine(st, repo, a, rid)

# `aviso` (id de reacción) del nodo de la buhardilla de ahora, o "".
static func node_aviso(st, repo, node: String) -> String:
	var snap := WorldModel.hub_snapshot(st, repo)
	if snap.is_empty() or not (snap.get("nodes", []) as Array).has(node):
		return ""
	var nd = snap.get("node_defs", {}).get(node)
	if typeof(nd) == TYPE_DICTIONARY and String(nd.get("aviso", "")) != "":
		return String(nd.aviso)
	var pl: Dictionary = repo.place(WorldModel.HOME)
	var lst: Array = (pl.get("nodes", []) as Array).duplicate()
	var vs = pl.get("variants", {})
	if typeof(vs) == TYPE_DICTIONARY:
		for k in WorldModel._sorted_keys(vs):
			if typeof(vs[k]) == TYPE_DICTIONARY:
				lst.append_array(vs[k].get("add_nodes", []))
	for n in lst:
		if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == node:
			return String(n.get("aviso", ""))
	return ""

# Reacción que se llevó un original que falta ahora en casa ("" si no falta).
static func missing_by(st, repo, copy_id: String) -> String:
	for m in WorldModel.missing(st, repo):
		if String(m.get("copy", "")) == copy_id:
			return String(m.get("rid", ""))
	return ""

# ---------------- recortes ----------------
static func _src_doc(repo, st, view: String) -> Dictionary:
	if st.world.get("docs", {}).has(view):
		return st.world.docs[view].get("meta", {})
	var cp: Dictionary = repo.copy(view)
	return repo.doc(String(cp.doc)) if not cp.is_empty() else {}

static func source_accessible(st, repo, a: Dictionary) -> bool:
	match String(a.get("t", "")):
		"clip_plate":
			return not WorldModel.plate_snapshot(st, repo, String(a.get("plate", ""))).is_empty() and _plate_now_ok(st, repo, String(a.get("plate", "")))
		"clip_text":
			var src: Dictionary = a.get("src", {})
			var ref := String(src.get("ref", ""))
			match String(src.get("kind", "")):
				"doc":
					return WorldModel.view_accessible(st, repo, ref)
				"line":
					# líneas de escena (WorldModel.say_line -> st.world.lines) o de diálogo (Dialogue.say_line ->
					# st.scenes.lines, W2-SCENES): ambas son recortables (§3.5 src kind "line"; integración ola 2).
					var sl = st.scenes.get("lines", {}) if typeof(st.scenes) == TYPE_DICTIONARY else {}
					return st.world.get("lines", {}).has(ref) or (typeof(sl) == TYPE_DICTIONARY and sl.has(ref))
				"diary":
					return not Diary.get_line(st, repo, ref).is_empty()
				"node":
					var pid := ref.get_slice("/", 0)
					var nid := ref.get_slice("/", 1)
					var snap := WorldModel.plate_snapshot(st, repo, pid)
					return not snap.is_empty() and _plate_now_ok(st, repo, pid) and ((snap.get("nodes", []) as Array).has(nid) or (snap.get("silhouettes", []) as Array).has(nid))
				"scene":
					var v: Dictionary = st.world.get("visit", {})
					return not v.is_empty() and (ref == String(v.get("id", "")) or ref == String(v.get("scene", "")) or (st.world.get("visits", []) as Array).has(ref))
	return false

# Láminas archivadas: siempre (clase I). Láminas de documento ("RB.foto"): si algún documento accesible la abre.
static func _plate_now_ok(st, repo, pid: String) -> bool:
	if st.world.get("plates", {}).has(pid):
		return true
	for v in WorldModel.accessible(st, repo):
		var d := _src_doc(repo, st, String(v.view))
		if String(d.get("plate", "")) == pid:
			return true
	return false

static func _clip(st, repo, a: Dictionary) -> Dictionary:
	# El escritorio muestra el hub («hub»): recortarlo (rectángulo o texto de examen «hub/<nodo>») archiva la buhardilla
	# de ahora como lámina (WorldModel.archive_hub) y el recorte la nombra; si el recorte falla, la lámina nueva se borra.
	var hub := {}
	if String(a.get("t", "")) == "clip_plate" and String(a.get("plate", "")) == WorldModel.HUB_PLATE:
		hub = WorldModel.archive_hub(st, repo)
		if not hub.is_empty():
			a = a.duplicate(true)
			a["plate"] = String(hub.id)
	elif String(a.get("t", "")) == "clip_text" and typeof(a.get("src")) == TYPE_DICTIONARY and String(a.src.get("kind", "")) == "node" \
			and String(a.src.get("ref", "")).begins_with(WorldModel.HUB_PLATE + "/"):
		hub = WorldModel.archive_hub(st, repo)
		if not hub.is_empty():
			a = a.duplicate(true)
			a.src["ref"] = String(hub.id) + String(a.src.ref).substr(WorldModel.HUB_PLATE.length())
	var r := _clip_now(st, repo, a)
	if not bool(r.get("ok", false)) and bool(hub.get("created", false)):
		st.world.plates.erase(String(hub.id))
	return r

static func _clip_now(st, repo, a: Dictionary) -> Dictionary:
	if not source_accessible(st, repo, a):
		return {"ok": false, "err": "inaccesible"}
	var mem_key := ""
	if String(a.get("t", "")) == "clip_text":
		var src: Dictionary = a.get("src", {})
		if String(src.get("kind", "")) == "doc" and String(_src_doc(repo, st, String(src.get("ref", ""))).get("clip_mode", "normal")) == "memoria":
			mem_key = String(st.world.get("visit", {}).get("id", "F.%d.%s" % [int(st.clock.day), String(st.clock.slot)]))
			if int(st.world.mem_clips.get(mem_key, 0)) >= WorldModel.MEMORY_CLIPS:
				return {"ok": false, "err": "memoria_agotada"}
	var r := _ext(st, repo, a)
	if r.get("ok", false):
		if mem_key != "":
			st.world.mem_clips[mem_key] = int(st.world.mem_clips.get(mem_key, 0)) + 1
	return r

# ---------------- conversación ----------------
static func max_questions(repo, char_id: String) -> int:
	return int(repo.dialogue(char_id).get("max_questions", DEFAULT_MAX_QUESTIONS))

static func questions_used(st, char_id: String) -> int:
	var v: Dictionary = st.world.get("visit", {})
	return int(st.world.get("questions", {}).get(String(v.get("id", "")), {}).get(char_id, 0))

static func char_present(st, char_id: String) -> bool:
	for c in st.world.get("visit", {}).get("chars", []):
		if (String(c.get("id", "")) if typeof(c) == TYPE_DICTIONARY else String(c)) == char_id:
			return true
	return false

static func _talk(st, repo, a: Dictionary) -> Dictionary:
	var t := String(a.get("t", ""))
	var ch := String(a.get("char", ""))
	if not char_present(st, ch):
		return {"ok": false, "err": "no_esta"}
	var counts := t == "ask" or t == "assert"
	if counts and questions_used(st, ch) >= max_questions(repo, ch):
		var closing := String(repo.dialogue(ch).get("closing", ""))
		return {"ok": false, "err": "sin_preguntas", "closing": closing}
	var r := _ext(st, repo, a)
	if not r.get("ok", false):
		return r
	var v: Dictionary = st.world.visit
	if counts:
		var vid := String(v.get("id", ""))
		if not st.world.questions.has(vid):
			st.world.questions[vid] = {}
		st.world.questions[vid][ch] = questions_used(st, ch) + 1
	if t == "pay":
		WorldModel.add_coins(st, -int(a.get("amount_d", 0)))
	var ln = r.get("line")
	if r.has("lines"):
		ln = null   # Dialogue real: ya registró sus líneas en st.scenes.lines (GameSim las pasa al diario)
	if ln != null:
		var rec := {}
		if typeof(ln) == TYPE_DICTIONARY:
			rec = {"id": String(ln.get("id", "")), "who": String(ln.get("who", ch)), "text": String(ln.get("text", ""))}
		elif typeof(ln) == TYPE_STRING and String(ln) != "":
			rec = {"id": "", "who": ch, "text": String(ln)}
		if not rec.is_empty() and rec.text != "":
			rec["origin"] = String(v.get("id", ""))
			rec["scene"] = String(v.get("id", ""))
			rec["place"] = String(v.get("place", ""))
			var uid := WorldModel.say_line(st, repo, rec)
			if typeof(ln) == TYPE_DICTIONARY:
				ln["uid"] = uid
			else:
				r["line"] = {"uid": uid, "who": ch, "text": rec.text}
	return r

# ---------------- compositores ----------------
static func _take_pending(st, before: int, types: Array) -> Array:
	var taken: Array = []
	var keep: Array = []
	for i in st.pending_events.size():
		var ev: Dictionary = st.pending_events[i]
		if i >= before and types.has(String(ev.get("type", ""))):
			taken.append(ev)
		else:
			keep.append(ev)
	st.pending_events = keep
	return taken

static func _assertion(repo, id: String) -> Dictionary:
	for x in repo.lists().get("assertions", []):
		if String(x.get("id", "")) == id:
			return x
	return {}

static func _ad_form(repo, id: String) -> Dictionary:
	for f in repo.lists().get("ad_forms", []):
		if String(f.get("id", "")) == id:
			return f
	return {}

static func _compose_ad(st, repo, a: Dictionary) -> Dictionary:
	var err := Clock.ad_error(st, repo)
	if err != "":
		return {"ok": false, "err": err}
	var before: int = st.pending_events.size()
	var r := _ext(st, repo, a)
	if not r.get("ok", false):
		return r
	var day := int(st.clock.day)
	var pub := Clock.ad_pub_day(repo, day)
	if r.has("pub_day") and int(r.pub_day) != pub:
		L.w("sim", "pub_day del compositor (%d) != reloj (%d); manda el reloj" % [int(r.pub_day), pub])
	r["pub_day"] = pub
	var pushed := _take_pending(st, before, ["ad"])
	var form := _ad_form(repo, String(a.get("form", "")))
	var real: bool = not st.handlers.has("compose_ad")
	if real and r.has("event"):
		# Composers real: emite el evento con on_dawn(día de publicación) (GameSim, paso 6). Nunca ambos caminos.
		pushed = []
	elif pushed.is_empty() and typeof(r.get("event")) == TYPE_DICTIONARY:
		pushed = [r.event.duplicate(true)]
	elif pushed.is_empty():
		var ev := {"type": "ad", "ad": String(r.get("ad", "")), "form": String(a.get("form", "")), "text": String(r.get("text", "")),
			"to_s": bool(form.get("to_s", false)), "says_alive": false, "pub_day": pub}
		if bool(form.get("canary", false)):
			ev["canary"] = String(a.get("form", ""))
		var fields: Dictionary = a.get("fields", {})
		for k in _keys(fields):
			var asr := _assertion(repo, String(fields[k]))
			if not asr.is_empty():
				ev["assertion"] = String(asr.id)
				if String(asr.get("kind", "")) == "cebo":
					ev["bait_topic"] = String(asr.get("topic", ""))
				if String(asr.get("kind", "")) == "canario":
					ev["canary"] = String(asr.get("topic", ""))
				ev["says_alive"] = bool(asr.get("says_alive", false))
		pushed = [ev]
	var pub_tk := TimeKey.tk(pub, "dawn")
	for ev in pushed:
		ev["pub_day"] = pub
		ev["tk"] = pub_tk
		ev["day"] = pub
		ev["slot"] = "dawn"
		st.clock.deferred.append({"tk": pub_tk, "ev": ev})
	st.clock.ads_by_day[str(day)] = {"ad": String(r.get("ad", "")), "ad_id": String(r.get("ad_id", r.get("ad", ""))), "pub_day": pub,
		"form": String(a.get("form", "")), "text": String(r.get("text", ""))}
	WorldModel.add_coins(st, -int(r.get("cost_d", repo.schedule().get("money_d", {}).get("ad", 30))))
	st.note("clock", {"ad": pub})
	return r

static func _compose_mail(st, repo, a: Dictionary) -> Dictionary:
	var t := String(a.get("t", ""))
	var et := "telegram" if t == "compose_telegram" else "letter"
	var before: int = st.pending_events.size()
	var r := _ext(st, repo, a)
	if not r.get("ok", false):
		return r
	var pushed := _take_pending(st, before, [et])
	if not st.handlers.has(t) and r.has("event"):
		# Composers real: lo emite on_end_slot (Clock.act_end_slot). Nunca ambos caminos.
		pushed = []
	elif pushed.is_empty() and typeof(r.get("event")) == TYPE_DICTIONARY:
		pushed = [r.event.duplicate(true)]
	elif pushed.is_empty():
		pushed = [{"type": et, "to": String(a.get("to", "")), "text": String(r.get("text", "")), "id": String(r.get("id", ""))}]
	for ev in pushed:
		st.world.outbox.append(ev)
	WorldModel.add_coins(st, -int(r.get("cost_d", 0)))
	st.note("clock", {"outbox": st.world.outbox.size()})
	return r

static func _report(st, repo, a: Dictionary) -> Dictionary:
	var rep := Clock.report_now(st, repo)
	if rep.is_empty():
		return {"ok": false, "err": "sin_informe"}
	if Clock.report_done(st, int(rep.n)):
		return {"ok": false, "err": "ya_entregado"}
	var before: int = st.pending_events.size()
	var r := _ext(st, repo, a)
	if not r.get("ok", false):
		return r
	var has_ev := false
	for i in range(before, st.pending_events.size()):
		if String(st.pending_events[i].get("type", "")) == "report":
			has_ev = true
			st.pending_events[i]["n"] = int(st.pending_events[i].get("n", rep.n))
	if not has_ev:
		var items: Array = []
		for it in a.get("items", []):
			if typeof(it) == TYPE_DICTIONARY:
				items.append({"kind": String(it.get("kind", "")), "cats": [], "copies": [], "cls": []})
		st.push_event({"type": "report", "n": int(rep.n), "mode": String(a.get("mode", "")), "items": items})
	Clock.on_report_submitted(st, repo, int(rep.n), bool(rep.final))
	r["n"] = int(rep.n)
	return r

static func _keys(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k
