--!strict
-- Supermarket Empire: the street everything sits on (docs/world-brief.md). Ground, road,
-- sidewalks, the central hero tower, the tree line and backdrop that contain the space,
-- and the "bright cartoon" lighting preset. Static: built once when the server starts.
-- Trees and rocks come from the LihFolk Asset Pack when the place can load them; until
-- then (and in an unpublished place) part-built trees stand in.
-- Status: reviewed, not run in Studio.

local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("AssetIds")) :: any
local Kit = require(script.Parent:WaitForChild("Kit"))

local C = Kit.C
local Scenery = {}

Scenery.ROAD_HALF = 20 -- the road runs along X, from z = -20 to 20
Scenery.SIDEWALK = 8
Scenery.HERO_HEIGHT = 44

local rng = Random.new(20261110) -- seeded: the street looks the same on every server

local function lighting()
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.35 -- measured in Play: at 0 the white floor and walls burn out
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ShadowSoftness = 0.3
	for _, old in Lighting:GetChildren() do
		if old:IsA("Atmosphere") or old:IsA("ColorCorrectionEffect") or old:IsA("BloomEffect") then
			old:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Haze = 0.5
	atmosphere.Color = Color3.fromRGB(205, 228, 255)
	atmosphere.Decay = Color3.fromRGB(150, 190, 235)
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.08
	grade.Saturation = 0.15
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = Lighting
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.45
		clouds.Density = 0.5
		clouds.Parent = terrain
	end
end

local function road(map: Instance)
	local half = Scenery.ROAD_HALF
	Kit.block(map, "Ground", Vector3.new(620, 2, 520), CFrame.new(0, -1, 0), C.grass)
	Kit.block(map, "Road", Vector3.new(620, 0.2, half * 2), CFrame.new(0, 0.1, 0), C.asphalt)
	for _, side in { 1, -1 } do
		-- sidewalk with a curb: path surfaces are lighter and smoother than the play space
		Kit.block(map, "Sidewalk", Vector3.new(620, 0.5, Scenery.SIDEWALK), CFrame.new(0, 0.25, side * (half + Scenery.SIDEWALK / 2)), C.sidewalk)
		Kit.deco(map, "Curb", Vector3.new(620, 0.55, 0.6), CFrame.new(0, 0.275, side * (half + 0.3)), C.curb)
		Kit.deco(map, "EdgeLine", Vector3.new(620, 0.05, 0.5), CFrame.new(0, 0.22, side * (half - 1.4)), C.paint)
	end
	for x = -300, 300, 20 do
		if math.abs(x) > 26 then -- the roundabout breaks the centre line
			Kit.deco(map, "CentreLine", Vector3.new(9, 0.05, 0.7), CFrame.new(x, 0.22, 0), C.yellow)
		end
	end
	-- crosswalks between the plots: leading lines from one side of the street to the other
	for _, x in { -70, 70 } do
		for i = -4, 4 do
			Kit.deco(map, "Crosswalk", Vector3.new(7, 0.05, 2.6), CFrame.new(x, 0.23, i * 4.2), C.paint)
		end
	end
end

-- The hero: a sign tower on a planted roundabout. Twice the height of a store and the most
-- saturated thing on the street, so every plot can find the centre.
local function hero(map: Instance)
	local m = Instance.new("Model")
	m.Name = "HeroTower"
	local H = Scenery.HERO_HEIGHT
	Kit.pole(m, "Island", 30, 0.8, CFrame.new(0, 0.4, 0), C.curb, { CanCollide = true })
	Kit.pole(m, "Lawn", 27, 0.3, CFrame.new(0, 0.95, 0), C.grassDark)
	Kit.pole(m, "Plinth", 11, 2.4, CFrame.new(0, 2, 0), C.wall, { CanCollide = true, CastShadow = true })
	Kit.pole(m, "PlinthTrim", 12, 0.6, CFrame.new(0, 3.3, 0), C.trim)
	Kit.pole(m, "Mast", 3, H - 14, CFrame.new(0, 3 + (H - 14) / 2, 0), C.trim, { CanCollide = true, CastShadow = true })
	local y = H - 9
	Kit.deco(m, "BoardBack", Vector3.new(30, 13, 3), CFrame.new(0, y, 0), C.trim, { CastShadow = true })
	for _, side in { 1, -1 } do
		local face = Kit.deco(m, "Board", Vector3.new(28.6, 11.6, 0.4), CFrame.new(0, y, side * 1.6), Kit.STAGE[1])
		local title = Kit.sign(face, if side == 1 then Enum.NormalId.Back else Enum.NormalId.Front, "SUPERMARKET\nEMPIRE", C.white)
		title.TextScaled = true
	end
	Kit.deco(m, "Cap", Vector3.new(31, 1, 4), CFrame.new(0, y + 7, 0), C.lime, { Material = Enum.Material.Neon })
	Kit.ball(m, "Finial", 3.4, CFrame.new(0, H - 0.3, 0), C.yellow, { Material = Enum.Material.Neon })
	-- an odd group of bushes on the lawn, largest first
	for i, a in { 20, 140, 260 } do
		local at = CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -9.5)
		Kit.ball(m, "Bush", 5 - i * 0.6, at * CFrame.new(0, 1.4, 0), if i % 2 == 0 then C.leafLight else C.leaf)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.7, 24) -- on the sidewalk, facing the tower
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map
	m.Parent = map
end

-- Edges: a tree line and a muted backdrop behind the plots, so the street is a contained
-- place and not a slab in the void. Backdrop stays lower and greyer than the hero.
local treeSpots: { CFrame } = {}
local rockSpots: { CFrame } = {}

local function edges(map: Instance)
	local back = Instance.new("Folder")
	back.Name = "Backdrop"
	back.Parent = map
	local tones = { Color3.fromRGB(214, 206, 196), Color3.fromRGB(198, 206, 214), Color3.fromRGB(222, 212, 190), Color3.fromRGB(204, 198, 208) }
	for _, side in { 1, -1 } do
		local x = -285
		while x < 285 do
			local w = rng:NextNumber(34, 52)
			local h = rng:NextNumber(16, 26)
			local d = rng:NextNumber(26, 34)
			local z = side * (212 + d / 2)
			local tone = tones[rng:NextInteger(1, #tones)]
			Kit.deco(back, "Building", Vector3.new(w, h, d), CFrame.new(x + w / 2, h / 2, z), tone, { CastShadow = true })
			Kit.deco(back, "Roof", Vector3.new(w + 1.5, 1.2, d + 1.5), CFrame.new(x + w / 2, h + 0.6, z), C.trim)
			-- one band of windows per storey: colour only, they are background
			for storey = 1, math.floor(h / 8) do
				Kit.deco(back, "Windows", Vector3.new(w - 6, 3.2, 0.3), CFrame.new(x + w / 2, storey * 8 - 2.5, z - side * (d / 2 + 0.1)), Color3.fromRGB(150, 190, 220))
			end
			x += w + rng:NextNumber(6, 14)
		end
		-- tree line in clumps (denser at the edges), not an even row
		local tx = -280
		while tx < 280 do
			local clump = rng:NextInteger(1, 3)
			for i = 1, clump do
				local at = CFrame.new(tx + rng:NextNumber(-5, 5), 0, side * (170 + rng:NextNumber(0, 24) + i * 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				table.insert(treeSpots, at)
			end
			tx += rng:NextNumber(20, 38)
		end
	end
	-- the ends of the street: trees close the view, with a rock group at each corner
	for _, sx in { 1, -1 } do
		for z = -150, 150, 26 do
			if math.abs(z) > 36 then
				table.insert(treeSpots, CFrame.new(sx * (262 + rng:NextNumber(0, 18)), 0, z + rng:NextNumber(-6, 6)))
			end
		end
		for _, sz in { 1, -1 } do
			table.insert(rockSpots, CFrame.new(sx * 248, 0, sz * 44))
		end
	end
	-- invisible walls so nobody walks off the map
	for _, w in { { 0, 258, 620, 2 }, { 0, -258, 620, 2 }, { 308, 0, 2, 520 }, { -308, 0, 2, 520 } } do
		Kit.block(map, "Bound", Vector3.new(w[3], 60, w[4]), CFrame.new(w[1], 30, w[2]), C.white, { Transparency = 1, CanQuery = false, CastShadow = false })
	end
end

local function street(map: Instance)
	local props = Instance.new("Folder")
	props.Name = "StreetProps"
	props.Parent = map
	local z = Scenery.ROAD_HALF + Scenery.SIDEWALK - 1.2
	local lit = 0
	for _, side in { 1, -1 } do
		-- lamps on a rhythm along the street: a line that leads the eye down it
		for x = -245, 245, 70 do
			local useLight = lit < 8 and math.abs(x) < 180
			if useLight then
				lit += 1
			end
			Kit.lamp(props, CFrame.new(x + side * 17, 0.5, side * z) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0), useLight)
		end
		-- a bench, a bin and a planter at each crosswalk: one story group per node
		for _, x in { -70, 70 } do
			local at = CFrame.new(x + 9, 0.5, side * (z - 0.6)) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
			Kit.deco(props, "BenchSeat", Vector3.new(6, 0.5, 2), at * CFrame.new(0, 1.6, 0), C.wood, { CanCollide = true })
			Kit.deco(props, "BenchBack", Vector3.new(6, 1.8, 0.4), at * CFrame.new(0, 2.7, 0.9), C.wood)
			Kit.deco(props, "BenchLegL", Vector3.new(0.5, 1.4, 1.8), at * CFrame.new(-2.5, 0.7, 0), C.trim)
			Kit.deco(props, "BenchLegR", Vector3.new(0.5, 1.4, 1.8), at * CFrame.new(2.5, 0.7, 0), C.trim)
			Kit.pole(props, "Bin", 1.8, 2.6, at * CFrame.new(5, 1.3, 0.2), C.metalDark, { CanCollide = true })
			Kit.planter(props, at * CFrame.new(-5.4, 0, 0.2))
		end
	end
end

-- Swap the stand-in trees for the pack's pines, and add rocks, once the models load.
-- InsertService only loads models owned by the experience's creator, so this needs a published place.
local function placeModel(template: Model, parent: Instance, at: CFrame, height: number)
	local m = template:Clone()
	local _, size = m:GetBoundingBox()
	m:ScaleTo(height / math.max(size.Y, 0.1))
	local box, scaled = m:GetBoundingBox()
	-- stand it on the ground by its bounding box, sunk a little so nothing floats
	local bottom = box.Position - Vector3.new(0, scaled.Y / 2, 0)
	m:PivotTo(m:GetPivot() + (at.Position - Vector3.new(0, 0.3, 0) - bottom))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	m.Parent = parent
end

local function loadPack(map: Instance, standIns: Folder)
	local ids = AssetIds.Models
	if type(ids) ~= "table" then
		return
	end
	local loaded: { [string]: Model } = {}
	for name, id in ids do
		if id ~= 0 then
			local ok, result = pcall(InsertService.LoadAsset, InsertService, id)
			if ok then
				local container = result :: Model
				loaded[name] = container:FindFirstChildWhichIsA("Model") or container
			end
		end
	end
	local pines = {}
	local rocks = {}
	for name, model in loaded do
		if string.find(name, "Pine") then
			table.insert(pines, model)
		else
			table.insert(rocks, model)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "PackProps"
	folder.Parent = map
	if #pines > 0 then
		standIns:Destroy()
		for i, at in treeSpots do
			placeModel(pines[(i % #pines) + 1], folder, at, 22 + (i * 7) % 12)
		end
	end
	if #rocks > 0 then
		for i, at in rockSpots do
			-- one big, two smaller: a group, not a sprinkle
			placeModel(rocks[(i % #rocks) + 1], folder, at, 7)
			placeModel(rocks[((i + 1) % #rocks) + 1], folder, at * CFrame.new(6, 0, 3) * CFrame.Angles(0, 1.1, 0), 4)
			placeModel(rocks[((i + 2) % #rocks) + 1], folder, at * CFrame.new(-4, 0, 5) * CFrame.Angles(0, 2.3, 0), 3)
		end
	end
end

function Scenery.Build(): Folder
	local map = Instance.new("Folder")
	map.Name = "Map"
	lighting()
	road(map)
	hero(map)
	edges(map)
	street(map)
	local standIns = Instance.new("Folder")
	standIns.Name = "Trees"
	for i, at in treeSpots do
		Kit.tree(standIns, at, 1.5 + (i * 7 % 10) / 10)
	end
	standIns.Parent = map
	map.Parent = workspace
	task.spawn(loadPack, map, standIns)
	return map
end

return Scenery
