# devtools/bots/bot_sabelotodo.gd — el que leyó a Doyle (GDD_v3 §1.9, T10): sabe la RESPUESTA de cada pregunta (la del
# canon) pero no qué recortes la prueban: recorta todo lo legible (como la fuerza bruta) y prueba la respuesta correcta
# con dos recortes al azar de papeles distintos, hasta MAX_TRIES intentos por pregunta. «Saber no es probar»: T10 lo
# mide y lo registra, sin umbral (GDD_v3 §1.9: ≈ 195 intentos esperados, cero si no recortó lo necesario).
extends "res://devtools/bots/bot_base.gd"

const FB = preload("res://devtools/bots/bot_fuerza_bruta.gd")
const MAX_TRIES := 50

func _init_bot() -> void:
	bot_name = "sabelotodo"
	deduce = false
	value_mode = "random"
	max_attempts = MAX_TRIES

func pol_desk_extra() -> void:
	FB.clip_everything(self)
	FB.random_tries(self, MAX_TRIES, true)

func pol_in_visit() -> void:
	FB.clip_everything(self)
	var v: Dictionary = sim.st.world.get("visit", {})
	if WorldModel.place_needs_seat(repo, String(v.get("place", ""))):
		FB.random_slips(self)
		FB.clip_everything(self)

func pol_outing() -> Dictionary:
	return FB.random_outing(self)

func pol_confirm() -> Array:
	return []
