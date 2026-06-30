extends CharacterBody3D

# ======================== বেসিক মুভমেন্ট ========================
@export_category("Basic Movement")
@export var SPEED: float = 2.0
@export var SPRINT_SPEED: float = 8.0
@export var CROUCH_SPEED: float = 1.2
const JUMP_VELOCITY: float = 4.5

# ======================== AAA ফিজিক্স ========================
@export_category("AAA Physics")
@export var ACCELERATION: float = 8.0
@export var DECELERATION: float = 10.0
@export var AIR_CONTROL: float = 0.3
@export var ROTATION_SPEED: float = 12.0
@export var LEAN_AMOUNT: float = 0.15
@export var LEAN_SPEED: float = 8.0

# ======================== স্ট্যামিনা ========================
@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var sprint_drain: float = 20.0
@export var stamina_regen: float = 15.0
@export var stamina_regen_delay: float = 0.5
var stamina: float = max_stamina
var stamina_delay_timer: float = 0.0

# ======================== ক্রাউচ / স্লাইড ========================
@export_category("Crouch & Slide")
@export var crouch_height_ratio: float = 0.5
@export var slide_duration: float = 0.5
@export var slide_deceleration: float = 5.0
@export var slide_initial_boost: float = 1.2
var is_crouching: bool = false
var slide_timer: float = 0.0
var was_sprinting_before_slide: bool = false

# ======================== জাম্প বাফার ========================
@export_category("Jump Buffer")
@export var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0

# ======================== ডজ / ড্যাশ ========================
@export_category("Dodge")
@export var dodge_distance: float = 4.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 0.5
@export var dodge_stamina_cost: float = 20.0
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

# ======================== ওয়াল জাম্প ========================
@export_category("Wall Jump")
@export var wall_jump_force: float = 6.0
@export var wall_jump_up: float = 4.0
@export var wall_slide_speed: float = 1.0
var is_wall_sliding: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var wall_jump_used: bool = false

# ======================== লেজ গ্র্যাব ========================
@export_category("Ledge Grab")
@export var ledge_grab_range: float = 0.6
@export var climb_up_speed: float = 2.0
var is_ledge_grabbing: bool = false
var ledge_position: Vector3 = Vector3.ZERO
var climb_phase: float = 0.0

# ======================== এয়ার ড্যাশ ========================
@export_category("Air Dash")
@export var air_dash_stamina: float = 25.0
var air_dash_used: bool = false

# ======================== ল্যান্ডিং রোল ========================
@export_category("Landing Roll")
@export var roll_threshold: float = -6.0

# ======================== ফুটস্টেপ ========================
@export_category("Footsteps")
@export var walk_step_interval: float = 0.5
@export var run_step_interval: float = 0.35
var step_timer: float = 0.0

# ======================== স্টেট মেশিন ========================
enum PlayerState {IDLE, WALK, RUN, JUMP, FALL, ATTACK, CROUCH, SLIDE, DODGE, WALL_SLIDE, LEDGE_GRAB, CLIMB_UP}
var current_state: PlayerState = PlayerState.IDLE

# ======================== নোড রেফারেন্স ========================
@onready var head: Node3D = $head
@onready var player_mesh: Node3D = $CollisionShape3D/"model1"
@onready var anim_player: AnimationPlayer = $CollisionShape3D/"model1"/AnimationPlayer
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer if has_node("FootstepPlayer") else null
@onready var footstep_player_extra: AudioStreamPlayer = $FootstepPlayerExtra if has_node("FootstepPlayerExtra") else null
@onready var ground_ray: RayCast3D = $GroundRay if has_node("GroundRay") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var land_sound_player: AudioStreamPlayer = $LandSoundPlayer if has_node("LandSoundPlayer") else null
@onready var wall_detector: RayCast3D = $WallDetector if has_node("WallDetector") else null

var original_collider_height: float = 0.0
var coyote_time: float = 0.0
const COYOTE_TIME_MAX: float = 0.15

func _ready() -> void:
	if anim_player == null and is_instance_valid(player_mesh):
		for child in player_mesh.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
	if not anim_player:
		print("ERROR: AnimationPlayer not found!")

	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape3D:
			original_collider_height = collision_shape.shape.height
		elif collision_shape.shape is BoxShape3D:
			original_collider_height = collision_shape.shape.size.y

func _physics_process(delta: float) -> void:
	_update_stamina(delta)
	_update_timers(delta)
	_handle_jump_buffer(delta)
	_apply_gravity(delta)

	# বিশেষ স্টেটগুলোর জন্য আলাদা প্রক্রিয়া
	if current_state == PlayerState.DODGE:
		_dodge_movement(delta)
		move_and_slide()
		return
	if current_state == PlayerState.LEDGE_GRAB or current_state == PlayerState.CLIMB_UP:
		_ledge_process(delta)
		return

	# দেয়াল চেক (ওয়াল স্লাইড) - null থাকলে skip
	if wall_detector:
		_handle_wall_detection()

	# লেজ গ্র্যাব চেক (শুধু শূন্যে পড়ার সময়)
	if not is_on_floor():
		_check_ledge_grab()

	_handle_jump()
	_handle_attack()
	_handle_dodge()
	_handle_air_dash()
	_handle_crouch_slide(delta)
	_update_movement(delta)
	_update_footsteps(delta)
	_update_animation_state()
	_handle_landing_impact()
	move_and_slide()
	_apply_slope_physics()

# ========================================================
# টাইমার আপডেট (ডজ কুলডাউন ইত্যাদি)
# ========================================================
func _update_timers(delta: float) -> void:
	if dodge_cooldown_timer > 0:
		dodge_cooldown_timer -= delta

# ========================================================
# স্ট্যামিনা সিস্টেম
# ========================================================
func _update_stamina(delta: float) -> void:
	var is_exhausting = (current_state == PlayerState.RUN or current_state == PlayerState.ATTACK or current_state == PlayerState.DODGE)
	if is_exhausting:
		stamina = max(stamina - sprint_drain * delta, 0)
		stamina_delay_timer = 0.0
		if stamina <= 0.0 and current_state == PlayerState.RUN:
			_change_state(PlayerState.WALK)
	else:
		stamina_delay_timer += delta
		if stamina_delay_timer >= stamina_regen_delay:
			stamina = min(stamina + stamina_regen * delta, max_stamina)

# ========================================================
# জাম্প বাফার ও জাম্প
# ========================================================
func _handle_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if not is_on_floor():
		jump_buffer_timer -= delta

func _handle_jump() -> void:
	# ওয়াল জাম্প অগ্রাধিকার
	if current_state == PlayerState.WALL_SLIDE and Input.is_action_just_pressed("jump") and not wall_jump_used:
		velocity.y = wall_jump_up
		if wall_normal != Vector3.ZERO:
			velocity += wall_normal * wall_jump_force
		wall_jump_used = true
		_change_state(PlayerState.JUMP)
		return

	var can_jump = (coyote_time > 0.0 or jump_buffer_timer > 0.0) and Input.is_action_pressed("jump")
	if can_jump and stamina > 1.0 and not is_wall_sliding:
		velocity.y = JUMP_VELOCITY
		coyote_time = 0.0
		jump_buffer_timer = 0.0
		wall_jump_used = false
		air_dash_used = false
		_change_state(PlayerState.JUMP)

# ========================================================
# অ্যাটাক
# ========================================================
func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and is_on_floor() and stamina > 10.0:
		_change_state(PlayerState.ATTACK)
		stamina = max(stamina - 10.0, 0)

# ========================================================
# ডজ (গ্রাউন্ড ড্যাশ)
# ========================================================
func _handle_dodge() -> void:
	if is_dodging or dodge_cooldown_timer > 0 or stamina < dodge_stamina_cost:
		return
	if Input.is_action_just_pressed("dodge") and is_on_floor():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input_dir == Vector2.ZERO:
			dodge_direction = -head.global_transform.basis.z.normalized()
		else:
			dodge_direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		dodge_direction.y = 0
		is_dodging = true
		dodge_timer = dodge_duration
		dodge_cooldown_timer = dodge_cooldown
		stamina -= dodge_stamina_cost
		_change_state(PlayerState.DODGE)

func _dodge_movement(delta: float) -> void:
	if dodge_timer > 0:
		velocity = dodge_direction * (dodge_distance / dodge_duration)
		dodge_timer -= delta
	else:
		is_dodging = false
		velocity = Vector3.ZERO
		_change_state(PlayerState.IDLE)

# ========================================================
# এয়ার ড্যাশ
# ========================================================
func _handle_air_dash() -> void:
	if air_dash_used or is_on_floor() or stamina < air_dash_stamina:
		return
	if Input.is_action_just_pressed("dodge"):
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir = Vector3.ZERO
		if input_dir == Vector2.ZERO:
			dir = -head.global_transform.basis.z.normalized()
		else:
			dir = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		dir.y = 0
		velocity = dir * (dodge_distance / dodge_duration)
		air_dash_used = true
		stamina -= air_dash_stamina

# ========================================================
# ওয়াল ডিটেকশন ও স্লাইড
# ========================================================
func _handle_wall_detection() -> void:
	if not wall_detector:   # safety
		return
	if is_on_floor():
		is_wall_sliding = false
		return
	wall_detector.force_raycast_update()
	if wall_detector.is_colliding():
		var normal = wall_detector.get_collision_normal()
		if abs(normal.dot(Vector3.UP)) < 0.1:
			wall_normal = normal
			is_wall_sliding = true
			velocity.y = max(velocity.y, -wall_slide_speed)
			_change_state(PlayerState.WALL_SLIDE)
		else:
			is_wall_sliding = false
	else:
		is_wall_sliding = false

# ========================================================
# লেজ গ্র্যাব ও ক্লাইম
# ========================================================
func _check_ledge_grab() -> void:
	if is_on_floor() or velocity.y > 0:
		return
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin + Vector3.UP * 0.5,
		global_transform.origin + Vector3.UP * 0.5 - head.global_transform.basis.z * ledge_grab_range
	)
	var result = space_state.intersect_ray(query)
	if result:
		ledge_position = result.position + Vector3.UP * 0.1
		_change_state(PlayerState.LEDGE_GRAB)

func _ledge_process(delta: float) -> void:
	if current_state == PlayerState.LEDGE_GRAB:
		velocity = Vector3.ZERO
		global_transform.origin = ledge_position
		if Input.is_action_just_pressed("jump"):
			global_transform.origin += Vector3.UP * 0.5
			velocity = Vector3.UP * JUMP_VELOCITY * 0.8
			_change_state(PlayerState.JUMP)
			return
		if Input.is_action_just_pressed("move_forward"):
			_change_state(PlayerState.CLIMB_UP)
			climb_phase = 0.0
	elif current_state == PlayerState.CLIMB_UP:
		climb_phase += climb_up_speed * delta
		if climb_phase >= 1.0:
			global_transform.origin += Vector3.UP * 0.8
			_change_state(PlayerState.IDLE)
			velocity = Vector3.ZERO

# ========================================================
# ক্রাউচ ও স্লাইড
# ========================================================
func _handle_crouch_slide(delta: float) -> void:
	var crouch_pressed = Input.is_action_just_pressed("crouch")
	var sprinting = Input.is_action_pressed("sprint") and is_on_floor() and stamina > 0.0

	if crouch_pressed:
		if sprinting and not is_crouching:
			was_sprinting_before_slide = true
			_change_state(PlayerState.SLIDE)
			slide_timer = slide_duration
			velocity.x *= slide_initial_boost
			velocity.z *= slide_initial_boost
			_set_collider_height(crouch_height_ratio)
			is_crouching = true
		elif is_crouching:
			_set_collider_height(1.0)
			is_crouching = false
			if current_state == PlayerState.CROUCH:
				_change_state(PlayerState.IDLE)
		else:
			is_crouching = true
			_set_collider_height(crouch_height_ratio)
			_change_state(PlayerState.CROUCH)

	if current_state == PlayerState.SLIDE:
		slide_timer -= delta
		velocity.x = lerp(velocity.x, 0.0, slide_deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, slide_deceleration * delta)
		if slide_timer <= 0.0:
			_change_state(PlayerState.CROUCH)
			is_crouching = true
			_set_collider_height(crouch_height_ratio)
			was_sprinting_before_slide = false

func _set_collider_height(ratio: float) -> void:
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape3D:
			collision_shape.shape.height = original_collider_height * ratio
		elif collision_shape.shape is BoxShape3D:
			var sz = collision_shape.shape.size
			sz.y = original_collider_height * ratio
			collision_shape.shape.size = sz

# ========================================================
# মুভমেন্ট
# ========================================================
func _update_movement(delta: float) -> void:
	if current_state == PlayerState.SLIDE or current_state == PlayerState.DODGE:
		return
	var current_speed = SPEED
	if is_crouching and current_state != PlayerState.SLIDE:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and is_on_floor() and stamina > 0.0:
		current_speed = SPRINT_SPEED

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0
	direction = direction.normalized()

	var current_accel = ACCELERATION if is_on_floor() else ACCELERATION * AIR_CONTROL
	var current_decel = DECELERATION if is_on_floor() else DECELERATION * 0.2

	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, current_accel * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, current_accel * delta)
		if is_instance_valid(player_mesh):
			var target_angle = atan2(direction.x, direction.z)
			var angle_diff = wrapf(target_angle - player_mesh.rotation.y, -PI, PI)
			player_mesh.rotation.y += angle_diff * ROTATION_SPEED * delta
			var speed_ratio = velocity.length() / SPRINT_SPEED
			var target_lean = clamp(-angle_diff * LEAN_AMOUNT * speed_ratio, -LEAN_AMOUNT, LEAN_AMOUNT)
			player_mesh.rotation.z = lerp(player_mesh.rotation.z, target_lean, LEAN_SPEED * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, current_decel * delta)
		velocity.z = lerp(velocity.z, 0.0, current_decel * delta)
		if is_instance_valid(player_mesh):
			player_mesh.rotation.z = lerp(player_mesh.rotation.z, 0.0, LEAN_SPEED * delta)

# ========================================================
# গ্র্যাভিটি ও কায়োট টাইম
# ========================================================
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		coyote_time = COYOTE_TIME_MAX
	else:
		coyote_time -= delta
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

# ========================================================
# ঢালু হ্যান্ডলিং (স্লোপ)
# ========================================================
func _apply_slope_physics() -> void:
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var angle_rad = floor_normal.angle_to(Vector3.UP)
		if angle_rad > 0.0 and angle_rad < deg_to_rad(45.0):
			var dot = floor_normal.dot(Vector3.UP)
			var slope_factor = 1.0 - dot
			if velocity.length() > 0.1:
				var direction_h = Vector3(velocity.x, 0, velocity.z).normalized()
				var slope_dir = floor_normal - Vector3.UP * floor_normal.dot(Vector3.UP)
				slope_dir = slope_dir.normalized()
				if direction_h.dot(slope_dir) < 0:
					velocity.x -= slope_dir.x * slope_factor * 2.0
					velocity.z -= slope_dir.z * slope_factor * 2.0
				else:
					velocity.x += slope_dir.x * slope_factor * 1.0
					velocity.z += slope_dir.z * slope_factor * 1.0

# ========================================================
# ফুটস্টেপ সাউন্ড
# ========================================================
func _update_footsteps(delta: float) -> void:
	if not is_on_floor() or velocity.length() < 0.2:
		return
	var interval = run_step_interval if current_state == PlayerState.RUN else walk_step_interval
	step_timer += delta
	if step_timer >= interval:
		step_timer -= interval
		_play_footstep()

func _play_footstep() -> void:
	if not footstep_player and not footstep_player_extra:
		return   # অডিও প্লেয়ার ইন্সটল না থাকলে কিছু করবে না
	var surface_name = "concrete"
	if ground_ray and ground_ray.is_colliding():
		var collider = ground_ray.get_collider()
		if collider:
			if collider.is_in_group("grass"):
				surface_name = "grass"
			elif collider.is_in_group("wood"):
				surface_name = "wood"
	var sound_path = "res://audio/footsteps/" + surface_name + "_step.ogg"
	var sound = load(sound_path)
	if sound:
		if footstep_player and not footstep_player.playing:
			footstep_player.stream = sound
			footstep_player.play()
		elif footstep_player_extra and not footstep_player_extra.playing:
			footstep_player_extra.stream = sound
			footstep_player_extra.play()

# ========================================================
# ল্যান্ডিং ইমপ্যাক্ট
# ========================================================
var was_in_air: bool = false
func _handle_landing_impact() -> void:
	if is_on_floor() and was_in_air:
		var fall_speed = abs(velocity.y)
		if fall_speed > 5.0:
			if anim_player and anim_player.has_animation("anim/land_hard"):
				anim_player.play("anim/land_hard", 0.1)
			if land_sound_player:
				land_sound_player.play()
		elif fall_speed > 2.0:
			if anim_player and anim_player.has_animation("anim/land_soft"):
				anim_player.play("anim/land_soft", 0.1)
	was_in_air = not is_on_floor()

# ========================================================
# স্টেট ম্যানেজমেন্ট ও অ্যানিমেশন
# ========================================================
func _change_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	# কিছু স্টেট থেকে বের হওয়া আটকানো (ইন্টারাপ্ট রোধ)
	if current_state == PlayerState.ATTACK and new_state != PlayerState.ATTACK:
		return
	if current_state == PlayerState.SLIDE and new_state != PlayerState.SLIDE:
		return
	if current_state == PlayerState.DODGE and new_state != PlayerState.DODGE:
		return
	if current_state == PlayerState.LEDGE_GRAB or current_state == PlayerState.CLIMB_UP:
		return
	current_state = new_state
	_apply_animation()

func _update_animation_state() -> void:
	if current_state in [PlayerState.ATTACK, PlayerState.SLIDE, PlayerState.DODGE, PlayerState.LEDGE_GRAB, PlayerState.CLIMB_UP]:
		return
	if not is_on_floor():
		if velocity.y > 0.1:
			_change_state(PlayerState.JUMP)
		elif velocity.y < -0.1:
			_change_state(PlayerState.FALL)
		return

	if is_crouching and current_state != PlayerState.SLIDE:
		_change_state(PlayerState.CROUCH)
		return

	if velocity.length() < 0.2:
		_change_state(PlayerState.IDLE)
	else:
		if Input.is_action_pressed("sprint") and stamina > 0.0:
			_change_state(PlayerState.RUN)
		else:
			_change_state(PlayerState.WALK)

func _apply_animation() -> void:
	if not is_instance_valid(anim_player):
		return
	match current_state:
		PlayerState.IDLE:
			anim_player.play("anim/idle", 0.2)
		PlayerState.WALK:
			anim_player.play("anim/walk", 0.2)
		PlayerState.RUN:
			anim_player.play("anim/run", 0.2)
		PlayerState.JUMP:
			anim_player.play("anim/jump", 0.1)
		PlayerState.FALL:
			anim_player.play("anim/fall", 0.1)
		PlayerState.ATTACK:
			var anim = anim_player.get_animation("anim/attack")
			if anim and anim.loop_mode != Animation.LOOP_NONE:
				anim.loop_mode = Animation.LOOP_NONE
			anim_player.play("anim/attack", 0.1)
			if not anim_player.animation_finished.is_connected(_on_attack_finished):
				anim_player.animation_finished.connect(_on_attack_finished)
		PlayerState.CROUCH:
			anim_player.play("anim/crouch_idle", 0.2)
		PlayerState.SLIDE:
			anim_player.play("anim/slide", 0.1)
		PlayerState.DODGE:
			anim_player.play("anim/dodge", 0.1)
		PlayerState.WALL_SLIDE:
			anim_player.play("anim/wall_slide", 0.1)
		PlayerState.LEDGE_GRAB:
			anim_player.play("anim/ledge_grab", 0.1)
		PlayerState.CLIMB_UP:
			anim_player.play("anim/climb_up", 0.1)

func _on_attack_finished(anim_name: String) -> void:
	if anim_name == "anim/attack":
		current_state = PlayerState.IDLE
		if anim_player.animation_finished.is_connected(_on_attack_finished):
			anim_player.animation_finished.disconnect(_on_attack_finished)