extends Node
## Parâmetros ajustáveis do jogo. Único lugar para valores de tuning.

# --- Tela / debug ---
var background_color: Color = Color(0.04, 0.04, 0.08)
var debug_overlay_enabled: bool = true
var debug_font_size: int = 40

# --- Câmera lenta ---
var slow_time_scale: float = 0.3
var time_scale_smooth_seconds: float = 0.1  # duração da transição, em tempo real

# --- Nave ---
var ship_speed: float = 3000.0  # px/s máximos (escalado pelo time scale)
var drag_sensitivity: float = 1.0  # 1.0 = nave anda o mesmo que o dedo
var ship_size: Vector2 = Vector2(90.0, 110.0)
var ship_color: Color = Color(0.4, 0.85, 1.0)
var ship_start_bottom_offset: float = 300.0  # distância da base da tela

# --- Tiro ---
var fire_rate: float = 10.0  # tiros por segundo
var bullet_speed: float = 2200.0  # px/s
var bullet_size: Vector2 = Vector2(10.0, 36.0)
var bullet_color: Color = Color(1.0, 0.95, 0.5)
var bullet_pool_size: int = 64
