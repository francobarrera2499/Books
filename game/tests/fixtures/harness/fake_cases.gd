# Fixture del selfcheck del runner (W1-ENG). NO es un test real (no empieza con test_ en la carpeta tests/).
extends "res://tests/test_base.gd"

const L = preload("res://core/util/log.gd")
signal _never

func test_pass():
	ok(true)

func test_assert_fail():
	eq(1, 2, "a propósito")

func test_push_error():
	push_error("fallo del motor a propósito")

func test_push_error_expected():
	expect_error("fallo esperado XYZ")
	push_error("fallo esperado XYZ (selfcheck)")

func test_expect_but_no_error():
	expect_error("nunca ocurre")

func test_script_error():
	var x = null
	x.metodo_que_no_existe()

func test_warning_ignored():
	push_warning("advertencia: no cuenta")

func test_log_e_ignored():
	L.e("selfcheck", "printerr no cuenta")

func test_log_bug_fails():
	L.bug("selfcheck", "invariante rota a propósito")

func test_skip():
	skip("motivo de prueba")

func test_async_ok():
	await tree.process_frame
	await tree.process_frame
	ok(true)

func test_hang():
	await _never

func test_async_script_error():
	await tree.process_frame
	await tree.process_frame
	var x = null
	x.metodo_que_no_existe()
