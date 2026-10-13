# Regresión: Confirm con texto largo (String → RichTextLabel fit_content+autowrap) centrado como lo hacen los
# llamadores (reset_size + centrar en el mismo cuadro) debía quedar más alto que la pantalla, con texto y botones
# fuera de la vista (título: «Partida nueva»/«Continuar» no hacían nada). Tras 2 cuadros debe caber y verse.
extends "res://tests/test_base.gd"

const Widgets = preload("res://ui/kit/widgets.gd")

func _show(body: String) -> Array:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	var c = Widgets.confirm(body, "Empezar de nuevo", "Volver", "Partida nueva")
	host.add_child(c)
	c.reset_size()
	c.position = ((c.get_viewport().get_visible_rect().size - c.size) * 0.5).floor()
	for i in 6:
		await tree.process_frame
	return [host, c]

func test_long_text_confirm_fits_and_is_visible():
	var r = await _show("Empezar de nuevo borra la partida guardada. Lo hecho no se recupera.")
	var host: Control = r[0]
	var c = r[1]
	var vs: Vector2 = c.get_viewport().get_visible_rect().size
	ok(c.size.y < vs.y - 16.0, "confirm más alto que la pantalla: %s" % str(c.size))
	ok(c.size.y < 400.0, "confirm de dos renglones demasiado alto: %s" % str(c.size))
	near(c.modulate.a, 1.0, 0.001, "confirm quedó invisible")
	for b in [c.ok_button, c.back_button]:
		var gr: Rect2 = b.get_global_rect()
		ok(Rect2(Vector2.ZERO, vs).encloses(gr), "botón fuera de la pantalla: %s" % str(gr))
	host.queue_free()

func test_very_long_text_still_fits():
	var txt := ""
	for i in 12:
		txt += "La partida se guardó con otra versión del texto: algunas cosas pueden no estar donde las dejé. "
	var r = await _show(txt)
	var c = r[1]
	var vs: Vector2 = c.get_viewport().get_visible_rect().size
	var gr: Rect2 = c.ok_button.get_global_rect()
	ok(gr.position.y >= 0.0 and gr.end.y <= vs.y + 0.5, "botón OK fuera de la pantalla con texto largo: %s" % str(gr))
	r[0].queue_free()
