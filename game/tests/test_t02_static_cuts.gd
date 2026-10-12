# T2 (W2-GRAPH; GDD§10.1/§10.6, D9): ningún efecto ni corte apunta a un ejemplar I, ni corta una ruta sólo-I, ni cierra
# la única fuente de un fragmento I (lugar, área, canal o personaje). Fixture + negativos + datos reales.
extends "res://tests/test_base.gd"

const CM = preload("res://core/graph/cut_model.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _moran(id: String, corta: Array, efecto: Array) -> Dictionary:
	return {"id": id, "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "informe", "actor": ["moran"],
		"disparador": {"evento": "report", "match": {"cat": "x"}}, "condiciones": {}, "ancla": [],
		"latencia": {"tipo": "siguiente_salida"}, "efecto": efecto,
		"rastro": [{"tpl": "x", "texto": "{{#x a:tirador e:harris|Nota del mayor.}}"}],
		"corta": corta, "agrega": [], "variante_blanda": {"efecto": [], "corta": []}}

func _errs(p) -> String:
	return str(CM.static_check(p).errors)

func test_t02_fixture():
	var res := CM.static_check(_r())
	eq(res.errors, [])
	eq(res.pending, [])

func test_t02_neg_points_to_I_copy():
	var p = PatchRepo.new(_r(), {"reactions": {"XA": _moran("XA", [{"copy": "D05@BM", "ventana": {"dias": 1}}], [{"op": "retirar", "copy": "D05@BM", "dias": 1}])}})
	var e := _errs(p)
	ok(e.contains("apunta al ejemplar I D05@BM"), e)
	ok(e.contains("cierra la única fuente de D05#marque"), e)

func test_t02_neg_only_source_place():
	var p = PatchRepo.new(_r(), {"reactions": {"XB": _moran("XB", [{"acceso": "L7.calle", "ventana": {"dias": 1}}], [{"op": "cerrar", "target": "L7.calle", "dias": 1}])}})
	ok(_errs(p).contains("cierra la única fuente de N:L7.linea_de_tiro"), _errs(p))

func test_t02_neg_cuts_star_route():
	var p = PatchRepo.new(_r(), {"reactions": {"XC": _moran("XC", [{"ref": "C2.R2", "ventana": {"dias": 1}}], [])}})
	ok(_errs(p).contains("corta la ruta sólo-I C2.R2"), _errs(p))

func test_t02_spare_needs_trigger_place():
	var r = _r()
	var hb12: Dictionary = r.reaction("HB12").duplicate(true)
	hb12.disparador = {"evento": "go", "match": {"place": "L2"}}
	var p = PatchRepo.new(r, {"reactions": {"HB12": hb12}})
	var e := _errs(p)
	ok(e.contains("única fuente de S:HC06"), "sin estar en la Sala de Forasteros, cerrarla corta HC06: " + e)

func test_t02_neg_flag_closes_later_scene():
	# HC05 (I, días 8–9) callada por hudson_cerrada (HB6, primera visita a 221B): HB6 cierra la única fuente de una
	# línea I aunque el acto disparador ocurra en el mismo lugar (sus líneas todavía no se dijeron).
	var r = _r()
	var hc05: Dictionary = r.scene("HC05").duplicate(true)
	hc05.lines[0]["when"] = {"not": {"flag": "hudson_cerrada"}}
	var p = PatchRepo.new(r, {"scenes": {"HC05": hc05}})
	ok(_errs(p).contains("HB6: ") and _errs(p).contains("cierra la única fuente de S:HC05.jueves_a"), _errs(p))

func test_t02_neg_unknown_target():
	var p = PatchRepo.new(_r(), {"reactions": {"XE": _moran("XE", [{"acceso": "L5.forastero", "ventana": {"permanente": true}}], [])}})
	ok(_errs(p).contains("XE: objetivo de corte desconocido"), "un acceso mal escrito no corta nada en silencio: " + _errs(p))

func test_t02_pending_missing_copy():
	var p = PatchRepo.new(_r(), {"reactions": {"XD": _moran("XD", [{"copy": "D77@L3", "ventana": {"dias": 1}}], [])}})
	var res := CM.static_check(p)
	ok(str(res.pending).contains("D77@L3"), str(res.pending))

func test_t02_real_data():
	var r = repo()
	if r.reactions().is_empty():
		pending_content("T2: data/reactions/*.json sin reacciones (W2-STRUCT)")
		return
	var res := CM.static_check(r)
	for n in res.notes:
		print("T2 nota: ", n)
	for e in res.errors:
		fail(e)
	if res.errors.is_empty() and not res.pending.is_empty():
		pending_content("T2: %s" % str(res.pending.slice(0, 5)))
