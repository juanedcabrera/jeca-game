extends Node2D

# House interior — intro on first visit, sleep-on-bed on all visits.

const PLAYER_SPEED = 130.0
const BED_CENTER   = Vector2(110, 280)
const DOOR_CENTER  = Vector2(480, 460)

# Pixelwood Valley sprite paths
const PW_SPRITES = {
	"bed": "res://Pixelwood Valley 1.1.2/interior/Bed/BED.PNG",
	"desk": "res://Pixelwood Valley 1.1.2/interior/furniture/DESK_FRONT.png",
	"bookshelf": "res://Pixelwood Valley 1.1.2/interior/furniture/BOOKSHELF.png",
	"window": "res://Pixelwood Valley 1.1.2/interior/furniture/WINDOW.png",
	"chair": "res://Pixelwood Valley 1.1.2/interior/furniture/chair_FRONT.png",
	"table": "res://Pixelwood Valley 1.1.2/interior/furniture/table.png",
	"interior_tiles": "res://Pixelwood Valley 1.1.2/interior/tiles.PNG",
	# Player - Boy
	"boy_idle_up": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Up.png",
	"boy_idle_down": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png",
	"boy_idle_side": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Side.png",
	"boy_walk_up": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Up.png",
	"boy_walk_down": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Down.png",
	"boy_walk_side": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Side.png",
	# Player - Girl
	"girl_sprite": "res://Pixelwood Valley 1.1.2/NPCs/4.png",
}

var _dialogue_lines: Array = []
var _dialogue_index: int = 0
var _dialogue_label: Label
var _continue_btn: Button
var _dialogue_box: Control     # shown/hidden depending on mode
var _interact_label: Label
var _interact_ribbon: Control  # parent container for interact hint

var _player: CharacterBody2D
var _player_drawer: Node2D
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_zone: String = ""    # "bed" | "door" | ""
var _in_dialogue: bool = false
var _sleeping: bool = false
var _transitioning: bool = false

func _ready() -> void:
	_build_scene()
	_build_player()
	if not PlayerData.intro_seen:
		_start_intro()
	else:
		_show_free_hint()

# ── Scene ─────────────────────────────────────────────────────────────────────

func _build_scene() -> void:
	# Floor
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.72, 0.55, 0.35)
	floor_rect.size = Vector2(960, 340)
	floor_rect.position = Vector2(0, 200)
	add_child(floor_rect)

	# Walls
	var wall = ColorRect.new()
	wall.color = Color(0.92, 0.82, 0.65)
	wall.size = Vector2(960, 210)
	wall.position = Vector2(0, 0)
	add_child(wall)

	var base = ColorRect.new()
	base.color = Color(0.55, 0.38, 0.2)
	base.size = Vector2(960, 12)
	base.position = Vector2(0, 198)
	add_child(base)

	var deco = _RoomDeco.new()
	deco.position = Vector2.ZERO
	add_child(deco)

	var bed = _BedDrawer.new()
	bed.position = Vector2(60, 240)
	add_child(bed)

	var desk = _DeskDrawer.new()
	desk.position = Vector2(760, 240)
	add_child(desk)

	# Door at bottom-center (visual)
	var door_deco = _DoorDrawer.new()
	door_deco.position = Vector2(440, 370)
	add_child(door_deco)

	# Interaction hint ribbon — fixed at bottom of screen
	_interact_ribbon = Control.new()
	_interact_ribbon.visible = false
	_interact_ribbon.position = Vector2(0, 494)
	_interact_ribbon.z_index = 10
	var hint_bg = ColorRect.new()
	hint_bg.color = Color(0.05, 0.03, 0.0, 0.90)
	hint_bg.size = Vector2(960, 42)
	_interact_ribbon.add_child(hint_bg)

	_interact_label = Label.new()
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.add_theme_font_size_override("font_size", 18)
	_interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_interact_label.position = Vector2(0, 7)
	_interact_label.size = Vector2(960, 28)
	_interact_ribbon.add_child(_interact_label)
	add_child(_interact_ribbon)


	# Dialogue box (hidden unless in intro or sleeping)
	_dialogue_box = Control.new()
	_dialogue_box.visible = false

	var diag_bg = ColorRect.new()
	diag_bg.color = Color(0.08, 0.05, 0.02, 0.92)
	diag_bg.size = Vector2(900, 120)
	diag_bg.position = Vector2(30, 395)
	_dialogue_box.add_child(diag_bg)

	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 20)
	_dialogue_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_dialogue_label.position = Vector2(50, 405)
	_dialogue_label.size = Vector2(860, 100)
	_dialogue_box.add_child(_dialogue_label)

	_continue_btn = GameManager.make_button("Continue >", Vector2(730, 478), Vector2(200, 44), Color(0.25, 0.5, 0.2))
	_continue_btn.add_theme_font_size_override("font_size", 18)
	_continue_btn.pressed.connect(_advance_dialogue)
	_dialogue_box.add_child(_continue_btn)

	add_child(_dialogue_box)

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

	_player_drawer = _RoomPlayer.new()
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

	_player.position = Vector2(480, 340)
	add_child(_player)

	# Room boundary walls
	_add_wall(Vector2(0, 180), Vector2(960, 30))   # top of floor (thick to prevent overlap with baseboard)
	_add_wall(Vector2(0, 520), Vector2(960, 10))   # bottom
	_add_wall(Vector2(0, 180), Vector2(10, 350))   # left
	_add_wall(Vector2(950, 180), Vector2(10, 350)) # right
	# Bed collision
	_add_wall(Vector2(55, 235), Vector2(170, 110))
	# Desk collision
	_add_wall(Vector2(755, 235), Vector2(150, 110))

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var w = StaticBody2D.new()
	w.collision_layer = 2
	var col = CollisionShape2D.new()
	var sh = RectangleShape2D.new()
	sh.size = size
	col.shape = sh
	col.position = pos + size * 0.5
	w.add_child(col)
	add_child(w)

# ── Dialogue ───────────────────────────────────────────────────────────────────

func _start_intro() -> void:
	_in_dialogue = true
	_dialogue_box.visible = true
	var n = PlayerData.player_name
	_dialogue_lines = [
		"Good morning, %s! Today is Day %d on the Cabrera Farm." % [n, PlayerData.day],
		"Grandma Rosa left you this farm to take care of.",
		"Earn coins at the Math Mines ↑ by solving math problems!",
		"The Literacy Library → unlocks special seeds and fertilizers.",
		"Spend coins at the Juarez Market ↓ to buy seeds, livestock, and tools.",
		"Walk back here and sleep in your bed to end the day and save.",
		"Now go outside and explore! The farm is waiting for you, %s!" % n,
	]
	_dialogue_index = 0
	_dialogue_label.text = _dialogue_lines[0]

func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_end_dialogue()
	else:
		_dialogue_label.text = _dialogue_lines[_dialogue_index]

func _end_dialogue() -> void:
	_in_dialogue = false
	_dialogue_box.visible = false
	PlayerData.intro_seen = true
	PlayerData.save_game()
	_show_free_hint()

func _show_free_hint() -> void:
	GameManager.show_message(self,
		"Walk to bed to sleep  |  Walk to door to go outside", 3.5)

# ── Input & Movement ───────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _in_dialogue or _sleeping:
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

	# Auto-exit through door
	if _player.position.y > 480 and _player.position.x > 420 and _player.position.x < 540:
		if not _transitioning:
			_transitioning = true
			PlayerData.save_game()
			_go_to_farm()
			return

	_check_nearby()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			GameManager.show_pause_menu(self)
		elif event.keycode == KEY_E:
			_interact()


func _check_nearby() -> void:
	_near_zone = ""
	var p = _player.position
	if p.distance_to(BED_CENTER) < 120:
		_near_zone = "bed"
	elif p.distance_to(DOOR_CENTER) < 90:
		_near_zone = "door"

	if _near_zone == "bed":
		_interact_ribbon.visible = true
		_interact_label.text = "[E] Sleep"
	elif _near_zone == "door":
		_interact_ribbon.visible = true
		_interact_label.text = "[E] Go Outside"
	else:
		_interact_ribbon.visible = false

func _interact() -> void:
	if _in_dialogue:
		_advance_dialogue()
		return
	match _near_zone:
		"bed":
			_do_sleep()
		"door":
			if not _transitioning:
				_transitioning = true
				_go_to_farm()

var _sleep_overlay: ColorRect
var _sleep_label: Label

func _do_sleep() -> void:
	_sleeping = true
	_interact_ribbon.visible = false
	_dialogue_box.visible = false

	# Create full-screen overlay for sleep animation
	_sleep_overlay = ColorRect.new()
	_sleep_overlay.color = Color(0, 0, 0, 0)
	_sleep_overlay.size = Vector2(960, 540)
	_sleep_overlay.z_index = 100
	add_child(_sleep_overlay)

	_sleep_label = Label.new()
	_sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sleep_label.add_theme_font_size_override("font_size", 36)
	_sleep_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_sleep_label.position = Vector2(0, 0)
	_sleep_label.size = Vector2(960, 540)
	_sleep_label.z_index = 101
	add_child(_sleep_label)

	# Phase 1: Fade to dark (1.2s)
	var fade_out = create_tween()
	fade_out.tween_property(_sleep_overlay, "color", Color(0, 0, 0.05, 1.0), 1.2)
	fade_out.tween_callback(_sleep_phase_night)

func _sleep_phase_night() -> void:
	# Show sleep text
	_sleep_label.text = "Good night, %s..." % PlayerData.player_name
	_sleep_label.add_theme_color_override("font_color", Color(0.7, 0.75, 1.0))

	# Advance the day and save
	PlayerData.advance_day()
	PlayerData.save_game()

	# Hold dark for 1.5s then transition to morning
	var hold = create_tween()
	hold.tween_interval(1.5)
	hold.tween_callback(_sleep_phase_dawn)

func _sleep_phase_dawn() -> void:
	# Change text to morning
	_sleep_label.text = "Day %d" % PlayerData.day
	_sleep_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	# Fade overlay to warm sunrise tint then clear
	var dawn = create_tween()
	dawn.tween_property(_sleep_overlay, "color", Color(1.0, 0.85, 0.5, 0.6), 0.8)
	dawn.tween_interval(1.0)
	dawn.tween_property(_sleep_overlay, "color", Color(1.0, 0.95, 0.8, 0.0), 0.8)
	dawn.tween_callback(_sleep_phase_done)

func _sleep_phase_done() -> void:
	# Clean up overlay
	if _sleep_overlay:
		_sleep_overlay.queue_free()
		_sleep_overlay = null
	if _sleep_label:
		_sleep_label.queue_free()
		_sleep_label = null

	# Show morning dialogue then go to farm
	_dialogue_lines = [
		"Your crops grew overnight. Don't forget to water them!",
	]
	_dialogue_index = 0
	_dialogue_label.text = _dialogue_lines[0]
	_dialogue_box.visible = true
	_in_dialogue = true
	if _continue_btn.pressed.is_connected(_advance_dialogue):
		_continue_btn.pressed.disconnect(_advance_dialogue)
	if not _continue_btn.pressed.is_connected(_advance_sleep_dialogue):
		_continue_btn.pressed.connect(_advance_sleep_dialogue)

func _advance_sleep_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_sleeping = false
		_in_dialogue = false
		_dialogue_box.visible = false
		_go_to_farm()
	else:
		_dialogue_label.text = _dialogue_lines[_dialogue_index]

func _go_to_farm() -> void:
	GameManager.go_to_farm("from_house")


# ── Room drawers ──────────────────────────────────────────────────────────────

class _RoomDeco extends Node2D:
	func _ready() -> void:
		# Window (14×16 → scale 4 = 56×64) centered on back wall
		var window = Sprite2D.new()
		window.texture = load(PW_SPRITES["window"])
		window.scale = Vector2(4.0, 4.0)
		window.position = Vector2(480, 80)
		add_child(window)

		# Big curtains flanking window (56×26 → scale 3 = 168×78)
		var curtains = Sprite2D.new()
		curtains.texture = load("res://Pixelwood Valley 1.1.2/interior/decorations/BIGCURTAINS.png")
		curtains.scale = Vector2(3.0, 3.0)
		curtains.position = Vector2(480, 80)
		add_child(curtains)

		# Bookshelf on right wall area (27×40 → scale 3 = 81×120)
		var shelf = Sprite2D.new()
		shelf.texture = load(PW_SPRITES["bookshelf"])
		shelf.scale = Vector2(3.0, 3.0)
		shelf.position = Vector2(820, 80)
		add_child(shelf)

		# Painting on left wall (22×12 → scale 4 = 88×48)
		var painting = Sprite2D.new()
		painting.texture = load("res://Pixelwood Valley 1.1.2/interior/decorations/pAINTING_1.png")
		painting.scale = Vector2(4.0, 4.0)
		painting.position = Vector2(210, 80)
		add_child(painting)

		# Blue carpet on floor center (86×70 → scale 3 = 258×210)
		var carpet = Sprite2D.new()
		carpet.texture = load("res://Pixelwood Valley 1.1.2/interior/carpet/BLUE/CARPET_1.png")
		carpet.scale = Vector2(3.0, 3.0)
		carpet.position = Vector2(480, 390)
		add_child(carpet)

	func _draw() -> void:
		pass


class _BedDrawer extends Node2D:
	func _ready() -> void:
		# BED.PNG: 24×41 → scale 4 = 96×164, centered at node origin
		var spr = Sprite2D.new()
		spr.texture = load(PW_SPRITES["bed"])
		spr.scale = Vector2(4.0, 4.0)
		spr.position = Vector2(0, 0)
		add_child(spr)

	func _draw() -> void:
		draw_string(ThemeDB.fallback_font, Vector2(-16, -90),
			"Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.75, 1.0))


class _DeskDrawer extends Node2D:
	func _ready() -> void:
		# DESK_FRONT.png: 43×26 → scale 3 = 129×78, centered at node origin
		var desk = Sprite2D.new()
		desk.texture = load(PW_SPRITES["desk"])
		desk.scale = Vector2(3.0, 3.0)
		desk.position = Vector2(0, 0)
		add_child(desk)

		# Chair in front of desk (11×18 → scale 3 = 33×54)
		var chair = Sprite2D.new()
		chair.texture = load(PW_SPRITES["chair"])
		chair.scale = Vector2(3.0, 3.0)
		chair.position = Vector2(0, 60)
		add_child(chair)

	func _draw() -> void:
		pass


class _DoorDrawer extends Node2D:
	func _draw() -> void:
		# Door frame
		draw_rect(Rect2(0, 0, 80, 130), Color(0.5, 0.3, 0.12))
		# Door fill
		draw_rect(Rect2(5, 5, 70, 120), Color(0.62, 0.42, 0.2))
		# Panels
		draw_rect(Rect2(10, 10, 28, 50), Color(0.55, 0.36, 0.16))
		draw_rect(Rect2(42, 10, 28, 50), Color(0.55, 0.36, 0.16))
		draw_rect(Rect2(10, 68, 60, 50), Color(0.55, 0.36, 0.16))
		# Knob
		draw_circle(Vector2(58, 68), 5, Color(0.85, 0.65, 0.1))
		# "Outside" label
		draw_string(ThemeDB.fallback_font, Vector2(-10, 148),
			"Outside", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.35, 0.55, 0.25))


class _RoomPlayer extends Node2D:
	var gender: String = "boy"
	var facing: String = "down"
	var walk_frame: float = 0.0
	var _sprite: Sprite2D
	var _last_tex_key: String = ""

	func _ready() -> void:
		_sprite = Sprite2D.new()
		if gender == "girl":
			_sprite.texture = load(PW_SPRITES["girl_sprite"])
			_sprite.hframes = 4
			_sprite.vframes = 7
			_sprite.frame = 0
		else:
			_sprite.hframes = 4
			_sprite.frame = 0
			_sprite.texture = load(PW_SPRITES["boy_idle_down"])
			_last_tex_key = "boy_idle_down"
		add_child(_sprite)

	func _process(_delta: float) -> void:
		if not _sprite:
			return
		var is_moving = walk_frame > 0
		_sprite.flip_h = (facing == "right")
		if gender == "girl":
			var row: int
			match facing:
				"up":
					row = 5 if is_moving else 2
				"left", "right":
					row = 4 if is_moving else 1
				_:
					row = 3 if is_moving else 0
			var col = int(walk_frame * 4) % 4 if is_moving else 0
			_sprite.frame = row * 4 + col
		else:
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
			_sprite.frame = int(walk_frame * 4) % 4 if is_moving else 0

	func _draw() -> void:
		pass
