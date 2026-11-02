class_name EnemySpawner
extends Node
## Faz os inimigos da fase surgirem acima da tela, em intervalos aleatórios.

var _stage: StageData
var _enemies: NodePool
var _cooldown: float = 0.0


func setup(stage: StageData, enemies: NodePool) -> void:
	_stage = stage
	_enemies = enemies
	_cooldown = stage.start_delay


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown += randf_range(_stage.spawn_interval_min, _stage.spawn_interval_max)
	_spawn()


func _spawn() -> void:
	if _stage.enemies.is_empty():
		return
	var enemy := _enemies.acquire() as Enemy
	if enemy == null:
		return
	var data: EnemyData = _stage.enemies.pick_random()
	var rect: Rect2 = get_viewport().get_visible_rect()
	var x: float = randf_range(rect.position.x + _stage.spawn_margin_x, rect.end.x - _stage.spawn_margin_x)
	enemy.activate(data, Vector2(x, rect.position.y - data.radius))
