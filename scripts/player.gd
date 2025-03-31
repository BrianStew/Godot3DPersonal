extends CharacterBody3D

# Player Nodes
@onready var head: Node3D = $Neck/Head
@onready var neck: Node3D = $Neck
@onready var eyes: Node3D = $Neck/Head/Eyes

@onready var standing_collision_shape: CollisionShape3D = $Standing_Collision_Shape
@onready var crouching_collision_shape: CollisionShape3D = $Crouching_Collision_Shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var camera_3d: Camera3D = $Neck/Head/Eyes/Camera3D


# Speed Variables
const JUMP_VELOCITY = 4.5
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 3.0

# Head Bobbing Variables
const HEAD_BOBBING_SPRINT_SPEED = 20.0 
const HEAD_BOBBING_WALK_SPEED = 11.0 
const HEAD_BOBBING_CROUCH_SPEED = 9.0 

const HEAD_BOBBING_SPRINT_INTENSITY = 0.17
const HEAD_BOBBING_WALK_INTENSITY = 0.08
const HEAD_BOBBING_CROUCH_INTENSITY = 0.04

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Movement Variables
var current_speed = 0.0
var crouch_depth = -0.5
var lerp_speed = 10.0
var free_look_tilt_amount = 7.5
var current_jumps = 0   # For Double-Jumps

# Slide Variables
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 9.0

# Player States
var walking = false
var sprinting = false
var sliding = false
var crouching = false
var freelooking = false

# Input Variables
@export var mouse_sense = 0.25
var direction = Vector3.ZERO

func _ready() -> void:
	# This locks our mouse into the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Mouse Movement
	if event is InputEventMouseMotion:
		# Handle Freelooking
		if freelooking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
			neck.rotation.y = clamp(neck.rotation.y, -2*PI/3, 2*PI/3)
		else:
			# We rotate about the y-axis by getting and inverting the movement of the mouse in the x dimension
			rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		
		# When rotating about the x-axis we just want to rotate the head, not the player
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		
		# To avoid infinite rotation we use the clamp function. 
		# clamp takes the value you want to clamp, then a min and max and it returns a clamped value in that range
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

func _physics_process(delta: float) -> void:
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		# If player is on the ground, set their jump counter to 0
		current_jumps = 0

	# Handle Crouching, Sprinting and Sliding
	if Input.is_action_pressed("crouch") || sliding:
		
		# If crouching in the air, maintain current velocity
		current_speed = CROUCH_SPEED
			
		head.position.y = lerp(head.position.y, crouch_depth, delta * lerp_speed)
		
		# Here we change our collision size when crouching
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		# Handle Sliding Begin
		if sprinting && input_dir != Vector2.ZERO && is_on_floor():
			sliding = true
			freelooking = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
		
		walking = false
		sprinting = false
		crouching = true
	
	elif !ray_cast_3d.is_colliding(): # We use the raycast to check if there's anything above the player's head before allowing them to stand
		
		# Set our collision size to standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_pressed("sprint"):
			# Sprinting
			current_speed = SPRINT_SPEED
			
			walking = false
			sprinting = true
		else:
			# Walking
			current_speed = WALK_SPEED
			
			walking = true
			sprinting = false
		
		crouching = false
		
	# Handle jump.
	if Input.is_action_just_pressed("jump") && current_jumps < 2:
		velocity.y = JUMP_VELOCITY
		current_jumps += 1
		
		# Slide Cancel
		sliding = false
		
	# Handle FreeLooking
	if Input.is_action_pressed("free_look") || sliding:
		freelooking = true
		
		# Add tilt when freelooking
		if sliding:
			camera_3d.rotation.z = lerp(camera_3d.rotation.z, -deg_to_rad(7.0), delta*lerp_speed)
		else:
			camera_3d.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt_amount)
	else:
		freelooking = false
		# Reset the rotation of neck to look forward and camera to look straight
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed)
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, 0.0, delta* lerp_speed)
	
	# Handle Slide Timer
	if sliding:
		slide_timer -= delta
		# Slide End
		if slide_timer <= 0:
			freelooking = false
			sliding = false
	
	# Head Bobbing
	if sprinting:
		head_bobbing_current_intensity = HEAD_BOBBING_SPRINT_INTENSITY
		head_bobbing_index += HEAD_BOBBING_SPRINT_SPEED*delta
	elif walking:
		head_bobbing_current_intensity = HEAD_BOBBING_WALK_INTENSITY
		head_bobbing_index += HEAD_BOBBING_WALK_SPEED*delta
	elif crouching:
		head_bobbing_current_intensity = HEAD_BOBBING_CROUCH_INTENSITY
		head_bobbing_index += HEAD_BOBBING_CROUCH_SPEED*delta
	
	# We only want to headbob on floor when moving
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		# For every side to side, we go up and down twice
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y*(head_bobbing_current_intensity/2), lerp_speed*delta)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x*(head_bobbing_current_intensity), lerp_speed*delta)
	else:
		# Reset eyes if not head bobbing
		eyes.position.y = lerp(eyes.position.y, 0.0, lerp_speed*delta)
		eyes.position.x = lerp(eyes.position.x, 0.0, lerp_speed*delta)
	
	# We implement the lerp function to negate the snappy movement, allowing the player to come to a gradual stop and start
	# To use lerp, lerp(value we want to lerp, the value we want to lerp it to, the speed of the lerp)
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	
	# Overwrite our direction if sliding to keep player from changing directions
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
			
		# Set Velocity if Sliding
		if sliding:
			velocity.x = direction.x * (slide_timer + 0.3) * slide_speed
			velocity.z = direction.z * (slide_timer + 0.3) * slide_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
