# Unit: core/graph/availability.gd (W2-GRAPH). §5.6: máscaras de 29 franjas, horarios, condiciones en 3 valores, fuentes.
extends "res://tests/test_base.gd"

const Av = preload("res://core/graph/availability.gd")
const CM = preload("res://core/graph/cut_model.gd")
const TK = preload("res://core/util/timekey.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _i(s: String) -> int:
	return TK.idx_of_tk(s)

func _b(s: String) -> int:
	return 1 << _i(s)

func test_fixture_loads_clean():
	eq(_r().errors(), [], "el fixture sintético de W2-GRAPH carga sin errores de esquema")

func test_bit_helpers():
	eq(Av.from_mask(0), Av.full_mask())
	eq(Av.from_mask(29), 0)
	eq(Av.from_mask(-3), Av.full_mask())
	eq(Av.range_mask(3, 5), 0b111000)
	eq(Av.range_mask(5, 3), 0)
	eq(Av.lowest(0b1000), 3)
	eq(Av.lowest(0), -1)
	eq(Av.highest(0b1011), 3)
	eq(Av.highest(0b1011, 2), 1)
	eq(Av.bits(0b101), [0, 2])
	eq(Av.idx_at_or_before("4.dawn"), _i("3.N"))
	eq(Av.idx_at_or_before("10.M"), _i("10.M"))
	eq(Av.day_bits(6), _b("6.T"))
	eq(Av.labels(_b("4.M") | _b("6.T")), "4.M,6.T")

func test_open_mask_hub_and_places():
	var r = _r()
	eq(Av.open_mask(r, "L1", "buhardilla"), Av.full_mask(), "la casa siempre está")
	var t := Av.open_mask(r, "L1", "tienda")
	eq(t & 1, 0, "la tienda está cerrada la noche del prólogo")
	ok(t & _b("10.M") != 0, "tienda abierta el día 10 (hub: el día fijo no la cierra)")
	eq(t & _b("6.T"), 0, "tienda cerrada el domingo")
	ok(Av.is_free(r, "L1", "tienda"))
	var bm := Av.open_mask(r, "L2", "*")
	ok(bm & _b("1.M") != 0)
	eq(bm & _b("6.T"), 0, "Sala de Lectura cerrada el domingo")
	eq(bm & _b("10.M"), 0, "día fijo: sin salidas")
	eq(bm & 1, 0, "prólogo: sin salidas")
	var calle := Av.open_mask(r, "L3", "calle")
	eq(calle & 1, 0, "P.N no es franja de salida aunque la ventana diga all")
	eq(calle & Av.day_bits(10), 0, "el día 10 no se sale")
	ok(calle & _b("6.T") != 0)
	eq(Av.open_mask(r, "L7", "calle"), Av.range_mask(_i("5.M"), _i("9.N")), "ventana from/to")
	eq(Av.open_mask(r, "L8", "interior"), _b("7.T") | _b("8.M") | _b("8.T") | _b("9.M") | _b("9.T"))
	eq(Av.open_mask(r, "L3", "*"), Av.open_mask(r, "L3", "calle") | Av.open_mask(r, "L3", "vestibulo") | Av.open_mask(r, "L3", "agente"))
	eq(Av.open_mask(r, "L9", "*"), 0, "lugar inexistente")
	eq(Av.open_mask(r, "L2", "nada"), 0, "área inexistente")
	ok(Av.outing_mask(r) & _b("1.M") != 0)
	eq(Av.outing_mask(r) & (1 | Av.day_bits(10)), 0)

func test_needs_with_hypothetical_flags():
	var r = _r()
	eq(Av.open_mask(r, "L5", "forasteros"), _b("8.T") | _b("8.N") | _b("9.T") | _b("9.N"))
	eq(Av.area_open(r, "L5", "forasteros", {"forasteros_cerrada": true}), 0)
	eq(Av.area_open(r, "L5", "porteria", {"forasteros_cerrada": true}), Av.open_mask(r, "L5", "porteria"))
	eq(Av.area_open(r, "L4", "consulta", {"consulta_cerrada": true}), 0)

func test_cond_mask_three_valued():
	var r = _r()
	eq(Av.cond_mask(r, {}, {}), Av.full_mask())
	eq(Av.cond_mask(r, null, {}), Av.full_mask())
	eq(Av.cond_mask(r, {"day": {"gte": 8}}, {}), Av.from_mask(_i("8.M")))
	eq(Av.cond_mask(r, {"day": 6}, {}), _b("6.T"))
	eq(Av.cond_mask(r, {"all": [{"slot": ["M"]}, {"day": 2}]}, {}), _b("2.M"))
	eq(Av.cond_mask(r, {"any": [{"day": 1}, {"day": 2}]}, {}), Av.day_bits(1) | Av.day_bits(2))
	eq(Av.cond_mask(r, {"weekday": "dom"}, {}), _b("6.T"))
	eq(Av.cond_mask(r, {"tk": {"gte": "9.T"}}, {}), Av.from_mask(_i("9.T")))
	eq(Av.cond_mask(r, {"event_count": {"type": "say", "gte": 1}}, {}), Av.full_mask(), "átomo del jugador = posible")
	eq(Av.cond_mask(r, {"not": {"event_count": {"type": "say", "gte": 1}}}, {}), Av.full_mask(), "not(desconocido) = posible")
	eq(Av.cond_mask(r, {"all": [{"day": 2}, {"visited": "L3"}]}, {}), Av.day_bits(2), "desconocido ∧ verdadero = posible")
	eq(Av.cond_mask(r, {"flag": "x"}, {}), 0)
	eq(Av.cond_mask(r, {"flag": "x"}, {"x": true}), Av.full_mask())
	eq(Av.cond_mask(r, {"not": {"flag": "x"}}, {"x": true}), 0)
	eq(Av.cond_mask(r, {"flag_eq": {"informe_final": "nada"}}, {}), 0)
	eq(Av.cond_mask(r, {"flag_gte": {"informes_vacios": 2}}, {"informes_vacios": 2}), Av.full_mask())
	eq(Av.cond_mask(r, {"channel_closed": "K-H"}, {"canal_cerrado.K-H": true}), Av.full_mask())
	eq(Av.tri({"any": [{"day": 1}, {"visited": "L3"}]}, {"day": 2, "slot": "M", "tk": 21}, {}), Av.T_U)
	eq(Av.tri({"always": false}, {"day": 2}, {}), Av.T_F)

func test_copy_sources():
	var r = _r()
	var s: Array = Av.copy_srcs(r, "D05@BM")
	eq(s.size(), 1, "área desconocida (periodicos) → las áreas de L2 en schedule (una)")
	eq(s[0].place, "L2")
	eq(s[0].area, "sala")
	eq(s[0].cls, "I")
	eq(s[0].unit.cap, "bm")
	eq(s[0].mask, Av.open_mask(r, "L2", "sala") & Av.range_mask(_i("1.M"), _i("9.N")))
	ok(Av.sub(r, "area_fallback").has("L2.periodicos"), "se registra la caída de área")
	var t: Array = Av.copy_srcs(r, "D03@tomo")
	eq(t[0].cls, "P")
	eq(t[0].unit, {}, "posesión: no exige salida")
	eq(t[0].mask, Av.full_mask())
	var c: Array = Av.copy_srcs(r, "D03@Crane")
	eq(c[0].area, "tienda")
	eq(c[0].unit, {}, "tienda de Crane: hub, no gasta franja")
	eq(c[0].mask, Av.open_mask(r, "L1", "tienda") & Av.range_mask(_i("1.M"), _i("10.M")))
	var d: Array = Av.copy_srcs(r, "D29b@L4")
	eq(d.size(), 2, "ejemplar sin área → una fuente por área del lugar")
	eq(Av.copy_srcs(r, "NO@X"), [])
	eq(Av.doc_srcs(r, "D03").size(), 3)

func test_reaction_due():
	var r = _r()
	eq(Av.react_due(r, "HC10"), [TK.parse("4.dawn")], "columna: tk fijo")
	var ha1: Array = Av.react_due(r, "HA1")
	eq(ha1[0], TK.parse("2.dawn"), "voz A: amanecer siguiente al acto más temprano")
	ok(ha1.has(TK.parse("10.dawn")), "papeleta del día 9")
	no(ha1.has(TK.parse("7.dawn")), "domingo sin papeleta (Sala cerrada)")
	eq(Av.react_due(r, "M1"), [TK.parse("3.dawn"), TK.parse("6.dawn"), TK.parse("9.dawn")], "informes 1–3 → siguiente salida")
	eq(Av.react_due(r, "D27")[0], TK.parse("2.dawn"), "telegrama: 1 día")
	eq(Av.react_due(r, "D28")[0], TK.parse("3.dawn"), "carta a Bath: 2 días")
	eq(Av.react_due(r, "HB1")[0], TK.parse("4.dawn"), "voz B: tabla voice_b")
	eq(Av.react_due(r, "HB4")[0], TK.parse("1.M"), "inmediata: en el acto")
	eq(Av.react_due(r, "NOPE"), [])
	eq(Av.due_of(r, {"tipo": "voz_b"}, TK.parse("6.T")), TK.parse("10.dawn"))
	eq(Av.due_of(r, {"tipo": "voz_b"}, TK.parse("0.N")), -1, "sin entrada en voice_b")
	eq(Av.due_of(r, {"tipo": "dias", "n": 3}, TK.parse("2.T")), TK.parse("5.dawn"))

func _react(id: String, disp: Dictionary, cond: Dictionary) -> Dictionary:
	return {"id": id, "tipo": "opcional", "lado": "mycroft", "voz": "A", "nivel": 3, "canal": "K-S", "actor": ["cotter"],
		"disparador": disp, "condiciones": cond, "ancla": [], "latencia": {"tipo": "voz_a"}, "efecto": [],
		"rastro": [{"tpl": "x", "texto": "Nada."}], "corta": [], "agrega": [], "variante_blanda": null}

func test_reaction_due_flag_gated_and_chained():
	var r = _r()
	var hb8b: Dictionary = r.reaction("HB8b").duplicate(true)
	hb8b.condiciones = {"flag": "wiggins_aliado"}
	var p = PatchRepo.new(r, {"reactions": {"HB8b": hb8b,
		"XR": _react("XR", {"evento": "reaccion", "match": {"rid": "M1"}}, {}),
		"XN": _react("XN", {"evento": "reaccion", "match": {}}, {"day": {"gte": 3}}),
		"XI": _react("XI", {"evento": "inactividad", "match": {}}, {}),
		"XS": _react("XS", {"evento": "reaccion", "match": {"rid": "XS"}}, {})}})
	# un flag que pone otra reacción (HB8 → wiggins_aliado) no impide el disparo en el peor caso
	ne(Av.react_due(p, "HB8b"), [], "HB8b condicionada a wiggins_aliado sigue pudiendo dispararse")
	eq(Av.react_due(p, "HB8b"), Av.react_due(r, "HB8b"))
	eq(Av.react_due(p, "HB8b", {"wiggins_aliado": false}), [], "con flags explícitos, exactos")
	ne(CM.timing(p, "HB8b").moments, [], "sus cortes tienen momento (T3 los ve)")
	# evento interno «reaccion»: entrega de la reacción citada + latencia propia
	eq(Av.react_due(p, "XR"), [TK.parse("4.dawn"), TK.parse("7.dawn"), TK.parse("10.dawn")], "M1 (3, 6, 9) + voz A")
	eq(Av.react_due(p, "XN")[0], TK.parse("4.dawn"), "sin rid: cualquier amanecer (cond día ≥3) + voz A")
	eq(Av.react_due(p, "XI")[0], TK.parse("2.dawn"), "inactividad desde el día 1")
	eq(Av.react_due(p, "XS"), [], "autorreferencia: sin recursión infinita")

func test_react_src_and_class():
	var r = _r()
	var s := Av.react_src(r, "HA1")
	eq(s.cls, "P")
	eq(s.mask, Av.from_mask(_i("2.M")))
	eq(s.unit.place, "L2", "la papeleta exige visitar la Sala")
	eq(Av.react_cls(r.reaction("HC10")), "I", "columna impresa")
	eq(Av.react_cls(r.reaction("M1")), "C", "rastro de nodo")
	eq(Av.react_cls(r.reaction("D27")), "P", "doc.class")
	eq(Av.react_src(r, "NOPE"), {})

func test_scene_sources():
	var r = _r()
	var m7: Array = Av.scene_srcs(r, "M7", {"id": "inteligente"})
	eq(m7[0].kind, "fixed")
	eq(m7[0].mask, Av.from_mask(_i("8.M")), "escena fija: desde su tk (7.night → 8.M) en adelante")
	eq(m7[0].unit, {})
	var hc05: Array = Av.scene_srcs(r, "HC05", {"id": "jueves_a"})
	eq(hc05[0].mask, _b("8.M") | _b("8.T") | _b("9.M") | _b("9.T"))
	eq(hc05[0].unit.place, "L3")
	eq(Av.scene_srcs(r, "NOPE", {}), [])

func test_char_silhouette_journal_sources():
	var r = _r()
	var w: Array = Av.char_srcs(r, "watson")
	eq(w.size(), 2)
	var m := 0
	for s in w:
		m |= int(s.mask)
	eq(m, Av.open_mask(r, "L4", "consulta") | _b("6.T"))
	eq(w[0].unit.cap, "q")
	var sil: Array = Av.sil_srcs(r, "wiggins")
	ok(sil.size() >= 6)
	for s in sil:
		eq(int(s.mask) & Av.range_mask(0, _i("2.N")), 0, "silueta desde el día 3 (HC02)")
		eq(s.cls, "I")
	eq(Av.sil_srcs(r, "nadie"), [])
	eq(Av.sil_channel(r, "wiggins"), "K-S")
	# "desde" relativo (M11: "+1" = el día siguiente a la entrega), no "desde el prólogo"
	var m11 := {"id": "XM", "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "columna", "actor": ["moran"],
		"disparador": {"evento": "ad", "match": {}}, "condiciones": {"day": {"gte": 5}}, "ancla": [], "latencia": {"tipo": "dias", "n": 1},
		"efecto": [{"op": "silueta", "who": "wiggins", "desde": "+1"}], "rastro": [], "corta": [], "agrega": [], "variante_blanda": null}
	var hc02: Dictionary = r.reaction("HC02").duplicate(true)
	hc02.efecto = []
	var p = PatchRepo.new(r, {"reactions": {"XM": m11, "HC02": hc02}})
	eq(Av.sil_from(p, "wiggins"), _i("7.M"), "anuncio del día 5 → entrega 6.dawn → +1 día = 7.dawn")
	var slip: Array = Av.journal_srcs(r, "slip")
	eq(slip.size(), 1)
	eq(slip[0].place, "L2")
	var go: Array = Av.journal_srcs(r, "go")
	ok(go.size() >= 7, "una fuente por lugar y área fuera de casa")
	var say: Array = Av.journal_srcs(r, "say.watson")
	eq(say[0].cls, "I", "el diario es I")
	eq(Av.journal_srcs(r, "nada"), [])
	eq(Av.plate_tb(r, "PRO"), Av.full_mask(), "lámina del prólogo: desde P.N")

# Silueta con diálogo = personaje de la visita (WorldModel.start_visit la suma a los chars): Wiggins se puede interrogar
# desde el día 3 en todo lugar que declara su silueta (data/ real; en el hub sólo en la tienda, nunca en la buhardilla).
func test_silhouette_with_dialogue_is_a_character_source():
	var r = repo()
	var w: Array = Av.char_srcs(r, "wiggins", [], "line", ".x", "C")
	# W4: sólo en las áreas de silhouettes.wiggins.talk (exteriores: tienda, calle de Baker Street, portería, Park Lane)
	eq(w.size(), 4, "una fuente por lugar y área donde se le habla: %d" % w.size())
	var places := {}
	for s in w:
		places[String(s.place)] = true
		eq(int(s.mask) & Av.range_mask(0, _i("2.night")), 0, "desde el día 3 (HC02): %s" % s.key)
		ne(String(s.area), "buhardilla", "en la buhardilla no hay visita")
		if String(s.place) != "L1":
			eq(String(s.unit.get("cap", "")), "q", "cuenta preguntas")
	var pk: Array = places.keys()
	pk.sort()
	eq(pk, ["L1", "L3", "L5", "L7"], str(pk))
	for s in w:
		ok(["tienda", "calle", "porteria", "exterior"].has(String(s.area)), "sólo exteriores: " + String(s.key))
	has(Av.all_chars(r), "wiggins")
	eq(Av.char_srcs(r, "cochero"), [], "silueta sin diálogo: no es personaje")
	var RouteDB = load("res://core/graph/route_db.gd")
	eq(String(RouteDB.resolve(r, "L:wiggins.vieja_tarifa").missing), "")
	eq(String(RouteDB.resolve(r, "L:wiggins.conduit").missing), "")

func test_frag_mask_contract():
	var r = _r()
	eq(Av.frag_mask(r, {"ref": "D05#marque", "copy": "D05@BM"}), Av.open_mask(r, "L2", "sala") & Av.range_mask(_i("1.M"), _i("9.N")))
	eq(Av.frag_mask(r, {"mask": 5}), 5)
	eq(Av.frag_mask(r, {}), 0)
	eq(Av.frag_mask(r, {"ref": "D99#nada"}), 0)

# W4-BALANCE D1: la silueta vista desde el escritorio (hub) no ancla K-S: no tiene acto «go» que citar (el recorte de la
# lámina del hub sólo lleva al muchacho; C6.R1 fallaba la condición 5). Sobre data/ real: ninguna fuente de silueta en L1.
func test_sil_srcs_skip_hub_real():
	var r = repo()
	var srcs: Array = Av.sil_srcs(r, "wiggins")
	ok(not srcs.is_empty(), "Wiggins tiene siluetas fuera del escritorio")
	for s in srcs:
		ok(String(s.get("place", "")) != Av.HUB, "silueta en el hub: %s" % str(s.get("key", "")))
