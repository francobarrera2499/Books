# T34 (CÁMARA + AFORDANCIAS, GDD_v2 §D.5) — sin pantalla:
#  - todo nodo con prop recibe el código 1 o 2 en alguna malla (todos los lugares, láminas y la buhardilla);
#  - los códigos sólo cambian la rugosidad (el resto del material es idéntico: la captura no cambia por el código);
#  - lo usable (código 2) sale SÓLO de un vínculo de data/map.json con su bandera (q_ui), las salidas y los personajes en
#    primer plano; ninguna silueta recibe el código 2 (su presencia es evidencia), aunque se le pueda hablar (mano);
#  - el realce bajo el mouse (código 3) pisa al 2 y al 1 y se deshace; la etiqueta suma el verbo sólo a lo usable;
#  - el picker no se queda con el ancla gruesa de un nodo si el rayo no toca ninguna de sus mallas (la silla y el
#    escritorio de la buhardilla).
# La parte con ventana (calibración del quad, cursor y etiqueta con el mouse real) está en test_t34_affordance_window.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const WR = preload("res://world/world_root.gd")
const AFF = preload("res://world/affordance/affordance.gd")
const Shell = preload("res://ui/shell.gd")
const Objects = preload("res://ui/desk/objects.gd")
const Bot = preload("res://devtools/bots/bot_deductor.gd")

const USABLE_DO := ["tray", "map", "notebook", "ledger", "scissors", "calendar", "compose", "sleep", "catalog", "go", "leave"]

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
					var c: int = AFF.code_of(gi)
					if c == 1 or c == 2:
						coded = true
				if not coded and not _only_shared(wr, b, prop):
					bad.append("%s.%s:%s" % [pid, area, nid])
			after_each()
	eq(bad, [], "nodos con prop sin código")

# Sin malla propia sólo se admite si todas las mallas de su prop que tocan su ancla son de otro dueño o son
# «arquitectura» compartida (> ARCH_RATIO × el volumen del ancla: las mesas radiales de la Sala son un solo MultiMesh):
# ese nodo se nombra y cambia el cursor, pero no se contornea (como los de sólo ancla).
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
	for code in [1, 2, 3]:
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
	ok(AFF.coded_mat(glass, 2) == glass, "lo transparente no se codifica (no escribe el buffer)")
	# variantes separadas por ≥ 2 pasos de 8 bits y lejos de los umbrales
	for code in [1, 2]:
		for vid in range(AFF.IDS):
			var r := AFF.rough_for(code, vid)
			var lo := 0.94 if code == 1 else 0.90
			var hi := 0.98 if code == 1 else 0.94
			ok(r - lo >= 1.5 / 255.0 and hi - r >= 1.5 / 255.0, "variante %d del código %d lejos de los umbrales (%.4f)" % [vid, code, r])

func test_hover_overrides_and_restores() -> void:
	var r = repo()
	var wr = await _world(r.place("L1"), "buhardilla")
	wr.set_usable({"n:cuaderno": true}, {})
	var cu: Array = AFF.owners(wr.diorama)["n:cuaderno"]
	var si: Array = AFF.owners(wr.diorama)["n:silla"]
	ok(not cu.is_empty() and not si.is_empty(), "mallas del cuaderno y de la silla")
	eq(AFF.code_of(cu[0]), 2, "cuaderno usable: 2")
	eq(AFF.code_of(si[0]), 1, "silla: 1")
	var p: Vector2 = wr.camera().unproject_position(wr.node_body("silla").global_position)
	var hit: Dictionary = wr.hover_at(p)
	eq(str(hit.get("id", "")), "silla", "realce bajo el mouse: la silla")
	eq(AFF.code_of(si[0]), 3, "silla bajo el mouse: 3")
	eq(wr.cursor_for("node", "silla"), Input.CURSOR_HELP, "lupa sobre lo examinable")
	eq(wr.cursor_for("node", "cuaderno"), Input.CURSOR_POINTING_HAND, "mano sobre lo usable")
	wr.hover_at(Vector2(-50, -50))
	eq(AFF.code_of(si[0]), 1, "al salir, la silla vuelve a 1")
	eq(AFF.code_of(cu[0]), 2, "el cuaderno sigue en 2")

func test_picker_skips_coarse_anchor() -> void:
	# el ancla de la silla (0,52 × 0,9 × 0,52) tapa en pantalla el frente del escritorio desde la vista general: entre los
	# barrotes del respaldo el rayo no toca ninguna malla de la silla y el clic llega al cuaderno y a la tijera
	var r = repo()
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.hover_enabled = false
	_wr.show_hub("general", "M")
	await tree.physics_frame
	await tree.physics_frame
	eq(_wr.rig.mode(), "overview", "vista general")
	for nid in ["cuaderno", "tijera", "tintero", "calendario", "bandeja"]:
		var c: Vector2 = _wr.camera().unproject_position(_wr.node_body(nid).global_position)
		var found := false
		for dx in range(-12, 13, 4):
			for dy in range(-8, 9, 4):
				if str(_wr.pick(c + Vector2(dx, dy)).get("id", "")) == nid:
					found = true
		ok(found, "«%s» se toca desde la vista general" % nid)

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
		ok(USABLE_DO.has(String(b.get("do", ""))), "%s: %s usable por un vínculo de map.json (%s)" % [where, nid, str(b)])
		ok(gs.binding_live(String(b.get("do", "")), ph, f), "%s: %s con su función viva" % [where, nid])
	# y al revés: todo vínculo vivo está marcado
	for nid in w.diorama.get_meta("nodes_index"):
		var b2: Dictionary = Objects.binding(g.sim.repo, gs.cur_place, String(nid))
		if String(nid).begins_with("sil_"): continue
		if gs.binding_live(String(b2.get("do", "")), ph, f):
			ok(w.usable.has("n:" + String(nid)), "%s: %s (vínculo vivo) lleva el contorno" % [where, nid])
	# las siluetas nunca tienen código 2 en sus mallas
	for k2 in AFF.owners(w.diorama):
		if String(k2).begins_with("n:sil_"):
			for gi in AFF.owners(w.diorama)[k2]:
				ok(AFF.code_of(gi) != 2, "%s: la silueta %s sin contorno permanente" % [where, k2])

func test_usable_only_from_bindings_flags_exits_and_characters() -> void:
	await _boot()
	var gs = sh.game_screen
	eq(String(g.sim.q_clock().phase), "prologue", "prólogo")
	await _check_usable_rule("prólogo")
	# en el prólogo el mapa todavía no existe para Lisle (desk.mapa): sin contorno aunque el mapa esté colgado
	no(sh.world.usable.has("n:mapa"), "prólogo: el mapa sin contorno")
	await _to_day(1)
	eq([int(g.sim.q_clock().day), String(g.sim.q_clock().phase)], [1, "desk"], "día 1 en el escritorio")
	await _check_usable_rule("día 1")
	var f: Dictionary = gs.ui_flags()
	eq(sh.world.usable.has("n:mapa"), bool(f.get("desk.mapa", true)), "día 1: el mapa con su bandera")
	eq(sh.world.usable.has("n:cuaderno"), bool(f.get("hud.cuaderno", true)), "día 1: el cuaderno con su bandera")
	# etiquetas: lo usable suma el verbo; lo examinable, sólo el sustantivo
	var t_use: String = gs.hover_text("node", "tintero") if sh.world.usable.has("n:tintero") else ""
	if t_use != "":
		ok(t_use.contains(" · "), "lo usable lleva verbo: «%s»" % t_use)
	eq(gs.hover_text("node", "silla"), "silla", "lo examinable, sólo el sustantivo")
	# Pendientes es interfaz: tapa el mouse (leerla, dentro de la banda izquierda, no gira ni realza lo de atrás)
	eq(gs.hud.guide_box.mouse_filter, Control.MOUSE_FILTER_STOP, "Pendientes toma el mouse")
	# una visita: personajes en primer plano usables, siluetas no
	var r: Dictionary = g.act({"t": "go", "place": "L4", "area": ""})
	if bool(r.get("ok", false)):
		await _settle()
		# la banda de escena (abierta casi siempre en una visita) no apaga los bordes ni «mirar alrededor»; un panel que
		# tapa el 3D, sí (§E.2)
		eq(sh.top_kind(), "scene", "visita: la banda de escena abierta")
		ok(sh.world.edge_enabled, "con la banda de escena los bordes giran (si no, no hay cómo pasar de estación)")
		gs.set_look_around(true)
		ok(gs.looking_around(), "con la banda de escena se mira alrededor")
		gs.set_look_around(false)
		sh.open_panel("notebook")
		await _settle()
		no(sh.world.edge_enabled, "con el cuaderno abierto los bordes no giran")
		gs.set_look_around(true)
		no(gs.looking_around(), "con el cuaderno abierto no se mira alrededor")
		sh.close_all()
		await _settle()
		await _check_usable_rule("visita L4")
