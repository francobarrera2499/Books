# W3-SHELL: arranque por línea de comandos (ARCHITECTURE §2.3: --new --seed --script --screen --data --save --fast --mute).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3shell_args res://devtools/drivers/w3shell_args.gd \
#     --new --fast --mute --seed=1894 --data=fixture --save=user://saves/w3shell_args.jsonl \
#     --script=res://tests/fixtures/w3shell/guion_dia1.jsonl --screen=map
# main.gd lee los mismos argumentos de usuario (ignora los de shot.gd). Espera la pantalla pedida y la captura.
extends RefCounted

func drive(tool, scene) -> void:
	var shell = scene.get_node_or_null("Shell")
	var g = scene.get_tree().root.get_node("Game")
	var opts: Dictionary = load("res://main.gd").parse_args(OS.get_cmdline_user_args())
	var want := String(opts.get("screen", "")).get_slice(":", 0)
	for i in 900:
		await tool.frames(1)
		if shell != null and shell.game_screen != null and shell.game_screen.idle() and (want == "" or want == "game" or shell.is_open(want) or (want == "place" and shell.game_screen.mode == "plate")):
			break
	await tool.frames(30)
	var c: Dictionary = g.sim.q_clock() if g.sim != null else {}
	print("W3SHELL ARGS screen=%s top=%s day=%s phase=%s acciones=%d" % [want, shell.top_kind() if shell != null else "", c.get("day", "?"), c.get("phase", "?"), g.sim.actions_log().size() if g.sim != null else -1])
	await tool.snap(want if want != "" else "game")
	g.end_session()
