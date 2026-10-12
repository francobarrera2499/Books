# Unit: core/graph/cut_model.gd (W2-GRAPH). §4.9 corta[] + efecto[] → cortes; momentos (D2); aplicación; huecos.
extends "res://tests/test_base.gd"

const CM = preload("res://core/graph/cut_model.gd")
const Av = preload("res://core/graph/availability.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const TK = preload("res://core/util/timekey.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _i(s: String) -> int:
	return TK.idx_of_tk(s)

func _with(src: String, cuts: Array) -> Array:
	var out: Array = []
	for c in cuts:
		if c.src == src:
			out.append(c)
	return out

func test_m1_cut_and_moments():
	var r = _r()
	var cs: Array = CM.cuts_for(r, "M1")
	eq(cs.size(), 2, "corta y efecto retirar: mismo objetivo, distinto origen (T5' los compara)")
	eq(_with("corta", cs).size(), 1)
	eq(cs[0].target, {"copies": "informadas"})
	eq(cs[1].target, {"copies": "informadas"})
	eq(cs[0].days, 1)
	eq(cs[0].moments, [_i("3.M"), _i("9.M")], "más temprano y más tardío; D2 no difiere desde el día 8")
	eq(cs[0].from_idx, _i("3.M"))
	eq(cs[0].to_idx, _i("3.N"), "M1 (P, 1 día) borra sólo ese día")
	ok(cs[0].rel)
	ok(CM.has_soft(r, "M1"))
	eq(CM.cuts_for(r, "M1", true), [], "variante blanda: registra sin llevarse originales")
	eq(CM.cuts_for(r, "HC10"), [], "la columna no corta")
	eq(CM.cuts_for(r, "NOPE"), [])

func test_window_and_at():
	eq(CM.window_end(_i("5.M"), 2), _i("6.T"), "2 días desde el sábado: sábado y domingo")
	eq(CM.window_end(_i("3.M"), -1), TK.idx_count() - 1)
	eq(CM.window_end(-1, 1), -1)
	eq(CM.window_end(_i("10.N"), 3), _i("10.N"))
	var c := CM.at({"days": 1, "target": {"copy": "X"}}, _i("4.T"))
	eq(c.from_idx, _i("4.T"))
	eq(c.to_idx, _i("4.N"))

func test_d2_deferral_moment():
	var r = _r()
	var t := CM.timing(r, "HB4")
	eq(t.moments, [_i("1.M"), _i("9.M"), _i("10.M")], "nivel 3, voz A: más tardío + 1 día por D2")
	ok(CM.deferrable(r.reaction("HB4"), 5))
	no(CM.deferrable(r.reaction("M1"), 8), "exento_d2_desde_dia")
	ok(CM.deferrable(r.reaction("M1"), 3))
	no(CM.deferrable(r.reaction("HB2"), 3), "voz B nunca se difiere")
	no(CM.deferrable(r.reaction("HB6"), 3), "nivel 2")

func test_route_copy_and_flag_targets():
	var r = _r()
	var cs: Array = CM.cuts_for(r, "HB6")
	var decl := _with("corta", cs)
	eq(decl.size(), 2)
	eq(decl[0].target, {"copy": "D30@L3"})
	eq(decl[1].target.route, "C4.R5")
	eq(decl[1].target.srcs.size(), 1, "sólo la parte no-I de la ruta (la línea de Mrs. Hudson)")
	var eff := _with("efecto", cs)
	eq(eff.size(), 1, "flag hudson_cerrada → la condición {not flag} de D30 y de la línea")
	ok(eff[0].target.has("cond"))
	ne(int(eff[0].target.lost), 0)
	var hb8b := CM.cuts_for(r, "HB8b")
	eq(_with("efecto", hb8b)[0].target, {"char": "wiggins"})
	var hb11 := CM.cuts_for(r, "HB11")
	eq(hb11[0].target, {"channel": "K-H"})
	var hb4 := CM.cuts_for(r, "HB4")
	eq(hb4[0].target, {"access": "L4.consulta"})
	eq(hb4[0].days, 2)
	var m5 := CM.cuts_for(r, "M5")
	eq(m5.size(), 2, "corta copy D32@L3 + efecto arrancar D32@L3 (permanente)")
	eq(m5[1].days, -1)
	var t2 := CM.flag_targets(r, {"forasteros_cerrada": true})
	eq(t2.size(), 1)
	eq(t2[0].access, "L5.forasteros")

func test_spare_scenes():
	var r = _r()
	eq(CM.spare_scenes(r, r.reaction("HB12")), ["HC06"], "Mycroft ya dijo HC06 (a)–(f) antes del error")
	eq(CM.spare_scenes(r, r.reaction("M1")), [])
	eq(CM.cuts_for(r, "HB12")[0].spare, ["HC06"])
	eq(CM.spare_scenes(r, r.reaction("HB6")), [], "HB6 puede ocurrir el día 2: HC05 (días 8–9) todavía no se dijo")

func test_hit():
	var r = _r()
	var s: Dictionary = Av.copy_srcs(r, "D29a@L4")[0]
	ok(CM.hit({"target": {"copy": "D29a@L4"}}, s) != 0)
	eq(CM.hit({"target": {"copy": "D05@BM"}}, s), 0)
	ok(CM.hit({"target": {"access": "L4.consulta"}}, s) != 0)
	eq(CM.hit({"target": {"access": "L4.estudio"}}, s), 0)
	ok(CM.hit({"target": {"place": "L4"}}, s) != 0)
	eq(CM.hit({"target": {"access": "L4.consulta", "lost": 6}}, s), 6)
	var tomo: Dictionary = Av.copy_srcs(r, "D03@tomo")[0]
	var bm: Dictionary = Av.copy_srcs(r, "D03@BM")[0]
	ok(CM.hit({"target": {"copies": "informadas"}}, tomo) != 0, "original P")
	eq(CM.hit({"target": {"copies": "informadas"}}, bm), 0, "I nunca")
	ok(CM.hit({"target": {"copies": ["D03@tomo"]}}, tomo) != 0)
	eq(CM.hit({"target": {"copies": ["D03@BM"]}}, tomo), 0)
	var line: Dictionary = Av.src(r, RouteDB.resolve(r, "L:wiggins.conduit").srcs[0])
	ok(CM.hit({"target": {"char": "wiggins"}}, line) != 0)
	eq(CM.hit({"target": {"char": "watson"}}, line), 0)
	var hb1 := Av.react_src(r, "HB1")
	eq(CM.hit({"target": {"channel": "K-H"}}, hb1), 0, "HB1 tiene canal * (el del acto)")
	var hb6 := Av.react_src(r, "HB6")
	ok(CM.hit({"target": {"channel": "K-H"}}, hb6) != 0, "opcional de K-H")
	ok(CM.hit({"target": {"access": "canal:K-H"}}, hb6) != 0, "forma de runtime del Director")
	ok(CM.hit({"target": {"channel": "*"}}, hb6) != 0, "canal del acto: cualquiera")
	eq(CM.hit({"target": {"channel": "*"}}, hb1), 0, "HB1 tiene garantizada_si: sigue")
	ok(CM.hit({"target": {"access": "char:wiggins"}}, line) != 0)
	var sc: Dictionary = Av.src(r, RouteDB.resolve(r, "S:HC06.e").srcs[0])
	ok(CM.hit({"target": {"access": "L5.forasteros"}}, sc) != 0)
	eq(CM.hit({"target": {"access": "L5.forasteros"}, "spare": ["HC06"]}, sc), 0)

func test_apply_cuts():
	var r = _r()
	var full := Av.full_mask()
	var m := {"D29a@L4": full, "D05@BM": full}
	var c := CM.at(_with("efecto", CM.cuts_for(r, "HB5"))[0], _i("3.M"))
	var out := CM.apply_cuts(m, [c])
	eq(out["D29a@L4"], Av.range_mask(0, _i("2.N")), "permanente desde 3.M")
	eq(out["D05@BM"], full)
	eq(m["D29a@L4"], full, "no muta la entrada")
	var s: Dictionary = Av.copy_srcs(r, "D29a@L4")[0]
	var out2 := CM.apply_cuts({"x": s}, [CM.at(CM.cuts_for(r, "HB4")[0], _i("2.M"))])
	eq(int(out2.x.mask), int(s.mask) & ~Av.range_mask(_i("2.M"), _i("3.N")))
	eq(CM.apply_cuts(m, [{"target": {"copy": "D29a@L4"}, "from_idx": -1}]), m, "corte sin momento no aplica")

func _moran(id: String, corta: Array, efecto: Array) -> Dictionary:
	return {"id": id, "tipo": "opcional", "lado": "moran", "voz": "M", "nivel": 3, "canal": "informe", "actor": ["moran"],
		"disparador": {"evento": "report", "match": {"cat": "x"}}, "condiciones": {}, "ancla": [],
		"latencia": {"tipo": "dias", "n": 1}, "efecto": efecto,
		"rastro": [{"tpl": "x", "texto": "{{#x a:tirador e:harris|Nota del mayor.}}"}],
		"corta": corta, "agrega": [], "variante_blanda": {"efecto": [], "corta": []}}

func test_task_and_unknown_targets():
	var r = _r()
	var p = PatchRepo.new(r, {"reactions": {
		"XT": _moran("XT", [{"acceso": "task:seguir_chico_pell", "ventana": {"permanente": true}}], []),
		"XU": _moran("XU", [{"acceso": "L4.consultorio", "ventana": {"dias": 2}}], [{"op": "cerrar", "target": "L9", "dias": 1}])}})
	var t: Array = CM.cuts_for(p, "XT")
	eq(t[0].target, {"task": "seguir_chico_pell"}, "encargo: no es un lugar")
	var any_src: Dictionary = Av.copy_srcs(r, "D29a@L4")[0]
	eq(CM.hit(t[0], any_src), 0)
	eq(CM.hit({"target": {"access": "task:seguir_chico_pell"}}, any_src), 0, "forma de runtime del Director")
	var res := CM.static_check(p)
	var e := " | ".join(PackedStringArray(res.errors))
	ok(e.contains("XU: objetivo de corte desconocido") and e.contains("consultorio"), e)
	ok(e.contains("lugar 'L9' inexistente"), e)
	no(e.contains("XT"), "un encargo no es un objetivo desconocido")
	var nt := " | ".join(PackedStringArray(res.notes))
	ok(nt.contains("XT: corta el encargo 'seguir_chico_pell'"), nt)

func test_static_checks_clean_on_fixture():
	var r = _r()
	eq(CM.static_check(r), {"errors": [], "pending": [], "notes": []})
	eq(CM.footprint(r), {"errors": [], "pending": []})
	eq(CM.derived_check(r), {"errors": [], "pending": []})
	var h := CM.hb11_check(r)
	eq(h.errors, [])
	eq(h.checked, ["HB11"])
