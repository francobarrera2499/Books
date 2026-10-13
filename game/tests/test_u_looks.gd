# Registro de looks de post-proceso (world/post/looks.gd; ARCHITECTURE §7.8): descubrimiento ('aguada' por defecto,
# elegida por el usuario; 'grabado' alternativa; nada más), 'grabado' idéntico a Lighting.look, la aguada calibra cada
# preset y la hora se lee en su papel, looks sin base (papel/tinta/defaults/presets y conversión de tipos), selección (override de sesión >
# elección del jugador > default), el quad cambia de shader y sigue la selección, --look=<id> y Opciones.
# Los looks sin base se prueban con res://tests/fixtures/looks (plano, otro; sin_shader.json se ignora).
extends "res://tests/test_base.gd"

const Looks = preload("res://world/post/looks.gd")
const Lighting = preload("res://world/lighting.gd")
const EngravingPost = preload("res://world/post/engraving_post.gd")
const MainScript = preload("res://main.gd")
const Options = preload("res://ui/menus/options.gd")
const FIX := "res://tests/fixtures/looks"

var _nodes: Array = []
var _saved := {}

func before_each() -> void:
	_saved = {"override": Looks._override, "choice": Looks._choice}

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	Looks.rescan()
	Looks._override = str(_saved.get("override", ""))
	Looks._choice = str(_saved.get("choice", ""))
	Looks.serial += 1

func _cam() -> Camera3D:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	return cam

func test_registry_discovers_looks() -> void:
	Looks.rescan()
	var ids := Looks.ids()
	eq(ids, ["aguada", "grabado"], "looks del juego: aguada (por defecto, primero en Opciones) y grabado (alternativa)")
	eq(Looks.DEFAULT, "aguada", "default: la aguada que eligió el usuario")
	Looks.set_choice("")
	eq(Looks.current(), "aguada", "sin elección ni override: la aguada")
	eq(Looks.shader_path("grabado"), EngravingPost.SHADER_PATH, "shader del look grabado")
	eq(Looks.shader_path("aguada"), "res://world/post/looks/aguada.gdshader")
	ok(Looks.is_base("grabado"), "grabado: base lighting")
	no(Looks.is_base("aguada"), "aguada: parámetros propios (looks/aguada.json)")
	for id in ids:
		ok(Looks.label(str(id)) != str(id), "%s: rótulo para Opciones" % id)
	for gone in ["albumina", "fotograbado"]:
		no(Looks.has(gone), "look eliminado: %s" % gone)
		no(FileAccess.file_exists(Looks.DIR.path_join(gone + ".json")) or ResourceLoader.exists(Looks.DIR.path_join(gone + ".gdshader")), "sin archivos de %s" % gone)
	# contrato de todo look del juego: par .json + .gdshader y uniforms paper / ink / grain
	var shaders := []
	for f in DirAccess.get_files_at(Looks.DIR):
		if f.ends_with(".gdshader"):
			shaders.append(f.get_basename())
	for s in shaders:
		ok(ids.has(s), "%s.gdshader tiene su %s.json" % [s, s])
	for id in ids:
		var u := Looks.uniforms(str(id))
		for k in ["paper", "ink", "grain"]:
			ok(u.has(k), "%s: uniform %s" % [id, k])
		ok(Looks.info(str(id)).has("name"), "%s: name" % id)

func test_grabado_params_equal_lighting() -> void:
	Looks.rescan()
	for p in Lighting.names():
		for s in ["dawn", "M", "T", "N", "night"]:
			var a := Looks.params("grabado", p, s)
			eq(str(a.get("look", "")), "grabado", "marca el look")
			a.erase("look")
			var b := Lighting.look(p, s)
			ok(a == b, "%s/%s: Looks.params(grabado) == Lighting.look" % [p, s])
	# un id desconocido cae al default
	eq(str(Looks.params("no_existe", "tarde", "T").look), "aguada", "desconocido -> default")

# La aguada calibra cada preset de Lighting y la hora se lee en su papel y su tinta: mañana fría/perla, tarde sepia,
# gas ámbar, la noche fría del 5 azulada (más fría que el gas), Park Lane a las 18 h dorado (más amarillo que la tarde).
func test_aguada_params_per_preset() -> void:
	Looks.rescan()
	for p in Lighting.names():
		for s in ["M", "T", "N"]:
			var a := Looks.params("aguada", p, s)
			eq(str(a.look), "aguada")
			ok(a.paper is Color and a.ink is Color, "%s/%s: papel y tinta" % [p, s])
			ok((a.paper as Color).get_luminance() > (a.ink as Color).get_luminance() + 0.5, "%s/%s: papel claro, tinta oscura" % [p, s])
			for k in ["exposure", "contrast", "gamma", "grain"]:
				ok(a.has(k), "%s/%s: %s" % [p, s, k])
	var warm := func(c: Color) -> float: return c.r - c.b
	var tarde: Color = Looks.params("aguada", "tarde", "T").paper
	var park: Color = Looks.params("aguada", "dorada_parklane", "T").paper
	var gas: Color = Looks.params("aguada", "gas", "N").paper
	var fria: Color = Looks.params("aguada", "noche_viento", "N").paper
	var perla: Color = Looks.params("aguada", "manana_perla", "M").paper
	ok(warm.call(park) > warm.call(tarde) + 0.05, "Park Lane dorado: papel más cálido que la tarde")
	ok(warm.call(fria) < warm.call(gas) - 0.1, "noche fría del 5: papel más frío que el gas")
	ok(warm.call(perla) < warm.call(tarde), "mañana perla: papel más frío que la tarde")

func test_fixture_discovery_and_selection() -> void:
	Looks.rescan(FIX)
	eq(Looks.ids(), ["plano", "otro"], "por order; el JSON sin shader se ignora")
	eq(Looks.current(), "plano", "sin el default en el directorio: el primero")
	var s0 := Looks.serial
	Looks.set_choice("otro")
	eq(Looks.current(), "otro", "elección del jugador")
	ok(Looks.serial > s0, "serial cambia")
	ok(Looks.set_override("plano"), "override válido")
	eq(Looks.current(), "plano", "el override de sesión gana")
	eq(Looks.choice(), "otro", "el override no toca la elección guardada")
	no(Looks.set_override("no_existe"), "override desconocido rechazado")
	eq(Looks.current(), "plano", "sigue el override anterior")
	Looks.set_override("")
	eq(Looks.current(), "otro", "sin override: la elección")
	Looks.set_override("plano")
	Looks.set_choice("otro")
	eq(Looks.current(), "otro", "elegir en Opciones quita el override")
	Looks.set_choice("no_existe")
	eq(Looks.choice(), "", "elección desconocida -> default")

func test_fixture_params_types_and_paper() -> void:
	Looks.rescan(FIX)
	var g := Looks.params("plano", "gas", "N")
	eq(str(g.look), "plano")
	ok((g.paper as Color).is_equal_approx(Color(0.9, 0.8, 0.6)), "papel de noche del look (lista) %s" % str(g.paper))
	ok((g.ink as Color).is_equal_approx(Color("203040")), "tinta del look")
	near(g.exposure, 1.6, 1e-6, "preset gas pisa el default")
	eq(typeof(g.steps), TYPE_INT, "int del uniform")
	eq(g.steps, 6)
	eq(g.tone_range, Vector2(0.1, 0.9), "vec2 desde lista")
	near(g.grain, 0.03, 1e-6, "'*' para todo preset")
	var m := Looks.params("plano", "manana_perla", "M")
	ok((m.paper as Color).is_equal_approx(Color("f0f0f0")), "papel de mañana")
	near(m.exposure, 1.2, 1e-6, "default")
	eq(m.steps, 4)
	var t := Looks.params("plano", "dorada_parklane", "T")
	ok((t.paper as Color).is_equal_approx(Lighting.PAPER.tarde.lerp(Color("ffcc66"), 0.5)), "tinte propio de Park Lane; tarde sin papel propio -> Lighting.PAPER")
	var v := Looks.params("plano", "noche_viento", "N")
	var tint: Dictionary = Lighting.PRESETS.noche_viento.paper
	ok((v.paper as Color).is_equal_approx(Color(0.9, 0.8, 0.6).lerp(tint.tint, float(tint.mix))), "sin tinte propio: hereda el de Lighting (noche fría del 5)")
	var hc := Looks.high_contrast("plano")
	ok((hc.paper as Color).is_equal_approx(Color("ffffee")) and float(hc.grain) == 0.0, "alto contraste del look")

func test_post_switches_shader_and_follows_selection() -> void:
	Looks.rescan()
	var post0 = EngravingPost.attach(_cam())
	eq(post0.look_id, "aguada", "el quad nace con la aguada")
	eq(post0.material_override.shader.resource_path, Looks.shader_path("aguada"), "aguada por defecto")
	post0.set_preset("gas", "N")
	ok(post0.param("paper").is_equal_approx(Looks.params("aguada", "gas", "N").paper), "aguada: papel de gas del look")
	near(post0.param("exposure"), float(Looks.params("aguada", "gas", "N").exposure), 1e-6, "aguada: preset gas")
	post0.set_look_id("grabado")
	eq(post0.material_override.shader.resource_path, EngravingPost.SHADER_PATH, "grabado: su shader")
	ok(post0.param("paper").is_equal_approx(Lighting.paper_for("N")), "grabado: papel de gas")
	near(post0.param("exposure"), Lighting.PRESETS.gas.post.exposure, 1e-6, "grabado: post del preset")
	Looks.rescan(FIX)
	var post = EngravingPost.attach(_cam())
	eq(post.look_id, "plano", "nace con Looks.current()")
	eq(post.material_override.shader.resource_path, FIX.path_join("plano.gdshader"))
	near(post.param("exposure"), 1.2, 1e-6, "defaults del look al cambiar de shader")
	post.set_preset("gas", "N")
	near(post.param("exposure"), 1.6, 1e-6, "preset")
	eq(int(post.param("steps")), 6)
	ok(post.param("paper").is_equal_approx(Color(0.9, 0.8, 0.6)), "papel del look")
	post.set_param("bias", 0.5)
	post.set_preset("manana_perla", "M")
	var b = post.param("bias")
	ok(b == null or absf(float(b)) < 1e-6, "lo que el look no da vuelve al default del shader (%s)" % str(b))
	# un Lighting.look (lo que pasan los drivers viejos) se traduce al look del quad
	post.set_look(Lighting.look("gas", "N"))
	eq(str(post._look.get("look", "")), "plano", "Lighting.look traducido")
	near(post.param("exposure"), 1.6, 1e-6, "parámetros del look, no los del grabado")
	post.set_high_contrast(true)
	ok(post.param("paper").is_equal_approx(Color("ffffee")), "alto contraste del look")
	post.set_high_contrast(false)
	# la selección global cambia el shader del quad vivo (Looks.serial, en _process)
	Looks.set_override("otro")
	await tree.process_frame
	await tree.process_frame
	eq(post.look_id, "otro", "sigue la selección")
	eq(post.material_override.shader.resource_path, FIX.path_join("otro.gdshader"))
	eq(str(post._look.get("preset", "")), "gas", "conserva preset y franja")
	ok(post.param("paper").is_equal_approx(Lighting.paper_for("N")), "otro: sin papel propio -> el de la franja")
	# un look fijado en el quad persiste hasta la próxima selección
	post.set_look_id("plano")
	await tree.process_frame
	eq(post.look_id, "plano", "set_look_id fija")

func test_parse_args_look() -> void:
	eq(str(MainScript.parse_args([]).look), "", "sin --look")
	eq(str(MainScript.parse_args(["--look=sepia", "--fast"]).look), "sepia", "--look=<id>")

func test_options_persist_and_list_looks() -> void:
	Looks.rescan()
	Looks.set_choice("")
	eq(str(Options.current().look), "", "sin elección: se guarda vacío (sigue el default)")
	var o := Options.current()
	o.look = "grabado"
	Options.apply(o)
	eq(Looks.choice(), "grabado", "apply restaura la elección")
	eq(str(Options.current().look), "grabado")
	o.look = ""
	Options.apply(o)
	eq(Looks.choice(), "")
	var op = Options.new()
	tree.root.add_child(op)
	_nodes.append(op)
	op._build()
	var ob: OptionButton = op.find_child("Look", true, false)
	ok(ob != null, "fila «Estilo de imagen»")
	if ob != null:
		eq(ob.item_count, Looks.ids().size(), "lista los looks existentes")
		eq(str(ob.get_item_metadata(0)), "aguada", "la aguada primero")
		eq(str(ob.get_item_metadata(ob.selected)), Looks.current(), "seleccionado = el activo")
	var lab := ""
	var row = op.find_child("LookRow", true, false)
	if row != null:
		lab = (row.get_child(0) as Label).text
	ok(lab != "" and lab != "shell.opt.estilo", "rótulo desde ui_text: %s" % lab)
