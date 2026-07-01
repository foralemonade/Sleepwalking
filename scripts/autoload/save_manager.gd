extends Node
## 存档管理器 (Autoload) — 管理游戏存档
## 使用 Godot ConfigFile 存储到 user:// 目录

const SAVE_PATH: String = "user://savegame.cfg"

var has_save: bool = false

func _ready() -> void:
	_check_save_exists()

func _check_save_exists() -> void:
	has_save = FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var config := ConfigFile.new()

	# 玩家生物
	config.set_value("player", "creatures", GameData.player_creatures)
	config.set_value("player", "equipped_modules", GameData.player_equipped_modules)
	config.set_value("player", "inventory_modules", GameData.player_inventory_modules)
	config.set_value("player", "skills", GameData.player_skills)
	config.set_value("player", "equipped_skills", GameData.equipped_skills)

	# 资源
	config.set_value("resources", "gold", GameData.resources["gold"])
	config.set_value("resources", "gems", GameData.resources["gems"])
	config.set_value("resources", "energy_core", GameData.resources["energy_core"])

	# 声誉
	for faction in GameData.faction_reputation:
		config.set_value("reputation", str(faction), GameData.faction_reputation[faction])

	# 世界进度
	config.set_value("world", "unlocked_nodes", GameData.world_progress["unlocked_nodes"])
	config.set_value("world", "completed_nodes", GameData.world_progress["completed_nodes"])

	# 城堡模块
	for key in GameData.castle_modules:
		config.set_value("castle", key, GameData.castle_modules[key])

	# 设置
	config.set_value("settings", "bgm_volume", GameData.settings["bgm_volume"])
	config.set_value("settings", "sfx_volume", GameData.settings["sfx_volume"])

	# 挑战最高分
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

	var config := ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	if err != OK:
		push_error("[SaveManager] 读取存档失败: " + str(err))
		return false

	# 玩家生物
	GameData.player_creatures = config.get_value("player", "creatures", ["mech_sniper", "spirit_wisp", "thorn_beast", "scrap_gambler", "echo_walker"])
	GameData.player_equipped_modules = config.get_value("player", "equipped_modules", [])
	GameData.player_inventory_modules = config.get_value("player", "inventory_modules", [])
	GameData.player_skills = config.get_value("player", "skills", ["energy_burst", "shield_overload"])
	GameData.equipped_skills = config.get_value("player", "equipped_skills", ["energy_burst"])

	# 资源
	GameData.resources["gold"] = config.get_value("resources", "gold", 200)
	GameData.resources["gems"] = config.get_value("resources", "gems", 20)
	GameData.resources["energy_core"] = config.get_value("resources", "energy_core", 0)

	# 声誉
	for faction in GameData.faction_reputation:
		GameData.faction_reputation[faction] = config.get_value("reputation", str(faction), 0)

	# 世界进度
	GameData.world_progress["unlocked_nodes"] = config.get_value("world", "unlocked_nodes", [])
	GameData.world_progress["completed_nodes"] = config.get_value("world", "completed_nodes", [])

	# 城堡模块
	for key in GameData.castle_modules:
		GameData.castle_modules[key] = config.get_value("castle", key, GameData.castle_modules[key])

	# 设置
	GameData.settings["bgm_volume"] = config.get_value("settings", "bgm_volume", 0.8)
	GameData.settings["sfx_volume"] = config.get_value("settings", "sfx_volume", 1.0)

	# 挑战高分
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
	GameData.player_skills = ["energy_burst", "shield_overload"]
	GameData.equipped_skills = ["energy_burst"]

	GameData.resources = {"gold": 200, "gems": 20, "energy_core": 0}

	for faction in GameData.faction_reputation:
		GameData.faction_reputation[faction] = 0

	GameData.world_progress = {
		"unlocked_nodes": [],
		"completed_nodes": [],
		"current_node": "",
		"challenge_active": false,
		"challenge_score": 0,
		"challenge_high_score": GameData.world_progress.get("challenge_high_score", 0),
	}

	GameData.castle_modules = {
		"creature_slots": 4, "defense": 100, "energy_regen": 1.0, "resonance_bonus": 0.0,
	}

	delete_save()
	has_save = true
	save_game()
	print("[SaveManager] 新游戏已创建")
