# T28 (presupuesto de arranque; ARCHITECTURE §8, GDD§14.6): el banco de sonido completo (todas las variantes de todos los
# ids, en paralelo con WorkerThreadPool) se genera en < 2 s. Es el PRIMER archivo de la suite (orden alfabético: «a00»)
# para medir en un proceso fresco, como en la pantalla de título: en el mismo proceso, después de otras generaciones o
# de cientos de tests, la misma generación tarda ~2,5 veces más (medido en la integración v3). El resto de T28 (hashes,
# ids, bucles, firmas) está en test_t28_audio.gd.
extends "res://tests/test_base.gd"

const AudioScript = preload("res://autoload/audio.gd")
const TIMEOUT_S := 60.0

func test_bank_under_2s_threaded_fresh_process() -> void:
	var a = AudioScript.new()
	ok(a.threaded, "warm en paralelo por defecto")
	a.warm()
	ok(a.is_warm(), "warm genera todas las variantes de todos los ids")
	print("    T28 banco completo (proceso fresco): %.0f ms (%d hilos)" % [a.last_warm_ms, OS.get_processor_count()])
	ok(a.last_warm_ms > 0.0 and a.last_warm_ms < 2000.0, "banco completo < 2 s (fue %.0f ms)" % a.last_warm_ms)
	a.free()
