--!strict
-- 체크포인트 판정, 부활 위치, 포탈 이동, 클리어 처리, leaderstats.
-- 플레이어 상태는 Attribute로 노출해 클라이언트 HUD가 바로 읽게 한다.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local ResetRemote = Remotes:WaitForChild("ResetToCheckpoint") :: RemoteEvent
local ReturnRemote = Remotes:WaitForChild("ReturnToHub") :: RemoteEvent

local ProgressService = {}

local TOUCH_DEBOUNCE = 0.5
local RESET_COOLDOWN = 1

-- pads[towerId][checkpointIndex] = SpawnLocation
local pads: { [number]: { [number]: SpawnLocation } } = {}
local hubSpawn: SpawnLocation? = nil
local lastAction: { [Player]: number } = {}

local function notify(player: Player, kind: string, message: string)
	NotifyRemote:FireClient(player, kind, message)
end

local function padFor(towerId: number, checkpoint: number): SpawnLocation?
	local tower = pads[towerId]
	return tower and tower[checkpoint]
end

local function teleport(player: Player, pad: BasePart)
	local character = player.Character
	if not character then
		return
	end
	-- 캐릭터가 막 생성된 직후에는 루트 파트가 아직 없을 수 있다.
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root or character.Parent == nil then
		return
	end
	character:PivotTo(pad.CFrame + Vector3.new(0, 5, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- 플레이어를 특정 타워의 특정 체크포인트로 보낸다.
local function sendTo(player: Player, towerId: number, checkpoint: number)
	local pad = if towerId == 0 then hubSpawn else padFor(towerId, checkpoint)
	if not pad then
		return
	end
	player.RespawnLocation = pad
	player:SetAttribute("TowerId", towerId)
	player:SetAttribute("Checkpoint", checkpoint)
	teleport(player, pad)
end

local function startRun(player: Player)
	player:SetAttribute("RunStart", workspace:GetServerTimeNow())
end

local function refreshLeaderstats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local cleared = stats:FindFirstChild("정복한 탑") :: IntValue?
	local best = stats:FindFirstChild("최고 난이도") :: StringValue?
	if cleared then
		cleared.Value = DataService.countCompleted(player)
	end
	if best then
		best.Value = DataService.highestDifficultyName(player)
	end
end

local function enterTower(player: Player, towerId: number)
	local tower = Config.getTower(towerId)
	if not tower then
		return
	end
	local checkpoint = DataService.getCheckpoint(player, towerId)
	player:SetAttribute("TowerName", tower.name)
	player:SetAttribute("TowerSections", tower.sections + 1)
	player:SetAttribute("DifficultyName", Config.getDifficulty(tower).name)
	sendTo(player, towerId, checkpoint)
	startRun(player)

	if checkpoint > 0 then
		notify(player, "info", `{tower.name} · 체크포인트 {checkpoint}부터 이어서 시작!`)
	else
		notify(player, "info", `{tower.name} 입장! ({Config.getDifficulty(tower).name})`)
	end
end

local function returnToHub(player: Player)
	player:SetAttribute("TowerId", 0)
	player:SetAttribute("Checkpoint", 0)
	player:SetAttribute("TowerName", Config.HubName)
	player:SetAttribute("TowerSections", 0)
	player:SetAttribute("DifficultyName", "")
	player:SetAttribute("RunStart", 0)
	if hubSpawn then
		player.RespawnLocation = hubSpawn
		teleport(player, hubSpawn)
	end
end

local function onSummit(player: Player, tower: Config.Tower)
	local runStart = player:GetAttribute("RunStart") :: number?
	local elapsed = if runStart and runStart > 0 then workspace:GetServerTimeNow() - runStart else 0
	local isRecord = DataService.completeTower(player, tower.id, elapsed)
	DataService.save(player)
	refreshLeaderstats(player)

	local minutes = math.floor(elapsed / 60)
	local seconds = elapsed % 60
	local timeText = string.format("%d분 %.1f초", minutes, seconds)
	if isRecord then
		notify(player, "record", `{tower.name} 클리어! 신기록 {timeText} 🏆`)
	else
		notify(player, "clear", `{tower.name} 클리어! {timeText}`)
	end
end

local function onCheckpointTouched(pad: SpawnLocation, hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < TOUCH_DEBOUNCE then
		return
	end
	lastAction[player] = now

	local towerId = pad:GetAttribute("TowerId") :: number
	local checkpoint = pad:GetAttribute("Checkpoint") :: number

	if towerId == 0 then
		-- 허브 스폰 발판
		returnToHub(player)
		return
	end

	local tower = Config.getTower(towerId)
	if not tower then
		return
	end

	-- 다른 타워에서 걸어 들어온 경우에도 자연스럽게 그 타워로 전환된다.
	if player:GetAttribute("TowerId") ~= towerId then
		player:SetAttribute("TowerId", towerId)
		player:SetAttribute("TowerName", tower.name)
		player:SetAttribute("TowerSections", tower.sections + 1)
		player:SetAttribute("DifficultyName", Config.getDifficulty(tower).name)
		startRun(player)
	end

	local current = player:GetAttribute("Checkpoint") :: number? or 0
	if checkpoint <= current then
		return
	end

	player:SetAttribute("Checkpoint", checkpoint)
	player.RespawnLocation = pad
	DataService.setCheckpoint(player, towerId, checkpoint)
	DataService.save(player)

	if pad:GetAttribute("Summit") then
		onSummit(player, tower)
	else
		notify(player, "checkpoint", `체크포인트 {checkpoint} / {tower.sections}`)
	end
end

local function onPortalTouched(portal: BasePart, hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < TOUCH_DEBOUNCE then
		return
	end
	lastAction[player] = now

	enterTower(player, portal:GetAttribute("TowerId") :: number)
end

local function indexMap()
	for _, pad in CollectionService:GetTagged(Config.Tags.Checkpoint) do
		if not pad:IsA("SpawnLocation") then
			continue
		end
		local towerId = pad:GetAttribute("TowerId") :: number
		local checkpoint = pad:GetAttribute("Checkpoint") :: number
		if towerId == 0 then
			hubSpawn = pad
		else
			pads[towerId] = pads[towerId] or {}
			pads[towerId][checkpoint] = pad
		end
		pad.Touched:Connect(function(hit)
			onCheckpointTouched(pad, hit)
		end)
	end

	for _, portal in CollectionService:GetTagged(Config.Tags.Portal) do
		if portal:IsA("BasePart") then
			portal.Touched:Connect(function(hit)
				onPortalTouched(portal, hit)
			end)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local profile = DataService.get(player)
		if profile then
			profile.deaths += 1
			DataService.markDirty(player)
		end
	end)

	-- 부활 위치가 밀리는 경우가 있어 한 프레임 뒤 직접 보정한다.
	task.defer(function()
		local towerId = player:GetAttribute("TowerId") :: number? or 0
		local checkpoint = player:GetAttribute("Checkpoint") :: number? or 0
		local pad = if towerId == 0 then hubSpawn else padFor(towerId, checkpoint)
		if pad then
			teleport(player, pad)
		end
	end)
end

local function onPlayerAdded(player: Player)
	DataService.load(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local cleared = Instance.new("IntValue")
	cleared.Name = "정복한 탑"
	cleared.Parent = stats

	local best = Instance.new("StringValue")
	best.Name = "최고 난이도"
	best.Parent = stats

	stats.Parent = player

	player:SetAttribute("TowerId", 0)
	player:SetAttribute("Checkpoint", 0)
	player:SetAttribute("TowerName", Config.HubName)
	player:SetAttribute("TowerSections", 0)
	player:SetAttribute("DifficultyName", "")
	player:SetAttribute("RunStart", 0)
	refreshLeaderstats(player)

	if hubSpawn then
		player.RespawnLocation = hubSpawn
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function ProgressService.start()
	indexMap()

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
		lastAction[player] = nil
	end)

	ResetRemote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastAction[player] and now - lastAction[player] < RESET_COOLDOWN then
			return
		end
		lastAction[player] = now
		local towerId = player:GetAttribute("TowerId") :: number? or 0
		local checkpoint = player:GetAttribute("Checkpoint") :: number? or 0
		sendTo(player, towerId, checkpoint)
	end)

	ReturnRemote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastAction[player] and now - lastAction[player] < RESET_COOLDOWN then
			return
		end
		lastAction[player] = now
		returnToHub(player)
	end)
end

return ProgressService
