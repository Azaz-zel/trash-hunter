--!strict
-- Drives your own car. The car is Roblox's vehicle kit chassis; its bundled
-- Driver script waits for a legacy PlayerModule that no longer exists, so this
-- controller feeds the kit's Chassis module directly from VehicleSeat input
-- (ThrottleFloat / SteerFloat work for keyboard, gamepad and the mobile stick).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CarDriver = {}

local driving: RBXScriptConnection? = nil

local function stop()
	if driving then
		driving:Disconnect()
		driving = nil
	end
end

local function drive(seat: VehicleSeat)
	stop()
	local model = seat:FindFirstAncestorWhichIsA("Model")
	while model and model.Parent and model.Parent.Name ~= "PlayerCars" do
		model = model.Parent:FindFirstAncestorWhichIsA("Model")
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
	driving = RunService.Heartbeat:Connect(function()
		if not seat.Parent then
			stop()
			return
		end
		local velocity = Chassis.GetAverageVelocity()
		Chassis.UpdateSteering(seat.SteerFloat, velocity)
		Chassis.UpdateThrottle(velocity, seat.ThrottleFloat)
		if seat.ThrottleFloat == 0 and math.abs(velocity) < 2 then
			Chassis.EnableHandbrake()
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

function CarDriver.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return CarDriver
