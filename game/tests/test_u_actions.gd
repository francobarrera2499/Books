# W2-SIM: catálogo de acciones (§3.5): normalize, shape_error, is_commit, fases.
extends "res://tests/test_base.gd"

const Actions = preload("res://core/sim/actions.gd")
const J = preload("res://core/util/j.gd")

const ALL := ["clip_text", "clip_plate", "clip_measure", "link", "unlink", "folio_open", "entry_new", "entry_set",
	"entry_support_add", "entry_support_remove", "entry_delete", "practice", "pass_clean", "go", "slip", "order_copy",
	"ask", "assert", "present", "pay", "task", "leave", "end_slot", "compose_ad", "compose_telegram", "compose_letter",
	"report_submit", "sleep", "confront", "night_choice", "publish_errata"]
const COMMITTED := ["pass_clean", "go", "slip", "order_copy", "ask", "assert", "present", "pay", "task", "leave", "end_slot",
	"compose_ad", "compose_telegram", "compose_letter", "report_submit", "sleep", "confront", "night_choice", "publish_errata"]
const FREE_T := ["clip_text", "clip_plate", "clip_measure", "link", "unlink", "folio_open", "entry_new", "entry_set",
	"entry_support_add", "entry_support_remove", "entry_delete", "practice"]

func test_spec_covers_table():
	var ks: Array = Actions.types()
	for t in ALL:
		has(ks, t, "SPEC")
	eq(ks.size(), ALL.size(), str(ks))

func test_commit_flags():
	for t in ALL:
		eq(Actions.is_commit(t), COMMITTED.has(t), t)
	no(Actions.is_commit("nada"))

func test_free_actions_everywhere_but_done():
	for t in FREE_T:
		var ph: Array = Actions.phases_of(t)
		no(ph.has("done"), t)
		for p in ["prologue", "desk", "visit", "scene", "night", "confront", "final_report", "parklane", "night_choice", "epilogue"]:
			has(ph, p, t)

func test_phases_of_committed():
	eq(Actions.phases_of("go"), ["desk"])
	eq(Actions.phases_of("pass_clean"), ["desk", "final_report"])
	eq(Actions.phases_of("sleep"), ["prologue", "night"])
	eq(Actions.phases_of("report_submit"), ["night", "final_report"])
	has(Actions.phases_of("compose_ad"), "prologue", "el aviso del prólogo")
	no(Actions.phases_of("compose_telegram").has("prologue"))
	for t in ["slip", "order_copy", "ask", "assert", "present", "pay", "task"]:
		eq(Actions.phases_of(t), ["visit"], t)

func test_normalize_casts_and_sorts():
	var a := {"seat": 214.0, "t": "go", "place": "L2", "basura": 1}
	var n := Actions.normalize(a)
	eq(n, {"area": "", "place": "L2", "seat": 214, "t": "go"})
	eq(typeof(n.seat), TYPE_INT)
	eq(n.keys(), ["area", "place", "seat", "t"], "claves ordenadas")
	var c := Actions.normalize({"t": "clip_text", "len": 12.0, "from": 3.0, "src": {"ref": "D05@BM", "kind": "doc", "part": 0.0, "block": 1.0}})
	eq(typeof(c.from), TYPE_INT)
	eq(typeof(c.src.part), TYPE_INT, "enteros anidados")
	eq(c.src.keys(), ["block", "kind", "part", "ref"])
	var p := Actions.normalize({"t": "clip_plate", "plate": "PL.L4.3.M", "hits": [{"node": "x", "cover": 1.0, "tight": true}], "area_frac": 0})
	eq(typeof(p.area_frac), TYPE_FLOAT, "float declarado")
	eq(p.touched, [], "opcional completado")

func test_normalize_idempotent_and_json_roundtrip():
	var samples := [
		{"t": "go", "place": "L2", "area": "sala", "seat": 214},
		{"t": "clip_plate", "plate": "P", "hits": [{"node": "n", "cover": 0.75, "tight": false}], "touched": ["n", "m"], "area_frac": 0.1},
		{"t": "confront", "step": 2},
		{"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}},
		{"t": "report_submit", "mode": "nada"},
		{"t": "publish_errata", "yes": true},
	]
	for a in samples:
		var n := Actions.normalize(a)
		eq(Actions.normalize(n), n, "idempotente " + str(a))
		var back = Actions.normalize(J.parse_str(J.stringify_canon(n)))
		eq(J.stringify_canon(back), J.stringify_canon(n), "ida y vuelta JSON " + str(a))
		eq(back, n, "igual en memoria " + str(a))

func test_shape_errors():
	eq(Actions.shape_error({"t": "nada"}), "accion_desconocida")
	eq(Actions.shape_error(Actions.normalize({"t": "slip"})), "falta:doc")
	eq(Actions.shape_error(Actions.normalize({"t": "slip", "doc": 5})), "tipo:doc")
	eq(Actions.shape_error(Actions.normalize({"t": "go", "place": "L2", "seat": 1.5})), "tipo:seat")
	eq(Actions.shape_error(Actions.normalize({"t": "go", "place": "L2"})), "")
	eq(Actions.shape_error(Actions.normalize({"t": "confront", "step": 1})), "", "item opcional = callar")
	eq(Actions.shape_error(Actions.normalize({"t": "publish_errata", "yes": "si"})), "tipo:yes")
	eq(Actions.shape_error(Actions.normalize({"t": "leave"})), "")
