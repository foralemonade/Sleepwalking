extends Node
## 梦游症 - 全局游戏数据管理 (Autoload) v0.4
## 管理生物数据库、道具数据库、玩家状态、生物健康状态、城堡模块、资源等
## v0.4 变更: 加生物 max_hp/position_type/role; 加道具数据库; 加生物健康追踪; 修复 xp_boost

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

enum PositionType {
	FRONT = 0,   # 前排 — 近战范围，承受更多伤害
	BACK = 1,    # 后排 — 远程范围，较少被攻击
	SIDE = 2,    # 侧翼 — 攻击角度扩展，可覆盖多条路线
	CORE = 3,    # 核心 — 保护城堡核心，特殊敌人必须经过此格
}

enum CreatureRole {
	DPS = 0,      # 输出型 — 高攻击力，低HP
	TANK = 1,     # 坦克型 — 高HP，低攻击力
	HEALER = 2,   # 治疗型 — 能为友方回血
	CONTROL = 3,  # 控制型 — 减速/眩晕/定身敌人
	BURST = 4,    # 爆发型 — 低频高伤，一击重创
	SUPPORT = 5,  # 辅助型 — 增益友方/削弱敌方
	SUMMONER = 6, # 召唤型 — 战斗中召唤临时单位
	ANTI_ELITE = 7, # 反精英型 — 对特殊敌人有额外伤害/拦截能力
}

enum InjuryStage {
	HEALTHY = 0,  # HP >= 75%
	LIGHT = 1,    # 50% <= HP < 75%
	SEVERE = 2,   # 25% <= HP < 50%
	DYING = 3,    # HP < 25%
	DEAD = 4,     # HP = 0
}

const FACTION_NAMES: Dictionary = {
	Faction.TECH: "秩序·技术",
	Faction.FAITH: "信仰·神秘",
	Faction.NATURE: "自然·野性",
	Faction.COMMERCE: "商业·混沌",
	Faction.MEMORY: "记忆·复古",
}

const FACTION_COLORS: Dictionary = {
	Faction.TECH: Color(0.55, 0.80, 0.95),
	Faction.FAITH: Color(0.95, 0.78, 0.82),
	Faction.NATURE: Color(0.68, 0.92, 0.82),
	Faction.COMMERCE: Color(0.95, 0.82, 0.72),
	Faction.MEMORY: Color(0.78, 0.65, 0.95),
}

const POSITION_NAMES: Dictionary = {
	PositionType.FRONT: "前排",
	PositionType.BACK: "后排",
	PositionType.SIDE: "侧翼",
	PositionType.CORE: "核心",
}

const ROLE_NAMES: Dictionary = {
	CreatureRole.DPS: "输出型",
	CreatureRole.TANK: "坦克型",
	CreatureRole.HEALER: "治疗型",
	CreatureRole.CONTROL: "控制型",
	CreatureRole.BURST: "爆发型",
	CreatureRole.SUPPORT: "辅助型",
	CreatureRole.SUMMONER: "召唤型",
	CreatureRole.ANTI_ELITE: "反精英型",
}

# ============================================================
# 数据库
# ============================================================
var creature_database: Dictionary = {}
var module_database: Dictionary = {}
var item_database: Dictionary = {}

# ============================================================
# 玩家状态
# ============================================================
var player_creatures: Array[String] = []
var player_equipped_modules: Array[String] = []
var player_inventory_modules: Array[String] = []

## 生物健康状态追踪 — 跨局继承
## key = creature_id, value = { "current_hp": float, "max_hp": float, "stage": InjuryStage, "is_dead": bool }
var creature_health: Dictionary = {}

var faction_reputation: Dictionary = {
	Faction.TECH: 0, Faction.FAITH: 0, Faction.NATURE: 0,
	Faction.COMMERCE: 0, Faction.MEMORY: 0,
}

var resources: Dictionary = {
	"gold": 200, "gems": 20, "energy_core": 0,
}

var world_progress: Dictionary = {
	"unlocked_nodes": [], "completed_nodes": [], "current_node": "start",
	"challenge_active": false, "challenge_score": 0,
	"challenge_high_score": 0, "challenge_wave": 0,
	"max_challenge_waves": 20,
	"battle_protection_count": 3,  # 新手保护: 前3局死亡自动复活
}

## 城堡配置 — v0.4 加 core_hp
var castle_modules: Dictionary = {
	"creature_slots": 4, "defense": 100, "energy_regen": 1.0,
	"resonance_bonus": 0.0, "core_hp": 200, "core_hp_max": 200,
}

var player_skills: Array[String] = ["energy_burst", "shield_overload", "healing_flow"]
var equipped_skills: Array[String] = ["energy_burst"]

## 治疗道具背包 — key=item_id, value=持有数量
var healing_items: Dictionary = {}

var settings: Dictionary = { "bgm_volume": 0.8, "sfx_volume": 1.0 }

# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	_init_creature_database()
	_init_module_database()
	_init_item_database()
	_init_player_creatures()
	_init_healing_items()
	print("[GameData] v0.4 游戏数据初始化完成")

func _init_creature_database() -> void:
	creature_database = {
		# ── TECH 派系 ──
		"mech_sniper": {
			"id":"mech_sniper","name":"机械狙击手","faction":Faction.TECH,"rarity":1,
			"role":CreatureRole.DPS,"position_type":PositionType.BACK,
			"max_hp":90.0,
			"attack":28,"attack_speed":1.2,"range":420.0,"target_priority":"lowest_health",
			"skill_name":"精准锁定","skill_desc":"攻击 15% 概率造成双倍伤害",
			"skill_chance":0.15,"skill_multiplier":2.0,
		},
		"steel_hound": {
			"id":"steel_hound","name":"钢牙猎犬","faction":Faction.TECH,"rarity":1,
			"role":CreatureRole.TANK,"position_type":PositionType.FRONT,
			"max_hp":160.0,
			"attack":18,"attack_speed":2.2,"range":260.0,"target_priority":"nearest",
			"skill_name":"撕咬","skill_desc":"对护盾敌人额外造成 40% 伤害","anti_shield_bonus":0.40,
		},
		"tesla_core": {
			"id":"tesla_core","name":"特斯拉核心","faction":Faction.TECH,"rarity":2,
			"role":CreatureRole.SUPPORT,"position_type":PositionType.SIDE,
			"max_hp":100.0,
			"attack":16,"attack_speed":3.0,"range":320.0,"target_priority":"nearest",
			"skill_name":"连锁闪电","skill_desc":"攻击弹射至 2 个额外目标","chain_targets":2,"chain_decay":0.3,
		},
		"war_mech": {
			"id":"war_mech","name":"战争机甲","faction":Faction.TECH,"rarity":3,
			"role":CreatureRole.ANTI_ELITE,"position_type":PositionType.CORE,
			"max_hp":130.0,
			"attack":35,"attack_speed":0.7,"range":380.0,"target_priority":"elite_first",
			"skill_name":"导弹轰炸","skill_desc":"每 8 秒对范围内敌人造成 80% 伤害，对特殊敌人额外+50%",
			"aoe_cooldown":8.0,"aoe_ratio":0.8,"aoe_range":200.0,"elite_bonus":0.50,
		},
		# ── FAITH 派系 ──
		"spirit_wisp": {
			"id":"spirit_wisp","name":"灵魂萤火","faction":Faction.FAITH,"rarity":1,
			"role":CreatureRole.HEALER,"position_type":PositionType.BACK,
			"max_hp":85.0,
			"attack":12,"attack_speed":1.5,"range":350.0,"target_priority":"nearest",
			"skill_name":"灵魂灼烧","skill_desc":"攻击附带灼烧，同时为最近受伤友方恢复 HP",
			"burn_ratio":0.20,"burn_duration":3.0,
			"heal_amount":8.0,"heal_range":300.0,
		},
		"ritual_bell": {
			"id":"ritual_bell","name":"祭祀铃","faction":Faction.FAITH,"rarity":1,
			"role":CreatureRole.CONTROL,"position_type":PositionType.SIDE,
			"max_hp":80.0,
			"attack":12,"attack_speed":1.0,"range":500.0,"target_priority":"elite_first",
			"skill_name":"镇魂","skill_desc":"攻击减速敌人 25%","slow_factor":0.75,"slow_duration":1.5,
		},
		"phantom_priest": {
			"id":"phantom_priest","name":"幻影祭司","faction":Faction.FAITH,"rarity":2,
			"role":CreatureRole.DPS,"position_type":PositionType.BACK,
			"max_hp":75.0,
			"attack":24,"attack_speed":0.8,"range":380.0,"target_priority":"lowest_health",
			"skill_name":"献祭","skill_desc":"击杀敌人恢复城堡 5 护盾","heal_on_kill":5,
		},
		"divine_guard": {
			"id":"divine_guard","name":"圣盾守卫","faction":Faction.FAITH,"rarity":3,
			"role":CreatureRole.TANK,"position_type":PositionType.FRONT,
			"max_hp":180.0,
			"attack":14,"attack_speed":1.3,"range":300.0,"target_priority":"nearest",
			"skill_name":"庇护光环","skill_desc":"城堡护盾上限+30，附近友方防御+10%",
			"castle_shield_bonus":30,"ally_defense_bonus":0.10,
		},
		# ── NATURE 派系 ──
		"thorn_beast": {
			"id":"thorn_beast","name":"荆棘兽","faction":Faction.NATURE,"rarity":1,
			"role":CreatureRole.TANK,"position_type":PositionType.FRONT,
			"max_hp":170.0,
			"attack":30,"attack_speed":0.7,"range":200.0,"target_priority":"nearest",
			"skill_name":"荆棘反弹","skill_desc":"反弹 25% 近战伤害","reflect_ratio":0.25,
		},
		"spore_flower": {
			"id":"spore_flower","name":"孢子花","faction":Faction.NATURE,"rarity":1,
			"role":CreatureRole.CONTROL,"position_type":PositionType.SIDE,
			"max_hp":70.0,
			"attack":16,"attack_speed":1.8,"range":330.0,"target_priority":"nearest",
			"skill_name":"毒孢","skill_desc":"中毒 5 秒","poison_ratio":0.50,"poison_duration":5.0,
		},
		"vine_guardian": {
			"id":"vine_guardian","name":"藤蔓守护者","faction":Faction.NATURE,"rarity":2,
			"role":CreatureRole.CONTROL,"position_type":PositionType.SIDE,
			"max_hp":95.0,
			"attack":10,"attack_speed":2.5,"range":280.0,"target_priority":"nearest",
			"skill_name":"缠绕","skill_desc":"20% 定身 1 秒","root_chance":0.20,"root_duration":1.0,
		},
		"elder_treant": {
			"id":"elder_treant","name":"古树长老","faction":Faction.NATURE,"rarity":3,
			"role":CreatureRole.SUMMONER,"position_type":PositionType.BACK,
			"max_hp":120.0,
			"attack":20,"attack_speed":0.6,"range":350.0,"target_priority":"nearest",
			"skill_name":"生命之种","skill_desc":"每 10 秒召唤树苗","summon_cooldown":10.0,"summon_duration":8.0,"summon_id":"sapling",
		},
		# ── COMMERCE 派系 ──
		"scrap_gambler": {
			"id":"scrap_gambler","name":"废品赌徒","faction":Faction.COMMERCE,"rarity":1,
			"role":CreatureRole.SUPPORT,"position_type":PositionType.SIDE,
			"max_hp":85.0,
			"attack":15,"attack_speed":2.0,"range":300.0,"target_priority":"nearest",
			"skill_name":"幸运一击","skill_desc":"25% 获得 3 金币","gold_chance":0.25,"gold_amount":3,
		},
		"mercenary_broker": {
			"id":"mercenary_broker","name":"雇佣中间人","faction":Faction.COMMERCE,"rarity":1,
			"role":CreatureRole.BURST,"position_type":PositionType.CORE,
			"max_hp":65.0,
			"attack":22,"attack_speed":1.0,"range":340.0,"target_priority":"elite_first",
			"skill_name":"加价","skill_desc":"精英/BOSS 伤害+50%","elite_bonus":0.50,
		},
		"stock_analyst": {
			"id":"stock_analyst","name":"股票分析师","faction":Faction.COMMERCE,"rarity":2,
			"role":CreatureRole.SUPPORT,"position_type":PositionType.SIDE,
			"max_hp":90.0,
			"attack":18,"attack_speed":1.5,"range":360.0,"target_priority":"lowest_health",
			"skill_name":"做空","skill_desc":"受伤+10% 可叠3层","vulnerable_ratio":0.10,"vulnerable_duration":3.0,"max_stacks":3,
		},
		"trade_prince": {
			"id":"trade_prince","name":"贸易亲王","faction":Faction.COMMERCE,"rarity":3,
			"role":CreatureRole.DPS,"position_type":PositionType.BACK,
			"max_hp":80.0,
			"attack":25,"attack_speed":1.2,"range":400.0,"target_priority":"nearest",
			"skill_name":"市场操纵","skill_desc":"每100金币+3%攻击","gold_to_attack":0.03,
		},
		# ── MEMORY 派系 ──
		"echo_walker": {
			"id":"echo_walker","name":"回声行者","faction":Faction.MEMORY,"rarity":1,
			"role":CreatureRole.BURST,"position_type":PositionType.CORE,
			"max_hp":60.0,
			"attack":20,"attack_speed":1.3,"range":340.0,"target_priority":"nearest",
			"skill_name":"残响","skill_desc":"30% 二次伤害判定","echo_ratio":0.30,"echo_delay":0.3,
		},
		"nostalgia_singer": {
			"id":"nostalgia_singer","name":"怀旧歌者","faction":Faction.MEMORY,"rarity":1,
			"role":CreatureRole.SUPPORT,"position_type":PositionType.SIDE,
			"max_hp":100.0,
			"attack":10,"attack_speed":2.0,"range":380.0,"target_priority":"nearest",
			"skill_name":"安眠曲","skill_desc":"敌攻速-15%","enemy_slow_ratio":0.15,"enemy_slow_duration":2.0,
		},
		"historian": {
			"id":"historian","name":"历史学家","faction":Faction.MEMORY,"rarity":2,
			"role":CreatureRole.DPS,"position_type":PositionType.BACK,
			"max_hp":85.0,
			"attack":22,"attack_speed":1.0,"range":400.0,"target_priority":"lowest_health",
			"skill_name":"经验汲取","skill_desc":"击杀后永久+1攻击","stacking_attack":1,
		},
		"archivist": {
			"id":"archivist","name":"大档案官","faction":Faction.MEMORY,"rarity":3,
			"role":CreatureRole.SUPPORT,"position_type":PositionType.SIDE,
			"max_hp":105.0,
			"attack":18,"attack_speed":1.5,"range":450.0,"target_priority":"elite_first",
			"skill_name":"知识洪流","skill_desc":"每杀5敌全队攻速+5%","kill_threshold":5,"team_speed_bonus":0.05,
		},
		# ── 召唤物 ──
		"sapling": {
			"id":"sapling","name":"树苗","faction":Faction.NATURE,"rarity":0,
			"role":CreatureRole.DPS,"position_type":PositionType.FRONT,
			"max_hp":40.0,
			"attack":8,"attack_speed":2.0,"range":220.0,"target_priority":"nearest",
			"skill_name":"","skill_desc":"临时召唤物",
		},
	}
	print("[GameData] 生物数据库初始化完成，共 %d 只" % creature_database.size())

func _init_module_database() -> void:
	module_database = {
		"reinforced_armor":{"id":"reinforced_armor","name":"强化装甲","faction":Faction.TECH,"rarity":1,"type":"defense","value":20,"desc":"城堡护盾 +20"},
		"energy_amplifier":{"id":"energy_amplifier","name":"能量增幅器","faction":Faction.TECH,"rarity":2,"type":"energy","value":0.5,"desc":"能量恢复速度 +0.5"},
		"prayer_altar":{"id":"prayer_altar","name":"祈祷祭坛","faction":Faction.FAITH,"rarity":1,"type":"regen","value":1.5,"desc":"城堡每秒恢复 1.5 护盾"},
		"holy_totem":{"id":"holy_totem","name":"圣图腾","faction":Faction.FAITH,"rarity":2,"type":"slot","value":1,"desc":"站位格 +1"},
		"thorn_armor":{"id":"thorn_armor","name":"荆棘装甲","faction":Faction.NATURE,"rarity":1,"type":"thorns","value":5,"desc":"城堡受击反弹 5 伤害"},
		"fertile_soil":{"id":"fertile_soil","name":"肥沃土壤","faction":Faction.NATURE,"rarity":2,"type":"nature_boost","value":0.15,"desc":"自然派系攻击 +15%"},
		"trade_license":{"id":"trade_license","name":"贸易执照","faction":Faction.COMMERCE,"rarity":1,"type":"gold_boost","value":0.20,"desc":"金币收益 +20%"},
		"black_market":{"id":"black_market","name":"黑市入口","faction":Faction.COMMERCE,"rarity":2,"type":"discount","value":0.15,"desc":"购买消耗 -15%"},
		# 修复: xp_boost → behavior型 (记忆强化: 首次攻击附带眩晕)
		"memory_shard":{"id":"memory_shard","name":"记忆碎片","faction":Faction.MEMORY,"rarity":1,"type":"first_attack_stun","value":0.5,"desc":"生物首次攻击眩晕敌人 0.5 秒"},
		"time_dilator":{"id":"time_dilator","name":"时间膨胀器","faction":Faction.MEMORY,"rarity":2,"type":"slow_aura","value":0.10,"desc":"敌人移速 -10%"},
	}
	print("[GameData] 模块数据库初始化完成")

func _init_item_database() -> void:
	## 治疗道具 + 复活道具
	item_database = {
		"basic_heal_pack": {
			"id":"basic_heal_pack","name":"基础治疗包","type":"heal_light",
			"heal_amount":0.30,  # 恢复 30% max_hp
			"cost_gold":30,"desc":"恢复生物 30% HP，治疗轻伤",
		},
		"advanced_heal_pack": {
			"id":"advanced_heal_pack","name":"高级治疗包","type":"heal_severe",
			"heal_amount":0.60,  # 恢复 60% max_hp
			"cost_gold":80,"desc":"恢复生物 60% HP，治疗重伤",
		},
		"emergency_heal": {
			"id":"emergency_heal","name":"紧急救治","type":"heal_dying",
			"heal_amount":0.50,
			"cost_gold":100,"cost_item":"basic_heal_pack","item_count":1,
			"desc":"恢复濒死生物 50% HP",
		},
		"soul_fragment": {
			"id":"soul_fragment","name":"灵魂碎片","type":"resurrection_material",
			"desc":"复活仪式所需稀有道具，高难度关卡掉落",
		},
		"resurrection_crystal": {
			"id":"resurrection_crystal","name":"复活晶石","type":"resurrection_material",
			"desc":"复活仪式所需稀有道具，混战大陆产出",
		},
	}
	print("[GameData] 道具数据库初始化完成")

func _init_player_creatures() -> void:
	player_creatures = ["mech_sniper","spirit_wisp","thorn_beast","scrap_gambler","echo_walker"]
	# 初始化所有生物的健康状态为满HP
	for cid: String in player_creatures:
		_init_creature_health(cid)
	print("[GameData] 玩家初始生物：", player_creatures)

func _init_healing_items() -> void:
	## 初始给玩家几个基础治疗包
	healing_items = {
		"basic_heal_pack": 3,
		"advanced_heal_pack": 1,
		"emergency_heal": 0,
		"soul_fragment": 0,
		"resurrection_crystal": 0,
	}

func _init_creature_health(cid: String) -> void:
	var data: Dictionary = creature_database.get(cid, {})
	if data.is_empty():
		return
	var max_hp: float = data.get("max_hp", 100.0)
	creature_health[cid] = {
		"current_hp": max_hp,
		"max_hp": max_hp,
		"stage": InjuryStage.HEALTHY,
		"is_dead": false,
	}

# ============================================================
# 数据查询
# ============================================================
func get_creature_data(id: String) -> Dictionary:
	return creature_database.get(id, {}).duplicate()

func get_faction_name(faction: int) -> String:
	return FACTION_NAMES.get(faction, "未知")

func get_faction_color(faction: int) -> Color:
	return FACTION_COLORS.get(faction, Color.GRAY)

func get_position_name(pt: int) -> String:
	return POSITION_NAMES.get(pt, "未知")

func get_role_name(role: int) -> String:
	return ROLE_NAMES.get(role, "未知")

func get_module_data(id: String) -> Dictionary:
	return module_database.get(id, {}).duplicate()

func get_item_data(id: String) -> Dictionary:
	return item_database.get(id, {}).duplicate()

func has_creature(id: String) -> bool:
	return id in player_creatures

# ============================================================
# 生物健康管理
# ============================================================
func get_creature_hp(cid: String) -> float:
	if not creature_health.has(cid):
		return 0.0
	return creature_health[cid]["current_hp"]

func get_creature_max_hp(cid: String) -> float:
	if not creature_health.has(cid):
		var data: Dictionary = creature_database.get(cid, {})
		return data.get("max_hp", 100.0)
	return creature_health[cid]["max_hp"]

func get_creature_injury_stage(cid: String) -> int:
	if not creature_health.has(cid):
		return InjuryStage.HEALTHY
	return creature_health[cid]["stage"]

func is_creature_dead(cid: String) -> bool:
	if not creature_health.has(cid):
		return false
	return creature_health[cid]["is_dead"]

## 更新生物受伤阶段 — 基于当前 HP 比例
func update_injury_stage(cid: String) -> void:
	if not creature_health.has(cid):
		return
	var hp: float = creature_health[cid]["current_hp"]
	var max_hp: float = creature_health[cid]["max_hp"]
	var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0

	if hp <= 0.0:
		creature_health[cid]["stage"] = InjuryStage.DEAD
		creature_health[cid]["is_dead"] = true
		creature_health[cid]["current_hp"] = 0.0
	elif ratio < 0.25:
		creature_health[cid]["stage"] = InjuryStage.DYING
	elif ratio < 0.50:
		creature_health[cid]["stage"] = InjuryStage.SEVERE
	elif ratio < 0.75:
		creature_health[cid]["stage"] = InjuryStage.LIGHT
	else:
		creature_health[cid]["stage"] = InjuryStage.HEALTHY
	creature_health[cid]["is_dead"] = (creature_health[cid]["stage"] == InjuryStage.DEAD)

## 生物受伤 — 战斗中调用
func creature_take_damage(cid: String, amount: float) -> void:
	if not creature_health.has(cid):
		return
	if creature_health[cid]["is_dead"]:
		return
	creature_health[cid]["current_hp"] = maxf(0.0, creature_health[cid]["current_hp"] - amount)
	update_injury_stage(cid)

## 生物回血 — 战斗中/战外治疗调用
func creature_heal(cid: String, amount: float) -> void:
	if not creature_health.has(cid):
		return
	if creature_health[cid]["is_dead"]:
		return
	var max_hp: float = creature_health[cid]["max_hp"]
	creature_health[cid]["current_hp"] = minf(max_hp, creature_health[cid]["current_hp"] + amount)
	update_injury_stage(cid)

## 战斗中生物死亡 — 站位空出
func creature_die_in_battle(cid: String) -> void:
	if not creature_health.has(cid):
		return
	creature_health[cid]["current_hp"] = 0.0
	creature_health[cid]["stage"] = InjuryStage.DEAD
	creature_health[cid]["is_dead"] = true
	EventBus.creature_died_in_battle.emit(cid)

## 新手保护期: 前3局死亡后自动复活 (HP恢复50%)
func check_newbie_protection(cid: String) -> bool:
	var protection_left: int = world_progress.get("battle_protection_count", 3)
	if protection_left > 0 and is_creature_dead(cid):
		creature_health[cid]["current_hp"] = creature_health[cid]["max_hp"] * 0.5
		creature_health[cid]["stage"] = InjuryStage.SEVERE
		creature_health[cid]["is_dead"] = false
		world_progress["battle_protection_count"] = protection_left - 1
		print("[GameData] 新手保护: %s 自动复活 (剩余保护次数: %d)" % [cid, protection_left - 1])
		return true
	return false

## 战后处理 — 轻伤自恢复
func post_battle_recovery() -> void:
	for cid: String in player_creatures:
		if not creature_health.has(cid):
			continue
		if creature_health[cid]["is_dead"]:
			continue
		# 轻伤自动恢复到满HP
		if creature_health[cid]["stage"] == InjuryStage.LIGHT:
			creature_health[cid]["current_hp"] = creature_health[cid]["max_hp"]
			creature_health[cid]["stage"] = InjuryStage.HEALTHY

## 复活仪式 — 金币+稀有道具
func resurrect_creature(cid: String) -> bool:
	if not creature_health.has(cid):
		return false
	if not creature_health[cid]["is_dead"]:
		return false
	var gold_cost: int = 500
	var fragment_cost: int = 3
	if resources["gold"] < gold_cost:
		return false
	if healing_items.get("soul_fragment", 0) < fragment_cost:
		return false
	spend_resource("gold", gold_cost)
	healing_items["soul_fragment"] = healing_items.get("soul_fragment", 0) - fragment_cost
	creature_health[cid]["current_hp"] = creature_health[cid]["max_hp"]
	creature_health[cid]["stage"] = InjuryStage.HEALTHY
	creature_health[cid]["is_dead"] = false
	EventBus.creature_resurrected.emit(cid)
	print("[GameData] 复活仪式完成: %s" % cid)
	return true

## 使用治疗道具
func use_heal_item(item_id: String, target_cid: String) -> bool:
	if not healing_items.has(item_id) or healing_items[item_id] <= 0:
		return false
	if is_creature_dead(target_cid):
		return false
	var item_data: Dictionary = get_item_data(item_id)
	if item_data.is_empty():
		return false
	var heal_type: String = item_data.get("type", "")
	var stage: int = get_creature_injury_stage(target_cid)
	# 验证道具适用阶段
	if heal_type == "heal_light" and stage > InjuryStage.LIGHT:
		# 基础治疗包只能治轻伤
		return false
	if heal_type == "heal_severe" and stage > InjuryStage.SEVERE:
		# 高级治疗包只能治重伤
		return false
	healing_items[item_id] -= 1
	var heal_amount: float = creature_health[target_cid]["max_hp"] * item_data.get("heal_amount", 0.3)
	creature_heal(target_cid, heal_amount)
	EventBus.heal_item_used.emit(item_id, target_cid)
	return true

# ============================================================
# 玩家操作
# ============================================================
func add_creature(id: String) -> void:
	if id not in player_creatures and creature_database.has(id):
		player_creatures.append(id)
		_init_creature_health(id)
		EventBus.creature_acquired.emit(id)

func add_resource(type: String, amount: int) -> void:
	resources[type] = resources.get(type, 0) + amount
	EventBus.resource_changed.emit(type, resources[type])

func spend_resource(type: String, amount: int) -> bool:
	if resources.get(type, 0) >= amount:
		resources[type] -= amount
		EventBus.resource_changed.emit(type, resources[type])
		return true
	return false

func add_reputation(faction: int, amount: int) -> void:
	faction_reputation[faction] += amount
	EventBus.reputation_changed.emit(faction, faction_reputation[faction])

func unlock_node(node_id: String) -> void:
	if node_id not in world_progress["unlocked_nodes"]:
		world_progress["unlocked_nodes"].append(node_id)

func complete_node(node_id: String) -> void:
	if node_id not in world_progress["completed_nodes"]:
		world_progress["completed_nodes"].append(node_id)
	EventBus.node_completed.emit(node_id)

## 获取可用生物列表（排除已死亡）
func get_available_creatures() -> Array[String]:
	var available: Array[String] = []
	for cid: String in player_creatures:
		if not is_creature_dead(cid):
			available.append(cid)
	return available
