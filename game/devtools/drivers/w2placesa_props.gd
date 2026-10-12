# devtools/drivers/w2placesa_props.gd — W2-PLACES-A. Hojas de contacto de los props propios (world/props/l1.gd, l2.gd).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pa_props res://devtools/drivers/w2placesa_props.gd
# Salida: .work/shots/w2pa_props_sheet<NN>.png (3 x 2 por hoja). Env W2PA_ONLY="l1.notebook,l2.slip_basket" (filtro).
extends RefCounted

const DB = preload("res://world/diorama_builder.gd")
const M = preload("res://world/materials.gd")

const LIST := [
	["l1.reading_stand", {}], ["l1.notebook", {}], ["l1.thick_book", {}], ["l1.spectacles_case", {}], ["l1.banknotes", {}], ["l1.clipping", {}],
	["l1.loose_papers", {"crumpled": true}], ["l1.drawer_out", {}], ["l1.footprint", {}], ["l1.rug", {}], ["l1.washstand", {}], ["l1.peg_rail", {}],
	["l1.gas_bracket", {}], ["l1.counter_lamp", {}], ["l1.shop_window", {}], ["l1.shop_door", {"open": 0.2}], ["l1.paper_lot", {}], ["l1.photo_box", {}],
	["l1.newspaper_bundle", {}], ["l1.magazine_stack", {}], ["l1.book_table", {"sign": "TODO A 6 d."}], ["l1.stair_glimpse", {}], ["l1.own_front", {"sign": "A. CRANE · LIBROS"}],
	["l1.holywell_row", {"houses": [{"w": 4.0, "floors": 2, "gable": true, "sign": "LIBROS", "stall": true}, {"w": 3.6, "floors": 2, "gable": false, "moon": true}, {"w": 4.2, "floors": 2, "brick": true, "shut": true}]}],
	["l1.reflection", {"s": 1.0}], ["l1.trunk", {}],
	["l2.slip_basket", {}], ["l2.cotter_desk", {}], ["l2.seat_items", {"number": "214"}], ["l2.attendant", {}], ["l2.newspaper_lectern", {"l": 3.0}], ["l2.folio_shelves", {"w": 2.4}],
	["l2.vestibule", {}], ["l2.pendant_lamps", {"n": 2, "l": 3.0, "y": 1.5, "drop": 0.8}],
	["l2.center", {"slips": [90.0]}], ["l2.radial_desks", {"n": 3, "r0": 2.0, "r1": 7.0}],
]

var tool
var world: Node3D
var cam: Camera3D
var label: Label

func drive(t, scene) -> void:
	tool = t
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	world = Node3D.new(); scene.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d8d2c4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8c0b0"); e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -35, 0); sun.light_energy = 1.0; sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 140, 0); fill.light_energy = 0.3
	world.add_child(fill)
	cam = Camera3D.new(); cam.fov = 35; world.add_child(cam); cam.current = true
	var cl := CanvasLayer.new(); scene.add_child(cl)
	label = Label.new(); label.position = Vector2(560, 60); label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("1b1712"))
	cl.add_child(label)
	var only := OS.get_environment("W2PA_ONLY")
	var items: Array = []
	for it in LIST:
		if only == "" or only.split(",").has(it[0]): items.append(it)
	var tw := 500; var th := 450
	var sheet: Image = null
	var k := 0
	var sheet_i := 0
	for it in items:
		var n := DB.build_prop(it[0], it[1])
		world.add_child(n)
		var floor := M.box(world, Vector3(80, 0.02, 80), Vector3(0, -0.011, 0), "papel_viejo")
		var box := M.aabb_of(n)
		var c := box.get_center()
		var rad := maxf(box.size.length() * 0.5, 0.08)
		var dir := Vector3(0.55, 0.42, 1.0).normalized()
		var dist := rad / sin(deg_to_rad(cam.fov) * 0.5) * 1.02
		cam.near = maxf(0.005, dist * 0.01)
		cam.far = dist * 6.0
		cam.global_transform = Transform3D(Basis.IDENTITY, c + dir * dist).looking_at(c, Vector3.UP)
		label.text = it[0]
		await tool.frames(3)
		await RenderingServer.frame_post_draw
		var img: Image = tool.root.get_viewport().get_texture().get_image()
		var crop := img.get_region(Rect2i(300, 0, 1000, 900))
		crop.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		if sheet == null:
			sheet = Image.create(tw * 3, th * 2, false, crop.get_format())
			sheet.fill(Color.WHITE)
		sheet.blit_rect(crop, Rect2i(0, 0, tw, th), Vector2i((k % 3) * tw, (k / 3) * th))
		k += 1
		n.queue_free(); floor.queue_free()
		if k == 6:
			_save(sheet, sheet_i); sheet = null; k = 0; sheet_i += 1
	if sheet != null: _save(sheet, sheet_i)

func _save(img: Image, i: int) -> void:
	var p: String = tool.out_dir.path_join("%s_sheet%02d.png" % [tool.prefix, i])
	img.save_png(p)
	print("SNAP ", p)
