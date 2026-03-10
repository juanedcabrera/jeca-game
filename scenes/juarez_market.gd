extends Node2D

# ── The Juarez Market (walkable village scene) ────────────────────────────────

const PLAYER_SPEED = 140.0

const PW_NPC = {
	"sofi":     "res://Pixelwood Valley 1.1.2/NPCs/2.png",
	"lucas":    "res://Pixelwood Valley 1.1.2/NPCs/1.png",
	"merchant": "res://Pixelwood Valley 1.1.2/NPCs/5.png",
}

const PW_SPRITES = {
	"boy_idle_up":   "res://Pixelwood Valley 1.1.2/Player Character/Idle/Up.png",
	"boy_idle_down": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Down.png",
	"boy_idle_side": "res://Pixelwood Valley 1.1.2/Player Character/Idle/Side.png",
	"boy_walk_up":   "res://Pixelwood Valley 1.1.2/Player Character/Walk/Up.png",
	"boy_walk_down": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Down.png",
	"boy_walk_side": "res://Pixelwood Valley 1.1.2/Player Character/Walk/Side.png",
	"girl_sprite": "res://Pixelwood Valley 1.1.2/NPCs/4.png",
}

const NPC_POSITIONS = {
	"sofi":     Vector2(200, 310),
	"lucas":    Vector2(480, 310),
	"merchant": Vector2(760, 310),
}

const NPC_TABS = {
	"sofi":     "seeds",
	"lucas":    "livestock",
	"merchant": "tools",
}

const NPC_NAMES = {
	"sofi":     "Sofi (Seeds)",
	"lucas":    "Lucas (Livestock)",
	"merchant": "Abuelo (Supplies)",
}

const ICON_PATH = "res://generated_sprites/icons/"

const SHOP_ITEMS = {
	"seeds": [
		{"id": "sunflower_seeds", "name": "Sofi's Sunflower Seeds", "cost": 5,  "label": "Sunflower Seeds", "desc": "Grows in 2 days, harvest sells for 6"},
		{"id": "carrot_seeds",    "name": "Sofi's Carrot Seeds",    "cost": 8,  "label": "Carrot Seeds", "desc": "Grows in 3 days, harvest sells for 10"},
		{"id": "strawberry_seeds","name": "Sofi's Strawberry Seeds","cost": 12, "label": "Strawberry Seeds", "desc": "Grows in 4 days, harvest sells for 16!"},
	],
	"livestock": [
		{"id": "chicken", "name": "Lucas's Chicken", "cost": 15, "label": "Chicken", "desc": "Produces eggs (sell for 2 each)"},
		{"id": "pig",     "name": "Lucas's Pig",     "cost": 20, "label": "Pig", "desc": "Produces bacon (sell for 3 each)"},
		{"id": "cow",     "name": "Lucas's Cow",     "cost": 30, "label": "Cow", "desc": "Produces milk (sell for 5 each)"},
	],
	"tools": [
		{"id": "sprinkler",   "name": "Sprinkler",    "cost": 40, "label": "Sprinkler", "desc": "Auto-waters all crops each day"},
		{"id": "fertilizer",  "name": "Fertilizer",   "cost": 15, "label": "Fertilizer", "desc": "Speeds up crop growth by 1 day"},
		{"id": "animal_food", "name": "Animal Food",  "cost": 8,  "label": "Feed", "desc": "Feed & water your livestock (1/day)"},
	],
}

const SELL_ITEMS = {
	"seeds": [
		{"id": "sunflower", "name": "Sunflower", "price": 6},
		{"id": "carrot", "name": "Carrot", "price": 10},
		{"id": "strawberry", "name": "Strawberry", "price": 16},
	],
	"livestock": [
		{"id": "egg", "name": "Egg", "price": 2},
		{"id": "bacon", "name": "Bacon", "price": 3},
		{"id": "milk", "name": "Milk", "price": 5},
	],
	"tools": [],
}

var _mode: String = "walk"   # "walk" | "shop"
var _active_npc: String = ""
var _active_tab: String = "seeds"
var _tab_buttons: Dictionary = {}

var _player: CharacterBody2D
var _player_drawer: Node2D
var _facing: String = "down"
var _walk_frame: float = 0.0
var _near_npc: String = ""
var _transitioning: bool = false

var _hud_coins: Label
var _action_ribbon: Control
var _action_label: Label
var _shop_overlay: Control
var _overlay_coins: Label
var _item_list_node: Control
var _feedback_label: Label

func _ready() -> void:
	_build_scene()
	_build_player()
	_build_hud()
	_build_shop_overlay()
	PlayerData.coins_changed.connect(_on_coins_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _mode == "shop":
				_close_shop()
			else:
				GameManager.show_pause_menu(self)
		elif event.keycode == KEY_E and _mode == "walk" and _near_npc != "":
			_open_shop(_near_npc)


# ── Scene ─────────────────────────────────────────────────────────────────────

func _build_scene() -> void:
	# Sky (small strip at very top)
	var sky = ColorRect.new()
	sky.color = Color(0.55, 0.76, 0.93)
	sky.size = Vector2(960, 60)
	add_child(sky)

	# Pavement behind shops (y=60 to y=280)
	var back_pave = ColorRect.new()
	back_pave.color = Color(0.55, 0.48, 0.38)
	back_pave.size = Vector2(960, 220)
	back_pave.position = Vector2(0, 60)
	add_child(back_pave)

	# Ground / walkable area (y=280 to y=540)
	var ground = ColorRect.new()
	ground.color = Color(0.62, 0.50, 0.34)
	ground.size = Vector2(960, 260)
	ground.position = Vector2(0, 280)
	add_child(ground)

	# Village market background + decorations
	var deco = _MarketDeco.new()
	add_child(deco)

	# NPC stall sprites (interactive)
	for npc_id in NPC_POSITIONS:
		var npc_node = _StallNPC.new()
		npc_node.npc_id = npc_id
		npc_node.position = NPC_POSITIONS[npc_id]
		npc_node.name = "NPC_" + npc_id
		add_child(npc_node)

	# Action prompt — compact centered bubble
	_action_ribbon = Control.new()
	_action_ribbon.visible = false
	_action_ribbon.z_index = 10

	var rb_border = ColorRect.new()
	rb_border.color = Color(0.55, 0.40, 0.18, 0.7)
	rb_border.size = Vector2(262, 36)
	rb_border.position = Vector2(349, 495)
	_action_ribbon.add_child(rb_border)

	var rb_bg = ColorRect.new()
	rb_bg.color = Color(0.05, 0.03, 0.0, 0.85)
	rb_bg.size = Vector2(260, 34)
	rb_bg.position = Vector2(350, 496)
	_action_ribbon.add_child(rb_bg)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 15)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_action_label.position = Vector2(350, 502)
	_action_label.size = Vector2(260, 24)
	_action_ribbon.add_child(_action_label)
	add_child(_action_ribbon)

	_setup_walls()

func _setup_walls() -> void:
	# Left/right walls
	_add_wall(Vector2(0, 50), Vector2(14, 466))
	_add_wall(Vector2(946, 50), Vector2(14, 466))
	# Bottom wall
	_add_wall(Vector2(0, 498), Vector2(960, 14))
	# Top walls with gap for exit north (x 290–390, between Sofi & Lucas)
	_add_wall(Vector2(0, 50), Vector2(290, 14))
	_add_wall(Vector2(390, 50), Vector2(570, 14))
	# Building-line wall — continuous barrier where ground meets shops
	# Gap at x 290–390 for the exit corridor (between Sofi and Lucas shops)
	_add_wall(Vector2(14, 280), Vector2(276, 14))     # left of exit path
	_add_wall(Vector2(390, 280), Vector2(556, 14))    # right of exit path (covers Lucas onward)
	# Side walls for exit corridor (prevent wandering behind shops)
	_add_wall(Vector2(290, 50), Vector2(14, 230))     # left side of corridor
	_add_wall(Vector2(376, 50), Vector2(14, 230))     # right side of corridor
	# Cart collision (left and right market carts)
	_add_wall(Vector2(30, 330), Vector2(80, 70))
	_add_wall(Vector2(850, 330), Vector2(80, 70))

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

	_player_drawer = _MarketPlayer.new()
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

	_player.position = Vector2(480, 420)
	add_child(_player)

# ── HUD ────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	# ── Top-right status panel (matches farm) ──
	var hud_border = ColorRect.new()
	hud_border.color = Color(0.55, 0.40, 0.18, 0.6)
	hud_border.size = Vector2(152, 54)
	hud_border.position = Vector2(805, 3)
	hud_border.z_index = 9
	add_child(hud_border)

	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.05, 0.02, 0.75)
	hud_bg.size = Vector2(150, 52)
	hud_bg.position = Vector2(806, 4)
	hud_bg.z_index = 10
	add_child(hud_bg)

	# Coin icon in HUD
	var coin_path = ICON_PATH + "coin.png"
	if ResourceLoader.exists(coin_path):
		var coin_icon = TextureRect.new()
		coin_icon.texture = load(coin_path)
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.size = Vector2(18, 18)
		coin_icon.position = Vector2(810, 8)
		coin_icon.z_index = 11
		add_child(coin_icon)
	_hud_coins = GameManager.make_label("%d" % PlayerData.coins, Vector2(830, 8), 15, Color(1.0, 0.9, 0.2))
	_hud_coins.z_index = 11
	add_child(_hud_coins)

	var day_lbl = GameManager.make_label("Day %d" % PlayerData.day, Vector2(814, 28), 14, Color(0.85, 0.9, 0.75))
	day_lbl.z_index = 11
	add_child(day_lbl)

	# ── Top-left scene title ──
	var title_border = ColorRect.new()
	title_border.color = Color(0.55, 0.40, 0.18, 0.6)
	title_border.size = Vector2(172, 34)
	title_border.position = Vector2(3, 3)
	title_border.z_index = 9
	add_child(title_border)

	var title_bg = ColorRect.new()
	title_bg.color = Color(0.08, 0.05, 0.02, 0.75)
	title_bg.size = Vector2(170, 32)
	title_bg.position = Vector2(4, 4)
	title_bg.z_index = 10
	add_child(title_bg)

	var title_lbl = GameManager.make_label("Juarez Market", Vector2(12, 8), 16, Color(1.0, 0.92, 0.3))
	title_lbl.z_index = 11
	add_child(title_lbl)

# ── Physics & Movement ─────────────────────────────────────────────────────────

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

	# Exit north → back to farm (corridor between Sofi & Lucas, x 290–390)
	if _player.position.y < 75 and _player.position.x > 280 and _player.position.x < 400 and not _transitioning:
		_transitioning = true
		PlayerData.save_game()
		GameManager.go_to_farm("from_market")
		return

	# NPC proximity check
	_near_npc = ""
	for npc_id in NPC_POSITIONS:
		if _player.position.distance_to(NPC_POSITIONS[npc_id]) < 90:
			_near_npc = npc_id
			break

	_action_ribbon.visible = (_near_npc != "")
	if _near_npc != "":
		_action_label.text = "[E] Talk to " + NPC_NAMES.get(_near_npc, _near_npc)

# ── Shop Overlay ───────────────────────────────────────────────────────────────

func _build_shop_overlay() -> void:
	_shop_overlay = Control.new()
	_shop_overlay.visible = false
	_shop_overlay.z_index = 50
	add_child(_shop_overlay)

	# Dim background
	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.size = Vector2(960, 540)
	_shop_overlay.add_child(dim)

	# Panel
	var panel = ColorRect.new()
	panel.color = Color(0.82, 0.72, 0.52)
	panel.size = Vector2(920, 474)
	panel.position = Vector2(20, 33)
	_shop_overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.name = "OverlayTitle"
	title.text = "Juarez Market"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	title.position = Vector2(20, 42)
	title.size = Vector2(920, 38)
	_shop_overlay.add_child(title)

	# Coins display
	_overlay_coins = Label.new()
	_overlay_coins.add_theme_font_size_override("font_size", 19)
	_overlay_coins.add_theme_color_override("font_color", Color(0.7, 0.5, 0.05))
	_overlay_coins.position = Vector2(32, 43)
	_overlay_coins.size = Vector2(200, 36)
	_shop_overlay.add_child(_overlay_coins)

	# Close button
	var close_btn = GameManager.make_button("X Close", Vector2(820, 40), Vector2(110, 36), Color(0.6, 0.15, 0.1))
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_close_shop)
	_shop_overlay.add_child(close_btn)

	# NPC speech
	var speech_lbl = Label.new()
	speech_lbl.name = "SpeechLabel"
	speech_lbl.add_theme_font_size_override("font_size", 15)
	speech_lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
	speech_lbl.position = Vector2(32, 88)
	speech_lbl.size = Vector2(880, 28)
	_shop_overlay.add_child(speech_lbl)

	# Tab buttons
	var tabs = [
		["seeds",     "Seeds (Sofi)",           Color(0.35, 0.55, 0.15)],
		["livestock", "Livestock (Lucas)",       Color(0.55, 0.35, 0.15)],
		["tools",     "Abuelo's Supplies",       Color(0.25, 0.35, 0.60)],
	]
	_tab_buttons.clear()
	for i in range(tabs.size()):
		var t = tabs[i]
		var tab_id = t[0]
		var btn = GameManager.make_button(t[1], Vector2(32 + i * 292, 122), Vector2(276, 46), t[2])
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(func(): _show_tab(tab_id))
		_shop_overlay.add_child(btn)
		_tab_buttons[tab_id] = btn

	# Item list
	_item_list_node = Control.new()
	_item_list_node.name = "ItemList"
	_item_list_node.position = Vector2(32, 178)
	_item_list_node.size = Vector2(880, 268)
	_shop_overlay.add_child(_item_list_node)

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 19)
	_feedback_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	_feedback_label.position = Vector2(32, 430)
	_feedback_label.size = Vector2(880, 30)
	_shop_overlay.add_child(_feedback_label)

	# Inventory summary
	var inv_label = Label.new()
	inv_label.name = "InvLabel"
	inv_label.add_theme_font_size_override("font_size", 13)
	inv_label.add_theme_color_override("font_color", Color(0.35, 0.2, 0.05))
	inv_label.position = Vector2(32, 462)
	inv_label.size = Vector2(880, 28)
	_shop_overlay.add_child(inv_label)

func _open_shop(npc_id: String) -> void:
	_mode = "shop"
	_active_npc = npc_id
	_action_ribbon.visible = false
	_shop_overlay.visible = true
	_update_overlay_coins()
	_show_tab(NPC_TABS.get(npc_id, "seeds"))
	_update_inv_label()

func _close_shop() -> void:
	_mode = "walk"
	_shop_overlay.visible = false

func _show_tab(tab: String) -> void:
	_active_tab = tab
	_clear_items()
	_update_tab_highlight()

	var speech_texts = {
		"seeds":     "Hi! I'm Sofi! Buy seeds to grow your farm!",
		"livestock": "Howdy! I'm Lucas! Animals earn you coins every day!",
		"tools":     "Hola mijo! Abuelo has everything you need!",
	}
	var speech_lbl = _shop_overlay.get_node_or_null("SpeechLabel")
	if speech_lbl:
		speech_lbl.text = speech_texts.get(tab, "What can I help you with?")

	var row_idx = 0
	for i in range(SHOP_ITEMS.get(tab, []).size()):
		_add_item_row(SHOP_ITEMS[tab][i], row_idx)
		row_idx += 1

	# Sell section (if this NPC buys items)
	var sell_list = SELL_ITEMS.get(tab, [])
	var has_sellable = false
	for sell_item in sell_list:
		if PlayerData.get_item_count(sell_item["id"]) > 0:
			has_sellable = true
			break
	if has_sellable:
		# Sell header
		var sell_header = Label.new()
		sell_header.text = "── Sell to %s ──" % NPC_NAMES.get(_active_npc, "NPC").split("(")[0].strip_edges()
		sell_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_header.add_theme_font_size_override("font_size", 16)
		sell_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		sell_header.position = Vector2(0, row_idx * 84 + 10)
		sell_header.size = Vector2(860, 28)
		_item_list_node.add_child(sell_header)
		row_idx += 1
		# Sell rows
		for sell_item in sell_list:
			if PlayerData.get_item_count(sell_item["id"]) > 0:
				_add_sell_row(sell_item, row_idx)
				row_idx += 1

func _add_item_row(item: Dictionary, row: int) -> void:
	var y = row * 84
	var panel = ColorRect.new()
	panel.color = Color(0.92, 0.85, 0.68)
	panel.size = Vector2(860, 76)
	panel.position = Vector2(0, y)
	_item_list_node.add_child(panel)

	# Item icon
	var icon_path = ICON_PATH + item["id"] + ".png"
	if ResourceLoader.exists(icon_path):
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(48, 48)
		icon_rect.position = Vector2(8, 14)
		panel.add_child(icon_rect)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.position = Vector2(62, 8)
	name_lbl.size = Vector2(440, 30)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
	panel.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.position = Vector2(62, 40)
	desc_lbl.size = Vector2(440, 26)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.4, 0.25, 0.05))
	panel.add_child(desc_lbl)

	var cost_str = "%d coins" % item["cost"] if item["cost"] > 0 else "FREE"
	var cost_lbl = Label.new()
	cost_lbl.text = cost_str
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.position = Vector2(506, 8)
	cost_lbl.size = Vector2(128, 30)
	cost_lbl.add_theme_font_size_override("font_size", 17)
	cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.05))
	panel.add_child(cost_lbl)

	var owned = ""
	if item["id"] in ["chicken", "pig", "cow"]:
		owned = "Owned: %d" % PlayerData.animals.filter(func(a): return a.get("type","") == item["id"]).size()
	else:
		owned = "Have: %d" % PlayerData.get_item_count(item["id"])
	var owned_lbl = Label.new()
	owned_lbl.text = owned
	owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned_lbl.position = Vector2(506, 40)
	owned_lbl.size = Vector2(128, 24)
	owned_lbl.add_theme_font_size_override("font_size", 12)
	owned_lbl.add_theme_color_override("font_color", Color(0.35, 0.5, 0.25))
	panel.add_child(owned_lbl)

	var can_afford = PlayerData.coins >= item["cost"]
	var btn_color = Color(0.2, 0.55, 0.2) if can_afford else Color(0.4, 0.4, 0.4)
	var buy_btn = GameManager.make_button("BUY", Vector2(644, 14), Vector2(110, 48), btn_color)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.disabled = not can_afford and item["cost"] > 0
	var item_ref = item
	buy_btn.pressed.connect(func(): _buy_item(item_ref))
	panel.add_child(buy_btn)

func _buy_item(item: Dictionary) -> void:
	var cost = item["cost"]
	if cost > 0 and not PlayerData.spend_coins(cost):
		_show_feedback("Not enough coins! Earn more at the Math Mines.", Color(0.85, 0.3, 0.1))
		return

	if item["id"] == "sprinkler" and PlayerData.has_item("sprinkler"):
		PlayerData.add_coins(cost)
		_show_feedback("You already own a sprinkler!", Color(0.85, 0.3, 0.1))
		_update_overlay_coins()
		return

	if item["id"] in ["chicken", "pig", "cow"]:
		if PlayerData.animals.size() >= 3:
			# Refund — pen is full
			PlayerData.add_coins(cost)
			_show_feedback("Your pen is full! (max 3 animals)", Color(0.85, 0.3, 0.1))
			_update_overlay_coins()
			return
		PlayerData.add_animal(item["id"])
		_show_feedback("%s added to your farm!" % item["name"], Color(0.2, 0.75, 0.2))
	else:
		PlayerData.add_item(item["id"], 1)
		_show_feedback("Bought %s!" % item["name"], Color(0.2, 0.75, 0.2))

	_update_overlay_coins()
	_update_inv_label()
	PlayerData.save_game()
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): _show_tab(_active_tab))

func _add_sell_row(item: Dictionary, row: int) -> void:
	var y = row * 84
	var panel = ColorRect.new()
	panel.color = Color(0.68, 0.85, 0.72)
	panel.size = Vector2(860, 76)
	panel.position = Vector2(0, y)
	_item_list_node.add_child(panel)

	# Item icon
	var icon_path = ICON_PATH + item["id"] + ".png"
	if ResourceLoader.exists(icon_path):
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(48, 48)
		icon_rect.position = Vector2(8, 14)
		panel.add_child(icon_rect)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.position = Vector2(62, 8)
	name_lbl.size = Vector2(330, 30)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.2, 0.05))
	panel.add_child(name_lbl)

	var count = PlayerData.get_item_count(item["id"])
	var owned_lbl = Label.new()
	owned_lbl.text = "In inventory: %d" % count
	owned_lbl.position = Vector2(62, 40)
	owned_lbl.size = Vector2(330, 26)
	owned_lbl.add_theme_font_size_override("font_size", 13)
	owned_lbl.add_theme_color_override("font_color", Color(0.2, 0.35, 0.1))
	panel.add_child(owned_lbl)

	var price_lbl = Label.new()
	price_lbl.text = "+%d coins each" % item["price"]
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.position = Vector2(406, 8)
	price_lbl.size = Vector2(128, 30)
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1))
	panel.add_child(price_lbl)

	# Sell 1 button
	var sell_btn = GameManager.make_button("SELL 1", Vector2(544, 14), Vector2(100, 48), Color(0.6, 0.35, 0.08))
	sell_btn.add_theme_font_size_override("font_size", 16)
	var item_ref = item
	sell_btn.pressed.connect(func(): _sell_item(item_ref, 1))
	panel.add_child(sell_btn)

	# Sell All button
	if count > 1:
		var sell_all_btn = GameManager.make_button("ALL", Vector2(654, 14), Vector2(100, 48), Color(0.5, 0.15, 0.08))
		sell_all_btn.add_theme_font_size_override("font_size", 16)
		sell_all_btn.pressed.connect(func(): _sell_item(item_ref, count))
		panel.add_child(sell_all_btn)

func _sell_item(item: Dictionary, quantity: int) -> void:
	var count = PlayerData.get_item_count(item["id"])
	var to_sell = mini(quantity, count)
	if to_sell <= 0:
		_show_feedback("You don't have any to sell!", Color(0.85, 0.3, 0.1))
		return
	for i in range(to_sell):
		PlayerData.use_item(item["id"])
	var earned = to_sell * item["price"]
	PlayerData.add_coins(earned)
	_show_feedback("Sold %d %s for %d coins!" % [to_sell, item["name"], earned], Color(0.1, 0.6, 0.1))
	_update_overlay_coins()
	_update_inv_label()
	PlayerData.save_game()
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): _show_tab(_active_tab))

func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(_feedback_label):
			_feedback_label.text = ""
	)

func _update_overlay_coins() -> void:
	if _overlay_coins:
		_overlay_coins.text = "%d coins" % PlayerData.coins
	if _hud_coins:
		_hud_coins.text = "%d" % PlayerData.coins

func _update_tab_highlight() -> void:
	for tab_id in _tab_buttons:
		var btn = _tab_buttons[tab_id]
		var base_colors = {"seeds": Color(0.35,0.55,0.15), "livestock": Color(0.55,0.35,0.15), "tools": Color(0.25,0.35,0.60)}
		var color = base_colors.get(tab_id, Color(0.3,0.3,0.3))
		if tab_id == _active_tab:
			color = color.lightened(0.25)
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", style)

func _clear_items() -> void:
	for child in _item_list_node.get_children():
		child.queue_free()

func _update_inv_label() -> void:
	var inv = _shop_overlay.get_node_or_null("InvLabel")
	if inv:
		var parts = []
		var item_names = {"sunflower_seeds":"Seeds(Sun)","carrot_seeds":"Seeds(Car)","strawberry_seeds":"Seeds(Str)",
						  "water_jug":"Jug","sprinkler":"Sprinkler","fertilizer":"Fert","animal_food":"Feed"}
		for key in ["sunflower_seeds", "carrot_seeds", "strawberry_seeds", "water_jug", "sprinkler", "fertilizer", "animal_food"]:
			var count = PlayerData.get_item_count(key)
			if count > 0:
				parts.append("%s x%d" % [item_names.get(key, key), count])
		inv.text = "Inventory: " + (", ".join(parts) if parts.size() > 0 else "Empty")

func _on_coins_changed(_val: int) -> void:
	_update_overlay_coins()


# ── Inner Classes ──────────────────────────────────────────────────────────────

class _MarketDeco extends Node2D:
	func _ready() -> void:
		# 3 shop buildings as market stalls
		var shop_paths = [
			"res://Pixelwood Valley 1.1.2/Village/Houses/Shop_1_1.png",
			"res://Pixelwood Valley 1.1.2/Village/Houses/Shop_2_1.png",
			"res://Pixelwood Valley 1.1.2/Village/Houses/Shop_3_1.png",
		]
		for i in range(3):
			var spr = Sprite2D.new()
			spr.texture = load(shop_paths[i])
			spr.scale = Vector2(1.8, 1.8)
			spr.position = Vector2(200 + i * 280, 230)
			add_child(spr)

		# Market carts on sides
		for cx in [70, 890]:
			var cart = Sprite2D.new()
			cart.texture = load("res://Pixelwood Valley 1.1.2/Village/Cart/1.png")
			cart.scale = Vector2(2.2, 2.2)
			cart.position = Vector2(cx, 370)
			add_child(cart)

		# Trees at far sides
		for tx in [30, 930]:
			var tree = Sprite2D.new()
			tree.texture = load("res://Pixelwood Valley 1.1.2/Trees/Tree1.png")
			tree.scale = Vector2(1.2, 1.2)
			tree.position = Vector2(tx, 200)
			add_child(tree)

	func _draw() -> void:
		# Cobblestone pavement behind shops (y=60 to y=280)
		var rng = RandomNumberGenerator.new()
		rng.seed = 5555
		for row in range(8):
			for col in range(12):
				var rx = col * 80 + (row % 2) * 40
				var ry = 60 + row * 28
				var v = rng.randf_range(0.92, 1.08)
				draw_rect(Rect2(rx, ry, 76, 25), Color(0.52 * v, 0.45 * v, 0.36 * v))
				draw_rect(Rect2(rx, ry, 76, 25), Color(0.42, 0.36, 0.28), false, 1)

		# Cobblestone market path (walkable area)
		for row in range(4):
			for col in range(12):
				var rx = col * 80 + (row % 2) * 40
				var ry = 388 + row * 14
				draw_rect(Rect2(rx, ry, 76, 11), Color(0.70, 0.62, 0.50))
				draw_rect(Rect2(rx, ry, 76, 11), Color(0.55, 0.48, 0.38), false, 1)
		# North exit path (back to farm) — dirt path through the pavement
		draw_rect(Rect2(290, 0, 100, 360), Color(0.58, 0.46, 0.30))
		# Path border lines
		draw_line(Vector2(290, 0), Vector2(290, 360), Color(0.48, 0.36, 0.22), 2)
		draw_line(Vector2(390, 0), Vector2(390, 360), Color(0.48, 0.36, 0.22), 2)
		# Exit arrow indicators along the path
		var arrow_color = Color(0.85, 0.75, 0.5, 0.6)
		for ai in range(5):
			var ay = 80 + ai * 40
			draw_colored_polygon(PackedVector2Array([
				Vector2(325, ay), Vector2(340, ay - 12), Vector2(355, ay)
			]), arrow_color)
		# Exit sign (back to farm)
		var sign_post = Color(0.45, 0.28, 0.10)
		var sign_plank = Color(0.62, 0.42, 0.18)
		draw_rect(Rect2(337, 58, 6, 26), sign_post)
		draw_rect(Rect2(308, 44, 64, 18), sign_plank)
		draw_string(ThemeDB.fallback_font, Vector2(314, 58),
			"Farm", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.60))

		# Stall sign boards
		var sign_names = ["Sofi's Seeds", "Lucas's Farm", "Abuelo"]
		for i in range(3):
			var sx = 145 + i * 280
			draw_rect(Rect2(sx, 136, 112, 20), Color(0.62, 0.42, 0.18))
			draw_string(ThemeDB.fallback_font, Vector2(sx + 6, 151),
				sign_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.60))
		# Bunting rope
		draw_line(Vector2(60, 70), Vector2(900, 70), Color(0.4, 0.3, 0.2), 2)
		var flag_cols = [Color(0.9,0.2,0.2), Color(0.2,0.5,0.9), Color(0.2,0.75,0.3),
						 Color(0.9,0.75,0.1), Color(0.6,0.2,0.8), Color(0.9,0.45,0.1),
						 Color(0.2,0.9,0.75), Color(0.9,0.2,0.5)]
		for i in range(8):
			var flag_x = 60 + i * 120
			draw_colored_polygon(PackedVector2Array([
				Vector2(flag_x, 70), Vector2(flag_x + 28, 70), Vector2(flag_x + 14, 90)
			]), flag_cols[i])


class _StallNPC extends Node2D:
	var npc_id: String = "sofi"
	var _sprite: Sprite2D

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.hframes = 4
		_sprite.vframes = 7
		_sprite.frame = 0
		_sprite.scale = Vector2(1.8, 1.8)
		_sprite.position = Vector2(0, 0)
		match npc_id:
			"sofi":
				_sprite.texture = load(PW_NPC["sofi"])
			"lucas":
				_sprite.texture = load(PW_NPC["lucas"])
			_:
				_sprite.texture = load(PW_NPC["merchant"])
		add_child(_sprite)

	func _draw() -> void:
		# Floating name bubble
		draw_rect(Rect2(-46, -100, 92, 22), Color(1.0, 1.0, 0.9, 0.90))
		draw_rect(Rect2(-47, -101, 94, 24), Color(0.55, 0.40, 0.18, 0.5), false, 1.0)
		var npc_names = {"sofi": "Sofi", "lucas": "Lucas", "merchant": "Abuelo"}
		draw_string(ThemeDB.fallback_font, Vector2(-40, -84),
			npc_names.get(npc_id, npc_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.1, 0.0))


class _MarketPlayer extends Node2D:
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
