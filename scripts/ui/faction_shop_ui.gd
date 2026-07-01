extends Control
## 阵营商店 UI — 查看声誉、购买生物和模块

var reputation_system: ReputationSystem = null
var current_faction: int = GameData.Faction.TECH

var faction_buttons: Array[Button] = []
var item_container: VBoxContainer = null
var gold_label: Label = null
var rep_label: Label = null
var rank_label: Label = null
var message_label: Label = null

func _ready() -> void:
	reputation_system = ReputationSystem.new()
	reputation_system.name = "ReputationSystem"
	add_child(reputation_system)
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.18, 0.14, 0.28)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "阵营商店"
	title.position = Vector2(0, 10)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	add_child(title)

	# 返回按钮
	var back := Button.new()
	back.position = Vector2(20, 10)
	back.size = Vector2(80, 35)
	back.text = "< 返回"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/world_map.tscn"))
	add_child(back)

	# 金币显示
	gold_label = Label.new()
	gold_label.position = Vector2(1100, 10)
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	add_child(gold_label)

	# 阵营选择按钮
	var faction_data: Array[Dictionary] = [
		{"f": GameData.Faction.TECH, "name": "技术", "col": Color(0.55, 0.80, 0.95)},
		{"f": GameData.Faction.FAITH, "name": "信仰", "col": Color(0.95, 0.78, 0.82)},
		{"f": GameData.Faction.NATURE, "name": "自然", "col": Color(0.68, 0.92, 0.82)},
		{"f": GameData.Faction.COMMERCE, "name": "商业", "col": Color(0.95, 0.82, 0.72)},
		{"f": GameData.Faction.MEMORY, "name": "记忆", "col": Color(0.78, 0.65, 0.95)},
	]
	for i in range(faction_data.size()):
		var fd: Dictionary = faction_data[i]
		var btn := Button.new()
		btn.position = Vector2(30 + i * 170, 60)
		btn.size = Vector2(155, 40)
		btn.text = fd["name"]
		btn.modulate = fd["col"]
		btn.pressed.connect(_on_faction_selected.bind(fd["f"]))
		add_child(btn)
		faction_buttons.append(btn)

	# 声誉和等级
	rep_label = Label.new()
	rep_label.position = Vector2(30, 110)
	rep_label.add_theme_font_size_override("font_size", 14)
	rep_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(rep_label)

	rank_label = Label.new()
	rank_label.position = Vector2(200, 110)
	rank_label.add_theme_font_size_override("font_size", 14)
	rank_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	add_child(rank_label)

	# 物品容器
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 140)
	scroll.size = Vector2(840, 500)
	add_child(scroll)

	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 8)
	scroll.add_child(item_container)

	# 消息
	message_label = Label.new()
	message_label.position = Vector2(900, 140)
	message_label.size = Vector2(350, 200)
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.88))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message_label)

	_select_faction(GameData.Faction.TECH)

func _connect_signals() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.reputation_changed.connect(_on_rep_changed)

func _on_faction_selected(faction: int) -> void:
	_select_faction(faction)

func _select_faction(faction: int) -> void:
	current_faction = faction
	_update_display()

func _update_display() -> void:
	gold_label.text = "金币: " + str(GameData.resources["gold"])
	var rep: int = GameData.faction_reputation.get(current_faction, 0)
	var rank: String = reputation_system.get_rank(current_faction)
	rep_label.text = GameData.get_faction_name(current_faction) + " 声誉: " + str(rep)
	rank_label.text = "等级: " + rank

	# 清空物品列表
	for child in item_container.get_children():
		child.queue_free()

	# 显示生物
	var shop: Dictionary = reputation_system.get_shop_items(current_faction)
	var creatures: Array = shop.get("creatures", [])
	var modules: Array = shop.get("modules", [])
	var costs: Dictionary = shop.get("costs", {})

	if not creatures.is_empty():
		var header := Label.new()
		header.text = "── 生物 ──"
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
		item_container.add_child(header)

		for cid in creatures:
			var data: Dictionary = GameData.get_creature_data(cid)
			if data.is_empty():
				continue
			var cost: int = costs.get(cid, 0)
			var owned: bool = GameData.has_creature(cid)
			var row := _create_shop_item_row(data["name"], data.get("skill_desc", ""), cost, owned, cid, "creature")
			item_container.add_child(row)

	if not modules.is_empty():
		var header := Label.new()
		header.text = "── 城堡模块 ──"
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
		item_container.add_child(header)

		for mid in modules:
			var data: Dictionary = GameData.get_module_data(mid)
			if data.is_empty():
				continue
			var cost: int = costs.get(mid, 0)
			var owned: bool = mid in GameData.player_inventory_modules
			var row := _create_shop_item_row(data["name"], data.get("desc", ""), cost, owned, mid, "module")
			item_container.add_child(row)

func _create_shop_item_row(item_name: String, desc: String, cost: int, owned: bool, item_id: String, item_type: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.98))
	row.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.custom_minimum_size = Vector2(300, 0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.82))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = str(cost) + " G"
	cost_lbl.custom_minimum_size = Vector2(80, 0)
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	row.add_child(cost_lbl)

	if owned:
		var owned_lbl := Label.new()
		owned_lbl.text = "已拥有"
		owned_lbl.add_theme_font_size_override("font_size", 12)
		owned_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72))
		row.add_child(owned_lbl)
	else:
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.custom_minimum_size = Vector2(60, 30)
		buy_btn.add_theme_font_size_override("font_size", 12)
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id, item_type))
		row.add_child(buy_btn)

	return row

func _on_buy_pressed(item_id: String, item_type: String) -> void:
	var success: bool = reputation_system.buy_item(current_faction, item_id)
	if success:
		_show_message("购买成功！")
		SaveManager.save_game()
		_update_display()
	else:
		_show_message("金币不足！")

func _on_resource_changed(_type: String, _amt: int) -> void:
	_update_display()

func _on_rep_changed(_faction: int, _value: int) -> void:
	_update_display()

func _show_message(text: String) -> void:
	message_label.text = text
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(message_label, "modulate", Color(0.75, 0.70, 0.88, 0.0), 0.5)
	tw.tween_callback(func(): message_label.modulate = Color(0.75, 0.70, 0.88, 1.0))
