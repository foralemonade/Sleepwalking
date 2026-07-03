extends Node
class_name WaveManager
## 波次管理器 v0.4 — 支持世界地图/挑战/测试三种模式
## v0.4 变更:
##   - 支持特殊敌人 (is_special) 生成
##   - 生成敌人时调用 battle_controller.setup_enemy_references()
##   - 波次配置中 has_special/special_count 字段

signal wave_started(wave_index: int, total_waves: int)
signal wave_completed(wave_index: int)
signal all_waves_completed()

var wave_configs: Array[Dictionary] = []
var current_wave: int = -1
var total_waves: int = 0
var enemies_remaining: int = 0
var spawn_queue: Array[Dictionary] = []
var special_spawn_queue: Array[Dictionary] = []
var spawn_timer: float = 0.0
var is_battle_active: bool = false

var enemy_spawner: Node2D = null
var enemy_path: Path2D = null
var enemy_container: Node = null

## 由 BattleController 注入的节点数据和战斗模式
var node_data: Dictionary = {}
var battle_mode: int = 2  # BattleMode.TEST
var battle_controller_ref: Node2D = null  # 用于设置敌人引用

func _ready() -> void:
	enemy_container = Node.new()
	enemy_container.name = "Enemies"
	add_child(enemy_container)

func setup_waves(configs: Array[Dictionary]) -> void:
	wave_configs = configs
	current_wave = -1
	total_waves = configs.size()
	spawn_queue.clear()
	special_spawn_queue.clear()

func _generate_waves() -> Array[Dictionary]:
	if battle_mode == 1:  # CHALLENGE
		return _generate_challenge_waves()
	if battle_mode == 0 and not node_data.is_empty():  # WORLD_MAP
		return WaveConfigs.get_waves_for_node(node_data)
	return WaveConfigs.get_default_waves()

func _generate_challenge_waves() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	var max_waves: int = GameData.world_progress.get("max_challenge_waves", 20)
	for i in range(1, max_waves + 1):
		configs.append(WaveConfigs.get_challenge_waves(i))
	return configs

func start_battle() -> void:
	if wave_configs.is_empty():
		wave_configs = _generate_waves()
	if wave_configs.is_empty():
		return
	is_battle_active = true
	EventBus.battle_started.emit()
	_start_next_wave()

func _start_next_wave() -> void:
	current_wave += 1
	if current_wave >= wave_configs.size():
		_all_waves_done()
		return
	var config: Dictionary = wave_configs[current_wave]
	var normal_count: int = config.get("enemy_count", 3)
	enemies_remaining = normal_count
	# 特殊敌人数量
	if config.get("has_special", false):
		enemies_remaining += config.get("special_count", 1)

	wave_started.emit(current_wave + 1, total_waves)
	EventBus.wave_started.emit(current_wave + 1)
	spawn_queue.clear()
	special_spawn_queue.clear()

	var interval: float = config.get("spawn_interval", 1.5)
	# 普通敌人队列
	for i in range(normal_count):
		spawn_queue.append({"enemy_type": config.get("enemy_type", "basic"), "delay": float(i) * interval, "is_special": false})
	# 特殊敌人队列
	if config.get("has_special", false):
		var special_count: int = config.get("special_count", 1)
		var special_interval: float = config.get("special_interval", 3.0)
		var special_type: String = config.get("enemy_type", "special")
		# 特殊敌人晚一些出现, 混入队列
		var base_delay: float = float(normal_count) * interval
		for i in range(special_count):
			special_spawn_queue.append({"enemy_type": special_type, "delay": base_delay + float(i) * special_interval, "is_special": true})
	spawn_timer = 0.0

func _process(delta: float) -> void:
	if not is_battle_active:
		return
	spawn_timer += delta
	# 处理普通敌人队列
	var to_spawn: Array[Dictionary] = []
	for item: Dictionary in spawn_queue:
		if spawn_timer >= item["delay"]:
			to_spawn.append(item)
	for item: Dictionary in to_spawn:
		spawn_queue.erase(item)
		_spawn_enemy(item["enemy_type"], item.get("is_special", false))
	# 处理特殊敌人队列
	to_spawn.clear()
	for item: Dictionary in special_spawn_queue:
		if spawn_timer >= item["delay"]:
			to_spawn.append(item)
	for item: Dictionary in to_spawn:
		special_spawn_queue.erase(item)
		_spawn_enemy(item["enemy_type"], true)

func _spawn_enemy(enemy_type: String, is_special: bool = false) -> void:
	if enemy_spawner == null:
		return
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	if enemy_scene == null:
		return
	var e: Enemy = enemy_scene.instantiate()
	e.enemy_type = enemy_type
	e.is_special = is_special
	if enemy_path:
		e.path_follow = enemy_path
	e.position = enemy_spawner.position
	enemy_container.add_child(e)
	# 注意: Enemy._ready() 已通过 call_deferred("_init_enemy") 初始化
	# 不再显式调用 _init_enemy, 避免重复初始化
	# 设置敌人引用 (creature_container + castle_ref)
	if battle_controller_ref and battle_controller_ref.has_method("setup_enemy_references"):
		battle_controller_ref.setup_enemy_references(e)
	e.died.connect(_on_enemy_died)
	e.reached_end.connect(_on_enemy_reached_end)
	EventBus.enemy_spawned.emit(e)

func _on_enemy_died(_enemy: Node2D) -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0 and spawn_queue.is_empty() and special_spawn_queue.is_empty():
		_wave_cleared()

func _on_enemy_reached_end(_enemy: Node2D) -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0 and spawn_queue.is_empty() and special_spawn_queue.is_empty():
		_wave_cleared()

func _wave_cleared() -> void:
	wave_completed.emit(current_wave + 1)
	EventBus.wave_cleared.emit(current_wave + 1)
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(_on_wave_delay_finished)

func _on_wave_delay_finished() -> void:
	if is_battle_active:
		_start_next_wave()

func _all_waves_done() -> void:
	is_battle_active = false
	spawn_queue.clear()
	special_spawn_queue.clear()
	all_waves_completed.emit()
	EventBus.battle_won.emit()

func stop_battle() -> void:
	is_battle_active = false
	spawn_queue.clear()
	special_spawn_queue.clear()

func clear_all_enemies() -> void:
	for child: Node in enemy_container.get_children():
		child.queue_free()
