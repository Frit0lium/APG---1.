-- BattleServer
-- Put this in: ServerScriptService (as a normal Script)
-- Builds the arena, two procedural mechs, turn logic, a simple AI and attack effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

Players.CharacterAutoLoads = false -- no Roblox avatar, we only use the camera + UI

--------------------------------------------------------------------------
-- CONFIG (tweak these to balance the game)
--------------------------------------------------------------------------
local CFG = {
	GRID = 8,
	TILE = 6,
	MOVE_RANGE = 2,
	ATTACK_RANGE = 4,
	ACTIONS_PER_TURN = 2,
	MAX_HP = 100,
	MAX_EN = 100,
	MOVE_COST = 10,
	ATTACK_COST = 25,
	DAMAGE = 30,
	EN_REGEN = 30,
}
local MECH_HEIGHT = 4.3 -- distance from mech center to its feet
local TILE_TOP = 0.5

--------------------------------------------------------------------------
-- REMOTES (parented at the very end so clients only see them when ready)
--------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "BattleRemotes"
local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = "Action"
actionRemote.Parent = remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = remotes
local fxRemote = Instance.new("RemoteEvent")
fxRemote.Name = "FX"
fxRemote.Parent = remotes

--------------------------------------------------------------------------
-- LIGHTING (dark industrial mood + bloom so neon pops)
--------------------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(75, 85, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(75, 85, 110)

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.9
bloom.Size = 28
bloom.Threshold = 1
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.15
cc.Saturation = 0.1
cc.TintColor = Color3.fromRGB(205, 215, 255)
cc.Parent = Lighting

local atmo = Instance.new("Atmosphere")
atmo.Density = 0.25
atmo.Color = Color3.fromRGB(40, 50, 80)
atmo.Haze = 1.5
atmo.Parent = Lighting

--------------------------------------------------------------------------
-- ARENA
--------------------------------------------------------------------------
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

local function tileWorld(x, y)
	return Vector3.new((x - 0.5 - CFG.GRID / 2) * CFG.TILE, 0, (y - 0.5 - CFG.GRID / 2) * CFG.TILE)
end

local function mechPos(x, y)
	return tileWorld(x, y) + Vector3.new(0, TILE_TOP + MECH_HEIGHT, 0)
end

local function manhattan(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local arena = Instance.new("Folder")
arena.Name = "Arena"

local floorPart = Instance.new("Part")
floorPart.Name = "Floor"
floorPart.Size = Vector3.new(CFG.GRID * CFG.TILE + 60, 1, CFG.GRID * CFG.TILE + 60)
floorPart.Position = Vector3.new(0, -1, 0)
floorPart.Color = Color3.fromRGB(14, 15, 19)
floorPart.Material = Enum.Material.Concrete
floorPart.Anchored = true
floorPart.Parent = arena

for x = 1, CFG.GRID do
	for y = 1, CFG.GRID do
		local tile = Instance.new("Part")
		tile.Name = "Tile"
		tile.Size = Vector3.new(CFG.TILE - 0.2, 1, CFG.TILE - 0.2)
		tile.Position = tileWorld(x, y)
		tile.Color = ((x + y) % 2 == 0) and Color3.fromRGB(40, 44, 54) or Color3.fromRGB(54, 59, 72)
		tile.Material = Enum.Material.SmoothPlastic
		tile.Anchored = true
		tile:SetAttribute("X", x)
		tile:SetAttribute("Y", y)
		tile.Parent = arena
	end
end
arena.Parent = workspace

local mechsFolder = Instance.new("Folder")
mechsFolder.Name = "Mechs"
mechsFolder.Parent = workspace

--------------------------------------------------------------------------
-- PROCEDURAL MECH (all Parts, no meshes needed)
-- Front of the mech is -Z. Pivot is the core.
--------------------------------------------------------------------------
local function buildMech(name, armor, dark, glow)
	local m = Instance.new("Model")
	m.Name = name

	local function p(pname, size, cf, color, mat)
		local part = Instance.new("Part")
		part.Name = pname
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = mat or Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = m
		return part
	end
	local V, CF = Vector3.new, CFrame.new
	local NEON = Enum.Material.Neon

	local core = p("Core", V(3.2, 2.4, 2.4), CF(0, 0, 0), armor)
	m.PrimaryPart = core
	p("Pelvis", V(2.4, 0.8, 2), CF(0, -1.4, 0), dark)
	p("ChestPlate", V(2.6, 1.2, 0.4), CF(0, 0.2, -1.3), armor)
	p("ChestGlow", V(2.0, 0.15, 0.1), CF(0, 0.2, -1.52), glow, NEON)
	p("Head", V(1.4, 1.0, 1.4), CF(0, 1.75, 0), armor)
	p("Visor", V(1.0, 0.25, 0.1), CF(0, 1.8, -0.72), glow, NEON)
	p("Booster", V(1.8, 1.6, 1.0), CF(0, 0.3, 1.7), dark)
	p("BoosterGlow", V(1.2, 0.2, 0.1), CF(0, -0.2, 2.23), glow, NEON)

	for _, s in ipairs({ -1, 1 }) do
		p("Thigh", V(1.2, 1.8, 1.6), CF(s * 1.2, -2.0, 0), armor)
		p("Shin", V(1.4, 1.8, 1.8), CF(s * 1.3, -3.3, 0.1), armor)
		p("Foot", V(1.8, 0.5, 2.8), CF(s * 1.3, -4.05, -0.3), dark)
		p("ShinGlow", V(0.2, 1.0, 0.2), CF(s * 1.3, -3.3, -0.95), glow, NEON)
		p("Shoulder", V(1.8, 0.7, 2), CF(s * 2.3, 1.5, 0), armor)
		p("Arm", V(1.1, 2.0, 1.3), CF(s * 2.3, 0.2, 0), dark)
	end

	-- right arm cannon, left shoulder pod
	p("Cannon", V(0.7, 0.7, 3.2), CF(2.3, 0.2, -2.1), dark)
	p("CannonTip", V(0.5, 0.5, 0.2), CF(2.3, 0.2, -3.8), glow, NEON)
	p("Pod", V(1.0, 1.0, 2.0), CF(-2.3, 2.3, 0.3), dark)

	return m
end

--------------------------------------------------------------------------
-- GAME STATE
--------------------------------------------------------------------------
local units = {}
local state = { turn = "player", ap = 0, over = nil, busy = false }
local logText = ""
local owner = nil

local resetBattle -- forward declarations
local enemyTurn

local function snapshot()
	local function u(side)
		local d = units[side]
		return { x = d.x, y = d.y, hp = d.hp, en = d.en }
	end
	return {
		turn = state.turn,
		ap = state.ap,
		over = state.over,
		busy = state.busy,
		log = logText,
		cfg = {
			grid = CFG.GRID,
			moveRange = CFG.MOVE_RANGE,
			attackRange = CFG.ATTACK_RANGE,
			moveCost = CFG.MOVE_COST,
			attackCost = CFG.ATTACK_COST,
			maxHp = CFG.MAX_HP,
			maxEn = CFG.MAX_EN,
		},
		units = { player = u("player"), enemy = u("enemy") },
	}
end

local function push()
	if owner and owner.Parent then
		stateRemote:FireClient(owner, snapshot())
	end
end

local function fx(kind, mag)
	if owner and owner.Parent then
		fxRemote:FireClient(owner, kind, mag)
	end
end

local function spawnUnit(side, x, y)
	local armor, dark, glow
	if side == "player" then
		armor, dark, glow = Color3.fromRGB(92, 98, 110), Color3.fromRGB(35, 38, 45), Color3.fromRGB(0, 220, 255)
	else
		armor, dark, glow = Color3.fromRGB(112, 62, 56), Color3.fromRGB(40, 30, 30), Color3.fromRGB(255, 80, 40)
	end
	local model = buildMech(side == "player" and "PlayerMech" or "EnemyMech", armor, dark, glow)
	local pos = mechPos(x, y)
	local dir = (side == "player") and 1 or -1
	model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dir, 0, 0)))
	model.Parent = mechsFolder
	return { x = x, y = y, hp = CFG.MAX_HP, en = CFG.MAX_EN, model = model, glow = glow }
end

--------------------------------------------------------------------------
-- ANIMATION + EFFECTS
--------------------------------------------------------------------------
local function moveModel(model, targetCF, t)
	local cv = Instance.new("CFrameValue")
	cv.Value = model:GetPivot()
	local conn = cv.Changed:Connect(function(v)
		model:PivotTo(v)
	end)
	local tw = TweenService:Create(cv, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = targetCF })
	tw:Play()
	tw.Completed:Wait()
	conn:Disconnect()
	cv:Destroy()
end

local function shakeModel(model)
	local base = model:GetPivot()
	for _ = 1, 6 do
		model:PivotTo(base * CFrame.new(math.random() - 0.5, 0, math.random() - 0.5))
		task.wait(0.03)
	end
	model:PivotTo(base)
end

local function explosion(pos, color, scale)
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Size = Vector3.new(2, 2, 2) * scale
	orb.Position = pos
	orb.Parent = workspace
	TweenService:Create(orb, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(14, 14, 14) * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(orb, 1)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(pos.X, TILE_TOP + 0.3, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 22 * scale, 22 * scale),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)

	local sparks = Instance.new("Part")
	sparks.Anchored = true
	sparks.CanCollide = false
	sparks.CanQuery = false
	sparks.Transparency = 1
	sparks.Size = Vector3.new(1, 1, 1)
	sparks.Position = pos
	sparks.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(25, 50)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(1.2, 0)
	pe.LightEmission = 1
	pe.Parent = sparks
	pe:Emit(40)
	Debris:AddItem(sparks, 2)
end

--------------------------------------------------------------------------
-- ACTIONS (shared by player and AI)
--------------------------------------------------------------------------
local function doMove(side, x, y)
	local u = units[side]
	local other = units[side == "player" and "enemy" or "player"]
	if state.over or state.busy or state.ap <= 0 then
		return false
	end
	if x < 1 or y < 1 or x > CFG.GRID or y > CFG.GRID then
		return false
	end
	if x == other.x and y == other.y then
		return false
	end
	local d = manhattan(u, { x = x, y = y })
	if d < 1 or d > CFG.MOVE_RANGE then
		return false
	end
	if u.en < CFG.MOVE_COST then
		return false
	end

	state.busy = true
	state.ap -= 1
	u.en -= CFG.MOVE_COST
	local cur = u.model:GetPivot().Position
	u.x, u.y = x, y
	logText = (side == "player" and "You move" or "Enemy moves")
	push()

	local goal = mechPos(x, y)
	local dir = Vector3.new(goal.X - cur.X, 0, goal.Z - cur.Z)
	moveModel(u.model, CFrame.lookAt(goal, goal + dir), 0.6)

	state.busy = false
	push()
	return true
end

local function doAttack(side)
	local a = units[side]
	local otherSide = (side == "player") and "enemy" or "player"
	local t = units[otherSide]
	if state.over or state.busy or state.ap <= 0 then
		return false
	end
	if a.en < CFG.ATTACK_COST then
		return false
	end
	if manhattan(a, t) > CFG.ATTACK_RANGE then
		return false
	end

	state.busy = true
	state.ap -= 1
	a.en -= CFG.ATTACK_COST
	logText = (side == "player") and "You fire!" or "Enemy fires!"
	push()

	-- turn toward the target
	local apos = a.model:GetPivot().Position
	local tpos = t.model:GetPivot().Position
	moveModel(a.model, CFrame.lookAt(apos, Vector3.new(tpos.X, apos.Y, tpos.Z)), 0.25)

	-- muzzle flash + projectile
	local muzzle = (a.model:GetPivot() * CFrame.new(2.3, 0.2, -4.0)).Position
	explosion(muzzle, a.glow, 0.25)
	local proj = Instance.new("Part")
	proj.Anchored = true
	proj.CanCollide = false
	proj.CanQuery = false
	proj.Material = Enum.Material.Neon
	proj.Color = a.glow
	proj.Size = Vector3.new(0.8, 0.8, 3.5)
	proj.CFrame = CFrame.lookAt(muzzle, tpos)
	proj.Parent = workspace
	local tw = TweenService:Create(proj, TweenInfo.new(0.22, Enum.EasingStyle.Linear), { Position = tpos })
	tw:Play()
	tw.Completed:Wait()
	proj:Destroy()

	-- impact
	explosion(tpos, a.glow, 1)
	fx("hit", 1.5)
	task.spawn(shakeModel, t.model)
	t.hp = math.max(0, t.hp - CFG.DAMAGE)
	logText = (side == "player") and "Direct hit on the enemy!" or "You took a hit!"
	push()
	task.wait(0.5)

	if t.hp <= 0 then
		explosion(tpos, Color3.fromRGB(255, 200, 80), 2.5)
		fx("hit", 3)
		task.wait(0.4)
		t.model:Destroy()
		state.over = (side == "player") and "win" or "lose"
		logText = (side == "player") and "Enemy mech destroyed!" or "Your mech was destroyed..."
		state.busy = false
		push()
		task.delay(5, function()
			resetBattle()
		end)
		return true
	end

	state.busy = false
	push()
	return true
end

local function endTurn()
	if state.over then
		return
	end
	state.turn = (state.turn == "player") and "enemy" or "player"
	state.ap = CFG.ACTIONS_PER_TURN
	local u = units[state.turn]
	u.en = math.min(CFG.MAX_EN, u.en + CFG.EN_REGEN)
	logText = (state.turn == "player") and "Your turn" or "Enemy turn..."
	push()
	if state.turn == "enemy" then
		task.spawn(enemyTurn)
	end
end

--------------------------------------------------------------------------
-- SIMPLE AI: keep around 3 tiles away, shoot when in range
--------------------------------------------------------------------------
local function aiMove()
	local e, p = units.enemy, units.player
	local best = math.abs(manhattan(e, p) - 3)
	local bx, by
	for dx = -CFG.MOVE_RANGE, CFG.MOVE_RANGE do
		for dy = -CFG.MOVE_RANGE, CFG.MOVE_RANGE do
			local d = math.abs(dx) + math.abs(dy)
			if d >= 1 and d <= CFG.MOVE_RANGE then
				local nx, ny = e.x + dx, e.y + dy
				if nx >= 1 and ny >= 1 and nx <= CFG.GRID and ny <= CFG.GRID and not (nx == p.x and ny == p.y) then
					local score = math.abs(manhattan({ x = nx, y = ny }, p) - 3)
					if score < best then
						best, bx, by = score, nx, ny
					end
				end
			end
		end
	end
	if bx then
		return doMove("enemy", bx, by)
	end
	return false
end

enemyTurn = function()
	task.wait(0.9)
	while state.turn == "enemy" and not state.over and state.ap > 0 do
		local e, p = units.enemy, units.player
		local acted = false
		if manhattan(e, p) <= CFG.ATTACK_RANGE and e.en >= CFG.ATTACK_COST then
			acted = doAttack("enemy")
		elseif e.en >= CFG.MOVE_COST then
			acted = aiMove()
		end
		if not acted then
			break
		end
		task.wait(0.4)
	end
	if not state.over then
		endTurn()
	end
end

--------------------------------------------------------------------------
-- RESET / START
--------------------------------------------------------------------------
resetBattle = function()
	for _, u in pairs(units) do
		if u.model then
			u.model:Destroy()
		end
	end
	units = {
		player = spawnUnit("player", 2, 4),
		enemy = spawnUnit("enemy", 7, 5),
	}
	state = { turn = "player", ap = CFG.ACTIONS_PER_TURN, over = nil, busy = false }
	logText = "Your turn"
	push()
end

resetBattle()

--------------------------------------------------------------------------
-- NETWORK: the client only *asks*, the server decides
--------------------------------------------------------------------------
actionRemote.OnServerEvent:Connect(function(plr, kind, x, y)
	if kind == "ready" then
		if owner == nil or owner.Parent == nil then
			owner = plr
		end
		if plr == owner then
			push()
		end
		return
	end

	if plr ~= owner then
		return
	end
	if state.turn ~= "player" or state.busy or state.over then
		return
	end

	if kind == "move" then
		if typeof(x) == "number" and typeof(y) == "number" then
			doMove("player", math.floor(x), math.floor(y))
		end
	elseif kind == "attack" then
		doAttack("player")
	elseif kind == "end" then
		endTurn()
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	if plr == owner then
		owner = nil
	end
end)

remotes.Parent = ReplicatedStorage
