--!strict
-- 서버 진입점: 맵을 생성한 뒤 서비스들을 켠다. 순서가 중요하다.

local TowerBuilder = require(script.TowerBuilder)
local HazardService = require(script.HazardService)
local DataService = require(script.DataService)
local ProgressService = require(script.ProgressService)

local startedAt = os.clock()

TowerBuilder.build()
DataService.start()
HazardService.start()
ProgressService.start()

print(string.format("[Tower] 맵 생성 완료 (%.2f초)", os.clock() - startedAt))
