extends Node
## Testes de lógica sem tela: save (migração e ida e volta), evolução do núcleo,
## bônus na partida e desbloqueios. Não grava o save do aparelho.

var _failures: int = 0
var _checks: int = 0
var _current: String = ""


func _ready() -> void:
	SaveGame.persistent = false
	for method in get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			_current = name
			call(name)
	print("testes: %d verificações, %d falhas" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU [%s]: %s" % [_current, message])


func _fresh_save() -> Node:
	var save: Node = load("res://scripts/core/save_game.gd").new()
	save.persistent = false
	return save


func _node(id: String) -> UpgradeData:
	for node in Session.upgrade_tree.nodes:
		if String(node.id) == id:
			return node
	return null


func _body(id: String) -> BodyData:
	for body in (load(Params.roster_path) as FormationData).bodies:
		if String(body.id) == id:
			return body
	return null


## Save real do celular (versão 2, campanha antiga de 13 fases).
func test_migrates_phone_save_v2() -> void:
	var save := _fresh_save()
	save.from_dict({
		"best_scores": {"p1_s1": 580.0, "p1_s3": 2735.0, "p2_s3": 5835.0, "p4_s3": 13390},
		"completed": ["p2_s3", "p1_s3", "p3_s1", "p4_s1", "p4_s2", "p4_s3"],
		"legacy_highest_unlocked": 5,
		"squad": ["beam_body", "lance_body", "homing_body", "orbit_body"],
		"unlock_everything": false,
		"version": 2,
	})
	# O avanço antigo (até a 6ª fase liberada) vira fases concluídas
	for id in ["p1_s1", "p1_s2", "p1_s3", "p2_s1", "p2_s2", "p2_s3", "p3_s1", "p4_s1", "p4_s2", "p4_s3"]:
		check(save.is_completed(StringName(id)), "%s deveria estar concluída" % id)
	check(not save.is_completed(&"p3_s2"), "p3_s2 não foi concluída")
	# Chefes antigos vencidos (Sentinela e Forja) contam como capítulos concluídos
	check(save.cleared_chapters == PackedStringArray(["planet_1", "planet_2"]), "capítulos: %s" % save.cleared_chapters)
	check(save.is_chapter_cleared(0) and save.is_chapter_cleared(1), "capítulos 1 e 2 concluídos")
	check(not save.is_chapter_cleared(2) and not save.is_chapter_cleared(3), "capítulos 3 e 4 não concluídos")
	check(save.is_companion_unlocked(), "espaço auxiliar liberado pelo capítulo 1")
	check(save.is_ship_unlocked(_body("lance_body")), "Lança liberada pelo capítulo 2")
	check(not save.is_ship_unlocked(_body("artillery_body")), "Artilharia ainda bloqueada")
	check(save.best_score(&"p4_s3") == 13390, "recorde preservado")
	check(save.quarks == 0 and save.upgrades.is_empty(), "sem quarks nem evolução")
	var squad: Array[BodyData] = save.squad_formation().bodies
	check(squad.size() == 4 and String(squad[1].id) == "lance_body", "esquadrão com a Lança mantido")
	save.free()


func test_save_round_trip() -> void:
	var save := _fresh_save()
	save.completed = {"p1_s1": true}
	save.best_scores = {"p1_s1": 1200}
	save.quarks = 345
	save.quarks_earned_total = 900
	save.upgrades = {"damage": 3, "hull": 1}
	save.companion = "spread_body"
	save.squad = PackedStringArray(["beam_body", "spread_body", "homing_body", "orbit_body"])
	var copy := _fresh_save()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.is_completed(&"p1_s1"), "fase concluída")
	check(copy.best_score(&"p1_s1") == 1200, "recorde")
	check(copy.quarks == 345 and copy.quarks_earned_total == 900, "quarks")
	check(int(copy.upgrades["damage"]) == 3 and int(copy.upgrades["hull"]) == 1, "evolução")
	check(copy.companion == "spread_body", "auxiliar")
	check(copy.cleared_chapters.is_empty(), "save novo não ganha capítulos da migração")
	save.free()
	copy.free()


func test_stage_stars() -> void:
	var stage := StageData.new()
	stage.id = &"t"
	stage.star_scores = PackedInt32Array([500, 900])
	check(stage.stars_for(0) == 1 and stage.stars_for(499) == 1, "1 estrela ao concluir")
	check(stage.stars_for(500) == 2 and stage.stars_for(899) == 2, "2 estrelas")
	check(stage.stars_for(900) == 3 and stage.stars_for(99999) == 3, "3 estrelas")
	check(stage.next_star_score(1) == 500 and stage.next_star_score(2) == 900 and stage.next_star_score(3) == 0, "meta da próxima estrela")
	for planet: PlanetData in Session.campaign.planets:
		for s: StageData in planet.stages:
			check(s.star_scores.size() == 2 and s.star_scores[0] < s.star_scores[1] and s.star_scores[0] > 0, "metas de %s" % s.id)


func test_debug_progress_rewind() -> void:
	var save := _fresh_save()
	var total: int = save.stage_order().size()
	save.set_progress_count(total)
	check(save.progress_count() == total and save.is_chapter_cleared(0), "concluir tudo")
	save.set_progress_count(save.progress_count() - 1)
	check(save.progress_count() == total - 1 and not save.is_chapter_cleared(4), "recuar 1 fase tira o chefe final")
	save.set_progress_count(9)
	check(save.progress_count() == 9 and not save.is_chapter_cleared(1), "início do capítulo 2")
	save.quarks = 50
	save.upgrades = {"damage": 2}
	save.reset_all()
	check(save.progress_count() == 0 and save.quarks == 0 and save.upgrades.is_empty(), "zerar tudo")
	save.free()


func test_companion_needs_unlocked_slot() -> void:
	var save := _fresh_save()
	save.companion = "spread_body"
	check(save.companion_body() == null, "sem capítulo 1 concluído, sem auxiliar")
	save.cleared_chapters = PackedStringArray(["planet_1"])
	check(save.companion_body() != null and String(save.companion_body().id) == "spread_body", "auxiliar liberada")
	save.companion = "artillery_body"
	check(save.companion_body() == null, "nave bloqueada não vira auxiliar")
	save.free()


func test_upgrade_costs_grow() -> void:
	var damage := _node("damage")
	check(damage.cost(1) == 40, "1º nível do dano custa 40 (custou %d)" % damage.cost(1))
	for level in range(2, damage.max_level + 1):
		check(damage.cost(level) > damage.cost(level - 1), "custo cresce no nível %d" % level)
	var overdrive := _node("overdrive")
	check(overdrive.is_infinite() and not overdrive.is_maxed(500), "Sobrecarga sem limite")
	check(overdrive.cost(2) - overdrive.cost(1) == overdrive.cost(3) - overdrive.cost(2), "Sobrecarga com custo linear")
	check(Session.upgrade_tree.finite_total_cost() > 10000, "árvore finita custa bem mais que uma fase")


func test_buy_upgrade_rules() -> void:
	var saved: Dictionary = SaveGame.to_dict()
	SaveGame.upgrades = {}
	SaveGame.quarks = 100
	check(not SaveGame.buy_upgrade(_node("fire_rate")), "Cadência precisa de Dano")
	check(SaveGame.buy_upgrade(_node("damage")), "compra o 1º nível do Dano")
	check(SaveGame.quarks == 60 and SaveGame.upgrade_level(_node("damage")) == 1, "saldo e nível depois da compra")
	check(not SaveGame.buy_upgrade(_node("fire_rate")) or SaveGame.quarks >= 0, "sem saldo negativo")
	SaveGame.quarks = 0
	check(not SaveGame.buy_upgrade(_node("damage")), "sem saldo não compra")
	SaveGame.upgrades = {"damage": 10}
	SaveGame.quarks = 99999
	check(not SaveGame.buy_upgrade(_node("damage")), "nível máximo não compra")
	SaveGame.from_dict(saved)
	SaveGame.upgrades = saved["upgrades"]
	SaveGame.quarks = saved["quarks"]


func test_boosts_from_levels() -> void:
	var boosts: PlayerBoosts = Session.upgrade_tree.boosts_for({
		"damage": 3, "hull": 2, "collect": 1, "special": 2, "shield": 1, "head_start": 1, "overdrive": 5,
	})
	check(is_equal_approx(boosts.damage, 1.0 + 0.08 * 3 + 0.02 * 5), "dano %.3f" % boosts.damage)
	check(boosts.extra_hits == 2, "hits extras")
	check(is_equal_approx(boosts.quarks, 1.1) and is_equal_approx(boosts.pickup_radius, 1.15), "coleta")
	check(is_equal_approx(boosts.special_damage, 1.2) and is_equal_approx(boosts.special_charge, 0.9), "especial")
	check(boosts.shields == 1 and boosts.start_level_bonus == 1, "escudo e arma inicial")
	var neutral: PlayerBoosts = Session.upgrade_tree.boosts_for({})
	check(neutral.damage == 1.0 and neutral.extra_hits == 0 and neutral.shields == 0, "sem evolução = neutro")


func test_match_state_applies_boosts() -> void:
	var boosts := PlayerBoosts.new()
	boosts.extra_hits = 2
	boosts.start_level_bonus = 1
	boosts.shields = 2
	boosts.quarks = 1.5
	var state := MatchState.new(load(Params.formation_path) as FormationData, boosts)
	check(state.max_hits == Params.body_max_hits + 2, "hits máximos com o Casco")
	check(state.hits_left[0] == state.max_hits, "corpos começam cheios")
	check(state.weapon_levels[0] == 2, "armas começam no nível 2")
	check(state.absorb_with_shield() and state.absorb_with_shield() and not state.absorb_with_shield(), "dois escudos")
	state.add_kill(100)
	check(is_equal_approx(state.quarks, 100 * Params.quarks_per_point * 1.5), "quarks por abate com bônus")
	state.damage_current(state.max_hits)
	check(not state.is_alive(0) and state.weapon_levels[0] == 2, "corpo perdido volta ao nível inicial")


func test_switch_cooldown_and_special_charge() -> void:
	var state := MatchState.new(load(Params.formation_path) as FormationData)
	check(state.can_switch(), "começa podendo trocar")
	state.start_switch_cooldown()
	check(not state.can_switch() and is_equal_approx(state.switch_cooldown_ratio(), 1.0), "recarga cheia ao trocar")
	state.tick_switch_cooldown(Params.switch_cooldown_seconds * 0.5)
	check(not state.can_switch() and is_equal_approx(state.switch_cooldown_ratio(), 0.5), "metade da recarga")
	state.tick_switch_cooldown(Params.switch_cooldown_seconds)
	check(state.can_switch(), "recarga terminou")
	var base: float = state.current_body().weapon.special_charge_seconds
	check(is_equal_approx(state.special_seconds(), base * Params.balance.special_charge_multiplier), "carga do especial com o multiplicador")


func test_companion_versions() -> void:
	var roster: Array[BodyData] = (load(Params.roster_path) as FormationData).bodies
	for body in roster:
		var weapon: WeaponData = body.weapon
		check(weapon.companion_levels.size() == 3, "%s: 3 níveis de auxiliar" % body.id)
		for key in [body.companion_description_key, body.companion_upgrade_key]:
			check(not key.is_empty() and TranslationServer.translate(key) != key, "%s: texto %s" % [body.id, key])
	var formation := load(Params.formation_path) as FormationData
	var state := MatchState.new(formation)
	check(not state.companion_can_level(), "sem auxiliar não sobe nível")
	state.companion = roster[0]
	check(state.level_up_companion() and state.level_up_companion(), "auxiliar sobe até o 3")
	check(state.companion_level == 3 and not state.level_up_companion(), "auxiliar para no 3")


func test_special_gets_ready_for_every_ship() -> void:
	# Tempos que não cabem exatos em 32 bits (bônus de recarga) deixavam o especial travado
	var roster := load(Params.roster_path) as FormationData
	for charge_bonus in [1.0, 0.9, 0.81, 0.73]:
		var boosts := PlayerBoosts.new()
		boosts.special_charge = charge_bonus
		var formation := FormationData.new()
		formation.bodies = roster.bodies.duplicate()
		var state := MatchState.new(formation, boosts)
		for i in state.bodies.size():
			state.select(i)
			for step in 4000:
				state.charge_special(1.0 / 60.0)
			check(state.special_ready(), "%s pronto com recarga %.2f" % [state.bodies[i].id, charge_bonus])
			state.use_special()
			check(not state.special_ready() and state.special_ratio() == 0.0, "%s zera ao usar" % state.bodies[i].id)


func test_every_sound_has_a_file_and_gain() -> void:
	for sound: StringName in Params.sfx_gain_db:
		check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % sound), "arquivo de %s" % sound)
		check(float(Params.sfx_gain_db[sound]) <= 0.0, "%s não amplifica (risco de estourar)" % sound)
	for sound: StringName in Params.sfx_min_gap:
		check(Params.sfx_gain_db.has(sound), "intervalo de %s sem som correspondente" % sound)
	check(Params.sfx_gain_db.size() == 28, "28 sons mapeados")


func test_settings_apply_to_buses() -> void:
	var saved: Dictionary = SaveGame.settings.duplicate()
	SaveGame.set_setting("sfx", 0.5)
	var bus: int = AudioServer.get_bus_index(&"SFX")
	check(bus >= 0, "barramento SFX existe")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)), "volume do SFX")
	SaveGame.set_setting("music", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "música em zero fica muda")
	SaveGame.set_setting("language", "en")
	check(TranslationServer.get_locale().begins_with("en"), "idioma inglês")
	check(tr("MENU_SETTINGS") == "Settings", "texto em inglês: %s" % tr("MENU_SETTINGS"))
	SaveGame.set_setting("language", "pt_BR")
	check(tr("MENU_SETTINGS") == "Configurações", "texto em português")
	SaveGame.settings = saved
	SaveGame.settings_changed.emit()


func test_settings_round_trip_and_defaults() -> void:
	var save := _fresh_save()
	check(is_equal_approx(float(save.setting("master")), 1.0) and save.setting("vibration") == true, "padrões")
	save.settings = {"sfx": 0.3, "language": "en"}
	var copy := _fresh_save()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(is_equal_approx(float(copy.setting("sfx")), 0.3) and copy.setting("language") == "en", "valores salvos")
	check(is_equal_approx(float(copy.setting("music")), Params.default_settings["music"]), "o resto fica no padrão")
	copy.from_dict({"settings": {"inexistente": 5}, "version": 3})
	check(not copy.settings.has("inexistente"), "chave desconhecida é ignorada")
	save.free()
	copy.free()


func test_audio_play_is_safe() -> void:
	Audio.play(&"ui_click")
	Audio.play(&"nao_existe")
	Audio.shot(WeaponData.Kind.CHAIN)
	Audio.explosion(10.0)
	Audio.explosion(200.0)
	Audio.ui_press("MENU_BACK")
	check(true, "tocar sons (inclusive inexistentes) não quebra")


func test_campaign_structure() -> void:
	var campaign: CampaignData = Session.campaign
	check(campaign.planets.size() == 5, "5 capítulos")
	var ids := {}
	for p in campaign.planets.size():
		var planet: PlanetData = campaign.planets[p]
		check(planet.stages.size() == 9, "capítulo %d com 9 fases" % (p + 1))
		for s in planet.stages.size():
			var stage: StageData = planet.stages[s]
			check(not ids.has(stage.id), "id repetido %s" % stage.id)
			ids[stage.id] = true
			check(String(stage.id) == "p%d_s%d" % [p + 1, s + 1], "id %s na posição %d-%d" % [stage.id, p + 1, s + 1])
			check((stage.boss != null) == (s == 4 or s == 8), "chefe só nas fases 5 e 9 (%s)" % stage.id)
			check(not stage.waves.is_empty(), "%s tem ondas" % stage.id)
	check(campaign.stage_count() == 45, "45 fases")


func test_music_tracks_loop() -> void:
	var paths: Array[String] = [Params.music_menu_path, Params.music_clear_path]
	for c in Session.campaign.planets.size():
		paths.append(Params.music_chapter_path % (c + 1))
	for path in paths:
		var stream := load(path) as AudioStreamWAV
		check(stream != null, "música %s existe" % path)
		if stream != null:
			check(stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "música %s em laço" % path)


func test_spanish_translation() -> void:
	var saved: Dictionary = SaveGame.settings.duplicate()
	SaveGame.set_setting("language", "es")
	check(tr("MENU_PLAY") == "Jugar" and tr("MENU_SETTINGS") == "Ajustes", "textos em espanhol: %s" % tr("MENU_PLAY"))
	SaveGame.settings = saved
	SaveGame.settings_changed.emit()


func test_ad_quarks_daily_limit() -> void:
	var save := _fresh_save()
	check(save.ads_left_today() == Params.ad_quarks_daily_limit, "limite cheio no começo")
	var reward: int = save.grant_ad_quarks()
	check(reward == Params.ad_quarks_base and save.quarks == reward, "primeiro anúncio: %d quarks" % reward)
	for i in Params.ad_quarks_daily_limit:
		save.grant_ad_quarks()
	check(save.ads_left_today() == 0, "limite do dia acaba")
	save.ad_day = "2000-01-01"
	check(save.ads_left_today() == Params.ad_quarks_daily_limit, "dia novo libera de novo")
	save.cleared_chapters = PackedStringArray(["planet_1", "planet_2"])
	check(save.ad_quark_reward() == Params.ad_quarks_base + 2 * Params.ad_quarks_per_chapter, "recompensa cresce com capítulos")
	var copy := _fresh_save()
	copy.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	check(copy.ad_day == "2000-01-01" and copy.ad_count == save.ad_count, "contagem salva")
	save.free()
	copy.free()


## Inimigo de teste fora da árvore (sem desenho nem processo): só a lógica de dano.
func _enemy(id: String) -> Enemy:
	var enemy := Enemy.new()
	enemy.context = CombatContext.new()
	enemy.activate(load("res://data/enemies/%s.tres" % id), Vector2(500.0, 500.0), Vector2.ZERO)
	return enemy


func test_weapon_multipliers() -> void:
	var colossus := _enemy("colossus")
	colossus.take_damage(10.0, WeaponData.Kind.BEAM)
	check(is_equal_approx(colossus.hp, 150.0 - 14.0), "Raio +40%% no Colosso (vida %.1f)" % colossus.hp)
	colossus.take_damage(10.0, WeaponData.Kind.SPREAD)
	check(is_equal_approx(colossus.hp, 136.0 - 2.0), "Leque -80%% no Colosso (vida %.1f)" % colossus.hp)
	colossus.take_damage(10.0, Enemy.SOURCE_SPECIAL)
	check(is_equal_approx(colossus.hp, 124.0), "especial ignora multiplicadores (vida %.1f)" % colossus.hp)
	colossus.free()


func test_shield_blocks_front_only() -> void:
	var shielder := _enemy("shielder")
	shielder.take_damage(5.0, WeaponData.Kind.SPREAD, Vector2(500.0, 700.0))
	check(is_equal_approx(shielder.hp, 20.0) and shielder.last_blocked, "tiro de baixo bloqueado")
	shielder.take_damage(5.0, WeaponData.Kind.SPREAD, Vector2(500.0, 300.0))
	check(is_equal_approx(shielder.hp, 15.0), "tiro de cima passa (vida %.1f)" % shielder.hp)
	shielder.take_damage(5.0, WeaponData.Kind.SPREAD)
	check(is_equal_approx(shielder.hp, 10.0), "área (sem origem) passa o escudo")
	# Escudo (14) já absorveu 5: mais dois tiros de 5 o quebram
	for i in 2:
		shielder.take_damage(5.0, WeaponData.Kind.SPREAD, Vector2(500.0, 700.0))
	check(not shielder.shield_up(), "escudo quebrado após absorver %d" % int(shielder.data.shield_hp))
	shielder.take_damage(5.0, WeaponData.Kind.SPREAD, Vector2(500.0, 700.0))
	check(is_equal_approx(shielder.hp, 5.0), "sem escudo, o tiro de baixo acerta (vida %.1f)" % shielder.hp)
	shielder.free()


func test_special_moment_armor() -> void:
	var drone := _enemy("drone")
	drone.armored = true
	drone.take_damage(2.0, WeaponData.Kind.BEAM)
	check(is_equal_approx(drone.hp, 6.0 - 0.2), "blindado leva 10%% do dano normal (vida %.2f)" % drone.hp)
	drone.take_damage(1.0, Enemy.SOURCE_SPECIAL)
	check(not drone.armored and is_equal_approx(drone.hp, 4.8), "especial quebra a blindagem")
	drone.take_damage(2.0, WeaponData.Kind.BEAM)
	check(is_equal_approx(drone.hp, 2.8), "depois do especial, dano normal")
	drone.free()


func test_every_attack_has_telegraph() -> void:
	for file in DirAccess.get_files_at("res://data/enemies"):
		var data := load("res://data/enemies/" + file) as EnemyData
		if data.fire_pattern != EnemyData.FirePattern.NONE or data.movement == EnemyData.Movement.DIVE:
			check(data.telegraph_seconds > 0.0, "%s ataca sem aviso" % file)
	for file in DirAccess.get_files_at("res://data/bosses"):
		var boss := load("res://data/bosses/" + file) as BossData
		for phase in boss.phases:
			for attack in phase.attacks:
				check(attack.telegraph_seconds > 0.0, "%s tem ataque sem aviso" % file)


## Tutorial: dicas do JSON têm texto nas 3 línguas, não repetem e o "rever" religa.
func test_tutorial_tips() -> void:
	var csv: String = FileAccess.get_file_as_string("res://data/i18n/strings.csv")
	var ids := {}
	for tip in Tutorial.tips:
		check(not ids.has(tip["id"]), "id de dica repetido: %s" % tip["id"])
		ids[tip["id"]] = true
		check(csv.contains("\n%s," % tip["text_key"]), "sem texto para %s" % tip["text_key"])
		check(["match", "screen", "end"].has(tip["context"]), "contexto inválido em %s" % tip["id"])
	for def in Tutorial.unlock_defs:
		check(csv.contains("\n%s," % def["text_key"]), "sem texto para %s" % def["text_key"])
	var save_seen: PackedStringArray = SaveGame.tips_seen
	SaveGame.tips_seen = PackedStringArray()
	SaveGame.settings["tips_enabled"] = true
	Tutorial.attach(&"match", self)
	Tutorial.notify(&"touch_released")
	Tutorial.notify(&"touch_released")
	check(Tutorial._queue[&"match"].size() == 1, "dica não pode entrar duas vezes na fila")
	Tutorial.notify(&"match_start", "p1_s1")
	check(Tutorial._queue[&"match"].size() == 2, "dica de fase específica entra na fila")
	Tutorial.notify(&"match_start", "p9_s9")
	check(Tutorial._queue[&"match"].size() == 2, "dica de outra fase não entra")
	SaveGame.mark_tip_seen("tip_slowmo")
	Tutorial.notify(&"touch_released")
	check(not Tutorial._is_queued(&"match", "tip_slowmo") or Tutorial._queue[&"match"].size() == 2, "dica vista não volta")
	Tutorial.disable_tips()
	check(not Tutorial.tips_enabled() and Tutorial._queue[&"match"].is_empty(), "não mostrar mais esvazia a fila")
	Tutorial.notify(&"match_start", "p1_s1")
	check(Tutorial._queue[&"match"].is_empty(), "com dicas desligadas nada entra")
	SaveGame.mark_tip_seen("unlock_companion")
	SaveGame.reset_tips()
	check(Tutorial.tips_enabled() and not SaveGame.is_tip_seen("tip_slowmo"), "rever tutorial religa e esquece as dicas")
	check(SaveGame.is_tip_seen("unlock_companion"), "avisos de desbloqueio não se repetem após rever")
	Tutorial.detach(&"match", self)
	SaveGame.tips_seen = save_seen


## Avisos de desbloqueio: cap. 1 libera o espaço auxiliar e o planeta 2; nunca repetem.
func test_unlock_notices() -> void:
	var save_seen: PackedStringArray = SaveGame.tips_seen
	SaveGame.tips_seen = PackedStringArray()
	var first: Array[Dictionary] = Tutorial.unlock_notices(0)
	check(first.size() == 2, "capítulo 1: auxiliar + planeta (%d)" % first.size())
	for notice in first:
		SaveGame.mark_tip_seen(notice["id"])
	check(Tutorial.unlock_notices(0).is_empty(), "aviso de desbloqueio não repete")
	var second: Array[Dictionary] = Tutorial.unlock_notices(1)
	var ships: int = 0
	for notice in second:
		if notice["body"] != null:
			ships += 1
	check(ships == 1, "capítulo 2 libera 1 nave")
	SaveGame.tips_seen = save_seen


## Power-ups por tempo: 15 em 75% da fase; o bônus do núcleo encurta, nunca abaixo de 40%.
func test_powerup_pacing() -> void:
	var balance: BalanceData = Params.balance
	var interval: float = balance.powerup_interval(120.0)
	check(is_equal_approx(interval * balance.powerups_per_stage, 120.0 * balance.powerup_span), "15 power-ups cobrem 75% da fase")
	check(balance.powerup_interval(120.0, 3) < interval, "bônus do núcleo encurta o intervalo")
	check(balance.powerup_interval(120.0, 100) >= interval * 0.4 - 0.001, "intervalo tem piso")
	check(balance.powerups_per_stage >= 12, "dá para pôr 3 armas no nível 5 (4 power-ups cada)")


## Chefes: cópia com mais vida e uma fase de fúria extra; o recurso original não muda.
func test_boss_tuning() -> void:
	var data := load("res://data/bosses/boss_1.tres") as BossData
	var before_hp: int = data.max_hp
	var phases: int = data.phases.size()
	Session.planet_index = 0
	var tuned: BossData = Boss._tuned(data)
	check(tuned.max_hp > before_hp, "chefe tem mais vida")
	check(data.max_hp == before_hp and data.phases.size() == phases, "recurso original intacto")
	check(tuned.phases.size() == phases + 1, "fase de fúria extra")
	check(tuned.phases.back().hp_ratio == Params.balance.boss_enrage_ratio, "fúria na fração configurada")
	check(not tuned.phases.back().special_moment, "fúria não rearma o momento de especial")
	check(tuned.phases.back().attacks[0].interval <= data.phases.back().attacks[0].interval, "ataques da fúria não ficam mais lentos")
