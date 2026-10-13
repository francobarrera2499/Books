# Planta de la buhardilla (CÁMARA v2): cámara ortográfica cenital sin look, para calibrar la vista general.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v2plan res://devtools/drivers/v2cam_plan.gd
extends RefCounted
const WR = preload("res://world/world_root.gd")
func drive(tool, _scene) -> void:
	tool.root.size = Vector2i(1600, 900)
	var wr = WR.new()
	tool.root.add_child(wr)
	wr.set_fast(true)
	wr.hover_enabled = false
	var area := OS.get_environment("PLAN_AREA")
	wr.show_hub("mostrador" if area == "tienda" else "general", "M")
	await tool.frames(8)
	wr.set_engraving(false)
	wr.aff_post().visible = false
	var cam: Camera3D = wr.camera()
	wr.rig.stack = []
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	var y := 4.0 if area != "tienda" else -2.6
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, y, 0)).looking_at(Vector3(0, y - 5, 0), Vector3.FORWARD)
	for g in wr.diorama.find_children("*", "Node3D", true, false):
		if g.has_meta("cut_n"): g.visible = false
	# techo fuera: todo lo que esté por encima de 2,1 m (o -3 m en la tienda) se oculta
	for mi in wr.diorama.find_children("*", "GeometryInstance3D", true, false):
		var a: AABB = (mi as GeometryInstance3D).global_transform * (mi as GeometryInstance3D).get_aabb()
		if a.position.y > (2.0 if area != "tienda" else -3.1): (mi as Node3D).visible = false
	await tool.frames(4)
	await tool.snap(area if area != "" else "buhardilla")
	for nid in wr.diorama.get_meta("nodes_index"):
		var b: Node3D = wr.node_body(nid)
		print("PLAN %s %s -> %s" % [nid, b.global_position, cam.unproject_position(b.global_position)])
