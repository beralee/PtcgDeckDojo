## 效果覆盖率统计工具 - 分析卡组中有多少卡牌效果已被实现
## 用法: 在任意脚本中调用 EffectCoverageReport.generate(deck_data, effect_processor)
class_name EffectCoverageReport
extends RefCounted

## 统计结果
var total_unique_cards: int = 0
var covered_cards: int = 0
var uncovered_cards: int = 0
var coverage_percent: float = 0.0

## 基础能量（不需要效果实现）
var basic_energy_count: int = 0
## 没有 effect_id 的卡（行为由引擎处理）
var no_effect_id_count: int = 0

## 详细信息
var covered_list: Array[Dictionary] = []     ## [{name, effect_id, card_type}]
var uncovered_list: Array[Dictionary] = []   ## [{name, effect_id, card_type, description}]


## 分析单个卡组的效果覆盖率
static func generate(deck_data: DeckData, proc: EffectProcessor) -> EffectCoverageReport:
	var report := EffectCoverageReport.new()
	var seen_effect_ids: Dictionary = {}  ## effect_id -> {name, card_type, description, count}

	for entry: Dictionary in deck_data.cards:
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var count: int = entry.get("count", 1)
		var card_data: CardData = CardDatabase.get_card(set_code, card_index)
		if card_data == null:
			continue

		# 基础能量不需要效果实现
		if card_data.card_type == "Basic Energy":
			report.basic_energy_count += count
			continue

		var eid: String = card_data.effect_id
		# 没有 effect_id 的宝可梦（纯数值卡，无特殊效果）
		if eid == "":
			report.no_effect_id_count += count
			continue

		# 避免重复统计同 effect_id
		if seen_effect_ids.has(eid):
			seen_effect_ids[eid]["count"] += count
			continue

		seen_effect_ids[eid] = {
			"name": card_data.name,
			"card_type": card_data.card_type,
			"description": card_data.description,
			"effect_id": eid,
			"count": count,
		}

	# 统计覆盖情况
	report.total_unique_cards = seen_effect_ids.size()
	for eid: String in seen_effect_ids:
		var info: Dictionary = seen_effect_ids[eid]
		if proc.has_effect(eid) or proc.has_attack_effect(eid):
			report.covered_cards += 1
			report.covered_list.append({
				"name": info["name"],
				"effect_id": eid,
				"card_type": info["card_type"],
				"count": info["count"],
			})
		else:
			report.uncovered_cards += 1
			report.uncovered_list.append({
				"name": info["name"],
				"effect_id": eid,
				"card_type": info["card_type"],
				"description": info["description"],
				"count": info["count"],
			})

	if report.total_unique_cards > 0:
		report.coverage_percent = float(report.covered_cards) / float(report.total_unique_cards) * 100.0

	return report


## 分析多个卡组的合并覆盖率
static func generate_multi(decks: Array[DeckData], proc: EffectProcessor) -> EffectCoverageReport:
	var report := EffectCoverageReport.new()
	var seen_effect_ids: Dictionary = {}

	for deck_data: DeckData in decks:
		for entry: Dictionary in deck_data.cards:
			var set_code: String = entry.get("set_code", "")
			var card_index: String = entry.get("card_index", "")
			var count: int = entry.get("count", 1)
			var card_data: CardData = CardDatabase.get_card(set_code, card_index)
			if card_data == null:
				continue
			if card_data.card_type == "Basic Energy":
				report.basic_energy_count += count
				continue
			var eid: String = card_data.effect_id
			if eid == "":
				report.no_effect_id_count += count
				continue
			if seen_effect_ids.has(eid):
				seen_effect_ids[eid]["count"] += count
				continue
			seen_effect_ids[eid] = {
				"name": card_data.name,
				"card_type": card_data.card_type,
				"description": card_data.description,
				"effect_id": eid,
				"count": count,
			}

	report.total_unique_cards = seen_effect_ids.size()
	for eid: String in seen_effect_ids:
		var info: Dictionary = seen_effect_ids[eid]
		if proc.has_effect(eid) or proc.has_attack_effect(eid):
			report.covered_cards += 1
			report.covered_list.append({
				"name": info["name"],
				"effect_id": eid,
				"card_type": info["card_type"],
				"count": info["count"],
			})
		else:
			report.uncovered_cards += 1
			report.uncovered_list.append({
				"name": info["name"],
				"effect_id": eid,
				"card_type": info["card_type"],
				"description": info["description"],
				"count": info["count"],
			})

	if report.total_unique_cards > 0:
		report.coverage_percent = float(report.covered_cards) / float(report.total_unique_cards) * 100.0

	return report


## 生成文本报告
func to_string_report() -> String:
	var lines: Array[String] = []
	lines.append("===== 效果覆盖率报告 =====")
	lines.append("需实现效果的卡牌种类: %d" % total_unique_cards)
	lines.append("已实现: %d | 未实现: %d" % [covered_cards, uncovered_cards])
	lines.append("覆盖率: %.1f%%" % coverage_percent)
	lines.append("基础能量（无需实现）: %d 张" % basic_energy_count)
	lines.append("无 effect_id（纯数值卡）: %d 张" % no_effect_id_count)

	if not uncovered_list.is_empty():
		lines.append("")
		lines.append("--- 未实现效果列表 ---")
		for info: Dictionary in uncovered_list:
			var desc: String = info.get("description", "")
			var desc_preview: String = desc.substr(0, 60) + "..." if desc.length() > 60 else desc
			lines.append("  [%s] %s (effect_id=%s, x%d)" % [
				info["card_type"], info["name"], info["effect_id"], info["count"]])
			if desc_preview != "":
				lines.append("    效果: %s" % desc_preview)

	if not covered_list.is_empty():
		lines.append("")
		lines.append("--- 已实现效果列表 ---")
		for info: Dictionary in covered_list:
			lines.append("  [%s] %s (effect_id=%s, x%d)" % [
				info["card_type"], info["name"], info["effect_id"], info["count"]])

	return "\n".join(lines)
