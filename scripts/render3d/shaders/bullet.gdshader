// Projéteis (MultiMesh): sem sombreamento, cor por instância e topo claro (UV.x) para ler
// o tiro no meio de muitos.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float core_white = 0.85;

void fragment() {
	// Só as faces de cima clareiam: o tiro mantém a cor e ganha um núcleo claro
	float top = UV.x * UV.x;
	ALBEDO = mix(COLOR.rgb, vec3(1.0), top * top * core_white);
}
