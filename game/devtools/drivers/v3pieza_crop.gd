# devtools/drivers/v3pieza_crop.gd — REACCIONES-PIEZA (diagnóstico): recorta y amplía una zona de una captura.
#   ./godot.sh --headless -s devtools/drivers/v3pieza_crop.gd -- <png en .work/shots> <x> <y> <w> <h> <escala> <salida>
extends SceneTree

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/shots")
	var img := Image.load_from_file(dir.path_join(a[0]))
	var r := Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
	var c := img.get_region(r)
	var k := float(a[5])
	c.resize(int(r.size.x * k), int(r.size.y * k), Image.INTERPOLATE_LANCZOS)
	c.save_png(dir.path_join(a[6]))
	quit(0)
