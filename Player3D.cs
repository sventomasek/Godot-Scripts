using System;
using System.Runtime.CompilerServices;
using Godot;
using Godot.Collections;

public partial class Player : CharacterBody3D
{
	private float moveSpeed = 0;
	[Export] private float walkSpeed = 3;
	[Export] private float runSpeed = 5;
	[Export] private float crouchSpeed = 1.5f;

	private Vector2 moveInput = Vector2.Zero;
	private Vector2 gamepadInput = Vector2.Zero;
	private Vector3 moveDir = Vector3.Zero;
	private bool moving = false;

	private bool running = false;
	public enum RunMode {Hold, Press, Toggle};
	[Export] public RunMode runMode = RunMode.Press;

	private bool crouching = false;
	[Export] public bool toggleCrouch = true;
	[Export] private float crouchLerp = 7.0f;

	[Export] private float groundAccel = 0.1f;
	[Export] private float airAccel = 0.025f;

	[Export] private float jumpForce = 6f;
	[Export] private float gravity = 30.0f;

	[ExportCategory("Camera")]
	[Export] public float mouseSensX = 0.15f;
	[Export] public float mouseSensY = 0.15f;
	[Export] public float gamepadSensX = 0.15f;
	[Export] public float gamepadSensY = 0.15f;
	[Export] public float gamepadAccelSpeed = 0.1f;
	[Export] public float gamepadAccelAmount = 2.0f;
	private float currentAccel = 0.0f;
	[Export] public float moveDeadZone = 0.1f;
	[Export] public float lookDeadZone = 0.1f;

	[ExportCategory("Head Bob")]
	private Vector3 bobOffset = Vector3.Zero;
	[Export] public float bobAmount = 0.03f;
	[Export] public float bobSpeed = 5.0f;
	private float bobTime = 0.0f;

	[ExportCategory("Footsteps")]
	[Export] bool doFootsteps = true;
	[Export] private Array<AudioStream> grassSteps { get; set; }
	[Export] private Array<AudioStream> dirtSteps { get; set; }
	[Export] private Array<AudioStream> stoneSteps { get; set; }
	[Export] private Array<AudioStream> woodSteps { get; set; }
	[Export] private Array<AudioStream> woodCreaks { get; set; }
	private AudioStreamPlayer footstepPlayer;
	private Timer footstepTimer;

	[Export] private float walkStepDelay = 0.6f;
	[Export] private float walkVolume = -3.0f;
	[Export] private float walkPitch = 1.0f;

	[Export] private float runStepDelay = 0.35f;
	[Export] private float runVolume = 0.0f;
	[Export] private float runPitch = 1.0f;

	[Export] private float crouchStepDelay = 0.8f;
	[Export] private float crouchVolume = -15.0f;
	[Export] private float crouchPitch = 0.75f;

	[Export] private float woodCreakChance = 0.05f;
	[Export] private int woodCreakDelay = 15; // Minimum steps required before triggering again
	private int woodCreakDelay_ = 15;

	private bool lastOnFloor = false;
	private bool firstStep = true;

	[ExportCategory("Holding Objects")]
	private RigidBody3D heldObject;
	[Export] private float throwForce = 7.5f;
	[Export] private float followSpeed = 5.0f;
	[Export] private float followDistance = 2.5f;
	[Export] private float maxDistanceFromCam = 5.0f;
	[Export] private bool dropBelowPlayer = true;

	[ExportCategory("References")]
	private Camera3D camera;
	private Node3D camPoint;
	private CollisionShape3D collision;
	private CapsuleShape3D collisionShape;
	private RayCast3D interactRay;
	private RayCast3D crouchCheck;
	private RayCast3D floorCheck;

	public override void _Ready()
	{
		// References
		footstepPlayer = GetNode<AudioStreamPlayer>("FootstepAudio");
		footstepTimer = GetNode<Timer>("FootstepTimer");
		camera = GetTree().GetFirstNodeInGroup("MainCamera") as Camera3D;
		camPoint = GetNode<Node3D>("Head/CamPoint");
		collision = GetNode<CollisionShape3D>("CollisionShape3D");
		collisionShape = (CapsuleShape3D)collision.Shape;
		interactRay = GetNode<RayCast3D>("Head/CamPoint/InteractRay");
		crouchCheck = GetNode<RayCast3D>("CrouchCheck");
		floorCheck = GetNode<RayCast3D>("FloorCheck");

		// Other
		Input.MouseMode = Input.MouseModeEnum.Captured;
		interactRay.AddException(this);
		crouchCheck.AddException(this);
		floorCheck.AddException(this);
	}

	public override void _Process(double delta)
	{
		HeadBob();

		// Camera pivot
		camera.GlobalPosition = camPoint.GlobalPosition;
		camera.GlobalRotation = camPoint.GlobalRotation;

		// Running
		switch (runMode)
		{
			case RunMode.Hold:
				if (Input.IsActionPressed("run") && moveDir != Vector3.Zero) running = true;
				else running = false;
				break;
			case RunMode.Press:
				if (Input.IsActionJustPressed("run") && moveDir != Vector3.Zero) running = true;
				else if (moveDir == Vector3.Zero) running = false;
				break;
			case RunMode.Toggle:
				if (Input.IsActionJustPressed("run")) running = !running;
				break;
		}

		// Move speed and footstep delay
		if (crouching)
		{
			moveSpeed = crouchSpeed;
			footstepTimer.WaitTime = crouchStepDelay;
		}
		else if (running)
		{
			moveSpeed = runSpeed;
			footstepTimer.WaitTime = runStepDelay;
		}
		else
		{
			moveSpeed = walkSpeed;
			footstepTimer.WaitTime = walkStepDelay;
		}

		// Jumping
		if (Input.IsActionJustPressed("jump") && IsOnFloor()) Velocity = new Vector3(Velocity.X, jumpForce, Velocity.Z);

		// Crouching
		if (Input.IsActionJustPressed("run") && crouching) crouching = false;
		if (crouching) running = false;

		if (toggleCrouch)
		{
			if (Input.IsActionJustPressed("crouch")) crouching = !crouching;
		}
		else
		{
			if (Input.IsActionPressed("crouching")) crouching = true;
			else crouching = false;
		}

		if (crouching) collisionShape.Height = Mathf.Lerp(collisionShape.Height, 1.0f, crouchLerp * (float)delta);
		else collisionShape.Height = Mathf.Lerp(collisionShape.Height, 2.0f, crouchLerp * (float)delta);

		// Gamepad camera movement
		gamepadInput = Input.GetVector("look_left", "look_right", "look_up", "look_down");

		if (Mathf.Abs(gamepadInput.X) > lookDeadZone) CameraRotateY(gamepadInput.X * gamepadSensX * 1000f * currentAccel * (float)delta);
		if (Mathf.Abs(gamepadInput.Y) > lookDeadZone) CameraRotateX(gamepadInput.Y * gamepadSensY * 1000f * currentAccel * (float)delta);

		// Acceleration
		if (Mathf.Abs(gamepadInput.X) > lookDeadZone || Mathf.Abs(gamepadInput.Y) > lookDeadZone) currentAccel = Mathf.Lerp(currentAccel, gamepadAccelAmount, gamepadAccelSpeed);
		else currentAccel = 0f;
	}

    public override void _PhysicsProcess(double delta)
    {
		// Holding physics objects
		HandleHoldingObjects();

		// Footsteps
		float totalVelocity = Mathf.Abs(Velocity.X) + Mathf.Abs(Velocity.Y) + Mathf.Abs(Velocity.Z);
		if (floorCheck.IsColliding() && moving && (totalVelocity > 0f)) footstepTimer.Paused = false;
		else footstepTimer.Paused = true;

		if (lastOnFloor != IsOnFloor())
		{
			if (IsOnFloor()) OnFootstepTimerTimeout();
			lastOnFloor = IsOnFloor();
		}

		// Gravity
		if (!IsOnFloor()) Velocity = new Vector3(Velocity.X, Velocity.Y - gravity * 0.01f, Velocity.Z);

		// Movement
		moveInput = Input.GetVector("move_left", "move_right", "move_forward", "move_backward");
		Transform3D transform = GlobalTransform;

		if (Mathf.Abs(moveInput.X) > moveDeadZone || Mathf.Abs(moveInput.Y) > moveDeadZone) moveDir = (transform.Basis * new Vector3(moveInput.X, 0f, moveInput.Y)).Normalized();
		else moveDir = Vector3.Zero;

		moving = Mathf.Abs(moveDir.X) > 0.01f || Mathf.Abs(moveDir.Y) > 0.01f;

		float moveAccel;
		if (IsOnFloor()) moveAccel = groundAccel;
		else moveAccel = airAccel;

		Velocity = new Vector3(Mathf.Lerp(Velocity.X, moveDir.X * moveSpeed, moveAccel), Velocity.Y, Mathf.Lerp(Velocity.Z, moveDir.Z * moveSpeed, moveAccel));

		MoveAndSlide();

		// Move RigidBodies
		int colCount = GetSlideCollisionCount();
		for (int i = 0; i < colCount; i++)
		{
			KinematicCollision3D col = GetSlideCollision(i);
			RigidBody3D collider = col.GetCollider() as RigidBody3D;

			if (collider is RigidBody3D)
			{
				float moveForce = 5.0f;
				collider.ApplyCentralImpulse(-col.GetNormal() * 0.3f * moveForce);
				collider.ApplyImpulse(-col.GetNormal() * 0.01f * moveForce, col.GetPosition());
			}
		}
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is InputEventMouseMotion && Input.MouseMode == Input.MouseModeEnum.Captured)
		{
			InputEventMouseMotion motion = (InputEventMouseMotion)@event;
			CameraRotateX(motion.Relative.Y * mouseSensY);
			CameraRotateY(motion.Relative.X * mouseSensX);
		}
    }

    private void CameraRotateX(float input)
	{
		camPoint.RotateX(-input * 0.01f);
		camPoint.Rotation = new Vector3(Mathf.Clamp(camPoint.Rotation.X, Mathf.DegToRad(-88), Mathf.DegToRad(88)), camPoint.Rotation.Y, camPoint.Rotation.Z);
	}

	private void CameraRotateY(float input)
	{
		RotateY(-input * 0.01f);
	}

    private void HeadBob()
	{
		float multiplier = 1f;
		if (crouching) multiplier = 0.7f;
		else if (running) multiplier = 1.5f;

		Vector3 moveVelocity = new Vector3(Velocity.X, 0f, Velocity.Z);
		if (Mathf.Abs(moveVelocity.Length()) <= 0.5f) return;

		bobTime += (float)GetProcessDeltaTime() * bobSpeed * multiplier;
		bobOffset.Y = Mathf.Sin(bobTime * 2.0f) * bobAmount * multiplier;
		bobOffset.X = Mathf.Sin(bobTime) * bobAmount * multiplier;

		camPoint.Position = bobOffset;
	}

	private void OnFootstepTimerTimeout()
	{
		if (!doFootsteps) return;

		// Ignore the first footstep because it will be played when the scene starts
		if (firstStep)
		{
			firstStep = false;
			return;
		}

		// Check ground material
		var random = new RandomNumberGenerator();
		if (floorCheck.IsColliding())
		{
			Node myFloor = floorCheck.GetCollider() as Node;
			if (myFloor.IsInGroup("Grass")) footstepPlayer.Stream = grassSteps.PickRandom();
			else if (myFloor.IsInGroup("Dirt")) footstepPlayer.Stream = dirtSteps.PickRandom();
			else if (myFloor.IsInGroup("Stone")) footstepPlayer.Stream = stoneSteps.PickRandom();
			else if (myFloor.IsInGroup("Wood"))
   			{
				footstepPlayer.Stream = woodSteps.PickRandom();
				if (woodCreakDelay_ <= 0 && random.RandfRange(0f, 1f) < woodCreakChance)
				{
					footstepPlayer.Stream = woodCreaks.PickRandom();
					woodCreakDelay_ = woodCreakDelay;
				}
				woodCreakDelay_ -= 1;
    			}
		}

		// Set volume & pitch
		if (crouching)
		{
			footstepPlayer.VolumeDb = crouchVolume;
			footstepPlayer.PitchScale = random.RandfRange(crouchPitch - 0.1f, crouchPitch + 0.1f);
		}
		else if (running)
		{
			footstepPlayer.VolumeDb = runVolume;
			footstepPlayer.PitchScale = random.RandfRange(runPitch - 0.1f, runPitch + 0.1f);
		}
		else
		{
			footstepPlayer.VolumeDb = walkVolume;
			footstepPlayer.PitchScale = random.RandfRange(walkPitch - 0.1f, walkPitch + 0.1f);
		}

		footstepPlayer.Play();
	}

	private void HandleHoldingObjects()
	{
		if (heldObject == null)
		{
			// Grabbing objects
			if (Input.IsActionJustPressed("primary") || Input.IsActionJustPressed("interact"))
			{
				if (interactRay.IsColliding())
				{
					RigidBody3D col = interactRay.GetCollider() as RigidBody3D;
					if (col != null && col.IsInGroup("Holdable")) SetHeldObject(col);
				}
			}
		}
		else
		{
			// Throwing and dropping objects
			if (Input.IsActionJustPressed("primary") && heldObject != null) ThrowHeldObject();
			if (Input.IsActionJustPressed("interact") && heldObject != null) DropHeldObject();
		}

		// Object following player
		if (heldObject != null)
		{
			Vector3 targetPos = camera.GlobalTransform.Origin + (camera.GlobalBasis * new Vector3(0f, 0f, -followDistance)); // 2.5 units in front of camera
			Vector3 objectPos = heldObject.GlobalTransform.Origin; // Held object position
			heldObject.LinearVelocity = (targetPos - objectPos) * followSpeed; // Our desired position

			// Drop if it's too far away from the camera
			if (heldObject.GlobalPosition.DistanceTo(camera.GlobalPosition) > maxDistanceFromCam) DropHeldObject();

			// Drop if the player is standing on top of the object
			if (dropBelowPlayer && floorCheck.IsColliding() && floorCheck.GetCollider() == heldObject) DropHeldObject();
		}
	}

	private void SetHeldObject(RigidBody3D body)
	{
		heldObject = body;
	}

	private void DropHeldObject()
	{
		heldObject = null;
	}

	private void ThrowHeldObject()
	{
		RigidBody3D body = heldObject;
		DropHeldObject();
		body.ApplyCentralImpulse(-camera.GlobalBasis.Z * throwForce * 10f);
	}
}
