# Fixture del selfcheck: archivo SLOW (W1-ENG).
extends "res://tests/test_base.gd"
const SLOW := true
func test_slow_one():
	ok(slow, "slow debe ser true cuando corre")
