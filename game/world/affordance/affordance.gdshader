// world/affordance/affordance.gdshader — realce de afordancias sobre el look (GDD_v2 §D.3). Dueño: CÁMARA + AFORDANCIAS.
// Quad a pantalla completa colgado de la cámara (affordance_post.gd), dibujado DESPUÉS del look (misma prioridad, sorting
// offset mayor). Lee sólo el buffer normal_roughness (no la pantalla): dibuja con alfa encima del resultado del look.
// Códigos en la rugosidad (world/affordance/affordance.gd): 0 escenario · 1 examinable · 2 usable · 3 bajo el mouse.
//  - bajo el mouse: borde = dilatación de la máscara 3 (8 tomas a hover_px = 2,5 px) menos la máscara, tinta α 0,8, y por
//    fuera un filete de papel (hasta halo_px = 5 px) α 0,75 para que se lea sobre fondos oscuros; interior: papel α 0,1;
//  - usable: borde exterior de 1,5 px de la máscara 2, rojo de las cintas (#8a2b22) α 0,7 (con 0,45 no se leía sobre el
//    escritorio oscuro de la aguada);
//  - mirar alrededor (reveal_all): borde donde cambia el valor entre dueños (cada examinable lleva una de 5 variantes de
//    rugosidad dentro de su código), así también se contornea lo apoyado sobre otro examinable; tinta α 0,6.
// Grosores en px a 900 p de alto (escalan con el viewport). En alto contraste: negro y rojo oscuro con α 1.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D nr_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.231, 0.141, 0.078, 1.0);
uniform vec4 paper : source_color = vec4(0.941, 0.894, 0.784, 1.0);
uniform vec4 usable_col : source_color = vec4(0.541, 0.169, 0.133, 1.0);
uniform float hover_px = 2.5;
uniform float halo_px = 5.0;
uniform float line_px = 1.5;
uniform float hover_a = 0.8;
uniform float hover_fill = 0.1;
uniform float halo_a = 0.75;
uniform float usable_a = 0.7;
uniform float reveal_a = 0.6;
uniform bool reveal_all = false;
uniform bool show_usable = true;
uniform bool high_contrast = false;
uniform int debug_view = 0;   // 1: códigos en gris (0 negro … 3 blanco)

// Godot 4.7 guarda la rugosidad tal cual en el canal A (medido con la sonda v2cam_affprobe: 1,00 · 0,96 · 0,92 se leen
// así); versiones viejas la empacaban en r·127/255 (y 1 − eso en objetos dinámicos): se aceptan las dos (nuestros
// códigos son ≥ 0,88, así que un valor > 0,6 sólo puede ser rugosidad directa).
float rough_at(vec2 uv) {
	float a = texture(nr_tex, uv).a;
	float r = a;
	if (a <= 0.5) r = a / (127.0 / 255.0);
	else if (a <= 0.6) r = (1.0 - a) / (127.0 / 255.0);
	return r;
}

int code_of(float r) {
	if (r > 0.98) return 0;
	if (r > 0.94) return 1;
	if (r > 0.90) return 2;
	return 3;
}

int code_at(vec2 uv) {
	return code_of(rough_at(uv));
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float sc = VIEWPORT_SIZE.y / 900.0;
	float r0 = rough_at(uv);
	int c0 = code_of(r0);
	if (debug_view == 1) {
		ALBEDO = vec3(float(c0) / 3.0);
		ALPHA = 1.0;
	} else if (debug_view == 2) {
		ALBEDO = vec3(texture(nr_tex, uv).a);
		ALPHA = 1.0;
	} else {
		// 8 direcciones a dos radios (fino y realce)
		float r1 = max(1.0, line_px * sc);
		float r2 = max(1.0, hover_px * sc);
		float r3 = max(2.0, halo_px * sc);
		bool near3 = false;
		bool halo3 = false;
		bool near2 = false;
		bool edge_any = false;   // un vecino con otro valor y alguno examinable: borde entre dueños
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.78539816;
			vec2 d = vec2(cos(ang), sin(ang));
			float ra = rough_at(uv + d * px * r1);
			int ca = code_of(ra);
			int cb = code_at(uv + d * px * r2);
			if (ca == 3 || cb == 3) near3 = true;
			if (code_at(uv + d * px * r3) == 3 || code_at(uv + d * px * (r2 + r3) * 0.5) == 3) halo3 = true;
			if (ca == 2) near2 = true;
			if (r0 > ra + 0.5 / 255.0 && (ca >= 1 || c0 >= 1)) edge_any = true;
		}
		vec3 ink_c = high_contrast ? vec3(0.0) : ink.rgb;
		vec3 red_c = high_contrast ? vec3(0.45, 0.0, 0.0) : usable_col.rgb;
		vec4 outc = vec4(0.0);
		if (reveal_all && edge_any) {
			outc = vec4(ink_c, high_contrast ? 1.0 : reveal_a);
		}
		if (show_usable && c0 != 2 && c0 != 3 && near2) {
			outc = vec4(red_c, high_contrast ? 1.0 : usable_a);
		}
		if (c0 == 3) {
			outc = vec4(paper.rgb, high_contrast ? 0.0 : hover_fill);
		} else if (near3) {
			outc = vec4(ink_c, high_contrast ? 1.0 : hover_a);
		} else if (halo3) {
			// filete de papel por fuera de la tinta: el contorno se lee igual sobre el escritorio oscuro y sobre la pared clara
			outc = vec4(high_contrast ? vec3(1.0) : paper.rgb, high_contrast ? 1.0 : halo_a);
		}
		ALBEDO = outc.rgb;
		ALPHA = outc.a;
	}
}
