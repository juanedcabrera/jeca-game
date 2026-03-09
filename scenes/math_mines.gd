extends Node2D

# ── Math Mines: Walkable cave with ore veins to mine ─────────────────────────

const PW_SPRITES = {
	"boy_idle_up":   "res://Pixelwood Valley 1.1.2/Player Character/Idle/Up.png",
	"boy_idle_down": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png",
	"boy_idle_side": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Side.png",
	"boy_walk_up":   "res://Pixelwood Valley 1.1.2/Player Character/Walk/Up.png",
	"boy_walk_down": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Down.png",
	"boy_walk_side": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Side.png",
}

const PW_CAVE = {
	"tile":        "res://Pixelwood Valley 1.1.2/Caves/Tiles/Tiles.png",
	"rock1":       "res://Pixelwood Valley 1.1.2/Caves/Rocks/Rock1.png",
	"rock2":       "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock2.png",
	"rock3":       "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock3.png",
	"rock4":       "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock4.png",
	"ore_gold":    "res://Pixelwood Valley 1.1.2/Caves/Ores/Gold.png",
	"ore_purple":  "res://Pixelwood Valley 1.1.2/Caves/Ores/Purple Ore.png",
	"ore_coal":    "res://Pixelwood Valley 1.1.2/Caves/Ores/Coal.png",
	"ore_iron":    "res://Pixelwood Valley 1.1.2/Caves/Ores/Iron.png",
	"ore_diamond": "res://Pixelwood Valley 1.1.2/Caves/Ores/Diamond.png",
	"ore_emerald": "res://Pixelwood Valley 1.1.2/Caves/Ores/Emerald.png",
	"lantern":     "res://Pixelwood Valley 1.1.2/Wooden/2.png",
}

const MAX_PROBLEMS        = 5
const PLAYER_SPEED        = 150
const ORE_INTERACT_DIST   = 130.0
const ORE_POSITIONS       = {
	"addition":       Vector2(115, 200),
	"multiplication": Vector2(115, 380),
	"subtraction":    Vector2(845, 200),
	"division":       Vector2(845, 380),
}

const COINS_PER_TYPE = {
	"addition":       2,
	"subtraction":    3,
	"multiplication": 4,
	"division":       5,
}

# ── State ─────────────────────────────────────────────────────────────────────
var _mode: String = "walk"   # walk | addition | subtraction | multiplication | division | results

# Walk
var _player: CharacterBody2D
var _player_drawer: Node2D
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_ore: String = ""
var _transitioning: bool = false

# Quiz
var _problems_done: int = 0
var _score: int = 0
var _current_answer: int = 0
var _num_a: int = 0
var _num_b: int = 0
var _op: String = "+"
var _answer_buttons: Array = []
var _question_label: Label
var _score_label: Label
var _feedback_label: Label
var _progress_label: Label
var _answer_panel: Control

# UI
var _action_bubble: Control
var _action_label: Label
var _quiz_overlay: Control
var _hud_coins: Label
var _hud_day: Label

# ── Difficulty ────────────────────────────────────────────────────────────────
func _get_difficulty_level() -> int:
	var solved = PlayerData.math_problems_solved
	if solved >= 40:
		return 3
	elif solved >= 15:
		return 2
	else:
		return 1

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_cave()
	_build_ore_sprites()
	_build_player()
	_build_hud()
	_build_action_bubble()
	_build_quiz_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _mode == "walk":
					GameManager.show_pause_menu(self)
			KEY_E:
				if _mode == "walk" and _near_ore != "":
					_start_activity(_near_ore)

	# Touch controls
	if TouchControls.is_pause_pressed():
		if _mode == "walk":
			GameManager.show_pause_menu(self)
	if TouchControls.is_action_just_pressed():
		if _mode == "walk" and _near_ore != "":
			_start_activity(_near_ore)

func _physics_process(delta: float) -> void:
	if _mode != "walk":
		return

	var dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1; _facing = "up"
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1; _facing = "down"
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1; _facing = "left"
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1; _facing = "right"

	# Touch controls
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

	# Exit south
	if _player.position.y > 498 and not _transitioning:
		_transitioning = true
		PlayerData.save_game()
		GameManager.go_to_farm("from_mines")
		return

	# Ore proximity
	_near_ore = ""
	for ore_id in ORE_POSITIONS:
		if _player.position.distance_to(ORE_POSITIONS[ore_id]) < ORE_INTERACT_DIST:
			_near_ore = ore_id
			break

	_action_bubble.visible = (_near_ore != "")
	match _near_ore:
		"addition":
			_action_label.text = "[E] Mine Gold Ore  (Addition +)"
		"subtraction":
			_action_label.text = "[E] Mine Purple Ore  (Subtraction -)"
		"multiplication":
			_action_label.text = "[E] Mine Emerald Ore  (Multiply x)"
		"division":
			_action_label.text = "[E] Mine Diamond Ore  (Division /)"

# ── Scene building ────────────────────────────────────────────────────────────
func _build_cave() -> void:
	# Dark cave floor — deeper underground feel
	var bg = ColorRect.new()
	bg.color = Color(0.52, 0.42, 0.30)
	bg.size = Vector2(960, 540)
	add_child(bg)

	# Cave floor detail drawer (cracks, puddles, texture)
	var floor_detail = _CaveFloorDrawer.new()
	floor_detail.z_index = 0
	add_child(floor_detail)

	# Build all cave walls and floor detail from rock sprites
	_place_cave_rocks()

	# Decorative ore veins embedded in walls (non-interactive)
	var deco_ores = [
		[PW_CAVE["ore_coal"], Vector2(160, 90), Vector2(2.0, 2.0)],
		[PW_CAVE["ore_iron"], Vector2(750, 100), Vector2(2.0, 2.0)],
		[PW_CAVE["ore_coal"], Vector2(400, 80), Vector2(1.8, 1.8)],
		[PW_CAVE["ore_iron"], Vector2(580, 95), Vector2(1.5, 1.5)],
		[PW_CAVE["ore_diamond"], Vector2(480, 55), Vector2(1.8, 1.8)],
	]
	for d in deco_ores:
		var ore = Sprite2D.new()
		ore.texture = load(d[0])
		ore.position = d[1]
		ore.scale = d[2]
		ore.z_index = 2
		ore.modulate = Color(1, 1, 1, 0.7)
		add_child(ore)

	# Lanterns on walls for warm lighting
	for lpos in [Vector2(92, 220), Vector2(868, 220), Vector2(92, 380), Vector2(868, 380)]:
		var lantern = Sprite2D.new()
		lantern.texture = load(PW_CAVE["lantern"])
		lantern.scale = Vector2(2.2, 2.2)
		lantern.position = lpos
		lantern.z_index = 3
		add_child(lantern)

	# Warm lantern glow circles
	var glow_drawer = _LanternGlowDrawer.new()
	glow_drawer.z_index = 1
	add_child(glow_drawer)

	# Cave entrance/exit at bottom center
	var entrance = Sprite2D.new()
	entrance.texture = load("res://Pixelwood Valley 1.1.2/Caves/CaveEntrance/1.png")
	entrance.scale = Vector2(4.0, 4.0)
	entrance.position = Vector2(480, 514)
	entrance.z_index = 3
	add_child(entrance)

	# Collision walls (match the visual rock boundary)
	_add_wall(Vector2(0, 0),   Vector2(960, 130))  # ceiling
	_add_wall(Vector2(0, 0),   Vector2(80, 540))   # left
	_add_wall(Vector2(880, 0), Vector2(960, 540))  # right

func _place_cave_rocks() -> void:
	var r1 = load(PW_CAVE["rock1"])   # 20x16 — large rock
	var r2 = load(PW_CAVE["rock2"])   # 20x13 — medium rock
	var r3 = load(PW_CAVE["rock3"])   # 13x9  — small rock
	var r4 = load(PW_CAVE["rock4"])   # 9x7   — tiny rock

	# ── Ceiling — two dense rows of large rocks ───────────────────────────
	# Back row (y ~ 10)
	for i in range(21):
		var s = Sprite2D.new()
		s.texture = r1
		s.scale = Vector2(6.5, 6.5)
		s.position = Vector2(22 + i * 46, 12 + (i % 3) * 12)
		s.modulate = Color(0.80, 0.68, 0.50)
		add_child(s)
	# Front row (y ~ 72), slightly offset — forms ragged ceiling edge
	for i in range(20):
		var s = Sprite2D.new()
		s.texture = r1
		s.scale = Vector2(5.0, 5.0)
		s.position = Vector2(46 + i * 48, 72 + (i % 4) * 10)
		s.modulate = Color(0.75, 0.63, 0.46)
		add_child(s)
	# Jagged toe of ceiling — small rocks at the bottom edge
	for i in range(24):
		var s = Sprite2D.new()
		s.texture = r2
		s.scale = Vector2(3.2, 3.2)
		s.position = Vector2(18 + i * 40, 116 + (i % 3) * 8)
		s.modulate = Color(0.72, 0.60, 0.44)
		add_child(s)

	# ── Left wall — column of large rocks ────────────────────────────────
	for i in range(10):
		var s = Sprite2D.new()
		s.texture = r1
		s.scale = Vector2(5.5, 5.5)
		s.position = Vector2(22 + (i % 2) * 18, 148 + i * 42)
		s.modulate = Color(0.78, 0.66, 0.48)
		add_child(s)
	# Ragged inner edge of left wall
	for i in range(10):
		var s = Sprite2D.new()
		s.texture = r2
		s.scale = Vector2(2.8, 2.8)
		s.position = Vector2(68 - (i % 3) * 12, 155 + i * 40)
		s.modulate = Color(0.72, 0.60, 0.44)
		add_child(s)

	# ── Right wall — column of large rocks ───────────────────────────────
	for i in range(10):
		var s = Sprite2D.new()
		s.texture = r1
		s.scale = Vector2(5.5, 5.5)
		s.position = Vector2(938 - (i % 2) * 18, 148 + i * 42)
		s.modulate = Color(0.78, 0.66, 0.48)
		add_child(s)
	# Ragged inner edge of right wall
	for i in range(10):
		var s = Sprite2D.new()
		s.texture = r2
		s.scale = Vector2(2.8, 2.8)
		s.position = Vector2(892 + (i % 3) * 12, 155 + i * 40)
		s.modulate = Color(0.72, 0.60, 0.44)
		add_child(s)

	# ── Floor rocks — small clusters scattered on the walkable floor ──────
	var floor_rocks = [
		[Vector2(280, 198), r2, Vector2(2.4, 2.4)],
		[Vector2(660, 212), r1, Vector2(2.0, 2.0)],
		[Vector2(480, 380), r2, Vector2(1.8, 1.8)],
		[Vector2(360, 355), r3, Vector2(2.2, 2.2)],
		[Vector2(590, 370), r3, Vector2(1.9, 1.9)],
		[Vector2(430, 440), r4, Vector2(2.5, 2.5)],
		[Vector2(700, 415), r2, Vector2(2.0, 2.0)],
		[Vector2(310, 430), r3, Vector2(1.7, 1.7)],
		[Vector2(540, 290), r4, Vector2(2.2, 2.2)],
		[Vector2(390, 220), r3, Vector2(1.6, 1.6)],
	]
	for d in floor_rocks:
		var s = Sprite2D.new()
		s.texture = d[1]
		s.scale = d[2]
		s.position = d[0]
		s.modulate = Color(0.76, 0.63, 0.46)
		add_child(s)

func _add_wall(top_left: Vector2, bottom_right: Vector2) -> void:
	var wall = StaticBody2D.new()
	wall.collision_layer = 2
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var sz = bottom_right - top_left
	shape.size = sz
	col.position = top_left + sz * 0.5
	col.shape = shape
	wall.add_child(col)
	add_child(wall)

func _build_ore_sprites() -> void:
	# Gold ore (Addition) — left upper, embedded in left wall rocks with glow
	var gold_glow = _OreGlowDrawer.new()
	gold_glow.ore_color = Color(1.0, 0.85, 0.2, 0.12)
	gold_glow.position = ORE_POSITIONS["addition"]
	gold_glow.z_index = 4
	add_child(gold_glow)

	var gold_spr = Sprite2D.new()
	gold_spr.texture = load(PW_CAVE["ore_gold"])
	gold_spr.scale = Vector2(4.5, 4.5)
	gold_spr.position = ORE_POSITIONS["addition"]
	gold_spr.z_index = 5
	add_child(gold_spr)

	var gold_lbl = Label.new()
	gold_lbl.text = "Gold Ore\nAddition (+)"
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	gold_lbl.add_theme_color_override("font_shadow_color", Color(0.15, 0.08, 0.0))
	gold_lbl.add_theme_constant_override("shadow_offset_x", 1)
	gold_lbl.add_theme_constant_override("shadow_offset_y", 1)
	gold_lbl.position = Vector2(44, 150)
	gold_lbl.size = Vector2(142, 40)
	gold_lbl.z_index = 5
	add_child(gold_lbl)

	# Emerald ore (Multiplication) — left lower
	var emer_glow = _OreGlowDrawer.new()
	emer_glow.ore_color = Color(0.2, 0.9, 0.4, 0.12)
	emer_glow.position = ORE_POSITIONS["multiplication"]
	emer_glow.z_index = 4
	add_child(emer_glow)

	var emer_spr = Sprite2D.new()
	emer_spr.texture = load(PW_CAVE["ore_emerald"])
	emer_spr.scale = Vector2(4.5, 4.5)
	emer_spr.position = ORE_POSITIONS["multiplication"]
	emer_spr.z_index = 5
	add_child(emer_spr)

	var emer_lbl = Label.new()
	emer_lbl.text = "Emerald Ore\nMultiply (x)"
	emer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emer_lbl.add_theme_font_size_override("font_size", 14)
	emer_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	emer_lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.12, 0.04))
	emer_lbl.add_theme_constant_override("shadow_offset_x", 1)
	emer_lbl.add_theme_constant_override("shadow_offset_y", 1)
	emer_lbl.position = Vector2(44, 330)
	emer_lbl.size = Vector2(142, 40)
	emer_lbl.z_index = 5
	add_child(emer_lbl)

	# Purple ore (Subtraction) — right upper, embedded in right wall rocks with glow
	var purp_glow = _OreGlowDrawer.new()
	purp_glow.ore_color = Color(0.7, 0.3, 1.0, 0.12)
	purp_glow.position = ORE_POSITIONS["subtraction"]
	purp_glow.z_index = 4
	add_child(purp_glow)

	var purple_spr = Sprite2D.new()
	purple_spr.texture = load(PW_CAVE["ore_purple"])
	purple_spr.scale = Vector2(4.5, 4.5)
	purple_spr.position = ORE_POSITIONS["subtraction"]
	purple_spr.z_index = 5
	add_child(purple_spr)

	var purple_lbl = Label.new()
	purple_lbl.text = "Purple Ore\nSubtract (-)"
	purple_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purple_lbl.add_theme_font_size_override("font_size", 14)
	purple_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	purple_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.18))
	purple_lbl.add_theme_constant_override("shadow_offset_x", 1)
	purple_lbl.add_theme_constant_override("shadow_offset_y", 1)
	purple_lbl.position = Vector2(774, 150)
	purple_lbl.size = Vector2(142, 40)
	purple_lbl.z_index = 5
	add_child(purple_lbl)

	# Diamond ore (Division) — right lower
	var diam_glow = _OreGlowDrawer.new()
	diam_glow.ore_color = Color(0.6, 0.85, 1.0, 0.12)
	diam_glow.position = ORE_POSITIONS["division"]
	diam_glow.z_index = 4
	add_child(diam_glow)

	var diam_spr = Sprite2D.new()
	diam_spr.texture = load(PW_CAVE["ore_diamond"])
	diam_spr.scale = Vector2(4.5, 4.5)
	diam_spr.position = ORE_POSITIONS["division"]
	diam_spr.z_index = 5
	add_child(diam_spr)

	var diam_lbl = Label.new()
	diam_lbl.text = "Diamond Ore\nDivision (/)"
	diam_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diam_lbl.add_theme_font_size_override("font_size", 14)
	diam_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	diam_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.08, 0.15))
	diam_lbl.add_theme_constant_override("shadow_offset_x", 1)
	diam_lbl.add_theme_constant_override("shadow_offset_y", 1)
	diam_lbl.position = Vector2(774, 330)
	diam_lbl.size = Vector2(142, 40)
	diam_lbl.z_index = 5
	add_child(diam_lbl)

	# Exit hint at bottom
	var exit_lbl = GameManager.make_label(
		"Walk south to exit", Vector2(400, 490), 14, Color(0.65, 0.55, 0.40, 0.7))
	exit_lbl.z_index = 4
	add_child(exit_lbl)

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 2
	_player.position = Vector2(480, 410)
	_player.z_index = 5

	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 18
	cap.height = 36
	col.shape = cap
	col.position = Vector2(0, 10)
	_player.add_child(col)

	_player_drawer = _MinePlayer.new()
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

func _build_hud() -> void:
	# Compact top-right panel (coins + day)
	var hud_border = ColorRect.new()
	hud_border.color = Color(0.55, 0.40, 0.18, 0.6)
	hud_border.size = Vector2(152, 54)
	hud_border.position = Vector2(805, 3)
	hud_border.z_index = 9
	add_child(hud_border)

	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	hud_bg.size = Vector2(150, 52)
	hud_bg.position = Vector2(806, 4)
	hud_bg.z_index = 10
	add_child(hud_bg)

	_hud_coins = Label.new()
	_hud_coins.text = "Coins: %d" % PlayerData.coins
	_hud_coins.add_theme_font_size_override("font_size", 14)
	_hud_coins.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_hud_coins.position = Vector2(816, 8)
	_hud_coins.size = Vector2(130, 20)
	_hud_coins.z_index = 11
	add_child(_hud_coins)

	_hud_day = Label.new()
	_hud_day.text = "Day %d" % PlayerData.day
	_hud_day.add_theme_font_size_override("font_size", 14)
	_hud_day.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_hud_day.position = Vector2(816, 28)
	_hud_day.size = Vector2(130, 20)
	_hud_day.z_index = 11
	add_child(_hud_day)

	# Scene title badge top-left
	var title_border = ColorRect.new()
	title_border.color = Color(0.55, 0.40, 0.18, 0.6)
	title_border.size = Vector2(122, 34)
	title_border.position = Vector2(3, 3)
	title_border.z_index = 9
	add_child(title_border)

	var title_bg = ColorRect.new()
	title_bg.color = Color(0.08, 0.05, 0.02, 0.80)
	title_bg.size = Vector2(120, 32)
	title_bg.position = Vector2(4, 4)
	title_bg.z_index = 10
	add_child(title_bg)

	var title_lbl = Label.new()
	title_lbl.text = "  Math Mines"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	title_lbl.position = Vector2(4, 8)
	title_lbl.size = Vector2(120, 24)
	title_lbl.z_index = 11
	add_child(title_lbl)

	# Problems solved badge below title
	_score_label = Label.new()
	_score_label.text = "Solved: %d" % PlayerData.math_problems_solved
	_score_label.add_theme_font_size_override("font_size", 12)
	_score_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.55))
	_score_label.position = Vector2(8, 38)
	_score_label.size = Vector2(120, 20)
	_score_label.z_index = 11
	add_child(_score_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.55))
	_progress_label.position = Vector2(8, 52)
	_progress_label.size = Vector2(120, 20)
	_progress_label.z_index = 11
	add_child(_progress_label)

func _build_action_bubble() -> void:
	_action_bubble = Control.new()
	_action_bubble.visible = false
	_action_bubble.position = Vector2(310, 496)
	_action_bubble.z_index = 10

	var bubble_bg = ColorRect.new()
	bubble_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	bubble_bg.size = Vector2(340, 34)
	_action_bubble.add_child(bubble_bg)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 16)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.position = Vector2(0, 6)
	_action_label.size = Vector2(340, 24)
	_action_bubble.add_child(_action_label)
	add_child(_action_bubble)

func _build_quiz_overlay() -> void:
	_quiz_overlay = Control.new()
	_quiz_overlay.visible = false
	_quiz_overlay.z_index = 50
	add_child(_quiz_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = Vector2(960, 540)
	dim.position = Vector2.ZERO
	_quiz_overlay.add_child(dim)

	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.05, 0.97)
	panel.size = Vector2(700, 440)
	panel.position = Vector2(130, 60)
	_quiz_overlay.add_child(panel)

# ── Quiz logic ────────────────────────────────────────────────────────────────
func _tag(node: Node) -> Node:
	node.set_meta("dynamic", true)
	return node

func _clear_content() -> void:
	for child in _quiz_overlay.get_children():
		if child.has_meta("dynamic"):
			child.queue_free()
	_answer_buttons.clear()
	_question_label = null
	_feedback_label = null
	_answer_panel = null

func _start_activity(ore_id: String) -> void:
	_mode = ore_id   # "addition" | "subtraction" | "multiplication" | "division"
	_problems_done = 0
	_score = 0
	_action_bubble.visible = false
	_quiz_overlay.visible = true
	_build_problem_ui()
	_next_problem()

func _close_quiz() -> void:
	_clear_content()
	_quiz_overlay.visible = false
	_mode = "walk"
	_near_ore = ""

func _get_ore_key_for_mode() -> String:
	match _mode:
		"addition":       return "ore_gold"
		"subtraction":    return "ore_purple"
		"multiplication": return "ore_emerald"
		"division":       return "ore_diamond"
	return "ore_gold"

func _get_mode_title() -> String:
	var lvl = _get_difficulty_level()
	match _mode:
		"addition":
			return "Gold Ore  --  Addition (+)  --  Level %d" % lvl
		"subtraction":
			return "Purple Ore  --  Subtraction (-)  --  Level %d" % lvl
		"multiplication":
			return "Emerald Ore  --  Multiply (x)  --  Level %d" % lvl
		"division":
			return "Diamond Ore  --  Division (/)  --  Level %d" % lvl
	return ""

func _get_mode_color() -> Color:
	match _mode:
		"addition":       return Color(1.0, 0.88, 0.2)
		"subtraction":    return Color(0.85, 0.6, 1.0)
		"multiplication": return Color(0.4, 1.0, 0.55)
		"division":       return Color(0.7, 0.9, 1.0)
	return Color.WHITE

func _get_mode_emoji() -> String:
	match _mode:
		"addition":       return "+"
		"subtraction":    return "-"
		"multiplication": return "x"
		"division":       return "/"
	return ""

func _build_problem_ui() -> void:
	# Ore icon
	var ore_key = _get_ore_key_for_mode()
	var ore_icon = Sprite2D.new()
	ore_icon.texture = load(PW_CAVE[ore_key])
	ore_icon.scale = Vector2(2.5, 2.5)
	ore_icon.position = Vector2(480, 108)
	_quiz_overlay.add_child(_tag(ore_icon))

	# Mode title with difficulty level
	var mode_lbl = Label.new()
	mode_lbl.text = _get_mode_title()
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 18)
	mode_lbl.add_theme_color_override("font_color", _get_mode_color())
	mode_lbl.position = Vector2(130, 140)
	mode_lbl.size = Vector2(700, 32)
	_quiz_overlay.add_child(_tag(mode_lbl))

	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question_label.add_theme_font_size_override("font_size", 72)
	_question_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	_question_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.15, 0.0))
	_question_label.add_theme_constant_override("shadow_offset_x", 3)
	_question_label.add_theme_constant_override("shadow_offset_y", 3)
	_question_label.position = Vector2(130, 172)
	_question_label.size = Vector2(700, 120)
	_quiz_overlay.add_child(_tag(_question_label))

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 26)
	_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_feedback_label.position = Vector2(130, 302)
	_feedback_label.size = Vector2(700, 40)
	_feedback_label.text = ""
	_quiz_overlay.add_child(_tag(_feedback_label))

	var hint_text = "Count the dots if you need help!"
	if _mode == "multiplication":
		hint_text = "Count the groups of dots!"
	elif _mode == "division":
		hint_text = "See how the dots split into groups!"
	var dots_hint = GameManager.make_label(
		hint_text, Vector2(300, 350), 15, Color(0.7, 0.7, 0.6))
	_quiz_overlay.add_child(_tag(dots_hint))

	_answer_panel = Control.new()
	_answer_panel.position = Vector2(130, 362)
	_answer_panel.size = Vector2(700, 50)
	_quiz_overlay.add_child(_tag(_answer_panel))

	_answer_buttons.clear()
	for i in range(5):
		var btn = GameManager.make_button("?", Vector2(90 + i * 156, 428), Vector2(126, 64), Color(0.25, 0.45, 0.65))
		btn.add_theme_font_size_override("font_size", 36)
		var btn_idx = i
		btn.pressed.connect(func(): _check_answer(btn_idx))
		_quiz_overlay.add_child(_tag(btn))
		_answer_buttons.append(btn)

func _next_problem() -> void:
	if _problems_done >= MAX_PROBLEMS:
		_show_results()
		return

	_feedback_label.text = ""
	_update_progress()
	_reset_button_colors()

	var lvl = _get_difficulty_level()

	match _mode:
		"addition":
			_op = "+"
			match lvl:
				1:
					_num_a = randi_range(1, 9)
					_num_b = randi_range(1, 9)
				2:
					_num_a = randi_range(10, 50)
					_num_b = randi_range(10, 50)
				3:
					_num_a = randi_range(50, 200)
					_num_b = randi_range(50, 200)
			_current_answer = _num_a + _num_b

		"subtraction":
			_op = "-"
			match lvl:
				1:
					_num_a = randi_range(3, 12)
					_num_b = randi_range(1, _num_a)
				2:
					_num_a = randi_range(20, 100)
					_num_b = randi_range(10, _num_a)
				3:
					_num_a = randi_range(100, 500)
					_num_b = randi_range(50, _num_a)
			_current_answer = _num_a - _num_b

		"multiplication":
			_op = "x"
			match lvl:
				1:
					_num_a = randi_range(1, 5)
					_num_b = randi_range(1, 5)
				2:
					_num_a = randi_range(2, 10)
					_num_b = randi_range(2, 10)
				3:
					_num_a = randi_range(5, 12)
					_num_b = randi_range(5, 12)
			_current_answer = _num_a * _num_b

		"division":
			_op = "/"
			var result: int
			var divisor: int
			match lvl:
				1:
					result = randi_range(1, 5)
					divisor = randi_range(2, 5)
				2:
					result = randi_range(2, 10)
					divisor = randi_range(2, 10)
				3:
					result = randi_range(5, 12)
					divisor = randi_range(5, 12)
			_num_a = result * divisor   # dividend = result * divisor so it divides evenly
			_num_b = divisor
			_current_answer = result

	_question_label.text = "%d  %s  %d  =  ?" % [_num_a, _op, _num_b]

	# Generate wrong answers
	var choices = [_current_answer]
	var spread = 4
	if _mode == "multiplication" or _mode == "division":
		if _current_answer > 20:
			spread = 8
		elif _current_answer > 10:
			spread = 6
	elif _mode == "addition" or _mode == "subtraction":
		if _current_answer > 50:
			spread = 8
		elif _current_answer > 20:
			spread = 6

	while choices.size() < 5:
		var wrong = _current_answer + randi_range(-spread, spread)
		if wrong >= 0 and wrong != _current_answer and wrong not in choices:
			choices.append(wrong)
	choices.shuffle()

	for i in range(5):
		_answer_buttons[i].text = str(choices[i])
		_answer_buttons[i].set_meta("value", choices[i])
		_answer_buttons[i].disabled = false

	_draw_dot_helper()

func _draw_dot_helper() -> void:
	for child in _answer_panel.get_children():
		child.queue_free()
	var dot_drawer = DotHelper.new()
	dot_drawer.num_a = _num_a
	dot_drawer.num_b = _num_b
	dot_drawer.op = _op
	_answer_panel.add_child(dot_drawer)

func _check_answer(btn_idx: int) -> void:
	var chosen = _answer_buttons[btn_idx].get_meta("value")
	var coins_this = COINS_PER_TYPE.get(_mode, 2)

	for btn in _answer_buttons:
		btn.disabled = true

	if chosen == _current_answer:
		_feedback_label.text = "Correct! +%d coins!" % coins_this
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.3))
		_score += coins_this
		PlayerData.add_coins(coins_this)
		PlayerData.math_problems_solved += 1
		_hud_coins.text = "Coins: %d" % PlayerData.coins
		_score_label.text = "Solved: %d" % PlayerData.math_problems_solved
		_color_button(btn_idx, Color(0.1, 0.6, 0.1))
	else:
		_feedback_label.text = "Not quite! The answer was %d. Try again!" % _current_answer
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1))
		_color_button(btn_idx, Color(0.6, 0.1, 0.1))
		for i in range(5):
			if _answer_buttons[i].get_meta("value") == _current_answer:
				_color_button(i, Color(0.1, 0.6, 0.1))

	_problems_done += 1
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(_next_problem)

func _color_button(idx: int, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_answer_buttons[idx].add_theme_stylebox_override("normal", style)
	_answer_buttons[idx].add_theme_stylebox_override("hover", style)

func _reset_button_colors() -> void:
	for btn in _answer_buttons:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.45, 0.65)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", style)
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.35, 0.55, 0.75)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_progress() -> void:
	_progress_label.text = "Problem %d / %d" % [_problems_done + 1, MAX_PROBLEMS]

func _show_results() -> void:
	_mode = "results"
	_clear_content()

	var result_title = Label.new()
	result_title.text = "Great Work, %s!" % PlayerData.player_name
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 32)
	result_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	result_title.position = Vector2(180, 130)
	result_title.size = Vector2(600, 50)
	_quiz_overlay.add_child(_tag(result_title))

	var earned = Label.new()
	earned.text = "You earned  %d  Gold Coins!" % _score
	earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earned.add_theme_font_size_override("font_size", 28)
	earned.add_theme_color_override("font_color", Color(0.9, 1.0, 0.6))
	earned.position = Vector2(180, 200)
	earned.size = Vector2(600, 44)
	_quiz_overlay.add_child(_tag(earned))

	var total_lbl = Label.new()
	total_lbl.text = "Total coins: %d   |  Total solved: %d" % [PlayerData.coins, PlayerData.math_problems_solved]
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 20)
	total_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	total_lbl.position = Vector2(180, 258)
	total_lbl.size = Vector2(600, 36)
	_quiz_overlay.add_child(_tag(total_lbl))

	var lvl_lbl = Label.new()
	lvl_lbl.text = "Difficulty Level: %d" % _get_difficulty_level()
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 16)
	lvl_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.65))
	lvl_lbl.position = Vector2(180, 290)
	lvl_lbl.size = Vector2(600, 28)
	_quiz_overlay.add_child(_tag(lvl_lbl))

	var hint = Label.new()
	hint.text = "Spend your coins at the Juarez Market!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	hint.position = Vector2(180, 320)
	hint.size = Vector2(600, 36)
	_quiz_overlay.add_child(_tag(hint))

	var mine_again = GameManager.make_button("Mine Again!", Vector2(270, 374), Vector2(190, 52), Color(0.55, 0.42, 0.08))
	mine_again.pressed.connect(func(): _close_quiz())
	_quiz_overlay.add_child(_tag(mine_again))

	var leave_btn = GameManager.make_button("Leave Mines", Vector2(500, 374), Vector2(190, 52), Color(0.3, 0.22, 0.12))
	leave_btn.pressed.connect(func(): _leave())
	_quiz_overlay.add_child(_tag(leave_btn))

	PlayerData.save_game()

func _leave() -> void:
	PlayerData.save_game()
	GameManager.go_to_farm("from_mines")


# ── Inner classes ─────────────────────────────────────────────────────────────

class _MinePlayer extends Node2D:
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


class _CaveFloorDrawer extends Node2D:
	func _draw() -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 4321
		# Dark patches for depth variation
		for i in range(20):
			var px = rng.randf_range(90, 870)
			var py = rng.randf_range(140, 490)
			var sz = rng.randf_range(20, 60)
			draw_rect(Rect2(px, py, sz, sz * 0.6), Color(0.44, 0.35, 0.24, 0.35))
		# Cracks in the stone floor
		var cracks = [
			[200, 300, 280, 320], [350, 250, 420, 270], [500, 350, 580, 340],
			[650, 280, 720, 310], [300, 420, 380, 440], [550, 450, 630, 430],
			[180, 400, 240, 420], [700, 400, 760, 380], [440, 200, 520, 210],
		]
		for c in cracks:
			draw_line(Vector2(c[0], c[1]), Vector2(c[2], c[3]), Color(0.38, 0.30, 0.20, 0.5), 1.5)
		# Small puddles (water seeping through)
		var puddle_positions = [Vector2(350, 380), Vector2(600, 320), Vector2(450, 460)]
		for pp in puddle_positions:
			draw_ellipse(pp, 18, 8, Color(0.35, 0.50, 0.62, 0.3))
		# Tiny pebbles
		for i in range(30):
			var px = rng.randf_range(100, 860)
			var py = rng.randf_range(150, 480)
			draw_circle(Vector2(px, py), rng.randf_range(1.5, 3.0), Color(0.58, 0.48, 0.34, 0.4))


class _LanternGlowDrawer extends Node2D:
	func _draw() -> void:
		# Warm glow circles around lantern positions
		var glow_positions = [Vector2(92, 220), Vector2(868, 220), Vector2(92, 380), Vector2(868, 380)]
		for gp in glow_positions:
			draw_circle(gp, 80, Color(1.0, 0.85, 0.5, 0.06))
			draw_circle(gp, 50, Color(1.0, 0.8, 0.4, 0.08))
			draw_circle(gp, 25, Color(1.0, 0.9, 0.6, 0.1))


class _OreGlowDrawer extends Node2D:
	var ore_color: Color = Color(1.0, 0.85, 0.2, 0.12)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 70, ore_color)
		draw_circle(Vector2.ZERO, 45, Color(ore_color.r, ore_color.g, ore_color.b, ore_color.a * 1.5))


class DotHelper extends Node2D:
	var num_a: int = 0
	var num_b: int = 0
	var op: String = "+"

	const DOT_R   = 7
	const DOT_GAP = 16
	const ROW_Y   = 20

	func _draw() -> void:
		var gold = Color(0.9, 0.7, 0.2)
		var blue = Color(0.4, 0.7, 0.9)
		var red  = Color(0.9, 0.3, 0.2)
		var green = Color(0.3, 0.85, 0.4)
		var cyan = Color(0.4, 0.8, 0.9)

		# Clamp displayed dots so the visual helper stays within panel bounds
		var max_dots = 18

		if op == "+":
			# Addition: show num_a gold dots + num_b blue dots
			var show_a = mini(num_a, 9)
			var show_b = mini(num_b, 9)
			for i in range(show_a):
				draw_circle(Vector2(10 + i * DOT_GAP, ROW_Y), DOT_R, gold)

			var sym_x = 10 + show_a * DOT_GAP + 8
			draw_string(ThemeDB.fallback_font, Vector2(sym_x, ROW_Y + 8),
				"+", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.9, 0.8))

			var b_start = sym_x + 28
			for i in range(show_b):
				draw_circle(Vector2(b_start + i * DOT_GAP, ROW_Y), DOT_R, blue)

			# If numbers are too large to show all dots, indicate with "..."
			if num_a > 9 or num_b > 9:
				var trail_x = b_start + show_b * DOT_GAP + 8
				draw_string(ThemeDB.fallback_font, Vector2(trail_x, ROW_Y + 8),
					"...", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.6))

		elif op == "-":
			# Subtraction: show num_a dots, cross out the last num_b
			var show_a = mini(num_a, max_dots)
			for i in range(show_a):
				var cx = 10 + i * DOT_GAP
				if i >= (show_a - mini(num_b, show_a)):
					draw_circle(Vector2(cx, ROW_Y), DOT_R, Color(0.5, 0.5, 0.5))
					draw_line(Vector2(cx - DOT_R, ROW_Y - DOT_R),
							  Vector2(cx + DOT_R, ROW_Y + DOT_R), red, 2)
				else:
					draw_circle(Vector2(cx, ROW_Y), DOT_R, gold)

			if num_a > max_dots:
				var trail_x = 10 + show_a * DOT_GAP + 8
				draw_string(ThemeDB.fallback_font, Vector2(trail_x, ROW_Y + 8),
					"...", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.6))

		elif op == "x":
			# Multiplication: show num_b groups of num_a dots (clamped)
			var show_groups = mini(num_b, 6)
			var dots_per = mini(num_a, 5)
			var group_width = dots_per * (DOT_GAP - 2) + 12
			var total_width = show_groups * group_width
			var start_x = max(10, (700 - total_width) / 2 - 130)

			var group_colors = [gold, blue, green, cyan, Color(0.9, 0.5, 0.7), Color(0.8, 0.6, 0.3)]

			for g in range(show_groups):
				var gx = start_x + g * group_width
				var gc = group_colors[g % group_colors.size()]
				# Draw a subtle bracket around the group
				draw_rect(Rect2(gx - 2, ROW_Y - DOT_R - 4, dots_per * (DOT_GAP - 2) + 4, DOT_R * 2 + 8),
					Color(gc.r, gc.g, gc.b, 0.15))
				for d in range(dots_per):
					draw_circle(Vector2(gx + d * (DOT_GAP - 2), ROW_Y), DOT_R - 1, gc)

			# Show multiplication symbol and counts
			var sym_x = start_x + show_groups * group_width + 4
			var sym_text = ""
			if num_b > 6 or num_a > 5:
				sym_text = "..."
			draw_string(ThemeDB.fallback_font, Vector2(sym_x, ROW_Y + 8),
				sym_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.6))

		elif op == "/":
			# Division: show num_a dots being split into num_b groups
			var total_dots = mini(num_a, 30)
			var result = num_a / num_b if num_b > 0 else 0
			var show_groups = mini(num_b, 6)
			var dots_per = mini(result, 5)
			var group_width = dots_per * (DOT_GAP - 2) + 16
			var total_width = show_groups * group_width
			var start_x = max(10, (700 - total_width) / 2 - 130)

			var group_colors = [gold, blue, green, cyan, Color(0.9, 0.5, 0.7), Color(0.8, 0.6, 0.3)]

			for g in range(show_groups):
				var gx = start_x + g * group_width
				var gc = group_colors[g % group_colors.size()]
				# Draw dividing lines between groups
				if g > 0:
					draw_line(Vector2(gx - 8, ROW_Y - DOT_R - 6),
							  Vector2(gx - 8, ROW_Y + DOT_R + 6), Color(0.8, 0.8, 0.7, 0.5), 2)
				for d in range(dots_per):
					draw_circle(Vector2(gx + d * (DOT_GAP - 2), ROW_Y), DOT_R - 1, gc)

			var sym_x = start_x + show_groups * group_width + 4
			var sym_text = ""
			if num_b > 6 or result > 5:
				sym_text = "..."
			draw_string(ThemeDB.fallback_font, Vector2(sym_x, ROW_Y + 8),
				sym_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.6))
