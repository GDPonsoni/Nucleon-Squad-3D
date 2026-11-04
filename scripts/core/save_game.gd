extends Node
## Autoload: progresso salvo no aparelho em JSON versionado (user://save.json),
## pensado para migração e sincronização futuras.
## Guarda fases concluídas, recordes, esquadrão, nave auxiliar, quarks e a evolução do núcleo.

const PATH: String = "user://save.json"
const VERSION: int = 3
## Campanha antiga (saves 1 e 2): fases por capítulo, na ordem, e a fase do chefe de cada um.
const LEGACY_STAGES: Array[PackedStringArray] = [
	["p1_s1", "p1_s2", "p1_s3"], ["p2_s1", "p2_s2", "p2_s3"],
	["p3_s1", "p3_s2", "p3_s3"], ["p4_s1", "p4_s2", "p4_s3", "p4_s4"],
]
const LEGACY_PLANETS: PackedStringArray = ["planet_1", "planet_2", "planet_3", "planet_4"]

var completed: Dictionary = {}  # id da fase -> true (fases concluídas)
var best_scores: Dictionary = {}  # id da fase -> melhor pontuação
var unlock_everything: bool = false  # atalho de debug do seletor
var squad: PackedStringArray = PackedStringArray()  # ids dos corpos escolhidos, em ordem
var companion: String = ""  # id do corpo da nave auxiliar ("" = nenhuma)
var quarks: int = 0  # saldo para a evolução do núcleo
var quarks_earned_total: int = 0  # total ganho desde o início (estatística)
var upgrades: Dictionary = {}  # id do nó da evolução -> nível
## Capítulos concluídos na campanha antiga (migração): contam como concluídos.
var cleared_chapters: PackedStringArray = PackedStringArray()
## false = não grava no aparelho (ferramentas de teste e simulação)
var persistent: bool = true


func _ready() -> void:
	load_data()


## A primeira fase de cada capítulo está sempre liberada; as outras, quando a
## anterior do mesmo capítulo foi concluída.
func is_unlocked(planet: int, stage: int) -> bool:
	if Params.debug_unlock_all or unlock_everything or stage == 0:
		return true
	var previous: StageData = Session.campaign.planets[planet].stages[stage - 1]
	return completed.has(String(previous.id))


func is_completed(stage_id: StringName) -> bool:
	return completed.has(String(stage_id))


## Capítulo concluído = fase final (chefe) concluída.
func is_chapter_cleared(planet: int) -> bool:
	if Params.debug_unlock_all or unlock_everything:
		return true
	var data: PlanetData = Session.campaign.planets[planet]
	if cleared_chapters.has(String(data.id)):
		return true
	return not data.stages.is_empty() and completed.has(String(data.stages.back().id))


## Nave liberada: inicial (unlock_chapter 0) ou do capítulo já concluído.
func is_ship_unlocked(body: BodyData) -> bool:
	return body.unlock_chapter <= 0 or is_chapter_cleared(body.unlock_chapter - 1)


func is_companion_unlocked() -> bool:
	return Params.companion_unlock_chapter <= 0 or is_chapter_cleared(Params.companion_unlock_chapter - 1)


func best_score(stage_id: StringName) -> int:
	return int(best_scores.get(String(stage_id), 0))


## Marca a fase como concluída (libera a próxima do capítulo) e guarda o recorde.
## Retorna true se for recorde novo.
func complete_stage(stage_id: StringName, score: int) -> bool:
	completed[String(stage_id)] = true
	var record: bool = score > best_score(stage_id)
	if record:
		best_scores[String(stage_id)] = score
	save()
	return record


## Esquadrão escolhido na tela de esquadrão; sem escolha válida (ou com nave
## bloqueada), o esquadrão inicial.
func squad_formation() -> FormationData:
	var roster := load(Params.roster_path) as FormationData
	var formation := FormationData.new()
	for id in squad:
		for body in roster.bodies:
			if String(body.id) == id and is_ship_unlocked(body):
				formation.bodies.append(body)
	if formation.bodies.size() != Params.squad_size:
		return load(Params.formation_path) as FormationData
	return formation


func set_squad(bodies: Array[BodyData]) -> void:
	squad = PackedStringArray()
	for body in bodies:
		squad.append(String(body.id))
	save()


## Nave auxiliar escolhida (null = nenhuma, espaço bloqueado ou nave bloqueada).
func companion_body() -> BodyData:
	if companion.is_empty() or not is_companion_unlocked():
		return null
	var roster := load(Params.roster_path) as FormationData
	for body in roster.bodies:
		if String(body.id) == companion and is_ship_unlocked(body):
			return body
	return null


func set_companion(body: BodyData) -> void:
	companion = "" if body == null else String(body.id)
	save()


## Soma quarks ao saldo (fim de partida).
func add_quarks(amount: int) -> void:
	if amount <= 0:
		return
	quarks += amount
	quarks_earned_total += amount
	save()


func upgrade_level(node: UpgradeData) -> int:
	return UpgradeTreeData.level_of(node, upgrades)


## Compra o próximo nível do nó, se liberado, sem limite atingido e com saldo.
func buy_upgrade(node: UpgradeData) -> bool:
	var tree: UpgradeTreeData = Session.upgrade_tree
	var level: int = upgrade_level(node)
	if node.is_maxed(level) or not tree.is_available(node, upgrades, is_companion_unlocked()):
		return false
	var price: int = node.cost(level + 1)
	if quarks < price:
		return false
	quarks -= price
	upgrades[String(node.id)] = level + 1
	save()
	return true


func unlock_all() -> void:
	unlock_everything = true
	save()


func save() -> void:
	if not persistent:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar o progresso: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"completed": completed.keys(),
		"best_scores": best_scores,
		"unlock_everything": unlock_everything,
		"squad": squad,
		"companion": companion,
		"quarks": quarks,
		"quarks_earned_total": quarks_earned_total,
		"upgrades": upgrades,
		"cleared_chapters": cleared_chapters,
	}


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save inválido, começando do zero")
		return
	from_dict(parsed)


## Lê qualquer versão do save. Versões antigas são convertidas para a atual.
func from_dict(data: Dictionary) -> void:
	unlock_everything = bool(data.get("unlock_everything", false))
	var chosen: Variant = data.get("squad", [])
	if typeof(chosen) == TYPE_ARRAY:
		squad = PackedStringArray(chosen)
	var done: Variant = data.get("completed", [])
	if typeof(done) == TYPE_ARRAY:
		for id in done:
			completed[String(id)] = true
	var scores: Variant = data.get("best_scores", {})
	if typeof(scores) == TYPE_DICTIONARY:
		for id in scores:
			best_scores[String(id)] = int(scores[id])
	companion = String(data.get("companion", ""))
	quarks = maxi(int(data.get("quarks", 0)), 0)
	quarks_earned_total = maxi(int(data.get("quarks_earned_total", quarks)), quarks)
	var levels: Variant = data.get("upgrades", {})
	if typeof(levels) == TYPE_DICTIONARY:
		for id in levels:
			upgrades[String(id)] = maxi(int(levels[id]), 0)
	var cleared: Variant = data.get("cleared_chapters", [])
	if typeof(cleared) == TYPE_ARRAY:
		cleared_chapters = PackedStringArray(cleared)
	if int(data.get("version", 1)) < 3:
		_migrate_legacy_campaign(data)


## Saves 1 e 2 eram da campanha de 13 fases (3, 3, 3 e 4 por capítulo, chefe na última).
## O avanço antigo vira fases concluídas, e cada chefe vencido conta como capítulo
## concluído (libera as recompensas do capítulo, como naves e o espaço auxiliar).
func _migrate_legacy_campaign(data: Dictionary) -> void:
	# Versão 1 guardava só a fase mais avançada liberada, na ordem geral
	var highest: int = int(data.get("legacy_highest_unlocked", data.get("highest_unlocked", -1)))
	var index: int = 0
	for chapter in LEGACY_STAGES.size():
		var stages: PackedStringArray = LEGACY_STAGES[chapter]
		for id in stages:
			if index < highest:
				completed[id] = true
			index += 1
		if completed.has(stages[stages.size() - 1]) and not cleared_chapters.has(LEGACY_PLANETS[chapter]):
			cleared_chapters.append(LEGACY_PLANETS[chapter])
