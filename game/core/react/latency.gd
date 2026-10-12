# core/react/latency.gd — la distancia es la demora (GDD§9.3, ARCHITECTURE §5.3). Dueño: W2-REACT.
# due_tk(st, repo, rule, act_tk): D = día del acto (anuncio: día de publicación, el evento ad ya trae ese tk).
#   voz_a                  → amanecer de D+1 (schedule.voice_a.default_days); si ese día no hay correo (domingo), en mano
#   voz_b                  → schedule.voice_b[D] (tabla GDD§9.3; día 9 → 10.M en persona; sin entrada → -1, no hay)
#   fija {tk}              → tk (o disparador.tk)
#   inmediata              → act_tk (no pasa por la cola)
#   siguiente_salida       → (D+1).M: se resuelve en la primera salida (go) de ese día o a la noche (M1, M2)
#   siguiente_comunicacion → act_tk: su línea espera la próxima nota de Pell/«H.» o M7/M8 (MoranAgent.next_lines)
#   dias {n}               → amanecer de D+n
# how_for: cómo llega un documento (correo | en_mano | mostrador_crane | columna | noticias).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const RDB = preload("res://core/react/reaction_db.gd")

static func due_tk(st, repo, rule: Dictionary, act_tk: int) -> int:
	var lat = rule.get("latencia", {})
	if typeof(lat) != TYPE_DICTIONARY:
		return -1
	var d := TimeKey.day_of(act_tk)
	match String(lat.get("tipo", "")):
		"voz_a":
			var n := 1
			if repo != null:
				n = int(repo.schedule().get("voice_a", {}).get("default_days", 1))
			return TimeKey.tk(d + maxi(1, n), "dawn")
		"voz_b":
			return voice_b_tk(repo, d)
		"fija":
			var f := TimeKey.of(lat.get("tk", RDB.disp(rule).get("tk", "")))
			return f if f >= 0 else act_tk
		"inmediata", "siguiente_comunicacion":
			return act_tk
		"siguiente_salida":
			return TimeKey.tk(d + 1, "M")
		"dias":
			return TimeKey.tk(d + maxi(1, int(lat.get("n", 1))), "dawn")
	return -1

static func voice_b_tk(repo, act_day: int) -> int:
	if repo == null:
		return -1
	var vb = repo.schedule().get("voice_b", {})
	if typeof(vb) != TYPE_DICTIONARY or not vb.has(str(act_day)):
		return -1
	return TimeKey.of(vb[str(act_day)])

static func voice_b_day(repo, act_day: int) -> int:
	var t := voice_b_tk(repo, act_day)
	return -1 if t < 0 else TimeKey.day_of(t)

# ¿La voz B contesta algún día en `day`? (destinos de schedule.voice_b: con la tabla de GDD§9.3, 4, 5, 7, 8 y 10; nunca
# el domingo 6 ni el miércoles 9, «el viajero está en camino»). Sin tabla → true (no bloquea).
static func voice_b_delivers_on(repo, day: int) -> bool:
	if repo == null:
		return true
	var vb = repo.schedule().get("voice_b", {})
	if typeof(vb) != TYPE_DICTIONARY or vb.is_empty():
		return true
	for k in vb:
		var t := TimeKey.of(vb[k])
		if t >= 0 and TimeKey.day_of(t) == day:
			return true
	return false

# Día de entrega con correo (schedule.days[].mail). Sin fila → true (no bloquea).
static func has_mail(repo, day: int) -> bool:
	var row := RDB.day_row(repo, day)
	return true if row.is_empty() else bool(row.get("mail", false))

static func has_times(repo, day: int) -> bool:
	var row := RDB.day_row(repo, day)
	return false if row.is_empty() else bool(row.get("times", false))

# Cómo se entrega el documento de una instancia (eff = efecto documental elegido).
static func how_for(st, repo, rule: Dictionary, inst: Dictionary, eff: Dictionary) -> String:
	var op := String(eff.get("op", ""))
	if op == "columna":
		return "columna"
	if op == "noticia":
		return "noticias"
	# entrega explícita; "correo" es la regla por defecto (sin correo ese día —domingo—, la voz A llega en mano: HC03)
	if eff.has("entrega") and String(eff.entrega) != "correo":
		return String(eff.entrega)
	if bool(inst.get("en_persona", false)):
		return "mostrador_crane"
	if RDB.lado(rule) == "moran":
		return "en_mano"
	var day := TimeKey.day_of(int(inst.get("due_tk", 0)))
	if not has_mail(repo, day):
		if RDB.voice(rule) == "A" and repo != null:
			return String(repo.schedule().get("voice_a", {}).get("sunday", "en_mano"))
		return "en_mano"
	return "correo"
