extends RefCounted
class_name WaveConfigs
## 波次配置数据 - 各大陆不同难度的预设波次

static func get_default_waves() -> Array[Dictionary]:
	return [
		{"enemy_type":"basic","enemy_count":3,"spawn_interval":1.5},
		{"enemy_type":"fast","enemy_count":4,"spawn_interval":1.2},
		{"enemy_type":"basic","enemy_count":2,"spawn_interval":2.0},
		{"enemy_type":"tank","enemy_count":2,"spawn_interval":2.5},
		{"enemy_type":"elite","enemy_count":1,"spawn_interval":0.5},
		{"enemy_type":"boss","enemy_count":1,"spawn_interval":0.5},
	]

static func get_waves_for_node(node_data: Dictionary) -> Array[Dictionary]:
	var count = node_data.get("wave_count", 4)
	var is_boss = node_data.get("is_boss", false)
	var theme = node_data.get("enemy_theme", "basic")
	var configs: Array[Dictionary] = []
	var wave_types = ["basic","fast","basic","tank","elite","boss"]
	for i in range(count):
		var etype = wave_types[min(i, wave_types.size()-1)]
		if theme == "mixed" and i < count-1:
			etype = wave_types[randi() % 4]
		var enemy_count = 3 if i < count-2 else (1 if is_boss and i==count-1 else 2)
		configs.append({"enemy_type":etype,"enemy_count":enemy_count,"spawn_interval":1.5})
	if is_boss and count > 0:
		configs[count-1] = {"enemy_type":"boss","enemy_count":1,"spawn_interval":0.5}
	return configs

static func get_challenge_waves(wave_num: int) -> Dictionary:
	var types = ["basic","fast","tank","elite"]
	var type_idx = (wave_num - 1) / 4
	var etype = types[min(type_idx, types.size()-1)]
	var count = 2 + wave_num
	var interval = max(0.5, 1.5 - wave_num * 0.05)
	if wave_num % 5 == 0:
		return {"enemy_type":"boss","enemy_count":1,"spawn_interval":0.5}
	return {"enemy_type":etype,"enemy_count":count,"spawn_interval":interval}
