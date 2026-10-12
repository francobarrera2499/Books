# Autoload Game. Dueño: W2-SIM. Contrato: docs/ARCHITECTURE.md §2.2 y §3.4.
# Sesión activa: sostiene el GameSim, persiste el registro (core/save/event_log.gd) ANTES de devolver el
# resultado de toda acción comprometida y reexpide señales a la UI. La UI muta estado SÓLO por act().
# STUB: carga perezosa por ruta para no romper la compilación mientras core/ no exista.
extends Node

signal sim_changed(kind: String, payload: Dictionary)
signal session_started
signal session_ended

const SIM_SCRIPT := "res://core/sim/game_sim.gd"
const LOG_SCRIPT := "res://core/save/event_log.gd"
const SAVE_PATH := "user://saves/partida.jsonl"

var sim = null                   # GameSim activo o null
var _log = null                  # EventLog

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_session(seed: int = 0) -> bool:
	return false  # W2-SIM

func continue_session() -> bool:
	return false  # W2-SIM

func act(action: Dictionary) -> Dictionary:
	if sim == null:
		return {"ok": false, "err": "no_sim"}
	return {"ok": false, "err": "stub"}

func end_session() -> void:
	sim = null
	_log = null
	session_ended.emit()
