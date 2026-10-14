# test_u_reader_v3_window.gd — LECTOR con ventana (GDD_v3 §6.7 y el riesgo de §8.8): el fondo del lector deja ver lo que
# hay debajo (no sale negro), desenfocado (unas rayas finas se vuelven un gris parejo) y oscurecido ≈25 %; el papel queda
# nítido encima. En alto contraste, gris liso. Se prueba con la textura de pantalla («pantalla», por defecto) y con el plan
# B («captura»). Debajo, una escena 2D de colores conocidos (no hace falta el 3D: el shader lee la pantalla igual).
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window reader_v3_window
extends "res://tests/test_base.gd"

const WINDOW := true
const TIMEOUT_S := 90.0

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")

const LEFT := Color(0.85, 0.35, 0.2)
const RIGHT := Color(0.2, 0.4, 0.85)

var _nodes: Array = []
var rd = null

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	rd = null
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti != null and ti.high_contrast:
		ti.set_high_contrast(false)

func _add(n: Node) -> Node:
	tree.root.add_child(n)
	_nodes.append(n)
	return n

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func _cap() -> Image:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()

# Fondo conocido: mitad izquierda cálida, mitad derecha fría, y a la izquierda (fuera del papel) rayas blancas y negras de 2 px.
func _scene() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 0
	_add(cl)
	var vs: Vector2 = tree.root.get_visible_rect().size
	var l := ColorRect.new()
	l.color = LEFT
	l.position = Vector2.ZERO
	l.size = Vector2(vs.x * 0.5, vs.y)
	cl.add_child(l)
	var r := ColorRect.new()
	r.color = RIGHT
	r.position = Vector2(vs.x * 0.5, 0)
	r.size = Vector2(vs.x * 0.5, vs.y)
	cl.add_child(r)
	for k in 40:
		var s := ColorRect.new()
		s.color = Color.WHITE if k % 2 == 0 else Color.BLACK
		s.position = Vector2(30.0 + float(k) * 2.0, 280.0)
		s.size = Vector2(2.0, 160.0)
		cl.add_child(s)

func _open(mode: String) -> void:
	rd = Reader.new()
	rd.sounds = false
	rd.emit_read = false
	rd.blur_mode = mode
	_add(rd)
	await _frames(3)
	ok(rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM")), "abre")
	await tree.create_timer(0.4).timeout   # fundido de entrada (0,18 s)
	await _frames(2)

func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _check_backdrop(img: Image, tag: String) -> void:
	var vs: Vector2 = tree.root.get_visible_rect().size
	var sx := float(img.get_width()) / vs.x
	var sy := float(img.get_height()) / vs.y
	var px := func(p: Vector2) -> Color: return img.get_pixel(int(p.x * sx), int(p.y * sy))
	# fuera del papel, lejos del borde entre colores: el mismo color, oscurecido, nunca negro
	var cl: Color = px.call(Vector2(90, vs.y * 0.62))
	ok(_lum(cl) > 0.12, "%s: el fondo no sale negro (lum %.2f)" % [tag, _lum(cl)])
	var kr := cl.r / LEFT.r
	ok(kr > 0.5 and kr < 0.9, "%s: oscurecido ≈25 %% (rojo ×%.2f)" % [tag, kr])
	ok(cl.r > cl.b, "%s: se sigue viendo el color de abajo (%s)" % [tag, cl])
	var cr: Color = px.call(Vector2(vs.x - 40.0, vs.y * 0.62))
	ok(cr.b > cr.r, "%s: a la derecha, el otro color (%s)" % [tag, cr])
	# desenfoque: las rayas de 2 px quedan casi parejas
	var lo := 1.0
	var hi := 0.0
	for x in range(44, 96):
		var v := _lum(px.call(Vector2(x, 360)))
		lo = minf(lo, v)
		hi = maxf(hi, v)
	ok(hi - lo < 0.2, "%s: desenfocado (rayas: %.2f..%.2f)" % [tag, lo, hi])

func test_screen_blur_dims_not_black_and_paper_sharp() -> void:
	_scene()
	await _frames(4)
	await _open("pantalla")
	var img := await _cap()
	_check_backdrop(img, "pantalla")
	# el papel, encima y nítido: su color en el centro de la hoja (lejos del texto)
	var pr: Rect2 = rd.paper_rect()
	ok(pr.size.x > 100.0, "hay papel")
	var vs: Vector2 = tree.root.get_visible_rect().size
	var c := img.get_pixel(int((pr.position.x + 12.0) * img.get_width() / vs.x), int((pr.get_center().y) * img.get_height() / vs.y))
	ok(c.r > 0.75 and c.g > 0.7 and c.b > 0.6, "el borde de la hoja es papel claro, no fondo (%s)" % c)

func test_capture_plan_b() -> void:
	_scene()
	await _frames(4)
	await _open("captura")
	var img := await _cap()
	_check_backdrop(img, "captura")

func test_high_contrast_plain_gray() -> void:
	_scene()
	await _frames(4)
	await _open("pantalla")
	tree.root.get_node("ThemeInstaller").set_high_contrast(true)
	await _frames(3)
	var img := await _cap()
	var vs: Vector2 = tree.root.get_visible_rect().size
	var c := img.get_pixel(int(90.0 * img.get_width() / vs.x), int(vs.y * 0.62 * img.get_height() / vs.y))
	ok(absf(c.r - 0.16) < 0.04 and absf(c.b - 0.16) < 0.04, "alto contraste: gris liso (%s)" % c)
