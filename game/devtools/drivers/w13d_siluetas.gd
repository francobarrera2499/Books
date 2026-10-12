# devtools/drivers/w13d_siluetas.gd — W1-3D (§7.4). Cada maniquí sobre fondo liso, binarizado; IoU por pares < 0,85.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w13d res://devtools/drivers/w13d_siluetas.gd
# Salida: .work/shots/w13d_siluetas.png (figuras), w13d_siluetas_bin.png (1 bit), w13d_siluetas_iou.txt, w13d_poses.png.
# Imprime «SILUETAS OK max_iou=…» o «SILUETAS FAIL …».
extends RefCounted

const MQ = preload("res://world/characters/mannequin.gd")
const M = preload("res://world/materials.gd")
const BG := Color(0.0, 1.0, 0.0)
const LIMIT := 0.85

var tool

func drive(t, scene) -> void:
	tool = t
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var world := Node3D.new(); scene.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8c0b0"); e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); sun.light_energy = 0.9
	world.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 30; world.add_child(cam); cam.current = true
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 6.2)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	var traits: Array = MQ.traits()
	var masks := {}
	var crops := {}
	for trt in traits:
		var fig := MQ.make("t_" + trt, trt, "")
		fig.rotation_degrees = Vector3(0, 30, 0)
		world.add_child(fig)
		await tool.frames(3)
		await RenderingServer.frame_post_draw
		var img: Image = tool.root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		masks[trt] = _mask(img)
		crops[trt] = img.get_region(Rect2i(500, 0, 600, 900))
		fig.queue_free()
		await tool.frames(1)
	# IoU por pares
	var lines: Array = []
	var worst := 0.0
	var worst_pair := ""
	for i in traits.size():
		for j in range(i + 1, traits.size()):
			var a: PackedByteArray = masks[traits[i]]
			var b: PackedByteArray = masks[traits[j]]
			var inter := 0; var uni := 0
			for k in a.size():
				var x := a[k]; var y := b[k]
				if x == 1 or y == 1:
					uni += 1
					if x == 1 and y == 1: inter += 1
			var iou := float(inter) / maxf(float(uni), 1.0)
			lines.append("IoU %s %s = %.3f" % [traits[i], traits[j], iou])
			if iou > worst: worst = iou; worst_pair = "%s/%s" % [traits[i], traits[j]]
	for l in lines: print(l)
	var verdict := ("SILUETAS OK max_iou=%.3f (%s)" % [worst, worst_pair]) if worst < LIMIT else ("SILUETAS FAIL max_iou=%.3f (%s)" % [worst, worst_pair])
	print(verdict)
	var f := FileAccess.open(tool.out_dir.path_join("w13d_siluetas_iou.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n" + verdict + "\n")
		f.close()
	# hojas: figuras y binarizado (12 en fila de 2 x 6)
	var tw := 260; var th := 390
	var sheet := Image.create(tw * 6, th * 2, false, Image.FORMAT_RGB8)
	var sheet_b := Image.create(tw * 6, th * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE); sheet_b.fill(Color.WHITE)
	for idx in traits.size():
		var c: Image = crops[traits[idx]]
		var cc := c.duplicate() as Image
		cc.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(cc, Rect2i(0, 0, tw, th), Vector2i((idx % 6) * tw, (idx / 6) * th))
		var bi := Image.create(600, 900, false, Image.FORMAT_RGB8)
		bi.fill(Color.WHITE)
		var mk: PackedByteArray = masks[traits[idx]]
		for y in 900:
			for x in 600:
				if mk[y * 1600 + 500 + x] == 1: bi.set_pixel(x, y, Color.BLACK)
		bi.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet_b.blit_rect(bi, Rect2i(0, 0, tw, th), Vector2i((idx % 6) * tw, (idx / 6) * th))
	sheet.save_png(tool.out_dir.path_join("w13d_siluetas.png"))
	sheet_b.save_png(tool.out_dir.path_join("w13d_siluetas_bin.png"))
	print("SNAP ", tool.out_dir.path_join("w13d_siluetas.png"))
	print("SNAP ", tool.out_dir.path_join("w13d_siluetas_bin.png"))
	print("ORDEN ", ", ".join(traits))
	# poses (§7.4): de_pie, sentado (en silla), encorvado, apoyado — con un rasgo de ejemplo
	e.background_color = Color("d8d2c4")
	var FU = load("res://world/props/furniture.gd")
	var poses := ["de_pie", "sentado", "encorvado", "apoyado"]
	var ps := Image.create(400 * 4, 900, false, Image.FORMAT_RGB8)
	for i in poses.size():
		var fig := MQ.make("p", "bombin_crespon", poses[i])
		fig.rotation_degrees = Vector3(0, 55, 0)
		world.add_child(fig)
		var chair: Node3D = null
		if poses[i] == "sentado":
			chair = FU.build_chair({})
			chair.rotation_degrees = Vector3(0, 55, 0)
			chair.position = Vector3(0, 0, 0) + Basis(Vector3.UP, deg_to_rad(55)) * Vector3(0, 0, -0.06)
			world.add_child(chair)
		await tool.frames(3)
		await RenderingServer.frame_post_draw
		var im: Image = tool.root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		ps.blit_rect(im, Rect2i(600, 0, 400, 900), Vector2i(i * 400, 0))
		fig.queue_free()
		if chair: chair.queue_free()
		await tool.frames(1)
	ps.save_png(tool.out_dir.path_join("w13d_poses.png"))
	print("SNAP ", tool.out_dir.path_join("w13d_poses.png"))

func _mask(img: Image) -> PackedByteArray:
	var w := img.get_width(); var h := img.get_height()
	var data := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h)
	for i in w * h:
		var r := data[i * 3]; var g := data[i * 3 + 1]; var b := data[i * 3 + 2]
		out[i] = 1 if (g < 200 or r > 60 or b > 60) else 0
	return out
