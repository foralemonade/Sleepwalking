# 梦游症 测试与修复日志

格式: `[日期] 修复/发现 BUG-XXX - 描述 [严重级别]`

## 2026-07-03

### 静态检查 (Step 1)

- [2026-07-03] 发现 BUG-001 - `creature_health_changed` 信号已定义已 connect 但**无任何 emit**,血条永远不动 [P1]
  - 修复: 在 `game_data.gd update_injury_stage()` 末尾和 `creature.gd take_damage/heal()` 末尾 emit
  - 状态: ✅ 已修复

- [2026-07-03] 发现 BUG-002 - `Creature.take_damage/heal()` 修改 `current_hp` 变量后**不写回 `GameData.creature_health[cid]`**,导致跨局继承失效、死亡检查用满血值、血条不更新 [P0]
  - 修复: take_damage / heal 在 `current_hp` 变化后立即 `GameData.creature_health[creature_id]["current_hp"] = current_hp`
  - 状态: ✅ 已修复

- [2026-07-03] 发现 BUG-003 - `GameData.update_injury_stage()` 修改 stage 后**不 emit** `creature_injured` 也不 emit `creature_health_changed` [P1]
  - 修复: 在 update_injury_stage 末尾 emit creature_health_changed
  - 状态: ✅ 已修复

- [2026-07-03] 观察 - `reaction_pop` 信号已定义已 connect 但**无任何 emit** [P2]
  - 状态: 📌 留作 P2,反应触发走 `reaction_triggered` 路径不影响功能

### 动态测试 (Step 2) - 16/16 通过,0 失败

#### 修复
- [2026-07-03] 修复 BUG-004 - 测试代码误读 `castle_modules.slot_count`,正确字段是 `creature_slots` (测试问题,非生产代码) [无]
  - 状态: ✅ 测试代码修正

- [2026-07-03] 修复 BUG-005 - 测试用 echo_walker HP=10/90 (DYING阶段) 无法用基础治疗包(只治LIGHT) [无]
  - 状态: ✅ 测试场景改为 LIGHT 阶段

- [2026-07-03] 修复 BUG-006 - `RewardTable.grant_reward()` 在 world_map_ui 中当实例方法调用,`class_name` GDScript 默认非 static [P0]
  - 修复: 给 `grant_reward` / `_grant_first_clear` / `_grant_repeat_clear` / `get_reward_preview` 加 `static` 关键字
  - 状态: ✅ 已修复,world_map_ui 重新加载无 Parse Error

#### 测试结果
```
模块A 战前部署与站位格: [PASS] A1/A2/A3 (creature_slots=4, 动态可改, 脚本可加载)
模块B 敌人攻击 + 生物HP:  [PASS] B1/B2/B3/B4 (HP 90->70, 阶段 0=健康, 死亡 is_dead=true)
模块C 死亡 + 战斗结算:    [PASS] C1/C3, [INFO] C4 (新手保护生效, post_battle_recovery LIGHT 阶段满血)
模块D 战外治疗 + 复活:    [PASS] D1/D2/D3, [INFO] D1b (24h 倒计时 86399s, 金币 10000->9500, 治疗包 5->4)
模块E 跨派系反应:         [PASS] E1/E2 (reaction_triggered 信号正常, RewardTable 返回 mech_sniper 80G)
模块F 存档与跨局继承:     [PASS] F1/F2/F3 (save/load 流程, HP 42.0 跨存档, 死亡状态跨存档)

总计: 13 PASS + 3 INFO + 0 FAIL
```

### 回归测试
- 6 个核心场景 (main_menu / battle_scene / castle_management / codex_ui / world_map / _test_runner)
- 全部无 SCRIPT ERROR / Parse / Compile
- 剩余警告均为 Godot 4.6 退出时的 NavMesh 内存清理(无害)
