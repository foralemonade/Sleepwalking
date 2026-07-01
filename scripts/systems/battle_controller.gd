extends Node2D
## 战斗场景主控制器
## 协调 Castle / WaveManager / SkillSystem / BattleUI
## 支持三种模式: world_map(世界地图)、challenge(无限挑战)、test(原型测试)

enum BattleMode { WORLD_MAP, CHALLENGE, TEST }

var castle: Castle = null
var wave_manager: WaveManager = null
var skill_system: SkillSystem = null
var battle_ui: CanvasLayer = null

## 挑战模式专用
var challenge_manager: ChallengeManager = null
var challenge_overlay: CanvasLayer = null
var challenge_wave_count: int = 0

var battle_mode: int = BattleMode.TEST
var node_data: Dictionary = {}
var current_node_id: String = ""

func _ready() -> void:
	castle = $Castle
	wave_manager = $WaveManager

	# 确定战斗模式
	_determine_battle_mode()

	# 技能系统
	skill_system = SkillSystem.new()
	skill_system.name = "SkillSystem"
	add_child(skill_system)

	# 战斗 UI
	var ui_script: GDScript = load("res://scripts/ui/battle_ui.gd")
	battle_ui = ui_script.new()
	battle_ui.name = "BattleUI"
	add_child(battle_ui)

	# 设置引用
	wave_manager.enemy_spawner = $EnemySpawner
	wave_manager.enemy_path = $EnemyPath
	castle.set_enemy_container(wave_manager.enemy_container)

	# 将节点数据传给 WaveManager
	wave_manager.node_data = node_data
	wave_manager.battle_mode = battle_mode

	if battle_ui.has_method("setup_references"):
		battle_ui.setup_references(castle, wave_manager, skill_system)

	# 恢复城堡状态
	castle.max_shield = GameData.castle_modules.get("defense", 100)
	castle.slot_count = GameData.castle_modules["creature_slots"]
	castle.current_shield = castle.max_shield

	# 挑战模式: 创建 ChallengeManager
	if battle_mode == BattleMode.CHALLENGE:
		_setup_challenge_mode()

	castle.castle_destroyed.connect(_on_castle_destroyed)
	EventBus.enemy_reached_end.connect(_on_enemy_reached_end)
	EventBus.battle_won.connect(_on_battle_won_global)

	# 监听波次完成(用于挑战模式卡牌选择)
	wave_manager.wave_completed.connect(_on_wave_completed_for_challenge)

func _determine_battle_mode() -> void:
	# 优先从 GameData 读取当前节点
	var cnode: String = GameData.world_progress.get("current_node", "")
	if cnode != "" and cnode != "start":
		node_data = WorldMap.get_map_node(cnode)
		if not node_data.is_empty():
			battle_mode = BattleMode.WORLD_MAP
			current_node_id = cnode
			print("[BattleController] 世界地图模式 - 节点:", node_data.get("name", cnode))
			return

	# 检查是否挑战模式
	if GameData.world_progress.get("challenge_active", false):
		battle_mode = BattleMode.CHALLENGE
		print("[BattleController] 无限挑战模式")
		return

	# 默认测试模式
	battle_mode = BattleMode.TEST
	print("[BattleController] 原型测试模式")

func _setup_challenge_mode() -> void:
	challenge_manager = ChallengeManager.new()
	challenge_manager.name = "ChallengeManager"
	add_child(challenge_manager)
	challenge_manager.start_challenge()
	challenge_wave_count = 0

	# 创建卡牌选择浮层
	var overlay_script: GDScript = load("res://scripts/ui/challenge_overlay.gd")
	challenge_overlay = overlay_script.new()
	challenge_overlay.name = "ChallengeOverlay"
	challenge_overlay.setup(challenge_manager)
	add_child(challenge_overlay)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.18, 0.14, 0.28))
	draw_line(Vector2(0, 500), Vector2(1280, 500), Color(0.35, 0.28, 0.45), 3.0)

func _on_enemy_reached_end(enemy: Node2D) -> void:
	if enemy is Enemy:
		castle.take_damage(enemy.damage_to_castle)

func _on_castle_destroyed() -> void:
	wave_manager.stop_battle()
	_handle_challenge_end()
	EventBus.battle_lost.emit()
	_on_battle_lost()

func _on_wave_completed_for_challenge(_wave_idx: int) -> void:
	if battle_mode != BattleMode.CHALLENGE or challenge_manager == null:
		return
	challenge_wave_count += 1
	challenge_manager.add_score(challenge_wave_count * 10)
	GameData.world_progress["challenge_wave"] = challenge_wave_count
	# 每 3 波显示卡牌选择
	if challenge_wave_count % 3 == 0 and challenge_wave_count < GameData.world_progress.get("max_challenge_waves", 20):
		if challenge_overlay and challenge_overlay.has_method("show_card_selection"):
			challenge_overlay.show_card_selection()

func _handle_challenge_end() -> void:
	if battle_mode == BattleMode.CHALLENGE and challenge_manager:
		challenge_manager.end_challenge()
		var score: int = challenge_manager.challenge_score
		GameData.world_progress["challenge_score"] = score
		# 更新最高分
		var high: int = GameData.world_progress.get("challenge_high_score", 0)
		if score > high:
			GameData.world_progress["challenge_high_score"] = score
		SaveManager.save_game()
	GameData.world_progress["challenge_active"] = false

func _on_battle_lost() -> void:
	GameData.world_progress["challenge_active"] = false
	GameData.world_progress["current_node"] = ""

func _on_battle_won_global() -> void:
	# 世界地图模式: 直接在 Autoload 上完成节点
	if battle_mode == BattleMode.WORLD_MAP and current_node_id != "":
		if not WorldMap.is_node_completed(current_node_id):
			WorldMap.complete_and_unlock(current_node_id)
			print("[BattleController] 节点完成: ", current_node_id)
		SaveManager.save_game()
