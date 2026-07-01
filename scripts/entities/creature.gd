extends Node2D
class_name Creature
## 城堡上的生物（防御单位）

signal creature_died(creature: Node2D)

var creature_data: Dictionary = {}
var creature_id: String = ""
var attack_power: float = 0.0
var base_attack: float = 0.0
var attack_speed: float = 0.0
var base_speed: float = 0.0
var attack_range: float = 0.0
var base_range: float = 0.0
var attack_cooldown: float = 0.0
var target_priority: String = "nearest"
var faction: int = 0

var synergy_attack_bonus: float = 0.0
var synergy_speed_bonus: float = 0.0
var synergy_range_bonus: float = 0.0
var has_cross_dot: bool = false
var cross_dot_ratio: float = 0.0
var cross_dot_duration: float = 0.0
var stun_chance: float = 0.0
var stun_duration: float = 0.0
var trade_attack_bonus: float = 0.0
var stacking_bonus: float = 0.0
var tech_extra_attack: float = 0.0
var faith_extra_speed: float = 0.0

var aoe_timer: float = 0.0
var summon_timer: float = 0.0

var current_target: Enemy = null
var attack_timer: float = 0.0
var attack_line: Line2D = null
var enemy_container: Node = null

func _ready():
	pass

func setup(data: Dictionary):
	creature_data = data
	creature_id = data.get("id", "")
	base_attack = data.get("attack", 10.0)
	base_speed = data.get("attack_speed", 1.0)
	base_range = data.get("range", 300.0)
	target_priority = data.get("target_priority", "nearest")
	faction = data.get("faction", 0)
	attack_power = base_attack
	attack_speed = base_speed
	attack_range = base_range
	attack_cooldown = 1.0 / attack_speed
	attack_timer = attack_cooldown * 0.3
	if data.has("aoe_cooldown"):
		aoe_timer = data["aoe_cooldown"] * 0.5
	if data.has("summon_cooldown"):
		summon_timer = data["summon_cooldown"] * 0.5
	_draw_sprite()
	attack_line = Line2D.new()
	attack_line.width = 2.0
	attack_line.default_color = Color(0.85, 0.80, 1.0, 0.5)
	attack_line.visible = false
	add_child(attack_line)

func apply_synergy_effects(result: Dictionary) -> void:
	synergy_attack_bonus = result.get("global_attack_bonus", 0.0)
	synergy_speed_bonus = result.get("global_speed_bonus", 0.0)
	synergy_range_bonus = result.get("global_range_bonus", 0.0)
	if result.has("dot_effects"):
		has_cross_dot = not result["dot_effects"].is_empty()
		if has_cross_dot:
			cross_dot_ratio = result["dot_effects"][0]["ratio"]
			cross_dot_duration = result["dot_effects"][0]["duration"]
	stun_chance = result.get("stun_chance", 0.0)
	stun_duration = result.get("stun_duration", 0.0)
	trade_attack_bonus = result.get("trade_attack_bonus", 0.0)
	tech_extra_attack = result.get("tech_attack_bonus", 0.0)
	faith_extra_speed = result.get("faith_speed_bonus", 0.0)

	# 挑战模式卡牌加成
	var challenge_bonus: float = _get_challenge_bonus()

	if creature_data.has("gold_to_attack"):
		var g: int = int(GameData.resources["gold"])
		stacking_bonus = int(g / 100.0) * creature_data["gold_to_attack"]

	var total_attack: float = 1.0 + synergy_attack_bonus + trade_attack_bonus + stacking_bonus + challenge_bonus
	if faction == GameData.Faction.TECH:
		total_attack = total_attack + tech_extra_attack
	attack_power = base_attack * total_attack

	var total_speed: float = 1.0 + synergy_speed_bonus
	if faction == GameData.Faction.FAITH:
		total_speed = total_speed + faith_extra_speed
	# 挑战模式狂暴卡牌
	total_speed += _get_challenge_speed_bonus()
	attack_speed = base_speed * total_speed
	if attack_speed < 0.1:
		attack_speed = 0.1
	attack_cooldown = 1.0 / attack_speed
	attack_range = base_range * (1.0 + synergy_range_bonus)

func _get_challenge_bonus() -> float:
	if not GameData.world_progress.get("challenge_active", false):
		return 0.0
	var bonus: float = 0.0
	bonus += _find_battle_controller_challenge_bonus("synergy")
	bonus += _find_battle_controller_challenge_bonus("attack")
	return bonus

func _get_challenge_speed_bonus() -> float:
	if not GameData.world_progress.get("challenge_active", false):
		return 0.0
	return _find_battle_controller_challenge_bonus("speed")

func _find_battle_controller_challenge_bonus(stat: String) -> float:
	# 向上查找 BattleController 获取 ChallengeManager
	var parent: Node = get_parent()
	while parent:
		if parent.has_method("_draw"):  # BattleController 有 _draw
			if parent.has_node("ChallengeManager"):
				var cm: Node = parent.get_node("ChallengeManager")
				if cm.has_method("get_active_card_bonus"):
					return cm.get_active_card_bonus(stat)
			break
		parent = parent.get_parent()
	return 0.0

func _process(delta):
	aoe_timer = aoe_timer - delta
	summon_timer = summon_timer - delta
	attack_timer = attack_timer - delta

	if creature_data.has("aoe_cooldown") and aoe_timer <= 0.0:
		_trigger_aoe()
		aoe_timer = creature_data["aoe_cooldown"]

	if creature_data.has("summon_cooldown") and summon_timer <= 0.0:
		_trigger_summon()
		summon_timer = creature_data["summon_cooldown"]

	if attack_timer <= 0.0:
		_find_and_attack_target()
		attack_timer = attack_cooldown

	if current_target and is_instance_valid(current_target) and current_target.is_alive:
		attack_line.visible = true
		attack_line.points = PackedVector2Array([Vector2.ZERO, current_target.global_position - global_position])
	else:
		attack_line.visible = false
		current_target = null

func _find_and_attack_target():
	if current_target and is_instance_valid(current_target) and current_target.is_alive:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			_attack_target(current_target)
			return
	var best = _find_best_target()
	if best:
		current_target = best
		_attack_target(best)

func _find_best_target():
	if enemy_container == null:
		return null
	var candidates = []
	for e in enemy_container.get_children():
		if not e is Enemy:
			continue
		if not e.is_alive:
			continue
		if global_position.distance_to(e.global_position) <= attack_range:
			candidates.append(e)
	if candidates.is_empty():
		return null
	if target_priority == "nearest":
		candidates.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	elif target_priority == "lowest_health":
		candidates.sort_custom(func(a, b): return a.current_health < b.current_health)
	elif target_priority == "elite_first":
		candidates.sort_custom(func(a, b):
			if a.is_boss and not b.is_boss:
				return true
			if not a.is_boss and b.is_boss:
				return false
			if a.is_elite and not b.is_elite:
				return true
			if not a.is_elite and b.is_elite:
				return false
			return a.current_health < b.current_health
		)
	return candidates[0]

func _attack_target(target: Enemy) -> void:
	var dmg: float = attack_power

	# 生物自身技能: 暴击
	if creature_data.has("skill_chance"):
		if randf() < creature_data["skill_chance"]:
			dmg = dmg * creature_data["skill_multiplier"]

	# 挑战卡牌: 暴击率
	var challenge_crit: float = _find_battle_controller_challenge_bonus("crit")
	if challenge_crit > 0.0 and randf() < challenge_crit:
		dmg = dmg * 2.0

	if creature_data.has("anti_shield_bonus") and target.armor > 0.0:
		dmg = dmg * (1.0 + creature_data["anti_shield_bonus"])

	if creature_data.has("elite_bonus"):
		if target.is_elite or target.is_boss:
			dmg = dmg * (1.0 + creature_data["elite_bonus"])

	target.take_damage(dmg)

	if creature_data.has("chain_targets"):
		_do_chain_lightning(target, dmg)

	if has_cross_dot:
		var dot_dmg: float = attack_power * cross_dot_ratio / cross_dot_duration
		target.apply_dot(dot_dmg, cross_dot_duration)

	if creature_data.has("burn_ratio"):
		var burn_dmg: float = attack_power * creature_data["burn_ratio"] / creature_data["burn_duration"]
		target.apply_dot(burn_dmg, creature_data["burn_duration"])

	if creature_data.has("poison_ratio"):
		var poison_dmg: float = attack_power * creature_data["poison_ratio"] / creature_data["poison_duration"]
		target.apply_dot(poison_dmg, creature_data["poison_duration"])

	# 挑战卡牌: 淬毒
	if _find_battle_controller_challenge_bonus("poison") > 0.0:
		target.apply_dot(attack_power * 0.1, 3.0)

	if creature_data.has("slow_factor"):
		target.apply_slow(creature_data["slow_factor"], creature_data["slow_duration"])

	if creature_data.has("root_chance") and randf() < creature_data["root_chance"]:
		target.apply_slow(0.0, creature_data["root_duration"])

	if stun_chance > 0.0 and randf() < stun_chance:
		target.apply_slow(0.0, stun_duration)

	if creature_data.has("vulnerable_ratio"):
		target.apply_vulnerable(creature_data["vulnerable_ratio"], creature_data["vulnerable_duration"], creature_data.get("max_stacks", 3))

	if creature_data.has("echo_ratio"):
		var echo_dmg: float = dmg * creature_data["echo_ratio"]
		var echo_delay: float = creature_data.get("echo_delay", 0.3)
		var t: Enemy = target
		get_tree().create_timer(echo_delay).timeout.connect(func():
			if is_instance_valid(t) and t.is_alive:
				t.take_damage(echo_dmg)
		)

	if creature_data.has("enemy_slow_ratio"):
		target.apply_attack_slow(creature_data["enemy_slow_ratio"], creature_data["enemy_slow_duration"])

	if creature_data.has("gold_chance") and randf() < creature_data["gold_chance"]:
		GameData.add_resource("gold", creature_data["gold_amount"])

	# 挑战卡牌: 淘金热
	var gold_bonus: float = _find_battle_controller_challenge_bonus("gold")
	if gold_bonus > 0.0 and randf() < 0.3:
		GameData.add_resource("gold", int(5 * gold_bonus))

func _do_chain_lightning(initial_target: Enemy, damage: float):
	var chain_targets = [initial_target]
	if enemy_container == null:
		return
	for e in enemy_container.get_children():
		if e is Enemy and e.is_alive and e != initial_target:
			if global_position.distance_to(e.global_position) <= attack_range * 1.5:
				chain_targets.append(e)
	var chain_count = creature_data.get("chain_targets", 2)
	var d = damage
	var max_i = chain_count + 1
	if max_i > chain_targets.size():
		max_i = chain_targets.size()
	for i in range(1, max_i):
		d = d * (1.0 - creature_data.get("chain_decay", 0.3))
		chain_targets[i].take_damage(d)

func _trigger_aoe():
	if enemy_container == null:
		return
	var aoe_rng = creature_data.get("aoe_range", 200.0)
	var aoe_rat = creature_data.get("aoe_ratio", 0.8)
	for e in enemy_container.get_children():
		if e is Enemy and e.is_alive:
			if global_position.distance_to(e.global_position) <= aoe_rng:
				e.take_damage(attack_power * aoe_rat)

func _trigger_summon():
	var summon_id = creature_data.get("summon_id", "")
	if summon_id == "":
		return
	var summon_data = GameData.get_creature_data(summon_id)
	if summon_data.is_empty():
		return
	var creature_scene = load("res://scenes/creature.tscn")
	if creature_scene == null:
		return
	var c = creature_scene.instantiate()
	c.setup(summon_data)
	c.position = position + Vector2(randi() % 60 - 30, -20)
	c.set_enemy_container(enemy_container)
	get_parent().add_child(c)
	var dur = creature_data.get("summon_duration", 8.0)
	var timer = get_tree().create_timer(dur)
	await timer.timeout
	if is_instance_valid(c):
		c.queue_free()

func set_enemy_container(container: Node):
	enemy_container = container

func _draw_sprite():
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	var sprite = Sprite2D.new()
	var fc = GameData.get_faction_color(faction)
	var s: int = 32
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)

	if faction == GameData.Faction.TECH:
		img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)
		img.fill_rect(Rect2i(8, 8, s - 16, s - 16), fc.lightened(0.3))
	elif faction == GameData.Faction.FAITH:
		for y in range(s):
			for x in range(s):
				var dx = float(x) - float(s) / 2.0
				var dy = float(y) - float(s) / 2.0
				if abs(dx) + abs(dy) < float(s) / 2.0 - 2.0:
					img.set_pixel(x, y, fc)
	elif faction == GameData.Faction.NATURE:
		for y in range(s):
			for x in range(s):
				var dx = float(x) - float(s) / 2.0
				var dy = float(y) - float(s) / 2.0
				if dx * dx + dy * dy < (float(s) / 2.0 - 2.0) * (float(s) / 2.0 - 2.0):
					img.set_pixel(x, y, fc)
	elif faction == GameData.Faction.COMMERCE:
		for y in range(s):
			for x in range(s):
				var dx = float(x) - float(s) / 2.0
				var dy = float(y) - float(s) / 2.0
				if abs(dx) + abs(dy) < float(s) / 2.0 - 2.0:
					img.set_pixel(x, y, fc.lightened(0.1))
	elif faction == GameData.Faction.MEMORY:
		img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)
	else:
		img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)

	var tex = ImageTexture.new()
	tex.set_image(img)
	sprite.texture = tex
	sprite.position = Vector2(0, -20)
	add_child(sprite)
	var label = Label.new()
	label.text = creature_data.get("name", "???")
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", fc)
	label.position = Vector2(-25, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(70, 18)
	add_child(label)
