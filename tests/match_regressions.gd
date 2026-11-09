extends Node
## Ver match_regressions_run.gd. Sai com código 1 se algum caso falhar.

func _ready() -> void:
	SaveGame.persistent = false
	SaveGame.settings["tips_enabled"] = false  # o destaque das dicas pausaria os casos (testado à parte)
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await get_tree().create_timer(0.8, true, false, true).timeout
	var failures: int = 0
	var hud: Hud = game.get("hud")
	var button: Control = hud.get("_special")
	var at: Vector2 = button.get_global_rect().get_center()
	var ship: Vector2 = get_viewport().get_visible_rect().get_center()
	# Caso 1: só um dedo, direto no botão
	failures += await _case(game, "um dedo", [[0, at, true], [0, at, false]])
	# Caso 2: dedo 0 segura a nave, dedo 1 toca o especial
	failures += await _case(game, "dois dedos", [[0, ship, true], [1, at, true], [1, at, false], [0, ship, false]])
	# Caso 3: dedo da nave sai antes do dedo do especial
	failures += await _case(game, "ordem trocada", [[0, ship, true], [1, at, true], [0, ship, false], [1, at, false]])
	# Depois de cada sequência estranha, um toque simples precisa funcionar
	var state: MatchState = game.get("state")
	# Caso 4: segura o botão com o especial ainda carregando e solta depois que encheu
	state.special_charge[state.current] = 0.0
	await _send([[0, at, true]])
	state.special_charge[state.current] = state.special_seconds()
	await _send([[0, at, false]])
	failures += await _case(game, "depois de segurar carregando", [[0, at, true], [0, at, false]])
	# Caso 5: começa no botão e arrasta para mover a nave
	await _send([[0, at, true], ["drag", ship], [0, ship, false]])
	failures += await _case(game, "depois de arrastar do botão", [[0, at, true], [0, at, false]])
	# Caso 6: dois dedos e o dedo 0 é que toca o especial depois de soltar
	await _send([[0, ship, true], [1, ship + Vector2(100, 0), true], [0, ship, false]])
	failures += await _case(game, "dedo 1 segurando", [[0, at, true], [0, at, false]])
	await _send([[1, ship, false]])
	failures += await _case(game, "final", [[0, at, true], [0, at, false]])
	failures += await _check_special_cycle(game)
	# Órbita com um alvo liberado da memória (como o chefe ao morrer) não pode quebrar
	var context: CombatContext = game.get("context")
	var orbit: Weapon = Weapon.create(load("res://data/weapons/orbit.tres") as WeaponData, context, 1)
	game.add_child(orbit)
	var gone := Enemy.new()
	orbit.get("_cooldowns")[gone] = 1.0
	gone.free()
	for i in 3:
		await get_tree().process_frame
	if not (orbit.get("_cooldowns") as Dictionary).is_empty():
		printerr("FALHOU: órbita não descartou o alvo liberado")
		failures += 1
	orbit.queue_free()
	failures += await _check_tip_spotlight(game)
	failures += await _check_slowmo_holds_fire(game)
	failures += await _check_clear_sequence(game)
	print("match_regressions: %d falhas" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _case(game: Node, label: String, touches: Array) -> int:
	var state: MatchState = game.get("state")
	state.special_charge[state.current] = state.special_seconds()
	await get_tree().process_frame
	await get_tree().process_frame
	await _send(touches)
	if state.special_ratio() > 0.5:
		printerr("FALHOU: especial não disparou (%s)" % label)
		return 1
	return 0


## [index, pos, pressed] = toque; ["drag", pos] = arrasta o dedo 0.
func _send(touches: Array) -> void:
	for t in touches:
		var event: InputEvent
		if t[0] is String:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = t[1]
			event = drag
		else:
			var touch := InputEventScreenTouch.new()
			touch.index = t[0]
			touch.position = t[1]
			touch.pressed = t[2]
			event = touch
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


## Ciclo real do especial: carrega com o tempo, dispara, troca de nave, volta, carrega e dispara de novo.
func _check_special_cycle(game: Node) -> int:
	var failures: int = 0
	var state: MatchState = game.get("state")
	var switcher: BodySwitcher = game.get("switcher")
	var hud: Hud = game.get("hud")
	var at: Vector2 = (hud.get("_special") as Control).get_global_rect().get_center()
	var saved: float = Params.balance.special_charge_multiplier
	Params.balance.special_charge_multiplier = 0.05  # ~1 s de jogo para encher
	for round in 3:
		state.special_charge[state.current] = 0.0
		var waited: float = 0.0
		while not state.special_ready() and waited < 15.0:
			await get_tree().create_timer(0.1, true, false, true).timeout
			waited += 0.1
		if not state.special_ready():
			printerr("FALHOU: especial não recarregou (rodada %d, nave %d, carga %.2f)" % [round, state.current, state.special_ratio()])
			failures += 1
			continue
		await _send([[0, at, true], [0, at, false]])
		if state.special_ratio() > 0.5:
			printerr("FALHOU: especial cheio não disparou (rodada %d, nave %d)" % [round, state.current])
			failures += 1
		# Troca para a próxima nave e espera a recarga da troca
		var next: int = (state.current + 1) % state.bodies.size()
		state.switch_cooldown_left = 0.0
		var icon: Vector2 = switcher.get("_positions")[next]
		await _send([[0, icon, true], [0, icon, false]])
		if state.current != next:
			printerr("FALHOU: não trocou para a nave %d" % next)
			failures += 1
	Params.balance.special_charge_multiplier = saved
	return failures


## Fim de fase: a nave fica imune, tiros e inimigos somem, a nave sai por cima e o resultado aparece.
func _check_clear_sequence(game: Node) -> int:
	var failures: int = 0
	var player: Player = game.get("player")
	var state: MatchState = game.get("state")
	var hits_before: int = state.hits_left[state.current]
	game.call("_finish_stage_clear")
	await get_tree().process_frame
	if player.is_vulnerable():
		printerr("FALHOU: nave vulnerável no fim de fase")
		failures += 1
	var bullets: NodePool = game.get("enemy_bullets")
	var bullet := bullets.acquire() as Bullet
	if bullet != null:
		bullet.position = player.position
	await get_tree().create_timer(0.3, true, false, true).timeout
	if state.hits_left[state.current] != hits_before:
		printerr("FALHOU: nave levou dano durante a sequência")
		failures += 1
	await get_tree().create_timer(Params.clear_pause_seconds + Params.clear_ship_center_seconds
			+ Params.clear_ship_exit_seconds + Params.clear_results_delay + 1.0, true, false, true).timeout
	if player.position.y > 0.0:
		printerr("FALHOU: nave não saiu da tela (y=%.0f)" % player.position.y)
		failures += 1
	if not Dialog.is_open():
		printerr("FALHOU: resultado não apareceu")
		failures += 1
	return failures


## Câmera lenta voluntária: as armas seguram o tiro; ao tocar de novo, voltam a atirar.
func _check_slowmo_holds_fire(game: Node) -> int:
	var failures: int = 0
	var context: CombatContext = game.get("context")
	var time: TimeController = game.get("time_controller")
	var spread: Weapon = Weapon.create(load("res://data/weapons/spread.tres") as WeaponData, context, 1)
	game.add_child(spread)
	spread.position = get_viewport().get_visible_rect().get_center()
	time.energy = 1.0  # os casos anteriores soltaram o dedo várias vezes e gastaram energia
	time._on_touch_started(spread.position)
	time._on_touch_ended()
	if not context.weapons_hold:
		printerr("FALHOU: câmera lenta voluntária não segurou as armas")
		failures += 1
	var before: int = context.player_bullets.active.size()
	var most: int = before
	for i in 40:
		await get_tree().process_frame
		most = maxi(most, context.player_bullets.active.size())
	if most > before:
		printerr("FALHOU: arma atirou na câmera lenta (%d -> %d)" % [before, most])
		failures += 1
	time._on_touch_started(spread.position)
	if context.weapons_hold:
		printerr("FALHOU: tocar de novo não liberou as armas")
		failures += 1
	var fired: bool = false
	for i in 40:
		await get_tree().process_frame
		if context.player_bullets.active.size() > before:
			fired = true
			break
	if not fired:
		printerr("FALHOU: arma não voltou a atirar depois da câmera lenta")
		failures += 1
	spread.queue_free()
	return failures


## Dica na primeira vez do evento: o kit aparece, o jogo pausa com o recorte em volta dele e
## "Entendi" volta o jogo; a dica fica vista e não repete.
func _check_tip_spotlight(game: Node) -> int:
	var failures: int = 0
	SaveGame.settings["tips_enabled"] = true
	SaveGame.tips_seen = PackedStringArray()
	var spotlight: TipSpotlight = game.get("tip_spotlight")
	var dropper: PowerUpDropper = game.get("dropper")
	var spot := Vector2(540, 900)
	dropper.drop_now(spot, PowerUp.Kind.HEAL)
	for i in 6:
		await get_tree().process_frame
	if not (spotlight.is_showing() and get_tree().paused):
		printerr("FALHOU: dica do kit não pausou com destaque")
		failures += 1
	var hole: Rect2 = spotlight.get("_hole")
	if not hole.has_point(spot):
		printerr("FALHOU: recorte não está em volta do kit (%s)" % hole)
		failures += 1
	spotlight.close()
	await get_tree().process_frame
	if get_tree().paused or not SaveGame.is_tip_seen("tip_medkit"):
		printerr("FALHOU: fechar a dica não voltou o jogo")
		failures += 1
	dropper.drop_now(spot, PowerUp.Kind.HEAL)
	for i in 6:
		await get_tree().process_frame
	if spotlight.is_showing():
		printerr("FALHOU: dica repetiu")
		failures += 1
	SaveGame.settings["tips_enabled"] = false
	for item in (game.get("power_ups") as NodePool).active.duplicate():
		(game.get("power_ups") as NodePool).release(item)
	return failures

