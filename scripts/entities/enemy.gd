extends Node2D
class_name Enemy
## 梦游症 - 敌人实体 v0.4
## v0.4 变更: 普通敌人打生物(停步攻击)/特殊敌人直攻核心/攻击计时器/状态机
## 普通敌人: 走到生物攻击范围内→停步攻击→目标死亡→继续前进
## 特殊敌人: 无视生物→直冲城堡核心→攻击核心HP

signal died(enemy: Node2D)
signal reached_end(enemy: Node2D)

# ── 状态机 ──
enum EnemyState { MOVING, ATTACKING_CREATURE, ATTACKING_CORE }

@export var enemy_type: String = "basic"
@export var max_health: float = 100.0
@export var move_speed: float = 80.0
@export var damage_to_castle: int = 10
@export var armor: float = 0.0
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var is_special: bool = false  # 特殊敌人: 无视生物，直攻核心

# ── v0.4 攻击属性 ──
var attack_damage: float = 8.0     # 对生物的每击伤害
var attack_range: float = 150.0    # 攻击生物的范围
var attack_cooldown: float = 1.5   # 攻击间隔(秒)
var attack_timer: float = 0.0      # 攻击计时器

# ── 状态 ──
var current_health: float = 100.0
var is_alive: bool = true
var state: int = EnemyState.MOVING
var current_attack_target: Creature = null

# ── 路径 ──
var path_follow: Path2D = null
var path_progress: float = 0.0

# ── 减速/脆弱/DOT ──
var slowed: bool = false
var slow_timer: float = 0.0
var slow_factor: float = 1.0
var attack_slowed: bool = false
var attack_slow_timer: float = 0.0
var attack_slow_factor: float = 1.0
var vulnerable_stacks: int = 0
var vulnerable_mult: float = 1.0
var dot_effects: Array[Dictionary] = []

# ── 视觉 ──
var flash_timer: float = 0.0
var original_modulate: Color = Color.WHITE
var hp_bar: ColorRect = null
var hp_bar_bg: ColorRect = null
var attack_line: Line2D = null
var sprite_node: Sprite2D = null

# ── 外部引用 ──
var creature_container: Node = null  # 生物容器(用于找攻击目标)
var castle_ref: Castle = null        # 城堡引用(特殊敌人攻击核心)

func _ready() -> void:
	call_deferred("_init_enemy")

func _init_enemy() -> void:
	_setup_by_type()
	current_health = max_health
	original_modulate = Color.WHITE
	modulate = original_modulate
	if is_elite:
		modulate = Color(0.95, 0.75, 0.55)
		scale = Vector2(1.3, 1.3)
	if is_boss:
		modulate = Color(0.85, 0.40, 0.45)
		scale = Vector2(2.0, 2.0)
	if is_special:
		modulate = Color(0.75, 0.55, 0.95)  # 紫色标识
		scale = Vector2(1.4, 1.4)
	original_modulate = modulate
	_draw_enemy_sprite()
	_create_hp_bar()

	# 攻击线(攻击生物时显示)
	attack_line = Line2D.new()
	attack_line.width = 2.0
	attack_line.default_color = Color(0.95, 0.55, 0.60, 0.6)
	attack_line.visible = false
	add_child(attack_line)

	attack_timer = attack_cooldown * 0.5

func _setup_by_type() -> void:
	if enemy_type == "basic":
		max_health = 80.0; move_speed = 80.0; damage_to_castle = 10
		attack_damage = 8.0; attack_range = 150.0; attack_cooldown = 1.5
	elif enemy_type == "fast":
		max_health = 50.0; move_speed = 140.0; damage_to_castle = 8
		attack_damage = 5.0; attack_range = 120.0; attack_cooldown = 1.0
	elif enemy_type == "tank":
		max_health = 200.0; move_speed = 50.0; damage_to_castle = 20
		armor = 5.0; attack_damage = 15.0; attack_range = 160.0; attack_cooldown = 2.0
	elif enemy_type == "elite":
		max_health = 180.0; move_speed = 90.0; damage_to_castle = 25
		is_elite = true; attack_damage = 20.0; attack_range = 180.0; attack_cooldown = 1.8
	elif enemy_type == "boss":
		max_health = 600.0; move_speed = 55.0; damage_to_castle = 50
		is_boss = true; attack_damage = 30.0; attack_range = 200.0; attack_cooldown = 2.5
	elif enemy_type == "special":
		max_health = 120.0; move_speed = 110.0; damage_to_castle = 30
		is_special = true; attack_damage = 25.0; attack_range = 180.0; attack_cooldown = 1.5

func set_creature_container(container: Node) -> void:
	creature_container = container

func set_castle_ref(castle: Castle) -> void:
	castle_ref = castle

func _process(delta: float) -> void:
	if not is_alive:
		return

	# 减速计时
	if slowed:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slowed = false
			slow_factor = 1.0
	if attack_slowed:
		attack_slow_timer -= delta
		if attack_slow_timer <= 0.0:
			attack_slowed = false
			attack_slow_factor = 1.0

	_process_dot(delta)

	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			modulate = original_modulate

	# 状态机驱动行为
	match state:
		EnemyState.MOVING:
			_move_along_path(delta)
			_check_for_creature_target()
		EnemyState.ATTACKING_CREATURE:
			_attack_creature_tick(delta)
		EnemyState.ATTACKING_CORE:
			_attack_core_tick(delta)

	_update_hp_bar()
	_update_attack_line()

# ── 移动 ──
func _move_along_path(delta: float) -> void:
	var speed_mult: float = slow_factor
	# 挑战模式减速力场
	if GameData.world_progress.get("challenge_active", false):
		var challenge_slow: float = _get_challenge_slow_bonus()
		if challenge_slow > 0.0:
			speed_mult = speed_mult * (1.0 - challenge_slow)

	if path_follow == null:
		position.x += move_speed * speed_mult * delta
	else:
		path_progress += move_speed * speed_mult * delta
		var path_length: float = path_follow.curve.get_baked_length()
		if path_progress >= path_length:
			_reach_end()
			return
		position = path_follow.curve.sample_baked(path_progress)

	# 无路径时: 超出屏幕右侧
	if position.x > 1350:
		_reach_end()

# ── 检查是否进入生物攻击范围 ──
func _check_for_creature_target() -> void:
	# 特殊敌人永远不打生物
	if is_special:
		return
	if creature_container == null:
		return

	var best_creature: Creature = null
	var best_dist: float = attack_range + 1.0

	for child in creature_container.get_children():
		if not child is Creature:
			continue
		var c: Creature = child as Creature
		if c.is_dead:
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist < best_dist:
			best_dist = dist
			best_creature = c

	if best_creature != null:
		current_attack_target = best_creature
		state = EnemyState.ATTACKING_CREATURE
		attack_timer = attack_cooldown * 0.3  # 首次攻击稍快

# ── 攻击生物 ──
func _attack_creature_tick(delta: float) -> void:
	# 检查目标是否仍有效
	if current_attack_target == null or not is_instance_valid(current_attack_target) or current_attack_target.is_dead:
		# 目标死亡或无效 → 恢复移动
		current_attack_target = null
		state = EnemyState.MOVING
		attack_line.visible = false
		return

	# 目标超出攻击范围 → 追击或恢复移动
	var dist: float = global_position.distance_to(current_attack_target.global_position)
	if dist > attack_range * 1.3:
		# 距离过远 → 恢复移动(生物可能已被移除)
		current_attack_target = null
		state = EnemyState.MOVING
		attack_line.visible = false
		return

	# 攻击计时
	attack_timer -= delta
	if attack_timer <= 0.0:
		_do_creature_attack()
		attack_timer = attack_cooldown * attack_slow_factor

# ── 执行生物攻击 ──
func _do_creature_attack() -> void:
	if current_attack_target == null or not is_instance_valid(current_attack_target):
		return

	var dmg: float = attack_damage

	# 精英/Boss额外伤害
	if is_elite or is_boss:
		dmg *= 1.3

	# 脆弱加成
	dmg *= vulnerable_mult

	current_attack_target.take_damage(dmg)

# ── 攻击城堡核心 ──
func _attack_core_tick(delta: float) -> void:
	if castle_ref == null:
		state = EnemyState.MOVING
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		_do_core_attack()
		attack_timer = attack_cooldown * attack_slow_factor

func _do_core_attack() -> void:
	if castle_ref == null:
		return
	var dmg: float = attack_damage
	if is_elite or is_boss:
		dmg *= 1.5
	dmg *= vulnerable_mult
	castle_ref.take_core_damage(dmg)

# ── 攻击线视觉 ──
func _update_attack_line() -> void:
	if state == EnemyState.ATTACKING_CREATURE and current_attack_target and is_instance_valid(current_attack_target):
		attack_line.visible = true
		attack_line.points = PackedVector2Array([Vector2.ZERO, current_attack_target.global_position - global_position])
		attack_line.default_color = Color(0.95, 0.55, 0.60, 0.6)
	elif state == EnemyState.ATTACKING_CORE and castle_ref:
		attack_line.visible = true
		attack_line.points = PackedVector2Array([Vector2.ZERO, castle_ref.global_position - global_position])
		attack_line.default_color = Color(0.75, 0.55, 0.95, 0.6)
	else:
		attack_line.visible = false

# ── 到达终点 ──
func _reach_end() -> void:
	if is_special and castle_ref:
		# 特殊敌人到达城堡 → 转为攻击核心
		state = EnemyState.ATTACKING_CORE
		attack_timer = attack_cooldown * 0.3
		return

	# 普通敌人到达终点 → 伤害城堡并消失
	is_alive = false
	reached_end.emit(self)
	EventBus.enemy_reached_end.emit(self)

	if castle_ref:
		castle_ref.take_damage(damage_to_castle)

	queue_free()

# ── DOT处理 ──
func _process_dot(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(dot_effects.size()):
		var dot: Dictionary = dot_effects[i]
		take_damage(dot["damage_per_sec"] * delta, false)
		dot["timer"] = dot["timer"] - delta
		if dot["timer"] <= 0.0:
			to_remove.append(i)
	var j: int = to_remove.size() - 1
	while j >= 0:
		dot_effects.remove_at(to_remove[j])
		j -= 1

# ── 受伤 ──
func take_damage(amount: float, show_flash: bool = true) -> void:
	if not is_alive:
		return
	var actual: float = (amount - armor) * vulnerable_mult
	if actual < 0.0:
		actual = 0.0
	current_health -= actual
	if show_flash:
		flash_timer = 0.1
		modulate = Color.WHITE
	if current_health <= 0.0:
		current_health = 0.0
		_die()

func _die() -> void:
	is_alive = false
	attack_line.visible = false
	died.emit(self)
	EventBus.enemy_killed.emit(enemy_type, position)
	queue_free()

# ── 减速/脆弱/DOT ──
func apply_slow(factor: float, duration: float) -> void:
	slowed = true
	slow_factor = factor
	slow_timer = duration

func apply_dot(damage_per_sec: float, duration: float) -> void:
	dot_effects.append({
		"damage_per_sec": damage_per_sec,
		"duration": duration,
		"timer": duration,
	})

func apply_vulnerable(ratio: float, duration: float, max_stacks: int) -> void:
	vulnerable_stacks = min(vulnerable_stacks + 1, max_stacks)
	vulnerable_mult = 1.0 + vulnerable_stacks * ratio
	get_tree().create_timer(duration).timeout.connect(func():
		vulnerable_stacks = max(0, vulnerable_stacks - 1)
		vulnerable_mult = 1.0 + vulnerable_stacks * ratio
	)

func apply_attack_slow(factor: float, duration: float) -> void:
	attack_slowed = true
	attack_slow_factor = 1.0 - factor
	attack_slow_timer = duration

func _get_challenge_slow_bonus() -> float:
	var parent: Node = get_parent()
	while parent:
		if parent.has_node("ChallengeManager"):
			var cm: Node = parent.get_node("ChallengeManager")
			if cm.has_method("get_active_card_bonus"):
				return cm.get_active_card_bonus("slow")
			break
		parent = parent.get_parent()
	return 0.0

# ── HP条 ──
func _create_hp_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(40, 5)
	hp_bar_bg.position = Vector2(-20, -30)
	hp_bar_bg.color = Color(0.30, 0.25, 0.38)
	add_child(hp_bar_bg)

	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(40, 5)
	hp_bar.position = Vector2(-20, -30)
	hp_bar.color = Color.RED
	add_child(hp_bar)

	# 特殊敌人标识
	if is_special:
		var tag: Label = Label.new()
		tag.text = "★"
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95))
		tag.position = Vector2(-8, -38)
		add_child(tag)

func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	var ratio: float = current_health / max_health
	hp_bar.size.x = 40.0 * maxf(0.0, ratio)
	if ratio < 0.3:
		hp_bar.color = Color(0.95, 0.55, 0.60)
	elif ratio < 0.6:
		hp_bar.color = Color(0.95, 0.75, 0.55)
	else:
		hp_bar.color = Color(0.55, 0.88, 0.72)

# ── 绘制 ──
func _draw_enemy_sprite() -> void:
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	sprite_node = Sprite2D.new()
	var size: int = 28
	if enemy_type == "fast":
		size = 22
	elif enemy_type == "tank":
		size = 36
	elif enemy_type == "elite":
		size = 32
	elif enemy_type == "boss":
		size = 48
	elif enemy_type == "special":
		size = 30

	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bc: Color = Color.GRAY
	if enemy_type == "basic":
		bc = Color(0.75, 0.55, 0.55)
	elif enemy_type == "fast":
		bc = Color(0.90, 0.80, 0.55)
	elif enemy_type == "tank":
		bc = Color(0.50, 0.45, 0.65)
	elif enemy_type == "elite":
		bc = Color(0.95, 0.75, 0.55)
	elif enemy_type == "boss":
		bc = Color(0.85, 0.40, 0.45)
	elif enemy_type == "special":
		bc = Color(0.75, 0.55, 0.95)  # 紫色标识

	var cx: float = float(size) / 2.0
	var cy: float = float(size) / 2.0
	var r: float = float(size) / 2.0 - 2.0
	var rr: float = r * r

	# 特殊敌人用菱形绘制
	if is_special:
		for y in range(size):
			for x in range(size):
				var dx: float = float(x) - cx
				var dy: float = float(y) - cy
				if abs(dx) + abs(dy) < r:
					img.set_pixel(x, y, bc)
	else:
		for y in range(size):
			for x in range(size):
				var dx: float = float(x) - cx
				var dy: float = float(y) - cy
				if dx * dx + dy * dy < rr:
					img.set_pixel(x, y, bc)

	# 眼睛
	img.set_pixel(int(cx) - 4, int(cy) - 4, Color.WHITE)
	img.set_pixel(int(cx) + 4, int(cy) - 4, Color.WHITE)

	var tex: ImageTexture = ImageTexture.new()
	tex.set_image(img)
	sprite_node.texture = tex
	sprite_node.position = Vector2(float(-size) / 2.0, float(-size) / 2.0)
	add_child(sprite_node)
