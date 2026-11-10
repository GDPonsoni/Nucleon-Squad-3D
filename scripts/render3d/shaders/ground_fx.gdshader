// Plano de jogo: mostra a camada 2D (avisos, feixes, escudos, explosões, números) deitada
// no chão. A textura vem de um SubViewport transparente: cor em sRGB, já multiplicada pelo
// alfa. Converter para linear com a cor ainda multiplicada escurece tudo que é translúcido
// (avisos, brilhos), então a cor é separada do alfa antes da conversão.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never;

uniform sampler2D layer : filter_linear, repeat_disable;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec4 texel = texture(layer, UV);
	vec3 color = texel.a > 0.0001 ? clamp(texel.rgb / texel.a, 0.0, 1.0) : vec3(0.0);
	ALBEDO = srgb_to_linear(color) * texel.a;
	ALPHA = texel.a;
}
