class_name MenuShip
extends Node2D
## Nave decorativa do menu: flutua e alterna entre os corpos da formação,
## desmontando e reconstruindo a partir do núcleo.

var _bodies: Array[BodyData] = []
var _index: int = 0
var _build: float = 0.0
var _clock: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	var formation := load(Params.formation_path) as FormationData
	_bodies = formation.bodies
	_base_y = position.y
	_cycle()


func _process(delta: float) -> void:
	_clock += delta
	position.y = _base_y + sin(_clock * Params.menu_ship_bob_speed) * Params.menu_ship_bob_height
	queue_redraw()


## Reconstrói o corpo atual, espera e passa para o próximo.
func _cycle() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_build", 1.0, Params.body_rebuild_seconds * 2.0)
	tween.tween_interval(Params.menu_ship_cycle_seconds)
	tween.tween_property(self, "_build", 0.0, Params.body_rebuild_seconds)
	tween.tween_callback(func() -> void: _index = (_index + 1) % _bodies.size())
	tween.finished.connect(_cycle)


func _draw() -> void:
	var scale_factor: float = Params.menu_ship_scale
	var body: BodyData = _bodies[_index]
	if _build > 0.0:
		var points := PackedVector2Array()
		for point in body.shape:
			points.append(point * Params.ship_size * scale_factor * _build)
		draw_colored_polygon(points, body.color)
	draw_circle(Vector2.ZERO, Params.nucleus_radius * scale_factor, Params.nucleus_color)
