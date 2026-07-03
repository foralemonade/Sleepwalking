extends Node2D
## 战斗场景主控制器 v0.4
## 协调 Castle / WaveManager / SkillSystem / BattleUI
## v0.4 变更:
##   - 战前部署阶段 (DEPLOY → FIGHT)
##   - 暂停/慢速模式支持
##   - 生物生死信号接驳 → EventBus
##   - 战后恢复 (post_battle_recovery)
##   - 设置 enemy 的 creature_container + castle_ref
##   - 核心HP毁灭判定
##   - 战斗阶段状态管理

enum BattleMode { WORLD_MAP, CHALLENGE, TEST }
enum BattlePhase { DEPLOY, FIGHT, PAUSED, SLOW, RESULT }

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
var current_phase: int = BattlePhase.DEPLOY

var _is_slow_mode: bool = false
var _time_scale: float = 1.0

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
	# 注入 battle_controller_ref, 供 WaveManager 设置敌人引用
	wave_manager.battle_controller_ref = self

	if battle_ui.has_method("setup_references"):
		battle_ui.setup_references(castle, wave_manager, skill_system)
	if battle_ui.has_method("set_battle_controller"):
		battle_ui.set_battle_controller(self)

	# 恢复城堡状态
	castle.max_shield = GameData.castle_modules.get("defense", 100)
	castle.slot_count = GameData.castle_modules["creature_slots"]
	castle.reset_for_battle()

	# 挑战模式: 创建 ChallengeManager
	if battle_mode == BattleMode.CHALLENGE:
		_setup_challenge_mode()

	# 信号接驳
	_connect_battle_signals()

	# 初始阶段: 战前部署
	_set_phase(BattlePhase.DEPLOY)

func _connect_battle_signals() -> void:
	# 城堡毁灭
	castle.castle_destroyed.connect(_on_castle_destroyed)
	castle.castle_core_destroyed.connect(_on_castle_core_destroyed)
	# 敌人到达终点
	EventBus.enemy_reached_end.connect(_on_enemy_reached_end)
	# 战斗胜利 (全局)
	EventBus.battle_won.connect(_on_battle_won_global)
	# 生物生死
	EventBus.creature_died_in_battle.connect(_on_creature_died_in_battle)
	EventBus.creature_resurrected.connect(_on_creature_resurrected)
	# 波次完成 (挑战模式卡牌选择)
	wave_manager.wave_completed.connect(_on_wave_completed_for_challenge)

# ============================================================
# 战斗阶段管理
# ============================================================
func _set_phase(phase: int) -> void:
	current_phase = phase
	match phase:
		BattlePhase.DEPLOY:
			EventBus.battle_phase_changed.emit("deploy")
			# 部署阶段: 暂停战斗逻辑, 等待玩家放置生物
			wave_manager.stop_battle()
		BattlePhase.FIGHT:
			EventBus.battle_phase_changed.emit("fight")
			_is_slow_mode = false
			_time_scale = 1.0
			Engine.time_scale = 1.0
		BattlePhase.PAUSED:
			EventBus.battle_phase_changed.emit("paused")
			EventBus.wave_pause_started.emit()
			Engine.time_scale = 0.0
		BattlePhase.SLOW:
			EventBus.battle_phase_changed.emit("slow")
			_is_slow_mode = true
			_time_scale = 0.3
			Engine.time_scale = 0.3
		BattlePhase.RESULT:
			EventBus.battle_phase_changed.emit("result")

## 开始战斗 — 从部署阶段过渡到战斗阶段
func start_fight() -> void:
	_set_phase(BattlePhase.FIGHT)
	wave_manager.current_wave = -1
	wave_manager.start_battle()

## 暂停 / 继续
func toggle_pause() -> void:
	if current_phase == BattlePhase.PAUSED:
		_set_phase(BattlePhase.FIGHT)
		EventBus.wave_pause_ended.emit()
	elif current_phase == BattlePhase.FIGHT or current_phase == BattlePhase.SLOW:
		_set_phase(BattlePhase.PAUSED)

## 慢速 / 正常
func toggle_slow() -> void:
	if current_phase == BattlePhase.SLOW:
		_set_phase(BattlePhase.FIGHT)
	elif current_phase == BattlePhase.FIGHT:
		_set_phase(BattlePhase.SLOW)
	elif current_phase == BattlePhase.PAUSED:
		# 暂停时切换慢速 → 取消暂停并进入慢速
		_set_phase(BattlePhase.SLOW)
		EventBus.wave_pause_ended.emit()

func get_phase_name() -> String:
	match current_phase:
		BattlePhase.DEPLOY: return "战前部署"
		BattlePhase.FIGHT: return "战斗中"
		BattlePhase.PAUSED: return "暂停"
		BattlePhase.SLOW: return "慢速模式"
		BattlePhase.RESULT: return "结算"
		_: return "未知"

func is_deploy_phase() -> bool:
	return current_phase == BattlePhase.DEPLOY

# ============================================================
# 战斗模式判定
# ============================================================
func _determine_battle_mode() -> void:
	var cnode: String = GameData.world_progress.get("current_node", "")
	if cnode != "" and cnode != "start":
		node_data = WorldMap.get_map_node(cnode)
		if not node_data.is_empty():
			battle_mode = BattleMode.WORLD_MAP
			current_node_id = cnode
			print("[BattleController] 世界地图模式 - 节点:", node_data.get("name", cnode))
			return
	if GameData.world_progress.get("challenge_active", false):
		battle_mode = BattleMode.CHALLENGE
		print("[BattleController] 无限挑战模式")
		return
	battle_mode = BattleMode.TEST
	print("[BattleController] 原型测试模式")

func _setup_challenge_mode() -> void:
	challenge_manager = ChallengeManager.new()
	challenge_manager.name = "ChallengeManager"
	add_child(challenge_manager)
	challenge_manager.start_challenge()
	challenge_wave_count = 0
	var overlay_script: GDScript = load("res://scripts/ui/challenge_overlay.gd")
	challenge_overlay = overlay_script.new()
	challenge_overlay.name = "ChallengeOverlay"
	challenge_overlay.setup(challenge_manager)
	add_child(challenge_overlay)

# ============================================================
# 绘制背景
# ============================================================
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.18, 0.14, 0.28))
	draw_line(Vector2(0, 500), Vector2(1280, 500), Color(0.35, 0.28, 0.45), 3.0)

# ============================================================
# 事件处理
# ============================================================
func _on_enemy_reached_end(enemy: Node2D) -> void:
	# 注意: 伤害由 enemy.gd 的 _reach_end() 直接调用 castle 处理
	# battle_controller 不再重复施加伤害, 只处理波次计数
	# (WaveManager 的 _on_enemy_reached_end 会递减 enemies_remaining)
	pass

func _on_castle_destroyed() -> void:
	_handle_battle_lost()

func _on_castle_core_destroyed() -> void:
	_handle_battle_lost()

func _on_creature_died_in_battle(cid: String) -> void:
	print("[BattleController] 生物阵亡: %s" % cid)
	# 清空阵亡生物的槽位
	for i in range(castle.creature_slots.size()):
		if castle.creature_slots[i]["creature_id"] == cid:
			var slot: Dictionary = castle.creature_slots[i]
			if slot["creature"] != null:
				slot["creature"].queue_free()
			slot["creature"] = null
			slot["creature_id"] = ""
			castle.refresh_creature_ids()
			castle.recalculate_synergies()
			break

func _on_creature_resurrected(cid: String) -> void:
	print("[BattleController] 生物复活: %s" % cid)

func _handle_battle_lost() -> void:
	wave_manager.stop_battle()
	_set_phase(BattlePhase.RESULT)
	_handle_challenge_end()
	EventBus.battle_lost.emit()
	GameData.world_progress["challenge_active"] = false
	GameData.world_progress["current_node"] = ""

# ============================================================
# 战后处理
# ============================================================
func _on_battle_won_global() -> void:
	_set_phase(BattlePhase.RESULT)
	# 战后恢复 — 轻伤自恢复
	GameData.post_battle_recovery()
	# 保存生物健康状态到城堡模块
	GameData.castle_modules["core_hp"] = castle.core_hp
	GameData.castle_modules["core_hp_max"] = castle.core_hp_max
	# 世界地图模式: 完成节点
	if battle_mode == BattleMode.WORLD_MAP and current_node_id != "":
		if not WorldMap.is_node_completed(current_node_id):
			WorldMap.complete_and_unlock(current_node_id)
			print("[BattleController] 节点完成: ", current_node_id)
		SaveManager.save_game()

func _on_wave_completed_for_challenge(_wave_idx: int) -> void:
	if battle_mode != BattleMode.CHALLENGE or challenge_manager == null:
		return
	challenge_wave_count += 1
	challenge_manager.add_score(challenge_wave_count * 10)
	GameData.world_progress["challenge_wave"] = challenge_wave_count
	if challenge_wave_count % 3 == 0 and challenge_wave_count < GameData.world_progress.get("max_challenge_waves", 20):
		if challenge_overlay and challenge_overlay.has_method("show_card_selection"):
			challenge_overlay.show_card_selection()

func _handle_challenge_end() -> void:
	if battle_mode == BattleMode.CHALLENGE and challenge_manager:
		challenge_manager.end_challenge()
		var score: int = challenge_manager.challenge_score
		GameData.world_progress["challenge_score"] = score
		var high: int = GameData.world_progress.get("challenge_high_score", 0)
		if score > high:
			GameData.world_progress["challenge_high_score"] = score
		SaveManager.save_game()
	GameData.world_progress["challenge_active"] = false

## 在 WaveManager 生成敌人时, 设置 creature_container 和 castle_ref
func setup_enemy_references(enemy: Node2D) -> void:
	if enemy is Enemy:
		var en: Enemy = enemy as Enemy
		en.creature_container = castle  # 生物在 castle 下
		en.castle_ref = castle
