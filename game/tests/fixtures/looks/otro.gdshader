// Fixture de tests (test_u_looks.gd): segundo look mínimo (papel liso).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled, ambient_light_disabled;

uniform vec4 paper : source_color = vec4(1.0);
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float grain = 0.0;
uniform int debug_view = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	ALBEDO = debug_view == 1 ? ink.rgb : paper.rgb * (1.0 - grain);
}
