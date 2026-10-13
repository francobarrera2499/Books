# W3-CT-TIMES: corre el recorrido de test_i_integration sobre un dataset ya armado, para validar D15.0327–0330
# aunque otro WP tenga data/ a medio hacer (test_walk_with_real_content se salta entero ante un solo error de carga).
# Armar el dataset: correr test_i_integration (deja .work/tests/test_i_integration/data_real = fixtures integ + data real
# encima), copiarlo a .work/times/data_walk y reemplazar el archivo ajeno roto por su fixture de tests/fixtures/integ/.
#   ./godot.sh --headless -s devtools/drivers/w3cttimes_walk.gd -- [ruta absoluta del dataset]
extends SceneTree
const DataRepo = preload("res://core/data/data_repo.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var root := ProjectSettings.globalize_path("res://").path_join("../.work/times/data_walk").simplify_path()
	if args.size() > 0:
		root = args[0]
	DataRepo.clear_cache(root)
	var repo = DataRepo.fresh(root)
	print("LOAD ERRS ", repo.errors())
	var T = load("res://tests/test_i_integration.gd").new()
	T.tree = self
	var sim = T._walk(repo)
	print("WALK ", "ok" if sim != null else "null", " ERRS ", T._errs.size())
	for e in T._errs:
		print("  ", e)
	for f in T._frags:
		print("  FRAG ", f.get("ref"), " ", f.get("copy"), " ", f.get("clip"))
	quit()
