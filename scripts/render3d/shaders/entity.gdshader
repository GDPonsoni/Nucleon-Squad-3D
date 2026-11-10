// Material único dos modelos low poly: cor por instância, clarão de acerto e transparência
// por retícula (continua opaco para o renderizador: sem ordenação nem mistura).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);  // a = força do clarão
instance uniform float glow = 0.0;  // brilho próprio (núcleo, olho, rachaduras)
instance uniform float opacity = 1.0;

void fragment() {
	if (opacity < 0.999) {
		ivec2 cell = ivec2(FRAGCOORD.xy);
		int index = (cell.x & 1) + (cell.y & 1) * 2;
		float threshold = index == 0 ? 0.2 : (index == 1 ? 0.7 : (index == 2 ? 0.95 : 0.45));
		if (opacity < threshold) {
			discard;
		}
	}
	// COLOR.r = tom da face (claro/escuro); COLOR.g = quanto puxa para o branco (cockpit)
	vec3 base = mix(tint.rgb * COLOR.r, vec3(1.0), COLOR.g);
	base = mix(base, flash.rgb, flash.a);
	ALBEDO = base;
	EMISSION = base * glow + flash.rgb * flash.a * 0.5;
	ROUGHNESS = 1.0;
}
