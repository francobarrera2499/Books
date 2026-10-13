# devtools/bots/bot_recorta_todo.gd — recorta todo (W3-BOTS; §9.3, GDD §11 «Recortar todo», T4/T10): sigue el
# itinerario del oráculo, pero NO recorta tramos a medida: hace los recortes legales máximos (oración entera, ≤40
# palabras) de todo lo legible, cada nodo del diorama por separado y cada línea dicha, y arma los asientos sólo con lo
# que esos recortes heredan. Prueba que recortarlo todo no da ventaja: sólo ruido propio (nunca supera al deductor).
extends "res://devtools/bots/bot_base.gd"

const FB = preload("res://devtools/bots/bot_fuerza_bruta.gd")

var _by_view := {}   # vista (o "line|<uid>", o lámina) -> [ids de recorte]

func _init_bot() -> void:
	bot_name = "recorta_todo"

func pol_desk_extra() -> void:
	_everything()

func pol_in_visit() -> void:
	_everything()

func _everything() -> void:
	var made: Dictionary = FB.clip_everything(self)
	for k in made:
		if not _by_view.has(k):
			_by_view[k] = []
		_by_view[k].append_array(made[k])

func _pick(ids: Array, want: Array) -> String:
	for id in ids:
		if not want.is_empty() and _clip_has_any(String(id), want):
			return String(id)
	return ""

func _try_doc(f: Dictionary) -> String:
	var view := String(f.copy)
	if view == "" or sim.q_view(view).is_empty():
		return ""
	_everything()
	return _pick(_by_view.get(view, []), f.want)

# Rastros entregados y avisos impresos (base: tramo exacto) también desde los recortes máximos de su vista.
func _clip_tagged(view: String, want: Array, _doc_filter := "") -> String:
	if sim.q_view(view).is_empty():
		return ""
	_everything()
	return _pick(_by_view.get(view, []), want)

func _try_line(f: Dictionary) -> String:
	for uid in _line_uids(f):
		var key := "line|" + String(uid)
		if not _by_view.has(key):
			_by_view[key] = []
			var p: Dictionary = sim.q_line(String(uid)).get("parsed", {})
			for s in ClipRules.max_legal_clips(p):
				var r := act({"t": "clip_text", "src": {"kind": "line", "ref": String(uid)}, "from": int(s.from), "len": int(s.to) - int(s.from)}, true)
				if String(r.get("clip", "")) != "":
					_by_view[key].append(String(r.clip))
		var id := _pick(_by_view[key], f.want)
		if id != "":
			return id
	return ""
