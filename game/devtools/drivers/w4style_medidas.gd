# devtools/drivers/w4style_medidas.gd — W4-STYLE. Medidas sobre capturas del grabado (las usan el driver
# w4style_lugares.gd y tests/test_t27_window.gd). No es un driver: biblioteca estática.
#   mask_from_depth(d1, d0, r) -> PackedByteArray      píxeles cuya profundidad (debug_view 4) cambia al ocultar la figura
#   legibility(eng, mask, r) -> Dictionary             {area, f_in, f_ring, c_in, c_out, fill, outline, white, leg}
#   screen_rect(cam, fig) -> Rect2i                     rectángulo de pantalla de las mallas de una figura
#   ink_frac(img, r) · mean(img) · lum(data, w, x, y)
# Legibilidad en 1 bit (tinta = lum < 0,5) de una figura de máscara M:
#   fill    = |tinta dentro (a > 2,5 px del borde) − tinta en el anillo de afuera (3,5–12 px)|  (mancha contra fondo)
#   outline = |tinta en el filo interior (≤ 1,5 px) − tinta en el filo exterior (≤ 2 px)|        (línea + halo)
#   white   = min(|filo − dentro|, |filo − anillo|) con filo = filo interior ∪ exterior          (línea blanca entre tintas)
#   leg     = max(fill, outline, white)
extends RefCounted

static func lum(d: PackedByteArray, w: int, x: int, y: int) -> float:
	var i := (y * w + x) * 3
	return (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255.0

static func ink_frac(img: Image, r: Rect2i, step := 2) -> float:
	var d := img.get_data()
	var w := img.get_width()
	var k := 0
	var n := 0
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			if lum(d, w, x, y) < 0.5:
				k += 1
			n += 1
	return float(k) / maxf(1.0, n)

static func mean(img: Image, r := Rect2i(), step := 3) -> float:
	if r.size.x <= 0:
		r = Rect2i(Vector2i.ZERO, img.get_size())
	var d := img.get_data()
	var w := img.get_width()
	var s := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, step):
		for x in range(r.position.x, r.end.x, step):
			s += lum(d, w, x, y)
			n += 1
	return s / maxf(1.0, n)

static func screen_rect(cam: Camera3D, fig: Node3D) -> Rect2i:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var any := false
	var mis: Array = fig.find_children("*", "MeshInstance3D", true, false)
	if fig is MeshInstance3D:
		mis.append(fig)
	for mi in mis:
		var ab: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = (mi as Node3D).global_transform
		for k in 8:
			var p := xf * (ab.position + ab.size * Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1))
			if cam.is_position_behind(p):
				continue
			var s := cam.unproject_position(p)
			lo = lo.min(s)
			hi = hi.max(s)
			any = true
	if not any:
		return Rect2i()
	return Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo).ceil()))

static func mask_from_depth(d1: Image, d0: Image, r: Rect2i) -> PackedByteArray:
	var a1 := d1.get_data()
	var a0 := d0.get_data()
	var W := d1.get_width()
	var m := PackedByteArray()
	m.resize(r.size.x * r.size.y)
	for y in r.size.y:
		for x in r.size.x:
			var i := ((r.position.y + y) * W + r.position.x + x) * 3
			var diff := absi(a1[i] - a0[i]) + absi(a1[i + 1] - a0[i + 1]) + absi(a1[i + 2] - a0[i + 2])
			m[y * r.size.x + x] = 1 if diff > 3 else 0
	return m

static func legibility(eng: Image, mask: PackedByteArray, r: Rect2i) -> Dictionary:
	return legibility_bands(eng, bands(mask, r.size.x, r.size.y), r)

# bandas de la máscara: 0 nada · 1 dentro (> 2,5 px del borde) · 2 filo interior (≤ 1,5 px) · 3 filo exterior (≤ 2 px)
# · 4 anillo (3,5–12 px afuera). Se calculan una vez por figura; legibility_bands las aplica a cada captura.
static func bands(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var din := chamfer(mask, w, h, 1)
	var dout := chamfer(mask, w, h, 0)
	var b := PackedByteArray()
	b.resize(w * h)
	for p in w * h:
		if mask[p] == 1:
			b[p] = 2 if din[p] <= 1.5 else (1 if din[p] > 2.5 else 0)
		else:
			b[p] = 3 if dout[p] <= 2.0 else (4 if dout[p] > 3.5 and dout[p] <= 12.0 else 0)
	return b

static func legibility_bands(eng: Image, bnd: PackedByteArray, r: Rect2i) -> Dictionary:
	var de := eng.get_data()
	var W := eng.get_width()
	var n := [0, 0, 0, 0, 0]
	var k := [0, 0, 0, 0, 0]
	var area := 0
	for y in r.size.y:
		var row := y * r.size.x
		var base := ((r.position.y + y) * W + r.position.x) * 3
		for x in r.size.x:
			var c: int = bnd[row + x]
			if c == 0:
				continue
			if c <= 2:
				area += 1
			var i := base + x * 3
			n[c] += 1
			if 0.2126 * de[i] + 0.7152 * de[i + 1] + 0.0722 * de[i + 2] < 127.5:
				k[c] += 1
	var f := [0.0, 0.0, 0.0, 0.0, 0.0]
	for c in range(1, 5):
		f[c] = float(k[c]) / maxf(1.0, n[c])
	var band := float(k[2] + k[3]) / maxf(1.0, n[2] + n[3])
	var fill := absf(f[1] - f[4])
	var outline := absf(f[2] - f[3])
	var white := minf(absf(band - f[1]), absf(band - f[4]))
	return {"area": area, "f_in": f[1], "f_ring": f[4], "c_in": f[2], "c_out": f[3], "fill": fill, "outline": outline,
		"white": white, "leg": maxf(fill, maxf(outline, white))}

# distancia chamfer (1, √2) hasta la región de valor distinto de `inside` (inside=1: dentro de la máscara; 0: fuera)
static func chamfer(mask: PackedByteArray, w: int, h: int, inside: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	const BIG := 1e6
	for p in w * h:
		d[p] = BIG if mask[p] == inside else 0.0
	for y in h:
		for x in w:
			var p := y * w + x
			if d[p] == 0.0:
				continue
			var v := d[p]
			if x > 0: v = minf(v, d[p - 1] + 1.0)
			if y > 0:
				v = minf(v, d[p - w] + 1.0)
				if x > 0: v = minf(v, d[p - w - 1] + 1.4142)
				if x < w - 1: v = minf(v, d[p - w + 1] + 1.4142)
			d[p] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var p := y * w + x
			if d[p] == 0.0:
				continue
			var v := d[p]
			if x < w - 1: v = minf(v, d[p + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[p + w] + 1.0)
				if x < w - 1: v = minf(v, d[p + w + 1] + 1.4142)
				if x > 0: v = minf(v, d[p + w - 1] + 1.4142)
			d[p] = v
	return d
