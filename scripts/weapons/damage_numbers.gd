class_name DamageNumbers
extends Node2D
## Contador de dano: números que sobem e somem onde o inimigo foi atingido. Os acertos no mesmo
## alvo se somam numa janela curta (Params.damage_number_window), então o Raio e as rajadas
## mostram um número por janela e não um por tiro. Pooled. Liga/desliga em Configurações.

var _pool: NodePool
## alvo (instance id) -> {"target", "amount", "color", "pos", "age"}
var _pending: Dictionary = {}


func _init() -> void:
	_pool = NodePool.new(DamageNumber.new, Params.damage_number_pool_size)
	_pool.name = "Pool"
	add_child(_pool)


## Registra dano num alvo (ignora se o contador está desligado).
func report(target: Node2D, amount: float, color: Color = Color.WHITE) -> void:
	if amount <= 0.0 or not bool(SaveGame.setting("damage_numbers")):
		return
	var id: int = target.get_instance_id()
	var entry: Dictionary = _pending.get(id, {"target": target, "amount": 0.0, "age": 0.0})
	entry["amount"] = float(entry["amount"]) + amount
	entry["color"] = color
	entry["pos"] = target.position
	_pending[id] = entry


func _process(delta: float) -> void:
	for id in _pending.keys():
		var entry: Dictionary = _pending[id]
		entry["age"] = float(entry["age"]) + delta
		var target: Node2D = entry["target"] if is_instance_valid(entry["target"]) else null
		if target != null:
			entry["pos"] = target.position
		if float(entry["age"]) >= Params.damage_number_window or target == null:
			_show(entry)
			_pending.erase(id)


func _show(entry: Dictionary) -> void:
	var item := _pool.acquire() as DamageNumber
	if item != null:
		item.activate(entry["pos"] + Vector2(randf_range(-20.0, 20.0), -30.0), float(entry["amount"]), entry["color"])
