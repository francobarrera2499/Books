# W4-AUDIO: verifica los diffs propuestos a archivos ajenos sin tocarlos. Corre con el arnés real (run_tests.gd) una
# copia de T28 que vive en .work/ (la versión propuesta, apuntando al fixture regenerado en .work/w4audio/).
# Uso: ./godot.sh --headless -s devtools/drivers/w4audio_t28check.gd [-- <ruta absoluta del .gd>]
extends "res://tests/run_tests.gd"

func _run() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../.work/w4audio/prop/t28_verif.gd").simplify_path()
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".gd"): path = a
	var res: Array = await run_file(path)
	var failed := 0
	for r in res:
		if r.status == "FAIL": failed += 1
	print("T28 PROPUESTO: %d corridos, %d fallidos" % [res.size(), failed])
	OS.remove_logger(cap)
	quit(1 if failed > 0 else 0)
