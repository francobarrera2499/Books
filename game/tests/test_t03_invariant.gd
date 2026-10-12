# T3 (W2-GRAPH; GDD§10.3/§10.6, ARCHITECTURE §5.6): invariante acotada. Por conclusión: sin cortes, subconjuntos de
# K_C (≤5) × momentos {temprano, tardío, +1 D2} con D1 modelado, control (todos los cortes), factibilidad global y
# fuzzing sembrado (300 partidas; --slow: 10 000). Presupuesto: < 10 s (falla si > 20 s). Negativos: falta sólo-I,
# corte sin variante_blanda, |K_C| > 5, plan imposible.
extends "res://tests/test_base.gd"

const Inv = preload("res://core/graph/invariant.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

const TIMEOUT_S := 600.0

func _r():
	return fixture_repo("graph/base")

func _moran(id: String, corta: Array, efecto: Array, soft = null) -> Dictionary:
	return {"id": id, "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "informe", "actor": ["moran"],
		"disparador": {"evento": "report", "match": {"cat": "x"}}, "condiciones": {}, "ancla": [],
		"latencia": {"tipo": "siguiente_salida"}, "efecto": efecto,
		"rastro": [{"tpl": "x", "texto": "{{#x a:tirador e:harris|Nota del mayor.}}"}],
		"corta": corta, "agrega": [], "variante_blanda": soft}

func _flist(res: Dictionary) -> String:
	return "\n".join(PackedStringArray(res.failures))

func test_t03_fixture():
	var n := 10000 if slow else 300
	var res := Inv.t3(_r(), {"clock": Time.get_ticks_msec, "fuzz": n, "seed": 1894})
	print("T3 fixture: ok=%s, %d estados, %d ms, %d partidas de fuzzing, %d cortes suavizados por D1" % [res.ok, res.states, res.ms, res.fuzz, res.softened])
	ok(res.ok, _flist(res))
	eq(res.pending, [])
	eq(res.fuzz, n)
	ok(res.states > 10000, "estados evaluados: %d" % res.states)
	ok(res.plan.ok, "factibilidad global desde P.N")
	eq(res.k.size(), 12)
	for cid in res.k:
		ok(res.k[cid].size() <= 5, cid)
	# presupuesto (§5.6): objetivo < 10 s en modo normal (aviso), falla si > 20 s; --slow (10 000 partidas) sólo informa.
	ok(res.ms > 0, "ms medido con opts.clock")
	if not slow:
		if res.ms > 20000:
			fail("T3 tardó %d ms (> 20 s)" % res.ms)
		elif res.ms >= 10000:
			print("AVISO T3: %d ms, por encima del objetivo de 10 s (§5.6)" % res.ms)

func test_t03_deterministic():
	var a := Inv.t3(_r(), {"fuzz": 40, "seed": 7, "feasibility": false})
	var b := Inv.t3(_r(), {"fuzz": 40, "seed": 7, "feasibility": false})
	eq(a.states, b.states)
	eq(a.failures, b.failures)

func test_t03_neg_no_star_route():
	var r = _r()
	var c: Dictionary = r.conclusion("C3").duplicate(true)
	c.routes = [c.routes[3], {"id": "C3.R5", "deps": "fija", "frags": [{"ref": "D05#corniche", "copy": "D05@BM"}, {"ref": "D03#sheer", "copy": "D03@tomo"}]}]
	var res := Inv.t3(PatchRepo.new(r, {"conclusions": {"C3": c}}), {"only": ["C3"], "fuzz": 0, "feasibility": false})
	no(res.ok)
	ok(_flist(res).contains("ninguna ruta intacta es sólo-I"), _flist(res))

func _c9_with_c_route(r) -> Dictionary:
	var c: Dictionary = r.conclusion("C9").duplicate(true)
	c.routes = [c.routes[0], {"id": "C9.R3", "deps": "fija", "frags": [{"ref": "S:HC06.e"}, {"ref": "D30#recibo", "copy": "D30@L3"}]}]
	return c

func test_t03_neg_cut_without_soft_variant():
	var r = _r()
	var cut := [{"copy": "D30@L3", "ventana": {"permanente": true}}]
	var eff := [{"op": "arrancar", "copy": "D30@L3"}]
	var p = PatchRepo.new(r, {"conclusions": {"C9": _c9_with_c_route(r)}, "reactions": {"XX": _moran("XX", cut, eff, null)}})
	var res := Inv.t3(p, {"only": ["C9"], "fuzz": 60, "feasibility": false})
	no(res.ok)
	ok(_flist(res).contains("XX en 3.M viola la invariante y no tiene variante_blanda (D1)"), _flist(res))
	ok(_flist(res).contains("fuzz #"), "el fuzzing también lo detecta: " + _flist(res))
	has(res.k["C9"], "XX")
	# misma reacción con variante_blanda: D1 la aplica y la invariante se sostiene
	var q = PatchRepo.new(r, {"conclusions": {"C9": _c9_with_c_route(r)}, "reactions": {"XX": _moran("XX", cut, eff, {"efecto": [], "corta": []})}})
	var res2 := Inv.t3(q, {"only": ["C9"], "fuzz": 60, "feasibility": false})
	ok(res2.ok, _flist(res2))
	ok(res2.softened > 0, "D1 suavizó")

func test_t03_neg_soft_variant_hits_other_conclusion():
	# XS corta D29a@L4 (C2) en su forma dura; su variante blanda arranca D30@L3 (C9). D1 mira todas las conclusiones:
	# si la dura viola C2, aplica la blanda, que nadie protege en C9. Peor caso de C9 = la blanda aplicada.
	var r = _r()
	var soft := {"efecto": [{"op": "arrancar", "copy": "D30@L3"}], "corta": [{"copy": "D30@L3", "ventana": {"permanente": true}}]}
	var xs := _moran("XS", [{"copy": "D29a@L4", "ventana": {"permanente": true}}], [{"op": "retirar", "copy": "D29a@L4", "dias": null}], soft)
	var p = PatchRepo.new(r, {"conclusions": {"C9": _c9_with_c_route(r)}, "reactions": {"XS": xs}})
	var res := Inv.t3(p, {"only": ["C9"], "fuzz": 0, "feasibility": false})
	no(res.ok)
	ok(_flist(res).contains("la variante_blanda de XS en 3.M viola la invariante (D1 puede aplicarla por otra conclusión)"), _flist(res))
	has(res.k["C9"], "XS")
	# si la blanda no toca C9, nada cambia
	xs.variante_blanda = {"efecto": [], "corta": []}
	var q = PatchRepo.new(r, {"conclusions": {"C9": _c9_with_c_route(r)}, "reactions": {"XS": xs}})
	ok(Inv.t3(q, {"only": ["C9"], "fuzz": 0, "feasibility": false}).ok)

func test_t03_neg_kc_over_5():
	var r = _r()
	var patch := {}
	for i in 6:
		var id := "X%d" % i
		patch[id] = _moran(id, [{"copy": "D29a@L4", "ventana": {"dias": 1}}], [], {"efecto": [], "corta": []})
	var res := Inv.t3(PatchRepo.new(r, {"reactions": patch}), {"only": ["C2"], "fuzz": 0, "feasibility": false})
	no(res.ok)
	ok(_flist(res).contains("C2: |K_C| = 9 > 5"), _flist(res))

func test_t03_neg_infeasible_plan():
	var r = _r()
	var sch: Dictionary = r.schedule().duplicate(true)
	sch.places.L2.areas.sala.open = [{"days": [1], "slots": ["M"]}]
	var res := Inv.t3(PatchRepo.new(r, {"schedule": sch}), {"fuzz": 0})
	no(res.ok)
	ok(_flist(res).contains("factibilidad global"), _flist(res))

func test_t03_feasibility_models_resources():
	# un corte que cierra Baker Street desde el día 1 entra al plan como recurso perdido (§5.6 acotación 4): las dos
	# rutas ★ de C9 dependen de L3. D1 lo suaviza en la enumeración, pero el plan mira el peor caso de recursos.
	var r = _r()
	var xl := _moran("XL", [{"acceso": "L3", "ventana": {"permanente": true}}], [{"op": "cerrar", "target": "L3", "dias": null}], {"efecto": [], "corta": []})
	xl.disparador = {"evento": "tiempo", "tk": "1.dawn"}
	xl.latencia = {"tipo": "fija", "tk": "1.dawn"}
	var p = PatchRepo.new(r, {"reactions": {"XL": xl}})
	var res := Inv.t3(p, {"fuzz": 0})
	ok(_flist(res).contains("factibilidad global"), _flist(res))
	var res2 := Inv.t3(p, {"fuzz": 0, "feas_worst": false})
	no(_flist(res2).contains("factibilidad global"), "sin recursos el plan pasa: " + _flist(res2))

func test_t03_real_data():
	var r = repo()
	if r.conclusions().is_empty() or r.schedule().is_empty():
		pending_content("T3: data/conclusions.json o data/schedule.json sin datos (W2-STRUCT)")
		return
	var res := Inv.t3(r, {"clock": Time.get_ticks_msec, "fuzz": 10000 if slow else 300})
	print("T3 datos reales: %d estados, %d ms, %d pendientes" % [res.states, res.ms, res.pending.size()])
	for f in res.failures:
		fail(f)
	if res.ms > 20000 and not slow:
		fail("T3 tardó %d ms (> 20 s)" % res.ms)
	if res.failures.is_empty() and not res.pending.is_empty():
		pending_content("T3: conclusiones con contenido pendiente: %s" % str(res.pending.slice(0, 6)))
