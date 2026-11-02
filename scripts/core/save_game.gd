extends Node
## Autoload: progresso salvo no aparelho em JSON versionado (user://save.json),
## pensado para migração e sincronização futuras.

const PATH: String = "user://save.json"
const VERSION: int = 1

var highest_unlocked: int = 0  # índice linear da fase mais avançada liberada
var best_scores: Dictionary = {}  # id da fase -> melhor pontuação


func _ready() -> void:
	load_data()


func is_unlocked(linear_index: int) -> bool:
	return Params.debug_unlock_all or linear_index <= highest_unlocked


func best_score(stage_id: StringName) -> int:
	return int(best_scores.get(String(stage_id), 0))


## Libera a próxima fase e guarda o recorde. Retorna true se for recorde novo.
func complete_stage(linear_index: int, stage_id: StringName, score: int) -> bool:
	highest_unlocked = maxi(highest_unlocked, linear_index + 1)
	var record: bool = score > best_score(stage_id)
	if record:
		best_scores[String(stage_id)] = score
	save()
	return record


func unlock_all() -> void:
	highest_unlocked = Session.campaign.stage_count() - 1
	save()


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar o progresso: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"version": VERSION,
		"highest_unlocked": highest_unlocked,
		"best_scores": best_scores,
	}, "\t"))


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save inválido, começando do zero")
		return
	var data: Dictionary = parsed
	highest_unlocked = int(data.get("highest_unlocked", 0))
	var scores: Variant = data.get("best_scores", {})
	if typeof(scores) == TYPE_DICTIONARY:
		best_scores = scores
