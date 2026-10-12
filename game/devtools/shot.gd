# Visual verification tool. From repo root:
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- <scene_path> <out_prefix> [driver_script.gd]
# Without driver: waits 30 frames and saves .work/shots/<out_prefix>.png
# With driver: driver script must define `func drive(tool, scene) -> void` (may await); call `await tool.snap("name")`
# and `await tool.frames(n)` inside. Saves .work/shots/<out_prefix>_<name>.png. Quits when drive returns.
extends SceneTree
var prefix := "shot"
var out_dir := ""
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("usage: -- <scene> <prefix> [driver]"); quit(2); return
	prefix = a[1]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../.work/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ps = load(a[0])
	if ps == null: printerr("cannot load scene ", a[0]); quit(2); return
	var scene = ps.instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred(scene, a[2] if a.size() > 2 else "")
func frames(n: int) -> void:
	for i in n: await process_frame
func snap(name := "") -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var p := out_dir.path_join(prefix + ("" if name == "" else "_" + name) + ".png")
	img.save_png(p)
	print("SNAP ", p)
func _run(scene, driver_path: String) -> void:
	if driver_path == "":
		await frames(30); await snap(); quit(0); return
	var d = load(driver_path).new()
	await d.drive(self, scene)
	quit(0)
