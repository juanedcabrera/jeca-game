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
	"tile":       "res://Pixelwood Valley 1.1.2/Caves/Tiles/Tiles.png",
	"rock1":      "res://Pixelwood Valley 1.1.2/Caves/Rocks/Rock1.png",
	"rock2":      "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock2.png",
	"rock3":      "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock3.png",
	"rock4":      "res://Pixelwood Valley 1.1.2/Caves/Rocks/rock4.png",
	"ore_gold":   "res://Pixelwood Valley 1.1.2/Caves/Ores/Gold.png",
	"ore_purple": "res://Pixelwood Valley 1.1.2/Caves/Ores/Purple Ore.png",
}

const MAX_PROBLEMS        = 5
const PLAYER_SPEED        = 150
const ORE_INTERACT_DIST   = 130.0
const ORE_POSITIONS       = {
	"addition":    Vector2(115, 250),
	"subtraction": Vector2(845, 250),
}

# ── State ─────────────────────────────────────────────────────────────────────
var _mode: String = "walk"   # walk | addition | subtraction | results

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
var _action_ribbon: Control
var _action_label: Label
var _quiz_overlay: Control

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_cave()
	_build_ore_sprites()
	_build_player()
	_build_action_ribbon()
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

	_action_ribbon.visible = (_near_ore != "")
	if _near_ore == "addition":
		_action_label.text = "[E] Mine Gold Ore  (Addition +)"
	elif _near_ore == "subtraction":
		_action_label.text = "[E] Mine Purple Ore  (Subtraction -)"

# ── Scene building ────────────────────────────────────────────────────────────
func _build_cave() -> void:
	# Warm sandy cave floor — matches Stardew mine palette
	var bg = ColorRect.new()
	bg.color = Color(0.70, 0.58, 0.40)
	bg.size = Vector2(960, 540)
	add_child(bg)

	# Build all cave walls and floor detail from rock sprites
	_place_cave_rocks()

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

	_score_label = GameManager.make_label("Coins earned: 0", Vector2(700, 8), 18, Color(0.42, 0.30, 0.08))
	add_child(_score_label)

	_progress_label = GameManager.make_label("", Vector2(20, 8), 16, Color(0.38, 0.28, 0.10))
	add_child(_progress_label)

func _place_cave_rocks() -> void:
	var r1 = load(PW_CAVE["rock1"])   # 20×16 — large rock
	var r2 = load(PW_CAVE["rock2"])   # 20×13 — medium rock
	var r3 = load(PW_CAVE["rock3"])   # 13×9  — small rock
	var r4 = load(PW_CAVE["rock4"])   # 9×7   — tiny rock

	# ── Ceiling — two dense rows of large rocks ───────────────────────────
	# Back row (y ≈ 10)
	for i in range(21):
		var s = Sprite2D.new()
		s.texture = r1
		s.scale = Vector2(6.5, 6.5)
		s.position = Vector2(22 + i * 46, 12 + (i % 3) * 12)
		s.modulate = Color(0.80, 0.68, 0.50)
		add_child(s)
	# Front row (y ≈ 72), slightly offset — forms ragged ceiling edge
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
	# Gold ore (Addition) — embedded in left wall rocks
	var gold_spr = Sprite2D.new()
	gold_spr.texture = load(PW_CAVE["ore_gold"])
	gold_spr.scale = Vector2(4.5, 4.5)
	gold_spr.position = ORE_POSITIONS["addition"]
	gold_spr.z_index = 5
	add_child(gold_spr)

	var gold_lbl = Label.new()
	gold_lbl.text = "Gold Ore\nAddition  (+)"
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 17)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	gold_lbl.add_theme_color_override("font_shadow_color", Color(0.15, 0.08, 0.0))
	gold_lbl.add_theme_constant_override("shadow_offset_x", 1)
	gold_lbl.add_theme_constant_override("shadow_offset_y", 1)
	gold_lbl.position = Vector2(40, 316)
	gold_lbl.size = Vector2(152, 52)
	add_child(gold_lbl)

	# Purple ore (Subtraction) — embedded in right wall rocks
	var purple_spr = Sprite2D.new()
	purple_spr.texture = load(PW_CAVE["ore_purple"])
	purple_spr.scale = Vector2(4.5, 4.5)
	purple_spr.position = ORE_POSITIONS["subtraction"]
	purple_spr.z_index = 5
	add_child(purple_spr)

	var purple_lbl = Label.new()
	purple_lbl.text = "Purple Ore\nSubtraction  (-)"
	purple_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purple_lbl.add_theme_font_size_override("font_size", 17)
	purple_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	purple_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.18))
	purple_lbl.add_theme_constant_override("shadow_offset_x", 1)
	purple_lbl.add_theme_constant_override("shadow_offset_y", 1)
	purple_lbl.position = Vector2(768, 316)
	purple_lbl.size = Vector2(152, 52)
	add_child(purple_lbl)

	var stats = GameManager.make_label(
		"⭐ Problems solved: %d" % PlayerData.math_problems_solved,
		Vector2(360, 460), 15, Color(0.38, 0.28, 0.10))
	add_child(stats)

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 2
	_player.position = Vector2(480, 410)
	_player.z_index = 5

	var shape = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 12
	cap.height = 24
	shape.shape = cap
	_player.add_child(shape)

	_player_drawer = _MinePlayer.new()
	_player_drawer.gender = PlayerData.player_gender
	_player.add_child(_player_drawer)

	add_child(_player)

func _build_action_ribbon() -> void:
	_action_ribbon = Control.new()
	_action_ribbon.visible = false
	_action_ribbon.position = Vector2(0, 456)
	_action_ribbon.z_index = 10

	var ribbon_bg = ColorRect.new()
	ribbon_bg.color = Color(0.05, 0.03, 0.0, 0.90)
	ribbon_bg.size = Vector2(960, 42)
	_action_ribbon.add_child(ribbon_bg)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 18)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.position = Vector2(0, 8)
	_action_label.size = Vector2(960, 28)
	_action_ribbon.add_child(_action_label)
	add_child(_action_ribbon)

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
	_mode = ore_id   # "addition" or "subtraction"
	_problems_done = 0
	_score = 0
	_score_label.text = "Coins earned: 0"
	_action_ribbon.visible = false
	_quiz_overlay.visible = true
	_build_problem_ui()
	_next_problem()

func _close_quiz() -> void:
	_clear_content()
	_quiz_overlay.visible = false
	_mode = "walk"
	_near_ore = ""

func _build_problem_ui() -> void:
	# Ore icon
	var ore_key = "ore_gold" if _mode == "addition" else "ore_purple"
	var ore_icon = Sprite2D.new()
	ore_icon.texture = load(PW_CAVE[ore_key])
	ore_icon.scale = Vector2(2.5, 2.5)
	ore_icon.position = Vector2(480, 108)
	_quiz_overlay.add_child(_tag(ore_icon))

	# Mode title
	var mode_lbl = Label.new()
	mode_lbl.text = ("⚡ Gold Ore  —  Addition  (+)" if _mode == "addition"
		else "💜 Purple Ore  —  Subtraction  (-)")
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 20)
	mode_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.88, 0.2) if _mode == "addition" else Color(0.85, 0.6, 1.0))
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

	var dots_hint = GameManager.make_label(
		"Count the dots if you need help!", Vector2(320, 350), 15, Color(0.7, 0.7, 0.6))
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

	if _mode == "addition":
		_num_a = randi_range(1, 9)
		_num_b = randi_range(1, 9)
		_op = "+"
		_current_answer = _num_a + _num_b
	else:
		_num_a = randi_range(3, 12)
		_num_b = randi_range(1, _num_a)
		_op = "-"
		_current_answer = _num_a - _num_b

	_question_label.text = "%d  %s  %d  =  ?" % [_num_a, _op, _num_b]

	var choices = [_current_answer]
	while choices.size() < 5:
		var wrong = _current_answer + randi_range(-4, 4)
		if wrong >= 0 and wrong <= 18 and wrong not in choices:
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
	var coins_this = 2 if _mode == "addition" else 3

	for btn in _answer_buttons:
		btn.disabled = true

	if chosen == _current_answer:
		_feedback_label.text = "⭐ Correct! +%d coins!" % coins_this
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.3))
		_score += coins_this
		PlayerData.add_coins(coins_this)
		PlayerData.math_problems_solved += 1
		_score_label.text = "Coins earned: %d" % _score
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
	earned.text = "You earned  %d  Gold Coins! 💰" % _score
	earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earned.add_theme_font_size_override("font_size", 28)
	earned.add_theme_color_override("font_color", Color(0.9, 1.0, 0.6))
	earned.position = Vector2(180, 200)
	earned.size = Vector2(600, 44)
	_quiz_overlay.add_child(_tag(earned))

	var total_lbl = Label.new()
	total_lbl.text = "Total coins: %d   ⭐ Total solved: %d" % [PlayerData.coins, PlayerData.math_problems_solved]
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 20)
	total_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	total_lbl.position = Vector2(180, 258)
	total_lbl.size = Vector2(600, 36)
	_quiz_overlay.add_child(_tag(total_lbl))

	var hint = Label.new()
	hint.text = "Spend your coins at the Juarez Market!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	hint.position = Vector2(180, 306)
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
		_sprite.flip_h = (facing == "left")
		_sprite.frame = int(walk_frame * 4) % 4 if is_moving else 0

	func _draw() -> void:
		pass


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

		for i in range(min(num_a, 9)):
			draw_circle(Vector2(10 + i * DOT_GAP, ROW_Y), DOT_R, gold)

		var sym_x = 10 + 9 * DOT_GAP + 8
		draw_string(ThemeDB.fallback_font, Vector2(sym_x, ROW_Y + 8),
			op, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.9, 0.8))

		if op == "+":
			var b_start = sym_x + 28
			for i in range(min(num_b, 9)):
				draw_circle(Vector2(b_start + i * DOT_GAP, ROW_Y), DOT_R, blue)
		else:
			for i in range(min(num_a, 9)):
				var cx = 10 + i * DOT_GAP
				if i >= (num_a - num_b):
					draw_circle(Vector2(cx, ROW_Y), DOT_R, Color(0.5, 0.5, 0.5))
					draw_line(Vector2(cx - DOT_R, ROW_Y - DOT_R),
							  Vector2(cx + DOT_R, ROW_Y + DOT_R), red, 2)
				else:
					draw_circle(Vector2(cx, ROW_Y), DOT_R, gold)
