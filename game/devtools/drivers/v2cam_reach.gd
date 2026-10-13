# Alcance de la cámara v2 (sin pantalla): qué nodos se pueden tocar desde la vista general de cada lugar/área (girando
# dentro de sus límites) y desde cada zona. ./godot.sh --headless -s devtools/drivers/v2cam_reach.gd
extends SceneTree
const WR = preload("res://world/world_root.gd")
const PK = preload("res://world/picker.gd")
func _init() -> void:
	_run.call_deferred()

func _visible(wr) -> Dictionary:
	var out := {}
	var cam: Camera3D = wr.camera()
	var vr := Rect2(Vector2.ZERO, Vector2(1600, 900)).grow(-20)
	var idx: Dictionary = wr.diorama.get_meta("nodes_index", {})
	var lim: Vector2 = wr.rig.limits()
	for yi in range(-3, 4):
		for pi in range(-2, 3):
			wr.rig.yaw_t = lim.x * yi / 3.0; wr.rig.pitch_t = lim.y * pi / 2.0
			wr.rig.yaw_off = wr.rig.yaw_t; wr.rig.pitch_off = wr.rig.pitch_t
			wr.rig._apply()
			wr._update_cutaway(true)
			for nid in idx:
				if out.has(nid): continue
				var b: Node3D = idx[nid]
				if wr.excluded_rids().has((b as CollisionObject3D).get_rid()): continue
				var s: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
				for off in [Vector3.ZERO, Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.3, 0, 0), Vector3(-s.x * 0.3, 0, 0), Vector3(0, -s.y * 0.3, 0)]:
					var p: Vector3 = b.global_position + off
					if cam.is_position_behind(p): continue
					var sp := cam.unproject_position(p)
					if not vr.has_point(sp): continue
					if str(wr.pick(sp).get("id", "")) == str(nid):
						out[nid] = true
						break
	wr.rig.yaw_t = 0; wr.rig.pitch_t = 0; wr.rig.yaw_off = 0; wr.rig.pitch_off = 0; wr.rig._apply()
	return out

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var repo = root.get_node("Data").repo()
	var all := {}
	for k in repo.places(): all[k] = repo.places()[k]
	for k in repo.plates(): all[k] = repo.plates()[k]
	var only := OS.get_environment("REACH")
	var keys: Array = all.keys()
	keys.sort()
	for pid in keys:
		if only != "" and str(pid) != only: continue
		var pl: Dictionary = all[pid]
		var areas: Array = (pl.get("areas", {}) as Dictionary).keys() if pl.get("areas", {}) is Dictionary else []
		if areas.is_empty(): areas = ["*"]
		for area in areas:
			var ids: Array = []
			for n in pl.get("nodes", []):
				var a := str(n.get("area", "*"))
				if a == "*" or area == "*" or a == area: ids.append(str(n.id))
			var chars: Array = []
			for c in pl.get("characters", []):
				var a2 := str(c.get("area", "*"))
				if a2 == "*" or area == "*" or a2 == area: chars.append({"id": str(c.id), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
			var sils: Array = (pl.get("silhouettes", {}) as Dictionary).keys() if pl.get("silhouettes", {}) is Dictionary else []
			var snap := {"id": "PL.%s.3.M" % pid, "place": pid, "area": area, "day": 3, "slot": "M", "variant": "", "nodes": ids, "chars": chars, "silhouettes": sils}
			var wr = WR.new()
			root.add_child(wr)
			wr.set_fast(true)
			wr.show_plate(snap, pl)
			await physics_frame
			await physics_frame
			var home: String = wr.rig.home
			var frs: Array = []
			for f in pl.get("frames", []):
				var fa := str(f.get("area", "*"))
				if fa == "*" or area == "*" or fa == area: frs.append(str(f.id))
			wr.rig.go_overview(true)
			await physics_frame
			var vh := _visible(wr)
			var zones: Dictionary = wr.rig.cfg.get("zones", {})
			print("REACH %s.%s home=%s frames=%s nodes=%d overview_sees=%d zones=%s" % [pid, area, home, str(frs), ids.size(), vh.size(), str(zones)])
			var missing: Array = []
			for nid in ids:
				if not vh.has(nid): missing.append(nid)
			print("REACH   no se tocan desde la general: ", missing)
			for f in frs:
				if f == home: continue
				wr.set_frame(f, true)
				await physics_frame
				var vz := _visible(wr)
				var only_here: Array = []
				for nid in vz:
					if not vh.has(nid): only_here.append(nid)
				# candidatos a disparador: nodos tocables desde la general cerca del centro del encuadre f
				var cam: Camera3D = wr.camera()
				var cands: Array = []
				for nid in vz:
					if not vh.has(nid): continue
					var b: Node3D = wr.node_body(nid)
					var sp := cam.unproject_position(b.global_position)
					cands.append([sp.distance_to(Vector2(800, 450)), nid, b.get_meta("size")])
				cands.sort_custom(func(a, c): return a[0] < c[0])
				print("REACH   zona %s: sólo desde aquí %s | candidatos %s" % [f, str(only_here), str(cands.slice(0, 5).map(func(x): return "%s(%.0fpx)" % [x[1], x[0]]))])
			# todas las estaciones/zonas: ¿qué nodo no se toca desde ninguna?
			var any := vh.duplicate()
			for f in frs:
				wr.set_frame(f, true)
				await physics_frame
				for k in _visible(wr): any[k] = true
			var never: Array = []
			for nid in ids:
				if not any.has(nid): never.append(nid)
			# la órbita vieja (W1: ±yaw/±pitch alrededor del pivote de cada encuadre, con chevrones entre encuadres)
			var old := {}
			for f in frs:
				var fd: Dictionary = wr.rig.frames[f]
				var base := Transform3D(Basis.IDENTITY, fd.pos).looking_at(fd.look, Vector3.UP)
				var piv: Vector3 = fd.pivot
				var cam: Camera3D = wr.camera()
				wr.rig.stack = []
				for yi in range(-2, 3):
					for pi in range(-1, 2):
						var yo := float(fd.yaw) * yi / 2.0
						var po := float(fd.pitch) * pi
						var r := Basis(Vector3.UP, deg_to_rad(yo)) * Basis(base.basis.x.normalized(), deg_to_rad(-po))
						cam.global_transform = Transform3D(Basis.IDENTITY, piv) * Transform3D(r, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -piv) * base
						wr._update_cutaway(true)
						for nid in ids:
							if old.has(nid): continue
							var b: Node3D = wr.node_body(nid)
							if b == null or wr.excluded_rids().has((b as CollisionObject3D).get_rid()): continue
							var sz: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
							for off in [Vector3.ZERO, Vector3(0, sz.y * 0.3, 0), Vector3(sz.x * 0.3, 0, 0), Vector3(-sz.x * 0.3, 0, 0), Vector3(0, -sz.y * 0.3, 0)]:
								var pp: Vector3 = b.global_position + off
								if cam.is_position_behind(pp): continue
								var sp := cam.unproject_position(pp)
								if not Rect2(20, 20, 1560, 860).has_point(sp): continue
								if str(wr.pick(sp).get("id", "")) == str(nid):
									old[nid] = true
									break
			var lost: Array = []
			for nid in ids:
				if old.has(nid) and not any.has(nid): lost.append(nid)
			print("REACH   NUNCA (ni general ni zonas): ", never, "  PERDIDOS respecto de la órbita vieja: ", lost)
			if wr.rig.station_mode():
				var ring: Array = []
				wr.rig.go_overview(true)
				for i in frs.size():
					var nb: String = wr.rig.neighbor(1)
					ring.append(nb)
					if nb == "": break
					wr.rig.set_frame(nb, true)
				print("REACH   vuelta a la izquierda: ", ring)
			wr.queue_free()
			await process_frame
	quit(0)
