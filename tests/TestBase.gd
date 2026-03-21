## 测试基类 - 提供断言方法
class_name TestBase
extends RefCounted


## 断言相等
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> String:
	if actual != expected:
		var detail := "期望 %s，实际 %s" % [str(expected), str(actual)]
		return msg + " | " + detail if msg != "" else detail
	return ""


## 断言为真
func assert_true(value: bool, msg: String = "") -> String:
	if not value:
		return msg if msg != "" else "期望为 true，实际为 false"
	return ""


## 断言为假
func assert_false(value: bool, msg: String = "") -> String:
	if value:
		return msg if msg != "" else "期望为 false，实际为 true"
	return ""


## 断言不为 null
func assert_not_null(value: Variant, msg: String = "") -> String:
	if value == null:
		return msg if msg != "" else "期望不为 null"
	return ""


## 断言为 null
func assert_null(value: Variant, msg: String = "") -> String:
	if value != null:
		return msg if msg != "" else "期望为 null，实际为 %s" % str(value)
	return ""


## 断言大于
func assert_gt(actual: Variant, threshold: Variant, msg: String = "") -> String:
	if actual <= threshold:
		var detail := "期望 > %s，实际 %s" % [str(threshold), str(actual)]
		return msg + " | " + detail if msg != "" else detail
	return ""


## 断言大于等于
func assert_gte(actual: Variant, threshold: Variant, msg: String = "") -> String:
	if actual < threshold:
		var detail := "期望 >= %s，实际 %s" % [str(threshold), str(actual)]
		return msg + " | " + detail if msg != "" else detail
	return ""


## 断言数组包含
func assert_contains(arr: Array, item: Variant, msg: String = "") -> String:
	if item not in arr:
		return msg if msg != "" else "数组不包含 %s" % str(item)
	return ""


## 断言字符串包含
func assert_str_contains(text: String, substring: String, msg: String = "") -> String:
	if substring not in text:
		return msg if msg != "" else "字符串不包含 '%s'" % substring
	return ""


## 运行多个断言，返回第一个失败的信息
func run_checks(checks: Array[String]) -> String:
	for check: String in checks:
		if check != "":
			return check
	return ""
