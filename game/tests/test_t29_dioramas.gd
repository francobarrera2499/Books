# T29 (W1-3D; lugares: W2-PLACES). GDD§14.4 / ARCHITECTURE §7.6, §9.2:
#  - todo nodo tiene `examine`;
#  - recorte por rectángulo: nodo encuadrado → cover ≥ 0,5 y tight (root.size 1600×900); nodo tras un ocluidor → ocluido;
#  - Wiggins (silueta) en el frustum y sin tapar en su encuadre (desde el día 3); la línea de tiro (L7) recortable sola.
# Corre sobre tests/fixtures/places/sample.json y sobre los data/places/*.json existentes (faltantes → pending_content).
extends "res://tests/test_base.gd"

const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")

const TIMEOUT_S := 300.0

var _wr = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		_wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null

func _sample() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/places/sample.json"))

func _full_snap(place: Dictionary, area: String, slot := "M", frame := "") -> Dictionary:
	var ids: Array = []
	for n in place.get("nodes", []): ids.append(str(n["id"]))
	var chars: Array = []
	for c in place.get("characters", []):
		var a := str(c.get("area", "*"))
		if a == "*" or area == "*" or a == area:
			chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "de_pie")), "trait": str(c.get("trait", ""))})
	var sils: Array = (place.get("silhouettes", {}) as Dictionary).keys() if place.get("silhouettes", {}) is Dictionary else []
	return {"id": "PL.%s.3.%s" % [place.get("id", "X"), slot], "place": place.get("id", ""), "area": area, "day": 3, "slot": slot,
		"variant": "", "nodes": ids, "chars": chars, "silhouettes": sils, "frame": frame}

func _world(place: Dictionary, snap: Dictionary):
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.show_plate(snap, place)
	await tree.physics_frame
	await tree.physics_frame
	return _wr

func _frame_area(place: Dictionary, fid: String) -> String:
	for f in place.get("frames", []):
		if str(f.get("id", "")) == fid:
			var a := str(f.get("area", "*"))
			if a != "*": return a
	var areas = place.get("areas", {})
	if areas is Dictionary and not areas.is_empty(): return str(areas.keys()[0])
	return "*"

# rectángulo ajustado alrededor del ancla visible del nodo
func _rect_around(wr, nid: String, grow := 0.06) -> Rect2:
	var body = wr.node_body(nid)
	if body == null: return Rect2()
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body).intersection(vp)
	return a.grow(maxf(2.0, a.size.length() * grow)).intersection(vp)

func _clip_alone(wr, nid: String) -> Dictionary:
	var r := _rect_around(wr, nid, 0.03)
	if r.get_area() <= 0.0: return {"ok": false, "why": "fuera de cuadro"}
	var res: Dictionary = wr.rect_clip(r)
	var big: Array = []
	for h in res["hits"]:
		if float(h["cover"]) >= 0.5: big.append(h)
	var why := ""
	if float(res["area_frac"]) > 0.125: why = "rectángulo > 1/8 (%.3f)" % float(res["area_frac"])
	elif big.size() != 1 or str(big[0]["node"]) != nid: why = "captura %s" % str(big)
	elif not bool(big[0]["tight"]): why = "no ajustado"
	return {"ok": why == "", "why": why, "res": res}

# Criterio del juego para que un recorte de lámina lleve las etiquetas del nodo (Clipper.act_clip_plate): rectángulo ≤ 1/8,
# a lo sumo MAX_PLATE_HITS nodos con cover ≥ 0,5, el nodo pedido es el de mayor cover y está ajustado.
func _clip_for_route(wr, nid: String) -> Dictionary:
	var r := _rect_around(wr, nid, 0.03)
	if r.get_area() <= 0.0: return {"ok": false, "why": "fuera de cuadro"}
	var res: Dictionary = wr.rect_clip(r)
	var big: Array = []
	for h in res["hits"]:
		if float(h["cover"]) >= 0.5: big.append(h)
	big.sort_custom(func(x, y): return float(x["cover"]) > float(y["cover"]) or (float(x["cover"]) == float(y["cover"]) and str(x["node"]) < str(y["node"])))
	var why := ""
	if float(res["area_frac"]) > 0.125: why = "rectángulo > 1/8 (%.3f)" % float(res["area_frac"])
	elif big.is_empty() or str(big[0]["node"]) != nid: why = "captura %s" % str(big)
	elif big.size() > 2: why = "más de 2 nodos %s" % str(big)
	elif not bool(big[0]["tight"]): why = "no ajustado"
	return {"ok": why == "", "why": why}

# «sin tapar» (GDD§14.4): en cuadro y con la mayoría de los puntos de muestra del ancla a la vista (no basta un hombro)
func _visible_in_frame(wr, nid: String) -> String:
	var body = wr.node_body(nid)
	if body == null: return "no existe el nodo"
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body)
	if a.get_area() <= 0.0: return "detrás de la cámara"
	if not vp.has_point(a.get_center()): return "fuera del frustum"
	if a.intersection(vp).get_area() < 0.6 * a.get_area(): return "más de 40 % fuera de cuadro"
	var vis: Vector2i = RC.visible_points(cam, body, wr.diorama, wr.excluded_rids())
	if vis.x == 0: return "tapado"
	if vis.x * 2 <= vis.y: return "tapado en buena parte (%d de %d puntos a la vista)" % [vis.x, vis.y]
	return ""

# ---------------------------------------------------------------------------------------------
func test_sample_every_node_has_examine() -> void:
	var place := _sample()
	var nodes: Array = place["nodes"].duplicate()
	for v in place.get("variants", {}).values():
		nodes.append_array(v.get("add_nodes", []))
	for n in nodes:
		ok(str(n.get("examine", "")).strip_edges() != "", "nodo %s sin examine" % n.get("id"))

func test_sample_framed_node_cover_and_tight() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	wr.set_frame("escritorio", true)
	await tree.physics_frame
	var r := _rect_around(wr, "lupa")
	var res: Dictionary = wr.rect_clip(r)
	ok(float(res["area_frac"]) <= 0.125, "rectángulo chico")
	var hit := {}
	for h in res["hits"]:
		if h["node"] == "lupa": hit = h
	ok(not hit.is_empty(), "la lupa no está en hits: %s" % str(res))
	if hit.is_empty(): return
	ok(float(hit["cover"]) >= 0.5, "cover %.2f" % float(hit["cover"]))
	ok(bool(hit["tight"]), "tight")
	has(res["touched"], "lupa", "touched")
	# un rectángulo enorme sobre el mismo nodo ya no es ajustado
	var cam: Camera3D = wr.camera()
	var big := Rect2(r.get_center() - Vector2(300, 200), Vector2(600, 400))
	var res2: Dictionary = wr.rect_clip(big)
	for h in res2["hits"]:
		if h["node"] == "lupa": ok(not bool(h["tight"]), "rectángulo grande no es tight")

func test_sample_node_behind_occluder_is_occluded() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "puerta"))
	wr.set_frame("puerta", true)
	await tree.physics_frame
	var r := _rect_around(wr, "detras_armario")
	ok(r.get_area() > 0.0, "el cajón proyecta en pantalla")
	var res: Dictionary = wr.rect_clip(r)
	for h in res["hits"]:
		ok(h["node"] != "detras_armario", "el cajón tras el armario no debe capturarse")
	has(res["occluded"], "detras_armario", "ocluidos")
	no("detras_armario" in res["touched"], "lo tapado no se lista como tocado")
	ok(RC.is_occluded(wr.camera(), wr.node_body("detras_armario"), wr.diorama, wr.excluded_rids()), "is_occluded")
	# el armario mismo sí se ve
	no(RC.is_occluded(wr.camera(), wr.node_body("armario"), wr.diorama, wr.excluded_rids()), "el armario se ve")
	# visto del otro lado (desde la ventana hacia el cajón) el armario ya no lo tapa: la oclusión depende del punto de vista
	var cam: Camera3D = wr.camera()
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.9, 1.3, -0.6)).looking_at(Vector3(0.9, 0.22, 0.75), Vector3.UP)
	await tree.physics_frame
	no(RC.is_occluded(cam, wr.node_body("detras_armario"), wr.diorama, wr.excluded_rids()), "desde el otro lado el cajón se ve")
	var r2 := _rect_around(wr, "detras_armario")
	var res2: Dictionary = wr.rect_clip(r2)
	has(res2["touched"], "detras_armario", "desde el otro lado se toca")

func test_sample_wiggins_visible_in_his_frame() -> void:
	var place := _sample()
	var fr := str(place["silhouettes"]["wiggins"]["frame"])
	var wr = await _world(place, _full_snap(place, _frame_area(place, fr), "M", fr))
	wr.set_frame(fr, true)
	await tree.physics_frame
	eq(_visible_in_frame(wr, "sil_wiggins"), "", "Wiggins en %s" % fr)

# §4.11: cada silueta tiene «posición garantizada sin tapar en el encuadre frame»
func test_sample_every_silhouette_visible_in_its_frame() -> void:
	var place := _sample()
	var msgs := await _silhouettes_check(place)
	eq(msgs, [], "siluetas")

func _silhouettes_check(pl: Dictionary) -> Array:
	var out: Array = []
	var sils: Dictionary = pl.get("silhouettes", {}) if pl.get("silhouettes", {}) is Dictionary else {}
	var who_list: Array = sils.keys()
	who_list.sort()
	for who in who_list:
		var fr := str((sils[who] as Dictionary).get("frame", ""))
		await _world(pl, _full_snap(pl, _frame_area(pl, fr), "M", fr))
		if not _wr.rig.has_frame(fr):
			out.append("%s: %s apunta a un encuadre inexistente '%s'" % [pl.get("id", "?"), who, fr])
		else:
			_wr.set_frame(fr, true)
			await tree.physics_frame
			var why := _visible_in_frame(_wr, "sil_" + str(who))
			if why != "": out.append("%s: %s en el encuadre %s: %s" % [pl.get("id", "?"), who, fr, why])
		after_each()
	return out

func test_sample_nodes_clippable_alone() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	for pair in [["escritorio", "lupa"], ["escritorio", "carta"], ["puerta", "crespon"], ["ventana", "sil_wiggins"]]:
		wr.set_frame(pair[0], true)
		await tree.physics_frame
		var r := _clip_alone(wr, pair[1])
		ok(bool(r["ok"]), "%s solo desde %s: %s" % [pair[1], pair[0], r["why"]])

func test_sample_pick_node_char_none() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	wr.set_frame("escritorio", true)
	await tree.physics_frame
	var cam: Camera3D = wr.camera()
	var p_lupa := cam.unproject_position(wr.node_body("lupa").global_position)
	eq(wr.pick(p_lupa), {"kind": "node", "id": "lupa"}, "clic en la lupa")
	var got := []
	wr.node_clicked.connect(func(id): got.append(id))
	wr._click(p_lupa)
	eq(got, ["lupa"], "señal node_clicked")
	wr.set_frame("puerta", true)
	await tree.physics_frame
	var ci: Dictionary = wr.diorama.get_meta("chars_index")
	var wat: Node3D = ci["watson"]
	var p_w := cam.unproject_position(wat.global_position + Vector3(0, 1.1, 0))
	eq(wr.pick(p_w), {"kind": "char", "id": "watson"}, "clic en Watson")
	eq(wr.pick_character(p_w), "watson", "pick_character")
	# techo/pared: vacío
	eq(str(wr.pick(Vector2(800, 20))["kind"]), "none", "clic en el techo")

func test_sample_cutaway_and_frames() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "puerta"))
	var fr: Array = wr.frames()
	fr.sort()
	eq(fr, ["escritorio", "puerta", "ventana"], "frames(): los puntos del riel (los encuadres del lugar)")
	eq(wr.current_plate(), "PL.SAMPLE.3.M", "current_plate")
	wr.set_frame("puerta", true)
	await tree.physics_frame
	var ws: Node3D = wr.diorama.get_node("Props/cuarto/wall_s")
	var wn: Node3D = wr.diorama.get_node("Props/cuarto/wall_n")
	no(ws.visible, "desde afuera el muro sur se corta")
	ok(wn.visible, "el muro norte queda")
	ok(wr.excluded_rids().size() >= 1, "el oclusor del muro cortado no cuenta")
	wr.set_frame("ventana", true)
	await tree.physics_frame
	ok(ws.visible, "desde adentro se ven todos los muros")

# v3 (GDD_v3 §6.6, UI-MUNDO): en un lugar sin riel propio en world/camera.json los encuadres son los puntos del riel
# (ordenados por rumbo); el de inicio es el primero del área; mirar arriba/abajo acotado; el riel no cíclico se acota a sus
# extremos; FOV entre base −18° y base +4°; examinar no acerca ni hay pila de poses.
func test_sample_orbit_limits_and_examine() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "puerta"))
	wr.set_frame("puerta", true)
	eq(wr.rig.mode(), "rail", "riel")
	eq(wr.rig.cur, "puerta", "el encuadre pedido")
	var cam: Camera3D = wr.camera()
	var p0 := cam.global_position
	wr.rig.look_now(0.0, 100.0)
	near(wr.rig.pitch_off, wr.rig.pitch_lim, 0.001, "cabeceo acotado")
	ok(cam.global_position.is_equal_approx(p0), "mirar arriba no traslada")
	wr.rig.look_now(1000.0, 0.0)
	near(wr.rig.yaw_off, wr.rig.s_max, 0.001, "giro acotado al extremo del riel")
	wr.set_frame("puerta", true)
	ok(cam.global_position.is_equal_approx(p0), "set_frame restituye el punto")
	var f0 := cam.fov
	wr.rig.zoom_by(20.0)
	near(cam.fov, f0 + 4.0, 0.001, "FOV +4 como máximo")
	wr.rig.zoom_by(-20.0)
	near(cam.fov, f0 - 18.0, 0.001, "FOV −18 como mínimo")
	wr.rig.zoom_by(6.0)
	wr.set_orbit_enabled(false)
	wr.set_frame("puerta", true)
	wr.rig.look_now(10.0, 0.0)
	near(wr.rig.yaw_off, float(wr.rig.rail[wr.rig.index_of("puerta")].s), 0.001, "sin girar si está apagado")
	wr.set_orbit_enabled(true)
	var x0 := cam.global_transform
	ok(wr.examine("lupa"), "examinar existe")
	no(wr.is_examining(), "pero no acerca la cámara")
	ok(cam.global_transform.is_equal_approx(x0), "la cámara no se movió")
	no(wr.back(), "no hay pila de poses")

# ---------------------------------------------------------------------------------------------
# Lugares reales (data/places/*.json, W2-PLACES-*)
func _places() -> Dictionary:
	var r = repo()
	if r == null or not r.has_method("places"): return {}
	var p = r.places()
	return p if p is Dictionary else {}

func _plates() -> Dictionary:
	var r = repo()
	if r == null or not r.has_method("plates"): return {}
	var p = r.plates()
	return p if p is Dictionary else {}

func test_places_every_node_has_examine() -> void:
	var places := _places()
	if places.is_empty():
		pending_content("no hay data/places/*.json todavía"); return
	# láminas fijas (plates/*.json) incluidas: mismo esquema, también se examinan y recortan
	var all := places.duplicate()
	var plates := _plates()
	for k in plates: all["plate:" + str(k)] = plates[k]
	for pid in all:
		var pl: Dictionary = all[pid]
		var nodes: Array = (pl.get("nodes", []) as Array).duplicate()
		var vs = pl.get("variants", {})
		if vs is Dictionary:
			for v in vs.values():
				if v is Dictionary: nodes.append_array(v.get("add_nodes", []))
		for n in nodes:
			ok(str(n.get("examine", "")).strip_edges() != "", "%s: nodo %s sin examine" % [pid, n.get("id")])

func test_places_wiggins_visible() -> void:
	var places := _places()
	if places.is_empty():
		pending_content("no hay data/places/*.json todavía"); return
	var pids: Array = places.keys()
	pids.sort()
	for pid in pids:
		var pl: Dictionary = places[pid]
		var sils = pl.get("silhouettes", {})
		if not (sils is Dictionary) or not sils.has("wiggins"):
			# GDD§14.4: cada lugar, también L1 (ventana a la calle, «Wiggins desde el día 3», GDD§5)
			pending_content("%s sin silueta de Wiggins" % pid)
		# Wiggins y toda otra silueta (m3_hombres, cochero…) sin tapar en su encuadre (§4.11)
		for m in await _silhouettes_check(pl):
			fail(m)

func test_places_line_of_fire_clippable_alone() -> void:
	var places := _places()
	var found := false
	for pid in places:
		var pl: Dictionary = places[pid]
		var has_line := false
		for n in pl.get("nodes", []):
			if str(n.get("id", "")) == "linea_de_tiro": has_line = true
		if not has_line: continue
		found = true
		var reasons: Array = []
		var any_ok := false
		for f in pl.get("frames", []):
			var fid := str(f.get("id", ""))
			await _world(pl, _full_snap(pl, _frame_area(pl, fid), "M", fid))
			_wr.set_frame(fid, true)
			await tree.physics_frame
			var r := _clip_alone(_wr, "linea_de_tiro")
			after_each()
			if r["ok"]: any_ok = true; break
			reasons.append("%s: %s" % [fid, r["why"]])
		ok(any_ok, "%s: la línea de tiro no se recorta sola en ningún encuadre (%s)" % [pid, "; ".join(reasons)])
	if not found:
		pending_content("ningún lugar con nodo linea_de_tiro (L7)")

# Todo nodo N: que una ruta de data/dossier.json (v3; antes conclusions.json) usa se recorta SOLO (rectángulo ≤ 1/8, cover ≥ 0,5, ajustado) desde
# algún encuadre de su lugar o lámina, con la instantánea del primer día y franja en que existe (hallazgo del playtest:
# T29 sólo probaba la línea de tiro). Nodos que pone un efecto (rastro) o un lugar inexistente: se informan aparte.
func test_route_nodes_clippable_alone() -> void:
	var r = repo()
	var txt := FileAccess.get_file_as_string("res://data/dossier.json")
	var rx := RegEx.new()
	rx.compile("\"N:([A-Za-z0-9_.]+)\"")
	var refs: Array = []
	for m in rx.search_all(txt):
		if not refs.has(m.get_string(1)):
			refs.append(m.get_string(1))
	refs.sort()
	if refs.is_empty():
		pending_content("dossier.json sin nodos N:")
		return
	var Cond = load("res://core/util/cond.gd")
	var TK = load("res://core/util/timekey.gd")
	var bad: Array = []
	for ref in refs:
		var parts: PackedStringArray = String(ref).split(".")
		var pid := parts[0]
		if pid == "*":
			continue   # rastro en cualquier lugar (N:*.sil_wiggins): lo pone un efecto
		var nid := parts[parts.size() - 1]
		var variant := parts[1] if parts.size() == 3 else ""
		var pl: Dictionary = r.place(pid)
		var fixed := false
		if pl.is_empty():
			pl = r.plate(pid)
			fixed = not pl.is_empty()
		if pl.is_empty():
			bad.append("%s: no existe el lugar o lámina %s" % [ref, pid])
			continue
		var nodes: Array = (pl.get("nodes", []) as Array).duplicate()
		var vd = (pl.get("variants", {}) as Dictionary).get(variant, {}) if pl.get("variants", {}) is Dictionary else {}
		if vd is Dictionary:
			nodes.append_array(vd.get("add_nodes", []))
		var nd := {}
		for n in nodes:
			if str(n.get("id", "")) == nid:
				nd = n
		if nd.is_empty():
			continue   # nodo que deja un efecto (rastro): no está en la lámina estática
		# primer día/franja en que el nodo existe (when de calendario)
		var day := int(pl.get("day", 3)) if fixed else -1
		var slot := str(pl.get("slot", "M")) if fixed else ""
		if not fixed:
			for d in range(1, 11):
				for sl in ["M", "T", "N"]:
					var w = nd.get("when", {})
					if day < 0 and (not (w is Dictionary) or (w as Dictionary).is_empty() or Cond.eval(w, {"st": null, "tk": TK.tk(d, sl)})):
						day = d
						slot = sl
		if day < 0:
			bad.append("%s: ningún día del calendario lo muestra" % ref)
			continue
		var node_area := str(nd.get("area", "*"))
		var reasons: Array = []
		var any_ok := false
		for f in pl.get("frames", []):
			var fid := str(f.get("id", ""))
			var farea := str(f.get("area", "*"))
			if node_area != "*" and farea != "*" and farea != node_area:
				continue
			var area := node_area if node_area != "*" else (farea if farea != "*" else _frame_area(pl, fid))
			var snap := _full_snap(pl, area, slot, fid)
			var ids: Array = []
			for n in nodes:
				var na := str(n.get("area", "*"))
				if area != "*" and na != "*" and na != area:
					continue
				var w2 = n.get("when", {})
				if w2 is Dictionary and not (w2 as Dictionary).is_empty() and not Cond.eval(w2, {"st": null, "tk": TK.tk(day, slot)}):
					continue
				ids.append(str(n["id"]))
			snap["nodes"] = ids
			snap["day"] = day
			snap["variant"] = variant
			snap["silhouettes"] = []
			await _world(pl, snap)
			_wr.set_frame(fid, true)
			await tree.physics_frame
			var res := _clip_for_route(_wr, nid)
			after_each()
			if res["ok"]:
				any_ok = true
				break
			reasons.append("%s: %s" % [fid, res["why"]])
		if not any_ok:
			bad.append("%s (día %d.%s): %s" % [ref, day, slot, "; ".join(reasons)])
	eq(bad, [], "nodos de rutas que no se recortan solos")

# ---------------------------------------------------------------------------------------------
# WorldRoot: entrada real (eventos empujados al viewport), precalentado y hub sin datos
func _mouse(btn: int, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	tree.root.push_input(ev)

func _motion(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(ev)

func test_worldroot_click_and_drag_orbit_by_events() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	wr.set_frame("escritorio", true)
	await tree.physics_frame
	ok(wr.is_plate_ready(), "plate_ready tras un physics_frame")
	var got := []
	wr.node_clicked.connect(func(id): got.append(id))
	var x0: Transform3D = wr.camera().global_transform
	var p: Vector2 = wr.camera().unproject_position(wr.node_body("lupa").global_position)
	_mouse(MOUSE_BUTTON_LEFT, true, p)
	_mouse(MOUSE_BUTTON_LEFT, false, p)
	await tree.process_frame
	eq(got, ["lupa"], "clic sobre la lupa → node_clicked")
	ok(wr.camera().global_transform.is_equal_approx(x0), "el clic no mueve la cámara (v3: se usa en el acto)")
	# arrastre sobre el vacío (techo) → gira; un toque de 3 px es clic
	wr.set_frame("puerta", true)
	await tree.physics_frame
	var empty := Vector2(800, 15)
	eq(str(wr.pick(empty)["kind"]), "none", "el techo está vacío")
	var empties := []
	wr.empty_clicked.connect(func(pos): empties.append(pos))
	var y0: float = wr.rig.yaw_off
	_mouse(MOUSE_BUTTON_LEFT, true, empty)
	_motion(empty + Vector2(40, 0), Vector2(40, 0))
	_motion(empty + Vector2(80, 0), Vector2(40, 0))
	_mouse(MOUSE_BUTTON_LEFT, false, empty + Vector2(80, 0))
	await tree.process_frame
	ok(absf(wr.rig.yaw_off - y0) > 5.0, "arrastre de 80 px gira (%.1f°)" % (wr.rig.yaw_off - y0))
	eq(empties.size(), 0, "un arrastre no es clic")
	_mouse(MOUSE_BUTTON_LEFT, true, empty)
	_motion(empty + Vector2(3, 0), Vector2(3, 0))
	_mouse(MOUSE_BUTTON_LEFT, false, empty + Vector2(3, 0))
	await tree.process_frame
	eq(empties.size(), 1, "3 px es clic (umbral 6 px)")
	var fov0: float = wr.camera().fov
	_mouse(MOUSE_BUTTON_WHEEL_UP, true, empty)
	await tree.process_frame
	ok(wr.camera().fov < fov0, "rueda arriba acerca (FOV menor)")

func test_worldroot_right_click_and_esc_leave_examine() -> void:
	# v3: no hay examen ni pila de poses; volver (clic derecho, Esc) no es del mundo y no mueve la cámara
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	wr.set_frame("escritorio", true)
	await tree.physics_frame
	var x0: Transform3D = wr.camera().global_transform
	_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(800, 450))
	_mouse(MOUSE_BUTTON_RIGHT, false, Vector2(800, 450))
	await tree.process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tree.root.push_input(esc)
	await tree.process_frame
	ok(wr.camera().global_transform.is_equal_approx(x0), "clic derecho y Esc no mueven la cámara")
	no(wr.is_examining(), "nunca se examina de cerca")

func test_worldroot_drag_from_node_is_not_a_click() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "escritorio"))
	wr.set_frame("escritorio", true)
	await tree.physics_frame
	var got := []
	wr.node_clicked.connect(func(id): got.append(id))
	wr.empty_clicked.connect(func(_p): got.append("vacio"))
	var cam: Camera3D = wr.camera()
	var a := cam.unproject_position(wr.node_body("lupa").global_position)
	var b := cam.unproject_position(wr.node_body("carta").global_position)
	ok(a.distance_to(b) > 40.0, "lupa y carta separadas en pantalla")
	var y0: float = wr.rig.yaw_off
	_mouse(MOUSE_BUTTON_LEFT, true, a)
	_motion(a.lerp(b, 0.5), (b - a) * 0.5)
	_motion(b, (b - a) * 0.5)
	_mouse(MOUSE_BUTTON_LEFT, false, b)
	await tree.process_frame
	eq(got, [], "arrastrar de la lupa a la carta no es clic en ninguna")
	ok(absf(wr.rig.yaw_off - y0) > 0.5, "v3: arrastrar gira la vista desde cualquier lado (se agarra el mundo)")

func test_cutaway_hides_nodes_on_cut_wall() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "puerta"))
	wr.set_frame("puerta", true)
	await tree.physics_frame
	var door: StaticBody3D = wr.node_body("puerta_sur")
	ok(door != null, "nodo de la puerta sur")
	no((wr.diorama.get_node("Props/cuarto/wall_s") as Node3D).visible, "muro sur cortado desde la puerta")
	has(wr.excluded_rids(), door.get_rid(), "la puerta del muro cortado no se clica")
	var cam: Camera3D = wr.camera()
	var p := cam.unproject_position(door.global_position)
	ne(wr.pick(p).get("id", ""), "puerta_sur", "clic donde estaría la puerta invisible")
	var r := RC.screen_rect(cam, door).intersection(cam.get_viewport().get_visible_rect())
	var res: Dictionary = wr.rect_clip(r.grow(-4.0))
	no("puerta_sur" in res["touched"], "lo invisible no se toca con la tijera")
	# los nodos de muros que quedan en pie siguen activos
	no(wr.excluded_rids().has((wr.node_body("ventana") as StaticBody3D).get_rid()), "la ventana del muro norte sigue")
	# desde adentro el muro sur vuelve y su puerta también
	wr.set_frame("ventana", true)
	await tree.physics_frame
	no(wr.excluded_rids().has(door.get_rid()), "desde adentro la puerta vuelve a contar")

func test_worldroot_prewarm_and_rebuild() -> void:
	var place := _sample()
	var wr = await _world(place, _full_snap(place, "estudio", "M", "puerta"))
	await wr.prewarm(place)
	await tree.process_frame
	eq(wr.find_children("Prewarm", "", false, false).size(), 0, "el precalentado se libera")
	var d0 = wr.diorama
	wr.show_plate(_full_snap(place, "estudio", "M", "puerta"), place)
	ok(wr.diorama == d0, "misma instantánea → no reconstruye")
	var s2 := _full_snap(place, "estudio", "N", "ventana")
	wr.show_plate(s2, place)
	ok(wr.diorama != d0, "otra franja → reconstruye")
	eq(str(wr.diorama.get_meta("light_preset")), "gas", "luz de la franja N")
	eq(wr.rig.cur, "ventana", "encuadre pedido por la instantánea")

func test_worldroot_show_hub_without_data_does_not_crash() -> void:
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	var r = repo()
	if r != null and r.has_method("place") and not (r.place("L1") as Dictionary).is_empty():
		_wr.show_hub("escritorio", "M")
		await tree.physics_frame
		ok(_wr.diorama != null, "hub L1 construido")
		ok(_wr.orbit_enabled, "en casa también se mira alrededor")
		eq([_wr.rig.mode(), _wr.rig.cur], ["rail", "escritorio"], "el riel de la buhardilla, en el escritorio")
		_wr.show_hub("general", "M")
		await tree.physics_frame
		eq(_wr.rig.cur, "escritorio", "«general» es el punto de inicio (el escritorio)")
		return
	_wr.show_hub("escritorio", "M")
	await tree.physics_frame
	ok(_wr.diorama != null, "hub de reemplazo mientras no exista data/places/L1.json")
