# W2-DED: Clipper (§5.1, GDD§8.1, §8.3). Fixture propio tests/fixtures/ded; estado falso con la forma de GameState.
# La accesibilidad se fija con la costura Clipper.test_access (no depende del estado de W2-SIM).
extends "res://tests/test_base.gd"

const Clipper = preload("res://core/deduction/clipper.gd")
const Index = preload("res://core/deduction/index.gd")
const J = preload("res://core/util/j.gd")
const FakeState = preload("res://tests/fixtures/ded/fake_state.gd")

var r

func before_each() -> void:
	r = fixture_repo("ded")
	Clipper.test_access = func(_st, _repo, _kind, _ref): return true

func after_each() -> void:
	Clipper.test_access = Callable()

func _st(day := 3, slot := "M"):
	var st = FakeState.new()
	st.clock = {"day": day, "slot": slot, "phase": "desk"}
	Clipper.init_state(st, r)
	return st

# [from, len] del texto `needle` en la parte `part` (índice) de la vista `view`.
func _sel(view: String, part, needle: String) -> Array:
	var cp: Dictionary = r.copy(view)
	var did: String = cp.doc if not cp.is_empty() else view
	var pid := ""
	if typeof(part) == TYPE_STRING:
		pid = part
	else:
		pid = String(r.doc(did).parts[int(part)].id)
	var plain: String = r.parsed(did, pid).plain
	var k := plain.find(needle)
	ok(k >= 0, "no encuentro «%s» en %s" % [needle, plain])
	return [k, needle.length()]

func _clip(st, view: String, part, needle: String) -> Dictionary:
	var s := _sel(view, part, needle)
	return Clipper.act_clip_text(st, r, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": part, "block": 0}, "from": s[0], "len": s[1]})

func test_fixture_is_valid():
	eq(r.errors(), [], "fixture ded")

func test_clip_text_tramo_inherits_and_indexes():
	var st = _st()
	var res := _clip(st, "D05@BM", 0, "une marque récente")
	ok(res.ok, str(res))
	var c := Clipper.get_clip(st, res.clip)
	eq(res.clip, "RC0001")
	eq(c.kind, "text")
	eq(c.tags, ["a:raspadura_registrada"])
	has(c.ents, "raspadura")
	has(c.ents, "journal_de_geneve", "entidad del documento en todo recorte")
	eq(c.origin, "D05")
	eq(c.copy, "D05@BM")
	eq(c.cls, "I")
	eq(c.tramo, "marque")
	ok(String(c.text).contains("une marque récente"), c.text)
	ok(String(c.src_line).contains("prensa extranjera"), c.src_line)
	ok(Index.has(st, "raspadura"))
	ok(Index.has(st, "journal_de_geneve"))
	var kinds: Array = st.notes.map(func(n): return n.kind)
	has(kinds, "clip")
	has(kinds, "index")

func test_snap_errors():
	var st = _st()
	var r1 := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "D05@BM", "part": 0}, "from": 3, "len": 0})
	eq(r1.get("err"), "vacio")
	var s := _sel("D03@Crane", "p1", "le pregunté. —De los")
	var r2 := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "D03@Crane", "part": "p1"}, "from": s[0], "len": s[1]})
	eq(r2.get("err"), "cruza_oracion")
	var s3 := _sel("D98@BM", 0, "Uno dos")
	var p3: String = r.parsed("D98", "p1").plain
	var r3 := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "D98@BM", "part": 0}, "from": s3[0], "len": p3.find(" Corta")})
	eq(r3.get("err"), "mas_de_15", "GDD_v3 §1.1: tope de 15 palabras")
	eq(Index.ensure(st).clips.size(), 0, "los errores no recortan")

func test_partial_cover_gives_entities_but_no_tags():
	var st = _st()
	# #corniche es largo: «Más arriba hay» cubre < 50 %
	var res := _clip(st, "D05@BM", 0, "Más arriba hay una cornisa")
	ok(res.ok, str(res))
	var c := Clipper.get_clip(st, res.clip)
	eq(c.tags, [], "menos de la mitad del tramo: sin afirmaciones")
	has(c.ents, "cornisa")
	has(c.ents, "reichenbach", "e: del tramo ganador se hereda siempre")
	var res2 := _clip(st, "D05@BM", 0, "Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que")
	eq(Clipper.get_clip(st, res2.clip).tags, ["a:cornisa_existe"])

func test_inaccesible():
	var st = _st()
	Clipper.test_access = func(_st2, _repo, _kind, _ref): return false
	var res := _clip(st, "D05@BM", 0, "une marque")
	eq(res.get("err"), "inaccesible")
	eq(Index.ensure(st).clips.size(), 0)

func test_unknown_source():
	var st = _st()
	eq(Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "D404@BM"}, "from": 0, "len": 3}).get("err"), "no_esta")
	eq(Clipper.act_clip_text(st, r, {"src": {"kind": "nada", "ref": "x"}, "from": 0, "len": 3}).get("err"), "forma")
	eq(Clipper.act_clip_text(st, r, {"src": "D05@BM", "from": 0, "len": 3}).get("err"), "forma")

func test_doc_entity_clip_entities_and_machine():
	var st = _st()
	var res := _clip(st, "D25@L1", 0, "Le ahorraré el trabajo")
	ok(res.ok, str(res))
	var c := Clipper.get_clip(st, res.clip)
	for e in ["carta_maquina", "cotter", "remington_s_alzada"]:
		has(c.ents, e)
	eq(c.cls, "P", "clase del ejemplar")
	eq(c.tags, [], "fuera de todo tramo")

func test_part_by_index_or_id_same_passage():
	var st = _st()
	var a := _clip(st, "D03@Crane", "p7", "Era un sendero de tres pies, con una pared a pique a un lado")
	var b := _clip(st, "D03@BM", 1, "Era un sendero de tres pies, con una pared a pique a un lado")
	ok(a.ok and b.ok)
	var ca := Clipper.get_clip(st, a.clip)
	var cb := Clipper.get_clip(st, b.clip)
	eq(ca.origin, cb.origin, "D03 es un solo origen aunque se recorte en Crane y en el BM")
	eq(ca.passage, cb.passage, "mismo tramo = mismo pasaje")
	ne(ca.copy, cb.copy)
	eq(ca.tags, ["a:fina_a_pique", "a:fina_impreso_sin_raspadura"])

func test_memory_mode_three_per_visit():
	var st = _st()
	st.world["visit"] = {"id": "S.L6.3.M"}
	for w in ["un tendero", "un sastre", "un coronel"]:
		ok(_clip(st, "D18@L6", 0, w).ok, w)
	eq(_clip(st, "D18@L6", 0, "un pastor").get("err"), "memoria_agotada")
	ok(_clip(st, "D05@BM", 0, "une marque").ok, "el tope es sólo para docs de memoria")
	st.world["visit"] = {"id": "S.L6.4.M"}
	ok(_clip(st, "D18@L6", 0, "un pastor").ok, "otra visita, otros tres")
	eq(Clipper.memory_count(st, "S.L6.3.M"), 3)

func test_diary_and_line_records():
	var st = _st()
	st.world["diary"] = [
		{"id": "J.1", "kind": "act", "text": "{{a:acto_ks|Martes 27, M: [[@act|Holborn]].}}", "act": "act.1"},
		{"id": "J.2", "kind": "line", "text": "{{a:vinculo_mycroft e:mycroft|Le escribí al señor Mycroft.}}", "origin": "S.L4.3.M", "who": "watson", "place": "kensington"},
	]
	var p1: Dictionary = r.parse_text(st.world.diary[0].text, {}, "act.1")
	var a := Clipper.act_clip_text(st, r, {"src": {"kind": "diary", "ref": "J.1"}, "from": 0, "len": p1.plain.length()})
	ok(a.ok, str(a))
	var ca := Clipper.get_clip(st, a.clip)
	eq(ca.origin, "D36", "acto del diario -> D36")
	eq(ca.tags, ["a:acto_ks"])
	has(ca.ents, "act.1")
	eq(Index.kind(r, "act.1"), "act_ref")
	eq(Index.label(st, r, "act.1"), "Holborn")
	var b := Clipper.act_clip_text(st, r, {"src": {"kind": "diary", "ref": "J.2"}, "from": 0, "len": 10})
	ok(b.ok, str(b))
	var cb := Clipper.get_clip(st, b.clip)
	eq(cb.origin, "S.L4.3.M", "línea dicha copiada del diario conserva el origen de su escena")
	has(cb.ents, "watson", "quien habla entra al epígrafe")
	has(cb.ents, "kensington")
	ok(String(cb.src_line).contains("el doctor Watson"), cb.src_line)
	eq(Clipper.act_clip_text(st, r, {"src": {"kind": "line", "ref": "nope"}, "from": 0, "len": 3}).get("err"), "inaccesible")

func test_scene_of_lines_and_runtime_doc_voice():
	var st = _st(8, "T")
	st.world["lines"] = {"LN.0001": {"uid": "LN.0001", "id": "c", "who": "mycroft", "text": "{{a:me_vigila_de_cerca|Mi hermano detesta los telegramas.}}",
		"scene": "HC06", "origin": "S.L5.8.T", "place": "L5", "tk": 82, "act": ""}}
	st.world["diary"] = [{"id": "DY.0001", "kind": "line", "line": "LN.0001", "text": "{{a:me_vigila_de_cerca|Mi hermano detesta los telegramas.}}", "origin": "S.L5.8.T", "who": "mycroft"}]
	var a := Clipper.act_clip_text(st, r, {"src": {"kind": "line", "ref": "LN.0001"}, "from": 0, "len": 34})
	ok(a.ok, str(a))
	eq(Clipper.get_clip(st, a.clip).scene, "HC06")
	eq(Clipper.get_clip(st, a.clip).origin, "S.L5.8.T")
	var b := Clipper.act_clip_text(st, r, {"src": {"kind": "diary", "ref": "DY.0001"}, "from": 0, "len": 34})
	eq(Clipper.get_clip(st, b.clip).scene, "HC06", "desde el diario conserva la escena de la línea")
	st.world["docs"] = {"R.HB1.1": {"id": "R.HB1.1", "rid": "HB1", "origin": "R.HB1.1",
		"blocks": [{"text": "{{#ancla a:ancla_kw a:corresponsal_s|[[@act|«A pique»]]: dele.}}", "act": "act.3"}],
		"meta": {"title": "Carta a máquina, firmada S.", "src_type": "carta_recibida", "class": "P"}}}
	st.world["acts"] = {"act.3": {"id": "act.3", "kind": "act_ref", "label": "«La pared era a pique», mar. 27"}}
	var c := Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "R.HB1.1", "part": 0, "block": 0}, "from": 0, "len": 15})
	ok(c.ok, str(c))
	var cc := Clipper.get_clip(st, c.clip)
	eq(cc.voice, "B", "voz de la reacción de origen")
	eq(cc.cls, "P")
	eq(cc.tags, ["a:ancla_kw", "a:corresponsal_s"])
	eq(cc.labels.get("act.3"), "«La pared era a pique», mar. 27", "etiqueta del acto de st.world.acts")
	eq(Index.label(st, r, "act.3"), "«La pared era a pique», mar. 27")
	eq(Clipper.act_clip_text(st, r, {"src": {"kind": "doc", "ref": "R.HB1.1", "part": 0, "block": 3}, "from": 0, "len": 5}).get("err"), "no_esta")

func test_node_examine_text_clip():
	var st = _st()
	var p: Dictionary = r.parse_text(r.plate("PRO").nodes[0].examine)
	var w: Array = load("res://devtools/bots/bot_base.gd").best_window(p, 0, p.plain.length())
	var a := Clipper.act_clip_text(st, r, {"src": {"kind": "node", "ref": "PL.prologo/harris"}, "from": int(w[0]), "len": int(w[1]) - int(w[0])})
	ok(a.ok, str(a))
	var c := Clipper.get_clip(st, a.clip)
	eq(c.origin, "PL.prologo")
	eq(c.tags, ["a:harris_es_moran"], "≥50 % del examen = recorte ajustado del nodo")
	has(c.ents, "harris")
	has(c.ents, "bigote")
	ok(String(c.src_line).contains("Prólogo"), "línea de fuente con la lámina, como el recorte por rectángulo: " + c.src_line)
	var b := Clipper.act_clip_text(st, r, {"src": {"kind": "node", "ref": "PL.prologo/harris"}, "from": 0, "len": 12})
	eq(Clipper.get_clip(st, b.clip).tags, [], "poco texto: sin etiquetas")
	eq(Clipper.act_clip_text(st, r, {"src": {"kind": "node", "ref": "PL.prologo/nadie"}, "from": 0, "len": 3}).get("err"), "no_esta")

func _plate(st, plate: String, hits: Array, touched: Array, frac := 0.05) -> Dictionary:
	return Clipper.act_clip_plate(st, r, {"t": "clip_plate", "plate": plate, "hits": hits, "touched": touched, "area_frac": frac})

func test_clip_plate_rules():
	var st = _st(3)
	st.events = [{"seq": 4, "type": "go", "place": "L2", "day": 3, "slot": "M", "act": "act.4"}]
	var plate := "PL.L2.3.M"
	var a := _plate(st, plate, [{"node": "cotter_canastilla", "cover": 0.8, "tight": true}, {"node": "cesto_tiras", "cover": 0.3, "tight": false}], ["cesto_tiras"])
	ok(a.ok, str(a))
	var c := Clipper.get_clip(st, a.clip)
	eq(c.kind, "plate")
	eq(c.tags, ["a:acto_kbm"], "etiquetas del hit de mayor cobertura, ajustado")
	eq(c.nodes, ["cotter_canastilla"], "cover < 0,5 no se captura")
	has(c.ents, "hombre_de_la_canastilla")
	ok(String(c.caption).contains("cesto") and String(c.caption).contains("hombre con canastilla"), "epígrafe con todos los tocados: " + c.caption)
	eq(c.origin, plate, "la lámina hereda el origen de la visita")
	var b := _plate(st, plate, [{"node": "cotter_canastilla", "cover": 0.9, "tight": false}], [])
	eq(Clipper.get_clip(st, b.clip).tags, [], "encuadre flojo: sin etiquetas")
	has(Clipper.get_clip(st, b.clip).ents, "hombre_de_la_canastilla", "pero con entidades")
	eq(_plate(st, plate, [], [], 0.2).get("err"), "rect_grande")
	var three := [{"node": "cotter_canastilla", "cover": 0.9, "tight": true}, {"node": "cesto_tiras", "cover": 0.7, "tight": true}, {"node": "sil_wiggins", "cover": 0.6, "tight": true}]
	eq(_plate(st, plate, three, []).get("err"), "demasiados_nodos")
	eq(_plate(st, plate, [{"node": "fantasma", "cover": 1.0, "tight": true}], []).get("err"), "no_esta")
	var e := _plate(st, plate, [], [])
	ok(e.ok, "rectángulo vacío: legal")
	eq(Clipper.get_clip(st, e.clip).tags, [])
	var s := _plate(st, plate, [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], [])
	ok(s.ok, str(s))
	var cs := Clipper.get_clip(st, s.clip)
	eq(cs.tags, ["a:ancla_ks"])
	has(cs.ents, "act.4", "entidad del acto go de esa visita")
	has(cs.ents, "muchacho_de_gorra", "sensor de «la calle»")
	ok(String(cs.caption).contains("gorra"), cs.caption)
	eq(_plate(st, "PL.L2.2.M", [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], []).get("err"), "no_esta", "Wiggins desde el día 3")
	Clipper.test_access = func(_s, _r, _k, _ref): return false
	eq(_plate(st, plate, [], []).get("err"), "inaccesible")

func test_clip_plate_uses_world_snapshot_and_node_defs():
	var st = _st(5)
	st.world["plates"] = {"PL.L2.5.T": {"id": "PL.L2.5.T", "place": "L2", "day": 5, "slot": "T", "nodes": ["cesto_tiras"],
		"silhouettes": ["cochero"], "node_defs": {"sil_cochero": {"noun": "cochero", "tags": [], "cls": "I", "ents": ["cochero"]}}}}
	eq(_plate(st, "PL.L2.5.T", [{"node": "cotter_canastilla", "cover": 0.9, "tight": true}], []).get("err"), "no_esta", "fuera de la instantánea")
	var a := _plate(st, "PL.L2.5.T", [{"node": "sil_cochero", "cover": 0.9, "tight": true}], ["cesto_tiras"])
	ok(a.ok, str(a))
	var c := Clipper.get_clip(st, a.clip)
	eq(c.tags, [])
	has(c.ents, "cochero")
	ok(String(c.caption).begins_with("cesto, cochero"), c.caption)

class FakeRepo:
	extends RefCounted
	var l := {}
	var rx := []
	func lists() -> Dictionary:
		return l
	func reactions() -> Array:
		return rx

# GDD§10.4 C6: K-S = silueta de Wiggins (HB8b cambia de muchacho, el canal sigue); las de Moran no son ojos de Holmes.
func test_sil_channel_from_placing_reaction():
	var fr := FakeRepo.new()
	fr.l = {"medios": [{"id": "la_calle", "ch": "ks"}, {"id": "sala_lectura", "ch": "kbm"}, {"id": "columna", "ch": "kt"}]}
	fr.rx = [
		{"id": "HC02", "canal": "K-S", "efecto": [{"op": "silueta", "who": "wiggins", "desde": "3.dawn"}]},
		{"id": "HB8b", "canal": "K-S", "efecto": [{"op": "silueta", "who": "muchacho_sin_gorra", "reemplaza": "wiggins"}]},
		{"id": "M3", "canal": "informe", "efecto": [{"op": "silueta", "who": "hombres_de_moran"}]},
		{"id": "M11", "canal": "columna", "efecto": [{"op": "silueta", "who": "hombre_del_abrigo"}]},
		{"id": "X", "canal": "K-BM", "efecto": [], "variante_blanda": {"efecto": [{"op": "silueta", "who": "ujier"}]}},
	]
	eq(Clipper.sil_channel(fr, "wiggins"), "ks")
	eq(Clipper.sil_channel(fr, "muchacho_sin_gorra"), "ks", "HB8b: otro muchacho, mismo canal")
	eq(Clipper.sil_channel(fr, "hombres_de_moran"), "", "M3: canal informe, no cita un acto ante Holmes")
	eq(Clipper.sil_channel(fr, "hombre_del_abrigo"), "", "M11: columna de Moran")
	eq(Clipper.sil_channel(fr, "ujier"), "kbm", "también la variante blanda pone siluetas")
	fr.rx = []
	eq(Clipper.sil_channel(fr, "wiggins"), "ks", "sin reacción: contrato §4.8 N:*.sil_wiggins")
	eq(Clipper.sil_channel(fr, "cochero"), "")

func test_sil_channel_real_data():
	var rr = repo()
	var seen := 0
	for rx in rr.reactions():
		for e in rx.get("efecto", []):
			if typeof(e) != TYPE_DICTIONARY or String(e.get("op", "")) != "silueta":
				continue
			seen += 1
			var ch := Clipper.sil_channel(rr, String(e.get("who", "")))
			if String(rx.get("lado", "")) == "moran":
				eq(ch, "", "%s: silueta de Moran sin ancla" % rx.id)
			if String(rx.get("canal", "")) == "K-S":
				eq(ch, "ks", "%s: vigía de la calle" % rx.id)
	if seen == 0:
		pending_content("data/reactions sin efecto «silueta» (W2-STRUCT)")

func test_plate_silhouettes_only_ks_watchers_anchor():
	var st = _st(5)
	st.events = [{"seq": 9, "type": "go", "place": "L2", "day": 5, "slot": "M", "act": "act.9"}]
	st.world["plates"] = {"PL.L2.5.M": {"id": "PL.L2.5.M", "place": "L2", "day": 5, "slot": "M", "nodes": [],
		"silhouettes": ["sil_wiggins", "sil_m3_hombres"], "act": "act.9"}}
	var w := _plate(st, "PL.L2.5.M", [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], [])
	eq(Clipper.get_clip(st, w.clip).tags, ["a:ancla_ks"])
	has(Clipper.get_clip(st, w.clip).ents, "act.9", "acto de la instantánea")
	var m := _plate(st, "PL.L2.5.M", [{"node": "sil_m3_hombres", "cover": 0.9, "tight": true}], [])
	ok(m.ok, str(m))
	eq(Clipper.get_clip(st, m.clip).tags, [], "una silueta que no es vigía de Holmes no es ancla de K-S")

func test_snap_origin():
	eq(Clipper.snap_origin(r, {"origin": "S.X", "place": "PRO"}, "PL.a"), "S.X", "la instantánea manda")
	eq(Clipper.snap_origin(r, {"place": "PRO", "variant": "v"}, "PRO.v"), "PL.prologo", "lámina fija (o su variante): su origin declarado (§4.11)")
	eq(Clipper.snap_origin(r, {"place": "L2"}, "PL.L2.3.M"), "PL.L2.3.M", "visita: la lámina de esa visita")
	eq(Clipper.snap_origin(r, {}, "PL.z"), "PL.z")

func test_clip_measure():
	var st = _st()
	var a := Clipper.act_clip_measure(st, r, {"src": {"kind": "doc", "ref": "D25@L1"}})
	ok(a.ok, str(a))
	var c := Clipper.get_clip(st, a.clip)
	eq(c.text, "Mide 244 por 203 milímetros.")
	eq(c.tags, ["a:me_vigila_de_cerca"])
	has(c.ents, "papel_corto")
	has(c.ents, "carta_maquina")
	eq(c.origin, "D25")
	eq(c.cls, "P")
	eq(Clipper.act_clip_measure(st, r, {"src": {"kind": "doc", "ref": "D05@BM"}}).get("err"), "sin_medida")
	eq(Clipper.act_clip_measure(st, r, {"src": {"kind": "scene", "ref": "M7"}}).get("err"), "sin_medida")

# GDD_v3 §1.1: sin pares; el cuaderno guarda recortes sueltos (el tope de 15 palabras: test_u_clip_rules, test_u_game_sim).
func test_no_pairs():
	var st = _st()
	no(Clipper.new().has_method("act_link"), "v3: sin act_link")
	no(st.ded.has("pairs"))
	var a: String = _clip(st, "D05@BM", 0, "une marque").clip
	ok(a != "")

func test_visible_hides_hidden_tags():
	var st = _st()
	var id: String = _clip(st, "D05@BM", 0, "une marque récente").clip
	var v := Clipper.visible(st, id)
	for k in ["tags", "tramo", "passage", "cls"]:
		no(v.has(k), "visible no expone " + k)
	ok(not str(v).contains("raspadura_registrada"), "ninguna etiqueta oculta en lo visible")
	eq(v.origin, "D05")
	eq(v.doc_ids, ["D05"])
	var labels := {}
	for e in v.ents:
		labels[e.id] = e.label
	eq(labels.get("raspadura"), "Raspadura", "nombre natural (playtest v2), no la forma de índice")
	eq(labels.get("journal_de_geneve"), "Journal de Genève")
	eq(Clipper.visible(st, "RC9999"), {})

func test_get_clip_is_a_copy():
	var st = _st()
	var id: String = _clip(st, "D05@BM", 0, "une marque").clip
	var c := Clipper.get_clip(st, id)
	c.tags.append("a:trampa")
	no(Clipper.get_clip(st, id).tags.has("a:trampa"))

func test_lisle_seeded_in_index():
	var st = _st()
	ok(Index.has(st, "lisle"), "«yo» está en el índice desde el principio")

func test_real_game_state_compatible():
	var GS: Script = load("res://core/sim/game_state.gd")
	var st = GS.new()
	st.clock = {"day": 1, "slot": "M", "phase": "desk"}
	Clipper.init_state(st, r)
	var res := _clip(st, "D05@BM", 0, "une marque")
	ok(res.ok, str(res))
	eq(res.clip, "RC0001")
	var s := J.stringify_canon(st.canon())
	ok(s.contains("RC0001"), "el recorte va al canon")
	ok(not s.contains("\"notes\""), "notes fuera del canon")

# Integración v3 (GDD_v3 §6.2): el recorte guarda la letra de su tramo cuando un <f=…> lo cubre (el aviso manuscrito
# de Pell al pie del encargo a máquina) y la tarjeta la usa.
func test_span_font_of_the_clipped_run():
	var p := {"plain": "Aviso a máquina. Se busca testigo.", "styles": [{"kind": "font", "from": 17, "to": 34, "val": "manuscrito"}]}
	eq(Clipper.span_font(p, 17, 34), "manuscrito", "el tramo entero en <f=manuscrito>")
	eq(Clipper.span_font(p, 10, 30), "manuscrito", "más de la mitad adentro")
	eq(Clipper.span_font(p, 0, 16), "", "fuera del estilo: la letra del documento")
	eq(Clipper.span_font({"plain": "x", "styles": []}, 0, 1), "", "sin estilos")
