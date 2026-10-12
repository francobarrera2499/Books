# audio/analysis.gd — W1-AUDIO. Análisis de señal para tests y devtools (no se usa en el juego):
# FFT, espectro medio, centroide, energía por banda, Goertzel, envolvente, ataques, autocorrelación, espectrograma.
extends RefCounted

const SR := 44100

# FFT radix-2 en el lugar (tamaño potencia de 2).
static func fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var tr := re[i]; re[i] = re[j]; re[j] = tr
			var ti := im[i]; im[i] = im[j]; im[j] = ti
	var m := 2
	while m <= n:
		var h := m >> 1
		var ang: float = -TAU / float(m)
		var wr := cos(ang)
		var wi := sin(ang)
		for s in range(0, n, m):
			var cr := 1.0
			var ci := 0.0
			for k in h:
				var a: int = s + k
				var b: int = a + h
				var br: float = re[b]; var bi: float = im[b]
				var tr2: float = br * cr - bi * ci
				var ti2: float = br * ci + bi * cr
				var ar: float = re[a]; var ai: float = im[a]
				re[b] = ar - tr2; im[b] = ai - ti2
				re[a] = ar + tr2; im[a] = ai + ti2
				var ncr: float = cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = ncr
		m <<= 1

# Potencia |X[k]|² (k = 0..size/2) de una ventana Hann desde start (rellena con ceros fuera de x).
static func power_spectrum(x: PackedFloat32Array, start: int, size: int) -> PackedFloat64Array:
	var re := PackedFloat64Array(); re.resize(size); re.fill(0.0)
	var im := PackedFloat64Array(); im.resize(size); im.fill(0.0)
	var n := x.size()
	for i in size:
		var j: int = start + i
		if j >= 0 and j < n:
			re[i] = x[j] * (0.5 - 0.5 * cos(TAU * float(i) / float(size)))
	fft(re, im)
	var p := PackedFloat64Array(); p.resize(size / 2 + 1)
	for k in size / 2 + 1: p[k] = re[k] * re[k] + im[k] * im[k]
	return p

# Espectro de potencia medio entre t0 y t1 (s); t1 < 0 = hasta el final.
static func avg_spectrum(x: PackedFloat32Array, size := 2048, t0 := 0.0, t1 := -1.0, max_frames := 64) -> PackedFloat64Array:
	var a: int = int(t0 * SR)
	var b: int = x.size() if t1 < 0.0 else mini(x.size(), int(t1 * SR))
	var acc := PackedFloat64Array(); acc.resize(size / 2 + 1); acc.fill(0.0)
	var span: int = maxi(0, b - a - size)
	var frames: int = clampi(span / (size / 2) + 1, 1, max_frames)
	for f in frames:
		var st: int = a + (span * f / maxi(1, frames - 1) if frames > 1 else 0)
		var p := power_spectrum(x, st, size)
		for k in p.size(): acc[k] += p[k]
	return acc

static func bin_hz(size: int) -> float:
	return float(SR) / float(size)

static func centroid(spec: PackedFloat64Array, size: int) -> float:
	var s := 0.0; var w := 0.0
	var bh := bin_hz(size)
	for k in range(1, spec.size()):
		s += spec[k] * float(k) * bh
		w += spec[k]
	return s / w if w > 0.0 else 0.0

# Fracción de energía en [f0, f1).
static func band_ratio(spec: PackedFloat64Array, size: int, f0: float, f1: float) -> float:
	var tot := 0.0; var bandv := 0.0
	var bh := bin_hz(size)
	for k in range(1, spec.size()):
		var f: float = float(k) * bh
		tot += spec[k]
		if f >= f0 and f < f1: bandv += spec[k]
	return bandv / tot if tot > 0.0 else 0.0

# Frecuencia del máximo en [f0, f1] con interpolación parabólica.
static func peak_freq(spec: PackedFloat64Array, size: int, f0: float, f1: float) -> float:
	var bh := bin_hz(size)
	var k0: int = maxi(1, int(f0 / bh)); var k1: int = mini(spec.size() - 2, int(f1 / bh))
	var best := k0
	for k in range(k0, k1 + 1):
		if spec[k] > spec[best]: best = k
	var a := spec[best - 1]; var b := spec[best]; var c := spec[best + 1]
	var den := a - 2.0 * b + c
	var off := 0.0
	if absf(den) > 1e-30: off = clampf(0.5 * (a - c) / den, -0.5, 0.5)
	return (float(best) + off) * bh

# Potencia normalizada de Goertzel en f sobre [start, start+n).
static func goertzel(x: PackedFloat32Array, f: float, start := 0, n := -1) -> float:
	var e: int = x.size() if n < 0 else mini(x.size(), start + n)
	var w: float = TAU * f / SR
	var c: float = 2.0 * cos(w)
	var s1 := 0.0; var s2 := 0.0
	for i in range(start, e):
		var s0: float = x[i] + c * s1 - s2
		s2 = s1; s1 = s0
	var cnt: int = maxi(1, e - start)
	return (s1 * s1 + s2 * s2 - c * s1 * s2) / float(cnt * cnt)

# Envolvente RMS por ventanas de win_s.
static func env_rms(x: PackedFloat32Array, win_s := 0.005) -> PackedFloat32Array:
	var w: int = maxi(1, int(win_s * SR))
	var nw: int = x.size() / w
	var e := PackedFloat32Array(); e.resize(nw)
	for k in nw:
		var s := 0.0
		for i in range(k * w, k * w + w): s += x[i] * x[i]
		e[k] = sqrt(s / float(w))
	return e

# Ataques: la envolvente sube rise_db sobre la media (RMS) de los 40 ms previos y supera (máximo − floor_db).
static func onsets(x: PackedFloat32Array, win_s := 0.005, rise_db := 10.0, min_gap_s := 0.04, floor_db := 30.0) -> Array:
	var e := env_rms(x, win_s)
	var mx := 0.0
	for v in e: mx = maxf(mx, v)
	if mx <= 0.0: return []
	var floor_lin: float = mx * db_to_linear(-floor_db)
	var look: int = maxi(1, int(0.04 / win_s))
	var gap: int = maxi(1, int(min_gap_s / win_s))
	var out := []
	var last := -1000000
	for k in range(1, e.size()):
		if e[k] < floor_lin or k - last < gap: continue
		var acc := 0.0
		var cnt := 0
		for j in range(maxi(0, k - look), k):
			acc += e[j] * e[j]
			cnt += 1
		var mn: float = sqrt(acc / float(maxi(cnt, 1)))
		if linear_to_db(maxf(e[k], 1e-9)) - linear_to_db(maxf(mn, 1e-9)) >= rise_db:
			out.append(float(k) * win_s)
			last = k
	return out

# Autocorrelación normalizada de una señal (p. ej. una envolvente) en un rango de retardos → {lag, r}.
static func autocorr_peak(x: PackedFloat32Array, lag_min: int, lag_max: int) -> Dictionary:
	var n := x.size()
	var mean := 0.0
	for v in x: mean += v
	mean /= float(maxi(1, n))
	var best := {"lag": lag_min, "r": -2.0}
	var e0 := 0.0
	for i in n: e0 += (x[i] - mean) * (x[i] - mean)
	if e0 <= 0.0: return best
	for lag in range(lag_min, mini(lag_max, n - 1) + 1):
		var s := 0.0
		for i in range(0, n - lag): s += (x[i] - mean) * (x[i + lag] - mean)
		var r: float = s / e0 * float(n) / float(n - lag)
		if r > best["r"]: best = {"lag": lag, "r": r}
	return best

# Espectrograma (frecuencia logarítmica fmin..fmax) + franja de forma de onda arriba. Imagen RGB8.
static func spectrogram_image(x: PackedFloat32Array, width := 600, height := 220, fmin := 40.0, fmax := 16000.0, size := 2048, wave_h := 60, db_range := 80.0) -> Image:
	var img := Image.create(width, height + wave_h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.06, 0.05, 0.04))
	var n := x.size()
	var bh := bin_hz(size)
	var cols := []
	var gmax := 1e-20
	for c in width:
		var center: int = int(float(c) / float(width) * float(n))
		var p := power_spectrum(x, center - size / 2, size)
		cols.append(p)
		for v in p: gmax = maxf(gmax, v)
	var lmin := log(fmin); var lmax := log(fmax)
	for c in width:
		var p: PackedFloat64Array = cols[c]
		for r in height:
			var fa: float = exp(lerpf(lmin, lmax, float(height - 1 - r) / float(height)))
			var fb: float = exp(lerpf(lmin, lmax, float(height - r) / float(height)))
			var ka: int = clampi(int(fa / bh), 1, p.size() - 1)
			var kb: int = clampi(int(fb / bh), ka, p.size() - 1)
			var v := 0.0
			for k in range(ka, kb + 1): v = maxf(v, p[k])
			var db := 10.0 * log(maxf(v, 1e-30) / gmax) / log(10.0)
			var u := clampf(1.0 + db / db_range, 0.0, 1.0)
			img.set_pixel(c, wave_h + r, Color(pow(u, 0.8), pow(u, 1.6) * 0.9, pow(u, 3.0) * 0.6))
	# forma de onda (pico por columna) y línea de 0 dBFS
	for c in width:
		var a: int = int(float(c) / float(width) * float(n))
		var b: int = int(float(c + 1) / float(width) * float(n))
		var mx := 0.0
		for i in range(a, mini(b, n)): mx = maxf(mx, absf(x[i]))
		var hh: int = int(mx * float(wave_h / 2 - 2))
		for y in range(wave_h / 2 - hh, wave_h / 2 + hh + 1):
			img.set_pixel(c, clampi(y, 0, wave_h - 1), Color(0.85, 0.8, 0.7))
	# marcas de frecuencia: 100 Hz, 1 kHz, 10 kHz
	for f in [100.0, 1000.0, 10000.0]:
		var r: int = height - 1 - int((log(f) - lmin) / (lmax - lmin) * float(height))
		if r >= 0 and r < height:
			for c in range(0, width, 4): img.set_pixel(c, wave_h + r, Color(0.3, 0.55, 0.9))
	return img
