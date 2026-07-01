extends Node2D
class_name Enemy
## 敌人实体

signal died(enemy: Node2D)
signal reached_end(enemy: Node2D)

@export var enemy_type: String = "basic"
@export var max_health: float = 100.0
@export var move_speed: float = 80.0
@export var damage_to_castle: int = 10
@export var armor: float = 0.0
@export var is_elite: bool = false
@export var is_boss: bool = false

var current_health: float = 100.0
var is_alive: bool = true
var path_follow: Path2D = null
var path_progress: float = 0.0
var slowed: bool = false
var slow_timer: float = 0.0
var slow_factor: float = 1.0
var attack_slowed: bool = false
var attack_slow_timer: float = 0.0
var attack_slow_factor: float = 1.0
var vulnerable_stacks: int = 0
var vulnerable_mult: float = 1.0
var dot_effects: Array[Dictionary] = []
var flash_timer: float = 0.0
var original_modulate: Color = Color.WHITE
var hp_bar: ColorRect = null
var hp_bar_bg: ColorRect = null

func _ready():
	call_deferred("_init_enemy")

func _init_enemy():
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
	original_modulate = modulate
	_draw_enemy_sprite()
	_create_hp_bar()

func _setup_by_type():
	if enemy_type == "basic":
		max_health = 80.0
		move_speed = 80.0
		damage_to_castle = 10
	elif enemy_type == "fast":
		max_health = 50.0
		move_speed = 140.0
		damage_to_castle = 8
	elif enemy_type == "tank":
		max_health = 200.0
		move_speed = 50.0
		damage_to_castle = 20
		armor = 5.0
	elif enemy_type == "elite":
		max_health = 180.0
		move_speed = 90.0
		damage_to_castle = 25
		is_elite = true
	elif enemy_type == "boss":
		max_health = 600.0
		move_speed = 55.0
		damage_to_castle = 50
		is_boss = true

func _process(delta):
	if not is_alive:
		return
	if slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			slowed = false
			slow_factor = 1.0
	if attack_slowed:
		attack_slow_timer -= delta
		if attack_slow_timer <= 0:
			attack_slowed = false
			attack_slow_factor = 1.0
	_process_dot(delta)
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			modulate = original_modulate
	_move_along_path(delta)
	_update_hp_bar()

func _move_along_path(delta: float) -> void:
	var speed_mult: float = slow_factor
	# 挑战模式: 减速力场
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
	if position.x > 1350:
		_reach_end()

func _process_dot(delta):
	var to_remove = []
	for i in range(dot_effects.size()):
		var dot = dot_effects[i]
		take_damage(dot["damage_per_sec"] * delta, false)
		dot["timer"] = dot["timer"] - delta
		if dot["timer"] <= 0:
			to_remove.append(i)
	var j = to_remove.size() - 1
	while j >= 0:
		dot_effects.remove_at(to_remove[j])
		j = j - 1

func take_damage(amount: float, show_flash: bool = true):
	if not is_alive:
		return
	var actual = (amount - armor) * vulnerable_mult
	if actual < 0:
		actual = 0
	current_health = current_health - actual
	if show_flash:
		flash_timer = 0.1
		modulate = Color.WHITE
	if current_health <= 0:
		current_health = 0
		_die()

func _die():
	is_alive = false
	died.emit(self)
	EventBus.enemy_killed.emit(enemy_type, position)
	queue_free()

func _reach_end():
	is_alive = false
	reached_end.emit(self)
	EventBus.enemy_reached_end.emit(self)
	queue_free()

func apply_slow(factor: float, duration: float):
	slowed = true
	slow_factor = factor
	slow_timer = duration

func apply_dot(damage_per_sec: float, duration: float):
	var dot_data = {}
	dot_data["damage_per_sec"] = damage_per_sec
	dot_data["duration"] = duration
	dot_data["timer"] = duration
	dot_effects.append(dot_data)

func apply_vulnerable(ratio: float, duration: float, max_stacks: int):
	if vulnerable_stacks + 1 < max_stacks:
		vulnerable_stacks = vulnerable_stacks + 1
	else:
		vulnerable_stacks = max_stacks
	vulnerable_mult = 1.0 + vulnerable_stacks * ratio
	get_tree().create_timer(duration).timeout.connect(func():
		vulnerable_stacks = vulnerable_stacks - 1
		if vulnerable_stacks < 0:
			vulnerable_stacks = 0
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

func _create_hp_bar():
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

func _update_hp_bar():
	if hp_bar == null:
		return
	var ratio = current_health / max_health
	hp_bar.size.x = 40.0 * ratio
	if ratio < 0.3:
		hp_bar.color = Color(0.95, 0.55, 0.60)
	elif ratio < 0.6:
		hp_bar.color = Color(0.95, 0.75, 0.55)
	else:
		hp_bar.color = Color(0.55, 0.88, 0.72)

func _draw_enemy_sprite():
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	var sprite = Sprite2D.new()
	var size = 28
	if enemy_type == "fast":
		size = 22
	elif enemy_type == "tank":
		size = 36
	elif enemy_type == "elite":
		size = 32
	elif enemy_type == "boss":
		size = 48
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bc = Color.GRAY
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
	var cx = float(size) / 2.0
	var cy = float(size) / 2.0
	var r = float(size) / 2.0 - 2.0
	var rr = r * r
	for y in range(size):
		for x in range(size):
			var dx = float(x) - cx
			var dy = float(y) - cy
			if dx * dx + dy * dy < rr:
				img.set_pixel(x, y, bc)
	img.set_pixel(int(cx) - 4, int(cy) - 4, Color.WHITE)
	img.set_pixel(int(cx) + 4, int(cy) - 4, Color.WHITE)
	var tex = ImageTexture.new()
	tex.set_image(img)
	sprite.texture = tex
	sprite.position = Vector2(float(-size) / 2.0, float(-size) / 2.0)
	add_child(sprite)
