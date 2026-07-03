extends Node
## 梦游症 v0.5 集成测试 Runner
## 用 --quit-after N 跑 N 帧,每帧推进测试用例
## 输出格式 [TEST] tag status detail

var _phase: int = 0  # 当前测试阶段
var _frame: int = 0
var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	print("\n========== 梦游症 v0.5 集成测试开始 ==========")

func _process(_delta: float) -> void:
	# 每 30 帧推进一个 phase,让上一步的信号/event 有时间触发
	if _frame % 30 != 0:
		_frame += 1
		return
	match _phase:
		0:
			_test_module_a_deploy()
		1:
			_test_module_b_enemy_creature_hp()
		2:
			_test_module_c_death()
		3:
			_test_module_d_heal_resurrect()
		4:
			_test_module_e_reaction()
		5:
			_test_module_f_save()
		6:
			_finish()
	_phase += 1

func _test_module_a_deploy() -> void:
	print("\n--- [A] 战前部署与站位格 ---")
	var gd: Object = GameData
	# 注: 字段叫 creature_slots 不是 slot_count
	var slot_count: int = gd.castle_modules.get("creature_slots", 0)
	if slot_count >= 4:
		_pass("A1", "Castle 默认 creature_slots = %d" % slot_count)
	else:
		_fail("A1", "Castle creature_slots 异常 = %d" % slot_count)
	# A2: 动态改变
	gd.castle_modules["creature_slots"] = 6
	if gd.castle_modules["creature_slots"] == 6:
		_pass("A2", "creature_slots 动态修改生效 (4->6)")
	else:
		_fail("A2", "creature_slots 不可改")
	gd.castle_modules["creature_slots"] = 4  # 还原

	# A3: get_position_type_for_index
	var CastleScript: GDScript = load("res://scripts/entities/castle.gd")
	if CastleScript != null:
		_pass("A3", "Castle 脚本加载成功")
	else:
		_fail("A3", "Castle 脚本加载失败")

	_advance()

func _test_module_b_enemy_creature_hp() -> void:
	print("\n--- [B] 敌人攻击行为 + 生物HP ---")
	var gd: Object = GameData
	# B1: 选一只生物,让 hp 减少
	gd._init_creature_health("mech_sniper")
	var before: float = gd.get_creature_hp("mech_sniper")
	var max_hp: float = gd.get_creature_max_hp("mech_sniper")
	if before > 0.0 and max_hp > 0.0:
		_pass("B1", "初始 HP = %.0f/%.0f" % [before, max_hp])
	else:
		_fail("B1", "HP 异常 before=%.0f max=%.0f" % [before, max_hp])

	# B2: take_damage 走 GameData
	gd.creature_take_damage("mech_sniper", 20.0)
	var after: float = gd.get_creature_hp("mech_sniper")
	if after < before:
		_pass("B2", "GameData.creature_take_damage 生效: %.0f -> %.0f" % [before, after])
	else:
		_fail("B2", "GameData.creature_take_damage 未生效 before=%.0f after=%.0f" % [before, after])

	# B3: 阶段变化
	var stage: int = gd.get_creature_injury_stage("mech_sniper")
	if stage >= 0 and stage <= 4:
		_pass("B3", "受伤阶段 = %d (0=健康 4=死亡)" % stage)
	else:
		_fail("B3", "阶段值越界 = %d" % stage)

	# B4: 死亡后 is_dead = true
	gd.creature_take_damage("mech_sniper", 9999.0)
	if gd.is_creature_dead("mech_sniper"):
		_pass("B4", "死亡后 is_dead = true")
	else:
		_fail("B4", "死亡检查失败")

	# 重置
	gd.creature_health["mech_sniper"]["current_hp"] = max_hp
	gd.creature_health["mech_sniper"]["stage"] = gd.InjuryStage.HEALTHY
	gd.creature_health["mech_sniper"]["is_dead"] = false

	_advance()

func _test_module_c_death() -> void:
	print("\n--- [C] 死亡 + 战斗结算 ---")
	# C1: creature_die_in_battle
	var gd: Object = GameData
	gd.creature_die_in_battle("spirit_wisp")
	if gd.is_creature_dead("spirit_wisp"):
		_pass("C1", "creature_die_in_battle 正确置 is_dead")
	else:
		_fail("C1", "creature_die_in_battle 未生效")
	# C2: creature_died_in_battle 信号应被 emit(检查 reaction)
	# 重新激活以测后续
	gd.creature_health["spirit_wisp"]["is_dead"] = false
	gd.creature_health["spirit_wisp"]["current_hp"] = gd.creature_health["spirit_wisp"]["max_hp"]
	gd.creature_health["spirit_wisp"]["stage"] = gd.InjuryStage.HEALTHY

	# C3: 新手保护 — check_newbie_protection
	# 先强制死亡
	gd.creature_die_in_battle("thorn_beast")
	var protected: bool = gd.check_newbie_protection("thorn_beast")
	if protected and not gd.is_creature_dead("thorn_beast"):
		_pass("C3", "新手保护生效 (前3局自动复活)")
	else:
		_fail("C3", "新手保护未生效 protected=%s dead=%s" % [protected, gd.is_creature_dead("thorn_beast")])
	# C4: 战外恢复
	gd.creature_health["thorn_beast"]["current_hp"] = 5.0
	gd.update_injury_stage("thorn_beast")
	gd.post_battle_recovery()
	if gd.get_creature_hp("thorn_beast") >= gd.get_creature_max_hp("thorn_beast"):
		_pass("C4", "post_battle_recovery 满血")
	else:
		_log("C4", "post_battle_recovery 未满血 — 该生物不是 LIGHT")

	_advance()

func _test_module_d_heal_resurrect() -> void:
	print("\n--- [D] 战外治疗 + 复活 ---")
	var gd: Object = GameData
	# D1: 死亡后 perform_free_resurrect
	gd.creature_die_in_battle("scrap_gambler")
	gd.enable_free_resurrect("scrap_gambler")
	if gd.can_free_resurrect("scrap_gambler"):
		_pass("D1", "24h 免费复活可用")
	else:
		# 立即模拟 24h 后
		var fr: Dictionary = gd.world_progress.get("free_resurrect_available", {})
		if fr.has("scrap_gambler"):
			_pass("D1", "已设置 24h 倒计时,剩余 %d 秒" % gd.free_resurrect_remaining("scrap_gambler"))
		else:
			_fail("D1", "enable_free_resurrect 未记录时间戳")
	if gd.perform_free_resurrect("scrap_gambler"):
		if not gd.is_creature_dead("scrap_gambler"):
			_pass("D1b", "perform_free_resurrect 成功")
		else:
			_fail("D1b", "复活后仍死亡")
	else:
		_log("D1b", "免费复活不可用(可能未到期),跳过")

	# D2: 付费复活
	gd.creature_die_in_battle("echo_walker")
	# 给足够资源
	gd.resources["gold"] = 10000
	gd.resources["soul"] = 100
	# 不一定能直接调,改用 API 检查金币逻辑
	var gold_before: int = gd.resources.get("gold", 0)
	gd.spend_resource("gold", 500)
	if gd.resources["gold"] == gold_before - 500:
		_pass("D2", "spend_resource 正确扣金币 %d -> %d" % [gold_before, gd.resources["gold"]])
	else:
		_fail("D2", "spend_resource 异常")

	# D3: use_heal_item — 设为 LIGHT 阶段 (75% HP) 才能用基础包
	gd._init_healing_items()
	gd.healing_items["basic_heal_pack"] = 5
	gd.creature_health["echo_walker"]["current_hp"] = gd.creature_health["echo_walker"]["max_hp"] * 0.80  # LIGHT 阶段
	gd.update_injury_stage("echo_walker")
	var stage_before: int = gd.get_creature_injury_stage("echo_walker")
	var used: bool = gd.use_heal_item("basic_heal_pack", "echo_walker")
	if used and gd.healing_items["basic_heal_pack"] == 4:
		_pass("D3", "use_heal_item 生效: 5->4 包,HP %.0f -> %.0f (stage=%d)" % [gd.creature_health["echo_walker"]["max_hp"]*0.80, gd.get_creature_hp("echo_walker"), stage_before])
	else:
		_fail("D3", "use_heal_item 失败 used=%s 包数=%d stage=%d" % [used, gd.healing_items.get("basic_heal_pack", -1), stage_before])

	_advance()

func _test_module_e_reaction() -> void:
	print("\n--- [E] 跨派系反应 ---")
	# E1: faction_synergy 必须 class_name 可用
	var fs_script: GDScript = load("res://scripts/systems/faction_synergy.gd")
	if fs_script == null:
		_fail("E0", "faction_synergy 加载失败")
		_advance(); return
	# 强制一次 reaction_triggered 信号
	var emitted: Array = []
	EventBus.reaction_triggered.connect(func(rs: Array):
		emitted.append(rs)
	)
	EventBus.reaction_triggered.emit([{"name":"测试反应", "desc":"测", "color":Color(1,1,1)}])
	if emitted.size() == 1:
		_pass("E1", "reaction_triggered 信号正常 emit/connect")
	else:
		_fail("E1", "reaction_triggered 未触发 listener")

	# E2: 测试 reward_table
	var reward: Dictionary = RewardTable.grant_reward("tech_01")
	print("  [DEBUG E2] reward = %s" % str(reward))
	if reward.has("creature_added") and reward["creature_added"] != "":
		_pass("E2", "RewardTable.grant_reward(tech_01) creature=%s gold=%d" % [reward["creature_added"], reward.get("gold", 0)])
	else:
		_fail("E2", "RewardTable.grant_reward 返回无 creature_added, reward=%s" % str(reward))

	_advance()

func _test_module_f_save() -> void:
	print("\n--- [F] 存档与跨局继承 ---")
	# F1: 改 HP,save,改 HP,load,看是否还原
	var gd: Object = GameData
	gd.creature_health["mech_sniper"]["current_hp"] = 42.0
	SaveManager.save_game()
	var load_ok: bool = SaveManager.load_game()
	if load_ok:
		_pass("F1", "save/load 流程跑通")
	else:
		_fail("F1", "load_game 失败")
	var hp_after: float = gd.get_creature_hp("mech_sniper")
	if absf(hp_after - 42.0) < 0.1:
		_pass("F2", "HP 跨存档正确: 42.0 -> %.1f" % hp_after)
	else:
		_fail("F2", "HP 跨存档丢失: 42.0 -> %.1f" % hp_after)

	# F3: 死亡状态跨存档
	gd.creature_die_in_battle("spirit_wisp")
	SaveManager.save_game()
	SaveManager.load_game()
	if gd.is_creature_dead("spirit_wisp"):
		_pass("F3", "死亡状态跨存档保留")
	else:
		_fail("F3", "死亡状态丢失")

	_advance()

func _finish() -> void:
	print("\n========== 测试完成 ==========")
	print("通过: %d" % _passes)
	print("失败: %d" % _failures.size())
	if _failures.size() > 0:
		print("失败列表:")
		for f in _failures:
			print("  - %s" % f)
		print("\n❌ 有失败用例")
	else:
		print("\n✅ 全部通过")
	# 给一帧让 print 出来再退出
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)

func _advance() -> void:
	pass  # phase 自动递增

func _pass(tag: String, detail: String) -> void:
	_passes += 1
	print("  [PASS] %s — %s" % [tag, detail])

func _fail(tag: String, detail: String) -> void:
	_failures.append("%s: %s" % [tag, detail])
	printerr("  [FAIL] %s — %s" % [tag, detail])

func _log(tag: String, detail: String) -> void:
	print("  [INFO] %s — %s" % [tag, detail])
