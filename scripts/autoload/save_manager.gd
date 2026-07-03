extends Node
## 存档管理器 (Autoload) v0.4 — 管理游戏存档
## v0.4 变更:
##   - 新增 creature_health 存档 (跨局继承的HP/受伤状态)
##   - 新增 healing_items 存档 (治疗道具背包)
##   - 新增 core_hp / core_hp_max 存档
##   - 新增 battle_protection_count 存档
## 使用 Godot ConfigFile 存储到 user:// 目录

const SAVE_PATH: String = "user://savegame.cfg"

var has_save: bool = false

func _ready() -> void:
	_check_save_exists()

func _check_save_exists() -> void:
	has_save = FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()

	# ---- 玩家生物 ----
	config.set_value("player", "creatures", GameData.player_creatures)
	config.set_value("player", "equipped_modules", GameData.player_equipped_modules)
	config.set_value("player", "inventory_modules", GameData.player_inventory_modules)
	config.set_value("player", "skills", GameData.player_skills)
	config.set_value("player", "equipped_skills", GameData.equipped_skills)

	# ---- 生物健康状态 (v0.4 新增) ----
	# creature_health 是嵌套字典, 逐个存储
	for cid: String in GameData.creature_health:
		var ch: Dictionary = GameData.creature_health[cid]
		config.set_value("creature_health", cid + "_current_hp", ch["current_hp"])
		config.set_value("creature_health", cid + "_max_hp", ch["max_hp"])
		config.set_value("creature_health", cid + "_stage", ch["stage"])
		config.set_value("creature_health", cid + "_is_dead", ch["is_dead"])

	# ---- 治疗道具背包 (v0.4 新增) ----
	for item_id: String in GameData.healing_items:
		config.set_value("healing_items", item_id, GameData.healing_items[item_id])

	# ---- 资源 ----
	config.set_value("resources", "gold", GameData.resources["gold"])
	config.set_value("resources", "gems", GameData.resources["gems"])
	config.set_value("resources", "energy_core", GameData.resources["energy_core"])

	# ---- 声誉 ----
	for faction: int in GameData.faction_reputation:
		config.set_value("reputation", str(faction), GameData.faction_reputation[faction])

	# ---- 世界进度 ----
	config.set_value("world", "unlocked_nodes", GameData.world_progress["unlocked_nodes"])
	config.set_value("world", "completed_nodes", GameData.world_progress["completed_nodes"])
	config.set_value("world", "current_node", GameData.world_progress.get("current_node", "start"))
	config.set_value("world", "challenge_active", GameData.world_progress.get("challenge_active", false))
	config.set_value("world", "challenge_score", GameData.world_progress.get("challenge_score", 0))
	config.set_value("world", "challenge_wave", GameData.world_progress.get("challenge_wave", 0))
	config.set_value("world", "max_challenge_waves", GameData.world_progress.get("max_challenge_waves", 20))
	config.set_value("world", "battle_protection_count", GameData.world_progress.get("battle_protection_count", 3))

	# ---- 城堡模块 ----
	for key: String in GameData.castle_modules:
		config.set_value("castle", key, GameData.castle_modules[key])

	# ---- 设置 ----
	config.set_value("settings", "bgm_volume", GameData.settings["bgm_volume"])
	config.set_value("settings", "sfx_volume", GameData.settings["sfx_volume"])

	# ---- 挑战最高分 ----
	config.set_value("challenge", "high_score", GameData.world_progress.get("challenge_high_score", 0))

	var err: int = config.save(SAVE_PATH)
	if err == OK:
		has_save = true
		print("[SaveManager] 游戏已保存")
	else:
		push_error("[SaveManager] 保存失败: " + str(err))

func load_game() -> bool:
	if not has_save:
		return false

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	if err != OK:
		push_error("[SaveManager] 读取存档失败: " + str(err))
		return false

	# ---- 玩家生物 ----
	GameData.player_creatures = config.get_value("player", "creatures", ["mech_sniper", "spirit_wisp", "thorn_beast", "scrap_gambler", "echo_walker"])
	GameData.player_equipped_modules = config.get_value("player", "equipped_modules", [])
	GameData.player_inventory_modules = config.get_value("player", "inventory_modules", [])
	GameData.player_skills = config.get_value("player", "skills", ["energy_burst", "shield_overload", "healing_flow"])
	GameData.equipped_skills = config.get_value("player", "equipped_skills", ["energy_burst"])

	# ---- 生物健康状态 ----
	# 先初始化默认值, 再从存档覆盖
	for cid: String in GameData.player_creatures:
		GameData._init_creature_health(cid)
	# 从存档恢复
	var ch_sections: PackedStringArray = config.get_sections()
	if "creature_health" in ch_sections:
		for cid: String in GameData.player_creatures:
			var has_data: bool = config.has_section_key("creature_health", cid + "_current_hp")
			if has_data and GameData.creature_health.has(cid):
				GameData.creature_health[cid]["current_hp"] = config.get_value("creature_health", cid + "_current_hp", GameData.creature_health[cid]["max_hp"])
				GameData.creature_health[cid]["max_hp"] = config.get_value("creature_health", cid + "_max_hp", GameData.creature_health[cid]["max_hp"])
				GameData.creature_health[cid]["stage"] = config.get_value("creature_health", cid + "_stage", GameData.InjuryStage.HEALTHY)
				GameData.creature_health[cid]["is_dead"] = config.get_value("creature_health", cid + "_is_dead", false)

	# ---- 治疗道具背包 ----
	GameData._init_healing_items()  # 先设默认值
	if "healing_items" in ch_sections:
		for item_id: String in GameData.healing_items:
			GameData.healing_items[item_id] = config.get_value("healing_items", item_id, GameData.healing_items[item_id])

	# ---- 资源 ----
	GameData.resources["gold"] = config.get_value("resources", "gold", 200)
	GameData.resources["gems"] = config.get_value("resources", "gems", 20)
	GameData.resources["energy_core"] = config.get_value("resources", "energy_core", 0)

	# ---- 声誉 ----
	for faction: int in GameData.faction_reputation:
		GameData.faction_reputation[faction] = config.get_value("reputation", str(faction), 0)

	# ---- 世界进度 ----
	GameData.world_progress["unlocked_nodes"] = config.get_value("world", "unlocked_nodes", [])
	GameData.world_progress["completed_nodes"] = config.get_value("world", "completed_nodes", [])
	GameData.world_progress["current_node"] = config.get_value("world", "current_node", "start")
	GameData.world_progress["challenge_active"] = config.get_value("world", "challenge_active", false)
	GameData.world_progress["challenge_score"] = config.get_value("world", "challenge_score", 0)
	GameData.world_progress["challenge_wave"] = config.get_value("world", "challenge_wave", 0)
	GameData.world_progress["max_challenge_waves"] = config.get_value("world", "max_challenge_waves", 20)
	GameData.world_progress["battle_protection_count"] = config.get_value("world", "battle_protection_count", 3)

	# ---- 城堡模块 ----
	for key: String in GameData.castle_modules:
		GameData.castle_modules[key] = config.get_value("castle", key, GameData.castle_modules[key])

	# ---- 设置 ----
	GameData.settings["bgm_volume"] = config.get_value("settings", "bgm_volume", 0.8)
	GameData.settings["sfx_volume"] = config.get_value("settings", "sfx_volume", 1.0)

	# ---- 挑战高分 ----
	GameData.world_progress["challenge_high_score"] = config.get_value("challenge", "high_score", 0)

	print("[SaveManager] 游戏已读取")
	return true

func delete_save() -> void:
	if has_save:
		DirAccess.remove_absolute(SAVE_PATH)
		has_save = false
		print("[SaveManager] 存档已删除")

func new_game() -> void:
	# 重置到初始状态
	GameData.player_creatures = ["mech_sniper", "spirit_wisp", "thorn_beast", "scrap_gambler", "echo_walker"]
	GameData.player_equipped_modules = []
	GameData.player_inventory_modules = []
	GameData.player_skills = ["energy_burst", "shield_overload", "healing_flow"]
	GameData.equipped_skills = ["energy_burst"]

	# 重新初始化所有生物健康状态
	GameData.creature_health.clear()
	for cid: String in GameData.player_creatures:
		GameData._init_creature_health(cid)

	GameData.healing_items = {
		"basic_heal_pack": 3,
		"advanced_heal_pack": 1,
		"emergency_heal": 0,
		"soul_fragment": 0,
		"resurrection_crystal": 0,
	}

	GameData.resources = {"gold": 200, "gems": 20, "energy_core": 0}

	for faction: int in GameData.faction_reputation:
		GameData.faction_reputation[faction] = 0

	GameData.world_progress = {
		"unlocked_nodes": [],
		"completed_nodes": [],
		"current_node": "start",
		"challenge_active": false,
		"challenge_score": 0,
		"challenge_high_score": GameData.world_progress.get("challenge_high_score", 0),
		"challenge_wave": 0,
		"max_challenge_waves": 20,
		"battle_protection_count": 3,
	}

	GameData.castle_modules = {
		"creature_slots": 4, "defense": 100, "energy_regen": 1.0,
		"resonance_bonus": 0.0, "core_hp": 200, "core_hp_max": 200,
	}

	delete_save()
	has_save = true
	save_game()
	print("[SaveManager] 新游戏已创建")
