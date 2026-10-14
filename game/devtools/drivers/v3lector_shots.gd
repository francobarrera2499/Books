# devtools/drivers/v3lector_shots.gd — LECTOR (GDD_v3 §6.7, §7.2 P5): el lector flotante sobre la buhardilla, con ventana,
# SIN --fast y con eventos reales de mouse y teclado (warp_mouse + Input.parse_input_event, como title_smoke/v2_novato).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3lector res://devtools/drivers/v3lector_shots.gd
# Detrás: la buhardilla real (WorldRoot, data/places/L1.json, encuadre del escritorio). Delante: DocumentReader con
# «El problema final» del cliente (D03@tomo: ficha de Lisle, marquitas, nota a lápiz al margen, tarjeta del cliente) y
# «El hombre del labio retorcido» (D01.TWIS@tomo, la nota «mi James» al margen). Si los datos todavía no traen el bloque
# v3 (paquete CONTENIDO), las vistas se arman como en tests/fixtures/v3 (V3Fixture.fina_view) y como manda GDD_v3 §3.2
# para TWIS (se avisa «sintética»).
# Capturas (.work/shots/v3lector_<n>.png): fina_1 … fina_<N> (la crónica completa, hoja por hoja; la última es la
#   tarjeta: también fina_tarjeta), fina_sheer (la hoja de #sheer, desplazada a mano hasta el pasaje marcado),
#   fina_tijera (la tijera en la mano, arrastrando sobre la nota al margen), fina_recorte (la tira volando),
#   fina_zoom (rueda: 130 %), twis_margen, fina_hc (alto contraste).
# Salida: «V3LECTOR OK» o «V3LECTOR FALLA <n>» con una línea «V3LECTOR FALLA: …» por chequeo.
extends RefCounted

const DB = preload("res://world/diorama_builder.gd")
const EP = preload("res://world/post/engraving_post.gd")
const Reader = preload("res://ui/reader/document_reader.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const V3Fixture = preload("res://tests/fixtures/v3/v3_fixture.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

var tool
var vp: Viewport
var reader
var repo
var sim
var acts: Array = []
var fails := 0
var synthetic := {}

# GDD_v3 §3.2 (para cuando los datos todavía no traen v3): ficha, marquitas, notas al margen y tarjeta.
const SPEC := {
	"D01.TWIS@tomo": {"nc": "NC.TWIS",
		"ficha": {"trata": "Un hombre desaparece y Holmes lo encuentra en el lugar menos pensado.",
			"cuando": "Pasó en junio de 1889; salió en la Strand en diciembre de 1891.",
			"por_que": "El cliente marcó un disfraz y la línea donde la esposa del doctor lo llama «James»."},
		"marcas": ["viejo", "james"], "margen": [["D01N", "mi_james", "james"]],
		"nota": "Un señor respetable que vive de mendigo, señor. {{#tic a:rasgo_de_harris e:adjetivos_repetidos|Hasta los nombres se disfrazan, se disfrazan: lea cómo llama la señora al doctor.}} —H."},
}

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("V3LECTOR FALLA: ", what)

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(420.0).timeout.connect(func():
		print("V3LECTOR VIGIA: se corta a los 420 s")
		tool.quit(2))
	vp = tool.root.get_viewport()
	for c in scene.get_children():
		c.queue_free()
	await tool.frames(2)
	repo = tool.root.get_node("Data").repo()
	sim = V3Fixture.sim(repo)
	# la buhardilla de fondo (diorama + cámara del encuadre del escritorio + post «aguada»; sin WorldRoot, que otro
	# paquete está cambiando: el lector sólo necesita algo real detrás)
	_room(scene)
	await tool.frames(60)
	reader = Reader.new()
	reader.act_fn = _act
	reader.sounds = false
	if OS.get_environment("V3L_BLUR") != "":
		reader.blur_mode = OS.get_environment("V3L_BLUR")   # "captura": plan B de GDD_v3 §8.8
	scene.add_child(reader)
	await tool.frames(4)

	# ---------------- FINA, hoja por hoja (con las flechas de abajo, clic real)
	var fina := V3Fixture.fina_view(repo)
	ok(not fina.is_empty(), "hay vista de FINA")
	if fina.is_empty():
		_end()
		return
	print("V3LECTOR FINA %s, %d hojas" % ["sintética" if fina.get("_sintetico", false) else "datos reales", fina.pages.size()])
	ok(reader.open_view(fina), "abre FINA")
	await tool.frames(20)
	var n: int = reader.page_count()
	_check_page("fina", 0)
	await tool.snap("fina_1")
	var ic: Rect2 = reader.scissors_rect()
	await _crop("icono", Rect2i(Vector2i(ic.get_center()) - Vector2i(65, 50), Vector2i(130, 100)), 4)
	for i in range(1, n):
		var r: Rect2 = reader.pager_rect()
		ok(r.size.x > 0.0, "paginación visible")
		var nxt: Control = reader._b_next
		await _click(nxt.get_global_rect().get_center())
		await tool.frames(12)
		ok(reader.page_idx == i, "la flecha › pasa a la hoja %d (está en %d)" % [i + 1, reader.page_idx + 1])
		_check_page("fina", i)
		await tool.snap("fina_%d" % (i + 1))
	ok(bool(reader.page.card), "la última hoja es la tarjeta del cliente")
	await tool.snap("fina_tarjeta")
	# recorte en la tarjeta: con la tecla C, arrastre real
	await _key(KEY_C)
	await tool.frames(4)
	ok(reader.tijera, "C toma la tijera")
	# la nota del cliente (no la descripción física que la encabeza): «Léalos despacio, despacio.» si está
	var cb := 0
	var card_text := _first_words(reader.block_rtl(0), 5)
	for j in reader.page.blocks.size():
		if reader.block_rtl(j).get_parsed_text().contains("Léalos despacio, despacio"):
			cb = j
			card_text = "Léalos despacio, despacio"
	print("V3LECTOR tarjeta: %d bloque(s); se recorta «%s» del bloque %d" % [reader.page.blocks.size(), card_text, cb])
	acts.clear()
	await _drag(reader.block_rtl(cb), card_text)
	await tool.frames(6)
	_clip_ok(_last_clip_origin() == "NC.FINA", "recortar la tarjeta da un recorte de NC.FINA (dio %s)" % _last_clip_origin())
	await tool.frames(30)

	# ---------------- la hoja de #sheer: marquitas y la nota del F.O. al margen
	var sp := _page_with_margin(fina)
	ok(sp >= 0, "FINA tiene una hoja con nota al margen")
	if sp >= 0:
		reader.go_page(sp)
		await tool.frames(10)
		# dejar la tijera con el ícono (clic real)
		await _click(reader.scissors_rect().get_center())
		await tool.frames(4)
		ok(not reader.tijera, "clic en el ícono: deja la tijera")
		var mi := _margin_block(reader.page)
		var mr: RichTextLabel = reader.block_rtl(mi)
		# desplazar el papel con el mouse hasta que la nota quede en el medio de la pantalla
		var target_y := vp.get_visible_rect().size.y * 0.45
		var note_y := (mr.get_global_transform_with_canvas() * Vector2(0, 0)).y
		if note_y > target_y:
			await _pan(Vector2(800, 700), Vector2(800, 700 - (note_y - target_y)))
		await tool.frames(8)
		_check_margin(mi)
		await tool.snap("fina_sheer")
		# tijera con el ícono y arrastre sobre la nota del margen
		await _click(reader.scissors_rect().get_center())
		await tool.frames(4)
		ok(reader.tijera, "clic en el ícono: toma la tijera")
		var words := _first_words(mr, 4)
		acts.clear()
		await _drag(mr, words, true)
		await tool.snap("fina_tijera")
		await _release()
		await tool.frames(3)
		await tool.snap("fina_recorte")
		await tool.frames(4)
		_clip_ok(_last_clip_origin() == "D01N", "recortar la nota del margen da un recorte de D01N (dio %s)" % _last_clip_origin())
		await tool.frames(30)
		await _right_click(Vector2(800, 450))
		await tool.frames(4)
		ok(not reader.tijera, "clic derecho: deja la tijera")
	# ---------------- la otra marquita (#a_mycroft) y el pie de la hoja: con ↓ hasta el final (la paginación no tapa el texto)
	var mk_page := -1
	for m in fina.get("marks", []):
		if String(m.get("tramo", "")) == "a_mycroft":
			mk_page = int(m.get("page", -1))
	if mk_page >= 0:
		reader.go_page(mk_page)
		await tool.frames(8)
		for _k in 40:
			await _key(KEY_DOWN)
		await tool.frames(6)
		var last: RichTextLabel = null
		for j in reader.page.blocks.size():
			if reader.page.slots[j] == "cuerpo":
				last = reader.page.blocks[j]
		if last != null:
			var bottom_y: float = (last.get_global_transform_with_canvas() * Vector2(0, last.size.y)).y
			ok(bottom_y < reader.pager_rect().position.y, "con ↓ el último renglón queda arriba de la paginación (%.0f)" % bottom_y)
		var pr: Rect2 = reader.paper_rect()
		ok(pr.end.y >= vp.get_visible_rect().size.y - Reader.BOTTOM_BAND - 1.0, "la hoja no se va de la pantalla (borde de abajo en %.0f)" % pr.end.y)
		ok(not reader.page.mark_rects().is_empty(), "marquita de #a_mycroft dibujada")
		await tool.snap("fina_mycroft")
	# zoom con Ctrl + rueda
	reader.go_page(0)
	await tool.frames(8)
	var b0: RichTextLabel = reader.block_rtl(0)
	var at: Vector2 = b0.get_global_transform_with_canvas() * Vector2(b0.size.x * 0.4, 60)
	for _i in 2:
		await _wheel(at, MOUSE_BUTTON_WHEEL_UP)
	await tool.frames(6)
	ok(reader.tool_names().has("Zoom"), "fuera del zoom de lectura aparece el indicador")
	await tool.snap("fina_zoom")
	await _click((reader._b_zoom as Control).get_global_rect().get_center())
	await tool.frames(4)
	ok(not reader.tool_names().has("Zoom"), "clic en el indicador: vuelve al zoom de lectura")
	# alto contraste
	var ti = tool.root.get_node("ThemeInstaller")
	ti.set_high_contrast(true)
	await tool.frames(10)
	await tool.snap("fina_hc")
	ti.set_high_contrast(false)
	await tool.frames(4)
	await _key(KEY_ESCAPE)
	await tool.frames(4)
	ok(not reader.visible, "Esc cierra el lector")

	# ---------------- TWIS: «mi James» al margen
	var tw := _view_v3("D01.TWIS@tomo")
	ok(not tw.is_empty(), "hay vista de TWIS")
	if not tw.is_empty():
		print("V3LECTOR TWIS %s, %d hojas" % ["sintética" if synthetic.get("D01.TWIS@tomo", false) else "datos reales", tw.pages.size()])
		reader.open_view(tw)
		await tool.frames(12)
		var tp := _page_with_margin(tw)
		ok(tp >= 0, "TWIS tiene la nota al margen")
		if tp >= 0:
			for _k in tp:
				await _key(KEY_RIGHT)
				await tool.frames(3)
			ok(reader.page_idx == tp, "→ llega a la hoja de #james")
			var mi2 := _margin_block(reader.page)
			var mr2: RichTextLabel = reader.block_rtl(mi2)
			var ny := (mr2.get_global_transform_with_canvas() * Vector2(0, 0)).y
			var ty := vp.get_visible_rect().size.y * 0.45
			if ny > ty:
				await _pan(Vector2(800, 700), Vector2(800, 700 - (ny - ty)))
			await tool.frames(8)
			_check_margin(mi2)
			await tool.snap("twis_margen")
	# ---------------- papeles de siempre en el lector flotante (sin v3): el Times y el Journal de Genève
	for ref in ["D15.0331@L1", "D05@BM"]:
		var v: Dictionary = WorldModel.view_any(sim.st, repo, ref)
		if v.is_empty():
			continue
		reader.open_view(v)
		await tool.frames(12)
		ok(not reader.page.margin_col and reader.page.ficha_rtl == null, "%s: sin columnas v3" % ref)
		_check_page(ref, 0)
		await tool.snap(ref.replace("@", "_").replace(".", "_").to_lower())
	_end()

func _room(scene: Node) -> void:
	var pl: Dictionary = repo.place("L1")
	var nodes: Array = []
	for nd in pl.get("nodes", []):
		if String(nd.get("area", "*")) != "tienda":
			nodes.append(String(nd.id))
	var snap := {"id": "PL.L1.v3lector", "place": "L1", "area": "buhardilla", "day": 1, "slot": "M", "variant": "",
		"nodes": nodes, "chars": [], "silhouettes": [], "frame": "escritorio"}
	var d: Node3D = DB.build(pl, snap)
	scene.add_child(d)
	var fr := {}
	for f in pl.get("frames", []):
		if String(f.get("id", "")) == "escritorio":
			fr = f
	var cam := Camera3D.new()
	scene.add_child(cam)
	var pos: Array = fr.get("pos", [0.9, 1.62, 0.1])
	var look: Array = fr.get("look", [-0.16, 0.92, -1.9])
	cam.global_position = Vector3(pos[0], pos[1], pos[2])
	cam.look_at(Vector3(look[0], look[1], look[2]), Vector3.UP)
	cam.fov = float(fr.get("fov", 56))
	cam.current = true
	var post = EP.attach(cam)
	if post != null and post.has_method("set_slot"):
		post.set_slot("M")

func _end() -> void:
	print("V3LECTOR OK" if fails == 0 else "V3LECTOR FALLA %d" % fails)

# ------------------------------------------------------------------ chequeos
func _check_page(tag: String, i: int) -> void:
	var pg = reader.page
	var vps: Vector2 = vp.get_visible_rect().size
	ok(pg != null, "%s hoja %d armada" % [tag, i + 1])
	if pg == null:
		return
	# el texto nunca está rotado y es el de la vista
	for j in pg.blocks.size():
		var r: RichTextLabel = pg.blocks[j]
		ok(absf(r.get_global_transform_with_canvas().get_rotation()) < 1e-4, "%s h%d b%d sin rotar" % [tag, i + 1, j])
		ok(r.get_parsed_text() == String(pg.parsed[j].get("plain", "")), "%s h%d b%d: texto == plain" % [tag, i + 1, j])
	# ficha sólo en la primera hoja, arriba del texto y fuera de los bloques (no se recorta)
	if i == 0 and reader.view.get("ficha") != null:
		ok(pg.ficha_rtl != null, "ficha en la hoja 1")
		if pg.ficha_rtl != null:
			ok(not pg.blocks.has(pg.ficha_rtl), "la ficha no es un bloque recortable")
			ok(pg.ficha_rtl.position.y + pg.ficha_rtl.size.y <= (pg.blocks[0] as Control).position.y, "la ficha va arriba del texto")
			ok(not pg.ficha_rtl.selection_enabled, "la ficha no se selecciona")
	elif i > 0:
		ok(pg.ficha_rtl == null, "sin ficha en la hoja %d" % (i + 1))
	# la paginación abajo al centro, la tijera arriba a la derecha y afuera del papel
	if reader.page_count() > 1:
		var pr: Rect2 = reader.pager_rect()
		ok(absf(pr.get_center().x - vps.x * 0.5) < 2.0, "paginación centrada (x=%.0f)" % pr.get_center().x)
		ok(pr.position.y > vps.y - 90.0, "paginación abajo (y=%.0f)" % pr.position.y)
	# GDD_v3 §10: la tijera va anclada a la esquina de arriba a la derecha DEL PAPEL, apenas afuera, sin salir de la pantalla
	var sr: Rect2 = reader.scissors_rect()
	if sr.size.x > 0.0:
		var ppr: Rect2 = reader.paper_rect()
		ok((sr.position.x >= ppr.end.x - 1.0 and sr.position.x - ppr.end.x <= 16.0) or sr.end.x >= vps.x - 10.0,
			"tijera junto al borde derecho del papel (%s, papel %s)" % [sr, ppr])
		ok(absf(sr.position.y - maxf(ppr.position.y, 16.0)) <= 2.0, "tijera a la altura del borde de arriba del papel (%s)" % sr)
		ok(sr.end.x <= vps.x and sr.position.y >= 0.0, "tijera dentro de la pantalla")
		ok(not ppr.intersects(sr), "tijera afuera del papel")

func _check_margin(mi: int) -> void:
	var pg = reader.page
	ok(mi >= 0, "hay bloque de margen")
	if mi < 0:
		return
	var r: RichTextLabel = pg.blocks[mi]
	var cr: Rect2 = pg.content_rect_px()
	ok(r.position.x >= cr.end.x + PageView.NOTE_GAP_MM * pg.px_per_mm - 0.5, "la nota va en el margen, separada del cuerpo")
	var a: Dictionary = pg.anchors[mi]
	var b: RichTextLabel = pg.blocks[int(a.get("block", 0))]
	var rg: Vector2i = PageView.tramo_range(pg.parsed[int(a.get("block", 0))], String(a.get("tramo", "")))
	if rg.x >= 0:
		var ly := b.position.y + float(b.get_line_offset(b.get_character_line(rg.x)))
		ok(absf(r.position.y - ly) < 2.0 or r.position.y > ly, "la nota a la altura de su tramo (nota %.0f, tramo %.0f)" % [r.position.y, ly])
	ok(r.get_theme_font_size("normal_font_size") < (b.get_theme_font_size("normal_font_size")), "la nota en letra más chica")
	if not pg.marks.is_empty():
		var rects: Array = pg.mark_rects()
		ok(not rects.is_empty(), "marquitas dibujadas")
		for mr in rects:
			ok((mr.rect as Rect2).end.x <= cr.position.x, "marquita en la columna izquierda")

func _page_with_margin(v: Dictionary) -> int:
	var pages: Array = v.get("pages", [])
	for i in pages.size():
		for b in pages[i]:
			if String(b.get("slot", "")) == "margen":
				return i
	return -1

func _margin_block(pg) -> int:
	for j in pg.slots.size():
		if pg.slots[j] == "margen":
			return j
	return -1

func _first_words(r: RichTextLabel, n: int) -> String:
	var words := r.get_parsed_text().strip_edges().split(" ", false)
	var out: Array = []
	for w in words:
		out.append(w)
		if out.size() >= n:
			break
	return " ".join(PackedStringArray(out)).rstrip(".,;:")

# Origen del último recorte ACEPTADO (un intento rechazado, p. ej. «cruza_oracion», no cuenta).
func _last_clip_origin() -> String:
	for k in range(acts.size() - 1, -1, -1):
		if String(acts[k].get("t", "")) == "clip_text" and bool(acts[k].get("_ok", false)):
			return String(acts[k].get("_origin", ""))
	return ""

# ------------------------------------------------------------------ vistas
func _view_v3(ref: String) -> Dictionary:
	var v: Dictionary = WorldModel.view_any(sim.st, repo, ref)
	if v.is_empty() or (v.get("ficha") != null and not (v.get("marks", []) as Array).is_empty()):
		return v
	var sp: Dictionary = SPEC.get(ref, {})
	if sp.is_empty():
		return v
	synthetic[ref] = true
	v["ficha"] = sp.ficha
	var pages: Array = v.pages
	var marks: Array = []
	var page_of := {}
	for pi in pages.size():
		for t in pages[pi][0].get("parsed", {}).get("tramos", []):
			page_of[String(t.get("id", ""))] = pi
	for tid in sp.marcas:
		if page_of.has(tid):
			marks.append({"page": page_of[tid], "block": 0, "tramo": tid})
	v["marks"] = marks
	for m in sp.margen:
		if not page_of.has(m[2]):
			continue
		var seg := WorldModel.tramo_markup(repo, m[0], m[1])
		if seg == "":
			continue
		pages[page_of[m[2]]].append({"doc": m[0], "origin": m[0], "copy": m[0] + "@tomo", "part": m[1], "parsed": repo.parse_text(seg),
			"slot": "margen", "hand": "lapiz", "anchor": {"block": 0, "tramo": m[2]}})
	var nc: Dictionary = repo.doc(sp.nc)
	var card: Array = []
	if not nc.is_empty():
		for p in nc.get("parts", []):
			card.append({"doc": sp.nc, "origin": sp.nc, "copy": sp.nc + "@tomo", "part": String(p.id), "parsed": repo.parsed(sp.nc, String(p.id)),
				"slot": "tarjeta", "hand": "mano_harris"})
	else:
		card.append({"doc": sp.nc, "origin": sp.nc, "copy": sp.nc + "@tomo", "part": "p1", "parsed": repo.parse_text(sp.nota),
			"slot": "tarjeta", "hand": "mano_harris"})
	pages.append(card)
	return v

# act: con datos v3 reales, el sim; con vistas sintéticas, el bloque de la vista del lector da el origen (como el sim).
func _act(a: Dictionary) -> Dictionary:
	if String(a.get("t", "")) == "read":
		return {"ok": true}
	var rec := a.duplicate(true)
	acts.append(rec)
	if String(a.get("t", "")) != "clip_text":
		return {"ok": false, "err": "desconocido"}
	var blk: Dictionary = reader.view.pages[int(a.src.part)][int(a.src.block)]
	rec["_origin"] = String(blk.get("origin", ""))
	if not reader.view.get("_sintetico", false) and not synthetic.get(String(a.src.ref), false):
		var res: Dictionary = sim.apply(a)
		rec["_ok"] = bool(res.get("ok", false))
		if bool(res.get("ok", false)) and res.has("clip"):
			var c: Dictionary = sim.q_clip(String(res.clip))
			rec["_origin"] = String(c.get("origin", rec["_origin"]))
		print("V3LECTOR recorte %s: %s" % ["aceptado" if rec["_ok"] else "rechazado (%s)" % res.get("err", ""), rec["_origin"]])
		return res
	var pv := SelectionMapper.preview(blk.parsed, int(a.from), int(a.len))
	rec["_ok"] = bool(pv.ok)
	if not pv.ok:
		return {"ok": false, "err": pv.err}
	return {"ok": true, "clip": "V3L%d" % acts.size(), "text": pv.text}

# ------------------------------------------------------------------ mouse y teclado reales (como w3int_flow: warp + evento)
var _last := Vector2.ZERO
func _mm(pos: Vector2, mask := 0) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = pos - _last
	e.button_mask = mask
	_last = pos
	Input.parse_input_event(e)

# Espera a que el cursor de verdad llegue (con ventana, warp_mouse tarda un cuadro o dos).
var cursor_ok := true   # false si alguna vez el cursor del sistema no obedeció a warp_mouse (pantalla bloqueada, mouse en uso)
func _sync(pos: Vector2, mask := 0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 6:
		_mm(pos, mask)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(pos) < 1.5:
			return
	cursor_ok = false
	print("V3LECTOR aviso: el cursor no llegó a %s (está en %s)" % [pos, vp.get_mouse_position()])

func _mb(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	var m := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_MIDDLE)
	e.button_mask = m if pressed else 0
	Input.parse_input_event(e)

func _click(pos: Vector2) -> void:
	_mm(pos)
	await tool.frames(2)
	await _sync(pos)
	_mb(pos, true)
	await tool.frames(1)
	_mb(pos, false)
	await tool.frames(3)

func _right_click(pos: Vector2) -> void:
	_mm(pos)
	await tool.frames(2)
	await _sync(pos)
	_mb(pos, true, MOUSE_BUTTON_RIGHT)
	await tool.frames(1)
	_mb(pos, false, MOUSE_BUTTON_RIGHT)
	await tool.frames(3)

func _wheel(pos: Vector2, button: MouseButton) -> void:
	_mm(pos)
	await tool.frames(1)
	await _sync(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.ctrl_pressed = true   # playtest v3: la rueda sola desplaza; Ctrl + rueda acerca
		e.factor = 1.0
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
	await tool.frames(2)

func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await tool.frames(1)

func _pan(from: Vector2, to: Vector2) -> void:
	var y0: float = reader._stage.position.y
	_mm(from)
	await tool.frames(2)
	await _sync(from)
	_mb(from, true)
	await tool.frames(2)
	for i in range(1, 21):
		_mm(from.lerp(to, float(i) / 20.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	await _sync(to, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(2)
	_mb(to, false)
	await tool.frames(3)
	print("V3LECTOR arrastre del papel: y %.0f -> %.0f" % [y0, reader._stage.position.y])
	ok(absf(reader._stage.position.y - y0) > 20.0, "arrastrar el papel lo desplaza")

var _drag_end := Vector2.ZERO
var _drag_rtl: RichTextLabel = null
# Arrastre de la tijera. Con ventana, RichTextLabel estira la selección cada 50 ms hasta donde está el cursor del sistema
# (que el usuario puede estar moviendo): el último movimiento y el soltar van en el mismo cuadro, así manda el evento.
func _drag(r: RichTextLabel, text: String, hold := false) -> void:
	var plain := r.get_parsed_text()
	var from := plain.find(text)
	ok(from >= 0, "el bloque contiene «%s»" % text)
	if from < 0:
		return
	var pts := SelectionMapper.drag_points(r, from, from + text.length())
	_drag_end = pts[1]
	_drag_rtl = r
	# hasta 3 intentos: si el cursor del sistema se mueve (el usuario usa la PC), la selección puede quedar vacía
	for attempt in 3:
		_mm(pts[0])
		await tool.frames(2)
		await _sync(pts[0])
		_mm(pts[0])
		_mb(pts[0], true)
		await tool.frames(1)
		for i in range(1, 13):
			_mm(pts[0].lerp(pts[1], float(i) / 12.0), MOUSE_BUTTON_MASK_LEFT)
			if i < 12:
				await tool.frames(1)
		var sel := r.get_selected_text()
		print("V3LECTOR seleccionado (intento %d): «%s»" % [attempt + 1, sel])
		if hold and sel != "":
			await tool.frames(1)
			_mm(pts[1], MOUSE_BUTTON_MASK_LEFT)
			return
		var n0 := acts.size()
		_mb(pts[1], false)
		await tool.frames(4)
		if hold:
			continue
		if acts.size() > n0 and bool(acts[-1].get("_ok", false)):
			return

func _release() -> void:
	_mm(_drag_end, MOUSE_BUTTON_MASK_LEFT)
	_mb(_drag_end, false)
	await tool.frames(4)

# Recorte ampliado de la pantalla (para mirar el ícono de la tijera de cerca).
func _crop(name: String, r: Rect2i, k: int) -> void:
	await tool.process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var c := img.get_region(r)
	c.resize(r.size.x * k, r.size.y * k, Image.INTERPOLATE_NEAREST)
	var p: String = tool.out_dir.path_join("v3lector_%s.png" % name)
	c.save_png(p)
	print("SNAP ", p)

# Con ventana, RichTextLabel arma la selección con el cursor del sistema: si el cursor no obedece (el usuario está usando
# el mouse o la pantalla está bloqueada) y el recorte no salió, es un aviso del entorno, no una falla del lector (la
# lógica la prueba test_u_reader_v3 sin ventana).
func _clip_ok(cond: bool, what: String) -> void:
	if cond:
		return
	if not cursor_ok:
		print("V3LECTOR AVISO (entorno): ", what, " — el cursor del sistema no obedeció; ver test_u_reader_v3")
		return
	ok(false, what)
