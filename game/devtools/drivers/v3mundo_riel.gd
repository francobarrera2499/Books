# devtools/drivers/v3mundo_riel.gd — UI-MUNDO (GDD_v3 §6.6): calibración del riel de la cámara. Captura cada punto del
# riel de la buhardilla y de la tienda (y, con MEDIOS=1, puntos intermedios del parámetro) y lista qué nodos se tocan
# desde cada uno. Sin juego (WorldRoot suelto sobre data/ real, hub con su variante por defecto).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3riel res://devtools/drivers/v3mundo_riel.gd
# AREAS (env, coma): buhardilla,tienda (por defecto ambas). PLACE=L4 AREA=consulta: un lugar (riel automático).
extends RefCounted

const WR = preload("res://world/world_root.gd")

func _touch(wr, ids: Array) -> Array:
	var cam: Camera3D = wr.camera()
	var out: Array = []
	for nid in ids:
		var b: Node3D = wr.node_body(nid)
		if b == null or wr.excluded_rids().has((b as CollisionObject3D).get_rid()): continue
		var s: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
		for off in [Vector3.ZERO, Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.3, 0, 0), Vector3(-s.x * 0.3, 0, 0), Vector3(0, -s.y * 0.3, 0)]:
			var p: Vector3 = b.global_position + off
			if cam.is_position_behind(p): continue
			var sp := cam.unproject_position(p)
			if not Rect2(20, 20, 1560, 860).has_point(sp): continue
			if str(wr.pick(sp).get("id", "")) == str(nid):
				out.append(str(nid))
				break
	return out

func drive(tool, _scene) -> void:
	tool.root.size = Vector2i(1600, 900)
	var medios := OS.get_environment("MEDIOS") == "1"
	var place := OS.get_environment("PLACE")
	var wr = WR.new()
	tool.root.add_child(wr)
	wr.set_fast(true)
	wr.hover_enabled = false
	var jobs: Array = []
	if place != "":
		jobs.append([place, OS.get_environment("AREA")])
	else:
		var areas := OS.get_environment("AREAS")
		for a in (areas.split(",") if areas != "" else PackedStringArray(["buhardilla", "tienda"])):
			jobs.append(["L1", a])
	for j in jobs:
		var pid := String(j[0])
		var area := String(j[1])
		if pid == "L1":
			wr.show_hub("general" if area == "buhardilla" else "mostrador", "M")
		else:
			var r = load("res://core/data/data_repo.gd").load_dir("res://data")
			var pl: Dictionary = r.place(pid)
			if pl.is_empty(): pl = r.plate(pid)
			var ids0: Array = []
			for n in pl.get("nodes", []):
				var na := str(n.get("area", "*"))
				if area == "" or na == "*" or na == area: ids0.append(str(n.id))
			wr.show_plate({"id": "PL." + pid, "place": pid, "area": area if area != "" else "*", "day": 3, "slot": "M", "variant": "", "nodes": ids0, "chars": [], "silhouettes": []}, pl)
		await tool.frames(6)
		var ids: Array = (wr.diorama.get_meta("nodes_index") as Dictionary).keys()
		var rig = wr.rig
		print("RIEL %s.%s cyclic=%s s=[%.0f, %.0f] puntos=%s" % [pid, area, str(rig.cyclic), rig.s_min, rig.s_max, str(rig.frame_ids())])
		var samples: Array = []
		for k in rig.rail.size():
			samples.append([str(rig.rail[k].id), float(rig.rail[k].s)])
			if medios:
				var s0 := float(rig.rail[k].s)
				var s1 := float(rig.rail[k + 1].s) if k + 1 < rig.rail.size() else (s0 + 360.0 - (s0 - float(rig.rail[0].s)) if rig.cyclic else s0 + 20.0)
				samples.append(["%s_medio" % str(rig.rail[k].id), (s0 + s1) * 0.5])
		for smp in samples:
			rig.yaw_t = float(smp[1]); rig.yaw_off = float(smp[1]); rig.pitch_t = 0.0; rig.pitch_off = 0.0
			rig._apply()
			wr._update_cutaway(true)
			await tool.frames(4)
			var cam: Camera3D = wr.camera()
			print("  %s s=%.0f pos=%s h=%.1f fov=%.1f toca: %s" % [smp[0], float(smp[1]), str(cam.global_position.snapped(Vector3.ONE * 0.01)), rig._h, cam.fov, ", ".join(PackedStringArray(_touch(wr, ids)))])
			await tool.snap("%s_%s_%s" % [pid, area, smp[0]])
