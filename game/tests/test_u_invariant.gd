# Unit: core/graph/invariant.gd (CORE-EXPEDIENTE). check (§5.6) y runtime_guard (D1, §5.3/§9.8; GDD_v3 §2.2: lo que
# está en tinta, st.ded.dossier.inked, no se protege). Fixture graph/base (mismos ids que v2).
extends "res://tests/test_base.gd"

const Inv = preload("res://core/graph/invariant.gd")
const CM = preload("res://core/graph/cut_model.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const TK = preload("res://core/util/timekey.gd")
const PatchRepo = preload("res://tests/fixtures/graph/patch_repo.gd")

func _r():
	return fixture_repo("graph/base")

func _i(s: String) -> int:
	return TK.idx_of_tk(s)

func _perm(target: Dictionary) -> Dictionary:
	return {"target": target, "from_idx": 0, "to_idx": TK.idx_count() - 1, "days": -1}

func _st(day: int, slot := "M", extra := {}) -> Dictionary:
	var st := {"clock": {"day": day, "slot": slot, "phase": "desk"}, "flags": {}, "react": {"delivered": []},
		"ded": {"dossier": {"inked": {}}, "clips": {}}}
	for k in extra:
		st[k] = extra[k]
	return st

func test_check_without_cuts():
	var r = _r()
	for cid in RouteDB.mandatory(r):
		var c := Inv.check(r, cid, 0, [])
		ok(c.ok, "%s: %s" % [cid, c.reason])
	var c2 := Inv.check(r, "C2", 0, [])
	has(c2.star, "C2.R2")
	has(c2.star, "C2.R3")
	ok(c2.intact.size() >= 4)
	for k in ["ok", "intact", "star", "reason"]:
		ok(c2.has(k))

func test_check_with_cuts_and_clipped():
	var r = _r()
	var cuts := [_perm({"copy": "D05@BM"}), _perm({"copy": "D04@Crane"})]
	var c := Inv.check(r, "C2", _i("2.M"), cuts)
	no(c.ok)
	eq(c.star, [], "sin rutas sólo-I")
	ok(c.reason.contains("sólo-I"), c.reason)
	var key: String = RouteDB.route_by_id(r, "C2.R2").frags[0].key
	ok(Inv.check(r, "C2", _i("2.M"), cuts, {key: true}).ok, "recortado = obtenido")
	ok(Inv.check(r, "C2", _i("2.M"), cuts, {"D05#marque": true}).ok, "también por ref")
	var temp := [{"target": {"copy": "D05@BM"}, "from_idx": _i("2.M"), "to_idx": _i("2.N")}, {"target": {"copy": "D04@Crane"}, "from_idx": _i("2.M"), "to_idx": _i("2.N")}]
	ok(Inv.check(r, "C2", _i("2.M"), temp).ok, "un corte de un día no vence la ruta")

func test_check_late_and_pending():
	var r = _r()
	no(Inv.check(r, "C9", _i("9.N"), []).ok, "pasada la ventana de HC05, C9 no tiene 2 rutas")
	ok(Inv.check(r, "C9", _i("8.N"), []).ok)
	no(Inv.check(r, "C12", _i("10.T"), []).ok, "después de la última pasada útil")
	var bad: Dictionary = r.question("C3").duplicate(true)
	bad.variantes[0].rutas[0].frags[0].ref = "D99#x"
	var p = PatchRepo.new(r, {"questions": {"C3": bad}})
	var c := Inv.check(p, "C3", 0, [])
	no(c.ok)
	ok(c.reason.contains("pendiente"))
	ok(c.has("pending"))

func test_compile_shape():
	var r = _r()
	var comp := Inv.compile(r, "C2")
	eq(comp.last, _i("10.M"))
	eq(comp.routes.size(), 5)
	ok(comp.srcs.size() > 5)
	eq(comp.pending, [])
	ok(bool(comp.common), "invariante normal: exige ningún ejemplar común")

func test_runtime_guard_basic():
	var r = _r()
	var g := Inv.runtime_guard(_st(3), r, CM.cuts_for(r, "HB5"))
	ok(g.ok)
	eq(g.violated, [])
	var bad := [{"target": {"copy": "D05@BM"}, "rel": true, "days": -1}, {"target": {"copy": "D04@Crane"}, "rel": true, "days": -1}]
	var v := Inv.runtime_guard(_st(3), r, bad)
	no(v.ok)
	eq(v.violated, ["C2"], "C3 conserva R2 y R3")
	eq(Inv.runtime_guard(_st(3, "M", {"ded": {"dossier": {"inked": {"C2": {}}}, "clips": {}}}), r, bad).violated, [], "en tinta: no se protege")
	var clips := {"RC0001": {"origin": "D05", "tags": ["a:raspadura_registrada"]}}
	eq(Inv.runtime_guard(_st(3, "M", {"ded": {"dossier": {"inked": {}}, "clips": clips}}), r, bad).violated, [], "el recorte ya está en el cuaderno")
	var clips2 := {"RC0001": {"origin": "D05", "tags": {"a": ["cornisa_existe"]}}}
	eq(Inv.runtime_guard(_st(3, "M", {"ded": {"dossier": {"inked": {}}, "clips": clips2}}), r, bad).violated, ["C2"], "otro tramo del mismo origen no cubre")

func test_runtime_guard_uses_world_state():
	var r = _r()
	var cut_l3 := [{"target": {"place": "L3"}, "rel": true, "days": -1}]
	eq(Inv.runtime_guard(_st(4), r, cut_l3).violated, ["C9", "C13"], "C9 y C13 pierden sus rutas de Baker Street")
	var flags := {"forasteros_cerrada": true}
	var cut_c8 := [{"target": {"copy": "D13@BM"}, "rel": true, "days": -1}, {"target": {"copy": "D44@Crane"}, "rel": true, "days": -1}]
	eq(Inv.runtime_guard(_st(4), r, cut_c8).violated, [], "sin flags: C8.R3 (HC06 + D31) y C8.R4 sostienen")
	eq(Inv.runtime_guard(_st(4, "M", {"flags": flags}), r, cut_c8).violated, ["C8"], "con Forasteros cerrada (flag real) cae C8.R3")
	var delivered := {"delivered": [{"rid": "HB5", "due_tk": TK.parse("3.dawn"), "soft": false}]}
	var bad := [{"target": {"copy": "D05@BM"}, "rel": true, "days": -1}, {"target": {"copy": "D04@Crane"}, "rel": true, "days": -1}]
	eq(Inv.runtime_guard(_st(4, "M", {"react": delivered}), r, bad).violated, ["C2"])
	eq(Inv.current_idx(_st(4, "T")), _i("4.T"))
	eq(Inv.current_idx({"clock": {"day": 4, "slot": "N", "phase": "night"}}), _i("5.M"))
	eq(Inv.current_idx({"clock": {"day": 5, "slot": "dawn", "phase": "desk"}}), _i("5.M"))
	eq(Inv.active_cuts(_st(4, "M", {"react": delivered}), r).size(), 3, "corta copy + corta ruta + efecto retirar")

func test_active_cuts_from_director_runtime_cuts():
	var r = _r()
	# HB4 1.ª vez: Director no cerró nada (si_n [2]) y dejó inst.cuts = []: la consulta sigue abierta
	var hb4 := {"delivered": [{"rid": "HB4", "due_tk": TK.parse("3.dawn"), "soft": false, "cuts": []}]}
	eq(Inv.active_cuts(_st(4, "M", {"react": hb4}), r), [])
	# sin inst.cuts (instancia vieja): peor caso, cierra 2 días
	var old := {"delivered": [{"rid": "HB4", "due_tk": TK.parse("3.dawn"), "soft": false}]}
	eq(Inv.active_cuts(_st(4, "M", {"react": old}), r).size(), 2)
	# M1 con los originales informados concretos: sólo esos, no «todo P en posesión»
	var rc := [{"target": {"copy": "D02@L1"}, "from_idx": _i("3.M"), "to_idx": _i("3.N")}]
	var m1 := {"delivered": [{"rid": "M1", "due_tk": TK.parse("3.dawn"), "soft": false, "cuts": rc}]}
	eq(Inv.active_cuts(_st(3, "M", {"react": m1}), r), rc)
	# HB6 con inst.cuts: la ruta (ref) y el flag traducido siguen saliendo de cuts_for
	var hb6 := {"delivered": [{"rid": "HB6", "due_tk": TK.parse("3.dawn"), "soft": false, "cuts": [{"target": {"copy": "D30@L3"}, "from_idx": _i("3.M"), "to_idx": TK.idx_count() - 1}]}]}
	var ac := Inv.active_cuts(_st(4, "M", {"react": hb6}), r)
	var kinds: Array = []
	for c in ac:
		kinds.append(c.target.keys()[0])
	kinds.sort()
	eq(kinds, ["cond", "copy", "route"])
	# variante blanda: los cortes de la blanda
	var soft := {"delivered": [{"rid": "M1", "due_tk": TK.parse("3.dawn"), "soft": true, "cuts": []}]}
	eq(Inv.active_cuts(_st(3, "M", {"react": soft}), r), [], "M1 blanda no se lleva originales")

func test_runtime_guard_looks_ahead():
	# C3 con tres rutas sin ejemplar común de a pares: A (D05@BM + D03@Crane) ★, B (D07@Crane + D03@BM) ★,
	# C (D08@BM + D03@tomo), y C vence sola después de 4.N. Cortar B en 3.M deja A y C en 3.M (bien), pero desde 5.M
	# sólo queda A, cuando sin el corte quedaban A y B: D1 debe verlo «desde la franja actual» (§5.6), no sólo en ella.
	var r = _r()
	var c: Dictionary = r.question("C3").duplicate(true)
	var rr: Array = c.variantes[0].rutas
	c.variantes[0].rutas = [rr[0], rr[1], {"id": "C3.RX", "deps": "fija", "frags": [{"ref": "D08#kanzel", "copy": "D08@BM"}, {"ref": "D03#sheer", "copy": "D03@tomo"}]}]
	var d08: Dictionary = r.doc("D08").duplicate(true)
	d08.copies[0].to = "4.N"
	var p = PatchRepo.new(r, {"questions": {"C3": c}, "docs": {"D08": d08}})
	var cut := [{"target": {"copy": "D07@Crane"}, "rel": true, "days": -1}]
	ok(Inv.check(p, "C3", _i("3.M"), [CM.at(cut[0], _i("3.M"))]).ok, "en la franja actual sigue en pie")
	no(Inv.check(p, "C3", _i("5.M"), [CM.at(cut[0], _i("3.M"))]).ok, "más tarde no")
	ok(Inv.check(p, "C3", _i("5.M"), []).ok, "sin el corte, sí")
	eq(Inv.runtime_guard(_st(3), p, cut).violated, ["C3"])
	eq(Inv.runtime_guard(_st(5), p, cut).violated, ["C3"], "rota en la franja actual")
	# sin el vencimiento temprano de C, A y C sostienen C3: nada que proteger
	var q = PatchRepo.new(r, {"questions": {"C3": c}})
	eq(Inv.runtime_guard(_st(3), q, cut).violated, [])
	# horizonte: hasta 8.N (los días 9–10 los cubre D1 con el estado real, §12.1.9; ver resolved_informadas)
	eq(Inv.d1_until(), _i("8.N"))

func test_runtime_guard_resolved_informadas():
	# C9 con una ruta que depende de un original P (la carta de HC01): «informadas» genérico = peor caso.
	var r = _r()
	var c: Dictionary = r.question("C9").duplicate(true)
	c.variantes[0].rutas = [c.variantes[0].rutas[0], {"id": "C9.RP", "deps": "fija", "frags": [{"ref": "S:HC06.e"}, {"ref": "R:HC01.no_lo_es"}]}]
	# v3: la ruta tiene que valer (dos grupos, enlace por claves) para contar; el rastro del parche lleva el otro grupo
	var hc: Dictionary = r.reaction("HC01").duplicate(true)
	for ra in hc.rastro:
		if String(ra.get("tpl", "")) == "no_lo_es":
			ra.texto = "{{#no_lo_es a:preparativos_221b e:mycroft|No lo es, a lápiz blando y de puño firme.}}"
	var p = PatchRepo.new(r, {"questions": {"C9": c}, "reactions": {"HC01": hc}})
	var generic := [{"target": {"copies": "informadas"}, "rel": true, "days": -1}]
	eq(Inv.runtime_guard(_st(3), p, generic).violated, ["C9"], "sin resolver: todo original P puede faltar")
	var resolved := generic + [{"target": {"copy": "D02@L1"}, "from_idx": _i("3.M"), "to_idx": _i("3.N")}]
	eq(Inv.runtime_guard(_st(3), p, resolved).violated, [], "Director pasó los originales concretos: el genérico sobra")
	var chan := [{"target": {"access": "canal:K-H"}, "from_idx": 0, "to_idx": 28}]
	ok(Inv.runtime_guard(_st(3), r, chan).ok, "forma de runtime canal:K-H")
	# un corte de runtime resuelto (ventana absoluta) manda sobre el genérico de cuts_for del mismo tipo
	var gen := [{"target": {"place": "L3"}, "rel": true, "days": -1}]
	eq(Inv.runtime_guard(_st(4), r, gen).violated, ["C9", "C13"])
	var one_day := gen + [{"target": {"place": "L3"}, "from_idx": _i("4.M"), "to_idx": _i("4.N")}]
	eq(Inv.runtime_guard(_st(4), r, one_day).violated, [], "Director resolvió un día: el permanente genérico sobra")

# GDD_v3 §2.2: Q8 (desde_nacimiento) se evalúa sólo desde que puede nacer y sin la condición de ejemplar común.
func test_from_birth_invariant():
	var r = _r()
	var c: Dictionary = r.question("C9").duplicate(true)
	c["invariante"] = "desde_nacimiento"
	c.variantes[0].rutas[0]["from"] = "8.M"
	var p = PatchRepo.new(r, {"questions": {"C9": c}})
	var comp := Inv.compile(p, "C9")
	no(bool(comp.common))
	eq(int(comp.start), _i("8.M"))
	ok(Inv.check(p, "C9", _i("2.M"), []).ok, "antes de nacer no se exige nada")
	has(RouteDB.from_birth(p), "C9")
	no(RouteDB.mandatory(p).has("C9"), "fuera de la invariante normal y de D1")
