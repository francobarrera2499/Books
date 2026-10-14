# T35 (REACCIONES-PIEZA, GDD_v3 §6.8): sonido tranquilo en todos los lugares. No se puede escuchar: se mide.
# Regla de calma, sobre los bucles que usa data/audio.json (ambience):
#   · RMS del bucle ≤ −32 dBFS y, en la banda de 2–8 kHz (siseo), ≤ −40 dBFS;
#   · los eventos sueltos del ambiente (coche, página, campana, tonada: tramos ≥ 3 dB sobre el fondo del bucle) están
#     separados ≥ 8 s, contando el punto de bucle;
#   · el tic del reloj (L4 estudio) ≤ −26 dBFS en su ventana de 0,4 s más fuerte (el tictac es su textura, no un evento).
# Además: amb.gas y amb.gas_parker se retiraron de todo uso (y del banco); la noche de la pieza y las láminas PRO/M7 son
# amb.noche (casi silencio: un coche lejano y la campana de los cuartos; en PRO, el arpa de Parker de vez en cuando); la
# corriente de aire al entrar con la ventana abierta (evento intrusion_techos → evt.corriente: ráfaga de 3 s de ruido rosa
# 200–900 Hz con envolvente suave, −29 dB aprox. (playtest v3: −8 dB), subtítulo «una corriente de aire»).
extends "res://tests/test_base.gd"

const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
const AudioScript = preload("res://autoload/audio.gd")
const TIMEOUT_S := 240.0
const MAX_RMS_DB := -32.0
const MAX_HISS_DB := -40.0
const MIN_GAP_S := 8.0
const MAX_TIC_DB := -26.0
const TIC_ID := "clock.tic"

static var _inst = null
static var _xs := {}

func _audio():
	if _inst == null:
		_inst = AudioScript.new()
		_inst.warm()
	return _inst

func _x(id: String) -> PackedFloat32Array:
	if not _xs.has(id):
		var w: AudioStreamWAV = _audio().stream(id)
		var f := Synth.wav_to_floats(w)
		if Bank.is_loop(id): f = f.slice(0, w.loop_end)
		_xs[id] = f
	return _xs[id]

# ids de bucle que suenan en algún lugar o lámina (data/audio.json ambience)
func _used_loops() -> Array:
	var out: Array = []
	var amb: Dictionary = _audio()._config().get("ambience", {})
	for p in amb:
		for s in amb[p]:
			var v = amb[p][s]
			var id := String(v.get("id", "")) if v is Dictionary else String(v)
			if id != "" and not out.has(id):
				out.append(id)
	out.sort()
	return out

func test_calm_levels_hiss_and_spacing() -> void:
	var used := _used_loops()
	ok(used.size() >= 8, "ambientes en uso: %s" % str(used))
	for id in used:
		ok(Bank.is_loop(id), id + " es bucle")
		var x := _x(id)
		var L := float(x.size()) / 44100.0
		var r := An.rms_db(x)
		var hiss := An.band_rms_db(x, 2000.0, 8000.0)
		print("    T35 %-18s %5.1f s · RMS %6.1f dBFS · 2–8 kHz %6.1f dBFS" % [id, L, r, hiss])
		ok(r <= MAX_RMS_DB, "%s: RMS %.1f dBFS > %.0f" % [id, r, MAX_RMS_DB])
		ok(hiss <= MAX_HISS_DB, "%s: siseo 2–8 kHz %.1f dBFS > %.0f" % [id, hiss, MAX_HISS_DB])
		if id == TIC_ID:
			continue
		var ev := An.loop_events(x, 0.1, 3.0)
		if ev.is_empty():
			print("        sin eventos sueltos")
			continue
		var gap := An.min_gap_circular(ev, L)
		print("        eventos %s · separación mínima %.1f s" % [str(ev), gap])
		ok(gap >= MIN_GAP_S - 0.05, "%s: eventos sueltos a %.1f s (< %.0f s): %s" % [id, gap, MIN_GAP_S, str(ev)])

func test_clock_tic_quiet() -> void:
	var a = _audio()
	eq(String(a.ambience_for("L4.estudio", "6.T").id), TIC_ID, "el estudio del doctor: el reloj")
	var t := An.loudest_window_db(_x(TIC_ID), 0.4)
	print("    T35 clock.tic ventana 0,4 s más fuerte %.1f dBFS" % t)
	ok(t <= MAX_TIC_DB, "tic del reloj %.1f dBFS > %.0f" % [t, MAX_TIC_DB])

func test_no_gas_hiss_anywhere() -> void:
	for id in ["amb.gas", "amb.gas_parker"]:
		no(Bank.BANK.has(id), "%s fuera del banco" % id)
		no(_used_loops().has(id), "%s fuera de los ambientes" % id)
	var cfg: Dictionary = _audio()._config()
	no(JSON.stringify(cfg.get("ambience", {})).contains("amb.gas"), "ningún ambiente nombra amb.gas")
	for id in cfg.get("captions", {}):
		no(String(id).begins_with("amb.gas"), "sin subtítulo para %s" % id)
		no(String(cfg.captions[id]).contains("siseo"), "ningún subtítulo de siseo (%s)" % id)

func test_night_is_almost_silent() -> void:
	var a = _audio()
	for c in [["L1", "4.N"], ["L1", "4.night"], ["L1", "0.N"], ["PL.M7", "7.night"]]:
		eq(String(a.ambience_for(c[0], c[1]).id), "amb.noche", "%s %s: la noche tranquila" % c)
	eq(String(a.ambience_for("PL.prologo", "0.N").id), "amb.noche_parker", "el prólogo: la noche y, de vez en cuando, el arpa")
	eq(String(a.ambience_for("L1", "10.night").id), "amb.viento", "la noche del 5 sigue con viento")
	for id in ["amb.noche", "amb.noche_parker"]:
		var x := _x(id)
		var L := float(x.size()) / 44100.0
		ok(L >= 20.0, "%s: bucle largo (%.0f s): un coche cada 20–40 s" % [id, L])
		ok(An.rms_db(x) <= -42.0, "%s casi silencio (%.1f dBFS)" % [id, An.rms_db(x)])
		var ev := An.loop_events(x, 0.1, 3.0)
		ok(ev.size() >= 2, "%s: un coche lejano y la campana de los cuartos (%s)" % [id, str(ev)])
		ok(not a.caption(id).is_empty() and not a.caption(id).contains("gas"), "%s: subtítulo sin gas" % id)
	ok(An.loop_events(_x("amb.noche_parker"), 0.1, 3.0).size() >= 3, "en el prólogo, además, el arpa de Parker")

func test_draft_on_entering_with_open_window() -> void:
	var a = _audio()
	eq(a.event_ids("intrusion_techos"), ["evt.corriente"], "el evento de UI-MUNDO: una sola ráfaga")
	ok(Bank.has("evt.corriente") and not Bank.is_loop("evt.corriente"))
	eq(a.caption("evt.corriente"), "una corriente de aire", "subtítulo neutro")
	var x := _x("evt.corriente")
	near(float(x.size()) / 44100.0, 3.0, 0.05, "3 s")
	var c := An.centroid(An.avg_spectrum(x, 2048), 2048)
	ok(c > 200.0 and c < 900.0, "ruido 200–900 Hz (centroide %.0f)" % c)
	eq(An.onsets(x, 0.005, 10.0, 0.3).size(), 0, "envolvente suave: sin golpes")
	var l := An.loudness_max(x)
	print("    T35 evt.corriente sonoridad máx %.1f dB" % l)
	ok(l >= -31.0 and l <= -26.0, "−29 dB aprox., sin alerta (playtest v3) (%.1f)" % l)

func test_zz_cleanup() -> void:
	if _inst != null:
		_inst.free()
		_inst = null
	_xs.clear()
	ok(true)
