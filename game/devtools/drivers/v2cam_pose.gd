# Calibración de la vista general (CÁMARA v2): POSE='{"pos":[..],"look":[..],"fov":58,"yaw":90,"pitch":14}' y AREA.
# Captura la general a yaw 0, +límite y −límite (con el look por defecto) y mide en px lo usable del escritorio.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v2pose res://devtools/drivers/v2cam_pose.gd
extends RefCounted
const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")
const RIG = preload("res://world/camera_rig.gd")
func drive(tool, _scene) -> void:
	tool.root.size = Vector2i(1600, 900)
	var area := OS.get_environment("AREA")
	if area == "": area = "buhardilla"
	var pose = JSON.parse_string(OS.get_environment("POSE")) if OS.get_environment("POSE") != "" else null
	if pose is Dictionary:
		RIG.cfg_all()
		RIG._cfg_all["L1." + area]["overview"] = pose
	var wr = WR.new()
	tool.root.add_child(wr)
	wr.set_fast(true)
	wr.hover_enabled = false
	wr.show_hub("general" if area == "buhardilla" else "mostrador", "M")
	await tool.frames(8)
	if area != "buhardilla":
		wr.rig.go_overview(true)
		await tool.frames(4)
	wr.set_usable({"n:cuaderno": true, "n:tintero": true, "n:bandeja": true, "n:calendario": true, "n:libro_mayor": true, "n:tijera": true, "n:mapa": true, "n:pliegos": true, "n:sello": true, "n:puerta": true, "n:cama": true}, {})
	await tool.frames(4)
	var lim: Vector2 = wr.rig.limits()
	for y in [0.0, lim.x, -lim.x]:
		wr.rig.yaw_t = y; wr.rig.yaw_off = y; wr.rig.pitch_t = 0; wr.rig.pitch_off = 0; wr.rig._apply()
		wr._update_cutaway(true)
		await tool.frames(4)
		await tool.snap("%s_yaw%d" % [area, int(y)])
		var cam: Camera3D = wr.camera()
		var seen: Array = []
		for nid in ["cuaderno", "tintero", "bandeja", "calendario", "libro_mayor", "tijera", "mapa", "pliegos", "puerta", "cama", "estante", "mostrador", "libro_ventas", "escalera_tienda", "puerta_calle", "escaparate"]:
			var b = wr.node_body(nid)
			if b == null: continue
			var r: Rect2 = RC.screen_rect(cam, b)
			var vis := r.get_area() > 0.0 and Rect2(0, 0, 1600, 900).intersects(r)
			var sp := cam.unproject_position(b.global_position) if not cam.is_position_behind(b.global_position) else Vector2(-1, -1)
			var pk: String = str(wr.pick(sp).get("id", "")) if sp.x >= 0 else ""
			if vis: seen.append("%s %dx%d%s" % [nid, int(r.size.x), int(r.size.y), "" if pk == nid else "(tapado:%s)" % pk])
		print("POSE yaw %d: %s" % [int(y), ", ".join(seen)])
