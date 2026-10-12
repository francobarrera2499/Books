# devtools/drivers/w2placesa_shots.gd — W2-PLACES-A. Capturas de L1, L2 y de las láminas PRO y M7 por encuadre y franja,
# con el WorldRoot real (grabado de W1-POST si está). Modo depuración: rectángulos de las anclas de los nodos
# (verde = se ve, rojo = tapado; gris = fuera de cuadro) con su id, para verificar que todo lo examinable se ve.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pa res://devtools/drivers/w2placesa_shots.gd
# Env: W2PA_PLACE=L1|L2|PRO|M7 (def L1) · W2PA_SLOTS="M,T,N" · W2PA_DAY=3 · W2PA_VARIANT=registrada · W2PA_FRAMES="ventana,…"
#      W2PA_DEBUG=1 (sólo capturas con anclas) · W2PA_RAW=1 (sin grabado) · W2PA_FLAGS="pell_despedido,…" · W2PA_SILS="wiggins,cochero"
#      W2PA_TIMING=1 (mide construcción y cuadros con y sin precalentado; imprime JSON)
# Salida: .work/shots/<prefijo>_<lugar>_<encuadre>_<franja>[_d<día>][_<variante>][_dbg].png
extends RefCounted

const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")
const DB = preload("res://world/diorama_builder.gd")

var tool
var wr
var overlay: Control
var labels: Array = []

static func place_data(id: String) -> Dictionary:
	var d = Engine.get_main_loop().root.get_node_or_null("Data")
	if d != null and d.has_method("repo"):
		var r = d.repo()
		var pl: Dictionary = r.place(id)
		if pl.is_empty(): pl = r.plate(id)
		if not pl.is_empty(): return pl
	for path in ["res://data/places/%s.json" % id, "res://data/plates/%s.json" % id]:
		if FileAccess.file_exists(path):
			return JSON.parse_string(FileAccess.get_file_as_string(path))
	return {}

# evaluador mínimo del DSL (§4.18) para elegir qué se ve en una captura: day, slot, flag, all/any/not, always
static func when_ok(c, day: int, slot: String, flags: Array) -> bool:
	if c == null or not (c is Dictionary) or (c as Dictionary).is_empty(): return true
	for k in c:
		var v = c[k]
		match str(k):
			"all":
				for x in v:
					if not when_ok(x, day, slot, flags): return false
			"any":
				var okk := false
				for x in v:
					if when_ok(x, day, slot, flags): okk = true
				if not okk: return false
			"not":
				if when_ok(v, day, slot, flags): return false
			"always":
				pass
			"day":
				if v is Dictionary:
					if v.has("gte") and day < int(v["gte"]): return false
					if v.has("lte") and day > int(v["lte"]): return false
					if v.has("eq") and day != int(v["eq"]): return false
				elif day != int(v): return false
			"slot":
				if not (v as Array).has(slot): return false
			"flag":
				if not flags.has(str(v)): return false
			_:
				return false
	return true

static func snapshot(pl: Dictionary, area: String, day: int, slot: String, variant: String, frame: String, flags: Array, sils_env := "") -> Dictionary:
	var nodes: Array = []
	var defs: Array = (pl.get("nodes", []) as Array).duplicate()
	var vs = pl.get("variants", {})
	if variant != "" and vs is Dictionary and vs.has(variant):
		defs.append_array(vs[variant].get("add_nodes", []))
	for n in defs:
		var a := str(n.get("area", "*"))
		if a != "*" and area != "*" and a != area: continue
		if not when_ok(n.get("when", {}), day, slot, flags): continue
		nodes.append(str(n["id"]))
	var chars: Array = []
	for c in pl.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if a2 != "*" and area != "*" and a2 != area: continue
		if not when_ok(c.get("when", {}), day, slot, flags): continue
		chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sils: Array = []
	var sd = pl.get("silhouettes", {})
	if sd is Dictionary and day >= 3:
		for k in sd:
			if sils_env == "" or sils_env.split(",").has(k): sils.append(str(k))
	return {"id": "PL.%s.%d.%s" % [pl.get("id", "X"), day, slot], "place": pl.get("id", ""), "area": area, "day": day, "slot": slot,
		"variant": variant, "nodes": nodes, "chars": chars, "silhouettes": sils, "frame": frame}

static func frame_area(pl: Dictionary, fid: String) -> String:
	for f in pl.get("frames", []):
		if str(f.get("id", "")) == fid: return str(f.get("area", "*"))
	return "*"

func drive(t, scene) -> void:
	tool = t
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var pid := OS.get_environment("W2PA_PLACE")
	if pid == "": pid = "L1"
	var pl := place_data(pid)
	if pl.is_empty():
		printerr("w2placesa_shots: no hay datos de ", pid); return
	var slots := OS.get_environment("W2PA_SLOTS")
	var slot_list: Array = (slots.split(",") if slots != "" else (["N"] if pl.get("fixed", false) else ["M", "T", "N"])) as Array
	var day := int(OS.get_environment("W2PA_DAY")) if OS.get_environment("W2PA_DAY") != "" else int(pl.get("day", 3))
	var variant := OS.get_environment("W2PA_VARIANT")
	var only := OS.get_environment("W2PA_FRAMES")
	var dbg := OS.get_environment("W2PA_DEBUG") != ""
	var raw := OS.get_environment("W2PA_RAW") != ""
	var flags: Array = Array(OS.get_environment("W2PA_FLAGS").split(",", false))
	var sils_env := OS.get_environment("W2PA_SILS")
	wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	var cl := CanvasLayer.new(); cl.layer = 50; scene.add_child(cl)
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	if OS.get_environment("W2PA_TIMING") != "":
		await _timing(pl, scene)
		return
	for slot in slot_list:
		for f in pl.get("frames", []):
			var fid := str(f["id"])
			if only != "" and not only.split(",").has(fid): continue
			var area := frame_area(pl, fid)
			if pl.get("fixed", false): area = "*"
			var sn := snapshot(pl, area, day, str(slot), variant, fid, flags, sils_env)
			wr.show_plate(sn, pl)
			wr.set_orbit_enabled(false)
			wr.set_frame(fid, true)
			if raw:
				wr.set_engraving(false)
				var post = wr.engraving_post()
				if post != null and post.has_method("set_enabled"): post.set_enabled(false)
			await tool.frames(4)
			await tool.root.get_tree().physics_frame
			var name := "%s_%s_%s" % [pid, fid, slot]
			if OS.get_environment("W2PA_DAY") != "": name += "_d%d" % day
			if variant != "": name += "_" + variant
			if dbg:
				_debug_marks()
				await tool.frames(2)
				await tool.snap(name + "_dbg")
				_clear_marks()
			else:
				await tool.snap(name)

var _marks: Array = []

func _debug_marks() -> void:
	_marks.clear()
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var idx: Dictionary = wr.diorama.get_meta("nodes_index", {})
	var ex: Array = wr.excluded_rids()
	var report: Array = []
	for nid in idx:
		var b: Node3D = idx[nid]
		var r := RC.screen_rect(cam, b)
		var col := Color(0.1, 0.7, 0.2)
		var st := "ok"
		if r.get_area() <= 0.0 or r.intersection(vp).get_area() <= 0.0:
			col = Color(0.5, 0.5, 0.5); st = "fuera"
		elif ex.has((b as CollisionObject3D).get_rid()):
			col = Color(0.3, 0.3, 0.9); st = "oculto"
		else:
			var vis: Vector2i = RC.visible_points(cam, b, wr.diorama, ex)
			if vis.x == 0: col = Color(0.9, 0.1, 0.1); st = "tapado"
			elif vis.x * 2 <= vis.y: col = Color(0.95, 0.55, 0.0); st = "medio %d/%d" % [vis.x, vis.y]
		if st != "fuera":
			_marks.append({"r": r.intersection(vp), "col": col, "id": str(nid)})
		report.append("%s:%s" % [nid, st])
	report.sort()
	print("ANCLAS ", wr.current_plate(), " ", wr.rig.cur, " ", ", ".join(report))
	for m in _marks:
		var lb := Label.new()
		lb.text = m["id"]
		lb.position = (m["r"] as Rect2).position + Vector2(2, 0)
		lb.add_theme_color_override("font_color", m["col"])
		lb.add_theme_color_override("font_outline_color", Color.WHITE)
		lb.add_theme_constant_override("outline_size", 6)
		lb.add_theme_font_size_override("font_size", 15)
		overlay.add_child(lb)
		labels.append(lb)
	overlay.queue_redraw()

func _clear_marks() -> void:
	_marks.clear()
	for l in labels: l.queue_free()
	labels.clear()
	overlay.queue_redraw()

func _draw_overlay() -> void:
	for m in _marks:
		overlay.draw_rect(m["r"], m["col"], false, 2.0)

func _timing(pl: Dictionary, scene) -> void:
	var out := {}
	var t0 := Time.get_ticks_usec()
	var d := DB.build(pl, snapshot(pl, "*", 3, "M", "", "", []))
	out["build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	out["nodes3d"] = d.find_children("*", "", true, false).size()
	d.free()
	for pre in [false, true]:
		var w2 = WR.new()
		scene.add_child(w2)
		w2.set_fast(true)
		await tool.frames(3)
		if pre:
			var tp := Time.get_ticks_usec()
			await w2.prewarm(pl)
			out["prewarm_ms"] = (Time.get_ticks_usec() - tp) / 1000.0
		var fid := str(pl.get("frames", [{}])[0].get("id", ""))
		var t1 := Time.get_ticks_usec()
		w2.show_plate(snapshot(pl, frame_area(pl, fid), 3, "M", "", fid, []), pl)
		var worst := 0.0
		var prev := Time.get_ticks_usec()
		for i in 12:
			await tool.process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - prev) / 1000.0)
			prev = now
		out["show_ms_" + ("pre" if pre else "frio")] = (prev - t1) / 1000.0
		out["peor_cuadro_ms_" + ("pre" if pre else "frio")] = worst
		w2.queue_free()
		await tool.frames(2)
	print("TIMING ", pl.get("id", ""), " ", JSON.stringify(out))
