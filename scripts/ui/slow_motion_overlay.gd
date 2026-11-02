class_name SlowMotionOverlay
extends CanvasLayer
## Vinheta azulada nas bordas da tela durante a câmera lenta.
## A intensidade acompanha o time scale (0 no normal, 1 no lento).

const SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 tint : source_color;
uniform float intensity = 0.0;
uniform vec2 band = vec2(0.25, 0.14);  // largura da moldura em fração da meia tela (x, y)
uniform float center_alpha = 0.06;  // leve tom na tela toda

void fragment() {
	// Moldura de cantos arredondados: 0 no miolo, 1 na borda da tela
	vec2 q = max(abs(UV - vec2(0.5)) * 2.0 - (vec2(1.0) - band), vec2(0.0)) / band;
	float edge = clamp(length(q), 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * intensity * max(edge * edge, center_alpha));
}
"""

var _material: ShaderMaterial


func _ready() -> void:
	layer = 5  # acima do jogo, abaixo do HUD
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("tint", Params.slow_motion_tint)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)


func _process(_delta: float) -> void:
	var intensity: float = clampf((1.0 - Engine.time_scale) / (1.0 - Params.slow_time_scale), 0.0, 1.0)
	_material.set_shader_parameter("intensity", intensity)
