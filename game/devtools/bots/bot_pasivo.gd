# devtools/bots/bot_pasivo.gd — el pasivo (W3-BOTS; §9.3, T10): hace el prólogo (obligatorio) y después no investiga:
# no sale, no recorta, no asienta, informa «nada», calla en la confrontación. Debe terminar en F4.
extends "res://devtools/bots/bot_base.gd"

func _init_bot() -> void:
	bot_name = "pasivo"
	deduce = false
