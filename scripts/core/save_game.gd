extends Node
## Autoload: progresso salvo no aparelho em JSON versionado (user://save.json),
## pensado para migração e sincronização futuras.

const PATH: String = "user://save.json"
const VERSION: int = 2

var completed: Dictionary = {}  # id da fase -> true (fases concluídas)
var best_scores: Dictionary = {}  # id da fase -> melhor pontuação
var unlock_everything: bool = false  # atalho de debug do seletor
var squad: PackedStringArray = PackedStringArray()  # ids dos corpos escolhidos, em ordem
## Versão 1 do save: fase mais avançada na ordem geral. Só é lida (compatibilidade).
var legacy_highest_unlocked: int = -1


func _ready() -> void:
	load_data()


## A primeira fase de cada capítulo está sempre liberada; as outras, quando a
## anterior do mesmo capítulo foi concluída.
func is_unlocked(planet: int, stage: int) -> bool:
	if Params.debug_unlock_all or unlock_everything or stage == 0:
		return true
	if Session.campaign.linear_index(planet, stage) <= legacy_highest_unlocked:
		return true
	var previous: StageData = Session.campaign.planets[planet].stages[stage - 1]
	return completed.has(String(previous.id))


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


## Esquadrão escolhido na tela de esquadrão; sem escolha válida, o esquadrão inicial.
func squad_formation() -> FormationData:
	var roster := load(Params.roster_path) as FormationData
	var formation := FormationData.new()
	for id in squad:
		for body in roster.bodies:
			if String(body.id) == id:
				formation.bodies.append(body)
	if formation.bodies.size() != Params.squad_size:
		return load(Params.formation_path) as FormationData
	return formation


func set_squad(bodies: Array[BodyData]) -> void:
	squad = PackedStringArray()
	for body in bodies:
		squad.append(String(body.id))
	save()


func unlock_all() -> void:
	unlock_everything = true
	save()


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar o progresso: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"version": VERSION,
		"completed": completed.keys(),
		"best_scores": best_scores,
		"unlock_everything": unlock_everything,
		"squad": squad,
		"legacy_highest_unlocked": legacy_highest_unlocked,
	}, "\t"))


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save inválido, começando do zero")
		return
	var data: Dictionary = parsed
	if data.has("highest_unlocked"):
		# Save da versão 1
		legacy_highest_unlocked = int(data["highest_unlocked"])
	legacy_highest_unlocked = int(data.get("legacy_highest_unlocked", legacy_highest_unlocked))
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
		best_scores = scores
