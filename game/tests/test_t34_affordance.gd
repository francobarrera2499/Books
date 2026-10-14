# T34 (UI-MUNDO, GDD_v3 §6.5) — afordancias sin pantalla:
#  - todo nodo con prop recibe el código 1 (examinable) en alguna malla (todos los lugares, láminas y la buhardilla);
#  - los códigos sólo cambian la rugosidad (el resto del material es idéntico: la captura no cambia por el código);
#  - NINGÚN contorno permanente: lo usable no cambia el código (sólo el cursor); bajo el mouse, código 3 (el quad dibuja
#    un contorno blanco) y se deshace al salir; cursor de mano si se usa, de lupa si se mira;
#  - el shader sólo dibuja el contorno blanco (#ffffff, α 0,9, 2 px a 900 p): sin filete rojo ni «mirar alrededor»;
#  - lo usable sale SÓLO de un vínculo de data/map.json con su bandera (q_ui), las salidas y los personajes en primer plano;
#    ninguna silueta es usable (aunque se le pueda hablar: mano);
#  - de la v2 no queda la etiqueta flotante, el rectángulo de tijera sobre el 3D, ni las teclas M, L y Espacio; las cintas
#    del HUD («Cuaderno», «Expediente») sólo fuera de la buhardilla.
# La parte con ventana (calibración del quad, cursor con el mouse real) está en test_t34_affordance_window.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const WR = preload("res://world/world_root.gd")
const AFF = preload("res://world/affordance/affordance.gd")
const Shell = preload("res://ui/shell.gd")
const Objects = preload("res://ui/desk/objects.gd")
const Bot = preload("res://devtools/bots/bot_deductor.gd")

const USABLE_DO := ["tray", "map", "notebook", "dossier", "scissors", "calendar", "compose", "sleep", "catalog", "go", "leave", "docs"]

var _wr = null
var sh = null
var g = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		_wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null
	if g != null and g.sim != null:
		g.end_session()
	if sh != null and is_instance_valid(sh):
		sh.free()
	sh = null
	if g != null:
		g.save_path = g.SAVE_PATH

func _full_snap(place: Dictionary, area: String) -> Dictionary:
	var ids: Array = []
	for n in place.get("nodes", []):
		var a := str(n.get("area", "*"))
		if a == "*" or area == "*" or a == area: ids.append(str(n.id))
	var chars: Array = []
	for c in place.get("characters", []):
		var a2 := str(c.get("area", "*"))
		if a2 == "*" or area == "*" or a2 == area: chars.append({"id": str(c.id), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sils: Array = (place.get("silhouettes", {}) as Dictionary).keys() if place.get("silhouettes", {}) is Dictionary else []
	return {"id": "PL.%s.3.M" % place.get("id", ""), "place": place.get("id", ""), "area": area, "day": 3, "slot": "M", "variant": "",
		"nodes": ids, "chars": chars, "silhouettes": sils}

func _world(place: Dictionary, area: String):
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_plate(_full_snap(place, area), place)
	await tree.physics_frame
	await tree.physics_frame
	return _wr

func _all_places() -> Dictionary:
	var r = repo()
	var all := {}
	for k in r.places(): all[k] = r.places()[k]
	for k in r.plates(): all[k] = r.plates()[k]
	return all

# Códigos puestos por las afordancias (sólo materiales codificados: lo transparente o sin BaseMaterial queda como era).
func _codes(root: Node3D) -> Dictionary:
	var out := {}
	var owners: Dictionary = AFF.owners(root)
	for k in owners:
		for gi in owners[k]:
			if not is_instance_valid(gi): continue
			var g3 := gi as GeometryInstance3D
			if g3.material_override == g3.get_meta("aff_orig", null): continue
			out[AFF.code_of(g3)] = true
	return out

func test_every_node_with_prop_gets_a_code() -> void:
	var all := _all_places()
	var bad: Array = []
	var keys: Array = all.keys()
	keys.sort()
	for pid in keys:
		var pl: Dictionary = all[pid]
		var areas: Array = (pl.get("areas", {}) as Dictionary).keys() if pl.get("areas", {}) is Dictionary else []
		if areas.is_empty(): areas = ["*"]
		for area in areas:
			var wr = await _world(pl, str(area))
			var owners: Dictionary = AFF.owners(wr.diorama)
			var props: Node = wr.diorama.get_node("Props")
			for nid in wr.diorama.get_meta("nodes_index"):
				var b: Node3D = wr.node_body(nid)
				var prop := str(b.get_meta("prop", ""))
				if prop == "" or (props.get_node_or_null(NodePath(prop.replace(".", "_"))) == null and not (wr.diorama.get_meta("chars_index") as Dictionary).has(prop)):
					continue
				var lst: Array = owners.get("n:" + str(nid), [])
				# un nodo que es parte de un personaje (las manos del librero, Harris en la lámina) se realza como el personaje
				if (wr.diorama.get_meta("chars_index") as Dictionary).has(prop) and lst.is_empty():
					lst = owners.get("c:" + prop, [])
				var coded := false
				for gi in lst:
					if AFF.code_of(gi) == 1:
						coded = true
				if not coded and not _only_shared(wr, b, prop):
					bad.append("%s.%s:%s" % [pid, area, nid])
			eq(_codes(wr.diorama).keys().filter(func(c): return int(c) != 1 and int(c) != 0), [], "%s.%s: sin realce armado el diorama" % [pid, area])
			after_each()
	eq(bad, [], "nodos con prop sin código")

# Sin malla propia sólo se admite si todas las mallas de su prop que tocan su ancla son de otro dueño o son
# «arquitectura» compartida (> ARCH_RATIO × el volumen del ancla): ese nodo cambia el cursor pero no se contornea.
func _only_shared(wr, b: Node3D, prop: String) -> bool:
	var src: Node = wr.diorama.get_node("Props").get_node_or_null(NodePath(prop.replace(".", "_")))
	if src == null: return true
	var s: Vector3 = b.get_meta("size", Vector3(0.2, 0.2, 0.2))
	var box := AABB(b.global_position - s * 0.5, s).grow(AFF.GROW)
	var owned := {}
	for k in AFF.owners(wr.diorama):
		for gi in AFF.owners(wr.diorama)[k]: owned[gi] = true
	for gi in src.find_children("*", "GeometryInstance3D", true, false):
		var a: AABB = (gi as GeometryInstance3D).global_transform * (gi as GeometryInstance3D).get_aabb()
		if not a.intersects(box): continue
		if owned.has(gi): continue
		if a.get_volume() > maxf(box.get_volume(), 1e-6) * AFF.ARCH_RATIO: continue
		return false
	return true

func test_codes_only_change_roughness() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("5a4632")
	m.roughness = 1.0
	m.metallic_specular = 0.25
	for code in [1, 3]:
		for vid in range(AFF.IDS):
			var d: BaseMaterial3D = AFF.coded_mat(m, code, vid)
			ok(d != m, "material duplicado")
			eq(AFF.code_of_rough(d.roughness), code, "código %d decodificable (variante %d, r=%.3f)" % [code, vid, d.roughness])
			eq(d.albedo_color, m.albedo_color, "mismo color")
			eq(d.metallic_specular, m.metallic_specular, "mismo especular")
			eq(d.diffuse_mode, m.diffuse_mode, "mismo modo difuso")
			eq(d.shading_mode, m.shading_mode, "mismo sombreado")
	eq(AFF.code_of_rough(1.0), 0, "escenario")
	ok(AFF.coded_mat(m, 0) == m, "código 0: el material original")
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ok(AFF.coded_mat(glass, 3) == glass, "lo transparente no se codifica (no escribe el buffer)")

func test_hover_only_and_cursors() -> void:
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("escritorio", "M")
	await tree.physics_frame
	await tree.physics_frame
	var wr = _wr
	wr.set_usable({"n:cuaderno": true, "n:tintero": true}, {})
	var owners: Dictionary = AFF.owners(wr.diorama)
	var cu: Array = owners.get("n:cuaderno", [])
	var ve: Array = owners.get("n:ventana", [])
	ok(not cu.is_empty() and not ve.is_empty(), "mallas del cuaderno y de la ventana")
	eq(_codes(wr.diorama).keys().filter(func(c): return int(c) >= 2), [], "lo usable no se marca: ningún contorno permanente")
	var p := _visible_point(wr, "cuaderno")
	ok(p.x >= 0.0, "el cuaderno se ve desde el escritorio")
	var hit: Dictionary = wr.hover_at(p)
	eq(str(hit.get("id", "")), "cuaderno", "bajo el mouse: el cuaderno")
	eq(AFF.code_of(cu[0]), 3, "cuaderno bajo el mouse: 3 (contorno)")
	eq(AFF.code_of(ve[0]), 1, "lo demás sigue en 1")
	eq(wr.cursor_for("node", "cuaderno"), Input.CURSOR_POINTING_HAND, "mano sobre lo que se usa")
	eq(wr.cursor_for("node", "ventana"), Input.CURSOR_HELP, "lupa sobre lo que se mira")
	eq(wr.cursor_for("none", ""), Input.CURSOR_ARROW, "flecha sobre nada")
	wr.hover_at(Vector2(-50, -50))
	eq(AFF.code_of(cu[0]), 1, "al salir, el cuaderno vuelve a 1")
	eq(_codes(wr.diorama).keys().filter(func(c): return int(c) >= 2), [], "nada queda marcado")

func _visible_point(wr, nid: String) -> Vector2:
	var b: Node3D = wr.node_body(nid)
	if b == null: return Vector2(-1, -1)
	var cam: Camera3D = wr.camera()
	var c := cam.unproject_position(b.global_position)
	for r in range(0, 120, 6):
		for k in 16:
			var q := c + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if str(wr.pick(q).get("id", "")) == nid: return q
			if r == 0: break
	return Vector2(-1, -1)

func test_shader_is_only_a_white_outline() -> void:
	var txt := FileAccess.get_file_as_string("res://world/affordance/affordance.gdshader")
	ok(txt.contains("uniform vec4 outline_col : source_color = vec4(1.0, 1.0, 1.0, 1.0)"), "contorno blanco")
	ok(txt.contains("uniform float outline_px = 2.0"), "2 px a 900 p")
	ok(txt.contains("uniform float outline_a = 0.9"), "α 0,9")
	for gone in ["usable_col", "reveal_all", "hover_fill", "halo"]:
		no(txt.contains(gone), "sin «%s» (v2)" % gone)
	var sh_res: Shader = load("res://world/affordance/affordance.gdshader")
	ok(sh_res != null, "el shader carga")

func test_desk_items_pickable_from_the_desk_point() -> void:
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("general", "M")
	await tree.physics_frame
	await tree.physics_frame
	eq(_wr.rig.cur, "escritorio", "se entra mirando el escritorio")
	for nid in ["cuaderno", "tintero", "expediente", "bandeja"]:
		ok(_visible_point(_wr, nid).x >= 0.0, "«%s» se toca desde el escritorio" % nid)

func test_v2_affordances_are_gone() -> void:
	for f in ["res://ui/desk/hover_label.gd", "res://ui/desk/scissors3d.gd"]:
		no(FileAccess.file_exists(f), "no existe %s" % f)
	for a in ["fe_mapa", "fe_mirar", "fe_libro_mayor"]:
		no(InputMap.has_action(a), "sin la acción %s" % a)
	ok(InputMap.has_action("fe_expediente"), "E abre el expediente")
	var gs_txt := FileAccess.get_file_as_string("res://ui/desk/game_screen.gd")
	for gone in ["HoverLabel", "Scissors3D", "set_look_around", "_away_btn", "go_zone"]:
		no(gs_txt.contains(gone), "game_screen.gd sin %s" % gone)

# --- con la pantalla de juego (datos reales): lo usable sale de los vínculos y las banderas
func _boot() -> void:
	tree.root.size = Vector2i(1600, 900)
	g = tree.root.get_node("Game")
	sh = Shell.new()
	tree.root.add_child(sh)
	await tree.process_frame
	await sh.boot({"new": true, "seed": 1894, "fast": true, "mute": true, "save": tmp_dir().path_join("t34.jsonl")})
	await _settle()

func _settle(max_frames := 900) -> void:
	for i in max_frames:
		await tree.process_frame
		if i < 3: continue
		var gs = sh.game_screen
		if not sh.is_busy() and (gs == null or gs.idle()): return

func _to_day(day: int, phase := "desk") -> void:
	var bot = Bot.new()
	bot.setup(g.sim, 1)
	for _i in 600:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= day and String(c.phase) == phase: break
		if not bot.step(): break
	await _settle()
	sh.close_all()
	await _settle()

func _check_usable_rule(where: String) -> void:
	var gs = sh.game_screen
	var w = sh.world
	gs.refresh_affordances()
	var ph := String(g.sim.q_clock().phase)
	var f: Dictionary = gs.ui_flags()
	for k in w.usable:
		var key := String(k)
		if key.begins_with("c:"):
			ok((w.diorama.get_meta("chars_index") as Dictionary).has(key.substr(2)), "%s: %s es un personaje en primer plano" % [where, key])
			continue
		var nid := key.substr(2)
		no(nid.begins_with("sil_"), "%s: ninguna silueta es usable (%s)" % [where, nid])
		var b: Dictionary = Objects.binding(g.sim.repo, gs.cur_place, nid)
		# playtest v3 (Somerset House): en una visita, lo que ofrece un papel para leer o pedir también se usa (mano)
		if ph == "visit" and not USABLE_DO.has(String(b.get("do", ""))):
			ok(not Objects.docs_for(g.sim, g.sim.repo, gs._place_def(gs.cur_place), gs._node_def(nid), b).is_empty(), "%s: %s usable porque su tarjeta ofrece un papel" % [where, nid])
			continue
		ok(USABLE_DO.has(String(b.get("do", ""))), "%s: %s usable por un vínculo de map.json (%s)" % [where, nid, str(b)])
		ok(gs.binding_live(String(b.get("do", "")), ph, f), "%s: %s con su función viva" % [where, nid])
	for nid in w.diorama.get_meta("nodes_index"):
		var b2: Dictionary = Objects.binding(g.sim.repo, gs.cur_place, String(nid))
		if String(nid).begins_with("sil_"): continue
		if gs.binding_live(String(b2.get("do", "")), ph, f):
			ok(w.usable.has("n:" + String(nid)), "%s: %s (vínculo vivo) lleva la mano" % [where, nid])
	eq(_codes(w.diorama).keys().filter(func(c): return int(c) == 2), [], "%s: ningún contorno permanente" % where)

func test_usable_only_from_bindings_flags_exits_and_characters() -> void:
	await _boot()
	var gs = sh.game_screen
	eq(String(g.sim.q_clock().phase), "prologue", "prólogo")
	await _check_usable_rule("prólogo")
	await _to_day(1)
	eq([int(g.sim.q_clock().day), String(g.sim.q_clock().phase)], [1, "desk"], "día 1 en el escritorio")
	await _check_usable_rule("día 1")
	var f: Dictionary = gs.ui_flags()
	eq(sh.world.usable.has("n:mapa"), bool(f.get("desk.mapa", true)), "día 1: el plano de la pared con su bandera")
	eq(sh.world.usable.has("n:expediente"), bool(f.get("desk.expediente", true)), "día 1: el expediente")
	# en casa las cintas del HUD no están (Cuaderno y Expediente están sobre la mesa); Pendientes es interfaz
	no(bool(gs.hud.books_box.visible), "en la buhardilla no hay cintas en el HUD")
	eq(gs.hud.guide_box.mouse_filter, Control.MOUSE_FILTER_STOP, "Pendientes toma el mouse")
	# una visita: personajes en primer plano usables, siluetas no; las cintas aparecen
	var r: Dictionary = g.act({"t": "go", "place": "L4", "area": ""})
	if bool(r.get("ok", false)):
		await _settle()
		eq(sh.top_kind(), "scene", "visita: la banda de escena abierta")
		ok(sh.world.edge_enabled, "con la banda de escena los bordes giran")
		ok(bool(gs.hud.books_box.visible) == bool(f.get("hud.cuaderno", true) or f.get("desk.expediente", true)), "fuera de casa, las cintas")
		sh.open_panel("notebook")
		await _settle()
		no(sh.world.edge_enabled, "con el cuaderno abierto los bordes no giran")
		sh.close_all()
		await _settle()
		await _check_usable_rule("visita L4")
