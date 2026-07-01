extends Node2D
class_name Castle
## 移动城堡 - 核心战斗单位

signal shield_changed(current: int, max_hp: int)
signal castle_destroyed()

@export var max_shield: int = 100
var current_shield: int = 100
var shield_regen: float = 0.0

@export var slot_count: int = 4
var creature_slots: Array[Dictionary] = []
var slot_positions: Array[Vector2] = []
var current_creature_ids: Array[String] = []

var synergy_system: Node = null
var enemy_container: Node = null

func _ready():
	current_shield = max_shield
	slot_positions = [
		Vector2(-50, -80), Vector2(50, -80),
		Vector2(-50, -30), Vector2(50, -30),
	]
	for i in range(slot_count):
		var pos = Vector2.ZERO
		if i < slot_positions.size():
			pos = slot_positions[i]
		creature_slots.append({
			"creature": null,
			"creature_id": "",
			"position": pos,
		})
	var synergy_script = load("res://scripts/systems/faction_synergy.gd")
	synergy_system = synergy_script.new()
	synergy_system.name = "FactionSynergyCalculator"
	add_child(synergy_system)
	_draw_castle()

func _process(delta: float) -> void:
	var total_regen: float = shield_regen
	# 挑战模式卡牌加成: 治愈光环
	if GameData.world_progress.get("challenge_active", false):
		total_regen += _get_challenge_regen_bonus()
	# 背水一战: 低血量时
	if GameData.world_progress.get("challenge_active", false) and current_shield < max_shield * 0.3:
		total_regen += 1.0

	if total_regen > 0.0 and current_shield < max_shield:
		var new_shield: float = float(current_shield) + total_regen * delta
		if new_shield > float(max_shield):
			new_shield = float(max_shield)
		current_shield = int(new_shield)
		shield_changed.emit(current_shield, max_shield)

func _draw_castle():
	var sprite = Sprite2D.new()
	var s = 160
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(10, 30, s - 20, s - 40), Color(0.45, 0.40, 0.65))
	img.fill_rect(Rect2i(20, 10, s - 40, 25), Color(0.55, 0.50, 0.72))
	var win_positions = [30, 70, 110]
	for wx in win_positions:
		img.fill_rect(Rect2i(wx, 50, 20, 20), Color(0.75, 0.75, 1.0, 0.8))
	img.fill_rect(Rect2i(65, 100, 30, 50), Color(0.35, 0.28, 0.50))
	img.fill_rect(Rect2i(10, 130, 30, 20), Color(0.40, 0.35, 0.45))
	img.fill_rect(Rect2i(120, 130, 30, 20), Color(0.40, 0.35, 0.45))
	var tex = ImageTexture.new()
	tex.set_image(img)
	sprite.texture = tex
	sprite.position = Vector2(float(-s) / 2.0, float(-s) / 2.0)
	add_child(sprite)

func place_creature(slot_index: int, creature_id: String) -> bool:
	if slot_index < 0 or slot_index >= creature_slots.size():
		return false
	var slot = creature_slots[slot_index]
	if slot["creature"] != null:
		remove_creature(slot_index)
	var data = GameData.get_creature_data(creature_id)
	if data.is_empty():
		return false
	var creature_scene = load("res://scenes/creature.tscn")
	if creature_scene == null:
		return false
	var c = creature_scene.instantiate()
	c.setup(data)
	c.position = slot["position"]
	c.set_enemy_container(enemy_container)
	add_child(c)
	slot["creature"] = c
	slot["creature_id"] = creature_id
	_refresh_creature_ids()
	_recalculate_synergies()
	EventBus.creature_placed.emit(slot_index, creature_id)
	return true

func remove_creature(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= creature_slots.size():
		return false
	var slot = creature_slots[slot_index]
	if slot["creature"] != null:
		slot["creature"].queue_free()
		slot["creature"] = null
		slot["creature_id"] = ""
		_refresh_creature_ids()
		_recalculate_synergies()
		EventBus.creature_removed.emit(slot_index)
		return true
	return false

func _refresh_creature_ids():
	current_creature_ids.clear()
	for slot in creature_slots:
		if slot["creature_id"] != "" and slot["creature_id"] != null:
			current_creature_ids.append(slot["creature_id"])

func _recalculate_synergies():
	var result = synergy_system.analyze_synergies(current_creature_ids)
	shield_regen = result.get("castle_regen", 0.0)
	for slot in creature_slots:
		if slot["creature"] != null:
			var c = slot["creature"]
			c.apply_synergy_effects(result)
	EventBus.synergy_updated.emit(result)

func take_damage(amount: int):
	var actual = amount
	if actual < 1:
		actual = 1
	current_shield = current_shield - actual
	if current_shield < 0:
		current_shield = 0
	shield_changed.emit(current_shield, max_shield)
	EventBus.castle_damaged.emit(current_shield, max_shield)
	if current_shield <= 0:
		castle_destroyed.emit()
		EventBus.castle_destroyed.emit()

func get_placed_creatures() -> Array[Node]:
	var r: Array[Node] = []
	for slot in creature_slots:
		if slot["creature"] != null:
			r.append(slot["creature"])
	return r

func set_enemy_container(container: Node) -> void:
	enemy_container = container

func _get_challenge_regen_bonus() -> float:
	var parent: Node = get_parent()
	while parent:
		if parent.has_node("ChallengeManager"):
			var cm: Node = parent.get_node("ChallengeManager")
			if cm.has_method("get_active_card_bonus"):
				return cm.get_active_card_bonus("regen")
			break
		parent = parent.get_parent()
	return 0.0
