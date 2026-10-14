# Unit: core/graph/feasibility.gd (W2-GRAPH). §5.6 acotación 4: plan de salidas para ≥1 ruta ★ de cada conclusión.
extends "res://tests/test_base.gd"

const Fe = preload("res://core/graph/feasibility.gd")
const Av = preload("res://core/graph/availability.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const TK = preload("res://core/util/timekey.gd")

func _r():
	return fixture_repo("graph/base")

func _i(s: String) -> int:
	return TK.idx_of_tk(s)

func test_plan_from_start():
	var r = _r()
	var p := Fe.plan(r, 0, [], RouteDB.mandatory(r))
	ok(p.ok, str(p.unmet))
	eq(p.unmet, [])
	eq(p.routes.size(), 11, "una ruta ★ elegida por pregunta obligatoria")
	ok(p.plan.size() > 0)
	var seen := {}
	var last := -1
	for e in p.plan:
		ok(int(e.idx) > last, "franjas ordenadas y únicas")
		last = int(e.idx)
		ok(Av.outing_mask(r) & (1 << int(e.idx)) != 0, "cada visita cae en una franja con salida")
		ne(e.place, "L1", "la casa no gasta salida")
		seen[e.idx] = true
	for cid in p.routes:
		ok(RouteDB.route_by_id(r, p.routes[cid]).star, "ruta ★")

func test_plan_too_late_and_unmet():
	var r = _r()
	var late := Fe.plan(r, _i("9.T"), [], RouteDB.mandatory(r))
	no(late.ok, "con dos salidas no alcanza")
	var cut := [{"target": {"place": "L3"}, "from_idx": 0, "to_idx": TK.idx_count() - 1}]
	var p := Fe.plan(r, 0, cut, ["C9", "C2"])
	no(p.ok)
	eq(p.unmet, ["C9"], "las dos rutas ★ de C9 dependen de Baker Street")
	ok(Fe.plan(r, 0, cut, ["C2"]).ok)

func test_merge_capacities():
	var req: Array = []
	for d in ["A", "B", "C", "D"]:
		req.append({"opts": [{"place": "L2", "area": "sala", "mask": 0b110, "cap": "bm", "capk": d}], "ref": d})
	var u := Fe.merge([], req)
	eq(u.size(), 2, "3 papeletas por visita a la Sala")
	eq(u[0].bm.size(), 3)
	var q: Array = []
	for n in 4:
		q.append({"opts": [{"place": "L4", "area": "consulta", "mask": 0b1, "cap": "q", "capk": "watson"}], "ref": str(n)})
	eq(Fe.merge([], q).size(), 2, "3 preguntas por personaje y visita")
	var any := [{"opts": [{"place": "L2", "area": "sala", "mask": 0b10, "cap": "", "capk": ""}, {"place": "L3", "area": "calle", "mask": 0b100, "cap": "", "capk": ""}], "ref": "J:go"}]
	var u2 := Fe.merge([], any)
	eq(u2[0].mask, 0b110, "alternativas: cualquier franja de cualquiera")
	var u3 := Fe.merge([{"place": "L3", "area": "calle", "mask": 0b100, "bm": [], "q": {}, "refs": []}], any)
	eq(u3.size(), 1, "se funde con una visita existente")
	# varias fuentes en el MISMO lugar y área (S:HC06.b_*: una línea por canal en la Sala de Forasteros): una visita a ese
	# lugar en cualquiera de sus franjas, no «una salida cualquiera» (el bot iba a otro lado y perdía la línea)
	var same := [{"opts": [{"place": "L5", "area": "forasteros", "mask": 0b10, "cap": "", "capk": ""}, {"place": "L5", "area": "forasteros", "mask": 0b100, "cap": "", "capk": ""}], "ref": "S:HC06.b_*"}]
	var u4 := Fe.merge([], same)
	eq(u4.size(), 1)
	eq([u4[0].place, u4[0].area, u4[0].mask], ["L5", "forasteros", 0b110])

func test_match_units():
	var m = Fe.match_units([{"mask": 0b11}, {"mask": 0b01}], 0b11)
	ne(m, null)
	eq(m[0], 1)
	eq(m[1], 0)
	eq(Fe.match_units([{"mask": 1}, {"mask": 1}], 1), null)
	eq(Fe.match_units([{"mask": 0b10}], 0b01), null, "franja fuera de la ventana")

# W4-BALANCE D1b: a igual número de salidas, el plan prefiere rutas que no dependen de un acto del jugador
# (fija < columna < garantizada < opcional).
func test_plan_prefers_routes_without_player_acts():
	var F = load("res://core/graph/feasibility.gd")
	eq(F.DEPS_RANK, {"fija": 0, "columna": 1, "garantizada": 2, "opcional": 3})
	# v3: sobre el fixture del grafo (en data/ real las rutas con contenido pendiente las mide T3).
	var r = _r()
	var p: Dictionary = F.plan(r, load("res://core/util/timekey.gd").idx(1, "M"), [], RouteDB.mandatory(r))
	ok(bool(p.get("ok", false)), "plan de las obligatorias desde 1.M")
	var deps := {}
	for cid in p.get("routes", {}):
		for rt in RouteDB.routes(r, String(cid)):
			if String(rt.id) == String(p.routes[cid]):
				deps[String(cid)] = String(rt.get("deps", ""))
	ok(not deps.is_empty(), "el plan elige rutas: %s" % str(deps))
	for cid in deps:
		ok(deps[cid] != "opcional" or RouteDB.routes(r, String(cid)).all(func(x): return String(x.get("deps", "")) == "opcional" or not bool(x.eligible)), "%s: elige opcional teniendo otra: %s" % [cid, str(deps)])
