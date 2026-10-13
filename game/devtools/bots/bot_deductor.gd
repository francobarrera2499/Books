# devtools/bots/bot_deductor.gd — el deductor (W3-BOTS; §9.3, GDD §15.5 T10): oráculo de rutas ★ (Feasibility.plan,
# mínimo de salidas), asientos verificados antes de pasar en limpio, crédito ante Moran (un informe 1–3 con un asiento
# «verdadero» que no entrega a Holmes) y errata a medida en el informe final (ofrecida por el librero al completar la
# confrontación con los cuatro grupos —conf_cover junta de fuentes gratuitas un recorte por grupo refutador que sus
# rutas no traigan—; la vía de Mycroft, HB12, la ejercita bot_mycroft_azar). Es la cota superior de
# T10: ningún bot debe superar su rank.
extends "res://devtools/bots/bot_base.gd"

const SAFE_BAD := ["holmes_vive", "regreso_jueves", "baker_street", "camden", "paradero_extranjero", "original_p",
	"watson_privado", "falso_verificable", "respuesta_s"]

func _init_bot() -> void:
	bot_name = "deductor"
	conf_cover = true   # material para las cuatro afirmaciones (errata a medida del librero)

func pol_report(n: int, final: bool) -> Dictionary:
	if final:
		if bool(sim.q_report_status().get("offered_erratum", false)):
			return {"mode": "errata", "items": []}
		return {"mode": "nada", "items": []}
	if bool(sim.st.flags.get("moran_credito", false)):
		return {"mode": "nada", "items": []}
	var it := credit_item()
	if it.is_empty():
		return {"mode": "nada", "items": []}
	return {"mode": "items", "items": [it]}

# Un ítem que Moran lee como «verdadero» y nada más comprometedor (asientos antes que recortes).
func credit_item() -> Dictionary:
	var best := {}
	for c in _report_candidates():
		var cats: Array = c.cats
		if not cats.has("verdadero"):
			continue
		var bad := false
		for b in SAFE_BAD:
			if cats.has(b):
				bad = true
		if bad:
			continue
		if best.is_empty() or (String(best.item.kind) != "entry" and String(c.item.kind) == "entry") or (String(best.item.kind) == String(c.item.kind) and cats.size() < (best.cats as Array).size()):
			best = c
	return best.get("item", {})

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)

func pol_night_choice() -> String:
	return "baker_street"
