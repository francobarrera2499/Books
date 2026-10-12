# Fixture del selfcheck: watchdog corto (W1-ENG).
extends "res://tests/test_base.gd"
const TIMEOUT_S := 0.3
signal _never
func test_hang():
	await _never
