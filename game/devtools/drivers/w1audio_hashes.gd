# W1-AUDIO: regenera tests/fixtures/audio_hashes.json (md5 del PCM de cada id y variante, generación en serie).
# Correr SÓLO cuando se cambia una receta a propósito. Uso: ./godot.sh --headless -s devtools/drivers/w1audio_hashes.gd
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
	var p := ProjectSettings.globalize_path("res://tests/fixtures/audio_hashes.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true) + "\n")
	f.close()
	print("escrito ", p, " (", h.size(), " hashes)")
	quit(0)
