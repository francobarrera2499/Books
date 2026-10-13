# tests/fixtures/w3notebook/nb_walk.gd — GameSim del recorrido de integración para el cuaderno (W3-NOTEBOOK).
# El recorrido (test_i_integration._walk: datos estructurales de data/ + tests/fixtures/integ, prólogo -> amanecer del
# día 4) se hace UNA vez por proceso, en un dataset temporal propio del proceso (.work/tests/nb_walk_<pid>/: dos corridas
# en paralelo no se pisan), que se borra apenas DataRepo lo cargó (lo lee entero). Cada sim() es un GameSim.replay
# nuevo de esas acciones: los tests pueden mutarlo sin afectarse entre sí.
extends RefCounted

const Integ = preload("res://tests/test_i_integration.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

static var _repo = null
static var _actions: Array = []
static var errs: Array = []

static func ok() -> bool:
	_ensure()
	return _repo != null

static func repo():
	_ensure()
	return _repo

static func actions() -> Array:
	_ensure()
	return _actions.duplicate(true)

static func sim():
	_ensure()
	if _repo == null:
		return null
	return GameSim.replay(_repo, Integ.SEED, _actions)

static func _ensure() -> void:
	if _repo != null or not errs.is_empty():
		return
	var t = Integ.new()
	t._cur = "nb_walk_%d.gd::walk" % OS.get_process_id()
	var r = t._repo("fixture")
	var dir: String = t.tmp_dir()
	var s = t._walk(r)
	if dir != "" and dir.replace("\\", "/").contains("/.work/tests/"):
		t._clear_dir(dir)
		DirAccess.remove_absolute(dir)
	if s == null or not t._errs.is_empty() or not t._fails.is_empty():
		errs = t._errs.duplicate() + t._fails.duplicate()
		if errs.is_empty():
			errs = ["recorrido sin GameSim"]
		return
	_repo = r
	_actions = s.actions_log()
