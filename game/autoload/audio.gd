# Autoload Audio. Dueño: W1-AUDIO. Contrato: docs/ARCHITECTURE.md §2.2 y §8.
# STUB con firmas definitivas. Genera WAV procedurales (audio/proc_audio.gd) de forma perezosa (warm()),
# nunca en _ready durante tests. Sin AudioStreamGenerator. Subtítulos encendidos por defecto.
extends Node

signal subtitle(text: String, seconds: float)

var subtitles_on := true
var _bank := {}                  # id -> AudioStreamWAV (lleno por warm())

func warm() -> void:
	pass  # W1-AUDIO: genera el banco completo (determinista)

func play(id: String, volume_db := 0.0) -> void:
	pass

func play_amb(id: String, fade_s := 1.0) -> void:
	pass

func stop_amb(fade_s := 1.0) -> void:
	pass

func set_place_ambience(place: String, slot: String) -> void:
	pass

func stream(id: String) -> AudioStream:
	return _bank.get(id, null)
