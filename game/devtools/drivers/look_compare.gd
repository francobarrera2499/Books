# devtools/drivers/look_compare.gd — capturas de referencia de un LOOK de post-proceso (world/post/looks.gd) para
# compararlos entre sí: SIEMPRE los mismos 6 encuadres, con el camino real (WorldRoot -> DioramaBuilder -> Lighting ->
# EngravingPost con el look elegido), a 1600x900, sin --fast (cámara instantánea, trama re-anclada en cada encuadre y
# FRAMES_SETTLE cuadros de espera: la imagen no depende de la toma anterior).
#   LOOK=<id> ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn look res://devtools/drivers/look_compare.gd
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn look res://devtools/drivers/look_compare.gd --look=<id>
# (sin LOOK ni --look: el look activo, Looks.current()). Corre CON ventana (sin --headless).
# Salida: .work/shots/look_<id>_<n>.png (n = 1..6) + .work/shots/look_<id>.json (look, rótulo, preset de luz por toma).
# Hoja 3x2 rotulada: ./godot.sh --headless -s devtools/contact_sheet.gd -- <id>   -> .work/shots/sheet_<id>.png
# Las 6 tomas (SHOTS): 1 buhardilla L1, escritorio, mañana (gris perla) · 2 prólogo PRO: Pell y Harris, noche de gas ·
# 3 tienda de Crane con el librero, día 10 · 4 estudio de Watson (L4) con Watson, tarde · 5 Baker Street (L3) exterior,
# tarde · 6 Park Lane a las 18 h (lámina PARK sobre L7: luz dorada, jueves 5).
# Instantánea emulada como WorldModel.snapshot (devtools/drivers/w4style_lugares.gd): nodos y personajes por `when`.
# Recorrido completo del look (TODO: L1-L8, láminas y todas las franjas, 30 tomas en 5 hojas de 6):
#   SET=todo LOOK=<id> ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn look res://devtools/drivers/look_compare.gd
#   -> .work/shots/look_<id>-t<g>_<n>.png + look_<id>-t<g>.json (g = 1..5); hojas: contact_sheet.gd -- <id>-t1 … <id>-t5
#   ONLY=3,7,12 (índices 1-based del recorrido) re-captura sólo esas tomas · RAW=1 guarda además el color 3D crudo.
extends RefCounted

const WR = preload("res://world/world_root.gd")
const Lighting = preload("res://world/lighting.gd")
const Looks = preload("res://world/post/looks.gd")
const W4S = preload("res://devtools/drivers/w4style_lugares.gd")

const FRAMES_SETTLE := 24
# [lugar o lámina, área, día, franja, encuadre, siluetas, variante, rótulo]
const SHOTS := [
	["L1", "buhardilla", 2, "M", "escritorio", [], "", "Buhardilla L1, escritorio · mañana"],
	["PRO", "*", 0, "N", "lamina", [], "", "Prólogo: Pell y Harris · gas"],
	["L1", "tienda", 10, "M", "mostrador", [], "", "Tienda de Crane, el librero · día 10"],
	["L4", "estudio", 6, "T", "estudio", [], "", "Estudio de Watson (L4) · tarde"],
	["L3", "calle", 5, "T", "221b", ["wiggins", "cochero"], "", "Baker Street (L3) · tarde"],
	["PARK", "*", 10, "T", "teoria", ["wiggins"], "", "Park Lane (L7) · 18 h, jueves 5"],
]

# recorrido completo: todos los lugares (L1-L8), láminas (PARK, RB, PRO, M7) y franjas (mañana perla, día de ventana,
# eléctrica, tarde, gas, farol, noche fría del 5, Park Lane dorado), con figuras donde las hay
const TODO := [
	["L1", "buhardilla", 2, "M", "escritorio", [], "", "L1 buhardilla, escritorio · mañana"],
	["L1", "buhardilla", 3, "T", "escritorio", ["wiggins"], "", "L1 buhardilla, escritorio · tarde"],
	["L1", "buhardilla", 3, "N", "escritorio", ["wiggins"], "", "L1 buhardilla, escritorio · gas"],
	["L1", "buhardilla", 10, "N", "ventana", ["wiggins"], "", "L1 buhardilla · noche fría del 5"],
	["L1", "tienda", 4, "T", "mostrador", [], "", "L1 tienda de Crane · tarde"],
	["L1", "tienda", 10, "M", "estantes", [], "", "L1 tienda, estantes · día 10"],
	["L2", "sala", 2, "M", "mesas", [], "", "L2 sala de lectura · eléctrica"],
	["L2", "sala", 4, "N", "mesas", [], "", "L2 sala de lectura · noche"],
	["L3", "calle", 3, "M", "221b", ["wiggins"], "", "L3 Baker Street · mañana"],
	["L3", "interior", 3, "M", "salita", [], "", "L3 salita · mañana"],
	["L3", "calle", 4, "N", "camden", ["wiggins"], "", "L3 Camden House · farol"],
	["L3", "calle", 10, "N", "221b", ["wiggins", "cochero"], "", "L3 Baker Street · noche fría del 5"],
	["L4", "consulta", 4, "M", "consultorio", ["wiggins", "m3_hombres"], "", "L4 consultorio · día de ventana"],
	["L4", "estudio", 6, "T", "estante", ["wiggins"], "", "L4 estudio, estante · tarde"],
	["L5", "porteria", 2, "M", "porteria", [], "", "L5 portería · mañana"],
	["L5", "porteria", 2, "M", "libro", [], "", "L5 libro de visitas · mañana"],
	["L5", "forasteros", 8, "T", "forasteros", ["wiggins"], "", "L5 sala de forasteros · tarde"],
	["L5", "forasteros", 9, "N", "forasteros", ["wiggins"], "", "L5 sala de forasteros · gas"],
	["L6", "sala", 2, "M", "sala", [], "", "L6 sala · mañana"],
	["L6", "sala", 2, "M", "indices", [], "", "L6 índices · mañana"],
	["L6", "sala", 3, "T", "mostrador", ["wiggins"], "", "L6 mostrador · tarde"],
	["L7", "exterior", 5, "M", "tiro", ["wiggins"], "", "L7 Park Lane, línea de tiro · mañana"],
	["L7", "exterior", 6, "T", "jardin", ["wiggins", "cochero"], "", "L7 jardín · tarde"],
	["L7", "exterior", 7, "N", "acera", ["wiggins"], "", "L7 acera · noche"],
	["L8", "interior", 7, "T", "sala", ["wiggins"], "", "L8 sala · día 7 (luz propia del lugar)"],
	["L8", "interior", 8, "M", "vista", ["wiggins"], "", "L8 vista · día 8 (luz propia del lugar)"],
	["PARK", "*", 10, "T", "ventana", ["wiggins"], "", "Park Lane, ventana · 18 h"],
	["RB", "*", 2, "M", "otra_orilla", [], "fina", "Reichenbach (lámina) · fina"],
	["RB", "*", 2, "M", "sendero", [], "journal", "Reichenbach, sendero · journal"],
	["M7", "*", 7, "night", "lamina", [], "", "Lámina M7 · noche"],
]

var tool
var scene

static func shots_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../.work/shots").simplify_path()

static func look_arg() -> String:
	var id := OS.get_environment("LOOK")
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--look="):
			id = String(a).substr(7)
	return id

func drive(p_tool, p_scene) -> void:
	tool = p_tool
	scene = p_scene
	var id := look_arg()
	if id == "":
		id = Looks.current()
	if not Looks.has(id):
		printerr("look_compare: look desconocido '%s' (hay: %s)" % [id, ", ".join(Looks.ids())])
		return
	Looks.set_override(id)
	var todo := OS.get_environment("SET") == "todo"
	for a in OS.get_cmdline_user_args():
		if String(a) == "--set=todo":
			todo = true
	var shots: Array = TODO if todo else SHOTS
	var only := {}
	for o in OS.get_environment("ONLY").split(",", false):
		only[int(o)] = true
	DirAccess.make_dir_recursive_absolute(shots_dir())
	var repo = load("res://core/data/data_repo.gd").load_dir("res://data")
	var wr = WR.new()
	scene.add_child(wr)
	await tool.frames(2)
	var metas := {}
	for i in shots.size():
		if not only.is_empty() and not only.has(i + 1):
			continue
		var s: Array = shots[i]
		var tag := id if not todo else "%s-t%d" % [id, i / 6 + 1]
		var n := i + 1 if not todo else i % 6 + 1
		if not metas.has(tag):
			metas[tag] = _meta(tag, id)
		var pid := str(s[0])
		var place: Dictionary = repo.place(pid)
		if place.is_empty():
			place = repo.plate(pid)
		if place.is_empty():
			printerr("look_compare: sin datos de ", pid)
			continue
		var snap: Dictionary = W4S.snapshot(repo, place, str(s[1]), int(s[2]), str(s[3]), s[5], str(s[6]))
		var want := str(Lighting.preset_for(place, str(s[3]), snap))
		wr.show_plate(snap, place)
		if str(wr.diorama.get_meta("light_preset", "")) != want:
			snap["light"] = want
			wr.show_plate(snap, place)
		# el parpadeo de faroles (noche del 5) cambiaría la luz entre corridas: quieto en su energía base
		var fl: Node = wr.diorama.get_node_or_null("Lights/Flicker")
		if fl != null:
			fl.set_process(false)
		if not wr.rig.has_frame(str(s[4])):
			printerr("look_compare: %s sin encuadre %s" % [pid, s[4]])
			continue
		wr.set_frame(str(s[4]), true)
		await tool.frames(3)
		var post = wr.engraving_post()
		if post != null:
			if str(post.look_id) != id:
				post.set_look_id(id)
			post.reanchor()  # trama anclada en cero para este encuadre (no arrastra el giro desde la toma anterior)
		await tool.frames(FRAMES_SETTLE)
		await RenderingServer.frame_post_draw
		var img: Image = scene.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var fname := "look_%s_%d.png" % [tag, n]
		img.save_png(shots_dir().path_join(fname))
		if OS.get_environment("RAW") == "1" and post != null:
			# RAW=1: además el color 3D sin post (debug_view 3) -> look_<tag>_<n>_crudo.png
			post.set_param("debug_view", 3)
			await tool.frames(3)
			await RenderingServer.frame_post_draw
			var raw: Image = scene.get_viewport().get_texture().get_image()
			raw.convert(Image.FORMAT_RGB8)
			raw.save_png(shots_dir().path_join("look_%s_%d_crudo.png" % [tag, n]))
			post.set_param("debug_view", 0)
		var chars: Array = []
		for c in snap.get("chars", []):
			chars.append(str(c.get("id", "")))
		var shl: Array = metas[tag].shots
		shl = shl.filter(func(e): return int(e.get("n", 0)) != n)
		metas[tag].shots = shl
		shl.append({"n": n, "file": fname, "caption": str(s[7]), "place": pid, "frame": str(s[4]), "day": int(s[2]),
			"slot": str(s[3]), "preset": want, "look_post": str(post.look_id) if post != null else "", "chars": chars})
		print("LOOK %s %d %s preset=%s personajes=%s -> %s" % [id, i + 1, pid, want, ",".join(chars), fname])
	for tag in metas:
		var f := FileAccess.open(shots_dir().path_join("look_%s.json" % tag), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(metas[tag], "  "))
			f.close()
	wr.queue_free()
	await tool.frames(2)

# metadatos de una hoja: los de una corrida anterior (ONLY re-captura algunas tomas) o nuevos
static func _meta(tag: String, id: String) -> Dictionary:
	var p := shots_dir().path_join("look_%s.json" % tag)
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary and d.get("shots", null) is Array:
			return d
	return {"look": id, "name": Looks.label(id), "shots": []}
