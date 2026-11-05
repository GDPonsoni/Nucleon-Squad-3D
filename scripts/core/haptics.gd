extends Node
## Feedback tátil por padrões nomeados (Params.haptic_patterns): sequências de
## (duração em ms, intensidade 0..1). No Android, Input.vibrate_handheld aceita amplitude
## (API 26+, se o motor tiver controle de amplitude); sem amplitude, a intensidade é
## simulada com pulsos (Params.haptic_amplitude_supported = false).
## Cada chamada nativa substitui a anterior, então os passos são disparados daqui, em
## tempo real (ignora a câmera lenta). Há prioridade, intervalo por padrão, intervalo
## global e um orçamento de tempo de motor ligado por janela, para nunca vibrar sem parar.

var _steps: Array = []  # passos em execução: [ms, intensidade]
var _index: int = 0
var _step_end_ms: int = 0
var _priority: int = -1
var _last_end_ms: int = 0
var _last_played: Dictionary = {}  # nome -> ticks_msec
var _spent: Array = []  # [ticks_msec, ms de motor] dentro da janela do orçamento
var _boss_accum: float = 0.0
var _boss_window_end_ms: int = 0


func _ready() -> void:
	set_process(false)


## Dispara um padrão. Devolve true se começou a tocar.
func play(pattern: StringName) -> bool:
	if not enabled() or not Params.haptic_patterns.has(pattern):
		return false
	var def: Dictionary = Params.haptic_patterns[pattern]
	var now: int = Time.get_ticks_msec()
	var priority: int = def["priority"]
	if now - int(_last_played.get(pattern, -100000)) < int(float(def["cooldown"]) * 1000.0):
		return false
	if _playing(now):
		# Padrão mais fraco não interrompe um mais forte
		if priority < _priority:
			return false
	elif now - _last_end_ms < Params.haptic_min_gap_ms:
		return false
	var flat: Array = _build_steps(def["steps"])
	var total: int = _motor_ms(flat)
	if priority < Params.haptic_budget_priority and _budget_used(now) + total > Params.haptic_budget_max_ms:
		return false
	_spent.append([now, total])
	_last_played[pattern] = now
	_steps = flat
	_index = 0
	_priority = priority
	_step_end_ms = now
	set_process(true)
	_advance(now)
	return true


## Dano ao chefe: acumula uma janela curta e vibra uma vez, com a faixa pelo dano total.
## fraction = dano / vida máxima do chefe.
func boss_damage(fraction: float) -> void:
	if not enabled():
		return
	var now: int = Time.get_ticks_msec()
	if _boss_accum <= 0.0:
		_boss_window_end_ms = now + int(Params.haptic_boss_window * 1000.0)
	_boss_accum += fraction
	set_process(true)


func enabled() -> bool:
	return bool(SaveGame.setting("vibration"))


## Cancela o que estiver tocando (ex.: ao pausar).
func stop() -> void:
	_steps.clear()
	_priority = -1
	_boss_accum = 0.0


func level_scale() -> float:
	var level: int = clampi(int(SaveGame.setting("haptic_level")), 0, Params.haptic_levels.size() - 1)
	return Params.haptic_levels[level]


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _boss_accum > 0.0 and now >= _boss_window_end_ms:
		_flush_boss()
	if _playing(now):
		_advance(now)
	elif _boss_accum <= 0.0:
		set_process(false)


func _flush_boss() -> void:
	var tier: int = -1
	for i in Params.haptic_boss_tiers.size():
		if _boss_accum >= Params.haptic_boss_tiers[i]:
			tier = i
	_boss_accum = 0.0
	if tier >= 0:
		play(Params.haptic_boss_tier_names[tier])


func _playing(now: int) -> bool:
	return _index < _steps.size() or now < _step_end_ms


## Passa para o passo atual conforme o relógio (se atrasou vários, pula para o último).
func _advance(now: int) -> void:
	while _index < _steps.size() and now >= _step_end_ms:
		var step: Array = _steps[_index]
		_index += 1
		_step_end_ms += int(step[0])
		# Atrasado: só toca o passo se ainda estiver nele
		if now < _step_end_ms:
			_vibrate(int(step[0]), float(step[1]))
	if _index >= _steps.size() and now >= _step_end_ms:
		_last_end_ms = now
		_priority = -1


func _vibrate(ms: int, intensity: float) -> void:
	if intensity <= 0.0:
		return
	var amplitude: float = clampf(intensity * level_scale(), 0.05, 1.0)
	Input.vibrate_handheld(ms, amplitude if Params.haptic_amplitude_supported else -1.0)


## Passos finais: limita a duração total e, sem amplitude, troca cada passo por pulsos.
func _build_steps(source: Array) -> Array:
	var out: Array = []
	var total: int = 0
	for raw in source:
		var ms: int = int(raw[0])
		var intensity: float = float(raw[1])
		if total + ms > Params.haptic_max_pattern_ms:
			ms = Params.haptic_max_pattern_ms - total
		if ms <= 0:
			break
		total += ms
		if Params.haptic_amplitude_supported or intensity <= 0.0:
			out.append([ms, intensity])
			continue
		# Simulado: duty cycle = intensidade (liga por period*i, desliga no resto)
		var scaled: float = clampf(intensity * level_scale(), 0.0, 1.0)
		var left: int = ms
		while left > 0:
			var on: int = clampi(int(Params.haptic_pwm_period_ms * scaled), 8, mini(left, Params.haptic_pwm_period_ms))
			out.append([on, 1.0])
			left -= on
			var off: int = mini(left, Params.haptic_pwm_period_ms - on)
			if off > 0:
				out.append([off, 0.0])
				left -= off
	return out


func _motor_ms(steps: Array) -> int:
	var total: int = 0
	for step in steps:
		if float(step[1]) > 0.0:
			total += int(step[0])
	return total


func _budget_used(now: int) -> int:
	var used: int = 0
	for i in range(_spent.size() - 1, -1, -1):
		if now - int(_spent[i][0]) > Params.haptic_budget_window_ms:
			_spent.remove_at(i)
		else:
			used += int(_spent[i][1])
	return used
