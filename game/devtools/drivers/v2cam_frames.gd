# Capturas de cada encuadre de un lugar/área en su pose base (CÁMARA v2): PLACE=L4 AREA=consulta.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v2fr res://devtools/drivers/v2cam_frames.gd
extends RefCounted
const WR = preload("res://world/world_root.gd")
func drive(tool, _scene) -> void:
	tool.root.size = Vector2i(1600, 900)
	var pid := OS.get_environment("PLACE")
	var area := OS.get_environment("AREA")
	var repo = tool.root.get_node("Data").repo()
	var pl: Dictionary = repo.place(pid)
	if pl.is_empty(): pl = repo.plate(pid)
	var ids: Array = []
	for n in pl.nodes:
		var a := str(n.get("area", "*"))
		if a == "*" or area == "*" or a == area: ids.append(str(n.id))
	var wr = WR.new()
	tool.root.add_child(wr)
	wr.set_fast(true)
	wr.hover_enabled = false
	wr.show_plate({"id": "PL.%s.3.M" % pid, "place": pid, "area": area, "day": 3, "slot": "M", "variant": "", "nodes": ids, "chars": [], "silhouettes": []}, pl)
	await tool.frames(8)
	for f in wr.frames():
		wr.rig.set_frame(f, true)
		wr._update_cutaway(true)
		await tool.frames(4)
		await tool.snap("%s_%s_%s" % [pid, area, f])
		print("FR %s yaw %s pitch %s cam %s" % [f, wr.rig.limits().x, wr.rig.limits().y, wr.camera().global_position])
		if OS.get_environment("LIMITS") != "":
			for sg in [1, -1]:
				wr.rig.look_now(wr.rig.limits().x * sg, 0.0)
				wr._update_cutaway(true)
				await tool.frames(4)
				await tool.snap("%s_%s_%s_%s" % [pid, area, f, "izq" if sg > 0 else "der"])
				print("FR   %s yaw %.1f cam %s" % [f, wr.rig.yaw_off, wr.camera().global_position])
				wr.rig.set_frame(f, true)
