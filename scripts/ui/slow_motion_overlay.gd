class_name SlowMotionOverlay
extends CanvasLayer
## Vinheta azulada nas bordas da tela durante a câmera lenta.
## A intensidade acompanha o time scale (0 no normal, 1 no lento).
## Acima da barra de troca, a barra de energia da câmera lenta (some quando está cheia).

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

var time_controller: TimeController  # dono da energia (null = sem barra)
var bar_bottom: float = -1.0  # distância da base da tela ao centro da barra (< 0 = acima da barra de troca)

var _material: ShaderMaterial
var _bar: Control
var _bar_alpha: float = 0.0
var _last_usec: int = 0


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

	_bar = Control.new()
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var intensity: float = clampf((1.0 - Engine.time_scale) / (1.0 - Params.slow_time_scale), 0.0, 1.0)
	if SaveGame.setting("reduced_effects"):
		intensity *= Params.reduced_slowmo_intensity
	_material.set_shader_parameter("intensity", intensity)
	# A barra aparece enquanto a energia não está cheia (tempo real: não acompanha a lenta)
	var now: int = Time.get_ticks_usec()
	var real_delta: float = (now - _last_usec) / 1_000_000.0
	_last_usec = now
	var wanted: bool = time_controller != null and (time_controller.energy < 1.0 or time_controller.is_voluntary_slow())
	_bar_alpha = move_toward(_bar_alpha, 1.0 if wanted else 0.0, real_delta / Params.slowmo_bar_fade_seconds)
	_bar.queue_redraw()


func _draw_bar() -> void:
	if time_controller == null or _bar_alpha <= 0.0:
		return
	var size: Vector2 = Params.slowmo_bar_size
	var screen: Vector2 = _bar.size
	var from_bottom: float = bar_bottom if bar_bottom >= 0.0 else Params.switch_strip_bottom + Params.slowmo_bar_gap
	var center := Vector2(screen.x * 0.5, screen.y - from_bottom)
	var rect := Rect2(center - size * 0.5, size)
	var low: bool = time_controller.energy < Params.slowmo_min_energy
	var color: Color = Params.slowmo_bar_low_color if low else Params.slowmo_bar_color
	_bar.draw_rect(rect.grow(3.0), Color(Params.slowmo_bar_bg_color, Params.slowmo_bar_bg_color.a * _bar_alpha))
	var fill := Rect2(rect.position, Vector2(size.x * time_controller.energy, size.y))
	_bar.draw_rect(fill, Color(color, _bar_alpha))
	# Marca do mínimo para ativar
	var mark_x: float = rect.position.x + size.x * Params.slowmo_min_energy
	_bar.draw_line(Vector2(mark_x, rect.position.y - 4.0), Vector2(mark_x, rect.end.y + 4.0), Color(1.0, 1.0, 1.0, 0.5 * _bar_alpha), 2.0)
