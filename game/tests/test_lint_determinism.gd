# Lint de determinismo y pureza de core/ (W1-ENG). §3.1 (D7), §11: sin azar ni reloj, sin autoloads/Node/Input/print,
# sin class_name en game/. Los detectores se prueban sobre archivos temporales en .work/tests/.
extends "res://tests/test_base.gd"

const Lint = preload("res://devtools/lint.gd")

func test_core_is_deterministic():
	for f in Lint.determinism():
		fail(f)

func test_core_is_pure():
	for f in Lint.core_purity():
		fail(f)

func test_no_class_name():
	for f in Lint.class_names():
		fail(f)

func _write(name: String, src: String) -> String:
	var d := tmp_dir()
	var f := FileAccess.open(d.path_join(name), FileAccess.WRITE)
	f.store_string(src)
	f.close()
	return d

func test_detectors():
	var q := "\""
	var lines := PackedStringArray([
		"extends Node",                                         # 1 pureza
		"func a():",                                            # 2
		"\tvar x = randi() % 3",                                # 3 det
		"\tvar t = Time.get_ticks_msec()",                      # 4 det
		"\tvar r = RandomNumberGenerator.new()",                # 5 det
		"\trandomize()",                                        # 6 det
		"\tvar o = OS.get_ticks_usec()",                        # 7 det
		"\tprint(" + q + "x" + q + ")",                         # 8 pureza
		"\tvar d = Data.repo()",                                # 9 pureza
		"\tif Input.is_action_pressed(" + q + "x" + q + "): pass",  # 10 pureza
		"\t# randi() Time.get_ticks_msec() en comentario",      # 11 nada
		"\tvar s = " + q + "Time.now randi() Data.repo()" + q,  # 12 nada (texto)
		"\tvar ok1 = Det.pick(seed, [], [])",                   # 13 nada
		"\tvar ok2 = st.seed",                                  # 14 nada
		"\tvar ok3 = my_randi_helper()",                        # 15 nada
		"\tvar arr = [1, 2]; arr.shuffle()",                    # 16 det (azar global)
		"\tvar y = arr.pick_random()",                          # 17 det (azar global)
		"\tvar ok4 = Det.shuffle(seed, [], arr)",               # 18 nada
	])
	var d := _write("bad.gd", "\n".join(lines))
	var det: Array = Lint.determinism(d)
	eq(det.size(), 7, "determinismo: " + str(det))
	for ln in [":3:", ":4:", ":5:", ":6:", ":7:", ":16:", ":17:"]:
		ok(str(det).contains(ln), "detecta " + ln)
	var pur: Array = Lint.core_purity(d)
	eq(pur.size(), 4, "pureza: " + str(pur))
	var cn := _write("cn.gd", "extends RefCounted\n" + "class" + "_name Foo\n")
	eq(Lint.class_names(cn).size(), 1)

func test_code_only_strips_comments_and_strings():
	var q := "\""
	var src := "a = " + q + "x # y" + q + " # coment\nb = 'z' + " + q + q + q + "multi\nlinea" + q + q + q
	var c := Lint.code_only(src)
	ok(not c.contains("coment"))
	ok(not c.contains("x # y"))
	ok(not c.contains("multi"))
	eq(c.split("\n").size(), 3, "conserva líneas")
