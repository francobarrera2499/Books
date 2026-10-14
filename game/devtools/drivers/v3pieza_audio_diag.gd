# v3pieza_audio_diag (REACCIONES-PIEZA, GDD_v3 §6.8): diagnóstico de calma de los bucles de ambiente (headless).
#   ./godot.sh --headless -s devtools/drivers/v3pieza_audio_diag.gd
# Por bucle: RMS, siseo 2–8 kHz, pico de ventana sobre la mediana y eventos detectados con varios umbrales; y el tiempo de
# generación de cada id (warm en serie).
extends SceneTree

const Bank = preload("res://audio/sound_bank.gd")
const Proc = preload("res://audio/proc_audio.gd")
const An = preload("res://audio/analysis.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var ids: Array = Bank.ids()
	var only := OS.get_environment("DBG_IDS")
	for id in ids:
		if only != "" and not only.split(",").has(String(id)):
			continue
		var t0 := Time.get_ticks_usec()
		var x := Proc.render(String(id), 0)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if not Bank.is_loop(String(id)):
			print("%-20s %6.0f ms  suelto  loud_max %.1f" % [id, ms, An.loudness_max(x)])
			continue
		x = x.slice(0, Synth_n(float(Bank.entry(String(id)).dur)))
		var r := An.window_rms(x, 0.1)
		var arr := Array(r); arr.sort()
		var med: float = float(arr[arr.size() / 2])
		var mx: float = float(arr[arr.size() - 1])
		print("%-20s %6.0f ms  %4.1f s  RMS %6.1f  2-8k %6.1f  max/med %+5.1f dB  ev3 %s  ev6 %s  li %.1f" % [id, ms, float(x.size()) / 44100.0,
			An.rms_db(x), An.band_rms_db(x, 2000.0, 8000.0), 20.0 * log(mx / maxf(med, 1e-9)) / log(10.0),
			str(An.loop_events(x, 0.1, 3.0)), str(An.loop_events(x, 0.1, 6.0)), An.loudness_int(x)])
	quit(0)

static func Synth_n(s: float) -> int:
	return int(round(s * 44100.0))
