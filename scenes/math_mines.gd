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

const UNLOCK_THRESHOLD = 15

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
var _score_label: Label
var _feedback_label: Label
var _progress_label: Label
var _answer_panel: Control

# Stacked display
var _num_a_label: Label
var _num_b_label: Label
var _op_display_label: Label
var _answer_display_label: Label
var _stack_line: ColorRect

# UI
var _action_bubble: Control
var _action_label: Label
var _quiz_overlay: Control
var _hud_coins: Label
var _hud_day: Label
var _age_picker_overlay: Control

# Ore lock labels (updated at build time)
var _ore_labels: Dictionary = {}
var _ore_sprites: Dictionary = {}
# Snapshot of unlock state at scene entry (to detect newly unlocked ops)
var _initial_unlocks: Dictionary = {}

# ── Age-based difficulty ─────────────────────────────────────────────────────
func _get_age_tier() -> int:
	var age = PlayerData.player_age
	if age <= 5: return 1
	if age <= 7: return 2
	if age <= 9: return 3
	if age <= 11: return 4
	return 5

func _is_unlocked(op: String) -> bool:
	match op:
		"addition": return true
		"subtraction": return PlayerData.math_addition_solved >= UNLOCK_THRESHOLD
		"multiplication": return PlayerData.math_subtraction_solved >= UNLOCK_THRESHOLD
		"division": return PlayerData.math_multiplication_solved >= UNLOCK_THRESHOLD
	return false

func _unlock_progress_text(op: String) -> String:
	match op:
		"subtraction":
			return "Solve %d more addition to unlock!" % max(0, UNLOCK_THRESHOLD - PlayerData.math_addition_solved)
		"multiplication":
			return "Solve %d more subtraction to unlock!" % max(0, UNLOCK_THRESHOLD - PlayerData.math_subtraction_solved)
		"division":
			return "Solve %d more multiplication to unlock!" % max(0, UNLOCK_THRESHOLD - PlayerData.math_multiplication_solved)
	return ""

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_cave()
	_build_ore_sprites()
	_build_player()
	_build_hud()
	_build_action_bubble()
	_build_quiz_overlay()
	# Snapshot unlock state so we can detect new unlocks during this session
	for op in ["addition", "subtraction", "multiplication", "division"]:
		_initial_unlocks[op] = _is_unlocked(op)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _age_picker_overlay and _age_picker_overlay.visible:
					_close_age_picker()
				elif _mode == "walk":
					GameManager.show_pause_menu(self)
			KEY_E:
				if _mode == "walk" and _near_ore != "":
					_try_start_activity(_near_ore)


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
	if _near_ore != "":
		if not _is_unlocked(_near_ore):
			_action_label.text = _unlock_progress_text(_near_ore)
		else:
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
	# Gold ore (Addition) — always unlocked
	_build_single_ore("addition", PW_CAVE["ore_gold"], "Gold Ore\nAddition (+)",
		Color(1.0, 0.85, 0.2, 0.12), Color(1.0, 0.88, 0.2),
		Color(0.15, 0.08, 0.0), Vector2(44, 150))

	# Emerald ore (Multiplication)
	_build_single_ore("multiplication", PW_CAVE["ore_emerald"], "Emerald Ore\nMultiply (x)",
		Color(0.2, 0.9, 0.4, 0.12), Color(0.4, 1.0, 0.55),
		Color(0.02, 0.12, 0.04), Vector2(44, 330))

	# Purple ore (Subtraction)
	_build_single_ore("subtraction", PW_CAVE["ore_purple"], "Purple Ore\nSubtract (-)",
		Color(0.7, 0.3, 1.0, 0.12), Color(0.85, 0.6, 1.0),
		Color(0.12, 0.04, 0.18), Vector2(774, 150))

	# Diamond ore (Division)
	_build_single_ore("division", PW_CAVE["ore_diamond"], "Diamond Ore\nDivision (/)",
		Color(0.6, 0.85, 1.0, 0.12), Color(0.7, 0.9, 1.0),
		Color(0.04, 0.08, 0.15), Vector2(774, 330))

	# Exit hint at bottom
	var exit_lbl = GameManager.make_label(
		"Walk south to exit", Vector2(400, 490), 14, Color(0.65, 0.55, 0.40, 0.7))
	exit_lbl.z_index = 4
	add_child(exit_lbl)

func _build_single_ore(ore_id: String, texture_path: String, label_text: String,
		glow_color: Color, text_color: Color, shadow_color: Color, label_pos: Vector2) -> void:
	var pos = ORE_POSITIONS[ore_id]
	var unlocked = _is_unlocked(ore_id)

	# Glow
	var glow = _OreGlowDrawer.new()
	glow.ore_color = glow_color
	glow.position = pos
	glow.z_index = 4
	if not unlocked:
		glow.modulate = Color(0.4, 0.4, 0.4, 0.5)
	add_child(glow)

	# Ore sprite
	var spr = Sprite2D.new()
	spr.texture = load(texture_path)
	spr.scale = Vector2(4.5, 4.5)
	spr.position = pos
	spr.z_index = 5
	if not unlocked:
		spr.modulate = Color(0.4, 0.4, 0.4, 0.6)
	add_child(spr)
	_ore_sprites[ore_id] = spr

	# Label
	var lbl = Label.new()
	if unlocked:
		lbl.text = label_text
	else:
		lbl.text = label_text + "\n(LOCKED)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	if unlocked:
		lbl.add_theme_color_override("font_color", text_color)
	else:
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.add_theme_color_override("font_shadow_color", shadow_color)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = label_pos
	lbl.size = Vector2(142, 55)
	lbl.z_index = 5
	add_child(lbl)
	_ore_labels[ore_id] = lbl

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
	_action_bubble.position = Vector2(260, 496)
	_action_bubble.z_index = 10

	var bubble_bg = ColorRect.new()
	bubble_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	bubble_bg.size = Vector2(440, 34)
	_action_bubble.add_child(bubble_bg)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 16)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.position = Vector2(0, 6)
	_action_label.size = Vector2(440, 24)
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

# ── Age picker overlay (for legacy saves with age = 0) ──────────────────────
func _show_age_picker() -> void:
	if _age_picker_overlay:
		_age_picker_overlay.queue_free()

	var selected_age = 6
	_age_picker_overlay = Control.new()
	_age_picker_overlay.z_index = 60
	add_child(_age_picker_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.size = Vector2(960, 540)
	_age_picker_overlay.add_child(dim)

	var panel = ColorRect.new()
	panel.color = Color(0.12, 0.08, 0.04, 0.97)
	panel.size = Vector2(400, 280)
	panel.position = Vector2(280, 130)
	_age_picker_overlay.add_child(panel)

	var border = ColorRect.new()
	border.color = Color(0.55, 0.35, 0.15)
	border.size = Vector2(404, 284)
	border.position = Vector2(278, 128)
	_age_picker_overlay.add_child(border)
	_age_picker_overlay.move_child(border, _age_picker_overlay.get_child_count() - 2)

	var title = Label.new()
	title.text = "How old are you?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.position = Vector2(280, 150)
	title.size = Vector2(400, 40)
	_age_picker_overlay.add_child(title)

	var hint = Label.new()
	hint.text = "This helps us pick the right math problems!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
	hint.position = Vector2(280, 190)
	hint.size = Vector2(400, 28)
	_age_picker_overlay.add_child(hint)

	var age_display = Label.new()
	age_display.text = str(selected_age)
	age_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	age_display.add_theme_font_size_override("font_size", 56)
	age_display.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	age_display.position = Vector2(420, 225)
	age_display.size = Vector2(120, 70)
	_age_picker_overlay.add_child(age_display)

	var left_btn = GameManager.make_button("<", Vector2(350, 235), Vector2(60, 52), Color(0.2, 0.45, 0.75))
	left_btn.add_theme_font_size_override("font_size", 28)
	left_btn.pressed.connect(func():
		selected_age = clampi(selected_age - 1, 4, 12)
		age_display.text = str(selected_age)
	)
	_age_picker_overlay.add_child(left_btn)

	var right_btn = GameManager.make_button(">", Vector2(550, 235), Vector2(60, 52), Color(0.2, 0.45, 0.75))
	right_btn.add_theme_font_size_override("font_size", 28)
	right_btn.pressed.connect(func():
		selected_age = clampi(selected_age + 1, 4, 12)
		age_display.text = str(selected_age)
	)
	_age_picker_overlay.add_child(right_btn)

	var confirm = GameManager.make_button("OK!", Vector2(400, 320), Vector2(160, 52), Color(0.15, 0.5, 0.15))
	confirm.add_theme_font_size_override("font_size", 24)
	confirm.pressed.connect(func():
		PlayerData.player_age = selected_age
		PlayerData.save_game()
		_close_age_picker()
	)
	_age_picker_overlay.add_child(confirm)

func _close_age_picker() -> void:
	if _age_picker_overlay:
		_age_picker_overlay.queue_free()
		_age_picker_overlay = null

# ── Quiz logic ────────────────────────────────────────────────────────────────
func _tag(node: Node) -> Node:
	node.set_meta("dynamic", true)
	return node

func _clear_content() -> void:
	for child in _quiz_overlay.get_children():
		if child.has_meta("dynamic"):
			child.queue_free()
	_answer_buttons.clear()
	_num_a_label = null
	_num_b_label = null
	_op_display_label = null
	_answer_display_label = null
	_stack_line = null
	_feedback_label = null
	_answer_panel = null

func _try_start_activity(ore_id: String) -> void:
	# Check if player has set their age (legacy save migration)
	if PlayerData.player_age == 0:
		_show_age_picker()
		return
	# Check if this operation is unlocked
	if not _is_unlocked(ore_id):
		return
	_start_activity(ore_id)

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
	match _mode:
		"addition":
			return "Gold Ore  --  Addition (+)  --  Age %d" % PlayerData.player_age
		"subtraction":
			return "Purple Ore  --  Subtraction (-)  --  Age %d" % PlayerData.player_age
		"multiplication":
			return "Emerald Ore  --  Multiply (x)  --  Age %d" % PlayerData.player_age
		"division":
			return "Diamond Ore  --  Division (/)  --  Age %d" % PlayerData.player_age
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
	var mode_color = _get_mode_color()

	# Ore icon
	var ore_key = _get_ore_key_for_mode()
	var ore_icon = Sprite2D.new()
	ore_icon.texture = load(PW_CAVE[ore_key])
	ore_icon.scale = Vector2(2.0, 2.0)
	ore_icon.position = Vector2(480, 96)
	_quiz_overlay.add_child(_tag(ore_icon))

	# Mode title
	var mode_lbl = Label.new()
	mode_lbl.text = _get_mode_title()
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 16)
	mode_lbl.add_theme_color_override("font_color", mode_color)
	mode_lbl.position = Vector2(130, 118)
	mode_lbl.size = Vector2(700, 28)
	_quiz_overlay.add_child(_tag(mode_lbl))

	# ── Stacked problem display ──────────────────────────────────────────
	var stack_x = 390   # Right edge of number area
	var stack_y = 150
	var row_h = 52
	var font_sz = 52

	# Top number (right-aligned)
	_num_a_label = Label.new()
	_num_a_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_num_a_label.add_theme_font_size_override("font_size", font_sz)
	_num_a_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_num_a_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0))
	_num_a_label.add_theme_constant_override("shadow_offset_x", 2)
	_num_a_label.add_theme_constant_override("shadow_offset_y", 2)
	_num_a_label.position = Vector2(stack_x - 200, stack_y)
	_num_a_label.size = Vector2(200, row_h)
	_quiz_overlay.add_child(_tag(_num_a_label))

	# Operator (left of second number)
	_op_display_label = Label.new()
	_op_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_op_display_label.add_theme_font_size_override("font_size", font_sz)
	_op_display_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_op_display_label.position = Vector2(stack_x - 240, stack_y + row_h)
	_op_display_label.size = Vector2(50, row_h)
	_quiz_overlay.add_child(_tag(_op_display_label))

	# Bottom number (right-aligned, same column as top)
	_num_b_label = Label.new()
	_num_b_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_num_b_label.add_theme_font_size_override("font_size", font_sz)
	_num_b_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_num_b_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0))
	_num_b_label.add_theme_constant_override("shadow_offset_x", 2)
	_num_b_label.add_theme_constant_override("shadow_offset_y", 2)
	_num_b_label.position = Vector2(stack_x - 200, stack_y + row_h)
	_num_b_label.size = Vector2(200, row_h)
	_quiz_overlay.add_child(_tag(_num_b_label))

	# Horizontal line
	_stack_line = ColorRect.new()
	_stack_line.color = Color(0.8, 0.75, 0.5)
	_stack_line.position = Vector2(stack_x - 240, stack_y + row_h * 2 + 4)
	_stack_line.size = Vector2(250, 3)
	_quiz_overlay.add_child(_tag(_stack_line))

	# Answer placeholder (right-aligned)
	_answer_display_label = Label.new()
	_answer_display_label.text = "?"
	_answer_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_answer_display_label.add_theme_font_size_override("font_size", font_sz)
	_answer_display_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	_answer_display_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0))
	_answer_display_label.add_theme_constant_override("shadow_offset_x", 2)
	_answer_display_label.add_theme_constant_override("shadow_offset_y", 2)
	_answer_display_label.position = Vector2(stack_x - 200, stack_y + row_h * 2 + 10)
	_answer_display_label.size = Vector2(200, row_h)
	_quiz_overlay.add_child(_tag(_answer_display_label))

	# Dot helper area (right side of stacked problem)
	_answer_panel = Control.new()
	_answer_panel.position = Vector2(460, 158)
	_answer_panel.size = Vector2(360, 120)
	_quiz_overlay.add_child(_tag(_answer_panel))

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 24)
	_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_feedback_label.position = Vector2(130, 330)
	_feedback_label.size = Vector2(700, 36)
	_feedback_label.text = ""
	_quiz_overlay.add_child(_tag(_feedback_label))

	# Answer buttons (5 choices)
	_answer_buttons.clear()
	for i in range(5):
		var btn = GameManager.make_button("?", Vector2(90 + i * 156, 380), Vector2(126, 64), Color(0.25, 0.45, 0.65))
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
	_answer_display_label.text = "?"
	_answer_display_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	_update_progress()
	_reset_button_colors()

	var tier = _get_age_tier()

	match _mode:
		"addition":
			_op = "+"
			match tier:
				1:  # Ages 4-5
					_num_a = randi_range(1, 5)
					_num_b = randi_range(1, 5)
				2:  # Ages 6-7
					_num_a = randi_range(1, 10)
					_num_b = randi_range(1, 10)
				3:  # Ages 8-9
					_num_a = randi_range(10, 50)
					_num_b = randi_range(10, 50)
				4:  # Ages 10-11
					_num_a = randi_range(50, 200)
					_num_b = randi_range(50, 200)
				_:  # Age 12+
					_num_a = randi_range(100, 999)
					_num_b = randi_range(100, 999)
			_current_answer = _num_a + _num_b

		"subtraction":
			_op = "-"
			match tier:
				1:
					_num_a = randi_range(3, 8)
					_num_b = randi_range(1, _num_a)
				2:
					_num_a = randi_range(5, 15)
					_num_b = randi_range(1, _num_a)
				3:
					_num_a = randi_range(20, 100)
					_num_b = randi_range(10, _num_a)
				4:
					_num_a = randi_range(100, 500)
					_num_b = randi_range(50, _num_a)
				_:
					_num_a = randi_range(200, 999)
					_num_b = randi_range(100, _num_a)
			_current_answer = _num_a - _num_b

		"multiplication":
			_op = "x"
			match tier:
				1:
					_num_a = randi_range(1, 3)
					_num_b = randi_range(1, 3)
				2:
					_num_a = randi_range(1, 5)
					_num_b = randi_range(1, 5)
				3:
					_num_a = randi_range(2, 10)
					_num_b = randi_range(2, 10)
				4:
					_num_a = randi_range(5, 12)
					_num_b = randi_range(5, 12)
				_:
					_num_a = randi_range(10, 20)
					_num_b = randi_range(5, 15)
			_current_answer = _num_a * _num_b

		"division":
			_op = "/"
			var result: int
			var divisor: int
			match tier:
				1:
					result = randi_range(1, 3)
					divisor = randi_range(2, 3)
				2:
					result = randi_range(1, 5)
					divisor = randi_range(2, 5)
				3:
					result = randi_range(2, 10)
					divisor = randi_range(2, 10)
				4:
					result = randi_range(5, 12)
					divisor = randi_range(5, 12)
				_:
					result = randi_range(10, 25)
					divisor = randi_range(5, 15)
			_num_a = result * divisor   # dividend = result * divisor so it divides evenly
			_num_b = divisor
			_current_answer = result

	# Update stacked display
	_num_a_label.text = str(_num_a)
	_num_b_label.text = str(_num_b)
	_op_display_label.text = _op

	# Generate wrong answers
	var choices = [_current_answer]
	var spread = 4
	if _current_answer > 50:
		spread = 10
	elif _current_answer > 20:
		spread = 8
	elif _current_answer > 10:
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
		# Increment per-operation counter
		match _mode:
			"addition":       PlayerData.math_addition_solved += 1
			"subtraction":    PlayerData.math_subtraction_solved += 1
			"multiplication": PlayerData.math_multiplication_solved += 1
			"division":       PlayerData.math_division_solved += 1
		_hud_coins.text = "Coins: %d" % PlayerData.coins
		_score_label.text = "Solved: %d" % PlayerData.math_problems_solved
		_color_button(btn_idx, Color(0.1, 0.6, 0.1))
		# Show correct answer in stacked display
		_answer_display_label.text = str(_current_answer)
		_answer_display_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.3))
	else:
		_feedback_label.text = "The answer was %d" % _current_answer
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1))
		_color_button(btn_idx, Color(0.6, 0.1, 0.1))
		for i in range(5):
			if _answer_buttons[i].get_meta("value") == _current_answer:
				_color_button(i, Color(0.1, 0.6, 0.1))
		# Show correct answer in stacked display
		_answer_display_label.text = str(_current_answer)
		_answer_display_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1))

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

	# Check if a new operation was unlocked during this session
	var unlock_msg = ""
	if _is_unlocked("subtraction") and not _initial_unlocks.get("subtraction", false):
		unlock_msg = "Subtraction unlocked!"
	elif _is_unlocked("multiplication") and not _initial_unlocks.get("multiplication", false):
		unlock_msg = "Multiplication unlocked!"
	elif _is_unlocked("division") and not _initial_unlocks.get("division", false):
		unlock_msg = "Division unlocked!"

	if unlock_msg != "":
		var unlock_lbl = Label.new()
		unlock_lbl.text = unlock_msg
		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_lbl.add_theme_font_size_override("font_size", 22)
		unlock_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		unlock_lbl.position = Vector2(180, 290)
		unlock_lbl.size = Vector2(600, 32)
		_quiz_overlay.add_child(_tag(unlock_lbl))

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
			var pts = PackedVector2Array()
			for a in range(33):
				var angle = float(a) / 32.0 * TAU
				pts.append(pp + Vector2(cos(angle) * 18, sin(angle) * 8))
			draw_colored_polygon(pts, Color(0.35, 0.50, 0.62, 0.3))
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

	const DOT_R   = 6
	const DOT_GAP = 14
	const ROW_Y   = 30

	# For small numbers, show all dots. For large, show "Use mental math!"
	func _is_dot_friendly() -> bool:
		match op:
			"+", "-":
				return num_a <= 15 and num_b <= 15
			"x":
				return num_a <= 5 and num_b <= 6
			"/":
				return num_a <= 30 and num_b <= 6
		return false

	func _draw() -> void:
		if not _is_dot_friendly():
			draw_string(ThemeDB.fallback_font, Vector2(10, ROW_Y + 8),
				"Use mental math!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.8, 0.6))
			return

		var gold = Color(0.9, 0.7, 0.2)
		var blue = Color(0.4, 0.7, 0.9)
		var red  = Color(0.9, 0.3, 0.2)
		var green = Color(0.3, 0.85, 0.4)
		var cyan = Color(0.4, 0.8, 0.9)

		if op == "+":
			# Addition: show num_a gold dots + num_b blue dots
			for i in range(num_a):
				var row = i / 10
				var col = i % 10
				draw_circle(Vector2(10 + col * DOT_GAP, ROW_Y + row * DOT_GAP), DOT_R, gold)

			var sym_y = ROW_Y + (ceili(float(num_a) / 10.0)) * DOT_GAP + 4
			draw_string(ThemeDB.fallback_font, Vector2(10, sym_y + 6),
				"+", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.8))

			var b_start_y = sym_y + 16
			for i in range(num_b):
				var row = i / 10
				var col = i % 10
				draw_circle(Vector2(10 + col * DOT_GAP, b_start_y + row * DOT_GAP), DOT_R, blue)

		elif op == "-":
			# Subtraction: show num_a dots, cross out last num_b
			for i in range(num_a):
				var row = i / 10
				var col = i % 10
				var cx = 10 + col * DOT_GAP
				var cy = ROW_Y + row * DOT_GAP
				if i >= (num_a - num_b):
					draw_circle(Vector2(cx, cy), DOT_R, Color(0.5, 0.5, 0.5))
					draw_line(Vector2(cx - DOT_R, cy - DOT_R),
							  Vector2(cx + DOT_R, cy + DOT_R), red, 2)
				else:
					draw_circle(Vector2(cx, cy), DOT_R, gold)

		elif op == "x":
			# Multiplication: show num_b groups of num_a dots
			var group_colors = [gold, blue, green, cyan, Color(0.9, 0.5, 0.7), Color(0.8, 0.6, 0.3)]
			var group_width = num_a * DOT_GAP + 8
			for g in range(num_b):
				var gx = 10 + g * group_width
				var gc = group_colors[g % group_colors.size()]
				# Subtle bracket
				draw_rect(Rect2(gx - 2, ROW_Y - DOT_R - 3, num_a * DOT_GAP + 2, DOT_R * 2 + 6),
					Color(gc.r, gc.g, gc.b, 0.15))
				for d in range(num_a):
					draw_circle(Vector2(gx + d * DOT_GAP, ROW_Y), DOT_R, gc)

		elif op == "/":
			# Division: show num_a dots split into num_b groups
			var result = num_a / num_b if num_b > 0 else 0
			var group_colors = [gold, blue, green, cyan, Color(0.9, 0.5, 0.7), Color(0.8, 0.6, 0.3)]
			var group_width = result * DOT_GAP + 12
			for g in range(num_b):
				var gx = 10 + g * group_width
				var gc = group_colors[g % group_colors.size()]
				if g > 0:
					draw_line(Vector2(gx - 6, ROW_Y - DOT_R - 4),
							  Vector2(gx - 6, ROW_Y + DOT_R + 4), Color(0.8, 0.8, 0.7, 0.5), 2)
				for d in range(result):
					draw_circle(Vector2(gx + d * DOT_GAP, ROW_Y), DOT_R, gc)
