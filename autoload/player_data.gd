extends Node

# Active save slot (0, 1, or 2)
var current_slot: int = 0

# Player identity
var player_name: String = "Friend"
var player_gender: String = "boy"  # "boy" or "girl"

# Economy
var coins: int = 10

# Inventory: item_id -> quantity
var inventory: Dictionary = {
	"water_jug": 1,
	"sunflower_seeds": 0,
	"carrot_seeds": 0,
	"strawberry_seeds": 0,
	"fertilizer": 0,
	"sprinkler": 0,
}

# Farm tiles: array of dicts with keys: state, crop_type, growth, watered
# state: "empty" | "tilled" | "planted" | "ready"
var farm_tiles: Array = []

# Animals: array of dicts with keys: type, name, happiness
var animals: Array = []

# Progress
var day: int = 1
var math_problems_solved: int = 0
var words_read: int = 0
var game_started: bool = false
var intro_seen: bool = false

signal coins_changed(new_amount: int)
signal inventory_changed()
signal day_advanced(new_day: int)

func _ready() -> void:
	_init_farm_tiles()

func _init_farm_tiles() -> void:
	farm_tiles.clear()
	for i in range(12):  # 4x3 grid
		farm_tiles.append({
			"state": "empty",
			"crop_type": "",
			"growth": 0,
			"watered": false,
			"max_growth": 3,
		})

# Reset all data to fresh-game defaults (call before starting a new game)
func reset() -> void:
	player_name = "Friend"
	player_gender = "boy"
	coins = 10
	inventory = {
		"water_jug": 1,
		"sunflower_seeds": 0,
		"carrot_seeds": 0,
		"strawberry_seeds": 0,
		"fertilizer": 0,
		"sprinkler": 0,
	}
	animals = []
	day = 1
	math_problems_solved = 0
	words_read = 0
	game_started = false
	intro_seen = false
	_init_farm_tiles()

# ── Economy ───────────────────────────────────────────────────────────────────

func add_coins(amount: int) -> void:
	coins += amount
	emit_signal("coins_changed", coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		emit_signal("coins_changed", coins)
		return true
	return false

func add_item(item_id: String, quantity: int = 1) -> void:
	if item_id in inventory:
		inventory[item_id] += quantity
	else:
		inventory[item_id] = quantity
	emit_signal("inventory_changed")

func use_item(item_id: String) -> bool:
	if item_id in inventory and inventory[item_id] > 0:
		inventory[item_id] -= 1
		emit_signal("inventory_changed")
		return true
	return false

func has_item(item_id: String) -> bool:
	return item_id in inventory and inventory[item_id] > 0

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func advance_day() -> void:
	day += 1
	# Grow all planted crops
	for tile in farm_tiles:
		if tile["state"] == "planted":
			if tile["watered"]:
				tile["growth"] += 1
				if tile["growth"] >= tile["max_growth"]:
					tile["state"] = "ready"
			tile["watered"] = false
	emit_signal("day_advanced", day)

func plant_seed(tile_index: int, seed_type: String) -> bool:
	if tile_index >= farm_tiles.size():
		return false
	var tile = farm_tiles[tile_index]
	if tile["state"] != "tilled":
		return false
	if not has_item(seed_type):
		return false
	use_item(seed_type)
	tile["state"] = "planted"
	tile["crop_type"] = seed_type
	tile["growth"] = 0
	tile["watered"] = false
	var grow_times = {"sunflower_seeds": 2, "carrot_seeds": 3, "strawberry_seeds": 4}
	tile["max_growth"] = grow_times.get(seed_type, 3)
	return true

func water_tile(tile_index: int) -> bool:
	if tile_index >= farm_tiles.size():
		return false
	var tile = farm_tiles[tile_index]
	if tile["state"] == "planted":
		tile["watered"] = true
		return true
	return false

func harvest_tile(tile_index: int) -> String:
	if tile_index >= farm_tiles.size():
		return ""
	var tile = farm_tiles[tile_index]
	if tile["state"] != "ready":
		return ""
	var crop = tile["crop_type"]
	tile["state"] = "tilled"
	tile["crop_type"] = ""
	tile["growth"] = 0
	tile["watered"] = false
	var rewards = {"sunflower_seeds": 8, "carrot_seeds": 5, "strawberry_seeds": 12}
	add_coins(rewards.get(crop, 5))
	return crop

func add_animal(animal_type: String) -> void:
	animals.append({
		"type": animal_type,
		"happiness": 5,
	})

# ── Save / Load ───────────────────────────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return "user://cabrera_save_%d.json" % slot

func save_game() -> void:
	var data = {
		"player_name": player_name,
		"player_gender": player_gender,
		"coins": coins,
		"inventory": inventory,
		"farm_tiles": farm_tiles,
		"animals": animals,
		"day": day,
		"math_problems_solved": math_problems_solved,
		"words_read": words_read,
		"intro_seen": intro_seen,
	}
	# Local save (instant, works offline)
	var file = FileAccess.open(_slot_path(current_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	# Cloud save (async fire-and-forget — safe to skip if offline)
	Supabase.push_slot(current_slot, data)

func load_game() -> bool:
	return load_slot(current_slot)

func load_slot(slot: int) -> bool:
	if not FileAccess.file_exists(_slot_path(slot)):
		return false
	var file = FileAccess.open(_slot_path(slot), FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null:
		return false
	current_slot = slot
	player_name = data.get("player_name", "Friend")
	player_gender = data.get("player_gender", "boy")
	coins = data.get("coins", 10)
	inventory = data.get("inventory", inventory)
	farm_tiles = data.get("farm_tiles", farm_tiles)
	animals = data.get("animals", [])
	day = data.get("day", 1)
	math_problems_solved = data.get("math_problems_solved", 0)
	words_read = data.get("words_read", 0)
	intro_seen = data.get("intro_seen", false)
	game_started = true
	return true

# Returns a lightweight preview dict for a slot without loading it into memory.
# Keys: "exists", "player_name", "player_gender", "day", "coins"
func read_slot_preview(slot: int) -> Dictionary:
	var path = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"exists": false}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return {"exists": false}
	return {
		"exists": true,
		"player_name": data.get("player_name", "Friend"),
		"player_gender": data.get("player_gender", "boy"),
		"day": data.get("day", 1),
		"coins": data.get("coins", 10),
	}

func delete_slot(slot: int) -> void:
	var path = _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
