extends Node
## 梦游症 - 全局事件总线 (Autoload) v0.4
## 解耦各系统间通信
## v0.4 变更: 加生物生死/治疗/站位格/战斗阶段/暂停信号

# ── 战斗事件 ──
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal battle_won()
signal battle_lost()
signal battle_started()
signal enemy_killed(enemy_type: String, position: Vector2)
signal enemy_reached_end(enemy: Node2D)
signal enemy_spawned(enemy: Node2D)

# ── 战斗阶段 ──
signal battle_phase_changed(phase: String)  # "deploy" / "fight" / "pause" / "slow"
signal wave_pause_started()                 # 波次间喘息开始
signal wave_pause_ended()                   # 波次间喘息结束

# ── 城堡事件 ──
signal castle_damaged(current_hp: int, max_hp: int)
signal castle_core_damaged(current_hp: float, max_hp: float)  # 城堡核心HP
signal castle_destroyed()
signal creature_placed(slot_index: int, creature_id: String)
signal creature_removed(slot_index: int)
signal synergy_updated(result: Dictionary)

# ── 生物生死事件 ──
signal creature_injured(creature_id: String, stage: int)     # 受伤阶段变化
signal creature_died_in_battle(creature_id: String)           # 战斗中死亡
signal creature_healed(creature_id: String, amount: float)    # 生物被治疗
signal creature_resurrected(creature_id: String)              # 复活仪式完成
signal creature_health_changed(creature_id: String, current: float, max: float)

# ── 技能事件 ──
signal skill_used(skill_id: String)
signal energy_changed(current: float, max_energy: float)

# ── 治疗事件 ──
signal heal_item_used(item_id: String, target_id: String)    # 使用治疗道具
signal heal_skill_used(target_id: String, amount: float)     # 治愈流技能

# ── 资源事件 ──
signal resource_changed(resource: String, amount: int)
signal creature_acquired(creature_id: String)
signal module_acquired(module_id: String)

# ── 好感度事件 ──
signal reputation_changed(faction: int, value: int)

# ── 大地图事件 ──
signal node_unlocked(node_id: String)
signal node_completed(node_id: String)
signal node_entered(node_id: String)

# ── 挑战模式事件 ──
signal challenge_started()
signal challenge_ended(score: int)
signal challenge_card_selected(card_id: String)
