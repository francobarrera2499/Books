# T32 (CÁMARA, GDD_v2 §E.4) — sin pantalla:
#  - límites por modo: general de casa en el lugar (vuelta entera/±14°, world/camera.json), zona de casa ±12°, examen ±40°/±22°,
#    estaciones de un lugar con la órbita de su encuadre y láminas fijas ≤ ±15°/±8°;
#  - el suavizado converge sin saltos > 3° por cuadro a 60 fps (bandas del borde y rueda hacia el cursor);
#  - la pila de poses: objeto → zona → general → nada;
#  - las bandas del borde: vector por posición y nunca con un panel, sobre la interfaz, sin mouse real, en el examen o con
#    la opción apagada;
#  - estaciones: la vuelta las recorre todas y empujar contra el límite pasa a la vecina; un nodo lejano lleva a su estación;
#  - alcance: todo nodo que antes se tocaba (encuadres de casa sin órbita; lugares con su órbita alrededor del pivote)
#    se sigue tocando desde la general, alguna zona o alguna estación (la deducción no pierde pistas por la cámara);
#  - no queda ningún chevrón en el código de la interfaz.
# La parte con ventana y eventos reales (borde, clic en el escritorio, clic derecho, rueda) está en test_t32_camera_window.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 420.0
const WR = preload("res://world/world_root.gd")
const RIG = preload("res://world/camera_rig.gd")

var _wr = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		_wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null
	RIG.edge_turn = true

func _snap(place: Dictionary, area: String) -> Dictionary:
	var ids: Array = []
	for n in place.get("nodes", []):
		var a := str(n.get("area", "*"))
		if a == "*" or area == "*" or a == area: ids.append(str(n.id))
	var chars: Array = []
	for c in place.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if a2 == "*" or area == "*" or a2 == area: chars.append({"id": str(c.id), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sils: Array = (place.get("silhouettes", {}) as Dictionary).keys() if place.get("silhouettes", {}) is Dictionary else []
	return {"id": "PL.%s.3.M" % place.get("id", ""), "place": place.get("id", ""), "area": area, "day": 3, "slot": "M", "variant": "",
		"nodes": ids, "chars": chars, "silhouettes": sils}

func _new_world():
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	return _wr

func _hub(frame := "general"):
	var wr = _new_world()
	wr.show_hub(frame, "M")
	await tree.physics_frame
	await tree.physics_frame
	return wr

func _place(pid: String, area: String):
	var wr = _new_world()
	var pl: Dictionary = repo().place(pid)
	if pl.is_empty(): pl = repo().plate(pid)
	wr.show_plate(_snap(pl, area), pl)
	await tree.physics_frame
	await tree.physics_frame
	return wr

func test_limits_per_mode() -> void:
	var wr = await _hub()
	eq(wr.rig.mode(), "overview", "casa: vista general")
	ok(wr.rig.inplace(), "la general de casa gira en el lugar")
	eq(wr.rig.limits(), Vector2(180, 14), "general de casa: vuelta entera/±14° (world/camera.json)")
	ok(wr.rig.wraps(), "la buhardilla se mira en redondo (la puerta a la tienda queda a la espalda)")
	var p0: Vector3 = wr.camera().global_position
	wr.rig.orbit_by(500.0, 500.0)
	ok(wr.camera().global_position.is_equal_approx(p0), "en el lugar: no hay traslación")
	near(wr.rig.yaw_off, 140.0, 0.001, "500° = 140° (sin tope, normalizado a ±180)")
	near(wr.rig.pitch_off, 14.0, 0.001, "pitch acotado")
	wr.go_zone("escritorio")
	eq([wr.rig.mode(), wr.rig.cur], ["zone", "escritorio"], "zona del escritorio")
	eq(wr.rig.limits(), Vector2(12, 12), "en una zona de casa la mirada se reduce a ±12°")
	ok(wr.examine("tomos"), "examinar los tomos")
	eq(wr.rig.limits(), Vector2(40, 22), "examen ±40°/±22°")
	after_each()
	var w2 = await _place("L4", "consulta")
	eq(w2.rig.mode(), "overview", "lugar: la general es el primer encuadre del área")
	no(w2.rig.inplace(), "un lugar orbita alrededor del pivote de su encuadre (como lo prueban T29 y las capturas W2)")
	var f: Dictionary = w2.rig.frames[w2.rig.cur]
	eq(w2.rig.limits(), Vector2(absf(float(f.yaw)), absf(float(f.pitch))), "límites del encuadre")
	after_each()
	var w3 = await _place("PRO", "*")
	var l3: Vector2 = w3.rig.limits()
	ok(l3.x <= 15.0 and l3.y <= 8.0, "lámina fija ≤ ±15°/±8° (%s)" % str(l3))

func test_smoothing_converges_without_jumps() -> void:
	var wr = await _hub()
	wr.rig.fast = false
	var cam: Camera3D = wr.camera()
	var dt := 1.0 / 60.0
	# banda del borde a fondo (45 °/s) durante 1 s y después suelta
	var prev := -cam.global_transform.basis.z
	var worst := 0.0
	for i in 90:
		if i < 60: wr.rig.look_by(45.0 * dt, 0.0)
		wr.rig.smooth_step(dt)
		var cur := -cam.global_transform.basis.z
		worst = maxf(worst, rad_to_deg(prev.angle_to(cur)))
		prev = cur
	ok(worst <= 3.0, "banda del borde: ≤ 3° por cuadro (%.2f°)" % worst)
	near(wr.rig.yaw_off, wr.rig.yaw_t, 0.05, "converge al objetivo")
	ok(wr.rig.yaw_off > 30.0, "en 1 s giró más de 30° (%.1f°)" % wr.rig.yaw_off)
	# rueda hacia una esquina: −3° de FOV y 25 % del ángulo del cursor, sin saltos
	var fov0: float = wr.rig.target_fov()
	var yaw0: float = wr.rig.yaw_off
	wr.rig.wheel(-1.0, wr.rig.cursor_angles(Vector2(1580, 20)))
	worst = 0.0
	var fworst := 0.0
	var pf := cam.fov
	prev = -cam.global_transform.basis.z
	for i in 90:
		wr.rig.smooth_step(dt)
		var cur2 := -cam.global_transform.basis.z
		worst = maxf(worst, rad_to_deg(prev.angle_to(cur2)))
		fworst = maxf(fworst, absf(cam.fov - pf))
		prev = cur2
		pf = cam.fov
	ok(worst <= 3.0, "rueda: ≤ 3° de giro por cuadro (%.2f°)" % worst)
	ok(fworst <= 3.0, "rueda: ≤ 3° de FOV por cuadro (%.2f°)" % fworst)
	near(cam.fov, fov0 - 3.0, 0.05, "rueda: −3° de FOV")
	wr.rig.wheel(1.0)
	for i in 120: wr.rig.smooth_step(dt)
	near(cam.fov, fov0, 0.05, "alejar deshace el FOV")
	near(wr.rig.yaw_off, yaw0, 0.05, "y el giro de la rueda (el yaw vuelve al de antes)")

func test_pose_stack() -> void:
	var wr = await _hub()
	eq(wr.rig.depth(), 1, "general")
	eq(wr.zone_of("escritorio"), "escritorio", "el escritorio es una zona desde la general")
	eq(wr.zone_of("tomos"), "", "los tomos no son zona")
	wr.go_zone("escritorio")
	eq(wr.zone_of("escritorio"), "", "desde la zona, el escritorio ya no lleva a otro lado")
	ok(wr.examine("cuaderno"), "examinar")
	eq([wr.rig.depth(), wr.rig.mode()], [3, "examine"], "objeto")
	ok(wr.back(), "atrás")
	eq([wr.rig.depth(), wr.rig.mode()], [2, "zone"], "zona")
	ok(wr.back(), "atrás")
	eq([wr.rig.depth(), wr.rig.mode()], [1, "overview"], "general")
	no(wr.back(), "nada más que bajar")
	# lo enorme o lejano se examina sin mover la cámara (la calle desde la ventana)
	wr.go_zone("ventana")
	var d0: int = wr.rig.depth()
	ok(wr.examine("enfrente"), "examinar las casas de enfrente")
	eq(wr.rig.depth(), d0, "sin acercarse a través de la pared")

# playtest v2 (BLOCKER): la puerta que baja a la tienda de Crane tiene que poder clicarse desde la vista general de la
# buhardilla girando dentro de los límites (antes, ±100°, quedaba siempre a la espalda). También el plano.
func test_home_door_and_map_reachable_from_overview() -> void:
	var wr = await _hub()
	var found := {}
	for yi in range(-12, 13):
		wr.rig.yaw_t = 15.0 * yi; wr.rig.yaw_off = wr.rig.yaw_t
		wr.rig.pitch_t = 0.0; wr.rig.pitch_off = 0.0
		wr.rig._apply()
		wr._update_cutaway(true)
		_touch_now(wr, wr.camera(), ["puerta", "mapa", "escritorio", "cama"], found)
	for nid in ["puerta", "mapa", "escritorio", "cama"]:
		ok(found.has(nid), "%s se puede clicar girando en la vista general" % nid)

func test_edge_band_vector_and_gating() -> void:
	var vs := Vector2(1600, 900)
	eq(WR.edge_vector(Vector2(800, 450), vs), Vector2.ZERO, "centro: nada")
	ok(WR.edge_vector(Vector2(2, 450), vs).x > 0.9, "borde izquierdo: mirar a la izquierda (yaw +)")
	ok(WR.edge_vector(Vector2(1598, 450), vs).x < -0.9, "borde derecho")
	ok(WR.edge_vector(Vector2(800, 2), vs).y > 0.9, "arriba: mirar arriba")
	ok(WR.edge_vector(Vector2(800, 898), vs).y < -0.9, "abajo")
	eq(WR.edge_vector(Vector2(1600 * 0.08 + 1, 450), vs), Vector2.ZERO, "fuera de la banda del 8 %")
	ok(absf(WR.edge_vector(Vector2(1600 * 0.04, 450), vs).x - 0.5) < 0.01, "smoothstep de la profundidad (mitad = 0,5)")
	eq(WR.edge_vector(Vector2(-5, 450), vs), Vector2.ZERO, "afuera de la ventana: nada")
	var wr = await _hub()
	no(wr.edge_allowed(), "sin un movimiento real del mouse no gira (tests, arranque)")
	wr._mouse_seen = true
	ok(wr.edge_allowed(), "con mouse real, en la general, sin interfaz debajo")
	wr.edge_enabled = false
	no(wr.edge_allowed(), "con un panel abierto (edge_enabled lo apaga la pantalla de juego) no gira")
	wr.edge_enabled = true
	wr.set_input_enabled(false)
	no(wr.edge_allowed(), "con la tijera o un panel que tapa el 3D (sin entrada) no gira")
	wr.set_input_enabled(true)
	RIG.edge_turn = false
	no(wr.edge_allowed(), "opción apagada")
	RIG.edge_turn = true
	wr.examine("tomos")
	no(wr.edge_allowed(), "en el examen no gira")
	wr.back()
	var b := Button.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(b)
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(4, 450)
	ev.global_position = ev.position
	tree.root.push_input(ev)
	await tree.process_frame
	if tree.root.gui_get_hovered_control() != null:
		no(wr.edge_allowed(), "sobre un control de la interfaz no gira")
	b.queue_free()

func test_stations_ring_push_and_far_click() -> void:
	var wr = await _place("L4", "consulta")
	ok(wr.rig.station_mode(), "un lugar sin general propia: estaciones")
	var ring: Array = wr.rig.station_ring()
	eq(PackedStringArray(ring.duplicate()).size(), wr.frames().size(), "la vuelta tiene todas las estaciones")
	var seen := {wr.rig.cur: true}
	for i in ring.size():
		var nb: String = wr.rig.neighbor(1)
		ok(nb != "", "hay vecina a la izquierda")
		wr.go_station(nb)
		seen[nb] = true
	eq(seen.size(), ring.size(), "empujando siempre a la izquierda se recorren todas")
	# empujar contra el límite PUSH_S (1 s) pasa a la vecina
	wr.rig.go_overview(true)
	var st0: String = wr.rig.cur
	var lim: float = wr.rig.limits().x
	wr.rig.yaw_t = lim
	wr.rig.yaw_off = lim
	wr._push_step(1, 0.6)
	eq(wr.rig.cur, st0, "0,6 s todavía no")
	wr._push_step(1, 0.45)
	eq(wr.rig.cur, wr.rig.station_ring()[(wr.rig.station_ring().find(st0) + 1) % ring.size()], "1,05 s: la vecina de la izquierda")
	# un nodo lejano lleva a su estación; uno cercano se examina
	wr.rig.go_overview(true)
	var far := ""
	for nid in wr.diorama.get_meta("nodes_index"):
		var z: String = wr.zone_of(String(nid))
		if z != "":
			far = String(nid)
			eq(z, wr.best_station(far), "la estación de %s es desde donde mejor se ve" % far)
			break
	ok(far != "", "algún nodo lejano lleva a otra estación")

# --- alcance (la deducción no pierde nodos por la cámara nueva)
func _touch_from_pose(wr, ids: Array, out: Dictionary, samples := Vector2i(3, 2)) -> void:
	var cam: Camera3D = wr.camera()
	var lim: Vector2 = wr.rig.limits()
	for yi in range(-samples.x, samples.x + 1):
		for pi in range(-samples.y, samples.y + 1):
			wr.rig.yaw_t = lim.x * yi / float(samples.x); wr.rig.yaw_off = wr.rig.yaw_t
			wr.rig.pitch_t = lim.y * pi / float(samples.y); wr.rig.pitch_off = wr.rig.pitch_t
			wr.rig._apply()
			wr._update_cutaway(true)
			_touch_now(wr, cam, ids, out)
	wr.rig.yaw_t = 0; wr.rig.yaw_off = 0; wr.rig.pitch_t = 0; wr.rig.pitch_off = 0; wr.rig._apply()

func _touch_now(wr, cam: Camera3D, ids: Array, out: Dictionary) -> void:
	for nid in ids:
		if out.has(nid): continue
		var b: Node3D = wr.node_body(nid)
		if b == null or wr.excluded_rids().has((b as CollisionObject3D).get_rid()): continue
		var s: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
		for off in [Vector3.ZERO, Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.3, 0, 0), Vector3(-s.x * 0.3, 0, 0), Vector3(0, -s.y * 0.3, 0)]:
			var p: Vector3 = b.global_position + off
			if cam.is_position_behind(p): continue
			var sp := cam.unproject_position(p)
			if not Rect2(20, 20, 1560, 860).has_point(sp): continue
			if str(wr.pick(sp).get("id", "")) == str(nid):
				out[nid] = true
				break

func test_reach_no_node_lost() -> void:
	var r = repo()
	var all := {}
	for k in r.places(): all[k] = r.places()[k]
	for k in r.plates(): all[k] = r.plates()[k]
	var lost: Array = []
	var n_before := 0
	var n_now := 0
	var keys: Array = all.keys()
	keys.sort()
	for pid in keys:
		var pl: Dictionary = all[pid]
		var areas: Array = (pl.get("areas", {}) as Dictionary).keys() if pl.get("areas", {}) is Dictionary else []
		if areas.is_empty(): areas = ["*"]
		for area in areas:
			var wr = _new_world()
			if str(pid) == "L1":
				wr.show_hub("general" if area == "buhardilla" else "mostrador", "M")
			else:
				wr.show_plate(_snap(pl, str(area)), pl)
			await tree.physics_frame
			await tree.physics_frame
			var ids: Array = []
			for nid in wr.diorama.get_meta("nodes_index"):
				var na := str(wr.node_body(nid).get_meta("area", "*"))
				if na == "*" or area == "*" or na == area: ids.append(str(nid))
			var frs: Array = []
			for f in pl.get("frames", []):
				var fa := str(f.get("area", "*"))
				if fa == "*" or area == "*" or fa == area: frs.append(str(f.id))
			# ahora: general + cada zona/estación, mirando dentro de sus límites
			var now := {}
			wr.rig.go_overview(true)
			_touch_from_pose(wr, ids, now)
			for f in frs:
				wr.rig.set_frame(f, true)
				_touch_from_pose(wr, ids, now)
			# antes (W1–W4): en casa los encuadres sin órbita; en los lugares la órbita alrededor del pivote
			var before := {}
			var cam: Camera3D = wr.camera()
			for f in frs:
				var fd: Dictionary = wr.rig.frames[f]
				var base := Transform3D(Basis.IDENTITY, fd.pos).looking_at(fd.look, Vector3.UP)
				var piv: Vector3 = fd.pivot
				var orbit := str(pid) != "L1"
				for yi in (range(-2, 3) if orbit else [0]):
					for pi in (range(-1, 2) if orbit else [0]):
						var rr := Basis(Vector3.UP, deg_to_rad(float(fd.yaw) * yi / 2.0)) * Basis(base.basis.x.normalized(), deg_to_rad(-float(fd.pitch) * pi))
						wr.rig.stack = []
						cam.global_transform = Transform3D(Basis.IDENTITY, piv) * Transform3D(rr, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -piv) * base
						wr._update_cutaway(true)
						_touch_now(wr, cam, ids, before)
			n_before += before.size()
			n_now += now.size()
			for nid in before:
				if not now.has(nid): lost.append("%s.%s:%s" % [pid, area, nid])
			after_each()
	ok(n_before > 150, "la comparación mira algo (%d nodos tocables antes, %d ahora)" % [n_before, n_now])
	ok(n_now >= n_before, "ahora se toca al menos lo mismo (%d ≥ %d)" % [n_now, n_before])
	eq(lost, [], "nodos que antes se tocaban y con la cámara nueva no")

func test_no_chevrons_left() -> void:
	var found: Array = []
	for dir in ["res://ui", "res://world"]:
		_grep(dir, ["ChevronIzq", "ChevronDer", "_chev_", "_step_frame"], found)
	eq(found, [], "sin chevrones en la interfaz")

func _grep(dir: String, needles: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if not f.ends_with(".gd"): continue
		var txt := FileAccess.get_file_as_string(dir + "/" + f)
		for n in needles:
			if txt.contains(String(n)): out.append("%s/%s: %s" % [dir, f, n])
	for sub in d.get_directories():
		_grep(dir + "/" + sub, needles, out)

func test_options_edge_turn() -> void:
	var Options = load("res://ui/menus/options.gd")
	ok(bool(Options.current().get("edge_turn", false)), "Opciones: «Girar la vista con los bordes» encendida por defecto")
	Options.apply({"edge_turn": false})
	no(RIG.edge_turn, "apagarla en Opciones apaga las bandas del borde")
	no(bool(Options.current().get("edge_turn", true)), "y queda en las opciones guardables")
	Options.apply({"edge_turn": true})
	ok(RIG.edge_turn, "se vuelve a encender")
