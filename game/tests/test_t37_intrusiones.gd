# T37 (REACCIONES-PIEZA, GDD_v3 §4, §7.2 P2): intrusiones en la pieza con sus dos firmas, sobre los datos reales.
# Los de Holmes (HA5, HA6): por los techos y la ventana; se llevan UN original P relacionado con el acto y vuelve solo al
# amanecer siguiente con una marca a lápiz «v.». Latencia `intrusion`: K-BM/K-T al volver de esa salida (Director.on_leave),
# K-W/K-H en la primera salida del día siguiente; si Lisle no sale, de noche mientras duerme (se ve al amanecer). Una sola
# vez cada una; como mucho tres intrusiones por partida.
# Los de Moran (M1): por la puerta (cerradura, cajón, silla, ceniza sobre el escritorio); los originales informados no
# vuelven solos (HB10 los deja con Crane); como mucho dos veces. Las variantes duran hasta el final del día siguiente y
# conviven («registrada+techos»). L1: sólo lo útil es interactivo; nodos con `aviso` (examine → Q8).
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Director = preload("res://core/react/director.gd")
const Effects = preload("res://core/react/effects.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const L2_GO := {"place": "L2", "area": "sala", "streets": ["Great Russell Street"], "hour": "9:40", "seat": 214}
const L4_GO := {"place": "L4", "area": "consulta", "streets": ["Kensington High Street"], "hour": "10:10"}

func after_each() -> void:
	H.cleanup()

func _h():
	return H.new(repo())

func _tk(s: String) -> int:
	return TimeKey.parse(s)

func _slip(h, topic: String, doc: String, t: String) -> void:
	h.ev("slip", {"seat": 214, "doc": doc, "title": "el tomo pedido", "topic": topic, "hour": "10:05"}, t)

# ---------------------------------------------------------------- HA5 por K-BM (en el momento)
func test_ha5_slip_takes_fina_and_returns_with_mark() -> void:
	var h = _h()
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	eq(h.queued("HA5").size(), 1, "HA5 en cola mientras Lisle sigue en la Sala de Lectura")
	no(Effects.copy_withdrawn(h.st, "D03@tomo", _tk("3.M")), "todavía no entraron")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	var ha5: Dictionary = h.first("HA5")
	ok(not ha5.is_empty(), "HA5 entregada al volver de la salida")
	eq(int(ha5.get("delivered_tk", -1)), _tk("3.M"), "en la misma franja")
	ok(Effects.copy_withdrawn(h.st, "D03@tomo", _tk("3.M")), "falta FINA del estante (el original relacionado con la papeleta de crónicas)")
	eq(Effects.withdrawn_by(h.st, "D03@tomo", _tk("3.M")), "HA5", "quién se lo llevó (examine «missing/…»)")
	eq(Effects.place_variant(h.st, "L1", _tk("3.M")), "techos", "la ventana quedó abierta")
	var nodes := _node_ids(Effects.extra_nodes(h.st, "L1", _tk("3.M")))
	has(nodes, "ventana_abierta")
	has(nodes, "papeles_viento")
	eq(h.ids().count("HA5"), 1)
	# no es una carta: nada en la bandeja por HA5
	for dv in h.sink.deliveries:
		no(String(dv.view).begins_with("R.HA5"), "HA5 no entrega documentos")
	# vuelve solo al amanecer siguiente, con la marca a lápiz
	h.advance_to("4.dawn")
	no(Effects.copy_withdrawn(h.st, "D03@tomo", _tk("4.dawn")), "FINA vuelve al amanecer")
	var mk: Array = Effects.marcas(h.st, "D03@tomo", _tk("4.dawn"))
	eq(mk.size(), 1, "una marca al margen")
	if mk.size() == 1:
		eq(String(mk[0].texto), "v.")
		eq(String(mk[0].mano), "copista")
		ok(String(mk[0].iid).begins_with("R.HA5."), "el bloque tiene origen R.HA5.<n>: %s" % mk[0].iid)
	eq(Effects.marcas(h.st, "D03@tomo", _tk("3.T")), [], "la marca no existe antes de volver")
	var ret := false
	for r in h.sink.returns:
		if String(r.copy) == "D03@tomo":
			ret = true
	ok(ret, "WorldModel.return_copy avisado")
	eq(int(h.st.react.counters.get("techos.manana", 0)), 1, "la mañana siguiente (línea de Crane pasos_techo)")
	# la ventana sigue abierta todo el día siguiente y se cierra después
	eq(Effects.place_variant(h.st, "L1", _tk("4.T")), "techos", "hasta el final del día siguiente")
	eq(Effects.place_variant(h.st, "L1", _tk("5.M")), "", "el día 5 ya está cerrada")
	no(_node_ids(Effects.extra_nodes(h.st, "L1", _tk("5.M"))).has("ventana_abierta"), "el rastro dura lo que la variante")

func test_ha5_once_and_not_before_day3() -> void:
	var h = _h()
	h.ev("go", L2_GO, "2.M")
	_slip(h, "holmes_cronicas", "D03", "2.M")
	Director.on_leave(h.st, h.repo, "S.L2.2.M")
	eq(h.ids().count("HA5") + h.queued("HA5").size(), 0, "Wiggins trabaja desde el día 3")
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_prensa_1891", "D05", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	eq(h.ids().count("HA5"), 1, "el primer acto del día 3 (no gastó su vez el día 2)")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", _tk("3.M")), "prensa de mayo de 1891 → la prueba de imprenta (roca)")
	h.ev("go", L2_GO, "4.M")
	_slip(h, "holmes_cronicas", "D03", "4.M")
	Director.on_leave(h.st, h.repo, "S.L2.4.M")
	h.advance_to("6.T")
	eq(h.ids().count("HA5"), 1, "una sola vez en la partida")

func test_ha5_needs_a_related_original_at_home() -> void:
	var h = _h()
	h.ev("go", L2_GO, "3.M")
	_slip(h, "coronel", "D09", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	eq(h.ids().count("HA5") + h.queued("HA5").size(), 0, "papeleta del coronel: nada relacionado (Ley 7)")
	# el original relacionado ya no está en casa: no dispara y no gasta la vez
	h.st.react.world.withdrawn["D03@tomo"] = {"from_tk": _tk("3.M"), "to_tk": _tk("5.dawn"), "by": "R.X.1", "rid": "X"}
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	eq(h.ids().count("HA5") + h.queued("HA5").size(), 0, "FINA no está: no hay a qué entrar")
	h.ev("go", L2_GO, "4.M")
	_slip(h, "holmes_prensa_1891", "D05", "4.M")
	Director.on_leave(h.st, h.repo, "S.L2.4.M")
	eq(h.ids().count("HA5"), 1, "dispara con el siguiente acto que tiene su original en casa")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", _tk("4.M")))

# ---------------------------------------------------------------- HA5 por K-W (al día siguiente)
func test_ha5_watson_next_day_first_outing() -> void:
	var h = _h()
	h.ev("go", L4_GO, "3.M")
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "fina", "ents": ["fina"], "phrase": "¿Qué recuerda del sendero?"}, "3.M")
	eq(h.queued("HA5").size(), 1, "Watson se lo cuenta a Cotter esa noche")
	Director.on_leave(h.st, h.repo, "S.L4.3.M")
	eq(h.ids().count("HA5"), 0, "no ocurre el mismo día")
	h.advance_to("3.night")
	eq(h.ids().count("HA5"), 0, "ni esa noche")
	h.advance_to("4.M")
	h.ev("go", L2_GO, "4.T")
	Director.on_leave(h.st, h.repo, "S.L2.4.T")
	var ha5: Dictionary = h.first("HA5")
	eq(int(ha5.get("delivered_tk", -1)), _tk("4.T"), "en la primera salida del día siguiente")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", _tk("4.T")), "roca → la prueba de imprenta de Lisle")
	h.advance_to("5.dawn")
	no(Effects.copy_withdrawn(h.st, "D02@L1", _tk("5.dawn")))
	eq(Effects.marcas(h.st, "D02@L1").size(), 1)

func test_ha5_at_night_if_no_outing() -> void:
	var h = _h()
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "galerada", "ents": ["galerada"], "phrase": "Sus pruebas"}, "3.M")
	h.advance_to("4.night")
	eq(h.ids().count("HA5"), 0, "a las 22 h, con Lisle en el escritorio, no")
	h.advance_to("5.dawn")
	eq(int(h.first("HA5").get("delivered_tk", -1)), _tk("5.dawn"), "si Lisle no sale, de noche mientras duerme: a la mañana")
	eq(Effects.place_variant(h.st, "L1", _tk("5.dawn")), "techos")
	eq(int(h.st.react.counters.get("techos.manana", 0)), 1, "entraron de noche: la mañana siguiente (Crane oyó los pasos) es ésta")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", _tk("5.M")), "falta el día entero")
	h.advance_to("6.dawn")
	no(Effects.copy_withdrawn(h.st, "D02@L1", _tk("6.dawn")), "y vuelve al amanecer siguiente")
	eq(Effects.marcas(h.st, "D02@L1", _tk("6.dawn")).size(), 1)
	eq(int(h.st.react.counters.get("techos.manana", 0)), 1, "y no se cuenta dos veces al volver el papel")

func test_tienda_is_not_an_outing() -> void:
	var h = _h()
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L1.3.M")
	eq(h.ids().count("HA5"), 0, "subir de la tienda de Crane no es volver de una salida")

# ---------------------------------------------------------------- HA6
func test_ha6_after_ha5_takes_the_shown_original() -> void:
	var h = _h()
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	h.advance_to("4.dawn")
	# día 4: le muestra a Watson un recorte de «El intérprete griego» (cuadernillo de casa)
	h.ev("go", L4_GO, "4.M")
	h.ev("show", {"char": "watson", "item": {"kind": "clip", "doc_ids": ["D01.GREE"], "origins": ["D01.GREE"], "ents": ["mycroft", "fina"], "src_types": ["cronica"]}}, "4.M")
	Director.on_leave(h.st, h.repo, "S.L4.4.M")
	eq(h.queued("HA6").size(), 1, "HA6 en cola para la primera salida del día 5")
	h.ev("go", L2_GO, "5.M")
	Director.on_leave(h.st, h.repo, "S.L2.5.M")
	eq(h.ids().count("HA6"), 1)
	ok(Effects.copy_withdrawn(h.st, "D01.GREE@tomo", _tk("5.M")), "se llevan ese mismo original")
	h.advance_to("6.T")
	no(Effects.copy_withdrawn(h.st, "D01.GREE@tomo", _tk("6.T")), "y vuelve al amanecer")
	eq(Effects.marcas(h.st, "D01.GREE@tomo").size(), 1)
	# una sola vez
	h.ev("go", L4_GO, "7.M")
	h.ev("show", {"char": "watson", "item": {"kind": "clip", "doc_ids": ["D03"], "origins": ["D03"], "ents": ["fina"], "src_types": ["cronica"]}}, "7.M")
	h.advance_to("9.T")
	eq(h.ids().count("HA6"), 1)

func test_ha6_needs_ha5_first() -> void:
	var h = _h()
	h.ev("go", L4_GO, "3.M")
	h.ev("show", {"char": "watson", "item": {"kind": "clip", "doc_ids": ["D01.GREE"], "origins": ["D01.GREE"], "ents": ["mycroft", "fina"], "src_types": ["cronica"]}}, "3.M")
	eq(h.queued("HA6").size(), 0, "HA6 sólo después de HA5")

# ---------------------------------------------------------------- M1 (los de Moran)
func _report(h, n: int, copies: Array, t: String) -> void:
	h.ev("report", {"n": n, "mode": "items", "items": [{"kind": "clip", "cats": ["original_p"], "copies": copies, "cls": ["P"]}]}, t)

func test_m1_door_signature_and_cap() -> void:
	var h = _h()
	_report(h, 1, ["D02@L1"], "2.night")
	h.ev("go", L2_GO, "3.M")
	var m1: Dictionary = h.first("M1")
	ok(not m1.is_empty(), "M1 en la primera salida del día siguiente")
	ok(Effects.copy_withdrawn(h.st, "D02@L1", _tk("3.M")), "se llevan lo informado")
	eq(Effects.place_variant(h.st, "L1", _tk("3.M")).split("+").has("registrada"), true, "variante registrada")
	var nodes := _node_ids(Effects.extra_nodes(h.st, "L1", _tk("3.M")))
	for nid in ["ceniza_escritorio", "cerradura_rayada", "cajon_entreabierto", "silla_corrida"]:
		has(nodes, nid, "firma de la puerta")
	for nid in ["ceniza_registro", "pisada"]:
		no(nodes.has(nid), "v3: sin %s" % nid)
	for n in Effects.extra_nodes(h.st, "L1", _tk("3.M")):
		if String(n.node) == "ceniza_escritorio":
			has(n.tags, "a:entraron_por_la_puerta")
			no((n.tags as Array).has("f:secreto_camden"), "la ceniza de la puerta no es secreto de Camden")
	# no vuelven solos: HB10 (mostrador de Crane) los devuelve
	h.advance_to("4.dawn")
	var hb10: Dictionary = h.first("HB10")
	ok(not hb10.is_empty(), "HB10 los recupera")
	eq(String(hb10.get("how", "")), "mostrador_crane")
	eq(Effects.marcas(h.st, "D02@L1"), [], "los de Moran no dejan marca")
	# como mucho dos veces
	_report(h, 2, ["D03@tomo"], "4.night")
	h.ev("go", L2_GO, "5.M")
	_report(h, 3, ["D01.TWIS@tomo"], "7.night")
	h.ev("go", L2_GO, "8.M")
	h.advance_to("8.night")
	eq(h.ids().count("M1"), 2, "la tercera M1 no ocurre")
	no(Effects.copy_withdrawn(h.st, "D01.TWIS@tomo", _tk("8.M")))

func test_both_signatures_coexist() -> void:
	var h = _h()
	_report(h, 1, ["D02@L1"], "2.night")
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	eq(Effects.place_variant(h.st, "L1", _tk("3.M")), "registrada+techos", "las dos variantes a la vez")
	var pl: Dictionary = h.repo.place("L1")
	ok((pl.get("variants", {}) as Dictionary).has("registrada+techos"), "L1 define la combinación")
	eq(Effects.place_variants(h.st, "L1", _tk("3.M")), ["registrada", "techos"])

func test_effects_variant_layers_legacy_format() -> void:
	var h = _h()
	Effects.init_world(h.st)
	h.st.react.world.variants["L1"] = {"variant": "registrada", "from_tk": 30, "rid": "M1"}
	eq(Effects.place_variant(h.st, "L1"), "registrada", "registro viejo (sin capas): vale siempre")

# ---------------------------------------------------------------- L1: sólo lo útil, firmas con aviso
func test_l1_only_useful_nodes_and_signatures() -> void:
	var pl: Dictionary = repo().place("L1")
	var ids: Array = []
	for n in pl.nodes:
		if String(n.get("area", "*")) != "tienda":
			ids.append(String(n.id))
	ids.sort()
	eq(ids, ["bandeja", "calle", "cuaderno", "enfrente", "estante", "expediente", "mapa", "puerta", "tintero", "ventana"], "buhardilla: sólo lo útil")
	for gone in ["cama", "libro_mayor", "tijera", "sello", "lampara", "estufa", "pliegos", "tomos", "calendario", "silla", "cajon"]:
		no(ids.has(gone), "sin nodo %s" % gone)
	var props: Array = []
	for p in pl.props:
		props.append(String(p.id))
	for pid in ["hoja_ventana", "cortina", "traba", "expediente", "cajon", "ventana_marco"]:
		has(props, pid, "prop fijo %s" % pid)
	var v: Dictionary = pl.variants
	for vid in ["techos", "registrada", "registrada+techos"]:
		ok(v.has(vid), "variante %s" % vid)
	eq(v.techos.get("hide_nodes", []), ["ventana"], "techos esconde la ventana cerrada")
	ok(v.techos.move.has("hoja_ventana") and v.techos.move.has("cortina") and v.techos.move.has("traba"))
	near(float(v.techos.move.hoja_ventana.pos[1]) - float(_prop(pl, "hoja_ventana").pos[1]), 0.45, 0.001, "la hoja sube 0,45 m")
	near(absf(float(v.techos.move.cortina.rot[0])), 25.0, 0.01, "la cortina gira 25°")
	ok(v.registrada.move.has("silla") and v.registrada.move.has("cajon"))
	near(float(v.registrada.move.cajon.pos[2]) - float(_prop(pl, "cajon").pos[2]), 0.12, 0.001, "el cajón, 12 cm afuera")
	var avisos := {}
	for vid in ["techos", "registrada"]:
		for n in v[vid].add_nodes:
			avisos[String(n.id)] = String(n.get("aviso", ""))
	eq(avisos, {"ventana_abierta": "HA5", "papeles_viento": "HA5", "cerradura_rayada": "M1", "cajon_entreabierto": "M1",
		"silla_corrida": "M1", "ceniza_escritorio": "M1"}, "nodos con aviso (examine → Q8)")
	for vid in ["techos", "registrada"]:
		for n in v[vid].add_nodes:
			ok(String(n.examine).split(" ").size() <= 30, "%s: examen ≤ 30 palabras" % n.id)
	ok(String(_node(v.techos.add_nodes, "ventana_abierta").examine).begins_with("Está abierta. Yo no la abrí."))

func test_rastros_match_variant_nodes() -> void:
	var r = repo()
	var pl: Dictionary = r.place("L1")
	for rid in ["HA5", "HA6", "M1"]:
		for ra in r.reaction(rid).get("rastro", []):
			var ref := String(ra.get("nodo", ""))
			if not ref.begins_with("N:L1."):
				continue
			var nid := ref.substr(5)
			var nd := {}
			for vid in pl.variants:
				var x := _node(pl.variants[vid].get("add_nodes", []), nid)
				if not x.is_empty():
					nd = x
			ok(not nd.is_empty(), "%s: %s existe en una variante de L1" % [rid, ref])
			var a: Array = (ra.get("tags", []) as Array).duplicate()
			var b: Array = (nd.get("tags", []) as Array).duplicate()
			a.sort()
			b.sort()
			eq(a, b, "%s: %s etiquetas = las del nodo" % [rid, ref])

func test_ley_huella_v3() -> void:
	# toda reacción del bando de Holmes que corta agrega etiquetas de Q3, Q5 u Q8; las de Moran, de Q6, Q8, Q9 o Q10
	var r = repo()
	var want := {"holmes": ["me_vigila_de_cerca", "vinculo_mycroft", "identidad_holmes", "actividad_posterior_a_mayo_1891",
		"entro_por_los_techos", "chicos_de_holmes", "entraron_por_la_puerta", "senas_del_mayor"],
		"moran": ["rasgo_de_harris", "rasgo_de_moran", "entraron_por_la_puerta", "senas_del_mayor", "cebo", "busca_a_holmes",
		"preparativos_221b", "dia_jueves", "tirador", "escondite_preparado"]}
	for rule in r.reactions():
		if (rule.get("corta", []) as Array).is_empty():
			continue
		var side := "moran" if String(rule.lado) == "moran" else "holmes"
		var tags: Array = []
		for ra in rule.get("rastro", []):
			for t in ra.get("tags", []):
				tags.append(String(t))
			for tr in r.parse_text(String(ra.get("texto", ""))).get("tramos", []):
				for a in tr.tags.get("a", []):
					tags.append("a:" + String(a))
		var hit := false
		for t in want[side]:
			if tags.has("a:" + t):
				hit = true
		ok(hit, "%s (%s) corta y su rastro no agrega etiquetas de sus preguntas: %s" % [rule.id, side, str(tags)])

func test_no_retired_tags_in_reactions() -> void:
	var txt := ""
	for f in ["columna", "holmes", "moran", "mycroft", "respuestas"]:
		txt += FileAccess.get_file_as_string("res://data/reactions/%s.json" % f)
	for t in ["harris_es_moran", "estilo_o_rostro_moran", "estilo_cartas_coronel", "autor_moran", "N:L1.pisada", "ceniza_registro"]:
		no(txt.contains(t), "reacciones sin %s (GDD_v3 §1.8)" % t)

# ---------------------------------------------------------------- helpers
static func _node_ids(arr: Array) -> Array:
	var out: Array = []
	for n in arr:
		out.append(String(n.get("node", n.get("id", ""))))
	return out

static func _node(arr: Array, nid: String) -> Dictionary:
	for n in arr:
		if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == nid:
			return n
	return {}

static func _prop(pl: Dictionary, pid: String) -> Dictionary:
	for p in pl.props:
		if String(p.id) == pid:
			return p
	return {}

# ---------------------------------------------------------------- integración con el sim (CORE)
# Partida real: el pasivo hace el prólogo y llega al día 3; Lisle va a la Sala de Lectura, pide «El problema final» con
# una papeleta (crónicas) y vuelve: falta FINA, la ventana está abierta, la buhardilla no tiene la ventana cerrada sino la
# abierta (hide_nodes), y examinarla hace nacer Q8. Al amanecer siguiente FINA vuelve con la marca «v.» al margen.
func _sim_at_day3_desk():
	var GameSim = load("res://core/sim/game_sim.gd")
	var sim = GameSim.new(repo(), 7)
	var b = load("res://devtools/bots/bot_pasivo.gd").new()
	b.setup(sim, 7)
	for _i in 600:
		var c: Dictionary = sim.q_clock()
		if int(c.day) == 3 and String(c.slot) == "M" and String(c.phase) == "desk":
			return sim
		if int(c.day) > 3:
			break
		b.step()
	return null

func test_integration_ha5_in_game_and_q8_birth() -> void:
	if not FileAccess.get_file_as_string("res://core/sim/clock.gd").contains("on_leave"):
		pending_content("Clock.act_leave sin el gancho Director.on_leave (CORE)")
		return
	var sim = _sim_at_day3_desk()
	if sim == null:
		fail("el pasivo no llegó al día 3 por la mañana")
		return
	var g: Dictionary = sim.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	ok(bool(g.get("ok", false)), "ir a la Sala de Lectura: %s" % str(g))
	var s: Dictionary = sim.apply({"t": "slip", "doc": "D03"})
	ok(bool(s.get("ok", false)), "papeleta de «El problema final»: %s" % str(s))
	ok(not sim.q_accessible().is_empty())
	var l: Dictionary = sim.apply({"t": "leave"})
	ok(bool(l.get("ok", false)), "volver: %s" % str(l))
	var missing: Array = []
	if sim.has_method("q_missing"):
		for m in sim.q_missing():
			missing.append(String(m.copy))
	has(missing, "D03@tomo", "falta FINA del estante")
	var hub: Dictionary = sim.q_hub_plate()
	eq(String(hub.get("variant", "")), "techos", "la ventana abierta")
	has(hub.get("nodes", []), "ventana_abierta")
	no((hub.get("nodes", []) as Array).has("ventana"), "hide_nodes: la ventana cerrada no está")
	var born_before: bool = _q8_shown(sim)
	no(born_before, "Q8 no nace por ver la pieza cambiada: hay que mirar")
	var ex: Dictionary = sim.apply({"t": "examine", "ref": "hub/ventana_abierta"})
	ok(bool(ex.get("ok", false)), "examine: %s" % str(ex))
	ok(_q8_born(sim), "examinar la ventana abierta hace nacer Q8")
	# al amanecer siguiente FINA vuelve, con la marca del copista al margen (WorldModel.view arma el bloque)
	for _i in 40:
		var c: Dictionary = sim.q_clock()
		if int(c.day) >= 4 and String(c.phase) == "desk":
			break
		match String(c.phase):
			"desk": sim.apply({"t": "end_slot"})
			"visit", "scene": sim.apply({"t": "leave"})
			"night":
				if bool(sim.q_report_status().due):
					sim.apply({"t": "report_submit", "mode": "nada", "items": []})
				else:
					sim.apply({"t": "sleep"})
	eq(int(sim.q_clock().day), 4, "día 4")
	var back: Array = []
	for m in sim.q_missing():
		back.append(String(m.copy))
	no(back.has("D03@tomo"), "FINA volvió al estante")
	var v: Dictionary = sim.q_view("D03@tomo")
	var mark := false
	for pg in v.get("pages", []):
		for bl in pg:
			if String(bl.get("origin", "")).begins_with("R.HA5") and String(bl.get("parsed", {}).get("plain", "")).contains("v."):
				mark = true
	ok(mark, "la marca «v.» al margen, con origen R.HA5.<n>")

func _q8_born(sim) -> bool:
	var d = sim.st.ded.get("dossier", {}) if typeof(sim.st.ded) == TYPE_DICTIONARY else {}
	return typeof(d) == TYPE_DICTIONARY and typeof(d.get("born")) == TYPE_DICTIONARY and d.born.has("Q8")

func _q8_shown(sim) -> bool:
	return _q8_born(sim)

# El usuario: «INTRUSIONES (2-3 por partida)». Con tres cambios de la pieza ya ocurridos, ni HA6 ni otra M1.
func test_at_most_three_intrusions() -> void:
	var h = _h()
	_report(h, 1, ["D21@L1"], "2.night")
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	_report(h, 2, ["D02@L1"], "4.night")
	h.ev("go", L2_GO, "5.M")
	eq(h.ids().count("M1"), 2)
	eq(h.ids().count("HA5"), 1)
	eq(int(h.st.react.counters.get("intrusiones", 0)), 3, "tres intrusiones")
	h.ev("go", L4_GO, "7.M")
	h.ev("show", {"char": "watson", "item": {"kind": "clip", "doc_ids": ["D01.GREE"], "origins": ["D01.GREE"], "ents": ["mycroft", "fina"], "src_types": ["cronica"]}}, "7.M")
	h.advance_to("9.night")
	eq(h.ids().count("HA6") + h.queued("HA6").size(), 0, "la cuarta no ocurre")

# Verificador: el tope también vale si dos intrusiones quedaron en cola a la vez con dos ya ocurridas (HA6 por mostrar a
# Watson y la 2.ª M1 por el informe de esa noche, las dos para la primera salida del día siguiente): ocurre sólo la
# primera que se aplica; la otra no (la condición se volvía a mirar sólo al disparar).
func test_cap_holds_when_two_are_queued_together() -> void:
	var h = _h()
	_report(h, 1, ["D21@L1"], "2.night")
	h.ev("go", L2_GO, "3.M")
	_slip(h, "holmes_cronicas", "D03", "3.M")
	Director.on_leave(h.st, h.repo, "S.L2.3.M")
	eq(int(h.st.react.counters.get("intrusiones", 0)), 2, "M1 y HA5")
	h.advance_to("6.M")
	h.ev("go", L4_GO, "6.M")
	h.ev("show", {"char": "watson", "item": {"kind": "clip", "doc_ids": ["D01.GREE"], "origins": ["D01.GREE"], "ents": ["mycroft", "fina"], "src_types": ["cronica"]}}, "6.M")
	Director.on_leave(h.st, h.repo, "S.L4.6.M")
	_report(h, 2, ["D02@L1"], "6.night")
	eq(h.queued("HA6").size() + h.queued("M1").size(), 2, "las dos en cola para el día 7")
	h.advance_to("7.M")
	h.ev("go", L2_GO, "7.M")
	Director.on_leave(h.st, h.repo, "S.L2.7.M")
	h.advance_to("8.night")
	ok(int(h.st.react.counters.get("intrusiones", 0)) <= 3, "como mucho tres intrusiones (fueron %d)" % int(h.st.react.counters.get("intrusiones", 0)))
	eq(h.ids().count("HA6") + h.ids().count("M1"), 2, "ocurre una sola de las dos (M1 #1 + una)")
	eq(h.queued("HA6").size() + h.queued("M1").size(), 0, "la que sobra no queda colgada en la cola")
