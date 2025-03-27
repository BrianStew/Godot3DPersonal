extends CharacterBody3D

# Player Nodes
@onready var head: Node3D = $Head
@onready var standing_collision_shape: CollisionShape3D = $Standing_Collision_Shape
@onready var crouching_collision_shape: CollisionShape3D = $Crouching_Collision_Shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D

# Speed Variables
const JUMP_VELOCITY = 4.5
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 3.0

# Movement Variables
var current_speed
var crouch_depth = -0.5
var lerp_speed = 10.0

# Input Variables
@export var mouse_sense = 0.25
var direction = Vector3.ZERO



func _ready() -> void:
	# This locks our mouse into the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Here we handle the movement of the mouse
	if event is InputEventMouseMotion:
		# We rotate about the y-axis by getting and inverting the movement of the mouse in the x dimension
		rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		# When rotating about the x-axis we just want to rotate the head, not the player
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		# To avoid infinite rotation we use the clamp function. 
		# clamp takes the value you want to clamp, then a min and max and it returns
		# a value clamped within that range
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

func _physics_process(delta: float) -> void:
	# Handle Crouching and Sprinting
	if Input.is_action_pressed("crouch"):
		current_speed = CROUCH_SPEED
		head.position.y = lerp(head.position.y, 1.7 + crouch_depth, delta * lerp_speed)
		# Here we change our collision size when crouching
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !ray_cast_3d.is_colliding(): # We use the raycast to check if there's anything above the player's head before allowing them to stand
		# Set our collision size to standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		
		head.position.y = lerp(head.position.y, 1.7, delta * lerp_speed)
		if Input.is_action_pressed("sprint"):
			current_speed = SPRINT_SPEED
		else:
			current_speed = WALK_SPEED
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# We implement the lerp function to negate the snappy movement, allowing the player to come to a gradual stop and start
	# To use lerp, lerp(value we want to lerp, the value we want to lerp it to, the speed of the lerp)
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
