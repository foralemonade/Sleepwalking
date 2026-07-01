extends Node
class_name WorldMapManager
## 大地图探索系统 (Autoload)
## 管理所有世界节点和大陆数据

var node_database: Dictionary = {}

func _ready():
	_init_node_database()

func _init_node_database():
	node_database = {
		"start": {
			"id": "start", "name": "废墟起点", "continent": "neutral",
			"type": "story", "x": 640, "y": 600,
			"unlocks": ["tech_01", "nature_01"], "completed": true,
		},
		"tech_01": {"id": "tech_01", "name": "铁锈前哨", "continent": "tech", "type": "battle", "x": 300, "y": 440, "unlocks": ["tech_02"], "wave_count": 4},
		"tech_02": {"id": "tech_02", "name": "残骸工厂", "continent": "tech", "type": "battle", "x": 240, "y": 340, "unlocks": ["tech_03"], "wave_count": 5},
		"tech_03": {"id": "tech_03", "name": "核心反应堆", "continent": "tech", "type": "boss", "x": 200, "y": 240, "unlocks": ["center_01"], "wave_count": 6, "is_boss": true},

		"faith_01": {"id": "faith_01", "name": "焦土神殿", "continent": "faith", "type": "battle", "x": 500, "y": 360, "unlocks": ["faith_02"], "wave_count": 4},
		"faith_02": {"id": "faith_02", "name": "神谕大厅", "continent": "faith", "type": "battle", "x": 520, "y": 260, "unlocks": ["faith_03"], "wave_count": 5},
		"faith_03": {"id": "faith_03", "name": "圣者墓园", "continent": "faith", "type": "boss", "x": 540, "y": 160, "unlocks": ["center_01"], "wave_count": 6, "is_boss": true},

		"nature_01": {"id": "nature_01", "name": "荆棘丛林", "continent": "nature", "type": "battle", "x": 800, "y": 440, "unlocks": ["nature_02"], "wave_count": 4},
		"nature_02": {"id": "nature_02", "name": "孢子沼泽", "continent": "nature", "type": "battle", "x": 860, "y": 340, "unlocks": ["nature_03"], "wave_count": 5},
		"nature_03": {"id": "nature_03", "name": "古树之心", "continent": "nature", "type": "boss", "x": 920, "y": 240, "unlocks": ["center_01"], "wave_count": 6, "is_boss": true},

		"commerce_01": {"id": "commerce_01", "name": "黑市入口", "continent": "commerce", "type": "battle", "x": 1020, "y": 400, "unlocks": ["commerce_02"], "wave_count": 4},
		"commerce_02": {"id": "commerce_02", "name": "交易所", "continent": "commerce", "type": "battle", "x": 1060, "y": 320, "unlocks": ["commerce_03"], "wave_count": 5},
		"commerce_03": {"id": "commerce_03", "name": "金融塔", "continent": "commerce", "type": "boss", "x": 1080, "y": 240, "unlocks": ["center_01"], "wave_count": 6, "is_boss": true},

		"memory_01": {"id": "memory_01", "name": "遗忘之街", "continent": "memory", "type": "battle", "x": 560, "y": 520, "unlocks": ["memory_02"], "wave_count": 4},
		"memory_02": {"id": "memory_02", "name": "档案馆", "continent": "memory", "type": "battle", "x": 620, "y": 480, "unlocks": ["memory_03"], "wave_count": 5},
		"memory_03": {"id": "memory_03", "name": "记忆之塔", "continent": "memory", "type": "boss", "x": 680, "y": 400, "unlocks": ["center_01"], "wave_count": 6, "is_boss": true},

		"center_01": {"id": "center_01", "name": "混战区·边缘", "continent": "neutral", "type": "battle", "x": 640, "y": 100, "unlocks": ["center_02"], "wave_count": 5},
		"center_02": {"id": "center_02", "name": "混战区·核心", "continent": "neutral", "type": "boss", "x": 640, "y": 50, "unlocks": [], "wave_count": 8, "is_boss": true},
	}

func get_map_node(id: String) -> Dictionary:
	return node_database.get(id, {}).duplicate()

func get_all_nodes() -> Dictionary:
	return node_database

func is_node_unlocked(id: String) -> bool:
	return id in GameData.world_progress["unlocked_nodes"]

func is_node_completed(id: String) -> bool:
	return id in GameData.world_progress["completed_nodes"]

func complete_and_unlock(node_id: String):
	GameData.complete_node(node_id)
	var nd = node_database.get(node_id, {})
	for next_id in nd.get("unlocks", []):
		if not is_node_unlocked(next_id):
			GameData.unlock_node(next_id)
			EventBus.node_unlocked.emit(next_id)

func get_continent_name(continent: String) -> String:
	var names = {
		"tech": "秩序·技术大陆",
		"faith": "信仰·神秘大陆",
		"nature": "自然·野性大陆",
		"commerce": "商业·混沌大陆",
		"memory": "记忆·复古大陆",
		"neutral": "中心混战大陆",
	}
	return names.get(continent, continent)
