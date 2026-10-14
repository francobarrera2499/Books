// ui/reader/backdrop.gdshader — fondo del lector v3 (GDD_v3 §6.7). Dueño: LECTOR.
// La pieza 3D (y lo que haya debajo de la capa 30) se ve detrás del papel desenfocada y oscurecida: lee la pantalla con
// mipmaps (hint_screen_texture + filter_linear_mipmap) a nivel blur_lod y suaviza con 8 muestras alrededor (sin el
// cuadriculado del mip). dim = cuánto se oscurece (0,25 = 25 %); viñeta leve hacia los bordes. Sin brillos.
// Plan B (GDD_v3 §8.8) si en alguna GPU la textura de pantalla sale negra: DocumentReader.blur_mode = "captura".
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D capture_tex : repeat_disable, filter_linear_mipmap;
uniform bool use_capture = false;
uniform vec2 cap_texel = vec2(0.004, 0.007);   // 1 / tamaño de la captura (plan B)
uniform float blur_lod = 2.5;
uniform float dim = 0.25;
uniform float vignette = 0.22;
uniform vec4 warm : source_color = vec4(0.16, 0.12, 0.08, 1.0);
uniform float warm_mix = 0.08;

vec3 tap(vec2 uv) {
	if (use_capture) {
		return textureLod(capture_tex, uv, blur_lod).rgb;
	}
	return textureLod(screen_tex, uv, blur_lod).rgb;
}

void fragment() {
	vec2 suv = use_capture ? UV : SCREEN_UV;
	vec2 px = use_capture ? cap_texel * 1.3 : SCREEN_PIXEL_SIZE * exp2(blur_lod);
	vec3 c = tap(suv) * 0.28;
	c += tap(suv + vec2(px.x, 0.0) * 1.2) * 0.09;
	c += tap(suv - vec2(px.x, 0.0) * 1.2) * 0.09;
	c += tap(suv + vec2(0.0, px.y) * 1.2) * 0.09;
	c += tap(suv - vec2(0.0, px.y) * 1.2) * 0.09;
	c += tap(suv + px * 0.9) * 0.09;
	c += tap(suv - px * 0.9) * 0.09;
	c += tap(suv + vec2(px.x, -px.y) * 0.9) * 0.09;
	c += tap(suv + vec2(-px.x, px.y) * 0.9) * 0.09;
	c = mix(c, warm.rgb, warm_mix);
	c *= 1.0 - dim;
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.9)));
	c *= 1.0 - vignette * v;
	COLOR = vec4(c, 1.0);
}
