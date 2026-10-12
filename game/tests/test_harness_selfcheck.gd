# Selfcheck del arnés (§9.1). Dueño: W1-ENG. Corre casos falsos de tests/fixtures/harness/ con run_one/run_file
# (contextos de captura anidados: los errores de los casos falsos no se filtran a este test).
extends "res://tests/test_base.gd"

const FAKE := "res://tests/fixtures/harness/fake_cases.gd"

func _one(m: String) -> Dictionary:
	return await tree.run_one(load(FAKE), m, "fake_cases.gd", 5.0)

func test_eq_works():
	eq(1 + 1, 2)
	ok(true)
	near(0.1 + 0.2, 0.3, 1e-9)
	ne(1, 2)

func test_pass_and_assert():
	eq((await _one("test_pass")).status, "PASS")
	var r = await _one("test_assert_fail")
	eq(r.status, "FAIL")
	ok(String(r.fails[0]).contains("a propósito"))

func test_push_error_fails():
	var r = await _one("test_push_error")
	eq(r.status, "FAIL", "push_error debe fallar")
	ok(str(r.fails).contains("fallo del motor a propósito"), str(r.fails))

func test_expect_error_excuses():
	eq((await _one("test_push_error_expected")).status, "PASS", "expect_error excusa el error")

func test_expect_error_unmet_fails():
	var r = await _one("test_expect_but_no_error")
	eq(r.status, "FAIL")
	ok(str(r.fails).contains("nunca ocurre"))

func test_script_error_fails():
	var r = await _one("test_script_error")
	eq(r.status, "FAIL")
	ok(str(r.fails).contains("SCRIPT"), str(r.fails))

func test_warnings_and_printerr_dont_count():
	eq((await _one("test_warning_ignored")).status, "PASS")
	eq((await _one("test_log_e_ignored")).status, "PASS")

func test_log_bug_counts():
	var r = await _one("test_log_bug_fails")
	eq(r.status, "FAIL")
	ok(str(r.fails).contains("invariante rota"))

func test_skip_status():
	var r = await _one("test_skip")
	eq(r.status, "SKIP")
	eq(r.reason, "motivo de prueba")

func test_async_test_completes():
	eq((await _one("test_async_ok")).status, "PASS")

func test_async_script_error_fails_fast():
	var t0 := Time.get_ticks_msec()
	var r = await _one("test_async_script_error")
	eq(r.status, "FAIL")
	ok(str(r.fails).contains("SCRIPT"), str(r.fails))
	no(str(r.fails).contains("watchdog"), "una corrutina abortada termina sin esperar al watchdog")
	ok(Time.get_ticks_msec() - t0 < 2000)

func test_watchdog():
	var t0 := Time.get_ticks_msec()
	var res: Array = await tree.run_file("res://tests/fixtures/harness/fake_timeout.gd", true)
	eq(res.size(), 1)
	eq(res[0].status, "FAIL")
	ok(str(res[0].fails).contains("watchdog"), str(res[0].fails))
	ok(Time.get_ticks_msec() - t0 < 3000, "watchdog de 0,3 s no debe tardar segundos")

func test_list():
	var l: Array = tree.list_tests("harness_selfcheck")
	has(l, "test_harness_selfcheck.gd::test_list")
	has(l, "test_harness_selfcheck.gd::test_watchdog")
	ok(tree.list_tests("zzz_no_existe").is_empty())

func test_slow_gate():
	var prev: bool = tree.slow
	tree.slow = false
	var a: Array = await tree.run_file("res://tests/fixtures/harness/fake_slow.gd", true)
	eq(a[0].status, "SKIP", "sin --slow")
	tree.slow = true
	var b: Array = await tree.run_file("res://tests/fixtures/harness/fake_slow.gd", true)
	eq(b[0].status, "PASS", "con --slow (y slow=true en el test)")
	tree.slow = prev

func test_window_gate():
	var prev: bool = tree.window
	tree.window = false
	var a: Array = await tree.run_file("res://tests/fixtures/harness/fake_window.gd", true)
	eq(a[0].status, "SKIP", "WINDOW sin --window")
	tree.window = true
	var b: Array = await tree.run_file(FAKE, true)
	eq(b.size(), 0, "con --window sólo corren archivos WINDOW")
	tree.window = prev

func test_tmp_dir():
	var d := tmp_dir()
	ok(d.replace("\\", "/").contains("/.work/tests/test_harness_selfcheck"), d)
	var f := FileAccess.open(d.path_join("x.txt"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	ok(FileAccess.file_exists(d.path_join("x.txt")))
	eq(tmp_dir(), d, "misma carpeta dentro del test")
	_tmp = ""
	tmp_dir()
	no(FileAccess.file_exists(d.path_join("x.txt")), "tmp_dir vacía la carpeta")
