# Unit: core/util/j.gd (W1-ENG).
extends "res://tests/test_base.gd"

const J = preload("res://core/util/j.gd")

func test_parse_ints_recursive():
	var v = J.parse_str("{\"a\":1,\"b\":[2,3.5,{\"c\":4.0}],\"d\":-7}")
	eq(typeof(v.a), TYPE_INT, "a")
	eq(typeof(v.b[0]), TYPE_INT, "b0")
	eq(typeof(v.b[1]), TYPE_FLOAT, "b1")
	eq(typeof(v.b[2].c), TYPE_INT, "c")
	eq(v.d, -7)

func test_parse_big_float_stays_float():
	var v = J.parse_str("[9007199254740994, 1e300, 0.1]")
	eq(typeof(v[0]), TYPE_FLOAT, "≥2^53 sigue float")
	eq(typeof(v[1]), TYPE_FLOAT)
	near(v[2], 0.1)

func test_parse_invalid_is_null_without_engine_error():
	eq(J.parse_str("{mal"), null)
	ok(J.last_error() != "", "last_error")
	eq(J.parse_file("res://no/existe.json"), null)
	ok(J.last_error().begins_with("no_existe"))

func test_stringify_sorted_compact():
	eq(J.stringify_canon({"b": 1, "a": [true, null, "x"], "c": {"z": 1, "y": 2}}), "{\"a\":[true,null,\"x\"],\"b\":1,\"c\":{\"y\":2,\"z\":1}}")

func test_stringify_numbers():
	eq(J.stringify_canon([1, 2.0, 0.5, -3.0, 214.0]), "[1,2,0.5,-3,214]")
	var s := J.stringify_canon(1.0 / 3.0)
	near(J.parse_str(s), 1.0 / 3.0, 0.0, "float re-parsea idéntico")

func test_stringify_escapes_and_unicode():
	eq(J.stringify_canon("a\"b\\c\nd\te"), "\"a\\\"b\\\\c\\nd\\te\"")
	eq(J.stringify_canon("ñ«»—"), "\"ñ«»—\"")
	eq(J.stringify_canon(char(1)), "\"\\u0001\"")

func test_non_string_keys():
	eq(J.stringify_canon({2: "b", 1: "a"}), "{\"1\":\"a\",\"2\":\"b\"}")

func test_roundtrip():
	var v := {"t": "clip_text", "src": {"kind": "doc", "ref": "D05@BM", "part": "p1", "block": 0}, "from": 12, "len": 30, "x": [0.25, "«»", false, null]}
	var s := J.stringify_canon(v)
	eq(J.parse_str(s), v)
	eq(J.stringify_canon(J.parse_str(s)), s, "canon estable")

func test_ints_helper():
	var v = J.ints({"a": 3.0, "b": [1.0, 1.5]})
	eq(typeof(v.a), TYPE_INT)
	eq(typeof(v.b[0]), TYPE_INT)
	eq(typeof(v.b[1]), TYPE_FLOAT)

func test_write_atomic_and_bak():
	var d := tmp_dir()
	var p := d.path_join("sub/a.txt")
	ok(J.write_atomic(p, "uno"), "primera escritura")
	eq(FileAccess.get_file_as_string(p), "uno")
	no(FileAccess.file_exists(p + ".bak"), "sin .bak la primera vez")
	ok(J.write_atomic(p, "dos"), "segunda escritura")
	eq(FileAccess.get_file_as_string(p), "dos")
	eq(FileAccess.get_file_as_string(p + ".bak"), "uno")
	no(FileAccess.file_exists(p + ".tmp"), "no queda .tmp")
	ok(J.write_atomic(p, "tres"))
	eq(FileAccess.get_file_as_string(p + ".bak"), "dos", ".bak = versión anterior")
	eq(J.read_text(p), "tres")
