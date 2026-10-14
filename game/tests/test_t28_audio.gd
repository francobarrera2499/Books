# T28 (W1-AUDIO; ARCHITECTURE §8, GDD§14.6): audio procedural.
# Hash del PCM estable (dos generaciones en el mismo proceso: hilos y serie; y contra tests/fixtures/audio_hashes.json),
# todos los ids de §8, banco completo en paralelo (el < 2 s, en test_a00_audio_budget), bucles sin clic, play emite subtítulo, nada se genera en _ready,
# y firmas de señal de cada receta (no se puede escuchar: se mide).
extends "res://tests/test_base.gd"

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
const AudioScript = preload("res://autoload/audio.gd")
const TIMEOUT_S := 180.0
const HASHES := "res://tests/fixtures/audio_hashes.json"
const SPEC_IDS := ["sfx.tijera", "sfx.papel", "sfx.pagina", "sfx.plumin", "sfx.secante", "sfx.sello", "sfx.sello_seco",
	"sfx.sobre", "evt.persiana_crane", "evt.lechero", "bells.st_clement", "clock.cuartos", "clock.tic", "hooves.madera",
	"hooves.granito", "harp.parker", "whistle.policia", "shot.silbido", "glass.tintineo", "evt.ladrillo",
	"evt.golpe_puerta", "amb.calle", "amb.noche", "amb.sala_lectura", "amb.diogenes", "amb.tienda", "amb.viento", "amb.parque"]
# v3 (GDD_v3 §6.8): sin amb.gas ni amb.gas_parker; la noche es amb.noche / amb.noche_parker (T35: calma)
const LOOP_IDS := ["clock.tic", "amb.calle", "amb.noche", "amb.sala_lectura", "amb.diogenes", "amb.tienda", "amb.viento", "amb.parque",
	"amb.calle_parker", "amb.noche_parker", "amb.casa_vacia", "amb.consultorio", "amb.vestibulo"]

static var _warm_inst = null       # instancia de audio.gd calentada (compartida entre tests del archivo)
static var _floats := {}           # id -> PackedFloat32Array decodificado del WAV

static func md5_bytes(b: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_MD5)
	c.update(b)
	return c.finish().hex_encode()

func _warmed():
	if _warm_inst == null:
		_warm_inst = AudioScript.new()
		_warm_inst.warm()
	return _warm_inst

func _x(id: String) -> PackedFloat32Array:
	if not _floats.has(id):
		_floats[id] = Synth.wav_to_floats(_warmed().stream(id))
		if Bank.is_loop(id):   # quitar las muestras de guarda del bucle
			var w: AudioStreamWAV = _warmed().stream(id)
			_floats[id] = _floats[id].slice(0, w.loop_end)
	return _floats[id]

func _add_to_tree(n: Node) -> void:
	tree.root.add_child(n)

# ---------------------------------------------------------------- banco
# El presupuesto de < 2 s se mide en tests/test_a00_audio_budget.gd, el primer archivo de la suite (proceso fresco, como
# el arranque del juego): en el mismo proceso, después de cientos de tests (o de otra generación completa), la misma
# generación en paralelo tarda ~2,5 veces más (estado del asignador de memoria; medido en la integración v3). Acá sólo
# se exige que el banco completo se genere en paralelo en un tiempo razonable.
func test_bank_threaded() -> void:
	var a = AudioScript.new()
	ok(a.threaded, "warm en paralelo por defecto")
	a.warm()
	ok(a.is_warm(), "warm genera todas las variantes de todos los ids")
	print("    T28 banco completo (con la suite ya corrida): %.0f ms (%d hilos)" % [a.last_warm_ms, OS.get_processor_count()])
	ok(a.last_warm_ms > 0.0 and a.last_warm_ms < 6000.0, "banco completo en paralelo < 6 s en medio de la suite (fue %.0f ms)" % a.last_warm_ms)
	_warm_inst = a
	_floats.clear()

func test_spec_ids_exist_and_format() -> void:
	for id in SPEC_IDS:
		ok(Bank.has(id), "falta el id de §8 " + id)
		var w = _warmed().stream(id)
		ok(w is AudioStreamWAV, "stream(%s) es AudioStreamWAV" % id)
		if not (w is AudioStreamWAV): continue
		eq(w.format, AudioStreamWAV.FORMAT_16_BITS, id + " 16 bits")
		eq(w.mix_rate, 44100, id + " 44,1 kHz")
		eq(w.stereo, false, id + " mono")
		var e := Bank.entry(id)
		var frames: int = w.data.size() / 2
		if Bank.is_loop(id):
			eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, id + " loop_mode forward")
			eq(w.loop_begin, 0, id + " loop_begin")
			eq(w.loop_end, Synth.n_of(float(e["dur"])), id + " loop_end = cuerpo")
			eq(frames, w.loop_end + Synth.LOOP_GUARD, id + " guarda tras loop_end")
		else:
			eq(w.loop_mode, AudioStreamWAV.LOOP_DISABLED, id + " sin bucle")
			eq(frames, Synth.n_of(float(e["dur"])), id + " duración")
	for id in LOOP_IDS: ok(Bank.is_loop(id), id + " es bucle")
	for al in Bank.ALIASES: ok(Bank.BANK.has(Bank.ALIASES[al]), "alias %s → id existente" % al)

func test_hash_stable_two_generations_and_fixture() -> void:
	# generación 1: warm() con hilos; generación 2: serie (Proc.pcm). Deben dar los mismos bytes.
	var a = _warmed()
	var fx := {}
	if FileAccess.file_exists(HASHES):
		var j = JSON.parse_string(FileAccess.get_file_as_string(HASHES))
		if j is Dictionary: fx = j.get("hashes", {})
	ok(not fx.is_empty(), "existe tests/fixtures/audio_hashes.json con hashes")
	var n := 0
	for id in Bank.ids():
		for v in Bank.variants(id):
			var h1 := md5_bytes(a._vars[id][v].data)
			var h2 := md5_bytes(Proc.pcm(id, v))
			eq(h1, h2, "%s#%d hilos == serie" % [id, v])
			var key := "%s#%d" % [id, v]
			ok(fx.has(key), "fixture tiene " + key)
			if fx.has(key): eq(h1, String(fx[key]), key + " == fixture")
			n += 1
	eq(fx.size(), n, "fixture sin ids sobrantes")
	# las variantes difieren entre sí
	ne(md5_bytes(a._vars["hooves.madera"][0].data), md5_bytes(a._vars["hooves.madera"][1].data), "variantes distintas")

# ---------------------------------------------------------------- calidad de señal
func test_loops_without_click() -> void:
	for id in LOOP_IDS:
		var w: AudioStreamWAV = _warmed().stream(id)
		var le: int = w.loop_end
		var x := _x(id)
		var d := w.data
		var last := x[le - 1]
		var first := x[w.loop_begin]
		var jump := absf(last - first)
		ok(jump < 0.02, "%s salto en el punto de bucle %.4f < 0,02" % [id, jump])
		# el salto no es atípico respecto de los pasos vecinos
		var s := 0.0
		var cnt := 0
		for i in range(le - 2000, le - 1):
			var st := x[i + 1] - x[i]
			s += st * st
			cnt += 1
		var rms_step := sqrt(s / float(cnt))
		ok(jump <= 4.0 * rms_step + 0.0005, "%s salto %.5f vs paso típico %.5f" % [id, jump, rms_step])
		for g in Synth.LOOP_GUARD:
			eq(d.decode_s16((le + g) * 2), d.decode_s16(g * 2), id + " guarda = cabeza")

func test_levels_edges_dc() -> void:
	for id in Bank.ids():
		var x := _x(id)
		var p := Synth.peak(x)
		ok(p <= 0.96, "%s pico %.3f ≤ 0,96 (sin saturar)" % [id, p])
		ok(p > 0.01, "%s no es silencio" % id)
		var m := 0.0
		for v in x: m += v
		m /= float(x.size())
		ok(absf(m) < 0.005, "%s sin continua (media %.4f)" % [id, m])
		if not Bank.is_loop(id):
			ok(absf(x[0]) < 0.003 and absf(x[x.size() - 1]) < 0.003, "%s empieza y termina en silencio (sin clic)" % id)
			var e := Bank.entry(id)
			near(p, float(e["level"]), 0.01, id + " pico normalizado")
		else:
			var r := linear_to_db(Synth.rms(x))
			ok(r > -52.0 and r < -20.0, "%s ambiente a nivel de fondo (%.1f dBFS)" % [id, r])

func test_no_harsh_highs() -> void:
	# nada de ondas crudas estridentes: poca energía arriba de 9 kHz y casi nada arriba de 14 kHz
	for id in Bank.ids():
		var sp := An.avg_spectrum(_x(id), 2048, 0.0, -1.0, 24)
		var hf := An.band_ratio(sp, 2048, 9000.0, 22050.0)
		var uhf := An.band_ratio(sp, 2048, 14000.0, 22050.0)
		ok(hf < 0.4, "%s energía > 9 kHz = %.3f" % [id, hf])
		ok(uhf < 0.03, "%s energía > 14 kHz = %.4f" % [id, uhf])

# ---------------------------------------------------------------- firmas por receta
func _centroid(id: String, t0 := 0.0, t1 := -1.0) -> float:
	return An.centroid(An.avg_spectrum(_x(id), 2048, t0, t1, 32), 2048)

func test_sig_desk() -> void:
	ok(_centroid("sfx.tijera") > 2500.0, "tijera brillante")
	var sp := An.avg_spectrum(_x("sfx.tijera"), 4096, 0.045, 0.2, 8)
	near(An.peak_freq(sp, 4096, 1900.0, 2300.0), 2100.0, 70.0, "anillo de la tijera 2,1 kHz")
	near(An.peak_freq(sp, 4096, 3150.0, 3650.0), 3400.0, 90.0, "anillo de la tijera 3,4 kHz")
	ok(_centroid("sfx.secante") < 450.0, "secante opaco (LP 300 Hz)")
	for id in ["sfx.papel", "sfx.pagina"]:
		var s2 := An.avg_spectrum(_x(id), 2048)
		ok(An.band_ratio(s2, 2048, 0.0, 600.0) < 0.25, id + " sin graves (HP 800 Hz)")
	ok(_x("sfx.pagina").size() > _x("sfx.papel").size(), "la página dura más que el papel")
	ok(An.band_ratio(An.avg_spectrum(_x("sfx.plumin"), 2048), 2048, 2000.0, 9000.0) > 0.6, "plumín: rasguido agudo")
	var ss := An.avg_spectrum(_x("sfx.sello"), 2048)
	ok(An.band_ratio(ss, 2048, 0.0, 200.0) > 0.3, "sello: golpe grave")
	ok(_centroid("sfx.sello_seco") > _centroid("sfx.sello"), "sello seco más agudo")
	ok(_energy_time(_x("sfx.sello_seco"), 0.95) < _energy_time(_x("sfx.sello"), 0.95), "sello seco más corto")

# Tiempo (s) en que la energía acumulada llega a frac.
func _energy_time(x: PackedFloat32Array, frac: float) -> float:
	var tot := 0.0
	for v in x: tot += v * v
	var acc := 0.0
	for i in x.size():
		acc += x[i] * x[i]
		if acc >= frac * tot: return float(i) / 44100.0
	return float(x.size()) / 44100.0

func test_sig_bells_and_clocks() -> void:
	var b := _x("bells.st_clement")
	var prime := 587.3
	ok(An.goertzel(b, prime * 2.0, 0, 44100) > 20.0 * An.goertzel(b, prime * 2.13, 0, 44100), "nominal de la primera campana")
	ok(An.goertzel(b, prime * 1.183, 0, 44100) > 10.0 * An.goertzel(b, prime * 1.09, 0, 44100), "tercera menor inarmónica (×1,183)")
	ok(An.goertzel(b, prime * 0.5, 0, 88200) > 10.0 * An.goertzel(b, prime * 0.62, 0, 88200), "hum (×0,5)")
	for f in [554.4, 493.9, 440.0]:
		ok(An.goertzel(b, f * 2.0, 0, 88200) > 10.0 * An.goertzel(b, f * 2.07, 0, 88200), "nominal de la campana %.0f Hz" % f)
	# cuartos: cada nota aparece al sonar (energía de su nominal sube después de su golpe)
	var c := _x("clock.cuartos")
	var notes := [415.3, 370.0, 329.6, 246.9]
	for k in 4:
		var t := 0.1 + 0.62 * k
		var b0: int = maxi(0, int((t - 0.27) * 44100))
		var before := An.goertzel(c, notes[k] * 2.0, b0, int((t - 0.02) * 44100) - b0)
		var after := An.goertzel(c, notes[k] * 2.0, int((t + 0.03) * 44100), 11025)
		ok(after > 8.0 * before, "nota %d del cuarto entra en su tiempo" % k)
	# tic: dos golpes por bucle de 2 s, a 1 Hz
	var tic := An.onsets(_x("clock.tic"), 0.002, 15.0, 0.3)
	eq(tic.size(), 2, "clock.tic: 2 golpes en el bucle")
	if tic.size() == 2: near(float(tic[1]) - float(tic[0]), 1.0, 0.01, "tic a 1 Hz")

func test_sig_hooves() -> void:
	for id in ["hooves.madera", "hooves.granito"]:
		var e := An.env_rms(_x(id), 0.005)
		var ac := An.autocorr_peak(e, 50, 76)   # 250–380 ms
		near(float(ac["lag"]) * 0.005, 1.0 / 3.2, 0.02, id + " pares a 3,2 Hz")
		ok(float(ac["r"]) > 0.2, id + " periodicidad clara")
	var gw := An.avg_spectrum(_x("hooves.granito"), 2048)
	var ww := An.avg_spectrum(_x("hooves.madera"), 2048)
	ok(An.band_ratio(gw, 2048, 1000.0, 6000.0) > 2.0 * An.band_ratio(ww, 2048, 1000.0, 6000.0), "granito más brillante que madera")
	ok(An.band_ratio(gw, 2048, 2600.0, 3000.0) > An.band_ratio(ww, 2048, 2600.0, 3000.0), "anillo de hierro 2,8 kHz en granito")

func test_sig_night() -> void:
	# arpa: periodicidad de 98 Hz y formante 400–1600 Hz
	var h := _x("harp.parker")
	var ac := An.autocorr_peak(h.slice(int(0.1 * 44100), int(0.5 * 44100)), 380, 520)
	near(44100.0 / float(ac["lag"]), 98.0, 3.0, "arpa a 98 Hz")
	ok(An.band_ratio(An.avg_spectrum(h, 2048), 2048, 380.0, 1700.0) > 0.25, "formante de la boca 400–1600 Hz")
	# silbato: 2100 y 2500 Hz con trémolo de 30 Hz
	var w := _x("whistle.policia")
	var sp := An.avg_spectrum(w, 8192, 0.1, 0.5, 8)
	near(An.peak_freq(sp, 8192, 1900.0, 2300.0), 2100.0, 40.0, "silbato 2100 Hz")
	near(An.peak_freq(sp, 8192, 2350.0, 2700.0), 2500.0, 40.0, "silbato 2500 Hz")
	var we := An.env_rms(w.slice(int(0.15 * 44100), int(0.5 * 44100)), 0.001)
	var tr := An.autocorr_peak(we, 25, 45)
	near(1.0 / (float(tr["lag"]) * 0.001), 30.0, 4.0, "trémolo 30 Hz")
	eq(An.onsets(w, 0.005, 12.0, 0.15).size(), 2, "dos toques de silbato")
	# silbido: el centroide baja (barrido 6 kHz → 1 kHz)
	ok(_centroid("shot.silbido", 0.04, 0.09) > 1.5 * _centroid("shot.silbido", 0.16, 0.24), "silbido barre hacia abajo")
	# vidrio: micro-campanas 3–9 kHz que siguen sonando ~1 s
	var g := _x("glass.tintineo")
	ok(An.band_ratio(An.avg_spectrum(g, 2048, 0.05, 1.3), 2048, 2800.0, 9500.0) > 0.5, "vidrio: parciales 3–9 kHz")
	var ge := An.env_rms(g, 0.05)
	var gmax := 0.0
	for v in ge: gmax = maxf(gmax, v)
	ok(ge[int(1.0 / 0.05)] > gmax * db_to_linear(-36.0), "tintineo largo (sigue a 1 s)")

func test_sig_events() -> void:
	eq(An.onsets(_x("evt.golpe_puerta"), 0.005, 12.0, 0.15).size(), 3, "tres golpes de puerta")
	var hp := _x("evt.persiana_crane").duplicate()
	Synth.hp(hp, 900.0)
	ok(An.onsets(hp, 0.003, 10.0, 0.08).size() >= 8, "persiana: 8 clics")
	ok(An.band_ratio(An.avg_spectrum(_x("evt.lechero"), 2048), 2048, 2000.0, 7000.0) > 0.1, "lechero: tintineo metálico ~2,4 kHz")
	var lad := An.avg_spectrum(_x("evt.ladrillo"), 2048)
	ok(An.band_ratio(lad, 2048, 0.0, 250.0) > 0.15 and An.band_ratio(lad, 2048, 1000.0, 6000.0) > 0.1, "ladrillo: golpe grave + cascotes")

func test_sig_ambience() -> void:
	ok(_centroid("amb.calle") < 700.0, "calle: rodar grave")
	ok(_centroid("amb.noche") < 700.0, "noche: rumor grave, sin siseo")
	ok(linear_to_db(Synth.rms(_x("amb.noche"))) < -42.0, "noche casi en silencio")
	ok(An.band_ratio(An.avg_spectrum(_x("amb.sala_lectura"), 2048), 2048, 150.0, 900.0) > 0.4, "sala: tono 200–800 Hz")
	# Diógenes: el tono de sala (mediana de la envolvente) ronda −48 dBFS
	var de := An.env_rms(_x("amb.diogenes"), 0.05)
	var arr := Array(de)
	arr.sort()
	near(linear_to_db(float(arr[arr.size() / 2])), -48.0, 4.0, "Diógenes −48 dBFS")
	# viento: ráfagas (la envolvente lenta varía) y banda 200–900 Hz
	var ve := An.env_rms(_x("amb.viento"), 0.1)
	var mean := 0.0
	for v in ve: mean += v
	mean /= float(ve.size())
	var sd := 0.0
	for v in ve: sd += (v - mean) * (v - mean)
	sd = sqrt(sd / float(ve.size()))
	ok(sd / mean > 0.15, "viento con ráfagas (cv %.2f)" % (sd / mean))
	var vc := _centroid("amb.viento")
	ok(vc > 200.0 and vc < 1000.0, "viento 200–900 Hz (centroide %.0f)" % vc)
	# parque: gorjeos agudos sobre la multitud
	ok(An.band_ratio(An.avg_spectrum(_x("amb.parque"), 2048), 2048, 2200.0, 6500.0) > 0.003, "parque: pájaros")
	# tienda: el reloj da 6 tics en 6 s
	var ti := _x("amb.tienda").duplicate()
	Synth.hp(ti, 2000.0)
	eq(An.onsets(ti, 0.002, 12.0, 0.5).size(), 6, "tienda: reloj a 1 Hz")

# ---------------------------------------------------------------- autoload
func test_nothing_generated_in_ready() -> void:
	var a = AudioScript.new()
	_add_to_tree(a)
	await tree.process_frame
	ok(a._bank.is_empty() and a._vars.is_empty(), "_ready no genera audio")
	eq(a.get_child_count(), 0, "_ready no crea reproductores")
	ok(AudioServer.get_bus_index("Amb") >= 0 and AudioServer.get_bus_index("Sfx") >= 0, "buses Amb y Sfx desde _ready (Opciones)")
	# el volumen que fije Opciones antes del primer sonido no se pisa al crear los reproductores
	var bi := AudioServer.get_bus_index("Amb")
	var prev := AudioServer.get_bus_volume_db(bi)
	AudioServer.set_bus_volume_db(bi, -11.0)
	a.play("sfx.sello_seco")
	near(AudioServer.get_bus_volume_db(bi), -11.0, 0.001, "primer play no pisa el volumen del bus Amb")
	AudioServer.set_bus_volume_db(bi, prev)
	a.queue_free()

func test_bank_contract_fields() -> void:
	# §8: const BANK = {id: {recipe, dur, loop, gain}}
	for id in Bank.ids():
		var e := Bank.entry(id)
		for k in ["recipe", "dur", "loop", "gain"]: ok(e.has(k), "%s tiene %s" % [id, k])
	# gain se aplica después de normalizar (no cambia la forma de onda, sólo el nivel)
	ok(Bank.entry("sfx.sello").get("gain", 0.0) == 1.0, "gain neutro por defecto")

func test_play_emits_subtitle() -> void:
	var a = AudioScript.new()
	_add_to_tree(a)
	var got: Array = []
	a.subtitle.connect(func(t: String, s: float) -> void: got.append([t, s]))
	a.play("harp.parker")
	eq(got.size(), 1, "play emite un subtítulo")
	if got.size() == 1:
		eq(got[0][0], "arpa de boca, lejos", "subtítulo descriptivo (audio.json)")
		ok(float(got[0][1]) >= 2.0 and float(got[0][1]) <= 6.0, "duración del subtítulo")
	var busy := 0
	for p in a._pool:
		if p.stream is AudioStreamRandomizer: busy += 1
	eq(busy, 1, "un reproductor del pool con el Randomizer")
	eq(a._pool.size(), 8, "pool de 8")
	ok(AudioServer.get_bus_index("Amb") >= 0 and AudioServer.get_bus_index("Sfx") >= 0, "buses Amb y Sfx")
	a.subtitles_on = false
	a.play("sfx.tijera")
	eq(got.size(), 1, "sin subtítulos si subtitles_on = false")
	a.subtitles_on = true
	a.play("no.existe")
	eq(got.size(), 1, "id desconocido: nada")
	a.play("hooves.madera")
	var r: AudioStreamRandomizer = a._rand["hooves.madera"]
	eq(r.streams_count, 3, "Randomizer con las 3 variantes")
	ok(r.random_pitch > 1.0, "Randomizer varía el tono")
	eq(got.size(), 2, "segundo subtítulo")
	# foley del propio clic (quiet_captions): suena sin subtítulo; lo que el jugador no ve hacer, sí
	for q in ["sfx.papel", "sfx.pagina", "sfx.plumin"]:
		ok(a.quiet(q), q + " es foley del clic")
		a.play(q)
	eq(got.size(), 2, "hojear, papel y plumín no se subtitulan")
	no(a.quiet("sfx.sello"))
	a.play("sfx.sello")
	eq(got.size(), 3, "el golpe del sello sí")
	a.queue_free()

func test_place_ambience_and_config() -> void:
	var a = AudioScript.new()
	_add_to_tree(a)
	var got: Array = []
	a.subtitle.connect(func(t: String, s: float) -> void: got.append(t))
	var cases := [["L2", "M", "amb.sala_lectura"], ["L1.tienda", "T", "amb.tienda"], ["L1", "N", "amb.noche"],
		["L1", "M", "amb.calle"], ["L3", "N", "amb.calle_parker"], ["L3", "10.N", "amb.viento"], ["L3", "9.N", "amb.calle_parker"],
		["L5", "T", "amb.diogenes"], ["L7", "10.T", "amb.parque"], ["L1", "10.night", "amb.viento"], ["L1", "9.night", "amb.noche"],
		["L1", "P.N", "amb.noche"]]
	for c in cases:
		a.set_place_ambience(c[0], c[1])
		eq(a.current_amb(), c[2], "ambiente de %s/%s" % [c[0], c[1]])
	ok(got.has(a.caption("amb.noche")) and got.has("viento"), "cambiar de ambiente emite subtítulo")
	a.set_place_ambience("L99", "M")
	eq(a.current_amb(), "", "lugar sin ambiente: silencio")
	eq(a.stream("amb.street"), a.stream("amb.calle"), "alias de §4.17")
	# configuración completa y coherente
	var cfg: Dictionary = a._config()
	for id in Bank.ids():
		var cap := a.caption(id)
		ok(cap != "", "subtítulo para " + id)
		for gl in ["†", "‡", "⅓", "℔"]: ok(not cap.contains(gl), "glifo prohibido en subtítulo de " + id)
	for p in cfg.get("ambience", {}):
		for s in cfg["ambience"][p]:
			var v = cfg["ambience"][p][s]
			var vid: String = String(v.get("id", "")) if v is Dictionary else String(v)
			ok(vid == "" or Bank.has(vid), "ambiente %s/%s → id existente (%s)" % [p, s, vid])
	for ev in cfg.get("events", {}):
		for id in cfg["events"][ev]: ok(Bank.has(String(id)), "evento %s → id existente %s" % [ev, id])
	eq(a.event_ids("dawn"), ["bells.st_clement", "evt.lechero", "evt.persiana_crane"], "ritual del amanecer")
	var total: float = a.play_event("pasada_tinta")
	ok(total > 1.0 and total < 3.0, "secuencia de pasada en tinta (%.2f s)" % total)
	a.stop_amb(0.0)
	a.queue_free()
	await tree.process_frame

func test_playback_through_audioserver() -> void:
	# el mezclador (driver Dummy en headless) avanza los bucles y los sueltos sin errores
	var a = AudioScript.new()
	_add_to_tree(a)
	a.play_amb("amb.noche", 0.1)
	a.play("sfx.sello")
	await tree.create_timer(0.4).timeout
	var amb: AudioStreamPlayer = a._amb[a._amb_cur]
	ok(amb.playing, "el ambiente suena")
	ok(amb.get_playback_position() > 0.0, "el ambiente avanza")
	near(amb.volume_db, 0.0, 0.5, "fundido de entrada completo")
	a.set_place_ambience("L5", "T")
	await tree.create_timer(1.3).timeout
	eq(a.current_amb(), "amb.diogenes", "cambio de ambiente")
	var old: AudioStreamPlayer = a._amb[1 - a._amb_cur]
	ok(not old.playing, "el ambiente anterior se detiene tras el fundido")
	a.stop_amb(0.0)
	ok(not a._amb[a._amb_cur].playing, "stop_amb")
	# play() de un id de bucle va al ambiente y respeta volume_db
	a.play("clock.tic", -9.0)
	eq(a.current_amb(), "clock.tic", "play de un bucle → ambiente")
	await tree.create_timer(1.2).timeout
	near(a._amb[a._amb_cur].volume_db, -9.0, 0.5, "play(bucle, volume_db) respeta el volumen")
	a.stop_amb(0.0)
	a.queue_free()
	await tree.process_frame

func test_zz_cleanup() -> void:
	# libera la instancia calentada compartida (evita fugas al salir)
	if _warm_inst != null:
		_warm_inst.free()
		_warm_inst = null
	_floats.clear()
	ok(true)
