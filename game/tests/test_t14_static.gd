# T14 (W1-ENG; v3 GDD_v3 §2.4, CORE-EXPEDIENTE): sólo core/deduction/dossier.gd escribe la tinta del expediente
# (st.ded.dossier.inked: asignar una clave, reasignar el diccionario, erase/clear/merge). tests/ y devtools/ quedan fuera
# del escaneo (los tests y los bots pueden armar estados a mano). Las lecturas (inked.has, inked.size(), ==) no cuentan.
extends "res://tests/test_base.gd"

const Lint = preload("res://devtools/lint.gd")

func test_only_dossier_writes_ink():
	for f in Lint.inked_writers():
		fail(f)

func test_detector_finds_writes():
	var d := tmp_dir()
	var tok := "ink" + "ed"
	var f := FileAccess.open(d.path_join("malo.gd"), FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc x(st):\n\tst.ded.dossier." + tok + "[\"Q1\"] = {}\n\t# st.ded.dossier." + tok + "[\"Q1\"] = {} en comentario no cuenta\n\tvar n: int = st.ded.dossier." + tok + ".size()\n\tst.ded.dossier." + tok + ".erase(\"Q2\")\n\tif st.ded.dossier." + tok + " == {}:\n\t\tpass\n\tst.ded.dossier." + tok + " = {}\n")
	f.close()
	var found: Array = Lint.inked_writers(d)
	eq(found.size(), 3, str(found))
	ok(str(found).contains(":3:"), "asignación de clave, línea 3: " + str(found))
	ok(str(found).contains(":6:"), "erase, línea 6: " + str(found))
	ok(str(found).contains(":9:"), "reasignación, línea 9: " + str(found))
	no(str(found).contains(":5:") or str(found).contains(":7:"), "lecturas y comparaciones no cuentan")

func test_v2_ledger_gone():
	no(FileAccess.file_exists("res://core/deduction/ledger.gd"), "v3: sin libro de conclusiones")
	no(FileAccess.file_exists("res://data/conclusions.json"), "v3: sin conclusions.json")
