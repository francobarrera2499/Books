# core/sim/actions.gd — catálogo de acciones (§3.5; GDD_v3 §1.7). Dueño: CORE-EXPEDIENTE. Contrato: ARCHITECTURE §3.8.
# SPEC: t -> {args:{nombre: TYPE_*}, opt:{nombre: valor por defecto}, commit: bool, phases:[...]}
#   commit = acción comprometida (Game.act la escribe a disco antes de devolver el resultado).
#   phases = fases en que se admite (las libres: todas salvo "done"; el tutorial filtra más en el prólogo).
# normalize(a): J.ints sobre todo (el JSON trae enteros como float), castea args declarados, completa opcionales,
#   descarta claves desconocidas y ordena claves (recursivo). normalize(normalize(a)) == normalize(a).
# shape_error(a): "" o código: "accion_desconocida" | "falta:<arg>" | "tipo:<arg>".
extends RefCounted

const J = preload("res://core/util/j.gd")

const PHASES := ["prologue", "desk", "visit", "scene", "night", "confront", "final_report", "parklane", "night_choice", "epilogue", "done"]
const FREE := ["prologue", "desk", "visit", "scene", "night", "confront", "final_report", "parklane", "night_choice", "epilogue"]

# Fases en que se puede pasar en limpio (GDD_v3 §1.6): hasta el informe final (después, lo entintado no cambia).
const DOSSIER_COMMIT := ["prologue", "desk", "visit", "scene", "night", "confront", "final_report"]

const SPEC := {
	"clip_text": {"args": {"src": TYPE_DICTIONARY, "from": TYPE_INT, "len": TYPE_INT}, "opt": {}, "commit": false, "phases": FREE},
	# bots y tests (GDD_v3 §6.2: la interfaz recorta todo lo del 3D del texto de su tarjeta de examen)
	"clip_plate": {"args": {"plate": TYPE_STRING, "hits": TYPE_ARRAY, "touched": TYPE_ARRAY, "area_frac": TYPE_FLOAT}, "opt": {"touched": [], "area_frac": 0.0}, "commit": false, "phases": FREE},
	# GDD_v2 §B.4: el lector la emite la primera vez que muestra cada hoja en la sesión. Libre y ciega (sin evento).
	"read": {"args": {"view": TYPE_STRING, "part": TYPE_INT}, "opt": {"part": 0}, "commit": false, "phases": FREE},
	# playtest v3: tirar un recorte equivocado (clic derecho en el cuaderno); no si es prueba de una hoja en tinta
	"clip_drop": {"args": {"clip": TYPE_STRING}, "opt": {}, "commit": false, "phases": FREE},
	# GDD_v3 §1.6–§1.7: Expediente Holmes (respuesta, pruebas, pasar en limpio de a una pregunta)
	"dq_answer": {"args": {"q": TYPE_STRING, "value": TYPE_STRING}, "opt": {"value": ""}, "commit": false, "phases": FREE},
	"dq_proof": {"args": {"q": TYPE_STRING, "slot": TYPE_INT, "clip": TYPE_STRING}, "opt": {"clip": ""}, "commit": false, "phases": FREE},
	"dq_confirm": {"args": {"q": TYPE_STRING}, "opt": {}, "commit": true, "phases": DOSSIER_COMMIT},
	# GDD_v3 §4.4: la UI la emite al abrir la tarjeta de un nodo con `aviso` ("hub/<nodo>") o al tocar un faltante del
	# estante ("missing/<copia>"). Libre y ciega.
	"examine": {"args": {"ref": TYPE_STRING}, "opt": {}, "commit": false, "phases": FREE},
	# GDD_v3 §5.2: «¿Dónde consigo…?» a Crane (gratis, sin límite, no pública: Crane no es canal)
	"ask_donde": {"args": {"char": TYPE_STRING, "item": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["visit"]},
	# GDD_v3 §5.4: cada salida es pieza -> lugar -> pieza; desde una visita la respuesta es «desde_casa»
	"go": {"args": {"place": TYPE_STRING, "area": TYPE_STRING, "seat": TYPE_INT}, "opt": {"area": "", "seat": 0}, "commit": true, "phases": ["desk", "visit"]},
	"slip": {"args": {"doc": TYPE_STRING, "noise": TYPE_STRING}, "opt": {"noise": ""}, "commit": true, "phases": ["visit"]},
	"order_copy": {"args": {"doc": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["visit"]},
	"ask": {"args": {"char": TYPE_STRING, "topic": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["visit"]},
	"assert": {"args": {"char": TYPE_STRING, "assertion": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["visit"]},
	"present": {"args": {"char": TYPE_STRING, "item": TYPE_DICTIONARY}, "opt": {}, "commit": true, "phases": ["visit"]},
	"pay": {"args": {"char": TYPE_STRING, "amount_d": TYPE_INT}, "opt": {}, "commit": true, "phases": ["visit"]},
	"task": {"args": {"char": TYPE_STRING, "task": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["visit"]},
	"leave": {"args": {}, "opt": {}, "commit": true, "phases": ["visit", "scene", "parklane", "epilogue"]},
	"end_slot": {"args": {}, "opt": {}, "commit": true, "phases": ["desk"]},
	"compose_ad": {"args": {"form": TYPE_STRING, "fields": TYPE_DICTIONARY}, "opt": {"fields": {}}, "commit": true, "phases": ["desk", "prologue"]},
	"compose_telegram": {"args": {"to": TYPE_STRING, "parts": TYPE_ARRAY}, "opt": {"parts": []}, "commit": true, "phases": ["desk"]},
	"compose_letter": {"args": {"to": TYPE_STRING, "parts": TYPE_ARRAY}, "opt": {"parts": []}, "commit": true, "phases": ["desk"]},
	"report_submit": {"args": {"mode": TYPE_STRING, "items": TYPE_ARRAY}, "opt": {"items": []}, "commit": true, "phases": ["night", "final_report"]},
	"sleep": {"args": {}, "opt": {}, "commit": true, "phases": ["prologue", "night"]},
	"confront": {"args": {"step": TYPE_INT, "item": TYPE_DICTIONARY}, "opt": {"item": {}}, "commit": true, "phases": ["confront"]},
	"night_choice": {"args": {"where": TYPE_STRING}, "opt": {}, "commit": true, "phases": ["night_choice"]},
	"publish_errata": {"args": {"yes": TYPE_BOOL}, "opt": {}, "commit": true, "phases": ["epilogue"]},
}

static func normalize(a: Dictionary) -> Dictionary:
	var src = J.ints(a)
	var t := String(src.get("t", ""))
	if not SPEC.has(t):
		return _sorted(src)
	var spec: Dictionary = SPEC[t]
	var out := {"t": t}
	var args: Dictionary = spec.args
	for k in args:
		var ty: int = args[k]
		if src.has(k) and src[k] != null:
			out[k] = _cast(src[k], ty)
		elif spec.opt.has(k):
			out[k] = _dup(spec.opt[k])
	return _sorted(out)

static func shape_error(a: Dictionary) -> String:
	var t := String(a.get("t", ""))
	if not SPEC.has(t):
		return "accion_desconocida"
	var spec: Dictionary = SPEC[t]
	var keys: Array = spec.args.keys()
	keys.sort()
	for k in keys:
		var ty: int = spec.args[k]
		if not a.has(k) or a[k] == null:
			if spec.opt.has(k):
				continue
			return "falta:" + k
		if not _type_ok(a[k], ty):
			return "tipo:" + k
	return ""

static func is_commit(t: String) -> bool:
	return SPEC.has(t) and bool(SPEC[t].commit)

static func phases_of(t: String) -> Array:
	return SPEC[t].phases if SPEC.has(t) else []

static func types() -> Array:
	var ks: Array = SPEC.keys()
	ks.sort()
	return ks

# ---------- helpers ----------
static func _type_ok(v, ty: int) -> bool:
	match ty:
		TYPE_INT:
			return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v))
		TYPE_FLOAT:
			return typeof(v) in [TYPE_INT, TYPE_FLOAT]
		TYPE_STRING:
			return typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]
		TYPE_BOOL:
			return typeof(v) == TYPE_BOOL
		TYPE_ARRAY:
			return typeof(v) == TYPE_ARRAY
		TYPE_DICTIONARY:
			return typeof(v) == TYPE_DICTIONARY
	return true

static func _cast(v, ty: int):
	match ty:
		TYPE_INT:
			if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
				return int(v)
			return v
		TYPE_FLOAT:
			if typeof(v) == TYPE_INT:
				return float(v)
			return v
		TYPE_STRING:
			if typeof(v) == TYPE_STRING_NAME:
				return String(v)
			return v
	return _sorted(J.ints(v)) if typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY] else v

static func _dup(v):
	if typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		return v.duplicate(true)
	return v

static func _sorted(v):
	if typeof(v) == TYPE_DICTIONARY:
		var ks: Array = v.keys()
		ks.sort()
		var d := {}
		for k in ks:
			d[String(k) if typeof(k) == TYPE_STRING_NAME else k] = _sorted(v[k])
		return d
	if typeof(v) == TYPE_ARRAY:
		var arr := []
		for x in v:
			arr.append(_sorted(x))
		return arr
	return v
