extends Node
## 无限挑战模式 - Roguelike 随机化框架

class_name ChallengeManager

signal challenge_started()
signal challenge_ended(score: int)
signal card_options_generated(cards: Array)

var current_challenge_wave: int = 0
var max_challenge_waves: int = 20
var challenge_score: int = 0
var is_challenge_active: bool = false
var active_cards: Array[Dictionary] = []

# Roguelike 卡牌池
var card_pool: Array[Dictionary] = []

func _ready():
	_init_card_pool()

func _init_card_pool():
	card_pool = [
		{"id":"resonance_amp","name":"派系共鸣增幅","desc":"派系协同伤害 +30%","icon":"star"},
		{"id":"iron_wall","name":"城堡铁壁","desc":"城堡护盾上限 +50%","icon":"shield"},
		{"id":"berserk","name":"生物狂暴","desc":"所有生物攻速 +25%，防御 -15%","icon":"sword"},
		{"id":"reinforcements","name":"召唤援军","desc":"每波结束后召唤一只随机生物","icon":"plus"},
		{"id":"crit_chance","name":"弱点感知","desc":"所有生物 15% 概率暴击（2x）","icon":"target"},
		{"id":"gold_rush","name":"淘金热","desc":"击杀敌人金币 +100%","icon":"coin"},
		{"id":"healing_aura","name":"治愈光环","desc":"城堡每秒恢复 2 护盾","icon":"heart"},
		{"id":"slow_field","name":"减速力场","desc":"所有敌人移速 -15%","icon":"clock"},
		{"id":"extra_slot","name":"额外槽位","desc":"城堡生物槽位 +1","icon":"grid"},
		{"id":"poison_blade","name":"淬毒","desc":"所有生物攻击附带中毒","icon":"skull"},
		{"id":"double_energy","name":"能量翻倍","desc":"能量恢复速度 +100%","icon":"bolt"},
		{"id":"last_stand","name":"背水一战","desc":"城堡护盾低于 30% 时攻速 +50%","icon":"fire"},
	]

func start_challenge():
	current_challenge_wave = 0
	challenge_score = 0
	active_cards.clear()
	is_challenge_active = true
	EventBus.challenge_started.emit()
	challenge_started.emit()

func end_challenge():
	is_challenge_active = false
	EventBus.challenge_ended.emit(challenge_score)
	challenge_ended.emit(challenge_score)

func generate_card_options(count: int = 3) -> Array:
	var pool = card_pool.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

func select_card(card_data: Dictionary):
	active_cards.append(card_data)
	EventBus.challenge_card_selected.emit(card_data["id"])
	# 应用卡片效果到全局状态
	_apply_card(card_data)

func _apply_card(card: Dictionary):
	match card["id"]:
		"iron_wall": GameData.castle_modules["defense"] += 50
		"extra_slot": GameData.castle_modules["creature_slots"] += 1

func add_score(points: int):
	challenge_score += points

func get_active_card_bonus(stat: String) -> float:
	var bonus: float = 0.0
	for card in active_cards:
		match card["id"]:
			"resonance_amp": if stat=="synergy": bonus+=0.30
			"berserk": if stat=="speed": bonus+=0.25
			"crit_chance": if stat=="crit": bonus+=0.15
			"gold_rush": if stat=="gold": bonus+=1.0
			"healing_aura": if stat=="regen": bonus+=2.0
			"slow_field": if stat=="slow": bonus+=0.15
			"double_energy": if stat=="energy": bonus+=1.0
			"poison_blade": if stat=="poison": bonus+=1.0
	return bonus
