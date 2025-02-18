extends CharacterBody2D

@export_category("Player Stuffs")

@export_group("Toggles")
@export var can_crouch := true
@export var can_dash := true
@export var can_double_jump := true
@export var can_wall_jump := true

@export_group("Horizontal")
@export var BASE_SPEED := 225.0
@export var ACCELERATION := 1500.0
@export var DECELERATION := 2000.0

@export_group("Vertical")
@export var JUMP_VELOCITY := -500.0
@export var VARIABLE_JUMP_MULTIPLIER := 1.75
@export var FALL_MULTIPLIER := 1.0
@export var LOW_JUMP_MULTIPLIER := 3.5
@export var COYOTE_TIME := 0.1
@export var JUMP_BUFFER_TIME := 0.15

@export_group("Wall")
@export var WALL_JUMP_VELOCITY := Vector2(180, -400)
@export var WALL_SLIDE_SPEED := 50.0
@export var WALL_JUMPING_DURATION := 0.15

@export_group("Other")
@export var DASH_SPEED := 500.0
@export var DASH_DURATION := 0.15
@export var ROLL_SPEED := 300.0
@export var LAND_TIME := 0.2
@export var CROUCHING_POSITION := Vector2(0, 7)
@export var PUSH_FORCE := 80.0

@onready var animated_sprite := $AnimatedSprite2D
@onready var collision_shape := $CollisionShape2D
@onready var crouch_rc1 := $"RayCast2D 1"
@onready var crouch_rc2 := $"RayCast2D 2"

var direction : float
var is_crouching := false
var is_wall_sliding := false
var is_wall_jumping := false
var has_double_jumped := false
var is_dashing := false
var is_landing := false
var dash_timer := 0.0
var speed := 0.0
var wall_jumping_timer := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var landing_timer := 0.0
var c : KinematicCollision2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var standing_shape : RectangleShape2D
var crouching_shape := RectangleShape2D.new()
var standing_position : Vector2
var crouching_position : Vector2
var was_on_floor = false

func _ready():
	initialize_shapes()

func _physics_process(delta):
	
	update_floor_status()
	update_input_direction()
	handle_crouch()
	handle_dash(delta)
	
	handle_wall_jump_state(delta)
	update_coyote_timer(delta)
	update_jump_buffer(delta)
	update_landing_timer(delta)
	handle_wall_slide()
	apply_gravity(delta)
	handle_jump()
	apply_variable_jump(delta)
	update_velocity(delta)
	
	move_and_slide()
	handle_collisions()
	handle_landing_detection()
	
	play_animations()

func initialize_shapes():
	standing_shape = collision_shape.shape.duplicate()
	crouching_shape.extents = Vector2(standing_shape.extents.x, standing_shape.extents.y / 2)
	standing_position = collision_shape.position
	crouching_position = CROUCHING_POSITION

func update_floor_status():
	was_on_floor = is_on_floor()

func update_input_direction():
	if is_wall_jumping and not is_dashing:
		return
	
	direction = Input.get_axis("move_left", "move_right")
	if direction != 0 and not is_wall_sliding:
		animated_sprite.flip_h = direction < 0

func handle_crouch():
	if can_crouch and Input.is_action_pressed("crouch") and is_on_floor():
		is_crouching = true
		collision_shape.shape = crouching_shape
		collision_shape.position = crouching_position
	elif not crouch_rc1.is_colliding() and not crouch_rc2.is_colliding():
		is_crouching = false
		collision_shape.shape = standing_shape
		collision_shape.position = standing_position

func handle_dash(delta):
	if is_dashing:
		dash_timer -= delta
		# Check if the player has changed direction during the dash
		if direction != 0 and direction != sign(velocity.x):
			is_dashing = false
			velocity.x = 0
		elif dash_timer <= 0:
			is_dashing = false
			velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
	else:
		if can_dash and Input.is_action_just_pressed("dash") and not is_wall_sliding and not is_dashing:
			start_dash()

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	can_dash = false
	
	var dash_direction = direction
	if dash_direction == 0:
		dash_direction = -1 if animated_sprite.flip_h else 1  # Default to sprite's facing direction
	
	velocity.x = dash_direction * (ROLL_SPEED if is_crouching else DASH_SPEED)

func handle_wall_jump_state(delta):
	if is_wall_jumping:
		wall_jumping_timer -= delta
	if wall_jumping_timer <= 0:
		is_wall_jumping = false
		wall_jumping_timer = WALL_JUMPING_DURATION

func update_coyote_timer(delta):
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		has_double_jumped = false
		can_dash = true
	else:
		coyote_timer -= delta

func update_jump_buffer(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func update_landing_timer(delta):
	if is_landing:
		landing_timer -= delta
		if landing_timer <= 0:
			is_landing = false

func handle_wall_slide():
	is_wall_sliding = can_wall_jump and not is_on_floor() and is_on_wall() and direction != 0 and velocity.y > 0
	if is_wall_sliding:
		velocity.y = WALL_SLIDE_SPEED

func apply_gravity(delta):
	if not is_on_floor() and not is_wall_sliding:
		velocity.y += gravity * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and not crouch_rc1.is_colliding() and not crouch_rc2.is_colliding():
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			perform_jump()
		elif can_wall_jump and is_wall_sliding:
			perform_wall_jump()
		elif can_double_jump and not has_double_jumped:
			perform_double_jump()

func perform_jump():
	velocity.y = JUMP_VELOCITY
	reset_jump_timers()

func perform_wall_jump():
	is_wall_jumping = true
	velocity = Vector2(WALL_JUMP_VELOCITY.x if animated_sprite.flip_h else -WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y)
	reset_jump_timers()
	animated_sprite.flip_h = not animated_sprite.flip_h

func perform_double_jump():
	velocity.y = JUMP_VELOCITY
	has_double_jumped = true
	reset_jump_timers()

func reset_jump_timers():
	jump_buffer_timer = 0
	coyote_timer = 0
	can_dash = true

func apply_variable_jump(delta):
	if velocity.y < 0:
		velocity.y += gravity * ((VARIABLE_JUMP_MULTIPLIER if Input.is_action_pressed("jump") else LOW_JUMP_MULTIPLIER) - 1) * delta
	elif velocity.y > 0:
		velocity.y += gravity * (FALL_MULTIPLIER - 1) * delta

func update_velocity(delta):
	speed = BASE_SPEED * (0.5 if is_crouching else 1.0)
	if not is_wall_jumping and not is_dashing:
		velocity.x = move_toward(velocity.x, direction * speed if direction != 0.0 else 0.0, (ACCELERATION if direction != 0.0 else DECELERATION) * delta)

func handle_collisions():
	for i in get_slide_collision_count():
		c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE)
	
func handle_landing_detection():
	if was_on_floor != is_on_floor() and is_on_floor():
		is_landing = true
		landing_timer = LAND_TIME

func play_animations():
	if is_dashing:
		if is_crouching:
			animated_sprite.play("roll")
		else:
			animated_sprite.play("dash")
	elif is_landing && not is_crouching && direction == 0:
		animated_sprite.play("land")
	elif is_on_floor():
		if direction == 0:
			if is_crouching:
				animated_sprite.play("crouch")
			else:
				animated_sprite.play("idle")
		else:
			if is_crouching:
				animated_sprite.play("crouch walk")
			else:
				animated_sprite.play("run")
	elif is_wall_sliding:
		animated_sprite.play("wall slide")
	
	else: # Handle jump animations
		if velocity.y <= 0:
			animated_sprite.play("jump rise")
			if animated_sprite.frame == 3:
				animated_sprite.pause()
		else:
			animated_sprite.play("jump fall")
			if animated_sprite.frame == 1:
				animated_sprite.pause()
