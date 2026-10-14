# core/sim/tutorial.gd — rampa de enseñanza en dos tiempos (GDD_v3 §6.9; GDD_v2 §B.7; T24). Dueño: CORE-EXPEDIENTE.
# PRÓLOGO («El encargo», instructores Pell y Harris dentro del mundo; bloquea como siempre, pasos en orden):
#   1 read (abrir el expediente y leer el encargo D23) · 2 clip (recortar el aviso al pie) · 3 ad (aviso con el tintero)
#   · 4 sleep (dormir). En el prólogo sólo se admiten las acciones de pasos ya alcanzados. Recortar el encargo cuenta
#   también como haberlo abierto: un recorte en el paso «read» completa los dos pasos. Desde el paso «clip» también se
#   admiten los verbos del Expediente (dq_*) y examine: no se enseñan en el prólogo, pero un guion que los use no se traba.
#   line_id = "PRO.t_<paso>" (scenes/PRO.json); GameSim dice la línea del paso cuando empieza.
# DÍA 1 (guía con notas de Lisle; NO bloquea nada; cada paso se cumple por el estado):
#   5 d1_leer: leer «El problema final» (read de una hoja de D03; nace Q2) · 6 d1_pruebas: ≥2 recortes y una hoja con
#   respuesta y dos pruebas · 7 d1_pasar: pasar en limpio cualquier pregunta (dq_confirm, cierre o no).
#   line_key = "v3core.d1.<paso>" (ui_text). Mientras un paso es el actual, su verbo cuenta como enseñado (T24).
# Verbos en contexto después del prólogo (verbs_taught): en el escritorio el plano y el calendario; la Sala de Lectura
# enseña el pedido; la tienda de Crane, preguntar/afirmar/presentar y «¿Dónde consigo…?»; la noche de informe, el
# informe; etc. Los verbos son tipos de acción (§3.5).
# st.world.tutorial = {step:int, done:bool, taught:{t: tk}, d1:{}}
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

const PROLOGUE_DOC := "D23"
# clip_measure (la regla) ya no existe en la interfaz (GDD_v2 §C.5.6): se admite para reproducir partidas viejas, pero no se
# enseña ni cuenta como paso.
const CLIP_ACTS := ["clip_text", "clip_plate"]
const CLIP_TEACH := ["clip_text", "clip_plate"]
const PROLOGUE := [
	{"id": "read", "instructor": "pell", "line_id": "PRO.t_read", "verb": "read", "acts": ["read"]},
	{"id": "clip", "instructor": "pell", "line_id": "PRO.t_clip", "verb": "clip", "acts": CLIP_ACTS},
	{"id": "ad", "instructor": "harris", "line_id": "PRO.t_ad", "verb": "ad", "acts": ["compose_ad"]},
	{"id": "sleep", "instructor": "pell", "line_id": "PRO.t_sleep", "verb": "sleep", "acts": ["sleep"]},
]
const STEPS := PROLOGUE   # compatibilidad: los pasos que bloquean
const DAY1 := [
	{"id": "d1_leer", "instructor": "lisle", "line_key": "v3core.d1.leer", "verb": "read", "acts": ["read"]},
	{"id": "d1_pruebas", "instructor": "lisle", "line_key": "v3core.d1.pruebas", "verb": "proof", "acts": ["dq_answer", "dq_proof"]},
	{"id": "d1_pasar", "instructor": "lisle", "line_key": "v3core.d1.pasar", "verb": "confirm", "acts": ["dq_confirm"]},
]
const DAY1_DOC := "D03"
# Verbos del Expediente admitidos en el prólogo desde el paso «clip» (no se enseñan ahí).
const PROLOGUE_FREE := ["dq_answer", "dq_proof", "dq_confirm", "examine"]
# Verbos que enseña cada paso del prólogo al completarse.
const STEP_TEACHES := {
	"read": ["read"],
	"clip": CLIP_TEACH,
	"ad": ["compose_ad"],
	"sleep": ["sleep"],
}

static func init_state(st, repo) -> void:
	st.world["tutorial"] = {"step": 0, "done": false, "taught": {}, "d1": {}}

static func _t(st) -> Dictionary:
	var t = st.world.get("tutorial", {})
	return t if typeof(t) == TYPE_DICTIONARY else {}

static func _d1(st) -> Dictionary:
	var t := _t(st)
	if typeof(t.get("d1")) != TYPE_DICTIONARY:
		t["d1"] = {}
	return t.d1

static func complete(st) -> bool:
	var t := _t(st)
	return bool(t.get("done", false)) or int(t.get("step", 0)) >= PROLOGUE.size() - 1

static func step_index_of(t: String) -> int:
	for i in PROLOGUE.size():
		if (PROLOGUE[i].acts as Array).has(t):
			return i
	return -1

static func _day1_act(t: String) -> bool:
	for s in DAY1:
		if (s.acts as Array).has(t):
			return true
	return false

static func allowed(st, a: Dictionary) -> bool:
	if String(st.clock.get("phase", "")) != "prologue":
		return true
	var t := String(a.get("t", ""))
	# abrir una hoja del expediente (examine «sheet/<qid>», playtest v3) no hace nada en el mundo: siempre vale
	if t == "examine" and String(a.get("ref", "")).begins_with("sheet/"):
		return true
	var cur := int(_t(st).get("step", 0))
	var i := step_index_of(t)
	if i >= 0:
		# recortar en el paso «read»: el encargo está abierto (se completa al recortar)
		return i <= cur or (i == 1 and cur == 0)
	if PROLOGUE_FREE.has(t):
		return cur >= 1
	return false

# Paso del prólogo (bloqueante); {} fuera del prólogo.
static func step(st) -> Dictionary:
	if String(st.clock.get("phase", "")) != "prologue":
		return {}
	var t := _t(st)
	var i := int(t.get("step", 0))
	if i >= PROLOGUE.size():
		return {}
	var s: Dictionary = PROLOGUE[i]
	return {"id": s.id, "instructor": s.instructor, "line_id": s.line_id, "verb": s.verb, "index": i, "count": PROLOGUE.size()}

# ---------------- día 1 guiado (GDD_v3 §6.9; no bloquea) ----------------
static func _d1_done(st, id: String) -> bool:
	match id:
		"d1_leer":
			var cps = st.world.get("read", {})
			if typeof(cps) != TYPE_DICTIONARY:
				return false
			for v in cps:
				if String(v).begins_with(DAY1_DOC + "@"):
					return true
			return false
		"d1_pruebas":
			if int(st.seq.get("clip", 0)) < 2:
				return false
			var d = st.ded.get("dossier", {}) if typeof(st.ded) == TYPE_DICTIONARY else {}
			if typeof(d) != TYPE_DICTIONARY:
				return false
			if not (d.get("inked", {}) as Dictionary).is_empty():
				return true
			for q in d.get("drafts", {}):
				var dr = d.drafts[q]
				if typeof(dr) == TYPE_DICTIONARY and String(dr.get("answer", "")) != "":
					var pr: Array = dr.get("proofs", [])
					if pr.size() == 2 and String(pr[0]) != "" and String(pr[1]) != "":
						return true
			return false
		"d1_pasar":
			var d2 = st.ded.get("dossier", {}) if typeof(st.ded) == TYPE_DICTIONARY else {}
			if typeof(d2) != TYPE_DICTIONARY:
				return false
			for q in d2.get("attempts", {}):
				if int(d2.attempts[q]) > 0:
					return true
			return false
	return false

# Índice del primer paso del día 1 sin cumplir; DAY1.size() si ya está todo.
static func day1_index(st) -> int:
	for i in DAY1.size():
		if not _d1_done(st, String(DAY1[i].id)):
			return i
	return DAY1.size()

static func day1_complete(st) -> bool:
	return day1_index(st) >= DAY1.size()

# Paso actual del día 1 guiado (desde el día 1 hasta pasar en limpio): {id, instructor, line_key, verb, index, count}.
static func day1_step(st) -> Dictionary:
	var ph := String(st.clock.get("phase", ""))
	if ph == "prologue" or ph == "done" or ph == "epilogue" or int(st.clock.get("day", 0)) < 1:
		return {}
	var i := day1_index(st)
	if i >= DAY1.size():
		return {}
	var s: Dictionary = DAY1[i]
	return {"id": s.id, "instructor": s.instructor, "line_key": s.line_key, "verb": s.verb, "index": i, "count": DAY1.size()}

static func _teach(st, verbs: Array, tk: int) -> void:
	var taught: Dictionary = _t(st).get("taught", {})
	_t(st)["taught"] = taught
	for v in verbs:
		if not taught.has(v):
			taught[v] = tk

# Verbos del día 1 guiado: los de los pasos cumplidos y el del actual (las notas de Lisle lo están pidiendo).
static func _teach_day1(st, tk: int) -> void:
	var cur := day1_index(st)
	for i in DAY1.size():
		if i <= cur:
			_teach(st, DAY1[i].acts, tk)

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
		var moved := false
		if i == 0 and ((t == "read" and _reads_prologue_doc(st, repo, a)) or CLIP_ACTS.has(t)):
			_teach(st, STEP_TEACHES.read, tk)
			i = 1
			moved = true
		if i < PROLOGUE.size() and (PROLOGUE[i].acts as Array).has(t) and PROLOGUE[i].id != "read":
			_teach(st, STEP_TEACHES.get(PROLOGUE[i].id, []), tk)
			i += 1
			moved = true
		if moved:
			tut.step = i
			if i >= PROLOGUE.size():
				tut.done = true
			st.note("clock", {"tutorial": i})
		if t == "sleep":
			tut.done = true
			_teach(st, ["sleep"], tk)
	if String(c.get("phase", "")) != "prologue":
		_teach_day1(st, tk)
	# --- verbos en contexto (Acto I) ---
	var phase := String(c.get("phase", ""))
	var v: Dictionary = st.world.get("visit", {})
	if phase == "desk" or t == "sleep":
		_teach(st, ["go", "end_slot", "leave", "compose_telegram", "compose_letter"], tk)
	if phase == "visit" and not v.is_empty():
		var place := String(v.get("place", ""))
		if bool(v.get("free", false)):
			_teach(st, ["ask", "assert", "present", "ask_donde"], tk)
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

# `read` del encargo (si el repo no lo tiene, cualquier lectura).
static func _reads_prologue_doc(st, repo, a: Dictionary) -> bool:
	if repo.doc(PROLOGUE_DOC).is_empty():
		return true
	var view := String(a.get("view", ""))
	var cp: Dictionary = repo.copy(view)
	return not cp.is_empty() and String(cp.get("doc", "")) == PROLOGUE_DOC

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
