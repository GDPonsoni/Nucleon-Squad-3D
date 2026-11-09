extends Node
## Autoload: tutorial contextual e avisos de desbloqueio, dirigidos por data/tutorial/tips.json.
##
## Dicas (kind tip): o jogo avisa eventos com notify() (e, na partida, o elemento envolvido:
## o power-up que apareceu, o inimigo que vai atacar...); as dicas ainda não vistas cujo gatilho
## casa entram numa fila por contexto (match = destaque com pausa na partida, na primeira vez
## que o evento acontece; screen = janela nas telas; end = janela ao fim da fase). Cada contexto tem um apresentador (attach) que diz se é seguro
## mostrar agora (can_show) e como mostrar (present). Uma dica por vez, com intervalo mínimo
## entre elas. Toda dica mostrada é gravada como vista (nunca repete) e é sempre pulável.
## Avisos de desbloqueio: show_unlocks() mostra um diálogo por recompensa do capítulo, em fila.

const MATCH: StringName = &"match"
const SCREEN: StringName = &"screen"
const END: StringName = &"end"

var tips: Array[Dictionary] = []
var unlock_defs: Array[Dictionary] = []

var _queue: Dictionary = {}  # contexto -> Array de {"id": String, "at": int (ms)}
var _presenters: Dictionary = {}  # contexto -> apresentador (objeto com can_show/present)
var _showing: Dictionary = {}  # contexto -> bool
var _next_at: Dictionary = {}  # contexto -> ms (tempo real) a partir do qual pode mostrar
var _by_event: Dictionary = {}  # evento -> dicas com esse gatilho (notify chamado muitas vezes)


func _ready() -> void:
	load_tips()


## Lê o arquivo de dicas (também usado nos testes com outro caminho).
func load_tips(path: String = Params.tips_path) -> void:
	tips.clear()
	unlock_defs.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Tutorial: arquivo de dicas inválido (%s)" % path)
		return
	_by_event.clear()
	for entry in parsed.get("tips", []):
		tips.append(entry)
		var event := StringName(entry["event"])
		if not _by_event.has(event):
			_by_event[event] = []
		_by_event[event].append(entry)
	for entry in parsed.get("unlocks", []):
		unlock_defs.append(entry)


func tips_enabled() -> bool:
	return bool(SaveGame.setting("tips_enabled"))


func tip_by_id(id: String) -> Dictionary:
	for tip in tips:
		if tip["id"] == id:
			return tip
	return {}


## Liga o apresentador de um contexto. Dicas de eventos anteriores ficam esperando a vez.
func attach(context: StringName, presenter: Object) -> void:
	_presenters[context] = presenter
	_showing[context] = false
	var delay: float = Params.tip_first_delay_match_seconds if context == MATCH else Params.tip_first_delay_seconds
	_next_at[context] = _now() + int(delay * 1000.0)
	_queue[context] = []


func detach(context: StringName, presenter: Object) -> void:
	if _presenters.get(context) == presenter:
		_presenters.erase(context)
		_showing[context] = false
		_queue[context] = []


## Abre uma tela com dicas: o apresentador mostra uma janela quando não houver outra aberta.
func open_screen(screen: Node, event: StringName) -> void:
	var presenter := ScreenTipPresenter.new(screen)
	attach(SCREEN, presenter)
	screen.tree_exiting.connect(detach.bind(SCREEN, presenter))
	notify(event)


## Algo aconteceu no jogo. Enfileira as dicas não vistas desse gatilho. target (opcional) é o
## elemento envolvido, destacado na dica da partida.
func notify(event: StringName, stage_id: String = "", target: Variant = null) -> void:
	if not _by_event.has(event) or not tips_enabled():
		return
	for tip in _by_event[event]:
		if not _stage_matches(tip, stage_id) or not _requirement_met(tip):
			continue
		var context := StringName(tip["context"])
		if SaveGame.is_tip_seen(tip["id"]) or _is_queued(context, tip["id"]):
			continue
		if not _queue.has(context):
			_queue[context] = []
		var ref: WeakRef = weakref(target) if target is Object else null
		_queue[context].append({"id": tip["id"], "at": _now(), "target": ref})


func _stage_matches(tip: Dictionary, stage_id: String) -> bool:
	return not tip.has("stage") or String(tip["stage"]) == stage_id


func _requirement_met(tip: Dictionary) -> bool:
	match String(tip.get("requires", "")):
		"companion_unlocked":
			return SaveGame.is_companion_unlocked()
	return true


func _is_queued(context: StringName, id: String) -> bool:
	for item in _queue.get(context, []):
		if item["id"] == id:
			return true
	return false


func _process(_delta: float) -> void:
	for context in _presenters.keys():
		if context != END:
			_try_present(context)


func _try_present(context: StringName) -> void:
	if _showing.get(context, false):
		return
	var presenter: Object = _presenters[context]
	if not is_instance_valid(presenter):
		_presenters.erase(context)
		return
	if not tips_enabled():
		_queue[context] = []
		return
	var items: Array = _queue.get(context, [])
	_drop_stale(context, items)
	if items.is_empty():
		return
	var tip: Dictionary = tip_by_id(items[0]["id"])
	# Dicas de abertura ("intro") aparecem já, uma atrás da outra; as outras respeitam o intervalo
	var intro: bool = bool(tip.get("intro", false))
	if not intro and _now() < int(_next_at.get(context, 0)):
		return
	if tip.is_empty() or SaveGame.is_tip_seen(tip["id"]):
		items.pop_front()
		return
	# Na partida, a dica espera um pouco depois do evento: dá tempo de ver o que aconteceu
	if context == MATCH and not intro and _now() - int(items[0]["at"]) < int(event_delay(tip) * 1000.0):
		return
	if not presenter.can_show(tip):
		return
	var item: Dictionary = items.pop_front()
	var ref: WeakRef = item.get("target")
	var target: Variant = ref.get_ref() if ref != null else null
	if ref != null and not tip.has("highlight") and not _target_alive(target):
		return  # o elemento já sumiu: a dica volta a disparar na próxima vez
	_begin(context, tip, presenter, target)


## Dicas de partida que esperaram demais (o momento passou) saem da fila e voltam a poder disparar.
func _drop_stale(context: StringName, items: Array) -> void:
	if context != MATCH:
		return
	var limit: int = int(Params.tip_expire_seconds * 1000.0)
	for i in range(items.size() - 1, -1, -1):
		if _now() - int(items[i]["at"]) > limit:
			items.remove_at(i)


## Segundos entre o evento e a dica aparecer ("delay" na dica ou o padrão).
func event_delay(tip: Dictionary) -> float:
	return float(tip.get("delay", Params.tip_event_delay_seconds))


func _target_alive(target: Variant) -> bool:
	return target is CanvasItem and is_instance_valid(target) and (target as CanvasItem).is_visible_in_tree()


func _begin(context: StringName, tip: Dictionary, presenter: Object, target: Variant = null) -> void:
	SaveGame.mark_tip_seen(tip["id"])
	_showing[context] = true
	presenter.present(tip, _finished.bind(context, tip), target)


func _finished(context: StringName, tip: Dictionary = {}) -> void:
	_showing[context] = false
	var gap: float = Params.tip_gap_match_seconds if context == MATCH else Params.tip_gap_screen_seconds
	if tip.has("gap"):
		gap = float(tip["gap"])  # a dica diz quanto esperar até a próxima
	_next_at[context] = _now() + int(gap * 1000.0)


## "Não mostrar mais": desliga todas as dicas (Configurações > rever tutorial religa).
func disable_tips() -> void:
	SaveGame.set_setting("tips_enabled", false)
	for context in _queue.keys():
		_queue[context] = []


## Fim de fase: mostra, em fila, as dicas do contexto "end" ainda não vistas (no máximo tip_end_max).
func show_end_tips(parent: Node) -> void:
	var items: Array = _queue.get(END, [])
	_queue[END] = []
	var shown: int = 0
	for item in items:
		if shown >= Params.tip_end_max or not tips_enabled():
			break
		var tip: Dictionary = tip_by_id(item["id"])
		if tip.is_empty() or SaveGame.is_tip_seen(tip["id"]):
			continue
		if shown > 0:
			await get_tree().create_timer(Params.tip_unlock_gap_seconds, true, false, true).timeout
		SaveGame.mark_tip_seen(tip["id"])
		var dialog := TipDialog.open_tip(parent, tip)
		await dialog.closed
		shown += 1


## Avisos do que o capítulo concluído liberou, ainda não vistos. Cada item:
## {"id", "text" (já traduzido), "body" (BodyData ou null)}.
func unlock_notices(planet_index: int) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	var chapter: int = planet_index + 1
	for def in unlock_defs:
		match String(def["reward"]):
			"ship":
				var roster := load(Params.roster_path) as FormationData
				for body in roster.bodies:
					if body.unlock_chapter == chapter:
						_add_notice(notices, "%s_%s" % [def["id"], body.id], tr(def["text_key"]) % tr(body.name_key), body)
			"companion":
				if Params.companion_unlock_chapter == chapter:
					_add_notice(notices, String(def["id"]), tr(def["text_key"]), null)
			"planet":
				if planet_index + 1 < Session.campaign.planets.size():
					var next: PlanetData = Session.campaign.planets[planet_index + 1]
					_add_notice(notices, "%s_%s" % [def["id"], next.id], tr(def["text_key"]) % tr(next.name_key), null)
	return notices


func _add_notice(notices: Array[Dictionary], id: String, text: String, body: BodyData) -> void:
	if not SaveGame.is_tip_seen(id):
		notices.append({"id": id, "text": text, "body": body})


## Mostra um aviso por recompensa, um depois do outro (com intervalo). Cada um tem X e botão OK.
func show_unlocks(parent: Node, planet_index: int) -> void:
	var notices: Array[Dictionary] = unlock_notices(planet_index)
	for i in notices.size():
		if i > 0:
			await get_tree().create_timer(Params.tip_unlock_gap_seconds, true, false, true).timeout
		SaveGame.mark_tip_seen(notices[i]["id"])
		Audio.play(&"special_ready")
		var dialog := UnlockNotice.open_notice(parent, notices[i])
		await dialog.closed


func _now() -> int:
	return Time.get_ticks_msec()
