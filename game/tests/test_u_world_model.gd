# W2-SIM: WorldModel: accesibilidad (holder, lugar, ventana, retiros, papeletas), vistas y bloques, documentos runtime
# y entregas (bandeja, columna, noticias), instantáneas y láminas, memoria de L6 y copia por correo, huevos (≤1 por visita),
# líneas automáticas de escena (HC05, HC06 con acts_by_channel).
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

func _at(day: int, slot: String):
	var s = Kit.new_sim()
	eq(Kit.advance_to(s, day, slot), "", "avance a %d.%s" % [day, slot])
	return s

func _views(s) -> Array:
	var out: Array = []
	for v in s.q_accessible():
		out.append(v.view)
	return out

func test_prologue_accessibility():
	var s = Kit.new_sim()
	var v := _views(s)
	for x in ["D23@L1", "D02@L1", "D03@tomo"]:
		has(v, x)
	for x in ["D15.0327@L1", "D03@Crane", "D05@BM", "D29b@L4"]:
		no(v.has(x), x)
	ok(WorldModel.view_accessible(s.st, s.repo, "D02@L1"))
	no(WorldModel.view_accessible(s.st, s.repo, "D99@L1"))

func test_shop_and_reading_room():
	var s = _at(1, "M")
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	var v := _views(s)
	ok(v.has("D03@Crane") and v.has("D07@Crane") and v.has("D33@Crane"), str(v))
	eq(s.q_view("D33@Crane").pages.size(), 1, "p2 de D33 sólo el día 10 (parts[].when)")
	ok(s.apply({"t": "leave"}).ok)
	no(_views(s).has("D03@Crane"), "de vuelta arriba")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok)
	no(_views(s).has("D05@BM"), "sin papeleta")
	var r: Dictionary = s.apply({"t": "slip", "doc": "D05"})
	ok(r.ok, str(r))
	eq(r.view, "D05@BM")
	ok(_views(s).has("D05@BM"))
	no(_views(s).has("D02@L1"), "lo de casa no está en el Museo")
	eq(s.apply({"t": "slip", "doc": "D05"}).err, "ya_pedido")
	eq(s.apply({"t": "slip", "doc": "D23"}).err, "no_esta", "sin ejemplar del BM")
	ok(s.apply({"t": "slip", "doc": "D08"}).ok)
	ok(s.apply({"t": "slip", "doc": "D10"}).ok)
	eq(s.apply({"t": "slip", "doc": "D19"}).err, "sin_papeletas", "3 por visita")
	var slips: Array = []
	for ev in s.st.events:
		if ev.type == "slip":
			slips.append(ev)
	eq(slips.size(), 3)
	eq(slips[0].seat, 214)
	eq(slips[0].topic, "holmes_prensa_1891")
	eq(slips[0].title, "Journal de Genève, miércoles 6 de mayo de 1891")
	ok(slips[1].hour > slips[0].hour or slips[1].hour.length() > slips[0].hour.length(), "hora creciente")
	ok(s.apply({"t": "leave"}).ok)
	ok(s.apply({"t": "end_slot"}).ok)
	no(_views(s).has("D05@BM"), "la papeleta vale una visita")

func test_withdraw_and_return():
	var s = _at(2, "M")
	var st = s.st
	WorldModel.withdraw_copy(st, "D02@L1", TimeKey.parse("2.N"))
	no(_views(s).has("D02@L1"))
	eq(s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D02@L1", "part": 0, "block": 0}, "from": 0, "len": 5}).err, "inaccesible")
	WorldModel.return_copy(st, "D02@L1")
	ok(_views(s).has("D02@L1"))
	WorldModel.withdraw_copy(st, "D02@L1", TimeKey.parse("2.N"))
	eq(Kit.advance_to(s, 3, "M"), "")
	ok(_views(s).has("D02@L1"), "retiro de un día")

func test_place_copies_by_area_and_window():
	var s = _at(6, "T")
	ok(s.apply({"t": "go", "place": "L4", "area": "estudio"}).ok)
	ok(_views(s).has("D29b@L4"), "el domingo, en el estudio")
	var v: Dictionary = s.q_view("D29b@L4")
	eq(v.class, "C")
	eq(v.src_line, "Hoja suelta del bloc del doctor Watson · papel privado")
	eq(v.measure.entity, "papel_corto")

func test_memory_clips_and_order_copy():
	var s = _at(5, "M")
	ok(s.apply({"t": "go", "place": "L6", "area": "registro"}).ok)
	var src := {"kind": "doc", "ref": "D18@L6", "part": 0, "block": 0}
	for i in 3:
		ok(s.apply({"t": "clip_text", "src": src, "from": 0, "len": 6}).ok, "memoria %d" % i)
	eq(s.apply({"t": "clip_text", "src": src, "from": 0, "len": 6}).err, "memoria_agotada")
	var r: Dictionary = s.apply({"t": "order_copy", "doc": "D18"})
	ok(r.ok, str(r))
	eq(r.arrives_tk, TimeKey.parse("7.dawn"), "dos días; el domingo no hay correo")
	eq(s.apply({"t": "order_copy", "doc": "D18"}).err, "ya_pedido")
	eq(s.apply({"t": "order_copy", "doc": "D02"}).err, "no_esta")
	var last: Dictionary = s.st.events[-1]
	eq(last.type, "order_copy")
	eq(last.doc, "D18")

func test_instantiate_and_deliver():
	var s = _at(4, "M")
	var st = s.st
	var repo = s.repo
	var tpl := {"tpl": "holmes_cronicas", "texto": "{{#ancla a:ancla_kbm|[[@act|Asiento ${seat}]]: el doctor se equivoca.}}"}
	var meta := {"rid": "HA1", "act": "act.3", "doc": {"title": "Carta a máquina, matasellos S.W.", "src_type": "carta_recibida", "class": "P", "font": "maquina", "firma": "Un amigo de la exactitud"}}
	var iid: String = WorldModel.instantiate_doc(st, repo, tpl, {"seat": 214}, meta)
	eq(iid, "R.HA1.1")
	eq(WorldModel.instantiate_doc(st, repo, tpl, {"seat": 9}, meta), "R.HA1.2")
	no(WorldModel.view_accessible(st, repo, iid), "sin entregar")
	WorldModel.deliver(st, repo, iid, "correo")
	ok(WorldModel.view_accessible(st, repo, iid))
	var v: Dictionary = s.q_view(iid)
	eq(v.pages[0].size(), 2, "cuerpo + firma")
	eq(v.pages[0][0].parsed.plain, "Asiento 214: el doctor se equivoca.")
	eq(v.pages[0][0].parsed.mentions[0].ent, "act.3", "@act -> entidad del acto")
	eq(v.pages[0][1].parsed.plain, "—Un amigo de la exactitud")
	var arrivals: Array = []
	for d in s.q_diary():
		if d.kind == "arrival":
			arrivals.append(d.parsed.plain)
	ok(arrivals.size() >= 1)
	var found := false
	for a in arrivals:
		if a.ends_with("Recibido: sobre, matasellos S.W."):
			found = true
	ok(found, str(arrivals))
	# fusión de voz A (D3): mismo R.<…>, bloques en orden
	var m2 := meta.duplicate(true)
	m2["merge_into"] = iid
	eq(WorldModel.instantiate_doc(st, repo, tpl, {"seat": 1}, m2), iid)
	eq(s.q_view(iid).pages[0].size(), 3)
	# columna: se inserta en el Times del día (D15.0330, día 4) con su origen
	var col: String = WorldModel.instantiate_doc(st, repo, {"tpl": "texto", "texto": "AL LECTOR DE HOLYWELL STREET. — Busca usted testigos."}, {}, {"rid": "HC10", "doc": {"title": "Columna"}})
	WorldModel.deliver(st, repo, col, "columna")
	no(WorldModel.view_accessible(st, repo, col), "no es una vista suelta")
	var t: Dictionary = s.q_view("D15.0330@L1")
	eq(t.pages[1].size(), 1, "el aviso runtime va DENTRO de la columna (p2), en el mismo bloque")
	eq(t.pages[1][0].origin, "D15.0330", "comparte origen con el número")
	eq(t.pages[1][0].segs.size(), 1)
	eq(t.pages[1][0].segs[0].doc, col, "el tramo insertado es del documento runtime")
	var plain: String = t.pages[1][0].parsed.plain
	var sg: Dictionary = t.pages[1][0].segs[0]
	eq(plain.substr(int(sg.from), int(sg.to) - int(sg.from)), "AL LECTOR DE HOLYWELL STREET. — Busca usted testigos.")
	ok(not plain.contains("

"), "sin renglón en blanco")
	ok(plain.find("AL LECTOR") < plain.rfind("
"), "nunca al pie de la columna")
	eq(WorldModel.block(st, repo, "D15.0330@L1", "p2", 0).segs[0].doc, col, "bloque por id de parte")
	eq(WorldModel.block(st, repo, "D15.0330@L1", 1, 0).segs[0].doc, col, "bloque por índice")
	var nt: String = WorldModel.instantiate_doc(st, repo, {"tpl": "x", "texto": "Nota comunicada."}, {}, {"rid": "HB3"})
	WorldModel.deliver(st, repo, nt, "noticias")
	var t2: Dictionary = s.q_view("D15.0330@L1")
	eq(t2.pages[0].size(), 1, "noticias en p1, en el mismo bloque")
	eq(t2.pages[0][0].segs[0].doc, nt)

# Hallazgo del lector: lo que el mundo agrega a la columna no sale al pie ni suelto. Va dentro del bloque de la parte,
# entre los avisos (nunca después del último, DINERO), en un lugar fijo por semilla y distinto entre partidas; en
# noticias, nunca después de «El tiempo.». El recorte de ese tramo es del documento runtime (voz, procedencia).
func test_times_insert_position_and_clip():
	var s = _at(4, "M")
	var st = s.st
	var repo = s.repo
	var col: String = WorldModel.instantiate_doc(st, repo, {"tpl": "texto", "texto": "{{#hc10|AL LECTOR DE HOLYWELL STREET. — Busca usted testigos.}} —S."}, {}, {"rid": "HC10", "doc": {"title": "Columna"}})
	WorldModel.deliver(st, repo, col, "columna")
	var pg: Array = s.q_view("D15.0330@L1").pages[1]
	eq(pg.size(), 1)
	var plain: String = pg[0].parsed.plain
	var lines: PackedStringArray = plain.split("
")
	var at := -1
	for i in lines.size():
		if lines[i].begins_with("AL LECTOR"):
			at = i
	ok(at >= 4 and at <= lines.size() - 3, "después del tercer aviso y antes del penúltimo: renglón %d de %d" % [at, lines.size()])
	ok(lines[lines.size() - 1].begins_with("DINERO"), "DINERO sigue cerrando la columna")
	# determinista por semilla, distinto entre semillas (alguna de 8 cae en otro renglón)
	var units := WorldModel.insert_units(repo.parsed("D15.0330", "p2"), "columna")
	var seen := {}
	for sd in 8:
		st.seed = sd
		seen[WorldModel.insert_pos(st, units, "columna", "D15.0330", col, 999)] = true
	ok(seen.size() >= 2, "el lugar depende de la semilla")
	# el recorte del tramo insertado es del documento runtime
	var sg: Dictionary = pg[0].segs[0]
	var r := Clipper.act_clip_text(st, repo, {"src": {"kind": "doc", "ref": "D15.0330@L1", "part": 1, "block": 0}, "from": int(sg.from), "len": 13})
	ok(r.ok, str(r))
	eq(String(Clipper.get_clip(st, String(r.clip)).doc), col, "recorte del aviso insertado -> su documento")
	eq(String(Clipper.get_clip(st, String(r.clip)).origin), "D15.0330", "con el origen del número")
	var r2 := Clipper.act_clip_text(st, repo, {"src": {"kind": "doc", "ref": "D15.0330@L1", "part": 1, "block": 0}, "from": plain.find("SE VENDE"), "len": 8})
	ok(r2.ok, str(r2))
	eq(String(Clipper.get_clip(st, String(r2.clip)).doc), "D15.0330", "un aviso del número sigue siendo del número")
	# noticias: nunca después de «El tiempo.»
	var nt: String = WorldModel.instantiate_doc(st, repo, {"tpl": "x", "texto": "{{#hb3|Nota comunicada.}}"}, {}, {"rid": "HB3"})
	WorldModel.deliver(st, repo, nt, "noticias")
	var p0: String = s.q_view("D15.0330@L1").pages[0][0].parsed.plain
	ok(p0.find("Nota comunicada.") < p0.find("El tiempo."), "la nota va antes del tiempo: " + p0)
	ok(p0.find("Nota comunicada.") > p0.find("Grand National"), "y después de la primera noticia")

func test_columna_without_times_falls_to_tray():
	var s = _at(6, "T")
	var iid: String = WorldModel.instantiate_doc(s.st, s.repo, {"tpl": "x", "texto": "Texto."}, {}, {"rid": "HC03", "doc": {"title": "Nota"}})
	WorldModel.deliver(s.st, s.repo, iid, "columna")
	ok(WorldModel.view_accessible(s.st, s.repo, iid), "sin Times el domingo: a la bandeja")

func test_snapshot_nodes_chars_silhouettes_variants():
	var s = _at(2, "M")
	var st = s.st
	var repo = s.repo
	var sn: Dictionary = WorldModel.snapshot(st, repo, "L3", "calle", "")
	no((sn.nodes as Array).has("ventanas_abiertas"), "when day >= 8")
	no((sn.nodes as Array).has("escalera"), "otra área")
	sn = WorldModel.snapshot(st, repo, "L4", "consulta", "")
	eq(sn.chars.size(), 1, "Watson por la mañana")
	eq(sn.silhouettes, [])
	WorldModel.add_silhouette(st, "wiggins", 3)
	eq(WorldModel.snapshot(st, repo, "L4", "consulta", "").silhouettes, [], "desde el día 3")
	eq(Kit.advance_to(s, 3, "T"), "")
	sn = WorldModel.snapshot(st, repo, "L4", "consulta", "")
	eq(sn.silhouettes, ["sil_wiggins"])
	eq(sn.chars.size(), 0, "Watson sólo de mañana")
	sn = WorldModel.snapshot(st, repo, "L1", "buhardilla", "registrada")
	has(sn.nodes, "ceniza_registro", "variante del registro (M1)")
	var rb: Dictionary = s.q_plate("RB.foto")
	has(rb.nodes, "linea", "variante foto de la lámina RB")
	eq(rb.variant, "foto")

func test_visit_plate_archive_and_silhouette_char():
	var s = _at(3, "M")
	WorldModel.add_silhouette(s.st, "wiggins", 3)
	var r: Dictionary = s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 7})
	ok(r.ok)
	eq(r.plate, "PL.L2.3.M")
	eq(r.visit, "S.L2.3.M")
	var p: Dictionary = s.q_visit_plate()
	eq(p.silhouettes, ["sil_wiggins"])
	ok(String(p.act).begins_with("act."), "el acto go de la visita")
	eq(s.st.events[-1].act, p.act, "act previsto == act numerado")
	var ids: Array = []
	for c in s.q_scene().chars:
		ids.append(c.id)
	ok(ids.has("cotter") and ids.has("wiggins"), str(ids))
	# recortar un nodo de la lámina archivada (accesible siempre)
	ok(s.apply({"t": "clip_plate", "plate": "PL.L2.3.M", "hits": [], "touched": ["cesto_tiras"], "area_frac": 0.05}).ok)
	eq(s.apply({"t": "clip_plate", "plate": "PL.NO", "hits": [], "touched": [], "area_frac": 0.05}).err, "inaccesible")

# Recortar en casa (hub, lo que se ve desde el escritorio): la buhardilla de ahora se archiva como lámina de visita
# PL.L1.<día>.<franja> (origen PL.L1…, el de RouteDB); sólo nodos de la buhardilla y «*»; una igual en la misma franja
# se reutiliza; un recorte rechazado no deja lámina; fuera de casa no hay hub.
func test_clip_hub_at_home():
	var Clipper = load("res://core/deduction/clipper.gd")
	var s = _at(3, "M")
	for t in ["clip_plate", "clip_text"]:
		s.st.handlers.erase(t)   # Clipper real (no el doble del kit)
	WorldModel.add_silhouette(s.st, "wiggins", 3)
	var hs: Dictionary = s.q_plate("hub")
	ok((hs.get("nodes", []) as Array).has("estufa") and not (hs.get("nodes", []) as Array).has("estantes"), str(hs))
	has(hs.get("silhouettes", []), "sil_wiggins")
	ok(Clipper.accessible(s.st, s.repo, "plate", "hub"))
	var bad: Dictionary = s.apply({"t": "clip_plate", "plate": "hub", "hits": [{"node": "estantes", "cover": 0.9, "tight": true}], "touched": [], "area_frac": 0.05})
	no(bad.ok, "la tienda no se ve desde el escritorio")
	eq(s.st.world.plates.keys().filter(func(k): return String(k).begins_with("PL.L1.")), [], "un recorte rechazado no archiva nada")
	var r1: Dictionary = s.apply({"t": "clip_plate", "plate": "hub", "hits": [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], "touched": ["sil_wiggins"], "area_frac": 0.05})
	ok(r1.ok, str(r1))
	var c1: Dictionary = Clipper.get_clip(s.st, String(r1.clip))
	eq(String(c1.plate), "PL.L1.3.M")
	ok(String(c1.origin).begins_with("PL.L1"), String(c1.origin))
	var r2: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "node", "ref": "hub/estufa"}, "from": 0, "len": 28})
	ok(r2.ok, str(r2))
	eq(String(Clipper.get_clip(s.st, String(r2.clip)).view), "PL.L1.3.M", "misma franja, misma lámina")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 7}).ok)
	eq(s.q_plate("hub"), {}, "de visita no hay hub")
	eq(s.apply({"t": "clip_plate", "plate": "hub", "hits": [], "touched": ["estufa"], "area_frac": 0.05}).err, "inaccesible")
	ok(not s.q_plate("PL.L1.3.M").is_empty(), "la lámina archivada sigue")

# lists.contracciones con borde de palabra: «de el»/«a el» sólo como palabras sueltas; «..» en cualquier lugar.
func test_contract_word_boundary():
	var r = Kit.repo()
	eq(WorldModel.contract(r, "A propósito de el Journal.."), "A propósito del Journal.")
	eq(WorldModel.contract(r, "Voy a el club, de el que le hablé."), "Voy al club, del que le hablé.")
	eq(WorldModel.contract(r, "De el Strand. A el fin."), "Del Strand. Al fin.")
	eq(WorldModel.contract(r, "«de el muelle»"), "«del muelle»")
	var keep := "Fue para el doctor; nadie puede el domingo; se toca el crespón; nada el perro."
	eq(WorldModel.contract(r, keep), keep, "sin borde de palabra no se contrae")
	eq(WorldModel.contract(r, "El problema final"), "El problema final")

func test_eggs_one_per_visit():
	var s = _at(1, "M")
	var st = s.st
	# como lo harían clip_text y link: recortes y par nuevos (los contadores avanzan)
	st.ded.clips["RC0901"] = {"id": "RC0901", "tags": ["x:EE01"], "ents": ["trichinopolis"]}
	st.ded.clips["RC0902"] = {"id": "RC0902", "tags": [], "ents": ["cheroot"]}
	st.ded.pairs["PR901"] = {"a": "RC0901", "b": "RC0902", "note": ""}
	st.seq["clip"] = int(st.seq.get("clip", 0)) + 2
	st.seq["pair"] = int(st.seq.get("pair", 0)) + 1
	WorldModel.check_eggs(st, s.repo)
	eq(st.world.eggs.keys(), ["EE01"])
	WorldModel.check_eggs(st, s.repo)
	eq(st.world.eggs.keys(), ["EE01"], "≤1 por visita: EE13 espera")
	ok(s.apply({"t": "end_slot"}).ok)
	ok(st.world.eggs.has("EE13"), "en la franja siguiente aparece")
	var m: Array = s.q_marginalia()
	eq(m.size(), 2)
	eq(m[0].id, "EE01")

func test_auto_scene_lines_and_acts_by_channel():
	var s = _at(1, "M")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok)
	ok(s.apply({"t": "slip", "doc": "D05"}).ok)
	ok(s.apply({"t": "leave"}).ok)
	eq(Kit.advance_to(s, 3, "M"), "")
	ok(s.apply({"t": "go", "place": "L7", "area": "exterior"}).err == "cerrado", "Park Lane desde el día 5")
	ok(s.apply({"t": "go", "place": "L3", "area": "calle"}).ok)
	ok(s.apply({"t": "leave"}).ok)
	eq(Kit.advance_to(s, 8, "M"), "")
	ok(s.apply({"t": "go", "place": "L3", "area": "interior"}).ok)
	var l3: Array = []
	for l in s.q_scene().lines:
		l3.append(l.id)
	eq(l3, ["jueves_a"], "HC05 automática los días 8–9 en el interior")
	ok(s.apply({"t": "leave"}).ok)
	ok(s.apply({"t": "end_slot"}).ok)
	ok(s.apply({"t": "go", "place": "L5", "area": "forasteros"}).ok)
	var lines: Array = s.q_scene().lines
	var ids: Array = []
	for l in lines:
		ids.append(l.id)
	eq(ids, ["a", "b_kbm", "b_ks", "b_kt"], "un acto por canal usado (kt: el aviso del prólogo)")
	var kbm: Dictionary = lines[1]
	ok(String(kbm.parsed.plain).contains("asiento 214"), kbm.parsed.plain)
	var slip_act := ""
	for ev in s.st.events:
		if ev.type == "slip":
			slip_act = ev.act
	eq(kbm.parsed.mentions[0].ent, slip_act, "ancla = entidad del acto citado")
	eq(kbm.parsed.tramos[0].tags.a, ["ancla_kbm"])
	# el diario conserva el origen de la escena
	var org := ""
	for d in s.q_diary():
		if d.kind == "line" and String(d.parsed.plain).contains("asiento 214"):
			org = d.origin
	eq(org, "S.L5.8.T")

func test_arrivals_and_coins():
	var s = Kit.new_sim()
	var c0: int = s.st.world.coins_d
	Kit.run(s, Kit.prologue())
	eq(s.st.world.coins_d, c0 + 252 - 30, "guinea al amanecer menos el aviso")
	var tray: Array = s.q_tray(1)
	eq(tray.size(), 1)
	eq(tray[0].how, "diario")
	eq(s.q_tray(0), [])

# Estado de mundo de Effects (W2-REACT, st.react.world) que WorldModel/Clock respetan.
func test_effects_world_state_is_honored():
	var s = _at(3, "M")
	var st = s.st
	var Effects = load("res://core/react/effects.gd")
	Effects.init_world(st)
	var w: Dictionary = st.react.world
	w.withdrawn["D02@L1"] = {"from_tk": TimeKey.parse("3.dawn"), "to_tk": TimeKey.parse("4.dawn"), "by": "R.M1.1"}
	no(_views(s).has("D02@L1"), "retirado por M1")
	w.closed["L6.registro"] = {"from_day": 3, "to_day": 3, "by": "R.X.1"}
	eq(s.apply({"t": "go", "place": "L6", "area": "registro"}).err, "cerrado")
	w = st.react.world   # un apply rechazado restaura el estado: las referencias viejas quedan sueltas
	w.variants["L1"] = {"variant": "registrada", "from_tk": 30, "rid": "M1"}
	w.silhouettes.append({"who": "wiggins", "place": "*", "desde": 3, "reemplaza": "", "rid": "HC02"})
	w.nodes.append({"ref": "N:L1.pisada", "place": "L1", "node": "pisada", "tags": ["a:tirador"], "from_tk": 30, "rid": "M1", "iid": "R.M1.1"})
	var hub: Dictionary = s.q_hub_plate()
	has(hub.nodes, "ceniza_registro", "variante de Effects")
	has(hub.nodes, "pisada", "nodo de rastro de Effects")
	eq(hub.node_defs.pisada.tags, ["a:tirador"])
	has(hub.silhouettes, "sil_wiggins", "silueta de Effects")
	w.torn["D33@Crane"] = {"tk": 30, "rid": "M5", "part": ""}
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	no(_views(s).has("D33@Crane"), "página arrancada")
	eq(Kit.advance_to(s, 4, "M"), "")
	ok(_views(s).has("D02@L1"), "vuelve al día siguiente")

func test_effects_doc_format_and_scene_extra():
	var s = _at(4, "M")
	var st = s.st
	var tpl := {"title": "Carta a máquina, matasellos S.W.", "src_type": "carta_recibida", "class": "P", "font": "maquina",
		"machine": "remington_cotter", "paper": "diogenes_recortado", "paper_mm": [203, 244], "entity": "cartas_a_maquina",
		"id": "R.HA1.1", "date": "1894-03-30", "origin": "R.HA1.1", "parts": [{"id": "p1", "text": "[[@act|Asiento 214]]: lea a Reuter.\n—Un amigo de la exactitud"}],
		"copies": [], "words": 8, "src_en": {}, "firma": "Un amigo de la exactitud"}
	var iid: String = WorldModel.instantiate_doc(st, s.repo, tpl, {}, {"iid": "R.HA1.1", "rid": "HA1", "act": "act.2", "how": "correo", "origin": "R.HA1.1"})
	eq(iid, "R.HA1.1")
	WorldModel.deliver(st, s.repo, iid, "correo")
	var v: Dictionary = s.q_view(iid)
	eq(v.pages[0].size(), 1, "la firma ya viene en el texto: no se duplica")
	eq(v.machine, "remington_cotter")
	eq(v.pages[0][0].parsed.mentions[0].ent, "act.2")
	eq(st.world.docs[iid].meta.entity, "cartas_a_maquina")
	# columna con insert explícito (Effects.doc_tpl): va al número indicado
	var col: String = WorldModel.instantiate_doc(st, s.repo, {"title": "The Times", "parts": [{"id": "p1", "text": "AL LECTOR. —S."}],
		"insert": {"doc": "D15.0327", "part": "columna"}, "origin": "D15.0327"}, {}, {"iid": "R.HC10.1", "rid": "HC10", "origin": "D15.0327"})
	WorldModel.deliver(st, s.repo, col, "columna")
	eq(s.q_view("D15.0327@L1").pages[1][0].segs[-1].doc, col)
	# líneas extra de una escena (siguiente comunicación de Moran)
	var Effects = load("res://core/react/effects.gd")
	Effects.init_world(st)
	st.react.world.scene_extra["M7"] = ["El mayor celebra su diligencia en Baker Street."]
	var ids: Array = []
	for l in WorldModel.scene_lines(st, s.repo, "M7"):
		ids.append(l.id)
	has(ids, "extra.0")
	if ids.size() >= 3:
		eq(ids.find("extra.0"), ids.size() - 2, "la línea extra va antes de la despedida, no después: %s" % str(ids))

func test_scene_lines_registry_sync():
	var s = _at(1, "M")
	var st = s.st
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	# una línea registrada por Dialogue/Confrontation (W2-SCENES) en st.scenes.lines
	var uid: String = st.next_id("line", "LN.", 4)
	st.scenes["lines"] = {uid: {"uid": uid, "who": "crane", "text": "Todo libro tiene precio, señor.", "origin": "S.L1.1.M", "tk": 11, "id": "gen.1", "act": ""}}
	WorldModel.sync_scene_lines(st, s.repo)
	WorldModel.sync_scene_lines(st, s.repo)
	var n := 0
	for d in s.q_diary():
		if d.kind == "line" and d.line == uid:
			n += 1
			eq(d.origin, "S.L1.1.M")
	eq(n, 1, "una vez en el diario")
	var lines: Array = s.q_scene().lines
	eq(lines[-1].uid, uid, "y en la escena en curso")
	eq(WorldModel.line(st, s.repo, uid).parsed.plain, "Todo libro tiene precio, señor.")

# Effects también retira originales recibidos (instancias P, M1 «esos originales») y HB10 «devolver» entrega ejemplares
# estáticos (no instancias): vuelven a la bandeja con su sello y una línea neutra en el diario, sin push_error.
func test_withdrawn_instance_and_returned_static_copy():
	var s = _at(3, "M")
	var st = s.st
	var repo = s.repo
	var Effects = load("res://core/react/effects.gd")
	var Diary = load("res://core/sim/diary.gd")
	Effects.init_world(st)
	var iid: String = WorldModel.instantiate_doc(st, repo, {"tpl": "x", "texto": "Le ahorraré el trabajo."}, {}, {"rid": "HA1", "doc": {"title": "Carta a máquina, matasellos S.W."}})
	WorldModel.deliver(st, repo, iid, "correo")
	ok(WorldModel.view_accessible(st, repo, iid))
	st.react.world.withdrawn[iid] = {"from_tk": TimeKey.parse("3.M"), "to_tk": TimeKey.parse("4.dawn"), "by": "R.M1.1"}
	no(WorldModel.view_accessible(st, repo, iid), "M1 se lleva también las cartas recibidas")
	no(_views(s).has(iid))
	eq(s.q_view(iid), {})
	eq(s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": iid, "part": 0, "block": 0}, "from": 0, "len": 5}).err, "inaccesible")
	st = s.st   # un apply rechazado restaura el estado
	st.react.world.withdrawn["D02@L1"] = {"from_tk": TimeKey.parse("3.M"), "to_tk": -1, "by": "R.M1.1"}
	no(_views(s).has("D02@L1"))
	# HB10: Effects borra el retiro y entrega el original estático
	st.react.world.withdrawn.erase("D02@L1")
	WorldModel.deliver(st, repo, "D02@L1", "mostrador_crane")
	ok(_views(s).has("D02@L1"), "de vuelta")
	var tray: Array = s.q_tray()
	eq(tray[-1].view, "D02@L1")
	eq(tray[-1].how, "mostrador_crane")
	var rec: Array = []
	for d in s.q_diary():
		if d.kind == "arrival" and d.view == "D02@L1":
			rec.append(d.parsed.plain)
	eq(rec, ["Jue. 29, M: Recibido: paquete en el mostrador de Crane."])
	Diary.on_arrival(st, repo, "D02@L1")
	var n := 0
	for d in s.q_diary():
		if d.kind == "arrival" and d.view == "D02@L1":
			n += 1
	eq(n, 1, "una línea por llegada")
	ok(WorldModel.view_accessible(st, repo, iid) == false, "la carta sigue fuera hasta el amanecer")
	eq(Kit.advance_to(s, 4, "M"), "")
	ok(WorldModel.view_accessible(s.st, repo, iid), "vuelve al día siguiente")

# order_copy -> respuesta L6copia (Effects pasa meta.copia_de): el sobre trae una copia P del documento pedido, legible y
# recortable en casa sin tope «de memoria», con el origen del original y su entidad como entidad de recorte.
func test_certified_copy_pages():
	var GameSim = load("res://core/sim/game_sim.gd")
	var s = GameSim.new(Kit.repo(), 7)   # módulos reales (Clipper)
	eq(Kit.advance_to(s, 7, "M"), "")
	var st = s.st
	st.now_tk = TimeKey.parse("7.dawn")
	var tpl := {"title": "Copia oficial, Somerset House", "src_type": "registro", "class": "P", "font": "imprenta", "paper": "registro",
		"paper_mm": [210, 330], "entity": "copia_oficial", "id": "R.L6copia.1", "origin": "R.L6copia.1",
		"parts": [{"id": "p1", "text": "Copia fiel, expedida a pedido de E. L., Holywell Street."}], "copies": [], "words": 9, "src_en": {}, "firma": ""}
	var iid: String = WorldModel.instantiate_doc(st, s.repo, tpl, {}, {"iid": "R.L6copia.1", "rid": "L6copia", "act": "", "how": "correo",
		"origin": "R.L6copia.1", "copia_de": "D18"})
	WorldModel.deliver(st, s.repo, iid, "correo")
	st.now_tk = -1
	var v: Dictionary = s.q_view(iid)
	eq(v.pages.size(), 2, "portada + una página por parte del original")
	eq(v.pages[0][0].parsed.plain, "Copia fiel, expedida a pedido de E. L., Holywell Street.")
	var b: Dictionary = v.pages[1][0]
	eq(b.origin, "D18", "mismo texto, mismo origen")
	eq(b.part, "copia.p1")
	eq(b.parsed.plain, s.repo.parsed("D18", "p1").plain)
	eq(WorldModel.block(st, s.repo, iid, "copia.p1", 0).origin, "D18")
	eq(WorldModel.block(st, s.repo, iid, "p1", 0).origin, "R.L6copia.1", "la portada por su id de parte")
	var ids: Array = []
	for i in 4:
		var r: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": iid, "part": 1, "block": 0}, "from": 0, "len": 6})
		ok(r.ok, "copia en casa: sin tope de memoria (%d) %s" % [i, str(r)])
		ids.append(String(r.get("clip", "")))
	var c: Dictionary = load("res://core/deduction/clipper.gd").get_clip(s.st, ids[0])
	eq(c.origin, "D18")
	eq(c.cls, "P")
	has(c.ents, "testamento", "entidad del documento copiado")

# W4: pedir nunca es gratis. Una ficha de ruido del catálogo ({doc: "", noise}) y un documento cuyo ejemplar BM no se
# sirve hoy gastan una papeleta y el ujier vuelve sin nada (view ""), como cualquier otra papeleta.
func test_w4_slip_always_costs():
	var s = _at(1, "M")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok)
	var r: Dictionary = s.apply({"t": "slip", "doc": "", "noise": "Viaje a la Luna"})
	ok(r.ok, str(r))
	eq(r.view, "", "el ujier vuelve sin nada")
	eq(s.q_slips_used(), 1, "la papeleta se gastó")
	eq(s.apply({"t": "slip", "doc": "", "noise": "Viaje a la Luna"}).err, "ya_pedido")
	eq(s.apply({"t": "slip", "doc": ""}).err, "forma", "sin documento ni rótulo")
	ok(s.apply({"t": "slip", "doc": "D05"}).ok)
	ok(s.apply({"t": "slip", "doc": "", "noise": "Otra obra"}).ok)
	eq(s.apply({"t": "slip", "doc": "D08"}).err, "sin_papeletas", "3 por visita, con o sin ejemplar")
	var noise: Array = []
	for ev in s.st.events:
		if ev.type == "slip" and String(ev.doc) == "":
			noise.append(ev)
	eq(noise.size(), 2)
	eq(noise[0].title, "Viaje a la Luna")
	eq(noise[0].topic, "otros")
	# datos reales: D16@BM se sirve desde el día 8; pedirlo el día 1 gasta la papeleta igual
	var W = load("res://tests/fixtures/w3shell/walk.gd")
	var GS = load("res://core/sim/game_sim.gd")
	var g = GS.new(repo(), 3)
	var act := func(a): return g.apply(a)
	W.errs.clear()
	W.tutorial(g, act)
	ok(bool(g.apply({"t": "sleep"}).get("ok", false)), "dormir tras el prólogo")
	ok(W.advance_to(g, act, 1, "M"), str(W.errs))
	var rg: Dictionary = g.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	ok(rg.ok, str(rg))
	var r16: Dictionary = g.apply({"t": "slip", "doc": "D16"})
	ok(r16.ok, str(r16))
	eq(String(r16.get("view", "")), "", "fuera de su ventana: no se sirve")
	eq(g.q_slips_used(), 1)
	eq(g.apply({"t": "slip", "doc": "D23"}).err, "no_esta", "un documento sin ejemplar del BM no se pide")
