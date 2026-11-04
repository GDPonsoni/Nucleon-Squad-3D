extends Node
## Autoload: efeitos sonoros, barramentos de volume e idioma.
## Os sons ficam em assets/audio/sfx/<nome>.wav; o ganho de cada um (Params.sfx_gain_db)
## nivela o volume entre eles. Barramentos: SFX e Música, ambos ligados ao Master.
## Música: ainda não há faixas; play_music() já usa o barramento e o volume da configuração.

const SFX_PATH: String = "res://assets/audio/sfx/%s.wav"
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"

var _streams: Dictionary = {}  # nome -> AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}  # nome -> ms do último disparo
var _next_voice: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	# Continua tocando com o jogo pausado (resultados, menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	for sound: StringName in Params.sfx_gain_db:
		var stream := load(SFX_PATH % sound) as AudioStream
		if stream == null:
			push_warning("Som não encontrado: %s" % sound)
			continue
		_streams[sound] = stream
	for i in Params.sfx_voices:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	SaveGame.settings_changed.connect(apply_settings)
	apply_settings()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


## Volumes e idioma vindos das configurações salvas.
func apply_settings() -> void:
	_set_bus_volume(&"Master", float(SaveGame.setting("master")))
	_set_bus_volume(SFX_BUS, float(SaveGame.setting("sfx")))
	_set_bus_volume(MUSIC_BUS, float(SaveGame.setting("music")))
	TranslationServer.set_locale(resolve_locale(String(SaveGame.setting("language"))))


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


## "auto" segue o idioma do aparelho (português ou inglês).
static func resolve_locale(language: String) -> String:
	if language == "auto":
		return "pt_BR" if OS.get_locale().begins_with("pt") else "en"
	return language


## Toca um efeito. extra_db soma ao ganho do som; pitch muda o tom (além da variação aleatória).
func play(sound: StringName, extra_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var now: int = Time.get_ticks_msec()
	var gap_ms: float = float(Params.sfx_min_gap.get(sound, 0.0)) * 1000.0
	if now - int(_last_play.get(sound, -1000000)) < gap_ms:
		return
	_last_play[sound] = now
	var voice: AudioStreamPlayer = _free_voice()
	voice.stream = stream
	voice.volume_db = float(Params.sfx_gain_db.get(sound, 0.0)) + extra_db
	voice.pitch_scale = pitch * (1.0 + randf_range(-Params.sfx_pitch_jitter, Params.sfx_pitch_jitter))
	voice.play()


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	# Todas ocupadas: reaproveita a mais antiga
	_next_voice = (_next_voice + 1) % _voices.size()
	return _voices[_next_voice]


## Música de fundo em loop (sem faixas por enquanto).
func play_music(stream: AudioStream) -> void:
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	if stream != null:
		_music.play()


## Som do botão: voltar, confirmar ou clique comum, conforme o texto dele.
func ui_press(text_key: String) -> void:
	match text_key:
		"MENU_BACK", "PAUSE_RESUME", "REVIVE_SKIP":
			play(&"ui_back")
		"MENU_PLAY", "SQUAD_SAVE", "STAGE_NEXT", "GAMEOVER_RETRY", "REVIVE_WATCH":
			play(&"ui_confirm")
		_:
			play(&"ui_click")


## Som do disparo de cada tipo de arma.
func shot(kind: WeaponData.Kind, extra_db: float = 0.0) -> void:
	match kind:
		WeaponData.Kind.SPREAD:
			play(&"shot_spread", extra_db)
		WeaponData.Kind.BOUNCE:
			play(&"shot_spread", extra_db, 1.3)
		WeaponData.Kind.PIERCE:
			play(&"shot_spread", extra_db + 1.0, 0.7)
		WeaponData.Kind.BLAST:
			play(&"shot_missile", extra_db, 0.75)
		WeaponData.Kind.HOMING:
			play(&"shot_missile", extra_db)
		WeaponData.Kind.BEAM:
			play(&"shot_beam", extra_db)
		WeaponData.Kind.CHAIN:
			play(&"shot_beam", extra_db, 1.6)
		WeaponData.Kind.ORBIT:
			play(&"shot_orbit", extra_db)


## Explosão de inimigo: pequena ou média conforme o raio.
func explosion(radius: float) -> void:
	if radius >= Params.explosion_reference_radius * 1.4:
		play(&"enemy_explode_medium")
	else:
		play(&"enemy_explode_small")


## Vibração do aparelho (se ligada nas configurações). ms = duração; mais longa = mais forte.
func vibrate(ms: int = Params.vibration_ms) -> void:
	if bool(SaveGame.setting("vibration")):
		Input.vibrate_handheld(ms)
