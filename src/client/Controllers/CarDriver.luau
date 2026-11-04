--!strict
-- Drives your own car. The car is Roblox's vehicle kit chassis; its bundled
-- Driver script (and VehicleSeat.ThrottleFloat) depend on the default
-- PlayerModule, which this place does not ship. So this controller reads input
-- itself (WASD / arrows, gamepad stick and triggers, on-screen pedals on touch)
-- and feeds the kit's Chassis module directly. Also shows a speedometer and an
-- Exit button while driving, and runs the car radio (R or the radio button
-- cycles Config.Radio stations; it stays hidden while no station has tracks).
--
-- Handling on top of the kit: each car has its own top speed and pull
-- (Config.Cars top / accel), Nitro (Shift or NOS) burns a recharging tank,
-- the camera widens with speed, a car on its roof turns itself back over,
-- and H / the horn button honks (people ahead jump out of the way).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Config =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local CarDriver = {}

local driving: RBXScriptConnection? = nil
local gui: ScreenGui
local hud: Frame
local speedLabel: TextLabel
local carLabel: TextLabel
local nitroFill: Frame
local speedArc: Frame
local nitroHeld = false
local nitroTank = 1 -- 0..1
local BASE_FOV = 70
local touchPad: Frame
-- Held on-screen pedals (touch): -1..1 each.
local touchThrottle, touchSteer = 0, 0

local STUDS_TO_MPH = 0.6 -- 1 stud ≈ 0.28 m; rounded for a readable dial
local CAR = Config.CAR

-- ─── radio ────────────────────────────────────────────────────────────────

local stations = {}
for _, st in Config.Radio do
	if #st.tracks > 0 then
		table.insert(stations, st)
	end
end
local station = if #stations > 0 then 1 else 0 -- 0 = off; kept between rides
local radioSound: Sound
local radioLabel: TextLabel
local radioButton: TextButton
local trackIndex = 0

local function playTrack()
	local st = stations[station]
	if not st then
		radioSound:Stop()
		return
	end
	trackIndex = trackIndex % #st.tracks + 1
	radioSound.SoundId = st.tracks[trackIndex]
	radioSound:Play()
end

local function radioOn(on: boolean)
	if #stations == 0 then
		return
	end
	if on and station > 0 then
		trackIndex = math.random(0, #stations[station].tracks - 1)
		playTrack()
	else
		radioSound:Stop()
	end
	local st = stations[station]
	radioLabel.Text = if st then `📻 {st.name}` else "📻 Radio off"
end

local function nextStation()
	if #stations == 0 then
		return
	end
	station = (station + 1) % (#stations + 1)
	radioOn(true)
end

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
	nitroHeld = false
	Ui.tween(workspace.CurrentCamera, 0.4, { FieldOfView = BASE_FOV })
	touchThrottle, touchSteer = 0, 0
	hud.Visible = false
	radioOn(false)
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
	radioOn(true)
	local spec = Config.Cars[1]
	for _, c in Config.Cars do
		if c.id == model:GetAttribute("CarId") then
			spec = c
		end
	end
	carLabel.Text = string.upper(spec.name)
	local camera = workspace.CurrentCamera
	local upsideDown = 0
	driving = RunService.Heartbeat:Connect(function(dt)
		if not seat.Parent then
			stop()
			return
		end
		local throttle, steer = readInput()
		local velocity = Chassis.GetAverageVelocity()
		local v = seat.AssemblyLinearVelocity
		local flatVel = Vector3.new(v.X, 0, v.Z)
		local speed = flatVel.Magnitude
		local look = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.zero
		local forward = flatVel:Dot(look) -- signed speed along the nose
		-- Top speed: off the gas at this car's limit.
		if throttle > 0 and forward >= spec.top then
			throttle = 0
		end
		-- The kit chassis steers opposite to SteerFloat's sign (D = +1 turned left).
		Chassis.UpdateSteering(-steer, velocity)
		Chassis.UpdateThrottle(velocity, throttle)
		if throttle == 0 and math.abs(velocity) < 2 then
			Chassis.EnableHandbrake()
		end
		local grounded = seat.CFrame.UpVector.Y > 0.6
		-- Extra pull per car, and nitro.
		local push = 0
		if throttle > 0 and grounded and forward < spec.top then
			push += spec.accel * throttle
		end
		local burning = nitroHeld and nitroTank > 0 and grounded and throttle >= 0
		if burning then
			nitroTank = math.max(0, nitroTank - dt / spec.nitro)
			if forward < spec.top * CAR.NITRO_OVER then
				push += CAR.NITRO_PUSH
			end
		else
			nitroTank = math.min(1, nitroTank + dt / CAR.NITRO_RECHARGE)
		end
		if push > 0 then
			seat.AssemblyLinearVelocity += look * push * dt
		end
		-- On its roof or side and stopped for a moment: back on its wheels.
		if not grounded and speed < 4 then
			upsideDown += dt
			if upsideDown > 2 then
				upsideDown = 0
				local pivot = model:GetPivot()
				local face = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
				face = if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis
				local up = pivot.Position + Vector3.new(0, 4, 0)
				model:PivotTo(CFrame.lookAt(up, up + face))
				seat.AssemblyLinearVelocity = Vector3.zero
				seat.AssemblyAngularVelocity = Vector3.zero
			end
		else
			upsideDown = 0
		end
		-- The camera widens with speed, more on nitro.
		local share = math.clamp(speed / spec.top, 0, 1.3)
		local fov = BASE_FOV + share * 14 + (if burning then 10 else 0)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 4)
		speedLabel.Text = tostring(math.floor(speed * STUDS_TO_MPH))
		speedArc.Size = UDim2.fromScale(math.clamp(speed / (spec.top * CAR.NITRO_OVER), 0, 1), 1)
		speedArc.BackgroundColor3 = if burning then Color3.fromRGB(80, 200, 255) else C.accent
		nitroFill.Size = UDim2.fromScale(nitroTank, 1)
		nitroFill.BackgroundColor3 = if nitroTank < 0.15
			then C.danger
			else Color3.fromRGB(80, 200, 255)
	end)
end

local lastHonk = 0
local function honk()
	if os.clock() - lastHonk < 0.8 then
		return
	end
	lastHonk = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and Config.Sounds.HORN ~= "" then
		local horn = Instance.new("Sound")
		horn.SoundId = Config.Sounds.HORN
		horn.Volume = 0.8
		horn.RollOffMaxDistance = 200
		horn.Parent = seat
		horn:Play()
		horn.Ended:Once(function()
			horn:Destroy()
		end)
	end
	task.spawn(Store.action, "honk")
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
	-- Dashboard, bottom centre: car name, speed, speed bar, nitro tank.
	local dial = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(210, 96),
		Parent = hud,
	})
	dial.BackgroundTransparency = 0.08
	carLabel = Ui.label("", 11, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 14),
		Font = Ui.FONT,
		TextColor3 = C.muted,
		Parent = dial,
	})
	speedLabel = Ui.label("0", 38, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, 26, 0, 18),
		Size = UDim2.fromOffset(110, 42),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = dial,
	})
	Ui.label("MPH", 13, {
		Position = UDim2.new(0.5, 32, 0, 38),
		Size = UDim2.fromOffset(40, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		Parent = dial,
	})
	local function bar(y: number, label: string): Frame
		Ui.label(label, 10, {
			Position = UDim2.fromOffset(12, y - 3),
			Size = UDim2.fromOffset(30, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.muted,
			Font = Ui.FONT,
			Parent = dial,
		})
		local track = Ui.new("Frame", {
			Position = UDim2.fromOffset(44, y),
			Size = UDim2.new(1, -56, 0, 6),
			BackgroundColor3 = C.panelLight,
			Parent = dial,
		}, { Ui.corner(3) })
		return Ui.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = C.accent,
			Parent = track,
		}, { Ui.corner(3) })
	end
	speedArc = bar(66, "SPD")
	nitroFill = bar(80, "NOS")
	local hint = Ui.label(
		`W/S drive · A/D steer · Shift nitro · H horn{if #stations > 0 then " · R radio" else ""} · Space exit`,
		13,
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -122),
			Size = UDim2.fromOffset(460, 16),
			TextColor3 = C.cream,
			TextStrokeTransparency = 0.5,
			Parent = hud,
		}
	)
	hint.Visible = not UserInputService.TouchEnabled
	-- Radio: station name above the dial, a button to switch.
	radioSound = Instance.new("Sound")
	radioSound.Name = "CarRadio"
	radioSound.Volume = 0.45
	radioSound.Parent = SoundService
	radioSound.Ended:Connect(playTrack)
	radioLabel = Ui.label("", 14, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(260, 18),
		Font = Ui.FONT,
		TextColor3 = Color3.fromRGB(120, 230, 255),
		TextStrokeTransparency = 0.4,
		Visible = #stations > 0,
		Parent = hud,
	})
	radioButton = Ui.button("📻", "secondary", UDim2.fromOffset(52, 52), nextStation)
	radioButton.AnchorPoint = Vector2.new(0, 1)
	radioButton.Position = UDim2.new(0, 134, 1, -18)
	radioButton.Visible = #stations > 0
	radioButton.Parent = hud
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
	pedal("NOS", UDim2.new(1, -190, 1, -198), function(on)
		nitroHeld = on
	end)
	pedal("HORN", UDim2.new(1, -102, 1, -286), function(on)
		if on then
			honk()
		end
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not driving then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			nextStation()
		elseif input.KeyCode == Enum.KeyCode.H then
			honk()
		elseif
			input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3
		then
			nitroHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			nitroHeld = false
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return CarDriver
