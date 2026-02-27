extends Node2D

# ── Alphabet Library: Walkable interior with bookshelves ─────────────────────

const PW_SPRITES = {
	"boy_idle_up":   "res://Pixelwood Valley 1.1.2/Player Character/Idle/Up.png",
	"boy_idle_down": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png",
	"boy_idle_side": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Side.png",
	"boy_walk_up":   "res://Pixelwood Valley 1.1.2/Player Character/Walk/Up.png",
	"boy_walk_down": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Down.png",
	"boy_walk_side": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Side.png",
}

const PW_INTERIOR = {
	"bookshelf": "res://Pixelwood Valley 1.1.2/interior/furniture/BOOKSHELF.png",
	"open_book": "res://Pixelwood Valley 1.1.2/interior/decorations/OPENBOOK_1.png",
	"flower_pot": "res://Pixelwood Valley 1.1.2/interior/flower and tree pots/1.png",
}

const MAX_ROUNDS             = 5
const FERTILIZER_EVERY       = 5
const PLAYER_SPEED           = 150
const BOOKSHELF_INTERACT_DIST = 110.0

# Bookshelf sprite centers (interaction points)
const BOOKSHELF_POSITIONS = [Vector2(130, 175), Vector2(830, 175)]

const LETTER_LIST = [
	["A", ["a", "b", "c"]], ["B", ["a", "b", "d"]], ["C", ["a", "b", "c"]],
	["D", ["a", "b", "d"]], ["E", ["a", "e", "i"]], ["F", ["a", "f", "d"]],
	["G", ["a", "g", "d"]], ["H", ["a", "h", "n"]], ["I", ["i", "o", "a"]],
	["J", ["a", "j", "g"]], ["K", ["a", "k", "h"]], ["L", ["a", "l", "i"]],
	["M", ["a", "m", "n"]], ["N", ["a", "n", "m"]], ["O", ["o", "a", "e"]],
	["P", ["a", "p", "b"]], ["Q", ["a", "q", "o"]], ["R", ["a", "r", "p"]],
	["S", ["a", "s", "z"]], ["T", ["a", "t", "d"]], ["U", ["u", "o", "a"]],
	["V", ["a", "v", "y"]], ["W", ["a", "w", "m"]], ["X", ["a", "x", "z"]],
	["Y", ["a", "y", "v"]], ["Z", ["a", "z", "s"]],
]

# ── State ─────────────────────────────────────────────────────────────────────
var _mode: String = "walk"   # walk | puzzle | results

# Walk
var _player: CharacterBody2D
var _player_drawer: Node2D
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_shelf: bool = false
var _transitioning: bool = false

# Puzzle
var _rounds_done: int = 0
var _current_letter: Array = []
var _letter_options: Array = []
var _chosen_letters: Array = []
var _question_label: Label
var _feedback_label: Label
var _progress_label: Label
var _letter_buttons: Array = []

# UI
var _action_ribbon: Control
var _action_label: Label
var _puzzle_overlay: Control

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_library()
	_build_player()
	_build_action_ribbon()
	_build_puzzle_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _mode == "walk":
					GameManager.show_pause_menu(self)
			KEY_E:
				if _mode == "walk" and _near_shelf:
					_start_game()

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
	if _player.position.y > 495 and not _transitioning:
		_transitioning = true
		PlayerData.save_game()
		GameManager.go_to_farm("from_library")
		return

	# Bookshelf proximity
	_near_shelf = false
	for shelf_pos in BOOKSHELF_POSITIONS:
		if _player.position.distance_to(shelf_pos) < BOOKSHELF_INTERACT_DIST:
			_near_shelf = true
			break

	_action_ribbon.visible = _near_shelf
	if _near_shelf:
		_action_label.text = "[E] Read a Book"

# ── Scene building ────────────────────────────────────────────────────────────
func _build_library() -> void:
	# Back wall
	var wall = ColorRect.new()
	wall.color = Color(0.85, 0.75, 0.58)
	wall.size = Vector2(960, 270)
	wall.position = Vector2.ZERO
	add_child(wall)

	# Wood floor
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.60, 0.44, 0.26)
	floor_rect.size = Vector2(960, 270)
	floor_rect.position = Vector2(0, 270)
	add_child(floor_rect)

	# Floor plank lines
	var planks = _FloorPlanks.new()
	planks.position = Vector2.ZERO
	planks.z_index = 1
	add_child(planks)

	# Left bookshelf (interactive)
	var shelf_l = Sprite2D.new()
	shelf_l.texture = load(PW_INTERIOR["bookshelf"])
	shelf_l.scale = Vector2(3.5, 3.5)
	shelf_l.position = BOOKSHELF_POSITIONS[0]
	shelf_l.z_index = 2
	add_child(shelf_l)

	# Right bookshelf (interactive)
	var shelf_r = Sprite2D.new()
	shelf_r.texture = load(PW_INTERIOR["bookshelf"])
	shelf_r.scale = Vector2(3.5, 3.5)
	shelf_r.position = BOOKSHELF_POSITIONS[1]
	shelf_r.z_index = 2
	add_child(shelf_r)

	# Center bookshelf (decorative, smaller, behind window)
	var shelf_c = Sprite2D.new()
	shelf_c.texture = load(PW_INTERIOR["bookshelf"])
	shelf_c.scale = Vector2(2.2, 2.2)
	shelf_c.position = Vector2(480, 108)
	shelf_c.z_index = 1
	add_child(shelf_c)

	# Window — centered on back wall, overdraws center shelf
	var win_frame = ColorRect.new()
	win_frame.color = Color(0.45, 0.30, 0.15)
	win_frame.size = Vector2(188, 148)
	win_frame.position = Vector2(386, 16)
	win_frame.z_index = 3
	add_child(win_frame)

	var win_bg = ColorRect.new()
	win_bg.color = Color(0.65, 0.88, 1.0)
	win_bg.size = Vector2(180, 140)
	win_bg.position = Vector2(390, 20)
	win_bg.z_index = 4
	add_child(win_bg)

	var win_v = ColorRect.new()
	win_v.color = Color(0.55, 0.38, 0.2)
	win_v.size = Vector2(8, 140)
	win_v.position = Vector2(476, 20)
	win_v.z_index = 5
	add_child(win_v)

	var win_h = ColorRect.new()
	win_h.color = Color(0.55, 0.38, 0.2)
	win_h.size = Vector2(180, 8)
	win_h.position = Vector2(390, 88)
	win_h.z_index = 5
	add_child(win_h)

	# Rug on floor
	var rug = _RugDrawer.new()
	rug.position = Vector2.ZERO
	rug.z_index = 1
	add_child(rug)

	# Flower pots flanking the bookshelves
	for pot_x in [290, 660]:
		var pot = Sprite2D.new()
		pot.texture = load(PW_INTERIOR["flower_pot"])
		pot.scale = Vector2(2.5, 2.5)
		pot.position = Vector2(pot_x, 248)
		pot.z_index = 2
		add_child(pot)

	# Collision: back wall (above bookshelves)
	_add_wall(Vector2(0, 0),   Vector2(960, 130))
	# Side walls
	_add_wall(Vector2(0, 0),   Vector2(28, 540))
	_add_wall(Vector2(932, 0), Vector2(960, 540))

	# Stats + exit hint
	var stats = GameManager.make_label(
		"📖 Letters: %d   🌱 Fertilizers: %d" % [
			PlayerData.words_read, PlayerData.get_item_count("fertilizer")],
		Vector2(280, 10), 16, Color(0.35, 0.20, 0.05))
	add_child(stats)

	var exit_lbl = GameManager.make_label(
		"↓  Walk down to exit  ↓", Vector2(330, 510), 15, Color(0.50, 0.38, 0.22))
	add_child(exit_lbl)

func _add_wall(top_left: Vector2, bottom_right: Vector2) -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 2
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var sz = bottom_right - top_left
	shape.size = sz
	col.position = top_left + sz * 0.5
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 2
	_player.position = Vector2(480, 400)
	_player.z_index = 6

	var shape = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 12
	cap.height = 24
	shape.shape = cap
	_player.add_child(shape)

	_player_drawer = _LibraryPlayer.new()
	_player_drawer.gender = PlayerData.player_gender
	_player.add_child(_player_drawer)

	add_child(_player)

func _build_action_ribbon() -> void:
	_action_ribbon = Control.new()
	_action_ribbon.visible = false
	_action_ribbon.position = Vector2(0, 456)
	_action_ribbon.z_index = 10

	var ribbon_bg = ColorRect.new()
	ribbon_bg.color = Color(0.18, 0.10, 0.04, 0.92)
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

func _build_puzzle_overlay() -> void:
	_puzzle_overlay = Control.new()
	_puzzle_overlay.visible = false
	_puzzle_overlay.z_index = 50
	add_child(_puzzle_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = Vector2(960, 540)
	dim.position = Vector2.ZERO
	_puzzle_overlay.add_child(dim)

	# Parchment panel border
	var border = ColorRect.new()
	border.color = Color(0.5, 0.32, 0.1)
	border.size = Vector2(626, 446)
	border.position = Vector2(167, 57)
	_puzzle_overlay.add_child(border)

	# Parchment panel
	var panel = ColorRect.new()
	panel.color = Color(0.96, 0.90, 0.72)
	panel.size = Vector2(620, 440)
	panel.position = Vector2(170, 60)
	_puzzle_overlay.add_child(panel)

	# Open book decoration (static, always in overlay)
	var book_spr = Sprite2D.new()
	book_spr.texture = load(PW_INTERIOR["open_book"])
	book_spr.scale = Vector2(3.0, 3.0)
	book_spr.position = Vector2(480, 108)
	_puzzle_overlay.add_child(book_spr)

	# Progress label (non-dynamic, updated each letter)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	_progress_label.position = Vector2(170, 68)
	_progress_label.size = Vector2(620, 28)
	_puzzle_overlay.add_child(_progress_label)

# ── Puzzle logic ──────────────────────────────────────────────────────────────
func _tag(node: Node) -> Node:
	node.set_meta("dynamic", true)
	return node

func _clear_dynamic() -> void:
	for child in _puzzle_overlay.get_children():
		if child.has_meta("dynamic"):
			child.queue_free()
	_letter_buttons.clear()
	_question_label = null
	_feedback_label = null
	if _progress_label:
		_progress_label.text = ""

func _start_game() -> void:
	_mode = "puzzle"
	_rounds_done = 0
	_clear_dynamic()
	_puzzle_overlay.visible = true
	_action_ribbon.visible = false

	var all_letters = LETTER_LIST.duplicate()
	all_letters.shuffle()
	_chosen_letters = all_letters.slice(0, MAX_ROUNDS)

	_build_puzzle_ui()
	_show_next_letter()

func _close_puzzle() -> void:
	_clear_dynamic()
	_puzzle_overlay.visible = false
	_mode = "walk"
	_near_shelf = false

func _build_puzzle_ui() -> void:
	# Library title
	var title = Label.new()
	title.text = "📚  ALPHABET LIBRARY  📚"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.35, 0.18, 0.04))
	title.position = Vector2(170, 138)
	title.size = Vector2(620, 34)
	_puzzle_overlay.add_child(_tag(title))

	# Large uppercase letter
	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.add_theme_font_size_override("font_size", 110)
	_question_label.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
	_question_label.position = Vector2(280, 185)
	_question_label.size = Vector2(400, 128)
	_puzzle_overlay.add_child(_tag(_question_label))

	# Instruction
	var hint = GameManager.make_label(
		"Find the matching lowercase letter!", Vector2(280, 322), 18, Color(0.4, 0.25, 0.08))
	_puzzle_overlay.add_child(_tag(hint))

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 26)
	_feedback_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	_feedback_label.position = Vector2(170, 354)
	_feedback_label.size = Vector2(620, 40)
	_feedback_label.text = ""
	_puzzle_overlay.add_child(_tag(_feedback_label))

	# 3 letter choice buttons
	_letter_buttons.clear()
	var letter_colors = [Color(0.75, 0.2, 0.2), Color(0.2, 0.55, 0.75), Color(0.55, 0.2, 0.75)]
	for i in range(3):
		var btn = GameManager.make_button("", Vector2(196 + i * 190, 404), Vector2(160, 88), letter_colors[i])
		btn.add_theme_font_size_override("font_size", 56)
		var btn_idx = i
		btn.pressed.connect(func(): _check_letter(btn_idx))
		_puzzle_overlay.add_child(_tag(btn))
		_letter_buttons.append(btn)

func _show_next_letter() -> void:
	if _rounds_done >= _chosen_letters.size():
		_show_results()
		return

	_current_letter = _chosen_letters[_rounds_done]
	_progress_label.text = "Letter %d / %d" % [_rounds_done + 1, _chosen_letters.size()]
	if _feedback_label:
		_feedback_label.text = ""

	var upper = _current_letter[0]
	var options = _current_letter[1].duplicate()
	options.shuffle()
	_letter_options = options
	var correct_answer = upper.to_lower()

	_question_label.text = upper

	for i in range(3):
		_letter_buttons[i].text = options[i]
		_letter_buttons[i].set_meta("correct", options[i] == correct_answer)
		_letter_buttons[i].disabled = false

func _check_letter(btn_idx: int) -> void:
	var btn = _letter_buttons[btn_idx]
	var is_correct = btn.get_meta("correct", false)

	for b in _letter_buttons:
		b.disabled = true

	if is_correct:
		_feedback_label.text = "⭐ Correct! +2 coins!"
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		PlayerData.add_coins(2)

		var is_fertilizer_reward = ((PlayerData.words_read + 1) % FERTILIZER_EVERY == 0)
		if is_fertilizer_reward:
			PlayerData.add_item("fertilizer", 1)
			_feedback_label.text = "🌱 Excellent! +2 coins and Fertilizer!"

		PlayerData.words_read += 1
	else:
		var correct_lower = _current_letter[0].to_lower()
		_feedback_label.text = "Not quite! The answer was '%s'" % correct_lower.to_upper()
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1))

	_rounds_done += 1
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(_show_next_letter)

func _show_results() -> void:
	_mode = "results"
	_clear_dynamic()

	var result = Label.new()
	result.text = "Wonderful Work, %s!" % PlayerData.player_name
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 28)
	result.add_theme_color_override("font_color", Color(0.25, 0.12, 0.02))
	result.position = Vector2(170, 168)
	result.size = Vector2(620, 44)
	_puzzle_overlay.add_child(_tag(result))

	var stats = Label.new()
	stats.text = "📖 Total letters matched: %d\n💰 Coins: %d   🌱 Fertilizer: %d" % [
		PlayerData.words_read, PlayerData.coins, PlayerData.get_item_count("fertilizer")]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 22)
	stats.add_theme_color_override("font_color", Color(0.35, 0.2, 0.05))
	stats.position = Vector2(170, 232)
	stats.size = Vector2(620, 80)
	_puzzle_overlay.add_child(_tag(stats))

	var hint = GameManager.make_label(
		"Use fertilizer on your farm crops for faster growth!",
		Vector2(170, 330), 16, Color(0.45, 0.28, 0.08))
	_puzzle_overlay.add_child(_tag(hint))

	var read_more = GameManager.make_button("Read More!", Vector2(265, 378), Vector2(180, 52), Color(0.35, 0.55, 0.2))
	read_more.pressed.connect(func(): _close_puzzle())
	_puzzle_overlay.add_child(_tag(read_more))

	var leave_btn = GameManager.make_button("Leave Library", Vector2(515, 378), Vector2(180, 52), Color(0.3, 0.22, 0.12))
	leave_btn.pressed.connect(func(): _leave())
	_puzzle_overlay.add_child(_tag(leave_btn))

	PlayerData.save_game()

func _leave() -> void:
	PlayerData.save_game()
	GameManager.go_to_farm("from_library")


# ── Inner classes ─────────────────────────────────────────────────────────────

class _FloorPlanks extends Node2D:
	func _draw() -> void:
		for i in range(9):
			var y = 278 + i * 32
			draw_rect(Rect2(0, y, 960, 1), Color(0.45, 0.32, 0.18))
		# Grain hints
		var grains = [
			[80, 283, 170, 283], [230, 315, 340, 315], [410, 347, 510, 347],
			[600, 279, 690, 279], [740, 311, 840, 311], [50, 343, 140, 343],
		]
		for g in grains:
			draw_line(Vector2(g[0], g[1]), Vector2(g[2], g[3]), Color(0.52, 0.38, 0.22, 0.45), 1)


class _RugDrawer extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(260, 355, 440, 120), Color(0.68, 0.28, 0.28))
		draw_rect(Rect2(272, 367, 416, 96), Color(0.78, 0.38, 0.38))
		draw_rect(Rect2(300, 380, 360, 70), Color(0.68, 0.28, 0.28))
		for i in range(5):
			draw_circle(Vector2(340 + i * 58, 415), 12, Color(1.0, 0.88, 0.55, 0.6))


class _LibraryPlayer extends Node2D:
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
