extends Node2D
class_name Castle
## 移动城堡 v0.4 — 站位格系统 + 城堡核心HP + 双层护盾
## v0.4 变更:
##   - core_hp / core_hp_max: 特殊敌人攻击核心HP, 核心HP=0 城堡毁灭
##   - take_core_damage(): 供特殊敌人调用
##   - 站位格按 PositionType 分组: FRONT/BACK/SIDE/CORE
##   - 动态槽位数量 via castle_modules["creature_slots"]
##   - 信号: shield_changed, core_hp_changed, castle_destroyed, castle_core_destroyed
##   - 核心HP血条视觉显示

# ============================================================
# 信号
# ============================================================
signal shield_changed(current: int, max_hp: int)
signal core_hp_changed(current: float, max_hp: float)
signal castle_destroyed()       # 护盾归零 (旧逻辑保留)
signal castle_core_destroyed()  # 核心HP归零 = 真正毁灭

# ============================================================
# 护盾系统 (外层 — 普通敌人到达终点扣除)
# ============================================================
@export var max_shield: int = 100
var current_shield: int = 100
var shield_regen: float = 0.0

# ============================================================
# 核心HP系统 (内层 — 特殊敌人直攻核心)
# ============================================================
var core_hp: float = 200.0
var core_hp_max: float = 200.0

# ============================================================
# 站位格系统
# ============================================================
@export var slot_count: int = 4
var creature_slots: Array[Dictionary] = []
var slot_positions: Array[Vector2] = []
var current_creature_ids: Array[String] = []

var synergy_system: Node = null
var enemy_container: Node = null

# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	current_shield = max_shield
	_init_core_hp()
	_init_slots()
	_init_synergy()
	_draw_castle()
	_draw_core_hp_bar()

func _init_core_hp() -> void:
	core_hp_max = float(GameData.castle_modules.get("core_hp_max", 200))
	core_hp = float(GameData.castle_modules.get("core_hp", core_hp_max))

func _init_slots() -> void:
	slot_count = GameData.castle_modules["creature_slots"]
	# 站位格布局 — 按 PositionType 分组
	# FRONT (前排) — 城堡前方近战位
	# BACK  (后排) — 城堡后方远程位
	# SIDE  (侧翼) — 城堡左右侧位
	# CORE  (核心) — 城堡正中核心位
	slot_positions = [
		# 前排 2 格
		Vector2(-60, -95), Vector2(60, -95),
		# 后排 2 格
		Vector2(-50, -30), Vector2(50, -30),
		# 侧翼 2 格 (超出 slot_count 时启用)
		Vector2(-110, -60), Vector2(110, -60),
		# 核心 2 格 (超出 slot_count+2 时启用)
		Vector2(-20, 10), Vector2(20, 10),
	]
	# 按 slot_count 动态生成槽位
	creature_slots.clear()
	for i in range(slot_count):
		var pos: Vector2 = Vector2.ZERO
		if i < slot_positions.size():
			pos = slot_positions[i]
		var pos_type: int = _get_position_type_for_index(i)
		creature_slots.append({
			"creature": null,
			"creature_id": "",
			"position": pos,
			"position_type": pos_type,
		})

## 根据槽位索引推断 PositionType
func get_position_type_for_index(idx: int) -> int:
	# 0-1: FRONT, 2-3: BACK, 4-5: SIDE, 6-7: CORE
	if idx < 2:
		return GameData.PositionType.FRONT
	elif idx < 4:
		return GameData.PositionType.BACK
	elif idx < 6:
		return GameData.PositionType.SIDE
	else:
		return GameData.PositionType.CORE

func _init_synergy() -> void:
	var synergy_script: GDScript = load("res://scripts/systems/faction_synergy.gd")
	synergy_system = synergy_script.new()
	synergy_system.name = "FactionSynergyCalculator"
	add_child(synergy_system)

# ============================================================
# 每帧更新 — 护盾恢复 + 挑战模式加成
# ============================================================
func _process(delta: float) -> void:
	var total_regen: float = shield_regen
	# 挑战模式: 治愈光环加成
	if GameData.world_progress.get("challenge_active", false):
		total_regen += _get_challenge_regen_bonus()
	# 背水一战: 低护盾时额外恢复
	if GameData.world_progress.get("challenge_active", false) and current_shield < max_shield * 0.3:
		total_regen += 1.0

	if total_regen > 0.0 and current_shield < max_shield:
		var new_shield: float = float(current_shield) + total_regen * delta
		if new_shield > float(max_shield):
			new_shield = float(max_shield)
		current_shield = int(new_shield)
		shield_changed.emit(current_shield, max_shield)

# ============================================================
# 城堡绘制
# ============================================================
func _draw_castle() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	var s: int = 160
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(10, 30, s - 20, s - 40), Color(0.45, 0.40, 0.65))
	img.fill_rect(Rect2i(20, 10, s - 40, 25), Color(0.55, 0.50, 0.72))
	# 窗户
	var win_positions: Array[int] = [30, 70, 110]
	for wx: int in win_positions:
		img.fill_rect(Rect2i(wx, 50, 20, 20), Color(0.75, 0.75, 1.0, 0.8))
	# 门
	img.fill_rect(Rect2i(65, 100, 30, 50), Color(0.35, 0.28, 0.50))
	# 装饰
	img.fill_rect(Rect2i(10, 130, 30, 20), Color(0.40, 0.35, 0.45))
	img.fill_rect(Rect2i(120, 130, 30, 20), Color(0.40, 0.35, 0.45))
	var tex: ImageTexture = ImageTexture.new()
	tex.set_image(img)
	sprite.texture = tex
	sprite.position = Vector2(float(-s) / 2.0, float(-s) / 2.0)
	add_child(sprite)
	# 站位格位置标记
	_draw_slot_markers()

func _draw_slot_markers() -> void:
	# 每个站位格位置画一个小指示点 + 位置类型标签
	for i in range(creature_slots.size()):
		var slot: Dictionary = creature_slots[i]
		var pos: Vector2 = slot["position"]
		var pos_type: int = slot["position_type"]
		var pos_name: String = GameData.get_position_name(pos_type)
		# 圆点标记
		var marker: ColorRect = ColorRect.new()
		marker.position = pos + Vector2(-6, -6)
		marker.size = Vector2(12, 12)
		marker.color = _get_position_color(pos_type)
		marker.modulate = Color(1.0, 1.0, 1.0, 0.6)
		add_child(marker)
		# 标签
		var label: Label = Label.new()
		label.position = pos + Vector2(-15, -20)
		label.text = pos_name
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", _get_position_color(pos_type))
		add_child(label)

func _get_position_color(pt: int) -> Color:
	match pt:
		GameData.PositionType.FRONT:
			return Color(0.95, 0.60, 0.55)  # 红 — 前线
		GameData.PositionType.BACK:
			return Color(0.55, 0.80, 0.95)  # 蓝 — 后方
		GameData.PositionType.SIDE:
			return Color(0.68, 0.92, 0.82)  # 绿 — 侧翼
		GameData.PositionType.CORE:
			return Color(0.95, 0.82, 0.55)  # 金 — 核心
		_:
			return Color.GRAY

# ============================================================
# 核心HP血条 (城堡上方第二行)
# ============================================================
var _core_hp_bar_bg: ColorRect = null
var _core_hp_bar_fg: ColorRect = null
var _core_hp_label: Label = null

func _draw_core_hp_bar() -> void:
	# 背景
	_core_hp_bar_bg = ColorRect.new()
	_core_hp_bar_bg.position = Vector2(-70, -130)
	_core_hp_bar_bg.size = Vector2(140, 10)
	_core_hp_bar_bg.color = Color(0.20, 0.15, 0.30)
	add_child(_core_hp_bar_bg)
	# 前景 (当前HP)
	_core_hp_bar_fg = ColorRect.new()
	_core_hp_bar_fg.position = Vector2(-70, -130)
	_core_hp_bar_fg.size = Vector2(140, 10)
	_core_hp_bar_fg.color = Color(0.95, 0.82, 0.55)  # 金色核心
	add_child(_core_hp_bar_fg)
	# 标签
	_core_hp_label = Label.new()
	_core_hp_label.position = Vector2(-70, -145)
	_core_hp_label.text = "核心: %d/%d" % [int(core_hp), int(core_hp_max)]
	_core_hp_label.add_theme_font_size_override("font_size", 11)
	_core_hp_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	add_child(_core_hp_label)
	update_core_hp_bar()

func update_core_hp_bar() -> void:
	if _core_hp_bar_fg == null:
		return
	var ratio: float = core_hp / core_hp_max if core_hp_max > 0.0 else 0.0
	_core_hp_bar_fg.size.x = 140.0 * ratio
	# 低HP变红
	if ratio < 0.25:
		_core_hp_bar_fg.color = Color(0.95, 0.40, 0.40)
	elif ratio < 0.50:
		_core_hp_bar_fg.color = Color(0.95, 0.65, 0.45)
	else:
		_core_hp_bar_fg.color = Color(0.95, 0.82, 0.55)
	if _core_hp_label:
		_core_hp_label.text = "核心: %d/%d" % [int(core_hp), int(core_hp_max)]

# ============================================================
# 护盾受伤 (普通敌人到达终点)
# ============================================================
func take_damage(amount: int) -> void:
	var actual: int = amount
	if actual < 1:
		actual = 1
	current_shield = current_shield - actual
	if current_shield < 0:
		current_shield = 0
	shield_changed.emit(current_shield, max_shield)
	EventBus.castle_damaged.emit(current_shield, max_shield)
	if current_shield <= 0:
		castle_destroyed.emit()
		EventBus.castle_destroyed.emit()

# ============================================================
# 核心HP受伤 (特殊敌人直攻核心)
# ============================================================
func take_core_damage(amount: float) -> void:
	core_hp = maxf(0.0, core_hp - amount)
	core_hp_changed.emit(core_hp, core_hp_max)
	EventBus.castle_core_damaged.emit(core_hp, core_hp_max)
	update_core_hp_bar()
	if core_hp <= 0.0:
		castle_core_destroyed.emit()
		EventBus.castle_destroyed.emit()  # 核心毁灭 = 城堡毁灭

# ============================================================
# 生物放置 / 移除
# ============================================================
func place_creature(slot_index: int, creature_id: String) -> bool:
	if slot_index < 0 or slot_index >= creature_slots.size():
		return false
	var slot: Dictionary = creature_slots[slot_index]
	if slot["creature"] != null:
		remove_creature(slot_index)
	var data: Dictionary = GameData.get_creature_data(creature_id)
	if data.is_empty():
		return false
	var creature_scene: PackedScene = load("res://scenes/creature.tscn")
	if creature_scene == null:
		return false
	var c: Node2D = creature_scene.instantiate()
	c.setup(data)
	c.position = slot["position"]
	c.set_enemy_container(enemy_container)
	# 设置 creature_container = self, 使治疗型生物能找到友方
	if c.has_method("set_creature_container"):
		c.set_creature_container(self)
	add_child(c)
	slot["creature"] = c
	slot["creature_id"] = creature_id
	refresh_creature_ids()
	recalculate_synergies()
	EventBus.creature_placed.emit(slot_index, creature_id)
	return true

func remove_creature(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= creature_slots.size():
		return false
	var slot: Dictionary = creature_slots[slot_index]
	if slot["creature"] != null:
		slot["creature"].queue_free()
		slot["creature"] = null
		slot["creature_id"] = ""
		_refresh_creature_ids()
		_recalculate_synergies()
		EventBus.creature_removed.emit(slot_index)
		return true
	return false

func refresh_creature_ids() -> void:
	current_creature_ids.clear()
	for slot: Dictionary in creature_slots:
		if slot["creature_id"] != "" and slot["creature_id"] != null:
			current_creature_ids.append(slot["creature_id"])

func recalculate_synergies() -> void:
	var result: Dictionary = synergy_system.analyze_synergies(current_creature_ids)
	shield_regen = result.get("castle_regen", 0.0)
	for slot: Dictionary in creature_slots:
		if slot["creature"] != null:
			var c: Node2D = slot["creature"]
			c.apply_synergy_effects(result)
	EventBus.synergy_updated.emit(result)

# ============================================================
# 查询
# ============================================================
func get_placed_creatures() -> Array[Node]:
	var r: Array[Node] = []
	for slot: Dictionary in creature_slots:
		if slot["creature"] != null:
			r.append(slot["creature"])
	return r

## 获取指定位置类型的所有空槽位索引
func get_empty_slots_by_position_type(pos_type: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(creature_slots.size()):
		if creature_slots[i]["position_type"] == pos_type and creature_slots[i]["creature_id"] == "":
			result.append(i)
	return result

## 获取所有空槽位索引
func get_all_empty_slots() -> Array[int]:
	var result: Array[int] = []
	for i in range(creature_slots.size()):
		if creature_slots[i]["creature_id"] == "":
			result.append(i)
	return result

## 查找生物适合的空槽位 (按 position_type 优先匹配)
func find_best_slot_for_creature(creature_id: String) -> int:
	var data: Dictionary = GameData.get_creature_data(creature_id)
	if data.is_empty():
		return -1
	var preferred_type: int = data.get("position_type", GameData.PositionType.FRONT)
	# 优先放入匹配位置类型的空格
	var preferred: Array[int] = get_empty_slots_by_position_type(preferred_type)
	if not preferred.is_empty():
		return preferred[0]
	# 没有匹配位置 → 放入任意空格
	var all_empty: Array[int] = get_all_empty_slots()
	if not all_empty.is_empty():
		return all_empty[0]
	return -1

func set_enemy_container(container: Node) -> void:
	enemy_container = container

func _get_challenge_regen_bonus() -> float:
	var parent: Node = get_parent()
	while parent:
		if parent.has_node("ChallengeManager"):
			var cm: Node = parent.get_node("ChallengeManager")
			if cm.has_method("get_active_card_bonus"):
				return cm.get_active_card_bonus("regen")
			break
		parent = parent.get_parent()
	return 0.0

# ============================================================
# 重置 (战斗开始时)
# ============================================================
func reset_for_battle() -> void:
	current_shield = max_shield
	core_hp = core_hp_max
	update_core_hp_bar()
	shield_changed.emit(current_shield, max_shield)
	core_hp_changed.emit(core_hp, core_hp_max)
