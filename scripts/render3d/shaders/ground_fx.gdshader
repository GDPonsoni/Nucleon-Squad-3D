// Plano de jogo: mostra a camada 2D (avisos, feixes, escudos, explosões, números) deitada
// no chão. A textura vem de um SubViewport transparente: cor já multiplicada pelo alfa.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never;

uniform sampler2D layer : source_color, filter_linear, repeat_disable;

void fragment() {
	vec4 texel = texture(layer, UV);
	ALBEDO = texel.rgb;
	ALPHA = texel.a;
}
