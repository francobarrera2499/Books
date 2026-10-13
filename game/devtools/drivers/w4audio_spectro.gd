# W4-AUDIO: espectrogramas (forma de onda + espectro log 40 Hz–16 kHz) y WAV de los ids pedidos, para mirarlos (y
# escucharlos fuera del juego), más tres mezclas como suenan en el juego (bus Amb −3 dB + db del lugar; sueltos a 0 dB):
# el amanecer en la buhardilla, la noche del 5 en Baker Street y en casa (con los sonidos de HC09 propuestos).
# Uso: ./godot.sh --headless -s devtools/drivers/w4audio_spectro.gd [-- id1,id2,...]   (sin ids: los de W4-AUDIO)
# Salida: .work/shots/w4audio_<id>.png, .work/w4audio/wav/<id>.wav y mezcla_<escena>.{png,wav}
extends SceneTree

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
const MINE := ["harp.parker", "glass.tintineo", "bells.st_clement", "bells.horas", "evt.cerrojo", "evt.carrera",
	"amb.calle_parker", "amb.gas_parker", "amb.casa_vacia", "clock.cuartos", "shot.silbido", "whistle.policia"]
# escena: [duración, ambiente, db del lugar, [[t, id], ...]] (tiempos de Audio.play_event o un golpe de HC09 cada ~5 s)
const SCENES := {
	"amanecer": [10.0, "amb.calle", -7.0, [[0.5, "bells.st_clement"], [5.0, "evt.lechero"], [7.25, "evt.persiana_crane"]]],
	"noche_baker_street": [24.0, "amb.viento", -3.0, [[3.0, "clock.cuartos"], [8.0, "harp.parker"], [13.5, "shot.silbido"],
		[14.05, "glass.tintineo"], [19.0, "whistle.policia"], [19.55, "evt.carrera"]]],
	"noche_casa": [24.0, "amb.viento", -6.0, [[2.0, "bells.horas"], [19.0, "evt.cerrojo"]]],
	"baker_street_de_noche": [16.0, "amb.calle_parker", 0.0, []],
}

var out_dir := ""

func _init() -> void:
	var ids: Array = MINE
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "": ids = Array(a[0].split(","))
	out_dir = ProjectSettings.globalize_path("res://").path_join("../.work")
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("shots"))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("w4audio/wav"))
	for id in ids:
		if not Bank.has(id):
			print("id desconocido ", id)
			continue
		var x := Proc.render(id, 0)
		_save(x, id, Bank.is_loop(id))
		print("%-20s dur=%.2fs peak=%.3f onsets=%s" % [id, float(x.size()) / 44100.0, Synth.peak(x), str(An.onsets(x, 0.005, 10.0, 0.08))])
	if a.size() == 0 or a[0] == "":
		for s in SCENES:
			var x := _scene(SCENES[s])
			_save(x, "mezcla_" + s, false)
			print("%-22s peak=%.3f LMax=%.1f" % ["mezcla_" + s, Synth.peak(x), An.loudness_max(x)])
	quit(0)

func _save(x: PackedFloat32Array, name: String, loop: bool) -> void:
	An.spectrogram_image(x, 900, 260, 40.0, 16000.0, 2048, 70).save_png(out_dir.path_join("shots/w4audio_%s.png" % name))
	Synth.to_wav(x, loop).save_to_wav(out_dir.path_join("w4audio/wav/%s.wav" % name))

func _scene(sc: Array) -> PackedFloat32Array:
	var n := Synth.n_of(float(sc[0]))
	var out := Synth.zeros(n)
	var amb := Proc.render(String(sc[1]), 0)
	var bed := Synth.zeros(n)
	var i := 0
	while i < n:
		Synth.mix(bed, amb, i)
		i += amb.size()
	Synth.mul_pts(bed, [[0.0, 0.0], [1.0, 1.0], [float(sc[0]) - 1.0, 1.0], [float(sc[0]), 0.0]])
	Synth.mix(out, bed, 0, db_to_linear(-3.0 + float(sc[2])))
	for e in sc[3]:
		Synth.mix(out, Proc.render(String(e[1]), 0), Synth.n_of(float(e[0])))
	return out
