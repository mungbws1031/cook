--!strict
-- 서버 진입점: 맵을 생성한 뒤 서비스들을 켠다. 순서가 중요하다.

local Players = game:GetService("Players")

local TowerBuilder = require(script.TowerBuilder)
local HazardService = require(script.HazardService)
local DataService = require(script.DataService)
local ProgressService = require(script.ProgressService)

-- 맵이 생기기 전에 캐릭터가 허공에서 스폰되지 않도록 잠시 자동 스폰을 끈다.
Players.CharacterAutoLoads = false

local startedAt = os.clock()

TowerBuilder.build()
DataService.start()
HazardService.start()
ProgressService.start()

Players.CharacterAutoLoads = true
for _, player in Players:GetPlayers() do
	if not player.Character then
		player:LoadCharacter()
	end
end

print(string.format("[Tower] 맵 생성 완료 (%.2f초)", os.clock() - startedAt))
