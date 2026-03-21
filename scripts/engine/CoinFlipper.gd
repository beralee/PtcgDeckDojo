## 投币系统 - 处理所有需要投币判定的游戏操作
class_name CoinFlipper
extends RefCounted

## 投币完成信号，result: true=正面, false=反面
signal coin_flipped(result: bool)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## 投一次硬币，返回 true=正面, false=反面
func flip() -> bool:
	var result: bool = _rng.randi_range(0, 1) == 1
	coin_flipped.emit(result)
	return result


## 投多次硬币，返回结果数组
func flip_multiple(count: int) -> Array[bool]:
	var results: Array[bool] = []
	for i: int in count:
		results.append(flip())
	return results


## 统计多次投币中正面的数量
func count_heads(results: Array[bool]) -> int:
	var count := 0
	for r: bool in results:
		if r:
			count += 1
	return count


## 投币直到出现反面，返回正面次数（用于"投币直到反面"类招式）
func flip_until_tails() -> int:
	var heads := 0
	while flip():
		heads += 1
	return heads
