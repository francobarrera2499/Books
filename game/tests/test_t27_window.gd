# T27 (W1-POST) — parte con ventana: calibración del grabado, contornos, trama estable y anclada, CanvasLayer intacta.
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window t27
extends "res://tests/test_base.gd"

const WINDOW := true
const TIMEOUT_S := 90.0
const EngravingPost = preload("res://world/post/engraving_post.gd")
const Lighting = preload("res://world/lighting.gd")
const Scene = preload("res://devtools/drivers/w1post_scene.gd")

var _nodes: Array = []

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()

func _skip_if_headless() -> bool:
	if DisplayServer.get_name() == "headless":
		if has_method("skip"):
			call("skip", "requiere ventana")
		return true
	return false

func _rig(fov := 40.0) -> Dictionary:
	var root := Node3D.new()
	tree.root.add_child(root)
	_nodes.append(root)
	var we := WorldEnvironment.new()
	we.environment = Lighting.make_environment("tarde")
	root.add_child(we)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.current = true
	var post = EngravingPost.attach(cam)
	post.set_palette(Color.WHITE, Color.BLACK)
	post.set_param("grain", 0.0)
	return {"root": root, "cam": cam, "post": post}

func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

func _plane(root: Node3D, z: float, c: Color, size := 60.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.position = Vector3(0, 0, z)
	mi.material_override = _unshaded(c)
	root.add_child(mi)
	return mi

func _grab(frames := 4) -> Image:
	for i in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

static func _lum(d: PackedByteArray, w: int, x: int, y: int) -> float:
	var i := (y * w + x) * 3
	return (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255.0

static func _mean(img: Image, r: Rect2i, step := 1) -> float:
	var d := img.get_data()
	var w := img.get_width()
	var s := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			s += _lum(d, w, x, y)
			n += 1
	return s / maxf(1.0, n)

static func _ink_frac(img: Image, r: Rect2i) -> float:
	var d := img.get_data()
	var w := img.get_width()
	var n := 0
	var k := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _lum(d, w, x, y) < 0.5:
				k += 1
			n += 1
	return float(k) / maxf(1.0, n)

static func _center(img: Image, frac: float) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	return Rect2i(int(w * (1.0 - frac) / 2.0), int(h * (1.0 - frac) / 2.0), int(w * frac), int(h * frac))

static func _lum_c(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

# GDD §15.5 / ARCH §7.8: plano gris 0,5 a 5 m -> gris medio esperado ±0,06 en la captura.
func test_calibration_gray_plane_5m() -> void:
	if _skip_if_headless():
		return
	var rg := _rig()
	_plane(rg.root, -5.0, Color(0.5, 0.5, 0.5))
	var post = rg.post
	post.set_param("debug_view", 1)
	var img: Image = await _grab()
	var m_tone := _mean(img, _center(img, 0.6), 2)
	print("T27 tono continuo: %.4f (esperado 0,5)" % m_tone)
	ok(absf(m_tone - 0.5) <= 0.02, "tono continuo %.4f" % m_tone)
	post.set_param("debug_view", 0)
	img = await _grab()
	var m_talla := _mean(img, _center(img, 0.6))
	print("T27 talla (tinta/papel b/n): %.4f" % m_talla)
	ok(absf(m_talla - 0.5) <= 0.06, "talla: gris medio %.4f ±0,06" % m_talla)
	post.set_param("hatch", 0.0)
	img = await _grab()
	var m_bayer := _mean(img, _center(img, 0.6))
	print("T27 Bayer 8x8 (b/n): %.4f" % m_bayer)
	ok(absf(m_bayer - 0.5) <= 0.06, "Bayer: gris medio %.4f ±0,06" % m_bayer)
	post.set_param("hatch", 1.0)
	post.set_palette(EngravingPost.PAPER, EngravingPost.INK)
	post.set_param("grain", EngravingPost.DEFAULTS.grain)
	img = await _grab()
	var m_real := _mean(img, _center(img, 0.6))
	var exp_real := _lum_c(EngravingPost.INK) + 0.5 * (_lum_c(EngravingPost.PAPER) - _lum_c(EngravingPost.INK))
	print("T27 dos tintas con grano: %.4f (esperado %.4f)" % [m_real, exp_real])
	ok(absf(m_real - exp_real) <= 0.06, "dos tintas: %.4f vs %.4f ±0,06" % [m_real, exp_real])

# Contornos: un plano y una caja blancos (tono = papel): la única tinta posible son los contornos.
func test_contours_visible_and_no_false_edges() -> void:
	if _skip_if_headless():
		return
	var rg := _rig()
	_plane(rg.root, -6.0, Color.WHITE)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	box.mesh = bm
	box.material_override = _unshaded(Color.WHITE)
	box.position = Vector3(0, 0, -3.0)
	box.rotation_degrees = Vector3(20, 35, 0)
	rg.root.add_child(box)
	var img: Image = await _grab()
	var cam: Camera3D = rg.cam
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 8:
		var c := Vector3((i & 1) - 0.5, ((i >> 1) & 1) - 0.5, ((i >> 2) & 1) - 0.5)
		var p := cam.unproject_position(box.global_transform * c)
		lo = lo.min(p)
		hi = hi.max(p)
	var r := Rect2i(Vector2i(lo) - Vector2i(4, 4), Vector2i(hi - lo) + Vector2i(8, 8))
	var w := img.get_width()
	var h := img.get_height()
	var corner := Rect2i(20, 20, int(r.position.x) - 40, h - 40)
	var plane_ink := _ink_frac(img, corner)
	print("T27 tinta en el plano liso: %.5f" % plane_ink)
	ok(plane_ink < 0.002, "plano a 6 m sin contornos falsos: %.5f" % plane_ink)
	var ink_box := _ink_frac(img, r) * r.size.x * r.size.y
	var perim := 2.0 * (hi.x - lo.x + hi.y - lo.y)
	print("T27 píxeles de contorno en la caja: %d (perímetro del rect %d)" % [int(ink_box), int(perim)])
	ok(ink_box > perim * 0.9, "contornos visibles (silueta + arista interior): %d" % int(ink_box))
	var inner := Rect2i(Vector2i((lo + hi) / 2.0) - Vector2i(6, 6), Vector2i(12, 12))
	ok(r.encloses(inner), "rect interior")
	ok(w > 0, "imagen")

# Trama estable (cámara quieta = idéntica) y anclada a la esfera (al girar se desplaza con el mundo).
func test_pattern_stable_and_anchored() -> void:
	if _skip_if_headless():
		return
	var rg := _rig(40.0)
	_plane(rg.root, -5.0, Color(0.5, 0.5, 0.5), 200.0)
	var a: Image = await _grab()
	var a2: Image = await _grab(6)
	var c := _center(a, 0.5)
	ok(_diff_frac(a, a2, c, Vector2i.ZERO) == 0.0, "cámara quieta: trama idéntica entre frames")
	var k := 0.5 * a.get_height() / tan(deg_to_rad(40.0) / 2.0)
	var cam: Camera3D = rg.cam
	cam.rotate_object_local(Vector3.UP, -12.0 / k)  # gira a la derecha 12 px
	var b: Image = await _grab()
	var moved := _diff_frac(a, b, c, Vector2i.ZERO)
	var anchored := _diff_frac(a, b, c, Vector2i(12, 0))
	print("T27 giro yaw: distinto sin desplazar %.3f · con desplazamiento de 12 px %.4f" % [moved, anchored])
	ok(moved > 0.2, "la trama acompaña al giro (no es de pantalla)")
	ok(anchored < 0.01, "yaw: B(x) == A(x+12): %.4f" % anchored)
	cam.rotate_object_local(Vector3.RIGHT, 8.0 / k)  # mira arriba 8 px
	var b2: Image = await _grab()
	var anch2 := _diff_frac(b, b2, c, Vector2i(0, -8))
	print("T27 giro pitch: con desplazamiento de 8 px %.4f" % anch2)
	ok(anch2 < 0.01, "pitch: C(y) == B(y-8): %.4f" % anch2)

# El rig de cámara (W1-3D) mueve la cámara con Tween, que corre DESPUÉS de los _process de los nodos: el ancla
# debe tomar la pose final del frame (sin un frame de retraso entre el mundo y la trama).
func test_pattern_anchored_when_tween_moves_camera() -> void:
	if _skip_if_headless():
		return
	var rg := _rig(40.0)
	_plane(rg.root, -5.0, Color(0.5, 0.5, 0.5), 200.0)
	var a: Image = await _grab()
	var c := _center(a, 0.5)
	var k := 0.5 * a.get_height() / tan(deg_to_rad(40.0) / 2.0)
	var cam: Camera3D = rg.cam
	var tw := (rg.root as Node).create_tween()
	tw.tween_callback(func(): cam.rotate_object_local(Vector3.UP, -12.0 / k))
	await RenderingServer.frame_post_draw
	var b := tree.root.get_texture().get_image()
	b.convert(Image.FORMAT_RGB8)
	var moved := _diff_frac(a, b, c, Vector2i.ZERO)
	var anchored := _diff_frac(a, b, c, Vector2i(12, 0))
	print("T27 giro por Tween, mismo frame: sin desplazar %.3f · desplazamiento de 12 px %.4f" % [moved, anchored])
	ok(moved > 0.2, "el giro por Tween llegó a este frame")
	ok(anchored < 0.01, "Tween: la trama acompaña al giro en el mismo frame: %.4f" % anchored)

# fracción de píxeles que difieren (tinta/papel) entre a(x+off) y b(x) en la región r
static func _diff_frac(a: Image, b: Image, r: Rect2i, off: Vector2i) -> float:
	var da := a.get_data()
	var db := b.get_data()
	var w := a.get_width()
	var n := 0
	var k := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ia := _lum(da, w, x + off.x, y + off.y) < 0.5
			var ib := _lum(db, w, x, y) < 0.5
			if ia != ib:
				k += 1
			n += 1
	return float(k) / maxf(1.0, n)

# Una CanvasLayer con texto queda intacta: mismos píxeles con y sin grabado, y el 3D sí cambia.
func test_canvas_layer_untouched() -> void:
	if _skip_if_headless():
		return
	var holder := Node.new()
	tree.root.add_child(holder)
	_nodes.append(holder)
	var sc := Scene.build(holder)
	Scene.set_preset(sc, "dia_ventana", "M")
	var on: Image = await _grab(8)
	sc.post.set_enabled(false)
	var off: Image = await _grab(4)
	var pr := Rect2i(Vector2i(sc.panel.position), Vector2i(sc.panel.size))
	var h := on.get_height()
	var band := Rect2i(0, h - 70, on.get_width(), 66)
	var same_panel := on.get_region(pr).get_data() == off.get_region(pr).get_data()
	var same_band := on.get_region(band).get_data() == off.get_region(band).get_data()
	ok(same_panel, "panel con texto idéntico con y sin grabado")
	ok(same_band, "epígrafe idéntico con y sin grabado")
	var px := on.get_pixel(pr.position.x + pr.size.x - 6, pr.position.y + 4)
	ok(px.is_equal_approx(Color("f0e8d6")) or (absf(px.r - 0.941) < 0.01 and absf(px.g - 0.91) < 0.01), "color del panel exacto: %s" % px.to_html(false))
	var mid := Rect2i(400, 200, 800, 400)
	var d3 := absf(_mean(on, mid, 3) - _mean(off, mid, 3)) + _diff_frac(on, off, mid, Vector2i.ZERO)
	ok(d3 > 0.05, "el 3D sí pasa por el grabado (%.3f)" % d3)
	# el rótulo 3D (Label3D con alpha_cut) se lee: hay tinta donde están las letras
	var cam: Camera3D = sc.cam
	var lab: Label3D = sc.props.get_node("Rotulo")
	var lp := cam.unproject_position(lab.global_position)
	var lr := Rect2i(Vector2i(lp) - Vector2i(120, 18), Vector2i(240, 36))
	var ink_lab := _ink_frac(on, lr)
	print("T27 tinta en el rótulo 3D: %.3f" % ink_lab)
	ok(ink_lab > 0.15, "el Label3D con alpha_cut sale en el grabado")

# Cada preset rinde algo legible: hay papel y tinta, la noche es más oscura que el día y los contornos existen.
func test_presets_legible() -> void:
	if _skip_if_headless():
		return
	var holder := Node.new()
	tree.root.add_child(holder)
	_nodes.append(holder)
	var sc := Scene.build(holder)
	var res := {}
	for p in Lighting.names():
		var slot := "N" if p in ["gas", "farol_calle", "noche_viento", "dorada_parklane"] else ("T" if p == "tarde" else "M")
		Scene.set_preset(sc, p, slot)
		var img: Image = await _grab(5)
		var r := Rect2i(0, 100, img.get_width(), img.get_height() - 200)
		res[p] = _ink_frac(img, r)
	print("T27 tinta por preset: ", res)
	for p in res:
		ok(res[p] > 0.08 and res[p] < 0.85, "%s legible (tinta %.2f)" % [p, res[p]])
	var day := (float(res.manana_perla) + float(res.dia_ventana) + float(res.tarde)) / 3.0
	var night := (float(res.gas) + float(res.farol_calle) + float(res.noche_viento)) / 3.0
	ok(night > day + 0.1, "la noche lleva más tinta que el día (%.2f vs %.2f)" % [night, day])
	sc.post.set_param("debug_view", 2)
	Scene.set_preset(sc, "dia_ventana", "M")
	var e: Image = await _grab(4)
	var ef := _ink_frac(e, Rect2i(0, 100, e.get_width(), e.get_height() - 200))
	print("T27 fracción de contornos: %.3f" % ef)
	ok(ef > 0.01 and ef < 0.25, "contornos visibles y no invasivos (%.3f)" % ef)
