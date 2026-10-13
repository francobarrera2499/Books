# Autoload Game. Dueño: W2-SIM. Contrato: docs/ARCHITECTURE.md §2.2, §3.4, §5.5.
# Sesión activa: sostiene el GameSim, persiste el registro (core/save/event_log.gd) ANTES de devolver el resultado de
# toda acción comprometida (Holmes no olvida, T25) y reexpide GameSim.changed como sim_changed. La UI muta estado
# SÓLO por act(). Acciones libres: escritura diferida (debounce 2 s) y al cerrar la ventana o terminar la sesión.
# Nada pesado ni push_error en _ready (el runner de tests instancia los autoloads).
# Extensiones (compatibles): signal notice(key) para avisos de guardado (ui_text core.save.*); save_path / repo_override /
# sim_handlers (sólo tests); flush(); header().
extends Node

signal sim_changed(kind: String, payload: Dictionary)
signal session_started
signal session_ended
signal notice(key: String)

const SIM_SCRIPT := "res://core/sim/game_sim.gd"
const LOG_SCRIPT := "res://core/save/event_log.gd"
const ACTIONS_SCRIPT := "res://core/sim/actions.gd"
const DET_SCRIPT := "res://core/util/det.gd"
const SAVE_PATH := "user://saves/partida.jsonl"
const DEBOUNCE_S := 2.0

var sim = null                   # GameSim activo o null
var _log = null                  # EventLog
var save_path := SAVE_PATH       # tests: una ruta bajo .work/tests/
var repo_override = null         # tests: DataRepo de fixtures (si null, Data.repo())
var sim_handlers := {}           # tests: dobles de manejadores de otros paquetes (GameSim)
var last_write_ok := true
var _header := {}
var _dirty := false
var _timer: Timer = null

func _repo():
	if repo_override != null:
		return repo_override
	return Data.repo()

func header() -> Dictionary:
	return _header.duplicate()

# ¿El guardado se escribió con otra versión del texto? (sólo la cabecera; false si no hay guardado legible). El título
# lo pregunta antes de continuar (W4: «Seguir» o «Volver al título»; el original se preserva en partida.<hash12>.jsonl).
func save_other_version() -> bool:
	var repo = _repo()
	if repo == null or not has_save():
		return false
	var r: Dictionary = load(LOG_SCRIPT).read(save_path)
	if not bool(r.get("ok", false)):
		return false
	return String(r.get("header", {}).get("content", "")) != String(repo.content_hash())

func has_save() -> bool:
	var p := _abs(save_path)
	return FileAccess.file_exists(p) or FileAccess.file_exists(p + ".tmp") or FileAccess.file_exists(p + ".bak")

func new_session(seed: int = 0) -> bool:
	_close_sim()
	var repo = _repo()
	if repo == null:
		return false
	var s := seed
	if s == 0:
		s = load(DET_SCRIPT).h32(["partida", repo.content_hash()])
	sim = load(SIM_SCRIPT).new(repo, s, sim_handlers)
	_log = load(LOG_SCRIPT).new(save_path)
	_header = load(LOG_SCRIPT).make_header(s, repo.content_hash())
	_connect()
	var ok := _write()
	session_started.emit()
	return ok

func continue_session() -> bool:
	_close_sim()
	var repo = _repo()
	if repo == null:
		return false
	var EL = load(LOG_SCRIPT)
	var r: Dictionary = EL.read(save_path)
	if not r.get("ok", false):
		if String(r.get("err", "")) == "no_existe":
			notice.emit("core.save.ninguna")
		else:
			notice.emit("core.save.corrupta")
		return false
	_header = r.header
	var other_version: bool = String(_header.get("content", "")) != String(repo.content_hash())
	if other_version:
		notice.emit("core.save.otra_version")
	if String(r.get("recovered", "")) != "":
		notice.emit("core.save.recuperada")
	sim = load(SIM_SCRIPT).replay(repo, int(_header.get("seed", 0)), r.actions, sim_handlers)
	if int(sim.replay_errors) > 0:
		notice.emit("core.save.corrupta")
	_log = EL.new(save_path)
	_connect()
	# reescribe el registro canónico (descarta una última línea truncada). Si el contenido cambió o alguna acción ya no se
	# acepta, el registro reescrito pierde acciones: antes se guarda el original entero aparte (la .bak se pisa en la
	# próxima escritura), partida.<hash del contenido viejo>.jsonl, para poder volver a él con la versión anterior.
	if int(r.get("dropped", 0)) > 0 or String(r.get("recovered", "")) != "" or int(sim.replay_errors) > 0:
		if other_version or int(sim.replay_errors) > 0:
			keep_original(r)
		_write()
	session_started.emit()
	return true

# Copia del registro tal como se leyó (cabecera y acciones originales) a partida.<hash viejo>.jsonl junto al archivo.
func keep_original(r: Dictionary) -> String:
	var old_hash := String(r.get("header", {}).get("content", "sin_hash"))
	if old_hash == "":
		old_hash = "sin_hash"
	var base := save_path.get_basename()
	var p := "%s.%s.%s" % [base, old_hash.left(12), save_path.get_extension() if save_path.get_extension() != "" else "jsonl"]
	if FileAccess.file_exists(_abs(p)):
		return p
	var EL = load(LOG_SCRIPT)
	if not EL.new(p).write(r.get("header", {}), r.get("actions", [])):
		push_warning("Game: no se pudo guardar la copia del registro original en " + p)
		return ""
	return p

func act(action: Dictionary) -> Dictionary:
	if sim == null:
		return {"ok": false, "err": "no_sim"}
	var res: Dictionary = sim.apply(action)
	if not res.get("ok", false):
		return res
	var t := String(action.get("t", ""))
	if load(ACTIONS_SCRIPT).is_commit(t):
		if not _write():
			res["save_err"] = true
	else:
		_dirty = true
		_arm_timer()
	return res

func flush() -> bool:
	if sim == null or not _dirty:
		return true
	return _write()

func end_session() -> void:
	if sim != null and _dirty:
		_write()
	_close_sim()
	session_ended.emit()

func _close_sim() -> void:
	if sim != null and sim.changed.is_connected(_on_changed):
		sim.changed.disconnect(_on_changed)
	sim = null
	_log = null
	_dirty = false
	if _timer != null:
		_timer.stop()

func _connect() -> void:
	if not sim.changed.is_connected(_on_changed):
		sim.changed.connect(_on_changed)

func _on_changed(kind: String, payload: Dictionary) -> void:
	sim_changed.emit(kind, payload)

func _write() -> bool:
	if sim == null or _log == null:
		return false
	last_write_ok = _log.write(_header, sim.actions_log())
	if last_write_ok:
		_dirty = false
	else:
		push_warning("Game: no se pudo escribir el registro en " + save_path)
	return last_write_ok

func _arm_timer() -> void:
	if not is_inside_tree():
		return
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.wait_time = DEBOUNCE_S
		_timer.timeout.connect(func(): flush())
		add_child(_timer)
	_timer.start(DEBOUNCE_S)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		if sim != null and _dirty:
			_write()

static func _abs(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p
