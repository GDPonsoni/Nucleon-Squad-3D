extends Node
## Parâmetros ajustáveis do jogo. Único lugar para valores de tuning.

## Ritmo e economia (vida dos inimigos, drops, duração, carga do especial): data/balance.tres.
var balance: BalanceData = load("res://data/balance.tres") as BalanceData

# --- Áudio e configurações (ganho de cada som em dB: nivela o volume entre eles) ---
var sfx_voices: int = 20  # sons ao mesmo tempo
var music_menu_path: String = "res://assets/audio/music/menu.wav"
var music_chapter_path: String = "res://assets/audio/music/chapter_%d.wav"
var music_volume_db: float = -14.0  # a música fica bem abaixo dos efeitos
var music_silent_db: float = -40.0
var music_fade_seconds: float = 0.6
var music_clear_path: String = "res://assets/audio/music/clear.wav"  # fim de fase
var music_clear_fade_seconds: float = 1.5
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
	&"missile_explode": 0.08, &"boss_warning": 0.12, &"ui_click": 0.04, &"slowmo_enter": 0.15, &"slowmo_exit": 0.15,
}
var sfx_pitch_jitter: float = 0.06  # variação aleatória de tom
var companion_sound_db: float = -8.0  # a nave auxiliar soa mais baixo
var default_settings: Dictionary = {
	"master": 1.0, "music": 0.7, "sfx": 0.8, "vibration": true, "haptic_level": 1, "reduced_effects": false, "language": "auto",
	"show_stats": true, "tips_enabled": true, "damage_numbers": true,
}
# Contador de dano
var damage_number_pool_size: int = 40
var damage_number_window: float = 0.2  # acertos no mesmo alvo dentro dessa janela viram um número
var damage_number_seconds: float = 0.8
var damage_number_rise_speed: float = 110.0  # px/s
var damage_number_font_size: int = 34
var damage_number_font_bonus: int = 22  # quanto o número cresce com dano alto, no máximo
# Tutorial e avisos (tempo real)
var tips_path: String = "res://data/tutorial/tips.json"
var tip_gap_match_seconds: float = 0.4  # intervalo mínimo entre dicas na partida (cada uma na 1ª vez do evento)
var tip_gap_screen_seconds: float = 1.2  # idem nas telas
var tip_first_delay_seconds: float = 2.5  # espera antes da 1ª dica de uma tela
var tip_first_delay_match_seconds: float = 0.8  # na partida: só o tempo da cena aparecer
var tip_spotlight_layer: int = 55  # acima da pausa (50), abaixo do resultado (60)
var tip_spot_padding: float = 1.7  # recorte em volta de um elemento: raio dele x isso
var tip_spot_min_radius: float = 70.0
var tip_spot_default_radius: float = 60.0
var tip_spot_rect_margin: float = 16.0  # recorte em volta de botões e barras
var tip_card_width_ratio: float = 0.86
var tip_card_font_size: int = 44
var tip_card_gap: float = 90.0  # entre o recorte e o card
var tip_highlight_color: Color = Color(1.0, 0.85, 0.3)
var tip_unlock_gap_seconds: float = 0.4  # entre dois avisos de desbloqueio
var tip_end_max: int = 2  # dicas por fim de fase
var tip_expire_seconds: float = 40.0  # dica de partida que não pôde aparecer (outra janela aberta) sai da fila
var unlock_icon_size: float = 220.0  # nave no aviso de desbloqueio
var languages: PackedStringArray = ["auto", "pt_BR", "en", "es"]
var ad_quarks_base: int = 80  # quarks por anúncio assistido (cerca de uma fase concluída)
var ad_quarks_per_chapter: int = 40  # a mais por capítulo concluído
var ad_quarks_daily_limit: int = 5
var banner_height_dp: float = 90.0  # banner do menu inicial: cabe o padrão (50 dp) e o adaptativo do AdMob
var banner_fallback_dpi: float = 420.0  # densidade usada fora do Android (S24 ~ 2,6 px por dp)
var dialog_width_ratio: float = 0.92  # largura do diálogo em relação à tela
var dialog_height_ratio: float = 0.92  # altura máxima do diálogo (passando disso, o corpo rola)
var dialog_close_size: float = 144.0  # botão X (>= 48 dp no S24)
var dialog_close_overhang: float = 0.0  # quanto o X sai do canto do painel
var dialog_close_icon_ratio: float = 0.13  # tamanho do X dentro da área de toque
var dialog_spacing: int = 28
var dialog_layer: int = 100
var icon_caption_font_size: int = 30  # legenda sob os botões de ícone
var icon_caption_min_width: float = 190.0
var pause_spacing: int = 90  # entre continuar e as ações
var pause_resume_size: float = 300.0  # botão de continuar da pausa
var pause_action_size: float = 150.0  # reiniciar, configurações, sair
var settings_panel_width: float = 860.0
var settings_compact_button_height: float = 110.0
var settings_icon_size: float = 104.0  # ícone à esquerda de cada controle
var settings_tile_size: float = 150.0  # interruptores (vibração, efeitos, estatísticas)
var toggle_on_color: Color = Color(0.3, 0.85, 0.5)
var quark_badge_height: float = 92.0
var quark_badge_font_size: int = 48
var quark_badge_count_seconds: float = 0.8
var button_press_scale: float = 0.94  # botão afunda ao tocar
var button_press_seconds: float = 0.06
# Paginação lateral (PagedView)
var pager_slop: float = 24.0  # px antes de decidir se o gesto é arrasto lateral
var pager_horizontal_bias: float = 1.2  # |dx| precisa passar |dy| x isto
var pager_snap_ratio: float = 0.5  # passou dessa fração da largura = muda de página
var pager_flick_velocity: float = 900.0  # px/s: gesto rápido muda de página
var pager_flick_min_distance: float = 60.0  # px mínimos andados para o gesto rápido valer
var pager_velocity_smoothing: float = 0.35
var pager_edge_resistance: float = 0.3  # arrasto além da primeira/última página
var pager_snap_seconds: float = 0.3
var pager_flick_snap_scale: float = 0.7  # encaixe mais curto depois de um gesto rápido
var chapter_art_size: Vector2 = Vector2(900.0, 300.0)
var reduced_explosion_shards: int = 5
var reduced_slowmo_intensity: float = 0.45
var settings_slider_width: float = 800.0  # cabe dentro do diálogo (~900 de conteúdo)
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
var squad_columns: int = 4
var squad_cell_width: float = 230.0  # célula da grade de naves
var squad_cell_icon_size: float = 170.0
var squad_cell_name_font_size: int = 34
var squad_info_touch_size: float = 100.0  # botão ⓘ: área de toque (o desenho é menor)
var squad_info_icon_radius: float = 22.0
var squad_fly_seconds: float = 0.28  # nave voando entre a grade e a vaga
var squad_pop_scale: float = 1.25
var squad_shake_px: float = 10.0  # balanço ao recusar
var squad_hint_flash_seconds: float = 2.2
var squad_chosen_alpha: float = 0.4  # nave já escolhida fica apagada na grade
var squad_slot_size: float = 150.0
var squad_hint_width: float = 900.0
var squad_hint_font_size: int = 38
var squad_slot_label_font_size: int = 30  # rótulos embaixo das vagas (1..4, Auxiliar)
var squad_button_size: Vector2 = Vector2(420.0, 140.0)
var back_corner_size: Vector2 = Vector2(104.0, 104.0)  # seta de voltar no canto superior esquerdo
var back_corner_margin: Vector2 = Vector2(24.0, 48.0)
var back_top_space: float = 150.0  # espaço no topo das telas para a seta não cobrir o conteúdo
var back_top_space_squad: float = 0.0  # a tela do esquadrão é a mais cheia
# Seletor: mapa do planeta
var stage_sheet_star_size: float = 96.0
var stage_header_star_size: float = 40.0
var stage_node_size: float = 180.0
var stage_node_boss_scale: float = 1.3
var stage_map_margin_top: float = 200.0  # topo do caminho (chefe) até a borda da página
var stage_map_margin_bottom: float = 170.0
var stage_map_step: float = 300.0  # distância vertical entre fases seguidas (o mapa rola)
var stage_map_art_gap: float = 40.0  # folga entre a arte do planeta e o chefe
var stage_map_wave_speed: float = 1.15  # rapidez da onda do caminho (rad por fase)
var stage_map_hue_span: float = 0.18  # variação de matiz entre a primeira e a última fase
var stage_map_sway: float = 0.30  # alcance lateral máximo dos nós (fração da largura)  # amplitude lateral do caminho (fração da largura)
var stage_map_dust: int = 36  # estrelinhas de fundo no mapa
var stage_map_art_alpha: float = 0.45
var stage_map_art_top: float = 10.0
var stage_header_name_width: float = 700.0  # o nome do capítulo encolhe para caber
var stage_chapter_font_size: int = 72
var stage_dot_spacing: float = 56.0  # bolinhas indicando o capítulo aberto
var stage_soon_color: Color = Color(0.6, 0.65, 0.8)  # página "novos capítulos em breve"
var stage_soon_planet_radius: float = 150.0
var stage_soon_text_width: float = 820.0
var stage_dot_radius: float = 11.0
var results_column_gap: int = 60
var results_spacing: int = 22  # entre os itens da tela de resultado
var results_detail_font_size: int = 30
var results_main_size: float = 260.0  # botão principal (próxima fase / jogar de novo)
var results_action_size: float = 150.0  # ações menores
var results_stats_font_size: int = 40
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
var upgrade_detail_width: float = 900.0
var upgrade_detail_spacing: int = 14
var upgrade_name_font_size: int = 56
var upgrade_detail_font_size: int = 36
var upgrade_buy_height: float = 130.0
var upgrade_buy_font_size: int = 46
var debug_quarks_grant: int = 5000  # botão de teste "dar quarks" (build de debug)
var debug_unlock_taps: int = 5  # toques no título do seletor (build de debug)
var ui_enter_seconds: float = 0.45  # entrada dos menus
var ui_enter_offset: float = 60.0
var menu_ship_y_ratio: float = 0.15  # altura da nave decorativa no menu
var menu_title_gap: float = 30.0  # entre a nave decorativa e o conteúdo do menu
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
# Custo da câmera lenta: as armas não atiram nela e uma energia esvazia (tempo real) enquanto
# ela dura; com o dedo na tela, a energia recarrega. Vazia = volta à velocidade normal.
var slowmo_holds_fire: bool = true
var slowmo_energy_seconds: float = 3.0  # duração da câmera lenta com a energia cheia (tempo real)
var slowmo_recharge_seconds: float = 6.0  # dedo na tela por tanto tempo enche a energia do zero
var slowmo_min_energy: float = 0.15  # abaixo disso, soltar o dedo não ativa a câmera lenta
var slowmo_max_frame_seconds: float = 0.1  # ignora saltos de tempo real (pausa, app em segundo plano)
var slowmo_bar_size: Vector2 = Vector2(420.0, 14.0)
var slowmo_bar_gap: float = 125.0  # acima do centro da barra de troca
var slowmo_bar_color: Color = Color(0.45, 0.75, 1.0)
var slowmo_bar_low_color: Color = Color(1.0, 0.45, 0.4)  # abaixo do mínimo
var slowmo_bar_bg_color: Color = Color(0.04, 0.05, 0.1, 0.6)
var slowmo_bar_fade_seconds: float = 0.25  # some depois de cheia (tempo real)

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
# --- Animações de nave (entrada, saída por troca, quebra) ---
var anim_intensity: float = 1.0  # multiplica deslocamentos e brilhos de todas as animações de nave (0 = sem)
var entry_start_scale: float = 0.0  # o corpo novo nasce do núcleo e cresce
var entry_glow_alpha: float = 0.75  # brilho branco no meio da entrada
var entry_ring_scale: float = 1.9  # anel que converge para a nave (x altura da nave)
var body_fx_pool_size: int = 8
var weapon_spawn_seconds: float = 0.35  # surgimento da arma ao ativar (curto, para não atrapalhar)
var weapon_spawn_orbit_spin: float = 2.5  # a órbita gira mais rápido enquanto se forma (multiplicador)
var weapon_charge_orb_scale: float = 0.45  # orbe de carga na ponta (x largura da nave)
# --- Rochas e fraquezas ---
var rock_points: int = 9  # vértices do contorno
var rock_roughness: float = 0.85  # raio mínimo de cada vértice (x raio); o máximo passa um pouco do raio de colisão
var weakness_flash_threshold: float = 1.2  # multiplicador a partir do qual o acerto pisca dourado
var weakness_flash_color: Color = Color(1.0, 0.85, 0.3)
var resist_flash_threshold: float = 0.8  # abaixo disso, pisca cinza (arma fraca contra ele)
var resist_flash_color: Color = Color(0.55, 0.55, 0.6)
var shield_block_flash_seconds: float = 0.15
var enemy_shield_color: Color = Color(0.45, 0.8, 1.0, 0.9)
var enemy_shield_width: float = 10.0
var regen_color: Color = Color(0.35, 1.0, 0.5, 0.9)
# --- Momentos de especial ---
var special_moment_armor: float = 0.1  # dano normal contra alvos blindados (o especial quebra a blindagem)
var special_moment_color: Color = Color(1.0, 0.82, 0.25)
var special_moment_blink_hz: float = 2.5
# --- Telegrafia (aviso antes de cada ataque inimigo) ---
var telegraph_line_length: float = 520.0  # linha tracejada na direção do tiro
var telegraph_line_width: float = 4.0
var telegraph_dash: float = 22.0
var telegraph_alpha: Vector2 = Vector2(0.15, 0.7)  # transparência no começo e no fim do aviso
var telegraph_ring_scale: float = 1.8  # anel que se contrai no inimigo (x raio)
var telegraph_big_radius: float = 30.0  # tiros com raio >= isso avisam com um orbe crescendo
var telegraph_sound_db: float = -4.0
var telegraph_dive_color: Color = Color(1.0, 0.25, 0.2)
var telegraph_gap_color: Color = Color(0.4, 1.0, 0.6)  # brecha segura da cortina
# --- Pseudo-3D no movimento (só transformações 2D; tilt_intensity 0 desliga) ---
var tilt_intensity: float = 1.0
var tilt_max_roll: float = 0.30  # rad de inclinação lateral na velocidade máxima
var tilt_squash: float = 0.16  # afina o corpo no eixo X ao virar
var tilt_pitch_stretch: float = 0.10  # alonga/encurta no eixo Y ao subir/descer
var tilt_brightness: float = 0.14  # clareia ao subir, escurece ao descer
var tilt_smooth_rate: float = 9.0  # quão rápido segue o movimento e volta ao repouso (1/s)
var ship_shadow_offset: Vector2 = Vector2(10.0, 22.0)  # sombra no repouso
var ship_shadow_shift: float = 16.0  # a sombra desliza para o lado oposto da inclinação
var ship_shadow_alpha: float = 0.32
var companion_tilt_share: float = 0.8  # fração da inclinação da nave principal que a auxiliar copia
var impact_pool_size: int = 40  # faíscas de acerto (todas as armas)
var impact_seconds: float = 0.22
var impact_sparks: int = 5
var impact_reduced_sparks: int = 2
var impact_spark_speed: float = 260.0
var impact_spark_length: float = 14.0
var muzzle_flash_seconds: float = 0.09  # clarão na ponta a cada tiro
var muzzle_flash_scale: float = 0.3  # x largura da nave
var missile_flame_length: float = 1.1  # chama dos mísseis (x altura do míssil)
var orbit_trail_radians: float = 0.7  # rastro atrás de cada esfera da órbita
var beam_impact_scale: float = 1.2  # brilho no ponto onde o raio acerta (x largura do raio)
var exit_seconds: float = 0.3  # saída por troca voluntária: o corpo recolhe de volta para o núcleo
var exit_spin: float = 2.5  # rad de giro enquanto recolhe (x intensidade)
var break_seconds: float = 0.75  # perda: o corpo se parte em pedaços que giram e somem
var break_speed_min: float = 160.0
var break_speed_max: float = 420.0
var break_spin_max: float = 7.0  # rad/s
var break_gravity: float = 380.0  # os pedaços caem um pouco
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
# Invulnerabilidade e recarga da troca contam em TEMPO DE JOGO (escalam com a câmera lenta):
# a 30% da velocidade, 1 s de jogo = ~3,3 s reais, mas cobre o mesmo avanço dos tiros.
var switch_invulnerability_seconds: float = 1.0  # testar até ~0,5 (o corpo reconstruindo também protege: body_rebuild_seconds)
var switch_cooldown_seconds: float = 4.0  # entre trocas voluntárias (faixa sugerida: 3 a 5)
var switch_cooldown_color: Color = Color(0.0, 0.0, 0.0, 0.62)  # setor escuro sobre os ícones em recarga
var switch_icon_radius: float = 82.0
var switch_icon_max_spacing_ratio: float = 0.36  # com muitos corpos, o raio diminui para caber
var no_switcher_bottom_margin: float = 170.0  # sem barra de troca: espaço livre na base (botão especial)
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
var companion_retreat_offset: Vector2 = Vector2(34.0, 18.0)  # sem nave principal, recolhe para junto do núcleo
var companion_retreat_scale: float = 0.6
var companion_retreat_rate: float = 4.5  # quão rápido sai/volta da formação (1/s)
var companion_roll: float = 0.5  # rad de inclinação durante o voo de saída/retorno (x intensidade)
var companion_arrive_pulse_seconds: float = 0.3

# --- Projéteis do jogador ---
var player_bullet_pool_size: int = 160

# --- Inimigos e fase (tipos e ondas ficam em data/) ---
var campaign_path: String = "res://data/campaign.tres"
var stage_clear_timeout: float = 6.0  # após o tempo da fase, espera no máximo isso pelos inimigos restantes
## Fim de fase: pausa -> nave sai da tela -> resultado (tempo real, imune a dano o tempo todo).
var clear_pause_seconds: float = 1.6  # depois do último inimigo/chefe, antes da nave partir
var clear_ship_center_seconds: float = 0.5  # nave vai ao centro da tela
var clear_ship_exit_seconds: float = 1.4  # acelera para cima e sai da tela
var clear_results_delay: float = 0.5  # após a nave sair, antes do resultado
var clear_ship_exit_margin: float = 3.0  # quantas alturas de nave acima do topo
var clear_wipe_gap: float = 0.04  # segundos entre as explosões que limpam os inimigos restantes
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

# --- Inspeção da nave (tela de esquadrão): demonstração ao vivo da arma ---
var inspect_demo_height_ratio: float = 0.78  # altura da demonstração em relação à largura
var inspect_demo_background: Color = Color(0.03, 0.04, 0.08)
var inspect_demo_sound_db: float = -14.0
var inspect_bullet_pool_size: int = 120
var inspect_target_small: String = "res://data/enemies/drone.tres"
var inspect_target_big: String = "res://data/enemies/tank.tres"
var inspect_target_positions: PackedVector2Array = [  # fração da área da demonstração
	Vector2(0.2, 0.18), Vector2(0.5, 0.12), Vector2(0.8, 0.18), Vector2(0.35, 0.36), Vector2(0.65, 0.36), Vector2(0.15, 0.6),
]
var inspect_big_target_index: int = 1
var inspect_ship_position: Vector2 = Vector2(0.5, 0.8)  # fração da área da demonstração
var inspect_icon_size: float = 210.0  # nave grande no topo da inspeção
var inspect_target_sway: float = 40.0
var inspect_target_sway_speed: float = 1.3
var inspect_level_button_size: float = 96.0
var inspect_mode_button_height: float = 110.0
var inspect_special_refill_seconds: float = 0.8  # recarga do especial na demonstração (tempo real)
var inspect_special_margin: float = 24.0  # botão do especial no canto da demonstração
var inspect_locked_icon_scale: float = 1.4
var inspect_text_font_size: int = 36

# --- Especial (valores de cada arma ficam em data/weapons/) ---
var special_ready_epsilon: float = 0.001  # segundos de folga ao comparar a carga (precisão de 32 bits)
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
# A renda vem sobretudo de concluir fases e ganhar estrelas (cresce por capítulo e não depende
# de quantos inimigos a fase tem). Meta: 1º nível de vários nós no cap. 1 e a árvore com limite
# completa por volta do fim do cap. 4 (test_quark_economy confere).
var quarks_per_point: float = 0.01  # quarks por ponto de pontuação (inimigos e chefes): só um extra
var quarks_stage_clear: PackedInt32Array = [60, 90, 120, 160, 200]  # bônus por concluir uma fase, por capítulo
var quarks_first_clear_multiplier: float = 2.0  # o bônus dobra na primeira vez que a fase é concluída
var quarks_per_new_star: PackedInt32Array = [30, 45, 60, 80, 100]  # por estrela nova na fase, por capítulo
var quarks_empty_slot_bonus: float = 0.25  # bônus de conclusão +25% por vaga vazia no esquadrão
var powerup_overflow_points: int = 50  # power-up com a arma no nível máximo vira pontos
var medkit_overflow_points: int = 50  # kit médico com o corpo sem dano vira pontos
var companion_unlock_chapter: int = 2  # concluir esse capítulo libera o espaço da nave auxiliar
var shield_color: Color = Color(0.4, 0.85, 1.0)
var shield_ring_scale: float = 0.62  # raio do anel do escudo em relação à altura da nave
var shield_ring_width: float = 6.0
var shield_gap_degrees: float = 18.0

# --- Power-ups ---
var medkit_heal: int = 1  # hits recuperados
var medkit_color: Color = Color(0.3, 0.9, 0.45)
var companion_powerup_color: Color = Color(0.72, 0.55, 1.0)  # lilás, a cor da auxiliar na tela de esquadrão
var companion_level_pip_size: Vector2 = Vector2(14.0, 6.0)  # nível da auxiliar, embaixo dela
var hud_toast_font_size: int = 50
var hud_toast_y: float = 0.36  # fração da altura da tela
var hud_toast_seconds: float = 1.8  # tempo real
var powerup_pool_size: int = 12  # power-ups e medkits

# --- Modo roguelike (regras em data/run/run_mode.tres) ---
var run_mode_path: String = "res://data/run/run_mode.tres"
var run_unlock_chapter: int = 1  # concluir esse capítulo libera o modo no menu
var locked_button_alpha: float = 0.5  # botão de algo ainda travado
var mode_card_height: float = 760.0  # cards da escolha de modo
var mode_card_radius: float = 28.0
var mode_card_gap: int = 48
var mode_card_side_margin: float = 60.0
var mode_card_title_size: int = 64
var mode_card_text_size: int = 38
var xp_orb_pool_size: int = 160
var xp_orb_radius: float = 13.0
var xp_orb_color: Color = Color(0.4, 1.0, 0.75)
var xp_orb_burst_up: float = 260.0  # pulinho ao nascer (px/s)
var xp_orb_burst_side: float = 140.0
var xp_orb_settle_accel: float = 700.0  # px/s² até a queda lenta
var run_time_top: float = 250.0  # tempo de partida, embaixo do botão de pausa
var run_xp_color: Color = Color(0.4, 1.0, 0.75)
var run_hud_font_size: int = 40
var run_card_height: float = 190.0  # cartas da tela de subir de nível
var run_card_icon_size: float = 140.0
var run_card_font_size: int = 46
var run_card_detail_font_size: int = 38
var run_slot_size: float = 130.0  # espaços de arma (pausa e tela de nível)
var run_slot_compact_size: float = 96.0  # espaços na câmera lenta
var run_slot_touch_margin: float = 24.0  # área de toque um pouco maior que o ícone
var run_slot_gap: int = 40  # entre os espaços de arma
var elite_color: Color = Color(1.0, 0.75, 0.25)
var boss_drop_accel: float = 3200.0  # px/s² do chefe que despenca na entrada
var boss_impact_seconds: float = 0.7  # onda de impacto (entrada e investida)
var boss_charge_depth: float = 0.68  # investida vai até essa fração da altura da tela
var boss_title_seconds: float = 2.2  # nome do chefe grande na tela ao terminar a entrada
var boss_title_font_size: int = 96
var chest_color: Color = Color(1.0, 0.8, 0.3)
var chest_scale: float = 1.35  # baú maior que os outros itens
var run_slow_loadout_bottom: float = 165.0  # topo dos espaços na câmera lenta, a partir da base (faixa sem nave)
var run_energy_bar_bottom: float = 26.0  # barra de energia da câmera lenta, na mesma faixa
var run_slow_loadout_fade_seconds: float = 0.2
var run_slot_pip_size: Vector2 = Vector2(18.0, 8.0)  # nível da arma, embaixo do espaço
var run_slot_empty_color: Color = Color(1.0, 1.0, 1.0, 0.25)
var powerup_fall_speed: float = 150.0  # px/s
var powerup_radius: float = 30.0
var powerup_pickup_radius: float = 60.0  # a partir do centro da nave
var powerup_color: Color = Color(1.0, 0.85, 0.3)
var powerup_spin_speed: float = 2.5  # rad/s
var powerup_pulse: float = 0.12  # variação de escala
var powerup_pulse_speed: float = 6.0


# --- Vibração (Haptics): padrões = lista de [duração_ms, intensidade 0..1]; intensidade 0 = pausa ---
var haptic_amplitude_supported: bool = true  # false = simula intensidade com pulsos (duração x intervalo)
var haptic_levels: PackedFloat32Array = [0.55, 0.8, 1.0]  # baixa, média, alta (multiplica a intensidade)
var haptic_min_gap_ms: int = 35  # intervalo mínimo entre dois padrões quaisquer
var haptic_max_pattern_ms: int = 700  # nenhum padrão passa disso
var haptic_budget_window_ms: int = 1000  # janela para limitar o tempo total de motor ligado
var haptic_budget_max_ms: int = 380  # acima disso, só padrões de prioridade >= haptic_budget_priority
var haptic_budget_priority: int = 3
var haptic_pwm_period_ms: int = 48  # só no modo simulado: período de cada pulso
var haptic_boss_window: float = 0.25  # segundos acumulando dano ao chefe antes de vibrar
var haptic_boss_tiers: PackedFloat32Array = [0.004, 0.015, 0.04]  # fração da vida do chefe na janela: leve, médio, forte
var haptic_boss_tier_names: Array[StringName] = [&"dano_boss_leve", &"dano_boss_medio", &"dano_boss_forte"]
var haptic_patterns: Dictionary = {
	# nome: {prioridade, intervalo mínimo (s) entre repetições, passos}
	&"tick": {"priority": 0, "cooldown": 0.05, "steps": [[16, 0.5]]},
	&"tiro_forte": {"priority": 1, "cooldown": 0.12, "steps": [[16, 1.0], [32, 0.0], [16, 0.35]]},
	&"nivel_arma": {"priority": 2, "cooldown": 0.2, "steps": [[16, 0.5], [32, 0.0], [32, 0.85]]},
	&"explosao_pequena": {"priority": 1, "cooldown": 0.12, "steps": [[16, 0.5], [16, 0.3], [16, 0.15]]},
	&"explosao_grande": {"priority": 3, "cooldown": 0.2, "steps": [[16, 0.4], [32, 0.7], [48, 1.0], [48, 0.7], [64, 0.45], [80, 0.25], [80, 0.12]]},
	&"dano_boss_leve": {"priority": 1, "cooldown": 0.0, "steps": [[16, 0.35]]},
	&"dano_boss_medio": {"priority": 1, "cooldown": 0.0, "steps": [[16, 0.6], [16, 0.35]]},
	&"dano_boss_forte": {"priority": 2, "cooldown": 0.0, "steps": [[32, 1.0], [32, 0.6], [16, 0.3]]},
	&"dano_jogador": {"priority": 3, "cooldown": 0.1, "steps": [[48, 1.0], [32, 0.0], [32, 0.6]]},
	&"troca_nave": {"priority": 2, "cooldown": 0.2, "steps": [[16, 0.6], [48, 0.0], [32, 1.0]]},
	&"especial": {"priority": 3, "cooldown": 0.3, "steps": [[32, 0.2], [32, 0.4], [48, 0.6], [48, 0.8], [112, 1.0], [80, 0.5]]},
	&"perda_nave": {"priority": 4, "cooldown": 0.3, "steps": [[48, 1.0], [48, 0.0], [32, 0.8], [32, 0.0], [128, 0.65], [96, 0.4], [80, 0.2]]},
	&"explosao_chefe": {"priority": 4, "cooldown": 0.3, "steps": [[32, 0.4], [32, 0.0], [48, 0.7], [32, 0.0], [80, 1.0], [128, 0.9], [144, 0.6], [160, 0.3]]},
	&"momento_especial": {"priority": 3, "cooldown": 1.0, "steps": [[32, 0.6], [48, 0.0], [32, 0.6], [48, 0.0], [64, 1.0]]},
	&"fase_completa": {"priority": 3, "cooldown": 0.3, "steps": [[32, 0.6], [48, 0.0], [32, 0.8], [48, 0.0], [96, 1.0], [80, 0.4]]},
}
