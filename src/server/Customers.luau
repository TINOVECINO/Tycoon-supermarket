--!strict
-- Supermarket Empire: customers. They walk in from the road, pick 1-3 unlocked products,
-- take each one if it is in stock and the price suits them, pay at the register and leave.
-- Bodies are two anchored-and-welded parts moved by tweens, so they cost no physics.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("GameConfig")) :: any
local Store = require(script.Parent:WaitForChild("Store"))
local World = require(script.Parent:WaitForChild("World"))

local Customers = {}

local SPEED = 12 -- studs per second
local SHIRTS = { "FF1F2A", "0A9CF0", "2BE000", "FFC800", "C830FF", "FF8A00", "00F0FF", "FF2BD6" }

local function walk(body: BasePart, slot: any, to: Vector3): boolean
	local goal = World.ToWorld(slot, to, 1.9)
	local from = body.Position
	local dist = (goal.Position - from).Magnitude
	if dist < 0.1 then
		return true
	end
	local flat = Vector3.new(goal.Position.X, from.Y, goal.Position.Z)
	local face = if (flat - from).Magnitude > 0.1 then CFrame.lookAt(goal.Position, goal.Position + (flat - from).Unit) else goal
	local seconds = dist / SPEED
	TweenService:Create(body, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = face }):Play()
	-- a plain wait, not Completed: a tween on a destroyed part may never complete
	task.wait(seconds)
	return body.Parent ~= nil
end

local function pickList(data: any): { string }
	local unlocked = {}
	for _, p in Config.Products do
		if data.Unlocked[p.id] then
			table.insert(unlocked, p.id)
		end
	end
	local list = {}
	for _ = 1, math.random(1, math.min(3, #unlocked)) do
		local i = math.random(1, #unlocked)
		table.insert(list, table.remove(unlocked, i) :: string)
	end
	return list
end

local function visit(rec: any)
	local slot = rec.Slot
	local folder = slot.Folder:FindFirstChild("Customers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Customers"
		folder.Parent = slot.Folder
	end
	local stage = rec.Data.Stage
	local pts = World.Points(stage)
	local shirt = Color3.fromHex(SHIRTS[math.random(1, #SHIRTS)])
	local model = World.Npc(folder, "Customer", World.ToWorld(slot, pts.road + Vector3.new(math.random(-4, 4), 0, 0), 0), shirt, nil)
	local body = model.PrimaryPart :: BasePart
	rec.Customers += 1

	local cart, bought = 0, 0
	local route = { pts.doorOut, pts.doorIn, Vector3.new(pts.corridorX, 0, pts.frontZ) }
	local ok = true
	for _, p in route do
		ok = ok and walk(body, slot, p)
	end
	for _, id in pickList(rec.Data) do
		if not ok or not rec.Alive or rec.Data.Stage ~= stage then
			break -- the store was rebuilt or closed under them
		end
		local x, z = World.ShelfXZ(stage, Config.ProductById[id].order)
		local aisle = z - 3
		ok = walk(body, slot, Vector3.new(pts.corridorX, 0, aisle)) and walk(body, slot, Vector3.new(x, 0, aisle))
		if ok and rec.Alive then
			task.wait(0.6)
			local paid = Store.TakeUnit(rec, id)
			if paid then
				cart += paid
				bought += 1
			end
		end
		ok = ok and walk(body, slot, Vector3.new(pts.corridorX, 0, aisle))
	end
	if ok and rec.Alive and rec.Data.Stage == stage then
		ok = walk(body, slot, Vector3.new(pts.corridorX, 0, pts.frontZ)) and walk(body, slot, pts.register)
		if ok and bought > 0 then
			task.wait(0.8)
			if rec.Alive then
				Store.Checkout(rec, cart)
			end
		end
	end
	if ok and rec.Alive then
		local _ = walk(body, slot, pts.doorIn) and walk(body, slot, pts.doorOut) and walk(body, slot, pts.road)
	end
	rec.Customers -= 1
	model:Destroy()
end

local function run(rec: any)
	while rec.Alive do
		task.wait(Store.SpawnSeconds(rec))
		if rec.Alive and rec.Profile.State == "active" and rec.Customers < Config.Stages[rec.Data.Stage].customers then
			task.spawn(visit, rec)
		end
	end
end

function Customers.Init()
	Store.Opened:Connect(function(rec: any)
		task.spawn(run, rec)
	end)
end

return Customers
