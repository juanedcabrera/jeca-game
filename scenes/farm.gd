extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────
const TILE_SIZE = 59  # Pixelwood Valley sprite size
const GRID_COLS = 4
const GRID_ROWS = 3
const GRID_ORIGIN = Vector2(330, 160)
const PLAYER_SPEED = 160.0

# Pixelwood Valley sprite paths
const PW_SPRITES = {
	# Player - Boy
	"boy_idle_up": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Up.png",
	"boy_idle_down": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png",
	"boy_idle_side": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Side.png",
	"boy_walk_up": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Up.png",
	"boy_walk_down": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Down.png",
	"boy_walk_side": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Side.png",
	# Player - Girl (using NPC 4 as sprite sheet)
	"girl_sprite": "res://Pixelwood Valley 1.1.2/NPCs/4.png",
	# Trees
	"tree1": "res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
	"tree2": "res://Pixelwood Valley 1.1.2/Trees/2.png",
	"tree3": "res://Pixelwood Valley 1.1.2/Trees/3.png",
	"tree4": "res://Pixelwood Valley 1.1.2/Trees/4.png",
	"tree5": "res://Pixelwood Valley 1.1.2/Trees/5.png",
	"tree6": "res://Pixelwood Valley 1.1.2/Trees/6.png",
	# Buildings
	"farmhouse":   "res://Pixelwood Valley 1.1.2/Houses/Houses/1.png",  # 84×97 brown house
	"barn":        "res://Pixelwood Valley 1.1.2/Houses/Farm/1.png",    # 100×115 red barn
	"well":        "res://Pixelwood Valley 1.1.2/Houses/Well/1.png",    # 53×63 well
	# Fence
	"fence_h":    "res://Pixelwood Valley 1.1.2/Wooden/3.png",   # 58×45 horizontal panel
	"fence_post": "res://Pixelwood Valley 1.1.2/Wooden/2.png",   # 20×45 vertical post
}

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _player: CharacterBody2D
var _player_drawer: Node2D
var _hud_coins: Label
var _hud_day: Label
var _hud_tool: Label
var _action_popup: Control
var _action_label: Label
var _farm_tile_drawers: Array = []

# ── State ─────────────────────────────────────────────────────────────────────
var _current_tool: String = "hand"   # hand | water_jug | seeds
var _selected_seed: String = "sunflower_seeds"
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_tile: int = -1
var _near_zone: String = ""
var _transitioning: bool = false

const TOOL_ICONS = {
	"hand": "✋ Hand",
	"water_jug": "💧 Water Jug",
	"sunflower_seeds": "🌻 Sunflower Seeds",
	"carrot_seeds": "🥕 Carrot Seeds",
	"strawberry_seeds": "🍓 Strawberry Seeds",
}

const CROP_COLORS = {
	"sunflower_seeds": Color(1.0, 0.85, 0.1),
	"carrot_seeds": Color(0.95, 0.55, 0.1),
	"strawberry_seeds": Color(0.9, 0.2, 0.3),
}

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	_build_tool_bar()
	_place_player_at_spawn()
	PlayerData.coins_changed.connect(_on_coins_changed)
	_refresh_hud()

# ── World building ─────────────────────────────────────────────────────────────

func _build_world() -> void:
	# Sky
	var sky = ColorRect.new()
	sky.color = Color(0.62, 0.84, 0.98)
	sky.size = Vector2(960, 130)
	add_child(sky)

	# Grass background — bright green field
	var grass_bg = ColorRect.new()
	grass_bg.color = Color(0.40, 0.72, 0.25)
	grass_bg.size = Vector2(960, 410)
	grass_bg.position = Vector2(0, 62)
	add_child(grass_bg)

	# Path (dirt paths between areas)
	var path_drawer = _PathDrawer.new()
	path_drawer.position = Vector2.ZERO
	add_child(path_drawer)

	# Farm plot dirt background
	var plot_bg = ColorRect.new()
	plot_bg.color = Color(0.50, 0.36, 0.20)
	plot_bg.size = Vector2(GRID_COLS * TILE_SIZE + 20, GRID_ROWS * TILE_SIZE + 20)
	plot_bg.position = GRID_ORIGIN - Vector2(10, 10)
	add_child(plot_bg)

	# Farm tile drawers
	for i in range(GRID_COLS * GRID_ROWS):
		var col = i % GRID_COLS
		var row = i / GRID_COLS as int
		var tile_pos = GRID_ORIGIN + Vector2(col * TILE_SIZE, row * TILE_SIZE)
		var td = FarmTileDrawer.new()
		td.position = tile_pos
		td.tile_index = i
		add_child(td)
		_farm_tile_drawers.append(td)

	# House (farmhouse sprite)
	var house = _HouseDrawer.new()
	house.position = Vector2(50, 120)
	add_child(house)

	# Barn (red barn — sits above and behind the animal pen)
	var barn_spr = Sprite2D.new()
	barn_spr.texture = load(PW_SPRITES["barn"])
	barn_spr.scale = Vector2(2.2, 2.2)   # 100×115 → 220×253
	barn_spr.position = Vector2(790, 268) # center; top-left ≈ (680, 141)
	add_child(barn_spr)

	# Animal pen (sits below barn)
	var pen = _AnimalPenDrawer.new()
	pen.position = Vector2(690, 350)
	add_child(pen)

	# Well (decorative, between house and farm plot)
	var well_spr = Sprite2D.new()
	well_spr.texture = load(PW_SPRITES["well"])
	well_spr.scale = Vector2(2.5, 2.5)   # 53×63 → 133×158
	well_spr.position = Vector2(258, 295) # center
	add_child(well_spr)

	# Trees scattered
	var tree_positions = [Vector2(20, 240), Vector2(20, 370), Vector2(900, 175),
						   Vector2(900, 300), Vector2(900, 420), Vector2(580, 430)]
	for tp in tree_positions:
		var tree = _TreeDrawer.new()
		tree.position = tp
		add_child(tree)

	# Wooden fence border
	var fence = _WoodFenceDrawer.new()
	fence.position = Vector2.ZERO
	add_child(fence)

	# Decorative direction signs (non-clickable — walk into the paths to travel)
	var signs = _DirectionSigns.new()
	signs.position = Vector2.ZERO
	add_child(signs)

	# Action ribbon — fixed bottom HUD strip above the tool bar
	_action_popup = Control.new()
	_action_popup.visible = false
	_action_popup.position = Vector2(0, 456)
	_action_popup.z_index = 10
	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0.05, 0.03, 0.0, 0.90)
	popup_bg.size = Vector2(960, 42)
	popup_bg.position = Vector2.ZERO
	_action_popup.add_child(popup_bg)

	_action_label = Label.new()
	_action_label.add_theme_font_size_override("font_size", 18)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.position = Vector2(0, 8)
	_action_label.size = Vector2(960, 28)
	_action_popup.add_child(_action_label)
	add_child(_action_popup)


# ── Player ─────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 2

	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12
	shape.height = 20
	col.shape = shape
	col.position = Vector2(0, 6)
	_player.add_child(col)

	_player_drawer = PlayerDrawer.new()
	_player_drawer.gender = PlayerData.player_gender
	_player.add_child(_player_drawer)

	var name_lbl = Label.new()
	name_lbl.text = PlayerData.player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.position = Vector2(-50, -52)
	name_lbl.size = Vector2(100, 24)
	_player.add_child(name_lbl)

	add_child(_player)
	_setup_walls()

func _setup_walls() -> void:
	# Top wall with gap for Math Mines path (x 400-560)
	_add_wall(Vector2(0,   60), Vector2(400, 14))
	_add_wall(Vector2(560, 60), Vector2(400, 14))
	# Bottom wall with gap for Juarez Market path (x 400-560)
	_add_wall(Vector2(0,   526), Vector2(400, 14))
	_add_wall(Vector2(560, 526), Vector2(400, 14))
	# Left wall — solid
	_add_wall(Vector2(0, 60), Vector2(14, 480))
	# Right wall with gap for Literacy Library path (y 230-370)
	_add_wall(Vector2(946, 60),  Vector2(14, 170))
	_add_wall(Vector2(946, 370), Vector2(14, 170))
	# House collision box (farmhouse 185×213 at position 50,120)
	_add_wall(Vector2(50, 130), Vector2(185, 160))
	# Barn collision box (220×253 centered at 790,268 → top-left ≈ 680,141)
	_add_wall(Vector2(682, 145), Vector2(216, 180))
	# Well collision (small blocker)
	_add_wall(Vector2(228, 268), Vector2(60, 56))

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall = StaticBody2D.new()
	wall.collision_layer = 2
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = pos + size * 0.5
	wall.add_child(col)
	add_child(wall)

func _place_player_at_spawn() -> void:
	_player.position = GameManager.get_farm_spawn()

# ── HUD ────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	hud_bg.size = Vector2(960, 52)
	hud_bg.position = Vector2(0, 0)
	add_child(hud_bg)

	_hud_coins = GameManager.make_label("💰 Coins: 10", Vector2(12, 10), 20, Color(1.0, 0.9, 0.2))
	add_child(_hud_coins)

	_hud_day = GameManager.make_label("Day 1", Vector2(420, 10), 20, Color(0.9, 0.95, 0.8))
	add_child(_hud_day)

	_hud_tool = GameManager.make_label("✋ Hand", Vector2(700, 10), 18, Color(0.8, 0.95, 0.8))
	add_child(_hud_tool)

	# E key hint
	var hint = GameManager.make_label("[E] Interact", Vector2(330, 58), 14, Color(0.8, 0.8, 0.6))
	add_child(hint)

func _build_tool_bar() -> void:
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.08, 0.05, 0.02, 0.80)
	bar_bg.size = Vector2(960, 38)
	bar_bg.position = Vector2(0, 502)
	add_child(bar_bg)

	var tools = [
		["hand", "✋ Hand", Color(0.35, 0.28, 0.18)],
		["water_jug", "💧 Water", Color(0.18, 0.35, 0.6)],
		["sunflower_seeds", "🌻 Sunflower", Color(0.5, 0.42, 0.08)],
		["carrot_seeds", "🥕 Carrot", Color(0.5, 0.28, 0.05)],
		["strawberry_seeds", "🍓 Berry", Color(0.5, 0.12, 0.18)],
	]
	for i in range(tools.size()):
		var t = tools[i]
		var btn = GameManager.make_button(t[1], Vector2(8 + i * 192, 505), Vector2(185, 30), t[2])
		btn.add_theme_font_size_override("font_size", 13)
		var tool_id = t[0]
		btn.pressed.connect(func(): _set_tool(tool_id))
		add_child(btn)

func _refresh_hud() -> void:
	_hud_coins.text = "💰 Coins: %d" % PlayerData.coins
	_hud_day.text = "Day %d" % PlayerData.day
	_hud_tool.text = TOOL_ICONS.get(_current_tool, _current_tool)

func _on_coins_changed(_val: int) -> void:
	_refresh_hud()

func _set_tool(tool_id: String) -> void:
	# Check if player has this tool/seeds
	if tool_id in ["sunflower_seeds", "carrot_seeds", "strawberry_seeds"]:
		if not PlayerData.has_item(tool_id):
			GameManager.show_message(self, "You don't have %s! Buy some at\nthe Juarez Market." % tool_id.replace("_", " "))
			return
		_selected_seed = tool_id
	if tool_id == "water_jug" and not PlayerData.has_item("water_jug"):
		GameManager.show_message(self, "You need a Water Jug!\nBuy one at the Juarez Market.")
		return
	_current_tool = tool_id
	_refresh_hud()

# ── Input & Movement ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameManager.show_pause_menu(self)

func _physics_process(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
		_facing = "up"
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
		_facing = "down"
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
		_facing = "left"
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
		_facing = "right"

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		_walk_frame += delta * 8.0
	else:
		_walk_frame = 0.0

	_player.velocity = dir * PLAYER_SPEED
	_player.move_and_slide()

	if _player_drawer:
		_player_drawer.facing = _facing
		_player_drawer.walk_frame = _walk_frame
		_player_drawer.queue_redraw()

	_check_exit_zones()
	_check_nearby()
	_update_action_popup()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_1:
			_set_tool("hand")
		elif event.keycode == KEY_2:
			_set_tool("water_jug")
		elif event.keycode == KEY_3:
			_set_tool("sunflower_seeds")
		elif event.keycode == KEY_4:
			_set_tool("carrot_seeds")
		elif event.keycode == KEY_5:
			_set_tool("strawberry_seeds")

func _check_exit_zones() -> void:
	if _transitioning:
		return
	var p = _player.position
	# North path → Math Mines  (walk above y=72, in x corridor 390–570)
	if p.y < 72 and p.x > 390 and p.x < 570:
		_transitioning = true
		GameManager.change_scene("math_mines")
		return
	# South path → Juarez Market  (walk below y=520, in x corridor 390–570)
	if p.y > 520 and p.x > 390 and p.x < 570:
		_transitioning = true
		GameManager.change_scene("juarez_market")
		return
	# East path → Literacy Library  (walk past x=950, in y corridor 220–380)
	if p.x > 950 and p.y > 220 and p.y < 380:
		_transitioning = true
		GameManager.change_scene("literacy_library")
		return

func _check_nearby() -> void:
	_near_tile = -1
	_near_zone = ""

	# Check farm tiles
	for i in range(PlayerData.farm_tiles.size()):
		var col = i % GRID_COLS
		var row = i / GRID_COLS as int
		var tile_center = GRID_ORIGIN + Vector2(col * TILE_SIZE + TILE_SIZE * 0.5, row * TILE_SIZE + TILE_SIZE * 0.5)
		if _player.position.distance_to(tile_center) < TILE_SIZE * 0.85:
			_near_tile = i
			return

	# Check zones (house, pen)
	# house_door = front of farmhouse sprite at (50,120) scale 2.2× (185×213) → door ≈ (143, 320)
	var house_door = Vector2(143, 320)
	if _player.position.distance_to(house_door) < 110:
		_near_zone = "house"
		return

	var pen_center = Vector2(790, 400)
	if _player.position.distance_to(pen_center) < 120:
		_near_zone = "pen"

func _update_action_popup() -> void:
	if _near_tile >= 0:
		_action_popup.visible = true
		var tile = PlayerData.farm_tiles[_near_tile]
		var state = tile["state"]
		match state:
			"empty":
				_action_label.text = "[E] Till soil with hand"
			"tilled":
				if _current_tool in ["sunflower_seeds", "carrot_seeds", "strawberry_seeds"]:
					_action_label.text = "[E] Plant %s" % _current_tool.replace("_seeds", "").capitalize()
				else:
					_action_label.text = "[E] Select seeds to plant"
			"planted":
				if tile["watered"]:
					_action_label.text = "Already watered today!"
				else:
					_action_label.text = "[E] Water this crop"
			"ready":
				_action_label.text = "[E] Harvest!"
	elif _near_zone == "pen":
		_action_popup.visible = true
		_action_label.text = "[E] Tend animals"
	elif _near_zone == "house":
		_action_popup.visible = true
		_action_label.text = "[E] Enter House"
	else:
		_action_popup.visible = false

func _interact() -> void:
	if _near_tile >= 0:
		_interact_with_tile(_near_tile)
	elif _near_zone == "pen":
		_tend_animals()
	elif _near_zone == "house":
		if not _transitioning:
			_transitioning = true
			GameManager.change_scene("house_interior")

func _interact_with_tile(idx: int) -> void:
	var tile = PlayerData.farm_tiles[idx]
	match tile["state"]:
		"empty":
			tile["state"] = "tilled"
			_refresh_tile_drawer(idx)
			GameManager.show_message(self, "Soil tilled! Now plant seeds.", 1.5)
		"tilled":
			if _current_tool in ["sunflower_seeds", "carrot_seeds", "strawberry_seeds"]:
				if PlayerData.plant_seed(idx, _current_tool):
					_refresh_tile_drawer(idx)
					GameManager.show_message(self, "Planted %s!" % _current_tool.replace("_", " "), 1.5)
				else:
					GameManager.show_message(self, "No seeds! Buy some at\nthe Juarez Market.", 2.0)
			else:
				GameManager.show_message(self, "Select your seeds first! (Keys 3-5)", 1.8)
		"planted":
			if _current_tool == "water_jug" or PlayerData.has_item("water_jug"):
				if PlayerData.water_tile(idx):
					_refresh_tile_drawer(idx)
					GameManager.show_message(self, "Watered! 💧 Come back tomorrow.", 1.5)
				else:
					GameManager.show_message(self, "Already watered today!", 1.2)
			else:
				GameManager.show_message(self, "You need a Water Jug!\nBuy one at the market.", 2.0)
		"ready":
			var crop = PlayerData.harvest_tile(idx)
			if crop != "":
				_refresh_tile_drawer(idx)
				var rewards = {"sunflower_seeds": 8, "carrot_seeds": 5, "strawberry_seeds": 12}
				GameManager.show_message(self, "🎉 Harvested! +%d coins!" % rewards.get(crop, 5), 2.0)

func _refresh_tile_drawer(idx: int) -> void:
	if idx < _farm_tile_drawers.size():
		_farm_tile_drawers[idx].queue_redraw()

func _tend_animals() -> void:
	if PlayerData.animals.is_empty():
		GameManager.show_message(self, "No animals yet! Buy some at\nthe Juarez Market.", 2.0)
	else:
		for animal in PlayerData.animals:
			animal["happiness"] = min(10, animal.get("happiness", 5) + 1)
		PlayerData.add_coins(PlayerData.animals.size() * 2)
		GameManager.show_message(self, "Animals tended! +%d coins 🐄" % (PlayerData.animals.size() * 2), 2.0)

func _advance_day() -> void:
	PlayerData.advance_day()
	PlayerData.save_game()
	_refresh_hud()
	# Refresh all tile drawers
	for td in _farm_tile_drawers:
		td.queue_redraw()
	GameManager.show_message(self, "💤 Good night! Day %d begins." % PlayerData.day, 2.5)


# ── Tile Drawer ────────────────────────────────────────────────────────────────

class FarmTileDrawer extends Node2D:
	var tile_index: int = 0
	var _farmland_tex = preload("res://Cute_Fantasy_Free/Tiles/FarmLand_Tile.png")

	func _draw() -> void:
		if tile_index >= PlayerData.farm_tiles.size():
			return
		var tile = PlayerData.farm_tiles[tile_index]
		var state = tile.get("state", "empty")
		var sz = Vector2(62, 62)

		match state:
			"empty":
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0.52, 0.38, 0.22))
			"tilled":
				draw_texture_rect(_farmland_tex, Rect2(Vector2.ZERO, sz), false)
				for row in range(4):
					draw_line(Vector2(2, 8 + row * 15), Vector2(60, 8 + row * 15), Color(0.28, 0.18, 0.08), 1)
			"planted", "ready":
				var watered = tile.get("watered", false)
				var tint = Color(0.75, 0.9, 1.0) if watered else Color.WHITE
				draw_texture_rect(_farmland_tex, Rect2(Vector2.ZERO, sz), false, tint)
				var growth = tile.get("growth", 0)
				var max_g = tile.get("max_growth", 3)
				var crop = tile.get("crop_type", "")
				var progress = float(growth) / float(max(max_g, 1))
				_draw_crop(state, crop, progress, watered)

	func _draw_crop(state: String, crop: String, progress: float, watered: bool) -> void:
		var center_x = 31.0
		var crop_colors = {
			"sunflower_seeds": Color(1.0, 0.85, 0.1),
			"carrot_seeds": Color(0.95, 0.55, 0.1),
			"strawberry_seeds": Color(0.9, 0.2, 0.3),
		}
		var color = crop_colors.get(crop, Color(0.4, 0.8, 0.2))

		if state == "ready":
			# Full plant — big and glowing
			draw_line(Vector2(center_x, 58), Vector2(center_x, 22), Color(0.3, 0.65, 0.2), 4)
			draw_circle(Vector2(center_x, 16), 16, color)
			draw_circle(Vector2(center_x, 16), 8, color.darkened(0.3))
			# Sparkle
			draw_circle(Vector2(center_x - 18, 16), 4, Color(1, 1, 0.6, 0.8))
			draw_circle(Vector2(center_x + 18, 16), 4, Color(1, 1, 0.6, 0.8))
		elif progress > 0.5:
			# Growing well
			draw_line(Vector2(center_x, 58), Vector2(center_x, 32), Color(0.3, 0.65, 0.2), 3)
			draw_circle(Vector2(center_x, 26), 10, color)
			# Leaf
			draw_line(Vector2(center_x, 44), Vector2(center_x - 10, 36), Color(0.3, 0.65, 0.2), 2)
		else:
			# Small sprout
			draw_line(Vector2(center_x, 58), Vector2(center_x, 44), Color(0.3, 0.65, 0.2), 2)
			draw_circle(Vector2(center_x, 40), 5, color)

		if watered:
			draw_circle(Vector2(8, 52), 3, Color(0.4, 0.7, 1.0, 0.7))
			draw_circle(Vector2(54, 52), 3, Color(0.4, 0.7, 1.0, 0.7))


# ── Player Drawer ──────────────────────────────────────────────────────────────

class PlayerDrawer extends Node2D:
	var gender: String = "boy"
	var facing: String = "down"
	var walk_frame: float = 0.0
	var _sprite: Sprite2D
	var _last_tex_key: String = ""

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.hframes = 4
		_sprite.frame = 0
		_sprite.texture = load(PW_SPRITES["boy_idle_down"])
		_last_tex_key = "boy_idle_down"
		if gender == "girl":
			_sprite.modulate = Color(1.05, 0.78, 0.92)
		add_child(_sprite)

	func _process(_delta: float) -> void:
		if not _sprite:
			return
		var is_moving = walk_frame > 0
		var tex_key: String
		match facing:
			"up":
				tex_key = "boy_walk_up" if is_moving else "boy_idle_up"
			"left", "right":
				tex_key = "boy_walk_side" if is_moving else "boy_idle_side"
			_:
				tex_key = "boy_walk_down" if is_moving else "boy_idle_down"
		if tex_key != _last_tex_key:
			_sprite.texture = load(PW_SPRITES[tex_key])
			_sprite.hframes = 4
			_last_tex_key = tex_key
		_sprite.flip_h = (facing == "left")
		_sprite.frame = int(walk_frame * 4) % 4 if is_moving else 0

	func _draw() -> void:
		pass


# ── World Drawers ──────────────────────────────────────────────────────────────

class _HouseDrawer extends Node2D:
	func _ready() -> void:
		var spr = Sprite2D.new()
		spr.texture = load(PW_SPRITES["farmhouse"])  # 84×97 brown farmhouse
		spr.scale = Vector2(2.2, 2.2)                # → 185×213
		spr.position = Vector2(92, 107)              # center → sprite fills (0,0)-(185,213)
		add_child(spr)

	func _draw() -> void:
		pass


class _AnimalPenDrawer extends Node2D:
	var _animal_sprites: Array = []
	const _TEXTURES = {
		"chicken": "res://Cute_Fantasy_Free/Animals/Chicken/Chicken.png",
		"cow":     "res://Cute_Fantasy_Free/Animals/Cow/Cow.png",
		"pig":     "res://Cute_Fantasy_Free/Animals/Pig/Pig.png",
	}

	func _ready() -> void:
		for i in range(3):
			var spr = Sprite2D.new()
			spr.hframes = 2
			spr.vframes = 2
			spr.frame = 0
			spr.scale = Vector2(0.9, 0.9)
			spr.position = Vector2(40 + i * 60, 55)
			spr.visible = false
			_animal_sprites.append(spr)
			add_child(spr)

	func _process(_delta: float) -> void:
		for i in range(3):
			var spr = _animal_sprites[i]
			if i < PlayerData.animals.size():
				var atype = PlayerData.animals[i].get("type", "chicken")
				spr.texture = load(_TEXTURES.get(atype, _TEXTURES["chicken"]))
				spr.visible = true
			else:
				spr.visible = false

	func _draw() -> void:
		# Pen ground (straw/dirt floor in front of barn)
		draw_rect(Rect2(0, 0, 200, 100), Color(0.62, 0.52, 0.32))
		# Simple front fence rails
		draw_rect(Rect2(0, 0, 200, 5), Color(0.48, 0.30, 0.12))
		draw_rect(Rect2(0, 34, 200, 5), Color(0.48, 0.30, 0.12))
		draw_rect(Rect2(0, 68, 200, 5), Color(0.48, 0.30, 0.12))
		# Fence posts
		for i in range(6):
			draw_rect(Rect2(i * 40, -4, 8, 110), Color(0.42, 0.26, 0.10))
		# Water trough
		draw_rect(Rect2(22, 76, 76, 18), Color(0.42, 0.26, 0.10))
		draw_rect(Rect2(25, 79, 70, 12), Color(0.32, 0.58, 0.78))


class _TreeDrawer extends Node2D:
	var _tree_variants = ["tree1", "tree2", "tree3", "tree4", "tree5", "tree6"]
	
	func _ready() -> void:
		var spr = Sprite2D.new()
		# Pick a random tree variant
		var tree_key = _tree_variants[randi() % _tree_variants.size()]
		spr.texture = load(PW_SPRITES[tree_key])
		spr.position = Vector2(0, -30)  # Adjusted for tree sprite anchor
		add_child(spr)

	func _draw() -> void:
		pass


class _WoodFenceDrawer extends Node2D:
	var _fence_h    = preload("res://Pixelwood Valley 1.1.2/Wooden/3.png")  # 58×45 horizontal
	var _fence_post = preload("res://Pixelwood Valley 1.1.2/Wooden/2.png")  # 20×45 vertical post

	func _draw() -> void:
		var fw = 58; var fh = 28   # display size for horizontal panel
		var pw = 20; var ph = 45   # display size for vertical post

		# ── Top fence (y=62) — gap x 430–530 for Mines path ──
		var x = 0
		while x < 430:
			draw_texture_rect(_fence_h, Rect2(x, 62, fw, fh), false)
			x += fw
		x = 536  # resume after path gap, aligned to panel width
		while x < 960:
			draw_texture_rect(_fence_h, Rect2(x, 62, fw, fh), false)
			x += fw

		# ── Bottom fence (y=502) — gap x 430–530 for Market path ──
		x = 0
		while x < 430:
			draw_texture_rect(_fence_h, Rect2(x, 502, fw, fh), false)
			x += fw
		x = 536
		while x < 960:
			draw_texture_rect(_fence_h, Rect2(x, 502, fw, fh), false)
			x += fw

		# ── Left fence (x=0) — solid ──
		var y = 62
		while y < 504:
			draw_texture_rect(_fence_post, Rect2(0, y, pw, ph), false)
			y += ph

		# ── Right fence (x=940) — gap y 230–370 for Library path ──
		y = 62
		while y < 230:
			draw_texture_rect(_fence_post, Rect2(940, y, pw, ph), false)
			y += ph
		y = 370
		while y < 504:
			draw_texture_rect(_fence_post, Rect2(940, y, pw, ph), false)
			y += ph


class _PathDrawer extends Node2D:
	func _draw() -> void:
		var dirt = Color(0.6, 0.48, 0.3)
		# Path to top (Math Mines)
		draw_rect(Rect2(440, 62, 80, 100), dirt)
		# Path to right (Library)
		draw_rect(Rect2(850, 240, 110, 60), dirt)
		# Path to bottom (Market)
		draw_rect(Rect2(440, 440, 80, 70), dirt)
		# Path to house
		draw_rect(Rect2(240, 290, 90, 40), dirt)


class _DirectionSigns extends Node2D:
	func _draw() -> void:
		var post  = Color(0.45, 0.28, 0.10)
		var plank = Color(0.62, 0.42, 0.18)
		var txt   = Color(0.15, 0.08, 0.02)

		# North sign (Math Mines) — top center path
		_draw_sign(Vector2(480, 116), "⛏ Math Mines", post, plank, txt)
		# South sign (Juarez Market) — bottom center path
		_draw_sign(Vector2(480, 448), "🏪 Market", post, plank, txt)
		# East sign (Literacy Library) — right path
		_draw_sign(Vector2(890, 300), "📚 Library", post, plank, txt)

	func _draw_sign(pos: Vector2, label: String, post: Color, plank: Color, txt: Color) -> void:
		# Post
		draw_rect(Rect2(pos + Vector2(-3, -4), Vector2(6, 30)), post)
		# Plank
		draw_rect(Rect2(pos + Vector2(-46, -20), Vector2(92, 20)), plank)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-42, -6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, txt)
