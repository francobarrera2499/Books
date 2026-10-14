# Unit: core/graph/route_db.gd (CORE-EXPEDIENTE). §4.8 (refs de fragmentos), §5.6 (rutas), GDD_v3 §1.7 (preguntas con
# variantes, rutas de dos fragmentos), T1 por unidad. Fixture graph/base (las conclusiones v2 convertidas, mismos ids).
extends "res://tests/test_base.gd"

const RouteDB = preload("res://core/graph/route_db.gd")
const Av = preload("res://core/graph/availability.gd")
const TK = preload("res://core/util/timekey.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _i(s: String) -> int:
	return TK.idx_of_tk(s)

func _by(rs: Array) -> Dictionary:
	var out := {}
	for x in rs:
		out[x.id] = x
	return out

func test_routes_contract_shape():
	var r = _r()
	var rs: Array = RouteDB.routes(r, "C2")
	eq(rs.size(), 5)
	for x in rs:
		for k in ["id", "star", "deps", "from_idx", "frags"]:
			ok(x.has(k), "ruta sin " + k)
		for f in x.frags:
			for k in ["ref", "copy", "kind", "cls", "place", "area", "mask"]:
				ok(f.has(k), "fragmento sin " + k)
	var by := _by(rs)
	ok(by["C2.R2"].star)
	ok(by["C2.R3"].star)
	no(by["C2.R1"].star, "galerada P")
	no(by["C2.R4"].star, "pruebas de Watson C")
	eq(by["C2.R2"].from_idx, _i("1.M"))
	eq(by["C2.R1"].frags[0].cls, "P")
	eq(by["C2.R2"].frags[0].place, "L2")
	eq(by["C2.R2"].deps, "fija")
	ok(by["C2.R2"].eligible)
	eq(RouteDB.routes(r, "C99"), [])

# GDD_v3 §1.7: unidades = variantes; sin subrutas ni pares implícitos; «Q.B» = otra variante.
func test_units_and_variants():
	var r = _r()
	has(RouteDB.units(r), "C10")
	has(RouteDB.units(r), "C10.B")
	eq(String(RouteDB.unit(r, "C10").variant), "A")
	eq(RouteDB.routes(r, "C10").size(), 2, "la principal: Ca y Cb")
	eq(RouteDB.routes(r, "C10", "B").size(), 2)
	eq(RouteDB.routes(r, "C10.B"), RouteDB.routes(r, "C10", "B"))
	eq(RouteDB.uid_of(r, "C10", "A"), "C10")
	eq(RouteDB.route_by_id(r, "C10.Id").frags.size(), 2, "busca en todas las variantes")
	no(RouteDB.units(r).has("C6"), "C6 (pares de canal) no existe en v3")

func test_frag_contract():
	var r = _r()
	var f := RouteDB.frag(r, "D05#marque")
	eq(f.kind, "doc")
	has(f.tags, "a:raspadura_registrada")
	has(f.ents, "pared")
	has(f.ents, "journal_de_geneve")
	eq(f.origin, "D05")
	eq(f.cls, "I")
	eq(f.copies, ["D05@BM"])
	eq(f.missing, "")
	var g := RouteDB.frag(r, "D03#sheer")
	eq(g.cls, "I", "sin ejemplar: vale la mejor clase disponible")
	eq(g.copies.size(), 3)
	eq(g.exemplar, "", "varias copias: no fuerza ejemplar")

func test_ref_kinds():
	var r = _r()
	var pro := RouteDB.resolve(r, "N:PRO.harris")
	eq(pro.kind, "node")
	eq(pro.cls, "I")
	eq(pro.origin, "PL.prologo")
	eq(pro.exemplar, "lamina:PRO")
	eq(pro.mask, Av.full_mask())
	var pro2 := RouteDB.resolve(r, "N:PRO.harris", "PL.prologo")
	eq(pro2.missing, "", "copy = la lámina (§4.8, C10 Ia)")
	eq(pro2.exemplar, "lamina:PRO")
	ne(RouteDB.resolve(r, "N:PRO.harris", "D99@X").missing, "")
	var sil := RouteDB.resolve(r, "N:*.sil_wiggins")
	eq(sil.kind, "sil")
	eq(sil.tags, ["a:ancla_ks"])
	has(sil.ents, "@act")
	eq(sil.mask, Av.outing_mask(r) & Av.from_mask(_i("3.M")))
	var reg := RouteDB.resolve(r, "N:L1.registrada.ceniza_registro")
	eq(reg.missing, "")
	eq(reg.mask, Av.from_mask(_i("3.M")), "nodo de variante: desde que M1 la aplica")
	var b := RouteDB.resolve(r, "S:HC06.b_kbm")
	has(b.tags, "a:ancla_kbm")
	has(b.ents, "@act")
	eq(b.exemplar, "scene:HC06")
	var m7 := RouteDB.resolve(r, "S:M7.donde_duerme")
	eq(m7.origin, "S.M7")
	has(m7.tags, "a:busca_a_holmes")
	var hud := RouteDB.resolve(r, "L:hudson.mycroft_paga")
	eq(hud.char, "mrs_hudson", "alias L:hudson → dialogue/mrs_hudson.json")
	eq(hud.cls, "C")
	eq(hud.notes.size(), 1)
	var ha1 := RouteDB.resolve(r, "R:HA1.*")
	has(ha1.tags, "a:ancla_kbm")
	no(ha1.tags.has("e:giro_ahorrare"), "* = intersección de plantillas")
	has(ha1.tags_any, "e:giro_ahorrare")
	eq(ha1.cls, "P")
	eq(ha1.origin, "R.HA1")
	var giro := RouteDB.resolve(r, "R:HA1.giro")
	eq(giro.missing, "", "R:<rid>.<tramo>")
	has(giro.ents, "giro_ahorrare")
	var hc10 := RouteDB.resolve(r, "R:HC10.texto", "D15.0330@L1")
	eq(hc10.cls, "I")
	eq(hc10.origin, "D15.0330")
	eq(hc10.mask, Av.from_mask(_i("4.M")))
	var hb1 := RouteDB.resolve(r, "R:HB1.pared.1", "", {"ch": "kt"})
	has(hb1.tags, "a:ancla_kt")
	var j := RouteDB.resolve(r, "J:go")
	eq(j.kind, "journal")
	eq(j.origin, "D36")
	eq(j.exemplar, "")
	eq(j.tags, ["a:acto_ks"])
	var ad := RouteDB.resolve(r, "AD:prologo", "D15.0327@L1")
	eq(ad.origin, "D15.0327")
	eq(ad.tags, ["a:acto_kt"])
	var me := RouteDB.resolve(r, "M:HA1.papel")
	eq(me.tags, ["a:me_vigila_de_cerca"])
	has(me.ents, "papel_corto")

# GDD §10.1 / GDD_v3 §2.1 (Q8.R2 ★ con L:crane.pasos_techo): una línea de diálogo es C (de campo) salvo que se declare
# inmutable con "cls": "I"; entonces su fragmento y sus fuentes son I.
func test_line_declared_immutable():
	# repo propio (load_dir comparte la instancia y sus cachés del grafo con los demás tests)
	var r = load("res://core/data/data_repo.gd").fresh("res://tests/fixtures/graph/base")
	for l in r.dialogue("mrs_hudson").get("lines", []):
		if String(l.get("id", "")) == "mycroft_paga":
			l["cls"] = "I"
	var hud := RouteDB.resolve(r, "L:hudson.mycroft_paga")
	eq(hud.cls, "I", "línea declarada inmutable")
	ok(not (hud.srcs as Array).is_empty())
	for k in hud.srcs:
		eq(String(Av.src(r, String(k)).get("cls", "")), "I", "fuente I: " + String(k))
	eq(RouteDB.resolve(_r(), "L:hudson.mycroft_paga").cls, "C", "por defecto, C")

func test_scene_variant_replace_must_keep_tags():
	var r = _r()
	eq(RouteDB.resolve(r, "S:M7.inteligente").tags.has("a:harris_es_moran"), true, "el reemplazo del fixture conserva el tramo")
	var m7: Dictionary = r.scene("M7").duplicate(true)
	m7.variants[0].replace.inteligente = "Un trabajo hecho. Su procurador ya no nos sirve."
	var p = PatchRepo.new(r, {"scenes": {"M7": m7}})
	var d := RouteDB.resolve(p, "S:M7.inteligente")
	no(d.tags.has("a:harris_es_moran"), "con pell_despedido la línea pierde el tramo: no sostiene la ruta")
	has(d.tags_any, "a:harris_es_moran")

func test_missing_refs():
	var r = _r()
	for ref in ["D99#x", "D05#nada", "N:L9.x", "N:L3.nada", "S:M7.nope", "S:ZZ.a", "L:nadie.x", "L:watson.nada", "R:ZZ.x", "R:HA1.nada", "J:nada", "X:1"]:
		var d := RouteDB.resolve(r, ref)
		ne(d.missing, "", ref)
	ne(RouteDB.resolve(r, "D05#marque", "D05@Crane").missing, "", "ejemplar inexistente")
	ne(RouteDB.resolve(r, "D05#marque", "D03@BM").missing, "", "ejemplar de otro documento")

func test_lint_fixture_clean():
	var r = _r()
	for cid in RouteDB.mandatory(r):
		var l := RouteDB.lint(r, cid)
		eq(l.errors, [], cid)
		eq(l.pending, [], cid)
	# una ruta de 3 fragmentos, o de un solo origen, no pasa
	var q: Dictionary = r.question("C2").duplicate(true)
	q.variantes[0].rutas[1].frags.append({"ref": "D08#kanzel", "copy": "D08@BM"})
	ok(str(RouteDB.lint(PatchRepo.new(r, {"questions": {"C2": q}}), "C2").errors).contains("3 fragmentos"))

func test_helpers():
	var r = _r()
	eq(RouteDB.mandatory(r).size(), 11)
	eq(RouteDB.final_idx(r), _i("10.M"))
	eq(RouteDB.last_idx(r, "C12"), _i("10.M"))
	eq(RouteDB.last_idx(r, "C2"), _i("10.M"))
	eq(RouteDB.sub_channel(r, "K-BMx"), "kbm")
	eq(RouteDB.sub_channel(r, "K-T'"), "kt")
	eq(RouteDB.sub_channel(r, "Ia"), "")
	eq(RouteDB.conc_tags(r, "C2"), ["fina_impreso_sin_raspadura", "raspadura_registrada"])
	has(RouteDB.question_tags(r, "C10"), "harris_es_moran", "etiquetas de todas las variantes")
	eq(RouteDB.route_by_id(r, "C2.R4").id, "C2.R4")
	eq(RouteDB.route_by_id(r, "C2.R99"), {})

func test_linked_groups_and_common():
	var r = _r()
	var c: Dictionary = RouteDB.unit(r, "C2")
	var r2 := RouteDB.route_by_id(r, "C2.R2")
	ok(RouteDB.linked(r, c, r2.frags))
	eq(RouteDB.missing_groups(r, c, r2), [])
	var odd := [RouteDB.resolve(r, "D05#marque"), RouteDB.resolve(r, "D13#muestra97")]
	no(RouteDB.linked(r, c, odd), "sin claves comunes")
	var both := {"frags": [RouteDB.resolve(r, "D05#marque"), RouteDB.resolve(r, "D02#clausula")]}
	ok(str(RouteDB.missing_groups(r, c, both)).contains("sin_raspadura"), "dos pruebas del mismo grupo no cubren el otro")
	eq(RouteDB.common_exemplars([RouteDB.route_by_id(r, "C2.R2"), RouteDB.route_by_id(r, "C3.R1")]), ["copy:D05@BM", "copy:D03@Crane"])

func test_all_frags_universe():
	var r = _r()
	var a: Array = RouteDB.all_frags(r)
	ok(a.size() > 60, "hay %d fragmentos" % a.size())
	var refs := {}
	for d in a:
		refs[d.ref] = true
	ok(refs.has("D05#baton"))
	ok(refs.has("N:L7.azafranes"))
	ok(refs.has("S:HC06.b_kh"))
	ok(refs.has("L:wiggins.conduit"))
	ok(refs.has("R:HB2.pared.3"))

# GDD_v2 §C.5: la descripción física se cita como D#fisica (documento estático; DataRepo inyecta el tramo) y como
# R:<rid>.fisica (papel que entrega la reacción; plantilla de data/fisica.json por doc.entity).
func test_fisica_refs():
	var r = repo()
	var d := RouteDB.resolve(r, "D46#fisica", "D46@L5")
	eq(String(d.missing), "", "D46#fisica se resuelve")
	ok((d.tags as Array).has("a:vinculo_mycroft"), str(d.tags))
	ok((d.ents as Array).has("papel_crema_grueso"), str(d.ents))
	var h := RouteDB.resolve(r, "R:HA1.fisica")
	eq(String(h.missing), "", "R:HA1.fisica se resuelve")
	eq(h.tags, ["a:me_vigila_de_cerca"])
	ok((h.ents as Array).has("papel_crema_grueso"), str(h.ents))
	eq(String(h.origin), "R.HA1")
	eq(String(h.cls), "P", "la carta original es clase P")
	ok(int(h.mask) != 0, "se puede obtener")
	var x := RouteDB.resolve(r, "R:HB3.fisica")
	ok(String(x.missing) != "" or (x.tags as Array).is_empty(), "un papel sin etiquetas no aporta a ninguna conclusión")

