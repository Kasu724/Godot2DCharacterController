extends CharacterBody2D

@export_category("Player Stuffs")

@export_group("Toggles")
@export var can_crouch = true
@export var can_dash = true  # Toggle for dash ability
@export var can_double_jump = true  # Toggle for double jump ability
@export var can_wall_jump = true  # Toggle for wall jump ability

@export_group("Horizontal")
@export var BASE_SPEED = 200.0
@export var ACCELERATION = 1500.0
@export var DECELERATION = 2000.0

@export_group("Vertical")
@export var JUMP_VELOCITY = -250.0
@export var VARIABLE_JUMP_MULTIPLIER = 0.5  # Adjust this value to control the variable jump height effect
@export var FALL_MULTIPLIER = 1.0  # Stronger gravity when falling
@export var LOW_JUMP_MULTIPLIER = 2.0  # Stronger gravity when jump button is released early
@export var COYOTE_TIME = 0.1  # Time after leaving the ground that the player can still jump
@export var JUMP_BUFFER_TIME = 0.15  # Time for jump buffering

@export_group("Wall")
@export var WALL_JUMP_VELOCITY = Vector2(100, JUMP_VELOCITY)  # Horizontal and vertical velocities for wall jump
@export var WALL_SLIDE_SPEED = 50.0  # Speed at which the player slides down the wall
@export var WALL_JUMPING_DURATION = 0.15 # Time that player will be wall jumping

@export_group("Other")
@export var DASH_SPEED = 500.0  # Speed during dash
@export var DASH_DURATION = 0.15  # Duration of the dash in seconds
@export var ROLL_SPEED = 300.0 # Speed during roll
@export var LAND_TIME = 0.2 # Time it takes to land
@export var CROUCHING_POSITION = Vector2(0, 7)

var direction
var is_crouching = false
var is_wall_sliding = false
var is_wall_jumping = false
var has_double_jumped = false
var is_dashing = false
var dash_again = false
var is_landing = false
var was_on_floor = false
var dash_timer = 0.0
var speed = 0.0
var wall_jumping_timer = 0.0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var landing_timer = 0.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var crouch_rc1 = $"RayCast2D 1"
@onready var crouch_rc2 = $"RayCast2D 2"

var standing_shape
var crouching_shape = RectangleShape2D.new() # Create a new shape for crouching
var standing_position
var crouching_position

func _ready():
	# Initialize shapes and positions for standing and crouching collisions
	standing_shape = collision_shape.shape.duplicate()
	crouching_shape.extents = Vector2(standing_shape.extents.x, standing_shape.extents.y / 2)
	standing_position = collision_shape.position
	crouching_position = CROUCHING_POSITION

func _physics_process(delta):
	
	# Floor check
	var was_on_floor_prev = was_on_floor
	was_on_floor = is_on_floor()
	
	# Get the input direction: -1, 0, 1
	direction = Input.get_axis("move_left", "move_right")
	
	# Handle crouching
	if can_crouch and Input.is_action_pressed("crouch") and is_on_floor():
		is_crouching = true
		collision_shape.shape = crouching_shape
		collision_shape.position = crouching_position
	elif not crouch_rc1.is_colliding() and not crouch_rc2.is_colliding():
		is_crouching = false
		collision_shape.shape = standing_shape
		collision_shape.position = standing_position
	
	# Handle dash timer and dash canceling
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
		elif direction != 0 and direction != sign(velocity.x):
			# Cancel dash if the player presses the opposite direction
			is_dashing = false
			velocity.x = 0  # Stop horizontal movement

	# Handle dash input
	if can_dash and Input.is_action_just_pressed("dash") and not is_wall_sliding and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		can_dash = false  # Disable dash until the player jumps again
		if direction != 0:
			if is_crouching:
				velocity.x = direction * ROLL_SPEED
			else:
				velocity.x = direction * DASH_SPEED
		else:
			# Dash in the current facing direction if no input direction
			if is_crouching:
				velocity.x = ROLL_SPEED if not animated_sprite.flip_h else -ROLL_SPEED
			else:
				velocity.x = DASH_SPEED if not animated_sprite.flip_h else -DASH_SPEED

	# Reset wall slide and wall jump state
	is_wall_sliding = false
	if is_wall_jumping:
		wall_jumping_timer -= delta
	if wall_jumping_timer <= 0:
		is_wall_jumping = false
		wall_jumping_timer = WALL_JUMPING_DURATION
	
	# Update coyote timer and double jump
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		has_double_jumped = false  # Reset double jump when on the floor
		can_dash = true  # Reset dash when on the floor
	else:
		coyote_timer -= delta

	# Update jump buffer timer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Update landing timer
	if is_landing:
		landing_timer -= delta
		if landing_timer <= 0:
			is_landing = false
	
	# Check for wall sliding
	if can_wall_jump and not is_on_floor() and is_on_wall() and direction != 0:
		if velocity.y > 0:
			velocity.y = WALL_SLIDE_SPEED
			is_wall_sliding = true

	# Add the gravity if not wall sliding
	if not is_on_floor() and not is_wall_sliding:
		velocity.y += gravity * delta

	# Handle jump input and buffering
	if Input.is_action_just_pressed("jump") and not crouch_rc1.is_colliding() and not crouch_rc2.is_colliding():
		jump_buffer_timer = JUMP_BUFFER_TIME
		
	# Handle jump.
	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0  # Reset coyote timer after jumping
			jump_buffer_timer = 0  # Reset jump buffer timer after jumping
			can_dash = true  # Reset dash after jumping
		elif can_wall_jump and is_wall_sliding:
			is_wall_jumping = true
			if animated_sprite.flip_h:  # Facing left wall
				velocity = Vector2(WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y)
				animated_sprite.flip_h = false
			else:  # Facing right wall
				velocity = Vector2(-WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y)
				animated_sprite.flip_h = true
			jump_buffer_timer = 0  # Reset jump buffer timer after wall jumping
			has_double_jumped = false  # Reset double jump after wall jump
			can_dash = true  # Reset dash after wall jumping
		elif can_double_jump and not has_double_jumped:
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true  # Set double jump to true after using it
			jump_buffer_timer = 0  # Reset jump buffer timer after double jumping
			can_dash = true  # Reset dash after double jumping
	
	# Implement variable jump height and snappy fall
	if velocity.y < 0:  # Player is going upwards
		if Input.is_action_pressed("jump"):
			velocity.y += gravity * (VARIABLE_JUMP_MULTIPLIER - 1) * delta
		else:
			velocity.y += gravity * (LOW_JUMP_MULTIPLIER - 1) * delta
	elif velocity.y > 0:  # Player is falling
		velocity.y += gravity * (FALL_MULTIPLIER - 1) * delta
	
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Apply movement
	speed = BASE_SPEED
	if is_crouching:
		speed *= 0.5

	if not is_wall_jumping and not is_dashing:
		if direction:
			velocity.x = move_toward(velocity.x, direction * speed, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
	
	move_and_slide()

	# Handle landing detection
	if was_on_floor_prev != is_on_floor() and is_on_floor():
		is_landing = true
		landing_timer = LAND_TIME

	# Play animations
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
