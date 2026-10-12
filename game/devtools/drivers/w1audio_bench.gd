# W1-AUDIO: mide el tiempo de render de cada id (serie), nivel y reparto espectral por bandas.
# Uso: ./godot.sh --headless -s devtools/drivers/w1audio_bench.gd [-- <filtro>]
extends SceneTree
const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
func _init() -> void:
	var filt := ""
	if OS.get_cmdline_user_args().size() > 0: filt = OS.get_cmdline_user_args()[0]
	var tot := 0.0
	var bands := [[0, 250], [250, 1000], [1000, 4000], [4000, 9000], [9000, 22050]]
	for id in Bank.ids():
		if filt != "" and not String(id).contains(filt): continue
		var t0 := Time.get_ticks_usec()
		var x := Proc.render(id, 0)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		tot += ms * Bank.variants(id)
		var sp := An.avg_spectrum(x, 2048, 0.0, -1.0, 24)
		var bs := ""
		for b in bands: bs += " %d-%d:%.2f" % [b[0], b[1], An.band_ratio(sp, 2048, b[0], b[1])]
		print("%-20s %6.1f ms peak=%.3f rms=%5.1f dBFS |%s" % [id, ms, Synth.peak(x), linear_to_db(Synth.rms(x)), bs])
		if filt != "": print("    onsets(5ms,12dB,0.15s): ", An.onsets(x, 0.005, 12.0, 0.15))
	print("TOTAL serie (con variantes, estimado) %.1f ms" % tot)
	quit(0)
