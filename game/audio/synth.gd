# audio/synth.gd — W1-AUDIO (ARCHITECTURE §8). Biblioteca DSP estática, sin estado global: apta para hilos.
# Convención: los arreglos empaquetados se pasan por referencia; las funciones que procesan MODIFICAN su
# entrada y la devuelven (x = Synth.lp(x, 800.0)). Para conservar el original: x.duplicate().
# Azar: LCG propio (Rng / white) sembrado por id; nada de randf/RandomNumberGenerator.
extends RefCounted

const SR := 44100
const BLOCK := 32            # muestras por bloque de control (filtros modulados)
const LP := 0
const HP := 1
const BP := 2                # pico de ganancia 1 en la central
const PEAK := 3
const LSHELF := 4
const HSHELF := 5
const LOOP_GUARD := 8        # muestras de la cabeza copiadas tras loop_end (interpolación del remuestreo)

# ---------------------------------------------------------------- azar determinista
class Rng:
	var s := 1
	func _init(p_seed: int) -> void:
		s = p_seed & 0x7fffffff
		for k in 3: next()
	func next() -> int:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		return s
	func f() -> float:                       # [0, 1)
		return float(next()) / 2147483648.0
	func r(a: float, b: float) -> float:
		return a + (b - a) * f()
	func bi() -> float:                      # [-1, 1)
		return f() * 2.0 - 1.0
	func i(a: int, b: int) -> int:           # [a, b]
		return mini(b, a + int(f() * float(b - a + 1)))
	func sub() -> int:                       # semilla derivada
		return (next() ^ 0x2545F491) & 0x7fffffff

static func seed_of(key: String) -> int:
	return key.md5_text().substr(0, 7).hex_to_int()

static func n_of(sec: float) -> int:
	return int(round(sec * SR))

# ---------------------------------------------------------------- buffers
static func zeros(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(maxi(n, 0))
	x.fill(0.0)
	return x

static func white(n: int, p_seed: int, amp := 1.0) -> PackedFloat32Array:
	var x := zeros(n)
	var s: int = p_seed & 0x7fffffff
	var k: float = 2.0 * amp / 2147483648.0
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		x[i] = float(s) * k - amp
	return x

# Rosa (Kellet, versión económica); salida ~RMS 0,25 con amp 1.
static func pink(n: int, p_seed: int, amp := 1.0) -> PackedFloat32Array:
	var x := zeros(n)
	var s: int = p_seed & 0x7fffffff
	var k: float = 2.0 / 2147483648.0
	var g: float = 0.11 * amp
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var w: float = float(s) * k - 1.0
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		x[i] = (b0 + b1 + b2 + w * 0.1848) * g
	return x

# Marrón (integrador con fuga); salida ~RMS 0,3 con amp 1.
static func brown(n: int, p_seed: int, amp := 1.0) -> PackedFloat32Array:
	var x := zeros(n)
	var s: int = p_seed & 0x7fffffff
	var k: float = 2.0 / 2147483648.0
	var b := 0.0
	var g: float = 3.5 * amp
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		b = (b + 0.02 * (float(s) * k - 1.0)) / 1.02
		x[i] = b * g
	return x

# ---------------------------------------------------------------- filtros
static func _coefs(kind: int, f: float, q: float, db: float) -> PackedFloat64Array:
	var w0: float = TAU * clampf(f, 5.0, 0.45 * SR) / SR
	var cw := cos(w0); var sw := sin(w0)
	var alpha: float = sw / (2.0 * maxf(q, 0.05))
	var A: float = pow(10.0, db / 40.0)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a0 := 1.0; var a1 := 0.0; var a2 := 0.0
	match kind:
		LP:
			b0 = (1.0 - cw) * 0.5; b1 = 1.0 - cw; b2 = b0; a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		HP:
			b0 = (1.0 + cw) * 0.5; b1 = -(1.0 + cw); b2 = b0; a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		BP:
			b0 = alpha; b1 = 0.0; b2 = -alpha; a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		PEAK:
			b0 = 1.0 + alpha * A; b1 = -2.0 * cw; b2 = 1.0 - alpha * A
			a0 = 1.0 + alpha / A; a1 = -2.0 * cw; a2 = 1.0 - alpha / A
		LSHELF:
			var sa := 2.0 * sqrt(A) * alpha
			b0 = A * ((A + 1.0) - (A - 1.0) * cw + sa); b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cw)
			b2 = A * ((A + 1.0) - (A - 1.0) * cw - sa); a0 = (A + 1.0) + (A - 1.0) * cw + sa
			a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cw); a2 = (A + 1.0) + (A - 1.0) * cw - sa
		HSHELF:
			var sb := 2.0 * sqrt(A) * alpha
			b0 = A * ((A + 1.0) + (A - 1.0) * cw + sb); b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cw)
			b2 = A * ((A + 1.0) + (A - 1.0) * cw - sb); a0 = (A + 1.0) - (A - 1.0) * cw + sb
			a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cw); a2 = (A + 1.0) - (A - 1.0) * cw - sb
	return PackedFloat64Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])

# Biquad RBJ (forma directa II transpuesta), en el lugar.
static func biquad(x: PackedFloat32Array, kind: int, f: float, q := 0.7071, db := 0.0) -> PackedFloat32Array:
	var c := _coefs(kind, f, q, db)
	var b0: float = c[0]; var b1: float = c[1]; var b2: float = c[2]; var a1: float = c[3]; var a2: float = c[4]
	var z1 := 0.0; var z2 := 0.0
	for i in x.size():
		var xi: float = x[i]
		var y: float = b0 * xi + z1
		z1 = b1 * xi - a1 * y + z2
		z2 = b2 * xi - a2 * y
		x[i] = y
	return x

static func lp(x: PackedFloat32Array, f: float, q := 0.7071) -> PackedFloat32Array: return biquad(x, LP, f, q)
static func hp(x: PackedFloat32Array, f: float, q := 0.7071) -> PackedFloat32Array: return biquad(x, HP, f, q)
static func bp(x: PackedFloat32Array, f: float, q := 1.0) -> PackedFloat32Array: return biquad(x, BP, f, q)
static func peak_eq(x: PackedFloat32Array, f: float, q: float, db: float) -> PackedFloat32Array: return biquad(x, PEAK, f, q, db)

# Banda f0..f1 (HP + LP de 2.º orden).
static func band(x: PackedFloat32Array, f0: float, f1: float) -> PackedFloat32Array:
	return biquad(biquad(x, HP, f0), LP, f1)

# Polo simple (6 dB/oct): pasa-bajos suave para «distancia».
static func lp1(x: PackedFloat32Array, f: float) -> PackedFloat32Array:
	var a: float = exp(-TAU * f / SR)
	var b: float = 1.0 - a
	var y := 0.0
	for i in x.size():
		y = b * x[i] + a * y
		x[i] = y
	return x

static func hp1(x: PackedFloat32Array, f: float) -> PackedFloat32Array:
	var a: float = exp(-TAU * f / SR)
	var b: float = 1.0 - a
	var y := 0.0
	for i in x.size():
		var xi: float = x[i]
		y = b * xi + a * y
		x[i] = xi - y
	return x

static func dc_block(x: PackedFloat32Array) -> PackedFloat32Array:
	return hp1(x, 18.0)

# Filtro de estado variable (TPT) con frecuencia modulada por bloque. mode LP/BP/HP.
# freqs: Hz por bloque de BLOCK muestras (se repite el último). BP normalizado a pico 1.
static func svf(x: PackedFloat32Array, mode: int, freqs: PackedFloat32Array, q: float) -> PackedFloat32Array:
	var n := x.size()
	var k: float = 1.0 / maxf(q, 0.05)
	var ic1 := 0.0; var ic2 := 0.0
	var nb: int = (n + BLOCK - 1) / BLOCK
	var nf := freqs.size()
	for b in nb:
		var f: float = freqs[mini(b, nf - 1)]
		var g: float = tan(PI * clampf(f, 10.0, 0.45 * SR) / SR)
		var a1: float = 1.0 / (1.0 + g * (g + k))
		var a2: float = g * a1
		var a3: float = g * a2
		var i0: int = b * BLOCK
		var i1: int = mini(i0 + BLOCK, n)
		if mode == LP:
			for i in range(i0, i1):
				var v3: float = x[i] - ic2
				var v1: float = a1 * ic1 + a2 * v3
				var v2: float = ic2 + a2 * ic1 + a3 * v3
				ic1 = 2.0 * v1 - ic1; ic2 = 2.0 * v2 - ic2
				x[i] = v2
		elif mode == BP:
			for i in range(i0, i1):
				var v3: float = x[i] - ic2
				var v1: float = a1 * ic1 + a2 * v3
				var v2: float = ic2 + a2 * ic1 + a3 * v3
				ic1 = 2.0 * v1 - ic1; ic2 = 2.0 * v2 - ic2
				x[i] = v1 * k
		else:
			for i in range(i0, i1):
				var v0: float = x[i]
				var v3: float = v0 - ic2
				var v1: float = a1 * ic1 + a2 * v3
				var v2: float = ic2 + a2 * ic1 + a3 * v3
				ic1 = 2.0 * v1 - ic1; ic2 = 2.0 * v2 - ic2
				x[i] = v0 - k * v1 - v2
	return x

# ---------------------------------------------------------------- curvas de control (por bloque)
static func nblocks(n: int) -> int:
	return (n + BLOCK - 1) / BLOCK

# pts = [[t_s, valor], ...] ordenados; geo=true interpola en escala logarítmica (frecuencias).
static func ctl_pts(n: int, pts: Array, geo := false) -> PackedFloat32Array:
	var nb := nblocks(n)
	var c := zeros(nb)
	var j := 0
	for b in nb:
		var t: float = float(b * BLOCK) / SR
		while j < pts.size() - 2 and t >= float(pts[j + 1][0]): j += 1
		var p0: Array = pts[j]
		var p1: Array = pts[mini(j + 1, pts.size() - 1)]
		var t0: float = p0[0]; var t1: float = p1[0]
		var u := 0.0
		if t1 > t0: u = clampf((t - t0) / (t1 - t0), 0.0, 1.0)
		elif t >= t1: u = 1.0
		if geo: c[b] = exp(lerpf(log(maxf(float(p0[1]), 1e-6)), log(maxf(float(p1[1]), 1e-6)), u))
		else: c[b] = lerpf(float(p0[1]), float(p1[1]), u)
	return c

# ---------------------------------------------------------------- envolventes
# Multiplica por la envolvente lineal a tramos pts=[[t_s, v], ...] (suavizada con coseno si smooth).
static func mul_pts(x: PackedFloat32Array, pts: Array, smooth := true) -> PackedFloat32Array:
	var n := x.size()
	if pts.is_empty(): return x
	var first: float = pts[0][1]
	var i0: int = clampi(n_of(float(pts[0][0])), 0, n)
	for i in i0: x[i] *= first
	for s in range(pts.size() - 1):
		var a: int = clampi(n_of(float(pts[s][0])), 0, n)
		var b: int = clampi(n_of(float(pts[s + 1][0])), 0, n)
		var va: float = pts[s][1]; var vb: float = pts[s + 1][1]
		var span: float = maxf(1.0, float(b - a))
		if smooth:
			for i in range(a, b):
				var u: float = float(i - a) / span
				x[i] *= va + (vb - va) * (0.5 - 0.5 * cos(PI * u))
		else:
			for i in range(a, b):
				x[i] *= va + (vb - va) * float(i - a) / span
	var last: float = pts[pts.size() - 1][1]
	var il: int = clampi(n_of(float(pts[pts.size() - 1][0])), 0, n)
	for i in range(il, n): x[i] *= last
	return x

# Ataque lineal de a_s y decaimiento exponencial (tau) desde start; antes de start → 0.
static func mul_ad(x: PackedFloat32Array, start: int, a_s: float, tau: float) -> PackedFloat32Array:
	var n := x.size()
	for i in mini(start, n): x[i] = 0.0
	var na: int = maxi(1, n_of(a_s))
	var r: float = exp(-1.0 / (maxf(tau, 1e-4) * SR))
	var g := 1.0
	for i in range(maxi(start, 0), n):
		var k: int = i - start
		if k < na: x[i] *= float(k) / float(na)
		else:
			x[i] *= g
			g *= r
	return x

# ADSR lineal de n muestras: ataque a_s, caída d_s hasta s_level, sostén, relajación r_s al final.
static func env_adsr(n: int, a_s: float, d_s: float, s_level: float, r_s: float) -> PackedFloat32Array:
	var e := zeros(n)
	var na: int = maxi(1, n_of(a_s))
	var nd: int = maxi(1, n_of(d_s))
	var nr: int = mini(n, maxi(1, n_of(r_s)))
	var rs: int = n - nr
	for i in n:
		var v: float
		if i < na: v = float(i) / float(na)
		elif i < na + nd: v = 1.0 - (1.0 - s_level) * float(i - na) / float(nd)
		else: v = s_level
		if i >= rs: v *= float(n - 1 - i) / float(maxi(1, nr - 1))
		e[i] = v
	return e

# Fundidos de coseno elevado en los extremos (evita clics de inicio/fin).
static func fade(x: PackedFloat32Array, in_s: float, out_s: float) -> PackedFloat32Array:
	var n := x.size()
	var a: int = mini(n_of(in_s), n)
	var b: int = mini(n_of(out_s), n)
	for i in a: x[i] *= 0.5 - 0.5 * cos(PI * float(i) / float(a))
	for i in b: x[n - 1 - i] *= 0.5 - 0.5 * cos(PI * float(i) / float(b))
	return x

# Envolvente aleatoria suave (modulación AM): puntos cada 1/rate s, interpolación coseno; valores en [lo, hi].
static func mul_wobble(x: PackedFloat32Array, p_seed: int, rate: float, lo: float, hi: float) -> PackedFloat32Array:
	var n := x.size()
	var rng := Rng.new(p_seed)
	var step: int = maxi(1, n_of(1.0 / rate))
	var v0: float = rng.r(lo, hi)
	var v1: float = rng.r(lo, hi)
	# coseno evaluado por bloque de BLOCK muestras e interpolado linealmente dentro (barato)
	var k := 0
	var i := 0
	while i < n:
		if k >= step:
			k -= step; v0 = v1; v1 = rng.r(lo, hi)
		var ka: int = mini(BLOCK, step - k)
		var ua: float = float(k) / float(step)
		var ub: float = float(k + ka) / float(step)
		var ga: float = v0 + (v1 - v0) * (0.5 - 0.5 * cos(PI * ua))
		var gb: float = v0 + (v1 - v0) * (0.5 - 0.5 * cos(PI * ub))
		var dg: float = (gb - ga) / float(ka)
		var e: int = mini(n, i + ka)
		for j in range(i, e):
			x[j] *= ga
			ga += dg
		i = e
		k += ka
	return x

static func mul(x: PackedFloat32Array, env: PackedFloat32Array) -> PackedFloat32Array:
	for i in mini(x.size(), env.size()): x[i] *= env[i]
	return x

# ---------------------------------------------------------------- osciladores y modos
# Modo amortiguado amp·e^(-t/tau)·sin(2πft+φ) sumado en dst desde start (recurrencia de 2 polos).
static func add_mode(dst: PackedFloat32Array, start: int, f: float, tau: float, amp: float, phase := 0.0) -> void:
	var n := dst.size()
	if start >= n or start < 0 or f <= 0.0 or f >= 0.47 * SR or amp == 0.0: return
	var w: float = TAU * f / SR
	var r: float = exp(-1.0 / (maxf(tau, 1e-4) * SR))
	var c: float = 2.0 * r * cos(w)
	var r2: float = r * r
	var life: int = int(tau * SR * log(maxf(absf(amp), 1e-9) / 2e-5)) + 2
	var cnt: int = mini(n - start, life)
	if cnt <= 0: return
	var ym2: float = amp * sin(phase)
	var ym1: float = amp * r * sin(w + phase)
	dst[start] += ym2
	if cnt > 1: dst[start + 1] += ym1
	for i in range(start + 2, start + cnt):
		var y: float = c * ym1 - r2 * ym2
		dst[i] += y
		ym2 = ym1; ym1 = y

# Seno de amplitud constante (recurrencia) en [start, start+cnt).
static func add_sine(dst: PackedFloat32Array, start: int, cnt: int, f: float, amp: float, phase := 0.0) -> void:
	var n := dst.size()
	var e: int = mini(n, start + cnt)
	if start >= e: return
	var w: float = TAU * f / SR
	var c: float = 2.0 * cos(w)
	var ym2: float = amp * sin(phase - w)
	var ym1: float = amp * sin(phase)
	dst[start] += ym1
	for i in range(start + 1, e):
		var y: float = c * ym1 - ym2
		dst[i] += y
		ym2 = ym1; ym1 = y

# Seno con frecuencia variable (curva por bloque, Hz) y envolvente Hann sobre cnt; para gorjeos y silbatos.
static func add_chirp(dst: PackedFloat32Array, start: int, cnt: int, freqs: PackedFloat32Array, amp: float, harm2 := 0.0) -> void:
	var n := dst.size()
	var ph := 0.0
	var nf := freqs.size()
	for k in cnt:
		var i: int = start + k
		if i >= n: break
		var f: float = freqs[mini(k / BLOCK, nf - 1)]
		ph += TAU * f / SR
		if i < 0: continue
		var e: float = 0.5 - 0.5 * cos(TAU * float(k) / float(cnt))
		dst[i] += amp * e * (sin(ph) + harm2 * sin(2.0 * ph))

# FM de 2 operadores: sin(2π fc t + index·sin(2π fm t)), amplitud amp, n muestras.
static func fm(n: int, fc: float, fmod: float, index: float, amp := 1.0) -> PackedFloat32Array:
	var x := zeros(n)
	var wc: float = TAU * fc / SR
	var wm: float = TAU * fmod / SR
	for i in n:
		x[i] = amp * sin(wc * float(i) + index * sin(wm * float(i)))
	return x

# Sierra limitada en banda (PolyBLEP). freqs por bloque (Hz).
static func saw(n: int, freqs: PackedFloat32Array) -> PackedFloat32Array:
	var x := zeros(n)
	var t := 0.0
	var nf := freqs.size()
	for b in nblocks(n):
		var dt: float = freqs[mini(b, nf - 1)] / SR
		var i0: int = b * BLOCK
		for i in range(i0, mini(i0 + BLOCK, n)):
			var v: float = 2.0 * t - 1.0
			if t < dt:
				var u: float = t / dt
				v -= u + u - u * u - 1.0
			elif t > 1.0 - dt:
				var u2: float = (t - 1.0) / dt
				v -= u2 * u2 + u2 + u2 + 1.0
			x[i] = v
			t += dt
			if t >= 1.0: t -= 1.0
	return x

# Ráfaga de ruido blanco con ataque a_s y decaimiento tau, sumada en dst.
static func add_burst(dst: PackedFloat32Array, start: int, a_s: float, tau: float, amp: float, p_seed: int) -> void:
	var n := dst.size()
	if start >= n: return
	var s: int = p_seed & 0x7fffffff
	var k: float = 2.0 / 2147483648.0
	var na: int = maxi(1, n_of(a_s))
	var r: float = exp(-1.0 / (maxf(tau, 1e-4) * SR))
	var life: int = na + int(tau * SR * log(maxf(absf(amp), 1e-9) / 2e-5)) + 1
	var g: float = amp
	for j in life:
		var i: int = start + j
		if i >= n: break
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var w: float = float(s) * k - 1.0
		if j < na: dst[i] += w * amp * float(j) / float(na)
		else:
			dst[i] += w * g
			g *= r

# Grano: ruido × ventana Hann de cnt muestras.
static func add_grain(dst: PackedFloat32Array, start: int, cnt: int, amp: float, p_seed: int) -> void:
	var n := dst.size()
	var s: int = p_seed & 0x7fffffff
	var k: float = 2.0 / 2147483648.0
	var inv: float = TAU / float(maxi(cnt, 1))
	for j in cnt:
		var i: int = start + j
		if i >= n: break
		s = (s * 1103515245 + 12345) & 0x7fffffff
		if i < 0: continue
		dst[i] += (float(s) * k - 1.0) * amp * (0.5 - 0.5 * cos(inv * float(j)))

# Suma a una envolvente un ataque lineal (a_s) + decaimiento exponencial (tau), sin ruido.
static func add_ad(env: PackedFloat32Array, start: int, a_s: float, tau: float, amp: float) -> void:
	var n := env.size()
	var na: int = maxi(1, n_of(a_s))
	var r: float = exp(-1.0 / (maxf(tau, 1e-4) * SR))
	var life: int = na + int(tau * SR * log(maxf(absf(amp), 1e-9) / 2e-5)) + 1
	var g: float = amp
	for j in life:
		var i: int = start + j
		if i >= n: break
		if i < 0: continue
		if j < na: env[i] += amp * float(j) / float(na)
		else:
			env[i] += g
			g *= r

# Golpe sordo: seno con caída de tono f_hi→f_lo (constante glide) y decaimiento tau.
static func add_thump(dst: PackedFloat32Array, start: int, f_hi: float, f_lo: float, glide: float, tau: float, amp: float) -> void:
	var n := dst.size()
	var life: int = int(tau * SR * log(maxf(absf(amp), 1e-9) / 2e-5)) + 1
	var ph := 0.0
	var rg: float = exp(-1.0 / (maxf(glide, 1e-4) * SR))
	var ra: float = exp(-1.0 / (maxf(tau, 1e-4) * SR))
	var gd: float = 1.0
	var ga: float = amp
	var df: float = f_hi - f_lo
	var k: float = TAU / SR
	for j in life:
		var i: int = start + j
		if i >= n: break
		ph += k * (f_lo + df * gd)
		gd *= rg
		if i >= 0: dst[i] += ga * sin(ph)
		ga *= ra

# Envolvente de granos: suma de ventanas Hann (para modular ruido ya filtrado).
static func add_hann(env: PackedFloat32Array, start: int, cnt: int, amp: float) -> void:
	var n := env.size()
	var inv: float = TAU / float(maxi(cnt, 1))
	for j in cnt:
		var i: int = start + j
		if i >= n: break
		if i < 0: continue
		env[i] += amp * (0.5 - 0.5 * cos(inv * float(j)))

# ---------------------------------------------------------------- mezcla
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, offset := 0, gain := 1.0) -> void:
	var n := dst.size()
	var j0: int = maxi(0, -offset)
	var j1: int = mini(src.size(), n - offset)
	for j in range(j0, j1): dst[offset + j] += src[j] * gain

static func scale(x: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in x.size(): x[i] *= g
	return x

# Pliega un buffer largo sobre L muestras (circular): las colas que pasan de L entran por la cabeza.
static func fold(src: PackedFloat32Array, L: int) -> PackedFloat32Array:
	var out := zeros(L)
	for i in src.size(): out[i % L] += src[i]
	return out

# Bucle: x dura L + F; la cola [L, L+F) se mezcla en la cabeza con fundido cruzado de igual potencia.
# out[0] = x[L] y out[L-1] = x[L-1]: el salto del bucle es el paso natural x[L-1]→x[L].
static func make_loop(x: PackedFloat32Array, fade_s: float) -> PackedFloat32Array:
	var F: int = n_of(fade_s)
	var L: int = x.size() - F
	var out := x.slice(0, L)
	for i in F:
		var u: float = float(i) / float(F) * (PI * 0.5)
		out[i] = x[i] * sin(u) + x[L + i] * cos(u)
	return out

# ---------------------------------------------------------------- espacio
# Reverberación tipo Freeverb (4 peines con amortiguación + 2 pasa-todo). size escala las demoras.
static func reverb(x: PackedFloat32Array, size := 1.0, fb := 0.8, damp := 0.3, wet := 0.25, dry := 1.0) -> PackedFloat32Array:
	# Freeverb mono: 8 peines con amortiguación (demoras de Jezar a 44,1 kHz × size) + 4 pasa-todo en serie.
	var d0: int = maxi(8, int(1116 * size)); var d1: int = maxi(8, int(1188 * size))
	var d2: int = maxi(8, int(1277 * size)); var d3: int = maxi(8, int(1356 * size))
	var d4: int = maxi(8, int(1422 * size)); var d5: int = maxi(8, int(1491 * size))
	var d6: int = maxi(8, int(1557 * size)); var d7: int = maxi(8, int(1617 * size))
	var e0: int = maxi(8, int(556 * size)); var e1: int = maxi(8, int(441 * size))
	var e2: int = maxi(8, int(341 * size)); var e3: int = maxi(8, int(225 * size))
	var c0 := zeros(d0); var c1 := zeros(d1); var c2 := zeros(d2); var c3 := zeros(d3)
	var c4 := zeros(d4); var c5 := zeros(d5); var c6 := zeros(d6); var c7 := zeros(d7)
	var p0 := zeros(e0); var p1 := zeros(e1); var p2 := zeros(e2); var p3 := zeros(e3)
	var i0 := 0; var i1 := 0; var i2 := 0; var i3 := 0; var i4 := 0; var i5 := 0; var i6 := 0; var i7 := 0
	var j0 := 0; var j1 := 0; var j2 := 0; var j3 := 0
	var f0 := 0.0; var f1 := 0.0; var f2 := 0.0; var f3 := 0.0; var f4 := 0.0; var f5 := 0.0; var f6 := 0.0; var f7 := 0.0
	var dm: float = damp; var dn: float = 1.0 - damp
	for i in x.size():
		var xi: float = x[i]
		var inp: float = xi * 0.1
		var y0: float = c0[i0]; f0 = y0 * dn + f0 * dm; c0[i0] = inp + f0 * fb; i0 += 1
		if i0 >= d0: i0 = 0
		var y1: float = c1[i1]; f1 = y1 * dn + f1 * dm; c1[i1] = inp + f1 * fb; i1 += 1
		if i1 >= d1: i1 = 0
		var y2: float = c2[i2]; f2 = y2 * dn + f2 * dm; c2[i2] = inp + f2 * fb; i2 += 1
		if i2 >= d2: i2 = 0
		var y3: float = c3[i3]; f3 = y3 * dn + f3 * dm; c3[i3] = inp + f3 * fb; i3 += 1
		if i3 >= d3: i3 = 0
		var y4: float = c4[i4]; f4 = y4 * dn + f4 * dm; c4[i4] = inp + f4 * fb; i4 += 1
		if i4 >= d4: i4 = 0
		var y5: float = c5[i5]; f5 = y5 * dn + f5 * dm; c5[i5] = inp + f5 * fb; i5 += 1
		if i5 >= d5: i5 = 0
		var y6: float = c6[i6]; f6 = y6 * dn + f6 * dm; c6[i6] = inp + f6 * fb; i6 += 1
		if i6 >= d6: i6 = 0
		var y7: float = c7[i7]; f7 = y7 * dn + f7 * dm; c7[i7] = inp + f7 * fb; i7 += 1
		if i7 >= d7: i7 = 0
		var o: float = y0 + y1 + y2 + y3 + y4 + y5 + y6 + y7
		var b0: float = p0[j0]; var o0: float = b0 - o; p0[j0] = o + b0 * 0.5; j0 += 1
		if j0 >= e0: j0 = 0
		var b1: float = p1[j1]; var o1: float = b1 - o0; p1[j1] = o0 + b1 * 0.5; j1 += 1
		if j1 >= e1: j1 = 0
		var b2: float = p2[j2]; var o2: float = b2 - o1; p2[j2] = o1 + b2 * 0.5; j2 += 1
		if j2 >= e2: j2 = 0
		var b3: float = p3[j3]; var o3: float = b3 - o2; p3[j3] = o2 + b3 * 0.5; j3 += 1
		if j3 >= e3: j3 = 0
		x[i] = xi * dry + o3 * wet
	return x

# Reverberación calculada a media tasa (sólo la cola; lo seco queda a tasa completa). Para buffers largos.
static func reverb_lofi(x: PackedFloat32Array, size := 1.0, fb := 0.8, damp := 0.3, wet := 0.25) -> PackedFloat32Array:
	var w := downsample2(x)
	reverb(w, size * 0.5, fb, damp, 1.0, 0.0)
	var up := upsample2(w, x.size())
	for i in x.size(): x[i] += up[i] * wet
	return x

# Diezmado ×2 con filtro [1 2 1]/4 (para procesos a media tasa: colas, campanas).
static func downsample2(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size()
	var m: int = (n + 1) / 2
	var y := zeros(m)
	for j in m:
		var i: int = 2 * j
		var a: float = x[i - 1] if i > 0 else 0.0
		var c: float = x[i + 1] if i + 1 < n else 0.0
		y[j] = 0.25 * a + 0.5 * x[i] + 0.25 * c
	return y

# Sobremuestreo ×2: muestras pares = originales; impares = interpolación de 4 puntos (−1 9 9 −1)/16.
static func upsample2(x: PackedFloat32Array, n_out: int) -> PackedFloat32Array:
	var out := zeros(n_out)
	var m := x.size()
	if m == 0: return out
	for i in n_out:
		var j: int = i >> 1
		if (i & 1) == 0:
			out[i] = x[mini(j, m - 1)]
		else:
			var a: float = x[maxi(j - 1, 0)]
			var b: float = x[mini(j, m - 1)]
			var c: float = x[mini(j + 1, m - 1)]
			var d: float = x[mini(j + 2, m - 1)]
			out[i] = (9.0 * (b + c) - a - d) * 0.0625
	return out

# Eco simple (rebote en una fachada): copia demorada, atenuada y opaca.
static func slap(x: PackedFloat32Array, delay_s: float, gain: float, lp_hz := 2500.0) -> PackedFloat32Array:
	var d: int = n_of(delay_s)
	var e := x.duplicate()
	e = lp1(e, lp_hz)
	for i in range(x.size() - 1, d - 1, -1): x[i] += e[i - d] * gain
	return x

# ---------------------------------------------------------------- nivel
static func peak(x: PackedFloat32Array) -> float:
	var m := 0.0
	for v in x: m = maxf(m, absf(v))
	return m

static func rms(x: PackedFloat32Array) -> float:
	if x.is_empty(): return 0.0
	var s := 0.0
	for v in x: s += v * v
	return sqrt(s / float(x.size()))

static func normalize(x: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var p := peak(x)
	if p > 1e-9: scale(x, target / p)
	return x

static func to_rms(x: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var r := rms(x)
	if r > 1e-12: scale(x, target / r)
	return x

# Limitador suave: lineal hasta knee, curva tanh hasta ceil.
static func limit(x: PackedFloat32Array, ceiling := 0.95, knee := 0.8) -> PackedFloat32Array:
	var room: float = ceiling - knee
	for i in x.size():
		var v: float = x[i]
		var a: float = absf(v)
		if a > knee: x[i] = signf(v) * (knee + room * tanh((a - knee) / room))
	return x

# ---------------------------------------------------------------- salida
# PCM 16 bits; si loop, agrega LOOP_GUARD muestras de la cabeza después del final (loop_end = x.size()).
static func pcm16(x: PackedFloat32Array, loop: bool) -> PackedByteArray:
	var n := x.size()
	var g: int = mini(LOOP_GUARD, n) if loop else 0
	var out := PackedByteArray()
	out.resize((n + g) * 2)
	for i in n:
		out.encode_s16(i * 2, int(round(clampf(x[i], -1.0, 1.0) * 32767.0)))
	for i in g:
		out.encode_s16((n + i) * 2, int(round(clampf(x[i], -1.0, 1.0) * 32767.0)))
	return out

static func wav_from_pcm(bytes: PackedByteArray, loop: bool, frames: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = frames
	else:
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w

static func to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	return wav_from_pcm(pcm16(samples, loop), loop, samples.size())

# Lee una muestra (−1..1) de un WAV de 16 bits.
static func sample_at(w: AudioStreamWAV, i: int) -> float:
	return float(w.data.decode_s16(i * 2)) / 32767.0

static func wav_to_floats(w: AudioStreamWAV) -> PackedFloat32Array:
	var d := w.data
	var n: int = d.size() / 2
	var x := zeros(n)
	for i in n: x[i] = float(d.decode_s16(i * 2)) / 32767.0
	return x
