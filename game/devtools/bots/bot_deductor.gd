# devtools/bots/bot_deductor.gd — el deductor (§9.3, GDD §15.5 T10; GDD_v3 §2.4): oráculo de rutas ★ (Feasibility.plan,
# mínimo de salidas), hojas verificadas (Dossier.check) antes de pasar en limpio, crédito ante Moran (un informe 1–3 con
# una pregunta en tinta o un recorte «verdadero» que no entrega a Holmes) y errata a medida en el informe final (ofrecida por el librero al completar la
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
		# la errata a medida sólo si el expediente alcanza el mejor final (si no, el silencio rinde más: F3a > F3b)
		if bool(sim.q_report_status().get("offered_erratum", false)) and _ink_meets_best():
			return {"mode": "errata", "items": []}
		return {"mode": "nada", "items": []}
	if bool(sim.st.flags.get("moran_credito", false)):
		return {"mode": "nada", "items": []}
	var it := credit_item()
	if it.is_empty():
		return {"mode": "nada", "items": []}
	return {"mode": "items", "items": [it]}

# Un ítem que Moran lee como «verdadero» y nada más comprometedor (preguntas antes que recortes).
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
		if best.is_empty() or (String(best.item.kind) != "pregunta" and String(c.item.kind) == "pregunta") or (String(best.item.kind) == String(c.item.kind) and cats.size() < (best.cats as Array).size()):
			best = c
	return best.get("item", {})

# Condiciones de tinta (inked*, inked_count) del final de mejor rank, evaluadas sobre el estado actual.
func _ink_meets_best() -> bool:
	var best := {}
	for e in repo.endings().get("endings", []):
		if int(e.get("rank", 0)) > 0 and (best.is_empty() or int(e.rank) < int(best.rank)):
			best = e
	var conds: Array = []
	var c = best.get("cond", {})
	if typeof(c) == TYPE_DICTIONARY and c.has("all"):
		conds = c.all
	elif typeof(c) == TYPE_DICTIONARY:
		conds = [c]
	var Cond = load("res://core/util/cond.gd")
	for x in conds:
		if typeof(x) == TYPE_DICTIONARY and (x.has("inked") or x.has("inked_all") or x.has("inked_count")):
			if not bool(Cond.eval(x, {"st": sim.st, "repo": repo})):
				return false
	return true

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)

func pol_night_choice() -> String:
	return "baker_street"
