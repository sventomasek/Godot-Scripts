extends CharacterBody3D

@export_group("Movement")
@export var moveSpeed = 5.0
@export var acceleration = 7.5
var moveDir: Vector3

@export var jumpForce = 4.5
@export var gravity = 9.8

@export_group("Camera")
@export var mouseSens = Vector2(0.2, 0.2)
@onready var camera = $Camera3D

@export_group("Holding Objects")
@export var throwForce = 7.5
@export var followSpeed = 5.0
@export var rotateSpeed = 10.0 # Set this to 0 if you don't want the object to face the camera
@export var followDistance = 2.5
@export var maxDistanceFromCamera = 5.0
@export var dropBelowPlayer = false
@export var groundRay: RayCast3D # Only needed if dropBelowPlayer is true

@onready var interactRay = $Camera3D/InteractRay
var heldObject: RigidBody3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _process(_delta):
	# Move Input
	var inputDir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	moveDir = (transform.basis * Vector3(inputDir.x, 0, inputDir.y)).normalized()
	
	# Jumping
	if Input.is_action_just_pressed("jump") && is_on_floor(): velocity.y = jumpForce
	
func _physics_process(delta):
	# Holding Physics Objects
	handle_holding_objects()
	
	# Gravity
	if !is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") && is_on_floor(): velocity.y = jumpForce
	
	# Movement
	velocity.x = lerp(velocity.x, moveDir.x * moveSpeed, acceleration * delta)
	velocity.z = lerp(velocity.z, moveDir.z * moveSpeed, acceleration * delta)
	
	move_and_slide()
	
func _unhandled_input(event):
	# Camera Rotation
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouseSens.x * 0.01)
		camera.rotate_x(-event.relative.y * mouseSens.y * 0.01)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
func set_held_object(body):
	if body is RigidBody3D:
		heldObject = body
	
func drop_held_object():
	heldObject = null
	
func throw_held_object():
	var obj = heldObject
	drop_held_object()
	obj.apply_central_impulse(-camera.global_basis.z * throwForce * 10)
	
func handle_holding_objects():
	# Throwing Objects
	if Input.is_action_just_pressed("throw"):
		if heldObject != null: throw_held_object()
		
	# Dropping and Grabbing Objects
	if Input.is_action_just_pressed("interact"):
		if heldObject != null: drop_held_object()
		elif interactRay.is_colliding() && interactRay.get_collider() is RigidBody3D: set_held_object(interactRay.get_collider())
		
	# Object Following
	if heldObject != null && is_instance_valid(heldObject):
		# Move the object in front of the camera
		var targetPos = camera.global_transform.origin + (camera.global_basis * Vector3(0, 0, -followDistance)) # 2.5 units in front of camera
		var objectPos = heldObject.global_transform.origin # Held object position
		heldObject.linear_velocity = (targetPos - objectPos) * followSpeed # Our desired position

		# Align the object rotation to the camera rotation
		if rotateSpeed != 0.0:
			var targetRot = camera.global_basis.get_rotation_quaternion()
			var objectRot = heldObject.global_basis.get_rotation_quaternion()
			var finalRot = targetRot * objectRot.inverse()
			
			var axis = finalRot.get_axis()
			var angle = finalRot.get_angle()
			if angle > PI: angle -= TAU

			heldObject.angular_velocity = axis * angle * rotateSpeed
		
		# Drop the object if it's too far away from the camera
		if heldObject.global_position.distance_to(camera.global_position) > maxDistanceFromCamera:
			drop_held_object()
			
		# Drop the object if the player is standing on it (must enable dropBelowPlayer and set a groundRay/RayCast3D below the player)
		if dropBelowPlayer && groundRay.is_colliding():
			if groundRay.get_collider() == heldObject: drop_held_object()
