# Unit: core/util/log.gd (W1-ENG). e() = printerr (no falla); bug() = push_error (falla salvo expect_error).
extends "res://tests/test_base.gd"

const L = preload("res://core/util/log.gd")

func after_each() -> void:
	L.stop_capture()
	L.level = 1

func test_capture():
	L.start_capture()
	L.d("t", "debug")
	L.i("t", "info")
	L.w("t", "warn")
	L.e("t", "error")
	var c := L.stop_capture()
	eq(c.size(), 4)
	eq(c[0], {"lvl": 0, "tag": "t", "msg": "debug"})
	eq(c[3].lvl, 3)
	no(L.capturing)
	eq(L.captured, [])

func test_e_does_not_fail():
	L.level = 3
	L.e("test_u_log", "printerr: no es falla del runner")
	ok(true)

func test_bug_pushes_error():
	expect_error("[BUG modulo] invariante")
	L.bug("modulo", "invariante rota (esperado)")

func test_bug_captured_too():
	expect_error("[BUG m]")
	L.start_capture()
	L.bug("m", "x")
	var c := L.stop_capture()
	eq(c.size(), 1)
	eq(c[0].lvl, 4)
