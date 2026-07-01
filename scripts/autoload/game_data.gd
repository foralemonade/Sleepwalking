extends Node
## 梦游症 - 全局游戏数据管理 (Autoload)
## 管理生物数据库、派系数据、玩家状态、城堡模块、资源等

# ============================================================
# 派系枚举
# ============================================================
enum Faction {
	NONE = 0,
	TECH = 1,
	FAITH = 2,
	NATURE = 3,
	COMMERCE = 4,
	MEMORY = 5,
}

const FACTION_NAMES: Dictionary = {
	Faction.TECH: "秩序·技术",
	Faction.FAITH: "信仰·神秘",
	Faction.NATURE: "自然·野性",
	Faction.COMMERCE: "商业·混沌",
	Faction.MEMORY: "记忆·复古",
}

const FACTION_COLORS: Dictionary = {
	Faction.TECH: Color(0.55, 0.80, 0.95),     # 冰蓝
	Faction.FAITH: Color(0.95, 0.78, 0.82),     # 柔粉
	Faction.NATURE: Color(0.68, 0.92, 0.82),    # 薄荷绿
	Faction.COMMERCE: Color(0.95, 0.82, 0.72),   # 浅珊瑚
	Faction.MEMORY: Color(0.78, 0.65, 0.95),     # 浅紫丁香
}

# ============================================================
# 生物数据库
# ============================================================
var creature_database: Dictionary = {}
var module_database: Dictionary = {}

# ============================================================
# 玩家状态
# ============================================================
var player_creatures: Array[String] = []
var player_equipped_modules: Array[String] = []
var player_inventory_modules: Array[String] = []

var faction_reputation: Dictionary = {
	Faction.TECH: 0, Faction.FAITH: 0, Faction.NATURE: 0,
	Faction.COMMERCE: 0, Faction.MEMORY: 0,
}

var resources: Dictionary = {
	"gold": 200, "gems": 20, "energy_core": 0,
}

var world_progress: Dictionary = {
	"unlocked_nodes": [], "completed_nodes": [], "current_node": "start",
}

var castle_modules: Dictionary = {
	"creature_slots": 4, "defense": 100, "energy_regen": 1.0, "resonance_bonus": 0.0,
}

var player_skills: Array[String] = ["energy_burst", "shield_overload"]
var equipped_skills: Array[String] = ["energy_burst"]

var settings: Dictionary = { "bgm_volume": 0.8, "sfx_volume": 1.0 }

func _ready():
	_init_creature_database()
	_init_module_database()
	_init_player_creatures()
	print("[GameData] 游戏数据初始化完成")

func _init_creature_database():
	creature_database = {
		"mech_sniper": {
			"id":"mech_sniper","name":"机械狙击手","faction":Faction.TECH,"rarity":1,
			"attack":28,"attack_speed":1.2,"range":420.0,"target_priority":"lowest_health",
			"skill_name":"精准锁定","skill_desc":"攻击 15% 概率造成双倍伤害",
			"skill_chance":0.15,"skill_multiplier":2.0,
		},
		"steel_hound": {
			"id":"steel_hound","name":"钢牙猎犬","faction":Faction.TECH,"rarity":1,
			"attack":18,"attack_speed":2.2,"range":260.0,"target_priority":"nearest",
			"skill_name":"撕咬","skill_desc":"对护盾敌人额外造成 40% 伤害","anti_shield_bonus":0.40,
		},
		"tesla_core": {
			"id":"tesla_core","name":"特斯拉核心","faction":Faction.TECH,"rarity":2,
			"attack":16,"attack_speed":3.0,"range":320.0,"target_priority":"nearest",
			"skill_name":"连锁闪电","skill_desc":"攻击弹射至 2 个额外目标","chain_targets":2,"chain_decay":0.3,
		},
		"war_mech": {
			"id":"war_mech","name":"战争机甲","faction":Faction.TECH,"rarity":3,
			"attack":35,"attack_speed":0.7,"range":380.0,"target_priority":"elite_first",
			"skill_name":"导弹轰炸","skill_desc":"每 8 秒对范围内敌人造成 80% 伤害","aoe_cooldown":8.0,"aoe_ratio":0.8,"aoe_range":200.0,
		},
		"spirit_wisp": {
			"id":"spirit_wisp","name":"灵火","faction":Faction.FAITH,"rarity":1,
			"attack":20,"attack_speed":1.5,"range":350.0,"target_priority":"nearest",
			"skill_name":"灵魂灼烧","skill_desc":"攻击附带灼烧","burn_ratio":0.20,"burn_duration":3.0,
		},
		"ritual_bell": {
			"id":"ritual_bell","name":"祭祀铃","faction":Faction.FAITH,"rarity":1,
			"attack":12,"attack_speed":1.0,"range":500.0,"target_priority":"elite_first",
			"skill_name":"镇魂","skill_desc":"攻击减速敌人 25%","slow_factor":0.75,"slow_duration":1.5,
		},
		"phantom_priest": {
			"id":"phantom_priest","name":"幻影祭司","faction":Faction.FAITH,"rarity":2,
			"attack":24,"attack_speed":0.8,"range":380.0,"target_priority":"lowest_health",
			"skill_name":"献祭","skill_desc":"击杀敌人恢复城堡 5 护盾","heal_on_kill":5,
		},
		"divine_guard": {
			"id":"divine_guard","name":"圣盾守卫","faction":Faction.FAITH,"rarity":3,
			"attack":14,"attack_speed":1.3,"range":300.0,"target_priority":"nearest",
			"skill_name":"庇护光环","skill_desc":"城堡护盾上限+30","castle_shield_bonus":30,"ally_defense_bonus":0.10,
		},
		"thorn_beast": {
			"id":"thorn_beast","name":"荆棘兽","faction":Faction.NATURE,"rarity":1,
			"attack":30,"attack_speed":0.7,"range":200.0,"target_priority":"nearest",
			"skill_name":"荆棘反弹","skill_desc":"反弹 25% 近战伤害","reflect_ratio":0.25,
		},
		"spore_flower": {
			"id":"spore_flower","name":"孢子花","faction":Faction.NATURE,"rarity":1,
			"attack":16,"attack_speed":1.8,"range":330.0,"target_priority":"nearest",
			"skill_name":"毒孢","skill_desc":"中毒 5 秒","poison_ratio":0.50,"poison_duration":5.0,
		},
		"vine_guardian": {
			"id":"vine_guardian","name":"藤蔓守护者","faction":Faction.NATURE,"rarity":2,
			"attack":10,"attack_speed":2.5,"range":280.0,"target_priority":"nearest",
			"skill_name":"缠绕","skill_desc":"20% 定身 1 秒","root_chance":0.20,"root_duration":1.0,
		},
		"elder_treant": {
			"id":"elder_treant","name":"古树长老","faction":Faction.NATURE,"rarity":3,
			"attack":20,"attack_speed":0.6,"range":350.0,"target_priority":"nearest",
			"skill_name":"生命之种","skill_desc":"每 10 秒召唤树苗","summon_cooldown":10.0,"summon_duration":8.0,"summon_id":"sapling",
		},
		"scrap_gambler": {
			"id":"scrap_gambler","name":"废品赌徒","faction":Faction.COMMERCE,"rarity":1,
			"attack":15,"attack_speed":2.0,"range":300.0,"target_priority":"nearest",
			"skill_name":"幸运一击","skill_desc":"25% 获得 3 金币","gold_chance":0.25,"gold_amount":3,
		},
		"mercenary_broker": {
			"id":"mercenary_broker","name":"雇佣中间人","faction":Faction.COMMERCE,"rarity":1,
			"attack":22,"attack_speed":1.0,"range":340.0,"target_priority":"elite_first",
			"skill_name":"加价","skill_desc":"精英/BOSS 伤害+50%","elite_bonus":0.50,
		},
		"stock_analyst": {
			"id":"stock_analyst","name":"股票分析师","faction":Faction.COMMERCE,"rarity":2,
			"attack":18,"attack_speed":1.5,"range":360.0,"target_priority":"lowest_health",
			"skill_name":"做空","skill_desc":"受伤+10% 可叠3层","vulnerable_ratio":0.10,"vulnerable_duration":3.0,"max_stacks":3,
		},
		"trade_prince": {
			"id":"trade_prince","name":"贸易亲王","faction":Faction.COMMERCE,"rarity":3,
			"attack":25,"attack_speed":1.2,"range":400.0,"target_priority":"nearest",
			"skill_name":"市场操纵","skill_desc":"每100金币+3%攻击","gold_to_attack":0.03,
		},
		"echo_walker": {
			"id":"echo_walker","name":"回声行者","faction":Faction.MEMORY,"rarity":1,
			"attack":20,"attack_speed":1.3,"range":340.0,"target_priority":"nearest",
			"skill_name":"残响","skill_desc":"30% 二次伤害判定","echo_ratio":0.30,"echo_delay":0.3,
		},
		"nostalgia_singer": {
			"id":"nostalgia_singer","name":"怀旧歌者","faction":Faction.MEMORY,"rarity":1,
			"attack":10,"attack_speed":2.0,"range":380.0,"target_priority":"nearest",
			"skill_name":"安眠曲","skill_desc":"敌攻速-15%","enemy_slow_ratio":0.15,"enemy_slow_duration":2.0,
		},
		"historian": {
			"id":"historian","name":"历史学家","faction":Faction.MEMORY,"rarity":2,
			"attack":22,"attack_speed":1.0,"range":400.0,"target_priority":"lowest_health",
			"skill_name":"经验汲取","skill_desc":"击杀后永久+1攻击","stacking_attack":1,
		},
		"archivist": {
			"id":"archivist","name":"大档案官","faction":Faction.MEMORY,"rarity":3,
			"attack":18,"attack_speed":1.5,"range":450.0,"target_priority":"elite_first",
			"skill_name":"知识洪流","skill_desc":"每杀5敌全队攻速+5%","kill_threshold":5,"team_speed_bonus":0.05,
		},
		"sapling": {
			"id":"sapling","name":"树苗","faction":Faction.NATURE,"rarity":0,
			"attack":8,"attack_speed":2.0,"range":220.0,"target_priority":"nearest",
			"skill_name":"","skill_desc":"临时召唤物",
		},
	}
	print("[GameData] 生物数据库初始化完成，共 %d 只" % creature_database.size())

func _init_module_database():
	module_database = {
		"reinforced_armor":{"id":"reinforced_armor","name":"强化装甲","faction":Faction.TECH,"rarity":1,"type":"defense","value":20,"desc":"城堡护盾 +20"},
		"energy_amplifier":{"id":"energy_amplifier","name":"能量增幅器","faction":Faction.TECH,"rarity":2,"type":"energy","value":0.5,"desc":"能量恢复速度 +0.5"},
		"prayer_altar":{"id":"prayer_altar","name":"祈祷祭坛","faction":Faction.FAITH,"rarity":1,"type":"regen","value":1.5,"desc":"城堡每秒恢复 1.5 护盾"},
		"holy_totem":{"id":"holy_totem","name":"圣图腾","faction":Faction.FAITH,"rarity":2,"type":"slot","value":1,"desc":"生物槽位 +1"},
		"thorn_armor":{"id":"thorn_armor","name":"荆棘装甲","faction":Faction.NATURE,"rarity":1,"type":"thorns","value":5,"desc":"城堡受击反弹 5 伤害"},
		"fertile_soil":{"id":"fertile_soil","name":"肥沃土壤","faction":Faction.NATURE,"rarity":2,"type":"nature_boost","value":0.15,"desc":"自然派系攻击 +15%"},
		"trade_license":{"id":"trade_license","name":"贸易执照","faction":Faction.COMMERCE,"rarity":1,"type":"gold_boost","value":0.20,"desc":"金币收益 +20%"},
		"black_market":{"id":"black_market","name":"黑市入口","faction":Faction.COMMERCE,"rarity":2,"type":"discount","value":0.15,"desc":"购买消耗 -15%"},
		"memory_shard":{"id":"memory_shard","name":"记忆碎片","faction":Faction.MEMORY,"rarity":1,"type":"xp_boost","value":0.25,"desc":"生物经验 +25%"},
		"time_dilator":{"id":"time_dilator","name":"时间膨胀器","faction":Faction.MEMORY,"rarity":2,"type":"slow_aura","value":0.10,"desc":"敌人移速 -10%"},
	}
	print("[GameData] 模块数据库初始化完成")

func _init_player_creatures():
	player_creatures = ["mech_sniper","spirit_wisp","thorn_beast","scrap_gambler","echo_walker"]
	print("[GameData] 玩家初始生物：", player_creatures)

func get_creature_data(id: String) -> Dictionary:
	return creature_database.get(id, {}).duplicate()

func get_faction_name(faction: int) -> String:
	return FACTION_NAMES.get(faction, "未知")

func get_faction_color(faction: int) -> Color:
	return FACTION_COLORS.get(faction, Color.GRAY)

func get_module_data(id: String) -> Dictionary:
	return module_database.get(id, {}).duplicate()

func has_creature(id: String) -> bool:
	return id in player_creatures

func add_creature(id: String):
	if id not in player_creatures and creature_database.has(id):
		player_creatures.append(id)
		EventBus.creature_acquired.emit(id)

func add_resource(type: String, amount: int):
	resources[type] = resources.get(type, 0) + amount
	EventBus.resource_changed.emit(type, resources[type])

func spend_resource(type: String, amount: int) -> bool:
	if resources.get(type, 0) >= amount:
		resources[type] -= amount
		EventBus.resource_changed.emit(type, resources[type])
		return true
	return false

func add_reputation(faction: int, amount: int):
	faction_reputation[faction] += amount
	EventBus.reputation_changed.emit(faction, faction_reputation[faction])

func unlock_node(node_id: String):
	if node_id not in world_progress["unlocked_nodes"]:
		world_progress["unlocked_nodes"].append(node_id)

func complete_node(node_id: String):
	if node_id not in world_progress["completed_nodes"]:
		world_progress["completed_nodes"].append(node_id)
	EventBus.node_completed.emit(node_id)
