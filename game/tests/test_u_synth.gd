# Unitarios de audio/synth.gd y audio/analysis.gd (W1-AUDIO): ruido determinista, filtros, envolventes, osciladores,
# bucles, plegado, cambio de tasa, salida PCM/WAV.
extends "res://tests/test_base.gd"

const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
const SR := 44100

func _sine(n: int, f: float, amp := 0.5) -> PackedFloat32Array:
	var x := Synth.zeros(n)
	Synth.add_sine(x, 0, n, f, amp)
	return x

func test_rng_and_noise_deterministic() -> void:
	var a := Synth.Rng.new(1234)
	var b := Synth.Rng.new(1234)
	for k in 100:
		var u := a.f()
		eq(u, b.f(), "misma semilla, misma secuencia")
		ok(u >= 0.0 and u < 1.0, "f() en [0,1)")
	var c := Synth.Rng.new(1235)
	ne(Synth.Rng.new(1234).f(), c.f(), "semillas vecinas difieren")
	for k in 200:
		var i := a.i(2, 5)
		ok(i >= 2 and i <= 5, "i() en rango")
	eq(Synth.white(1000, 7), Synth.white(1000, 7), "ruido blanco determinista")
	ne(Synth.white(1000, 7), Synth.white(1000, 8), "otra semilla, otro ruido")
	eq(Synth.seed_of("sfx.tijera#0"), Synth.seed_of("sfx.tijera#0"), "semilla por id estable")
	var w := Synth.white(44100, 3)
	near(Synth.rms(w), 1.0 / sqrt(3.0), 0.02, "blanco uniforme: RMS 1/√3")
	# rosa y marrón: más energía en graves que el blanco
	var p := Synth.pink(44100, 3)
	var br := Synth.brown(44100, 3)
	var sw := An.avg_spectrum(w, 2048)
	ok(An.band_ratio(An.avg_spectrum(p, 2048), 2048, 0.0, 1000.0) > 3.0 * An.band_ratio(sw, 2048, 0.0, 1000.0), "rosa con más graves")
	ok(An.band_ratio(An.avg_spectrum(br, 2048), 2048, 0.0, 300.0) > 0.5, "marrón concentrado en graves")

func test_biquad_responses() -> void:
	var n := 22050
	var lo := Synth.lp(_sine(n, 200.0), 1000.0)
	var hi := Synth.lp(_sine(n, 8000.0), 1000.0)
	ok(Synth.rms(lo.slice(4410)) > 0.3, "LP deja pasar 200 Hz")
	ok(Synth.rms(hi.slice(4410)) < 0.02, "LP corta 8 kHz")
	var h1 := Synth.hp(_sine(n, 100.0), 1000.0)
	ok(Synth.rms(h1.slice(4410)) < 0.01, "HP corta 100 Hz")
	var b1 := Synth.bp(_sine(n, 1000.0), 1000.0, 2.0)
	var b2 := Synth.bp(_sine(n, 4000.0), 1000.0, 2.0)
	near(Synth.rms(b1.slice(4410)), 0.5 / sqrt(2.0), 0.02, "BP con ganancia 1 en la central")
	ok(Synth.rms(b2.slice(4410)) < 0.1, "BP atenúa lejos de la central")
	var pk := Synth.peak_eq(_sine(n, 1000.0), 1000.0, 1.0, 6.0)
	near(Synth.rms(pk.slice(4410)) / (0.5 / sqrt(2.0)), db_to_linear(6.0), 0.05, "peaking +6 dB")
	var s1 := Synth.lp1(_sine(n, 5000.0), 500.0)
	ok(Synth.rms(s1.slice(4410)) < 0.06, "polo simple suaviza")
	# SVF modulado: BP sigue a la curva de control
	var x := _sine(n, 2000.0)
	var f_lo := Synth.ctl_pts(n, [[0.0, 500.0], [0.5, 500.0]])
	var f_on := Synth.ctl_pts(n, [[0.0, 2000.0], [0.5, 2000.0]])
	ok(Synth.rms(Synth.svf(x.duplicate(), Synth.BP, f_on, 4.0).slice(4410)) > 3.0 * Synth.rms(Synth.svf(x.duplicate(), Synth.BP, f_lo, 4.0).slice(4410)), "SVF BP centrado")
	ok(Synth.rms(Synth.svf(_sine(n, 100.0), Synth.HP, f_on, 0.7).slice(4410)) < 0.01, "SVF HP")
	ok(Synth.rms(Synth.svf(_sine(n, 100.0), Synth.LP, f_on, 0.7).slice(4410)) > 0.3, "SVF LP")

func test_ctl_and_envelopes() -> void:
	var c := Synth.ctl_pts(SR, [[0.0, 100.0], [1.0, 1000.0]], true)
	near(c[0], 100.0, 0.5, "curva: inicio")
	near(c[Synth.nblocks(SR) / 2], sqrt(100.0 * 1000.0), 10.0, "curva geométrica: media geométrica a la mitad")
	var one := Synth.zeros(SR)
	one.fill(1.0)
	Synth.mul_pts(one, [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]], false)
	near(one[SR / 4], 0.5, 0.01, "tramo lineal")
	near(one[SR / 2], 1.0, 0.01, "pico")
	var e := Synth.env_adsr(1000, 10.0 / SR, 10.0 / SR, 0.5, 100.0 / SR)
	near(e[10], 1.0, 0.01, "ADSR: fin del ataque")
	near(e[500], 0.5, 0.001, "ADSR: sostén")
	near(e[999], 0.0, 0.001, "ADSR: relajación a cero")
	var f := Synth.zeros(1000)
	f.fill(1.0)
	Synth.fade(f, 100.0 / SR, 100.0 / SR)
	eq(f[0], 0.0, "fundido de entrada desde 0")
	ok(f[999] < 0.001, "fundido de salida a 0")
	var w := Synth.zeros(SR)
	w.fill(1.0)
	Synth.mul_wobble(w, 5, 4.0, 0.2, 1.0)
	var mn := 2.0
	var mx := -1.0
	var step := 0.0
	for i in range(1, SR):
		mn = minf(mn, w[i]); mx = maxf(mx, w[i]); step = maxf(step, absf(w[i] - w[i - 1]))
	ok(mn >= 0.2 - 1e-4 and mx <= 1.0 + 1e-4, "wobble en [lo, hi]")
	ok(step < 0.002, "wobble suave (sin escalones)")

func test_modes_and_oscillators() -> void:
	var x := Synth.zeros(SR)
	Synth.add_mode(x, 100, 1000.0, 0.1, 1.0)
	eq(x[99], 0.0, "modo empieza en start")
	near(absf(x[100]), 0.0, 1e-6, "modo arranca en fase 0 (sin clic)")
	var e1 := Synth.rms(x.slice(100 + 4410 - 441, 100 + 4410 + 441))
	var e2 := Synth.rms(x.slice(100 + 8820 - 441, 100 + 8820 + 441))
	near(e1 / e2, exp(1.0), 0.1, "decae e^-1 por tau")
	near(An.peak_freq(An.avg_spectrum(x, 8192, 0.0, 0.3, 4), 8192, 500.0, 2000.0), 1000.0, 3.0, "frecuencia del modo")
	var s := _sine(SR, 440.0, 0.5)
	near(Synth.peak(s), 0.5, 0.001, "seno por recurrencia: amplitud estable")
	near(An.peak_freq(An.avg_spectrum(s, 8192), 8192, 300.0, 600.0), 440.0, 2.0, "seno 440 Hz")
	var sw := Synth.saw(SR, PackedFloat32Array([98.0]))
	near(An.peak_freq(An.avg_spectrum(sw, 8192), 8192, 60.0, 150.0), 98.0, 2.0, "sierra 98 Hz")
	ok(An.band_ratio(An.avg_spectrum(sw, 2048), 2048, 16000.0, 22050.0) < 0.01, "sierra PolyBLEP sin aliasing fuerte")
	var f := Synth.fm(SR, 1000.0, 100.0, 1.0)
	var sp := An.avg_spectrum(f, 8192)
	ok(An.goertzel(f, 1100.0) > 10.0 * An.goertzel(f, 1050.0), "FM: banda lateral a fc+fm")
	near(An.peak_freq(sp, 8192, 900.0, 1050.0), 1000.0, 3.0, "FM: portadora")
	var ch := Synth.zeros(4410)
	Synth.add_chirp(ch, 0, 4410, Synth.ctl_pts(4410, [[0.0, 3000.0], [0.1, 3000.0]]), 1.0)
	near(An.peak_freq(An.avg_spectrum(ch, 2048), 2048, 2000.0, 4000.0), 3000.0, 30.0, "gorjeo a su frecuencia")
	eq(ch[0], 0.0, "gorjeo con ventana Hann")
	var th := Synth.zeros(4410)
	Synth.add_thump(th, 0, 120.0, 70.0, 0.01, 0.03, 1.0)
	ok(Synth.peak(th) > 0.3 and absf(th[4409]) < 0.05, "golpe sordo decae")
	var bu := Synth.zeros(4410)
	Synth.add_burst(bu, 10, 0.001, 0.005, 1.0, 9)
	eq(bu[10], 0.0, "ráfaga con ataque")
	ok(Synth.rms(bu.slice(10, 400)) > 10.0 * Synth.rms(bu.slice(3000)), "ráfaga decae")

func test_loop_fold_and_rates() -> void:
	# make_loop: el punto de bucle es el paso natural x[L-1] → x[L]
	var x := Synth.lp(Synth.white(SR + 4410, 11), 2000.0)
	var y := Synth.make_loop(x.duplicate(), 0.1)
	eq(y.size(), SR, "largo del bucle")
	near(y[0], x[SR], 1e-6, "cabeza = continuación de la cola")
	near(y[SR - 1], x[SR - 1], 1e-6, "cola intacta")
	near(y[5000], x[5000], 1e-6, "cuerpo intacto")
	# fold: una cola que pasa del final entra por la cabeza
	var ev := Synth.zeros(150)
	ev[120] = 1.0
	ev[20] = 0.5
	var fo := Synth.fold(ev, 100)
	eq(fo.size(), 100, "fold largo")
	near(fo[20], 1.5, 1e-6, "fold suma circular")
	# diezmado y sobremuestreo
	var s := _sine(SR, 1000.0, 0.5)
	var d := Synth.downsample2(s)
	eq(d.size(), SR / 2, "diezmado ×2")
	var u := Synth.upsample2(d, SR)
	eq(u.size(), SR, "sobremuestreo ×2")
	var err := 0.0
	for i in range(100, SR - 100): err = maxf(err, absf(u[i] - s[i] * cos(PI * 1000.0 / SR) * cos(PI * 1000.0 / SR)))
	ok(err < 0.01, "ida y vuelta de tasa conserva un seno de 1 kHz (err %.4f)" % err)
	var rv := Synth.zeros(SR)
	rv[100] = 1.0
	Synth.reverb_lofi(rv, 1.0, 0.8, 0.3, 1.0)
	ok(Synth.rms(rv.slice(4410, 22050)) > 1e-4, "reverb_lofi deja cola")
	var r2 := Synth.zeros(SR)
	r2[100] = 1.0
	Synth.reverb(r2, 1.0, 0.8, 0.3, 1.0, 0.0)
	ok(Synth.rms(r2.slice(4410, 22050)) > 1e-4 and Synth.rms(r2.slice(40000)) < Synth.rms(r2.slice(4410, 22050)), "reverb decae")

func test_levels_and_output() -> void:
	var x := _sine(1000, 440.0, 2.0)
	Synth.limit(x, 0.95, 0.8)
	ok(Synth.peak(x) <= 0.95, "limitador: techo")
	var y := _sine(1000, 440.0, 0.3)
	Synth.normalize(y, 0.6)
	near(Synth.peak(y), 0.6, 1e-4, "normalizar al pico")
	Synth.to_rms(y, 0.1)
	near(Synth.rms(y), 0.1, 1e-4, "llevar a RMS")
	var z := Synth.zeros(100)
	z[0] = 0.5
	z[99] = -0.25
	var w := Synth.to_wav(z, true)
	eq(w.format, AudioStreamWAV.FORMAT_16_BITS, "16 bits")
	eq(w.mix_rate, 44100, "44,1 kHz")
	eq(w.stereo, false, "mono")
	eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "bucle hacia adelante")
	eq(w.loop_end, 100, "loop_end = cuerpo")
	eq(w.data.size(), (100 + Synth.LOOP_GUARD) * 2, "guarda tras el bucle")
	near(Synth.sample_at(w, 0), 0.5, 1e-4, "muestra 0")
	near(Synth.sample_at(w, 99), -0.25, 1e-4, "última muestra")
	near(Synth.sample_at(w, 100), 0.5, 1e-4, "guarda = cabeza")
	var w2 := Synth.to_wav(z, false)
	eq(w2.loop_mode, AudioStreamWAV.LOOP_DISABLED, "sin bucle")
	eq(w2.data.size(), 200, "sin guarda")
	eq(Synth.wav_to_floats(w2).size(), 100, "decodificar")

func test_analysis_helpers() -> void:
	var x := Synth.zeros(SR)
	for t in [0.1, 0.4, 0.7]:
		Synth.add_mode(x, int(t * SR), 1500.0, 0.02, 1.0)
	var on := An.onsets(x, 0.005, 12.0, 0.1)
	eq(on.size(), 3, "tres ataques")
	if on.size() == 3:
		near(on[1], 0.4, 0.01, "tiempo del ataque")
	var e := An.env_rms(x, 0.005)
	var ac := An.autocorr_peak(e, 40, 80)
	near(float(ac["lag"]) * 0.005, 0.3, 0.01, "autocorrelación encuentra el período")
	var s := _sine(SR, 2500.0)
	near(An.centroid(An.avg_spectrum(s, 2048), 2048), 2500.0, 60.0, "centroide de un seno")
	ok(An.goertzel(s, 2500.0) > 100.0 * An.goertzel(s, 3000.0), "Goertzel selectivo")
	var img := An.spectrogram_image(s, 64, 32, 40.0, 16000.0, 512, 10)
	eq(img.get_size(), Vector2i(64, 42), "imagen de espectrograma")
