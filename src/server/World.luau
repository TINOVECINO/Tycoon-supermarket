--!strict
-- Supermarket Empire: the six plots and every store on them (docs/world-brief.md).
-- Draws a player's store from their data (stage, shelves, staff, upgrades) and runs the buy
-- pads and the register. The street itself is Scenery.luau; shared pieces are Kit.luau.
-- Plot space: -Z points at the road; the store's front wall is at z = -12 and it grows back.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("GameConfig")) :: any
local Kit = require(script.Parent:WaitForChild("Kit"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))

local World = {}

local C = Kit.C
local FRONT = -12 -- the store's front wall, in plot space
local H = 12 -- floor to eave: one storey (10-12), 2-3 avatar heights so the camera does not clip
local DOOR_W, DOOR_H = 8, 8
local PLOT_W, PLOT_D = 120, 110
local PYLON_H = 26 -- the plot's landmark: 2x the store, seen from the street and the spawn
local BOXES = 12 -- product boxes drawn on a shelf

export type Slot = {
	Index: number,
	CFrame: CFrame,
	Folder: Model,
	Owner: Player?,
	Store: Model?,
	PadFolder: Folder?,
	Shelves: { [string]: Model },
	RegisterLabel: TextLabel?,
	Register: BasePart?,
	PylonLabels: { TextLabel },
	PylonFaces: { BasePart },
	DepotLabel: TextLabel?,
	DepotStacks: { BasePart },
	SpawnConn: RBXScriptConnection?,
}

local slots: { Slot } = {}
local padHandler: ((Player, string, string) -> ())? = nil
local registerHandler: ((Player) -> ())? = nil
local staffHandler: ((Player, string) -> ())? = nil

---------------------------------------------------------------------------
-- Staff and customers share this simple body
---------------------------------------------------------------------------

local function npc(parent: Instance, name: string, cf: CFrame, shirt: Color3, title: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	local body = Kit.block(m, "Body", Vector3.new(2, 3, 1.2), cf * CFrame.new(0, 1.9, 0), shirt, { CanCollide = false, CanQuery = false })
	local head = Kit.block(m, "Head", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 4.2, 0), Color3.fromHex("F2C79E"), { CanCollide = false, CanQuery = false, Anchored = false, Massless = true, Shape = Enum.PartType.Ball })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = head
	weld.Parent = body
	m.PrimaryPart = body
	if title then
		Kit.label(Kit.billboard(head, "Title", 6, 1.2, 1.8, 50), title, 1)
	end
	m.Parent = parent
	return m
end
World.Npc = npc

---------------------------------------------------------------------------
-- Layout: where things are inside a store of a given stage
---------------------------------------------------------------------------

function World.Size(stage: number): Vector2
	return Config.Stages[stage].size
end

-- Shelf slot for a product, in plot space (x, z of the shelf's centre)
function World.ShelfXZ(stage: number, order: number): (number, number)
	-- Rows start against the back wall and come forward, so the door and the
	-- register keep a clear lobby. The left 5 studs are the customers' corridor;
	-- from the Almacén on, the right wall is kept for the fridge.
	local size = World.Size(stage)
	local left = -size.X / 2 + 5
	local right = size.X / 2 - (if stage >= 2 then 5 else 2)
	local cols = math.clamp(math.floor((right - left) / 8), 1, 5)
	local count = 0
	for _, p in Config.Products do
		if p.stage <= stage then
			count += 1
		end
	end
	local rows = math.ceil(count / cols)
	local gap = math.clamp((size.Y - 11) / rows, 7, 12)
	local row = math.floor((order - 1) / cols)
	local col = (order - 1) % cols
	local spacing = (right - left) / cols
	return left + (col + 0.5) * spacing, FRONT + size.Y - 1.6 - row * gap
end

function World.Points(stage: number): { [string]: any }
	local size = World.Size(stage)
	return {
		road = Vector3.new(0, 0, -64), -- on the sidewalk, at the foot of the entry walk
		doorOut = Vector3.new(0, 0, FRONT - 4),
		doorIn = Vector3.new(0, 0, FRONT + 3),
		corridorX = -size.X / 2 + 2,
		frontZ = FRONT + 3,
		register = Vector3.new(size.X / 2 - 7, 0, FRONT + 3),
	}
end

function World.ToWorld(slot: Slot, p: Vector3, y: number?): CFrame
	return slot.CFrame * CFrame.new(p.X, y or p.Y, p.Z)
end

---------------------------------------------------------------------------
-- Plots
---------------------------------------------------------------------------

local function setPylon(slot: Slot, top: string, bottom: string, color: Color3)
	for _, l in slot.PylonLabels do
		l.Text = top .. "\n" .. bottom
	end
	for _, f in slot.PylonFaces do
		f.Color = color
	end
end

local function buildPlot(parent: Instance, index: number, cf: CFrame): Slot
	local folder = Instance.new("Model")
	folder.Name = "Plot" .. index
	local top = cf * CFrame.new(0, 0.4, 0) -- everything on the plot is placed from the top of its base
	local function at(x: number, y: number, z: number): CFrame
		return top * CFrame.new(x, y, z)
	end
	Kit.block(folder, "Base", Vector3.new(PLOT_W, 0.4, PLOT_D), cf * CFrame.new(0, 0.2, 0), C.pad)
	Kit.deco(folder, "BaseEdge", Vector3.new(PLOT_W + 1.2, 0.3, PLOT_D + 1.2), cf * CFrame.new(0, 0.15, 0), C.curb)
	-- entry walk: sidewalk -> door. Lighter than the pad, 12 wide, kept clear of props and pads
	Kit.block(folder, "WalkOut", Vector3.new(12, 0.45, 13), cf * CFrame.new(0, 0.225, -PLOT_D / 2 - 6), C.sidewalk)
	Kit.deco(folder, "Walk", Vector3.new(12, 0.06, PLOT_D / 2 + FRONT), at(0, 0.03, (-PLOT_D / 2 + FRONT) / 2), C.sidewalk)
	for _, sx in { -1, 1 } do
		Kit.deco(folder, "WalkEdge", Vector3.new(0.5, 0.08, PLOT_D / 2 + FRONT), at(sx * 6.25, 0.04, (-PLOT_D / 2 + FRONT) / 2), C.curb)
	end
	-- hedges on three sides contain the plot; the street side stays open
	local hz = PLOT_D / 2 - 1.5
	Kit.deco(folder, "HedgeBack", Vector3.new(PLOT_W - 2, 3.4, 2.6), at(0, 1.7, hz), C.hedge, { CanCollide = true, CastShadow = true })
	for _, sx in { -1, 1 } do
		Kit.deco(folder, "HedgeSide", Vector3.new(2.6, 3.4, PLOT_D - 14), at(sx * (PLOT_W / 2 - 1.5), 1.7, 6), C.hedge, { CanCollide = true, CastShadow = true })
		Kit.ball(folder, "HedgeEnd", 4.4, at(sx * (PLOT_W / 2 - 1.5), 2.2, -PLOT_D / 2 + 13), C.leaf)
		Kit.tree(folder, at(sx * (PLOT_W / 2 - 9), 0, hz - 8), 1.25)
	end
	-- the upgrade bay, right of the walk: where the buy pads appear
	Kit.deco(folder, "Bay", Vector3.new(12, 0.06, 12), at(14, 0.03, -34), C.wallShade)
	for _, e in { { 14, -40.2, 12.6, 0.6 }, { 14, -27.8, 12.6, 0.6 }, { 8, -34, 0.6, 12 }, { 20, -34, 0.6, 12 } } do
		Kit.deco(folder, "BayLine", Vector3.new(e[3], 0.08, e[4]), at(e[1], 0.04, e[2]), C.limeDark)
	end

	-- pylon: the landmark of the plot
	local px, pz = 34, -20 -- ahead of the spawn and beside the door: in view on arrival
	Kit.pole(folder, "PylonFoot", 4, 1, at(px, 0.5, pz), C.trim, { CanCollide = true })
	Kit.pole(folder, "PylonPole", 1.6, PYLON_H - 8, at(px, (PYLON_H - 8) / 2, pz), C.trim, { CanCollide = true, CastShadow = true })
	Kit.deco(folder, "PylonBack", Vector3.new(17, 9, 1.6), at(px, PYLON_H - 4.5, pz), C.trim, { CastShadow = true })
	local labels, faces = {}, {}
	for _, side in { -1, 1 } do
		local face = Kit.deco(folder, "PylonFace", Vector3.new(16, 8, 0.3), at(px, PYLON_H - 4.5, pz + side * 0.9), C.metalDark)
		table.insert(faces, face)
		table.insert(labels, Kit.sign(face, if side == -1 then Enum.NormalId.Front else Enum.NormalId.Back, "", C.white))
	end
	folder.Parent = parent
	local slot: Slot = {
		Index = index,
		CFrame = top,
		Folder = folder,
		Owner = nil,
		Store = nil,
		PadFolder = nil,
		Shelves = {},
		RegisterLabel = nil,
		Register = nil,
		PylonLabels = labels,
		PylonFaces = faces,
		DepotLabel = nil,
		DepotStacks = {},
	}
	setPylon(slot, "EN ALQUILER", "terreno " .. index, C.metalDark)
	return slot
end

function World.Build()
	Scenery.Build()
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = workspace
	for i = 1, Config.Plots do
		local col = ((i - 1) % 3) - 1
		local side = if i <= 3 then 1 else -1
		local center = Vector3.new(col * 140, 0, side * 95)
		table.insert(slots, buildPlot(plots, i, CFrame.lookAt(center, Vector3.new(center.X, 0, 0))))
	end
end

function World.Claim(player: Player): Slot?
	for _, slot in slots do
		if slot.Owner == nil then
			slot.Owner = player
			return slot
		end
	end
	return nil
end

function World.Release(rec: any)
	local slot: Slot = rec.Slot
	if slot.SpawnConn then
		slot.SpawnConn:Disconnect()
		slot.SpawnConn = nil
	end
	if slot.Store then
		slot.Store:Destroy()
		slot.Store = nil
	end
	if slot.PadFolder then
		slot.PadFolder:Destroy()
		slot.PadFolder = nil
	end
	local customers = slot.Folder:FindFirstChild("Customers")
	if customers then
		customers:Destroy()
	end
	local trucks = slot.Folder:FindFirstChild("Trucks")
	if trucks then
		trucks:Destroy()
	end
	slot.Shelves = {}
	slot.Register = nil
	slot.RegisterLabel = nil
	slot.DepotLabel = nil
	slot.DepotStacks = {}
	slot.Owner = nil
	setPylon(slot, "EN ALQUILER", "terreno " .. slot.Index, C.metalDark)
end

-- The owner spawns on the entry walk, facing their store and its sign
function World.SpawnAt(rec: any)
	local slot: Slot = rec.Slot
	local function place(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and slot.Owner == rec.Player then
			task.wait()
			character:PivotTo(slot.CFrame * CFrame.new(0, 4, -42) * CFrame.Angles(0, math.pi, 0))
		end
	end
	slot.SpawnConn = rec.Player.CharacterAdded:Connect(place)
	if rec.Player.Character then
		task.spawn(place, rec.Player.Character)
	end
end

---------------------------------------------------------------------------
-- The store
---------------------------------------------------------------------------

local function ownerOf(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

-- A gondola: three boards of product, a header with its name, and the stock count over it
local function drawShelf(slot: Slot, store: Model, stage: number, product: any): Model
	local x, z = World.ShelfXZ(stage, product.order)
	local m = Instance.new("Model")
	m.Name = "Shelf_" .. product.id
	local function at(dx: number, y: number, dz: number): CFrame
		return World.ToWorld(slot, Vector3.new(x + dx, y, z + dz))
	end
	local base = Kit.block(m, "Base", Vector3.new(6, 0.6, 2), at(0, 0.6, 0), C.metalDark)
	Kit.deco(m, "Back", Vector3.new(6, 5, 0.3), at(0, 3.1, 0.85), C.wallShade, { CanCollide = true, CastShadow = true })
	for _, sx in { -1, 1 } do
		Kit.deco(m, "Upright", Vector3.new(0.3, 5, 2), at(sx * 3, 3.1, 0), C.metal)
	end
	local light = product.color:Lerp(C.white, 0.35)
	for level = 1, 3 do
		local y = 0.9 + (level - 1) * 1.55
		Kit.deco(m, "Board", Vector3.new(5.7, 0.18, 1.7), at(0, y, 0), C.paint)
		Kit.deco(m, "PriceStrip", Vector3.new(5.7, 0.26, 0.08), at(0, y, -0.86), C.yellow)
		for i = 1, 4 do
			local n = (level - 1) * 4 + i
			local tall = 0.9 + ((n * 7) % 4) * 0.12
			-- lower boards fill first, so a half-empty shelf empties from the top
			Kit.deco(m, "Box" .. n, Vector3.new(1.05, tall, 1.1), at(-2.1 + (i - 1) * 1.4, y + 0.09 + tall / 2, -0.05), if n % 2 == 0 then product.color else light)
		end
	end
	local header = Kit.deco(m, "Header", Vector3.new(6.2, 1.2, 0.5), at(0, 6.2, 0.7), product.color)
	Kit.sign(header, Enum.NormalId.Front, string.upper(product.name), C.white)
	local b = Kit.billboard(base, "Info", 5, 1, 7.4, 55)
	Kit.label(b, "", 1, C.lime).Name = "Stock"
	m.Parent = store
	return m
end

function World.UpdateShelf(rec: any, id: string)
	local slot: Slot = rec.Slot
	local shelf = slot.Shelves[id]
	if not shelf then
		return
	end
	local p = Config.ProductById[id]
	local cap = math.floor(p.stock * Config.Stages[rec.Data.Stage].capacity)
	local stock = rec.Data.Stock[id] or 0
	local shown = math.ceil(stock / math.max(cap, 1) * BOXES)
	for i = 1, BOXES do
		local box = shelf:FindFirstChild("Box" .. i) :: BasePart? -- lihfolk-ignore: findfirstchild-chain (checked below)
		if box then
			box.Transparency = if i <= shown then 0 else 1
		end
	end
	local base = shelf:FindFirstChild("Base")
	local info = base and base:FindFirstChild("Info")
	local stockLabel = info and info:FindFirstChild("Stock") :: TextLabel? -- lihfolk-ignore: findfirstchild-chain (checked below)
	if stockLabel then
		stockLabel.Text = if stock == 0 then "¡SIN STOCK!" else stock .. "/" .. cap
		stockLabel.TextColor3 = if stock == 0 then C.red else C.lime
	end
end

function World.UpdateRegister(rec: any)
	local slot: Slot = rec.Slot
	if slot.RegisterLabel then
		slot.RegisterLabel.Text = "$" .. rec.Data.Register
	end
end

-- a "+$12" that rises from the register
function World.Pop(rec: any, text: string)
	local slot: Slot = rec.Slot
	if not slot.Register then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Adornee = slot.Register
	b.Size = UDim2.fromScale(4, 1.2)
	b.StudsOffset = Vector3.new(0, 4, 0)
	b.LightInfluence = 0
	b.MaxDistance = 60
	local l = Kit.label(b, text, 1, C.lime)
	b.Parent = slot.Register
	TweenService:Create(b, TweenInfo.new(1.1), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.1), { TextTransparency = 1 }):Play()
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	end
	task.delay(1.2, function()
		b:Destroy()
	end)
end

local function drawShell(slot: Slot, store: Model, data: any, size: Vector2, color: Color3)
	local W, D = size.X, size.Y
	local mid = FRONT + D / 2
	local back = FRONT + D
	local function at(x: number, y: number, z: number): CFrame
		return World.ToWorld(slot, Vector3.new(x, y, z))
	end
	-- floor: one slab to stand on, with every other tile tinted so the flat does not read as empty
	Kit.block(store, "Floor", Vector3.new(W, 0.3, D), at(0, 0.15, mid), C.tileA)
	local nx, nz = math.max(1, math.round(W / 6)), math.max(1, math.round(D / 6))
	local tw, td = W / nx, D / nz
	for i = 1, nx do
		for j = 1, nz do
			if (i + j) % 2 == 0 then
				Kit.deco(store, "Tile", Vector3.new(tw, 0.04, td), at(-W / 2 + (i - 0.5) * tw, 0.32, FRONT + (j - 0.5) * td), C.tileB)
			end
		end
	end
	Kit.deco(store, "Mat", Vector3.new(DOOR_W - 1, 0.06, 4), at(0, 0.34, FRONT - 0.5), C.trim)

	-- walls: cream body, a band in the stage colour, a dark cap. Two storeys of colour read from the street
	local band = 3
	local function wall(name: string, sx: number, sz: number, cx: number, cz: number)
		Kit.block(store, name, Vector3.new(sx, H - band, sz), at(cx, (H - band) / 2, cz), C.wall)
		Kit.block(store, name .. "Band", Vector3.new(sx, band, sz), at(cx, H - band / 2, cz), color)
		Kit.deco(store, name .. "Cap", Vector3.new(sx + 0.6, 0.6, sz + 0.6), at(cx, H + 0.3, cz), C.trim)
		Kit.deco(store, name .. "Skirt", Vector3.new(sx + 0.3, 1, sz + 0.3), at(cx, 0.5, cz), C.trim)
	end
	wall("WallBack", W, 1, 0, back)
	wall("WallLeft", 1, D, -W / 2, mid)
	wall("WallRight", 1, D, W / 2, mid)
	-- pilasters break the long side walls into bays
	for _, sx in { -1, 1 } do
		local n = math.max(1, math.floor(D / 14))
		for i = 0, n do
			Kit.deco(store, "Pilaster", Vector3.new(0.8, H, 1.4), at(sx * (W / 2 + 0.5), H / 2, FRONT + i * (D / n)), C.wallShade)
		end
	end

	-- storefront: sill, glass with mullions, the band, and the door opening
	local side = (W - DOOR_W) / 2
	for _, sx in { -1, 1 } do
		local cx = sx * (DOOR_W / 2 + side / 2)
		Kit.block(store, "Sill", Vector3.new(side, 3, 1), at(cx, 1.5, FRONT), C.wall)
		Kit.block(store, "Glass", Vector3.new(side, H - band - 3, 0.4), at(cx, 3 + (H - band - 3) / 2, FRONT), C.glass, { Material = Enum.Material.Glass, Transparency = 0.55, CastShadow = false })
		Kit.block(store, "FrontBand", Vector3.new(side, band, 1), at(cx, H - band / 2, FRONT), color)
		Kit.deco(store, "SillCap", Vector3.new(side, 0.3, 1.5), at(cx, 3.1, FRONT - 0.1), C.trim)
		local n = math.max(1, math.round(side / 5))
		for i = 0, n do
			Kit.deco(store, "Mullion", Vector3.new(0.5, H - band - 3, 0.7), at(sx * (DOOR_W / 2 + i * (side / n)), 3 + (H - band - 3) / 2, FRONT), C.trim)
		end
		Kit.deco(store, "Corner", Vector3.new(1.6, H + 0.6, 1.6), at(sx * W / 2, (H + 0.6) / 2, FRONT), C.trim, { CastShadow = true })
		Kit.deco(store, "DoorFrame", Vector3.new(0.6, DOOR_H, 1.3), at(sx * DOOR_W / 2, DOOR_H / 2, FRONT), C.metal)
	end
	Kit.block(store, "Lintel", Vector3.new(DOOR_W, H - band - DOOR_H, 1), at(0, DOOR_H + (H - band - DOOR_H) / 2, FRONT), C.wall)
	Kit.block(store, "DoorBand", Vector3.new(DOOR_W, band, 1), at(0, H - band / 2, FRONT), color)
	Kit.deco(store, "FrontCap", Vector3.new(W + 0.6, 0.6, 1.6), at(0, H + 0.3, FRONT), C.trim)

	-- name on the band, over the door: the sign is part of the building
	local board = Kit.deco(store, "NameBoard", Vector3.new(math.min(W - 3, 24), band - 0.5, 0.3), at(0, H - band / 2, FRONT - 0.6), color)
	local stageName = Config.Stages[data.Stage].name
	Kit.sign(board, Enum.NormalId.Front, string.upper(stageName), C.white)

	-- open top with beams and light panels: reads as a roof from the street, never hides the inside
	local beams = math.max(2, math.floor(D / 10))
	for i = 1, beams do
		local z = FRONT + i * (D / (beams + 1))
		Kit.deco(store, "Beam", Vector3.new(W, 0.5, 0.7), at(0, H - 0.6, z), C.metalDark)
	end
end

local function drawRegister(slot: Slot, store: Model, size: Vector2)
	local x, z = size.X / 2 - 4, FRONT + 3
	local function at(dx: number, y: number, dz: number): CFrame
		return World.ToWorld(slot, Vector3.new(x + dx, y, z + dz))
	end
	local counter = Kit.block(store, "Register", Vector3.new(2.4, 2.8, 6), at(0, 1.7, 0), C.trim)
	Kit.deco(store, "CounterTop", Vector3.new(2.7, 0.25, 6.3), at(0, 3.2, 0), C.paint)
	Kit.deco(store, "Belt", Vector3.new(1.6, 0.1, 3.4), at(0, 3.36, 1.1), C.asphaltDark)
	Kit.deco(store, "Till", Vector3.new(1.5, 0.9, 1.3), at(0.2, 3.8, -1.7), C.metalDark)
	-- the one saturated thing on the counter: where the money is
	Kit.deco(store, "Screen", Vector3.new(1.1, 0.9, 0.2), at(0.2, 4.7, -1.7) * CFrame.Angles(math.rad(-12), 0, 0), C.lime, { Material = Enum.Material.Neon })
	Kit.pole(store, "LanePole", 0.3, 4.4, at(1, 5.5, -2.7), C.metal)
	local lane = Kit.deco(store, "LaneSign", Vector3.new(2.4, 1.3, 0.3), at(1, 8.2, -2.7), C.limeDark)
	Kit.sign(lane, Enum.NormalId.Front, "CAJA", C.white)
	local b = Kit.billboard(counter, "Cash", 5, 1.3, 5.2, 80)
	local amount = Kit.label(b, "$0", 1, C.lime)
	slot.Register = counter
	slot.RegisterLabel = amount
	local busy = false
	counter.Touched:Connect(function(hit: BasePart)
		local player = ownerOf(hit)
		if busy or not player or player ~= slot.Owner or not registerHandler then
			return
		end
		busy = true
		registerHandler(player)
		task.delay(0.5, function()
			busy = false
		end)
	end)
end

-- The small upgrades ("mini compras"): each one bought adds its own thing to the storefront.
local function drawExtras(slot: Slot, store: Model, data: any, size: Vector2, color: Color3)
	local W, D = size.X, size.Y
	local has = data.Extras
	local function at(x: number, y: number, z: number): CFrame
		return World.ToWorld(slot, Vector3.new(x, y, z))
	end
	-- a delivery waiting at the side wall: the store's one story group from day one
	Kit.boxes(store, at(W / 2 + 4.5, 0, FRONT + 5))
	if has.maceteros then
		for _, sx in { -1, 1 } do
			Kit.planter(store, at(sx * (DOOR_W / 2 + 3), 0, FRONT - 2.6))
		end
	end
	if has.tacho then
		Kit.pole(store, "Bin", 1.8, 2.6, at(-10.4, 1.3, FRONT - 1.8), C.metalDark, { CanCollide = true })
		Kit.pole(store, "BinLid", 2, 0.3, at(-10.4, 2.75, FRONT - 1.8), C.trim)
	end
	if has.farol1 then
		Kit.lamp(store, at(-7.6, 0, -30) * CFrame.Angles(0, -math.pi / 2, 0), false)
	end
	if has.farol2 then
		Kit.lamp(store, at(-7.6, 0, -48) * CFrame.Angles(0, -math.pi / 2, 0), false)
	end
	if has.pizarra then
		for _, tilt in { -1, 1 } do
			local panel = Kit.deco(store, "Pizarra", Vector3.new(3, 4, 0.25), at(7.6, 2, -21.5 + tilt * 0.7) * CFrame.Angles(math.rad(tilt * 14), 0, 0), C.wood, { CastShadow = true })
			if tilt == -1 then
				Kit.sign(panel, Enum.NormalId.Front, "OFERTAS\nHOY", C.white)
			end
		end
	end
	if has.toldo then
		-- striped awning over the storefront, lower at the street edge
		local n = math.max(2, math.round(W / 3))
		local sw = W / n
		for i = 1, n do
			local stripe = if i % 2 == 0 then C.paint else color
			Kit.deco(store, "Awning", Vector3.new(sw, 0.3, 4.6), at(-W / 2 + (i - 0.5) * sw, H - 3.4, FRONT - 2.4) * CFrame.Angles(math.rad(-16), 0, 0), stripe, { CastShadow = true })
		end
	end
	if has.carritos then
		local x = math.min(W / 2 - 3, DOOR_W / 2 + 8)
		Kit.cart(store, at(x, 0, FRONT - 3.2) * CFrame.Angles(0, math.rad(90), 0), color)
		Kit.cart(store, at(x + 0.4, 0, FRONT - 5.6) * CFrame.Angles(0, math.rad(84), 0), color)
		Kit.cart(store, at(x - 3.4, 0, FRONT - 6.4) * CFrame.Angles(0, math.rad(40), 0), color)
	end
	if has.banco then
		Kit.deco(store, "BenchSeat", Vector3.new(6, 0.5, 2), at(-15.6, 1.6, FRONT - 2.2), C.wood, { CanCollide = true })
		Kit.deco(store, "BenchBack", Vector3.new(6, 1.8, 0.4), at(-15.6, 2.7, FRONT - 1.3), C.wood)
		for _, dx in { -2.5, 2.5 } do
			Kit.deco(store, "BenchLeg", Vector3.new(0.5, 1.4, 1.8), at(-15.6 + dx, 0.7, FRONT - 2.2), C.trim)
		end
	end
	if has.luces then
		local beams = math.max(2, math.floor(D / 10))
		for i = 1, beams do
			local z = FRONT + i * (D / (beams + 1))
			local lamps = math.max(1, math.floor(W / 14))
			for j = 1, lamps do
				Kit.deco(store, "LightPanel", Vector3.new(4, 0.2, 1.2), at(-W / 2 + j * (W / (lamps + 1)), H - 1, z), C.paint, { Material = Enum.Material.Neon })
			end
		end
	end
	if has.banderines then
		local flags = { Kit.STAGE[4], C.yellow, Kit.STAGE[2], Kit.STAGE[3], Kit.STAGE[5] }
		for _, sx in { -1, 1 } do
			Kit.pole(store, "FlagPole", 0.4, 9.6, at(sx * 6.6, 4.8, -26), C.trim)
		end
		Kit.deco(store, "FlagLine", Vector3.new(13.2, 0.12, 0.12), at(0, 9.3, -26), C.trim)
		for i = 1, 9 do
			Kit.deco(store, "Flag", Vector3.new(0.9, 0.9, 0.08), at(-6.6 + i * 1.32, 8.7, -26) * CFrame.Angles(0, 0, math.rad(45)), flags[(i % #flags) + 1])
		end
	end
	if has.expendedora then
		local x = W / 2 - 2.6
		Kit.deco(store, "Vending", Vector3.new(3, 6.4, 2.2), at(x, 3.2, FRONT - 1.7), Kit.STAGE[4], { CanCollide = true, CastShadow = true })
		Kit.deco(store, "VendingGlass", Vector3.new(1.9, 3.6, 0.15), at(x - 0.35, 4.1, FRONT - 2.85), C.glass, { Material = Enum.Material.Neon })
		Kit.deco(store, "VendingSlot", Vector3.new(1.9, 0.7, 0.15), at(x - 0.35, 1.2, FRONT - 2.85), C.trim)
	end
	if has.bicicletero then
		for i = 0, 3 do
			Kit.deco(store, "RackLoop", Vector3.new(0.25, 2.2, 2.2), at(12.5 + i * 1.6, 1.1, -21), C.metal)
		end
		Kit.pole(store, "BikeWheelA", 2, 0.25, at(13.3, 1, -22) * CFrame.Angles(0, 0, math.rad(90)), C.trim)
		Kit.pole(store, "BikeWheelB", 2, 0.25, at(13.3, 1, -19.6) * CFrame.Angles(0, 0, math.rad(90)), C.trim)
		Kit.deco(store, "BikeFrame", Vector3.new(0.25, 0.25, 2.6), at(13.3, 1.9, -20.8), Kit.STAGE[2])
	end
	if has.camaras then
		for _, sx in { -1, 1 } do
			Kit.deco(store, "Camera", Vector3.new(0.7, 0.7, 1.6), at(sx * (W / 2 - 1.5), H - 1.2, FRONT - 1.3) * CFrame.Angles(math.rad(-20), 0, 0), C.paint)
			Kit.deco(store, "CameraLens", Vector3.new(0.4, 0.4, 0.2), at(sx * (W / 2 - 1.5), H - 1.5, FRONT - 2.1), C.trim)
		end
	end
	if has.parlantes then
		for _, sx in { -1, 1 } do
			Kit.deco(store, "Speaker", Vector3.new(1.6, 2.4, 1.2), at(sx * (DOOR_W / 2 + 1.6), H - 4.6, FRONT - 1.1), C.trim)
			Kit.pole(store, "SpeakerCone", 1.1, 0.2, at(sx * (DOOR_W / 2 + 1.6), H - 4.6, FRONT - 1.75) * CFrame.Angles(math.rad(90), 0, 0), C.metal)
		end
	end
	if has.fuente then
		local x, z = 50, -13
		Kit.pole(store, "FountainBase", 10, 1.2, at(x, 0.6, z), C.curb, { CanCollide = true })
		Kit.pole(store, "FountainWater", 8.6, 0.3, at(x, 1.25, z), C.glass, { Material = Enum.Material.Glass, Transparency = 0.2 })
		Kit.pole(store, "FountainStem", 1.4, 3.4, at(x, 2.8, z), C.wall)
		Kit.pole(store, "FountainBowl", 4, 0.6, at(x, 4.6, z), C.curb)
		Kit.ball(store, "FountainJet", 1.6, at(x, 5.6, z), C.glass, { Material = Enum.Material.Glass, Transparency = 0.3 })
	end
	if has.inflable then
		local x, z = -W / 4, FRONT + D / 2
		Kit.pole(store, "BalloonRope", 0.15, 9, at(x, H + 4.5, z), C.trim)
		Kit.ball(store, "Balloon", 8, at(x, H + 12, z), Kit.STAGE[4], { CastShadow = true })
		Kit.pole(store, "BalloonBand", 8.1, 1.4, at(x, H + 12, z), C.yellow)
	end
end

---------------------------------------------------------------------------
-- Depot and trucks. The depot stands left of the store, clear of every stage's footprint;
-- trucks come up the lane from the street, dock nose-in, unload and back out.
---------------------------------------------------------------------------

local DEPOT_X, DEPOT_Z = -49, 12 -- centre line and front wall of the depot
local DEPOT_W, DEPOT_H = 16, 10

function World.UpdateDepot(rec: any)
	local slot: Slot = rec.Slot
	local depot = rec.Data.Depot
	local level = Config.Depot.levels[depot.Level]
	if not level then
		return
	end
	if slot.DepotLabel then
		slot.DepotLabel.Text = depot.Boxes .. "/" .. level.cap .. " cajas"
	end
	local shown = math.ceil(depot.Boxes / level.cap * #slot.DepotStacks)
	for i, crate in slot.DepotStacks do
		crate.Transparency = if i <= shown then 0 else 1
	end
end

local function drawDepot(slot: Slot, store: Model, data: any, color: Color3)
	slot.DepotLabel = nil
	slot.DepotStacks = {}
	if data.Depot.Level == 0 then
		return
	end
	local depth = 22 + (data.Depot.Level - 1) * 3
	local mid = DEPOT_Z + depth / 2
	local function at(dx: number, y: number, z: number): CFrame
		return World.ToWorld(slot, Vector3.new(DEPOT_X + dx, y, z))
	end
	-- the lane: asphalt from the street to the dock, with painted edges
	Kit.block(store, "LaneOut", Vector3.new(9, 0.45, 13), at(0, -0.175, -61), C.asphalt)
	Kit.deco(store, "Lane", Vector3.new(9, 0.07, 67), at(0, 0.035, -21.5), C.asphalt)
	for _, sx in { -1, 1 } do
		Kit.deco(store, "LaneEdge", Vector3.new(0.4, 0.09, 67), at(sx * 4.3, 0.045, -21.5), C.yellow)
	end
	for i = 0, 4 do
		Kit.deco(store, "DockStripe", Vector3.new(1.4, 0.1, 2.4), at(-3.6 + i * 1.8, 0.05, DEPOT_Z - 1.6) * CFrame.Angles(0, math.rad(35), 0), C.yellow)
	end
	-- the shed
	Kit.block(store, "DepotFloor", Vector3.new(DEPOT_W, 0.3, depth), at(0, 0.15, mid), C.curb)
	Kit.block(store, "DepotBack", Vector3.new(DEPOT_W, DEPOT_H, 1), at(0, DEPOT_H / 2, DEPOT_Z + depth), C.metal)
	for _, sx in { -1, 1 } do
		Kit.block(store, "DepotSide", Vector3.new(1, DEPOT_H, depth), at(sx * DEPOT_W / 2, DEPOT_H / 2, mid), C.metal)
		Kit.block(store, "DepotJamb", Vector3.new(3, DEPOT_H, 1), at(sx * (DEPOT_W / 2 - 1.5), DEPOT_H / 2, DEPOT_Z), C.metal)
		Kit.deco(store, "DepotPost", Vector3.new(0.7, 8, 1.3), at(sx * 5.2, 4, DEPOT_Z), C.yellow)
		-- ribs: the sheet-metal look, in colour only
		local ribs = math.floor(depth / 4)
		for i = 1, ribs do
			Kit.deco(store, "DepotRib", Vector3.new(0.3, DEPOT_H, 0.5), at(sx * (DEPOT_W / 2 + 0.55), DEPOT_H / 2, DEPOT_Z + i * (depth / (ribs + 1))), C.metalDark)
		end
	end
	local lintel = Kit.block(store, "DepotLintel", Vector3.new(10, DEPOT_H - 8, 1), at(0, 8 + (DEPOT_H - 8) / 2, DEPOT_Z), color)
	Kit.sign(lintel, Enum.NormalId.Front, "DEPÓSITO", C.white)
	Kit.deco(store, "DepotRoof", Vector3.new(DEPOT_W + 1.4, 0.8, depth + 1.4), at(0, DEPOT_H + 0.4, mid), C.trim, { CastShadow = true })
	Kit.deco(store, "DepotDoorRoll", Vector3.new(10, 0.9, 0.9), at(0, 7.7, DEPOT_Z + 0.3), C.metalDark)
	-- crates inside, seen through the door: they appear as the depot fills
	local n = 0
	for row = 0, 2 do
		for col = -1, 1 do
			n += 1
			local tall = 2.6 + (n % 3) * 0.9
			local crate = Kit.deco(store, "DepotCrate", Vector3.new(3.6, tall, 3.6), at(col * 4.4, 0.3 + tall / 2, DEPOT_Z + 4 + row * 5), C.cardboard:Lerp(if n % 2 == 0 then C.black else C.white, 0.08))
			table.insert(slot.DepotStacks, crate)
		end
	end
	local b = Kit.billboard(lintel, "Cajas", 9, 1.2, 3.2, 110)
	slot.DepotLabel = Kit.label(b, "", 1, C.white)
end

local function weldTo(root: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

-- A truck facing +Z (toward the depot), built around its cargo box. index 1-3 = bigger trucks.
local function buildTruck(parent: Instance, cf: CFrame, index: number, color: Color3): (Model, BasePart, number)
	local m = Instance.new("Model")
	m.Name = "Truck" .. index
	local cargo = ({ 6, 10, 9 })[index]
	local width = ({ 4.6, 5.4, 5.6 })[index]
	local tall = ({ 4.4, 6, 6.4 })[index]
	local length = cargo + 4.2 + (if index == 3 then 11 else 0)
	local nose = length / 2 -- the root sits at the middle of the whole truck
	local root = Kit.deco(m, "Root", Vector3.new(1, 1, 1), cf * CFrame.new(0, 1.5, 0), C.trim, { Transparency = 1 })
	local function add(name: string, size: Vector3, offset: Vector3, c: Color3, props: { [string]: any }?): Part
		local part = Kit.deco(m, name, size, cf * CFrame.new(offset), c, props)
		weldTo(root, part)
		return part
	end
	local function wheels(z: number)
		for _, sx in { -1, 1 } do
			local w = Kit.pole(m, "Wheel", 1.9, 0.9, cf * CFrame.new(sx * (width / 2 - 0.2), 0.95, z) * CFrame.Angles(0, 0, math.rad(90)), C.trim)
			weldTo(root, w)
		end
	end
	-- cab at the nose
	local cabZ = nose - 2
	add("Cab", Vector3.new(width, 3.6, 3.8), Vector3.new(0, 3.1, cabZ), color, { CastShadow = true })
	add("Windshield", Vector3.new(width - 0.6, 1.5, 0.2), Vector3.new(0, 3.9, cabZ + 1.95), C.glass)
	add("Bumper", Vector3.new(width + 0.2, 0.7, 0.5), Vector3.new(0, 1.4, nose + 0.1), C.metalDark)
	for _, sx in { -1, 1 } do
		add("Headlight", Vector3.new(0.8, 0.5, 0.2), Vector3.new(sx * (width / 2 - 0.7), 2, nose - 0.05), C.yellow, { Material = Enum.Material.Neon })
	end
	wheels(cabZ)
	-- cargo box behind the cab
	local boxZ = nose - 4.2 - cargo / 2
	add("Chassis", Vector3.new(width - 1, 0.5, cargo + 3), Vector3.new(0, 1.5, boxZ + 1), C.metalDark)
	add("Cargo", Vector3.new(width + 0.2, tall, cargo), Vector3.new(0, 1.8 + tall / 2, boxZ), C.paint, { CastShadow = true })
	add("CargoStripe", Vector3.new(width + 0.3, 1, cargo + 0.05), Vector3.new(0, 1.8 + tall * 0.42, boxZ), color)
	wheels(boxZ - cargo / 2 + 1.6)
	if index >= 2 then
		wheels(boxZ - cargo / 2 + 3.8)
	end
	if index == 3 then
		local trailerZ = boxZ - cargo / 2 - 1.5 - 4.75
		add("Hitch", Vector3.new(0.5, 0.4, 2), Vector3.new(0, 1.5, boxZ - cargo / 2 - 0.9), C.metalDark)
		add("Trailer", Vector3.new(width + 0.2, tall, 9.5), Vector3.new(0, 1.8 + tall / 2, trailerZ), C.paint, { CastShadow = true })
		add("TrailerStripe", Vector3.new(width + 0.3, 1, 9.55), Vector3.new(0, 1.8 + tall * 0.42, trailerZ), color)
		wheels(trailerZ + 3)
		wheels(trailerZ - 3)
	end
	m.PrimaryPart = root
	m.Parent = parent
	return m, root, length
end

-- One delivery: drive in, dock (onDock adds the boxes), back out. Yields until the truck is gone.
function World.TruckRun(rec: any, index: number, onDock: () -> ())
	local slot: Slot = rec.Slot
	local folder = slot.Folder:FindFirstChild("Trucks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Trucks"
		folder.Parent = slot.Folder
	end
	local color = Kit.STAGE[rec.Data.Stage]
	local start = World.ToWorld(slot, Vector3.new(DEPOT_X, 0, -88))
	local model, root, length = buildTruck(folder, start, index, color)
	local dock = World.ToWorld(slot, Vector3.new(DEPOT_X, 1.5, DEPOT_Z - 2 - length / 2))
	local home = root.CFrame
	local drive = TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(root, drive, { CFrame = dock }):Play()
	task.wait(5)
	onDock()
	task.wait(3)
	if root.Parent then
		TweenService:Create(root, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = home }):Play()
		task.wait(5)
	end
	model:Destroy()
end

local function car(parent: Instance, cf: CFrame, color: Color3)
	Kit.deco(parent, "CarBody", Vector3.new(5, 1.8, 10), cf * CFrame.new(0, 1.6, 0), color, { CanCollide = true, CastShadow = true })
	Kit.deco(parent, "CarCabin", Vector3.new(4.4, 1.6, 5), cf * CFrame.new(0, 3.2, 0.6), C.glass)
	Kit.deco(parent, "CarRoof", Vector3.new(4.6, 0.3, 5.2), cf * CFrame.new(0, 4.1, 0.6), color)
	for _, o in { Vector3.new(-2.5, 0.8, -3), Vector3.new(2.5, 0.8, -3), Vector3.new(-2.5, 0.8, 3), Vector3.new(2.5, 0.8, 3) } do
		Kit.pole(parent, "Wheel", 1.6, 0.8, cf * CFrame.new(o) * CFrame.Angles(0, 0, math.rad(90)), C.trim)
	end
end

local function drawDecor(slot: Slot, store: Model, data: any, size: Vector2, color: Color3)
	local W, D = size.X, size.Y
	local back = FRONT + D
	local function at(x: number, y: number, z: number): CFrame
		return World.ToWorld(slot, Vector3.new(x, y, z))
	end
	if data.Decor.cartel then
		Kit.deco(store, "CartelFrame", Vector3.new(15, 4, 0.8), at(0, H + 2.8, FRONT), C.trim, { CastShadow = true })
		local sign = Kit.deco(store, "Cartel", Vector3.new(14, 3.2, 0.3), at(0, H + 2.8, FRONT - 0.5), C.yellow, { Material = Enum.Material.Neon })
		Kit.sign(sign, Enum.NormalId.Front, "¡ABIERTO!", C.red)
		for _, sx in { -1, 1 } do
			Kit.deco(store, "CartelLeg", Vector3.new(0.5, 1.4, 0.5), at(sx * 6, H + 0.9, FRONT), C.trim)
		end
	end
	if data.Decor.heladera then
		-- against the right wall, facing the aisles
		local x, z = W / 2 - 1.7, FRONT + D * 0.62
		Kit.deco(store, "FridgeBody", Vector3.new(2, 7, 8), at(x, 3.8, z), C.metal, { CanCollide = true, CastShadow = true })
		Kit.deco(store, "FridgeGlass", Vector3.new(0.2, 5.6, 7.2), at(x - 1.05, 4, z), C.glass, { Material = Enum.Material.Glass, Transparency = 0.45 })
		Kit.deco(store, "FridgeGlow", Vector3.new(1.2, 0.3, 7.2), at(x - 0.4, 7, z), C.paint, { Material = Enum.Material.Neon })
		for i = 1, 3 do
			Kit.deco(store, "FridgeShelf", Vector3.new(1.4, 0.15, 7.2), at(x - 0.3, 1.2 + i * 1.5, z), C.paint)
		end
	end
	if data.Decor.aire then
		for _, dx in { -5, 5 } do
			Kit.deco(store, "AirUnit", Vector3.new(5, 2.6, 3.4), at(dx, H + 1.9, back - 3), C.metal, { CastShadow = true })
			Kit.pole(store, "AirFan", 2.4, 0.3, at(dx, H + 3.3, back - 3), C.metalDark)
		end
	end
	if data.Decor.estacionamiento then
		-- in front of the store, left of the entry walk: clear of every stage's footprint
		Kit.deco(store, "Lot", Vector3.new(33, 0.08, 30), at(-25.5, 0.04, -33), C.asphalt)
		for i = 0, 4 do
			Kit.deco(store, "LotLine", Vector3.new(0.5, 0.05, 13), at(-41 + i * 7.6, 0.1, -26), C.paint)
		end
		car(store, at(-37.2, 0, -26.5), Color3.fromHex("0A9CF0"))
		car(store, at(-22, 0, -27.5), Color3.fromHex("FF2A1A"))
	end
	if data.Decor.escaleras then
		Kit.deco(store, "Mezzanine", Vector3.new(W - 2, 0.8, 10), at(0, 7.6, back - 5.5), C.wallShade, { CastShadow = true })
		Kit.deco(store, "MezzRail", Vector3.new(W - 2, 2.4, 0.3), at(0, 9.2, back - 10.4), C.glass, { Material = Enum.Material.Glass, Transparency = 0.5 })
		local run = 17
		Kit.deco(store, "Escalator", Vector3.new(5, 0.8, run + 1.4), at(W / 2 - 4, 3.9, back - 10.5 - run / 2) * CFrame.Angles(math.rad(25), 0, 0), C.metalDark, { Material = Enum.Material.DiamondPlate, CastShadow = true })
		for _, dx in { -2.5, 2.5 } do
			Kit.deco(store, "EscalatorRail", Vector3.new(0.4, 2.4, run + 1.4), at(W / 2 - 4 + dx, 5.4, back - 10.5 - run / 2) * CFrame.Angles(math.rad(25), 0, 0), color)
		end
	end
end

local STAFF_LOOK = {
	cajero = { who = "Lucía", shirt = "0A9CF0" },
	repositor = { who = "Tito", shirt = "FF8A00" },
	promotor = { who = "Maru", shirt = "FF2BD6" },
	gerente = { who = "Don Rubén", shirt = "1A1A1A" },
}

-- Each post is hired and trained on the spot: hold E at the "SE BUSCA" stand to hire,
-- and at the employee to train them to the next level.
local function drawStaff(slot: Slot, store: Model, data: any, size: Vector2)
	local posts = {
		cajero = World.ToWorld(slot, Vector3.new(size.X / 2 - 1.8, 0, FRONT + 3)) * CFrame.Angles(0, math.pi / 2, 0),
		repositor = World.ToWorld(slot, Vector3.new(-size.X / 2 + 2, 0, FRONT + size.Y - 3)),
		promotor = World.ToWorld(slot, Vector3.new(-9, 0, FRONT - 7)) * CFrame.Angles(0, math.pi, 0),
		gerente = World.ToWorld(slot, Vector3.new(size.X / 2 - 3, 0, FRONT + 9)) * CFrame.Angles(0, math.pi / 2, 0),
	}
	for _, def in Config.Staff do
		local level = data.Staff[def.id] or 0
		local look = STAFF_LOOK[def.id]
		local cf = posts[def.id]
		local price = def.prices[level + 1]
		local anchor: BasePart
		if level > 0 then
			local m = npc(store, def.name, cf, Color3.fromHex(look.shirt), nil)
			anchor = m.PrimaryPart :: BasePart
			local b = Kit.billboard(anchor, "Title", 7, 1.8, 4.4, 60)
			Kit.label(b, look.who .. " · " .. def.name, 0.5)
			Kit.label(b, if price then "NIVEL " .. level else "NIVEL MÁX", 0.5, C.yellow)
		else
			Kit.pole(store, "VacancyPole", 0.3, 4, cf * CFrame.new(0, 2, 0), C.metal)
			anchor = Kit.deco(store, "Vacancy", Vector3.new(3.2, 1.6, 0.25), cf * CFrame.new(0, 4.6, 0), C.wood)
			Kit.sign(anchor, Enum.NormalId.Front, "SE BUSCA
" .. string.upper(def.name), C.white)
			Kit.sign(anchor, Enum.NormalId.Back, "SE BUSCA
" .. string.upper(def.name), C.white)
		end
		if price then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = (if level > 0 then "Capacitar $" else "Contratar $") .. price
			prompt.ObjectText = if level > 0 then def.name .. " · " .. def.levelText[level] else def.desc
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function(player: Player)
				if player == slot.Owner and staffHandler then
					staffHandler(player, def.id)
				end
			end)
			prompt.Parent = anchor
		end
	end
end

-- Rebuilds the store from data. Called on load and after any purchase that changes how it looks.
function World.Render(rec: any)
	local slot: Slot = rec.Slot
	local data = rec.Data
	if slot.Store then
		slot.Store:Destroy()
	end
	slot.Shelves = {}
	local store = Instance.new("Model")
	store.Name = "Store"
	local size = World.Size(data.Stage)
	local color = Kit.STAGE[data.Stage]
	drawShell(slot, store, data, size, color)
	drawRegister(slot, store, size)
	for _, p in Config.Products do
		if data.Unlocked[p.id] then
			slot.Shelves[p.id] = drawShelf(slot, store, data.Stage, p)
		end
	end
	drawExtras(slot, store, data, size, color)
	drawDepot(slot, store, data, color)
	drawDecor(slot, store, data, size, color)
	drawStaff(slot, store, data, size)
	store.Parent = slot.Folder
	slot.Store = store
	for id in slot.Shelves do
		World.UpdateShelf(rec, id)
	end
	World.UpdateRegister(rec)
	World.UpdateDepot(rec)
	local stageName = string.upper(Config.Stages[data.Stage].name)
	local branch = if data.Branches > 0 then " · SUC. " .. (data.Branches + 1) else ""
	setPylon(slot, stageName .. branch, "de " .. rec.Player.DisplayName, color)
end

-- Where a buy pad stands: on the spot the thing will appear, so the plot fills in
-- under the player's feet. Only "Ampliar" keeps the big pad in the bay by the walk.
local function padSpot(stage: number, pad: any): (number, number)
	local size = World.Size(stage)
	local W, D = size.X, size.Y
	if pad.kind == "product" then
		local x, z = World.ShelfXZ(stage, Config.ProductById[pad.id].order)
		return x, z - 3.5
	elseif pad.kind == "depot" then
		return DEPOT_X, DEPOT_Z - 6
	elseif pad.kind == "stage" then
		return 14, -34
	end
	local spots: { [string]: { number } } = {
		-- mini compras
		maceteros = { DOOR_W / 2 + 3, FRONT - 5 },
		tacho = { -10.4, FRONT - 5 },
		farol1 = { -10.5, -30 },
		farol2 = { -10.5, -48 },
		pizarra = { 7.6, -21.5 },
		toldo = { -7, FRONT - 4 },
		carritos = { math.min(W / 2 - 3, DOOR_W / 2 + 8), FRONT - 4.5 },
		banco = { -15.6, FRONT - 4.5 },
		luces = { -W / 2 + 2.5, FRONT + 4 },
		banderines = { 6.6, -26 },
		expendedora = { W / 2 - 2.6, FRONT - 4.5 },
		bicicletero = { 15, -23.5 },
		camaras = { W / 2 - 1.5, FRONT - 4 },
		parlantes = { -6.6, FRONT - 3.5 },
		fuente = { 50, -20 },
		inflable = { -W / 4, FRONT - 8 },
		-- decoración grande
		cartel = { -10, FRONT - 11 },
		heladera = { W / 2 - 5, FRONT + D * 0.62 },
		aire = { 5, FRONT + 7 },
		estacionamiento = { -25.5, -33 },
		escaleras = { W / 2 - 8, FRONT + D - 24 },
	}
	local spot = spots[pad.id]
	if spot then
		return spot[1], spot[2]
	end
	return 14, -34
end

-- Lime is the game's one "pay here" colour, so nothing else on the plot uses it.
function World.Pads(rec: any, pads: { any })
	local slot: Slot = rec.Slot
	if slot.PadFolder then
		slot.PadFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pads"
	for _, pad in pads do
		local x, z = padSpot(rec.Data.Stage, pad)
		local big = pad.kind == "stage"
		local d = if big then 7.6 else 5
		Kit.pole(folder, "Rim", d + 1.2, 0.6, World.ToWorld(slot, Vector3.new(x, 0.3, z)), C.black)
		local base = Kit.pole(folder, "Pad_" .. pad.kind, d, 0.5, World.ToWorld(slot, Vector3.new(x, 0.6, z)), C.lime, { CanCollide = true, CanTouch = true })
		Kit.pole(folder, "Ring", d * 0.7, 0.1, World.ToWorld(slot, Vector3.new(x, 0.88, z)), C.limeDark)
		Kit.pole(folder, "Dot", d * 0.58, 0.1, World.ToWorld(slot, Vector3.new(x, 0.9, z)), C.lime)
		local b = if big then Kit.billboard(base, "Label", 9, 2.4, 4, 110) else Kit.billboard(base, "Label", 6.5, 1.8, 3, 60)
		Kit.label(b, pad.name, 0.5)
		Kit.label(b, "$" .. pad.price, 0.5, C.lime)
		local busy = false
		base.Touched:Connect(function(hit: BasePart)
			local player = ownerOf(hit)
			if busy or not player or player ~= slot.Owner or not padHandler then
				return
			end
			busy = true
			padHandler(player, pad.kind, pad.id)
			task.delay(1, function()
				busy = false
			end)
		end)
	end
	folder.Parent = slot.Folder
	slot.PadFolder = folder
end

function World.OnPad(fn: (Player, string, string) -> ())
	padHandler = fn
end

function World.OnStaff(fn: (Player, string) -> ())
	staffHandler = fn
end

function World.OnRegister(fn: (Player) -> ())
	registerHandler = fn
end

return World
