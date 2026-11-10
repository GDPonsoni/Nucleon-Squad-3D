class_name CameraRig
extends RefCounted
## Matemática da câmera 3D, sem nós (testável em headless).
## A simulação continua 2D, em pixels. Um ponto 2D (x, y) vira o ponto do mundo
## (x·S, altura, y·S), com S = Params.world_scale_3d. y maior = mais perto da câmera.
## A câmera fica atrás da nave, olhando para a frente (-Z) e para baixo (pitch).

var world_scale: float = 0.01
var pitch: float = deg_to_rad(70.0)  # abaixo da horizontal
var fov: float = deg_to_rad(38.0)  # vertical
var view_size := Vector2(1080.0, 1920.0)  # tela (px)

## Ponto do chão (2D, px) para onde a câmera olha sem deslocamento, e a distância até ele.
var target := Vector2.ZERO
var distance: float = 10.0


## Configura a partir dos Params (ângulos em graus).
func configure(view: Vector2) -> void:
	world_scale = Params.world_scale_3d
	pitch = deg_to_rad(clampf(Params.camera_pitch_deg, 10.0, 89.5))
	fov = deg_to_rad(clampf(Params.camera_fov_deg, 5.0, 120.0))
	view_size = view


## Enquadra: o retângulo jogável (2D, px), crescido de margin, cabe inteiro em screen_area
## (px de tela), encostado na base dela. Com perspectiva a borda de baixo é a mais larga:
## é ela que define o enquadramento (ou a altura, em telas baixas).
func fit(playable: Rect2, screen_area: Rect2, margin: float) -> void:
	var rect: Rect2 = playable.grow(margin)
	target.x = rect.get_center().x
	var low: float = 0.01
	var high: float = 1000.0
	for i in 48:
		var mid: float = (low + high) * 0.5
		distance = mid
		_pin_bottom(rect, screen_area)
		if _fits(rect, screen_area):
			high = mid
		else:
			low = mid
	distance = high
	_pin_bottom(rect, screen_area)


## Ajusta target.y para a borda de baixo de rect cair na base de screen_area.
func _pin_bottom(rect: Rect2, screen_area: Rect2) -> void:
	var span: float = distance / world_scale * 4.0 + rect.size.y
	var low: float = rect.end.y - span
	var high: float = rect.end.y + span
	for i in 48:
		target.y = (low + high) * 0.5
		var edge := Vector2(target.x, rect.end.y)
		# Olhar mais para trás (target.y maior) sobe a borda na tela; borda atrás da câmera
		# conta como "baixa demais"
		if not is_in_front(edge) or project(edge).y > screen_area.end.y:
			low = target.y
		else:
			high = target.y
	target.y = (low + high) * 0.5


func _fits(rect: Rect2, screen_area: Rect2) -> bool:
	var tolerance: float = 0.5
	if not is_in_front(Vector2(target.x, rect.position.y)) or not is_in_front(Vector2(target.x, rect.end.y)):
		return false
	var bottom_left: Vector2 = project(Vector2(rect.position.x, rect.end.y))
	var top_left: Vector2 = project(rect.position)
	return bottom_left.x >= screen_area.position.x - tolerance and top_left.x >= screen_area.position.x - tolerance \
			and top_left.y >= screen_area.position.y - tolerance


## Ponto 2D (px) -> mundo 3D.
func to_world(pos: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(pos.x * world_scale, height, pos.y * world_scale)


func _forward() -> Vector3:
	return Vector3(0.0, -sin(pitch), -cos(pitch))


func _up() -> Vector3:
	return Vector3(0.0, cos(pitch), -sin(pitch))


## Transform da câmera, com o deslocamento do seguimento (px no chão).
func camera_transform(offset: Vector2 = Vector2.ZERO) -> Transform3D:
	var origin: Vector3 = to_world(target + offset) - _forward() * distance
	return Transform3D(Basis(Vector3.RIGHT, _up(), -_forward()), origin)


func is_in_front(pos: Vector2, offset: Vector2 = Vector2.ZERO, height: float = 0.0) -> bool:
	var origin: Vector3 = to_world(target + offset) - _forward() * distance
	return (to_world(pos, height) - origin).dot(_forward()) > 0.001


## Ponto 2D do jogo (px) -> posição na tela (px), com a perspectiva e o seguimento.
func project(pos: Vector2, offset: Vector2 = Vector2.ZERO, height: float = 0.0) -> Vector2:
	var origin: Vector3 = to_world(target + offset) - _forward() * distance
	var rel: Vector3 = to_world(pos, height) - origin
	var depth: float = maxf(rel.dot(_forward()), 0.001)
	var half: float = tan(fov * 0.5) * depth
	var aspect: float = view_size.x / maxf(view_size.y, 1.0)
	var ndc := Vector2(rel.x / (half * aspect), rel.dot(_up()) / half)
	return Vector2((ndc.x + 1.0) * 0.5 * view_size.x, (1.0 - ndc.y) * 0.5 * view_size.y)


## Px de tela por px do jogo na profundidade de pos (para escalar sobreposições 2D).
func screen_scale_at(pos: Vector2, offset: Vector2 = Vector2.ZERO) -> float:
	return project(pos + Vector2(1.0, 0.0), offset).x - project(pos, offset).x


## Deslocamento do seguimento: proporcional à distância da nave ao centro, limitado.
static func follow_offset(ship: Vector2, center: Vector2, factor: float, max_px: float) -> Vector2:
	var raw: Vector2 = (ship - center) * factor
	return Vector2(clampf(raw.x, -max_px, max_px), clampf(raw.y, -max_px, max_px))
