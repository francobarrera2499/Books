# W1-AUDIO: reproduce sueltos y ambientes por el AudioServer (driver real o Dummy) y verifica que avanzan.
# Uso: ./godot.sh --headless -s devtools/drivers/w1audio_playcheck.gd
extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var a = load("res://autoload/audio.gd").new()
	root.add_child(a)
	a.subtitle.connect(func(t, s): print("SUBTITULO: ", t, " (", s, " s)"))
	a.play("sfx.tijera")
	a.play_amb("amb.gas", 0.2)
	await create_timer(0.5).timeout
	var amb = a._amb[a._amb_cur]
	print("amb playing=", amb.playing, " pos=", amb.get_playback_position(), " vol=", amb.volume_db)
	a.set_place_ambience("L2", "M")
	await create_timer(0.6).timeout
	print("amb now=", a.current_amb(), " old vol=", a._amb[1 - a._amb_cur].volume_db, " playing=", a._amb[1 - a._amb_cur].playing)
	var dur = a.play_event("dawn")
	print("dawn total ", dur)
	await create_timer(1.0).timeout
	var busy = 0
	for p in a._pool: if p.playing: busy += 1
	print("pool busy=", busy)
	a.queue_free()
	await process_frame
	quit(0)
