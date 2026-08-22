--!strict
-- 허브 광장과 난이도별 타워 10개를 생성한다.
-- 고정 시드를 쓰기 때문에 어느 서버에 들어가도 맵 모양이 같다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TowerBuilder = {}

local TAU = math.pi * 2

local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- 원통 좌표(각도, 반지름, 높이) → 안쪽(중심축)을 바라보는 CFrame
local function ringCFrame(origin: Vector3, theta: number, radius: number, y: number): CFrame
	local pos = origin + Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
	local center = Vector3.new(origin.X, pos.Y, origin.Z)
	return CFrame.lookAt(pos, center)
end

local function addSurfaceLabel(
	part: BasePart,
	face: Enum.NormalId,
	title: string,
	subtitle: string,
	color: Color3
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(500, 250)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.62)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0, 0.62)
	subLabel.Size = UDim2.fromScale(1, 0.38)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.Text = subtitle
	subLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
	subLabel.TextScaled = true
	subLabel.Parent = gui
end

-- 체크포인트는 SpawnLocation 자체를 발판으로 쓴다(부활 위치 지정이 쉬움).
local function buildCheckpoint(
	towerId: number,
	index: number,
	difficulty: Config.Difficulty,
	cf: CFrame,
	parent: Instance
): SpawnLocation
	local pad = Instance.new("SpawnLocation")
	pad.Name = string.format("Checkpoint_%d_%02d", towerId, index)
	pad.Size = Vector3.new(15, 1.6, 15)
	pad.CFrame = cf
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.AllowTeamChangeOnTouch = false
	-- 새 플레이어가 아무 타워에서나 스폰되지 않도록 꺼둔다.
	-- 부활 위치는 ProgressService가 직접 텔레포트로 맞춘다.
	pad.Enabled = false
	pad.Material = Enum.Material.Neon
	pad.Color = difficulty.color
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("TowerId", towerId)
	pad:SetAttribute("Checkpoint", index)
	pad.Parent = parent

	addSurfaceLabel(pad, Enum.NormalId.Top, tostring(index), difficulty.name, Color3.new(1, 1, 1))
	CollectionService:AddTag(pad, Config.Tags.Checkpoint)
	return pad
end

-- 발판 한 칸. 종류에 따라 태그와 속성을 붙여두면 HazardService가 알아서 굴린다.
local function buildPlatform(
	kind: string,
	difficulty: Config.Difficulty,
	cf: CFrame,
	rng: Random,
	stepIndex: number,
	parent: Instance
)
	local size = difficulty.platformSize
	local baseColor = difficulty.color:Lerp(Color3.new(1, 1, 1), 0.25)

	if kind == "wide" then
		makePart({
			Name = "Platform",
			Size = Vector3.new(size * 1.8, 1.2, size * 1.8),
			CFrame = cf,
			Color = baseColor,
		}, parent)
	elseif kind == "static" then
		makePart({
			Name = "Platform",
			Size = Vector3.new(size, 1.2, size),
			CFrame = cf,
			Color = baseColor,
		}, parent)
	elseif kind == "moving" then
		local part = makePart({
			Name = "MovingPlatform",
			Size = Vector3.new(size * 1.15, 1.2, size * 1.15),
			CFrame = cf,
			Color = Color3.fromRGB(90, 170, 255),
			Material = Enum.Material.Metal,
		}, parent)
		-- 진행 방향 기준 좌우로 왕복시킨다.
		local axis = cf.RightVector
		part:SetAttribute("AxisX", axis.X)
		part:SetAttribute("AxisY", axis.Y)
		part:SetAttribute("AxisZ", axis.Z)
		part:SetAttribute("OriginX", cf.Position.X)
		part:SetAttribute("OriginY", cf.Position.Y)
		part:SetAttribute("OriginZ", cf.Position.Z)
		part:SetAttribute("Distance", rng:NextNumber(5, 10))
		part:SetAttribute("Speed", difficulty.speed * rng:NextNumber(0.8, 1.2))
		part:SetAttribute("Phase", rng:NextNumber(0, TAU))
		CollectionService:AddTag(part, Config.Tags.Mover)
	elseif kind == "vanish" then
		local part = makePart({
			Name = "VanishPlatform",
			Size = Vector3.new(size, 1.2, size),
			CFrame = cf,
			Color = Color3.fromRGB(255, 200, 120),
			Material = Enum.Material.Neon,
		}, parent)
		part:SetAttribute("Interval", math.max(1.2, 3.4 / difficulty.speed))
		-- 이웃 발판끼리 반주기 어긋나게 해서 리듬을 만든다.
		part:SetAttribute("Offset", (stepIndex % 2) * 0.5)
		CollectionService:AddTag(part, Config.Tags.Vanisher)
	elseif kind == "conveyor" then
		local part = makePart({
			Name = "Conveyor",
			Size = Vector3.new(size * 1.3, 1.2, size * 2.2),
			CFrame = cf,
			Color = Color3.fromRGB(150, 150, 162),
			Material = Enum.Material.DiamondPlate,
		}, parent)
		local direction = if rng:NextNumber() < 0.5 then 1 else -1
		part:SetAttribute("Speed", direction * 9 * difficulty.speed)
		CollectionService:AddTag(part, Config.Tags.Conveyor)
	elseif kind == "spinner" then
		makePart({
			Name = "Platform",
			Size = Vector3.new(size * 1.7, 1.2, size * 1.7),
			CFrame = cf,
			Color = baseColor,
		}, parent)
		local arm = makePart({
			Name = "Spinner",
			Size = Vector3.new(size * 3.4, 1.4, 1.4),
			CFrame = cf * CFrame.new(0, 2.4, 0),
			Color = Color3.fromRGB(255, 90, 90),
			Material = Enum.Material.Neon,
		}, parent)
		arm:SetAttribute("PivotX", cf.Position.X)
		arm:SetAttribute("PivotY", cf.Position.Y + 2.4)
		arm:SetAttribute("PivotZ", cf.Position.Z)
		arm:SetAttribute("Speed", difficulty.speed * rng:NextNumber(1.1, 1.9))
		arm:SetAttribute("Phase", rng:NextNumber(0, TAU))
		CollectionService:AddTag(arm, Config.Tags.Spinner)
	elseif kind == "kill" then
		makePart({
			Name = "Platform",
			Size = Vector3.new(size, 1.2, size),
			CFrame = cf,
			Color = baseColor,
		}, parent)
		-- 발판 바로 앞에 용암 띠를 깔아 점프 타이밍을 강제한다.
		local lava = makePart({
			Name = "Lava",
			Size = Vector3.new(size * 1.1, 1.4, difficulty.gap * 0.55),
			CFrame = cf * CFrame.new(0, 0, -(size * 0.5 + difficulty.gap * 0.35)),
			Color = Color3.fromRGB(255, 70, 30),
			Material = Enum.Material.Neon,
		}, parent)
		CollectionService:AddTag(lava, Config.Tags.Killbrick)
	else
		error(`알 수 없는 발판 종류: {kind}`)
	end
end

local function buildTower(tower: Config.Tower, origin: Vector3, rng: Random, parent: Instance)
	local difficulty = Config.getDifficulty(tower)

	local folder = Instance.new("Folder")
	folder.Name = string.format("Tower_%02d_%s", tower.id, tower.acronym)
	folder:SetAttribute("TowerId", tower.id)
	folder.Parent = parent

	-- 타워 받침대 (입구)
	makePart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, (Config.PathRadius + 18) * 2, (Config.PathRadius + 18) * 2),
		CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2),
		Color = difficulty.color:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Slate,
	}, folder)

	-- 입구 간판
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(30, 14, 1),
		CFrame = CFrame.new(origin + Vector3.new(0, 12, 0)),
		Color = Color3.fromRGB(18, 18, 22),
	}, folder)
	addSurfaceLabel(
		sign,
		Enum.NormalId.Back,
		tower.name,
		`{difficulty.name} · {tower.sections}구간`,
		difficulty.color
	)
	addSurfaceLabel(
		sign,
		Enum.NormalId.Front,
		tower.name,
		`{difficulty.name} · {tower.sections}구간`,
		difficulty.color
	)

	local theta = 0
	local y = 4

	-- 0번 체크포인트 = 타워 입구(부활 기준점)
	buildCheckpoint(tower.id, 0, difficulty, ringCFrame(origin, theta, Config.PathRadius, y), folder)

	for section = 1, tower.sections do
		local steps = rng:NextInteger(difficulty.stepsPerSection.Min, difficulty.stepsPerSection.Max)
		for step = 1, steps do
			theta += difficulty.gap / Config.PathRadius
			y += difficulty.rise
			local kind = difficulty.hazards[rng:NextInteger(1, #difficulty.hazards)]
			buildPlatform(kind, difficulty, ringCFrame(origin, theta, Config.PathRadius, y), rng, step, folder)
		end

		-- 다음 체크포인트 앞에는 한 칸 여유를 준다.
		theta += difficulty.gap / Config.PathRadius
		y += difficulty.rise + Config.SectionGapY
		buildCheckpoint(tower.id, section, difficulty, ringCFrame(origin, theta, Config.PathRadius, y), folder)
	end

	-- 중심 기둥: 난이도 색으로 칠해 멀리서도 어떤 타워인지 보이게 한다.
	local height = y + 20
	makePart({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, Config.CoreRadius * 2, Config.CoreRadius * 2),
		CFrame = CFrame.new(origin + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = difficulty.color,
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	}, folder)

	-- 정상: 마지막 체크포인트 위의 클리어 발판
	local summit = buildCheckpoint(
		tower.id,
		tower.sections + 1,
		difficulty,
		CFrame.new(origin + Vector3.new(0, y + 12, 0)),
		folder
	)
	summit.Name = string.format("Summit_%02d", tower.id)
	summit.Size = Vector3.new(Config.CoreRadius * 2.4, 2, Config.CoreRadius * 2.4)
	summit.Color = Color3.fromRGB(255, 215, 0)
	summit:SetAttribute("Summit", true)

	folder:SetAttribute("SummitCheckpoint", tower.sections + 1)
	folder:SetAttribute("Height", height)
end

local function buildHub(parent: Instance)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent

	makePart({
		Name = "HubFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, Config.HubRadius * 2, Config.HubRadius * 2),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(214, 218, 228),
		Material = Enum.Material.Marble,
	}, hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(28, 2, 28)
	spawn.CFrame = CFrame.new(0, 3, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn:SetAttribute("TowerId", 0)
	spawn:SetAttribute("Checkpoint", 0)
	spawn.Parent = hub
	CollectionService:AddTag(spawn, Config.Tags.Checkpoint)
	addSurfaceLabel(spawn, Enum.NormalId.Top, Config.HubName, "발판을 밟아 타워로 이동", Color3.fromRGB(50, 50, 55))

	return hub
end

-- 허브와 타워 전체를 생성해 Workspace 아래 폴더로 반환한다.
function TowerBuilder.build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local hub = buildHub(map)
	local rng = Random.new(Config.Seed)

	-- 맵 전체 바닥이 없으므로 아래에 보이지 않는 사망 판정면을 깐다.
	local void = makePart({
		Name = "Void",
		Size = Vector3.new(4000, 4, 4000),
		CFrame = CFrame.new(0, Config.VoidY, 0),
		Transparency = 1,
		CanCollide = false,
		Color = Color3.new(0, 0, 0),
	}, map)
	CollectionService:AddTag(void, Config.Tags.Killbrick)

	local towerCount = #Config.Towers
	for index, tower in Config.Towers do
		local theta = (index - 1) / towerCount * TAU
		local origin = Vector3.new(math.cos(theta) * Config.TowerRingRadius, 0, math.sin(theta) * Config.TowerRingRadius)
		buildTower(tower, origin, rng, map)

		-- 허브 가장자리에 해당 타워로 가는 포탈 발판을 놓는다.
		local difficulty = Config.getDifficulty(tower)
		local portalPos = Vector3.new(
			math.cos(theta) * (Config.HubRadius - 18),
			3,
			math.sin(theta) * (Config.HubRadius - 18)
		)
		local portal = makePart({
			Name = string.format("Portal_%02d", tower.id),
			Size = Vector3.new(16, 1.6, 16),
			CFrame = CFrame.lookAt(portalPos, Vector3.new(portalPos.X * 2, portalPos.Y, portalPos.Z * 2)),
			Color = difficulty.color,
			Material = Enum.Material.Neon,
		}, hub)
		portal:SetAttribute("TowerId", tower.id)
		addSurfaceLabel(portal, Enum.NormalId.Top, tower.name, difficulty.name, Color3.new(1, 1, 1))
		CollectionService:AddTag(portal, Config.Tags.Portal)
	end

	return map
end

return TowerBuilder
