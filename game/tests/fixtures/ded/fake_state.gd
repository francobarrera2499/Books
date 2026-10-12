# W2-DED: estado mínimo con la forma de GameState (§3.3) para los tests de deducción, sin depender de W2-SIM.
extends RefCounted

var seed := 7
var clock := {}
var world := {}
var ded := {}
var react := {}
var scenes := {}
var flags := {}
var events := []
var seq := {}
var notes := []
var pending_events := []

func next_id(kind: String, prefix: String, width: int) -> String:
	var n: int = int(seq.get(kind, 0)) + 1
	seq[kind] = n
	return prefix + str(n).pad_zeros(width)

func note(kind: String, payload := {}) -> void:
	notes.append({"kind": kind, "payload": payload})

func push_event(ev: Dictionary) -> void:
	pending_events.append(ev)
