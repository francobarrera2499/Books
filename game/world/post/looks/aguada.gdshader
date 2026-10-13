// Aguada sepia (look 'aguada' del registro world/post/looks.gd, EL POR DEFECTO; parámetros: looks/aguada.json). Contrato:
// ARCHITECTURE §7.8. Como los originales de Sidney Paget para la Strand (dibujos a la aguada). Pasos:
//  1. abstracción: cada cara se vuelve un lavado (dos anillos de 6 tomas con su mip, pesos por profundidad y normal: no se
//     mezclan objetos ni caras) -> la textura chica no parte el lavado en islas; `detail` la insinúa encima, tenue;
//  2. el lavado se toma con un leve desfase orgánico (`wash_shift`): no calza exacto con la pluma, como a mano;
//  3. tono -> oscuridad bajo `paper_white` (blancos de papel reservados), terrazas suaves (`levels`, `posterize`) con
//     borde acumulado del lado oscuro de cada terraza (`pool`) y de cada contraste grande (`pool_big`: borde de la zona);
//  4. carga despareja (`mottle`, `bloom`) y granulación en los valles del papel (menos en lo oscuro);
//  5. hilo de papel seco del lado lejano de cada silueta (`lift`): separa figuras oscuras superpuestas de noche; de cerca
//     también tras escalones chicos (`lift_fine`: un cuaderno sobre la mesa del mismo color que la mesa);
//  6. pluma en siluetas (salto de profundidad no plano, lado cercano) y pliegues fuertes, con presión variable; de cerca,
//     pluma fina en escalones chicos (`fine*`: lo que hay sobre una mesa, lomos, marcos) sin tocar pisos ni paredes;
//  7. veladura: oscuridad perceptual -> carga D (la luminancia sRGB resultante es mix(papel, tinta, d)) y color =
//     papel · (tinta/papel)^D: los medios tonos tiran a siena y los oscuros a sepia profunda; papel de acuarela en relieve;
//  8. encuadre: viñeta de gas (`vignette`) o lámina viñeteada que se aclara al borde (`fade_edge`, de día).
// Sin rayado ni trama regular. Estático: no usa el tiempo. El papel está fijo a la pantalla (es la hoja); el ruido de los
// lavados se ancla a la esfera de la cámara en px enteros (anchor_rad, como la trama del grabado): con cámara quieta los
// cuadros son idénticos byte a byte. Nunca marca un objeto por ser pista: sólo color, profundidad y normales del 3D.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D nr_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// --- contrato §7.8 ---
uniform vec4 paper : source_color = vec4(0.941, 0.894, 0.784, 1.0); // papel de la franja (looks/aguada.json)
uniform vec4 ink : source_color = vec4(0.231, 0.141, 0.078, 1.0);   // sepia a plena carga (el lavado más oscuro)
uniform float grain = 0.5;          // textura del papel de acuarela (0 = liso)
// --- tono ---
uniform float exposure = 1.3;       // multiplica la luminancia lineal
uniform float contrast = 1.25;      // pivote 0,5 (en sRGB)
uniform float gamma = 0.9;          // < 1 aclara los medios tonos
uniform float paper_white = 0.94;   // tono (0..1) desde el cual el papel queda reservado: sin lavado
uniform float density_gamma = 0.85; // curva oscuridad -> carga de pigmento
uniform float max_density = 1.0;    // carga del lavado más oscuro (1 = la tinta)
// --- lavados ---
uniform float wash_shift = 1.25;    // px (a 900 p): el lavado no calza exacto con la pluma (desfase orgánico, anclado)
uniform float soften = 4.0;         // px (a 900 p) del suavizado que respeta la profundidad: simplifica el detalle chico
uniform float soften_far = 2.0;     // multiplicador del suavizado a lo lejos
uniform float detail = 0.3;         // textura de la escena que se insinúa sobre el lavado (ladrillo, papel pintado, tablas)
uniform vec2 soften_range = vec2(6.0, 40.0);
uniform float levels = 4.0;         // capas de lavado
uniform float posterize = 0.35;     // 0 = modelado continuo · 1 = capas planas
uniform float band_soft = 0.3;      // ancho del borde de una capa (en unidades de capa)
uniform float wobble = 0.0;         // irregularidad de los bordes de las capas (en unidades de capa)
uniform float pool = 0.3;           // pigmento acumulado en el borde de cada capa (fracción de una capa)
uniform float pool_px = 3.0;        // ancho del borde acumulado (px a 900 p)
uniform float pool_big = 1.0;       // oscurecimiento del lado oscuro de un contraste grande (figura sobre pared clara)
uniform float pool_lod = 3.0;       // mip del entorno para ese contraste
uniform float mottle = 0.09;        // lavado desparejo (baja frecuencia: el agua corre y deja más pigmento en partes)
uniform float bloom = 0.03;         // flores del lavado (escala media)
uniform float granulation = 0.12;   // el pigmento se asienta en los valles del papel
uniform float chroma = 0.0;         // color de la escena que se cuela en el lavado (gas, sol dorado)
// --- pluma ---
uniform float line = 0.9;           // opacidad de la línea de pluma
uniform float line_density = 1.05;  // carga de la línea (1 = la tinta)
uniform float line_depth = 0.14;    // salto relativo de profundidad que cuenta como silueta
uniform float line_abs = 0.12;      // y salto absoluto mínimo (m)
uniform float line_normal = 0.7;    // pliegue: 1 - cos(ángulo) entre normales vecinas (0,7 ≈ 73°)
uniform float crease = 0.45;        // opacidad relativa de los pliegues
uniform float line_far = 40.0;      // la línea se adelgaza y desaparece hacia esta distancia (m)
uniform float line_break = 0.35;    // pluma viva: presión variable y cortes
// pluma fina de cerca: escalones chicos de profundidad sobre una superficie (lo que hay sobre una mesa, lomos en un
// estante, un marco en la pared). Sólo donde la profundidad deja de ser plana (laplaciano de 1/z): un piso o una pared
// vistos de costado no dibujan nada. Igual para todo objeto: nunca distingue pistas.
uniform float fine = 0.85;          // opacidad relativa de la pluma fina
uniform float fine_rel = 0.012;     // salto relativo de profundidad mínimo
uniform float fine_abs = 0.006;     // y absoluto (m)
uniform float fine_far = 7.0;       // la pluma fina se apaga hacia esta distancia (m)
// --- separación de figuras: hilo de papel seco del lado lejano de una silueta ---
uniform float lift = 0.4;           // cuánto lavado se levanta (0..1)
uniform float lift_px = 2.0;        // ancho (px a 900 p)
uniform float lift_rel = 0.08;      // salto relativo de profundidad que cuenta
uniform float lift_fine = 0.55;     // ídem tras escalones chicos de cerca (umbrales de la pluma fina): objeto / mesa
// --- atmósfera y encuadre ---
uniform float haze = 0.0;           // bruma: lo lejano se aclara hacia el papel
uniform vec2 haze_range = vec2(14.0, 70.0);
uniform float vignette = 0.0;       // noche de gas: los bordes del cuadro se cargan de lavado
uniform float fade_edge = 0.0;      // el dibujo se desvanece en el papel en el borde del cuadro (ancho relativo al alto)
uniform float fade_amount = 0.6;    // cuánto lavado se pierde en el borde mismo
uniform vec2 anchor_rad = vec2(0.0); // giro acumulado de la cámara (yaw, pitch): ancla el ruido de los lavados
uniform int debug_view = 0;         // 0 aguada · 1 tono · 2 línea · 3 color 3D · 4 profundidad

float to_srgb(float x) {
	x = clamp(x, 0.0, 1.0);
	return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}

float to_linear(float x) {
	return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

float fbm2(vec2 p) {
	return 0.65 * vnoise(p) + 0.35 * vnoise(p * 2.31 + 17.3);
}

// celdas (papel prensado en frío): distancia al punto más cercano
float cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash22(i + o) - f;
			d = min(d, dot(r, r));
		}
	}
	return sqrt(d);
}

// relieve del papel de acuarela (0..1, 1 = cresta): cráteres de celdas + ondulación + fibra fina
float paper_h(vec2 p) {
	float c = 1.0 - cells(p / 5.5);
	float w = vnoise(p / 13.0);
	float f = vnoise(p * vec2(0.9, 0.35));
	return clamp(0.55 * c + 0.3 * w + 0.15 * f, 0.0, 1.0);
}

float lin_z(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(-v.z / v.w, 1e-4);
}

vec3 nrm(vec2 uv) {
	return texture(nr_tex, uv).xyz * 2.0 - 1.0;
}

// GDD_v2 §D.4: código de afordancia en el canal A (world/affordance/affordance.gd): 0 escenario · 1 examinable ·
// 2 usable · 3 bajo el mouse. Lo examinable (todo, por igual) se lava menos y lleva más pluma que el escenario.
float aff_code(vec2 uv) {
	float a = texture(nr_tex, uv).a;
	if (a < 0.02) return 0.0;
	float r = a;
	if (a <= 0.5) r = a / (127.0 / 255.0);
	else if (a <= 0.6) r = (1.0 - a) / (127.0 / 255.0);
	return r > 0.98 ? 0.0 : (r > 0.94 ? 1.0 : (r > 0.90 ? 2.0 : 3.0));
}
uniform float obj_soften = 0.5;     // §D.4: suavizado × esto sobre lo examinable
uniform float obj_line = 1.3;       // §D.4: pluma × esto sobre lo examinable

// d perceptual (0 papel .. 1 tinta) -> carga D del modelo de veladura (L = Lp · (Li/Lp)^D)
float density_of(float d, float lp, float li) {
	float s = mix(to_srgb(lp), to_srgb(li), clamp(d, 0.0, 1.0));
	return log(max(to_linear(s), 1e-5) / lp) / log(li / lp);
}

float tone(vec3 c) {
	float t = to_srgb(dot(c, vec3(0.2126, 0.7152, 0.0722)) * exposure);
	t = clamp((t - 0.5) * contrast + 0.5, 0.0, 1.0);
	return pow(t, gamma);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float sc = max(1.0, floor(VIEWPORT_SIZE.y / 900.0 + 0.5));
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 o = sc * px;
	mat4 ipm = INV_PROJECTION_MATRIX;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;

	// coordenadas: p = papel (fijo a la pantalla, px a 900 p) · pw = lavado (anclado al giro de la cámara)
	float kk = 0.5 * VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]);
	vec2 off = floor(vec2(anchor_rad.x, -anchor_rad.y) * kk + 0.5); // px enteros: la deriva mínima del ángulo no mueve nada
	vec2 p = FRAGCOORD.xy / sc;
	vec2 pw = (FRAGCOORD.xy + off) / sc;

	// --- profundidad: centro y 4 vecinos (la pluma sigue la geometría exacta) ---
	float zc = lin_z(uv, ipm);
	float zl = lin_z(uv - vec2(o.x, 0.0), ipm);
	float zr = lin_z(uv + vec2(o.x, 0.0), ipm);
	float zu = lin_z(uv - vec2(0.0, o.y), ipm);
	float zd = lin_z(uv + vec2(0.0, o.y), ipm);

	// --- el lavado se toma con un leve desfase orgánico (no calza exacto con la pluma, como a mano) ---
	vec2 wv = vec2(vnoise(pw / 41.0), vnoise(pw / 41.0 + 53.1)) - 0.5;
	wv += 0.45 * (vec2(vnoise(pw / 11.0 + 9.0), vnoise(pw / 11.0 + 71.0)) - 0.5);
	vec2 uvw = uv + wv * 2.0 * wash_shift * o;
	float zw = lin_z(uvw, ipm);

	// --- abstracción: cada cara se vuelve un lavado (dos anillos de 6 tomas con su mip; pesos por profundidad y normal:
	// no se mezclan objetos ni caras distintas) -> la textura chica (ladrillo, papel pintado) no parte el lavado en islas ---
	float far_f = smoothstep(soften_range.x, soften_range.y, zw);
	float r = soften * sc * mix(1.0, soften_far, far_f) * (aff_code(uvw) >= 1.0 ? obj_soften : 1.0);
	vec3 nw0 = nrm(uvw);
	vec3 acc = textureLod(screen_tex, uvw, log2(max(r, 1.0)) - 1.0).rgb;
	float wsum = 1.0;
	float zs = zw * 0.035 + 0.03;
	for (int ring = 0; ring < 2; ring++) {
		float rr = r * (ring == 0 ? 1.0 : 2.4);
		float lod = log2(max(rr, 1.0)) - 0.3;
		for (int i = 0; i < 6; i++) {
			float a = float(i) * 1.047198 + (ring == 0 ? 0.2618 : 0.7854);
			vec2 du = vec2(cos(a), sin(a)) * rr * px;
			float zi = lin_z(uvw + du, ipm);
			float dz = (zi - zw) / zs;
			float w = exp(-dz * dz) * smoothstep(0.75, 0.97, dot(nrm(uvw + du), nw0));
			acc += textureLod(screen_tex, uvw + du, lod).rgb * w;
			wsum += w;
		}
	}
	vec3 cs = acc / wsum;
	float t = tone(cs);
	float t_det = tone(textureLod(screen_tex, uvw, 0.0).rgb) - t;
	float t_big = tone(textureLod(screen_tex, uvw, pool_lod + log2(sc)).rgb);

	// bruma: lo lejano hacia el papel
	float hz = haze * smoothstep(haze_range.x, haze_range.y, zw);
	t = mix(t, 1.0, hz);
	t_big = mix(t_big, 1.0, hz);

	// --- capas de lavado ---
	float dk = clamp((paper_white - t) / max(paper_white, 1e-3), 0.0, 1.0); // oscuridad bajo el blanco reservado
	float nb = fbm2(pw / 30.0) - 0.5;
	float nf = vnoise(pw / 7.0) - 0.5;
	float x = dk * levels + wobble * (nb + 0.25 * nf);
	x = (dk > 0.0) ? clamp(x, 0.0, levels) : 0.0;
	// umbrales a medio camino (k + 0,5): el papel limpio, el negro macizo y los tonos enteros quedan estables (sin islas)
	float q = x + 0.5;
	float fl = floor(q);
	float fr = q - fl;
	float gx = max(fwidth(x), 1e-4);
	// borde de capa nítido con antialias (1,2 px) o blando (band_soft), lo que sea más ancho
	float bw = max(band_soft, min(gx * 1.2, 0.5));
	float stair = fl + smoothstep(1.0 - bw, 1.0, fr);
	float dstep = stair / levels;
	float d = mix(dk, dstep, posterize);
	d -= detail * t_det * (1.0 - far_f) * step(1e-4, dk + 0.2);
	// borde acumulado: del lado oscuro de cada umbral de capa, a pool_px en pantalla (distancia = fr / |grad x|)
	float dist_px = fr / gx / sc;
	float rim = (fl >= 1.0) ? exp(-dist_px / max(pool_px, 0.1)) * smoothstep(0.0, 1.5, dist_px + 0.5) : 0.0;
	d += pool * rim / levels;
	// contraste grande (figura oscura sobre pared clara): el lado oscuro se carga hacia el borde
	float dk_big = clamp((paper_white - t_big) / max(paper_white, 1e-3), 0.0, 1.0);
	d += pool_big * max(0.0, dk - dk_big) * step(1e-4, dk);
	// el agua corre: carga despareja a baja y media frecuencia + granulación leve en los valles del papel
	float h = paper_h(p);
	float flow = fbm2(pw / 120.0 + 31.0) - 0.5;
	float bl = smoothstep(0.25, 0.75, fbm2(pw / 34.0 + 3.7)) - 0.5;
	d *= 1.0 + (mottle * 2.0 * flow + bloom * 2.0 * bl) * (1.0 - 0.75 * smoothstep(0.4, 0.85, d));
	d *= 1.0 + granulation * (0.5 - h) * 2.0 * smoothstep(0.0, 0.2, d) * (1.0 - 0.6 * smoothstep(0.55, 0.95, d));

	// --- separación: hilo de papel seco del lado lejano de una silueta (algo bastante más cerca a 1..lift_px) ---
	// De cerca, también tras escalones chicos (un cuaderno sobre la mesa): `lift_fine`, con los umbrales de la pluma fina y
	// sólo si el vecino NO sigue el plano de este píxel (1/z de los dos lados no es lineal): un piso de costado no se aclara.
	float lifted = 0.0;
	float lifted_f = 0.0;
	if (lift > 0.0 || lift_fine > 0.0) {
		float lp = lift_px * sc;
		for (int i = 0; i < 4; i++) {
			vec2 dir = (i == 0) ? vec2(1.0, 0.0) : ((i == 1) ? vec2(-1.0, 0.0) : ((i == 2) ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
			for (int k = 1; k <= 2; k++) {
				float dd = float(k) * lp / 2.0;
				float zn = lin_z(uvw + dir * dd * px, ipm);
				if (zw - zn > max(lift_rel * zn, 0.1)) {
					lifted = max(lifted, k == 1 ? 1.0 : 0.6);
				} else if (lift_fine > 0.0 && zw - zn > max(fine_rel * zn, fine_abs)) {
					float zo = lin_z(uvw - dir * dd * px, ipm);
					if (abs(1.0 / zn + 1.0 / zo - 2.0 / zw) * zw > 0.004) {
						lifted_f = max(lifted_f, k == 1 ? 1.0 : 0.6);
					}
				}
			}
		}
		lifted *= 1.0 - smoothstep(line_far * 0.5, line_far, zw);
		lifted_f *= 1.0 - smoothstep(fine_far * 0.5, fine_far, zw);
	}
	d *= 1.0 - max(lift * lifted, lift_fine * lifted_f);

	// --- encuadre: viñeta de gas (carga) y desvanecido al papel en los bordes ---
	vec2 vc = (uv - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	if (vignette > 0.0) {
		float vg = smoothstep(0.35, 1.0, length(vc) / 0.95);
		d = d + vignette * vg * (1.0 - d * 0.5) * (0.85 + 0.3 * nb);
	}
	if (fade_edge > 0.0) {
		// lámina viñeteada de la Strand: el lavado se aclara hacia el borde (blando, sin marco roto; más en las esquinas)
		vec2 e2 = min(uv, 1.0 - uv) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		vec2 f2 = smoothstep(vec2(0.0), vec2(fade_edge), e2 + 0.12 * fade_edge * nb);
		d *= mix(1.0 - fade_amount, 1.0, f2.x * f2.y);
	}
	d = clamp(d, 0.0, 1.0);
	// oscuridad perceptual -> carga de pigmento: la luminancia (sRGB) del resultado es mix(papel, tinta, d^density_gamma)
	vec3 tr = clamp(ink.rgb / max(paper.rgb, vec3(0.02)), vec3(0.002), vec3(1.0));
	float lp_ = max(dot(paper.rgb, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
	float li_ = max(dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
	float D = density_of(pow(d, density_gamma) * max_density, lp_, li_);

	// --- pluma: silueta (este píxel es el lado cercano de un salto de profundidad no plano) y pliegues fuertes ---
	float wc = 1.0 / zc;
	float lap = abs(1.0 / zl + 1.0 / zr - 2.0 * wc) + abs(1.0 / zu + 1.0 / zd - 2.0 * wc);
	float jump = max(max(zl, zr), max(zu, zd)) - zc;
	float sil = (lap * zc > 0.06 && jump > max(line_depth * zc, line_abs)) ? 1.0 : 0.0;
	float sil_f = (lap * zc > 0.004 && jump > max(fine_rel * zc, fine_abs)) ? fine * (1.0 - smoothstep(fine_far * 0.5, fine_far, zc)) : 0.0;
	// 2.º píxel (trazo de ~1,5 px, antialias)
	float jump2 = max(max(lin_z(uv - 2.0 * vec2(o.x, 0.0), ipm), lin_z(uv + 2.0 * vec2(o.x, 0.0), ipm)),
		max(lin_z(uv - 2.0 * vec2(0.0, o.y), ipm), lin_z(uv + 2.0 * vec2(0.0, o.y), ipm))) - zc;
	float sil2 = (jump2 > max(line_depth * 1.6 * zc, line_abs * 1.6) && sil < 0.5) ? 0.4 : 0.0;
	vec3 nc = nrm(uv);
	float en = 0.0;
	en = max(en, 1.0 - dot(nc, nrm(uv - vec2(o.x, 0.0))));
	en = max(en, 1.0 - dot(nc, nrm(uv + vec2(o.x, 0.0))));
	en = max(en, 1.0 - dot(nc, nrm(uv - vec2(0.0, o.y))));
	en = max(en, 1.0 - dot(nc, nrm(uv + vec2(0.0, o.y))));
	float cr = smoothstep(line_normal, line_normal + 0.25, en) * crease;
	float near_l = 1.0 - smoothstep(line_far * 0.35, line_far, zc);
	float press = 1.0 - line_break * smoothstep(0.25, 0.8, fbm2(pw / 48.0 + 7.0));
	float ln = max(max(max(sil, sil2), sil_f), cr * smoothstep(line_far * 0.6, line_far * 0.2, zc)) * near_l * press * line;
	ln *= 1.0 - 0.5 * hz;
	ln = min(ln * (aff_code(uv) >= 1.0 ? obj_line : 1.0), 1.0);

	// --- color: veladuras de sepia sobre el papel (transmitancia multiplicativa) ---
	float shade = (paper_h(p + vec2(0.7, 0.7)) - h);
	vec3 pap = paper.rgb * (1.0 + grain * (0.5 * shade - 0.06 * (h - 0.5) + 0.05 * (vnoise(p / 40.0) - 0.5)));
	vec3 outc = pap * pow(tr, vec3(D));
	if (chroma > 0.0) {
		float l = max(dot(cs, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
		vec3 hue = clamp(cs / l, vec3(0.5), vec3(1.6));
		outc *= mix(vec3(1.0), hue, chroma);
	}
	vec3 line_c = pap * pow(tr, vec3(max(D + 0.3, line_density)));
	outc = mix(outc, line_c, clamp(ln, 0.0, 1.0));

	if (debug_view == 1) {
		outc = vec3(to_linear(1.0 - D));
	} else if (debug_view == 2) {
		outc = vec3(1.0 - clamp(ln, 0.0, 1.0));
	} else if (debug_view == 3) {
		outc = col;
	} else if (debug_view == 4) {
		outc = vec3(clamp(zc / 64.0, 0.0, 1.0), fract(zc), fract(zc * 8.0));
	}
	ALBEDO = outc;
}
