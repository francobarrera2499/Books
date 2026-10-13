// Grabado de la Strand (W1-POST; calibración W4-STYLE). Contrato: docs/ARCHITECTURE.md §7.8 · GDD §14.5.
// Look 'grabado' del registro world/post/looks.gd (parámetros: looks/grabado.json -> base lighting).
// Quad 2x2 colgado de la Camera3D (engraving_post.gd). Lee color, profundidad y normales del 3D y escribe
// mix(paper, ink, máscara): contornos (profundidad + normales, 4 vecinos) + trama anclada a la esfera de la cámara
// (hatch=1, «talla»: rayado por cara cuyas filas se reparten con los umbrales Bayer 8x8 -> cobertura 1 − t en toda la
// escala; hatch=0: Bayer puro) + halo de papel tras los bordes de oclusión de lo macizo (siluetas legibles en 1 bit) + grano de
// papel. Tono por preset: exposición, contraste, gamma, piso y viñeta. Estático: no usa el tiempo (la trama no titila
// con la cámara quieta).
// Las CanvasLayer (lector, HUD, cuadernos) se dibujan después del 3D: este shader no las toca.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D nr_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// --- contrato §7.8 ---
uniform vec4 paper : source_color = vec4(0.937255, 0.901961, 0.823529, 1.0); // #efe6d2 (por franja)
uniform vec4 ink : source_color = vec4(0.105882, 0.090196, 0.070588, 1.0);   // #1b1712
uniform float edge_depth = 0.08;  // umbral relativo: |laplaciano(1/z)| * z
uniform float edge_normal = 0.35; // umbral 1 - cos(ángulo) entre normales vecinas (0,35 ≈ 49°)
uniform float cell_px = 2.0;      // px por celda Bayer a 900 px de alto (escala con el alto del viewport)
uniform float grain = 0.05;       // grano de papel (0 = liso)
// --- extras de estilo (los fija Lighting.look por preset) ---
uniform float exposure = 1.0;     // multiplica la luminancia lineal antes del tono
uniform float contrast = 1.5;     // curva lineal con pivote en 0,5 (0,5 -> 0,5: calibración T27)
uniform float hatch = 1.0;        // 0 = Bayer puro; 1 = talla (rayado por cara, cruzado en sombra; misma cobertura media)
uniform float hatch_below = 0.4;  // tono bajo el cual el rayado se cruza
uniform float hatch_period = 3.0; // período del rayado en celdas (6 px a 900 p); el borde lo reparte la trama Bayer
uniform float white_line = 0.16;  // bajo este tono los contornos se tallan en blanco (grabado a la contra)
uniform float haze = 0.0;         // bruma de Londres: aclara con la distancia
uniform vec2 haze_range = vec2(14.0, 70.0);
// --- calibración por preset (W4-STYLE; neutros por defecto: la calibración T27 del gris 0,5 no cambia) ---
uniform float gamma = 1.0;        // < 1 aclara los medios tonos (interiores de día legibles), > 1 los hunde (noche)
uniform float tone_floor = 0.0;   // tono mínimo: de día lo más oscuro sigue siendo rayado cruzado, no negro macizo
uniform float vignette = 0.0;     // noche de gas: los bordes del cuadro se hunden hacia la tinta (el centro, la lámpara)
uniform float halo = 1.0;         // (0/1) separación de siluetas: filete de papel del lado lejano de un borde de oclusión
uniform float halo_rel = 0.06;    // salto relativo de profundidad que cuenta como oclusión (figura delante del fondo)
uniform float halo_abs = 0.12;    // y salto absoluto mínimo (m)
uniform float halo_thick = 3.0;   // px seguidos que debe ocupar lo que tapa: ramas, barrotes y rejas finas no llevan halo
uniform float edge_far = 90.0;    // los contornos se puntean y desaparecen hacia esta distancia (m)
uniform vec2 anchor_rad = vec2(0.0); // giro acumulado de la cámara (yaw, pitch) en rad: ancla la trama a la esfera
uniform int debug_view = 0;       // 0 grabado · 1 tono continuo · 2 contornos · 3 color 3D sin tocar · 4 profundidad

float to_srgb(float x) {
	x = clamp(x, 0.0, 1.0);
	return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}

float to_linear(float x) {
	return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
}

// Bayer 8x8 procedural: bit-reverse(interleave(x^y, y)) -> 0..63, umbral centrado.
float bayer8(ivec2 p) {
	int x = p.x & 7;
	int y = p.y & 7;
	int xy = x ^ y;
	int v = ((xy & 1) << 5) | ((y & 1) << 4) | ((xy & 2) << 2) | ((y & 2) << 1) | ((xy & 4) >> 1) | ((y & 4) >> 2);
	return (float(v) + 0.5) / 64.0;
}

// Umbral de una trama de líneas: q = coordenada entera (px) perpendicular a la línea, período P; p = coordenada a lo
// largo de la línea. Las filas se ordenan por distancia al núcleo (0 primero, luego ±1, ±2…) y cada fila se reparte con
// los 64 umbrales Bayer recorridos A LO LARGO de la línea (celdas de cs px; desfase por fila): umbrales uniformes en
// [0, 1) por fila, así la cobertura de tinta es 1 − t en toda la escala (calibración T27), no sólo en el gris 0,5.
float line_thr(int q, int p, int P, int csi) {
	int j = q - P * int(floor(float(q) / float(P)));
	int d = min(j, P - j);
	int rank = (j == 0) ? 0 : ((2 * j == P) ? P - 1 : 2 * d - 1 + ((2 * j > P) ? 1 : 0));
	int idx = int(floor(float(p) / float(csi))) + 37 * q;
	idx = idx - 64 * int(floor(float(idx) / 64.0));
	float bb = bayer8(ivec2(idx & 7, idx >> 3));
	return 1.0 - (float(rank) + bb) / float(P);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lin_z(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(-v.z / v.w, 1e-4);
}

vec3 nrm(vec2 uv) {
	return texture(nr_tex, uv).xyz * 2.0 - 1.0;
}

// Halo hacia d (paso de 1 px de trazo; z1 = profundidad ya leída a 1 px): este píxel está a 1 o 2 px de algo bastante
// más cerca que ocupa ≥ halo_thick px seguidos en esa dirección. Devuelve la profundidad de lo que tapa (1e9 = sin halo).
// Sin el mínimo de grosor, de noche cada rama y cada barrote se ensanchaba en papel (árboles «nevados», rejas de hierro
// leídas como empalizadas blancas). Un declive continuo (piso rasante a lo lejos) no es un borde: a 2 px el salto tiene
// que estar entre el px 1 y el 2.
float halo_dir(vec2 uv, vec2 d, float zc, float z1, mat4 ipm) {
	int need = int(clamp(floor(halo_thick + 0.5), 1.0, 6.0));
	float z2 = lin_z(uv + 2.0 * d, ipm);
	bool o1 = zc - z1 > max(halo_abs, halo_rel * z1);
	bool o2 = zc - z2 > max(halo_abs, halo_rel * z2);
	if (!o1 && (!o2 || zc - z1 > 0.25 * (zc - z2))) {
		return 1e9;
	}
	int k0 = o1 ? 1 : 2;
	for (int k = k0 + 1; k < k0 + need; k++) {
		float zk = (k == 2) ? z2 : lin_z(uv + float(k) * d, ipm);
		if (zc - zk <= max(halo_abs, halo_rel * zk)) {
			return 1e9;
		}
	}
	return o1 ? z1 : z2;
}

// tono de un color 3D con la curva del preset (sin viñeta ni bruma): lo usa la regla de la línea blanca
float tone_of(vec3 c) {
	float t = to_srgb(dot(c, vec3(0.2126, 0.7152, 0.0722)) * exposure);
	t = clamp((t - 0.5) * contrast + 0.5, 0.0, 1.0);
	return tone_floor + (1.0 - tone_floor) * pow(t, gamma);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float sc = max(1.0, floor(VIEWPORT_SIZE.y / 900.0 + 0.5)); // px de trazo a esta resolución
	vec2 o = sc / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;

	// --- contornos: discontinuidad de profundidad (laplaciano de 1/z, plano = 0) y de normal (4 vecinos) ---
	float zc = lin_z(uv, INV_PROJECTION_MATRIX);
	float zl = lin_z(uv - vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float zr = lin_z(uv + vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float zu = lin_z(uv - vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float zd = lin_z(uv + vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float wc = 1.0 / zc;
	float lap = abs(1.0 / zl + 1.0 / zr - 2.0 * wc) + abs(1.0 / zu + 1.0 / zd - 2.0 * wc);
	float ed = lap * zc;
	vec3 nc = nrm(uv);
	float en = 0.0;
	en = max(en, 1.0 - dot(nc, nrm(uv - vec2(o.x, 0.0))));
	en = max(en, 1.0 - dot(nc, nrm(uv + vec2(o.x, 0.0))));
	en = max(en, 1.0 - dot(nc, nrm(uv - vec2(0.0, o.y))));
	en = max(en, 1.0 - dot(nc, nrm(uv + vec2(0.0, o.y))));
	float edge = (ed > edge_depth || en > edge_normal) ? 1.0 : 0.0;

	// --- tono: luminancia lineal -> percepción (sRGB) -> curva de contraste con pivote 0,5 -> bruma ---
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722)) * exposure;
	float t = to_srgb(lum);
	t = clamp((t - 0.5) * contrast + 0.5, 0.0, 1.0);
	t = tone_floor + (1.0 - tone_floor) * pow(t, gamma);
	if (vignette > 0.0) {
		vec2 vc = (uv - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		t *= 1.0 - vignette * smoothstep(0.3, 1.0, length(vc) / 0.95);
	}
	t = mix(t, 1.0, haze * smoothstep(haze_range.x, haze_range.y, zc));

	// --- halo: del lado lejano de un borde de oclusión (algo bastante más cerca a 1-2 px) va un filete de papel;
	// con el contorno de tinta del lado cercano queda «línea negra + blanco», como el grabador separa una figura
	// del fondo. Sólo depende de la profundidad (y del grosor en pantalla): nunca marca un objeto por ser pista.
	vec2 o2 = 2.0 * o;
	float zn = 1e9; // profundidad de lo que tapa (1e9 = sin halo)
	if (halo > 0.5) {
		zn = min(min(halo_dir(uv, vec2(-o.x, 0.0), zc, zl, INV_PROJECTION_MATRIX), halo_dir(uv, vec2(o.x, 0.0), zc, zr, INV_PROJECTION_MATRIX)),
			min(halo_dir(uv, vec2(0.0, -o.y), zc, zu, INV_PROJECTION_MATRIX), halo_dir(uv, vec2(0.0, o.y), zc, zd, INV_PROJECTION_MATRIX)));
	}
	bool behind = zn < 1e8;

	// --- trama anclada: rejilla de píxeles enteros desplazada por el giro de la cámara (px/rad = FOV y alto) ---
	float cs = max(1.0, floor(cell_px * VIEWPORT_SIZE.y / 900.0 + 0.5));
	float k = 0.5 * VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]); // abs: la proyección de Vulkan invierte Y
	vec2 off = floor(vec2(anchor_rad.x, -anchor_rad.y) * k + 0.5);
	vec2 g = floor(FRAGCOORD.xy) + off;
	ivec2 cell = ivec2(floor(g / cs));
	float b = bayer8(cell);
	float ink_m = t < b ? 1.0 : 0.0;
	// talla (hatch > 0): rayado anclado a la misma rejilla; dirección según la cara (mundo): pisos y cielo
	// horizontales, caras X a 45°, caras Z a -45°; en sombra, rayado cruzado. Umbral ~uniforme -> cobertura 1 - t.
	if (hatch > 0.0) {
		vec3 nw = mat3(INV_VIEW_MATRIX) * nc;
		bool bg = texture(depth_tex, uv).r <= 0.0;
		vec3 an = abs(nw);
		float dir = 0.0; // 0 horizontal, 1 diagonal /, 2 diagonal '\'
		if (!bg) {
			float sel_y = (an.y - max(an.x, an.z)) * 3.0 + 0.5;
			float sel_x = (an.x - an.z) * 3.0 + 0.5;
			dir = (sel_y > b) ? 0.0 : ((sel_x > b) ? 1.0 : 2.0);
		}
		// período en px: horizontal sobre y; diagonales sobre x ± y (√2 más largo: el mismo espaciado perpendicular)
		ivec2 gi = ivec2(g);
		int csi = int(cs);
		int ph = max(2, int(floor(hatch_period * cs + 0.5)));
		int pd = max(2, int(floor(hatch_period * cs * 1.41421 + 0.5)));
		int sum = gi.x + gi.y;
		int dif = gi.x - gi.y;
		// dirección 1: y (a lo largo, x) · x+y (a lo largo, x−y) · x−y (a lo largo, x+y); la 2.ª cruza en diagonal
		float r1 = dir < 0.5 ? line_thr(gi.y, gi.x, ph, csi) : (dir < 1.5 ? line_thr(sum, dif, pd, csi) : line_thr(dif, sum, pd, csi));
		float r2 = (dir > 0.5 && dir < 1.5) ? line_thr(dif + pd / 2, sum + 5, pd, csi) : line_thr(sum + pd / 2, dif + 5, pd, csi);
		float hm = (t >= hatch_below) ? (t < r1 ? 1.0 : 0.0) : (sqrt(t) < max(r1, r2) ? 1.0 : 0.0);
		ink_m = mix(ink_m, hm, step(b, hatch));
	}

	// contornos lejanos: punteados por la misma trama hasta desaparecer (perspectiva aérea)
	float near_f = 1.0 - smoothstep(edge_far * 0.45, edge_far, zc);
	edge *= (b < near_f) ? 1.0 : 0.0;
	float mask = max(ink_m, edge);
	// grabado a la contra: el contorno se talla en blanco sólo si TODO alrededor (2 px) es casi negro; si un lado es
	// claro, la línea negra ya se lee contra él (una figura oscura sobre una pared clara conserva su línea)
	if (edge > 0.0 && t < white_line) {
		float tn = max(max(tone_of(texture(screen_tex, uv - vec2(o2.x, 0.0)).rgb), tone_of(texture(screen_tex, uv + vec2(o2.x, 0.0)).rgb)),
			max(tone_of(texture(screen_tex, uv - vec2(0.0, o2.y)).rgb), tone_of(texture(screen_tex, uv + vec2(0.0, o2.y)).rgb)));
		if (tn < white_line + 0.12) {
			mask = 0.0;
		}
	}
	// halo: papel del lado lejano (también apaga el contorno de ese lado: la línea queda en la figura); se puntea y
	// desaparece con la distancia de la figura, como los contornos
	if (behind && b < 1.0 - smoothstep(edge_far * 0.45, edge_far, zn)) {
		mask = 0.0;
	}

	// --- papel: grano fino + moteado lento + fibras horizontales; tinta con mordida irregular ---
	vec2 fp = floor(FRAGCOORD.xy);
	float n1 = hash12(fp) - 0.5;
	float n2 = vnoise(fp / (28.0 * sc)) - 0.5;
	float n3 = vnoise(fp * vec2(0.35, 0.04) / sc) - 0.5;
	vec3 pap = paper.rgb * (1.0 + grain * (0.55 * n1 + 1.1 * n2 + 0.6 * n3));
	vec3 ink_c = mix(ink.rgb, paper.rgb, grain * 1.4 * max(n1 + 0.5 * n2, 0.0));
	vec3 outc = mix(pap, ink_c, mask);

	if (debug_view == 1) {
		outc = vec3(to_linear(t));
	} else if (debug_view == 2) {
		outc = mix(vec3(1.0), vec3(0.0), edge);
	} else if (debug_view == 3) {
		outc = col;
	} else if (debug_view == 4) {
		// profundidad lineal codificada (medidas de silueta en los drivers: máscara = píxeles cuya z cambia)
		outc = vec3(clamp(zc / 64.0, 0.0, 1.0), fract(zc), fract(zc * 8.0));
	}
	ALBEDO = outc;
}
