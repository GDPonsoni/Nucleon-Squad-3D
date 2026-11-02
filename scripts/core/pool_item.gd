class_name PoolItem
extends Node2D
## Base dos itens de um NodePool (projéteis, inimigos, efeitos).
## A subclasse define seu activate(...) e chama _set_active() ao final.

signal expired(item: PoolItem)


func _ready() -> void:
	# O Godot reativa o _process ao entrar na árvore: começa desligado
	deactivate()


func deactivate() -> void:
	visible = false
	set_process(false)


## Devolve o item ao pool.
func expire() -> void:
	expired.emit(self)


func _set_active() -> void:
	visible = true
	set_process(true)
