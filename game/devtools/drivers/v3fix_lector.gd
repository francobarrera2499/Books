# devtools/drivers/v3fix_lector.gd — CORRECTOR FINAL (playtest v3): el lector con ventana, SIN --fast y eventos reales.
#   1. La tira de HA2 (señalador, 22 × 190 mm): se dibuja ACOSTADA y se lee entera (antes, de a 1–4 letras por renglón).
#   2. Una hoja larga de «El problema final»: la RUEDA desplaza (antes acercaba) hasta el último renglón, arriba de la
#      paginación; Ctrl + rueda acerca.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3fixl res://devtools/drivers/v3fix_lector.gd
# Salida: «V3FIXL OK» o «V3FIXL FALLA n» (una línea «V3FIXL FALLA: …» por chequeo). Capturas .work/shots/v3fixl_*.png.
extends "res://devtools/drivers/v3lector_shots.gd"

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("V3FIXL FALLA: ", what)
	else:
		print("V3FIXL ok: ", what)

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3FIXL VIGIA")
		tool.quit(2))
	vp = tool.root.get_viewport()
	for c in scene.get_children():
		c.queue_free()
	await tool.frames(2)
	repo = tool.root.get_node("Data").repo()
	sim = V3Fixture.sim(repo)
	_room(scene)
	await tool.frames(60)
	reader = Reader.new()
	reader.act_fn = _act
	reader.sounds = false
	scene.add_child(reader)
	await tool.frames(4)
	# ---------------- 1. la tira de HA2 (la vista como la arma Effects: línea física + rastro)
	var Fis = load("res://core/text/fisica.gd")
	var spec: Dictionary = Fis.spec_tpl(repo.fisica(), "senalador")
	var line := String(Fis.line(spec, [22, 190], repo.fisica()))
	var txt := line + "\n" + "{{#tira a:vinculo_mycroft e:membrete_recortado e:tiras_de_papel|Entre las páginas de «The Times, enero-mayo de 1891», de señalador, una tira de papel de carta con medio membrete impreso: «…GENES CLUB · [[pall_mall|PALL MALL]]…».}}"
	var v := {"view": "R.HA2.11", "title": "Tira de papel usada como señalador", "src_line": "Tira de papel usada como señalador, papel privado",
		"paper": "diogenes_recortado", "paper_mm": [22, 190], "font": "imprenta", "machine": "", "ficha": null, "marks": [],
		"pages": [[{"doc": "R.HA2.11", "origin": "R.HA2.11", "copy": "R.HA2.11", "parsed": repo.parse_text(txt), "slot": "cuerpo"}]]}
	synthetic["R.HA2.11"] = true
	ok(reader.open_view(v), "abre la tira")
	await tool.frames(20)
	var pg = reader.page
	ok(pg.paper_mm.x > pg.paper_mm.y, "la tira se dibuja acostada (%s mm)" % str(pg.paper_mm))
	var r: RichTextLabel = reader.block_rtl(0)
	var lines := r.get_line_count()
	ok(lines >= 2 and lines <= 8, "se lee en pocos renglones (%d)" % lines)
	var pr: Rect2 = reader.paper_rect()
	ok(pr.position.y >= 0.0 and pr.end.y <= vp.get_visible_rect().size.y, "la tira entera en la pantalla (%s)" % str(pr))
	await tool.snap("tira")
	reader.close()
	await tool.frames(6)
	# ---------------- 2. una hoja larga: la rueda desplaza
	var fina := V3Fixture.fina_view(repo)
	ok(reader.open_view(fina), "abre FINA")
	await tool.frames(16)
	var tall := -1
	for i in reader.page_count():
		reader.go_page(i)
		await tool.frames(4)
		if reader.paper_rect().end.y > vp.get_visible_rect().size.y - Reader.BOTTOM_BAND + 4.0:
			tall = i
			break
	ok(tall >= 0, "hay una hoja más alta que la pantalla (hoja %d)" % (tall + 1))
	if tall < 0:
		_end2()
		return
	await tool.snap("fina_larga_arriba")
	var z0: float = reader.zoom
	var y0: float = reader.paper_rect().position.y
	var at := Vector2(800, 450)
	for _i in 25:
		await _wheel_plain(at, MOUSE_BUTTON_WHEEL_DOWN)
	await tool.frames(6)
	var pr2: Rect2 = reader.paper_rect()
	ok(is_equal_approx(reader.zoom, z0), "la rueda no cambia el zoom (%.2f → %.2f)" % [z0, reader.zoom])
	ok(pr2.position.y < y0 - 40.0, "la rueda baja la hoja (%.0f → %.0f)" % [y0, pr2.position.y])
	ok(pr2.end.y <= vp.get_visible_rect().size.y - Reader.BOTTOM_BAND + 1.0, "el último renglón queda arriba de la paginación (fin %.0f)" % pr2.end.y)
	var pager: Rect2 = reader.pager_rect()
	ok(pager.position.y >= pr2.end.y - 1.0, "la paginación no tapa el papel (paginación %.0f, papel %.0f)" % [pager.position.y, pr2.end.y])
	await tool.snap("fina_larga_abajo")
	for _i in 2:
		await _wheel(at, MOUSE_BUTTON_WHEEL_UP)
	await tool.frames(6)
	ok(reader.zoom > z0 * 1.15, "Ctrl + rueda acerca (%.2f → %.2f)" % [z0, reader.zoom])
	_end2()

func _wheel_plain(pos: Vector2, button: MouseButton) -> void:
	_mm(pos)
	await tool.frames(1)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.factor = 1.0
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
	await tool.frames(1)

func _end2() -> void:
	print("V3FIXL OK" if fails == 0 else "V3FIXL FALLA %d" % fails)
