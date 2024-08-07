extends Camera2D

@export var target : Node2D

@export var ignoreX = false
@export var ignoreY = false

@export_group("Move when Target outside Camera")
@export var boundsMovement = false
@export var boundsPosition = Vector2(192, 108)
# NOTE: When using Bounds Movement, I recommend not using any additional Offsets like
# Fixed or Directional Offset because it will move the camera wrong by a few units
# Using Mouse/Joystick Movement is fine though

@export_group("Settings")
@export var speed = Vector2(0.1, 0.25)
@export var fixedOffset = Vector2(0, -15)

@export_group("Directional Offset")
@export var centerOnIdle = true
@export var idleDelay = 3
@export var dirOffset = Vector2(0, 0)
@export var dirOffsetSpeed = Vector2(0.05, 0.05)

@export_group("Mouse and Joystick Movement")
@export var checkIfMouseInWindow = true
@export var mouseMoveAmount = Vector2(0.3, 0.3)
@export var joystickMoveAmount = Vector2(40, 25)
@export var joystickDead = 0.2

# Screenshake [activate it by calling the function StartScreenshake(time, strength, speed)]
var shakeStrength = 0
var shakeSpeed = 0
var shakeTimer = 0
var shakeRecoverySpeed = 0.5
var shakeOffset = Vector2.ZERO

# The rest of the stuff
var targetPosition = Vector2.ZERO

var usingMouse = true
var mouseInWindow = true
var mousePosition = Vector2.ZERO
var joystickDirection = Vector2.ZERO
var currentDirOffset = Vector2(dirOffset.x, dirOffset.y)
var facingRight = true
var facingUp = true
var idleDelayValue = 0
var isIdle = true
var cameraBoundPosition = Vector2.ZERO

func _process(delta):
	GetPosition()
	CenterOnIdle(delta)
	MouseInWindow()
	TargetDirection()
	ControllerInput()
	Screenshake(delta)

func _physics_process(delta):
	DirectionalOffset()
	ApplyPosition()

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

func GetPosition():
	# Find the place where the Camera should be, based on Target's position
	if (!boundsMovement):
		targetPosition = target.position
	else:
		if target.position.x >= cameraBoundPosition.x + fixedOffset.x + boundsPosition.x / 2:
			cameraBoundPosition.x += boundsPosition.x + fixedOffset.x
		elif target.position.x <= cameraBoundPosition.x + fixedOffset.x - boundsPosition.x / 2:
			cameraBoundPosition.x -= boundsPosition.x + fixedOffset.x
			
		targetPosition.x = cameraBoundPosition.x
			
		if target.position.y >= cameraBoundPosition.y + fixedOffset.y + boundsPosition.y / 2:
			cameraBoundPosition.y += boundsPosition.y + fixedOffset.y
		elif target.position.y <= cameraBoundPosition.y + fixedOffset.y - boundsPosition.y / 2:
			cameraBoundPosition.y -= boundsPosition.y + fixedOffset.y
			
		targetPosition.y = cameraBoundPosition.y

func CenterOnIdle(delta):
	# Center the Camera when Idle
	idleDelayValue -= delta
	
	if idleDelayValue < 0:
		isIdle = true
	else:
		isIdle = false
		
	if target.velocity != Vector2.ZERO: idleDelayValue = idleDelay

func MouseInWindow():
	# Check if the Mouse is inside the Game's Window
	if checkIfMouseInWindow:
		if mouseInWindow: mousePosition = get_global_mouse_position()
	else:
		mousePosition = get_global_mouse_position()

func TargetDirection():
	# Check where the target is facing
	if target.velocity.x > 0:
		facingRight = true
	elif target.velocity.x < 0:
		facingRight = false
		
	if target.velocity.y < 0:
		facingUp = true
	elif target.velocity.y > 0:
		facingUp = false

func ControllerInput():
	# Get Joystick Input
	var joystickDirectionX = Input.get_axis("joystick_look_left", "joystick_look_right")
	var joystickDirectionY = Input.get_axis("joystick_look_down", "joystick_look_up")
	joystickDirection = Vector2(joystickDirectionX, -joystickDirectionY)
	
	# Switch to Controller Input
	if (joystickDirection.x > joystickDead || joystickDirection.x < -joystickDead) || (joystickDirection.y > joystickDead || joystickDirection.y < -joystickDead):
		usingMouse = false

func Screenshake(delta):
	# Screenshake
	if shakeTimer > 0:
		var random = Vector2(randf_range(-shakeStrength, shakeStrength), randf_range(-shakeStrength, shakeStrength))
		shakeOffset = lerp(shakeOffset, random, shakeSpeed)
		shakeTimer -= delta
	else:
		shakeOffset = lerp(shakeOffset, Vector2.ZERO, shakeRecoverySpeed)

	#if Input.is_key_pressed(KEY_F1): StartScreenshake(0.2, 10, 0.01)

func StartScreenshake(time: float, strength: float, speed: float):
	shakeStrength = strength
	shakeSpeed = speed
	shakeTimer = time

func DirectionalOffset():
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

func ApplyPosition():
	# Set the position of the camera
	var myPosition = Vector2(0, 0)

	myPosition.x = lerp(targetPosition.x, mousePosition.x, mouseMoveAmount.x)
	myPosition.y = lerp(targetPosition.y, mousePosition.y, mouseMoveAmount.y)

	var posX = 0
	var posY = 0

	if usingMouse:
		# Mouse Input
		posX = lerp(position.x, myPosition.x + fixedOffset.x + currentDirOffset.x + shakeOffset.x, speed.x)
		posY = lerp(position.y, myPosition.y + fixedOffset.y + currentDirOffset.y + shakeOffset.y, speed.y)
	else:
		# Dead Zone
		if (joystickDirection.x < joystickDead && joystickDirection.x > -joystickDead) && (joystickDirection.y < joystickDead && joystickDirection.y > -joystickDead):
			joystickDirection = Vector2.ZERO
			
		# Controller Input
		posX = lerp(position.x, targetPosition.x + fixedOffset.x + currentDirOffset.x + shakeOffset.x + (joystickDirection.x * joystickMoveAmount.x), speed.x)
		posY = lerp(position.y, targetPosition.y + fixedOffset.y + currentDirOffset.y + shakeOffset.y + (joystickDirection.y * joystickMoveAmount.y), speed.y)
		
	# Apply the Camera's Position
	if !ignoreX: position.x = posX
	if !ignoreY: position.y = posY
