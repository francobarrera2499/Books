# devtools/bots/bot_pesca.gd — la pesca (W3-BOTS; §9.3, GDD §8.9, T10): fundamentos correctos (el oráculo de rutas
# junta los recortes de una ruta ★ y arma el «según» por grupo, como el deductor), pero VALORES AL AZAR entre los
# candidatos aceptables del índice o de la lista cerrada. Pasa en limpio en cada franja un lote al azar de asientos de
# conclusiones distintas sin sellar y, si el sello cae seco, vuelve a sortear los valores de esos asientos (no sabe cuál
# falló). Presupuesto de T10: sellar C6, C7 y C10 en la misma partida con probabilidad ≤ 5 %.
extends "res://devtools/bots/bot_base.gd"

func _init_bot() -> void:
	bot_name = "pesca"
	value_mode = "random"
	fillers = false
