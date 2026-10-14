# T34 (UI-MUNDO, GDD_v3 §6.5) — con ventana:
#  - calibración del quad (world/affordance/affordance.gdshader, compila): bajo el mouse el realce es SÓLO un contorno
#    blanco POR FUERA de la máscara del objeto (los píxeles que cambian son casi blancos y quedan fuera); sin realce, con
#    o sin cosas usables, la captura es la del material original (ningún contorno permanente);
#  - sólo el borde de afuera: lo que TAPA al objeto bajo el mouse (el farol delante de la fachada) no se contornea;
#  - con el juego real (SIN --fast) y el mouse real: sobre el tintero, contorno blanco y mano; sobre la ventana,
#    contorno blanco y lupa; sobre la cama (decoración, no es un nodo), nada: ni contorno ni cursor especial.
# Correr SIN --headless:  ./godot.sh -s tests/run_tests.gd -- --window t34
extends "res://tests/fixtures/v2cam/window_base.gd"

const WINDOW := true
const TIMEOUT_S := 240.0

const WR = preload("res://world/world_root.gd")
const AFF = preload("res://world/affordance/affordance.gd")

var _wr = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		_wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null
	super.after_each()

func _cap() -> Image:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()

static func _diff_mask(a: Image, b: Image, thr := 0.08) -> Array:
	var out: Array = []
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > thr:
				out.append(Vector2i(x, y))
	return out

func _visible_point(wr, nid: String) -> Vector2:
	var b: Node3D = wr.node_body(nid)
	if b == null: return Vector2(-1, -1)
	var cam: Camera3D = wr.camera()
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 140, 6):
		for k in 16:
			var q := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if str(wr.pick(q).get("id", "")) == nid: return q
			if r == 0: break
	return Vector2(-1, -1)

func test_white_outline_only_on_hover() -> void:
	if DisplayServer.get_name() == "headless":
		skip("requiere ventana"); return
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("escritorio", "M")
	for _i in 8: await tree.process_frame
	var ap = _wr.aff_post()
	ok(ap != null and ap.mat.shader != null, "quad de afordancias con su shader")
	# GDD_v2 §D.4: la aguada lava menos y lleva más pluma en lo examinable (todo, por igual); para comparar SÓLO el
	# material, el ajuste del look se apaga un momento
	var post = _wr.engraving_post()
	var tweak: bool = post != null and post.has_method("set_param")
	if tweak:
		post.set_param("obj_soften", 1.0)
		post.set_param("obj_line", 1.0)
		for _i in 2: await tree.process_frame
	var base := await _cap()
	# código 1 contra el material original: el código no cambia el dibujo
	var owners: Dictionary = AFF.owners(_wr.diorama)
	for gi in owners.get("n:cuaderno", []):
		(gi as GeometryInstance3D).material_override = (gi as GeometryInstance3D).get_meta("aff_orig")
	var orig := await _cap()
	AFF.apply(_wr.diorama, {}, "")
	var d0 := _diff_mask(base, orig, 0.06)
	ok(d0.size() < 40, "código 1 ≈ material original (%d píxeles distintos)" % d0.size())
	# lo usable no dibuja nada (v3: sin filete rojo permanente)
	_wr.set_usable({"n:cuaderno": true, "n:tintero": true, "n:expediente": true, "n:bandeja": true}, {})
	var use := await _cap()
	var du := _diff_mask(base, use, 0.06)
	ok(du.size() < 40, "lo usable sin realce: sin contorno permanente (%d píxeles)" % du.size())
	# bajo el mouse: contorno blanco por fuera de la máscara
	var p := _visible_point(_wr, "cuaderno")
	ok(p.x >= 0.0, "el cuaderno se ve")
	_wr.hover_at(p)
	var hov := await _cap()
	ap.set_param("debug_view", 1)
	var mask := await _cap()
	ap.set_param("debug_view", 0)
	var d1 := _diff_mask(base, hov)
	var outside := 0
	var white := 0
	for q in d1:
		if mask.get_pixel(q.x, q.y).r < 0.9:
			outside += 1
			var c := hov.get_pixel(q.x, q.y)
			if c.r > 0.82 and c.g > 0.82 and c.b > 0.82:
				white += 1
	ok(d1.size() > 60, "el realce bajo el mouse se ve (%d píxeles)" % d1.size())
	ok(outside >= d1.size() * 0.9, "todo por fuera de la máscara: nada adentro (%d de %d)" % [outside, d1.size()])
	ok(white >= outside * 0.8, "y blanco (%d de %d casi blancos)" % [white, outside])
	_wr.hover_at(Vector2(-20, -20))
	var back := await _cap()
	ok(_diff_mask(base, back).size() < 40, "al salir, nada queda marcado")

# Verificador v3: el contorno es el borde de AFUERA del objeto bajo el mouse. Lo que lo tapa (el farol delante de la
# fachada de enfrente: decoración, §6.4) no se contornea. Con la tolerancia de profundidad desactivada (como antes) el
# farol sí quedaba marcado: así la prueba se valida sola.
func test_outline_skips_what_covers_the_hovered() -> void:
	if DisplayServer.get_name() == "headless":
		skip("requiere ventana"); return
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("ventana", "M")
	for _i in 8: await tree.process_frame
	var ap = _wr.aff_post()
	var farol: Node3D = _wr.diorama.get_node_or_null("Props/farol")
	ok(farol != null, "el farol de enfrente (decoración)")
	if farol == null: return
	var cam: Camera3D = _wr.camera()
	var head := cam.unproject_position(farol.global_position + Vector3(0, 3.0, 0))
	var foot := cam.unproject_position(farol.global_position + Vector3(0, 1.2, 0))
	var box := Rect2(Vector2(minf(head.x, foot.x) - 30.0, head.y - 30.0), Vector2(absf(head.x - foot.x) + 60.0, absf(foot.y - head.y) + 30.0))
	ok(Rect2(0, 0, 1600, 900).encloses(box), "el farol a la vista: %s" % str(box))
	# la fachada bajo el mouse, lejos del farol
	var p := Vector2(-1, -1)
	for y in range(150, 500, 20):
		for x in range(900, 1400, 20):
			if p.x < 0.0 and str(_wr.pick(Vector2(x, y)).get("id", "")) == "enfrente":
				p = Vector2(x, y)
	ok(p.x >= 0.0, "la fachada de enfrente bajo el mouse")
	if p.x < 0.0: return
	_wr.hover_at(Vector2(-20, -20))
	var base := await _cap()
	var count := func(img: Image) -> int:
		var n := 0
		for q in _diff_mask(base, img):
			if box.has_point(Vector2(q)): n += 1
		return n
	_wr.hover_at(p)
	eq(_wr.hover_id, "enfrente", "bajo el mouse: la fachada")
	var hov := await _cap()
	var tol0 = ap.param("occl_tol")
	ap.set_param("occl_tol", 1.0e6)
	var old := await _cap()
	ap.set_param("occl_tol", tol0)
	var n_old: int = count.call(old)
	var n_new: int = count.call(hov)
	ok(n_old > 20, "sin la tolerancia de profundidad, el farol quedaba contorneado (%d píxeles)" % n_old)
	ok(n_new <= maxi(4, n_old / 10), "con ella, el farol no se marca (%d píxeles; antes %d)" % [n_new, n_old])

# ¿Alguna malla codificada del dueño lleva el código? (lo transparente no se codifica: queda como era)
func _coded(w, key: String, code: int) -> bool:
	for gi in AFF.owners(w.diorama).get(key, []):
		var g3 := gi as GeometryInstance3D
		if g3.material_override != g3.get_meta("aff_orig", null) and AFF.code_of(g3) == code:
			return true
	return false

# Un punto de la pantalla, fuera de las bandas del borde, donde el clic da con el nodo (rejilla de 20 px).
func _safe_point(wr, nid: String) -> Vector2:
	for y in range(110, 790, 20):
		for x in range(150, 1450, 20):
			if str(wr.pick(Vector2(x, y)).get("id", "")) == nid:
				return Vector2(x, y)
	return Vector2(-1, -1)

func test_cursor_and_outline_with_real_mouse() -> void:
	if not await _boot_day1(): return
	var w = sh.world
	await _focus()
	# el tintero: se usa (mano)
	var pt := _safe_point(w, "tintero")
	ok(pt.x >= 0.0, "el tintero a la vista")
	await _move(pt)
	await _wait(0.4)
	eq(w.hover_id, "tintero", "bajo el mouse: el tintero")
	eq(Input.get_current_cursor_shape(), Input.CURSOR_POINTING_HAND, "mano sobre lo que se usa")
	ok(_coded(w, "n:tintero", 3), "el tintero lleva el contorno")
	# la ventana: se mira (lupa)
	var pv := _safe_point(w, "ventana")
	ok(pv.x >= 0.0, "la ventana a la vista")
	await _move(pv)
	await _wait(0.4)
	eq(w.hover_id, "ventana", "bajo el mouse: la ventana (%s, %s)" % [str(pv), str(w.edge_debug())])
	eq(Input.get_current_cursor_shape(), Input.CURSOR_HELP, "lupa sobre lo que se mira")
	ok(_coded(w, "n:ventana", 3), "la ventana lleva el contorno")
	no(_coded(w, "n:tintero", 3), "el tintero ya no")
	# la cama (decoración): girar hasta verla y pasar el mouse por encima
	var bed: Node3D = w.diorama.get_node_or_null("Props/cama")
	ok(bed != null, "la cama existe como decoración")
	if bed != null:
		var cam: Camera3D = w.camera()
		var pb := Vector2(-1, -1)
		for yy in range(180, 340, 5):
			w.rig.yaw_t = float(yy); w.rig.yaw_off = float(yy); w.rig._apply()
			var q := bed.global_position + Vector3(0, 0.45, 0)
			if cam.is_position_behind(q): continue
			var sp := cam.unproject_position(q)
			if Rect2(200, 150, 1200, 600).has_point(sp):
				pb = sp
				break
		await _wait(0.3)
		ok(pb.x >= 0.0, "la cama en pantalla: %s" % str(pb))
		await _move(pb)
		await _wait(0.4)
		eq(w.hover_kind, "none", "sobre la cama: nada (%s)" % w.hover_id)
		eq(Input.get_current_cursor_shape(), Input.CURSOR_ARROW, "ni cursor especial")
		var any3 := false
		for k in AFF.owners(w.diorama):
			for gi in AFF.owners(w.diorama)[k]:
				if (gi as GeometryInstance3D).material_override != (gi as GeometryInstance3D).get_meta("aff_orig", null) and AFF.code_of(gi) == 3:
					any3 = true
		no(any3, "ningún contorno")
