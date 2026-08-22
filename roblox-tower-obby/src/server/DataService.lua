--!strict
-- 플레이어 진행도 저장/불러오기 (DataStore).
-- Studio에서 API 접근이 꺼져 있으면 자동으로 메모리 전용으로 동작한다.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Profile = {
	version: number,
	progress: { [string]: number },  -- towerId → 도달한 최고 체크포인트
	completed: { [string]: boolean },-- towerId → 클리어 여부
	bestTimes: { [string]: number }, -- towerId → 최고 기록(초)
	deaths: number,
}

local DataService = {}

local STORE_NAME = "TowerProgress_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RETRY = 4

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}

local function defaultProfile(): Profile
	return {
		version = 1,
		progress = {},
		completed = {},
		bestTimes = {},
		deaths = 0,
	}
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

-- DataStore 호출은 실패할 수 있으니 지수 백오프로 재시도한다.
local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local delayTime = 1
	for attempt = 1, MAX_RETRY do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} 실패 ({attempt}/{MAX_RETRY}): {result}`)
		if attempt < MAX_RETRY then
			task.wait(delayTime)
			delayTime *= 2
		end
	end
	return false, nil
end

local function sanitize(raw: any): Profile
	local profile = defaultProfile()
	if type(raw) ~= "table" then
		return profile
	end
	if type(raw.progress) == "table" then
		for towerId, checkpoint in raw.progress do
			if type(towerId) == "string" and type(checkpoint) == "number" then
				profile.progress[towerId] = math.floor(checkpoint)
			end
		end
	end
	if type(raw.completed) == "table" then
		for towerId, done in raw.completed do
			if type(towerId) == "string" and done == true then
				profile.completed[towerId] = true
			end
		end
	end
	if type(raw.bestTimes) == "table" then
		for towerId, seconds in raw.bestTimes do
			if type(towerId) == "string" and type(seconds) == "number" then
				profile.bestTimes[towerId] = seconds
			end
		end
	end
	if type(raw.deaths) == "number" then
		profile.deaths = math.floor(raw.deaths)
	end
	return profile
end

function DataService.load(player: Player): Profile
	local existing = profiles[player]
	if existing then
		return existing
	end

	local profile = defaultProfile()
	local activeStore = store
	if activeStore then
		local ok, raw = retry(`GetAsync {player.Name}`, function()
			return activeStore:GetAsync(keyFor(player))
		end)
		if ok and raw ~= nil then
			profile = sanitize(raw)
		elseif not ok then
			-- 불러오기에 실패한 세션은 덮어쓰지 않는다(진행도 유실 방지).
			player:SetAttribute("DataLoadFailed", true)
		end
	end

	profiles[player] = profile
	return profile
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.save(player: Player)
	local profile = profiles[player]
	local activeStore = store
	if not profile or not activeStore then
		return
	end
	if player:GetAttribute("DataLoadFailed") then
		return
	end
	if not dirty[player] then
		return
	end

	local ok = retry(`SetAsync {player.Name}`, function()
		activeStore:UpdateAsync(keyFor(player), function()
			return profile
		end)
		return true
	end)
	if ok then
		dirty[player] = false
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
	dirty[player] = nil
end

-- 편의 함수 ------------------------------------------------------------

function DataService.getCheckpoint(player: Player, towerId: number): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	return profile.progress[tostring(towerId)] or 0
end

function DataService.setCheckpoint(player: Player, towerId: number, checkpoint: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local key = tostring(towerId)
	if (profile.progress[key] or 0) < checkpoint then
		profile.progress[key] = checkpoint
		DataService.markDirty(player)
	end
end

function DataService.completeTower(player: Player, towerId: number, seconds: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local key = tostring(towerId)
	profile.completed[key] = true

	local isRecord = false
	local best = profile.bestTimes[key]
	if not best or seconds < best then
		profile.bestTimes[key] = seconds
		isRecord = true
	end
	DataService.markDirty(player)
	return isRecord
end

function DataService.countCompleted(player: Player): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	local count = 0
	for _ in profile.completed do
		count += 1
	end
	return count
end

-- 클리어한 타워 중 가장 높은 난이도 이름
function DataService.highestDifficultyName(player: Player): string
	local profile = profiles[player]
	if not profile then
		return "-"
	end
	local best = 0
	for key in profile.completed do
		local tower = Config.getTower(tonumber(key) or 0)
		if tower and tower.difficulty > best then
			best = tower.difficulty
		end
	end
	if best == 0 then
		return "-"
	end
	return Config.Difficulties[best].name
end

function DataService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore를 쓸 수 없어 메모리 전용으로 동작합니다 (Studio API 접근 설정 확인).")
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.save(player)
		end
	end)
end

return DataService
