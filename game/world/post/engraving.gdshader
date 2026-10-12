// Grabado de la Strand (W1-POST). Contrato: docs/ARCHITECTURE.md §7.8 · GDD §14.5.
// Quad 2x2 colgado de la Camera3D (engraving_post.gd). Lee color, profundidad y normales del 3D y escribe
// mix(paper, ink, máscara): contornos (profundidad + normales, 4 vecinos) + trama Bayer 8x8 anclada a la
// esfera de la cámara (hatch=1: el umbral Bayer modula un rayado por cara, «talla»; hatch=0: Bayer puro)
// + grano de papel. Estático: no usa el tiempo (la trama no titila con la cámara quieta).
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
uniform float hatch_period = 3.0; // período del rayado en celdas
uniform float hatch_jitter = 0.2; // mezcla del umbral Bayer en el rayado (borde de buril irregular)
uniform float white_line = 0.16;  // bajo este tono los contornos se tallan en blanco (grabado a la contra)
uniform float haze = 0.0;         // bruma de Londres: aclara con la distancia
uniform vec2 haze_range = vec2(14.0, 70.0);
uniform float edge_far = 90.0;    // los contornos se puntean y desaparecen hacia esta distancia (m)
uniform vec2 anchor_rad = vec2(0.0); // giro acumulado de la cámara (yaw, pitch) en rad: ancla la trama a la esfera
uniform int debug_view = 0;       // 0 grabado · 1 tono continuo · 2 contornos · 3 color 3D sin tocar

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
	t = mix(t, 1.0, haze * smoothstep(haze_range.x, haze_range.y, zc));

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
		vec2 gd = g / cs;
		vec3 nw = mat3(INV_VIEW_MATRIX) * nc;
		bool bg = texture(depth_tex, uv).r <= 0.0;
		vec3 an = abs(nw);
		float dir = 0.0; // 0 horizontal, 1 diagonal /, 2 diagonal '\'
		if (!bg) {
			float sel_y = (an.y - max(an.x, an.z)) * 3.0 + 0.5;
			float sel_x = (an.x - an.z) * 3.0 + 0.5;
			dir = (sel_y > b) ? 0.0 : ((sel_x > b) ? 1.0 : 2.0);
		}
		float per = hatch_period;
		float s1 = dir < 0.5 ? gd.y : (dir < 1.5 ? (gd.x + gd.y) * 0.7071 : (gd.x - gd.y) * 0.7071);
		float s2 = dir < 0.5 ? (gd.x + gd.y) * 0.7071 : (dir < 1.5 ? (gd.x - gd.y) * 0.7071 : (gd.x + gd.y) * 0.7071);
		float r1 = abs(fract(s1 / per) * 2.0 - 1.0);
		float r2 = abs(fract(s2 / per + 0.5) * 2.0 - 1.0);
		r1 = mix(r1, b, hatch_jitter);
		r2 = mix(r2, b, hatch_jitter);
		float hm = (t >= hatch_below) ? (t < r1 ? 1.0 : 0.0) : (sqrt(t) < max(r1, r2) ? 1.0 : 0.0);
		ink_m = mix(ink_m, hm, step(b, hatch));
	}

	// contornos lejanos: punteados por la misma trama hasta desaparecer (perspectiva aérea)
	float near_f = 1.0 - smoothstep(edge_far * 0.45, edge_far, zc);
	edge *= (b < near_f) ? 1.0 : 0.0;
	float mask = max(ink_m, edge);
	// grabado a la contra: en zonas casi negras el contorno se talla en blanco para que se lea la forma
	if (edge > 0.0 && t < white_line) {
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
	}
	ALBEDO = outc;
}
