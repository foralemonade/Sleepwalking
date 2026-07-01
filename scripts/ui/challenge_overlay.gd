extends CanvasLayer
## 挑战模式卡牌选择浮层 — 每 3 波出现一次

signal card_selected(card_id: String)

var challenge_manager: ChallengeManager = null
var card_buttons: Array[Button] = []
var is_visible: bool = false

func _ready() -> void:
	hide()

func setup(cm: ChallengeManager) -> void:
	challenge_manager = cm

func show_card_selection() -> void:
	if challenge_manager == null:
		return
	# 暂停游戏
	get_tree().paused = true
	is_visible = true
	show()
	_clear_cards()
	_create_selection_ui()

func _clear_cards() -> void:
	for child in get_children():
		child.queue_free()
	card_buttons.clear()

func _create_selection_ui() -> void:
	# 半透明背景
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.15, 0.10, 0.25, 0.80)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "选择一张强化卡牌"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
	add_child(title)

	# 生成 3 张随机卡牌
	var cards: Array = challenge_manager.generate_card_options(3)
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var card_panel := _create_card(card, i)
		add_child(card_panel)

func _create_card(card: Dictionary, index: int) -> Panel:
	var panel := Panel.new()
	var x: float = 90.0 + index * 380.0
	panel.position = Vector2(x, 160)
	panel.size = Vector2(340, 380)
	panel.modulate = Color(0.20, 0.15, 0.30, 0.95)
	add_child(panel)

	# 图标/颜色
	var icon_rect := ColorRect.new()
	icon_rect.position = Vector2(20, 20)
	icon_rect.size = Vector2(300, 60)
	var icon_color: Color = _get_card_color(card["id"])
	icon_rect.color = icon_color
	panel.add_child(icon_rect)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = card["name"]
	name_lbl.position = Vector2(20, 30)
	name_lbl.size = Vector2(300, 40)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(name_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = card.get("desc", "")
	desc_lbl.position = Vector2(20, 100)
	desc_lbl.size = Vector2(300, 120)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.88))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_lbl)

	# 选择按钮
	var select_btn := Button.new()
	select_btn.text = "选 择"
	select_btn.position = Vector2(70, 280)
	select_btn.size = Vector2(200, 60)
	select_btn.add_theme_font_size_override("font_size", 20)
	select_btn.modulate = icon_color
	select_btn.pressed.connect(_on_card_selected.bind(card))
	panel.add_child(select_btn)

	return panel

func _get_card_color(card_id: String) -> Color:
	match card_id:
		"resonance_amp": return Color(0.78, 0.65, 0.95)    # 丁香紫
		"iron_wall": return Color(0.55, 0.80, 0.95)        # 冰蓝
		"berserk": return Color(0.95, 0.60, 0.65)          # 柔红
		"reinforcements": return Color(0.68, 0.92, 0.82)   # 薄荷绿
		"crit_chance": return Color(1.0, 0.88, 0.55)       # 柔金
		"gold_rush": return Color(1.0, 0.88, 0.55)         # 柔金
		"healing_aura": return Color(0.55, 0.88, 0.72)     # 柔绿
		"slow_field": return Color(0.55, 0.80, 0.95)       # 冰蓝
		"extra_slot": return Color(0.78, 0.65, 0.95)       # 丁香紫
		"poison_blade": return Color(0.68, 0.92, 0.82)     # 薄荷绿
		"double_energy": return Color(0.95, 0.88, 0.55)    # 柔金
		"last_stand": return Color(0.95, 0.75, 0.55)       # 柔橙
		_: return Color(0.55, 0.50, 0.65)                  # 灰紫

func _on_card_selected(card: Dictionary) -> void:
	challenge_manager.select_card(card)
	EventBus.challenge_card_selected.emit(card["id"])
	_apply_card_to_game(card)
	# 恢复游戏
	get_tree().paused = false
	is_visible = false
	hide()
	card_selected.emit(card["id"])

func _apply_card_to_game(card: Dictionary) -> void:
	var cid: String = card["id"]
	match cid:
		"iron_wall":
			GameData.castle_modules["defense"] += 50
		"extra_slot":
			GameData.castle_modules["creature_slots"] += 1
		"healing_aura":
			GameData.castle_modules["energy_regen"] += 2.0
		"double_energy":
			GameData.castle_modules["energy_regen"] += 1.0
		"slow_field":
			pass  # 由 get_active_card_bonus 处理
		"gold_rush":
			pass
		"resonance_amp":
			pass
		"berserk":
			pass
		"crit_chance":
			pass
		"poison_blade":
			pass
		"reinforcements":
			pass
		"last_stand":
			pass
