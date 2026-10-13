# devtools/drivers/slice_ui.gd — W4-SLICE por la UI real, con ventana y capturas de cada día (ARCHITECTURE §9.4, §10).
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn slice_f1 res://devtools/drivers/slice_ui.gd --mute --slice=f1
#   (--rapido: Shell.fast, sin fundidos ni epígrafes que duren; por defecto a la velocidad del juego para que las capturas
#    muestren lo que ve el jugador. --slice=f2|f3a|f4; f2/f3a juegan la investigación compartida con f1 sin capturas y por la UI desde el informe final:
#    --rama=final_report; --rama= vacío juega todo por la UI)
# Juega devtools/scripts/slice_<final>.jsonl con devtools/drivers/slice_ui_runner.gd (cada acción con su widget; ver allí).
# Capturas: .work/shots/<prefijo>_dNN_<n>_<qué>.png (amanecer con la bandeja, cada visita, diálogos, informe, libro mayor,
# compositores, escenas, confrontación, Park Lane, la noche final, el epílogo). Salida: «SLICEUI RESUMEN {…}» y
# «SLICEUI OK|FALLA».
extends RefCounted

const Runner = preload("res://devtools/drivers/slice_ui_runner.gd")

func drive(tool, scene) -> void:
	await tool.frames(10)
	var shell = scene.get_node_or_null("Shell")
	var g = tool.root.get_node("Game")
	if shell == null or g == null:
		print("SLICEUI FALLA sin Shell/Game")
		return
	var key := "f1"
	var rama := ""
	var set_rama := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--slice="):
			key = s.substr(8)
		elif s.begins_with("--rama="):
			rama = s.substr(7)
			set_rama = true
	if not set_rama and key in ["f2", "f3a"]:
		rama = "final_report"
	var r = Runner.new()
	r.setup(tool, shell, g)
	r.fast = OS.get_cmdline_user_args().has("--rapido")
	r.prefix = String(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else "slice_" + key
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await r.run(key, rama)
	res["ms"] = Time.get_ticks_msec() - t0
	print("SLICEUI RESUMEN ", JSON.stringify(res))
	for f in res.get("fails", []):
		print("SLICEUI FALLA ", f)
	print("SLICEUI %s %s final=%s respaldos=%s" % ["OK" if (res.get("fails", ["?"]) as Array).is_empty() and (res.get("fallbacks", {}) as Dictionary).is_empty() else "FALLA", key, res.get("ending", ""), str(res.get("fallbacks", {}))])
	g.end_session()
