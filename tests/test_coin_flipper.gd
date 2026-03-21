## 投币系统测试
class_name TestCoinFlipper
extends TestBase


func test_flip_returns_bool() -> String:
	var flipper := CoinFlipper.new()
	var result: Variant = flipper.flip()
	return run_checks([
		assert_eq(result is bool, true, "flip() 返回 bool 类型"),
	])


func test_flip_multiple_count() -> String:
	var flipper := CoinFlipper.new()
	var results: Array[bool] = flipper.flip_multiple(5)
	return run_checks([
		assert_eq(results.size(), 5, "flip_multiple(5) 返回5个结果"),
	])


func test_count_heads() -> String:
	var flipper := CoinFlipper.new()
	var results: Array[bool] = [true, false, true, true, false]
	return run_checks([
		assert_eq(flipper.count_heads(results), 3, "3个正面"),
	])


func test_flip_until_tails_returns_non_negative() -> String:
	var flipper := CoinFlipper.new()
	var heads: int = flipper.flip_until_tails()
	return run_checks([
		assert_eq(heads >= 0, true, "flip_until_tails 返回非负数"),
	])


func test_coin_flipped_signal() -> String:
	var flipper := CoinFlipper.new()
	var signal_fired := false
	flipper.coin_flipped.connect(func(_r: bool) -> void: signal_fired = true)
	flipper.flip()
	return run_checks([
		assert_eq(signal_fired, true, "flip() 触发 coin_flipped 信号"),
	])
