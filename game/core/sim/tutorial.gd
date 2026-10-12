# core/sim/tutorial.gd — rampa de enseñanza (GDD§3.2 prólogo, §7.7, T24). Dueño: W2-SIM. Contrato: ARCHITECTURE §3.8.
# Prólogo: un verbo por paso, con instructor dentro del mundo (Pell / Harris). Pasos en orden: recortar, vincular,
# abrir folio, asentar (llenar un campo y poner su «según»), practicar (lote guiado de 1, C1), redactar el aviso de
# testigos y dormir. En el prólogo sólo se admiten las acciones de pasos ya alcanzados (allowed); dormir exige el
# tutorial completo (Clock.act_sleep -> "tutorial"). Un paso se completa con su primera acción ok (practicar: cualquier
# resultado evaluado, para que nadie quede trabado; asentar: un entry_set y un entry_support_add ok).
# line_id = "PRO.t_<verbo>": línea del instructor en scenes/PRO.json (W3-CT-DLG-B); WorldModel.start_prologue no dice
# las líneas "t_*" y GameSim dice la del paso cuando éste empieza.
# Después del prólogo registra los verbos enseñados en contexto (verbs_taught): en el día 1 el mapa y el calendario;
# la Sala de Lectura enseña la papeleta (ujier); la tienda de Crane, preguntar/afirmar/presentar (interlocutor gratuito);
# la noche de informe, el informe (chico de Pell); etc. Los verbos son tipos de acción (§3.5).
# st.world.tutorial = {step:int, sub:{set:bool, support:bool}, done:bool, taught:{t: tk}}
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

const STEPS := [
	{"id": "clip", "instructor": "pell", "line_id": "PRO.t_clip", "verb": "clip", "acts": ["clip_text", "clip_plate", "clip_measure"]},
	{"id": "link", "instructor": "pell", "line_id": "PRO.t_link", "verb": "link", "acts": ["link", "unlink"]},
	{"id": "folio", "instructor": "pell", "line_id": "PRO.t_folio", "verb": "folio", "acts": ["folio_open"]},
	{"id": "entry", "instructor": "pell", "line_id": "PRO.t_entry", "verb": "entry", "acts": ["entry_new", "entry_set", "entry_support_add", "entry_support_remove", "entry_delete"]},
	{"id": "practice", "instructor": "pell", "line_id": "PRO.t_practice", "verb": "practice", "acts": ["practice"]},
	{"id": "ad", "instructor": "harris", "line_id": "PRO.t_ad", "verb": "ad", "acts": ["compose_ad"]},
	{"id": "sleep", "instructor": "pell", "line_id": "PRO.t_sleep", "verb": "sleep", "acts": ["sleep"]},
]
# Verbos que enseña cada paso del prólogo al completarse (practicar = el sello «Visto» de pasar en limpio).
const STEP_TEACHES := {
	"clip": ["clip_text", "clip_plate", "clip_measure"],
	"link": ["link", "unlink"],
	"folio": ["folio_open"],
	"entry": ["entry_new", "entry_set", "entry_support_add", "entry_support_remove", "entry_delete"],
	"practice": ["practice", "pass_clean"],
	"ad": ["compose_ad"],
	"sleep": ["sleep"],
}

static func init_state(st, repo) -> void:
	st.world["tutorial"] = {"step": 0, "sub": {"set": false, "support": false}, "done": false, "taught": {}}

static func _t(st) -> Dictionary:
	var t = st.world.get("tutorial", {})
	return t if typeof(t) == TYPE_DICTIONARY else {}

static func complete(st) -> bool:
	var t := _t(st)
	return bool(t.get("done", false)) or int(t.get("step", 0)) >= STEPS.size() - 1

static func step_index_of(t: String) -> int:
	for i in STEPS.size():
		if (STEPS[i].acts as Array).has(t):
			return i
	return -1

static func allowed(st, a: Dictionary) -> bool:
	if String(st.clock.get("phase", "")) != "prologue":
		return true
	var t := String(a.get("t", ""))
	var i := step_index_of(t)
	if i < 0:
		return false
	return i <= int(_t(st).get("step", 0))

static func step(st) -> Dictionary:
	if String(st.clock.get("phase", "")) != "prologue":
		return {}
	var t := _t(st)
	var i := int(t.get("step", 0))
	if i >= STEPS.size():
		return {}
	var s: Dictionary = STEPS[i]
	return {"id": s.id, "instructor": s.instructor, "line_id": s.line_id, "verb": s.verb, "index": i, "count": STEPS.size()}

static func _teach(st, verbs: Array, tk: int) -> void:
	var taught: Dictionary = st.world.tutorial.taught
	for v in verbs:
		if not taught.has(v):
			taught[v] = tk

static func after(st, repo, a: Dictionary, res: Dictionary) -> void:
	if not bool(res.get("ok", false)):
		return
	var tut := _t(st)
	if tut.is_empty():
		return
	var t := String(a.get("t", ""))
	var c: Dictionary = st.clock
	var tk := TimeKey.tk(int(c.get("day", 0)), String(c.get("slot", "N")))
	# --- prólogo: avance de pasos ---
	if not bool(tut.get("done", false)):
		var i := int(tut.get("step", 0))
		if i < STEPS.size() and (STEPS[i].acts as Array).has(t):
			var advance := true
			if STEPS[i].id == "entry":
				if t == "entry_set":
					tut.sub["set"] = true
				elif t == "entry_support_add":
					tut.sub["support"] = true
				advance = bool(tut.sub.get("set", false)) and bool(tut.sub.get("support", false))
			if advance:
				_teach(st, STEP_TEACHES.get(STEPS[i].id, []), tk)
				tut.step = i + 1
				if tut.step >= STEPS.size():
					tut.done = true
				st.note("clock", {"tutorial": tut.step})
		if t == "sleep":
			tut.done = true
			_teach(st, ["sleep"], tk)
	# --- verbos en contexto (Acto I) ---
	var phase := String(c.get("phase", ""))
	var v: Dictionary = st.world.get("visit", {})
	if phase == "desk" or t == "sleep":
		_teach(st, ["go", "end_slot", "leave", "compose_telegram", "compose_letter"], tk)
	if phase == "visit" and not v.is_empty():
		var place := String(v.get("place", ""))
		if bool(v.get("free", false)):
			_teach(st, ["ask", "assert", "present"], tk)
		if WorldModel.place_needs_seat(repo, place):
			_teach(st, ["slip"], tk)
		for ch in v.get("chars", []):
			var cid := String(ch.get("id", "")) if typeof(ch) == TYPE_DICTIONARY else String(ch)
			if not repo.dialogue(cid).is_empty():
				_teach(st, ["ask", "assert", "present"], tk)
			if typeof(ch) == TYPE_DICTIONARY and bool(ch.get("sil", false)):
				_teach(st, ["pay", "task"], tk)
		var dids: Array = repo.docs().keys()
		dids.sort()
		for did in dids:
			var d: Dictionary = repo.doc(did)
			if String(d.get("clip_mode", "")) == "memoria":
				for cp in d.get("copies", []):
					if String(cp.get("holder", "")) == place:
						_teach(st, ["order_copy"], tk)
	if phase == "final_report" or (phase == "night" and _report_night(repo, int(c.get("day", 0)))):
		_teach(st, ["report_submit"], tk)
	if phase == "confront":
		_teach(st, ["confront"], tk)
	if phase == "night_choice":
		_teach(st, ["night_choice"], tk)
	if phase == "epilogue":
		_teach(st, ["publish_errata"], tk)

static func _report_night(repo, day: int) -> bool:
	for r in repo.schedule().get("reports", []):
		if TimeKey.of(r.get("tk", "")) == TimeKey.tk(day, "night"):
			return true
	return false

# Verbos (tipos de acción) enseñados hasta ahora, en orden de enseñanza (tk, luego nombre).
static func verbs_taught(st) -> Array:
	var taught: Dictionary = _t(st).get("taught", {})
	var ks: Array = taught.keys()
	ks.sort_custom(func(a, b):
		if int(taught[a]) != int(taught[b]):
			return int(taught[a]) < int(taught[b])
		return String(a) < String(b))
	return ks
