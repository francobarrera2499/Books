# T17 (W2-GRAPH; GDD§10.5/§10.6): toda pista falsa con ≥2 refutaciones alcanzables (≥2 orígenes), ninguna ⚠ (w:).
# Convención: refutación `a:refuta_<x>`; pista falsa `f:refutado` + `a:<x>`. Fixture + negativos + datos reales.
extends "res://tests/test_base.gd"

const RouteDB = preload("res://core/graph/route_db.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _doc_patch(did: String, f: Callable):
	var r = _r()
	var d: Dictionary = r.doc(did).duplicate(true)
	f.call(d)
	return PatchRepo.new(r, {"docs": {did: d}})

func _errs(p) -> String:
	return " | ".join(PackedStringArray(RouteDB.false_leads(p).errors))

func test_t17_fixture():
	var res := RouteDB.false_leads(_r())
	eq(res.errors, [])
	eq(res.leads.size(), 8)
	for x in res.leads:
		ok(res.leads[x].ok, x)
		ok(res.leads[x].origins.size() >= 2, x)
	eq(res.falsas.size(), 8)
	for f in res.falsas:
		ne(f.lead, "", f.ref)

func test_t17_neg_single_refutation():
	var p = _doc_patch("D05", func(d): d.parts[0].text = d.parts[0].text.replace("a:refuta_baston_robado ", ""))
	ok(_errs(p).contains("pista falsa 'baston_robado': 1 refutación"), _errs(p))
	ok(_errs(p).contains("R:HB2.pared.3 (f:refutado) sin refutaciones"), "la pista falsa queda sin refutar: " + _errs(p))

func test_t17_neg_warning_refutation():
	var p = _doc_patch("D34", func(d): d.parts[0].text = d.parts[0].text.replace("a:refuta_sigerson_jartum", "a:refuta_sigerson_jartum w:dudoso"))
	var e := _errs(p)
	ok(e.contains("refutación ⚠ (w:) de 'sigerson_jartum': D34#ruinas"), e)
	ok(e.contains("pista falsa 'sigerson_jartum': 1 refutación"), e)

func test_t17_neg_orphan_false_lead():
	var p = _doc_patch("D13", func(d): d.parts[0].text = d.parts[0].text.replace("a:sigerson_jartum", "a:otra_cosa"))
	ok(_errs(p).contains("D13#jartum (f:refutado) sin refutaciones"), _errs(p))

func test_t17_neg_unreachable_refutation():
	var p = _doc_patch("D35", func(d): d.copies[0].from = "10.N")
	var res := RouteDB.false_leads(p)
	ok(" | ".join(PackedStringArray(res.errors)).contains("pista falsa 'sigerson_jartum': 1 refutación"), str(res.errors))
	has(res.unreachable, "D35#califa")

func test_t17_real_data():
	var r = repo()
	if r.docs().is_empty() and r.reactions().is_empty():
		pending_content("T17: sin documentos ni reacciones en data/ (contenido de ola 3 y W2-STRUCT)")
		return
	var res := RouteDB.false_leads(r)
	for e in res.errors:
		fail(e)
	if not res.errors.is_empty():
		return
	if not res.pending.is_empty():
		pending_content("T17: %d refutaciones/orígenes sin contenido; p. ej. %s" % [res.pending.size(), str(res.pending.slice(0, 4))])
	elif res.leads.size() < 9:
		pending_content("T17: %d pistas falsas con refutaciones en data/ (GDD§10.5 lista 9)" % res.leads.size())

func test_t17_declared_list():
	# conclusions.json `_pistas_falsas` (W2-STRUCT): refs ausentes = pendientes; presentes sin etiqueta = error.
	var r = _r()
	eq(RouteDB.declared_false_leads(r), [], "el fixture no declara lista")
	var real = repo()
	for decl in RouteDB.declared_false_leads(real):
		ok(String(decl.get("id", "")).begins_with("falsa_"), str(decl))
		ok(decl.get("refutaciones", []).size() >= 2, "%s declara ≥2 refutaciones" % decl.get("id", ""))
