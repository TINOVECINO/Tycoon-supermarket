--!strict
-- Supermarket Empire: every screen, built at runtime from the Folk Stud UI kit and the
-- shared GameConfig, then kept up to date from the server's State messages.
-- The client only asks; the server checks and answers. Nothing here changes money.
-- Status: reviewed, not run in Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = ReplicatedStorage:WaitForChild("Game")
local M = require(Game:WaitForChild("FolkStudUI")) :: any
local Config = require(Game:WaitForChild("GameConfig")) :: any
local AssetIds = require(Game:WaitForChild("AssetIds")) :: any
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local Ui = {}

local player = Players.LocalPlayer
local C, A = M.COLOR, M.ART
local short = M.short

local function icon(name: string, fallback: any): any
	local id = AssetIds.Icons[name]
	return if type(id) == "string" and id ~= "" then id else fallback
end

local MESSAGES = {
	NoCash = "¡No te alcanza la plata!",
	Full = "Esa góndola ya está llena",
	Max = "Ya está al máximo",
	NotYet = "Todavía no la cumpliste",
	Claimed = "Ya la cobraste",
	Stage = "Primero abrí el Hipermercado",
	Locked = "Todavía está bloqueado",
	Nothing = "No hay nada para reponer",
	DepotFull = "El depósito ya está lleno",
	TooFast = "¡Más despacio!",
	NetworkError = "Sin conexión, probá de nuevo",
}

local PRODUCT_COLORS = { C.pink, C.blue, C.orange, C.gold, C.purple, C.green, C.amber, C.red, C.crimson, C.hudBlue }
local STAFF_COLORS = { cajero = C.blue, repositor = C.orange, promotor = C.pink, gerente = C.purple }

function Ui.Start()
	local pg = player:WaitForChild("PlayerGui")

	-- Roblox's player list sits on the top right, over the windows' X button. The money is
	-- already on the top HUD, so it is hidden.
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if ok then
				break
			end
			task.wait(0.5)
		end
	end)

	---------------------------------------------------------------- build
	local money = M.money(pg, { sub = "", objective = "" })
	local tracker = M.tracker(pg)

	local shop = M.shop(pg, {
		name = "FolkShop", title = "Tienda", icon = A.shop,
		passes = {
			{ id = "x2Cash", title = "x2 Dinero", desc = "Cada venta paga\n¡el doble, siempre!", tag = "HOT!", color = C.green, art = icon("cash", A.star), price = "--" },
			{ id = "x2Customers", title = "Clientes x2", desc = "Los clientes llegan\n¡el doble de rápido!", tag = "OP!", color = C.amber, art = A.star, price = "--" },
		},
	})

	local questSections, bySection = {}, {}
	for _, q in Config.Quests do
		local sec = bySection[q.section]
		if not sec then
			sec = { name = q.section, icon = if #questSections == 0 then A.star else A.rebirth, color = if #questSections == 0 then C.green else C.blue, quests = {} }
			bySection[q.section] = sec
			table.insert(questSections, sec)
		end
		table.insert(sec.quests, { id = q.id, title = q.title, desc = q.desc, have = 0, need = q.need, reward = "+$" .. short(q.reward), color = if #sec.quests % 2 == 0 then C.blue else C.pink, icon = A.star })
	end
	local quests = M.quests(pg, { name = "FolkQuests", title = "Misiones", icon = A.quest, sections = questSections })

	local stockRows, priceRows = { { id = "all", title = "Reponer todo", desc = "Llena todas las góndolas que puedas pagar", color = C.green, icon = icon("stock", A.star), label = "TODO" } }, {}
	local productRows = {}
	for i, p in Config.Products do
		table.insert(productRows, { id = p.id, title = p.name, desc = "", color = PRODUCT_COLORS[i], icon = icon(p.id, icon("stock", A.star)) })
		table.insert(priceRows, { id = p.id, kind = "slider", title = p.name, desc = "", value = 100, min = Config.PriceMin, max = Config.PriceMax, color = PRODUCT_COLORS[i], icon = icon(p.id, icon("prices", A.star)) })
	end
	local stock = M.manage(pg, {
		name = "FolkStock", title = "Stock", icon = icon("stock", A.star),
		sections = { { name = "Todo", icon = A.star, color = C.green, rows = stockRows }, { name = "Góndolas", icon = A.star, color = C.blue, rows = productRows } },
	})

	local staffRows = {}
	for _, s in Config.Staff do
		table.insert(staffRows, { id = s.id, title = s.name, desc = s.desc, color = STAFF_COLORS[s.id], icon = icon("staff", A.star) })
	end
	local staff = M.manage(pg, { name = "FolkStaff", title = "Empleados", icon = icon("staff", A.star), sections = { { name = "Equipo", icon = A.star, color = C.purple, rows = staffRows } } })

	local depotRows = { { id = "depot", title = "Depósito", desc = "", color = C.orange, icon = icon("depot", icon("stock", A.star)) } }
	local truckRows = {}
	for i, t in Config.Trucks do
		table.insert(truckRows, { id = "truck" .. i, title = t.name, desc = "", color = ({ C.blue, C.purple, C.crimson })[i], icon = icon("truck", A.star) })
	end
	local depot = M.manage(pg, {
		name = "FolkDepot", title = "Depósito", icon = icon("depot", icon("stock", A.star)),
		sections = { { name = "Depósito", icon = A.star, color = C.orange, rows = depotRows }, { name = "Camiones", icon = A.star, color = C.blue, rows = truckRows } },
	})

	local prices = M.settings(pg, { name = "FolkPrices", title = "Precios", icon = icon("prices", A.star), sections = { { name = "Precios", icon = A.star, color = C.gold, rows = priceRows } } })

	local branch = M.rebirth(pg, {
		name = "FolkRebirth", title = "Sucursal", icon = A.rebirth,
		from = "Sucursal 1", to = "Sucursal 2", gainFrom = "x1 Plata", gainTo = "x1.5 Plata",
		warn = "¡Reinicia tu plata y tu local!", barText = "$0/$0", barFrac = 0,
	})

	local hud = M.hud(pg, { buttons = {
		{ label = "Tienda", icon = A.shop, color = C.hudShop, opens = "FolkShop", tag = "NEW!" },
		{ label = "Misiones", icon = A.quest, color = C.hudPurple, opens = "FolkQuests" },
		{ label = "Stock", icon = icon("stock", A.star), color = C.green, opens = "FolkStock" },
		{ label = "Depósito", icon = icon("depot", icon("stock", A.star)), color = C.orange, opens = "FolkDepot" },
		{ label = "Equipo", icon = icon("staff", A.star), color = C.pink, opens = "FolkStaff" },
		{ label = "Precios", icon = icon("prices", A.star), color = C.amber, opens = "FolkPrices" },
		{ label = "Sucursal", icon = A.rebirth, color = C.hudBlue, opens = "FolkRebirth" },
	} })

	-- windows start closed and open from the rail
	for _, g in { shop, quests, stock, depot, staff, prices, branch } do
		g.Enabled = false
	end

	---------------------------------------------------------------- actions
	local function answer(result: any, okText: string?)
		if result.ok then
			if okText then
				M.toast(money, okText, true)
			end
		elseif result.code ~= "Busy" then
			M.toast(money, MESSAGES[result.code] or "No se pudo")
		end
	end


	local function buyPass(key: string)
		local id = AssetIds.Passes[key]
		if not id or id == 0 then
			M.toast(money, "Pase sin configurar: poné su id en AssetIds")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
	M.live(shop, { buy = buyPass, gift = function()
		M.toast(money, "Los regalos todavía no están disponibles")
	end })
	-- real Robux prices, read from Roblox for the passes that have an id
	for key, id in AssetIds.Passes do
		if id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.GamePass)
				if ok and info and info.PriceInRobux then

					for _, b in shop:GetDescendants() do
						if b.Name == "Buy" and b:GetAttribute("Offer") == key then
							local label = b:FindFirstChild("Price")
							if label and label:IsA("TextLabel") then
								label.Text = utf8.char(0xE002) .. " " .. info.PriceInRobux
							end
						end
					end
				end
			end)
		end
	end

	M.live(quests, {
		go = function()
			M.show(quests, false)
		end,
		claim = function(id: string)
			local result = Net.Request("ClaimQuest", id)
			if result.ok then
				M.setQuest(quests, id, nil, nil, "done")
			else
				answer(result)
			end
		end,
	})
	local stateNow: any = nil
	M.live(depot, { act = function(id: string)
		if id == "depot" then
			answer(Net.Request("UpgradeDepot"))
			return
		end
		local index = tonumber(string.match(id, "%d+")) or 0
		local owned = if stateNow then stateNow.Trucks else 0
		if index <= owned then
			answer(Net.Request("DispatchTruck", index), "¡Camión en camino!")
		else
			answer(Net.Request("BuyTruck"))
		end
	end })
	M.live(stock, { act = function(id: string)
		if id == "all" then
			answer(Net.Request("RestockAll"), "¡Góndolas repuestas!")
		else
			answer(Net.Request("Restock", id))
		end
	end })
	M.live(staff, { act = function(id: string)
		answer(Net.Request("Hire", id))
	end })

	-- a drag fires many changes: send the last one, a moment after the slider stops
	local pending: { [string]: number } = {}
	local function priceDesc(id: string, percent: number)
		local p = Config.ProductById[id]
		local demand = Config.Demand(percent)
		local mood = if demand >= 1.2 then "¡Se vende volando!" elseif demand >= 0.9 then "Precio justo" elseif demand >= 0.5 then "Algunos no compran" else "Casi nadie compra"
		M.setSettingDesc(prices, id, string.format("$%s c/u · %s", tostring(math.floor(p.price * percent) / 100), mood))
	end
	M.settingsLive(prices, { change = function(id: string, value: any)
		if type(value) ~= "number" then
			return
		end
		priceDesc(id, value)
		local first = pending[id] == nil
		pending[id] = value
		if first then
			task.delay(0.3, function()
				local v = pending[id]
				pending[id] = nil
				if v then
					Net.Send("SetPrice", id, v)
				end
			end)
		end
	end })

	M.live(branch, {
		rebirth = function()
			answer(Net.Request("OpenBranch"))
			M.show(branch, false)
		end,
	})
	M.live(money, {})
	M.setTrackerClaim(tracker, function(id: string)
		local result = Net.Request("ClaimQuest", id)
		if not result.ok then
			answer(result)
		end
	end)
	M.hudLive(hud, { FolkShop = shop, FolkQuests = quests, FolkStock = stock, FolkDepot = depot, FolkStaff = staff, FolkPrices = prices, FolkRebirth = branch })

	---------------------------------------------------------------- state
	local claimedShown: { [string]: boolean } = {}
	local pricesLoaded = false

	local function cash(): number
		local v = player:GetAttribute("Cash")
		return if type(v) == "number" then v else 0
	end

	local function objective(s: any): string
		local function words(verb: string, thing: string, count: string?): string
			return `<font color="#00BFFF">{verb}</font> <font color="#FFA200">{thing}</font>` .. (if count then ` <font color="#8CFF00">{count}</font>` else "")
		end
		if s.Register > 0 and not s.Staff.cajero then
			return words("Tocá", "la CAJA para cobrar", "$" .. short(s.Register))
		end
		for _, p in Config.Products do
			if s.Unlocked[p.id] and (s.Stock[p.id] or 0) == 0 then
				return words("Reponé", p.name, "en Stock")
			end
		end
		local pad = s.Pads[1]
		for _, p in s.Pads do
			if p.price < pad.price then
				pad = p
			end
		end
		if pad then
			return words("Comprá", pad.name, "$" .. short(pad.price) .. " " .. "en tu terreno")
		end
		if s.Stage >= Config.Branch.stage then
			return words("Abrí", "una sucursal nueva", "$" .. short(s.BranchCost))
		end
		return ""
	end

	-- income per minute, from what was actually collected over the last minute
	local samples: { { t: number, earned: number } } = {}
	local function perMinute(earned: number): number
		local now = os.clock()
		table.insert(samples, { t = now, earned = earned })
		while #samples > 1 and now - samples[1].t > 60 do
			table.remove(samples, 1)
		end
		local first = samples[1]
		local span = now - first.t
		if span < 5 or earned < first.earned then
			return 0
		end
		return (earned - first.earned) / span * 60
	end

	local function refresh()
		local s = stateNow
		if not s then
			return
		end
		local balance = cash()
		local stageName = Config.Stages[s.Stage].name
		M.setMoney(money, balance, string.format("+$%s/MIN · x%s · %s", short(math.floor(perMinute(s.Stats.Earned or 0))), tostring(s.Multiplier), string.upper(stageName)))
		M.setObjective(money, objective(s))

		-- level and the three missions in progress
		local active = {}
		for _, q in Config.Quests do
			if not s.Claimed[q.id] and #active < 3 then
				local have = s.Quests[q.id] or 0
				table.insert(active, {
					id = q.id, title = q.title, have = have, need = q.need, done = have >= q.need,
					reward = "+$" .. short(q.reward) .. "  +" .. Config.QuestXP(q) .. " XP",
				})
			end
		end
		M.setTracker(tracker, { level = s.Level, xp = s.XPInto, need = s.XPNeed, quests = active })

		-- stock rows
		local totalMissing = 0
		local boxes = s.Depot.Boxes
		local function price(cost: number): string
			-- boxes from the depot pay first; what is left costs cash
			local cashPart = math.max(0, cost - boxes)
			return if cashPart == 0 then "GRATIS" else "$" .. short(cashPart)
		end
		for _, p in Config.Products do
			if s.Unlocked[p.id] then
				local have, cap = s.Stock[p.id] or 0, s.Caps[p.id]
				local missing = cap - have
				totalMissing += missing * p.cost
				M.setManage(stock, p.id, {
					desc = if have == 0 then "¡Sin stock! Los clientes se van" else "Tocá para llenar la góndola",
					info = "$" .. p.cost .. " c/u", count = have .. "/" .. cap, have = have, need = cap,
					label = price(missing * p.cost), state = if missing > 0 then "act" else "max", maxText = "LLENO",
					glint = have == 0,
				})
			else
				local reason = if p.stage > s.Stage then "Necesita " .. Config.Stages[p.stage].name else "Comprala en tu terreno: $" .. short(p.unlock)
				M.setManage(stock, p.id, { desc = reason, info = "", count = "", have = 0, need = 1, state = "locked", lockText = "BLOQUEADO" })
			end
		end
		M.setManage(stock, "all", { info = "", count = "", have = 0, need = 1, label = price(totalMissing), state = if totalMissing > 0 then "act" else "max", maxText = "LLENO" })

		-- depot and trucks
		local d = s.Depot
		if d.Level == 0 then
			local reason = if s.Stage < Config.Depot.stage then "Necesita " .. Config.Stages[Config.Depot.stage].name else "Construilo en tu terreno: $" .. short(Config.Depot.price)
			M.setManage(depot, "depot", { desc = reason, info = "", count = "", have = 0, need = 1, state = "locked", lockText = "SIN CONSTRUIR" })
		else
			local nextLevel = Config.Depot.levels[d.Level + 1]
			M.setManage(depot, "depot", {
				desc = "El stock sale de acá antes que de tu plata",
				info = "-" .. math.round((1 - Config.Depot.wholesale) * 100) .. "% costo",
				count = d.Boxes .. "/" .. d.Cap .. " cajas" .. (if d.Incoming > 0 then " (+" .. d.Incoming .. ")" else ""), have = d.Boxes, need = d.Cap,
				label = if nextLevel then "$" .. short(nextLevel.price) else "", state = if nextLevel then "act" else "max",
			})
		end
		for i, t in Config.Trucks do
			local id = "truck" .. i
			local trip = "Trae " .. t.load .. " cajas por viaje"
			if d.Level == 0 or i > s.Trucks + 1 then
				M.setManage(depot, id, { desc = trip, info = "", count = "", have = 0, need = 1, state = "locked", lockText = "BLOQUEADO" })
			elseif i == s.Trucks + 1 then
				M.setManage(depot, id, { desc = trip, info = "", count = "SIN COMPRAR", have = 0, need = 1, label = "$" .. short(t.price), state = "act", glint = balance >= t.price })
			elseif s.TruckBusy[i] then
				M.setManage(depot, id, { desc = trip, info = "", count = "EN VIAJE", have = 1, need = 1, state = "max", maxText = "EN VIAJE" })
			else
				local load = math.min(t.load, d.Cap - d.Boxes - d.Incoming)
				M.setManage(depot, id, {
					desc = trip, info = "$" .. short(math.ceil(math.max(load, 0) * Config.Depot.wholesale)), count = "LISTO", have = 0, need = 1,
					label = "PEDIR", state = if load >= 10 then "act" else "max", maxText = "LLENO",
				})
			end
		end

		-- staff rows
		for _, def in Config.Staff do
			local level = s.Staff[def.id] or 0
			local nextPrice = def.prices[level + 1]
			M.setManage(staff, def.id, {
				desc = if level > 0 then def.levelText[level] else def.desc,
				info = if nextPrice and level > 0 then "→ " .. def.levelText[level + 1] else "",
				count = "NIVEL " .. level .. "/" .. #def.prices, have = level, need = #def.prices,
				label = if nextPrice then "$" .. short(nextPrice) else "", state = if nextPrice then "act" else "max",
				glint = nextPrice ~= nil and balance >= nextPrice,
			})
		end

		-- prices: load the saved ones once, then the sliders are the player's
		if not pricesLoaded then
			pricesLoaded = true
			for _, p in Config.Products do
				local percent = s.Prices[p.id] or 100
				M.setSetting(prices, p.id, percent)
				priceDesc(p.id, percent)
			end
		end

		-- quests
		for _, q in Config.Quests do
			local have = s.Quests[q.id] or 0
			if s.Claimed[q.id] then
				if not claimedShown[q.id] then
					claimedShown[q.id] = true
					M.setQuest(quests, q.id, q.need, q.need, "done")
				end
			else
				claimedShown[q.id] = nil
				M.setQuest(quests, q.id, math.min(have, q.need), q.need, nil)
			end
		end

		-- branch window
		local cost = s.BranchCost
		local ready = s.Stage >= Config.Branch.stage
		M.setRebirth(branch, {
			from = "Sucursal " .. (s.Branches + 1), to = "Sucursal " .. (s.Branches + 2),
			gainFrom = "x" .. tostring(Config.BranchMultiplier(s.Branches)) .. " Plata", gainTo = "x" .. tostring(Config.BranchMultiplier(s.Branches + 1)) .. " Plata",
			warn = if ready then "¡Reinicia tu plata y tu local!" else "Necesitás el " .. Config.Stages[Config.Branch.stage].name,
			barText = "$" .. short(balance) .. "/$" .. short(cost), barFrac = if ready then balance / cost else 0,
		})
	end

	Net.On("State", function(s: any)
		stateNow = s
		refresh()
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	Net.On("Toast", function(text: string, good: boolean)
		M.toast(money, text, good)
	end)
end

return Ui
