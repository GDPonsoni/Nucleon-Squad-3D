class_name CampaignData
extends Resource
## Lista de planetas em ordem de progressão. Valor em data/campaign.tres.

@export var planets: Array[PlanetData] = []


## Posição da fase na ordem geral (0, 1, 2... atravessando os planetas).
func linear_index(planet: int, stage: int) -> int:
	var index: int = stage
	for p in planet:
		index += planets[p].stages.size()
	return index


func stage_count() -> int:
	return linear_index(planets.size(), 0)
