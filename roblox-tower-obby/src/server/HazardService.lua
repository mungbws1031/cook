--!strict
-- 태그가 붙은 장치들을 한 개의 Heartbeat 루프로 굴린다.
-- (파트마다 루프를 도는 것보다 훨씬 가볍다.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local HazardService = {}

local KILL_DEBOUNCE = 0.4
local lastKill: { [Humanoid]: number } = {}

local function humanoidFromHit(hit: BasePart): Humanoid?
	local character = hit.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and Players:GetPlayerFromCharacter(character) then
		return humanoid
	end
	return nil
end

local function onKillbrickTouched(hit: BasePart)
	local humanoid = humanoidFromHit(hit)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if lastKill[humanoid] and now - lastKill[humanoid] < KILL_DEBOUNCE then
		return
	end
	lastKill[humanoid] = now
	humanoid.Health = 0
end

local function bindKillbrick(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(onKillbrickTouched)
end

local function updateMover(part: BasePart, now: number)
	local origin = Vector3.new(
		part:GetAttribute("OriginX") :: number,
		part:GetAttribute("OriginY") :: number,
		part:GetAttribute("OriginZ") :: number
	)
	local axis = Vector3.new(
		part:GetAttribute("AxisX") :: number,
		part:GetAttribute("AxisY") :: number,
		part:GetAttribute("AxisZ") :: number
	)
	local distance = part:GetAttribute("Distance") :: number
	local speed = part:GetAttribute("Speed") :: number
	local phase = part:GetAttribute("Phase") :: number

	local angle = now * speed + phase
	local offset = math.sin(angle) * distance
	part.CFrame = CFrame.new(origin + axis * offset) * (part.CFrame - part.CFrame.Position)

	-- 고정(Anchored) 파트라도 표면 속도를 주면 위에 선 캐릭터가 같이 끌려간다.
	part.AssemblyLinearVelocity = axis * (math.cos(angle) * distance * speed)
end

local function updateSpinner(part: BasePart, now: number)
	local pivot = Vector3.new(
		part:GetAttribute("PivotX") :: number,
		part:GetAttribute("PivotY") :: number,
		part:GetAttribute("PivotZ") :: number
	)
	local speed = part:GetAttribute("Speed") :: number
	local phase = part:GetAttribute("Phase") :: number
	part.CFrame = CFrame.new(pivot) * CFrame.Angles(0, now * speed + phase, 0)
end

local function updateVanisher(part: BasePart, now: number)
	local interval = part:GetAttribute("Interval") :: number
	local offset = part:GetAttribute("Offset") :: number
	-- 한 주기의 앞 절반은 존재, 뒤 절반은 사라짐.
	local phase = ((now / interval) + offset) % 1
	local visible = phase < 0.5

	if part.CanCollide ~= visible then
		part.CanCollide = visible
		part.Transparency = if visible then 0 else 0.75
	end

	-- 사라지기 직전 0.4주기 구간에서 깜빡여 예고한다.
	if visible and phase > 0.35 then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 120, 120)
	elseif visible then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 200, 120)
	end
end

local function updateConveyor(part: BasePart)
	local speed = part:GetAttribute("Speed") :: number
	part.AssemblyLinearVelocity = part.CFrame.LookVector * speed
end

-- 낙하 속도가 빠르면 사망 판정면을 뚫고 지나갈 수 있어 높이도 함께 감시한다.
local function watchVoid()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and root.Position.Y < Config.VoidY then
				humanoid.Health = 0
			end
		end
	end
end

function HazardService.start()
	task.spawn(watchVoid)

	for _, instance in CollectionService:GetTagged(Config.Tags.Killbrick) do
		bindKillbrick(instance)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Killbrick):Connect(bindKillbrick)

	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lastKill[humanoid] = nil
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()

		for _, part in CollectionService:GetTagged(Config.Tags.Mover) do
			if part:IsA("BasePart") then
				updateMover(part, now)
			end
		end
		for _, part in CollectionService:GetTagged(Config.Tags.Spinner) do
			if part:IsA("BasePart") then
				updateSpinner(part, now)
			end
		end
		for _, part in CollectionService:GetTagged(Config.Tags.Vanisher) do
			if part:IsA("BasePart") then
				updateVanisher(part, now)
			end
		end
		for _, part in CollectionService:GetTagged(Config.Tags.Conveyor) do
			if part:IsA("BasePart") then
				updateConveyor(part)
			end
		end
	end)
end

return HazardService
