class_name EffectTempleOfSinnoh
extends BaseEffect


func suppresses_special_energy_effects() -> bool:
	return true


func get_description() -> String:
	return "All Special Energy provide only 1 Colorless Energy and lose their effects."
