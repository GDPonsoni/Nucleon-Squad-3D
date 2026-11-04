class_name UpgradeIcon
## Ícones dos nós da evolução do núcleo, desenhados por código (placeholders).


static func draw(canvas: CanvasItem, stat: UpgradeData.Stat, center: Vector2, size: float, color: Color) -> void:
	var w: float = maxf(size * 0.09, 3.0)  # espessura das linhas
	match stat:
		UpgradeData.Stat.DAMAGE:
			# Projétil apontando para cima
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -size * 0.5), center + Vector2(size * 0.22, -size * 0.15),
				center + Vector2(size * 0.22, size * 0.45), center + Vector2(-size * 0.22, size * 0.45),
				center + Vector2(-size * 0.22, -size * 0.15),
			]), color)
		UpgradeData.Stat.FIRE_RATE:
			for i in 3:
				var x: float = (i - 1) * size * 0.3
				var y: float = absf(i - 1) * size * 0.12
				canvas.draw_rect(Rect2(center + Vector2(x - size * 0.07, -size * 0.42 + y), Vector2(size * 0.14, size * 0.7)), color)
		UpgradeData.Stat.SPECIAL:
			_star(canvas, center, size * 0.5, size * 0.18, 4, color)
		UpgradeData.Stat.BOSS_DAMAGE:
			canvas.draw_arc(center, size * 0.34, 0.0, TAU, 32, color, w)
			canvas.draw_line(center + Vector2(-size * 0.5, 0.0), center + Vector2(size * 0.5, 0.0), color, w)
			canvas.draw_line(center + Vector2(0.0, -size * 0.5), center + Vector2(0.0, size * 0.5), color, w)
		UpgradeData.Stat.MAX_HITS:
			_polygon_outline(canvas, center, size * 0.45, 6, color, w)
			_plus(canvas, center, size * 0.2, color, w)
		UpgradeData.Stat.INVULNERABILITY:
			for i in 8:
				var start: float = TAU * i / 8.0
				canvas.draw_arc(center, size * 0.4, start, start + TAU / 16.0, 6, color, w)
			canvas.draw_circle(center, size * 0.13, color)
		UpgradeData.Stat.SHIELD:
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-size * 0.38, -size * 0.4), center + Vector2(size * 0.38, -size * 0.4),
				center + Vector2(size * 0.32, size * 0.1), center + Vector2(0.0, size * 0.48),
				center + Vector2(-size * 0.32, size * 0.1),
			]), color)
		UpgradeData.Stat.MEDKIT:
			var arm: float = size * 0.42
			var thick: float = size * 0.26
			canvas.draw_rect(Rect2(center + Vector2(-arm, -thick * 0.5), Vector2(arm * 2.0, thick)), color)
			canvas.draw_rect(Rect2(center + Vector2(-thick * 0.5, -arm), Vector2(thick, arm * 2.0)), color)
		UpgradeData.Stat.COLLECT:
			# Ímã em U
			canvas.draw_arc(center + Vector2(0.0, size * 0.05), size * 0.3, 0.0, PI, 16, color, w * 1.6)
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * size * 0.3, size * 0.05), center + Vector2(side * size * 0.3, -size * 0.4), color, w * 1.6)
		UpgradeData.Stat.POWERUP:
			_diamond(canvas, center, size * 0.45, color)
			_plus(canvas, center, size * 0.2, Color.WHITE, w)
		UpgradeData.Stat.START_LEVEL:
			_diamond(canvas, center + Vector2(0.0, size * 0.12), size * 0.34, color)
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(-size * 0.25, -size * 0.3), center + Vector2(0.0, -size * 0.5),
				center + Vector2(size * 0.25, -size * 0.3),
			]), color, w)
		UpgradeData.Stat.COMPANION:
			_ship(canvas, center + Vector2(size * 0.12, 0.0), size * 0.8, color)
			_ship(canvas, center + Vector2(-size * 0.32, size * 0.18), size * 0.42, color.darkened(0.2))
		UpgradeData.Stat.OVERDRIVE:
			canvas.draw_circle(center, size * 0.2, color)
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				canvas.draw_line(center + dir * size * 0.3, center + dir * size * 0.5, color, w)


static func _star(canvas: CanvasItem, center: Vector2, outer: float, inner: float, points: int, color: Color) -> void:
	var shape := PackedVector2Array()
	for i in points * 2:
		var radius: float = outer if i % 2 == 0 else inner
		shape.append(center + Vector2.from_angle(-PI * 0.5 + PI * i / points) * radius)
	canvas.draw_colored_polygon(shape, color)


static func _polygon_outline(canvas: CanvasItem, center: Vector2, radius: float, sides: int, color: Color, width: float) -> void:
	var shape := PackedVector2Array()
	for i in sides + 1:
		shape.append(center + Vector2.from_angle(-PI * 0.5 + TAU * i / sides) * radius)
	canvas.draw_polyline(shape, color, width)


static func _plus(canvas: CanvasItem, center: Vector2, arm: float, color: Color, width: float) -> void:
	canvas.draw_line(center + Vector2(-arm, 0.0), center + Vector2(arm, 0.0), color, width)
	canvas.draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, arm), color, width)


static func _diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
	]), color)


static func _ship(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -size * 0.5), center + Vector2(size * 0.32, size * 0.5),
		center + Vector2(0.0, size * 0.3), center + Vector2(-size * 0.32, size * 0.5),
	]), color)
