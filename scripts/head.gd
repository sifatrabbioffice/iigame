extends Node3D

@export_category("Look & Feel (Joystick Only)")
@export var SENSITIVITY: float = 0.005
@export var TOUCH_SPEED_MULTIPLIER: float = 350.0 
@export var ROTATION_SMOOTHING: float = 20.0 # ক্যামেরা ঘোরার মোলায়েম মোমেন্টাম

@export_category("Follow Physics")
@export var follow_speed_horizontal: float = 18.0 
@export var follow_speed_vertical: float = 4.0     

@export_category("AAA Dynamic Effects")
@export var base_fov: float = 75.0           
@export var sprint_fov: float = 90.0         
@export var fov_transition_speed: float = 6.0
@export var bob_frequency: float = 2.5       
@export var bob_amplitude: float = 0.04      

# ডিরেক্ট পাথ ম্যাপিং (১০০% ক্র্যাশ প্রুফ)
@onready var player: CharacterBody3D = get_parent() 
@onready var camera: Camera3D = $Camera3D

var rotation_x: float = 0.0
var rotation_y: float = 0.0

# স্মুথ রোটেশন ফিল্টারিং ভেরিয়েবল
var current_rotation_x: float = 0.0
var current_rotation_y: float = 0.0

# হেড ববিং ট্র্যাকিং
var t_bob: float = 0.0
var camera_base_y: float = 0.0
var camera_base_x: float = 0.0

func _ready() -> void:
	# ক্যামেরাকে প্লেয়ারের ঝটকা মুভমেন্ট থেকে আলাদা করা হলো
	set_as_top_level(true)
	
	# ক্যামেরার ডিফল্ট লোকাল পজিশন মেমরিতে সেভ রাখা হচ্ছে প্রসিডিউরাল অ্যানিমেশনের জন্য
	camera_base_y = camera.position.y
	camera_base_x = camera.position.x
	camera.fov = base_fov
	
	# রোটেশন ভেক্টরের প্রারম্ভিক মান সেটআপ
	rotation_y = rotation.y
	rotation_x = rotation.x
	current_rotation_y = rotation.y
	current_rotation_x = rotation.x

func _process(delta: float) -> void:
	if not player: return
	
	# ১. পজিশন ট্র্যাকিং (প্লেয়ার বডিকে তাড়া করা)
	var target_pos = player.global_position
	global_position.x = lerp(global_position.x, target_pos.x, follow_speed_horizontal * delta)
	global_position.z = lerp(global_position.z, target_pos.z, follow_speed_horizontal * delta)
	
	var y_lerp_speed = follow_speed_horizontal if player.is_on_floor() else follow_speed_vertical
	global_position.y = lerp(global_position.y, target_pos.y, y_lerp_speed * delta)
	
	# ২. এক্সক্লুসিভ জয়স্টিক ইনপুট প্রসেসিং
	_handle_ui_joystick_look(delta)
	
	# ৩. রোটেশন মোমেন্টাম (AAA Look Smoothing)
	current_rotation_x = lerp_angle(current_rotation_x, rotation_x, ROTATION_SMOOTHING * delta)
	current_rotation_y = lerp_angle(current_rotation_y, rotation_y, ROTATION_SMOOTHING * delta)
	
	# ক্যামেরার ফাইনাল রোটেশন ম্যাট্রিক্স অ্যাপ্লাই
	transform.basis = Basis.from_euler(Vector3(current_rotation_x, current_rotation_y, 0))

	# ৪. ডাইনামিক FOV মেকানিজম (গতি বাড়লে ভিউ ওয়াইড হওয়া)
	var target_fov = base_fov
	if Input.is_action_pressed("sprint") and player.velocity.length() > 1.0:
		target_fov = sprint_fov
	camera.fov = lerp(camera.fov, target_fov, fov_transition_speed * delta)

	# ৫. প্রসিডিউরাল হেড ববিং (বাস্তবসম্মত হাঁটার কম্পন)
	if player.is_on_floor() and player.velocity.length() > 1.0:
		t_bob += delta * player.velocity.length() 
		var expected_bob_y = sin(t_bob * bob_frequency) * bob_amplitude
		var expected_bob_x = cos(t_bob * bob_frequency / 2.0) * (bob_amplitude / 2.0)
		
		camera.position.y = lerp(camera.position.y, camera_base_y + expected_bob_y, delta * 15.0)
		camera.position.x = lerp(camera.position.x, camera_base_x + expected_bob_x, delta * 15.0)
	else:
		camera.position.y = lerp(camera.position.y, camera_base_y, delta * 8.0)
		camera.position.x = lerp(camera.position.x, camera_base_x, delta * 8.0)
		t_bob = 0.0

func _handle_ui_joystick_look(delta: float) -> void:
	var look_vec = Vector2.ZERO
	
	# শুধুমাত্র ডেডিকেটেড জয়স্টিক ইনপুট ম্যাপ রিড করা হচ্ছে
	if InputMap.has_action("look_right"):
		look_vec.x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
		look_vec.y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	else:
		# ফালব্যাক মেকানিজম (যদি কোন কারণে ইনপুট ম্যাপ সেট না থাকে)
		look_vec.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		look_vec.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	if look_vec.length() > 0.0:
		var look_dir = look_vec.normalized()
		# Aim Acceleration Curve (জয়স্টিকের সূক্ষ্ম নড়াচড়ায় নিখুঁত নিশানা, পুরোটা টানলে তীব্র গতি)
		var look_strength = pow(look_vec.length(), 1.5) 
		
		rotation_y -= look_dir.x * look_strength * SENSITIVITY * TOUCH_SPEED_MULTIPLIER * delta
		rotation_x -= look_dir.y * look_strength * SENSITIVITY * TOUCH_SPEED_MULTIPLIER * delta
		
		# ক্যামেরা যেন উল্টে ৩৬০ ডিগ্রি ঘুরে না যায় (লক মেকানিজম)
		rotation_x = clamp(rotation_x, deg_to_rad(-45), deg_to_rad(60))
