# devtools/bots/bot_informa_todo.gd — informa todo (W3-BOTS; §9.3, GDD §11 «Contarle todo al patrón», §7.3, T10):
# investiga como el deductor y en CADA informe (1–3 y final) entrega a Moran los tres elementos más reveladores que tiene
# (preguntas antes que recortes; los que Moran lee como regreso, paradero, Baker Street, Camden, su propio nombre…).
# Dispara M1–M5 y termina en F2 si el informe final lleva datos de regreso/lugar/Camden. Nunca supera al deductor.
extends "res://devtools/bots/bot_base.gd"

const WEIGHT := {"holmes_vive": 3, "regreso_jueves": 5, "baker_street": 5, "camden": 5, "paradero_extranjero": 4,
	"watson_privado": 3, "moran_autor": 3, "verdadero": 1, "original_p": 2, "falso_verificable": 1, "respuesta_s": 1}

func _init_bot() -> void:
	bot_name = "informa_todo"

func pol_report(_n: int, _final: bool) -> Dictionary:
	var scored: Array = []
	for c in _report_candidates():
		var s := 0
		for ct in c.cats:
			s += int(WEIGHT.get(String(ct), 0))
		if String(c.item.kind) == "pregunta":
			s += 1
		if s > 0:
			scored.append({"item": c.item, "s": s})
	scored.sort_custom(func(a, b): return int(a.s) > int(b.s) or (int(a.s) == int(b.s) and String(a.item.id) < String(b.item.id)))
	var items: Array = []
	for x in scored.slice(0, 3):
		items.append(x.item)
	if items.is_empty():
		return {"mode": "nada", "items": []}
	return {"mode": "items", "items": items}

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)
