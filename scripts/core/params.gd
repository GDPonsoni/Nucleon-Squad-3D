extends Node
## Parâmetros ajustáveis do jogo. Único lugar para valores de tuning.

# --- Tela / debug ---
var background_color: Color = Color(0.04, 0.04, 0.08)
var debug_overlay_enabled: bool = true
var debug_font_size: int = 40
var debug_margin: Vector2 = Vector2(40.0, 260.0)  # abaixo da pontuação do HUD
var debug_unlock_all: bool = false  # libera todas as fases sem mexer no save

# --- Interface ---
var ui_font_size: int = 60
var title_font_size: int = 120
var title_outline_size: int = 14
var subtitle_font_size: int = 44
var ui_accent_color: Color = Color(0.45, 0.9, 1.0)
var ui_panel_color: Color = Color(0.1, 0.12, 0.2, 0.92)
var ui_panel_alpha: float = 0.8
var ui_text_color: Color = Color(0.92, 0.95, 1.0)
var ui_muted_text_color: Color = Color(0.6, 0.66, 0.78)
var ui_corner_radius: int = 28
var ui_border_width: int = 3
var ui_button_padding: float = 24.0
var ui_panel_padding: float = 48.0
var stage_button_size: Vector2 = Vector2(260.0, 190.0)
var stage_record_font_size: int = 32
var results_column_gap: int = 60
var stage_select_spacing: int = 28
var stage_lock_size: float = 34.0
var debug_unlock_taps: int = 5  # toques no título do seletor (build de debug)
var ui_enter_seconds: float = 0.45  # entrada dos menus
var ui_enter_offset: float = 60.0
var menu_ship_y_ratio: float = 0.24  # altura da nave decorativa no menu
var menu_ship_scale: float = 2.2
var menu_ship_bob_height: float = 18.0
var menu_ship_bob_speed: float = 1.6
var menu_ship_cycle_seconds: float = 1.6  # tempo exibindo cada corpo
var transition_seconds: float = 0.2  # cada metade do fade entre telas
var transition_color: Color = Color(0.0, 0.0, 0.0)
var button_min_size: Vector2 = Vector2(600.0, 150.0)
var menu_spacing: int = 56
var pause_button_size: Vector2 = Vector2(130.0, 130.0)
var pause_button_margin: Vector2 = Vector2(40.0, 100.0)  # a partir do canto superior direito
var pause_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.65)
var hud_margin: Vector2 = Vector2(40.0, 70.0)  # a partir dos cantos inferiores
var hud_pip_size: Vector2 = Vector2(48.0, 48.0)
var hud_pip_radius: float = 8.0
var hud_gap: float = 14.0
var hud_icon_radius: float = 34.0
var hud_level_size: float = 30.0
var hud_level_gap: float = 8.0
var hud_dead_color: Color = Color(0.35, 0.35, 0.42)
var hud_dead_mark_color: Color = Color(1.0, 0.3, 0.3)
var hud_panel_color: Color = Color(0.06, 0.07, 0.12, 0.6)
var hud_panel_padding: float = 18.0
var hud_progress_y: float = 50.0
var hud_progress_height: float = 14.0
var hud_score_position: Vector2 = Vector2(40.0, 80.0)
var hud_score_font_size: int = 64
var hud_stage_font_size: int = 36
var hud_hit_flash_color: Color = Color(1.0, 0.15, 0.2)
var hud_hit_flash_alpha: float = 0.35
var hud_hit_flash_seconds: float = 0.35

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
var hit_invulnerability_seconds: float = 1.0  # após levar hit ([EM ABERTO] no GDD)
var game_over_delay_seconds: float = 0.8
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
var campaign_path: String = "res://data/campaign.tres"
var stage_clear_timeout: float = 6.0  # após o tempo da fase, espera no máximo isso pelos inimigos restantes
var enemy_pool_size: int = 24
var enemy_bullet_pool_size: int = 240
var enemy_hit_flash_seconds: float = 0.06
var explosion_pool_size: int = 24
var explosion_seconds: float = 0.55  # para um inimigo de raio de referência
var explosion_reference_radius: float = 48.0
var explosion_shards: int = 14
var explosion_shard_speed_min: float = 300.0
var explosion_shard_speed_max: float = 800.0
var explosion_shard_length: float = 0.5  # em relação ao raio
var explosion_shard_width: float = 8.0
var explosion_ring_growth: float = 1.8  # o anel cresce até ~2,3x o raio
var explosion_ring_width: float = 16.0
var explosion_flash_part: float = 0.2  # fração inicial com clarão branco
var cross_band_top: float = 0.08  # faixa da tela (0-1) onde os inimigos laterais entram
var cross_band_bottom: float = 0.45

# --- Power-ups ---
var powerup_every_kills: int = 8  # 1 power-up a cada N inimigos destruídos
var powerup_pool_size: int = 8
var powerup_fall_speed: float = 150.0  # px/s
var powerup_radius: float = 30.0
var powerup_pickup_radius: float = 60.0  # a partir do centro da nave
var powerup_color: Color = Color(1.0, 0.85, 0.3)
var powerup_spin_speed: float = 2.5  # rad/s
var powerup_pulse: float = 0.12  # variação de escala
var powerup_pulse_speed: float = 6.0
