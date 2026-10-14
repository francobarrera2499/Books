# v3pieza_shots (REACCIONES-PIEZA, GDD_v3 §4.3, §6.4): la buhardilla antes y después de cada intrusión, con ventana.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3pieza res://devtools/drivers/v3pieza_shots.gd
# Datos reales (data/places/L1.json). Para cada estado (sin variante = «antes»; techos; registrada; las dos) arma la
# instantánea como WorldModel.snapshot (nodos base + add_nodes de la variante − hide_nodes; Wiggins por la ventana desde
# el día 3) y saca los encuadres escritorio, ventana y pared. Además, un primer plano de cada firma (cámara libre).
# Salida: .work/shots/v3pieza_<estado>_<encuadre>.png. Sin set_fast: la cámara llega a su encuadre como en el juego.
extends RefCounted

const WR = preload("res://world/world_root.gd")
const DataRepo = preload("res://core/data/data_repo.gd")

func _snap(pl: Dictionary, variant: String, frame: String, slot := "M") -> Dictionary:
	var vd: Dictionary = pl.get("variants", {}).get(variant, {}) if variant != "" else {}
	var hide: Array = vd.get("hide_nodes", [])
	var nodes: Array = []
	for n in pl.get("nodes", []) + vd.get("add_nodes", []):
		var a := String(n.get("area", "*"))
		if a == "tienda":
			continue
		if hide.has(String(n.id)) or nodes.has(String(n.id)):
			continue
		nodes.append(String(n.id))
	return {"id": "PL.L1.v3pieza.%s.%s" % [variant if variant != "" else "base", slot], "place": "L1", "area": "buhardilla", "day": 4,
		"slot": slot, "variant": variant, "nodes": nodes, "chars": [], "silhouettes": ["sil_wiggins"], "frame": frame}

func _free_cam(wr, on: bool) -> void:
	if wr.get("rig") != null:
		wr.rig.set_process(not on)
		wr.rig.set_physics_process(not on)

# DBG_SET = todo (por defecto) | cerca (sólo primeros planos) | encuadres (sólo los tres encuadres)
func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var which := OS.get_environment("DBG_SET")
	if which == "": which = "todo"
	var rp = DataRepo.load_dir("res://data")
	var pl: Dictionary = rp.place("L1")
	var wr = WR.new()
	scene.add_child(wr)
	var states := {"antes": "", "techos": "techos", "registrada": "registrada", "ambas": "registrada+techos"}
	var close := {
		"ventana_cerca": [Vector3(0.55, 1.55, -1.25), Vector3(0.0, 1.15, -2.25), 50.0],
		"escritorio_cerca": [Vector3(0.75, 1.35, -0.55), Vector3(0.05, 0.7, -1.5), 50.0],
		"cerradura_cerca": [Vector3(-0.15, 1.15, 1.35), Vector3(0.19, 0.92, 2.07), 40.0],
		"alfeizar_cerca": [Vector3(0.3, 1.25, -1.75), Vector3(0.12, 0.85, -2.17), 45.0],
	}
	for name in states:
		var v: String = states[name]
		wr.show_plate(_snap(pl, v, "escritorio"), pl)
		wr.set_orbit_enabled(false)
		await tool.frames(20)
		if which != "cerca":
			for f in ["escritorio", "ventana", "pared"]:
				_free_cam(wr, false)
				wr.set_frame(f, true)
				await tool.frames(30)
				await tool.snap("%s_%s" % [name, f])
		if which != "encuadres" and name != "ambas":
			for k in close:
				_free_cam(wr, true)
				var cam: Camera3D = wr.camera()
				var c: Array = close[k]
				cam.global_position = c[0]
				cam.look_at(c[1], Vector3.UP)
				cam.fov = float(c[2])
				await tool.frames(20)
				await tool.snap("%s_%s" % [name, k])
			_free_cam(wr, false)
	if which != "cerca":
		# la noche, con la ventana abierta
		wr.show_plate(_snap(pl, "techos", "escritorio", "N"), pl)
		wr.set_orbit_enabled(false)
		wr.set_frame("escritorio", true)
		await tool.frames(40)
		await tool.snap("techos_noche_escritorio")
