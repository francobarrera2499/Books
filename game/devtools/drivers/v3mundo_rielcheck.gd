# devtools/drivers/v3mundo_rielcheck.gd — UI-MUNDO: revisa la continuidad del riel de la buhardilla y la tienda (paso
# máximo de posición y rumbo por 0,1° de parámetro) sin pantalla.
#   ./godot.sh --headless -s devtools/drivers/v3mundo_rielcheck.gd
extends SceneTree

const RIG = preload("res://world/camera_rig.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for key in ["L1.buhardilla", "L1.tienda", "PRO"]:
		var r = RIG.new()
		root.add_child(r)
		r.setup({}, RIG.cfg_for(key.get_slice(".", 0), key.get_slice(".", 1) if key.contains(".") else "*"), false, [])
		var prev = r.eval_rail(r.s_min)
		var worst_p := 0.0
		var worst_h := 0.0
		var at_p := 0.0
		var at_h := 0.0
		var s: float = r.s_min + 0.1
		while s <= r.s_max + 0.001:
			var e = r.eval_rail(s)
			var dp: float = (e.pos as Vector3).distance_to(prev.pos)
			var dh: float = absf(float(e.h) - float(prev.h))
			if dp > worst_p:
				worst_p = dp; at_p = s
			if dh > worst_h:
				worst_h = dh; at_h = s
			prev = e
			s += 0.1
		print("%s: paso máx %.3f m en s=%.1f; rumbo máx %.3f° en s=%.1f (por 0,1°)" % [key, worst_p, at_p, worst_h, at_h])
		r.free()
	quit(0)
