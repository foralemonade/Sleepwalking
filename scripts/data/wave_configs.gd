extends RefCounted
class_name WaveConfigs
## 波次配置数据 v0.4 - 各大陆不同难度的预设波次
## v0.4 变更:
##   - 新增 "special" 敌人类型 (直攻城堡核心的特殊敌人)
##   - 每波次可包含 is_special 标记的敌人

static func get_default_waves() -> Array[Dictionary]:
	return [
		{"enemy_type":"basic","enemy_count":3,"spawn_interval":1.5},
		{"enemy_type":"fast","enemy_count":4,"spawn_interval":1.2},
		{"enemy_type":"basic","enemy_count":2,"spawn_interval":2.0},
		{"enemy_type":"tank","enemy_count":2,"spawn_interval":2.5,"has_special":true,"special_count":1,"special_interval":2.5},
		{"enemy_type":"elite","enemy_count":1,"spawn_interval":0.5},
		{"enemy_type":"tank","enemy_count":3,"spawn_interval":1.5,"has_special":true,"special_count":2,"special_interval":1.8},
		{"enemy_type":"boss","enemy_count":1,"spawn_interval":0.5},
	]

static func get_waves_for_node(node_data: Dictionary) -> Array[Dictionary]:
	var count: int = node_data.get("wave_count", 4)
	var is_boss: bool = node_data.get("is_boss", false)
	var theme: String = node_data.get("enemy_theme", "basic")
	var configs: Array[Dictionary] = []
	var wave_types: Array[String] = ["basic", "fast", "basic", "tank", "elite", "boss"]
	for i in range(count):
		var etype: String = wave_types[min(i, wave_types.size() - 1)]
		if theme == "mixed" and i < count - 1:
			etype = wave_types[randi() % 4]
		var enemy_count: int = 3 if i < count - 2 else (1 if is_boss and i == count - 1 else 2)
		var wave_config: Dictionary = {"enemy_type": etype, "enemy_count": enemy_count, "spawn_interval": 1.5}
		# 从第3波起, 每2波可能出现1个特殊敌人
		if i >= 2 and i % 2 == 0 and not is_boss:
			wave_config["has_special"] = true
			wave_config["special_count"] = 1
			wave_config["special_interval"] = 3.0
		configs.append(wave_config)
	if is_boss and count > 0:
		configs[count - 1] = {"enemy_type": "boss", "enemy_count": 1, "spawn_interval": 0.5}
	return configs

static func get_challenge_waves(wave_num: int) -> Dictionary:
	var types: Array[String] = ["basic", "fast", "tank", "elite"]
	var type_idx: int = (wave_num - 1) / 4
	var etype: String = types[min(type_idx, types.size() - 1)]
	var count: int = 2 + wave_num
	var interval: float = maxf(0.5, 1.5 - wave_num * 0.05)
	if wave_num % 5 == 0:
		return {"enemy_type": "boss", "enemy_count": 1, "spawn_interval": 0.5}
	# 每4波增加1个特殊敌人
	var config: Dictionary = {"enemy_type": etype, "enemy_count": count, "spawn_interval": interval}
	if wave_num % 4 == 0 and wave_num > 4:
		config["has_special"] = true
		config["special_count"] = 1
		config["special_interval"] = 2.5
	return config
