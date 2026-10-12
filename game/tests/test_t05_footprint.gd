# T5 (W2-GRAPH; GDD§10.1/§10.6): ley de la huella (Holmes que corta → etiquetas de C6/C7/C8; Moran → C10/C13);
# T5' (lo que los efectos quitan ⊆ corta[], por alcanzabilidad); HB11 exige ≥2 reacciones previas del canal.
extends "res://tests/test_base.gd"

const CM = preload("res://core/graph/cut_model.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _patch(rid: String, f: Callable):
	var r = _r()
	var x: Dictionary = r.reaction(rid).duplicate(true)
	f.call(x)
	return PatchRepo.new(r, {"reactions": {rid: x}})

func test_t05_fixture():
	var r = _r()
	eq(CM.footprint(r), {"errors": [], "pending": []})
	eq(CM.derived_check(r), {"errors": [], "pending": []})
	var h := CM.hb11_check(r)
	eq(h.errors, [])
	has(h.checked, "HB11")

func test_t05_neg_holmes_without_footprint():
	var p = _patch("HB5", func(x): x.rastro = [{"tpl": "recibo", "texto": "{{#recibo a:otra_cosa e:mycroft|Prestadas a un caballero.}}"}])
	ok(str(CM.footprint(p).errors).contains("HB5 (lado mycroft) corta"), str(CM.footprint(p).errors))

func test_t05_neg_moran_without_footprint():
	var p = _patch("M5", func(x): x.rastro = [{"tpl": "chico", "texto": "{{#ayer a:me_vigila_de_cerca e:harris|Ayer vino un caballero.}}"}])
	ok(str(CM.footprint(p).errors).contains("M5 (lado moran) corta"), str(CM.footprint(p).errors))

func test_t05_neg_effect_not_declared():
	var p = _patch("HB6", func(x): x.corta = [{"copy": "D30@L3", "ventana": {"permanente": true}}])
	var e := str(CM.derived_check(p).errors)
	ok(e.contains("HB6: el efecto quita L:") and e.contains("mycroft_paga"), e)
	no(e.contains("D30#recibo"), "D30 sí figura en corta[]")
	var q = _patch("HB4", func(x): x.corta = [{"acceso": "L4.consulta", "ventana": {"dias": 1}}])
	ok(str(CM.derived_check(q).errors).contains("HB4: el efecto quita"), "ventana declarada más corta que la del efecto")
	var s = _patch("M4", func(x): x.variante_blanda = {"efecto": [{"op": "flag", "name": "pell_despedido", "value": true}], "corta": []})
	ok(str(CM.derived_check(s).errors).contains("M4 (variante_blanda): el efecto quita"), "la variante blanda también se compara")

func test_t05_neg_hb11_single_reaction():
	var p = _patch("HB11", func(x): x.disparador.n_in = [1])
	ok(str(CM.hb11_check(p).errors).contains("HB11 cierra un canal"), str(CM.hb11_check(p).errors))
	var q = _patch("HB11", func(x):
		x.disparador.erase("n_in")
		x.condiciones = {"counter": {"name": "reacciones_canal", "gte": 2}})
	eq(CM.hb11_check(q).errors, [], "una condición counter ≥ 2 también vale")

func test_t05_real_data():
	var r = repo()
	if r.reactions().is_empty():
		pending_content("T5: data/reactions/*.json sin reacciones (W2-STRUCT)")
		return
	var fp := CM.footprint(r)
	var dc := CM.derived_check(r)
	var hb := CM.hb11_check(r)
	for e in fp.errors + dc.errors + hb.errors:
		fail(e)
	var pend: Array = fp.pending + dc.pending
	if r.reaction("HB11").is_empty():
		pend.append("HB11 ausente")
	if fp.errors.is_empty() and dc.errors.is_empty() and hb.errors.is_empty() and not pend.is_empty():
		pending_content("T5: %s" % str(pend.slice(0, 5)))
