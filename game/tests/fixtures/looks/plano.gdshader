// Fixture de tests (test_u_looks.gd): look mínimo con la plantilla del quad de §7.8 (no es un look del juego: vive
// fuera de world/post/looks/ y sólo se descubre con Looks.reload("res://tests/fixtures/looks")). Tono continuo
// mix(paper, ink, 1 - tono) con exposición, banda de tonos y pasos.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 paper : source_color = vec4(1.0);
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float grain = 0.0;
uniform float exposure = 1.0;
uniform vec2 tone_range = vec2(0.0, 1.0);
uniform int steps = 0;
uniform float bias = 0.0;           // sin valor en el JSON: queda el default del shader
uniform int debug_view = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float t = clamp(dot(col, vec3(0.2126, 0.7152, 0.0722)) * exposure, 0.0, 1.0);
	t = smoothstep(tone_range.x, tone_range.y, t);
	if (steps > 1) {
		t = floor(t * float(steps)) / float(steps - 1);
	}
	float n = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	vec3 outc = mix(ink.rgb, paper.rgb, clamp(t + bias + grain * n, 0.0, 1.0));
	if (debug_view == 3) {
		outc = col;
	}
	ALBEDO = outc;
}
