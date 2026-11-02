extends Node
## Autoload: campanha carregada e fase escolhida, compartilhadas entre as telas.

var campaign: CampaignData
var planet_index: int = 0
var stage_index: int = 0


func _ready() -> void:
	campaign = load(Params.campaign_path) as CampaignData


func select(planet: int, stage: int) -> void:
	planet_index = planet
	stage_index = stage


func planet() -> PlanetData:
	return campaign.planets[planet_index]


func stage() -> StageData:
	return planet().stages[stage_index]


func linear_index() -> int:
	return campaign.linear_index(planet_index, stage_index)


func has_next() -> bool:
	return linear_index() + 1 < campaign.stage_count()


## Avança para a próxima fase (passa para o próximo planeta no fim do atual).
func select_next() -> void:
	if stage_index + 1 < planet().stages.size():
		stage_index += 1
	elif planet_index + 1 < campaign.planets.size():
		planet_index += 1
		stage_index = 0


## Rótulo curto da fase, ex.: "1-2".
func stage_label(planet: int, stage: int) -> String:
	return "%d-%d" % [planet + 1, stage + 1]
