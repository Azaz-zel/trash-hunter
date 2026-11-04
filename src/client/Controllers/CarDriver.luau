--!strict
-- Drives your own car. The car is Roblox's vehicle kit chassis; its bundled
-- Driver script (and VehicleSeat.ThrottleFloat) depend on the default
-- PlayerModule, which this place does not ship. So this controller reads input
-- itself (WASD / arrows, gamepad stick and triggers, on-screen pedals on touch)
-- and feeds the kit's Chassis module directly. Also shows a speedometer and an
-- Exit button while driving.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)

local C = Ui.COLORS
local player = Players.LocalPlayer

local CarDriver = {}

local driving: RBXScriptConnection? = nil
local gui: ScreenGui
local hud: Frame
local speedLabel: TextLabel
local touchPad: Frame
-- Held on-screen pedals (touch): -1..1 each.
local touchThrottle, touchSteer = 0, 0

local STUDS_TO_MPH = 0.6 -- 1 stud ≈ 0.28 m; rounded for a readable dial

local function keyAxis(pos: { Enum.KeyCode }, neg: { Enum.KeyCode }): number
	local v = 0
	for _, k in pos do
		if UserInputService:IsKeyDown(k) then
			v += 1
			break
		end
	end
	for _, k in neg do
		if UserInputService:IsKeyDown(k) then
			v -= 1
			break
		end
	end
	return v
end

local function readInput(): (number, number)
	local throttle = keyAxis(
		{ Enum.KeyCode.W, Enum.KeyCode.Up },
		{ Enum.KeyCode.S, Enum.KeyCode.Down }
	)
	local steer = keyAxis(
		{ Enum.KeyCode.D, Enum.KeyCode.Right },
		{ Enum.KeyCode.A, Enum.KeyCode.Left }
	)
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(state.Position.X) > 0.15 then
			steer = state.Position.X
		elseif state.KeyCode == Enum.KeyCode.ButtonR2 and state.Position.Z > 0.1 then
			throttle = state.Position.Z
		elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.1 then
			throttle = -state.Position.Z
		end
	end
	if touchThrottle ~= 0 then
		throttle = touchThrottle
	end
	if touchSteer ~= 0 then
		steer = touchSteer
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

local function stop()
	if driving then
		driving:Disconnect()
		driving = nil
	end
	touchThrottle, touchSteer = 0, 0
	hud.Visible = false
end

local function drive(seat: VehicleSeat)
	stop()
	local model = seat:FindFirstAncestorWhichIsA("Model")
	while model and model.Parent and model.Parent.Name ~= "PlayerCars" do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	if not model or model:GetAttribute("Owner") ~= player.UserId then
		return
	end
	local scripts = model:FindFirstChild("Scripts")
	local chassisModule = scripts and scripts:FindFirstChild("Chassis")
	if not chassisModule or not chassisModule:IsA("ModuleScript") then
		return
	end
	local ok, Chassis = pcall(require, chassisModule)
	if not ok then
		warn("[CarDriver] chassis failed to load: " .. tostring(Chassis))
		return
	end
	Chassis.InitializeDrivingValues()
	hud.Visible = true
	touchPad.Visible = UserInputService.TouchEnabled
	driving = RunService.Heartbeat:Connect(function()
		if not seat.Parent then
			stop()
			return
		end
		local throttle, steer = readInput()
		local velocity = Chassis.GetAverageVelocity()
		Chassis.UpdateSteering(steer, velocity)
		Chassis.UpdateThrottle(velocity, throttle)
		if throttle == 0 and math.abs(velocity) < 2 then
			Chassis.EnableHandbrake()
		end
		speedLabel.Text = tostring(math.floor(seat.AssemblyLinearVelocity.Magnitude * STUDS_TO_MPH))
	end)
end

local function exitCar()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

-- Hold-to-press pedal for touch screens.
local function pedal(text: string, pos: UDim2, onHold: (boolean) -> ())
	local b: TextButton = Ui.new("TextButton", {
		Text = text,
		Font = Ui.FONT,
		TextSize = 22,
		TextColor3 = C.cream,
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Position = pos,
		Size = UDim2.fromOffset(78, 78),
		Parent = touchPad,
	}, { Ui.corner(39), Ui.stroke() })
	b.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			b.BackgroundTransparency = 0
			onHold(true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			b.BackgroundTransparency = 0.25
			onHold(false)
		end
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Driving",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	hud = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	-- Speedometer, bottom centre.
	local dial = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(150, 74),
		Parent = hud,
	})
	speedLabel = Ui.label("0", 38, {
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 6),
		Parent = dial,
	})
	Ui.label("MPH", 13, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = C.muted,
		Parent = dial,
	})
	local hint = Ui.label("W/S drive · A/D steer · Space exit", 13, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -98),
		Size = UDim2.fromOffset(320, 16),
		TextColor3 = C.cream,
		TextStrokeTransparency = 0.5,
		Parent = hud,
	})
	hint.Visible = not UserInputService.TouchEnabled
	local exit = Ui.button("Exit car", "secondary", UDim2.fromOffset(110, 52), exitCar)
	exit.AnchorPoint = Vector2.new(0, 1)
	exit.Position = UDim2.new(0, 16, 1, -18)
	exit.Parent = hud

	-- Touch pedals: steering on the left, gas and brake on the right.
	touchPad = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = hud,
	})
	local steerHeld = { left = false, right = false }
	local function updateSteer()
		touchSteer = (if steerHeld.right then 1 else 0) - (if steerHeld.left then 1 else 0)
	end
	pedal("◀", UDim2.new(0, 24, 1, -178), function(on)
		steerHeld.left = on
		updateSteer()
	end)
	pedal("▶", UDim2.new(0, 112, 1, -178), function(on)
		steerHeld.right = on
		updateSteer()
	end)
	pedal("GAS", UDim2.new(1, -102, 1, -198), function(on)
		touchThrottle = if on then 1 elseif touchThrottle > 0 then 0 else touchThrottle
	end)
	pedal("REV", UDim2.new(1, -190, 1, -110), function(on)
		touchThrottle = if on then -1 elseif touchThrottle < 0 then 0 else touchThrottle
	end)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") then
			drive(seatPart)
		else
			stop()
		end
	end)
end

function CarDriver.init()
	build()
	Ui.autoScale(gui)
end

function CarDriver.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return CarDriver
