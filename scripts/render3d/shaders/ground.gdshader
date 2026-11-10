// Chão distante: grade e estrelas rolando na direção da câmera (sensação de avanço).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.04, 0.04, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(0.3, 0.4, 0.7, 1.0);
uniform vec4 star_color : source_color = vec4(0.8, 0.85, 1.0, 1.0);
uniform float cell = 2.0;  // tamanho da célula da grade (unidades do mundo)
uniform float scroll = 0.0;  // quanto o chão já andou (unidades do mundo)
uniform float line_strength = 0.35;
uniform float star_density = 0.5;  // células de estrela por unidade
uniform float fade_start = 8.0;
uniform float fade_end = 40.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_pos.x, world_pos.z - scroll);
	vec2 g = p / cell;
	vec2 dist = abs(fract(g - 0.5) - 0.5) / max(fwidth(g), vec2(0.0001));
	float line = 1.0 - min(min(dist.x, dist.y), 1.0);
	float fade = 1.0 - smoothstep(fade_start, fade_end, length(world_pos - CAMERA_POSITION_WORLD));
	// Uma estrela por célula, em posição e brilho sorteados pelo índice da célula
	vec2 s = p * star_density;
	vec2 id = floor(s);
	vec2 f = fract(s) - 0.5;
	vec2 jitter = vec2(hash(id), hash(id + 17.0)) - 0.5;
	float size = 0.03 + 0.05 * hash(id + 5.0);
	float star = smoothstep(size, size * 0.4, length(f - jitter * 0.7)) * step(0.45, hash(id + 9.0));
	vec3 color = base_color.rgb + line_color.rgb * line * line_strength * fade + star_color.rgb * star * fade;
	ALBEDO = color;
}
