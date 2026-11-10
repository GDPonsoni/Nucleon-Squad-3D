class_name BulletView
extends Node3D
## Projéteis em 3D: um MultiMeshInstance3D por formato (um draw call por formato), alimentado
## a cada quadro pelos pools de tiros do jogador e dos inimigos. Só lê os projéteis.

var _game: Node2D
var _rig: CameraRig
var _scale: float = 0.01
var _height: float = 0.0
var _meshes: Array[MultiMesh] = []  # índice = Bullet.Shape
var _counts := PackedInt32Array()


func setup(game: Node2D, rig: CameraRig) -> void:
	_game = game
	_rig = rig
	_scale = rig.world_scale
	_height = Params.bullet_height_3d * _scale
	var capacity: int = Params.player_bullet_pool_size + Params.enemy_bullet_pool_size
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/render3d/shaders/bullet.gdshader") as Shader
	material.set_shader_parameter("core_white", Params.bullet_core_white_3d)
	var shapes: Array[Mesh] = []
	shapes.resize(Bullet.Shape.size())
	shapes[Bullet.Shape.RECT] = ModelLibrary.bullet_box()
	shapes[Bullet.Shape.CIRCLE] = ModelLibrary.bullet_orb()
	shapes[Bullet.Shape.TRIANGLE] = ModelLibrary.bullet_dart()
	for i in shapes.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = shapes[i]
		multimesh.instance_count = capacity
		multimesh.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.name = "Bullets%d" % i
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Os tiros cobrem a arena inteira: não vale calcular o volume a cada quadro
		instance.custom_aabb = AABB(Vector3(-500.0, -50.0, -500.0), Vector3(1000.0, 100.0, 1000.0))
		add_child(instance)
		_meshes.append(multimesh)
	_counts.resize(shapes.size())


func _process(_delta: float) -> void:
	_counts.fill(0)
	_feed(_game.get("player_bullets"))
	_feed(_game.get("enemy_bullets"))
	for i in _meshes.size():
		_meshes[i].visible_instance_count = _counts[i]


func visible_count() -> int:
	var total: int = 0
	for count in _counts:
		total += count
	return total


func _feed(pool: NodePool) -> void:
	if pool == null:
		return
	for item in pool.active:
		var bullet := item as Bullet
		var shape: int = bullet.shape()
		var index: int = _counts[shape]
		var multimesh: MultiMesh = _meshes[shape]
		if index >= multimesh.instance_count:
			continue
		var size: Vector2 = bullet.visual_size()
		var pos := Vector3(bullet.position.x * _scale, _height, bullet.position.y * _scale)
		var basis: Basis
		if shape == Bullet.Shape.CIRCLE:
			basis = Basis.from_scale(Vector3.ONE * size.x * 0.5 * _scale)
		else:
			# As formas apontam para cima no 2D (-Z aqui) e giram com a velocidade
			var thickness: float = minf(size.x, size.y)
			basis = Basis(Vector3.UP, -bullet.rotation).scaled_local(Vector3(size.x, thickness, size.y) * _scale)
		multimesh.set_instance_transform(index, Transform3D(basis, pos))
		multimesh.set_instance_color(index, bullet.color())
		_counts[shape] = index + 1
