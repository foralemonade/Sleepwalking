extends CanvasLayer
## 战斗 UI 层 — 顶部状态栏 / 底部生物面板 / 技能按钮 / 消息提示

var wave_label: Label = null
var castle_hp_bar: ProgressBar = null
var castle_hp_label: Label = null
var synergy_label: Label = null
var energy_bar: ProgressBar = null
var start_button: Button = null
var message_label: Label = null
var gold_label: Label = null
var continent_label: Label = null
var back_button: Button = null

var creature_panel_container: HBoxContainer = null
var slot_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []

var castle: Castle = null
var wave_manager: WaveManager = null
var skill_system: SkillSystem = null

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_gold_display()

func _setup_ui() -> void:
	# ---- 顶部半透明栏 ----
	var top_bar := Panel.new()
	top_bar.position = Vector2(10, 10)
	top_bar.size = Vector2(1260, 90)
	top_bar.modulate = Color(0.15, 0.10, 0.25, 0.6)
	add_child(top_bar)

	# 波次标签
	wave_label = Label.new()
	wave_label.position = Vector2(20, 15)
	wave_label.text = "准备战斗"
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(wave_label)

	# 大陆/节点名称
	continent_label = Label.new()
	continent_label.position = Vector2(20, 38)
	continent_label.add_theme_font_size_override("font_size", 12)
	continent_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	add_child(continent_label)

	# 金币
	gold_label = Label.new()
	gold_label.position = Vector2(250, 15)
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	add_child(gold_label)

	# 护盾标签
	var hp_lbl := Label.new()
	hp_lbl.position = Vector2(20, 55)
	hp_lbl.text = "护盾:"
	hp_lbl.add_theme_font_size_override("font_size", 14)
	hp_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	add_child(hp_lbl)

	castle_hp_bar = ProgressBar.new()
	castle_hp_bar.position = Vector2(70, 55)
	castle_hp_bar.size = Vector2(260, 18)
	castle_hp_bar.max_value = 100
	castle_hp_bar.value = 100
	castle_hp_bar.modulate = Color(0.55, 0.75, 1.0)
	add_child(castle_hp_bar)

	castle_hp_label = Label.new()
	castle_hp_label.position = Vector2(340, 55)
	castle_hp_label.add_theme_font_size_override("font_size", 13)
	castle_hp_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(castle_hp_label)

	# 能量标签
	var en_lbl := Label.new()
	en_lbl.position = Vector2(450, 55)
	en_lbl.text = "能量:"
	en_lbl.add_theme_font_size_override("font_size", 14)
	en_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72))
	add_child(en_lbl)

	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(500, 55)
	energy_bar.size = Vector2(200, 18)
	energy_bar.max_value = 100
	energy_bar.value = 50
	energy_bar.modulate = Color(0.55, 0.88, 0.72)
	add_child(energy_bar)

	# 派系信息
	synergy_label = Label.new()
	synergy_label.position = Vector2(720, 15)
	synergy_label.size = Vector2(350, 70)
	synergy_label.text = "派系阵容: 无"
	synergy_label.add_theme_font_size_override("font_size", 12)
	synergy_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.88))
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(synergy_label)

	# 消息标签
	message_label = Label.new()
	message_label.position = Vector2(400, 280)
	message_label.size = Vector2(480, 80)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(message_label)

	# 开始按钮
	start_button = Button.new()
	start_button.position = Vector2(1100, 20)
	start_button.size = Vector2(140, 50)
	start_button.text = "开始战斗"
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	# 返回按钮
	back_button = Button.new()
	back_button.position = Vector2(10, 680)
	back_button.size = Vector2(80, 30)
	back_button.text = "< 返回"
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	# 技能按钮
	_create_skill_buttons()

	# 底部面板
	var bottom := Panel.new()
	bottom.position = Vector2(10, 550)
	bottom.size = Vector2(1260, 160)
	bottom.modulate = Color(0.15, 0.10, 0.25, 0.6)
	add_child(bottom)

	var panel_title := Label.new()
	panel_title.position = Vector2(20, 558)
	panel_title.text = "可用生物 | 点击放置到城堡空槽位"
	panel_title.add_theme_font_size_override("font_size", 14)
	panel_title.add_theme_color_override("font_color", Color(0.85, 0.80, 0.92))
	add_child(panel_title)

	# 生物选择面板
	creature_panel_container = HBoxContainer.new()
	creature_panel_container.position = Vector2(30, 590)
	creature_panel_container.add_theme_constant_override("separation", 8)
	add_child(creature_panel_container)

	_refresh_creature_buttons()

func _create_skill_buttons() -> void:
	skill_buttons.clear()
	var btn1 := Button.new()
	btn1.position = Vector2(1080, 80)
	btn1.size = Vector2(70, 35)
	btn1.text = "能量爆发"
	btn1.add_theme_font_size_override("font_size", 10)
	btn1.modulate = Color(0.95, 0.60, 0.65)
	btn1.pressed.connect(func(): _on_skill_pressed("energy_burst"))
	add_child(btn1)
	skill_buttons.append(btn1)

	var btn2 := Button.new()
	btn2.position = Vector2(1160, 80)
	btn2.size = Vector2(70, 35)
	btn2.text = "护盾过载"
	btn2.add_theme_font_size_override("font_size", 10)
	btn2.modulate = Color(0.55, 0.75, 1.0)
	btn2.pressed.connect(func(): _on_skill_pressed("shield_overload"))
	add_child(btn2)
	skill_buttons.append(btn2)

func _refresh_creature_buttons() -> void:
	for child in creature_panel_container.get_children():
		child.queue_free()
	slot_buttons.clear()

	for cid in GameData.player_creatures:
		var data: Dictionary = GameData.get_creature_data(cid)
		if data.is_empty():
			continue
		var btn := Button.new()
		btn.text = data["name"] + "\n[" + GameData.get_faction_name(data["faction"]) + "]"
		btn.custom_minimum_size = Vector2(110, 60)
		btn.add_theme_font_size_override("font_size", 11)
		btn.modulate = GameData.get_faction_color(data["faction"])
		btn.tooltip_text = "攻:" + str(data["attack"]) + " 速:" + str(data["attack_speed"]) + "\n" + data.get("skill_desc", "")
		btn.pressed.connect(_on_creature_btn_pressed.bind(cid))
		creature_panel_container.add_child(btn)

	var slot_count: int = GameData.castle_modules["creature_slots"]
	for i in range(slot_count):
		var btn := Button.new()
		btn.text = "槽" + str(i + 1) + "\n[空]"
		btn.custom_minimum_size = Vector2(90, 60)
		btn.add_theme_font_size_override("font_size", 11)
		btn.modulate = Color(0.55, 0.50, 0.65)
		btn.pressed.connect(_on_slot_btn_pressed.bind(i))
		creature_panel_container.add_child(btn)
		slot_buttons.append(btn)

func _connect_signals() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.castle_damaged.connect(_on_castle_damaged)
	EventBus.castle_destroyed.connect(_on_battle_lost)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.creature_placed.connect(_on_creature_change)
	EventBus.creature_removed.connect(_on_creature_change)
	EventBus.synergy_updated.connect(_on_synergy_updated)
	EventBus.resource_changed.connect(_on_resource_changed)

func setup_references(c: Castle, wm: WaveManager, ss: SkillSystem) -> void:
	castle = c
	wave_manager = wm
	skill_system = ss
	castle_hp_bar.max_value = castle.max_shield
	castle_hp_bar.value = castle.current_shield
	castle_hp_label.text = str(castle.current_shield) + "/" + str(castle.max_shield)

	# 更新大陆/节点显示
	if not wave_manager.node_data.is_empty():
		var nd: Dictionary = wave_manager.node_data
		continent_label.text = nd.get("name", "") + " | " + WorldMap.get_continent_name(nd.get("continent", ""))

	# 刷新生物槽位数量
	_refresh_creature_buttons()

func _on_wave_started(wn: int) -> void:
	wave_label.text = "第 " + str(wn) + " 波 - 战斗中"
	start_button.disabled = true
	_show_message("第 " + str(wn) + " 波 开始！", 2.0)

func _on_wave_cleared(wn: int) -> void:
	wave_label.text = "第 " + str(wn) + " 波 - 完成！"

func _on_battle_won() -> void:
	wave_label.text = "战斗胜利！"
	start_button.disabled = false
	start_button.text = "再来一局"
	_show_message("胜利！", 3.0)
	# 发放声誉奖励
	_award_reputation()
	# 发放通关奖励
	_award_node_rewards()
	# 世界地图模式: 自动返回地图
	if wave_manager and wave_manager.battle_mode == 0:
		_auto_return_to_map()

func _auto_return_to_map() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		GameData.world_progress["current_node"] = ""
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	)

func _award_reputation() -> void:
	var nd: Dictionary = wave_manager.node_data
	if nd.is_empty():
		return
	var continent: String = nd.get("continent", "")
	var faction_map: Dictionary = {
		"tech": GameData.Faction.TECH,
		"faith": GameData.Faction.FAITH,
		"nature": GameData.Faction.NATURE,
		"commerce": GameData.Faction.COMMERCE,
		"memory": GameData.Faction.MEMORY,
	}
	var amount: int = 30
	if nd.get("is_boss", false):
		amount = 100
	if nd.get("type", "") == "story":
		amount = 10
	if continent in faction_map:
		GameData.add_reputation(faction_map[continent], amount)
	elif continent == "neutral":
		for f in [GameData.Faction.TECH, GameData.Faction.FAITH, GameData.Faction.NATURE, GameData.Faction.COMMERCE, GameData.Faction.MEMORY]:
			GameData.add_reputation(f, int(amount / 2))

func _award_node_rewards() -> void:
	var nd: Dictionary = wave_manager.node_data
	if nd.is_empty():
		return
	# 节点完成时给予金币奖励
	var gold_reward: int = nd.get("wave_count", 4) * 25
	if nd.get("is_boss", false):
		gold_reward = 200
	GameData.add_resource("gold", gold_reward)
	_show_message("获得 " + str(gold_reward) + " 金币！", 2.5)

func _on_battle_lost(_a = null) -> void:
	wave_label.text = "城堡被摧毁..."
	start_button.disabled = false
	start_button.text = "重新挑战"
	_show_message("失败...", 3.0)

func _on_castle_damaged(current: int, m: int) -> void:
	castle_hp_bar.max_value = m
	castle_hp_bar.value = current
	castle_hp_label.text = str(current) + "/" + str(m)
	var ratio: float = float(current) / float(m)
	if ratio < 0.3:
		castle_hp_bar.modulate = Color(0.95, 0.50, 0.55)
	elif ratio < 0.6:
		castle_hp_bar.modulate = Color(0.95, 0.70, 0.55)
	else:
		castle_hp_bar.modulate = Color(0.55, 0.75, 1.0)

func _on_creature_change(_a: int = 0, _b: String = "") -> void:
	_update_slot_labels()

func _on_synergy_updated(result: Dictionary) -> void:
	_update_synergy_display(result)

func _on_resource_changed(_type: String, _amt: int) -> void:
	_update_gold_display()

func _update_synergy_display(result: Dictionary) -> void:
	if result.is_empty():
		synergy_label.text = "派系阵容: 无"
		return
	if castle == null:
		return
	var ids: Array[String] = castle.current_creature_ids
	if ids.is_empty():
		synergy_label.text = "派系阵容: 无"
		return
	var text: String = "阵容: "
	for id in ids:
		var d: Dictionary = GameData.get_creature_data(id)
		if d.has("name"):
			text += d["name"] + " "
	text += "\n攻+" + str(int(result.get("global_attack_bonus", 0.0) * 100)) + "%"
	text += " 速+" + str(int(result.get("global_speed_bonus", 0.0) * 100)) + "%"
	var rxns: Array = result.get("cross_reactions", [])
	if not rxns.is_empty():
		text += "\n反应: "
		for r in rxns:
			text += r["name"] + " "
	synergy_label.text = text

func _update_slot_labels() -> void:
	if castle == null:
		return
	for i in range(min(slot_buttons.size(), castle.creature_slots.size())):
		var slot: Dictionary = castle.creature_slots[i]
		if slot["creature_id"] == "":
			slot_buttons[i].text = "槽" + str(i + 1) + "\n[空]"
			slot_buttons[i].modulate = Color(0.55, 0.50, 0.65)
		else:
			var d: Dictionary = GameData.get_creature_data(slot["creature_id"])
			slot_buttons[i].text = "槽" + str(i + 1) + "\n" + d.get("name", "???")
			slot_buttons[i].modulate = GameData.get_faction_color(d.get("faction", 0))

func _update_gold_display() -> void:
	gold_label.text = "金币: " + str(GameData.resources["gold"])

func _on_back_pressed() -> void:
	# 停止战斗
	if wave_manager and wave_manager.is_battle_active:
		wave_manager.stop_battle()
	# 清除标记
	GameData.world_progress["current_node"] = ""
	GameData.world_progress["challenge_active"] = false
	# 根据模式返回不同场景
	if wave_manager and wave_manager.battle_mode == 0:  # WORLD_MAP
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	elif wave_manager and wave_manager.battle_mode == 1:  # CHALLENGE
		get_tree().change_scene_to_file("res://scenes/challenge_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_start_pressed() -> void:
	if wave_manager == null:
		return
	wave_manager.clear_all_enemies()
	wave_manager.current_wave = -1
	wave_manager.start_battle()
	start_button.text = "战斗中..."
	start_button.disabled = true

func _on_creature_btn_pressed(cid: String) -> void:
	if castle == null:
		return
	for i in range(castle.creature_slots.size()):
		if castle.creature_slots[i]["creature_id"] == "":
			castle.place_creature(i, cid)
			return
	_show_message("槽位已满！先移除一个生物", 2.0)

func _on_slot_btn_pressed(idx: int) -> void:
	if castle == null:
		return
	castle.remove_creature(idx)

func _on_skill_pressed(skill_id: String) -> void:
	if skill_system == null or castle == null:
		return
	skill_system.use_skill(skill_id, wave_manager.enemy_container, castle)

func _process(_delta: float) -> void:
	if skill_system and energy_bar:
		energy_bar.value = skill_system.current_energy
		energy_bar.max_value = skill_system.max_energy

func _show_message(text: String, duration: float) -> void:
	message_label.text = text
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(message_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
