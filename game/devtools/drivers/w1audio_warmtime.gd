# W1-AUDIO: mide Audio.warm() (con hilos y en serie) sobre una instancia nueva. Uso: ./godot.sh --headless -s devtools/drivers/w1audio_warmtime.gd
extends SceneTree
func _init() -> void:
	var A = load("res://autoload/audio.gd")
	for th in [true, false]:
		var a = A.new()
		a.threaded = th
		a.warm()
		print("warm threaded=%s: %.0f ms" % [th, a.last_warm_ms])
		a.free()
	quit(0)
