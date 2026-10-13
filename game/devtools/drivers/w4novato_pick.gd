# devtools/drivers/w4novato_pick.gd — W4 playtest (diagnóstico): ¿qué objetos de la lámina del prólogo se pueden tocar
# con el mouse desde el encuadre inicial? Para cada nodo del diorama: su proyección, si está en pantalla y qué devuelve
# el pick ahí y en una espiral de 60 px (como un jugador que lo busca). Captura el encuadre y un acercamiento al pupitre.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4novpick res://devtools/drivers/w4novato_pick.gd --mute
extends RefCounted

func drive(tool, scene) -> void:
	await tool.frames(10)
	var shell = scene.get_node_or_null("Shell")
	var g = tool.root.get_node("Game")
	g.save_path = "user://saves/w4novato_pick.jsonl"
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await shell.new_game(7)
	for i in 240:
		await tool.frames(1)
		if shell.game_screen != null and shell.game_screen.idle():
			break
	await tool.create_timer(1.5).timeout
	await tool.snap("prologo")
	var w = shell.world
	var cam: Camera3D = w.camera()
	var idx: Dictionary = w.diorama.get_meta("nodes_index", {})
	var vs: Vector2 = tool.root.get_viewport().get_visible_rect().size
	print("PICK cámara pos=%s rot=%s fov=%s encuadre=%s" % [cam.global_position, cam.global_rotation_degrees, cam.fov, shell.game_screen.frame])
	for id in idx.keys():
		var b: Node3D = idx[id]
		var pr := cam.unproject_position(b.global_position)
		var on := Rect2(Vector2.ZERO, vs).has_point(pr) and not cam.is_position_behind(b.global_position)
		var at := String(w.pick(pr).get("id", ""))
		var found := Vector2(-1, -1)
		for r in range(0, 64, 4):
			for k in 16:
				var p := pr + Vector2.from_angle(TAU * k / 16.0) * float(r)
				if String(w.pick(p).get("id", "")) == String(id):
					found = p
					break
				if r == 0:
					break
			if found.x >= 0:
				break
		var size: Vector3 = b.get_meta("size", Vector3.ZERO)
		print("PICK %s proy=%s en_pantalla=%s pick_en_proy=%s alcanzable=%s tam=%s" % [id, pr.round(), on, at, found.round() if found.x >= 0 else "NO", size])
	var gs = shell.game_screen
	print("PICK chevrones izq=%s der=%s encuadres=%s salir=%s" % [gs._chev_l.visible, gs._chev_r.visible, str(gs.frames()), gs._leave_btn.visible])
	for f in ["escritorio", "ventana"]:
		gs.go_frame(f)
		await tool.create_timer(1.5).timeout
		await tool.snap("encuadre_" + f)
		for id in ["encargo", "concordancia", "tijera", "tomos", "recorte", "lupa", "estuche", "atril", "calendario", "tintero"]:
			if not idx.has(id):
				continue
			var b2: Node3D = idx[id]
			var pr2 := cam.unproject_position(b2.global_position)
			var found2 := Vector2(-1, -1)
			for r in range(0, 64, 4):
				for k in 16:
					var p2 := pr2 + Vector2.from_angle(TAU * k / 16.0) * float(r)
					if String(w.pick(p2).get("id", "")) == id:
						found2 = p2
						break
					if r == 0:
						break
				if found2.x >= 0:
					break
			print("PICK [%s] %s proy=%s pick_en_proy=%s alcanzable=%s" % [f, id, pr2.round(), String(w.pick(pr2).get("id", "")), found2.round() if found2.x >= 0 else "NO"])
	g.end_session()
