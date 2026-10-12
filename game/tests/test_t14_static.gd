# T14 (W1-ENG): create_folio( sólo en core/sim/player_actions.gd (y su definición en core/deduction/ledger.gd).
# tests/ queda fuera del escaneo (los tests unitarios del ledger pueden llamarla).
extends "res://tests/test_base.gd"

const Lint = preload("res://devtools/lint.gd")

func test_only_player_actions_creates_folios():
	for f in Lint.create_folio_calls():
		fail(f)

func test_detector_finds_calls():
	var d := tmp_dir()
	var tok := "create" + "_folio("
	var f := FileAccess.open(d.path_join("malo.gd"), FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc x(st, repo):\n\tLedger." + tok + "st, repo, \"RC0001\")\n\t# " + tok + " en comentario no cuenta\n\tvar s := \"" + tok + "\"\n")
	f.close()
	var found: Array = Lint.create_folio_calls(d)
	eq(found.size(), 1, str(found))
	ok(str(found).contains(":3:"), "línea 3")

func test_definition_allowed_but_not_internal_calls():
	# En ledger.gd sólo vale la definición: una llamada interna (p. ej. desde act_entry_new) también falla T14.
	var d := tmp_dir()
	var tok := "create" + "_folio("
	var f := FileAccess.open(d.path_join("ledger.gd"), FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic func " + tok + "st, repo, head_clip: String) -> String:\n\treturn \"\"\nfunc helper():\n\treturn " + tok + "null, null, \"RC1\")\nfunc\t" + tok + ") -> void:\n\tpass\n")
	f.close()
	var found: Array = Lint.create_folio_calls(d)
	eq(found.size(), 1, str(found))
	ok(str(found).contains(":5:"), "sólo la llamada de la línea 5: " + str(found))
