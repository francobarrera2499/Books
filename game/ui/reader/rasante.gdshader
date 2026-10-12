// ui/reader/rasante.gdshader — luz rasante en 2D (D29b, GDD§14.3). Dueño: W2-READER. Contrato: ARCHITECTURE §6.4.
// Va en el RichTextLabel de un bloque con <rasante>. Sólo toca los glifos teñidos con el marcador (TextBuilder.MARKER):
// no hay tinta; el trazo es un surco (la hoja anterior del bloc) y se ve por su relieve: la pared que mira a la lámpara
// se aclara, la otra se oscurece. La lámpara está en light_pos (coordenadas de canvas, = posición del mouse), a
// light_height px sobre el papel; con la lámpara encima el relieve casi no se ve, de costado (rasante) sí, y se apaga
// más allá de `reach`. El resto del texto (y la selección) pasa intacto. El relieve se calcula sobre el campo de
// distancia MSDF del glifo (ya decodificado en COLOR por el renderer; aquí se vuelve a muestrear TEXTURE).
shader_type canvas_item;

uniform vec2 light_pos = vec2(-10000.0, -10000.0);
uniform float light_height = 28.0;
uniform float reach = 340.0;
uniform float depth = 2.2;
uniform float strength = 1.0;
uniform float ramp_px = 0.85;
uniform float px_range = 14.0;
uniform bool msdf = true;
uniform vec4 marker : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.20, 0.15, 0.09, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.985, 0.94, 1.0);

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float med3(vec3 c) {
	return max(min(c.r, c.g), min(max(c.r, c.g), c.b));
}

// (TEXTURE no se pasa como argumento: el compilador de 4.7 no acepta muestreadores integrados en funciones)
float groove(vec4 s, float half_texels) {
	float sd = msdf ? (med3(s.rgb) - 0.5) * px_range : (s.a - 0.5) * 2.0 * half_texels;
	return smoothstep(-half_texels, half_texels, sd);
}

void fragment() {
	vec4 c = COLOR;
	if (distance(c.rgb, marker.rgb) < 0.1) {
		vec2 dx = dFdx(UV);
		vec2 dy = dFdy(UV);
		float k = max(length(dx / TEXTURE_PIXEL_SIZE), 0.001);   // texels por pixel de pantalla
		float hw = ramp_px * k;
		float gl = groove(texture(TEXTURE, UV - dx), hw);
		float gr = groove(texture(TEXTURE, UV + dx), hw);
		float gu = groove(texture(TEXTURE, UV - dy), hw);
		float gd = groove(texture(TEXTURE, UV + dy), hw);
		vec2 g = vec2(gr - gl, gd - gu) * 0.5;
		// superficie z = -depth * groove  ->  normal = (depth * dG/dx, depth * dG/dy, 1)
		vec3 n = normalize(vec3(depth * g, 1.0));
		vec2 to_l = light_pos - wp;
		float dist = length(to_l);
		vec3 L = normalize(vec3(to_l, light_height));
		float shade = dot(n, L) - L.z;
		float att = clamp(1.0 - dist / reach, 0.0, 1.0);
		att = att * att * (3.0 - 2.0 * att);
		float a = shade * att * strength;
		if (a >= 0.0) {
			COLOR = vec4(lit_color.rgb, clamp(a * 0.9, 0.0, 0.7));
		} else {
			COLOR = vec4(shade_color.rgb, clamp(-a * 1.15, 0.0, 0.8));
		}
	}
}
