extends Control
## 大地图 UI - 六大陆节点选择

var node_buttons: Dictionary = {}

func _ready():
	_setup_ui()
	_connect_signals()

func _setup_ui():
	# 背景
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.18, 0.14, 0.28)
	add_child(bg)

	# 标题
	var title = Label.new()
	title.text = "梦游症 · 六大陆"
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
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back)

	# 阵营商店按钮
	var shop_btn := Button.new()
	shop_btn.position = Vector2(110, 10)
	shop_btn.size = Vector2(100, 35)
	shop_btn.text = "阵营商店"
	shop_btn.add_theme_font_size_override("font_size", 12)
	shop_btn.modulate = Color(1.0, 0.88, 0.55)
	shop_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/faction_shop.tscn"))
	add_child(shop_btn)

	# 存档按钮
	var save_btn := Button.new()
	save_btn.position = Vector2(220, 10)
	save_btn.size = Vector2(80, 35)
	save_btn.text = "存档"
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.modulate = Color(0.55, 0.88, 0.72)
	save_btn.pressed.connect(_on_save_pressed)
	add_child(save_btn)

	# 大陆区域
	var continents = [
		{"name": "技术大陆", "x": 160, "y": 200, "w": 200, "h": 300, "col": Color(0.25, 0.32, 0.45)},
		{"name": "信仰大陆", "x": 420, "y": 100, "w": 200, "h": 340, "col": Color(0.35, 0.25, 0.30)},
		{"name": "自然大陆", "x": 720, "y": 200, "w": 200, "h": 310, "col": Color(0.25, 0.35, 0.28)},
		{"name": "商业大陆", "x": 940, "y": 280, "w": 200, "h": 260, "col": Color(0.35, 0.28, 0.25)},
		{"name": "记忆大陆", "x": 520, "y": 460, "w": 200, "h": 200, "col": Color(0.30, 0.22, 0.40)},
		{"name": "混战大陆", "x": 520, "y": 30, "w": 200, "h": 100, "col": Color(0.25, 0.18, 0.30)},
	]
	for cont in continents:
		var r = ColorRect.new()
		r.position = Vector2(cont["x"], cont["y"])
		r.size = Vector2(cont["w"], cont["h"])
		r.color = cont["col"]
		add_child(r)
		var lbl = Label.new()
		lbl.position = Vector2(cont["x"] + 5, cont["y"] + 5)
		lbl.text = cont["name"]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.88))
		add_child(lbl)

	_create_node_buttons()

func _create_node_buttons():
	var nodes: Dictionary = WorldMap.get_all_nodes()
	for nid in nodes:
		var nd = nodes[nid]
		var btn = Button.new()
		var sx = nd["x"] - 18
		var sy = nd["y"] - 18

		if nd.get("is_boss", false):
			btn.position = Vector2(sx - 6, sy - 6)
			btn.size = Vector2(48, 48)
			btn.text = "BOSS"
		else:
			btn.position = Vector2(sx, sy)
			btn.size = Vector2(36, 36)
			btn.text = nd["name"]

		btn.add_theme_font_size_override("font_size", 8)

		if WorldMap.is_node_completed(nid):
			btn.modulate = Color(0.65, 0.90, 0.70)
		elif WorldMap.is_node_unlocked(nid) or nid == "start":
			btn.modulate = Color(0.95, 0.90, 0.95)
		else:
			btn.modulate = Color(0.40, 0.35, 0.45)

		btn.pressed.connect(_on_node_pressed.bind(nid))
		add_child(btn)
		node_buttons[nid] = btn

func _on_node_pressed(node_id: String):
	if not WorldMap.is_node_unlocked(node_id) and node_id != "start":
		return
	GameData.world_progress["current_node"] = node_id
	var nd: Dictionary = WorldMap.get_map_node(node_id)
	EventBus.node_entered.emit(node_id)
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")

func _connect_signals():
	EventBus.node_completed.connect(_on_node_completed)
	EventBus.node_unlocked.connect(_on_node_unlocked)
	EventBus.battle_won.connect(_on_battle_won_map)

func _on_battle_won_map() -> void:
	var node_id: String = GameData.world_progress["current_node"]
	if node_id != "" and not WorldMap.is_node_completed(node_id):
		WorldMap.complete_and_unlock(node_id)
	# 自动存档
	SaveManager.save_game()

func _on_node_completed(node_id: String):
	if node_buttons.has(node_id):
		node_buttons[node_id].modulate = Color(0.65, 0.90, 0.70)

func _on_node_unlocked(node_id: String) -> void:
	if node_buttons.has(node_id):
		node_buttons[node_id].modulate = Color(0.95, 0.90, 0.95)

func _on_save_pressed() -> void:
	SaveManager.save_game()
	_show_save_feedback()

func _show_save_feedback() -> void:
	var lbl := Label.new()
	lbl.text = "已保存！"
	lbl.position = Vector2(540, 350)
	lbl.size = Vector2(200, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72))
	add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate", Color(0.55, 0.88, 0.72, 0.0), 0.5)
	tw.tween_callback(func(): lbl.queue_free())
