# core/util/log.gd — logger estático (sin autoload). Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8, §11.
# Uso: const L = preload("res://core/util/log.gd"); L.i("modulo", "msg").
# e() = printerr (NO push_error). bug() = push_error: sólo invariante interna rota (el runner lo cuenta como falla).
# capturing = true: d/i/w/e se guardan en `captured` ({lvl, tag, msg}) y no se imprimen; bug siempre hace push_error.
extends RefCounted

static var level := 1            # 0 debug, 1 info, 2 warn, 3 error
static var captured: Array = []
static var capturing := false

const NAMES := ["D", "I", "W", "E", "BUG"]

static func d(tag: String, msg: String) -> void:
	_out(0, tag, msg)

static func i(tag: String, msg: String) -> void:
	_out(1, tag, msg)

static func w(tag: String, msg: String) -> void:
	_out(2, tag, msg)

static func e(tag: String, msg: String) -> void:
	_out(3, tag, msg)

static func bug(tag: String, msg: String) -> void:
	if capturing:
		captured.append({"lvl": 4, "tag": tag, "msg": msg})
	push_error("[BUG %s] %s" % [tag, msg])

static func start_capture() -> void:
	captured = []
	capturing = true

static func stop_capture() -> Array:
	capturing = false
	var c := captured
	captured = []
	return c

static func _out(lvl: int, tag: String, msg: String) -> void:
	if capturing:
		captured.append({"lvl": lvl, "tag": tag, "msg": msg})
		return
	if lvl < level:
		return
	var line := "%s [%s] %s" % [NAMES[lvl], tag, msg]
	if lvl >= 3:
		printerr(line)
	else:
		print(line)
