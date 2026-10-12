# Driver de capturas W1-POST: escena de prueba por preset de luz × papel de franja (+ crudo y vistas de depuración).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w1post res://devtools/drivers/w1post_matrix.gd
# Salida: .work/shots/w1post_<preset>_<slot>.png, w1post_raw.png, w1post_dbg_{tono,contornos}.png y la hoja
# w1post_hoja.png (8 presets × 3 franjas, 1/4 de tamaño). Args de usuario extra (tras el driver): "rapido" = sólo la diagonal.
extends RefCounted

const S = preload("res://devtools/drivers/w1post_scene.gd")
const Lighting = preload("res://world/lighting.gd")
const NATURAL := {"manana_perla": "M", "dia_ventana": "M", "tarde": "T", "gas": "N", "farol_calle": "N",
	"electrica_fria": "M", "dorada_parklane": "N", "noche_viento": "N"}

func drive(tool, scene) -> void:
	var quick := OS.get_cmdline_user_args().has("rapido")
	var sc := S.build(scene)
	S.set_preset(sc, "dia_ventana", "M")
	await tool.frames(10)
	sc.post.set_enabled(false)
	await tool.frames(3)
	await tool.snap("raw")
	sc.post.set_enabled(true)
	sc.post.set_param("debug_view", 1)
	await tool.frames(3)
	await tool.snap("dbg_tono")
	sc.post.set_param("debug_view", 2)
	await tool.frames(3)
	await tool.snap("dbg_contornos")
	sc.post.set_param("debug_view", 0)
	var sheet_imgs := []
	for preset in Lighting.names():
		var slots := [NATURAL[preset]] if quick else ["M", "T", "N"]
		for slot in slots:
			S.set_preset(sc, preset, slot)
			await tool.frames(6)
			var nm := "%s_%s" % [preset, slot]
			await tool.snap(nm)
			var img: Image = tool.root.get_viewport().get_texture().get_image()
			img.resize(img.get_width() / 4, img.get_height() / 4, Image.INTERPOLATE_LANCZOS)
			sheet_imgs.append(img)
	if quick:
		return
	var w: int = sheet_imgs[0].get_width()
	var h: int = sheet_imgs[0].get_height()
	var sheet := Image.create(w * 3, h * 8, false, sheet_imgs[0].get_format())
	for i in sheet_imgs.size():
		sheet.blit_rect(sheet_imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	var p: String = tool.out_dir.path_join(tool.prefix + "_hoja.png")
	sheet.save_png(p)
	print("SNAP ", p)
