# Unit: core/util/det.gd (W1-ENG). D7: azar sin estado por md5.
extends "res://tests/test_base.gd"

const Det = preload("res://core/util/det.gd")

func test_h32_is_md5_prefix():
	eq(Det.h32(["a", "b"]), "a|b".md5_text().substr(0, 8).hex_to_int())
	eq(Det.h32([]), "".md5_text().substr(0, 8).hex_to_int())
	ok(Det.h32(["x"]) >= 0 and Det.h32(["x"]) < 4294967296)

func test_h32_float_int_equivalent():
	eq(Det.h32([1, 2.0, "c"]), Det.h32([1, 2, "c"]), "2.0 == 2 (JSON)")

func test_rand01_range_and_stable():
	for i in 200:
		var r := Det.rand01(7, ["r", i])
		ok(r >= 0.0 and r < 1.0)
	eq(Det.rand01(7, ["a"]), Det.rand01(7, ["a"]))
	ne(Det.rand01(7, ["a"]), Det.rand01(8, ["a"]))

func test_pick():
	eq(Det.pick(1, ["x"], []), null)
	var arr := ["a", "b", "c", "d"]
	var seen := {}
	for i in 400:
		var v = Det.pick(3, ["p", i], arr)
		ok(arr.has(v))
		seen[v] = true
	eq(seen.size(), 4, "cubre todos")
	eq(Det.pick(3, ["p", 5], arr), Det.pick(3, ["p", 5], arr), "determinista")

func test_shuffle():
	var arr := [1, 2, 3, 4, 5, 6, 7, 8]
	var s1 := Det.shuffle(42, ["s"], arr)
	var s2 := Det.shuffle(42, ["s"], arr)
	eq(s1, s2, "determinista")
	eq(arr, [1, 2, 3, 4, 5, 6, 7, 8], "no muta la entrada")
	var sorted := s1.duplicate()
	sorted.sort()
	eq(sorted, arr, "es permutación")
	var differs := false
	for sd in range(10):
		if Det.shuffle(sd, ["s"], arr) != s1:
			differs = true
	ok(differs, "otras semillas dan otro orden")
	eq(Det.shuffle(1, [], []), [])
