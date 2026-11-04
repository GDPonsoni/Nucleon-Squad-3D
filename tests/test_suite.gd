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
	var paths: Array[String] = [Params.music_menu_path]
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
