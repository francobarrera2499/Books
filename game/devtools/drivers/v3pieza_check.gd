# v3pieza_check (REACCIONES-PIEZA, GDD_v3 §4, §6.4): chequeo rápido headless de los datos del paquete.
#   ./godot.sh --headless -s devtools/drivers/v3pieza_check.gd
# Errores del repo en los archivos del paquete (reacciones, L1, entidades/ui_text v3_reacciones), lint de gramática
# de reacciones, y construcción de la buhardilla en sus cuatro estados (sin variante, techos, registrada, ambas).
extends SceneTree

const DataRepo = preload("res://core/data/data_repo.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const DB = preload("res://world/diorama_builder.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var rp = DataRepo.load_dir("res://data")
	print("== errores del repo en archivos del paquete")
	var n := 0
	for e in rp.errors():
		var s := String(e)
		if s.contains("reactions/") or s.contains("places/L1") or s.contains("v3_reacciones") or s.contains("audio"):
			print("  ", s)
			n += 1
	print("  (%d; total del repo %d)" % [n, rp.errors().size()])
	print("== lint de reacciones")
	for e in RDB.lint(rp):
		print("  ", e)
	print("== buhardilla por variante")
	var pl: Dictionary = rp.place("L1")
	for v in ["", "techos", "registrada", "registrada+techos"]:
		var root: Node3D = DB.build(pl, {"id": "chk", "area": "buhardilla", "slot": "M", "variant": v})
		var miss: Array = []
		for c in root.get_node("Props").get_children():
			if c.has_meta("missing_type"):
				miss.append(String(c.get_meta("missing_type")))
		var nodes: Array = []
		for c in root.get_node("Nodes").get_children():
			nodes.append(String(c.name))
		print("  [%s] props %d, faltan tipos %s, nodos %d" % [v, root.get_node("Props").get_child_count(), str(miss), nodes.size()])
		root.free()
	quit(0)
