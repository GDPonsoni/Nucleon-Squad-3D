class_name WeaponDemo
extends SubViewportContainer
## Demonstração ao vivo de uma arma (tela de inspeção da nave): mundo pequeno numa
## SubViewport com a nave de verdade atirando em alvos de treino. Modo principal mostra
## a nave com a arma no nível escolhido; modo auxiliar mostra só o núcleo com a nave
## auxiliar ao lado, usando a versão auxiliar da arma.

var _viewport: SubViewport
var _world: Node2D
var _context: CombatContext
var _player: Player
var _companion: Companion
var _targets: NodePool


func _init(display_size: Vector2) -> void:
	custom_minimum_size = display_size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(display_size)
	_viewport.transparent_bg = false
	add_child(_viewport)


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Params.inspect_demo_background
	background.size = Vector2(_viewport.size)
	_viewport.add_child(background)
	_world = Node2D.new()
	_viewport.add_child(_world)

	_context = CombatContext.new()
	_context.player_bullets = NodePool.new(Bullet.new, Params.inspect_bullet_pool_size)
	_world.add_child(_context.player_bullets)
	_targets = NodePool.new(TrainingTarget.new, Params.inspect_target_positions.size())
	_world.add_child(_targets)
	_context.enemies = _targets
	_context.impacts = NodePool.new(HitSpark.new, 16)
	_world.add_child(_context.impacts)
	_context.enemy_bullets = NodePool.new(Bullet.new, 1)
	_world.add_child(_context.enemy_bullets)
	_context.power_ups = NodePool.new(PowerUp.new, 1)
	_world.add_child(_context.power_ups)

	_player = Player.new()
	_world.add_child(_player)
	_player.setup(_context)
	_player.place_at(Vector2(_viewport.size) * Params.inspect_ship_position)
	_player.mount.sound_db = Params.inspect_demo_sound_db
	_context.player = _player

	var combat := CombatSystem.new()
	_world.add_child(combat)
	combat.setup(_context, _player)
	_place_targets()


## Alvos em posições relativas ao tamanho da demonstração; o maior serve para os Mísseis.
func _place_targets() -> void:
	var size := Vector2(_viewport.size)
	var small := load(Params.inspect_target_small) as EnemyData
	var big := load(Params.inspect_target_big) as EnemyData
	for i in Params.inspect_target_positions.size():
		var target := _targets.acquire() as TrainingTarget
		var data: EnemyData = big if i == Params.inspect_big_target_index else small
		target.place(data, Params.inspect_target_positions[i] * size, i * 0.9)


## Mostra a arma completa no nível dado.
func show_main(body: BodyData, level: int) -> void:
	_clear_companion()
	_player.set_body(body, level, 0.0)


## Dispara o especial da arma a partir da nave da demonstração.
func trigger_special(body: BodyData) -> void:
	if _player.body == null:
		return
	SpecialAttack.trigger(body.weapon, _player, _context, _world)


## Mostra a versão auxiliar no nível dado (só o núcleo da nave principal, sem arma).
func show_companion(body: BodyData, level: int) -> void:
	_player.clear_body()
	_clear_companion()
	_companion = Companion.new()
	_companion.always_active = true
	_world.add_child(_companion)
	_companion.setup(body, _context)
	for weapon in _companion.mount.weapons():
		weapon.sound_db = Params.inspect_demo_sound_db
	_companion.set_level(level)


func _clear_companion() -> void:
	if _companion != null:
		_companion.queue_free()
		_companion = null
	for bullet in _context.player_bullets.active.duplicate():
		_context.player_bullets.release(bullet)
