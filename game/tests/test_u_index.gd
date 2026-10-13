# W2-DED: índice del jugador (GDD§8.2). Fixture tests/fixtures/ded.
extends "res://tests/test_base.gd"

const Index = preload("res://core/deduction/index.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const FakeState = preload("res://tests/fixtures/ded/fake_state.gd")
const L = preload("res://core/util/log.gd")

var r

func before_each() -> void:
	r = fixture_repo("ded")

func _st():
	var st = FakeState.new()
	Index.ensure(st)
	return st

func test_ensure_is_idempotent_and_complete():
	var st = FakeState.new()
	var d := Index.ensure(st)
	for k in ["clips", "pairs", "folios", "entries", "index", "sealed"]:
		eq(typeof(d[k]), TYPE_DICTIONARY, k)
	for k in ["practice", "passes"]:
		eq(typeof(d[k]), TYPE_ARRAY, k)
	d.clips["RC0001"] = {"id": "RC0001"}
	Index.ensure(st)
	ok(st.ded.clips.has("RC0001"), "no pisa lo existente")

func test_add_has_dedupe_and_note():
	var st = _st()
	no(Index.has(st, "watson"))
	Index.add_entities(st, r, ["watson", "watson", "holmes"])
	ok(Index.has(st, "watson"))
	ok(Index.has(st, "holmes"))
	eq(st.ded.index.size(), 2)
	eq(st.notes.size(), 1)
	eq(st.notes[0].kind, "index")
	eq(st.notes[0].payload.added, ["watson", "holmes"])
	Index.add_entities(st, r, ["watson"])
	eq(st.notes.size(), 1, "nada nuevo, sin aviso")

func test_unknown_entity_ignored():
	var st = _st()
	L.start_capture()
	Index.add_entities(st, r, ["no_existe_esto"])
	var cap := L.stop_capture()
	no(Index.has(st, "no_existe_esto"))
	eq(cap.size(), 1, "un aviso (no un error)")

func test_runtime_act_refs():
	var st = _st()
	Index.add_entities(st, r, [{"id": "act.7", "label": "asiento 214"}])
	ok(Index.has(st, "act.7"))
	eq(Index.kind(r, "act.7"), "act_ref")
	eq(Index.label(st, r, "act.7"), "asiento 214")
	Index.add_entities(st, r, [{"id": "act.7", "label": "otra"}])
	eq(Index.label(st, r, "act.7"), "asiento 214", "la primera etiqueta queda")
	Index.add_entities(st, r, ["act.8"])
	eq(Index.label(st, r, "act.8"), "act.8")
	Index.add_entities(st, r, [{"id": "act.8", "label": "Holborn"}])
	eq(Index.label(st, r, "act.8"), "Holborn", "una etiqueta vacía se completa")

func test_known_sorted_by_index_label():
	var st = _st()
	# índices: «Watson, John H., doctor», «abejas», ««El problema final» (Strand, dic. 1893)», «Holmes, Sherlock», «Ávila» no existe:
	# «bastón herrado», «Reichenbach, cascada del», «Trichinópolis», «a pique»
	Index.add_entities(st, r, ["watson", "abejas", "fina", "holmes", "baston", "reichenbach", "trichinopolis", "a_pique"])
	eq(Index.known(st, r), ["a_pique", "abejas", "baston", "fina", "holmes", "reichenbach", "trichinopolis", "watson"])
	var rows := Index.rows(st, r)
	eq(rows[3], {"id": "fina", "label": "«El problema final»", "kind": "documento", "index": "«El problema final» (Strand, dic. 1893)"}, "a la vista, el nombre natural (playtest v2)")
	eq(Index.index_label(st, r, "fina"), "«El problema final» (Strand, dic. 1893)", "la forma de índice sólo ordena")

func test_sort_key_folds_accents_and_enye():
	ok(Index.sort_key("«Ávila»").begins_with("avila"), Index.sort_key("«Ávila»"))
	ok(Index.sort_key("ñandú") > Index.sort_key("nube"), "ñ va después de n")
	ok(Index.sort_key("Óscar") < Index.sort_key("pato"))

func test_kind_and_label_of_data_entities():
	var st = _st()
	eq(Index.kind(r, "watson"), "persona")
	eq(Index.label(st, r, "watson"), "Doctor Watson")
	eq(Index.index_label(st, r, "watson"), "Watson, John H., doctor")
	eq(Index.label(st, r, "nada"), "nada")
