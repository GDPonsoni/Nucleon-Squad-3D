extends Node
## Parâmetros ajustáveis do jogo. Único lugar para valores de tuning.

# --- Áudio e configurações (ganho de cada som em dB: nivela o volume entre eles) ---
var sfx_voices: int = 20  # sons ao mesmo tempo
var music_menu_path: String = "res://assets/audio/music/menu.wav"
var music_chapter_path: String = "res://assets/audio/music/chapter_%d.wav"
var music_volume_db: float = -6.0  # a música fica abaixo dos efeitos
var music_silent_db: float = -40.0
var music_fade_seconds: float = 0.6
var sfx_gain_db: Dictionary = {
	&"body_break": -4.1, &"bomb_global": -1.0, &"boss_explode": -1.8, &"boss_hit": -11.2,
	&"boss_warning": -8.7, &"core_crack": -4.8, &"enemy_explode_medium": -6.3, &"enemy_explode_small": -6.9,
	&"enemy_hit": -13.4, &"game_over": -5.4, &"hit_player": -2.2, &"missile_explode": -5.2,
	&"powerup_pickup": -10.1, &"revive": -5.8, &"ship_switch": -7.4, &"shot_beam": -11.2,
	&"shot_missile": -8.4, &"shot_orbit": -11.1, &"shot_spread": -9.7, &"slowmo_enter": -9.3,
	&"slowmo_exit": -10.8, &"special_fire": -1.9, &"special_ready": -5.0, &"stage_clear": -10.1,
	&"ui_back": -13.5, &"ui_click": -13.1, &"ui_confirm": -13.5, &"weapon_levelup": -11.0,
}
# Intervalo mínimo entre dois disparos do mesmo som (s): evita empilhar tiros e acertos
var sfx_min_gap: Dictionary = {
	&"shot_beam": 0.2, &"shot_spread": 0.07, &"shot_missile": 0.15, &"shot_orbit": 0.18,
	&"enemy_hit": 0.05, &"boss_hit": 0.08, &"enemy_explode_small": 0.05, &"enemy_explode_medium": 0.06,
	&"missile_explode": 0.08, &"ui_click": 0.04, &"slowmo_enter": 0.15, &"slowmo_exit": 0.15,
}
var sfx_pitch_jitter: float = 0.06  # variação aleatória de tom
var companion_sound_db: float = -8.0  # a nave auxiliar soa mais baixo
var default_settings: Dictionary = {
	"master": 1.0, "music": 0.7, "sfx": 0.8, "vibration": true, "reduced_effects": false, "language": "auto",
}
var languages: PackedStringArray = ["auto", "pt_BR", "en", "es"]
var vibration_ms: int = 60  # levar hit
var haptic_tick_ms: int = 12  # toque leve: trocar de capítulo, trocar de nave
var haptic_level_up_ms: int = 25
var haptic_special_ms: int = 40
var haptic_body_break_ms: int = 160
var haptic_boss_kill_ms: int = 220
var haptic_stage_clear_ms: int = 90
var button_press_scale: float = 0.94  # botão afunda ao tocar
var button_press_seconds: float = 0.06
var swipe_min_distance: float = 140.0  # gesto para trocar de capítulo
var swipe_max_seconds: float = 0.6
var stage_slide_offset: float = 260.0  # animação ao trocar de capítulo
var stage_slide_seconds: float = 0.28
var chapter_art_size: Vector2 = Vector2(900.0, 300.0)
var reduced_explosion_shards: int = 5
var reduced_slowmo_intensity: float = 0.45
var settings_slider_width: float = 900.0
var settings_slider_height: float = 84.0
var settings_row_spacing: int = 14
var settings_label_font_size: int = 46

# --- Tela / debug ---
var background_color: Color = Color(0.04, 0.04, 0.08)
var debug_overlay_enabled: bool = true
var debug_font_size: int = 40
var debug_margin: Vector2 = Vector2(40.0, 260.0)  # abaixo da pontuação do HUD
var debug_unlock_all: bool = false  # libera todas as fases sem mexer no save
var debug_start_weapon_level: int = 1  # nível inicial das armas (testes)

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
var ui_corner_radius: int = 34
var ui_border_width: int = 3
var ui_button_depth: int = 9  # relevo dos botões (borda de baixo)
var ui_button_padding: float = 24.0
var ui_panel_padding: float = 48.0
var squad_spacing: int = 22
var squad_columns: int = 2
var squad_slot_size: float = 150.0
var squad_card_size: Vector2 = Vector2(490.0, 225.0)
var squad_card_icon_size: float = 110.0
var squad_hint_width: float = 900.0
var squad_wingman_columns: int = 5  # escolha da nave auxiliar
var squad_wingman_size: float = 120.0
var squad_wingman_font_size: int = 26
var squad_name_font_size: int = 46
var squad_description_font_size: int = 28
var squad_button_size: Vector2 = Vector2(420.0, 140.0)
var stage_button_size: Vector2 = Vector2(260.0, 190.0)
var stage_grid_columns: int = 3  # fases por linha no seletor (9 fases = 3 x 3)
var stage_chapter_font_size: int = 72
var stage_chapter_name_width: float = 620.0  # o nome encolhe para caber
var stage_arrow_size: float = 130.0
var stage_dot_spacing: float = 56.0  # bolinhas indicando o capítulo aberto
var stage_dot_radius: float = 11.0
var stage_record_font_size: int = 27
var stage_row_max_width: float = 880.0  # largura máxima da fileira de fases de um capítulo
var results_column_gap: int = 60
var results_spacing: int = 22  # entre os itens da tela de resultado
var results_detail_font_size: int = 30
var results_button_height: float = 128.0
var upgrade_tree_width: float = 1000.0  # tela de evolução do núcleo
var upgrade_tree_header: float = 64.0  # nomes dos ramos acima dos nós
var upgrade_node_radius: float = 62.0
var upgrade_row_gap: float = 196.0
var upgrade_column_offset: float = 320.0  # distância das colunas laterais até o centro
var upgrade_touch_scale: float = 1.3  # área de toque maior que o nó
var upgrade_ring_width: float = 8.0
var upgrade_link_width: float = 6.0
var upgrade_node_bg_color: Color = Color(0.08, 0.09, 0.15, 1.0)
var upgrade_level_font_size: int = 34
var upgrade_branch_font_size: int = 40
var upgrade_pulse_seconds: float = 0.5
var upgrade_spacing: int = 24
var upgrade_balance_font_size: int = 52
var upgrade_detail_width: float = 900.0
var upgrade_detail_spacing: int = 14
var upgrade_name_font_size: int = 56
var upgrade_detail_font_size: int = 36
var upgrade_buy_height: float = 130.0
var upgrade_buy_font_size: int = 46
var stage_select_spacing: int = 28
var stage_lock_size: float = 34.0
var debug_unlock_taps: int = 5  # toques no título do seletor (build de debug)
var ui_enter_seconds: float = 0.45  # entrada dos menus
var ui_enter_offset: float = 60.0
var menu_ship_y_ratio: float = 0.17  # altura da nave decorativa no menu
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
var hud_margin: Vector2 = Vector2(40.0, 70.0)  # margens laterais do HUD
var hud_quark_icon_radius: float = 20.0
var hud_dead_color: Color = Color(0.35, 0.35, 0.42)
var hud_dead_mark_color: Color = Color(1.0, 0.3, 0.3)
var hud_panel_color: Color = Color(0.06, 0.07, 0.12, 0.6)
var hud_progress_y: float = 50.0
var hud_progress_height: float = 14.0
var hud_score_position: Vector2 = Vector2(40.0, 80.0)
var hud_score_font_size: int = 64
var hud_stage_font_size: int = 36
var hud_hit_flash_color: Color = Color(1.0, 0.15, 0.2)
var hud_hit_flash_alpha: float = 0.35
var hud_hit_flash_seconds: float = 0.35
var hud_boss_bar_height: float = 22.0
var hud_boss_name_font_size: int = 40
var hud_warning_color: Color = Color(1.0, 0.3, 0.35)
var hud_warning_blinks: int = 4

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
var slow_motion_tint: Color = Color(0.3, 0.6, 1.0, 0.6)  # vinheta nas bordas (alfa = força máxima)

# --- Nave ---
var ship_speed: float = 3000.0  # px/s máximos (escalado pelo time scale)
var drag_sensitivity: float = 1.0  # 1.0 = nave anda o mesmo que o dedo
var ship_size: Vector2 = Vector2(90.0, 110.0)  # tamanho de referência dos corpos
var ship_start_bottom_offset: float = 380.0  # distância da base da tela (acima da barra de troca)
var nucleus_radius: float = 16.0  # também é a hitbox da nave
var nucleus_color: Color = Color(1.0, 1.0, 1.0)
var nucleus_outline_color: Color = Color(0.02, 0.02, 0.06)  # separa o núcleo da cor do corpo
var nucleus_outline_width: float = 5.0
var nucleus_ring_scale: float = 1.9  # anel pulsando em volta do núcleo (x raio)
var nucleus_ring_width: float = 4.0
var nucleus_ring_alpha: float = 0.45
var nucleus_ring_alpha_slow: float = 1.0  # anel mais forte na câmera lenta
var nucleus_pulse_speed: float = 6.0
var health_pip_size: Vector2 = Vector2(22.0, 10.0)  # segmentos de saúde embaixo da nave
var health_pip_gap: float = 5.0
var health_offset: float = 14.0  # distância da base da nave até a barra de saúde
var health_flash_seconds: float = 0.3  # a barra pisca em branco ao perder um hit
var level_up_pulse_seconds: float = 0.5
var level_up_pulse_growth: float = 2.0
var level_up_pulse_width: float = 10.0
var crack_start_angle: float = 0.8  # rad; posição da 1ª rachadura do núcleo
var crack_angle_step: float = 2.1  # rad entre rachaduras

# --- Corpos (formas e armas ficam em data/) ---
var formation_path: String = "res://data/formations/default.tres"  # esquadrão inicial
var roster_path: String = "res://data/formations/roster.tres"  # todas as naves disponíveis
var squad_size: int = 4
var body_max_hits: int = 3
var body_rebuild_seconds: float = 0.35
var hit_invulnerability_seconds: float = 1.0  # após levar hit ([EM ABERTO] no GDD)
var game_over_delay_seconds: float = 0.8
var revive_offer_seconds: float = 20.0  # tempo para aceitar continuar com anúncio
var revive_invulnerability_seconds: float = 3.0
var revive_clear_radius: float = 2400.0  # limpa os tiros inimigos ao voltar
var ad_simulated_seconds: float = 2.5  # duração do anúncio simulado (sem SDK)
var ad_placeholder_color: Color = Color(0.02, 0.02, 0.05, 0.97)
var invulnerability_blink_hz: float = 12.0
var invulnerability_alpha: float = 0.3

# --- Troca de corpo: barra fixa na base da tela (nítida na câmera lenta) ---
var switch_invulnerability_seconds: float = 2.0
var switch_icon_radius: float = 82.0
var switch_icon_max_spacing_ratio: float = 0.36  # com muitos corpos, o raio diminui para caber
var switch_strip_bottom: float = 150.0  # centro da barra, a partir da base da tela
var switch_strip_spacing: float = 235.0  # entre ícones da barra
var switch_strip_side_margin: float = 30.0
var switch_strip_padding: float = 14.0
var switch_strip_touch_margin: float = 20.0  # toque curto vale um pouco além da barra
var switch_strip_color: Color = Color(0.04, 0.05, 0.1, 0.55)  # levemente transparente
var switch_bar_border_alpha: float = 0.35
var switch_bar_idle_alpha: float = 0.45  # opacidade da barra enquanto o dedo move a nave
var switch_bar_fade_seconds: float = 0.12  # transição entre translúcida e nítida (tempo real)
var switch_current_scale: float = 1.08  # o corpo ativo aparece um pouco maior
var switch_dead_alpha: float = 0.35
var switch_level_ring_offset: float = 11.0  # anel de nível da arma, fora do ícone
var switch_level_ring_width: float = 7.0
var switch_level_ring_gap_degrees: float = 14.0
var switch_icon_touch_scale: float = 1.15  # área de toque um pouco maior que o ícone
var switch_icon_shape_scale: float = 1.1
var switch_icon_bg_color: Color = Color(0.1, 0.1, 0.16, 0.85)
var switch_hint_font_size: int = 44
var switch_hint_gap: float = 26.0  # aviso "escolha a próxima nave" acima da barra
var tap_max_seconds: float = 0.35  # toque curto: tempo máximo com o dedo na barra (tempo real)
var tap_move_tolerance: float = 36.0  # toque curto: quanto o dedo pode andar sem virar arraste

# --- Nave auxiliar (a arma dela fica em data/weapons/, campo companion) ---
var companion_scale: float = 0.5  # tamanho em relação à nave principal
var companion_offset: Vector2 = Vector2(115.0, 70.0)  # posição relativa à nave (x = para o lado)
var companion_follow_rate: float = 9.0  # quão rápido acompanha a nave (maior = mais grudada)
var companion_side_margin: float = 230.0  # perto da borda, passa para o outro lado
var companion_alpha: float = 0.9

# --- Projéteis do jogador ---
var player_bullet_pool_size: int = 160

# --- Inimigos e fase (tipos e ondas ficam em data/) ---
var campaign_path: String = "res://data/campaign.tres"
var stage_clear_timeout: float = 6.0  # após o tempo da fase, espera no máximo isso pelos inimigos restantes
var enemy_pool_size: int = 64
var enemy_bullet_pool_size: int = 500
var enemy_hit_flash_seconds: float = 0.06
var explosion_pool_size: int = 24
var boss_warning_seconds: float = 2.5  # aviso antes do chefe entrar
var boss_explosions: int = 8  # explosões em sequência ao destruir o chefe
var boss_explosion_gap: float = 0.12
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

# --- Especial (valores de cada arma ficam em data/weapons/) ---
var special_button_size: float = 150.0
var special_button_gap: float = 28.0  # acima da barra de troca
var special_ring_width: float = 9.0
var special_beam_open_seconds: float = 0.15
var special_burst_rings: int = 3
var special_burst_speed: float = 1300.0
var special_burst_size: Vector2 = Vector2(22.0, 22.0)
var special_missile_speed: float = 900.0
var special_missile_size: Vector2 = Vector2(20.0, 32.0)
var special_missile_lifetime: float = 3.0
var special_missile_turn_degrees: float = 360.0
var special_lance_spread_degrees: float = 50.0
var special_lance_length_ratio: float = 4.0  # comprimento em relação à largura
var special_lance_speed: float = 2400.0
var special_lance_pierce: int = 999
var special_bombard_area: float = 0.75  # explosões caem até essa fração da altura
var special_bombard_aim_chance: float = 0.6  # chance de mirar num inimigo
var special_bombard_blast_seconds: float = 0.35
var special_pinball_speed: float = 1300.0  # Ricochete
var special_pinball_size: Vector2 = Vector2(24.0, 24.0)
var special_pinball_bounces: int = 5
var special_pinball_wall_bounces: int = 3
var special_pinball_range: float = 600.0
var special_pinball_lifetime: float = 2.5
var storm_flash_seconds: float = 0.25  # Tesla: cada raio da tempestade
var chain_bolt_seconds: float = 0.12  # Tesla: quanto cada descarga fica na tela
var chain_bolt_segments: int = 6  # pedaços do raio quebrado
var chain_bolt_jitter: float = 18.0  # px de zigue-zague
var chain_bolt_width: float = 5.0

# --- Progressão: quarks e evolução do núcleo (cores do ícone do quark) ---
var quark_color: Color = Color(0.78, 0.66, 1.0)
var quark_dot_colors: PackedColorArray = [Color(1.0, 0.4, 0.4), Color(0.45, 1.0, 0.55), Color(0.45, 0.65, 1.0)]

# --- Progressão: quarks e evolução do núcleo (valores de cada nó ficam em data/upgrades/) ---
var upgrade_tree_path: String = "res://data/upgrade_tree.tres"
var quarks_per_point: float = 0.1  # quarks ganhos por ponto de pontuação (inimigos e chefes)
var quarks_stage_clear: PackedInt32Array = [30, 45, 60, 80, 100]  # bônus por concluir uma fase, por capítulo
var quarks_first_clear_multiplier: float = 2.0  # o bônus dobra na primeira vez que a fase é concluída
var companion_unlock_chapter: int = 1  # concluir esse capítulo libera o espaço da nave auxiliar
var shield_color: Color = Color(0.4, 0.85, 1.0)
var shield_ring_scale: float = 0.62  # raio do anel do escudo em relação à altura da nave
var shield_ring_width: float = 6.0
var shield_gap_degrees: float = 18.0

# --- Power-ups ---
var powerup_every_kills: int = 8  # 1 power-up a cada N inimigos destruídos
var medkit_every_kills: int = 13  # 1 medkit a cada N inimigos destruídos (mais raro)
var medkit_heal: int = 1  # hits recuperados
var medkit_color: Color = Color(0.3, 0.9, 0.45)
var powerup_pool_size: int = 12  # power-ups e medkits
var powerup_fall_speed: float = 150.0  # px/s
var powerup_radius: float = 30.0
var powerup_pickup_radius: float = 60.0  # a partir do centro da nave
var powerup_color: Color = Color(1.0, 0.85, 0.3)
var powerup_spin_speed: float = 2.5  # rad/s
var powerup_pulse: float = 0.12  # variação de escala
var powerup_pulse_speed: float = 6.0
