class_name Renderer3D
extends Node3D
## Visão 3D da partida. A simulação continua 2D (posições em px, colisão por círculos):
## este nó só desenha. Monta câmera, luz, ambiente, chão e as vistas das entidades, e
## converte posições do jogo em posições de tela (project_to_screen) para o HUD.
## Entra por último entre os nós de lógica, para sincronizar depois da simulação do quadro.

## Há uma visão 3D em cena: as entidades não desenham o próprio corpo em 2D.
static var active: bool = false
static var _count: int = 0

var rig := CameraRig.new()
var camera: Camera3D
var ground: MeshInstance3D
var ground_fx: GroundFx
var scenery: Scenery3D  # null com Params.scenery_enabled_3d desligado
var entities: EntityViews
var bullets: BulletView

var _game: Node2D
var _reserved_bottom: float = 0.0
var _offset := Vector2.ZERO  # deslocamento do seguimento (px no chão), já suavizado
var _scroll: float = 0.0
var _ground_material: ShaderMaterial


func _enter_tree() -> void:
	_count += 1
	active = true


func _exit_tree() -> void:
	_count = maxi(_count - 1, 0)
	active = _count > 0


## game = cena da partida; reserved_bottom = faixa da base ocupada pela barra de troca (px).
func setup(game: Node2D, reserved_bottom: float) -> void:
	_game = game
	_reserved_bottom = reserved_bottom
	var planet: PlanetData = Session.planet()

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = planet.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Params.ambient_color_3d
	environment.ambient_light_energy = Params.ambient_energy_3d
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Environment"
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Params.light_rotation_3d
	light.light_energy = Params.light_energy_3d
	light.shadow_enabled = false
	add_child(light)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.current = true

	_build_ground(planet)

	if Params.scenery_enabled_3d:
		scenery = Scenery3D.new()
		scenery.name = "Scenery"
		add_child(scenery)
		var view: Vector2 = _view_size()
		scenery.setup(planet, String(game.call("_stage").id), Vector3(view.x, 0.0, view.y) * 0.5 * Params.world_scale_3d)

	ground_fx = GroundFx.new()
	ground_fx.name = "GroundFx"
	add_child(ground_fx)

	_refit()
	ground_fx.setup(game, rig)

	entities = EntityViews.new()
	entities.name = "EntityViews"
	add_child(entities)
	entities.setup(game, rig)

	bullets = BulletView.new()
	bullets.name = "BulletView"
	add_child(bullets)
	bullets.setup(game, rig)

	game.get_viewport().size_changed.connect(_on_view_resized)
	_sync_camera()


## Posição 2D do jogo (px) -> posição na tela (px), para sobreposições 2D (dicas, HUD).
func project_to_screen(pos: Vector2, height: float = 0.0) -> Vector2:
	return rig.project(pos, _offset, height)


## Tamanho na tela de 1 px do jogo, na profundidade de pos.
func screen_scale_at(pos: Vector2) -> float:
	return rig.screen_scale_at(pos, _offset)


## Retângulo de tela que cobre um círculo do jogo (centro e raio em px do jogo).
func project_rect(center: Vector2, radius: float) -> Rect2:
	var at: Vector2 = project_to_screen(center)
	var r: float = radius * screen_scale_at(center)
	return Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0)


func follow_offset() -> Vector2:
	return _offset


func _process(delta: float) -> void:
	_update_follow(delta)
	_sync_camera()
	_scroll = fposmod(_scroll + Params.ground_scroll_speed_3d * rig.world_scale * delta, Params.ground_cell_3d * 64.0)
	_ground_material.set_shader_parameter("scroll", _scroll)


## Seguimento leve: a câmera desliza um pouco na direção da nave, com limite e suavização.
func _update_follow(delta: float) -> void:
	var player: Player = _game.get("player")
	if player == null:
		return
	var goal: Vector2 = CameraRig.follow_offset(player.position, _playable().get_center(),
		Params.camera_follow_factor, minf(Params.camera_follow_max_px, Params.camera_fit_margin))
	_offset = _offset.lerp(goal, 1.0 - exp(-Params.camera_follow_smooth * delta))


func _sync_camera() -> void:
	camera.fov = rad_to_deg(rig.fov)
	camera.global_transform = rig.camera_transform(_offset)


func _view_size() -> Vector2:
	return _game.get_viewport_rect().size


## Área onde a nave anda: a tela menos a faixa da barra de troca.
func _playable() -> Rect2:
	var view: Vector2 = _view_size()
	return Rect2(0.0, 0.0, view.x, view.y - _reserved_bottom)


func _refit() -> void:
	var view: Vector2 = _view_size()
	rig.configure(view)
	rig.fit(_playable(), Rect2(0.0, 0.0, view.x, view.y - _reserved_bottom), Params.camera_fit_margin)


func _on_view_resized() -> void:
	_refit()
	ground_fx.resize(rig)
	_sync_camera()


## Chão distante, abaixo do plano de jogo, grande o bastante para cobrir o horizonte visível.
func _build_ground(planet: PlanetData) -> void:
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = MeshFactory.quad()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://scripts/render3d/shaders/ground.gdshader") as Shader
	_ground_material.set_shader_parameter("base_color", planet.background_color)
	_ground_material.set_shader_parameter("line_color", planet.star_color.darkened(0.35))
	_ground_material.set_shader_parameter("star_color", planet.star_color)
	_ground_material.set_shader_parameter("cell", Params.ground_cell_3d)
	_ground_material.set_shader_parameter("line_strength", Params.ground_line_strength_3d)
	_ground_material.set_shader_parameter("star_strength", Params.ground_star_strength_3d)
	_ground_material.set_shader_parameter("star_density", Params.ground_star_density_3d)
	_ground_material.set_shader_parameter("fade_start", Params.ground_fade_start_3d)
	_ground_material.set_shader_parameter("fade_end", Params.ground_fade_end_3d)
	ground.material_override = _ground_material
	var view: Vector2 = _view_size()
	ground.position = Vector3(view.x * 0.5 * Params.world_scale_3d, -Params.ground_depth_3d, view.y * 0.5 * Params.world_scale_3d)
	ground.scale = Vector3.ONE * Params.ground_size_3d
	add_child(ground)
