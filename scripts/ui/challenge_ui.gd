extends Control
## 无限挑战入口 — Roguelike 模式
## 设置挑战标记后跳转战斗场景,由 BattleController 接管

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.18, 0.14, 0.28)
	add_child(bg)

	var title := Label.new()
	title.text = "无限挑战"
	title.position = Vector2(0, 100)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
	add_child(title)

	var sub := Label.new()
	sub.text = "Roguelike 模式 | 20 波递增难度 | 每波结束后选卡牌强化"
	sub.position = Vector2(0, 160)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.70, 0.65, 0.85))
	add_child(sub)

	# 规则说明
	var rules := Label.new()
	rules.text = "规则:\n- 共 20 波敌人,难度递增\n- 每波结束后获得金币\n- 每 3 波可选择一张强化卡牌\n- 12 种 Roguelike 卡牌随机出现\n- 城堡被摧毁或全部波次通过即结束"
	rules.position = Vector2(290, 220)
	rules.size = Vector2(700, 130)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_theme_font_size_override("font_size", 14)
	rules.add_theme_color_override("font_color", Color(0.70, 0.65, 0.85))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(rules)

	var start_btn := Button.new()
	start_btn.text = "开始挑战"
	start_btn.position = Vector2(490, 380)
	start_btn.size = Vector2(300, 60)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.pressed.connect(_on_start_challenge)
	add_child(start_btn)

	var back := Button.new()
	back.text = "< 返回"
	back.position = Vector2(20, 20)
	back.size = Vector2(80, 35)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back)

func _on_start_challenge() -> void:
	# 设置挑战标记
	GameData.world_progress["challenge_active"] = true
	GameData.world_progress["current_node"] = ""
	GameData.world_progress["challenge_score"] = 0
	GameData.world_progress["challenge_wave"] = 0
	GameData.world_progress["max_challenge_waves"] = 20
	EventBus.challenge_started.emit()
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")
