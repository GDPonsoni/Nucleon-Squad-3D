class_name Starfield
extends Node2D
## Fundo de estrelas em camadas (parallax) descendo: sensação de avanço da nave.
## Usa o delta escalado, então também desacelera na câmera lenta.

var star_color: Color = Params.star_color

var _layers: Array[PackedVector2Array] = []


func _ready() -> void:
	var rect: Rect2 = get_viewport_rect()
	for layer in Params.star_layer_counts.size():
		var stars := PackedVector2Array()
		for i in Params.star_layer_counts[layer]:
			stars.append(Vector2(
				randf_range(rect.position.x, rect.end.x),
				randf_range(rect.position.y, rect.end.y)))
		_layers.append(stars)


func _process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	for layer in _layers.size():
		var stars: PackedVector2Array = _layers[layer]
		var step: float = Params.star_layer_speeds[layer] * delta
		for i in stars.size():
			var star: Vector2 = stars[i]
			star.y += step
			# Saiu por baixo: volta no topo em outra coluna
			if star.y > rect.end.y:
				star.y -= rect.size.y
				star.x = randf_range(rect.position.x, rect.end.x)
			stars[i] = star
		_layers[layer] = stars
	queue_redraw()


func _draw() -> void:
	# Na visão 3D o chão rolando faz esse papel (o sorteio do _process segue igual)
	if Renderer3D.active:
		return
	for layer in _layers.size():
		var size: float = Params.star_layer_sizes[layer]
		var color: Color = star_color
		color.a = Params.star_layer_alphas[layer]
		# Camadas próximas viram rastros curtos (mais sensação de velocidade)
		var streak: float = size * Params.star_layer_streaks[layer]
		var star_size := Vector2(size, size + streak)
		for star in _layers[layer]:
			draw_rect(Rect2(star - star_size * 0.5, star_size), color)
