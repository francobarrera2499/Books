# core/sim/endings.gd — finales, variantes del epílogo y lápiz azul (§4.15, §5.2, §5.7; GDD §12). Dueño: W2-SCENES.
# evaluate: recorre endings.json por `order` (GDD §12.1: F1, F4, F2, F3a, F3b) y elige el primero cuya cond (DSL §4.18)
#   se cumple; las variantes son acumulables (todas las que se cumplen). rank (1 = mejor) sale de los datos
#   (§12.1.2: F1=1, F3a=2, F3b=3, F2=4, F4=5). Puro: no muta (los sellos ya no cambian tras el informe final).
#   -> {ending, rank, name, card, card_base, card_adds:[], scene, variants:[{id, card_add?, epilogue?}], epilogue:[ids]}
# freeze: guarda evaluate() en st.scenes.ending (W2-SIM lo llama tras despachar el evento del informe final);
#   result(): lo congelado si existe, si no evaluate().
# blue_pencil (post-créditos): por cada obligatoria sin sellar, blue_pencil.missing; por cada asiento a lápiz con
#   which_conclusion != "" y entry_ok falso, blue_pencil.wrong. -> [{kind:"missing", cid, note} | {kind:"wrong", entry, cid, note}]
# Lee st.ded.entries/sealed (forma §5.2) sólo para enumerar; usa Validator para decidir.
extends RefCounted

const Deps = preload("res://core/scenes/deps.gd")
const Cond = preload("res://core/util/cond.gd")

static func evaluate(st, repo) -> Dictionary:
	var data: Dictionary = repo.endings()
	var ends: Array = []
	for e in data.get("endings", []):
		if typeof(e) == TYPE_DICTIONARY:
			ends.append(e)
	ends.sort_custom(func(x, y): return int(x.get("order", 0)) < int(y.get("order", 0)) or (int(x.get("order", 0)) == int(y.get("order", 0)) and String(x.get("id", "")) < String(y.get("id", ""))))
	var ctx := {"st": st, "repo": repo}
	var chosen := {}
	for e in ends:
		if Cond.eval(e.get("cond", {}), ctx):
			chosen = e
			break
	var variants: Array = []
	var adds: Array = []
	var epi: Array = []
	for v in data.get("variants", []):
		if typeof(v) != TYPE_DICTIONARY or not Cond.eval(v.get("cond", {}), ctx):
			continue
		var vv := {"id": String(v.get("id", ""))}
		if v.has("card_add"):
			vv["card_add"] = String(v.card_add)
			adds.append(String(v.card_add))
		if v.has("epilogue"):
			vv["epilogue"] = String(v.epilogue)
			epi.append(String(v.epilogue))
		variants.append(vv)
	var base := String(chosen.get("card", ""))
	var card := base
	for a in adds:
		card = (card + " " + a) if card != "" else a
	return {"ending": String(chosen.get("id", "")), "rank": int(chosen.get("rank", 0)), "name": String(chosen.get("name", "")),
		"card": card, "card_base": base, "card_adds": adds, "scene": String(chosen.get("scene", "")), "variants": variants,
		"epilogue": epi}

static func blue_pencil(st, repo) -> Array:
	var out: Array = []
	var sealed := Deps.sealed(st)
	for cid in repo.conclusions_meta().get("mandatory", []):
		if not sealed.has(String(cid)):
			out.append({"kind": "missing", "cid": String(cid), "note": String(repo.conclusion(String(cid)).get("blue_pencil", {}).get("missing", ""))})
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var entries: Dictionary = ded.get("entries", {})
	var ids: Array = entries.keys()
	ids.sort()
	for eid in ids:
		var e = entries[eid]
		if typeof(e) != TYPE_DICTIONARY or String(e.get("ink", "lapiz")) != "lapiz":
			continue
		var cid := String(Deps.validator().which_conclusion(repo, e, sealed))
		if cid == "":
			continue
		var r: Dictionary = Deps.validator().entry_ok(st, repo, String(eid))
		if bool(r.get("ok", false)):
			continue
		out.append({"kind": "wrong", "entry": String(eid), "cid": cid, "note": String(repo.conclusion(cid).get("blue_pencil", {}).get("wrong", ""))})
	return out

# ---------------- extensiones ----------------
static func freeze(st, repo) -> Dictionary:
	var r := evaluate(st, repo)
	Deps.ensure(st)["ending"] = r
	return r

static func result(st, repo) -> Dictionary:
	var fr = Deps.sc(st, "ending")
	if typeof(fr) == TYPE_DICTIONARY and not fr.is_empty():
		return fr.duplicate(true)
	return evaluate(st, repo)

# Datos del epílogo (W4-EPILOGUE): final, variantes y flags que lo modulan.
static func epilogue(st, repo) -> Dictionary:
	var r := result(st, repo)
	var f := Deps.flags(st)
	return {"ending": r.ending, "rank": r.rank, "card": r.card, "variants": r.variants, "epilogue": r.epilogue,
		"noche_final": String(f.get("noche_final", "")), "publica_errata": bool(f.get("publica_errata", false)),
		"confront_estado": String(f.get("confront_estado", "")), "informe_final": String(f.get("informe_final", ""))}
