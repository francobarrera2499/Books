# devtools/bots/bot_cebo.gd — cebo diario (W3-BOTS; §9.3, GDD §11 «Cebar a Holmes sin parar», Ley 2, T10): investiga
# como el deductor y, además, pone un anuncio-cebo CADA día que la oficina lo admite (franja M o T): «A propósito de
# [fuente]: [afirmación]» con una afirmación de cebo distinta cada día y, desde que existe, «Al corresponsal S.». Ejercita
# los contadores por tema (dos verdades, una falsa, silencio), las respuestas de voz B, la columna que lee Moran (M8, M11)
# y la protección de rutas del director. Informa «Sin novedad». No debe superar al deductor.
extends "res://devtools/bots/bot_base.gd"

var _ad_day := -1

func _init_bot() -> void:
	bot_name = "cebo"

func pol_desk_extra() -> void:
	var c: Dictionary = _c()
	var day := int(c.day)
	if _ad_day == day or not ["M", "T"].has(String(c.slot)):
		return
	var order := ["al_corresponsal", "a_proposito"] if day % 2 == 0 else ["a_proposito", "al_corresponsal"]
	for form in order:
		var fields := _bait_fields(String(form), day)
		if fields.is_empty():
			continue
		var r := act({"t": "compose_ad", "form": String(form), "fields": fields}, true)
		if bool(r.get("ok", false)):
			stats["ads"] = int(stats.get("ads", 0)) + 1
			_ad_day = day
			return
		if ["uno_por_dia", "oficina_cerrada"].has(String(r.get("err", ""))):
			_ad_day = day
			return
	_ad_day = day

# Campos de la forma: la afirmación de cebo rota con el día; la fuente es un documento indexado.
func _bait_fields(form: String, day: int) -> Dictionary:
	var out := {}
	for f in Composers.forms(repo):
		if String(f.get("id", "")) != form:
			continue
		for slot in _sorted((f.get("slots", {}) as Dictionary).keys()):
			var opts := Composers.options(sim.st, repo, form, String(slot))
			var bait: Array = opts.filter(func(o): return String(o.id).begins_with("as.") and String(o.id) != "as.vive")
			var pool: Array = bait if not bait.is_empty() else opts
			if pool.is_empty():
				return {}
			out[String(slot)] = String(pool[day % pool.size()].id)
	return out

func pol_confront(step_n: int) -> Dictionary:
	return _confront_item(step_n)
