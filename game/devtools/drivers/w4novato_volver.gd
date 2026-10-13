# devtools/drivers/w4novato_volver.gd — W4 playtest (diagnóstico): «Volver = clic derecho o Esc» (GDD §14.2) en cada cosa
# que un novato abre en el prólogo y en el día 1 (data/ real, mouse real). Para cada caso: abrir, clic derecho, ¿cerró?;
# si no, Esc, ¿cerró? Salida «VOLVER <caso> clic_derecho=<sí|no> esc=<sí|no|->».
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4novvolver res://devtools/drivers/w4novato_volver.gd --mute
extends "res://devtools/drivers/w3int_flow.gd"

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	g.save_path = "user://saves/w4novato_volver.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	await shell.new_game(7)
	await _idle()
	await _wait(1.5)
	# 1. tijera sobre la lámina (C)
	await _case("tijera_3d", func(): await _key(KEY_C), func(): return gs().scissors_on)
	# 2. tarjeta de examen + acercamiento de cámara (clic en los tomos)
	await _case("examen", func(): await _click(_node_pos("tomos")), func(): return gs().exam.visible or shell.world.is_examining())
	# 3. cuaderno, libro mayor, mapa (atajos)
	await _case("cuaderno", func(): await _key(KEY_TAB), func(): return shell.is_open("notebook"))
	await _case("libro_mayor", func(): await _key(KEY_L), func(): return shell.is_open("ledger"))
	await _case("mapa", func(): await _key(KEY_M), func(): return shell.is_open("map"))
	await _case("bandeja", func(): await _click(_node_pos("bandeja")), func(): return gs().tray.visible)
	# 4. lector (desde los tomos) y lector con tijera
	await _case("lector", func():
		await _click(_node_pos("tomos"))
		await _wait(0.5)
		var links: Array = gs().exam.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
		if not links.is_empty():
			await _click(_c(links[0])), func(): return shell.reader_open())
	await _case("lector_tijera", func():
		await _click(_node_pos("tomos"))
		await _wait(0.5)
		var links2: Array = gs().exam.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
		if not links2.is_empty():
			await _click(_c(links2[0]))
			await _wait(0.5)
		if shell.reader_open():
			await _click(_c(shell.reader._b_tijera)), func(): return shell.reader_open())
	# 5. panel de escena (clic en Harris)
	await _case("escena", func(): await _click(gs().char_screen_pos("harris")), func(): return shell.is_open("scene"))
	print("VOLVER FIN")
	g.end_session()

func _case(name: String, open_fn: Callable, is_open: Callable) -> void:
	await _wait(0.4)
	await open_fn.call()
	await _wait(0.8)
	var was: bool = is_open.call()
	if not was:
		print("VOLVER %s no se abrió" % name)
		return
	await _snap(name + "_abierto")
	await _rclick(Vector2(800, 450) if name != "lector_tijera" else Vector2(1500, 450))
	await _wait(0.8)
	var after_r: bool = is_open.call()
	var esc := "-"
	if after_r:
		await _snap(name + "_tras_clic_derecho")
		await _key(KEY_ESCAPE)
		await _wait(0.8)
		esc = "no" if is_open.call() else "sí"
		if is_open.call():
			for _i in 3:
				await _key(KEY_ESCAPE)
				await _wait(0.5)
	print("VOLVER %s clic_derecho=%s esc=%s" % [name, "no" if after_r else "sí", esc])
	for _i in 4:
		if shell.top() == null and not gs().exam.visible and not shell.world.is_examining() and not gs().scissors_on and not shell.reader_open():
			break
		await _key(KEY_ESCAPE)
		await _wait(0.5)
	if shell.top_kind() == "options":
		await _key(KEY_ESCAPE)
		await _wait(0.5)

func _snap(name: String) -> void:
	_shot += 1
	await tool.snap("%02d_%s" % [_shot, name])
