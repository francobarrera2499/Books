# Driver W1-POST: compara variantes de trama sobre la escena de prueba (Bayer puro vs talla) y estilo sepia.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w1post_est res://devtools/drivers/w1post_estilos.gd [preset] [slot]
extends RefCounted

const S = preload("res://devtools/drivers/w1post_scene.gd")

func drive(tool, scene) -> void:
	var ua := OS.get_cmdline_user_args()
	var preset: String = ua[3] if ua.size() > 3 else "dia_ventana"
	var slot: String = ua[4] if ua.size() > 4 else "M"
	var sc := S.build(scene)
	S.set_preset(sc, preset, slot)
	var variants := {
		"bayer": {"hatch": 0.0},
		"talla": {"hatch": 1.0},
		"talla_mixta": {"hatch": 0.5},
	}
	for nm in variants:
		for k in variants[nm]:
			sc.post.set_param(k, variants[nm][k])
		await tool.frames(4)
		await tool.snap("%s_%s" % [preset, nm])
	sc.post.set_param("hatch", 1.0)
	sc.post.set_style("sepia")
	await tool.frames(4)
	await tool.snap("%s_sepia" % preset)
	sc.post.set_style("dos_tintas")
	sc.post.set_high_contrast(true)
	await tool.frames(4)
	await tool.snap("%s_alto_contraste" % preset)
	sc.post.set_high_contrast(false)
