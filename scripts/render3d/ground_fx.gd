class_name GroundFx
extends Node3D
## Efeitos planos no plano de jogo: avisos de tiro, feixes, escudos, auras, ondas de choque,
## explosões, números de dano. Em vez de refazer cada draw_* em 3D, a camada 2D inteira do
## jogo (o mesmo desenho da versão 2D) é renderizada num SubViewport e aplicada como textura
## num quadrado deitado no plano de jogo. Assim o aviso e a colisão usam a mesma geometria.
##
## Como funciona: os nós 2D do jogo ficam na camada de visibilidade WORLD_LAYER; a tela
## principal deixa de desenhá-la (canvas_cull_mask) e o SubViewport, que compartilha o
## mesmo World2D, só desenha ela. HUD e menus (CanvasLayer) seguem na tela, por cima do 3D.

const WORLD_LAYER: int = 2  # bit da camada de visibilidade dos nós 2D do jogo

var viewport: SubViewport
var plane: MeshInstance3D
var _game: Node
var _main: Viewport
var _saved_mask: int = 0


func setup(game: Node2D, rig: CameraRig) -> void:
	_game = game
	_main = game.get_viewport()
	viewport = SubViewport.new()
	viewport.name = "GroundFxViewport"
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_cull_mask = WORLD_LAYER
	add_child(viewport)
	viewport.world_2d = _main.world_2d
	_saved_mask = _main.canvas_cull_mask
	_main.canvas_cull_mask = _saved_mask & ~WORLD_LAYER

	plane = MeshInstance3D.new()
	plane.name = "GroundFxPlane"
	plane.mesh = MeshFactory.quad()
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/render3d/shaders/ground_fx.gdshader") as Shader
	material.set_shader_parameter("layer", viewport.get_texture())
	material.render_priority = 1
	plane.material_override = material
	add_child(plane)
	resize(rig)

	_mark(game)
	game.get_tree().node_added.connect(_on_node_added)


## Ajusta a textura e o quadrado ao tamanho da tela (a arena 2D é o retângulo da tela).
func resize(rig: CameraRig) -> void:
	var view: Vector2 = rig.view_size
	var ratio: float = clampf(Params.ground_fx_resolution, 0.25, 1.0)
	viewport.size = Vector2i(maxi(int(view.x * ratio), 2), maxi(int(view.y * ratio), 2))
	viewport.size_2d_override = Vector2i(view)
	viewport.size_2d_override_stretch = true
	plane.position = rig.to_world(view * 0.5, Params.ground_fx_height_3d)
	plane.scale = Vector3(view.x * rig.world_scale, 1.0, view.y * rig.world_scale)


func _exit_tree() -> void:
	if _main != null and is_instance_valid(_main):
		_main.canvas_cull_mask = _saved_mask
	if _game != null and _game.get_tree() != null and _game.get_tree().node_added.is_connected(_on_node_added):
		_game.get_tree().node_added.disconnect(_on_node_added)


## Põe na camada do jogo o nó e os filhos 2D (para em CanvasLayer e em outros viewports).
func _mark(node: Node) -> void:
	if node is CanvasLayer or node is Viewport:
		return
	if node is CanvasItem:
		(node as CanvasItem).visibility_layer = WORLD_LAYER
	for child in node.get_children():
		_mark(child)


## Nós criados durante a partida (chefe, armas, ondas de choque) entram na mesma camada.
func _on_node_added(node: Node) -> void:
	if not (node is CanvasItem):
		return
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is CanvasLayer or parent is Viewport:
			return
		if parent == _game:
			_mark(node)
			return
		parent = parent.get_parent()
