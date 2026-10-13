# devtools/bots/bot_solo_bm.gd — sólo Sala de Lectura (W3-BOTS; §9.3, GDD §11 «Investigar sólo en la Sala de Lectura»,
# T10): todas sus salidas son a la Sala (L2), con sus tres papeletas por visita; fuera de eso, sólo lo que tiene en casa
# (buhardilla, tomos, la tienda de Crane, el correo, el diario, la columna). Elige para cada conclusión la ruta (★ si hay)
# que pueda completarse sin otros lugares; las que piden campo (C9, C13…) quedan sin asiento. Estilo válido, no atajo:
# igual provoca a Holmes (K-BM) y nunca supera al deductor.
extends "res://devtools/bots/bot_base.gd"

const HOME := ["L1", "L2"]

func _init_bot() -> void:
	bot_name = "solo_bm"
	fillers = false

func pol_outing() -> Dictionary:
	var c: Dictionary = _c()
	if Clock.place_open(repo, sim.st, "L2", "sala", int(c.day), String(c.slot)).open:
		return {"place": "L2", "area": "sala"}
	return {}

func _replan() -> void:
	itinerary = {}
	for cid in _need():
		var best := {}
		for r in RouteDB.routes(repo, String(cid)):
			if not (r.get("missing", []) as Array).is_empty() or not bool(r.get("eligible", false)) or not _home_route(r):
				continue
			if best.is_empty() or (bool(r.get("star", false)) and not bool(best.get("star", false))) \
					or (bool(r.get("star", false)) == bool(best.get("star", false)) and (r.frags as Array).size() < (best.frags as Array).size()):
				best = r
		if best.is_empty():
			waits[String(cid)] = "ninguna ruta sólo con la Sala de Lectura y la casa"
		else:
			_set_target(String(cid), String(best.id))

# ¿Cada fragmento tiene alguna fuente en casa (sin salida) o en la Sala de Lectura?
func _home_route(r: Dictionary) -> bool:
	for f in r.get("frags", []):
		var ok := false
		for sk in f.get("srcs", []):
			var u: Dictionary = Av.src(repo, String(sk)).get("unit", {})
			if u.is_empty() or HOME.has(String(u.get("place", ""))):
				ok = true
				break
		if not ok:
			return false
	return true

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)
