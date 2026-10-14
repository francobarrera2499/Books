# devtools/drivers/v3pieza_floor.gd — REACCIONES-PIEZA (diagnóstico): desde cada punto del riel de la buhardilla, qué
# puntos del piso cerca de la ventana se ven (rayo de la cámara sin oclusor, dentro de cuadro y fuera de la columna del
# HUD arriba a la izquierda). Para ubicar las hojas del piso (variante techos) donde el jugador las vea.
#   ./godot.sh --headless -s devtools/shot.gd -- res://devtools/blank.tscn v3pf res://devtools/drivers/v3pieza_floor.gd
extends RefCounted

const PLC = preload("res://tests/fixtures/w2placesa/places_check.gd")
const DataRepo = preload("res://core/data/data_repo.gd")

func drive(tool, scene) -> void:
	var rp = DataRepo.load_dir("res://data")
	var pl: Dictionary = rp.place("L1")
	var sc := {"day": 4, "slot": "M", "variant": "techos"}
	for fid in ["escritorio", "estante", "puerta"]:
		var wr = await PLC._show(tool, pl, sc, fid)
		await tool.physics_frame
		var cam: Camera3D = wr.camera()
		var space := cam.get_world_3d().direct_space_state
		var vp := Rect2(Vector2.ZERO, Vector2(1600, 900))
		var line := ""
		for zi in range(0, 13):
			var z := -2.15 + 0.1 * zi
			line = "z=%.2f " % z
			for xi in range(0, 27):
				var x := -1.5 + 0.1 * xi
				var p := Vector3(x, 0.02, z)
				var ch := "."
				if not cam.is_position_behind(p):
					var sp := cam.unproject_position(p)
					if vp.grow(-30).has_point(sp) and not (sp.x < 270 and sp.y < 280):
						var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
						var h := space.intersect_ray(q)
						if h.is_empty() or cam.global_position.distance_to(h.position) >= cam.global_position.distance_to(p) - 0.03:
							ch = "O"
						else:
							ch = "x"
				line += ch
			print("V3PF %s %s" % [fid, line])
		print("V3PF %s columnas x=-1.5..1.1 de a 0,1" % fid)
	PLC.free_world()
