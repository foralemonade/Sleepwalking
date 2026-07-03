extends Node
## 主角技能系统 v0.4 - 支援技能的释放、冷却、效果执行
## v0.4 变更:
##   - 新增 healing_flow (治愈流): 消耗25能量, 为目标生物恢复30% HP
##   - heal 技能现在也恢复 core_hp (护盾过载)
##   - 治愈流选择目标生物模式

class_name SkillSystem

var max_energy: float = 100.0
var current_energy: float = 50.0
var energy_regen: float = 2.0

var skill_database: Dictionary = {}
var cooldowns: Dictionary = {}

func _ready() -> void:
	_init_skill_database()

func _init_skill_database() -> void:
	skill_database = {
		"energy_burst": {
			"id":"energy_burst","name":"能量爆发","desc":"对场上所有敌人造成 50 伤害",
			"cost":30,"cooldown":15.0,"type":"damage","value":50,
		},
		"shield_overload": {
			"id":"shield_overload","name":"护盾过载","desc":"立即恢复城堡 30 护盾 + 20 核心HP",
			"cost":25,"cooldown":12.0,"type":"heal_castle","shield_value":30,"core_value":20,
		},
		"time_freeze": {
			"id":"time_freeze","name":"时间凝滞","desc":"所有敌人减速 80%，持续 3 秒",
			"cost":40,"cooldown":20.0,"type":"slow","value":0.20,"duration":3.0,
		},
		"reinforcement": {
			"id":"reinforcement","name":"紧急增援","desc":"召唤一只临时生物战斗 10 秒",
			"cost":35,"cooldown":18.0,"type":"summon","duration":10.0,
		},
		"airstrike": {
			"id":"airstrike","name":"空袭","desc":"对血量最低的 3 个敌人造成 80 伤害",
			"cost":45,"cooldown":25.0,"type":"snipe","value":80,"targets":3,
		},
		"healing_flow": {
			"id":"healing_flow","name":"治愈流","desc":"为目标生物恢复 30% HP",
			"cost":25,"cooldown":10.0,"type":"heal_creature","heal_ratio":0.30,
		},
	}
	for skill_id: String in skill_database:
		cooldowns[skill_id] = 0.0

func _process(delta: float) -> void:
	if current_energy < max_energy:
		current_energy = minf(max_energy, current_energy + energy_regen * delta)
	for skill_id: String in cooldowns:
		if cooldowns[skill_id] > 0.0:
			cooldowns[skill_id] -= delta

func use_skill(skill_id: String, enemy_container: Node, castle: Castle) -> bool:
	if not skill_database.has(skill_id):
		return false
	if cooldowns[skill_id] > 0.0:
		return false
	var skill: Dictionary = skill_database[skill_id]
	if current_energy < skill["cost"]:
		return false

	current_energy -= skill["cost"]
	cooldowns[skill_id] = skill["cooldown"]
	EventBus.skill_used.emit(skill_id)
	EventBus.energy_changed.emit(current_energy, max_energy)

	match skill["type"]:
		"damage":
			_damage_all(enemy_container, skill["value"])
		"heal_castle":
			_heal_castle(castle, skill["shield_value"], skill.get("core_value", 0.0))
		"slow":
			_slow_all(enemy_container, skill["value"], skill["duration"])
		"summon":
			_summon_reinforcement(castle, skill["duration"])
		"snipe":
			_snipe_targets(enemy_container, skill["value"], skill["targets"])
		"heal_creature":
			# 治愈流需要选择目标 — 由 BattleUI 处理目标选择后调用 use_healing_flow
			pass
	return true

## 治愈流: 为指定目标生物恢复 HP
func use_healing_flow(target_cid: String) -> bool:
	var skill: Dictionary = skill_database.get("healing_flow", {})
	if skill.is_empty():
		return false
	if cooldowns["healing_flow"] > 0.0:
		return false
	if current_energy < skill["cost"]:
		return false

	current_energy -= skill["cost"]
	cooldowns["healing_flow"] = skill["cooldown"]
	EventBus.skill_used.emit("healing_flow")
	EventBus.energy_changed.emit(current_energy, max_energy)

	var heal_ratio: float = skill.get("heal_ratio", 0.30)
	var max_hp: float = GameData.get_creature_max_hp(target_cid)
	var heal_amount: float = max_hp * heal_ratio
	GameData.creature_heal(target_cid, heal_amount)
	EventBus.heal_skill_used.emit(target_cid, heal_amount)
	print("[SkillSystem] 治愈流: %s 恢复 %.0f HP" % [target_cid, heal_amount])
	return true

func _heal_castle(castle: Castle, shield_value: float, core_value: float) -> void:
	if castle == null:
		return
	# 护盾恢复
	castle.current_shield = mini(castle.max_shield, castle.current_shield + int(shield_value))
	castle.shield_changed.emit(castle.current_shield, castle.max_shield)
	# 核心HP恢复
	if core_value > 0.0:
		castle.core_hp = minf(castle.core_hp_max, castle.core_hp + core_value)
		castle.core_hp_changed.emit(castle.core_hp, castle.core_hp_max)
		castle.update_core_hp_bar()

func _damage_all(container: Node, damage: float) -> void:
	if container == null:
		return
	for e: Node in container.get_children():
		if e is Enemy and e.is_alive:
			e.take_damage(damage)

func _slow_all(container: Node, factor: float, duration: float) -> void:
	if container == null:
		return
	for e: Node in container.get_children():
		if e is Enemy and e.is_alive:
			e.apply_slow(factor, duration)

func _snipe_targets(container: Node, damage: float, count: int) -> void:
	if container == null:
		return
	var enemies: Array[Enemy] = []
	for e: Node in container.get_children():
		if e is Enemy and e.is_alive:
			enemies.append(e)
	enemies.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.current_health < b.current_health)
	for i in range(min(count, enemies.size()):
		enemies[i].take_damage(damage)

func _summon_reinforcement(castle: Castle, duration: float) -> void:
	if castle == null:
		return
	var ids: Array[String] = ["mech_sniper","spirit_wisp","thorn_beast","scrap_gambler","echo_walker"]
	var pick: String = ids[randi() % ids.size()]
	var data: Dictionary = GameData.get_creature_data(pick)
	if data.is_empty():
		return
	var creature_scene: PackedScene = load("res://scenes/creature.tscn")
	if creature_scene == null:
		return
	var c: Node2D = creature_scene.instantiate()
	c.setup(data)
	c.position = Vector2(randi() % 60 - 30, -40)
	c.set_enemy_container(castle.enemy_container)
	# 设置 creature_container, 使治疗型召唤物能找到友方
	if c.has_method("set_creature_container"):
		c.set_creature_container(castle)
	castle.add_child(c)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(c):
		c.queue_free()

func get_cooldown(skill_id: String) -> float:
	return maxf(0.0, cooldowns.get(skill_id, 0.0))

func get_cooldown_max(skill_id: String) -> float:
	if skill_database.has(skill_id):
		return skill_database[skill_id]["cooldown"]
	return 0.0
