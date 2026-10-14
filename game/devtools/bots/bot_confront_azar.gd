# devtools/bots/bot_confront_azar.gd — acusador al azar (W3-BOTS; §9.3, GDD §8.8, §11 «Mostrarlo todo en la
# confrontación», T10/T18): juega como el deductor (también busca crédito ante Moran), pero en la confrontación del día
# 10 presenta en cada afirmación un recorte o asiento AL AZAR (nunca calla). Tres errores y el librero se va sin ofrecer
# la errata a medida. Nunca supera al deductor.
extends "res://devtools/bots/bot_deductor.gd"

func _init_bot() -> void:
	bot_name = "confront_azar"

func pol_confront(_step_n: int) -> Dictionary:
	var items: Array = []
	for cl in _clip_ids():
		items.append({"kind": "clip", "id": String(cl)})
	for h in (sim.q_dossier().get("inked", []) as Array) + (sim.q_dossier().get("open", []) as Array):
		items.append({"kind": "pregunta", "id": String(h.id)})
	if items.is_empty():
		return {}
	return rnd_pick(items, "confront")
