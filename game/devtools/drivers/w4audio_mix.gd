# W4-AUDIO: tabla de mezcla. Por id: pico, sonoridad máxima de corto plazo (sueltos) o integrada (bucles), duración y
# ms de render; por ambiente de data/audio.json: sonoridad efectiva (bus Amb −3 dB + db del lugar).
# Uso: ./godot.sh --headless -s devtools/drivers/w4audio_mix.gd [-- <filtro>]
extends SceneTree

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")

func _init() -> void:
	var filt := ""
	if OS.get_cmdline_user_args().size() > 0: filt = OS.get_cmdline_user_args()[0]
	var loud := {}
	var tot := 0.0
	for id in Bank.ids():
		if filt != "" and not String(id).contains(filt): continue
		var t0 := Time.get_ticks_usec()
		var x := Proc.render(id, 0)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		tot += ms * Bank.variants(id)
		var l: float = An.loudness_int(x) if Bank.is_loop(id) else An.loudness_max(x)
		loud[id] = l
		print("%-22s %7.1f ms  dur=%5.2f  peak=%.3f  %s=%6.1f  target=%s" % [id, ms, float(x.size()) / 44100.0, Synth.peak(x),
			"LInt" if Bank.is_loop(id) else "LMax", l, str(Bank.entry(id).get("target", "-"))])
	print("TOTAL serie (con variantes) %.1f ms" % tot)
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	if filt == "" and cfg is Dictionary:
		print("--- ambientes (bus Amb −3 dB + db)")
		var amb: Dictionary = cfg.get("ambience", {})
		var keys := amb.keys()
		keys.sort()
		for p in keys:
			var row: Dictionary = amb[p]
			var ss := row.keys()
			ss.sort()
			for s in ss:
				var v = row[s]
				var vid := String(v.get("id", "")) if v is Dictionary else String(v)
				var db := float(v.get("db", 0.0)) if v is Dictionary else 0.0
				if vid == "" or not loud.has(Bank.resolve(vid)): continue
				print("  %-14s %-9s %-22s %6.1f" % [p, s, vid, float(loud[Bank.resolve(vid)]) - 3.0 + db])
	quit(0)
