class_name RunChoice
extends RefCounted
## Uma opção da tela de subir de nível: arma nova, subir uma arma que já tem ou quarks.

enum Kind { NEW_WEAPON, UPGRADE, QUARKS }

var kind: Kind = Kind.QUARKS
var body: BodyData  # nave dona da arma (nome, cor e ícone); null em QUARKS
var to_level: int = 1  # nível da arma depois de escolher
var quarks: int = 0


static func weapon(ship: BodyData, level: int) -> RunChoice:
	var choice := RunChoice.new()
	choice.kind = Kind.NEW_WEAPON if level <= 1 else Kind.UPGRADE
	choice.body = ship
	choice.to_level = level
	return choice


static func reward(amount: int) -> RunChoice:
	var choice := RunChoice.new()
	choice.kind = Kind.QUARKS
	choice.quarks = amount
	return choice
