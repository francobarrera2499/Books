# W1-AUDIO: espectrogramas y WAV de inspección (no se puede escuchar: se mira).
# Uso (desde la raíz): ./godot.sh --headless -s devtools/drivers/w1audio_spectro.gd [-- <filtro>]
# Salida: .work/shots/w1audio_<id>.png (forma de onda + espectrograma log 40 Hz–16 kHz; líneas en 100 Hz, 1 kHz, 10 kHz)
#         .work/audio/<id>.wav (para escuchar fuera del juego) y métricas por consola.
extends SceneTree

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")

func _init() -> void:
	var filt := ""
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: filt = a[0]
	var sheet_cols := 4
	var tiles: Array = []
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../.work")
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("shots"))
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("audio"))
	for id in Bank.ids():
		if filt != "" and not String(id).contains(filt): continue
		var x := Proc.render(id, 0)
		var w := Synth.to_wav(x, Bank.is_loop(id))
		var img := An.spectrogram_image(x, 600, 220)
		var tile := An.spectrogram_image(x, 296, 110, 40.0, 16000.0, 1024, 30)
		tiles.append(tile)
		img.save_png(root_dir.path_join("shots/w1audio_%s.png" % id))
		w.save_to_wav(root_dir.path_join("audio/%s.wav" % id))
		var spec := An.avg_spectrum(x, 2048)
		var jump := -1.0
		if Bank.is_loop(id): jump = absf(x[x.size() - 1] - x[0])
		print("%-20s dur=%.2fs peak=%.3f rms=%.1fdBFS centroid=%5.0fHz hf>9k=%.3f onsets=%d loopjump=%.4f" % [
			id, float(x.size()) / 44100.0, Synth.peak(x), linear_to_db(maxf(Synth.rms(x), 1e-9)),
			An.centroid(spec, 2048), An.band_ratio(spec, 2048, 9000.0, 22050.0), An.onsets(x).size(), jump])
	# hoja de contactos: ids en orden alfabético, de izquierda a derecha y de arriba abajo
	if tiles.size() > 1:
		var tw: int = tiles[0].get_width() + 4
		var th: int = tiles[0].get_height() + 4
		var rows: int = (tiles.size() + sheet_cols - 1) / sheet_cols
		var sheet := Image.create(tw * sheet_cols, th * rows, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.3, 0.3, 0.3))
		for k in tiles.size():
			sheet.blit_rect(tiles[k], Rect2i(Vector2i.ZERO, tiles[k].get_size()), Vector2i((k % sheet_cols) * tw + 2, (k / sheet_cols) * th + 2))
		sheet.save_png(root_dir.path_join("shots/w1audio_sheet.png"))
	quit(0)
