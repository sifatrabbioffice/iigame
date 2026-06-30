extends Control

# 🎛️ CUSTOMIZATION & DESIGN SETTINGS 
@export_range(0.5, 2.0) var ui_scale: float = 1.35
@export_range(0.1, 1.0) var global_opacity: float = 0.85

@export var max_range: float = 160.0       
@export var deadzone: float = 0.15
@export var return_speed: float = 35.0  

const COL_GLASS = Color(0.08, 0.08, 0.10, 0.6)
const COL_PRESS = Color(0.2, 0.2, 0.25, 0.9)
const COL_BORDER = Color(0.4, 0.4, 0.45, 0.3)
const COL_GLOW = Color(1.0, 1.0, 1.0, 0.15)
const COL_TEXT_DIM = Color(0.6, 0.6, 0.65, 0.8)
const COL_TRIANGLE = Color(0.15, 0.85, 0.65, 1.0)  
const COL_CIRCLE   = Color(0.95, 0.25, 0.35, 1.0)  
const COL_CROSS    = Color(0.35, 0.55, 1.0, 1.0)  
const COL_SQUARE   = Color(0.95, 0.45, 0.70, 1.0)

var l_track_id: int = -1
var r_track_id: int = -1
var l_base_center: Vector2
var r_base_center: Vector2
var l_stick_pos: Vector2
var r_stick_pos: Vector2
var l_stick_target: Vector2
var r_stick_target: Vector2
var dpad_center: Vector2
var face_center: Vector2
var menu_l_center: Vector2
var menu_r_center: Vector2
var button_rects: Dictionary = {}
var active_buttons: Dictionary = {}
var default_font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	draw.connect(_on_ui_draw)
	gui_input.connect(_on_gui_input)
	get_tree().root.size_changed.connect(_update_screen_size)
	
	default_font = ThemeDB.fallback_font
	max_range = max_range * ui_scale
	_setup_actions()
	
	await get_tree().create_timer(0.2).timeout
	_update_screen_size()

func _setup_actions() -> void:
	var required_actions = [
		"move_left", "move_right", "move_forward", "move_back",
		"look_left", "look_right", "look_up", "look_down",
		"jump", "sprint", "crouch", "weapon_swap", "aim", "fire", "grenade", "attack",
		"dpad_up", "dpad_down", "dpad_left", "dpad_right", "ps_options", "ps_home"
	]
	for action in required_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _update_screen_size() -> void:
	size = get_viewport().get_visible_rect().size
	_calculate_layout()
	queue_redraw()

func _process(delta: float) -> void:
	if size == Vector2.ZERO: return
	
	var needs_redraw = false
	if l_stick_pos.distance_to(l_stick_target) > 0.5:
		l_stick_pos = l_stick_pos.lerp(l_stick_target, return_speed * delta)
		needs_redraw = true
	if r_stick_pos.distance_to(r_stick_target) > 0.5:
		r_stick_pos = r_stick_pos.lerp(r_stick_target, return_speed * delta)
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()

func _op(color: Color, alpha_multiplier: float = 1.0) -> Color:
	return Color(color.r, color.g, color.b, color.a * global_opacity * alpha_multiplier)

func _calculate_layout() -> void:
	var current_size = size
	var is_landscape = current_size.x > current_size.y
	
	var pad_margin_x = (240.0 if is_landscape else 160.0) * ui_scale
	var pad_margin_y = (200.0 if is_landscape else 180.0) * ui_scale
	
	l_base_center = Vector2(pad_margin_x, current_size.y - pad_margin_y)
	r_base_center = Vector2(current_size.x - pad_margin_x, current_size.y - pad_margin_y)
	l_stick_target = l_base_center; l_stick_pos = l_base_center
	r_stick_target = r_base_center; r_stick_pos = r_base_center
	
	if is_landscape:
		dpad_center = Vector2(pad_margin_x, current_size.y - pad_margin_y - (340.0 * ui_scale))
		face_center = Vector2(current_size.x - pad_margin_x, current_size.y - pad_margin_y - (340.0 * ui_scale))
		menu_l_center = Vector2(current_size.x / 2.0 - (55 * ui_scale), current_size.y - (120 * ui_scale))
		menu_r_center = Vector2(current_size.x / 2.0 + (55 * ui_scale), current_size.y - (120 * ui_scale))
	else:
		dpad_center = Vector2(pad_margin_x - (40 * ui_scale), current_size.y - pad_margin_y - (250.0 * ui_scale))
		face_center = Vector2(current_size.x - pad_margin_x + (40 * ui_scale), current_size.y - pad_margin_y - (250.0 * ui_scale))
		menu_l_center = Vector2(current_size.x / 2.0 - (50 * ui_scale), current_size.y - (100 * ui_scale))
		menu_r_center = Vector2(current_size.x / 2.0 + (50 * ui_scale), current_size.y - (100 * ui_scale))

	var s_margin_x = (140.0 if is_landscape else 80.0) * ui_scale
	var s_margin_top = (70.0 if is_landscape else 100.0) * ui_scale
	var l2_size = Vector2(210, 95) * ui_scale
	var l1_size = Vector2(185, 75) * ui_scale
	
	button_rects = {
		"aim": Rect2(Vector2(s_margin_x, s_margin_top), l2_size),
		"fire": Rect2(Vector2(current_size.x - s_margin_x - l2_size.x, s_margin_top), l2_size),
		"grenade": Rect2(Vector2(s_margin_x + (12 * ui_scale), s_margin_top + l2_size.y + (20 * ui_scale)), l1_size),
		"attack": Rect2(Vector2(current_size.x - s_margin_x - l1_size.x - (12 * ui_scale), s_margin_top + l2_size.y + (20 * ui_scale)), l1_size)
	}

# ==========================================
# 🎨 DRAWING FUNCTIONS
# ==========================================

func _on_ui_draw() -> void:
	if size == Vector2.ZERO: return 
	
	_draw_3d_joystick(l_base_center, l_stick_pos, "L", l_track_id != -1)
	_draw_3d_joystick(r_base_center, r_stick_pos, "R", r_track_id != -1)
	
	for action in button_rects:
		var rect: Rect2 = button_rects[action]
		var is_pressed = active_buttons.has(action)
		var label = "L2"
		if action == "fire": label = "R2"
		elif action == "grenade": label = "L1"
		elif action == "attack": label = "ATT"
		_draw_rounded_button(rect, label, is_pressed)
		
	_draw_cross_dpad()
	_draw_ps_face_buttons()
	
	var l_press = active_buttons.has("ps_options")
	var r_press = active_buttons.has("ps_home")
	var m_rad = 32.0 * ui_scale
	
	draw_circle(menu_l_center, m_rad, _op(COL_PRESS) if l_press else _op(COL_GLASS))
	draw_circle(menu_l_center, m_rad, _op(COL_BORDER), false, 2.0, true)
	_draw_menu_lines(menu_l_center, false)
	
	draw_circle(menu_r_center, m_rad, _op(COL_PRESS) if r_press else _op(COL_GLASS))
	draw_circle(menu_r_center, m_rad, _op(COL_BORDER), false, 2.0, true)
	_draw_menu_lines(menu_r_center, true)

func _draw_3d_joystick(base: Vector2, stick: Vector2, label: String, is_active: bool) -> void:
	draw_circle(base, max_range, _op(COL_GLASS))
	draw_circle(base, max_range, _op(COL_BORDER), false, 2.5, true)
	
	if is_active:
		draw_circle(base, max_range + 5, _op(COL_GLOW, 0.5), false, 8.0, true)
	
	if default_font:
		var font_sz = int(24 * ui_scale)
		var str_sz = default_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
		draw_string(default_font, base + Vector2(-str_sz.x/2, max_range - (20 * ui_scale)), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, _op(COL_TEXT_DIM))
	
	var stick_radius = 85.0 * ui_scale
	var offset_light = Vector2(-10, -25) * ui_scale
	
	draw_circle(stick + Vector2(0, 12 * ui_scale), stick_radius + 4, Color(0, 0, 0, 0.3 * global_opacity))
	
	var steps = 25
	for i in range(steps):
		var r = stick_radius * (1.0 - float(i) / steps)
		var center_offset = stick + (offset_light * (float(i) / steps))
		var color_val = lerp(0.15, 0.50, float(i) / steps)
		draw_circle(center_offset, r, _op(Color(color_val, color_val, color_val, 1.0)))
		
	draw_circle(stick, stick_radius * 0.65, _op(Color(0,0,0,0.2)), false, 3.0, true)

func _draw_rounded_button(rect: Rect2, text: String, is_pressed: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = _op(COL_PRESS) if is_pressed else _op(COL_GLASS)
	sb.border_color = _op(COL_BORDER)
	sb.set_border_width_all(int(2.5 * ui_scale))
	sb.set_corner_radius_all(int(22 * ui_scale))
	
	if not is_pressed:
		sb.shadow_color = Color(0, 0, 0, 0.25 * global_opacity)
		sb.shadow_size = int(6 * ui_scale)
		sb.shadow_offset = Vector2(0, int(4 * ui_scale))
	
	draw_style_box(sb, rect)
	
	if default_font:
		var font_sz = int(32 * ui_scale)
		var str_sz = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
		var text_pos = rect.position + (rect.size / 2.0) + Vector2(-str_sz.x/2, str_sz.y/3.3)
		draw_string(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, _op(Color.WHITE))

func _draw_cross_dpad() -> void:
	var lenth = 95.0 * ui_scale 
	var thick = 65.0 * ui_scale
	
	var up_pressed = active_buttons.has("dpad_up")
	var down_pressed = active_buttons.has("dpad_down")
	var left_pressed = active_buttons.has("dpad_left")
	var right_pressed = active_buttons.has("dpad_right")
	
	var v_rect = Rect2(dpad_center - Vector2(thick/2, lenth), Vector2(thick, lenth*2))
	var h_rect = Rect2(dpad_center - Vector2(lenth, thick/2), Vector2(lenth*2, thick))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = _op(COL_GLASS)
	sb.set_corner_radius_all(int(16 * ui_scale))
	sb.shadow_color = Color(0, 0, 0, 0.2 * global_opacity)
	sb.shadow_size = int(4 * ui_scale)
	
	draw_style_box(sb, v_rect)
	draw_style_box(sb, h_rect)
	
	draw_circle(dpad_center, 18.0 * ui_scale, _op(Color(0,0,0,0.15)))
	
	_draw_dpad_arm("up", dpad_center + Vector2(0, -lenth*0.62), up_pressed)
	_draw_dpad_arm("down", dpad_center + Vector2(0, lenth*0.62), down_pressed)
	_draw_dpad_arm("left", dpad_center + Vector2(-lenth*0.62, 0), left_pressed)
	_draw_dpad_arm("right", dpad_center + Vector2(lenth*0.62, 0), right_pressed)

func _draw_dpad_arm(dir: String, pos: Vector2, is_pressed: bool) -> void:
	if is_pressed:
		draw_circle(pos, 35.0 * ui_scale, _op(COL_PRESS))
		draw_circle(pos, 35.0 * ui_scale, _op(COL_GLOW, 0.4), false, 4.0, true)
		
	var arrow_col = _op(Color.WHITE) if is_pressed else _op(COL_TEXT_DIM)
	var pts = PackedVector2Array()
	var s = 12.0 * ui_scale
	match dir:
		"up": pts.append_array([pos+Vector2(0,-s), pos+Vector2(-s,s), pos+Vector2(s,s)])
		"down": pts.append_array([pos+Vector2(0,s), pos+Vector2(-s,-s), pos+Vector2(s,-s)])
		"left": pts.append_array([pos+Vector2(-s,0), pos+Vector2(s,-s), pos+Vector2(s,s)])
		"right": pts.append_array([pos+Vector2(s,0), pos+Vector2(-s,-s), pos+Vector2(-s,s)])
	draw_polygon(pts, PackedColorArray([arrow_col]))

func _draw_ps_face_buttons() -> void:
	var base_rad = 160.0 * ui_scale
	draw_circle(face_center, base_rad, _op(COL_GLASS))
	draw_circle(face_center, base_rad, _op(COL_BORDER), false, 2.5, true)
	
	var dist = 90.0 * ui_scale
	var btn_rad = 45.0 * ui_scale
	
	var t_pos = face_center + Vector2(0, -dist)
	_draw_single_face_btn(t_pos, btn_rad, "weapon_swap", "triangle")
	
	var c_pos = face_center + Vector2(dist, 0)
	_draw_single_face_btn(c_pos, btn_rad, "crouch", "circle")
	
	var x_pos = face_center + Vector2(0, dist)
	_draw_single_face_btn(x_pos, btn_rad, "jump", "cross")
	
	var s_pos = face_center + Vector2(-dist, 0)
	_draw_single_face_btn(s_pos, btn_rad, "sprint", "square")

func _draw_single_face_btn(pos: Vector2, rad: float, action: String, shape: String) -> void:
	var is_pressed = active_buttons.has(action)
	draw_circle(pos, rad, _op(Color(0.05, 0.05, 0.06, 0.8)))
	if is_pressed:
		draw_circle(pos, rad, _op(COL_GLOW, 0.8))
		
	draw_circle(pos, rad, _op(COL_BORDER, 0.5), false, 2.0, true)
	_draw_ps_symbol(shape, pos, is_pressed)

func _draw_ps_symbol(type: String, pos: Vector2, is_pressed: bool) -> void:
	var thickness = (5.5 if is_pressed else 4.0) * ui_scale
	var alpha_boost = 1.0 if is_pressed else 0.7
	
	match type:
		"triangle":
			var s = 19.0 * ui_scale
			var pts = PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(-s, s), pos + Vector2(s, s), pos + Vector2(0, -s)])
			draw_polyline(pts, _op(COL_TRIANGLE, alpha_boost), thickness, true)
		"circle":
			draw_arc(pos, 19.0 * ui_scale, 0, TAU, 32, _op(COL_CIRCLE, alpha_boost), thickness, true)
		"cross":
			var s = 16.0 * ui_scale
			draw_line(pos + Vector2(-s, -s), pos + Vector2(s, s), _op(COL_CROSS, alpha_boost), thickness, true)
			draw_line(pos + Vector2(-s, s), pos + Vector2(s, -s), _op(COL_CROSS, alpha_boost), thickness, true)
		"square":
			var s = 16.0 * ui_scale
			var sq_rect = Rect2(pos - Vector2(s, s), Vector2(s*2, s*2))
			draw_rect(sq_rect, _op(COL_SQUARE, alpha_boost), false, thickness)

func _draw_menu_lines(center: Vector2, is_square: bool) -> void:
	var thick = 3.0 * ui_scale
	if not is_square:
		var w = 12 * ui_scale
		draw_line(center + Vector2(-w, -7 * ui_scale), center + Vector2(w, -7 * ui_scale), _op(Color.WHITE), thick, true)
		draw_line(center + Vector2(-w, 0), center + Vector2(w, 0), _op(Color.WHITE), thick, true)
		draw_line(center + Vector2(-w, 7 * ui_scale), center + Vector2(w, 7 * ui_scale), _op(Color.WHITE), thick, true)
	else:
		var s = 10 * ui_scale
		var sq = Rect2(center - Vector2(s, s), Vector2(s*2, s*2))
		draw_rect(sq, _op(Color.WHITE), false, thick)

# ==========================================
# 🎮 INPUT HANDLING
# ==========================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_process_touch_down(event.position, event.index)
		else:
			_process_touch_up(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_process_drag(event.position, event.index)
		accept_event()

func _process_touch_down(pos: Vector2, index: int) -> void:
	for action in button_rects:
		if button_rects[action].has_point(pos):
			active_buttons[action] = index
			Input.action_press(action, 1.0)
			queue_redraw()
			return
			
	var m_click_rad = 50.0 * ui_scale
	if pos.distance_to(menu_l_center) < m_click_rad:
		active_buttons["ps_options"] = index; Input.action_press("ps_options"); queue_redraw(); return
	if pos.distance_to(menu_r_center) < m_click_rad:
		active_buttons["ps_home"] = index; Input.action_press("ps_home"); queue_redraw(); return
		
	if pos.distance_to(face_center) < (180.0 * ui_scale):
		var angle = (pos - face_center).angle()
		var action = ""
		if angle > -PI/4 and angle <= PI/4: action = "crouch"        
		elif angle > PI/4 and angle <= 3*PI/4: action = "jump"       
		elif angle > 3*PI/4 or angle <= -3*PI/4: action = "sprint"   
		else: action = "weapon_swap"                                 
		active_buttons[action] = index
		Input.action_press(action, 1.0)
		queue_redraw()
		return
		
	if pos.distance_to(dpad_center) < (140.0 * ui_scale):
		var angle = (pos - dpad_center).angle()
		var action = ""
		if angle > -PI/4 and angle <= PI/4: action = "dpad_right"
		elif angle > PI/4 and angle <= 3*PI/4: action = "dpad_down"
		elif angle > 3*PI/4 or angle <= -3*PI/4: action = "dpad_left"
		else: action = "dpad_up"
		active_buttons[action] = index
		Input.action_press(action, 1.0)
		queue_redraw()
		return

	if pos.distance_to(l_base_center) < (250.0 * ui_scale) and l_track_id == -1:
		l_track_id = index
		_update_stick(pos, true)
	elif pos.distance_to(r_base_center) < (250.0 * ui_scale) and r_track_id == -1:
		r_track_id = index
		_update_stick(pos, false)

func _process_drag(pos: Vector2, index: int) -> void:
	if index == l_track_id:
		_update_stick(pos, true)
	elif index == r_track_id:
		_update_stick(pos, false)

func _process_touch_up(index: int) -> void:
	if index == l_track_id:
		l_track_id = -1
		l_stick_target = l_base_center
		_clear_actions(["move_left", "move_right", "move_forward", "move_back"])
	elif index == r_track_id:
		r_track_id = -1
		r_stick_target = r_base_center
		_clear_actions(["look_left", "look_right", "look_up", "look_down"])
		
	var to_erase = []
	for action in active_buttons.keys():
		if active_buttons[action] == index:
			Input.action_release(action)
			to_erase.append(action)
			
	for action in to_erase:
		active_buttons.erase(action)
		
	queue_redraw()

func _update_stick(touch_pos: Vector2, is_left: bool) -> void:
	var base = l_base_center if is_left else r_base_center
	var offset = touch_pos - base
	
	if offset.length() > max_range:
		offset = offset.normalized() * max_range
		
	if is_left:
		l_stick_target = base + offset
	else:
		r_stick_target = base + offset
		
	var out = offset / max_range
	if out.length() < deadzone: 
		out = Vector2.ZERO
		
	var actions = ["move_left", "move_right", "move_forward", "move_back"] if is_left else ["look_left", "look_right", "look_up", "look_down"]
	_inject_axis(out, actions)
	queue_redraw()

func _inject_axis(vec: Vector2, acts: Array) -> void:
	if vec.x < 0:
		Input.action_press(acts[0], abs(vec.x)); Input.action_release(acts[1])
	elif vec.x > 0:
		Input.action_press(acts[1], vec.x); Input.action_release(acts[0])
	else:
		Input.action_release(acts[0]); Input.action_release(acts[1])

	if vec.y < 0:
		Input.action_press(acts[2], abs(vec.y)); Input.action_release(acts[3])
	elif vec.y > 0:
		Input.action_press(acts[3], vec.y); Input.action_release(acts[2])
	else:
		Input.action_release(acts[2]); Input.action_release(acts[3])

func _clear_actions(acts: Array) -> void:
	for a in acts: 
		Input.action_release(a)