// world/affordance/affordance.gdshader — v3 (GDD_v3 §6.5): SÓLO un contorno blanco alrededor de lo que está bajo el
// mouse. Dueño: UI-MUNDO. Quad a pantalla completa colgado de la cámara (affordance_post.gd), dibujado DESPUÉS del look
// (misma prioridad, sorting offset mayor). Lee el buffer normal_roughness y la profundidad (no la pantalla): dibuja con
// alfa encima.
// Códigos en la rugosidad (world/affordance/affordance.gd): 0 escenario · 1 examinable · 3 bajo el mouse. El código
// «usable permanente» (2) y el «mirar alrededor» de la v2 ya no existen: lo usable sólo cambia el cursor (mano).
// Contorno: la dilatación de la máscara 3 (8 direcciones a outline_px y a la mitad) menos la máscara: blanco #ffffff
// α 0,9, 2 px a 900 p de alto (escala con el viewport). Nada adentro (sin aclarado). Alto contraste: α 1.
// Sólo el borde de AFUERA (verificador v3): un píxel que tapa al objeto bajo el mouse (está claramente más cerca que él:
// el farol y el puesto delante de la fachada de enfrente, los tomos delante de la ventana) no se contornea; si no, al
// pasar por la fachada se marcaban el farol y el puesto, que son decoración (§6.4: sólo es interactivo lo útil).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D nr_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float occl_tol = 0.04;   // m: un vecino «bajo el mouse» más lejos que esto (o que occl_rel·z) está DETRÁS del píxel
uniform float occl_rel = 0.03;
uniform vec4 outline_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_px = 2.0;
uniform float outline_a = 0.9;
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

float lin_z(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(-v.z / v.w, 1e-4);
}

// ¿q está «bajo el mouse» y NO detrás del píxel actual (de profundidad zp)?
bool edge_from(vec2 q, float zp, mat4 ipm) {
	if (code_at(q) != 3) return false;
	return lin_z(q, ipm) <= zp + max(occl_tol, zp * occl_rel);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float sc = VIEWPORT_SIZE.y / 900.0;
	int c0 = code_at(uv);
	if (debug_view == 1) {
		ALBEDO = vec3(float(c0) / 3.0);
		ALPHA = 1.0;
	} else if (debug_view == 2) {
		ALBEDO = vec3(texture(nr_tex, uv).a);
		ALPHA = 1.0;
	} else {
		float r1 = max(1.0, outline_px * sc);
		bool near3 = false;
		if (c0 != 3) {
			mat4 ipm = INV_PROJECTION_MATRIX;
			float zp = lin_z(uv, ipm);
			for (int i = 0; i < 8; i++) {
				float ang = float(i) * 0.78539816;
				vec2 d = vec2(cos(ang), sin(ang));
				if (edge_from(uv + d * px * r1, zp, ipm) || edge_from(uv + d * px * r1 * 0.5, zp, ipm)) {
					near3 = true;
				}
			}
		}
		if (near3) {
			ALBEDO = outline_col.rgb;
			ALPHA = high_contrast ? 1.0 : outline_a;
		} else {
			ALBEDO = vec3(0.0);
			ALPHA = 0.0;
		}
	}
}
