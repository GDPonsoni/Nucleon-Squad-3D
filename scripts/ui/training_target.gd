class_name TrainingTarget
extends Enemy
## Alvo da demonstração de armas (tela de inspeção): balança devagar no lugar, não
## atira e não morre (a vida volta ao zerar). Sem som de acerto, para a tela não ficar barulhenta.

var _home: Vector2
var _clock: float = 0.0


func place(enemy_data: EnemyData, pos: Vector2, phase: float) -> void:
	activate(enemy_data, pos, Vector2.ZERO)
	_home = pos
	_clock = phase


func take_damage(amount: float, _source: int = SOURCE_NONE, _from: Vector2 = Vector2.INF) -> void:
	if not visible:
		return
	hp -= amount
	_flash_left = Params.enemy_hit_flash_seconds
	queue_redraw()
	if hp <= 0.0:
		hp = data.max_hp


func _process(delta: float) -> void:
	_clock += delta
	position = _home + Vector2(sin(_clock * Params.inspect_target_sway_speed) * Params.inspect_target_sway, 0.0)
	_update_flash(delta)
