# devtools/bots/bot_pesca.gd — la pesca (§9.3; GDD_v3 §1.9 «riesgo aceptado», T10): pruebas correctas (el oráculo de
# rutas junta los dos recortes de una ruta ★, como el deductor), pero la RESPUESTA AL AZAR entre las opciones del índice;
# si «Algo no cierra.», sortea otra. Con las pruebas correctas, adivinar cuesta ≤ A intentos (GDD_v3 §1.9): se mide, sin
# umbral.
extends "res://devtools/bots/bot_base.gd"

func _init_bot() -> void:
	bot_name = "pesca"
	value_mode = "random"
	fillers = false

func pol_confirm() -> Array:
	var out: Array = []
	for q in _sorted(sheet_of.keys()):
		if Dossier.is_open(sim.st, String(q)):
			out.append(String(q))
	return out
