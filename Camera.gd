extends Camera2D

@onready var target = get_tree().get_nodes_in_group("Player")[0]

@export var ignoreX = false
@export var ignoreY = false
@export var checkIfMouseInWindow = true

@export var directionalOffset = Vector2(0, 0)
@export var fixedOffset = Vector2(0, -15)
@export var smoothness = Vector2(0.1, 0.25)

@export var mouseMoveAmount = Vector2(0.3, 0.3)
@export var joystickMoveAmount = Vector2(40, 25)
@export var joystickDead = 0.2

var usingMouse = true
var mouseInWindow = true
var mousePosition = Vector2(0, 0)
var joystickDirection = Vector2(0, 0)
var currentDirOffset = Vector2(directionalOffset.x, 0)
var velocity = Vector2(0, 0)

func _physics_process(delta):
	var myPosition = Vector2(0, 0)
	var targetPosition = target.position
	
	# Check if the Mouse is inside the Game's Window
	if checkIfMouseInWindow:
		if mouseInWindow: mousePosition = get_global_mouse_position()
	else:
		mousePosition = get_global_mouse_position()
	
	# Change direction of the Directional Offset
	if target.velocity.x > 0:
		currentDirOffset.x = directionalOffset.x
	else: if target.velocity.x < 0:
		currentDirOffset.x = -directionalOffset.x
	
	# Set the position of the camera
	myPosition.x = lerp(targetPosition.x, fixedOffset.x + mousePosition.x, mouseMoveAmount.x)
	myPosition.y = lerp(targetPosition.y, fixedOffset.y + mousePosition.y, mouseMoveAmount.y)
	
	var posX = 0
	var posY = 0
	
	if usingMouse:
		# Mouse Input
		posX = lerp(position.x, myPosition.x + currentDirOffset.x, smoothness.x)
		posY = lerp(position.y, myPosition.y, smoothness.y)
	else:
		# Dead Zone
		if (joystickDirection.x < joystickDead && joystickDirection.x > -joystickDead) && (joystickDirection.y < joystickDead && joystickDirection.y > -joystickDead):
			joystickDirection = Vector2.ZERO
			
		# Controller Input
		posX = lerp(position.x, target.position.x + fixedOffset.x + currentDirOffset.x + (joystickDirection.x * joystickMoveAmount.x), smoothness.x)
		posY = lerp(position.y, target.position.y + fixedOffset.y + (joystickDirection.y * joystickMoveAmount.y), smoothness.y)
		
	# Get Joystick Input
	var joystickDirectionX = Input.get_axis("joystick_look_left", "joystick_look_right")
	var joystickDirectionY = Input.get_axis("joystick_look_down", "joystick_look_up")
	joystickDirection = Vector2(joystickDirectionX, -joystickDirectionY)
	
	# Switch to Controller Input
	if (joystickDirection.x > joystickDead || joystickDirection.x < -joystickDead) || (joystickDirection.y > joystickDead || joystickDirection.y < -joystickDead):
		usingMouse = false
		
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
