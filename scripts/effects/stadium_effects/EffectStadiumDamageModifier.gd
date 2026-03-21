## Stadium modifier for attack or defense damage.
class_name EffectStadiumDamageModifier
extends BaseEffect

var modifier_amount: int = 0
var modifier_type: String = "attack"
var pokemon_filter: String = ""
var owner_only: bool = false


func _init(amount: int = 0, type: String = "attack", filter: String = "", owner: bool = false) -> void:
	modifier_amount = amount
	modifier_type = type
	pokemon_filter = filter
	owner_only = owner


func matches_pokemon(slot: PokemonSlot) -> bool:
	if pokemon_filter == "":
		return true
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	match pokemon_filter:
		"Basic":
			return cd.stage == "Basic"
		"evolved":
			return cd.stage in ["Stage 1", "Stage 2"]
		"ex":
			return cd.mechanic == "ex"
		"R", "W", "G", "L", "P", "F", "D", "M", "N", "C":
			return cd.energy_type == pokemon_filter
		_:
			return true


func is_attack_modifier() -> bool:
	return modifier_type == "attack"


func is_defense_modifier() -> bool:
	return modifier_type == "defense"


func get_description() -> String:
	var filter_map := {
		"Basic": "Basic Pokemon",
		"evolved": "Evolved Pokemon",
		"ex": "Pokemon ex",
		"R": "Fire Pokemon",
		"W": "Water Pokemon",
		"G": "Grass Pokemon",
		"L": "Lightning Pokemon",
		"P": "Psychic Pokemon",
		"F": "Fighting Pokemon",
		"D": "Darkness Pokemon",
		"M": "Metal Pokemon",
		"N": "Dragon Pokemon",
		"C": "Colorless Pokemon",
	}
	var filter_str: String = ""
	if pokemon_filter != "":
		filter_str = "%s " % filter_map.get(pokemon_filter, pokemon_filter)
	var type_str: String = "attack damage" if modifier_type == "attack" else "damage taken"
	var sign: String = "+" if modifier_amount > 0 else ""
	return "Stadium: %s%s%s%d" % [filter_str, type_str, sign, modifier_amount]
