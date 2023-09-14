extends Camera2D

@onready var target = get_tree().get_nodes_in_group("Player")[0]

@export_category("Camera.gd")
@export var ignoreX = false
@export var ignoreY = false
@export var checkIfMouseInWindow = true

@export_category("Settings")
@export var speed = Vector2(0.1, 0.25)
@export var fixedOffset = Vector2(0, -15)

@export_category("Directional Offset")
@export var centerOnIdle = true
@export var idleDelay = 3
@export var dirOffset = Vector2(0, 0)
@export var dirOffsetSpeed = Vector2(0.05, 0.05)

@export_category("Mouse and Joystick Movement")
@export var mouseMoveAmount = Vector2(0.3, 0.3)
@export var joystickMoveAmount = Vector2(40, 25)
@export var joystickDead = 0.2

var usingMouse = true
var mouseInWindow = true
var mousePosition = Vector2(0, 0)
var joystickDirection = Vector2(0, 0)
var currentDirOffset = Vector2(dirOffset.x, dirOffset.y)
var facingRight = true
var facingUp = true
var idleDelayValue = 0
var isIdle = true

func _process(delta):
	# Center the Camera when Idle
	idleDelayValue -= delta
	
	if idleDelayValue < 0:
		isIdle = true
	else:
		isIdle = false
		
	if target.velocity != Vector2.ZERO: idleDelayValue = idleDelay
	
	# Check if the Mouse is inside the Game's Window
	if checkIfMouseInWindow:
		if mouseInWindow: mousePosition = get_global_mouse_position()
	else:
		mousePosition = get_global_mouse_position()
		
	# Check where the target is facing
	if target.velocity.x > 0:
		facingRight = true
	elif target.velocity.x < 0:
		facingRight = false
		
	if target.velocity.y < 0:
		facingUp = true
	elif target.velocity.y > 0:
		facingUp = false
		
	# Get Joystick Input
	var joystickDirectionX = Input.get_axis("joystick_look_left", "joystick_look_right")
	var joystickDirectionY = Input.get_axis("joystick_look_down", "joystick_look_up")
	joystickDirection = Vector2(joystickDirectionX, -joystickDirectionY)
	
	# Switch to Controller Input
	if (joystickDirection.x > joystickDead || joystickDirection.x < -joystickDead) || (joystickDirection.y > joystickDead || joystickDirection.y < -joystickDead):
		usingMouse = false

func _physics_process(delta):
	var myPosition = Vector2(0, 0)
	var targetPosition = target.position
	
	# Change direction of the Directional Offset
	if centerOnIdle && isIdle:
		currentDirOffset.x = lerp(currentDirOffset.x, Vector2.ZERO.x, dirOffsetSpeed.x)
	elif facingRight:
		currentDirOffset.x = lerp(currentDirOffset.x, dirOffset.x, dirOffsetSpeed.x)
	else:
		currentDirOffset.x = lerp(currentDirOffset.x, -dirOffset.x, dirOffsetSpeed.x)
	
	if centerOnIdle && isIdle:
		currentDirOffset.y = lerp(currentDirOffset.y, Vector2.ZERO.y, dirOffsetSpeed.y)
	elif facingUp:
		currentDirOffset.y = lerp(currentDirOffset.y, dirOffset.y, dirOffsetSpeed.y)
	else:
		currentDirOffset.y = lerp(currentDirOffset.y, -dirOffset.y, dirOffsetSpeed.y)
	
	# Set the position of the camera
	myPosition.x = lerp(targetPosition.x, mousePosition.x, mouseMoveAmount.x)
	myPosition.y = lerp(targetPosition.y, mousePosition.y, mouseMoveAmount.y)
	
	var posX = 0
	var posY = 0
	
	if usingMouse:
		# Mouse Input
		posX = lerp(position.x, myPosition.x + fixedOffset.x + currentDirOffset.x, speed.x)
		posY = lerp(position.y, myPosition.y + fixedOffset.y + currentDirOffset.y, speed.y)
	else:
		# Dead Zone
		if (joystickDirection.x < joystickDead && joystickDirection.x > -joystickDead) && (joystickDirection.y < joystickDead && joystickDirection.y > -joystickDead):
			joystickDirection = Vector2.ZERO
			
		# Controller Input
		posX = lerp(position.x, target.position.x + fixedOffset.x + currentDirOffset.x + (joystickDirection.x * joystickMoveAmount.x), speed.x)
		posY = lerp(position.y, target.position.y + fixedOffset.y + (joystickDirection.y * joystickMoveAmount.y), speed.y)
		
	# Apply the Camera's Position
	if !ignoreX: position.x = posX
	if !ignoreY: position.y = posY

func _input(event):
	# Switch to Mouse Input
	if event is InputEventMouseButton:
		usingMouse = true

func _notification(event):
	# Detect when Mouse is inside/outside the Game's Window
	match event:
		NOTIFICATION_WM_MOUSE_EXIT:
			mouseInWindow = false
		NOTIFICATION_WM_MOUSE_ENTER:
			mouseInWindow = true
