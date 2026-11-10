--!strict
-- Supermarket Empire: the store of each player. Owns the "Store" data slice, every
-- purchase (pads, stock, staff, branches), the register and the state sent to the owner.
-- Every price comes from GameConfig on the server; the client only sends ids.
-- Status: reviewed, not run in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))
local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("GameConfig")) :: any
local Lib = ServerScriptService:WaitForChild("LihFolk")
local PlayerData = require(Lib:WaitForChild("PlayerData"))
local Currency = require(Lib:WaitForChild("Currency"))
local World = require(script.Parent:WaitForChild("World"))
local Passes = require(script.Parent:WaitForChild("Passes"))

local T = (Net :: any).T

export type Rec = {
	Player: Player,
	Slot: any, -- World slot
	Profile: PlayerData.Profile,
	Data: { [string]: any }, -- profile.Data.Store
	Customers: number,
	Alive: boolean,
	PushPending: boolean,
	TruckBusy: { [number]: boolean }, -- not saved: a truck on a trip when the owner leaves is just back next time
	Incoming: number, -- boxes paid for and on their way
}

local Store = {}
Store.Recs = {} :: { [Player]: Rec }
Store.Opened = Signal.new() -- (rec): a store is ready, start its customers

local statePush: any = nil
local toastPush: any = nil

local function newData(): { [string]: any }
	local first = Config.Products[1]
	return {
		Stage = 1,
		Unlocked = { [first.id] = true },
		Stock = { [first.id] = first.stock },
		Prices = {},
		Decor = {},
		Extras = {},
		Depot = { Level = 0, Boxes = 0 },
		Trucks = 0,
		XP = 0,
		Staff = {},
		Register = 0,
		Branches = 0,
		Stats = { Sold = 0, Restocks = 0, Hired = 0, Earned = 0, Deliveries = 0 },
		Claimed = {},
	}
end

---------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------

function Store.Capacity(data: { [string]: any }, product: any): number
	return math.floor(product.stock * Config.Stages[data.Stage].capacity)
end

function Store.PricePercent(data: { [string]: any }, id: string): number
	return data.Prices[id] or 100
end

function Store.StaffValue(data: { [string]: any }, id: string): number?
	local level = data.Staff[id] or 0
	if level <= 0 then
		return nil
	end
	return Config.StaffById[id].values[level]
end

-- What the buy pads on the plot offer now: the next stage, the next product and the next upgrade.
function Store.NextPads(data: { [string]: any }): { any }
	local pads = {}
	-- the cheap one first: there is almost always a small upgrade within reach
	for _, e in Config.Extras do
		if not data.Extras[e.id] and e.stage <= data.Stage then
			table.insert(pads, { kind = "extra", id = e.id, name = e.name, price = e.price })
			break
		end
	end
	for _, p in Config.Products do
		if not data.Unlocked[p.id] and p.stage <= data.Stage then
			table.insert(pads, { kind = "product", id = p.id, name = "Góndola de " .. p.name, price = p.unlock })
			break
		end
	end
	if data.Depot.Level == 0 and data.Stage >= Config.Depot.stage then
		table.insert(pads, { kind = "depot", id = "depot", name = "Construir Depósito", price = Config.Depot.price })
	end
	for _, d in Config.Decor do
		if not data.Decor[d.id] and d.stage <= data.Stage then
			table.insert(pads, { kind = "decor", id = d.id, name = d.name, price = d.price })
			break
		end
	end
	local nextStage = Config.Stages[data.Stage + 1]
	if nextStage then
		table.insert(pads, { kind = "stage", id = tostring(data.Stage + 1), name = "Ampliar a " .. nextStage.name, price = nextStage.price })
	end
	return pads
end

-- Seconds between customers. More upgrades, staff and fair prices bring them faster.
function Store.SpawnSeconds(rec: Rec): number
	local data = rec.Data
	local stage = Config.Stages[data.Stage]
	local bonus = 1
	for id in data.Decor do
		bonus += Config.DecorById[id].bonus
	end
	for id in data.Extras do
		local extra = Config.ExtraById[id]
		if extra then
			bonus += extra.bonus
		end
	end
	bonus += Store.StaffValue(data, "promotor") or 0
	local demand, n = 0, 0
	for id in data.Unlocked do
		demand += Config.Demand(Store.PricePercent(data, id))
		n += 1
	end
	local priceFactor = math.clamp(if n > 0 then demand / n else 1, 0.4, 1.4)
	local pass = if Passes.Owns(rec.Player, "x2Customers") then 2 else 1
	return stage.spawnSeconds / (bonus * priceFactor * pass)
end

---------------------------------------------------------------------------
-- State for the owner's UI
---------------------------------------------------------------------------

function Store.DepotCap(data: { [string]: any }): number
	local level = Config.Depot.levels[data.Depot.Level]
	return if level then level.cap else 0
end

function Store.QuestValue(data: { [string]: any }, stat: string): number
	if stat == "Stage" then
		return data.Stage
	elseif stat == "Branches" then
		return data.Branches
	elseif stat == "Depot" then
		return data.Depot.Level
	elseif stat == "Extras" then
		local n = 0
		for _ in data.Extras do
			n += 1
		end
		return n
	end
	return data.Stats[stat] or 0
end

local function questValues(data: { [string]: any }): { [string]: number }
	local values = {}
	for _, q in Config.Quests do
		values[q.id] = Store.QuestValue(data, q.stat)
	end
	return values
end

local function snapshot(rec: Rec): { [string]: any }
	local data = rec.Data
	local caps = {}
	for _, p in Config.Products do
		caps[p.id] = Store.Capacity(data, p)
	end
	local level, xpInto, xpNeed = Config.LevelOf(data.XP or 0)
	return {
		Stage = data.Stage,
		Branches = data.Branches,
		Register = data.Register,
		Unlocked = data.Unlocked,
		Stock = data.Stock,
		Caps = caps,
		Prices = data.Prices,
		Staff = data.Staff,
		Decor = data.Decor,
		Extras = data.Extras,
		Depot = { Level = data.Depot.Level, Boxes = data.Depot.Boxes, Cap = Store.DepotCap(data), Incoming = rec.Incoming },
		Trucks = data.Trucks,
		TruckBusy = { rec.TruckBusy[1] == true, rec.TruckBusy[2] == true, rec.TruckBusy[3] == true },
		Quests = questValues(data),
		Level = level,
		XPInto = xpInto,
		XPNeed = xpNeed,
		Stats = data.Stats,
		Claimed = data.Claimed,
		Multiplier = Currency.GetMultiplier(rec.Player, "Cash"),
		BranchCost = Config.BranchCost(data.Branches),
		Pads = Store.NextPads(data),
	}
end

function Store.Changed(rec: Rec)
	rec.PushPending = true
	PlayerData.MarkDirty(rec.Profile)
end

local function toast(player: Player, text: string, good: boolean?)
	toastPush:Fire(player, text, good == true)
end

local function recOf(player: Player): Rec?
	local rec = Store.Recs[player]
	if rec and rec.Alive and rec.Profile.State == "active" then
		return rec
	end
	return nil
end

-- Gives XP; on a level up, a cash gift and a toast. The caller marks the record changed.
function Store.AddXP(rec: Rec, amount: number)
	local data = rec.Data
	local before = Config.LevelOf(data.XP or 0)
	data.XP = (data.XP or 0) + amount
	local after = Config.LevelOf(data.XP)
	if after > before then
		Currency.Add(rec.Player, "Cash", Config.LevelCash * after, "level:" .. after)
		toast(rec.Player, "¡NIVEL " .. after .. "! +" .. math.round(Config.LevelBonus * 100) .. "% por venta", true)
	end
	rec.PushPending = true
end

---------------------------------------------------------------------------
-- Actions. Each one checks, then writes, with no yield in between.
---------------------------------------------------------------------------

function Store.BuyPad(player: Player, kind: string, id: string): (boolean, string)
	local rec = recOf(player)
	if not rec then
		return false, "NoStore"
	end
	local data = rec.Data
	-- the pad must be one the server is offering right now
	local pad
	for _, p in Store.NextPads(data) do
		if p.kind == kind and p.id == id then
			pad = p
		end
	end
	if not pad then
		return false, "Gone"
	end
	if not Currency.Spend(player, "Cash", pad.price, "pad:" .. kind .. ":" .. id) then
		toast(player, "¡Te faltan $" .. (pad.price - (Currency.Get(player, "Cash") or 0)) .. "!")
		return false, "NoCash"
	end
	if kind == "stage" then
		data.Stage += 1
		toast(player, "¡Ahora sos un " .. Config.Stages[data.Stage].name .. "!", true)
	elseif kind == "product" then
		local p = Config.ProductById[id]
		data.Unlocked[id] = true
		data.Stock[id] = Store.Capacity(data, p)
		toast(player, "¡Nueva góndola: " .. p.name .. "!", true)
	elseif kind == "extra" then
		data.Extras[id] = true
		toast(player, "¡" .. Config.ExtraById[id].name .. "! Vienen más clientes", true)
	elseif kind == "depot" then
		data.Depot.Level = 1
		toast(player, "¡Depósito listo! Comprá un camión en la ventana Depósito", true)
	else
		data.Decor[id] = true
		toast(player, "¡" .. Config.DecorById[id].name .. " instalado!", true)
	end
	Store.AddXP(rec, Config.XP[kind] or 15)
	Store.Changed(rec)
	World.Render(rec)
	World.Pads(rec, Store.NextPads(data))
	return true, "Ok"
end

-- Buys units at cost until the shelf is full or the money runs out. auto = done by the Repositor.
function Store.Restock(rec: Rec, id: string, auto: boolean): (boolean, string)
	local data = rec.Data
	local p = Config.ProductById[id]
	if not p or not data.Unlocked[id] then
		return false, "Locked"
	end
	local missing = Store.Capacity(data, p) - (data.Stock[id] or 0)
	if missing <= 0 then
		return false, "Full"
	end
	-- depot boxes first (already paid for at wholesale), cash for the rest
	local boxes = data.Depot.Boxes
	local cash = Currency.Get(rec.Player, "Cash") or 0
	local n = math.min(missing, math.floor((boxes + cash) / p.cost))
	if n <= 0 then
		return false, "NoCash"
	end
	local fromBoxes = math.min(boxes, n * p.cost)
	local pay = n * p.cost - fromBoxes
	if pay > 0 and not Currency.Spend(rec.Player, "Cash", pay, "restock:" .. id) then
		return false, "NoCash"
	end
	data.Depot.Boxes = boxes - fromBoxes
	if fromBoxes > 0 then
		World.UpdateDepot(rec)
	end
	data.Stock[id] = (data.Stock[id] or 0) + n
	if not auto then
		data.Stats.Restocks += 1
	end
	Store.Changed(rec)
	World.UpdateShelf(rec, id)
	return true, "Ok"
end

function Store.Hire(player: Player, id: string): (boolean, string)
	local rec = recOf(player)
	local def = Config.StaffById[id]
	if not rec or not def then
		return false, "Invalid"
	end
	local level = rec.Data.Staff[id] or 0
	local price = def.prices[level + 1]
	if not price then
		return false, "Max"
	end
	if not Currency.Spend(player, "Cash", price, "staff:" .. id) then
		return false, "NoCash"
	end
	rec.Data.Staff[id] = level + 1
	rec.Data.Stats.Hired += 1
	toast(player, if level == 0 then "¡Contrataste un " .. def.name .. "!" else def.name .. " nivel " .. (level + 1), true)
	Store.AddXP(rec, Config.XP.hire)
	Store.Changed(rec)
	World.Render(rec)
	return true, "Ok"
end

function Store.Collect(rec: Rec)
	local amount = rec.Data.Register
	if amount <= 0 then
		return
	end
	rec.Data.Register = 0
	if Currency.Add(rec.Player, "Cash", amount, "register") then
		rec.Data.Stats.Earned += amount
	else
		rec.Data.Register = amount -- balance cap reached: keep it in the register
	end
	Store.Changed(rec)
	World.UpdateRegister(rec)
end

-- A customer takes one unit. Returns what it costs them, or nil if they leave it on the shelf.
function Store.TakeUnit(rec: Rec, id: string): number?
	local data = rec.Data
	local p = Config.ProductById[id]
	if not p or not data.Unlocked[id] or (data.Stock[id] or 0) <= 0 then
		return nil
	end
	local percent = Store.PricePercent(data, id)
	if math.random() > Config.Demand(percent) then
		return nil -- too expensive for this customer
	end
	data.Stock[id] -= 1
	data.Stats.Sold += 1
	Store.Changed(rec)
	World.UpdateShelf(rec, id)
	return p.price * percent / 100
end

function Store.Checkout(rec: Rec, cart: number)
	if cart <= 0 then
		return
	end
	local manager = 1 + (Store.StaffValue(rec.Data, "gerente") or 0)
	local levelBonus = 1 + (Config.LevelOf(rec.Data.XP or 0) - 1) * Config.LevelBonus
	local amount = math.floor(cart * manager * levelBonus * Currency.GetMultiplier(rec.Player, "Cash"))
	if amount < 1 then
		return
	end
	rec.Data.Register += amount
	Store.AddXP(rec, Config.XP.sale)
	Store.Changed(rec)
	World.UpdateRegister(rec)
	World.Pop(rec, "+$" .. amount)
end

function Store.OpenBranch(player: Player): (boolean, string)
	local rec = recOf(player)
	if not rec then
		return false, "NoStore"
	end
	local data = rec.Data
	if data.Stage < Config.Branch.stage then
		return false, "Stage"
	end
	local cost = Config.BranchCost(data.Branches)
	if (Currency.Get(player, "Cash") or 0) < cost then
		return false, "NoCash"
	end
	-- a new branch starts from a kiosk again: money, store, staff and register reset; prices, stats and goals stay
	local fresh = newData()
	data.Stage, data.Unlocked, data.Stock, data.Decor, data.Staff, data.Register = fresh.Stage, fresh.Unlocked, fresh.Stock, fresh.Decor, fresh.Staff, 0
	data.Extras, data.Depot, data.Trucks = fresh.Extras, fresh.Depot, fresh.Trucks
	data.Branches += 1
	Currency.Set(player, "Cash", Config.Currency.currencies.Cash.start, "branch")
	Store.Changed(rec)
	World.Render(rec)
	World.Pads(rec, Store.NextPads(data))
	toast(player, "¡Sucursal " .. (data.Branches + 1) .. " abierta! x" .. Config.BranchMultiplier(data.Branches) .. " plata", true)
	return true, "Ok"
end

---------------------------------------------------------------------------
-- Depot and trucks
---------------------------------------------------------------------------

function Store.UpgradeDepot(player: Player): (boolean, string)
	local rec = recOf(player)
	if not rec or rec.Data.Depot.Level == 0 then
		return false, "Locked"
	end
	local nextLevel = Config.Depot.levels[rec.Data.Depot.Level + 1]
	if not nextLevel then
		return false, "Max"
	end
	if not Currency.Spend(player, "Cash", nextLevel.price, "depot") then
		return false, "NoCash"
	end
	rec.Data.Depot.Level += 1
	Store.AddXP(rec, Config.XP.depot)
	Store.Changed(rec)
	World.Render(rec)
	toast(player, "¡Depósito más grande: " .. nextLevel.cap .. " cajas!", true)
	return true, "Ok"
end

function Store.BuyTruck(player: Player): (boolean, string)
	local rec = recOf(player)
	if not rec or rec.Data.Depot.Level == 0 then
		return false, "Locked"
	end
	local def = Config.Trucks[rec.Data.Trucks + 1]
	if not def then
		return false, "Max"
	end
	if not Currency.Spend(player, "Cash", def.price, "truck") then
		return false, "NoCash"
	end
	rec.Data.Trucks += 1
	Store.AddXP(rec, Config.XP.truck)
	Store.Changed(rec)
	toast(player, "¡Compraste: " .. def.name .. "! Tocá PEDIR para traer cajas", true)
	return true, "Ok"
end

-- Sends a truck for boxes. It is paid when it leaves and the boxes arrive when it docks.
function Store.DispatchTruck(rec: Rec, index: number): (boolean, string)
	local data = rec.Data
	local def = Config.Trucks[index]
	if not def or data.Depot.Level == 0 or index > data.Trucks then
		return false, "Locked"
	end
	if rec.TruckBusy[index] then
		return false, "Busy"
	end
	local space = Store.DepotCap(data) - data.Depot.Boxes - rec.Incoming
	if space < 10 then
		return false, "DepotFull"
	end
	local cash = Currency.Get(rec.Player, "Cash") or 0
	local load = math.min(def.load, space, math.floor(cash / Config.Depot.wholesale))
	if load < 10 then
		return false, "NoCash"
	end
	if not Currency.Spend(rec.Player, "Cash", math.ceil(load * Config.Depot.wholesale), "truck:" .. index) then
		return false, "NoCash"
	end
	rec.TruckBusy[index] = true
	rec.Incoming += load
	Store.Changed(rec)
	task.spawn(function()
		World.TruckRun(rec, index, function()
			-- docked: unload. The owner may have left or opened a new branch meanwhile
			rec.Incoming = math.max(0, rec.Incoming - load)
			if rec.Alive and rec.Data.Depot.Level > 0 then
				rec.Data.Depot.Boxes = math.min(Store.DepotCap(rec.Data), rec.Data.Depot.Boxes + load)
				rec.Data.Stats.Deliveries += 1
				Store.Changed(rec)
				World.UpdateDepot(rec)
			end
		end)
		task.wait(Config.Depot.tripSeconds)
		rec.TruckBusy[index] = nil
		rec.PushPending = true
	end)
	return true, "Ok"
end

function Store.ClaimQuest(player: Player, id: string): (boolean, string)
	local rec = recOf(player)
	if not rec then
		return false, "NoStore"
	end
	local quest
	for _, q in Config.Quests do
		if q.id == id then
			quest = q
		end
	end
	if not quest then
		return false, "Invalid"
	end
	if rec.Data.Claimed[id] then
		return false, "Claimed"
	end
	if Store.QuestValue(rec.Data, quest.stat) < quest.need then
		return false, "NotYet"
	end
	rec.Data.Claimed[id] = true
	Currency.Add(player, "Cash", quest.reward, "quest:" .. id)
	toast(player, "¡Misión cumplida! +$" .. quest.reward, true)
	Store.AddXP(rec, Config.QuestXP(quest))
	Store.Changed(rec)
	return true, "Ok"
end

---------------------------------------------------------------------------
-- Staff and pushes
---------------------------------------------------------------------------

-- Runs the Cajero and the Repositor for one store while its owner is here.
local function staffLoop(rec: Rec)
	local cashTimer, stockTimer, managerTimer = 0, 0, 0
	while rec.Alive do
		local dt = task.wait(0.25)
		if rec.Profile.State ~= "active" then
			continue
		end
		local cashEvery = Store.StaffValue(rec.Data, "cajero")
		cashTimer += dt
		if cashEvery and cashTimer >= cashEvery then
			cashTimer = 0
			Store.Collect(rec)
		end
		-- the Gerente keeps the depot above 60% by sending whatever truck is free
		managerTimer += dt
		if managerTimer >= 2 then
			managerTimer = 0
			local depot = rec.Data.Depot
			if (rec.Data.Staff.gerente or 0) > 0 and depot.Level > 0 and depot.Boxes + rec.Incoming < Store.DepotCap(rec.Data) * 0.6 then
				for i = rec.Data.Trucks, 1, -1 do
					if not rec.TruckBusy[i] and Store.DispatchTruck(rec, i) then
						break
					end
				end
			end
		end
		local stockEvery = Store.StaffValue(rec.Data, "repositor")
		stockTimer += dt
		if stockEvery and stockTimer >= stockEvery then
			stockTimer = 0
			-- the emptiest shelf first
			local best, bestFrac = nil, 1
			for id in rec.Data.Unlocked do
				local frac = (rec.Data.Stock[id] or 0) / math.max(Store.Capacity(rec.Data, Config.ProductById[id]), 1)
				if frac < bestFrac then
					best, bestFrac = id, frac
				end
			end
			if best then
				Store.Restock(rec, best, true)
			end
		end
	end
end

local function onLoaded(player: Player, profile: PlayerData.Profile)
	local slot = World.Claim(player)
	if not slot then
		player:Kick("El servidor está lleno. Probá en otro servidor.")
		return
	end
	local rec: Rec = {
		Player = player,
		Slot = slot,
		Profile = profile,
		Data = profile.Data.Store,
		Customers = 0,
		Alive = true,
		PushPending = true,
		TruckBusy = {},
		Incoming = 0,
	}
	-- saves made before these existed
	local data = rec.Data
	data.Extras = data.Extras or {}
	data.Depot = data.Depot or { Level = 0, Boxes = 0 }
	data.Trucks = data.Trucks or 0
	data.XP = data.XP or 0
	data.Stats.Deliveries = data.Stats.Deliveries or 0
	Store.Recs[player] = rec
	-- Studio only: extra cash for testing late-game things. Never applies on a live server.
	if RunService:IsStudio() and Config.StudioTestCash > 0 then
		Currency.Add(player, "Cash", Config.StudioTestCash, "studio-test")
	end
	World.Render(rec)
	World.Pads(rec, Store.NextPads(rec.Data))
	World.SpawnAt(rec)
	task.spawn(staffLoop, rec)
	Store.Opened:Fire(rec)
end

local function close(player: Player)
	local rec = Store.Recs[player]
	if rec then
		rec.Alive = false
		Store.Recs[player] = nil
		World.Release(rec)
	end
end

function Store.Init()
	PlayerData.RegisterSlice("Store", newData)
	Currency.AddMultiplier("Cash", function(player: Player): number
		local rec = Store.Recs[player]
		local branches = if rec then rec.Data.Branches else 0
		return Config.BranchMultiplier(branches) * (if Passes.Owns(player, "x2Cash") then 2 else 1)
	end)
	PlayerData.Loaded:Connect(onLoaded)
	PlayerData.Releasing:Connect(function(player: Player)
		close(player)
	end)
	Players.PlayerRemoving:Connect(close)
	Currency.Changed:Connect(function(player: Player)
		local rec = Store.Recs[player]
		if rec then
			rec.PushPending = true -- affordability shows in the UI
			task.defer(World.PadsAfford, rec) -- after Currency has published the new balance
		end
	end)
	Passes.Changed:Connect(function(player: Player)
		local rec = Store.Recs[player]
		if rec then
			rec.PushPending = true
		end
	end)

	World.OnPad(function(player: Player, kind: string, id: string)
		Store.BuyPad(player, kind, id)
	end)
	World.OnStaff(function(player: Player, id: string)
		local ok, code = Store.Hire(player, id)
		if not ok and code == "NoCash" then
			toast(player, "No te alcanza la plata", false)
		end
	end)
	World.OnRegister(function(player: Player)
		local rec = recOf(player)
		if rec then
			Store.Collect(rec)
		end
	end)

	statePush = Net.Push("State")
	toastPush = Net.Push("Toast")

	local productId = T.key(Config.ProductById)
	local staffId = T.key(Config.StaffById)
	local questIds = {}
	for _, q in Config.Quests do
		questIds[q.id] = true
	end

	Net.Handle("Restock", {
		rate = { burst = 8, perSecond = 4 },
		args = { productId },
		handler = function(player: Player, id: string)
			local rec = recOf(player)
			if not rec then
				return Net.fail("NoStore")
			end
			local ok, code = Store.Restock(rec, id, false)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Handle("RestockAll", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player)
			local rec = recOf(player)
			if not rec then
				return Net.fail("NoStore")
			end
			local any = false
			for _, p in Config.Products do
				if rec.Data.Unlocked[p.id] and Store.Restock(rec, p.id, false) then
					any = true
				end
			end
			return if any then Net.ok() else Net.fail("Nothing")
		end,
	})
	Net.Handle("Hire", {
		rate = { burst = 4, perSecond = 2 },
		args = { staffId },
		handler = function(player: Player, id: string)
			local ok, code = Store.Hire(player, id)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Listen("SetPrice", {
		rate = { burst = 20, perSecond = 10 },
		args = { productId, T.integer(Config.PriceMin, Config.PriceMax) },
		handler = function(player: Player, id: string, percent: number)
			local rec = recOf(player)
			if rec then
				rec.Data.Prices[id] = if percent == 100 then nil else percent
				Store.Changed(rec)
			end
		end,
	})
	Net.Handle("UpgradeDepot", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player)
			local ok, code = Store.UpgradeDepot(player)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Handle("BuyTruck", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player)
			local ok, code = Store.BuyTruck(player)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Handle("DispatchTruck", {
		rate = { burst = 4, perSecond = 1 },
		args = { T.integer(1, #Config.Trucks) },
		handler = function(player: Player, index: number)
			local rec = recOf(player)
			if not rec then
				return Net.fail("NoStore")
			end
			local ok, code = Store.DispatchTruck(rec, index)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Handle("ClaimQuest", {
		rate = { burst = 4, perSecond = 2 },
		args = { T.key(questIds) },
		handler = function(player: Player, id: string)
			local ok, code = Store.ClaimQuest(player, id)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})
	Net.Handle("OpenBranch", {
		rate = { burst = 2, perSecond = 0.5 },
		args = {},
		handler = function(player: Player)
			local ok, code = Store.OpenBranch(player)
			return if ok then Net.ok() else Net.fail(code)
		end,
	})

	-- one state message per store at most every 0.3 s
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player, rec in Store.Recs do
				if rec.PushPending and rec.Profile.State == "active" then
					rec.PushPending = false
					statePush:Fire(player, snapshot(rec))
				end
			end
		end
	end)
end

return Store
