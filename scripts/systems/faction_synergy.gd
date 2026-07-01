extends Node
## 梦游症 - 派系搭配效果计算引擎
## 同派系协同 + 全 10 组跨派系反应

const SYNERGY_THRESHOLDS = {
	2: {"attack_bonus": 0.15},
	3: {"attack_bonus": 0.25},
	4: {"attack_bonus": 0.40},
}

# 跨派系反应完整表（5 派系任意两两组合 = 10 组）
const CROSS_REACTIONS = {
	"nature_tech":     {"name":"生化异变","desc":"攻击附带持续伤害 3 秒","dot_ratio":0.15,"dot_duration":3.0},
	"tech_nature":     {"name":"生化异变","desc":"攻击附带持续伤害 3 秒","dot_ratio":0.15,"dot_duration":3.0},
	"faith_memory":    {"name":"回响","desc":"生物死亡后复活战斗 2 秒","revive_duration":2.0},
	"memory_faith":    {"name":"回响","desc":"生物死亡后复活战斗 2 秒","revive_duration":2.0},
	"tech_commerce":   {"name":"军火交易","desc":"所有生物攻速 +20%","speed_bonus":0.20},
	"commerce_tech":   {"name":"军火交易","desc":"所有生物攻速 +20%","speed_bonus":0.20},
	"nature_faith":    {"name":"神圣花园","desc":"城堡每秒恢复 1.5 护盾","castle_regen":1.5},
	"faith_nature":    {"name":"神圣花园","desc":"城堡每秒恢复 1.5 护盾","castle_regen":1.5},
	"tech_memory":     {"name":"数字幽灵","desc":"攻击 10% 概率眩晕敌人 0.5 秒","stun_chance":0.10,"stun_duration":0.5},
	"memory_tech":     {"name":"数字幽灵","desc":"攻击 10% 概率眩晕敌人 0.5 秒","stun_chance":0.10,"stun_duration":0.5},
	"commerce_memory": {"name":"古董交易","desc":"击杀敌人额外获得 5 金币","gold_per_kill":5},
	"memory_commerce": {"name":"古董交易","desc":"击杀敌人额外获得 5 金币","gold_per_kill":5},
	"nature_commerce": {"name":"资源掠夺","desc":"所有生物攻击力 +10%，城堡护盾 -20","trade_attack":0.10,"trade_shield_penalty":20},
	"commerce_nature": {"name":"资源掠夺","desc":"所有生物攻击力 +10%，城堡护盾 -20","trade_attack":0.10,"trade_shield_penalty":20},
	"tech_faith":      {"name":"圣装机兵","desc":"技术派系生物 +15% 攻击，信仰派系生物 +15% 攻速","tech_atk":0.15,"faith_spd":0.15},
	"faith_tech":      {"name":"圣装机兵","desc":"技术派系生物 +15% 攻击，信仰派系生物 +15% 攻速","tech_atk":0.15,"faith_spd":0.15},
	"nature_memory":   {"name":"远古记忆","desc":"全队攻击范围 +15%","range_bonus":0.15},
	"memory_nature":   {"name":"远古记忆","desc":"全队攻击范围 +15%","range_bonus":0.15},
}

var _faction_tag = {
	GameData.Faction.TECH: "tech",
	GameData.Faction.FAITH: "faith",
	GameData.Faction.NATURE: "nature",
	GameData.Faction.COMMERCE: "commerce",
	GameData.Faction.MEMORY: "memory",
}

func analyze_synergies(creature_ids: Array[String]) -> Dictionary:
	var result = {
		"faction_synergy": {},
		"cross_reactions": [],
		"global_attack_bonus": 0.0,
		"global_speed_bonus": 0.0,
		"global_range_bonus": 0.0,
		"dot_effects": [],
		"castle_regen": 0.0,
		"revive_enabled": false,
		"revive_duration": 0.0,
		"stun_chance": 0.0,
		"stun_duration": 0.0,
		"gold_per_kill": 0,
		"trade_attack_bonus": 0.0,
		"trade_shield_penalty": 0,
		"tech_attack_bonus": 0.0,
		"faith_speed_bonus": 0.0,
	}

	if creature_ids.is_empty():
		return result

	var faction_counts = {}
	var present_factions = []

	for id in creature_ids:
		var data = GameData.get_creature_data(id)
		if data.is_empty(): continue
		var f = data["faction"]
		faction_counts[f] = faction_counts.get(f, 0) + 1

	for f in faction_counts:
		present_factions.append(f)

	# 同派系协同
	for f in faction_counts:
		var cnt = faction_counts[f]
		if cnt >= 2:
			var lv = mini(cnt, 4)
			if SYNERGY_THRESHOLDS.has(lv):
				var bonus = SYNERGY_THRESHOLDS[lv].duplicate()
				result["faction_synergy"][f] = {"level":lv,"count":cnt,"bonus":bonus}
				result["global_attack_bonus"] = max(result["global_attack_bonus"], bonus.get("attack_bonus",0.0))

	# 跨派系反应
	var tags = []
	for f in present_factions:
		if _faction_tag.has(f): tags.append(_faction_tag[f])

	for i in range(tags.size()):
		for j in range(tags.size()):
			if i == j: continue
			var key = tags[i] + "_" + tags[j]
			if CROSS_REACTIONS.has(key):
				var r = CROSS_REACTIONS[key].duplicate()
				var already_added = false
				for existing in result["cross_reactions"]:
					if existing["name"] == r["name"]:
						already_added = true
						break
				if not already_added:
					result["cross_reactions"].append(r)
					if r.has("speed_bonus"): result["global_speed_bonus"] += r["speed_bonus"]
					if r.has("dot_ratio"): result["dot_effects"].append({"ratio":r["dot_ratio"],"duration":r["dot_duration"]})
					if r.has("castle_regen"): result["castle_regen"] += r["castle_regen"]
					if r.has("revive_duration"):
						result["revive_enabled"] = true
						result["revive_duration"] = max(result["revive_duration"], r["revive_duration"])
					if r.has("stun_chance"): result["stun_chance"] += r["stun_chance"]
					if r.has("stun_duration"): result["stun_duration"] = max(result["stun_duration"], r["stun_duration"])
					if r.has("gold_per_kill"): result["gold_per_kill"] += r["gold_per_kill"]
					if r.has("trade_attack"): result["trade_attack_bonus"] += r["trade_attack"]
					if r.has("trade_shield_penalty"): result["trade_shield_penalty"] += r["trade_shield_penalty"]
					if r.has("tech_atk"): result["tech_attack_bonus"] += r["tech_atk"]
					if r.has("faith_spd"): result["faith_speed_bonus"] += r["faith_spd"]
					if r.has("range_bonus"): result["global_range_bonus"] += r["range_bonus"]

	return result
