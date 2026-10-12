# Autoload Data. Dueño: W1-ENG. Contrato: docs/ARCHITECTURE.md §2.2 y §4.
# Acceso global de UI/mundo al DataRepo compartido. El núcleo (core/) NUNCA usa este autoload:
# recibe el repo por parámetro. Carga perezosa: nada pesado ni push_error en _ready.
extends Node

const REPO_SCRIPT := "res://core/data/data_repo.gd"
const DATA_ROOT := "res://data"

var _repo = null

func repo():
	if _repo == null and ResourceLoader.exists(REPO_SCRIPT):
		_repo = load(REPO_SCRIPT).load_dir(DATA_ROOT)
	return _repo

# Descarta la caché (también la estática de DataRepo) y vuelve a leer data/ en el próximo repo().
func reload() -> void:
	if ResourceLoader.exists(REPO_SCRIPT):
		load(REPO_SCRIPT).clear_cache(DATA_ROOT)
	_repo = null
