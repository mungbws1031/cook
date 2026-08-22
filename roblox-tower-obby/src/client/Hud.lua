--!strict
-- 화면 UI: 현재 타워/난이도/체크포인트, 타이머, 조작 버튼, 토스트.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Hud = {}

local COLORS = {
	panel = Color3.fromRGB(18, 19, 26),
	text = Color3.fromRGB(240, 242, 248),
	dim = Color3.fromRGB(160, 165, 180),
	accent = Color3.fromRGB(120, 220, 120),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function difficultyColor(name: string): Color3
	for _, difficulty in Config.Difficulties do
		if difficulty.name == name then
			return difficulty.color
		end
	end
	return COLORS.accent
end

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%05.2f", minutes, seconds % 60)
end

function Hud.build(): { [string]: any }
	local gui = Instance.new("ScreenGui")
	gui.Name = "TowerHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 상단 정보 패널 ---------------------------------------------------
	local top = Instance.new("Frame")
	top.Name = "Status"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 12)
	top.Size = UDim2.new(0, 340, 0, 74)
	top.BackgroundColor3 = COLORS.panel
	top.BackgroundTransparency = 0.15
	top.BorderSizePixel = 0
	top.Parent = gui
	corner(top, 12)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Position = UDim2.new(0, 0, 0, 0)
	badge.Size = UDim2.new(0, 6, 1, 0)
	badge.BackgroundColor3 = COLORS.accent
	badge.BorderSizePixel = 0
	badge.Parent = top
	corner(badge, 12)

	local towerLabel = Instance.new("TextLabel")
	towerLabel.Name = "Tower"
	towerLabel.BackgroundTransparency = 1
	towerLabel.Position = UDim2.new(0, 18, 0, 8)
	towerLabel.Size = UDim2.new(1, -28, 0, 26)
	towerLabel.Font = Enum.Font.GothamBold
	towerLabel.TextXAlignment = Enum.TextXAlignment.Left
	towerLabel.TextColor3 = COLORS.text
	towerLabel.TextSize = 20
	towerLabel.Text = Config.HubName
	towerLabel.Parent = top

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Sub"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.new(0, 18, 0, 36)
	subLabel.Size = UDim2.new(1, -28, 0, 22)
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextColor3 = COLORS.dim
	subLabel.TextSize = 15
	subLabel.Text = "포탈 발판을 밟아 타워를 골라보세요"
	subLabel.Parent = top

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -14, 0, 24)
	timerLabel.Size = UDim2.new(0, 110, 0, 26)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.RobotoMono
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.TextColor3 = COLORS.text
	timerLabel.TextSize = 18
	timerLabel.Text = ""
	timerLabel.Parent = top

	-- 하단 버튼 --------------------------------------------------------
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -16)
	buttons.Size = UDim2.new(0, 300, 0, 46)
	buttons.BackgroundTransparency = 1
	buttons.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = buttons

	local function makeButton(name: string, text: string): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.new(0, 145, 1, 0)
		button.BackgroundColor3 = COLORS.panel
		button.BackgroundTransparency = 0.1
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = COLORS.text
		button.TextSize = 16
		button.Text = text
		button.Parent = buttons
		corner(button, 10)
		return button
	end

	local resetButton = makeButton("Reset", "체크포인트 (R)")
	local hubButton = makeButton("Hub", "허브로 (H)")

	-- 토스트 -----------------------------------------------------------
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 100)
	toast.Size = UDim2.new(0, 420, 0, 44)
	toast.BackgroundColor3 = COLORS.panel
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.TextColor3 = COLORS.text
	toast.TextSize = 18
	toast.TextTransparency = 1
	toast.Text = ""
	toast.Parent = gui
	corner(toast, 10)

	return {
		gui = gui,
		badge = badge,
		towerLabel = towerLabel,
		subLabel = subLabel,
		timerLabel = timerLabel,
		toast = toast,
		resetButton = resetButton,
		hubButton = hubButton,
	}
end

function Hud.refresh(ui: { [string]: any })
	local towerId = player:GetAttribute("TowerId") :: number? or 0
	local towerName = player:GetAttribute("TowerName") :: string? or Config.HubName
	local difficultyName = player:GetAttribute("DifficultyName") :: string? or ""
	local checkpoint = player:GetAttribute("Checkpoint") :: number? or 0
	local sections = player:GetAttribute("TowerSections") :: number? or 0

	ui.towerLabel.Text = towerName

	if towerId == 0 then
		ui.subLabel.Text = "포탈 발판을 밟아 타워를 골라보세요"
		ui.badge.BackgroundColor3 = Color3.fromRGB(200, 205, 215)
		ui.timerLabel.Text = ""
	else
		local total = math.max(sections - 1, 1)
		if checkpoint >= sections then
			ui.subLabel.Text = `{difficultyName} · 정상 정복 완료 🏆`
		else
			ui.subLabel.Text = `{difficultyName} · 체크포인트 {checkpoint} / {total}`
		end
		ui.badge.BackgroundColor3 = difficultyColor(difficultyName)
	end
end

function Hud.startTimer(ui: { [string]: any })
	RunService.RenderStepped:Connect(function()
		local runStart = player:GetAttribute("RunStart") :: number? or 0
		local towerId = player:GetAttribute("TowerId") :: number? or 0
		if towerId == 0 or runStart <= 0 then
			ui.timerLabel.Text = ""
			return
		end
		ui.timerLabel.Text = formatTime(workspace:GetServerTimeNow() - runStart)
	end)
end

local toastToken = 0

function Hud.showToast(ui: { [string]: any }, kind: string, message: string)
	toastToken += 1
	local token = toastToken

	local color = COLORS.text
	if kind == "record" then
		color = Color3.fromRGB(255, 215, 0)
	elseif kind == "clear" then
		color = Color3.fromRGB(120, 220, 120)
	elseif kind == "checkpoint" then
		color = Color3.fromRGB(120, 200, 255)
	end

	ui.toast.Text = message
	ui.toast.TextColor3 = color

	local fadeIn = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ui.toast, fadeIn, { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()

	task.delay(2.4, function()
		if token ~= toastToken then
			return
		end
		local fadeOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(ui.toast, fadeOut, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

return Hud
