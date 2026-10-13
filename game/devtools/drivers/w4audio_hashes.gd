# W4-AUDIO: genera el reemplazo de tests/fixtures/audio_hashes.json (md5 del PCM de cada id y variante, en serie) en
# .work/w4audio/audio_hashes.json, con el mismo formato que devtools/drivers/w1audio_hashes.gd. El fixture es de
# W1-AUDIO/T28: lo copia el orquestador (diff propuesto). Uso: ./godot.sh --headless -s devtools/drivers/w4audio_hashes.gd
extends SceneTree

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")

static func md5_bytes(b: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_MD5)
	c.update(b)
	return c.finish().hex_encode()

func _init() -> void:
	var h := {}
	for id in Bank.ids():
		for v in Bank.variants(id):
			h["%s#%d" % [id, v]] = md5_bytes(Proc.pcm(id, v))
	var out := {"_nota": "W1-AUDIO T28: md5 de AudioStreamWAV.data por id#variante (16 bits mono 44,1 kHz). Regenerar con devtools/drivers/w1audio_hashes.gd sólo si cambia una receta. Dependen de la libm de la plataforma (Windows x86-64).", "hashes": h}
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/w4audio")
	DirAccess.make_dir_recursive_absolute(dir)
	var p := dir.path_join("audio_hashes.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true) + "\n")
	f.close()
	print("escrito ", p, " (", h.size(), " hashes)")
	quit(0)
