extends Node2D
class_name Creature
## 梦游症 - 战场生物实体 v0.4
## 固定站位自动攻击最近目标，有HP可被打死，受伤4阶段视觉反馈
## v0.4 变更: 加 max_hp/current_hp/受伤4阶段/死亡/血条/治疗被动

signal creature_died(creature_id: String)
signal health_changed(current: float, max_hp: float, stage: int)

# ── 核心属性 ──
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
var role: int = 0
var position_type: int = 0

# ── HP与受伤系统 ──
var max_hp: float = 100.0
var current_hp: float = 100.0
var injury_stage: int = 0  # GameData.InjuryStage
var is_dead: bool = false

# ── 协同加成 ──
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

# ── 计时器 ──
var aoe_timer: float = 0.0
var summon_timer: float = 0.0
var heal_ally_timer: float = 0.0
var current_target: Enemy = null
var attack_timer: float = 0.0
var attack_line: Line2D = null
var enemy_container: Node = null
var creature_container: Node = null  # 用于寻找友方生物(治疗)

# ── 视觉 ──
var hp_bar_bg: ColorRect = null
var hp_bar: ColorRect = null
var injury_indicator: ColorRect = null
var sprite_node: Sprite2D = null

func _ready() -> void:
	pass

func setup(data: Dictionary) -> void:
	creature_data = data
	creature_id = data.get("id", "")
	base_attack = data.get("attack", 10.0)
	base_speed = data.get("attack_speed", 1.0)
	base_range = data.get("range", 300.0)
	target_priority = data.get("target_priority", "nearest")
	faction = data.get("faction", 0)
	role = data.get("role", 0)
	position_type = data.get("position_type", 0)

	# HP系统
	max_hp = data.get("max_hp", 100.0)
	# 从 GameData 健康追踪中读取当前HP（跨局继承）
	if GameData.creature_health.has(creature_id):
		current_hp = GameData.creature_health[creature_id]["current_hp"]
		injury_stage = GameData.creature_health[creature_id]["stage"]
		is_dead = GameData.creature_health[creature_id]["is_dead"]
	else:
		current_hp = max_hp
		injury_stage = GameData.InjuryStage.HEALTHY
		is_dead = false

	attack_power = base_attack
	attack_speed = base_speed
	attack_range = base_range
	attack_cooldown = 1.0 / attack_speed
	attack_timer = attack_cooldown * 0.3
	heal_ally_timer = 0.0

	if data.has("aoe_cooldown"):
		aoe_timer = data["aoe_cooldown"] * 0.5
	if data.has("summon_cooldown"):
		summon_timer = data["summon_cooldown"] * 0.5

	_draw_sprite()
	_create_hp_bar()
	_update_injury_visual()

	attack_line = Line2D.new()
	attack_line.width = 2.0
	attack_line.default_color = Color(0.85, 0.80, 1.0, 0.5)
	attack_line.visible = false
	add_child(attack_line)

# ── 协同效果 ──
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

	var challenge_bonus: float = _get_challenge_bonus("synergy") + _get_challenge_bonus("attack")
	if creature_data.has("gold_to_attack"):
		var g: int = int(GameData.resources["gold"])
		stacking_bonus = int(g / 100.0) * creature_data["gold_to_attack"]

	var total_attack: float = 1.0 + synergy_attack_bonus + trade_attack_bonus + stacking_bonus + challenge_bonus
	if faction == GameData.Faction.TECH:
		total_attack += tech_extra_attack
	attack_power = base_attack * total_attack

	var total_speed: float = 1.0 + synergy_speed_bonus
	if faction == GameData.Faction.FAITH:
		total_speed += faith_extra_speed
	total_speed += _get_challenge_bonus("speed")
	attack_speed = maxf(0.1, base_speed * total_speed)
	attack_cooldown = 1.0 / attack_speed
	attack_range = base_range * (1.0 + synergy_range_bonus)

func _get_challenge_bonus(stat: String) -> float:
	if not GameData.world_progress.get("challenge_active", false):
		return 0.0
	return _find_challenge_bonus(stat)

func _find_challenge_bonus(stat: String) -> float:
	var parent: Node = get_parent()
	while parent:
		if parent.has_node("ChallengeManager"):
			var cm: Node = parent.get_node("ChallengeManager")
			if cm.has_method("get_active_card_bonus"):
				return cm.get_active_card_bonus(stat)
			break
		parent = parent.get_parent()
	return 0.0

# ── 受伤与死亡 ──
func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp = maxf(0.0, current_hp - amount)
	_update_injury_stage()
	_update_hp_bar()
	_update_injury_visual()

	if current_hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(max_hp, current_hp + amount)
	_update_injury_stage()
	_update_hp_bar()
	_update_injury_visual()

func _update_injury_stage() -> void:
	var ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.0
	var old_stage: int = injury_stage
	if current_hp <= 0.0:
		injury_stage = GameData.InjuryStage.DEAD
	elif ratio < 0.25:
		injury_stage = GameData.InjuryStage.DYING
	elif ratio < 0.50:
		injury_stage = GameData.InjuryStage.SEVERE
	elif ratio < 0.75:
		injury_stage = GameData.InjuryStage.LIGHT
	else:
		injury_stage = GameData.InjuryStage.HEALTHY
	if old_stage != injury_stage:
		health_changed.emit(current_hp, max_hp, injury_stage)
		EventBus.creature_injured.emit(creature_id, injury_stage)

func _die() -> void:
	is_dead = true
	injury_stage = GameData.InjuryStage.DEAD

	# 新手保护期检查
	if GameData.check_newbie_protection(creature_id):
		current_hp = GameData.creature_health[creature_id]["current_hp"]
		injury_stage = GameData.creature_health[creature_id]["stage"]
		is_dead = false
		_update_hp_bar()
		_update_injury_visual()
		return

	# 真正死亡
	GameData.creature_die_in_battle(creature_id)
	creature_died.emit(creature_id)

	# 死亡视觉效果 — 消散
	modulate = Color(1.0, 1.0, 1.0, 0.3)
	# 延迟移除（留空站位）
	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			# 死亡后站位空出但不queue_free，改为显示"阵亡"标记
			_show_dead_marker()
	)

func _show_dead_marker() -> void:
	# 隐藏攻击线
	if attack_line:
		attack_line.visible = false
	# 在血条位置显示"阵亡"
	for child in get_children():
		if child is Label and child != sprite_node:
			child.queue_free()
	var label: Label = Label.new()
	label.text = "阵亡"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.60))
	label.position = Vector2(-20, -40)
	label.size = Vector2(40, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	# 隐藏血条
	if hp_bar:
		hp_bar.visible = false
	if hp_bar_bg:
		hp_bar_bg.visible = false

# ── 受伤视觉反馈 ──
func _update_injury_visual() -> void:
	if sprite_node == null:
		return
	var fc: Color = GameData.get_faction_color(faction)

	match injury_stage:
		GameData.InjuryStage.HEALTHY:
			sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if injury_indicator:
				injury_indicator.visible = false
		GameData.InjuryStage.LIGHT:
			# 颜色略暗淡
			sprite_node.modulate = fc.darkened(0.15)
			if injury_indicator:
				injury_indicator.color = Color(0.75, 0.70, 0.85, 0.3)
				injury_indicator.visible = true
		GameData.InjuryStage.SEVERE:
			# 明显暗淡+闪烁
			sprite_node.modulate = fc.darkened(0.30)
			if injury_indicator:
				injury_indicator.color = Color(0.95, 0.70, 0.55, 0.5)
				injury_indicator.visible = true
		GameData.InjuryStage.DYING:
			# 红色警告光环
			sprite_node.modulate = Color(0.95, 0.55, 0.60, 0.8)
			if injury_indicator:
				injury_indicator.color = Color(0.95, 0.45, 0.50, 0.7)
				injury_indicator.visible = true
		GameData.InjuryStage.DEAD:
			sprite_node.modulate = Color(0.5, 0.45, 0.55, 0.4)
			if injury_indicator:
				injury_indicator.visible = false

# ── 血条 ──
func _create_hp_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(44, 6)
	hp_bar_bg.position = Vector2(-22, -42)
	hp_bar_bg.color = Color(0.30, 0.25, 0.38)
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(44, 6)
	hp_bar.position = Vector2(-22, -42)
	add_child(hp_bar)

	# 受伤阶段指示器(小色块)
	injury_indicator = ColorRect.new()
	injury_indicator.size = Vector2(8, 6)
	injury_indicator.position = Vector2(24, -42)
	injury_indicator.visible = false
	add_child(injury_indicator)

	_update_hp_bar()

func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	var ratio: float = current_hp / max_hp if max_hp > 0.0 else 0.0
	hp_bar.size.x = 44.0 * maxf(0.0, ratio)
	if ratio < 0.25:
		hp_bar.color = Color(0.95, 0.45, 0.50)
	elif ratio < 0.50:
		hp_bar.color = Color(0.95, 0.70, 0.55)
	elif ratio < 0.75:
		hp_bar.color = Color(0.95, 0.85, 0.70)
	else:
		hp_bar.color = Color(0.55, 0.88, 0.72)

# ── 每帧处理 ──
func _process(delta: float) -> void:
	if is_dead:
		attack_line.visible = false
		return

	aoe_timer -= delta
	summon_timer -= delta
	attack_timer -= delta
	heal_ally_timer -= delta

	# 治疗型生物被动回血
	if creature_data.has("heal_amount") and heal_ally_timer <= 0.0:
		_heal_ally()
		heal_ally_timer = 3.0  # 每3秒一次治疗

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

# ── 治疗友方 ──
func _heal_ally() -> void:
	if creature_container == null:
		return
	var heal_range: float = creature_data.get("heal_range", 300.0)
	var heal_amount: float = creature_data.get("heal_amount", 5.0)
	var best_target: Creature = null
	var best_hp_ratio: float = 1.0

	for child in creature_container.get_children():
		if not child is Creature:
			continue
		var c: Creature = child as Creature
		if c.is_dead:
			continue
		if c == self:
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist > heal_range:
			continue
		var ratio: float = c.current_hp / c.max_hp
		if ratio < best_hp_ratio:
			best_hp_ratio = ratio
			best_target = c

	if best_target and best_hp_ratio < 0.90:
		best_target.heal(heal_amount)
		GameData.creature_heal(best_target.creature_id, heal_amount)
		EventBus.creature_healed.emit(best_target.creature_id, heal_amount)

# ── 攻击逻辑 ──
func _find_and_attack_target() -> void:
	if current_target and is_instance_valid(current_target) and current_target.is_alive:
		var dist: float = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			_attack_target(current_target)
			return
	var best: Enemy = _find_best_target()
	if best:
		current_target = best
		_attack_target(best)

func _find_best_target() -> Enemy:
	if enemy_container == null:
		return null
	var candidates: Array[Enemy] = []
	for e in enemy_container.get_children():
		if not e is Enemy:
			continue
		if not e.is_alive:
			continue
		if global_position.distance_to(e.global_position) <= attack_range:
			candidates.append(e)
	if candidates.is_empty():
		return null

	match target_priority:
		"nearest":
			candidates.sort_custom(func(a: Enemy, b: Enemy): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
		"lowest_health":
			candidates.sort_custom(func(a: Enemy, b: Enemy): return a.current_health < b.current_health)
		"elite_first":
			candidates.sort_custom(func(a: Enemy, b: Enemy):
				if a.is_boss and not b.is_boss: return true
				if not a.is_boss and b.is_boss: return false
				if a.is_elite and not b.is_elite: return true
				if not a.is_elite and b.is_elite: return false
				return a.current_health < b.current_health
			)
		"castle_priority":
			# 反精英型优先攻击特殊敌人
			candidates.sort_custom(func(a: Enemy, b: Enemy):
				if a.is_special and not b.is_special: return true
				if not a.is_special and b.is_special: return false
				return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
			)
	return candidates[0] if candidates.size() > 0 else null

func _attack_target(target: Enemy) -> void:
	var dmg: float = attack_power

	# 暴击
	if creature_data.has("skill_chance") and randf() < creature_data["skill_chance"]:
		dmg *= creature_data["skill_multiplier"]

	# 挑战卡牌暴击
	var challenge_crit: float = _get_challenge_bonus("crit")
	if challenge_crit > 0.0 and randf() < challenge_crit:
		dmg *= 2.0

	# 护盾额外伤害
	if creature_data.has("anti_shield_bonus") and target.armor > 0.0:
		dmg *= (1.0 + creature_data["anti_shield_bonus"])

	# 精英额外伤害
	if creature_data.has("elite_bonus"):
		if target.is_elite or target.is_boss or target.is_special:
			dmg *= (1.0 + creature_data["elite_bonus"])

	target.take_damage(dmg)

	# 连锁闪电
	if creature_data.has("chain_targets"):
		_do_chain_lightning(target, dmg)

	# DOT效果
	if has_cross_dot:
		var dot_dmg: float = attack_power * cross_dot_ratio / cross_dot_duration
		target.apply_dot(dot_dmg, cross_dot_duration)

	if creature_data.has("burn_ratio"):
		target.apply_dot(attack_power * creature_data["burn_ratio"] / creature_data["burn_duration"], creature_data["burn_duration"])

	if creature_data.has("poison_ratio"):
		target.apply_dot(attack_power * creature_data["poison_ratio"] / creature_data["poison_duration"], creature_data["poison_duration"])

	# 挑战淬毒
	if _get_challenge_bonus("poison") > 0.0:
		target.apply_dot(attack_power * 0.1, 3.0)

	# 减速/定身/眩晕
	if creature_data.has("slow_factor"):
		target.apply_slow(creature_data["slow_factor"], creature_data["slow_duration"])

	if creature_data.has("root_chance") and randf() < creature_data["root_chance"]:
		target.apply_slow(0.0, creature_data["root_duration"])

	if stun_chance > 0.0 and randf() < stun_chance:
		target.apply_slow(0.0, stun_duration)

	if creature_data.has("vulnerable_ratio"):
		target.apply_vulnerable(creature_data["vulnerable_ratio"], creature_data["vulnerable_duration"], creature_data.get("max_stacks", 3))

	# 残响
	if creature_data.has("echo_ratio"):
		var echo_dmg: float = dmg * creature_data["echo_ratio"]
		var t: Enemy = target
		get_tree().create_timer(creature_data.get("echo_delay", 0.3)).timeout.connect(func():
			if is_instance_valid(t) and t.is_alive:
				t.take_damage(echo_dmg)
		)

	# 敌人攻速降低
	if creature_data.has("enemy_slow_ratio"):
		target.apply_attack_slow(creature_data["enemy_slow_ratio"], creature_data["enemy_slow_duration"])

	# 金币获取
	if creature_data.has("gold_chance") and randf() < creature_data["gold_chance"]:
		GameData.add_resource("gold", creature_data["gold_amount"])

	# 挑战淘金
	var gold_bonus: float = _get_challenge_bonus("gold")
	if gold_bonus > 0.0 and randf() < 0.3:
		GameData.add_resource("gold", int(5 * gold_bonus))

func _do_chain_lightning(initial_target: Enemy, damage: float) -> void:
	if enemy_container == null:
		return
	var chain_targets: Array = [initial_target]
	for e in enemy_container.get_children():
		if e is Enemy and e.is_alive and e != initial_target:
			if global_position.distance_to(e.global_position) <= attack_range * 1.5:
				chain_targets.append(e)
	var chain_count: int = creature_data.get("chain_targets", 2)
	var d: float = damage
	var max_i: int = min(chain_count + 1, chain_targets.size())
	for i in range(1, max_i):
		d *= (1.0 - creature_data.get("chain_decay", 0.3))
		chain_targets[i].take_damage(d)

func _trigger_aoe() -> void:
	if enemy_container == null:
		return
	var aoe_rng: float = creature_data.get("aoe_range", 200.0)
	var aoe_rat: float = creature_data.get("aoe_ratio", 0.8)
	for e in enemy_container.get_children():
		if e is Enemy and e.is_alive:
			if global_position.distance_to(e.global_position) <= aoe_rng:
				e.take_damage(attack_power * aoe_rat)

func _trigger_summon() -> void:
	var summon_id: String = creature_data.get("summon_id", "")
	if summon_id == "":
		return
	var summon_data: Dictionary = GameData.get_creature_data(summon_id)
	if summon_data.is_empty():
		return
	var creature_scene: PackedScene = load("res://scenes/creature.tscn")
	if creature_scene == null:
		return
	var c: Creature = creature_scene.instantiate() as Creature
	c.setup(summon_data)
	c.position = position + Vector2(randi() % 60 - 30, -20)
	c.set_enemy_container(enemy_container)
	c.set_creature_container(creature_container)
	# 召唤物HP不跨局继承 — 每次召唤都是满血
	c.current_hp = c.max_hp
	c.injury_stage = GameData.InjuryStage.HEALTHY
	get_parent().add_child(c)
	var dur: float = creature_data.get("summon_duration", 8.0)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(c):
		c.queue_free()

func set_enemy_container(container: Node) -> void:
	enemy_container = container

func set_creature_container(container: Node) -> void:
	creature_container = container

# ── 绘制 ──
func _draw_sprite() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	sprite_node = Sprite2D.new()
	var fc: Color = GameData.get_faction_color(faction)
	var s: int = 36
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)

	# 各派系不同形状
	match faction:
		GameData.Faction.TECH:
			img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)
			img.fill_rect(Rect2i(8, 8, s - 16, s - 16), fc.lightened(0.3))
		GameData.Faction.FAITH:
			for y in range(s):
				for x in range(s):
					var dx: float = float(x) - float(s) / 2.0
					var dy: float = float(y) - float(s) / 2.0
					if abs(dx) + abs(dy) < float(s) / 2.0 - 2.0:
						img.set_pixel(x, y, fc)
		GameData.Faction.NATURE:
			for y in range(s):
				for x in range(s):
					var dx: float = float(x) - float(s) / 2.0
					var dy: float = float(y) - float(s) / 2.0
					if dx * dx + dy * dy < (float(s) / 2.0 - 2.0) * (float(s) / 2.0 - 2.0):
						img.set_pixel(x, y, fc)
		GameData.Faction.COMMERCE:
			for y in range(s):
				for x in range(s):
					var dx: float = float(x) - float(s) / 2.0
					var dy: float = float(y) - float(s) / 2.0
					if abs(dx) + abs(dy) < float(s) / 2.0 - 2.0:
						img.set_pixel(x, y, fc.lightened(0.1))
		GameData.Faction.MEMORY:
			img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)
		_:
			img.fill_rect(Rect2i(4, 4, s - 8, s - 8), fc)

	var tex: ImageTexture = ImageTexture.new()
	tex.set_image(img)
	sprite_node.texture = tex
	sprite_node.position = Vector2(0, -20)
	add_child(sprite_node)

	# 名字标签
	var label: Label = Label.new()
	label.text = creature_data.get("name", "???")
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", fc)
	label.position = Vector2(-30, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(70, 18)
	add_child(label)

	# 角色标签(小字)
	var role_label: Label = Label.new()
	role_label.text = GameData.get_role_name(role)
	role_label.add_theme_font_size_override("font_size", 7)
	role_label.add_theme_color_override("font_color", fc.darkened(0.2))
	role_label.position = Vector2(-30, 26)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.size = Vector2(70, 14)
	add_child(role_label)
