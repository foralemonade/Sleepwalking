extends RefCounted
class_name FactionData
## 派系数据 - 各大洲地形描述、派系背景

static func get_faction_lore(faction: int) -> Dictionary:
	var lores = {
		GameData.Faction.TECH: {
			"continent_name":"废弃城市·钢铁废土",
			"terrain_desc":"曾经繁华的都市群如今只剩钢铁骨架。高耸的摩天楼斜插在地面，地下管道暴露在酸雨中。技术派系在这里用旧世界的零件组装武器和机械生物。",
			"ideology":"秩序需要技术来维持。只有精确的计算和可靠的机械才能重建文明。",
			"enemy_desc":"机械改造怪物、失控的自动化兵器",
		},
		GameData.Faction.FAITH: {
			"continent_name":"焦土平原·圣殿遗迹",
			"terrain_desc":"大灾变后的焦黑色平原上散布着无数崩塌的宗教建筑。奇异的灵体在废墟间游荡，空气中回荡着古老的祈祷声。",
			"ideology":"在物质崩塌之后，精神是唯一的支柱。",
			"enemy_desc":"灵体生物、被诅咒的祭祀傀儡",
		},
		GameData.Faction.NATURE: {
			"continent_name":"变异丛林·绿海",
			"terrain_desc":"末日反而催生了植物的疯狂变异。巨大的藤蔓覆盖了破败建筑，孢子云遮蔽天空。这里是生命的狂欢，也是最危险的地方之一。",
			"ideology":"文明是枷锁，回归自然才是真正的自由。",
			"enemy_desc":"变异植物、巨大化的野兽",
		},
		GameData.Faction.COMMERCE: {
			"continent_name":"废土集市·红土荒原",
			"terrain_desc":"一片被炸烂的红色荒原上，商队帐篷和铁皮房构成了流动的集市。这里没有法律，只有交易。一切都可以是商品。",
			"ideology":"在废墟中，最有价值的不是力量，而是信息与契约。",
			"enemy_desc":"雇佣兵、欺诈者、商会私兵",
		},
		GameData.Faction.MEMORY: {
			"continent_name":"记忆之都·回声街道",
			"terrain_desc":"一座被时间冻结的城市。建筑物保持着大灾变瞬间的样子，人们的影子似乎还留在墙上。回忆在这里变成了可以触摸的东西。",
			"ideology":"遗忘才是真正的死亡。保存过去，才能面对未来。",
			"enemy_desc":"记忆碎片、时间异常体、旧世界的残响",
		},
	}
	return lores.get(faction, {})

static func get_neutral_lore() -> Dictionary:
	return {
		"continent_name":"中心混战大陆·血泊平原",
		"terrain_desc":"五片大陆的交汇处，各派系的触角在此纠缠。资源最丰富，战斗最激烈。任何势力都想占有它，但没有人能站稳脚跟。",
	}
