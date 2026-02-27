extends Node2D

var _cloud_positions: Array = []
var _cloud_speeds: Array = []
var _title_bob: float = 0.0
var _title_label: Label

# Slot cards are rebuilt whenever we return to the start screen
var _slot_cards: Array = []  # Array of Control nodes (for rebuild)
var _sync_label: Label       # "Syncing…" indicator

func _ready() -> void:
	# If not logged in, redirect to login screen
	if not Supabase.is_logged_in:
		GameManager.change_scene("login_screen")
		return
	_build_scene()
	# Async: sync cloud saves, then show cards
	_sync_label.visible = true
	await Supabase.fetch_and_sync_slots()
	_sync_label.visible = false
	_build_slot_cards()

func _build_scene() -> void:
	# Sky background
	var sky = ColorRect.new()
	sky.color = Color(0.39, 0.69, 1.0)
	sky.size = Vector2(960, 540)
	add_child(sky)

	# Sun
	var sun = _make_sun()
	add_child(sun)

	# Clouds (stored for animation)
	for i in range(4):
		var cx = randf_range(0, 900)
		var cy = randf_range(40, 140)
		_cloud_positions.append(Vector2(cx, cy))
		_cloud_speeds.append(randf_range(15, 35))

	# Green hills
	var hills = _HillsDrawer.new()
	hills.position = Vector2.ZERO
	add_child(hills)

	# Farm decorations
	_add_decorations()

	# Title panel
	var title_bg = ColorRect.new()
	title_bg.color = Color(0.1, 0.05, 0.0, 0.72)
	title_bg.size = Vector2(620, 90)
	title_bg.position = Vector2(170, 50)
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	add_child(title_bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "CABRERA HARVEST"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 54)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.5, 0.25, 0.0))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.position = Vector2(170, 58)
	_title_label.size = Vector2(620, 80)
	add_child(_title_label)

	# Subtitle
	var sub = Label.new()
	sub.text = "Choose Your Player"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	sub.position = Vector2(280, 152)
	sub.size = Vector2(400, 30)
	add_child(sub)

	# "Syncing…" label (visible while cloud fetch is in progress)
	_sync_label = Label.new()
	_sync_label.text = "Syncing saves…"
	_sync_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sync_label.add_theme_font_size_override("font_size", 18)
	_sync_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.7))
	_sync_label.position = Vector2(330, 310)
	_sync_label.size = Vector2(300, 30)
	_sync_label.visible = false  # shown in _ready() before sync
	add_child(_sync_label)

	# Signed-in email + Sign Out
	var email_lbl = Label.new()
	email_lbl.text = Supabase.get_user_email()
	email_lbl.add_theme_font_size_override("font_size", 13)
	email_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.6))
	email_lbl.position = Vector2(20, 514)
	email_lbl.size = Vector2(700, 22)
	add_child(email_lbl)

	var sign_out_btn = GameManager.make_button("Sign Out", Vector2(820, 506), Vector2(120, 30), Color(0.35, 0.15, 0.1))
	sign_out_btn.add_theme_font_size_override("font_size", 14)
	sign_out_btn.pressed.connect(_on_sign_out)
	add_child(sign_out_btn)

	# Credits
	var credit = Label.new()
	credit.text = "Made with love by the Cabrera Family"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 13)
	credit.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	credit.position = Vector2(260, 494)
	credit.size = Vector2(440, 22)
	add_child(credit)

func _build_slot_cards() -> void:
	# Remove old cards if any (for rebuild)
	for c in _slot_cards:
		c.queue_free()
	_slot_cards.clear()

	# Card layout: 3 cards side by side
	# Screen: 960×540; cards at y=190, each 280×200 with 20px gap
	var card_w = 270.0
	var card_h = 210.0
	var total_w = card_w * 3 + 20 * 2  # 870
	var start_x = (960 - total_w) / 2.0  # 45

	for slot in range(3):
		var cx = start_x + slot * (card_w + 20)
		var cy = 185.0
		var preview = PlayerData.read_slot_preview(slot)
		var card = _make_slot_card(slot, cx, cy, card_w, card_h, preview)
		add_child(card)
		_slot_cards.append(card)

func _make_slot_card(slot: int, x: float, y: float, w: float, h: float, preview: Dictionary) -> Control:
	var container = Control.new()
	container.position = Vector2(x, y)
	container.size = Vector2(w, h)

	# Card background
	var bg = ColorRect.new()
	bg.size = Vector2(w, h)
	var has_save = preview.get("exists", false)
	bg.color = Color(0.1, 0.06, 0.02, 0.88) if has_save else Color(0.05, 0.1, 0.05, 0.75)
	container.add_child(bg)

	# Border drawer
	var border = _CardBorder.new()
	border.card_size = Vector2(w, h)
	border.has_save = has_save
	container.add_child(border)

	# Slot number badge
	var badge = Label.new()
	badge.text = "Player %d" % (slot + 1)
	badge.position = Vector2(10, 8)
	badge.size = Vector2(w - 20, 24)
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	container.add_child(badge)

	if has_save:
		# Character avatar
		var gender = preview.get("player_gender", "boy")
		var avatar = _MiniAvatar.new()
		avatar.gender = gender
		avatar.position = Vector2(w / 2.0, 80)
		container.add_child(avatar)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = preview.get("player_name", "Friend")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, 115)
		name_lbl.size = Vector2(w, 28)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		container.add_child(name_lbl)

		# Day + coins
		var info_lbl = Label.new()
		info_lbl.text = "Day %d  •  %d coins" % [preview.get("day", 1), preview.get("coins", 10)]
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.position = Vector2(0, 142)
		info_lbl.size = Vector2(w, 22)
		info_lbl.add_theme_font_size_override("font_size", 14)
		info_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
		container.add_child(info_lbl)

		# Play button
		var play_btn = GameManager.make_button("Play", Vector2(20, 168), Vector2(w - 80, 36), Color(0.15, 0.5, 0.15))
		play_btn.add_theme_font_size_override("font_size", 18)
		play_btn.pressed.connect(func(): _on_slot_play(slot))
		container.add_child(play_btn)

		# Delete button (small, red)
		var del_btn = GameManager.make_button("✕", Vector2(w - 54, 168), Vector2(34, 36), Color(0.55, 0.12, 0.12))
		del_btn.add_theme_font_size_override("font_size", 16)
		del_btn.pressed.connect(func(): _on_slot_delete(slot))
		container.add_child(del_btn)
	else:
		# Empty slot — big "New Game" button area
		var plus_lbl = Label.new()
		plus_lbl.text = "+"
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.position = Vector2(0, 55)
		plus_lbl.size = Vector2(w, 60)
		plus_lbl.add_theme_font_size_override("font_size", 52)
		plus_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.35, 0.8))
		container.add_child(plus_lbl)

		var new_btn = GameManager.make_button("New Game", Vector2(35, 152), Vector2(w - 70, 42), Color(0.18, 0.48, 0.18))
		new_btn.add_theme_font_size_override("font_size", 18)
		new_btn.pressed.connect(func(): _on_slot_new(slot))
		container.add_child(new_btn)

	return container

func _make_sun() -> Node2D:
	var sun_node = Node2D.new()
	sun_node.position = Vector2(820, 80)
	var drawer = _SunDrawer.new()
	sun_node.add_child(drawer)
	return sun_node

func _add_decorations() -> void:
	var decor = _DecorDrawer.new()
	decor.position = Vector2.ZERO
	add_child(decor)

func _process(delta: float) -> void:
	if _cloud_positions.is_empty():
		return  # Scene not built yet (redirecting to login)
	# Bob the title
	_title_bob += delta * 1.5
	if _title_label:
		_title_label.position.y = 58 + sin(_title_bob) * 4.0

	# Move clouds
	for i in range(_cloud_positions.size()):
		_cloud_positions[i].x += _cloud_speeds[i] * delta
		if _cloud_positions[i].x > 1020:
			_cloud_positions[i].x = -120
	queue_redraw()

func _draw() -> void:
	for pos in _cloud_positions:
		_draw_cloud(pos)

func _draw_cloud(pos: Vector2) -> void:
	var c = Color(1, 1, 1, 0.85)
	draw_circle(pos, 28, c)
	draw_circle(pos + Vector2(30, 8), 22, c)
	draw_circle(pos + Vector2(-28, 8), 20, c)
	draw_circle(pos + Vector2(10, -10), 24, c)
	draw_rect(Rect2(pos + Vector2(-40, 8), Vector2(108, 28)), c)

# ── Slot actions ──────────────────────────────────────────────────────────────

func _on_slot_play(slot: int) -> void:
	if PlayerData.load_slot(slot):
		GameManager.go_to_farm("from_house")

func _on_slot_new(slot: int) -> void:
	PlayerData.reset()
	PlayerData.current_slot = slot
	GameManager.change_scene("character_creation")

func _on_slot_delete(slot: int) -> void:
	PlayerData.delete_slot(slot)
	_build_slot_cards()  # Refresh cards immediately from local state
	Supabase.delete_slot_from_db(slot)  # Fire-and-forget cloud delete

func _on_sign_out() -> void:
	Supabase.sign_out()
	GameManager.change_scene("login_screen")


# ── Inner drawers ─────────────────────────────────────────────────────────────

class _CardBorder extends Node2D:
	var card_size: Vector2 = Vector2(270, 210)
	var has_save: bool = false

	func _draw() -> void:
		var col = Color(0.55, 0.4, 0.15) if has_save else Color(0.25, 0.45, 0.2)
		var r = Rect2(Vector2.ZERO, card_size)
		draw_rect(r, col, false, 2.5)


class _MiniAvatar extends Node2D:
	var gender: String = "boy"

	func _ready() -> void:
		var spr = Sprite2D.new()
		# Player Idle/Down: 236×49, hframes=4 → each frame 59×49
		spr.texture = load("res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png")
		spr.hframes = 4
		spr.frame = 0
		spr.scale = Vector2(1.8, 1.8)
		if gender == "girl":
			spr.modulate = Color(1.05, 0.78, 0.92)
		add_child(spr)

	func _draw() -> void:
		pass


class _SunDrawer extends Node2D:
	func _draw() -> void:
		var gold = Color(1.0, 0.85, 0.1)
		draw_circle(Vector2.ZERO, 42, gold)
		for i in range(8):
			var angle = i * PI / 4.0
			var inner = Vector2(cos(angle), sin(angle)) * 50
			var outer = Vector2(cos(angle), sin(angle)) * 68
			draw_line(inner, outer, gold, 5, true)


class _HillsDrawer extends Node2D:
	func _draw() -> void:
		var pts1 = PackedVector2Array()
		pts1.append(Vector2(-10, 540))
		pts1.append(Vector2(-10, 390))
		for x in range(0, 971, 20):
			var y = 390 - sin(x * 0.008) * 60 - cos(x * 0.013) * 30
			pts1.append(Vector2(x, y))
		pts1.append(Vector2(970, 540))
		draw_colored_polygon(pts1, Color(0.36, 0.56, 0.29))

		var pts2 = PackedVector2Array()
		pts2.append(Vector2(-10, 540))
		pts2.append(Vector2(-10, 440))
		for x in range(0, 971, 20):
			var y = 450 - sin(x * 0.012 + 1.0) * 40 - cos(x * 0.007) * 25
			pts2.append(Vector2(x, y))
		pts2.append(Vector2(970, 540))
		draw_colored_polygon(pts2, Color(0.29, 0.47, 0.22))


# Pixelwood Valley sprites for start screen
const PW_START = {
	"tree": "res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
}

class _DecorDrawer extends Node2D:
	var _tree_sprites: Array = []
	var _tree_variants = [
		"res://Pixelwood Valley 1.1.2/Trees/Tree1.png",
		"res://Pixelwood Valley 1.1.2/Trees/2.png",
		"res://Pixelwood Valley 1.1.2/Trees/3.png",
		"res://Pixelwood Valley 1.1.2/Trees/4.png",
		"res://Pixelwood Valley 1.1.2/Trees/5.png",
		"res://Pixelwood Valley 1.1.2/Trees/6.png",
	]
	
	func _ready() -> void:
		var positions = [Vector2(60, 490), Vector2(130, 500), Vector2(830, 495), Vector2(900, 488)]
		for p in positions:
			var spr = Sprite2D.new()
			spr.texture = load(_tree_variants[randi() % _tree_variants.size()])
			spr.scale = Vector2(0.8, 0.8)
			spr.position = p + Vector2(0, -40)
			_tree_sprites.append(spr)
			add_child(spr)

	func _draw() -> void:
		# Background grass tufts (simple decorations)
		for i in range(20):
			var x = randf() * 960
			var y = 400 + randf() * 140
			draw_circle(Vector2(x, y), 2, Color(0.3, 0.5, 0.2))
