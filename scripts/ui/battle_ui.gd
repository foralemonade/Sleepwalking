extends CanvasLayer
## 战斗 UI 层 v0.4
## 顶部状态栏 / 核心HP+护盾双血条 / 底部生物面板 / 战前部署 / 暂停慢速 / 治疗道具 / 治愈流技能
## v0.4 变更:
##   - 战前部署面板 (DEPLOY 阶段显示生物选择)
##   - 暂停/慢速按钮
##   - 核心HP血条 (金色, 与护盾血条并列)
##   - 治疗道具按钮 (基础/高级/紧急)
##   - 治愈流 (healing_flow) 技能按钮
##   - 生物HP/受伤状态显示
##   - 站位格位置类型标签

# ============================================================
# 顶栏元素
# ============================================================
var wave_label: Label = null
var castle_hp_bar: ProgressBar = null
var castle_hp_label: Label = null
var core_hp_bar: ProgressBar = null
var core_hp_label: Label = null
var synergy_label: Label = null
var energy_bar: ProgressBar = null
var message_label: Label = null
var gold_label: Label = null
var continent_label: Label = null
var phase_label: Label = null

# ============================================================
# 按钮
# ============================================================
var start_button: Button = null
var pause_button: Button = null
var slow_button: Button = null
var back_button: Button = null

# ============================================================
# 面板
# ============================================================
var creature_panel_container: HBoxContainer = null
var slot_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []
var heal_buttons: Array[Button] = []

# ============================================================
# 引用
# ============================================================
var castle: Castle = null
var wave_manager: WaveManager = null
var skill_system: SkillSystem = null
var battle_controller: Node2D = null

## 设置战斗控制器引用 (由 BattleController 调用)
func set_battle_controller(controller: Node2D) -> void:
	battle_controller = controller

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_gold_display()

# ============================================================
# UI 构建
# ============================================================
func _setup_ui() -> void:
	# ---- 顶部半透明栏 ----
	var top_bar: Panel = Panel.new()
	top_bar.position = Vector2(10, 10)
	top_bar.size = Vector2(1260, 90)
	top_bar.modulate = Color(0.15, 0.10, 0.25, 0.6)
	add_child(top_bar)

	# 阶段标签
	phase_label = Label.new()
	phase_label.position = Vector2(20, 5)
	phase_label.text = "[战前部署]"
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	add_child(phase_label)

	# 波次标签
	wave_label = Label.new()
	wave_label.position = Vector2(120, 5)
	wave_label.text = "准备战斗"
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(wave_label)

	# 大陆/节点名称
	continent_label = Label.new()
	continent_label.position = Vector2(20, 30)
	continent_label.add_theme_font_size_override("font_size", 12)
	continent_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	add_child(continent_label)

	# 金币
	gold_label = Label.new()
	gold_label.position = Vector2(250, 5)
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	add_child(gold_label)

	# ---- 护盾血条 (蓝色) ----
	var hp_lbl: Label = Label.new()
	hp_lbl.position = Vector2(20, 47)
	hp_lbl.text = "护盾:"
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	add_child(hp_lbl)

	castle_hp_bar = ProgressBar.new()
	castle_hp_bar.position = Vector2(70, 47)
	castle_hp_bar.size = Vector2(200, 14)
	castle_hp_bar.max_value = 100
	castle_hp_bar.value = 100
	castle_hp_bar.modulate = Color(0.55, 0.75, 1.0)
	add_child(castle_hp_bar)

	castle_hp_label = Label.new()
	castle_hp_label.position = Vector2(280, 47)
	castle_hp_label.add_theme_font_size_override("font_size", 12)
	castle_hp_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	add_child(castle_hp_label)

	# ---- 核心HP血条 (金色) ----
	var core_lbl: Label = Label.new()
	core_lbl.position = Vector2(20, 63)
	core_lbl.text = "核心:"
	core_lbl.add_theme_font_size_override("font_size", 13)
	core_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	add_child(core_lbl)

	core_hp_bar = ProgressBar.new()
	core_hp_bar.position = Vector2(70, 63)
	core_hp_bar.size = Vector2(200, 14)
	core_hp_bar.max_value = 200
	core_hp_bar.value = 200
	core_hp_bar.modulate = Color(0.95, 0.82, 0.55)
	add_child(core_hp_bar)

	core_hp_label = Label.new()
	core_hp_label.position = Vector2(280, 63)
	core_hp_label.add_theme_font_size_override("font_size", 12)
	core_hp_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	add_child(core_hp_label)

	# ---- 能量条 ----
	var en_lbl: Label = Label.new()
	en_lbl.position = Vector2(340, 47)
	en_lbl.text = "能量:"
	en_lbl.add_theme_font_size_override("font_size", 13)
	en_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72))
	add_child(en_lbl)

	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(390, 47)
	energy_bar.size = Vector2(150, 14)
	energy_bar.max_value = 100
	energy_bar.value = 50
	energy_bar.modulate = Color(0.55, 0.88, 0.72)
	add_child(energy_bar)

	# ---- 派系信息 ----
	synergy_label = Label.new()
	synergy_label.position = Vector2(560, 5)
	synergy_label.size = Vector2(350, 85)
	synergy_label.text = "派系阵容: 无"
	synergy_label.add_theme_font_size_override("font_size", 12)
	synergy_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.88))
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(synergy_label)

	# ---- 消息标签 ----
	message_label = Label.new()
	message_label.position = Vector2(400, 280)
	message_label.size = Vector2(480, 80)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(message_label)

	# ---- 右侧按钮区 ----
	# 开始战斗按钮
	start_button = Button.new()
	start_button.position = Vector2(1050, 5)
	start_button.size = Vector2(120, 40)
	start_button.text = "开始战斗"
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	# 暂停按钮
	pause_button = Button.new()
	pause_button.position = Vector2(1050, 48)
	pause_button.size = Vector2(55, 28)
	pause_button.text = "暂停"
	pause_button.add_theme_font_size_override("font_size", 10)
	pause_button.modulate = Color(0.55, 0.75, 1.0)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)

	# 慢速按钮
	slow_button = Button.new()
	slow_button.position = Vector2(1115, 48)
	slow_button.size = Vector2(55, 28)
	slow_button.text = "慢速"
	slow_button.add_theme_font_size_override("font_size", 10)
	slow_button.modulate = Color(0.95, 0.82, 0.55)
	slow_button.pressed.connect(_on_slow_pressed)
	add_child(slow_button)

	# 返回按钮
	back_button = Button.new()
	back_button.position = Vector2(10, 680)
	back_button.size = Vector2(80, 30)
	back_button.text = "< 返回"
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	# ---- 技能按钮 ----
	_create_skill_buttons()

	# ---- 治疗道具按钮 ----
	_create_heal_buttons()

	# ---- 底部面板 ----
	var bottom: Panel = Panel.new()
	bottom.position = Vector2(10, 560)
	bottom.size = Vector2(1260, 150)
	bottom.modulate = Color(0.15, 0.10, 0.25, 0.6)
	add_child(bottom)

	var panel_title: Label = Label.new()
	panel_title.position = Vector2(20, 565)
	panel_title.text = "可用生物 | 点击放置到站位格 | 空槽位点击移除"
	panel_title.add_theme_font_size_override("font_size", 14)
	panel_title.add_theme_color_override("font_color", Color(0.85, 0.80, 0.92))
	add_child(panel_title)

	# 生物选择面板
	creature_panel_container = HBoxContainer.new()
	creature_panel_container.position = Vector2(30, 595)
	creature_panel_container.add_theme_constant_override("separation", 8)
	add_child(creature_panel_container)

	_refresh_creature_buttons()

# ============================================================
# 技能按钮 — 含治愈流
# ============================================================
func _create_skill_buttons() -> void:
	skill_buttons.clear()
	var skills: Array[Dictionary] = [
		{"id":"energy_burst","name":"能量爆发","color":Color(0.95, 0.60, 0.65)},
		{"id":"shield_overload","name":"护盾过载","color":Color(0.55, 0.75, 1.0)},
		{"id":"time_freeze","name":"时间凝滞","color":Color(0.65, 0.80, 0.95)},
		{"id":"healing_flow","name":"治愈流","color":Color(0.68, 0.92, 0.82)},
	]
	for i in range(skills.size()):
		var s: Dictionary = skills[i]
		var btn: Button = Button.new()
		btn.position = Vector2(1050 + i * 55, 80)
		btn.size = Vector2(55, 30)
		btn.text = s["name"]
		btn.add_theme_font_size_override("font_size", 9)
		btn.modulate = s["color"]
		btn.pressed.connect(func(): _on_skill_pressed(s["id"]))
		add_child(btn)
		skill_buttons.append(btn)

# ============================================================
# 治疗道具按钮
# ============================================================
func _create_heal_buttons() -> void:
	heal_buttons.clear()
	var items: Array[Dictionary] = [
		{"id":"basic_heal_pack","name":"基础包","color":Color(0.68, 0.92, 0.82)},
		{"id":"advanced_heal_pack","name":"高级包","color":Color(0.55, 0.80, 0.95)},
		{"id":"emergency_heal","name":"紧急救治","color":Color(0.95, 0.60, 0.65)},
	]
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var btn: Button = Button.new()
		btn.position = Vector2(920 + i * 55, 80)
		btn.size = Vector2(55, 30)
		btn.text = it["name"]
		btn.add_theme_font_size_override("font_size", 9)
		btn.modulate = it["color"]
		btn.tooltip_text = GameData.get_item_data(it["id"]).get("desc", "")
		btn.pressed.connect(func(): _on_heal_item_pressed(it["id"]))
		add_child(btn)
		heal_buttons.append(btn)
	_update_heal_button_labels()

func _update_heal_button_labels() -> void:
	var item_ids: Array[String] = ["basic_heal_pack", "advanced_heal_pack", "emergency_heal"]
	for i in range(heal_buttons.size()):
		if i < item_ids.size():
			var count: int = GameData.healing_items.get(item_ids[i], 0)
			heal_buttons[i].text = heal_buttons[i].text.split("\n")[0] + "\n×%d" % count

# ============================================================
# 生物按钮刷新
# ============================================================
func _refresh_creature_buttons() -> void:
	for child: Node in creature_panel_container.get_children():
		child.queue_free()
	slot_buttons.clear()

	# 可用生物 (排除已死亡的)
	var available: Array[String] = GameData.get_available_creatures()
	for cid: String in available:
		var data: Dictionary = GameData.get_creature_data(cid)
		if data.is_empty():
			continue
		var hp: float = GameData.get_creature_hp(cid)
		var max_hp: float = GameData.get_creature_max_hp(cid)
		var stage: int = GameData.get_creature_injury_stage(cid)
		var stage_name: String = _get_injury_stage_short_name(stage)
		var pos_name: String = GameData.get_position_name(data.get("position_type", 0))
		var btn: Button = Button.new()
		btn.text = data["name"] + "\n[%s] %s" % [GameData.get_faction_name(data["faction"]), pos_name]
		btn.custom_minimum_size = Vector2(110, 70)
		btn.add_theme_font_size_override("font_size", 10)
		btn.modulate = GameData.get_faction_color(data["faction"])
		var tooltip: String = "HP: %d/%d (%s)\n攻:%d 速:%s\n%s" % [
			int(hp), int(max_hp), stage_name,
			data["attack"], str(data["attack_speed"]),
			data.get("skill_desc", "")
		]
		btn.tooltip_text = tooltip
		btn.pressed.connect(_on_creature_btn_pressed.bind(cid))
		creature_panel_container.add_child(btn)

	# 站位格槽位按钮
	var slot_count: int = GameData.castle_modules["creature_slots"]
	for i in range(slot_count):
		var pos_type: int = castle.get_position_type_for_index(i) if castle else 0
		var pos_name: String = GameData.get_position_name(pos_type)
		var btn: Button = Button.new()
		btn.text = "格%d [%s]\n[空]" % [i + 1, pos_name]
		btn.custom_minimum_size = Vector2(90, 70)
		btn.add_theme_font_size_override("font_size", 10)
		btn.modulate = Color(0.55, 0.50, 0.65)
		btn.tooltip_text = "站位格: %s — 点击移除生物" % pos_name
		btn.pressed.connect(_on_slot_btn_pressed.bind(i))
		creature_panel_container.add_child(btn)
		slot_buttons.append(btn)

func _get_injury_stage_short_name(stage: int) -> String:
	match stage:
		GameData.InjuryStage.HEALTHY: return "健康"
		GameData.InjuryStage.LIGHT: return "轻伤"
		GameData.InjuryStage.SEVERE: return "重伤"
		GameData.InjuryStage.DYING: return "濒死"
		GameData.InjuryStage.DEAD: return "阵亡"
		_: return "?"

# ============================================================
# 信号连接
# ============================================================
func _connect_signals() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.castle_damaged.connect(_on_castle_damaged)
	EventBus.castle_core_damaged.connect(_on_castle_core_damaged)
	EventBus.castle_destroyed.connect(_on_battle_lost)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.creature_placed.connect(_on_creature_change)
	EventBus.creature_removed.connect(_on_creature_change)
	EventBus.creature_died_in_battle.connect(_on_creature_died_update)
	EventBus.creature_resurrected.connect(_on_creature_resurrected_update)
	EventBus.creature_health_changed.connect(_on_creature_health_changed)
	EventBus.synergy_updated.connect(_on_synergy_updated)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.battle_phase_changed.connect(_on_phase_changed)
	EventBus.heal_item_used.connect(_on_heal_item_used)
	EventBus.creature_healed.connect(_on_creature_healed_update)

func setup_references(c: Castle, wm: WaveManager, ss: SkillSystem) -> void:
	castle = c
	wave_manager = wm
	skill_system = ss
	# 护盾
	castle_hp_bar.max_value = c.max_shield
	castle_hp_bar.value = c.current_shield
	castle_hp_label.text = "%d/%d" % [c.current_shield, c.max_shield]
	# 核心HP
	core_hp_bar.max_value = c.core_hp_max
	core_hp_bar.value = c.core_hp
	core_hp_label.text = "%d/%d" % [int(c.core_hp), int(c.core_hp_max)]
	# 大陆/节点显示
	if not wave_manager.node_data.is_empty():
		var nd: Dictionary = wave_manager.node_data
		continent_label.text = nd.get("name", "") + " | " + WorldMap.get_continent_name(nd.get("continent", ""))
	_refresh_creature_buttons()

# ============================================================
# 信号响应
# ============================================================
func _on_phase_changed(phase: String) -> void:
	match phase:
		"deploy":
			phase_label.text = "[战前部署]"
			phase_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
			start_button.text = "开始战斗"
			start_button.disabled = false
			pause_button.disabled = true
			slow_button.disabled = true
		"fight":
			phase_label.text = "[战斗中]"
			phase_label.add_theme_color_override("font_color", Color(0.95, 0.60, 0.65))
			start_button.text = "战斗中..."
			start_button.disabled = true
			pause_button.disabled = false
			slow_button.disabled = false
		"paused":
			phase_label.text = "[暂停]"
			phase_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
			pause_button.text = "继续"
		"slow":
			phase_label.text = "[慢速]"
			phase_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
			slow_button.text = "正常"
		"result":
			phase_label.text = "[结算]"
			phase_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.82))
			start_button.text = "再来一局"
			start_button.disabled = false
			pause_button.disabled = true
			slow_button.disabled = true

func _on_wave_started(wn: int) -> void:
	wave_label.text = "第 %d 波 - 战斗中" % wn
	_show_message("第 %d 波 开始！" % wn, 2.0)

func _on_wave_cleared(wn: int) -> void:
	wave_label.text = "第 %d 波 - 完成！" % wn

func _on_battle_won() -> void:
	wave_label.text = "战斗胜利！"
	_show_message("胜利！", 3.0)
	_award_reputation()
	_award_node_rewards()
	if wave_manager and wave_manager.battle_mode == 0:
		_auto_return_to_map()

func _on_battle_lost(_a: Variant = null) -> void:
	wave_label.text = "城堡被摧毁..."
	_show_message("失败...", 3.0)
	start_button.disabled = false
	start_button.text = "重新挑战"

func _on_castle_damaged(current: int, m: int) -> void:
	castle_hp_bar.max_value = m
	castle_hp_bar.value = current
	castle_hp_label.text = "%d/%d" % [current, m]
	var ratio: float = float(current) / float(m) if m > 0 else 0.0
	if ratio < 0.3:
		castle_hp_bar.modulate = Color(0.95, 0.50, 0.55)
	elif ratio < 0.6:
		castle_hp_bar.modulate = Color(0.95, 0.70, 0.55)
	else:
		castle_hp_bar.modulate = Color(0.55, 0.75, 1.0)

func _on_castle_core_damaged(current: float, m: float) -> void:
	core_hp_bar.max_value = m
	core_hp_bar.value = current
	core_hp_label.text = "%d/%d" % [int(current), int(m)]
	var ratio: float = current / m if m > 0.0 else 0.0
	if ratio < 0.25:
		core_hp_bar.modulate = Color(0.95, 0.40, 0.40)
	elif ratio < 0.5:
		core_hp_bar.modulate = Color(0.95, 0.65, 0.45)
	else:
		core_hp_bar.modulate = Color(0.95, 0.82, 0.55)

func _on_creature_change(_a: int = 0, _b: String = "") -> void:
	_update_slot_labels()

func _on_creature_died_update(cid: String) -> void:
	_show_message("生物阵亡: %s" % GameData.get_creature_data(cid).get("name", cid), 2.5)
	_refresh_creature_buttons()

func _on_creature_resurrected_update(cid: String) -> void:
	_show_message("生物复活: %s" % GameData.get_creature_data(cid).get("name", cid), 2.0)
	_refresh_creature_buttons()

func _on_creature_health_changed(cid: String) -> void:
	_refresh_creature_buttons()

func _on_creature_healed_update(cid: String, amount: float) -> void:
	_refresh_creature_buttons()

func _on_heal_item_used(item_id: String, target_id: String) -> void:
	_update_heal_button_labels()
	_refresh_creature_buttons()

func _on_synergy_updated(result: Dictionary) -> void:
	_update_synergy_display(result)

func _on_resource_changed(_type: String, _amt: int) -> void:
	_update_gold_display()

# ============================================================
# 显示更新
# ============================================================
func _update_synergy_display(result: Dictionary) -> void:
	if result.is_empty() or castle == null:
		synergy_label.text = "派系阵容: 无"
		return
	var ids: Array[String] = castle.current_creature_ids
	if ids.is_empty():
		synergy_label.text = "派系阵容: 无"
		return
	var text: String = "阵容: "
	for id: String in ids:
		var d: Dictionary = GameData.get_creature_data(id)
		if d.has("name"):
			text += d["name"] + " "
	text += "\n攻+" + str(int(result.get("global_attack_bonus", 0.0) * 100)) + "%"
	text += " 速+" + str(int(result.get("global_speed_bonus", 0.0) * 100)) + "%"
	var rxns: Array = result.get("cross_reactions", [])
	if not rxns.is_empty():
		text += "\n反应: "
		for r: Dictionary in rxns:
			text += r["name"] + " "
	synergy_label.text = text

func _update_slot_labels() -> void:
	if castle == null:
		return
	for i in range(min(slot_buttons.size(), castle.creature_slots.size()):
		var slot: Dictionary = castle.creature_slots[i]
		var pos_type: int = slot.get("position_type", 0)
		var pos_name: String = GameData.get_position_name(pos_type)
		if slot["creature_id"] == "":
			slot_buttons[i].text = "格%d [%s]\n[空]" % [i + 1, pos_name]
			slot_buttons[i].modulate = Color(0.55, 0.50, 0.65)
		else:
			var d: Dictionary = GameData.get_creature_data(slot["creature_id"])
			var hp_info: String = ""
			var cid: String = slot["creature_id"]
			if GameData.creature_health.has(cid):
				var hp: float = GameData.creature_health[cid]["current_hp"]
				var max_hp: float = GameData.creature_health[cid]["max_hp"]
				hp_info = " HP:%d/%d" % [int(hp), int(max_hp)]
			slot_buttons[i].text = "格%d [%s]\n%s%s" % [i + 1, pos_name, d.get("name", "???"), hp_info]
			slot_buttons[i].modulate = GameData.get_faction_color(d.get("faction", 0))

func _update_gold_display() -> void:
	gold_label.text = "金币: %d" % GameData.resources["gold"]

# ============================================================
# 按钮响应
# ============================================================
func _on_start_pressed() -> void:
	if battle_controller == null:
		# 尝试从场景树获取
		battle_controller = get_parent() as Node2D
	if battle_controller and battle_controller.has_method("start_fight"):
		battle_controller.start_fight()
	elif wave_manager:
		# 兜底: 直接启动
		wave_manager.clear_all_enemies()
		wave_manager.current_wave = -1
		wave_manager.start_battle()

func _on_pause_pressed() -> void:
	if battle_controller == null:
		battle_controller = get_parent() as Node2D
	if battle_controller and battle_controller.has_method("toggle_pause"):
		battle_controller.toggle_pause()
		if pause_button.text == "暂停":
			pause_button.text = "继续"
		else:
			pause_button.text = "暂停"

func _on_slow_pressed() -> void:
	if battle_controller == null:
		battle_controller = get_parent() as Node2D
	if battle_controller and battle_controller.has_method("toggle_slow"):
		battle_controller.toggle_slow()
		if slow_button.text == "慢速":
			slow_button.text = "正常"
		else:
			slow_button.text = "慢速"

func _on_back_pressed() -> void:
	if wave_manager and wave_manager.is_battle_active:
		wave_manager.stop_battle()
	GameData.world_progress["current_node"] = ""
	GameData.world_progress["challenge_active"] = false
	if wave_manager and wave_manager.battle_mode == 0:
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	elif wave_manager and wave_manager.battle_mode == 1:
		get_tree().change_scene_to_file("res://scenes/challenge_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_creature_btn_pressed(cid: String) -> void:
	if castle == null:
		return
	# 优先匹配位置类型的空格
	var best_slot: int = castle.find_best_slot_for_creature(cid)
	if best_slot >= 0:
		castle.place_creature(best_slot, cid)
	else:
		_show_message("槽位已满！先移除一个生物", 2.0)

func _on_slot_btn_pressed(idx: int) -> void:
	if castle == null:
		return
	# 治疗目标选择模式
	if _heal_target_mode:
		var cid: String = castle.creature_slots[idx]["creature_id"]
		if cid != "":
			if _heal_target_item_id != "":
				# 使用治疗道具
				var success: bool = GameData.use_heal_item(_heal_target_item_id, cid)
				if success:
					_show_message("使用 %s 治疗 %s" % [GameData.get_item_data(_heal_target_item_id).get("name", ""), GameData.get_creature_data(cid).get("name", cid)], 2.0)
				else:
					_show_message("无法治疗 — 阶段不匹配或道具不足", 2.0)
			else:
				# 使用治愈流技能
				if skill_system:
					var success: bool = skill_system.use_healing_flow(cid)
					if success:
						_show_message("治愈流: %s 恢复 HP" % GameData.get_creature_data(cid).get("name", cid), 2.0)
					else:
						_show_message("治愈流: 能量不足或冷却中", 2.0)
		_heal_target_mode = false
		_heal_target_item_id = ""
		return
	# 正常模式: 移除生物
	castle.remove_creature(idx)

func _on_skill_pressed(skill_id: String) -> void:
	if skill_system == null or castle == null:
		return
	# 治愈流需要选择目标生物
	if skill_id == "healing_flow":
		_show_message("治愈流: 点击受伤生物治疗", 3.0)
		_enter_heal_target_mode()
		return
	skill_system.use_skill(skill_id, wave_manager.enemy_container, castle)

func _on_heal_item_pressed(item_id: String) -> void:
	# 治疗道具需要选择目标生物
	_show_message("选择目标生物使用治疗道具", 3.0)
	_enter_heal_target_mode_with_item(item_id)

## 治愈流目标选择模式
var _heal_target_mode: bool = false
var _heal_target_item_id: String = ""

func _enter_heal_target_mode() -> void:
	_heal_target_mode = true
	_heal_target_item_id = ""

func _enter_heal_target_mode_with_item(item_id: String) -> void:
	_heal_target_mode = true
	_heal_target_item_id = item_id

# ============================================================
# 声誉/奖励
# ============================================================
func _award_reputation() -> void:
	if wave_manager == null:
		return
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
		for f: int in [GameData.Faction.TECH, GameData.Faction.FAITH, GameData.Faction.NATURE, GameData.Faction.COMMERCE, GameData.Faction.MEMORY]:
			GameData.add_reputation(f, int(amount / 2))

func _award_node_rewards() -> void:
	if wave_manager == null:
		return
	var nd: Dictionary = wave_manager.node_data
	if nd.is_empty():
		return
	var gold_reward: int = nd.get("wave_count", 4) * 25
	if nd.get("is_boss", false):
		gold_reward = 200
	GameData.add_resource("gold", gold_reward)
	_show_message("获得 %d 金币！" % gold_reward, 2.5)

func _auto_return_to_map() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		GameData.world_progress["current_node"] = ""
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	)

# ============================================================
# 每帧更新
# ============================================================
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
