# T32 (UI-MUNDO, GDD_v3 §6.6) — cámara EN RIEL, sin pantalla:
#  - el riel de la buhardilla (5 puntos, vuelta entera) y de la tienda (4) salen de world/camera.json; los alias de los
#    encuadres de antes llevan a su punto; los lugares sin riel propio arman uno con sus encuadres ordenados por rumbo;
#  - interpolación continua: girando con la banda del borde (45 °/s), a tirones (arrastre) o con un salto de punto, la
#    cámara nunca salta más de 3° ni 5 cm por cuadro a 60 fps (todos los lugares y láminas);
#  - girando a la derecha desde el estante la cámara se desliza hacia el escritorio y después hacia la ventana;
#  - límites: cabeceo acotado, riel no cíclico acotado a sus extremos, FOV de la rueda −18°/+4° (y se deshace);
#  - un tramo largo (> 6 m) no deja la cámara parada a mitad de camino;
#  - alcance: todo nodo que se tocaba desde algún encuadre de antes se toca desde algún punto del riel;
#  - un clic sobre un nodo lo informa y NO mueve la cámara (no hay acercamiento ni pila de poses);
#  - no queda ningún chevrón en el código de la interfaz; Opciones apaga las bandas del borde.
# La parte con ventana y eventos reales (borde, clic en el expediente, rueda) está en test_t32_camera_window.gd.
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

func _new_world(fast := true):
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(fast)
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

func _all_places() -> Dictionary:
	var r = repo()
	var all := {}
	for k in r.places(): all[k] = r.places()[k]
	for k in r.plates(): all[k] = r.plates()[k]
	return all

func test_rails_from_camera_json_and_aliases() -> void:
	var wr = await _hub()
	eq(wr.rig.mode(), "rail", "riel")
	eq(wr.frames(), ["escritorio", "estante", "mapa", "puerta", "ventana"], "buhardilla: 5 puntos")
	ok(wr.rig.wraps(), "la buhardilla se mira en redondo (vuelta entera)")
	eq(wr.rig.cur, "escritorio", "se entra mirando el escritorio")
	var cfg: Dictionary = RIG.cfg_for("L1", "buhardilla")
	for r in cfg.rail:
		wr.set_frame(str(r.id), true)
		near(wr.camera().global_position.distance_to(RIG._v3(r.pos)), 0.0, 0.001, "%s: en su posición" % r.id)
		var fwd: Vector3 = -wr.camera().global_transform.basis.z
		var want: Vector3 = (RIG._v3(r.look) - RIG._v3(r.pos)).normalized()
		ok(rad_to_deg(fwd.angle_to(want)) < 0.5, "%s: mirando su punto (%.2f°)" % [r.id, rad_to_deg(fwd.angle_to(want))])
		near(wr.camera().fov, float(r.fov), 0.01, "%s: su FOV" % r.id)
		eq(wr.rig.cur, str(r.id), "cur")
	for al in [["general", "escritorio"], ["pared", "mapa"], ["plano", "mapa"]]:
		wr.set_frame(str(al[0]), true)
		eq(wr.rig.cur, str(al[1]), "alias %s → %s" % al)
	after_each()
	var w2 = await _place("L1", "tienda")
	eq(w2.frames(), ["estantes", "mostrador", "escalera", "revistas"], "tienda: 4 puntos")
	eq(w2.rig.cur, "mostrador", "se entra mirando el mostrador (Crane)")
	w2.set_frame("escaparate", true)
	eq(w2.rig.cur, "estantes", "alias escaparate → estantes")
	after_each()
	# un lugar sin riel propio: sus encuadres ordenados por rumbo, el parámetro creciente, el de inicio el primero del área
	var w3 = await _place("L4", "consulta")
	ok(not w3.rig.wraps(), "un lugar no da la vuelta entera")
	var hs: Array = []
	var ss: Array = []
	for r in w3.rig.rail:
		hs.append(float(r.h)); ss.append(float(r.s))
	for i in range(1, hs.size()):
		ok(hs[i] >= hs[i - 1] - 0.001 and ss[i] > ss[i - 1], "ordenado por rumbo y parámetro creciente")
	eq(w3.rig.cur, "consultorio", "el primer encuadre del área")

# Rumbo, cabeceo y posición de la cámara dibujada.
static func _pose(cam: Camera3D) -> Array:
	return [cam.global_position, -cam.global_transform.basis.z]

func _run_check(wr, steps: int, dt: float, drive: Callable) -> Dictionary:
	var cam: Camera3D = wr.camera()
	var prev := _pose(cam)
	var worst_a := 0.0
	var worst_p := 0.0
	var worst_f := 0.0
	var pf := cam.fov
	for i in steps:
		drive.call(i)
		wr.rig.smooth_step(dt)
		var cur := _pose(cam)
		worst_a = maxf(worst_a, rad_to_deg((prev[1] as Vector3).angle_to(cur[1])))
		worst_p = maxf(worst_p, (prev[0] as Vector3).distance_to(cur[0]))
		worst_f = maxf(worst_f, absf(cam.fov - pf))
		prev = cur
		pf = cam.fov
	return {"a": worst_a, "p": worst_p, "f": worst_f}

func test_continuous_without_jumps() -> void:
	var dt := 1.0 / 60.0
	var wr = await _hub()
	wr.rig.fast = false
	# banda del borde a fondo (45 °/s) una vuelta entera y algo más, a la derecha y a la izquierda
	var r1 := _run_check(wr, 60 * 10, dt, func(_i): wr.rig.look_by(-45.0 * dt, 0.0))
	ok(r1.a < 3.0 and r1.p < 0.05, "buhardilla, borde derecho 10 s: ≤3°/≤5 cm por cuadro (%.2f°, %.1f cm)" % [r1.a, r1.p * 100.0])
	var r2 := _run_check(wr, 60 * 10, dt, func(_i): wr.rig.look_by(45.0 * dt, 0.0))
	ok(r2.a < 3.0 and r2.p < 0.05, "buhardilla, borde izquierdo 10 s (%.2f°, %.1f cm)" % [r2.a, r2.p * 100.0])
	# a tirones: arrastres de 200 px por cuadro, y saltos de punto (set_frame se desliza)
	var r3 := _run_check(wr, 240, dt, func(i):
		if i % 30 < 6:
			wr.rig.drag_by(Vector2(200, 30)))
	ok(r3.a < 3.0 and r3.p < 0.05, "arrastres bruscos (%.2f°, %.1f cm)" % [r3.a, r3.p * 100.0])
	var r4 := _run_check(wr, 360, dt, func(i):
		if i % 90 == 0:
			wr.rig.set_frame(["mapa", "ventana", "estante", "puerta"][int(i / 90.0) % 4]))
	ok(r4.a < 3.0 and r4.p < 0.05, "ir a un punto se desliza (%.2f°, %.1f cm)" % [r4.a, r4.p * 100.0])
	var r5 := _run_check(wr, 240, dt, func(i):
		if i == 0: wr.rig.wheel(-1.0, Vector2(20, 10))
		if i == 60: wr.rig.wheel(-1.0, Vector2(-20, -5))
		if i == 120: wr.rig.wheel(1.0)
		if i == 180: wr.rig.wheel(1.0))
	ok(r5.a < 3.0 and r5.f < 3.0, "rueda (%.2f°, %.2f° de FOV)" % [r5.a, r5.f])
	after_each()
	# todos los lugares y láminas: recorrer el riel entero ida y vuelta con el borde
	var bad: Array = []
	var all := _all_places()
	var keys: Array = all.keys()
	keys.sort()
	for pid in keys:
		var pl: Dictionary = all[pid]
		var areas: Array = (pl.get("areas", {}) as Dictionary).keys() if pl.get("areas", {}) is Dictionary else []
		if areas.is_empty(): areas = ["*"]
		for area in areas:
			var w = await _place(str(pid), str(area))
			w.rig.fast = false
			w.rig.yaw_t = w.rig.s_min; w.rig.yaw_off = w.rig.s_min; w.rig._apply()
			var span: float = w.rig.s_max - w.rig.s_min
			var n := int(ceil(span / 45.0 * 60.0)) + 120
			var rr := _run_check(w, n, dt, func(_i): w.rig.look_by(45.0 * dt, 0.0))
			if rr.a >= 3.0 or rr.p >= 0.05:
				bad.append("%s.%s: %.2f° %.1f cm" % [pid, area, rr.a, rr.p * 100.0])
			after_each()
	eq(bad, [], "lugares con saltos por cuadro")

# GDD_v3 §7.2 P4: «girar con el borde desliza la cámara hacia el escritorio y luego hacia la ventana sin saltos».
func test_turning_right_slides_to_desk_then_window() -> void:
	var dt := 1.0 / 60.0
	var wr = await _hub("estante")
	wr.rig.fast = false
	var cam: Camera3D = wr.camera()
	var cfg: Dictionary = RIG.cfg_for("L1", "buhardilla")
	var pts := {}
	for r in cfg.rail:
		pts[str(r.id)] = RIG._v3(r.pos)
	var seq: Array = [wr.rig.cur]
	var min_desk := INF
	var t_desk := -1
	var turn_s: float = (75.0 - (-30.0)) / 45.0
	for i in int((turn_s + 1.5) * 60.0):
		if i < int(turn_s * 60.0):
			wr.rig.look_by(-45.0 * dt, 0.0)   # borde derecho
		wr.rig.smooth_step(dt)
		if seq[-1] != wr.rig.cur:
			seq.append(wr.rig.cur)
		var dd := cam.global_position.distance_to(pts.escritorio)
		if dd < min_desk:
			min_desk = dd
			t_desk = i
	eq(seq, ["estante", "escritorio", "ventana"], "pasa por el escritorio y llega a la ventana")
	ok(min_desk < 0.1, "la cámara pasa por el punto del escritorio (a %.2f m)" % min_desk)
	ok(cam.global_position.distance_to(pts.ventana) < 0.05, "y se queda en el de la ventana (a %.2f m)" % cam.global_position.distance_to(pts.ventana))
	ok(t_desk > 0, "el escritorio llega antes que la ventana")

func test_limits_pitch_ends_and_wheel() -> void:
	var wr = await _hub()
	wr.rig.look_now(0.0, 100.0)
	near(wr.rig.pitch_off, 14.0, 0.001, "cabeceo acotado (±14° en la buhardilla)")
	wr.rig.look_now(500.0, -200.0)
	near(wr.rig.pitch_off, -14.0, 0.001, "hacia abajo también")
	ok(wr.rig.wraps(), "en la buhardilla el giro no tiene tope")
	after_each()
	var w2 = await _place("L4", "consulta")
	w2.rig.look_now(10000.0, 0.0)
	near(w2.rig.yaw_off, w2.rig.s_max, 0.001, "riel no cíclico: tope a la izquierda")
	w2.rig.look_now(-20000.0, 0.0)
	near(w2.rig.yaw_off, w2.rig.s_min, 0.001, "tope a la derecha")
	w2.rig.go_overview(true)
	var p0: Vector3 = w2.camera().global_position
	var f0: float = w2.camera().fov
	w2.rig.zoom_by(20.0)
	near(w2.camera().fov, f0 + 4.0, 0.001, "FOV +4 como máximo")
	w2.rig.zoom_by(-20.0)
	near(w2.camera().fov, f0 - 18.0, 0.001, "FOV −18 como mínimo")
	ok(w2.camera().global_position.is_equal_approx(p0), "el zoom no traslada")
	w2.rig.zoom_by(6.0)
	w2.rig.go_overview(true)
	var yaw0: Vector3 = -w2.camera().global_transform.basis.z
	w2.rig.wheel(-1.0, Vector2(30.0, 0.0))
	var yaw1: Vector3 = -w2.camera().global_transform.basis.z
	ok(rad_to_deg(yaw0.angle_to(yaw1)) > 5.0, "la rueda gira hacia el cursor")
	ok(w2.camera().global_position.is_equal_approx(p0), "sin moverse por el riel")
	w2.rig.wheel(1.0)
	near(rad_to_deg(yaw0.angle_to(-w2.camera().global_transform.basis.z)), 0.0, 0.01, "alejar deshace el giro")

# Soltado el giro a mitad de camino, la cámara se desliza sola al punto más cercano (también entre salas lejanas).
func test_rest_settles_on_a_point() -> void:
	for job in [["L1", "buhardilla"], ["L2", "*"]]:
		var wr = null
		if job[0] == "L1":
			wr = await _hub()
		else:
			wr = await _place(job[0], job[1])
		wr.rig.fast = false
		var mid := (float(wr.rig.rail[1].s) + float(wr.rig.rail[2].s)) * 0.5 + 3.0
		wr.rig.yaw_t = mid; wr.rig.yaw_off = mid; wr.rig._apply()
		for i in 60 * 4:
			wr.rig.smooth_step(1.0 / 60.0)
		var at := ""
		for r in wr.rig.rail:
			if absf(wr.rig.yaw_off - float(r.s)) < 0.5:
				at = str(r.id)
		ok(at != "", "%s: terminó en un punto del riel (yaw %.1f)" % [job[0], wr.rig.yaw_off])
		eq(at, str(wr.rig.rail[2].id), "%s: el más cercano" % job[0])
		after_each()

# playtest v3: un empujón corto por el borde (22° de 75°) no vuelve al escritorio: se asienta en el punto hacia el que giraba
func test_short_edge_push_settles_forward() -> void:
	var wr = await _hub()
	wr.rig.fast = false
	wr.rig.set_frame("escritorio", true)
	var s0 := float(wr.rig.yaw_off)
	wr.rig.look_by(22.0, 0.0)
	for i in 60 * 4:
		wr.rig.smooth_step(1.0 / 60.0)
	eq(wr.rig.cur, "estante", "girando a la izquierda 22° se asienta en el estante (yaw %.1f → %.1f)" % [s0, wr.rig.yaw_off])
	wr.rig.set_frame("escritorio", true)
	wr.rig.look_by(8.0, 0.0)
	for i in 60 * 4:
		wr.rig.smooth_step(1.0 / 60.0)
	eq(wr.rig.cur, "escritorio", "un roce de 8° vuelve al escritorio")
	wr.rig.set_frame("estante", true)
	wr.rig.look_by(-22.0, 0.0)
	for i in 60 * 4:
		wr.rig.smooth_step(1.0 / 60.0)
	eq(wr.rig.cur, "escritorio", "y de vuelta: 22° a la derecha desde el estante llega al escritorio")

func test_click_reports_and_does_not_move_camera() -> void:
	var wr = await _hub()
	var got: Array = []
	wr.node_clicked.connect(func(id): got.append(id))
	var cam: Camera3D = wr.camera()
	var x0: Transform3D = cam.global_transform
	var f0 := cam.fov
	var p := _visible_point(wr, "expediente")
	ok(p.x >= 0.0, "el expediente se ve desde el escritorio")
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		tree.root.push_input(ev)
	for _i in 10: await tree.process_frame
	eq(got, ["expediente"], "el clic informa el objeto")
	ok(cam.global_transform.is_equal_approx(x0) and is_equal_approx(cam.fov, f0), "y la cámara no se movió")
	ok(wr.examine("tintero"), "examine() existe (compatibilidad)")
	no(wr.is_examining(), "pero no hay acercamiento")
	no(wr.back(), "ni pila de poses que bajar")
	ok(cam.global_transform.is_equal_approx(x0), "nada movió la cámara")

func _visible_point(wr, nid: String) -> Vector2:
	var b: Node3D = wr.node_body(nid)
	if b == null: return Vector2(-1, -1)
	var cam: Camera3D = wr.camera()
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 120, 6):
		for k in 16:
			var q := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if str(wr.pick(q).get("id", "")) == nid: return q
			if r == 0: break
	return Vector2(-1, -1)

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
	ok(wr.edge_allowed(), "con mouse real, sin interfaz debajo")
	wr.edge_enabled = false
	no(wr.edge_allowed(), "con un panel abierto (edge_enabled lo apaga la pantalla de juego) no gira")
	wr.edge_enabled = true
	wr.set_input_enabled(false)
	no(wr.edge_allowed(), "con un panel que tapa el 3D (sin entrada) no gira")
	wr.set_input_enabled(true)
	# playtest v3: al cerrar un panel el mouse queda sobre el botón Volver, en la franja; no gira hasta salir de ella
	no(wr.edge_allowed(), "recién reactivada la entrada no gira (el mouse puede estar en la franja)")
	var vsz: Vector2 = tree.root.get_visible_rect().size
	var m1 := InputEventMouseMotion.new()
	m1.position = Vector2(4, vsz.y * 0.5)
	m1.global_position = m1.position
	tree.root.push_input(m1)
	await tree.process_frame
	no(wr.edge_allowed(), "moverse dentro de la franja no la arma")
	var m2 := InputEventMouseMotion.new()
	m2.position = vsz * 0.5
	m2.global_position = m2.position
	tree.root.push_input(m2)
	await tree.process_frame
	if tree.root.gui_get_hovered_control() == null:
		ok(wr.edge_allowed(), "tras salir de la franja vuelve a girar")
	wr.edge_enabled = false
	wr.edge_enabled = true
	no(wr.edge_allowed(), "lo mismo al cerrar un panel (edge_enabled vuelve a true)")
	wr._edge_armed = true
	RIG.edge_turn = false
	no(wr.edge_allowed(), "opción apagada")
	RIG.edge_turn = true
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

# --- alcance (la deducción no pierde nodos por la cámara nueva)
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
	var all := _all_places()
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
			var cam: Camera3D = wr.camera()
			# ahora: el riel entero cada 5° con tres cabeceos
			var now := {}
			var s: float = wr.rig.s_min
			while s <= wr.rig.s_max + 0.001:
				for pt in [-1.0, 0.0, 1.0]:
					wr.rig.yaw_t = s; wr.rig.yaw_off = s
					wr.rig.pitch_t = pt * wr.rig.pitch_lim; wr.rig.pitch_off = wr.rig.pitch_t
					wr.rig._apply()
					wr._update_cutaway(true)
					_touch_now(wr, cam, ids, now)
				s += 5.0
			# antes: cada encuadre del área del lugar, tal cual
			var before := {}
			for f in pl.get("frames", []):
				var fa := str(f.get("area", "*"))
				if not (fa == "*" or area == "*" or fa == area): continue
				var pos := RIG._v3(f.pos)
				var look := RIG._v3(f.look)
				cam.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
				cam.fov = float(f.get("fov", 45.0))
				wr._update_cutaway(true)
				_touch_now(wr, cam, ids, before)
			n_before += before.size()
			n_now += now.size()
			for nid in before:
				if not now.has(nid): lost.append("%s.%s:%s" % [pid, area, nid])
			after_each()
	ok(n_before > 100, "la comparación mira algo (%d nodos tocables antes, %d ahora)" % [n_before, n_now])
	eq(lost, [], "nodos que antes se tocaban desde un encuadre y con el riel no")

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
