// Projéteis (MultiMesh): sem sombreamento, cor por instância e topo claro (UV.x) para ler
// o tiro no meio de muitos.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float core_white = 0.85;

void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0), UV.x * UV.x * core_white);
}
