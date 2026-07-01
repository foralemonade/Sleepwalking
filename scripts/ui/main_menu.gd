extends Control
## 梦游症 - 主菜单
## 支持新游戏 / 继续游戏 / 各模式入口

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.18, 0.14, 0.28)
	add_child(bg)

	# 星星背景
	for i in range(40):
		var dot := ColorRect.new()
		dot.position = Vector2(randi() % 1280, randi() % 720)
		dot.size = Vector2(2, 2)
		dot.color = Color(0.7, 0.65, 1.0, randf() * 0.5 + 0.3)
		add_child(dot)

	# 标题
	var title := Label.new()
	title.text = "梦 游 症"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	add_child(title)

	var sub := Label.new()
	sub.text = "Somnambulism"
	sub.position = Vector2(0, 160)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	add_child(sub)

	# 存档状态
	if SaveManager.has_save:
		_create_button("继续游戏", 220, "_continue_game")
		_create_button("新游戏", 290, "_new_game")
	else:
		_create_button("新游戏", 250, "_new_game")

	_create_button("阵营商店", 350, "_open_shop")
	_create_button("无限挑战", 420, "_open_challenge")
	_create_button("原型战斗", 490, "_open_test")

	# 版本
	var ver := Label.new()
	ver.text = "v0.3 | Godot 4.6 | 五大派系 x 六大陆 x 20只生物"
	ver.position = Vector2(0, 680)
	ver.size = Vector2(1280, 20)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.55, 0.50, 0.70))
	add_child(ver)

func _create_button(txt: String, y_pos: float, method: String) -> void:
	var btn := Button.new()
	btn.text = txt
	btn.position = Vector2(490, y_pos)
	btn.size = Vector2(300, 55)
	btn.add_theme_font_size_override("font_size", 20)
	match method:
		"_continue_game":
			btn.pressed.connect(_on_continue_game)
		"_new_game":
			btn.pressed.connect(_on_new_game)
		"_open_shop":
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/faction_shop.tscn"))
		"_open_challenge":
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/challenge_scene.tscn"))
		"_open_test":
			btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_scene.tscn"))
	add_child(btn)

func _on_continue_game() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _on_new_game() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
