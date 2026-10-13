# T27 (W1-POST) — parte headless: todos los shaders compilan (el renderer dummy de 4.7 reporta errores de shader
# al Logger) y el quad de grabado cumple el contrato de §7.8. La calibración con ventana está en test_t27_window.gd.
extends "res://tests/test_base.gd"

const EngravingPost = preload("res://world/post/engraving_post.gd")
const Lighting = preload("res://world/lighting.gd")
const SHADER := "res://world/post/engraving.gdshader"

class ShaderLog extends Logger:
	var errs: Array = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errs.append("%s %s (%s:%d)" % [code, rationale, file, line])
		mutex.unlock()
	func _log_message(message: String, error: bool) -> void:
		pass

var _nodes: Array = []

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()

static func _shader_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or (dir == "res://tests" and sub == "fixtures"):
			continue
		_shader_files(dir.path_join(sub), out)

func _compile(path: String) -> Array:
	var lg := ShaderLog.new()
	OS.add_logger(lg)
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(path)
	var uniforms := sh.get_shader_uniform_list()
	OS.remove_logger(lg)
	var errs: Array = lg.errs.duplicate()
	if FileAccess.get_file_as_string(path).contains("uniform") and uniforms.is_empty():
		errs.append("sin uniforms tras compilar (¿falló el parse?)")
	return errs

func test_all_shaders_compile() -> void:
	var files: Array = []
	_shader_files("res://", files)
	ok(files.has(SHADER), "falta " + SHADER)
	for p in files:
		var errs := _compile(p)
		ok(errs.is_empty(), "%s no compila: %s" % [p, str(errs)])

func test_engraving_contract_text() -> void:
	var code := FileAccess.get_file_as_string(SHADER)
	ok(code.contains("shader_type spatial;"), "shader_type spatial")
	for rm in ["unshaded", "cull_disabled", "depth_test_disabled", "depth_draw_never"]:
		ok(code.contains(rm), "render_mode " + rm)
	ok(code.contains("POSITION = vec4(VERTEX.xy, 1.0, 1.0);"), "vértice en el plano cercano (Z invertida)")
	for h in ["hint_screen_texture", "hint_depth_texture", "hint_normal_roughness_texture", "INV_PROJECTION_MATRIX"]:
		ok(code.contains(h), "usa " + h)
	var no_comments := ""
	for line in code.split("\n"):
		var i := line.find("//")
		no_comments += (line.substr(0, i) if i >= 0 else line) + "\n"
	var re := RegEx.create_from_string("\\bTIME\\b")
	ok(re.search(no_comments) == null, "estático: sin TIME (la trama no titila)")
	ok(code.contains("bayer8"), "trama Bayer 8x8")
	var sh: Shader = load(SHADER)
	var names := []
	for u in sh.get_shader_uniform_list():
		names.append(u.name)
	for u in ["paper", "ink", "edge_depth", "edge_normal", "cell_px", "grain", "anchor_rad", "exposure", "contrast", "hatch"]:
		ok(names.has(u), "uniform " + u)
	# W4-STYLE: calibración por preset y separación de siluetas
	for u in ["gamma", "tone_floor", "vignette", "halo", "halo_rel", "halo_abs", "halo_thick"]:
		ok(names.has(u), "uniform " + u)
	ok(code.contains("line_thr"), "talla con umbrales uniformes por fila (calibración en toda la escala)")
	for k in EngravingPost.LOOK_KEYS:
		ok(names.has(k), "LOOK_KEYS: %s es uniform del shader" % k)

func test_post_attach_contract() -> void:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	var post = EngravingPost.attach(cam)
	ok(post != null and post.get_parent() == cam, "cuelga de la cámara")
	eq(String(post.name), "EngravingPost")
	ok(post.mesh is QuadMesh, "QuadMesh")
	eq(post.mesh.size, Vector2(2, 2), "quad 2x2")
	eq(post.extra_cull_margin, 16384.0, "extra_cull_margin")
	eq(post.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "sin sombras")
	eq(post.layers, EngravingPost.LAYER, "capa propia")
	var m = post.material_override
	ok(m is ShaderMaterial and m.shader != null and m.shader.resource_path == SHADER, "ShaderMaterial(engraving)")
	eq(m.render_priority, Material.RENDER_PRIORITY_MAX, "se dibuja último en la pasada transparente")
	ok(post.param("paper").is_equal_approx(Color("efe6d2")), "papel por defecto #efe6d2")
	ok(post.param("ink").is_equal_approx(Color("1b1712")), "tinta #1b1712")
	ok(EngravingPost.attach(cam) == post, "attach reutiliza")
	eq(cam.get_child_count(), 1, "un solo quad")
	ok(EngravingPost.find(cam) == post, "find")
	EngravingPost.detach(cam)
	ok(EngravingPost.find(cam) == null, "detach")

func test_post_renders_in_tree_without_errors() -> void:
	var lg := ShaderLog.new()
	OS.add_logger(lg)
	var root := Node3D.new()
	tree.root.add_child(root)
	_nodes.append(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -3)
	root.add_child(box)
	var post = EngravingPost.attach(cam)
	for i in 4:
		await tree.process_frame
	OS.remove_logger(lg)
	ok(lg.errs.is_empty(), "errores al dibujar: " + str(lg.errs))
	ok(post.is_inside_tree(), "en el árbol")

func test_anchor_follows_rotation() -> void:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	var post = EngravingPost.attach(cam)
	post.reanchor()
	ok(post.anchor_rad.is_equal_approx(Vector2.ZERO), "ancla en cero")
	post.update_anchor()
	ok(post.anchor_rad.is_equal_approx(Vector2.ZERO), "cámara quieta: la trama no se mueve")
	cam.rotate_object_local(Vector3.UP, -0.1)  # gira a la derecha
	post.update_anchor()
	ok(absf(post.anchor_rad.x - 0.1) < 1e-4 and absf(post.anchor_rad.y) < 1e-4, "yaw a la derecha +0,1: %s" % str(post.anchor_rad))
	cam.rotate_object_local(Vector3.RIGHT, 0.05)  # mira arriba
	post.update_anchor()
	ok(absf(post.anchor_rad.y - 0.05) < 1e-4, "pitch arriba +0,05: %s" % str(post.anchor_rad))
	var before: Vector2 = post.anchor_rad
	cam.position += Vector3(1, 0, 0)
	post.update_anchor()
	ok(post.anchor_rad.is_equal_approx(before), "traslación pura no mueve la trama")
	ok((post.param("anchor_rad") as Vector2).is_equal_approx(post.anchor_rad), "uniform actualizado")

# WorldRoot (W1-3D) llama set_slot(slot) cuando aún no conoce el preset del lugar: el papel sigue a la franja
# y se conserva el preset del look anterior.
func test_set_slot_keeps_preset_and_follows_paper() -> void:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	var post = EngravingPost.attach(cam)
	post.set_slot("N")
	ok(post.param("paper").is_equal_approx(Lighting.paper_for("N")), "noche: papel ámbar de gas")
	eq(str(post._look.get("preset", "")), "gas", "sin preset previo: el de la franja")
	post.set_look(Lighting.look("electrica_fria", "M"))
	post.set_slot("T")
	eq(str(post._look.get("preset", "")), "electrica_fria", "conserva el preset del lugar")
	ok(post.param("paper").is_equal_approx(Lighting.paper_for("T")), "papel de tarde")
	near(post.param("exposure"), Lighting.PRESETS.electrica_fria.post.exposure, 1e-6, "exposición del preset")
	post.set_slot("M", "dorada_parklane")
	eq(str(post._look.get("preset", "")), "dorada_parklane", "preset explícito")

# El ancla sigue a la cámara por NOTIFICATION_TRANSFORM_CHANGED (el rig la mueve con Tween, después de _process).
func test_anchor_updates_on_transform_notification() -> void:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	var post = EngravingPost.attach(cam)
	await tree.process_frame
	post.reanchor()
	var tw := cam.create_tween()
	tw.tween_callback(func(): cam.rotate_object_local(Vector3.UP, -0.2))
	await tree.process_frame  # el Tween corrió en el frame anterior, DESPUÉS de los _process: sólo la notificación lo vio
	ok(absf(post.anchor_rad.x - 0.2) < 1e-4, "giro por Tween acumulado: %s" % str(post.anchor_rad))

func test_look_palette_and_modes() -> void:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	_nodes.append(cam)
	var post = EngravingPost.attach(cam)
	post.set_look({"paper": Color("e8e6e0"), "exposure": 1.3, "haze": 0.2})
	ok(post.param("paper").is_equal_approx(Color("e8e6e0")), "papel del look")
	ok(absf(post.param("exposure") - 1.3) < 1e-6, "exposure del look")
	ok(absf(post.param("contrast") - EngravingPost.DEFAULTS.contrast) < 1e-6, "lo no dado vuelve al default")
	post.set_high_contrast(true)
	ok(post.param("paper").is_equal_approx(Color.WHITE) and post.param("ink").is_equal_approx(Color.BLACK), "alto contraste")
	eq(post.param("grain"), 0.0, "alto contraste sin grano")
	post.set_high_contrast(false)
	ok(post.param("paper").is_equal_approx(Color("e8e6e0")), "vuelve al papel de la franja")
	post.set_style("sepia")
	ok(post.param("ink").is_equal_approx(EngravingPost.PALETTES.sepia.ink), "sepia = sólo papel y tinta")
	post.set_style("dos_tintas")
	post.set_palette(Color.WHITE, Color.BLACK)
	ok(post.current_paper().is_equal_approx(Color.WHITE), "set_palette")
	post.set_enabled(false)
	ok(not post.visible, "set_enabled(false)")
