extends Node

## TouchControls — Autoload singleton for on-screen touch controls.
## Only visible on web builds. Renders via _draw() on a CanvasLayer (layer 99).
##
## Uses JavaScript touch listeners directly on the canvas (with preventDefault)
## to bypass iPad Safari's default touch interception. Touch state is polled
## each frame. Button presses inject synthetic InputEventKey events so scenes'
## existing keyboard handlers work without modification.
##
## Usage from any scene:
##   var move = TouchControls.get_movement_vector()  # in _physics_process()
##   # Action/pause/inventory are handled via synthetic KEY_E/ESCAPE/I injection

# ── Constants ────────────────────────────────────────────────────────────────

const VIEWPORT_SIZE := Vector2(960, 540)

# D-pad
const DPAD_CENTER := Vector2(95, 445)
const DPAD_RADIUS := 60.0
const DPAD_DEAD_ZONE := 12.0
const DPAD_BG_RADIUS := 70.0

# Action button (bottom-right)
const ACTION_CENTER := Vector2(890, 465)
const ACTION_RADIUS := 35.0

# Pause button (top-right)
const PAUSE_CENTER := Vector2(925, 35)
const PAUSE_RADIUS := 22.0

# Inventory button (top-right, left of pause)
const INV_CENTER := Vector2(865, 35)
const INV_RADIUS := 22.0

# Colors
const COL_DPAD_BG := Color(0.25, 0.18, 0.08, 0.35)
const COL_DPAD_KNOB := Color(0.45, 0.35, 0.15, 0.5)
const COL_DPAD_KNOB_ACTIVE := Color(0.55, 0.42, 0.18, 0.65)
const COL_DPAD_ARROWS := Color(0.9, 0.85, 0.7, 0.4)
const COL_ACTION_BG := Color(0.15, 0.42, 0.15, 0.4)
const COL_ACTION_ACTIVE := Color(0.25, 0.55, 0.25, 0.6)
const COL_PAUSE_BG := Color(0.3, 0.22, 0.1, 0.4)
const COL_PAUSE_ACTIVE := Color(0.5, 0.38, 0.15, 0.6)
const COL_INV_BG := Color(0.3, 0.22, 0.1, 0.4)
const COL_INV_ACTIVE := Color(0.5, 0.38, 0.15, 0.6)
const COL_TEXT := Color(1.0, 0.95, 0.85, 0.6)
const COL_TEXT_ACTIVE := Color(1.0, 0.97, 0.9, 0.85)

# ── State ────────────────────────────────────────────────────────────────────

var _canvas_layer: CanvasLayer
var _draw_node: Control
var _enabled := false

# D-pad
var _dpad_touch_id: int = -1
var _dpad_vector := Vector2.ZERO
var _dpad_knob_pos := Vector2.ZERO

# Button visual state (for drawing)
var _action_pressed := false
var _pause_pressed := false
var _inv_pressed := false

# Track if we need to redraw
var _last_dpad_active := false
var _last_action := false
var _last_pause := false
var _last_inv := false
var _last_knob_pos := Vector2.ZERO

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return

	_enabled = true

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 99
	_canvas_layer.name = "TouchControlsLayer"
	add_child(_canvas_layer)

	_draw_node = Control.new()
	_draw_node.name = "TouchDraw"
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.size = VIEWPORT_SIZE
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.connect("draw", _on_draw)
	_canvas_layer.add_child(_draw_node)

	_setup_js_touch_listeners()

func _process(_delta: float) -> void:
	if not _enabled:
		return
	_poll_js_touches()
	# Only redraw if visual state changed
	var dpad_active = _dpad_touch_id != -1
	if (dpad_active != _last_dpad_active or _action_pressed != _last_action
			or _pause_pressed != _last_pause or _inv_pressed != _last_inv
			or _dpad_knob_pos != _last_knob_pos):
		_last_dpad_active = dpad_active
		_last_action = _action_pressed
		_last_pause = _pause_pressed
		_last_inv = _inv_pressed
		_last_knob_pos = _dpad_knob_pos
		_draw_node.queue_redraw()

# ── Public API ───────────────────────────────────────────────────────────────

func get_movement_vector() -> Vector2:
	if not _enabled:
		return Vector2.ZERO
	return _dpad_vector

func show_controls() -> void:
	if _draw_node:
		_draw_node.visible = true

func hide_controls() -> void:
	if _draw_node:
		_draw_node.visible = false

# Legacy API — kept for compatibility but buttons now inject synthetic keys
func is_action_just_pressed() -> bool:
	return false

func is_action_pressed() -> bool:
	return _action_pressed

func is_pause_pressed() -> bool:
	return false

func is_inventory_pressed() -> bool:
	return false

# ── JavaScript touch capture ────────────────────────────────────────────────

func _setup_js_touch_listeners() -> void:
	JavaScriptBridge.eval("""
	(function() {
		var canvas = document.querySelector('canvas');
		if (!canvas) return;

		canvas.style.touchAction = 'none';
		canvas.style.webkitTouchCallout = 'none';
		canvas.style.webkitUserSelect = 'none';

		// Current active touches (for d-pad tracking)
		window._godotCurTouches = '';
		// New touch-starts accumulated since last GDScript poll (for button taps)
		window._godotNewTouches = '';

		function toViewport(clientX, clientY) {
			var cr = canvas.getBoundingClientRect();
			var gameAspect = 960 / 540;
			var canvasAspect = cr.width / cr.height;
			var ox = 0, oy = 0, s = 1;
			if (canvasAspect > gameAspect) {
				s = cr.height / 540;
				ox = (cr.width - 960 * s) / 2;
			} else {
				s = cr.width / 960;
				oy = (cr.height - 540 * s) / 2;
			}
			return {
				x: (clientX - cr.left - ox) / s,
				y: (clientY - cr.top - oy) / s
			};
		}

		function updateCurrent(e) {
			var arr = [];
			for (var i = 0; i < e.touches.length; i++) {
				var t = e.touches[i];
				var vp = toViewport(t.clientX, t.clientY);
				arr.push(t.identifier + ':' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1));
			}
			window._godotCurTouches = arr.join(';');
		}

		canvas.addEventListener('touchstart', function(e) {
			e.preventDefault();
			// Accumulate new touch positions for button detection
			for (var i = 0; i < e.changedTouches.length; i++) {
				var t = e.changedTouches[i];
				var vp = toViewport(t.clientX, t.clientY);
				var entry = t.identifier + ':' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1);
				if (window._godotNewTouches.length > 0) {
					window._godotNewTouches += ';' + entry;
				} else {
					window._godotNewTouches = entry;
				}
			}
			updateCurrent(e);
		}, {passive: false});

		canvas.addEventListener('touchmove', function(e) {
			e.preventDefault();
			updateCurrent(e);
		}, {passive: false});

		canvas.addEventListener('touchend', function(e) {
			e.preventDefault();
			updateCurrent(e);
		}, {passive: false});

		canvas.addEventListener('touchcancel', function(e) {
			e.preventDefault();
			updateCurrent(e);
		}, {passive: false});

		// Mouse fallback (desktop testing)
		var mouseDown = false;
		canvas.addEventListener('mousedown', function(e) {
			mouseDown = true;
			var vp = toViewport(e.clientX, e.clientY);
			var entry = '-1:' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1);
			window._godotCurTouches = entry;
			if (window._godotNewTouches.length > 0) {
				window._godotNewTouches += ';' + entry;
			} else {
				window._godotNewTouches = entry;
			}
		});
		canvas.addEventListener('mousemove', function(e) {
			if (!mouseDown) return;
			var vp = toViewport(e.clientX, e.clientY);
			window._godotCurTouches = '-1:' + vp.x.toFixed(1) + ',' + vp.y.toFixed(1);
		});
		canvas.addEventListener('mouseup', function(e) {
			mouseDown = false;
			window._godotCurTouches = '';
		});
	})();
	""")

func _poll_js_touches() -> void:
	# Read and clear new touch-start events (atomic read+clear)
	var new_raw = JavaScriptBridge.eval(
		"(function(){var n=window._godotNewTouches||'';window._godotNewTouches='';return n;})()")
	var new_str: String = str(new_raw) if new_raw != null else ""

	# Read current active touches
	var cur_raw = JavaScriptBridge.eval("window._godotCurTouches||''")
	var cur_str: String = str(cur_raw) if cur_raw != null else ""

	# Parse new touch-starts → check for button presses, inject key events
	if new_str.length() > 0:
		var new_touches := _parse_touches(new_str)
		for t in new_touches:
			var pos: Vector2 = t["pos"]
			if _is_in_circle(pos, ACTION_CENTER, ACTION_RADIUS + 15.0):
				_inject_key(KEY_E)
			elif _is_in_circle(pos, PAUSE_CENTER, PAUSE_RADIUS + 10.0):
				_inject_key(KEY_ESCAPE)
			elif _is_in_circle(pos, INV_CENTER, INV_RADIUS + 10.0):
				_inject_key(KEY_I)

	# Parse current touches → update d-pad and button visual states
	var cur_touches := _parse_touches(cur_str)

	# Update button visual states
	_action_pressed = false
	_pause_pressed = false
	_inv_pressed = false
	for t in cur_touches:
		var pos: Vector2 = t["pos"]
		if _is_in_circle(pos, ACTION_CENTER, ACTION_RADIUS + 15.0):
			_action_pressed = true
		elif _is_in_circle(pos, PAUSE_CENTER, PAUSE_RADIUS + 10.0):
			_pause_pressed = true
		elif _is_in_circle(pos, INV_CENTER, INV_RADIUS + 10.0):
			_inv_pressed = true

	# D-pad: track a specific touch
	if _dpad_touch_id != -1:
		var found := false
		for t in cur_touches:
			if t["id"] == _dpad_touch_id:
				_update_dpad(t["pos"])
				found = true
				break
		if not found:
			_dpad_touch_id = -1
			_dpad_vector = Vector2.ZERO
			_dpad_knob_pos = Vector2.ZERO

	if _dpad_touch_id == -1:
		for t in cur_touches:
			if _is_in_dpad(t["pos"]):
				# Don't steal touches on buttons
				var pos: Vector2 = t["pos"]
				if (_is_in_circle(pos, ACTION_CENTER, ACTION_RADIUS + 15.0)
						or _is_in_circle(pos, PAUSE_CENTER, PAUSE_RADIUS + 10.0)
						or _is_in_circle(pos, INV_CENTER, INV_RADIUS + 10.0)):
					continue
				_dpad_touch_id = t["id"]
				_update_dpad(t["pos"])
				break

func _parse_touches(s: String) -> Array:
	var result: Array = []
	if s.length() == 0:
		return result
	var parts = s.split(";")
	for part in parts:
		if part.length() == 0:
			continue
		var id_and_pos = part.split(":")
		if id_and_pos.size() != 2:
			continue
		var tid = int(id_and_pos[0])
		var coords = id_and_pos[1].split(",")
		if coords.size() != 2:
			continue
		result.append({"id": tid, "pos": Vector2(float(coords[0]), float(coords[1]))})
	return result

func _inject_key(keycode: int) -> void:
	# Inject a synthetic key press + release so scenes' _input()/_unhandled_input() fire
	var press = InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)

	var release = InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)

# ── Geometry helpers ────────────────────────────────────────────────────────

func _update_dpad(pos: Vector2) -> void:
	var offset := pos - DPAD_CENTER
	var dist := offset.length()
	if dist < DPAD_DEAD_ZONE:
		_dpad_vector = Vector2.ZERO
		_dpad_knob_pos = offset
		return
	if dist > DPAD_RADIUS:
		_dpad_knob_pos = offset.normalized() * DPAD_RADIUS
	else:
		_dpad_knob_pos = offset
	_dpad_vector = offset.normalized()

func _is_in_dpad(pos: Vector2) -> bool:
	return pos.distance_to(DPAD_CENTER) <= DPAD_BG_RADIUS + 20.0

func _is_in_circle(pos: Vector2, center: Vector2, radius: float) -> bool:
	return pos.distance_to(center) <= radius

# ── Drawing ──────────────────────────────────────────────────────────────────

func _on_draw() -> void:
	_draw_dpad()
	_draw_action_button()
	_draw_pause_button()
	_draw_inventory_button()

func _draw_dpad() -> void:
	var dpad_active := _dpad_touch_id != -1
	_draw_node.draw_circle(DPAD_CENTER, DPAD_BG_RADIUS, COL_DPAD_BG)

	var arrow_dist := 48.0
	var arrow_size := 10.0
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(0, -arrow_dist), Vector2.UP, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(0, arrow_dist), Vector2.DOWN, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(-arrow_dist, 0), Vector2.LEFT, arrow_size)
	_draw_arrow(_draw_node, DPAD_CENTER + Vector2(arrow_dist, 0), Vector2.RIGHT, arrow_size)

	var knob_center := DPAD_CENTER + _dpad_knob_pos
	var knob_color := COL_DPAD_KNOB_ACTIVE if dpad_active else COL_DPAD_KNOB
	_draw_node.draw_circle(knob_center, 22.0, knob_color)
	_draw_circle_outline(_draw_node, knob_center, 22.0, Color(0.6, 0.5, 0.3, 0.3), 2.0)

func _draw_arrow(node: Control, tip: Vector2, direction: Vector2, size: float) -> void:
	var perp := Vector2(-direction.y, direction.x)
	var base := tip - direction * size
	node.draw_colored_polygon(PackedVector2Array([
		tip, base + perp * size * 0.6, base - perp * size * 0.6,
	]), COL_DPAD_ARROWS)

func _draw_action_button() -> void:
	var bg_col := COL_ACTION_ACTIVE if _action_pressed else COL_ACTION_BG
	var txt_col := COL_TEXT_ACTIVE if _action_pressed else COL_TEXT
	_draw_node.draw_circle(ACTION_CENTER, ACTION_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, ACTION_CENTER, ACTION_RADIUS, Color(0.3, 0.55, 0.3, 0.35), 2.0)
	_draw_letter_e(_draw_node, ACTION_CENTER, 16.0, txt_col)

func _draw_pause_button() -> void:
	var bg_col := COL_PAUSE_ACTIVE if _pause_pressed else COL_PAUSE_BG
	var icon_col := COL_TEXT_ACTIVE if _pause_pressed else COL_TEXT
	_draw_node.draw_circle(PAUSE_CENTER, PAUSE_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, PAUSE_CENTER, PAUSE_RADIUS, Color(0.5, 0.4, 0.2, 0.3), 1.5)
	var bar_w := 4.0
	var bar_h := 14.0
	var gap := 4.0
	_draw_node.draw_rect(Rect2(PAUSE_CENTER.x - gap - bar_w, PAUSE_CENTER.y - bar_h / 2, bar_w, bar_h), icon_col)
	_draw_node.draw_rect(Rect2(PAUSE_CENTER.x + gap, PAUSE_CENTER.y - bar_h / 2, bar_w, bar_h), icon_col)

func _draw_inventory_button() -> void:
	var bg_col := COL_INV_ACTIVE if _inv_pressed else COL_INV_BG
	var icon_col := COL_TEXT_ACTIVE if _inv_pressed else COL_TEXT
	_draw_node.draw_circle(INV_CENTER, INV_RADIUS, bg_col)
	_draw_circle_outline(_draw_node, INV_CENTER, INV_RADIUS, Color(0.5, 0.4, 0.2, 0.3), 1.5)
	var bag_w := 14.0
	var bag_h := 16.0
	var bag_tl := INV_CENTER - Vector2(bag_w / 2, bag_h / 2 - 1)
	_draw_node.draw_rect(Rect2(bag_tl, Vector2(bag_w, bag_h)), icon_col, false, 2.0)
	var handle_w := 8.0
	var handle_h := 5.0
	_draw_node.draw_rect(
		Rect2(INV_CENTER.x - handle_w / 2, bag_tl.y - handle_h, handle_w, handle_h),
		icon_col, false, 2.0)

func _draw_circle_outline(node: Control, center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count := 32
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var angle := (float(i) / point_count) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(point_count):
		node.draw_line(points[i], points[i + 1], color, width)

func _draw_letter_e(node: Control, center: Vector2, size: float, color: Color) -> void:
	var half := size / 2.0
	var left := center.x - half * 0.4
	var right := center.x + half * 0.5
	var top := center.y - half
	var mid := center.y
	var bottom := center.y + half
	var w := 2.5
	node.draw_line(Vector2(left, top), Vector2(left, bottom), color, w)
	node.draw_line(Vector2(left, top), Vector2(right, top), color, w)
	node.draw_line(Vector2(left, mid), Vector2(right - 2, mid), color, w)
	node.draw_line(Vector2(left, bottom), Vector2(right, bottom), color, w)
