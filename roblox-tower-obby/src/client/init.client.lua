--!strict
-- 클라이언트 진입점: HUD를 만들고 입력을 서버 리모트에 연결한다.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(script.Hud)

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local ResetRemote = Remotes:WaitForChild("ResetToCheckpoint") :: RemoteEvent
local ReturnRemote = Remotes:WaitForChild("ReturnToHub") :: RemoteEvent

local ui = Hud.build()
Hud.refresh(ui)
Hud.startTimer(ui)

for _, attribute in { "TowerId", "TowerName", "DifficultyName", "Checkpoint", "TowerSections" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		Hud.refresh(ui)
	end)
end

NotifyRemote.OnClientEvent:Connect(function(kind: string, message: string)
	Hud.showToast(ui, kind, message)
end)

local function requestReset()
	ResetRemote:FireServer()
end

local function requestHub()
	ReturnRemote:FireServer()
end

ui.resetButton.Activated:Connect(requestReset)
ui.hubButton.Activated:Connect(requestHub)

-- 키보드 단축키 (모바일은 위 버튼을 쓴다)
ContextActionService:BindAction("TowerReset", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestReset()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R)

ContextActionService:BindAction("TowerHub", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestHub()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.H)
