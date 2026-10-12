# Usage (from repo root): ./godot.sh --headless -s tests/run_tests.gd [-- filter]
# Runs every res://tests/test_*.gd. Exit code 0 = all pass, 1 = failures.
extends SceneTree
func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: filter = args[0]
	var files: Array = []
	var d := DirAccess.open("res://tests")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd" and (filter == "" or f.contains(filter)):
			files.append(f)
	files.sort()
	var total := 0; var failed := 0; var all_fails: Array = []
	for f in files:
		var scr = load("res://tests/" + f)
		if scr == null: all_fails.append(f + ": failed to load (parse error?)"); failed += 1; continue
		var methods: Array = []
		for m in scr.get_script_method_list():
			if String(m.name).begins_with("test_") and not methods.has(m.name): methods.append(m.name)
		for m in methods:
			var t = scr.new()
			t.tree = self
			t._cur = f + "::" + m
			t.before_each()
			var r = t.call(m)
			if r is Object and r.get_class() == "GDScriptFunctionState": await r
			t.after_each()
			total += 1
			if t._fails.size() > 0:
				failed += 1; all_fails.append_array(t._fails)
	for x in all_fails: printerr("FAIL ", x)
	print("TESTS: %d run, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
