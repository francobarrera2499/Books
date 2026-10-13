# devtools/bots/bot_novato.gd — el novato (W3-BOTS; §9.3, GDD §15.5 T10/T24): sólo usa verbos ya enseñados
# (Tutorial.verbs_taught; un verbo no enseñado queda en stats.blocked y no se intenta), lee TODO lo legible en cada paso
# (documentos, líneas, exámenes del diorama) y estima minutos = palabras/180 × 1,3 por tramo (GDD §7.7; mide el Acto III).
# Practica antes de pagar: el primer día baja a la tienda de Crane (gratis) y allí pregunta, afirma y presenta; en una
# visita con costo pregunta una vez a cada personaje con diálogo. Investiga con el oráculo de rutas como el deductor,
# pero informa «Sin novedad» (no busca crédito ante Moran) y pasa la noche final en casa.
extends "res://devtools/bots/bot_base.gd"

var _shop_done := false
var _shop_practiced := false
var _asked := {}

func _init_bot() -> void:
	bot_name = "novato"
	only_taught = true
	reads_all = true
	emit_reads = true

func pol_desk_extra() -> void:
	if _shop_done:
		return
	var c: Dictionary = _c()
	if not Clock.place_open(repo, sim.st, HUB, SHOP, int(c.day), String(c.slot)).open:
		return
	_shop_done = true
	_go(HUB, SHOP)

func pol_in_visit() -> void:
	var v: Dictionary = sim.st.world.get("visit", {})
	var sc: Dictionary = sim.q_scene()
	if sc.is_empty():
		return
	var free := bool(v.get("free", false))
	for ch in sc.get("chars", []):
		var cid := String(ch.id)
		if free:
			if _shop_practiced:
				return
			_shop_practiced = true
			_practice_with(cid)
			return
		if _asked.has(cid) or not bool(ch.get("can_ask", false)) or repo.dialogue(cid).is_empty():
			continue
		var tps: Array = sim.q_topics(cid)
		if tps.is_empty():
			continue
		_asked[cid] = true
		act({"t": "ask", "char": cid, "topic": String(tps[0].get("id", "")) if typeof(tps[0]) == TYPE_DICTIONARY else String(tps[0])}, true)

# En la tienda (interlocutor gratuito): una pregunta, una afirmación y una presentación.
func _practice_with(cid: String) -> void:
	var tps: Array = sim.q_topics(cid)
	if not tps.is_empty():
		act({"t": "ask", "char": cid, "topic": String(tps[0].get("id", "")) if typeof(tps[0]) == TYPE_DICTIONARY else String(tps[0])}, true)
	var asr: Array = sim.q_assertions()
	if not asr.is_empty():
		act({"t": "assert", "char": cid, "assertion": String(asr[0].id)}, true)
	var ids := _clip_ids()
	if not ids.is_empty():
		act({"t": "present", "char": cid, "item": {"kind": "clip", "id": String(ids[0])}}, true)

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)

# ---------------------------------------------------------------- T24 (rampa)
# Verbos con gemelo gratuito: antes del primer uso con costo debe haber un uso ok guiado (prólogo) o gratuito de alguno
# de estos verbos (pasar en limpio <- practicar; preguntar/afirmar/presentar <- en la tienda de Crane; salir <- bajar a la
# tienda). Los demás verbos con costo (papeleta, informe, confrontación, elección nocturna, errata, fin de franja,
# anuncio…) no tienen versión gratuita: su primer uso debe ocurrir en el prólogo o ya enseñado en contexto por Tutorial
# (instructor dentro del mundo: ujier, chico de Pell, Crane…), es decir con taught = true en el registro.
const RAMP_TWINS := {"pass_clean": ["practice", "pass_clean"], "ask": ["ask"], "assert": ["assert"], "present": ["present"], "go": ["go"]}
# Pasos del prólogo (GDD_v2 §B.7) y los verbos que el novato debe tocar en cada uno (al menos uno ok de cada grupo, en
# fase prologue). La primera conclusión (juntar, hoja, conclusión, práctica) es del día 1: DAY1_TOUCH, antes de la
# primera confirmación (day1_violations).
const PROLOGUE_TOUCH := {"leer": ["read"], "recortar": ["clip_text", "clip_plate", "clip_measure"], "aviso": ["compose_ad"],
	"dormir": ["sleep"]}
const DAY1_TOUCH := {"juntar": ["link"], "hoja": ["folio_open"], "conclusión": ["entry_new"], "llenar": ["entry_set"],
	"pruebas": ["entry_support_add"], "practicar": ["practice"]}

# Violaciones de T24 sobre un registro de bot (lista de {t, ok, free, costly, taught, phase, tk}). [] = rampa cumplida.
static func ramp_violations(lg: Array) -> Array:
	var out: Array = []
	var touched := {}
	var first := {}
	for i in lg.size():
		var e: Dictionary = lg[i]
		if not bool(e.get("ok", false)):
			continue
		var t := String(e.t)
		var guided := String(e.get("phase", "")) == "prologue"
		var costly := bool(e.get("costly", false))
		if costly and not guided and not first.has(t):
			first[t] = i
			var twins: Array = RAMP_TWINS.get(t, [])
			if not twins.is_empty():
				var hit := false
				for tw in twins:
					if touched.has(tw):
						hit = true
				if not hit:
					out.append("%s: primer uso con costo en %s (tk %d) sin uso guiado o gratuito previo de %s" % [t, String(e.get("phase", "")), int(e.get("tk", 0)), str(twins)])
			elif not bool(e.get("taught", false)):
				out.append("%s: primer uso con costo en %s (tk %d) sin enseñanza previa en contexto" % [t, String(e.get("phase", "")), int(e.get("tk", 0))])
		if guided or not costly:
			touched[t] = true
	return out

# Pasos del prólogo que el registro no tocó (en fase prologue, ok).
static func prologue_missing(lg: Array) -> Array:
	var seen := {}
	for e in lg:
		if bool(e.get("ok", false)) and String(e.get("phase", "")) == "prologue":
			seen[String(e.t)] = true
	var out: Array = []
	for k in PROLOGUE_TOUCH:
		var hit := false
		for t in PROLOGUE_TOUCH[k]:
			if seen.has(t):
				hit = true
		if not hit:
			out.append(k)
	return out

# Primera conclusión del día 1: cada grupo de DAY1_TOUCH tocado (ok, fuera del prólogo) antes del primer pass_clean ok,
# y la práctica hecha el día 1. [] = cumplido (también si nunca confirma).
static func day1_violations(lg: Array) -> Array:
	var seen := {}
	var first_pass := -1
	var practice_day := -1
	for i in lg.size():
		var e: Dictionary = lg[i]
		if not bool(e.get("ok", false)):
			continue
		var t := String(e.t)
		if t == "pass_clean" and first_pass < 0:
			first_pass = i
		if first_pass < 0 and String(e.get("phase", "")) != "prologue":
			seen[t] = true
		if t == "practice" and practice_day < 0:
			practice_day = int(e.get("day", -1))
	var out: Array = []
	if first_pass >= 0:
		for k in DAY1_TOUCH:
			var hit := false
			for t in DAY1_TOUCH[k]:
				if seen.has(t):
					hit = true
			if not hit:
				out.append("%s: no antes de la primera confirmación" % k)
	if practice_day >= 0 and practice_day != 1:
		out.append("la práctica fue el día %d, no el 1" % practice_day)
	return out
