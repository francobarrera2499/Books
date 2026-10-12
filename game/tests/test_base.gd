# Base for tests. Each test file: extends "res://tests/test_base.gd", methods named test_* run in order.
extends RefCounted
var _fails: Array = []
var _cur := ""
var tree: SceneTree
func fail(msg: String) -> void: _fails.append("%s: %s" % [_cur, msg])
func ok(cond: bool, msg := "expected true") -> void:
	if not cond: fail(msg)
func eq(a, b, msg := "") -> void:
	if typeof(a) != typeof(b) and not ((typeof(a) in [TYPE_INT, TYPE_FLOAT]) and (typeof(b) in [TYPE_INT, TYPE_FLOAT])):
		fail("%s expected %s (%s) got %s (%s)" % [msg, str(b), type_string(typeof(b)), str(a), type_string(typeof(a))]); return
	if a != b: fail("%s expected %s got %s" % [msg, str(b), str(a)])
func before_each() -> void: pass
func after_each() -> void: pass
