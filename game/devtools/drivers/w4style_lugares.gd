# devtools/drivers/w4style_lugares.gd — W4-STYLE. Capturas comparativas de cada lugar × encuadre × franja con el camino
# real (WorldRoot -> DioramaBuilder -> Lighting -> EngravingPost), medidas de legibilidad de siluetas y hojas comparativas.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w4s_antes res://devtools/drivers/w4style_lugares.gd
# Env:
#   W4S_ONLY=<subcadena>  sólo los trabajos cuyo nombre la contenga (p. ej. "L1_", "10N", "PARK"; varias con comas)
#   W4S_FIG=1             mide cada figura (personaje o silueta) visible: máscara por profundidad (debug_view 4, con y sin la
#                         figura) y, sobre el grabado 1 bit, tinta dentro / en el borde / en el anillo de alrededor
#   W4S_ANTES=<prefijo>   con W4S_FIG: mide la misma máscara también sobre <prefijo>_<toma>.png (captura vieja) -> antes=
#   W4S_CMP=A,B           no renderiza: arma <prefijo>_<toma>.png con <A>_<toma>.png | <B>_<toma>.png (mitad de tamaño)
#   W4S_SHEET=<prefijo>   no renderiza: hojas de contacto 2×2 de <prefijo>_* (CMP y SHEET corren con --headless)
#   W4S_RAW=1             además, el color 3D sin grabado (<toma>_crudo)
# Corrida de la ola 4: w4s_antes (código previo) y w4s_despues; hojas w4s_cmp_<toma> (antes | después) y w4s_hoja_NN.
# Instantánea emulada como WorldModel.snapshot (nodos y personajes por `when` con tk; siluetas explícitas por trabajo).
# La luz la elige DioramaBuilder (Lighting.preset_for); si el builder todavía no pasa la instantánea (diff propuesto),
# se fuerza snap.light = Lighting.preset_for(place, slot, snap) y se imprime EMULADO.
extends RefCounted

const WR = preload("res://world/world_root.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Lighting = preload("res://world/lighting.gd")
const Med = preload("res://devtools/drivers/w4style_medidas.gd")

# [lugar, área, día, franja, encuadres, siluetas, variante]
const JOBS := [
	["L1", "buhardilla", 2, "M", ["escritorio", "ventana", "pared"], [], ""],
	["L1", "buhardilla", 3, "T", ["escritorio", "ventana"], ["wiggins"], ""],
	["L1", "buhardilla", 3, "N", ["escritorio", "ventana"], ["wiggins"], ""],
	["L1", "tienda", 4, "T", ["mostrador", "estantes"], [], ""],
	["L1", "tienda", 10, "M", ["mostrador"], [], ""],
	["L1", "buhardilla", 10, "N", ["ventana", "escritorio"], ["wiggins"], ""],
	["L2", "sala", 2, "M", ["mostrador", "mesas"], [], ""],
	["L2", "sala", 4, "N", ["mesas"], [], ""],
	["L3", "calle", 3, "M", ["221b", "camden"], ["wiggins"], ""],
	["L3", "interior", 3, "M", ["vestibulo", "salita"], [], ""],
	["L3", "calle", 5, "T", ["221b"], ["wiggins", "cochero"], ""],
	["L3", "calle", 4, "N", ["221b", "camden"], ["wiggins"], ""],
	["L3", "calle", 10, "N", ["221b"], ["wiggins", "cochero"], ""],
	["L4", "consulta", 4, "M", ["consultorio", "ventana"], ["wiggins", "m3_hombres"], ""],
	["L4", "estudio", 6, "T", ["estudio", "estante"], ["wiggins"], ""],
	["L5", "porteria", 2, "M", ["porteria", "libro"], [], ""],
	["L5", "forasteros", 8, "T", ["forasteros", "mirador"], ["wiggins"], ""],
	["L5", "forasteros", 9, "N", ["forasteros"], ["wiggins"], ""],
	["L6", "sala", 2, "M", ["sala", "indices"], [], ""],
	["L6", "sala", 3, "T", ["mostrador"], ["wiggins"], ""],
	["L7", "exterior", 5, "M", ["acera", "tiro"], ["wiggins"], ""],
	["L7", "exterior", 6, "T", ["jardin"], ["wiggins", "cochero"], ""],
	["L7", "exterior", 7, "N", ["acera"], ["wiggins"], ""],
	["L8", "interior", 7, "T", ["sala", "ventana"], ["wiggins"], ""],
	["L8", "interior", 8, "M", ["vista"], ["wiggins"], ""],
	["PARK", "*", 10, "T", ["teoria", "choque", "ventana"], ["wiggins"], ""],
	["RB", "*", 2, "M", ["otra_orilla", "sendero"], [], "fina"],
	["RB", "*", 2, "M", ["sendero", "pared"], [], "journal"],
	["RB", "*", 2, "M", ["otra_orilla"], [], "foto"],
	["PRO", "*", 0, "N", ["lamina", "ventana"], [], ""],
	["M7", "*", 7, "night", ["lamina"], [], ""],
]

var tool
var scene
var repo
var wr

static func snapshot(p_repo, place: Dictionary, area: String, day: int, slot: String, sils: Array, variant: String) -> Dictionary:
	var tk := TimeKey.tk(day, slot)
	var ctx := {"repo": p_repo, "tk": tk}
	var nodes: Array = []
	var defs: Array = (place.get("nodes", []) as Array).duplicate()
	var vd = place.get("variants", {}).get(variant, {}) if place.get("variants", {}) is Dictionary else {}
	if vd is Dictionary:
		defs.append_array(vd.get("add_nodes", []))
	for n in defs:
		if not (n is Dictionary):
			continue
		var a := str(n.get("area", "*"))
		if not (a == "*" or a == "" or area == "*" or a == area):
			continue
		if Cond.eval(n.get("when", {}), ctx):
			nodes.append(str(n["id"]))
	var chars: Array = []
	for c in place.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if not (a2 == "*" or area == "*" or a2 == area):
			continue
		if Cond.eval(c.get("when", {}), ctx):
			chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var s: Array = []
	for who in sils:
		if (place.get("silhouettes", {}) as Dictionary).has(who):
			s.append("sil_" + str(who))
	return {"id": "PL.%s.%d.%s" % [place.get("id", "?"), day, slot], "place": str(place.get("id", "")), "area": area, "day": day,
		"slot": slot, "variant": variant, "nodes": nodes, "chars": chars, "silhouettes": s}

static func job_name(j: Array) -> String:
	return "%s_%d%s%s" % [j[0], int(j[2]), str(j[3]), ("_" + str(j[6])) if str(j[6]) != "" else ""]

func drive(p_tool, p_scene) -> void:
	tool = p_tool
	scene = p_scene
	var cmp := OS.get_environment("W4S_CMP")
	if cmp != "":
		_compare(cmp)
		return
	var sheet := OS.get_environment("W4S_SHEET")
	if sheet != "":
		_sheets(sheet)
		return
	for c in scene.get_children():
		c.queue_free()
	await tool.frames(2)
	repo = load("res://core/data/data_repo.gd").load_dir("res://data")
	var only := OS.get_environment("W4S_ONLY")
	var figs := OS.get_environment("W4S_FIG") != ""
	var raw := OS.get_environment("W4S_RAW") != ""
	wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	await tool.frames(2)
	for j in JOBS:
		var jn := job_name(j)
		if not _match(jn, only):
			continue
		var pid: String = j[0]
		var place: Dictionary = repo.place(pid)
		if place.is_empty():
			place = repo.plate(pid)
		if place.is_empty():
			print("SIN DATOS ", pid)
			continue
		var snap := snapshot(repo, place, str(j[1]), int(j[2]), str(j[3]), j[5], str(j[6]))
		var LT: Script = load("res://world/lighting.gd")
		var want := str(LT.preset_for(place, str(j[3]), snap)) if _preset_for_arity() >= 3 else str(LT.preset_for(place, str(j[3])))
		wr.show_plate(snap, place)
		var got := str(wr.diorama.get_meta("light_preset", ""))
		if got != want:
			print("EMULADO %s: el builder eligió %s; Lighting.preset_for(place, slot, snap) = %s (diff propuesto a diorama_builder)" % [jn, got, want])
			snap["light"] = want
			wr.show_plate(snap, place)
		await tool.frames(3)
		for f in j[4]:
			if not wr.rig.has_frame(str(f)):
				print("SIN ENCUADRE ", jn, " ", f)
				continue
			wr.set_frame(str(f), true)
			await tool.frames(6)
			var shot := "%s_%s" % [jn, f]
			await tool.snap(shot)
			var img := await _grab(0)
			print("STAT %s preset=%s tinta=%.3f media=%.3f" % [shot, want, Med.ink_frac(img, Rect2i(Vector2i.ZERO, img.get_size())), Med.mean(img)])
			if figs:
				await _figures(shot, img)
			if raw:
				var post = wr.engraving_post()
				post.set_param("debug_view", 3)
				await tool.frames(3)
				await tool.snap(shot + "_crudo")
				post.set_param("debug_view", 0)
	wr.queue_free()
	await tool.frames(2)

# W4S_ONLY: vacío = todo; si no, alguna de las subcadenas separadas por comas
static func _match(name: String, only: String) -> bool:
	if only == "":
		return true
	for o in only.split(",", false):
		if name.contains(o.strip_edges()):
			return true
	return false

func _preset_for_arity() -> int:
	for m in (Lighting as Script).get_script_method_list():
		if str(m.name) == "preset_for":
			return (m.args as Array).size()
	return 2

func _grab(n := 2) -> Image:
	for i in n:
		await tool.process_frame
	await RenderingServer.frame_post_draw
	var img: Image = scene.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

# ---------------------------------------------------------------------------------------------
# legibilidad de figuras en 1 bit (Med.legibility): máscara por profundidad con y sin la figura
func _figures(shot: String, eng: Image) -> void:
	var d: Node3D = wr.diorama
	var post = wr.engraving_post()
	var cam: Camera3D = wr.camera()
	var vp := Rect2i(Vector2i.ZERO, eng.get_size())
	var items: Array = []
	for cid in (d.get_meta("chars_index", {}) as Dictionary):
		items.append({"who": str(cid), "body": d.get_meta("chars_index")[cid]})
	for nid in (d.get_meta("nodes_index", {}) as Dictionary):
		var b2: Node3D = d.get_meta("nodes_index")[nid]
		if b2.has_meta("silhouette"):
			items.append({"who": str(nid), "body": b2})
	var fl := d.get_node_or_null("Lights/Flicker")
	if fl != null:
		fl.set_process(false)
	# W4S_ANTES=<prefijo>: la misma máscara (la geometría no cambia) medida también sobre la captura vieja
	var antes: Image = null
	var ap := OS.get_environment("W4S_ANTES")
	if ap != "":
		var f := ProjectSettings.globalize_path("res://").path_join("../.work/shots/%s_%s.png" % [ap, shot])
		if FileAccess.file_exists(f):
			antes = Image.load_from_file(f)
			antes.convert(Image.FORMAT_RGB8)
	for it in items:
		var fig: Node3D = null
		for c in (it.body as Node3D).get_children():
			if c is Node3D and not (c is CollisionShape3D):
				fig = c
				break
		if fig == null:
			continue
		var r := Med.screen_rect(cam, fig)
		if r.size.x <= 0 or not vp.intersects(r):
			continue
		r = r.grow(14).intersection(vp)
		post.set_param("debug_view", 4)
		var d1 := await _grab(3)
		fig.visible = false
		var d0 := await _grab(3)
		fig.visible = true
		post.set_param("debug_view", 0)
		await _grab(2)
		var mask := Med.mask_from_depth(d1, d0, r)
		var m := Med.legibility(eng, mask, r)
		if int(m.area) < 150:
			continue
		var prev := ""
		if antes != null:
			var ma := Med.legibility(antes, mask, r)
			prev = " antes=%.2f" % ma.leg
		print("FIG %s %s area=%d leg=%.2f%s mancha=%.2f linea=%.2f blanca=%.2f (dentro %.2f anillo %.2f filo %.2f/%.2f)" % [shot, it.who,
			m.area, m.leg, prev, m.fill, m.outline, m.white, m.f_in, m.f_ring, m.c_in, m.c_out])
	if fl != null:
		fl.set_process(true)

# ---------------------------------------------------------------------------------------------
# hojas de contacto: 2×2 tomas de <prefijo>_* a mitad de tamaño (W4S_SHEET=<prefijo>) -> <prefijo de la corrida>_<n>.png
func _sheets(src: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/shots")
	var only := OS.get_environment("W4S_ONLY")
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(src + "_") and f.ends_with(".png") and not f.contains("_crudo") and _match(f, only):
			files.append(f)
	files.sort()
	var k := 0
	while k < files.size():
		var out := Image.create(1600 + 6, 900 + 6, false, Image.FORMAT_RGB8)
		out.fill(Color(0.6, 0.1, 0.1))
		var names: Array = []
		for q in 4:
			if k + q >= files.size():
				break
			var im := Image.load_from_file(dir.path_join(files[k + q]))
			im.convert(Image.FORMAT_RGB8)
			im.resize(800, 450, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(im, Rect2i(0, 0, 800, 450), Vector2i((q % 2) * 806, (q / 2) * 456))
			names.append(str(files[k + q]).trim_prefix(src + "_").trim_suffix(".png"))
		var nm := "%s_%02d.png" % [tool.prefix, k / 4]
		out.save_png(dir.path_join(nm))
		print("HOJA ", nm, " ", names)
		k += 4

# ---------------------------------------------------------------------------------------------
# hojas comparativas: A | B a mitad de tamaño
func _compare(spec: String) -> void:
	var ab := spec.split(",")
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/shots")
	var only := OS.get_environment("W4S_ONLY")
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with(ab[0] + "_") or not f.ends_with(".png"):
			continue
		var shot := f.trim_prefix(ab[0] + "_").trim_suffix(".png")
		if not _match(shot, only):
			continue
		var fb := dir.path_join(ab[1] + "_" + shot + ".png")
		if not FileAccess.file_exists(fb):
			continue
		var ia := Image.load_from_file(dir.path_join(f))
		var ib := Image.load_from_file(fb)
		ia.resize(ia.get_width() / 2, ia.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		ib.resize(ia.get_width(), ia.get_height(), Image.INTERPOLATE_BILINEAR)
		var out := Image.create(ia.get_width() * 2 + 8, ia.get_height(), false, Image.FORMAT_RGB8)
		out.fill(Color(0.5, 0.1, 0.1))
		ia.convert(Image.FORMAT_RGB8)
		ib.convert(Image.FORMAT_RGB8)
		out.blit_rect(ia, Rect2i(Vector2i.ZERO, ia.get_size()), Vector2i.ZERO)
		out.blit_rect(ib, Rect2i(Vector2i.ZERO, ib.get_size()), Vector2i(ia.get_width() + 8, 0))
		out.save_png(dir.path_join(tool.prefix + "_" + shot + ".png"))
		n += 1
	print("CMP hojas: ", n)
