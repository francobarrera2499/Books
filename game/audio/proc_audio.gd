# audio/proc_audio.gd — W1-AUDIO (ARCHITECTURE §8, GDD§14.6). Recetas procedurales: id → muestras → AudioStreamWAV.
# Determinista: semilla = md5("<id>#<variante>") y RNG propio (Synth.Rng). Sin estado: apto para hilos (render/pcm).
# Bucles: lecho de ruido de dur+fade con fundido cruzado de igual potencia (Synth.make_loop) + capa de eventos
# renderizada larga y plegada en circular (Synth.fold): ni clic ni hueco en el punto de bucle.
extends RefCounted

const Synth = preload("res://audio/synth.gd")
const Bank = preload("res://audio/sound_bank.gd")
const SR := 44100

# ---------------------------------------------------------------- API
static func gen(id: String) -> AudioStreamWAV:
	return gen_variant(id, 0)

static func gen_variant(id: String, variant: int) -> AudioStreamWAV:
	var x := render(id, variant)
	if x.is_empty(): return null
	return Synth.to_wav(x, Bank.is_loop(id))

# PCM 16 bits listo para AudioStreamWAV.data (thread-safe).
static func pcm(id: String, variant := 0) -> PackedByteArray:
	return Synth.pcm16(render(id, variant), Bank.is_loop(id))

static func wav_from_pcm(id: String, bytes: PackedByteArray) -> AudioStreamWAV:
	var loop := Bank.is_loop(id)
	var frames: int = bytes.size() / 2
	if loop: frames -= mini(Synth.LOOP_GUARD, frames)
	return Synth.wav_from_pcm(bytes, loop, frames)

static func render(id: String, variant := 0) -> PackedFloat32Array:
	var key := Bank.resolve(id)
	if not Bank.BANK.has(key): return PackedFloat32Array()
	var e: Dictionary = Bank.BANK[key]
	var rng := Synth.Rng.new(Synth.seed_of("%s#%d" % [key, variant]))
	var dur: float = e["dur"]
	var loop: bool = e["loop"]
	var fd: float = e.get("fade", 0.0)
	var x := _recipe(String(e["recipe"]), dur, fd, rng)
	if not loop:
		Synth.dc_block(x)
		Synth.fade(x, 0.0015, float(e.get("out", 0.03)))
	if String(e.get("norm", "peak")) == "peak":
		Synth.normalize(x, float(e.get("level", 0.6)))
	var gain: float = float(e.get("gain", 1.0))       # ganancia final lineal (campo del contrato §8; 1 = sin cambio)
	if gain != 1.0: Synth.scale(x, gain)
	Synth.limit(x, 0.95, 0.8)
	return x

static func _recipe(r: String, dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	match r:
		"tijera": return _tijera(dur, rng)
		"papel": return _paper(dur, rng, false)
		"pagina": return _paper(dur, rng, true)
		"plumin": return _plumin(dur, rng)
		"secante": return _secante(dur, rng)
		"sello": return _sello(dur, rng, false)
		"sello_seco": return _sello(dur, rng, true)
		"sobre": return _sobre(dur, rng)
		"persiana": return _persiana(dur, rng)
		"lechero": return _lechero(dur, rng)
		"bells": return _bells(dur, rng)
		"cuartos": return _cuartos(dur, rng)
		"tic": return _tic(dur, fd, rng)
		"hooves_madera": return _hooves(dur, rng, false)
		"hooves_granito": return _hooves(dur, rng, true)
		"harp": return _harp(dur, rng)
		"whistle": return _whistle(dur, rng)
		"silbido": return _silbido(dur, rng)
		"glass": return _glass(dur, rng)
		"ladrillo": return _ladrillo(dur, rng)
		"golpe_puerta": return _golpe_puerta(dur, rng)
		"amb_calle": return _amb_calle(dur, fd, rng)
		"amb_gas": return _amb_gas(dur, fd, rng)
		"amb_sala_lectura": return _amb_sala_lectura(dur, fd, rng)
		"amb_diogenes": return _amb_diogenes(dur, fd, rng)
		"amb_tienda": return _amb_tienda(dur, fd, rng)
		"amb_viento": return _amb_viento(dur, fd, rng)
		"amb_parque": return _amb_parque(dur, fd, rng)
	push_warning("proc_audio: receta desconocida " + r)
	return Synth.zeros(Synth.n_of(dur))

static func _n(s: float) -> int:
	return Synth.n_of(s)

# ---------------------------------------------------------------- escritorio
# Tijera: cizalla de hojas (ruido BP 3–6 kHz, ~25 ms) + cierre (clic + anillo metálico 2,1/3,4 kHz, ~60 ms).
static func _tijera(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var t1 := _n(0.004)
	var sh := Synth.zeros(n)
	Synth.add_burst(sh, t1, 0.003, 0.007, 1.0, rng.sub())
	Synth.add_burst(sh, t1 + _n(0.006), 0.012, 0.012, 0.35, rng.sub())
	Synth.band(sh, 3000.0, 6000.0)
	Synth.mix(x, sh, 0, 1.0)
	# papel que cede bajo la hoja
	var pp := Synth.zeros(n)
	for k in 5:
		Synth.add_grain(pp, t1 + _n(rng.r(0.0, 0.03)), _n(rng.r(0.003, 0.008)), rng.r(0.2, 0.5), rng.sub())
	Synth.hp(pp, 1500.0)
	Synth.mix(x, pp, 0, 0.5)
	var t2 := t1 + _n(rng.r(0.030, 0.040))
	var ck := Synth.zeros(n)
	Synth.add_burst(ck, t2, 0.0004, 0.0012, 1.0, rng.sub())
	Synth.hp(ck, 1800.0)
	Synth.mix(x, ck, 0, 0.7)
	var d := rng.r(0.98, 1.02)
	Synth.add_mode(x, t2, 2100.0 * d, 0.020, 0.30)
	Synth.add_mode(x, t2, 3400.0 * d, 0.015, 0.24)
	Synth.add_mode(x, t2, 5150.0 * d, 0.006, 0.08)
	Synth.lp(x, 9500.0)
	return x

static func _gesture(u: float, a: float, b: float) -> float:
	if u < a: return sin(u / a * PI * 0.5)
	if u > b: return cos(clampf((u - b) / (1.0 - b), 0.0, 1.0) * PI * 0.5)
	return 1.0

# Papel / página: granos de ruido rosa 10–40 ms (HP 800 Hz) con amplitud aleatoria + crujidos finos;
# la página agrega el soplo del giro y el asentarse de la hoja.
static func _paper(dur: float, rng: Synth.Rng, page: bool) -> PackedFloat32Array:
	var n := _n(dur)
	var envb := Synth.zeros(n)
	var envc := Synth.zeros(n)
	var a := 0.15 if page else 0.2
	var b := 0.55 if page else 0.65
	for k in int(dur * 30.0):
		var t := rng.f() * dur
		var amp := _gesture(t / dur, a, b) * (0.25 + 0.75 * rng.f() * rng.f())
		var cnt := _n(rng.r(0.010, 0.040))
		Synth.add_hann(envb, _n(t) - cnt / 2, cnt, amp)
	for k in int(dur * 55.0):
		var t := rng.f() * dur
		var r := rng.f()
		var amp := _gesture(t / dur, a, b) * r * r * r
		var cnt := _n(rng.r(0.004, 0.014))
		Synth.add_hann(envc, _n(t) - cnt / 2, cnt, amp)
	var x := Synth.pink(n, rng.sub())
	Synth.band(x, 800.0, 6500.0)
	Synth.mul(x, envb)
	var c := Synth.white(n, rng.sub(), 0.5)
	Synth.hp(c, 2200.0)
	Synth.lp(c, 10000.0)
	Synth.mul(c, envc)
	Synth.mix(x, c, 0, 0.6)
	if page:
		var sw := Synth.pink(n, rng.sub())
		Synth.band(sw, 350.0, 2500.0)
		Synth.mul_pts(sw, [[0.0, 0.0], [dur * 0.25, 0.15], [dur * 0.6, 0.5], [dur * 0.8, 0.1], [dur, 0.0]])
		Synth.mix(x, sw, 0, 0.8)
		var fl := Synth.zeros(n)
		Synth.add_burst(fl, _n(dur * 0.78), 0.004, 0.02, 1.0, rng.sub())
		Synth.lp(fl, 900.0)
		Synth.mix(x, fl, 0, 0.35)
	return x

# Plumín: ruido HP 2,5 kHz × pulsos stick-slip 30–60 Hz agrupados en trazos (con levantadas de pluma).
static func _plumin(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var m := Synth.zeros(n)
	var t := 0.04
	while t < dur - 0.12:
		var sl := rng.r(0.14, 0.30)
		var rate := rng.r(30.0, 60.0)
		var pres := rng.r(0.6, 1.0)
		var tt := t
		while tt < t + sl and tt < dur - 0.06:
			var ph := (tt - t) / sl
			var pe := pres * pow(sin(PI * ph), 0.6)
			Synth.add_ad(m, _n(tt), 0.0008, rng.r(0.003, 0.007), pe * rng.r(0.5, 1.0))
			tt += rng.r(0.8, 1.2) / rate
			rate = clampf(rate + rng.r(-5.0, 5.0), 30.0, 60.0)
		Synth.add_hann(m, _n(t), _n(sl), 0.2 * pres)
		t += sl + rng.r(0.05, 0.13)
	var x := Synth.white(n, rng.sub())
	Synth.hp(x, 2500.0)
	Synth.hp(x, 2500.0)
	Synth.peak_eq(x, 3900.0, 2.5, 5.0)
	Synth.lp(x, 8500.0)
	Synth.mul(x, m)
	var body := Synth.pink(n, rng.sub())
	Synth.band(body, 900.0, 3000.0)
	Synth.mul(body, m)
	Synth.mix(x, body, 0, 0.35)
	return x

# Secante: presión suave (ruido LP 300 Hz) que se mece dos veces.
static func _secante(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.brown(n, rng.sub())
	var p := Synth.pink(n, rng.sub())
	Synth.mix(x, p, 0, 0.6)
	Synth.lp(x, 300.0)
	Synth.lp(x, 400.0)
	var env := [[0.0, 0.0], [dur * 0.12, 0.75], [dur * 0.32, 1.0], [dur * 0.52, 0.6], [dur * 0.7, 0.9], [dur * 0.95, 0.0]]
	Synth.mul_pts(x, env)
	var fr := Synth.pink(n, rng.sub())
	Synth.band(fr, 500.0, 1600.0)
	Synth.mul_pts(fr, env)
	Synth.mix(x, fr, 0, 0.1)
	Synth.add_thump(x, _n(0.012), 110.0, 80.0, 0.01, 0.03, 0.12)
	return x

# Sello: seno 70 Hz que cae (~120 ms) + clic 5 ms + cuerpo de madera BP 400 Hz. Seco: más corto y agudo.
static func _sello(dur: float, rng: Synth.Rng, dry: bool) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var t0 := _n(0.004)
	var k := rng.r(0.97, 1.03)
	if dry:
		Synth.add_thump(x, t0, 120.0 * k, 88.0 * k, 0.008, 0.025, 1.0)
	else:
		Synth.add_thump(x, t0, 96.0 * k, 68.0 * k, 0.012, 0.045, 1.0)
	var ck := Synth.zeros(n)
	Synth.add_burst(ck, t0, 0.0002, 0.0008 if dry else 0.0012, 1.0, rng.sub())
	Synth.hp(ck, 3000.0 if dry else 1500.0)
	Synth.mix(x, ck, 0, 0.6 if dry else 0.45)
	var wf := (620.0 if dry else 400.0) * k
	var wt := 0.02 if dry else 0.035
	Synth.add_mode(x, t0, wf, wt, 0.45)
	Synth.add_mode(x, t0, wf * 2.33, wt * 0.55, 0.22)
	Synth.add_mode(x, t0, wf * 4.1, wt * 0.3, 0.1)
	var pd := Synth.zeros(n)
	Synth.add_burst(pd, t0, 0.0005, 0.003 if dry else 0.006, 1.0, rng.sub())
	Synth.lp(pd, 2000.0)
	Synth.mix(x, pd, 0, 0.3)
	return x

# Sobre: deslizamiento de papel (~0,5 s) + golpecito al asentarse.
static func _sobre(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.pink(n, rng.sub())
	Synth.band(x, 900.0, 5000.0)
	Synth.mul_pts(x, [[0.0, 0.0], [0.08, 0.6], [0.32, 1.0], [0.46, 0.7], [0.5, 0.0]])
	Synth.mul_wobble(x, rng.sub(), 25.0, 0.55, 1.0)
	var t := _n(0.52)
	Synth.add_thump(x, t, 220.0, 170.0, 0.006, 0.02, 0.35)
	Synth.add_mode(x, t, 520.0, 0.012, 0.15)
	var tp := Synth.zeros(n)
	Synth.add_burst(tp, t, 0.0005, 0.004, 0.6, rng.sub())
	Synth.lp(tp, 3000.0)
	Synth.mix(x, tp, 0, 1.0)
	return x

# ---------------------------------------------------------------- calle y casa
# Persiana de Crane (abajo): 8 clics de la persiana que sube + rodar de tablillas (ruido LP) + golpe al tope.
static func _persiana(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var nz := Synth.zeros(n)
	var gaps := [0.24, 0.2, 0.17, 0.15, 0.14, 0.14, 0.15]
	var t := 0.06
	for k in 8:
		var i := _n(t)
		var a := rng.r(0.6, 1.0)
		var f := rng.r(0.95, 1.05)
		Synth.add_mode(x, i, 1150.0 * f, 0.02, 0.5 * a)
		Synth.add_mode(x, i, 2600.0 * f, 0.012, 0.3 * a)
		Synth.add_mode(x, i, 4100.0 * f, 0.006, 0.12 * a)
		Synth.add_burst(nz, i, 0.0003, 0.003, a, rng.sub())
		if k < gaps.size(): t += float(gaps[k]) + rng.r(-0.01, 0.01)
	var t_end := t + 0.22
	Synth.hp(nz, 1000.0)
	Synth.mix(x, nz, 0, 0.5)
	var rum := Synth.brown(n, rng.sub())
	Synth.lp(rum, 220.0)
	Synth.mul_pts(rum, [[0.0, 0.0], [0.1, 0.6], [t_end - 0.1, 0.9], [t_end, 0.0]])
	Synth.mix(x, rum, 0, 0.45)
	var rat := Synth.white(n, rng.sub())
	Synth.band(rat, 600.0, 2500.0)
	Synth.mul_wobble(rat, rng.sub(), 18.0, 0.0, 1.0)
	Synth.mul_pts(rat, [[0.0, 0.0], [0.1, 0.3], [t_end - 0.1, 0.4], [t_end, 0.0]])
	Synth.mix(x, rat, 0, 0.12)
	var ie := _n(t_end)
	Synth.add_thump(x, ie, 95.0, 70.0, 0.015, 0.06, 1.0)
	Synth.add_mode(x, ie, 160.0, 0.04, 0.4)
	Synth.add_mode(x, ie, 420.0, 0.03, 0.3)
	Synth.add_mode(x, ie, 880.0, 0.015, 0.15)
	var gb := Synth.zeros(n)
	Synth.add_burst(gb, ie, 0.0005, 0.02, 1.0, rng.sub())
	Synth.lp(gb, 1500.0)
	Synth.mix(x, gb, 0, 0.5)
	Synth.lp(x, 3500.0)
	Synth.reverb(x, 0.6, 0.6, 0.4, 0.15)
	return x

# Golpe de casco. th: capa tonal (modos, sin filtrar); nz: capa de ruido (el llamador la filtra una vez).
static func _hoof(th: PackedFloat32Array, nz: PackedFloat32Array, i: int, amp: float, granite: bool, rng: Synth.Rng) -> void:
	if granite:
		Synth.add_thump(th, i, rng.r(165.0, 185.0), rng.r(130.0, 150.0), 0.006, 0.016, amp * 0.8)
		Synth.add_burst(nz, i, 0.0005, 0.007, amp * 1.4, rng.sub())
		var fr := rng.r(0.96, 1.04)
		Synth.add_mode(th, i, 2800.0 * fr, 0.03, amp * 0.3)
		Synth.add_mode(th, i, 4170.0 * fr, 0.018, amp * 0.14)
		Synth.add_mode(th, i, 5640.0 * fr, 0.01, amp * 0.06)
	else:
		Synth.add_thump(th, i, rng.r(155.0, 175.0), rng.r(125.0, 145.0), 0.008, 0.024, amp)
		Synth.add_mode(th, i, rng.r(520.0, 680.0), 0.011, amp * 0.6)
		Synth.add_mode(th, i, rng.r(1000.0, 1250.0), 0.006, amp * 0.2)
		Synth.add_burst(nz, i, 0.0008, 0.009, amp * 0.9, rng.sub())

static func _hoof_filter(nz: PackedFloat32Array, granite: bool) -> void:
	if granite: Synth.bp(nz, 1500.0, 1.2)
	else: Synth.lp(nz, 1500.0)

# Coche que pasa: golpes desde t0 durante span s; rate ≥ 2,5 = trote en pares; si no, paso en 4 tiempos.
static func _cab(th: PackedFloat32Array, nz: PackedFloat32Array, t0: float, span: float, rate: float, amp: float, granite: bool, rng: Synth.Rng) -> void:
	var t := t0
	var k := 0
	while t < t0 + span:
		var u := (t - t0) / span
		var a := amp * sin(PI * u) * rng.r(0.75, 1.0)
		if rate >= 2.5:
			_hoof(th, nz, _n(t), a, granite, rng)
			_hoof(th, nz, _n(t + rng.r(0.05, 0.075)), a * 0.8, granite, rng)
			t += 1.0 / rate + rng.r(-0.008, 0.008)
		else:
			_hoof(th, nz, _n(t), a * (1.0 if k % 2 == 0 else 0.7), granite, rng)
			t += 0.5 / rate + rng.r(-0.012, 0.012)
		k += 1

# Lechero: dos pasos de casco + tintineo metálico de latas (≈2,4 kHz) + ruedas; abajo, en la calle.
static func _lechero(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var th := Synth.zeros(n)
	var nz := Synth.zeros(n)
	var steps := [0.18, 0.74]
	for s in steps:
		_hoof(th, nz, _n(float(s)), rng.r(0.85, 1.0), false, rng)
	_hoof_filter(nz, false)
	Synth.mix(th, nz, 0, 1.0)
	var cl := Synth.zeros(n)
	var bursts := [[0.22, 4], [0.78, 5], [1.55, 3], [2.05, 2]]
	for bu in bursts:
		var tb: float = bu[0]
		for k in int(bu[1]):
			var i := _n(tb + rng.r(0.0, 0.16))
			var f := 2400.0 * rng.r(0.9, 1.1)
			var a := rng.r(0.25, 0.6)
			Synth.add_mode(cl, i, f, rng.r(0.03, 0.09), a)
			Synth.add_mode(cl, i, f * 1.47, rng.r(0.02, 0.05), a * 0.5)
			Synth.add_mode(cl, i, f * 2.09, rng.r(0.012, 0.03), a * 0.3)
			Synth.add_mode(cl, i, f * 2.56, rng.r(0.008, 0.02), a * 0.15)
	Synth.mix(th, cl, 0, 0.55)
	var wh := Synth.brown(n, rng.sub())
	Synth.lp(wh, 180.0)
	Synth.mul_pts(wh, [[0.0, 0.0], [0.4, 0.5], [1.6, 0.6], [2.6, 0.0]])
	Synth.mix(th, wh, 0, 0.35)
	Synth.lp(th, 5000.0)
	Synth.slap(th, 0.045, 0.3, 2000.0)
	Synth.reverb(th, 0.8, 0.65, 0.4, 0.15)
	return th

# Cascos sobre madera o granito: pares a 3,2 Hz durante 3 s + rodar de ruedas.
static func _hooves(dur: float, rng: Synth.Rng, granite: bool) -> PackedFloat32Array:
	var n := _n(dur)
	var th := Synth.zeros(n)
	var nz := Synth.zeros(n)
	var t := 0.06 + rng.r(0.0, 0.05)
	while t < dur - 0.15:
		var a := rng.r(0.8, 1.0)
		_hoof(th, nz, _n(t), a, granite, rng)
		_hoof(th, nz, _n(t + rng.r(0.05, 0.075)), a * rng.r(0.7, 0.9), granite, rng)
		t += 1.0 / 3.2 + rng.r(-0.008, 0.008)
	_hoof_filter(nz, granite)
	Synth.mix(th, nz, 0, 1.0 if granite else 0.8)
	var wh := Synth.brown(n, rng.sub())
	Synth.lp(wh, 140.0)
	Synth.hp1(wh, 25.0)
	Synth.mix(th, wh, 0, 0.15 if granite else 0.12)
	if granite:
		var rat := Synth.white(n, rng.sub())
		Synth.band(rat, 300.0, 1200.0)
		Synth.mul_wobble(rat, rng.sub(), 14.0, 0.0, 1.0)
		Synth.mix(th, rat, 0, 0.08)
	Synth.mul_pts(th, [[0.0, 0.0], [0.15, 1.0], [dur - 0.4, 1.0], [dur, 0.0]])
	Synth.slap(th, 0.035, 0.25, 2500.0)
	return th

# Tres golpes de nudillo en una puerta de madera.
static func _golpe_puerta(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var nz := Synth.zeros(n)
	var modes := [[105.0, 0.09, 0.6], [172.0, 0.07, 1.0], [248.0, 0.05, 0.8], [335.0, 0.04, 0.6], [470.0, 0.03, 0.45], [640.0, 0.02, 0.3]]
	var times := [0.03, 0.31, 0.59]
	var amps := [0.9, 0.85, 1.0]
	for k in 3:
		var i := _n(float(times[k]) + rng.r(-0.015, 0.015))
		var a: float = amps[k] * rng.r(0.9, 1.0)
		for m in modes:
			Synth.add_mode(x, i, float(m[0]) * rng.r(0.98, 1.02), float(m[1]), float(m[2]) * a * 0.5)
		Synth.add_burst(nz, i, 0.0002, 0.002, a, rng.sub())
	Synth.lp(nz, 3500.0)
	Synth.mix(x, nz, 0, 0.5)
	Synth.reverb(x, 0.7, 0.7, 0.4, 0.18)
	return x

# Ladrillo que cae de un alero: impacto (golpe LP + chasquido) + granos de derrumbe, rebotes y polvo.
static func _ladrillo(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var t0 := _n(0.02)
	Synth.add_thump(x, t0, 130.0, 90.0, 0.01, 0.035, 0.6)
	Synth.add_mode(x, t0, 170.0, 0.025, 0.3)
	Synth.add_mode(x, t0, 310.0, 0.02, 0.3)
	Synth.add_mode(x, t0, 720.0, 0.012, 0.2)
	var cr := Synth.zeros(n)
	Synth.add_burst(cr, t0, 0.0003, 0.009, 1.0, rng.sub())
	Synth.hp(cr, 800.0)
	Synth.mix(x, cr, 0, 1.2)
	var db := Synth.zeros(n)
	for k in 28:
		var u := rng.f()
		var t := 0.03 + 1.15 * u * u
		Synth.add_burst(db, _n(t), 0.0005, rng.r(0.003, 0.012), rng.r(0.2, 0.9) * (1.0 - 0.7 * u), rng.sub())
	var bt := 0.2
	var gap := 0.14
	for k in 5:
		var i := _n(bt)
		var a := 0.5 * pow(0.7, k)
		Synth.add_mode(x, i, rng.r(420.0, 700.0), 0.015, a)
		Synth.add_burst(db, i, 0.0003, 0.004, a * 1.5, rng.sub())
		bt += gap
		gap *= 0.7
	Synth.band(db, 700.0, 5000.0)
	Synth.mix(x, db, 0, 1.0)
	var du := Synth.zeros(n)
	for k in 70:
		var t := 0.08 + rng.f() * 0.9
		Synth.add_grain(du, _n(t), _n(rng.r(0.002, 0.006)), rng.r(0.05, 0.3) * (1.0 - (t - 0.08) / 0.95), rng.sub())
	Synth.hp(du, 3000.0)
	Synth.mix(x, du, 0, 0.4)
	Synth.slap(x, 0.06, 0.3, 2000.0)
	Synth.reverb(x, 0.7, 0.6, 0.4, 0.15)
	Synth.lp(x, 10000.0)
	return x

# ---------------------------------------------------------------- campanas y relojes
# Parciales de campana (×prima, amplitud, tau s): hum, prima, tercera, quinta, nominal y superiores.
const BELL := [[0.5, 0.55, 2.2], [1.0, 0.65, 1.4], [1.183, 0.7, 1.1], [1.506, 0.3, 0.8], [2.0, 1.0, 0.9],
	[2.514, 0.45, 0.5], [2.662, 0.4, 0.45], [3.011, 0.35, 0.35], [4.166, 0.2, 0.22]]

# Campana aditiva en dst desde start. fs = factor de tasa: con fs = 2 se sintetiza a media tasa (SR/2) usando las
# primitivas de tasa completa (frecuencias ×fs, tiempos ÷fs) y luego se sobremuestrea (Synth.upsample2).
static func _bell_into(dst: PackedFloat32Array, start: int, prime: float, tau_k: float, amp: float, rng: Synth.Rng, fs := 1.0) -> void:
	for p in BELL:
		var f: float = prime * float(p[0]) * rng.r(0.998, 1.002)
		var tau: float = float(p[2]) * tau_k
		Synth.add_mode(dst, start, f * fs, tau / fs, float(p[1]) * amp)
		if float(p[0]) == 0.5 or float(p[0]) == 2.0:   # doblete: batido lento
			Synth.add_mode(dst, start, (f + rng.r(0.6, 1.2)) * fs, tau / fs, float(p[1]) * amp * 0.45)
	var cl := Synth.zeros(int(0.08 * SR / fs))
	Synth.add_burst(cl, 0, 0.0003 / fs, 0.004 / fs, 0.5 * amp, rng.sub())
	Synth.bp(cl, prime * 5.2 * fs, 1.5)
	Synth.mix(dst, cl, start, 1.0)

# St Clement Danes: 4 campanas en rondas (1-2-3-4) con pausa de toque de mano. Sintetizadas a media tasa
# (todo el contenido < 7 kHz): cada campana se genera una vez y se mezcla en cada golpe.
static func _bells(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var nh: int = (n + 1) / 2
	var h := Synth.zeros(nh)
	var primes := [587.3, 554.4, 493.9, 440.0]
	var bells := []
	for b in 4:
		var bb := Synth.zeros(nh)
		_bell_into(bb, 0, float(primes[b]), 1.0, 1.0, rng, 2.0)
		bells.append(bb)
	var row_t := 0.05
	var gap := 0.27
	for row in 4:
		for b in 4:
			var t := row_t + gap * b + rng.r(-0.012, 0.012)
			Synth.mix(h, bells[b], int(t * SR * 0.5), rng.r(0.8, 1.0) * (1.1 if b == 3 else 1.0))
		row_t += gap * 4.0 + (gap if row % 2 == 1 else 0.0)
	Synth.lp(h, 14000.0)                       # = 7 kHz a media tasa
	Synth.reverb(h, 1.25 * 0.5, 0.82, 0.35, 0.22)
	var x := Synth.upsample2(h, n)
	Synth.mul_pts(x, [[0.0, 1.0], [dur - 1.0, 1.0], [dur, 0.0]])
	return x

# Cuartos: primer cuarto de Westminster (sol#, fa#, mi, si) con timbre de campana, lejos (media tasa).
static func _cuartos(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var nh: int = (n + 1) / 2
	var h := Synth.zeros(nh)
	var notes := [415.3, 370.0, 329.6, 246.9]
	for k in 4:
		_bell_into(h, int((0.1 + 0.62 * k + rng.r(-0.01, 0.01)) * SR * 0.5), float(notes[k]), 0.8, 1.0, rng, 2.0)
	Synth.lp(h, 7000.0)                        # = 3,5 kHz a media tasa
	Synth.reverb(h, 1.4 * 0.5, 0.85, 0.4, 0.4)
	var x := Synth.upsample2(h, n)
	Synth.mul_pts(x, [[0.0, 1.0], [dur - 0.8, 1.0], [dur, 0.0]])
	return x

static func _tick(dst: PackedFloat32Array, i: int, tac: bool, amp: float, rng: Synth.Rng) -> void:
	var k := 0.88 if tac else 1.0
	Synth.add_burst(dst, i, 0.0001, 0.0006, amp * 0.25, rng.sub())
	Synth.add_mode(dst, i, 3100.0 * k, 0.004, amp * 0.5)
	Synth.add_mode(dst, i, 4700.0 * k, 0.003, amp * 0.3)
	Synth.add_mode(dst, i, 7300.0 * k, 0.0015, amp * 0.12)
	Synth.add_mode(dst, i, 950.0 * k, 0.012, amp * 0.25)
	Synth.add_mode(dst, i, 1800.0 * k, 0.006, amp * 0.15)

# Tic-tac a 1 Hz (bucle de 2 s): eventos plegados + aire de sala apenas audible.
static func _tic(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nl := _n(dur)
	var ev := Synth.zeros(nl + _n(0.4))
	for k in int(round(dur)):
		_tick(ev, _n(0.25 + k), k % 2 == 1, 1.0, rng)
	Synth.reverb_lofi(ev, 0.5, 0.6, 0.5, 0.12)
	var x := Synth.fold(ev, nl)
	var bed := Synth.pink(nl + _n(fd), rng.sub())
	Synth.lp(bed, 1500.0)
	Synth.to_rms(bed, 0.004)
	bed = Synth.make_loop(bed, fd)
	Synth.mix(x, bed)
	return x

# ---------------------------------------------------------------- la noche final
# Arpa de boca (Parker): sierra 98 Hz; formante de la boca (BP resonante 400–1600 Hz) que barre con LFO;
# pellizcos con «boing». Lejos, en la calle.
static func _harp(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var nb := Synth.nblocks(n)
	var f0 := Synth.zeros(nb)
	var vph := rng.r(0.0, TAU)
	for b in nb:
		var t := float(b * Synth.BLOCK) / SR
		f0[b] = 98.0 * (1.0 + 0.004 * sin(TAU * 5.3 * t + vph))
	var src := Synth.saw(n, f0)
	var plucks := [0.04, 0.58, 0.98, 1.36, 1.9]
	var harms := [6, 8, 7, 5, 6]
	var env := Synth.zeros(n)
	for k in plucks.size():
		Synth.add_ad(env, _n(float(plucks[k])), 0.002, 0.33, 1.0)
	Synth.mul(src, env)
	var fm := Synth.zeros(nb)
	var kk := 0
	for b in nb:
		var t := float(b * Synth.BLOCK) / SR
		while kk < plucks.size() - 1 and t >= float(plucks[kk + 1]): kk += 1
		var dt := maxf(0.0, t - float(plucks[kk]))
		var g := 0.7 + 0.3 * (1.0 - exp(-dt / 0.025))
		fm[b] = clampf(float(harms[kk]) * 98.0 * g * (1.0 + 0.1 * sin(TAU * 1.7 * t)), 400.0, 1600.0)
	var f1 := src.duplicate()
	Synth.svf(f1, Synth.BP, fm, 9.0)
	var f2 := src.duplicate()
	Synth.bp(f2, 2300.0, 2.5)
	var lo := src
	Synth.lp(lo, 260.0)
	var x := Synth.zeros(n)
	Synth.mix(x, f1, 0, 3.0)
	Synth.mix(x, f2, 0, 1.2)
	Synth.mix(x, lo, 0, 0.22)
	Synth.lp(x, 3800.0)
	Synth.reverb(x, 0.9, 0.72, 0.45, 0.28)
	return x

# Silbato de policía: senos 2100/2500 Hz con trémolo de 30 Hz (la bolita), dos toques, aliento; en la calle.
static func _whistle(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var blasts := [[0.03, 0.58], [0.76, 1.22]]
	for bl in blasts:
		var i0 := _n(float(bl[0]))
		var cnt := _n(float(bl[1])) - i0
		var na := _n(0.025)
		var nr := _n(0.05)
		var ph1 := 0.0
		var ph2 := 0.0
		var vph := rng.r(0.0, TAU)
		var tph := rng.r(0.0, TAU)
		for j in cnt:
			var t := float(j) / SR
			var scoop := 0.955 + 0.045 * (1.0 - exp(-t / 0.03))
			var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t + vph)
			ph1 += TAU * 2100.0 * scoop * vib / SR
			ph2 += TAU * 2500.0 * scoop * vib / SR
			var trem := 1.0 - 0.5 * (0.5 + 0.5 * sin(TAU * 30.0 * t + tph))
			var e := 1.0
			if j < na: e = 0.5 - 0.5 * cos(PI * float(j) / float(na))
			elif j > cnt - nr: e = 0.5 - 0.5 * cos(PI * float(cnt - j) / float(nr))
			x[i0 + j] += e * trem * (sin(ph1) + 0.85 * sin(ph2) + 0.04 * sin(2.0 * ph1))
	var br := Synth.white(n, rng.sub())
	Synth.bp(br, 2300.0, 1.2)
	Synth.mul_pts(br, [[0.0, 0.0], [0.03, 0.0], [0.055, 1.0], [0.56, 1.0], [0.58, 0.0], [0.76, 0.0], [0.785, 1.0], [1.2, 1.0], [1.22, 0.0]], false)
	Synth.mix(x, br, 0, 0.12)
	Synth.lp1(x, 7000.0)
	Synth.reverb(x, 1.1, 0.78, 0.4, 0.3)
	return x

# Silbido del fusil de aire: soplo breve + ruido con HP que barre 6 kHz → 1 kHz en 150 ms.
static func _silbido(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.white(n, rng.sub())
	var tone := x.duplicate()
	Synth.svf(x, Synth.HP, Synth.ctl_pts(n, [[0.0, 6000.0], [0.04, 6000.0], [0.19, 1000.0], [dur, 1000.0]], true), 0.8)
	Synth.svf(x, Synth.LP, Synth.ctl_pts(n, [[0.0, 12000.0], [0.04, 12000.0], [0.19, 2500.0], [dur, 2500.0]], true), 0.8)
	Synth.svf(tone, Synth.BP, Synth.ctl_pts(n, [[0.0, 7000.0], [0.04, 7000.0], [0.19, 1200.0], [dur, 1100.0]], true), 4.0)
	Synth.mix(x, tone, 0, 0.6)
	Synth.lp(x, 9000.0)
	Synth.mul_pts(x, [[0.0, 0.0], [0.03, 0.15], [0.13, 1.0], [0.19, 0.6], [0.27, 0.06], [dur, 0.0]])
	var pf := Synth.zeros(n)
	Synth.add_burst(pf, _n(0.005), 0.002, 0.012, 1.0, rng.sub())
	Synth.lp(pf, 800.0)
	Synth.mix(x, pf, 0, 0.25)
	return x

# Vidrio roto: estallido + ~60 micro-campanas (parciales 3–9 kHz, 50–200 ms) dispersas en 1,2 s.
static func _glass(dur: float, rng: Synth.Rng) -> PackedFloat32Array:
	var n := _n(dur)
	var x := Synth.zeros(n)
	var nz := Synth.zeros(n)
	var t0 := _n(0.01)
	Synth.add_burst(nz, t0, 0.0003, 0.02, 1.0, rng.sub())
	Synth.add_thump(x, t0, 220.0, 170.0, 0.01, 0.03, 0.25)
	for k in 60:
		var u := pow(rng.f(), 1.8)
		var i := t0 + _n(0.004 + 1.2 * u)
		var a := rng.r(0.15, 1.0) * (1.0 - 0.6 * u)
		var f1 := rng.r(3000.0, 7000.0)
		var life := rng.r(0.05, 0.2) / 3.5
		Synth.add_mode(x, i, f1, life, a * 0.35)
		var f2 := f1 * rng.r(1.4, 1.75)
		if f2 < 9000.0: Synth.add_mode(x, i, f2, life * 0.7, a * 0.18)
		var f3 := f1 * rng.r(2.1, 2.6)
		if f3 < 9000.0: Synth.add_mode(x, i, f3, life * 0.5, a * 0.08)
		Synth.add_burst(nz, i, 0.0002, 0.0008, a * 0.3, rng.sub())
	Synth.hp(nz, 1500.0)
	Synth.mix(x, nz, 0, 0.6)
	Synth.lp(x, 11000.0)
	Synth.reverb(x, 0.9, 0.75, 0.4, 0.25)
	return x

# ---------------------------------------------------------------- ambientes (bucles)
static func _bed_len(dur: float, fd: float) -> int:
	return _n(dur) + _n(fd)

# Murmullo lejano: dos bandas de ruido rosa con AM silábica.
static func _murmur(nt: int, rng: Synth.Rng, lo: float, hi: float, lp_hz: float) -> PackedFloat32Array:
	var a := Synth.pink(nt, rng.sub())
	Synth.band(a, lo, hi * 0.6)
	Synth.mul_wobble(a, rng.sub(), 4.5, 0.2, 1.0)
	var b := Synth.pink(nt, rng.sub())
	Synth.band(b, lo * 2.0, hi)
	Synth.mul_wobble(b, rng.sub(), 6.3, 0.05, 1.0)
	Synth.mix(a, b, 0, 0.7)
	Synth.lp1(a, lp_hz)
	return a

# Calle: rodar de llantas (marrón LP) + murmullo AM + cascos lejanos horneados.
static func _amb_calle(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nl := _n(dur)
	var bed := Synth.brown(nt, rng.sub())
	Synth.lp(bed, 350.0)
	Synth.hp1(bed, 30.0)
	Synth.to_rms(bed, 0.03)
	var grit := Synth.white(nt, rng.sub())
	Synth.band(grit, 1200.0, 3500.0)
	Synth.mul_wobble(grit, rng.sub(), 8.0, 0.0, 1.0)
	Synth.to_rms(grit, 0.004)
	Synth.mix(bed, grit)
	var mu := _murmur(nt, rng, 250.0, 2000.0, 1500.0)
	Synth.to_rms(mu, 0.009)
	Synth.mix(bed, mu)
	var x := Synth.make_loop(bed, fd)
	# la capa de eventos debe contener ENTERO el segundo coche (empieza ≤ 5,0 s y dura 5,5 s → ≤ 10,9 s con colas):
	# si se trunca, el coche se corta en seco en mitad del bucle.
	var th := Synth.zeros(nl + _n(3.0))
	var nz := Synth.zeros(nl + _n(3.0))
	_cab(th, nz, rng.r(0.3, 1.0), 5.0, 3.0, 1.0, false, rng)
	_cab(th, nz, rng.r(4.2, 5.0), 5.5, 1.8, 0.7, true, rng)
	Synth.lp(nz, 1200.0)
	Synth.mix(th, nz, 0, 0.8)
	Synth.lp1(th, 1000.0)
	Synth.slap(th, 0.05, 0.3, 1500.0)
	var ev := Synth.fold(th, nl)
	Synth.mix(x, ev, 0, 0.07)
	return x

# Gas: siseo HP 4 kHz muy bajo con aleteo lento (+ un rumor de llama casi inaudible).
static func _amb_gas(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var x := Synth.white(nt, rng.sub())
	Synth.hp(x, 4000.0)
	Synth.hp(x, 3500.0)
	Synth.lp(x, 9000.0)
	Synth.mul_wobble(x, rng.sub(), 1.2, 0.7, 1.0)
	Synth.mul_wobble(x, rng.sub(), 7.0, 0.9, 1.0)
	Synth.to_rms(x, 0.006)
	var fl := Synth.brown(nt, rng.sub())
	Synth.lp(fl, 180.0)
	Synth.hp1(fl, 30.0)
	Synth.mul_wobble(fl, rng.sub(), 2.0, 0.6, 1.0)
	Synth.to_rms(fl, 0.0015)
	Synth.mix(x, fl)
	return Synth.make_loop(x, fd)

# Sala de Lectura: tono de sala 200–800 Hz muy bajo + páginas ocasionales bajo la cúpula.
static func _amb_sala_lectura(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nl := _n(dur)
	var bed := Synth.pink(nt, rng.sub())
	Synth.band(bed, 200.0, 800.0)
	Synth.mul_wobble(bed, rng.sub(), 0.7, 0.8, 1.0)
	Synth.to_rms(bed, 0.008)
	var air := Synth.pink(nt, rng.sub())
	Synth.hp(air, 2000.0)
	Synth.to_rms(air, 0.0012)
	Synth.mix(bed, air)
	var x := Synth.make_loop(bed, fd)
	var ev := Synth.zeros(nl + _n(3.0))
	var p1 := _paper(0.9, rng, true)
	Synth.normalize(p1, 0.06)
	Synth.mix(ev, p1, _n(rng.r(1.0, 2.2)))
	var p2 := _paper(0.9, rng, true)
	Synth.normalize(p2, 0.035)
	Synth.mix(ev, p2, _n(rng.r(5.0, 6.2)))
	var p3 := _paper(0.6, rng, false)
	Synth.normalize(p3, 0.02)
	Synth.mix(ev, p3, _n(rng.r(3.4, 4.2)))
	Synth.reverb_lofi(ev, 1.6, 0.88, 0.45, 1.2)
	Synth.scale(ev, 0.5)
	Synth.lp(ev, 6000.0)
	Synth.mix(x, Synth.fold(ev, nl))
	return x

# Diógenes: tono de sala a −48 dBFS + algún papel.
static func _amb_diogenes(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nl := _n(dur)
	var bed := Synth.pink(nt, rng.sub())
	Synth.band(bed, 80.0, 600.0)
	Synth.to_rms(bed, 0.004)
	var x := Synth.make_loop(bed, fd)
	var ev := Synth.zeros(nl + _n(1.5))
	var p1 := _paper(0.6, rng, false)
	Synth.normalize(p1, 0.05)
	Synth.mix(ev, p1, _n(rng.r(2.0, 2.8)))
	var p2 := _paper(0.9, rng, true)
	Synth.normalize(p2, 0.02)
	Synth.mix(ev, p2, _n(rng.r(4.6, 5.2)))
	Synth.reverb_lofi(ev, 0.8, 0.7, 0.5, 0.2)
	Synth.mix(x, Synth.fold(ev, nl))
	return x

# Tienda de Crane: reloj de pared + calle amortiguada tras el escaparate.
static func _amb_tienda(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nl := _n(dur)
	var st := Synth.brown(nt, rng.sub())
	Synth.lp(st, 220.0)
	Synth.hp1(st, 30.0)
	Synth.to_rms(st, 0.012)
	var mu := _murmur(nt, rng, 200.0, 1200.0, 500.0)
	Synth.to_rms(mu, 0.004)
	Synth.mix(st, mu)
	var x := Synth.make_loop(st, fd)
	var ev := Synth.zeros(nl + _n(0.5))
	for k in int(round(dur)):
		_tick(ev, _n(0.3 + k), k % 2 == 1, 0.06, rng)
	Synth.reverb_lofi(ev, 0.6, 0.65, 0.5, 0.15)
	Synth.mix(x, Synth.fold(ev, nl))
	return x

# Viento (noche del 5 de abril): ruido por BP 200–900 Hz con LFO 0,125/0,25 Hz + ráfagas + aullido tenue.
static func _amb_viento(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nb := Synth.nblocks(nt)
	var fc := Synth.zeros(nb)
	var fh := Synth.zeros(nb)
	var p1 := rng.r(0.0, TAU)
	var p2 := rng.r(0.0, TAU)
	for b in nb:
		var t := float(b * Synth.BLOCK) / SR
		var u := 0.5 + 0.5 * (0.6 * sin(TAU * 0.125 * t + p1) + 0.4 * sin(TAU * 0.25 * t + p2))
		fc[b] = 200.0 * pow(4.5, u)
		fh[b] = fc[b] * 1.9
	var x := Synth.pink(nt, rng.sub())
	Synth.svf(x, Synth.BP, fc, 1.6)
	var gust := Synth.zeros(nt)
	gust.fill(1.0)
	Synth.mul_wobble(gust, rng.sub(), 0.6, 0.3, 1.0)
	Synth.mul(x, gust)
	Synth.to_rms(x, 0.05)
	var how := Synth.white(nt, rng.sub())
	Synth.svf(how, Synth.BP, fh, 14.0)
	Synth.mul(how, gust)
	Synth.mul(how, gust)
	Synth.to_rms(how, 0.006)
	Synth.mix(x, how)
	var ru := Synth.brown(nt, rng.sub())
	Synth.lp(ru, 120.0)
	Synth.hp1(ru, 25.0)
	Synth.mul(ru, gust)
	Synth.to_rms(ru, 0.02)
	Synth.mix(x, ru)
	return Synth.make_loop(x, fd)

# Gorjeo: senos con chirp en frases cortas.
static func _birds(ev: PackedFloat32Array, t0: float, rng: Synth.Rng, blackbird: bool) -> void:
	var t := t0
	var notes := rng.i(2, 6)
	var base := rng.r(1800.0, 2600.0) if blackbird else rng.r(2800.0, 4500.0)
	for k in notes:
		var cnt := _n(rng.r(0.15, 0.25) if blackbird else rng.r(0.04, 0.11))
		var f0 := base * rng.r(0.85, 1.2)
		var f1 := f0 * (rng.r(0.9, 1.15) if blackbird else rng.r(0.7, 1.35))
		var nb := Synth.nblocks(cnt)
		var fr := Synth.ctl_pts(cnt, [[0.0, f0], [float(cnt) / SR, f1]], true)
		if blackbird:
			for b in nb: fr[b] *= 1.0 + 0.02 * sin(TAU * 18.0 * float(b * Synth.BLOCK) / SR)
		Synth.add_chirp(ev, _n(t), cnt, fr, rng.r(0.4, 1.0), 0.15)
		t += float(cnt) / SR + rng.r(0.04, 0.09)

# Parque (Park Lane): multitud lejana + coches + gorjeos.
static func _amb_parque(dur: float, fd: float, rng: Synth.Rng) -> PackedFloat32Array:
	var nt := _bed_len(dur, fd)
	var nl := _n(dur)
	var cr := _murmur(nt, rng, 250.0, 2500.0, 1800.0)
	Synth.to_rms(cr, 0.016)
	var car := Synth.brown(nt, rng.sub())
	Synth.lp(car, 200.0)
	Synth.hp1(car, 30.0)
	Synth.to_rms(car, 0.01)
	Synth.mix(cr, car)
	var x := Synth.make_loop(cr, fd)
	var ev := Synth.zeros(nl + _n(1.5))
	var starts := [0.4, 1.7, 2.9, 4.3, 5.6, 6.8]
	for k in starts.size():
		_birds(ev, float(starts[k]) + rng.r(0.0, 0.5), rng, k == 2)
	Synth.reverb_lofi(ev, 1.0, 0.6, 0.5, 0.2)
	Synth.lp(ev, 9000.0)
	Synth.mix(x, Synth.fold(ev, nl), 0, 0.03)
	return x
