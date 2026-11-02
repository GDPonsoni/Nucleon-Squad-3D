extends Node
## Parâmetros ajustáveis do jogo. Único lugar para valores de tuning.

# --- Tela / debug ---
var background_color: Color = Color(0.04, 0.04, 0.08)
var debug_overlay_enabled: bool = true
var debug_font_size: int = 40
var debug_margin: Vector2 = Vector2(40.0, 120.0)  # abaixo da câmera frontal

# --- Interface ---
var ui_font_size: int = 64
var title_font_size: int = 120
var button_min_size: Vector2 = Vector2(600.0, 150.0)
var menu_spacing: int = 56
var pause_button_size: Vector2 = Vector2(130.0, 130.0)
var pause_button_margin: Vector2 = Vector2(40.0, 100.0)  # a partir do canto superior direito
var pause_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.65)

# --- Fundo: estrelas em camadas (distante -> próxima) ---
var star_layer_counts: PackedInt32Array = [70, 40, 16]
var star_layer_speeds: PackedFloat32Array = [40.0, 120.0, 320.0]  # px/s
var star_layer_sizes: PackedFloat32Array = [2.0, 3.5, 5.0]
var star_layer_alphas: PackedFloat32Array = [0.3, 0.55, 0.85]
var star_layer_streaks: PackedFloat32Array = [0.0, 1.0, 4.0]  # alongamento vertical
var star_color: Color = Color(0.8, 0.85, 1.0)

# --- Câmera lenta ---
var slow_time_scale: float = 0.3
var time_scale_smooth_seconds: float = 0.1  # duração da transição, em tempo real

# --- Nave ---
var ship_speed: float = 3000.0  # px/s máximos (escalado pelo time scale)
var drag_sensitivity: float = 1.0  # 1.0 = nave anda o mesmo que o dedo
var ship_size: Vector2 = Vector2(90.0, 110.0)  # tamanho de referência dos corpos
var ship_start_bottom_offset: float = 300.0  # distância da base da tela
var nucleus_radius: float = 16.0  # também é a hitbox da nave
var nucleus_color: Color = Color(1.0, 1.0, 1.0)
var crack_start_angle: float = 0.8  # rad; posição da 1ª rachadura do núcleo
var crack_angle_step: float = 2.1  # rad entre rachaduras

# --- Corpos (formas e armas ficam em data/) ---
var formation_path: String = "res://data/formations/default.tres"
var body_max_hits: int = 3
var body_rebuild_seconds: float = 0.35
var invulnerability_blink_hz: float = 12.0
var invulnerability_alpha: float = 0.3

# --- Troca de corpo (ícones na câmera lenta) ---
var switch_invulnerability_seconds: float = 2.0
var switch_icon_radius: float = 70.0
var switch_icon_distance: float = 230.0  # do centro da nave
var switch_icon_arc_degrees: float = 120.0
var switch_icon_touch_scale: float = 1.25  # área de toque maior que o ícone
var switch_icon_shape_scale: float = 1.1
var switch_icon_bg_color: Color = Color(0.1, 0.1, 0.16, 0.85)

# --- Projéteis do jogador ---
var player_bullet_pool_size: int = 128

# --- Inimigos e fase (tipos e ondas ficam em data/) ---
var stage_path: String = "res://data/stages/stage_01.tres"
var enemy_pool_size: int = 24
var enemy_bullet_pool_size: int = 160
var enemy_hit_flash_seconds: float = 0.06
