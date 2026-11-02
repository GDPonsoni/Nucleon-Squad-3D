class_name NodePool
extends Node2D
## Pool genérico: cria todos os itens no início e os reaproveita.
## Nunca instancia nem destrói itens durante a partida.

## Itens em uso. Para remover itens durante uma iteração, percorra de trás para frente.
var active: Array[PoolItem] = []

var _free: Array[PoolItem] = []


func _init(factory: Callable, size: int) -> void:
	for i in size:
		var item: PoolItem = factory.call()
		add_child(item)
		item.deactivate()
		item.expired.connect(release)
		_free.append(item)


## Retorna null se o pool estiver esgotado. Chame activate(...) no item retornado.
func acquire() -> PoolItem:
	if _free.is_empty():
		return null
	var item: PoolItem = _free.pop_back()
	active.append(item)
	return item


func release(item: PoolItem) -> void:
	var index: int = active.find(item)
	if index == -1:
		return
	active.remove_at(index)
	item.deactivate()
	_free.append(item)
