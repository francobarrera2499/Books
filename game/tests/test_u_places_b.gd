# Tests de W2-PLACES-B: lugares L3 (Baker Street), L7 (Park Lane 427), L8 (Camden House) y lámina PARK.
# Dueño: W2-PLACES-B (módulos world/props/l3.gd, l7.gd, l8.gd y sus datos).
#  - los datos cargan sin errores de esquema ni de entidades;
#  - nodos del contrato §4.8 con sus etiquetas y su `when` (ventanas abiertas día 8-9, shag, cajón 9.T, línea de tiro…);
#  - secreto de Camden House: todo nodo de L8 lleva f:secreto_camden; el cartel «Se alquila» no lleva escondite_preparado;
#  - todo nodo se ve y se recorta SOLO (cover ≥ 0,5, ajustado, ≤ 1/8 de pantalla) en algún encuadre de su área, en una
#    instantánea donde su `when` vale (root.size 1600×900);
#  - geometría condicionada por nodos (Gate): ventanas, cajón, Parker; oclusores apagados cuando no está;
#  - construcción determinista y dentro de presupuesto; precalentado sin errores; caída de libros con pose final fija.
extends "res://tests/test_base.gd"

const WR = preload("res://world/world_root.gd")
const RC = preload("res://world/rect_clip.gd")
const DB = preload("res://world/diorama_builder.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const L3 = preload("res://world/props/l3.gd")
const L7 = preload("res://world/props/l7.gd")

const TIMEOUT_S := 240.0
const MINE := ["L3", "L7", "L8"]
const MINE_PLATES := ["PARK"]
const BUILD_BUDGET_MS := 1500

var _wr = null

func after_each() -> void:
	if _wr != null and is_instance_valid(_wr):
		if _wr.get_parent() != null: _wr.get_parent().remove_child(_wr)
		_wr.free()
	_wr = null

func _place(id: String) -> Dictionary:
	var r = repo()
	var p: Dictionary = r.place(id)
	if p.is_empty(): p = r.plate(id)
	return p

func _all_mine() -> Array:
	return MINE + MINE_PLATES

func _node(pl: Dictionary, nid: String) -> Dictionary:
	for n in pl.get("nodes", []):
		if str(n.get("id", "")) == nid: return n
	return {}

static func _area_ok(a: String, area: String) -> bool:
	return a == "*" or area == "*" or a == area

# misma emulación de WorldModel.snapshot que el driver de capturas (nodos/personajes por `when` con tk)
func _snap(pl: Dictionary, area: String, day: int, slot: String, frame := "") -> Dictionary:
	var tk := TimeKey.tk(day, slot)
	var ctx := {"repo": repo(), "tk": tk}
	var nodes: Array = []
	for n in pl.get("nodes", []):
		if _area_ok(str(n.get("area", "*")), area) and Cond.eval(n.get("when", {}), ctx): nodes.append(str(n["id"]))
	var chars: Array = []
	for c in pl.get("characters", []):
		if _area_ok(str(c.get("area", "*")), area) and Cond.eval(c.get("when", {}), ctx):
			chars.append({"id": str(c["id"]), "pose": str(c.get("pose", "")), "trait": str(c.get("trait", ""))})
	var sils: Array = []
	if day >= 3:
		for who in (pl.get("silhouettes", {}) as Dictionary).keys(): sils.append(str(who))
	return {"id": "PL.%s.%d.%s" % [pl.get("id", "?"), day, slot], "place": str(pl.get("id", "")), "area": area, "day": day,
		"slot": slot, "variant": "", "nodes": nodes, "chars": chars, "silhouettes": sils, "frame": frame}

func _world(pl: Dictionary, snap: Dictionary):
	after_each()
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	_wr.set_fast(true)
	_wr.show_plate(snap, pl)
	await tree.physics_frame
	await tree.physics_frame
	return _wr

func _clip_alone(wr, nid: String) -> String:
	var body = wr.node_body(nid)
	if body == null: return "no está en la instantánea"
	var cam: Camera3D = wr.camera()
	var vp := cam.get_viewport().get_visible_rect()
	var a := RC.screen_rect(cam, body).intersection(vp)
	if a.get_area() <= 0.0: return "fuera de cuadro"
	var r := a.grow(maxf(2.0, a.size.length() * 0.03)).intersection(vp)
	var res: Dictionary = wr.rect_clip(r)
	if float(res["area_frac"]) > 0.125: return "rectángulo > 1/8 (%.3f)" % float(res["area_frac"])
	var big: Array = []
	for h in res["hits"]:
		if float(h["cover"]) >= 0.5: big.append(h)
	if big.size() != 1 or str(big[0]["node"]) != nid:
		return "captura %s%s" % [str(big.map(func(h): return h["node"])), " (ocluido)" if res["occluded"].has(nid) else ""]
	if not bool(big[0]["tight"]): return "no ajustado"
	return ""

# primer tk (días 1..10, franjas M T N night) en que el `when` del nodo vale
func _tk_for(n: Dictionary) -> int:
	for d in range(1, 11):
		for s in ["M", "T", "N", "night"]:
			var tk := TimeKey.tk(d, s)
			if Cond.eval(n.get("when", {}), {"repo": repo(), "tk": tk}): return tk
	return -1

func _frames_for_area(pl: Dictionary, area: String) -> Array:
	var out: Array = []
	for f in pl.get("frames", []):
		if _area_ok(str(f.get("area", "*")), area): out.append(str(f["id"]))
	return out

func _first_area(pl: Dictionary) -> String:
	var areas = pl.get("areas", {})
	if areas is Dictionary and not areas.is_empty(): return str(areas.keys()[0])
	return "*"

# ---------------------------------------------------------------------------------------------
func test_data_loads_without_errors() -> void:
	var r = repo()
	for pid in _all_mine():
		ok(not _place(pid).is_empty(), "%s cargado" % pid)
	var mine: Array = []
	for e in r.errors():
		var s := str(e)
		for k in ["places/L3", "places/L7", "places/L8", "plates/PARK", "places_b"]:
			if s.contains(k): mine.append(s)
	eq(mine, [], "errores de esquema/entidades en mis archivos")
	ok(not r.entity("diecisiete_escalones").is_empty(), "entities/places_b.json")

func test_every_prop_type_resolves() -> void:
	for pid in _all_mine():
		var pl := _place(pid)
		for pr in pl.get("props", []):
			var t := str(pr.get("type", ""))
			var n := DB.build_prop(t, (pr.get("p", {}) as Dictionary).duplicate())
			no(n.has_meta("missing_type"), "%s.%s: tipo %s no existe" % [pid, pr.get("id"), t])
			ok(n.has_meta("occ"), "%s.%s sin meta occ" % [pid, pr.get("id")])
			n.free()

func test_contract_nodes_and_tags() -> void:
	# §4.8: N:L3.ventanas_abiertas / N:L3.shag (C9.R1), N:L3.cajon (C9.R2 y refutación de Meunier), N:L7.linea_de_tiro
	# (C11.R2), N:L7.azafranes (refutación de los anarquistas), N:L8.guillotina + N:L8.ceniza (C13.R1), N:PARK.libros (C12.R2)
	var want := {
		"L3": {"ventanas_abiertas": ["a:preparativos_221b"], "shag": ["a:preparativos_221b"],
			"cajon": ["a:preparativos_221b", "a:refuta_meunier", "e:oscar_meunier", "e:cajon_de_grenoble"]},
		"L7": {"linea_de_tiro": ["a:disparo_desde_fuera", "e:linea_de_tiro"], "azafranes": ["a:disparo_desde_fuera", "a:refuta_anarquistas", "e:azafranes"],
			"ventana": ["a:disparo_desde_fuera"], "cesped": ["a:disparo_desde_fuera"]},
		"L8": {"guillotina": ["a:escondite_preparado", "f:secreto_camden", "c:camden"], "ceniza": ["a:escondite_preparado", "e:cheroot", "f:secreto_camden"],
			"alfeizar": ["a:escondite_preparado", "f:secreto_camden"], "vista": ["a:escondite_preparado", "f:secreto_camden"]},
		"PARK": {"libros": ["e:tree_worship"]},
	}
	for pid in want:
		var pl := _place(pid)
		for nid in want[pid]:
			var n := _node(pl, nid)
			ok(not n.is_empty(), "%s: falta el nodo %s" % [pid, nid])
			if n.is_empty(): continue
			for tg in want[pid][nid]:
				has(n.get("tags", []), tg, "%s.%s" % [pid, nid])
			eq(str(n.get("cls", "")), "I", "%s.%s clase I (lugar)" % [pid, nid])

# Cruce con los datos estructurales (W2-STRUCT): toda ref N:<mío>.<nodo> de rutas, apoyos, refutaciones y rastros
# existe; los rastros que nombran un nodo mío llevan esas etiquetas; cada refutación lleva a:refuta_<x>.
func test_struct_refs_to_my_nodes() -> void:
	var r = repo()
	# v3 (CONTENIDO): las rutas son las de las preguntas del Expediente (data/dossier.json); _pistas_falsas va en el mismo archivo
	var meta: Dictionary = r.dossier()
	if r.questions().is_empty():
		pending_content("data/dossier.json (CORE)"); return
	var mine := {}
	for pid in _all_mine(): mine[pid] = _place(pid)
	var refs: Array = []   # [ref, tags_requeridos, origen]
	var walk := func(v, src: String, rec: Callable) -> void:
		if v is Dictionary:
			if v.has("ref") and str(v["ref"]).begins_with("N:"): refs.append([str(v["ref"]), [], src])
			if v.has("nodo") and str(v["nodo"]).begins_with("N:"): refs.append([str(v["nodo"]), v.get("tags", []), src])
			for k in v: rec.call(v[k], src, rec)
		elif v is Array:
			for x in v:
				if x is String and str(x).begins_with("N:"): refs.append([str(x), [], src])
				else: rec.call(x, src, rec)
	for c in r.questions(): walk.call(c, "pregunta " + str(c.get("id", "")), walk)
	for rx in r.reactions(): walk.call(rx, "reacción " + str(rx.get("id", "")), walk)
	var falsas: Array = meta.get("_pistas_falsas", [])
	for f in falsas:
		for ref in f.get("refutaciones", []):
			if str(ref).begins_with("N:"): refs.append([str(ref), ["a:refuta_" + str(f.get("id", "")).trim_prefix("falsa_")], "pista falsa " + str(f.get("id", ""))])
	var seen := 0
	for e in refs:
		var body := str(e[0]).substr(2)
		var dot := body.find(".")
		if dot < 0: continue
		var pid := body.substr(0, dot)
		var nid := body.substr(dot + 1)
		if not mine.has(pid): continue
		seen += 1
		var n := _node(mine[pid], nid)
		ok(not n.is_empty(), "%s: %s no existe" % [e[2], e[0]])
		for tg in e[1]:
			has(n.get("tags", []), tg, "%s pide %s en %s" % [e[2], tg, e[0]])
	ok(seen >= 8, "refs a mis nodos encontradas (%d)" % seen)

func test_when_windows() -> void:
	var l3 := _place("L3")
	var cases := [["ventanas_abiertas", "7.M", false], ["ventanas_abiertas", "8.M", true], ["ventanas_abiertas", "9.T", true], ["ventanas_abiertas", "10.night", false],
		["ventanas_cerradas", "7.T", true], ["ventanas_cerradas", "8.M", false], ["ventanas_cerradas", "10.T", true], ["ventanas_cerradas", "10.night", false],
		["shag", "7.T", false], ["shag", "8.M", true],
		["cajon", "9.M", false], ["cajon", "9.T", true], ["silueta_ventana", "9.N", false], ["silueta_ventana", "10.T", false], ["silueta_ventana", "10.night", true],
		["parker", "4.T", false], ["parker", "4.N", true], ["escalera", "1.M", true]]
	for c in cases:
		var n := _node(l3, str(c[0]))
		var got := Cond.eval(n.get("when", {}), {"repo": repo(), "tk": TimeKey.parse(str(c[1]))})
		eq(got, c[2], "L3.%s en %s" % [c[0], c[1]])
	# ventanas abiertas vistas desde Camden House (L8) en los mismos días
	var n8 := _node(_place("L8"), "ventanas_enfrente")
	eq(Cond.eval(n8.get("when", {}), {"repo": repo(), "tk": TimeKey.parse("8.M")}), true, "L8.ventanas_enfrente 8.M")
	eq(Cond.eval(n8.get("when", {}), {"repo": repo(), "tk": TimeKey.parse("7.T")}), false, "L8.ventanas_enfrente 7.T")

func test_camden_secret() -> void:
	# GDD§2.4 / D10 / T22: lo de adentro de Camden House es secreto de Moran; el cartel público no prepara el escondite (GRA-15)
	for n in _place("L8").get("nodes", []):
		has(n.get("tags", []), "f:secreto_camden", "L8.%s" % n.get("id"))
		# lo que Lisle informe desde adentro de Camden House le dice a Moran que estuvo en su escondite (M5, F1)
		if str(n.get("id", "")) != "ventanas_enfrente":
			has(n.get("tags", []), "c:camden", "L8.%s" % n.get("id"))
	# C12.R2 (N:PARK.libros) sólo vale para el epílogo: no lleva etiquetas de grupo (como el rastro de HC08)
	for tg in _node(_place("PARK"), "libros").get("tags", []):
		no(str(tg).begins_with("a:"), "PARK.libros sin a: (%s)" % tg)
	for pid in ["L3", "L7", "PARK"]:
		for n in _place(pid).get("nodes", []):
			no((n.get("tags", []) as Array).has("a:escondite_preparado"), "%s.%s no prepara el escondite" % [pid, n.get("id")])
			no((n.get("tags", []) as Array).has("f:secreto_camden"), "%s.%s es público" % [pid, n.get("id")])
	# nada de L3/L7/PARK da el paradero de Holmes ni dice que vive (T7/T23)
	for pid in _all_mine():
		for n in _place(pid).get("nodes", []):
			for tg in ["c:holmes_vive", "f:afirma_que_vive", "c:paradero_extranjero"]:
				no((n.get("tags", []) as Array).has(tg), "%s.%s sin %s" % [pid, n.get("id"), tg])

func test_every_node_has_examine_and_noun() -> void:
	for pid in _all_mine():
		for n in _place(pid).get("nodes", []):
			ok(str(n.get("examine", "")).strip_edges().length() > 12, "%s.%s examine" % [pid, n.get("id")])
			ok(str(n.get("noun", "")) != "", "%s.%s noun (epígrafe automático)" % [pid, n.get("id")])
			var s: Vector3 = Vector3(n["anchor"]["s"][0], n["anchor"]["s"][1], n["anchor"]["s"][2])
			ok(s.x > 0.0 and s.y > 0.0 and s.z > 0.0, "%s.%s ancla con volumen" % [pid, n.get("id")])

# T29 extendido a todos mis nodos: visible y recortable solo en algún encuadre de su área
func test_every_node_clippable_alone() -> void:
	var fails: Array = []
	for pid in _all_mine():
		var pl := _place(pid)
		# agrupar por (área, tk) para construir cada instantánea una sola vez
		var groups := {}
		for n in pl.get("nodes", []):
			var a := str(n.get("area", "*"))
			if a == "*": a = _first_area(pl)
			var tk := _tk_for(n)
			if tk < 0:
				fails.append("%s.%s: su when no vale nunca" % [pid, n["id"]]); continue
			var key := "%s|%d" % [a, tk]
			if not groups.has(key): groups[key] = []
			groups[key].append(str(n["id"]))
		var keys: Array = groups.keys()
		keys.sort()
		for key in keys:
			var a2 := str(key).get_slice("|", 0)
			var tk2 := int(str(key).get_slice("|", 1))
			var snap := _snap(pl, a2, TimeKey.day_of(tk2), TimeKey.slot_of(tk2))
			await _world(pl, snap)
			var pending: Array = (groups[key] as Array).duplicate()
			var why := {}
			for fid in _frames_for_area(pl, a2):
				if pending.is_empty(): break
				_wr.set_frame(fid, true)
				await tree.physics_frame
				for nid in pending.duplicate():
					var w := _clip_alone(_wr, nid)
					if w == "": pending.erase(nid)
					else: why[nid] = str(why.get(nid, "")) + "%s: %s; " % [fid, w]
			for nid in pending:
				fails.append("%s.%s (%s): %s" % [pid, nid, key, why.get(nid, "")])
	eq(fails, [], "nodos que no se recortan solos")

func test_gates_follow_snapshot() -> void:
	var l3 := _place("L3")
	var d3 := DB.build(l3, _snap(l3, "interior", 3, "M"))
	var d8 := DB.build(l3, _snap(l3, "interior", 9, "T"))
	tree.root.add_child(d3)
	tree.root.add_child(d8)
	await tree.process_frame
	var open3: Node3D = d3.get_node("Props/casa_221b/win_1_0/alt_ventanas_abiertas")
	var def3: Node3D = d3.get_node("Props/casa_221b/win_1_0/alt_default")
	var open8: Node3D = d8.get_node("Props/casa_221b/win_1_0/alt_ventanas_abiertas")
	var def8: Node3D = d8.get_node("Props/casa_221b/win_1_0/alt_default")
	no(open3.visible, "día 3: ventanas cerradas")
	ok(def3.visible, "día 3: estado por defecto")
	ok(open8.visible, "día 9: ventanas abiertas")
	no(def8.visible, "día 9: el estado por defecto se oculta")
	var caj3: Node3D = d3.get_node("Props/cajon_p")
	var caj8: Node3D = d8.get_node("Props/cajon_p")
	no(caj3.visible, "día 3: sin cajón")
	ok(caj8.visible, "9.T: cajón de Grenoble")
	for b in (d3.get_meta("prop_bodies", {}) as Dictionary).get("cajon_p", []):
		eq((b as CollisionObject3D).collision_layer, 0, "cajón ausente no ocluye")
	for b in (d8.get_meta("prop_bodies", {}) as Dictionary).get("cajon_p", []):
		eq((b as CollisionObject3D).collision_layer, 1, "cajón presente ocluye")
	no((d3.get_node("Props/shag_p") as Node3D).visible, "día 3: sin shag")
	ok((d8.get_node("Props/shag_p") as Node3D).visible, "día 9: shag")
	d3.queue_free()
	d8.queue_free()
	# Parker sólo de noche (calle)
	var dn := DB.build(l3, _snap(l3, "calle", 4, "N"))
	var dm := DB.build(l3, _snap(l3, "calle", 4, "M"))
	tree.root.add_child(dn)
	tree.root.add_child(dm)
	await tree.process_frame
	ok((dn.get_node("Props/parker_p") as Node3D).visible, "Parker de noche")
	no((dm.get_node("Props/parker_p") as Node3D).visible, "Parker no de día")
	dn.queue_free()
	dm.queue_free()
	# Gate.decide: el primer estado alternativo presente gana; exclude manda
	eq(L3.Gate.decide({"a": 1}, ["a"], []), true, "need presente")
	eq(L3.Gate.decide({}, ["a"], []), false, "need ausente")
	eq(L3.Gate.decide({"a": 1, "b": 1}, ["b"], ["a"]), false, "exclude manda")
	eq(L3.Gate.decide({}, [], ["a"]), true, "sin need: visible si no hay exclusión")

func test_build_deterministic_and_budget() -> void:
	for pid in _all_mine():
		var pl := _place(pid)
		var a := _first_area(pl)
		var t0 := Time.get_ticks_msec()
		var d1 := DB.build(pl, _snap(pl, a, 8, "T"))
		var ms := Time.get_ticks_msec() - t0
		var d2 := DB.build(pl, _snap(pl, a, 8, "T"))
		eq(_sig(d1), _sig(d2), "%s determinista" % pid)
		ok(ms < BUILD_BUDGET_MS, "%s se arma en %d ms (presupuesto %d)" % [pid, ms, BUILD_BUDGET_MS])
		print("  BUILD %s %d ms" % [pid, ms])
		d1.free()
		d2.free()

# firma independiente de los nombres automáticos de nodos: posición, escala y malla de cada geometría (orden de árbol)
func _sig(d: Node) -> String:
	var parts: PackedStringArray = []
	for mi in d.find_children("*", "GeometryInstance3D", true, false):
		var t: Transform3D = DB.M._rel_xform(d as Node3D, mi as Node3D)
		var extra := ""
		if mi is MultiMeshInstance3D and (mi as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
			extra = ":%d" % mm.instance_count
			if mm.instance_count > 0:
				var o2 := mm.get_instance_transform(mm.instance_count - 1).origin
				extra += "/%.3f,%.3f,%.3f" % [o2.x, o2.y, o2.z]
		elif mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			extra = ":" + (mi as MeshInstance3D).mesh.get_class()
		parts.append("%.3f,%.3f,%.3f|%.3f,%.3f,%.3f%s" % [t.origin.x, t.origin.y, t.origin.z, t.basis.x.x, t.basis.y.y, t.basis.z.z, extra])
	return str(parts.size()) + "#" + str(hash("|".join(parts)))

func test_prewarm_my_places() -> void:
	tree.root.size = Vector2i(1600, 900)
	_wr = WR.new()
	tree.root.add_child(_wr)
	for pid in _all_mine():
		await _wr.prewarm(_place(pid))
		await tree.process_frame
		eq(_wr.find_children("Prewarm", "", false, false).size(), 0, "%s: el precalentado se libera" % pid)

func test_books_fall_to_fixed_pose() -> void:
	var n := L7.build_libros_caidos({"seed": 5, "from": [-1.25, 1.0, -0.4], "delay": 0.2, "dur": 0.5})
	tree.root.add_child(n)
	await tree.process_frame
	var cai = n.get_node("caida")
	var finals: Array = cai.finals
	eq(finals.size(), 5, "cinco libros")
	var b0: Node3D = cai.get_child(0)
	cai._process(0.3)    # en el aire
	no(b0.transform.is_equal_approx(finals[0]), "a mitad de la caída no está en su pose final")
	ok(b0.position.y > 0.05, "a mitad de la caída está en el aire")
	cai._process(1.0)
	for i in finals.size():
		ok((cai.get_child(i) as Node3D).transform.is_equal_approx(finals[i]), "libro %d en su pose final" % i)
	no(cai.is_processing(), "la animación termina")
	# pose final determinista (misma semilla → mismas poses)
	var m := L7.build_libros_caidos({"seed": 5})
	var c2 = m.get_node("caida")
	for i in finals.size():
		ok((c2.finals[i] as Transform3D).is_equal_approx(finals[i]), "pose %d estable" % i)
	var title := n.find_children("titulo", "Label3D", true, false)
	eq(title.size(), 1, "un libro con el título")
	if not title.is_empty():
		ok(str((title[0] as Label3D).text).contains("Tree Worship"), "«The Origin of Tree Worship»")
	n.queue_free()
	m.free()

# La visita arranca en el primer encuadre que coincide con el área (WorldModel.snapshot / WorldRoot._first_frame):
# entrar al 221B muestra el vestíbulo (Mrs. Hudson), la oficina muestra al agente, la calle el 221B. La única noche en
# Baker Street (HC09, día 10) es ventosa. La etiqueta del cajón cabe entera en su papel (el renglón GRENOBLE incluido).
func test_entry_frame_night_light_and_labels() -> void:
	var l3 := _place("L3")
	var first := func(area: String) -> String:
		for f in l3.get("frames", []):
			var a := str(f.get("area", "*"))
			if a == "*" or a == "" or a == area: return str(f["id"])
		return ""
	eq(first.call("interior"), "vestibulo", "interior arranca en el vestíbulo")
	eq(first.call("agente"), "agente", "agente arranca en la oficina")
	eq(first.call("calle"), "221b", "calle arranca frente al 221B")
	var LT = load("res://world/lighting.gd")
	eq(str(LT.preset_for(l3, "night")), "noche_viento", "HC09: noche ventosa en Baker Street")
	eq(str(LT.preset_for(l3, "N")), "farol_calle", "las demás noches (N): farol")
	var cp: Dictionary = {}
	for pr in l3.get("props", []):
		if str(pr.get("id", "")) == "cajon_p": cp = pr["p"]["p"]
	var caj := L3.build_cajon(cp)
	tree.root.add_child(caj)
	var lb: Label3D = caj.find_child("etiqueta", true, false)
	ok(lb != null and lb.text.contains("GRENOBLE"), "etiqueta con GRENOBLE")
	if lb != null:
		var f: Font = lb.font if lb.font != null else ThemeDB.fallback_font
		var lines := lb.text.split("\n")
		var mw := 0.0
		for l in lines: mw = maxf(mw, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.font_size).x)
		var tw := mw * lb.pixel_size
		var th := lines.size() * (f.get_height(lb.font_size) + lb.line_spacing) * lb.pixel_size
		ok(tw <= minf(float(cp.get("w", 0.7)) * 0.88, 0.64) + 0.001, "el texto cabe a lo ancho (%.3f m)" % tw)
		ok(th <= minf(float(cp.get("h", 0.95)) * 0.6, 0.56) + 0.001, "el texto cabe a lo alto (%.3f m)" % th)
		ok(lb.pixel_size >= 0.001, "legible al examinar (pixel_size %.5f)" % lb.pixel_size)
		eq(lb.autowrap_mode, TextServer.AUTOWRAP_OFF, "renglones explícitos")
	caj.queue_free()

func test_silhouettes_and_frames_sane() -> void:
	for pid in _all_mine():
		var pl := _place(pid)
		var fids: Array = []
		for f in pl.get("frames", []): fids.append(str(f["id"]))
		# GDD§14.4: de 2 a 4 encuadres fijos (por área visitable: los de área "*" cuentan en todas)
		var areas: Array = (pl.get("areas", {"*": {}}) as Dictionary).keys()
		for a in areas:
			var nfa := _frames_for_area(pl, str(a)).size()
			ok(nfa >= 2 and nfa <= 4, "%s.%s: 2-4 encuadres (%d)" % [pid, a, nfa])
		var sils: Dictionary = pl.get("silhouettes", {})
		ok(sils.has("wiggins"), "%s: silueta de Wiggins (HC02, desde el día 3)" % pid)
		for who in sils:
			has(fids, str(sils[who].get("frame", "")), "%s: %s apunta a un encuadre existente" % [pid, who])
	# L7 y PARK: luz de la franja; PARK siempre dorada (día 10, 18 h)
	eq(str(_place("PARK").get("light", {}).get("T", "")), "dorada_parklane", "PARK dorada")
	eq(bool(_place("PARK").get("fixed", false)), true, "PARK lámina fija")
	eq(str(_place("L8").get("light", {}).get("T", "")), "farol_calle", "L8 a la luz del farol de la calle")
