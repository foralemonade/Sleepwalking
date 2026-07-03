extends Node
class_name RewardTable
## 关卡奖励表 — 每个节点首通固定奖励 + 重复通关奖励
## 企划书 10.2: 确定性奖励 + 同名生物第二只逻辑
## 方法均为 static — 通过 RewardTable.grant_reward(...) 直接调用,无需实例化

# 每个节点的首通奖励: { node_id: { "creature": cid, "gold": int, "items": {item_id: count}, "rep": {faction: amount} } }
const FIRST_CLEAR_REWARDS: Dictionary = {
	"start":     {"creature":"echo_walker",      "gold":100, "items":{"basic_heal_pack":2},       "rep":{}},
	"tech_01":   {"creature":"mech_sniper",      "gold":80,  "items":{},                         "rep":{1:20}},
	"tech_02":   {"creature":"steel_hound",      "gold":120, "items":{"basic_heal_pack":1},       "rep":{1:30}},
	"tech_03":   {"creature":"tesla_core",       "gold":250, "items":{"advanced_heal_pack":1},    "rep":{1:60}},
	"faith_01":  {"creature":"spirit_wisp",      "gold":80,  "items":{},                         "rep":{2:20}},
	"faith_02":  {"creature":"ritual_bell",      "gold":120, "items":{},                         "rep":{2:30}},
	"faith_03":  {"creature":"phantom_priest",   "gold":250, "items":{"soul_fragment":1},         "rep":{2:60}},
	"nature_01": {"creature":"thorn_beast",      "gold":80,  "items":{},                         "rep":{3:20}},
	"nature_02": {"creature":"spore_flower",     "gold":120, "items":{},                         "rep":{3:30}},
	"nature_03": {"creature":"vine_guardian",    "gold":250, "items":{"soul_fragment":1},         "rep":{3:60}},
	"commerce_01":{"creature":"scrap_gambler",   "gold":80,  "items":{},                         "rep":{4:20}},
	"commerce_02":{"creature":"mercenary_broker","gold":120, "items":{},                         "rep":{4:30}},
	"commerce_03":{"creature":"stock_analyst",   "gold":250, "items":{"soul_fragment":1},         "rep":{4:60}},
	"memory_01": {"creature":"echo_walker",      "gold":80,  "items":{},                         "rep":{5:20}},
	"memory_02": {"creature":"nostalgia_singer", "gold":120, "items":{},                         "rep":{5:30}},
	"memory_03": {"creature":"historian",       "gold":250, "items":{"soul_fragment":1},         "rep":{5:60}},
	"center_01": {"creature":"trade_prince",     "gold":400, "items":{"advanced_heal_pack":1,"soul_fragment":1}, "rep":{}},
	"center_02": {"creature":"divine_guard",     "gold":800, "items":{"advanced_heal_pack":3,"soul_fragment":3,"resurrection_crystal":1}, "rep":{}},
}

# 重复通关奖励: 金币(基于首通 gold 的 30%) + 50% 概率再给一只同名生物
const REPEAT_GOLD_RATIO: float = 0.30
const REPEAT_DUPLICATE_CHANCE: float = 0.50

## 发放关卡奖励 — 返回 { "creature_added": cid_or_empty, "gold": int, "items": Dictionary, "is_first_clear": bool }
## 给节点发奖 — 静态方法,直接 RewardTable.grant_reward("tech_01") 调用
static func grant_reward(node_id: String) -> Dictionary:
	if not FIRST_CLEAR_REWARDS.has(node_id):
		return {"creature_added":"", "gold":0, "items":{}, "is_first_clear":false}
	var reward: Dictionary = FIRST_CLEAR_REWARDS[node_id]
	var is_first: bool = not GameData.world_progress["completed_nodes"].has(node_id)

	var result: Dictionary = {
		"creature_added": "",
		"gold": 0,
		"items": {},
		"is_first_clear": is_first,
	}

	if is_first:
		# 首通: 完整奖励
		_grant_first_clear(reward, result)
	else:
		# 重复通关: 30% 金币 + 50% 概率同名生物
		_grant_repeat_clear(reward, result)

	return result

static func _grant_first_clear(reward: Dictionary, result: Dictionary) -> void:
	# 1) 生物(永远给)
	var cid: String = reward.get("creature", "")
	if cid != "" and GameData.creature_database.has(cid):
		# 同名第二只 — add_creature_now 支持重复添加
		GameData.add_creature_duplicate(cid)
		result["creature_added"] = cid

	# 2) 金币
	var gold: int = reward.get("gold", 0)
	if gold > 0:
		GameData.add_resource("gold", gold)
		result["gold"] = gold

	# 3) 道具
	var items: Dictionary = reward.get("items", {})
	for item_id: String in items:
		var count: int = items[item_id]
		GameData.healing_items[item_id] = GameData.healing_items.get(item_id, 0) + count
	result["items"] = items.duplicate()

	# 4) 派系声誉
	var rep: Dictionary = reward.get("rep", {})
	for faction: int in rep:
		GameData.add_reputation(faction, rep[faction])

	print("[Reward] 首通奖励: %s, 生物: %s, 金币: %d, 道具: %s" % [
		"yes", result["creature_added"], result["gold"], str(result["items"])
	])

static func _grant_repeat_clear(reward: Dictionary, result: Dictionary) -> void:
	# 30% 金币
	var base_gold: int = reward.get("gold", 0)
	var gold: int = int(base_gold * REPEAT_GOLD_RATIO)
	if gold > 0:
		GameData.add_resource("gold", gold)
		result["gold"] = gold

	# 50% 概率同名生物
	var cid: String = reward.get("creature", "")
	if cid != "" and randf() < REPEAT_DUPLICATE_CHANCE:
		GameData.add_creature_duplicate(cid)
		result["creature_added"] = cid

	print("[Reward] 重复通关奖励: 金币 %d, 生物(随机): %s" % [
		gold, result["creature_added"] if result["creature_added"] != "" else "无"
	])

## 获取节点的奖励预览(UI显示)
static func get_reward_preview(node_id: String) -> Dictionary:
	if not FIRST_CLEAR_REWARDS.has(node_id):
		return {}
	var reward: Dictionary = FIRST_CLEAR_REWARDS[node_id]
	return {
		"creature": reward.get("creature", ""),
		"gold": reward.get("gold", 0),
		"items": reward.get("items", {}),
		"rep": reward.get("rep", {}),
	}
