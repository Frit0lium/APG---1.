-- BattleClient
-- Put this in: StarterPlayer > StarterPlayerScripts (as a LocalScript)
-- Camera, UI, tile highlights and click input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BattleRemotes")
local actionRemote = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local fxRemote = remotes:WaitForChild("FX")
local arena = workspace:WaitForChild("Arena")

local current = nil
local markers = {}
local shake = 0

--------------------------------------------------------------------------
-- CAMERA (fixed tactical view + shake)
--------------------------------------------------------------------------
local BASE_CF = CFrame.lookAt(Vector3.new(0, 34, 40), Vector3.new(0, 0, 6))

RunService:BindToRenderStep("BattleCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local off = Vector3.zero
	if shake > 0.01 then
		off = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		shake = shake * math.max(0, 1 - dt * 6)
	end
	cam.CFrame = BASE_CF * CFrame.new(off)
end)

--------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local gui = mk("ScreenGui", { Name = "BattleUI", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

local function makeUnitPanel(title, anchorX, color)
	local panel = mk("Frame", {
		Size = UDim2.new(0, 200, 0, 76),
		Position = UDim2.new(anchorX, anchorX == 0 and 12 or -12, 0, 12),
		AnchorPoint = Vector2.new(anchorX, 0),
		BackgroundColor3 = Color3.fromRGB(15, 18, 26),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, panel)
	mk("TextLabel", {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = color,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.new(0, 8, 0, 2),
	}, panel)

	local function bar(y, h, fillColor)
		local bg = mk("Frame", {
			Size = UDim2.new(1, -16, 0, h),
			Position = UDim2.new(0, 8, 0, y),
			BackgroundColor3 = Color3.fromRGB(40, 44, 55),
			BorderSizePixel = 0,
		}, panel)
		local fill = mk("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = fillColor,
			BorderSizePixel = 0,
		}, bg)
		local txt = mk("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = h - 4,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 2,
		}, bg)
		return function(v, max)
			fill.Size = UDim2.fromScale(math.clamp(v / max, 0, 1), 1)
			txt.Text = v .. " / " .. max
		end
	end

	return {
		hp = bar(26, 20, Color3.fromRGB(80, 200, 120)),
		en = bar(51, 16, Color3.fromRGB(70, 170, 255)),
	}
end

local playerPanel = makeUnitPanel("PLAYER MECH", 0, Color3.fromRGB(0, 220, 255))
local enemyPanel = makeUnitPanel("ENEMY MECH", 1, Color3.fromRGB(255, 90, 60))

local turnLabel = mk("TextLabel", {
	Size = UDim2.new(0, 320, 0, 32),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -136),
	BackgroundColor3 = Color3.fromRGB(15, 18, 26),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, turnLabel)

local logLabel = mk("TextLabel", {
	Size = UDim2.new(0, 360, 0, 22),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -102),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(200, 205, 215),
	Text = "",
}, gui)

local function makeButton(text, xOffset)
	local b = mk("TextButton", {
		Size = UDim2.new(0, 150, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, xOffset, 1, -66),
		BackgroundColor3 = Color3.fromRGB(0, 170, 210),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		AutoButtonColor = true,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	return b
end

local attackBtn = makeButton("ATTACK", -80)
local endBtn = makeButton("END TURN", 80)

local banner = mk("TextLabel", {
	Size = UDim2.new(0, 520, 0, 90),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 56,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.3,
	Text = "",
	Visible = false,
}, gui)

local flashFrame = mk("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
}, gui)

local function flash()
	flashFrame.BackgroundTransparency = 0.35
	TweenService:Create(flashFrame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
end

--------------------------------------------------------------------------
-- TILE MARKERS (client-only highlights)
--------------------------------------------------------------------------
local markerFolder = Instance.new("Folder")
markerFolder.Name = "LocalMarkers"
markerFolder.Parent = workspace

local function ensureMarkers()
	if next(markers) then
		return
	end
	for _, tile in ipairs(arena:GetChildren()) do
		local x, y = tile:GetAttribute("X"), tile:GetAttribute("Y")
		if x and y then
			local m = Instance.new("Part")
			m.Size = Vector3.new(tile.Size.X - 0.6, 0.2, tile.Size.Z - 0.6)
			m.Position = tile.Position + Vector3.new(0, 0.6, 0)
			m.Material = Enum.Material.Neon
			m.Anchored = true
			m.CanCollide = false
			m.CanQuery = false
			m.CastShadow = false
			m.Transparency = 1
			m.Parent = markerFolder
			markers[x * 100 + y] = m
		end
	end
end

local function setMarker(x, y, color, transparency)
	local m = markers[x * 100 + y]
	if m then
		m.Color = color
		m.Transparency = transparency
	end
end

--------------------------------------------------------------------------
-- LOGIC HELPERS
--------------------------------------------------------------------------
local function canAct()
	return current ~= nil and current.turn == "player" and not current.busy and not current.over and current.ap > 0
end

local function isValidMove(x, y)
	if not canAct() then
		return false
	end
	local s = current
	local pu, eu = s.units.player, s.units.enemy
	if pu.en < s.cfg.moveCost then
		return false
	end
	if x == eu.x and y == eu.y then
		return false
	end
	local d = math.abs(x - pu.x) + math.abs(y - pu.y)
	return d >= 1 and d <= s.cfg.moveRange
end

local function canAttack()
	if not canAct() then
		return false
	end
	local pu, eu = current.units.player, current.units.enemy
	local d = math.abs(pu.x - eu.x) + math.abs(pu.y - eu.y)
	return d <= current.cfg.attackRange and pu.en >= current.cfg.attackCost
end

--------------------------------------------------------------------------
-- RENDER
--------------------------------------------------------------------------
local function render()
	local s = current
	if not s then
		return
	end
	ensureMarkers()

	local pu, eu = s.units.player, s.units.enemy
	playerPanel.hp(pu.hp, s.cfg.maxHp)
	playerPanel.en(pu.en, s.cfg.maxEn)
	enemyPanel.hp(eu.hp, s.cfg.maxHp)
	enemyPanel.en(eu.en, s.cfg.maxEn)

	if s.over then
		turnLabel.Text = "BATTLE OVER"
	elseif s.turn == "player" then
		turnLabel.Text = "YOUR TURN  |  ACTIONS: " .. s.ap
	else
		turnLabel.Text = "ENEMY TURN"
	end
	logLabel.Text = s.log or ""

	attackBtn.BackgroundColor3 = canAttack() and Color3.fromRGB(0, 170, 210) or Color3.fromRGB(50, 55, 65)
	local canEnd = s.turn == "player" and not s.busy and not s.over
	endBtn.BackgroundColor3 = canEnd and Color3.fromRGB(210, 140, 30) or Color3.fromRGB(50, 55, 65)

	if s.over then
		banner.Visible = true
		banner.Text = (s.over == "win") and "VICTORY" or "DEFEATED"
		banner.TextColor3 = (s.over == "win") and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(255, 80, 50)
	else
		banner.Visible = false
	end

	-- markers
	for _, m in pairs(markers) do
		m.Transparency = 1
	end
	setMarker(pu.x, pu.y, Color3.fromRGB(60, 255, 140), 0.6)
	local inRange = canAttack()
	setMarker(eu.x, eu.y, Color3.fromRGB(255, 60, 50), inRange and 0.3 or 0.6)
	if canAct() then
		for x = 1, s.cfg.grid do
			for y = 1, s.cfg.grid do
				if isValidMove(x, y) then
					setMarker(x, y, Color3.fromRGB(60, 150, 255), 0.55)
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { arena }

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not canAct() then
		return
	end
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
	local res = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
	if res then
		local x, y = res.Instance:GetAttribute("X"), res.Instance:GetAttribute("Y")
		if x and y and isValidMove(x, y) then
			actionRemote:FireServer("move", x, y)
		end
	end
end)

attackBtn.Activated:Connect(function()
	if canAttack() then
		actionRemote:FireServer("attack")
	end
end)

endBtn.Activated:Connect(function()
	if current and current.turn == "player" and not current.busy and not current.over then
		actionRemote:FireServer("end")
	end
end)

--------------------------------------------------------------------------
-- SERVER EVENTS
--------------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(function(s)
	current = s
	render()
end)

fxRemote.OnClientEvent:Connect(function(kind, mag)
	if kind == "hit" then
		shake = math.max(shake, mag or 1)
		flash()
		local cam = workspace.CurrentCamera
		cam.FieldOfView = 58
		TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
	end
end)

actionRemote:FireServer("ready")
