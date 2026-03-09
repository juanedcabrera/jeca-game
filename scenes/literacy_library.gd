extends Node2D

# ── Literacy Library: Walkable interior with bookshelves ─────────────────────
# Three game modes: Letters, Reading Comprehension, Spelling Bee

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
	"candle": "res://Pixelwood Valley 1.1.2/interior/decorations/candle.png",
"painting1": "res://Pixelwood Valley 1.1.2/interior/decorations/pAINTING_1.png",
	"painting2": "res://Pixelwood Valley 1.1.2/interior/decorations/pAINTING_3.png",
	"carpet": "res://Pixelwood Valley 1.1.2/interior/carpet/red/CARPET_1.png",
	"closed_book": "res://Pixelwood Valley 1.1.2/interior/decorations/CLOSEDBOOK_1.png",
	"shelf": "res://Pixelwood Valley 1.1.2/interior/furniture/shelf_1.png",
	"table": "res://Pixelwood Valley 1.1.2/interior/furniture/table.png",
	"chair_front": "res://Pixelwood Valley 1.1.2/interior/furniture/chair_FRONT.png",
	"lantern": "res://Pixelwood Valley 1.1.2/Wooden/2.png",
}

const MAX_ROUNDS             = 5
const READING_QUESTIONS      = 3
const SPELLING_ROUNDS        = 5
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

# ── Reading Comprehension Stories ────────────────────────────────────────────
const STORIES = [
	{
		"title": "The Little Garden",
		"text": "Maria planted sunflower seeds in her garden. She watered them every day. After two weeks, tall yellow flowers grew! Maria was so happy she picked one for her grandmother.",
		"questions": [
			{"q": "What did Maria plant?", "choices": ["Sunflower seeds", "Roses", "Carrots"], "answer": 0},
			{"q": "How often did she water them?", "choices": ["Every week", "Every day", "Once a month"], "answer": 1},
			{"q": "Who did Maria pick a flower for?", "choices": ["Her teacher", "Her grandmother", "Her friend"], "answer": 1},
		]
	},
	{
		"title": "A Day at the Farm",
		"text": "Carlos woke up early to feed the chickens. The chickens clucked happily when they saw the food. After feeding them, Carlos collected five eggs from the henhouse.",
		"questions": [
			{"q": "What animals did Carlos feed?", "choices": ["Cows", "Pigs", "Chickens"], "answer": 2},
			{"q": "How did the chickens feel?", "choices": ["Scared", "Happy", "Angry"], "answer": 1},
			{"q": "How many eggs did Carlos collect?", "choices": ["Three", "Five", "Ten"], "answer": 1},
		]
	},
	{
		"title": "The Market Visit",
		"text": "Sofi went to the market with her mother. They bought fresh tomatoes, corn, and a watermelon. On the way home, they shared a slice of watermelon under a big tree.",
		"questions": [
			{"q": "Who did Sofi go to the market with?", "choices": ["Her father", "Her brother", "Her mother"], "answer": 2},
			{"q": "What fruit did they buy?", "choices": ["Apples", "Watermelon", "Oranges"], "answer": 1},
			{"q": "Where did they eat watermelon?", "choices": ["At home", "At school", "Under a tree"], "answer": 2},
		]
	},
	{
		"title": "The Helpful Dog",
		"text": "Luna the dog loved to help on the farm. Every morning she would herd the sheep into the green pasture. The sheep followed Luna because she was gentle and kind.",
		"questions": [
			{"q": "What is the dog's name?", "choices": ["Bella", "Luna", "Max"], "answer": 1},
			{"q": "What animals did Luna herd?", "choices": ["Cows", "Chickens", "Sheep"], "answer": 2},
			{"q": "Why did the sheep follow Luna?", "choices": ["She was loud", "She was gentle and kind", "She had food"], "answer": 1},
		]
	},
	{
		"title": "Rainy Day Fun",
		"text": "It rained all morning so Ana stayed inside. She drew pictures of butterflies with her crayons. When the rain stopped, she saw a real rainbow outside her window!",
		"questions": [
			{"q": "Why did Ana stay inside?", "choices": ["She was sick", "It was raining", "She was tired"], "answer": 1},
			{"q": "What did Ana draw?", "choices": ["Flowers", "Butterflies", "Dogs"], "answer": 1},
			{"q": "What did Ana see after the rain?", "choices": ["A rainbow", "A bird", "Snow"], "answer": 0},
		]
	},
	{
		"title": "The Apple Tree",
		"text": "Grandpa had a tall apple tree in his yard. In autumn, the tree was full of red apples. Pedro climbed a ladder and picked a basket full of them to share with his neighbors.",
		"questions": [
			{"q": "Who owned the apple tree?", "choices": ["Pedro", "Grandpa", "The neighbor"], "answer": 1},
			{"q": "What season were the apples ready?", "choices": ["Spring", "Summer", "Autumn"], "answer": 2},
			{"q": "Who did Pedro share the apples with?", "choices": ["His teacher", "His neighbors", "His dog"], "answer": 1},
		]
	},
	{
		"title": "The Baby Chicks",
		"text": "The mother hen sat on her eggs for three weeks. One morning, four tiny chicks hatched! They were fluffy and yellow. The chicks followed their mother everywhere around the barn.",
		"questions": [
			{"q": "How long did the hen sit on the eggs?", "choices": ["One week", "Two weeks", "Three weeks"], "answer": 2},
			{"q": "How many chicks hatched?", "choices": ["Two", "Four", "Six"], "answer": 1},
			{"q": "What color were the chicks?", "choices": ["Brown", "White", "Yellow"], "answer": 2},
		]
	},
	{
		"title": "Planting Carrots",
		"text": "Diego dug small holes in the garden soil. He placed a carrot seed in each hole and covered them with dirt. He watered the seeds and waited. After ten days, tiny green sprouts appeared!",
		"questions": [
			{"q": "What did Diego plant?", "choices": ["Tomato seeds", "Carrot seeds", "Flower seeds"], "answer": 1},
			{"q": "What did he do after planting?", "choices": ["He left them alone", "He watered them", "He picked them"], "answer": 1},
			{"q": "How many days until sprouts appeared?", "choices": ["Five days", "Ten days", "Twenty days"], "answer": 1},
		]
	},
]

# ── Spelling Bee Words ───────────────────────────────────────────────────────
const SPELLING_WORDS = [
	{"word": "farm", "hint": "f _ _ m", "definition": "A place where crops and animals are raised", "wrongs": ["foam", "from"]},
	{"word": "seed", "hint": "s _ _ d", "definition": "You plant this to grow a flower", "wrongs": ["sand", "sled"]},
	{"word": "water", "hint": "w _ _ _ r", "definition": "Plants need this to grow", "wrongs": ["wiper", "wider"]},
	{"word": "sunny", "hint": "s _ _ _ y", "definition": "When the sky is bright and warm", "wrongs": ["sandy", "story"]},
	{"word": "chicken", "hint": "c _ _ _ _ _ n", "definition": "A bird that lays eggs", "wrongs": ["captain", "curtain"]},
	{"word": "apple", "hint": "a _ _ _ e", "definition": "A round red or green fruit", "wrongs": ["ample", "angle"]},
	{"word": "rain", "hint": "r _ _ n", "definition": "Water that falls from clouds", "wrongs": ["ruin", "roan"]},
	{"word": "tree", "hint": "t _ _ e", "definition": "A tall plant with a trunk and leaves", "wrongs": ["tire", "tube"]},
	{"word": "flower", "hint": "f _ _ _ _ r", "definition": "The colorful part of a plant", "wrongs": ["finger", "folder"]},
	{"word": "garden", "hint": "g _ _ _ _ n", "definition": "A place where you grow plants", "wrongs": ["golden", "gallon"]},
	{"word": "horse", "hint": "h _ _ _ e", "definition": "A large animal you can ride", "wrongs": ["house", "hedge"]},
	{"word": "rabbit", "hint": "r _ _ _ _ t", "definition": "A small animal with long ears", "wrongs": ["racket", "rocket"]},
	{"word": "bread", "hint": "b _ _ _ d", "definition": "A food made from flour and baked", "wrongs": ["brand", "blend"]},
	{"word": "river", "hint": "r _ _ _ r", "definition": "A long body of flowing water", "wrongs": ["ruler", "racer"]},
	{"word": "cloud", "hint": "c _ _ _ d", "definition": "A white fluffy shape in the sky", "wrongs": ["crowd", "could"]},
	{"word": "sheep", "hint": "s _ _ _ p", "definition": "A woolly farm animal", "wrongs": ["sharp", "stomp"]},
	{"word": "barn", "hint": "b _ _ n", "definition": "A building on a farm for animals or hay", "wrongs": ["burn", "bean"]},
	{"word": "nest", "hint": "n _ _ t", "definition": "Where a bird keeps its eggs", "wrongs": ["knot", "newt"]},
	{"word": "field", "hint": "f _ _ _ d", "definition": "A large open area of land", "wrongs": ["found", "flood"]},
	{"word": "honey", "hint": "h _ _ _ y", "definition": "Sweet food made by bees", "wrongs": ["handy", "happy"]},
	{"word": "puppy", "hint": "p _ _ _ y", "definition": "A baby dog", "wrongs": ["party", "penny"]},
	{"word": "berry", "hint": "b _ _ _ y", "definition": "A small sweet fruit that grows on bushes", "wrongs": ["buddy", "bunny"]},
	{"word": "stone", "hint": "s _ _ _ e", "definition": "A small hard piece of rock", "wrongs": ["stare", "spoke"]},
	{"word": "storm", "hint": "s _ _ _ m", "definition": "When there is strong wind and heavy rain", "wrongs": ["steam", "swarm"]},
	{"word": "leaf", "hint": "l _ _ f", "definition": "The flat green part of a plant", "wrongs": ["loaf", "lief"]},
]

# ── State ─────────────────────────────────────────────────────────────────────
var _mode: String = "walk"   # walk | menu | letters | reading | spelling | results

# Walk
var _player: CharacterBody2D
var _player_drawer: Node2D
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_shelf: bool = false
var _transitioning: bool = false

# Letters (existing game)
var _rounds_done: int = 0
var _current_letter: Array = []
var _letter_options: Array = []
var _chosen_letters: Array = []
var _question_label: Label
var _feedback_label: Label
var _progress_label: Label
var _letter_buttons: Array = []

# Reading Comprehension
var _current_story: Dictionary = {}
var _reading_question_idx: int = 0
var _reading_correct: int = 0
var _story_label: Label
var _reading_q_label: Label
var _reading_buttons: Array = []

# Spelling Bee
var _spelling_round: int = 0
var _spelling_correct: int = 0
var _chosen_spelling_words: Array = []
var _current_spelling: Dictionary = {}
var _spelling_def_label: Label
var _spelling_buttons: Array = []

# Session tracking for results
var _session_coins_earned: int = 0
var _session_game_mode: String = ""

# UI
var _action_bubble: Control
var _action_label: Label
var _puzzle_overlay: Control
var _hud_coins: Label
var _hud_day: Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_library()
	_build_player()
	_build_hud()
	_build_action_bubble()
	_build_puzzle_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _mode == "walk":
					GameManager.show_pause_menu(self)
				elif _mode == "menu":
					_close_puzzle()
			KEY_E:
				if _mode == "walk" and _near_shelf:
					_show_game_menu()

	# Touch controls
	if TouchControls.is_pause_pressed():
		if _mode == "walk":
			GameManager.show_pause_menu(self)
		elif _mode == "menu":
			_close_puzzle()
	if TouchControls.is_action_just_pressed():
		if _mode == "walk" and _near_shelf:
			_show_game_menu()

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

	_action_bubble.visible = _near_shelf
	if _near_shelf:
		_action_label.text = "[E] Read a Book"

# ── Scene building ────────────────────────────────────────────────────────────
func _build_library() -> void:
	# Back wall — warm plaster with subtle gradient
	var wall_lower = ColorRect.new()
	wall_lower.color = Color(0.82, 0.72, 0.55)
	wall_lower.size = Vector2(960, 270)
	wall_lower.position = Vector2.ZERO
	add_child(wall_lower)

	var wall_upper = ColorRect.new()
	wall_upper.color = Color(0.88, 0.78, 0.60)
	wall_upper.size = Vector2(960, 80)
	wall_upper.position = Vector2.ZERO
	add_child(wall_upper)

	# Wainscoting / baseboard (dark wood strip along wall-floor boundary)
	var wainscot = ColorRect.new()
	wainscot.color = Color(0.38, 0.25, 0.12)
	wainscot.size = Vector2(960, 8)
	wainscot.position = Vector2(0, 262)
	wainscot.z_index = 3
	add_child(wainscot)

	# Crown molding (thin strip at top of wall)
	var crown = ColorRect.new()
	crown.color = Color(0.45, 0.30, 0.15)
	crown.size = Vector2(960, 4)
	crown.position = Vector2(0, 0)
	crown.z_index = 3
	add_child(crown)

	# Wood floor — rich dark wood
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.55, 0.38, 0.22)
	floor_rect.size = Vector2(960, 270)
	floor_rect.position = Vector2(0, 270)
	add_child(floor_rect)

	# Floor plank lines
	var planks = _FloorPlanks.new()
	planks.position = Vector2.ZERO
	planks.z_index = 1
	add_child(planks)

	# Carpet under reading area
	var carpet_spr = Sprite2D.new()
	carpet_spr.texture = load(PW_INTERIOR["carpet"])
	carpet_spr.scale = Vector2(3.5, 2.8)
	carpet_spr.position = Vector2(480, 400)
	carpet_spr.z_index = 1
	add_child(carpet_spr)

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

	# Small wall shelves flanking the window
	for sx in [310, 640]:
		var ws = Sprite2D.new()
		ws.texture = load(PW_INTERIOR["shelf"])
		ws.scale = Vector2(2.5, 2.5)
		ws.position = Vector2(sx, 80)
		ws.z_index = 2
		add_child(ws)

	# Closed books on wall shelves
	for bx in [305, 645]:
		var cb = Sprite2D.new()
		cb.texture = load(PW_INTERIOR["closed_book"])
		cb.scale = Vector2(2.0, 2.0)
		cb.position = Vector2(bx, 68)
		cb.z_index = 3
		add_child(cb)

	# Window — centered on back wall
	var win_frame = ColorRect.new()
	win_frame.color = Color(0.40, 0.26, 0.12)
	win_frame.size = Vector2(168, 128)
	win_frame.position = Vector2(396, 20)
	win_frame.z_index = 3
	add_child(win_frame)

	var win_bg = ColorRect.new()
	win_bg.color = Color(0.62, 0.85, 0.98)
	win_bg.size = Vector2(160, 120)
	win_bg.position = Vector2(400, 24)
	win_bg.z_index = 4
	add_child(win_bg)

	# Window sunlight glow
	var sun_glow = ColorRect.new()
	sun_glow.color = Color(1.0, 0.95, 0.75, 0.15)
	sun_glow.size = Vector2(200, 200)
	sun_glow.position = Vector2(380, 24)
	sun_glow.z_index = 2
	add_child(sun_glow)

	var win_v = ColorRect.new()
	win_v.color = Color(0.48, 0.32, 0.16)
	win_v.size = Vector2(6, 120)
	win_v.position = Vector2(477, 24)
	win_v.z_index = 5
	add_child(win_v)

	var win_h = ColorRect.new()
	win_h.color = Color(0.48, 0.32, 0.16)
	win_h.size = Vector2(160, 6)
	win_h.position = Vector2(400, 82)
	win_h.z_index = 5
	add_child(win_h)

	# Paintings on walls
	var paint_l = Sprite2D.new()
	paint_l.texture = load(PW_INTERIOR["painting1"])
	paint_l.scale = Vector2(3.5, 3.5)
	paint_l.position = Vector2(60, 75)
	paint_l.z_index = 2
	add_child(paint_l)

	var paint_r = Sprite2D.new()
	paint_r.texture = load(PW_INTERIOR["painting2"])
	paint_r.scale = Vector2(3.5, 3.5)
	paint_r.position = Vector2(900, 75)
	paint_r.z_index = 2
	add_child(paint_r)

	# Candle wall sconces
	for cx in [230, 730]:
		var candle = Sprite2D.new()
		candle.texture = load(PW_INTERIOR["candle"])
		candle.scale = Vector2(2.5, 2.5)
		candle.position = Vector2(cx, 75)
		candle.z_index = 3
		add_child(candle)

	# Reading table with chairs (center floor area)
	var table_spr = Sprite2D.new()
	table_spr.texture = load(PW_INTERIOR["table"])
	table_spr.scale = Vector2(2.5, 2.5)
	table_spr.position = Vector2(480, 370)
	table_spr.z_index = 2
	add_child(table_spr)

	# Open book on table
	var table_book = Sprite2D.new()
	table_book.texture = load(PW_INTERIOR["open_book"])
	table_book.scale = Vector2(2.0, 2.0)
	table_book.position = Vector2(480, 358)
	table_book.z_index = 3
	add_child(table_book)

	# Chairs at reading table
	for chair_x in [430, 530]:
		var chair = Sprite2D.new()
		chair.texture = load(PW_INTERIOR["chair_front"])
		chair.scale = Vector2(2.5, 2.5)
		chair.position = Vector2(chair_x, 410)
		chair.z_index = 2
		add_child(chair)

	# Flower pots flanking the bookshelves
	for pot_x in [200, 700]:
		var pot = Sprite2D.new()
		pot.texture = load(PW_INTERIOR["flower_pot"])
		pot.scale = Vector2(2.5, 2.5)
		pot.position = Vector2(pot_x, 248)
		pot.z_index = 2
		add_child(pot)

	# Lanterns near entrance
	for lx in [80, 880]:
		var lantern = Sprite2D.new()
		lantern.texture = load(PW_INTERIOR["lantern"])
		lantern.scale = Vector2(2.0, 2.0)
		lantern.position = Vector2(lx, 450)
		lantern.z_index = 2
		add_child(lantern)

	# ── Collision ──
	# Back wall (behind bookshelves)
	_add_wall(Vector2(0, 0), Vector2(960, 130))
	# Side walls
	_add_wall(Vector2(0, 0), Vector2(28, 540))
	_add_wall(Vector2(932, 0), Vector2(960, 540))
	# Left bookshelf collision (sprite is ~3.5x scale, bookshelf native ~30x50)
	_add_wall(Vector2(78, 130), Vector2(182, 240))
	# Right bookshelf collision
	_add_wall(Vector2(778, 130), Vector2(882, 240))
	# Reading table collision
	_add_wall(Vector2(430, 350), Vector2(530, 400))

	# Exit hint
	var exit_lbl = GameManager.make_label(
		"Walk south to exit", Vector2(390, 510), 14, Color(0.50, 0.38, 0.22, 0.7))
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

	var col = CollisionShape2D.new()
	var cap = CapsuleShape2D.new()
	cap.radius = 18
	cap.height = 30
	col.shape = cap
	col.position = Vector2(0, 10)
	_player.add_child(col)

	_player_drawer = _LibraryPlayer.new()
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
	var hud = Control.new()
	hud.position = Vector2(800, 8)
	hud.z_index = 10
	add_child(hud)

	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	hud_bg.size = Vector2(150, 52)
	hud.add_child(hud_bg)

	_hud_coins = Label.new()
	_hud_coins.text = "Coins: %d" % PlayerData.coins
	_hud_coins.add_theme_font_size_override("font_size", 14)
	_hud_coins.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_hud_coins.position = Vector2(10, 4)
	_hud_coins.size = Vector2(130, 20)
	hud.add_child(_hud_coins)

	_hud_day = Label.new()
	_hud_day.text = "Day %d" % PlayerData.day
	_hud_day.add_theme_font_size_override("font_size", 14)
	_hud_day.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_hud_day.position = Vector2(10, 26)
	_hud_day.size = Vector2(130, 20)
	hud.add_child(_hud_day)

	# Scene title badge top-left
	var title_bg = ColorRect.new()
	title_bg.color = Color(0.08, 0.05, 0.02, 0.80)
	title_bg.size = Vector2(140, 28)
	title_bg.position = Vector2(8, 8)
	title_bg.z_index = 10
	add_child(title_bg)

	var title_lbl = Label.new()
	title_lbl.text = "  Alphabet Library"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	title_lbl.position = Vector2(8, 11)
	title_lbl.size = Vector2(140, 24)
	title_lbl.z_index = 10
	add_child(title_lbl)

func _build_action_bubble() -> void:
	_action_bubble = Control.new()
	_action_bubble.visible = false
	_action_bubble.position = Vector2(350, 496)
	_action_bubble.z_index = 10

	var bubble_bg = ColorRect.new()
	bubble_bg.color = Color(0.08, 0.05, 0.02, 0.88)
	bubble_bg.size = Vector2(260, 34)
	_action_bubble.add_child(bubble_bg)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 16)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.position = Vector2(0, 6)
	_action_label.size = Vector2(260, 24)
	_action_bubble.add_child(_action_label)
	add_child(_action_bubble)

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

	# Progress label (non-dynamic, updated each round)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	_progress_label.position = Vector2(170, 68)
	_progress_label.size = Vector2(620, 28)
	_puzzle_overlay.add_child(_progress_label)

# ── Dynamic node helpers ─────────────────────────────────────────────────────
func _tag(node: Node) -> Node:
	node.set_meta("dynamic", true)
	return node

func _clear_dynamic() -> void:
	for child in _puzzle_overlay.get_children():
		if child.has_meta("dynamic"):
			child.queue_free()
	_letter_buttons.clear()
	_reading_buttons.clear()
	_spelling_buttons.clear()
	_question_label = null
	_feedback_label = null
	_story_label = null
	_reading_q_label = null
	_spelling_def_label = null
	if _progress_label:
		_progress_label.text = ""

# ── Game Selection Menu ──────────────────────────────────────────────────────
func _show_game_menu() -> void:
	_mode = "menu"
	_clear_dynamic()
	_puzzle_overlay.visible = true
	_action_bubble.visible = false

	# Title
	var title = Label.new()
	title.text = "Choose Your Activity"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.35, 0.18, 0.04))
	title.position = Vector2(170, 140)
	title.size = Vector2(620, 40)
	_puzzle_overlay.add_child(_tag(title))

	# ABC Letters button
	var letters_btn = GameManager.make_button("ABC Letters", Vector2(310, 210), Vector2(340, 56), Color(0.75, 0.2, 0.2))
	letters_btn.add_theme_font_size_override("font_size", 24)
	letters_btn.pressed.connect(func(): _start_letters_game())
	_puzzle_overlay.add_child(_tag(letters_btn))

	# Reading Stories button
	var reading_btn = GameManager.make_button("Reading Stories", Vector2(310, 282), Vector2(340, 56), Color(0.2, 0.55, 0.75))
	reading_btn.add_theme_font_size_override("font_size", 24)
	reading_btn.pressed.connect(func(): _start_reading_game())
	_puzzle_overlay.add_child(_tag(reading_btn))

	# Spelling Bee button
	var spelling_btn = GameManager.make_button("Spelling Bee", Vector2(310, 354), Vector2(340, 56), Color(0.55, 0.2, 0.75))
	spelling_btn.add_theme_font_size_override("font_size", 24)
	spelling_btn.pressed.connect(func(): _start_spelling_game())
	_puzzle_overlay.add_child(_tag(spelling_btn))

	# Back button
	var back_btn = GameManager.make_button("Back", Vector2(400, 430), Vector2(160, 46), Color(0.3, 0.22, 0.12))
	back_btn.pressed.connect(func(): _close_puzzle())
	_puzzle_overlay.add_child(_tag(back_btn))

# ── Close / Leave ────────────────────────────────────────────────────────────
func _close_puzzle() -> void:
	_clear_dynamic()
	_puzzle_overlay.visible = false
	_mode = "walk"
	_near_shelf = false

func _leave() -> void:
	PlayerData.save_game()
	GameManager.go_to_farm("from_library")

# ══════════════════════════════════════════════════════════════════════════════
# MODE 1: LETTERS (existing game — preserved as-is)
# ══════════════════════════════════════════════════════════════════════════════

func _start_letters_game() -> void:
	_mode = "letters"
	_session_game_mode = "letters"
	_session_coins_earned = 0
	_rounds_done = 0
	_clear_dynamic()

	var all_letters = LETTER_LIST.duplicate()
	all_letters.shuffle()
	_chosen_letters = all_letters.slice(0, MAX_ROUNDS)

	_build_letters_ui()
	_show_next_letter()

func _build_letters_ui() -> void:
	# Library title
	var title = Label.new()
	title.text = "ALPHABET LIBRARY"
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
		_feedback_label.text = "Correct! +2 coins!"
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		PlayerData.add_coins(2)
		_session_coins_earned += 2
		_hud_coins.text = "Coins: %d" % PlayerData.coins

		var is_fertilizer_reward = ((PlayerData.words_read + 1) % FERTILIZER_EVERY == 0)
		if is_fertilizer_reward:
			PlayerData.add_item("fertilizer", 1)
			_feedback_label.text = "Excellent! +2 coins and Fertilizer!"

		PlayerData.words_read += 1
	else:
		var correct_lower = _current_letter[0].to_lower()
		_feedback_label.text = "Not quite! The answer was '%s'" % correct_lower.to_upper()
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1))

	_rounds_done += 1
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(_show_next_letter)

# ══════════════════════════════════════════════════════════════════════════════
# MODE 2: READING COMPREHENSION
# ══════════════════════════════════════════════════════════════════════════════

func _start_reading_game() -> void:
	_mode = "reading"
	_session_game_mode = "reading"
	_session_coins_earned = 0
	_reading_question_idx = 0
	_reading_correct = 0
	_clear_dynamic()

	# Pick a random story
	var stories = STORIES.duplicate()
	stories.shuffle()
	_current_story = stories[0]

	_build_reading_ui()
	_show_reading_question()

func _build_reading_ui() -> void:
	# Story title
	var title = Label.new()
	title.text = _current_story["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.35, 0.18, 0.04))
	title.position = Vector2(170, 134)
	title.size = Vector2(620, 30)
	_puzzle_overlay.add_child(_tag(title))

	# Story text (large label with autowrap)
	_story_label = Label.new()
	_story_label.text = _current_story["text"]
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.add_theme_font_size_override("font_size", 16)
	_story_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.04))
	_story_label.position = Vector2(195, 168)
	_story_label.size = Vector2(570, 100)
	_puzzle_overlay.add_child(_tag(_story_label))

	# Question label
	_reading_q_label = Label.new()
	_reading_q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reading_q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reading_q_label.add_theme_font_size_override("font_size", 20)
	_reading_q_label.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
	_reading_q_label.position = Vector2(195, 280)
	_reading_q_label.size = Vector2(570, 40)
	_puzzle_overlay.add_child(_tag(_reading_q_label))

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 22)
	_feedback_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	_feedback_label.position = Vector2(170, 328)
	_feedback_label.size = Vector2(620, 34)
	_feedback_label.text = ""
	_puzzle_overlay.add_child(_tag(_feedback_label))

	# 3 answer buttons stacked vertically
	_reading_buttons.clear()
	var btn_colors = [Color(0.75, 0.2, 0.2), Color(0.2, 0.55, 0.75), Color(0.55, 0.2, 0.75)]
	for i in range(3):
		var btn = GameManager.make_button("", Vector2(250, 370 + i * 42), Vector2(460, 36), btn_colors[i])
		btn.add_theme_font_size_override("font_size", 16)
		var btn_idx = i
		btn.pressed.connect(func(): _check_reading_answer(btn_idx))
		_puzzle_overlay.add_child(_tag(btn))
		_reading_buttons.append(btn)

func _show_reading_question() -> void:
	if _reading_question_idx >= _current_story["questions"].size():
		_show_results()
		return

	var q_data = _current_story["questions"][_reading_question_idx]
	_progress_label.text = "Question %d / %d" % [_reading_question_idx + 1, _current_story["questions"].size()]
	_reading_q_label.text = q_data["q"]
	if _feedback_label:
		_feedback_label.text = ""

	for i in range(3):
		_reading_buttons[i].text = q_data["choices"][i]
		_reading_buttons[i].set_meta("correct", i == q_data["answer"])
		_reading_buttons[i].disabled = false

func _check_reading_answer(btn_idx: int) -> void:
	var btn = _reading_buttons[btn_idx]
	var is_correct = btn.get_meta("correct", false)

	for b in _reading_buttons:
		b.disabled = true

	var q_data = _current_story["questions"][_reading_question_idx]

	if is_correct:
		_reading_correct += 1
		_feedback_label.text = "Correct! +3 coins!"
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		PlayerData.add_coins(3)
		_session_coins_earned += 3
		_hud_coins.text = "Coins: %d" % PlayerData.coins

		var is_fertilizer_reward = ((PlayerData.words_read + 1) % FERTILIZER_EVERY == 0)
		if is_fertilizer_reward:
			PlayerData.add_item("fertilizer", 1)
			_feedback_label.text = "Correct! +3 coins and Fertilizer!"

		PlayerData.words_read += 1
	else:
		var correct_text = q_data["choices"][q_data["answer"]]
		_feedback_label.text = "Not quite! Answer: %s" % correct_text
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1))

	_reading_question_idx += 1
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(_show_reading_question)

# ══════════════════════════════════════════════════════════════════════════════
# MODE 3: SPELLING BEE
# ══════════════════════════════════════════════════════════════════════════════

func _start_spelling_game() -> void:
	_mode = "spelling"
	_session_game_mode = "spelling"
	_session_coins_earned = 0
	_spelling_round = 0
	_spelling_correct = 0
	_clear_dynamic()

	# Pick random words
	var all_words = SPELLING_WORDS.duplicate()
	all_words.shuffle()
	_chosen_spelling_words = all_words.slice(0, SPELLING_ROUNDS)

	_build_spelling_ui()
	_show_next_spelling()

func _build_spelling_ui() -> void:
	# Title
	var title = Label.new()
	title.text = "SPELLING BEE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.35, 0.18, 0.04))
	title.position = Vector2(170, 134)
	title.size = Vector2(620, 30)
	_puzzle_overlay.add_child(_tag(title))

	# Definition label
	_spelling_def_label = Label.new()
	_spelling_def_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spelling_def_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spelling_def_label.add_theme_font_size_override("font_size", 20)
	_spelling_def_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.04))
	_spelling_def_label.position = Vector2(210, 168)
	_spelling_def_label.size = Vector2(540, 65)
	_puzzle_overlay.add_child(_tag(_spelling_def_label))

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 22)
	_feedback_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	_feedback_label.position = Vector2(170, 240)
	_feedback_label.size = Vector2(620, 34)
	_feedback_label.text = ""
	_puzzle_overlay.add_child(_tag(_feedback_label))

	# 3 word choice buttons
	_spelling_buttons.clear()
	var btn_colors = [Color(0.75, 0.2, 0.2), Color(0.2, 0.55, 0.75), Color(0.55, 0.2, 0.75)]
	for i in range(3):
		var btn = GameManager.make_button("", Vector2(196 + i * 190, 290), Vector2(172, 56), btn_colors[i])
		btn.add_theme_font_size_override("font_size", 24)
		var btn_idx = i
		btn.pressed.connect(func(): _check_spelling(btn_idx))
		_puzzle_overlay.add_child(_tag(btn))
		_spelling_buttons.append(btn)

func _show_next_spelling() -> void:
	if _spelling_round >= _chosen_spelling_words.size():
		_show_results()
		return

	_current_spelling = _chosen_spelling_words[_spelling_round]
	_progress_label.text = "Word %d / %d" % [_spelling_round + 1, _chosen_spelling_words.size()]
	_spelling_def_label.text = _current_spelling["definition"]
	if _feedback_label:
		_feedback_label.text = ""

	# Build choices: correct word + 2 wrongs, shuffled
	var choices = [_current_spelling["word"]]
	for w in _current_spelling["wrongs"]:
		choices.append(w)
	choices.shuffle()

	for i in range(3):
		_spelling_buttons[i].text = choices[i]
		_spelling_buttons[i].set_meta("correct", choices[i] == _current_spelling["word"])
		_spelling_buttons[i].disabled = false

func _check_spelling(btn_idx: int) -> void:
	var btn = _spelling_buttons[btn_idx]
	var is_correct = btn.get_meta("correct", false)

	for b in _spelling_buttons:
		b.disabled = true

	if is_correct:
		_spelling_correct += 1
		_feedback_label.text = "Correct! +3 coins!"
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		PlayerData.add_coins(3)
		_session_coins_earned += 3
		_hud_coins.text = "Coins: %d" % PlayerData.coins

		var is_fertilizer_reward = ((PlayerData.words_read + 1) % FERTILIZER_EVERY == 0)
		if is_fertilizer_reward:
			PlayerData.add_item("fertilizer", 1)
			_feedback_label.text = "Correct! +3 coins and Fertilizer!"

		PlayerData.words_read += 1
	else:
		_feedback_label.text = "Not quite! The word was '%s'" % _current_spelling["word"]
		_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1))

	_spelling_round += 1
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(_show_next_spelling)

# ══════════════════════════════════════════════════════════════════════════════
# RESULTS (shared across all modes)
# ══════════════════════════════════════════════════════════════════════════════

func _show_results() -> void:
	_mode = "results"
	_clear_dynamic()

	var result = Label.new()
	result.text = "Wonderful Work, %s!" % PlayerData.player_name
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 28)
	result.add_theme_color_override("font_color", Color(0.25, 0.12, 0.02))
	result.position = Vector2(170, 148)
	result.size = Vector2(620, 44)
	_puzzle_overlay.add_child(_tag(result))

	# Mode-specific summary
	var summary_text = ""
	match _session_game_mode:
		"letters":
			summary_text = "Letters matched: %d / %d\nCoins earned: %d" % [
				_session_coins_earned / 2, MAX_ROUNDS, _session_coins_earned]
		"reading":
			summary_text = "Story: %s\nCorrect answers: %d / %d\nCoins earned: %d" % [
				_current_story["title"], _reading_correct, READING_QUESTIONS, _session_coins_earned]
		"spelling":
			summary_text = "Words spelled: %d / %d\nCoins earned: %d" % [
				_spelling_correct, SPELLING_ROUNDS, _session_coins_earned]

	var stats = Label.new()
	stats.text = summary_text
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(0.35, 0.2, 0.05))
	stats.position = Vector2(170, 208)
	stats.size = Vector2(620, 80)
	_puzzle_overlay.add_child(_tag(stats))

	var totals = Label.new()
	totals.text = "Total words learned: %d   |   Coins: %d   |   Fertilizer: %d" % [
		PlayerData.words_read, PlayerData.coins, PlayerData.get_item_count("fertilizer")]
	totals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	totals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	totals.add_theme_font_size_override("font_size", 16)
	totals.add_theme_color_override("font_color", Color(0.45, 0.28, 0.08))
	totals.position = Vector2(170, 302)
	totals.size = Vector2(620, 40)
	_puzzle_overlay.add_child(_tag(totals))

	var hint = GameManager.make_label(
		"Use fertilizer on your farm crops for faster growth!",
		Vector2(170, 350), 16, Color(0.45, 0.28, 0.08))
	_puzzle_overlay.add_child(_tag(hint))

	var play_again = GameManager.make_button("Play Again!", Vector2(265, 390), Vector2(180, 52), Color(0.35, 0.55, 0.2))
	play_again.pressed.connect(func(): _show_game_menu())
	_puzzle_overlay.add_child(_tag(play_again))

	var leave_btn = GameManager.make_button("Leave Library", Vector2(515, 390), Vector2(180, 52), Color(0.3, 0.22, 0.12))
	leave_btn.pressed.connect(func(): _leave())
	_puzzle_overlay.add_child(_tag(leave_btn))

	PlayerData.save_game()


# ── Inner classes ─────────────────────────────────────────────────────────────

class _FloorPlanks extends Node2D:
	func _draw() -> void:
		# Plank seams — alternating offset for herringbone feel
		for i in range(9):
			var y = 278 + i * 30
			draw_rect(Rect2(0, y, 960, 1), Color(0.42, 0.28, 0.14, 0.6))
		# Vertical plank joints (staggered)
		for i in range(9):
			var y = 278 + i * 30
			var offset = 60 if i % 2 == 0 else 120
			var x = offset
			while x < 960:
				draw_rect(Rect2(x, y, 1, 30), Color(0.42, 0.28, 0.14, 0.3))
				x += 160
		# Subtle wood grain
		var grains = [
			[80, 283, 170, 283], [230, 315, 340, 315], [410, 347, 510, 347],
			[600, 279, 690, 279], [740, 311, 840, 311], [50, 343, 140, 343],
			[320, 395, 400, 395], [550, 430, 650, 430], [150, 460, 250, 460],
			[700, 380, 790, 380], [450, 475, 560, 475],
		]
		for g in grains:
			draw_line(Vector2(g[0], g[1]), Vector2(g[2], g[3]), Color(0.48, 0.34, 0.18, 0.3), 1)


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
		_sprite.flip_h = (facing == "right")
		_sprite.frame = int(walk_frame * 4) % 4 if is_moving else 0

	func _draw() -> void:
		pass
