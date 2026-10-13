// ui/epilogue/sight.gdshader — la vista de Lisle en 1903 (W4-EPILOGUE): lo que hay debajo del rectángulo (la hoja de
// la Strand) se ve borroso y apagado hacia los bordes; la lupa (otro nodo, encima) es lo único nítido.
// Lee la pantalla con mipmaps (hint_screen_texture + filter_linear_mipmap): blur = nivel de mip. Sin brillos.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 2.3;
uniform float veil = 0.18;          // velo cálido (papel viejo bajo la lámpara)
uniform vec4 veil_color : source_color = vec4(0.93, 0.89, 0.80, 1.0);
uniform float vignette = 0.35;      // oscurece los bordes de la hoja

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	c = mix(c, veil_color.rgb, veil);
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.32, 0.75, length(d * vec2(1.0, 0.85)));
	c *= 1.0 - vignette * v;
	COLOR = vec4(c, 1.0);
}
