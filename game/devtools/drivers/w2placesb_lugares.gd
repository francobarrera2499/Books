# devtools/drivers/w2placesb_lugares.gd — W2-PLACES-B. Capturas de L3, L7, L8 y la lámina PARK por encuadre × franja,
# con grabado. La instantánea se emula como lo haría WorldModel.snapshot: nodos y personajes por `when` (Cond con tk),
# área del encuadre, siluetas wiggins/cochero desde el día 3.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2placesb res://devtools/drivers/w2placesb_lugares.gd
# Env: W2PB=L3|L7|L8|PARK (filtra), W2PB_RAW=1 (también sin grabado), W2PB_JOB=<texto> (sólo trabajos cuyo nombre lo contenga),
#  W2PB_ANIM=1 (PARK: la caída de libros en 4 instantes → w2placesb_PARK_caida_<0|35|70|100>.png),
#  W2PB_CAM="x,y,z;lx,ly,lz;fov|…" (cámaras libres de depuración), W2PB_NODE="L3:interior:3:M:vestibulo:<nodo>"
#  (imprime rect_clip y los impactos de los rayos de oclusión de un nodo).
# Salida: .work/shots/w2placesb_<lugar>_<encuadre>_<día><franja>.png
extends RefCounted

const WR = preload("res://world/world_root.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const L3 = preload("res://world/props/l3.gd")

var repo

static func snapshot(repo, place: Dictionary, area: String, day: int, slot: String, sils: Array = []) -> Dictionary:
	var tk := TimeKey.tk(day, slot)
	var ctx := {"repo": repo, "tk": tk}
	var nodes: Array = []
	for n in place.get("nodes", []):
		var a := str(n.get("area", "*"))
		if not (a == "*" or area == "*" or a == area): continue
		if Cond.eval(n.get("when", {}), ctx): nodes.append(str(n["id"]))
	var chars: Array = []
	for c in place.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if not (a2 == "*" or area == "*" or a2 == area): continue
		if Cond.eval(c.get("when", {}), ctx):
			chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var s := sils.duplicate()
	if s.is_empty() and day >= 3:
		for who in (place.get("silhouettes", {}) as Dictionary).keys():
			if who in ["wiggins", "cochero"]: s.append(who)
	return {"id": "PL.%s.%d.%s" % [place.get("id", "?"), day, slot], "place": str(place.get("id", "")), "area": area, "day": day,
		"slot": slot, "variant": "", "nodes": nodes, "chars": chars, "silhouettes": s}

# W2PB_NODE="L3:interior:3:M:vestibulo:puerta_entreabierta" → imprime rect_clip y los impactos de los rayos de oclusión
func _debug_node(tool, scene, spec: String) -> void:
	var a := spec.split(":")
	var place: Dictionary = repo.place(a[0])
	if place.is_empty(): place = repo.plate(a[0])
	var snap := snapshot(repo, place, a[1], int(a[2]), a[3])
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	wr.show_plate(snap, place)
	await tool.frames(3)
	wr.set_frame(a[4], true)
	await tool.frames(3)
	var RCs = load("res://world/rect_clip.gd")
	var body = wr.node_body(a[5])
	var cam: Camera3D = wr.camera()
	var r: Rect2 = RCs.screen_rect(cam, body)
	print("RECT ", r, " vp ", cam.get_viewport().get_visible_rect())
	var res: Dictionary = wr.rect_clip(r.grow(4))
	print("CLIP ", res)
	var s: Vector3 = body.get_meta("size")
	var xf: Transform3D = body.global_transform
	var cl: Vector3 = xf.affine_inverse() * cam.global_position
	var space := cam.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for rid in wr.excluded_rids(): ex.append(rid)
	for rid in RCs.own_bodies(body, wr.diorama): ex.append(rid)
	ex.append(body.get_rid())
	for pl in RCs.sample_points(cl, s * 0.5):
		var pw: Vector3 = xf * pl
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, pw, 1 | 4, ex)
		var h := space.intersect_ray(q)
		var who := "-"
		if not h.is_empty():
			var c: Object = h["collider"]
			who = "%s prop=%s char=%s at %s" % [c.name, c.get_meta("prop_id", ""), c.get_meta("char_id", ""), h["position"]]
		print("  PT ", pw, " -> ", who)
	await tool.snap("dbg_" + a[5])

func _frames_of(place: Dictionary, area: String) -> Array:
	var out: Array = []
	for f in place.get("frames", []):
		var a := str(f.get("area", "*"))
		if a == "*" or a == area: out.append(str(f["id"]))
	return out

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	repo = load("res://core/data/data_repo.gd").load_dir("res://data")
	var mine := []
	for e in repo.errors():
		var s := str(e)
		if s.contains("L3") or s.contains("L7") or s.contains("L8") or s.contains("PARK") or s.contains("places_b"):
			mine.append(s)
	print("REPO_ERRORS_MINE ", mine.size())
	for m in mine: print("  ", m)
	var dbgn := OS.get_environment("W2PB_NODE")
	if dbgn != "":
		await _debug_node(tool, scene, dbgn)
		return
	var only := OS.get_environment("W2PB")
	var jobf := OS.get_environment("W2PB_JOB")
	var raw := OS.get_environment("W2PB_RAW") != ""
	# [lugar, área, día, franja, encuadres ([] = todos los del área), luz forzada]
	var jobs := [
		["L3", "calle", 3, "M", ["221b", "camden"], ""],
		["L3", "interior", 3, "M", ["vestibulo", "salita"], ""],
		["L3", "agente", 3, "T", ["agente"], ""],
		["L3", "interior", 8, "M", ["221b", "vestibulo"], ""],
		["L3", "interior", 9, "T", ["vestibulo"], ""],
		["L3", "calle", 4, "N", ["camden", "221b"], ""],
		["L3", "calle", 10, "night", ["221b"], "noche_viento"],
		["L7", "exterior", 5, "M", [], ""],
		["L3", "calle", 5, "T", ["221b", "camden"], ""],
		["L3", "interior", 6, "T", ["vestibulo", "salita"], ""],
		["L7", "exterior", 6, "T", [], ""],
		["L7", "exterior", 7, "N", [], ""],
		["L8", "interior", 7, "T", [], ""],
		["L8", "interior", 8, "M", ["vista"], ""],
		["PARK", "*", 10, "T", [], ""],
	]
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	for j in jobs:
		var pid: String = j[0]
		if only != "" and pid != only: continue
		var name := "%s_%s_%d%s" % [pid, j[1], j[2], j[3]]
		if jobf != "" and not name.contains(jobf): continue
		var place: Dictionary = repo.place(pid)
		if place.is_empty(): place = repo.plate(pid)
		if place.is_empty():
			print("SIN DATOS ", pid); continue
		var snap := snapshot(repo, place, str(j[1]), int(j[2]), str(j[3]))
		if str(j[5]) != "": snap["light"] = str(j[5])
		var t0 := Time.get_ticks_msec()
		wr.show_plate(snap, place)
		print("BUILD_MS %s %d nodos=%d" % [name, Time.get_ticks_msec() - t0, wr.diorama.find_children("*", "", true, false).size()])
		await tool.frames(2)
		var cai = wr.diorama.find_children("caida", "", true, false)
		if pid == "PARK" and not cai.is_empty() and OS.get_environment("W2PB_ANIM") != "":
			# la caída de libros en tres instantes (la única animación del juego)
			var c0 = cai[0]
			c0.set_process(false)
			c0.playing = false
			wr.set_frame("choque", true)
			for u in [0.0, 0.35, 0.7, 1.0]:
				c0._pose(u)
				await tool.frames(3)
				await tool.snap("PARK_caida_%d" % int(u * 100))
		for c2 in cai:
			if c2.has_method("finish"): c2.finish()
		var frs: Array = j[4] if not (j[4] as Array).is_empty() else _frames_of(place, str(j[1]))
		var dbg := OS.get_environment("W2PB_CAM")
		if dbg != "":
			# cámara libre de depuración: "x,y,z;lx,ly,lz;fov" (varias separadas por |)
			var k := 0
			for spec in dbg.split("|"):
				var parts := spec.split(";")
				var a := parts[0].split_floats(","); var b := parts[1].split_floats(",")
				var cam: Camera3D = wr.camera()
				wr.rig.set_process(false)
				cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(a[0], a[1], a[2])).looking_at(Vector3(b[0], b[1], b[2]), Vector3.UP)
				cam.fov = float(parts[2]) if parts.size() > 2 else 60.0
				await tool.frames(4)
				await tool.snap("%s_dbg%d" % [name, k])
				k += 1
			continue
		for f in frs:
			wr.set_frame(str(f), true)
			await tool.frames(5)
			await tool.snap("%s_%s_%d%s" % [pid, f, j[2], j[3]])
			if raw:
				wr.set_engraving(false)
				var post = wr.engraving_post()
				if post != null and post.has_method("set_enabled"): post.set_enabled(false)
				await tool.frames(3)
				await tool.snap("%s_%s_%d%s_crudo" % [pid, f, j[2], j[3]])
				if post != null and post.has_method("set_enabled"): post.set_enabled(true)
				wr.set_engraving(true)
