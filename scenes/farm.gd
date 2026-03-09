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
	# Fence (Cute Fantasy Free)
	"fence":      "res://Cute_Fantasy_Free/Outdoor decoration/Fences.png",  # 64×64 fence panel
	# Grass tile
	"grass":      "res://Cute_Fantasy_Free/Tiles/Grass_Middle.png",         # 16×16 grass tile
}

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _player: CharacterBody2D
var _player_drawer: Node2D
var _hud_coins: Label
var _hud_day: Label
var _action_popup: Control
var _action_label: Label
var _inventory_panel: Control
var _inventory_tool_buttons: Array = []
var _farm_tile_drawers: Array = []

# ── State ─────────────────────────────────────────────────────────────────────
var _current_tool: String = "hand"   # hand | water_jug | seeds
var _selected_seed: String = "sunflower_seeds"
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_tile: int = -1
var _near_zone: String = ""
var _transitioning: bool = false
var _inventory_open: bool = false

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

	# Grass background — tiled grass texture
	var grass_drawer = _GrassDrawer.new()
	grass_drawer.position = Vector2(0, 62)
	add_child(grass_drawer)

	# Path (dirt paths between areas)
	var path_drawer = _PathDrawer.new()
	path_drawer.position = Vector2.ZERO
	add_child(path_drawer)

	# Farm plot background with border
	var plot_drawer = _FarmPlotDrawer.new()
	plot_drawer.position = GRID_ORIGIN - Vector2(14, 14)
	add_child(plot_drawer)

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

	# Animal pen (sits below barn — added first so barn renders on top)
	var pen = _AnimalPenDrawer.new()
	pen.position = Vector2(690, 390)
	add_child(pen)

	# Barn (red barn — sits above and behind the animal pen)
	var barn_spr = Sprite2D.new()
	barn_spr.texture = load(PW_SPRITES["barn"])
	barn_spr.scale = Vector2(2.2, 2.2)   # 100×115 → 220×253
	barn_spr.position = Vector2(790, 268) # center; top-left ≈ (680, 141)
	add_child(barn_spr)

	# Well (decorative, between house and farm plot)
	var well_spr = Sprite2D.new()
	well_spr.texture = load(PW_SPRITES["well"])
	well_spr.scale = Vector2(2.5, 2.5)   # 53×63 → 133×158
	well_spr.position = Vector2(258, 295) # center
	add_child(well_spr)

	# Trees scattered (kept away from fence borders)
	var tree_positions = [Vector2(55, 240), Vector2(55, 390), Vector2(630, 430)]
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

	# Action prompt — compact centered bubble
	_action_popup = Control.new()
	_action_popup.visible = false
	_action_popup.z_index = 10

	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0.05, 0.03, 0.0, 0.85)
	popup_bg.size = Vector2(260, 34)
	popup_bg.position = Vector2(350, 496)
	_action_popup.add_child(popup_bg)

	# Border accent
	var popup_border = ColorRect.new()
	popup_border.color = Color(0.55, 0.40, 0.18, 0.7)
	popup_border.size = Vector2(262, 36)
	popup_border.position = Vector2(349, 495)
	_action_popup.add_child(popup_border)
	_action_popup.move_child(popup_border, 0)

	_action_label = Label.new()
	_action_label.add_theme_font_size_override("font_size", 15)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.position = Vector2(350, 502)
	_action_label.size = Vector2(260, 24)
	_action_popup.add_child(_action_label)
	add_child(_action_popup)


# ── Player ─────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 2

	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 18
	shape.height = 30
	col.shape = shape
	col.position = Vector2(0, 10)
	_player.add_child(col)

	_player_drawer = PlayerDrawer.new()
	_player_drawer.gender = PlayerData.player_gender
	_player_drawer.scale = Vector2(1.8, 1.8)
	_player.add_child(_player_drawer)

	var name_lbl = Label.new()
	name_lbl.text = PlayerData.player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.position = Vector2(-50, -72)
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
	# ── Top-right status panel ──
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.05, 0.02, 0.75)
	hud_bg.size = Vector2(150, 52)
	hud_bg.position = Vector2(806, 4)
	hud_bg.z_index = 10
	add_child(hud_bg)

	# Rounded border effect
	var hud_border = ColorRect.new()
	hud_border.color = Color(0.55, 0.40, 0.18, 0.6)
	hud_border.size = Vector2(152, 54)
	hud_border.position = Vector2(805, 3)
	hud_border.z_index = 9
	add_child(hud_border)

	_hud_coins = GameManager.make_label("💰 %d" % PlayerData.coins, Vector2(814, 6), 15, Color(1.0, 0.9, 0.2))
	_hud_coins.z_index = 11
	add_child(_hud_coins)

	_hud_day = GameManager.make_label("Day %d" % PlayerData.day, Vector2(814, 28), 14, Color(0.85, 0.9, 0.75))
	_hud_day.z_index = 11
	add_child(_hud_day)

	# ── Inventory chest button (below status panel) ──
	var chest_btn = GameManager.make_button("🧰 [I]", Vector2(836, 62), Vector2(90, 30), Color(0.45, 0.30, 0.12))
	chest_btn.add_theme_font_size_override("font_size", 13)
	chest_btn.z_index = 11
	chest_btn.pressed.connect(_toggle_inventory)
	add_child(chest_btn)

func _build_tool_bar() -> void:
	# ── Inventory panel (hidden by default) ──
	_inventory_panel = Control.new()
	_inventory_panel.visible = false
	_inventory_panel.z_index = 50

	# Dim overlay
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(960, 540)
	_inventory_panel.add_child(dim)

	# Panel border (behind panel)
	var panel_border = ColorRect.new()
	panel_border.color = Color(0.55, 0.40, 0.18)
	panel_border.size = Vector2(324, 284)
	panel_border.position = Vector2(318, 128)
	_inventory_panel.add_child(panel_border)

	# Panel background
	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.12, 0.08, 0.03, 0.95)
	panel_bg.size = Vector2(320, 280)
	panel_bg.position = Vector2(320, 130)
	_inventory_panel.add_child(panel_bg)

	# Title
	var title = Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.position = Vector2(320, 138)
	title.size = Vector2(320, 30)
	_inventory_panel.add_child(title)

	# Tool/seed buttons
	var tools = [
		["hand", "✋ Hand", Color(0.35, 0.28, 0.18)],
		["water_jug", "💧 Water Jug", Color(0.18, 0.35, 0.6)],
		["sunflower_seeds", "🌻 Sunflower Seeds", Color(0.5, 0.42, 0.08)],
		["carrot_seeds", "🥕 Carrot Seeds", Color(0.5, 0.28, 0.05)],
		["strawberry_seeds", "🍓 Strawberry Seeds", Color(0.5, 0.12, 0.18)],
	]
	for i in range(tools.size()):
		var t = tools[i]
		var btn = GameManager.make_button(t[1], Vector2(345, 175 + i * 42), Vector2(270, 36), t[2])
		btn.add_theme_font_size_override("font_size", 15)
		var tool_id = t[0]
		btn.pressed.connect(func():
			_set_tool(tool_id)
			_toggle_inventory()
		)
		_inventory_panel.add_child(btn)
		_inventory_tool_buttons.append(btn)

	add_child(_inventory_panel)

func _toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	_inventory_panel.visible = _inventory_open

func _refresh_hud() -> void:
	_hud_coins.text = "💰 %d" % PlayerData.coins
	_hud_day.text = "Day %d" % PlayerData.day

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
	if TouchControls.is_pause_pressed():
		GameManager.show_pause_menu(self)

func _physics_process(delta: float) -> void:
	if _inventory_open:
		return
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

	# Touch controls (overrides keyboard if active)
	var touch_dir = TouchControls.get_movement_vector()
	if touch_dir != Vector2.ZERO:
		dir = touch_dir
		if abs(touch_dir.x) > abs(touch_dir.y):
			_facing = "right" if touch_dir.x > 0 else "left"
		else:
			_facing = "down" if touch_dir.y > 0 else "up"

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
		if event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_E:
			if _inventory_open:
				_toggle_inventory()
			else:
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

	# Touch controls
	if TouchControls.is_action_just_pressed():
		if _inventory_open:
			_toggle_inventory()
		else:
			_interact()
	if TouchControls.is_inventory_pressed():
		_toggle_inventory()

func _check_exit_zones() -> void:
	if _transitioning:
		return
	var p = _player.position
	# North path → Math Mines  (walk above y=85, in x corridor 390–570)
	if p.y < 85 and p.x > 390 and p.x < 570:
		_transitioning = true
		GameManager.change_scene("math_mines")
		return
	# South path → Juarez Market  (walk below y=500, in x corridor 390–570)
	if p.y > 500 and p.x > 390 and p.x < 570:
		_transitioning = true
		GameManager.change_scene("juarez_market")
		return
	# East path → Literacy Library  (walk past x=926, in y corridor 220–380)
	if p.x > 926 and p.y > 220 and p.y < 380:
		_transitioning = true
		GameManager.change_scene("literacy_library")
		return

func _check_nearby() -> void:
	_near_tile = -1
	_near_zone = ""

	# Check farm tiles — pick the closest tile, not the first in index order
	var best_dist = TILE_SIZE * 1.0
	for i in range(PlayerData.farm_tiles.size()):
		var col: int = i % GRID_COLS
		var row: int = int(i / GRID_COLS)
		var tile_center = GRID_ORIGIN + Vector2(col * TILE_SIZE + TILE_SIZE * 0.5, row * TILE_SIZE + TILE_SIZE * 0.5)
		var dist = _player.position.distance_to(tile_center)
		if dist < best_dist:
			best_dist = dist
			_near_tile = i
	if _near_tile >= 0:
		return

	# Check zones (house, pen)
	# house_door = front of farmhouse sprite at (50,120) scale 2.2× (185×213) → door ≈ (143, 320)
	var house_door = Vector2(143, 320)
	if _player.position.distance_to(house_door) < 110:
		_near_zone = "house"
		return

	var pen_center = Vector2(790, 445)
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
		if PlayerData.animals.is_empty():
			_action_label.text = "[E] Check the animal pen"
		elif not PlayerData.animals_tended_today:
			_action_label.text = "[E] Tend animals (food & water)"
		else:
			_action_label.text = "[E] Pet your animals"
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
		GameManager.show_message(self, "The pen is ready for animals!\nBuy some at the Juarez Market.", 2.0)
		return

	if PlayerData.animals_tended_today:
		# Already tended — just pet them
		for animal in PlayerData.animals:
			animal["happiness"] = min(10, animal.get("happiness", 5) + 1)
		GameManager.show_message(self, "Your animals love the attention! 💕", 2.0)
		return

	# Tend: requires food
	if not PlayerData.has_item("animal_food"):
		GameManager.show_message(self, "You need Animal Food!\nBuy some from Abuelo at the market.", 2.5)
		return

	PlayerData.use_item("animal_food")
	PlayerData.animals_tended_today = true
	for animal in PlayerData.animals:
		animal["happiness"] = min(10, animal.get("happiness", 5) + 2)
	PlayerData.add_coins(PlayerData.animals.size() * 2)
	GameManager.show_message(self, "Fed & watered! +%d coins 🥣💧" % (PlayerData.animals.size() * 2), 2.0)

func _advance_day() -> void:
	PlayerData.advance_day()
	PlayerData.save_game()
	_refresh_hud()
	# Refresh all tile drawers
	for td in _farm_tile_drawers:
		td.queue_redraw()
	GameManager.show_message(self, "💤 Good night! Day %d begins." % PlayerData.day, 2.5)


# ── Tile Drawer ────────────────────────────────────────────────────────────────

class _FarmPlotDrawer extends Node2D:
	func _draw() -> void:
		var w = GRID_COLS * TILE_SIZE + 28
		var h = GRID_ROWS * TILE_SIZE + 28
		# Outer wooden border
		draw_rect(Rect2(0, 0, w, h), Color(0.42, 0.28, 0.12))
		# Inner soil area
		draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.48, 0.34, 0.18))
		# Corner posts
		var post = Color(0.38, 0.24, 0.10)
		draw_rect(Rect2(0, 0, 10, 10), post)
		draw_rect(Rect2(w - 10, 0, 10, 10), post)
		draw_rect(Rect2(0, h - 10, 10, 10), post)
		draw_rect(Rect2(w - 10, h - 10, 10, 10), post)


class FarmTileDrawer extends Node2D:
	var tile_index: int = 0
	var _farmland_tex = preload("res://Cute_Fantasy_Free/Tiles/FarmLand_Tile.png")

	func _draw() -> void:
		if tile_index >= PlayerData.farm_tiles.size():
			return
		var tile = PlayerData.farm_tiles[tile_index]
		var state = tile.get("state", "empty")
		var sz = Vector2(TILE_SIZE, TILE_SIZE)

		match state:
			"empty":
				# Rich soil with subtle texture variation
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0.46, 0.34, 0.20))
				# Soil texture dots
				var rng = RandomNumberGenerator.new()
				rng.seed = tile_index * 31 + 7
				for k in range(8):
					var dx = rng.randf_range(4, sz.x - 4)
					var dy = rng.randf_range(4, sz.y - 4)
					draw_circle(Vector2(dx, dy), rng.randf_range(1.5, 3.0), Color(0.40, 0.28, 0.16, 0.5))
				# Subtle border
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0.36, 0.24, 0.12), false, 1.0)
			"tilled":
				draw_texture_rect(_farmland_tex, Rect2(Vector2.ZERO, sz), false)
				# Furrow lines
				for row in range(4):
					var y = 6 + row * (sz.y / 4.0)
					draw_line(Vector2(3, y), Vector2(sz.x - 3, y), Color(0.28, 0.18, 0.08, 0.6), 1.5)
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0.36, 0.24, 0.12), false, 1.0)
			"planted", "ready":
				var watered = tile.get("watered", false)
				var tint = Color(0.82, 0.92, 1.0) if watered else Color.WHITE
				draw_texture_rect(_farmland_tex, Rect2(Vector2.ZERO, sz), false, tint)
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0.36, 0.24, 0.12), false, 1.0)
				var growth = tile.get("growth", 0)
				var max_g = tile.get("max_growth", 3)
				var crop = tile.get("crop_type", "")
				var progress = float(growth) / float(max(max_g, 1))
				_draw_crop(state, crop, progress, watered)

	func _draw_crop(state: String, crop: String, progress: float, watered: bool) -> void:
		var cx = TILE_SIZE * 0.5
		var bottom = TILE_SIZE - 3.0
		var crop_colors = {
			"sunflower_seeds": Color(1.0, 0.85, 0.1),
			"carrot_seeds": Color(0.95, 0.55, 0.1),
			"strawberry_seeds": Color(0.9, 0.2, 0.3),
		}
		var color = crop_colors.get(crop, Color(0.4, 0.8, 0.2))
		var stem = Color(0.3, 0.65, 0.2)

		if state == "ready":
			# Full plant — big and lush
			draw_line(Vector2(cx, bottom), Vector2(cx, 18), stem, 4)
			# Leaves
			draw_line(Vector2(cx, 36), Vector2(cx - 12, 28), stem, 3)
			draw_line(Vector2(cx, 28), Vector2(cx + 12, 22), stem, 3)
			# Bloom
			draw_circle(Vector2(cx, 14), 14, color)
			draw_circle(Vector2(cx, 14), 7, color.darkened(0.25))
			# Sparkle
			draw_circle(Vector2(cx - 16, 12), 3.5, Color(1, 1, 0.6, 0.8))
			draw_circle(Vector2(cx + 16, 12), 3.5, Color(1, 1, 0.6, 0.8))
		elif progress > 0.5:
			# Growing well
			draw_line(Vector2(cx, bottom), Vector2(cx, 28), stem, 3)
			draw_line(Vector2(cx, 40), Vector2(cx - 10, 33), stem, 2)
			draw_circle(Vector2(cx, 24), 9, color)
		else:
			# Small sprout
			draw_line(Vector2(cx, bottom), Vector2(cx, 40), stem, 2)
			draw_circle(Vector2(cx, 37), 5, color)

		if watered:
			draw_circle(Vector2(6, bottom - 4), 3, Color(0.4, 0.7, 1.0, 0.7))
			draw_circle(Vector2(TILE_SIZE - 6, bottom - 4), 3, Color(0.4, 0.7, 1.0, 0.7))


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
		_sprite.flip_h = (facing == "right")
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
	var _heart_sprites: Array = []
	var _time: float = 0.0
	const _TEXTURES = {
		"chicken": "res://Cute_Fantasy_Free/Animals/Chicken/Chicken.png",
		"cow":     "res://Cute_Fantasy_Free/Animals/Cow/Cow.png",
		"pig":     "res://Cute_Fantasy_Free/Animals/Pig/Pig.png",
		"sheep":   "res://Cute_Fantasy_Free/Animals/Sheep/Sheep.png",
	}
	# Spread animals across the pen so they have room to roam
	const _ANIMAL_POSITIONS = [
		Vector2(50, 40), Vector2(140, 65), Vector2(95, 85),
	]

	func _ready() -> void:
		for i in range(3):
			var spr = Sprite2D.new()
			spr.hframes = 2
			spr.vframes = 2
			spr.frame = 0
			spr.scale = Vector2(1.3, 1.3)
			spr.position = _ANIMAL_POSITIONS[i]
			spr.visible = false
			_animal_sprites.append(spr)
			add_child(spr)

	func _process(delta: float) -> void:
		_time += delta
		for i in range(3):
			var spr = _animal_sprites[i]
			if i < PlayerData.animals.size():
				var animal = PlayerData.animals[i]
				var atype = animal.get("type", "chicken")
				spr.texture = load(_TEXTURES.get(atype, _TEXTURES["chicken"]))
				spr.visible = true
				# Gentle bobbing — each animal has a different phase
				var phase = _time * 1.8 + i * 2.1
				spr.position.y = _ANIMAL_POSITIONS[i].y + sin(phase) * 3.0
				# Occasionally face the other way
				spr.flip_h = sin(_time * 0.4 + i * 1.5) > 0.3
				# Animate sprite frame (idle animation)
				spr.frame = int(_time * 2.0 + i) % 2
			else:
				spr.visible = false
		queue_redraw()

	func _draw() -> void:
		# Pen ground — warm green grass base
		draw_rect(Rect2(0, 0, 200, 110), Color(0.38, 0.56, 0.25))
		# Grass variation patches
		var rng = RandomNumberGenerator.new()
		rng.seed = 7777
		for j in range(12):
			var gx = rng.randf_range(8, 190)
			var gy = rng.randf_range(8, 100)
			draw_circle(Vector2(gx, gy), rng.randf_range(6, 14), Color(0.34, 0.52, 0.22, 0.5))
		# A few tiny flowers in the pen
		var flower_colors = [Color(1, 0.9, 0.3, 0.8), Color(1, 0.5, 0.6, 0.8), Color(0.8, 0.6, 1, 0.7)]
		for j in range(5):
			var fx = rng.randf_range(12, 188)
			var fy = rng.randf_range(10, 100)
			draw_circle(Vector2(fx, fy), 2.5, flower_colors[j % flower_colors.size()])

		# Hay pile (golden straw near trough)
		draw_rect(Rect2(150, 82, 36, 20), Color(0.82, 0.72, 0.32))
		draw_rect(Rect2(153, 85, 30, 14), Color(0.88, 0.78, 0.38))

		# Water trough (wooden with water)
		draw_rect(Rect2(10, 86, 56, 18), Color(0.42, 0.26, 0.10))
		draw_rect(Rect2(13, 89, 50, 12), Color(0.40, 0.65, 0.85))
		# Water shimmer
		var shimmer = sin(_time * 2.0) * 0.15
		draw_rect(Rect2(18, 91, 20, 3), Color(0.6, 0.8, 1.0, 0.4 + shimmer))

		# Fence — open style: posts at corners and midpoints, two low rails
		var post_color = Color(0.48, 0.30, 0.12)
		var rail_color = Color(0.55, 0.36, 0.16)
		# Bottom fence (front of pen)
		draw_rect(Rect2(0, 104, 200, 4), rail_color)
		draw_rect(Rect2(0, 94, 200, 4), rail_color)
		# Left fence
		draw_rect(Rect2(0, 0, 4, 110), rail_color)
		draw_rect(Rect2(8, 0, 4, 110), rail_color)
		# Right fence
		draw_rect(Rect2(196, 0, 4, 110), rail_color)
		draw_rect(Rect2(188, 0, 4, 110), rail_color)
		# Fence posts (corners + midpoints)
		var post_xs = [0, 100, 192]
		for px in post_xs:
			draw_rect(Rect2(px, 90, 10, 20), post_color)
		draw_rect(Rect2(0, -2, 10, 14), post_color)
		draw_rect(Rect2(192, -2, 10, 14), post_color)

		# Floating hearts for happy animals
		for i in range(min(PlayerData.animals.size(), 3)):
			var animal = PlayerData.animals[i]
			var happiness = animal.get("happiness", 5)
			if happiness >= 7:
				var hpos = _ANIMAL_POSITIONS[i] + Vector2(0, -28)
				var float_y = sin(_time * 2.5 + i * 1.7) * 4.0
				var alpha = 0.5 + sin(_time * 1.5 + i) * 0.3
				_draw_heart(hpos + Vector2(0, float_y), Color(1.0, 0.3, 0.4, alpha), 5.0)

	func _draw_heart(pos: Vector2, color: Color, size: float) -> void:
		# Simple heart shape from circles + triangle
		var r = size * 0.4
		draw_circle(pos + Vector2(-r * 0.55, -r * 0.2), r, color)
		draw_circle(pos + Vector2(r * 0.55, -r * 0.2), r, color)
		var points = PackedVector2Array([
			pos + Vector2(-size * 0.5, -r * 0.1),
			pos + Vector2(size * 0.5, -r * 0.1),
			pos + Vector2(0, size * 0.55),
		])
		draw_colored_polygon(points, color)


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


class _GrassDrawer extends Node2D:
	var _grass_tex = preload("res://Cute_Fantasy_Free/Tiles/Grass_Middle.png")  # 16×16

	func _draw() -> void:
		var ts = 48  # tile display size
		var w = 960
		var h = 448  # grass area height (y=62 to y=510)
		var rng = RandomNumberGenerator.new()
		rng.seed = 12345  # deterministic so it doesn't change every frame

		# Base grass tiling with subtle color variation per tile
		var cols = int(ceil(w / float(ts))) + 1
		var rows = int(ceil(h / float(ts))) + 1
		for row in range(rows):
			for col in range(cols):
				var v = rng.randf_range(0.90, 1.10)
				draw_texture_rect(_grass_tex, Rect2(col * ts, row * ts, ts, ts), false, Color(v, v, v))

		# Darker grass tufts for depth variation
		for i in range(35):
			var tx = rng.randf_range(30, w - 30)
			var ty = rng.randf_range(20, h - 20)
			var size = rng.randf_range(4, 8)
			draw_circle(Vector2(tx, ty), size, Color(0.25, 0.52, 0.15, 0.35))

		# Lighter grass highlights
		for i in range(20):
			var tx = rng.randf_range(30, w - 30)
			var ty = rng.randf_range(20, h - 20)
			draw_circle(Vector2(tx, ty), rng.randf_range(3, 6), Color(0.55, 0.85, 0.35, 0.25))

		# Small scattered flowers
		var flower_colors = [
			Color(1.0, 0.92, 0.3, 0.7),   # yellow
			Color(0.95, 0.45, 0.5, 0.7),   # pink
			Color(0.75, 0.5, 0.9, 0.65),   # purple
			Color(1.0, 1.0, 1.0, 0.55),    # white
		]
		for i in range(25):
			var fx = rng.randf_range(30, w - 30)
			var fy = rng.randf_range(20, h - 20)
			var fc = flower_colors[rng.randi() % flower_colors.size()]
			draw_circle(Vector2(fx, fy), 2.5, fc)

		# Edge shadows along borders for depth (fence casts shadow inward)
		draw_rect(Rect2(0, 0, w, 10), Color(0, 0, 0, 0.12))        # top
		draw_rect(Rect2(0, h - 10, w, 10), Color(0, 0, 0, 0.12))   # bottom
		draw_rect(Rect2(0, 0, 10, h), Color(0, 0, 0, 0.12))        # left
		draw_rect(Rect2(w - 10, 0, 10, h), Color(0, 0, 0, 0.12))   # right


class _WoodFenceDrawer extends Node2D:
	var _fence_tex = preload("res://Cute_Fantasy_Free/Outdoor decoration/Fences.png")  # 64×64

	func _draw() -> void:
		# The sprite has posts at x 6-9, 22-25, 38-41, 54-57
		# and rails at y 6-11, 22-27, 38-43, 54-59
		# Extract regions for proper orientation:
		#   Horizontal fences: full-width strip (64×16) — shows posts + rails
		#   Left vertical:  left post column (16×64) — post with rails extending right
		#   Right vertical: right post column (16×64) — post with rails extending left

		var h_region = Rect2(0, 0, 64, 16)   # one horizontal fence tier
		var hw = 96    # display width for horizontal section
		var hh = 26    # display height for horizontal section

		var vl_region = Rect2(0, 0, 16, 64)   # left post column (rails go right)
		var vr_region = Rect2(48, 0, 16, 64)  # right post column (rails go left)
		var vw = 26    # display width for vertical section
		var vh = 96    # display height for vertical section

		# ── Top fence (y=60) — gap x 430–530 for Mines path ──
		var x = 0
		while x < 430:
			draw_texture_rect_region(_fence_tex, Rect2(x, 60, hw, hh), h_region)
			x += hw
		x = 530
		while x < 960:
			draw_texture_rect_region(_fence_tex, Rect2(x, 60, hw, hh), h_region)
			x += hw

		# ── Bottom fence (y=500) — gap x 430–530 for Market path ──
		x = 0
		while x < 430:
			draw_texture_rect_region(_fence_tex, Rect2(x, 500, hw, hh), h_region)
			x += hw
		x = 530
		while x < 960:
			draw_texture_rect_region(_fence_tex, Rect2(x, 500, hw, hh), h_region)
			x += hw

		# ── Left fence (x=0) — solid, uses left post column (rails face inward) ──
		var y = 60
		while y < 510:
			draw_texture_rect_region(_fence_tex, Rect2(0, y, vw, vh), vl_region)
			y += vh

		# ── Right fence (x=934) — gap y 230–370 for Library path ──
		# Uses right post column (rails face inward)
		y = 60
		while y < 230:
			draw_texture_rect_region(_fence_tex, Rect2(934, y, vw, vh), vr_region)
			y += vh
		y = 370
		while y < 510:
			draw_texture_rect_region(_fence_tex, Rect2(934, y, vw, vh), vr_region)
			y += vh


class _PathDrawer extends Node2D:
	func _ready() -> void:
		# Cave entrance sprite at the mine path
		var cave_spr = Sprite2D.new()
		cave_spr.texture = load("res://Pixelwood Valley 1.1.2/Caves/CaveEntrance/1.png")
		cave_spr.scale = Vector2(3.5, 3.5)
		cave_spr.position = Vector2(480, 48)
		add_child(cave_spr)

	func _draw() -> void:
		var dirt = Color(0.6, 0.48, 0.3)
		var rock = Color(0.38, 0.34, 0.30)
		var dark_rock = Color(0.28, 0.24, 0.20)

		# Path to top (Math Mines) — rocky approach
		draw_rect(Rect2(420, 50, 120, 120), dirt)
		# Rock framing on sides of mine path
		draw_rect(Rect2(400, 50, 22, 80), rock)
		draw_rect(Rect2(538, 50, 22, 80), rock)
		draw_rect(Rect2(406, 50, 10, 60), dark_rock)
		draw_rect(Rect2(544, 50, 10, 60), dark_rock)
		# Scattered rocks near entrance
		draw_circle(Vector2(415, 130), 8, rock)
		draw_circle(Vector2(548, 125), 6, rock)
		draw_circle(Vector2(425, 145), 5, dark_rock)

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
