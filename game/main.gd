# main.gd — arranque (ARCHITECTURE §2.3). Dueño: W3-SHELL. main.tscn = Node con este script (única escena del juego).
# Lee los argumentos de usuario (tras «--») y crea la Shell (ui/shell.gd), que posee capas, mundo y pantallas.
#   --new · --continue · --seed=N · --script=res://….jsonl (aplica acciones en orden con Game.act, para capturas) ·
#   --screen=<title|game|reader:D05|notebook|ledger|map|place:L4[.area]|epilogue> · --fast (sin fundidos ni esperas)
# Extensiones (desarrollo): --data=fixture|<ruta> (dataset: «fixture» = data/ estructural + tests/fixtures/integ, como
#   test_i_integration) · --save=<ruta> (registro de partida aparte) · --mute (sin sonido; capturas y tests).
# Las opciones del jugador (user://opciones.cfg) se aplican antes de la primera pantalla.
extends Node

const Shell = preload("res://ui/shell.gd")
const Options = preload("res://ui/menus/options.gd")

var shell: Node = null

func _ready() -> void:
	var opts := parse_args(OS.get_cmdline_user_args())
	Options.apply_saved()
	shell = Shell.new()
	add_child(shell)
	shell.boot.call_deferred(opts)

static func parse_args(args) -> Dictionary:
	var o := {"new": false, "continue": false, "seed": 0, "script": "", "screen": "", "fast": false, "data": "", "save": "", "mute": false}
	for a0 in args:
		var a := String(a0)
		if a == "--new":
			o["new"] = true
		elif a == "--continue":
			o["continue"] = true
		elif a == "--fast":
			o.fast = true
		elif a == "--mute":
			o.mute = true
		elif a.begins_with("--seed="):
			o.seed = a.substr(7).to_int()
		elif a.begins_with("--script="):
			o.script = a.substr(9)
		elif a.begins_with("--screen="):
			o.screen = a.substr(9)
		elif a.begins_with("--data="):
			o.data = a.substr(7)
		elif a.begins_with("--save="):
			o.save = a.substr(7)
	return o
