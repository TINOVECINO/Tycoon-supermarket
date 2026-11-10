--!strict
-- Supermarket Empire: every number of the economy lives here. Shared, so the UI
-- shows the same prices the server charges. The server never reads a price from the client.

local Config = {}

Config.Plots = 6 -- one store per player; the server holds up to this many players

-- Store stages: the kiosk grows into a hypermarket. size = store footprint in studs.
Config.Stages = {
	{ name = "Kiosco", price = 0, size = Vector2.new(24, 18), customers = 3, spawnSeconds = 6, capacity = 1 },
	{ name = "Almacén", price = 1_500, size = Vector2.new(36, 28), customers = 5, spawnSeconds = 4.5, capacity = 1.5 },
	{ name = "Minimercado", price = 12_000, size = Vector2.new(48, 36), customers = 7, spawnSeconds = 3.5, capacity = 2 },
	{ name = "Supermercado", price = 75_000, size = Vector2.new(62, 46), customers = 10, spawnSeconds = 2.6, capacity = 3 },
	{ name = "Hipermercado", price = 300_000, size = Vector2.new(78, 56), customers = 14, spawnSeconds = 1.8, capacity = 4 },
}

-- Products. cost = what one unit costs to restock, price = base sale price,
-- stock = shelf size at capacity 1, stage = store stage needed to unlock it.
Config.Products = {
	{ id = "golosinas", name = "Golosinas", cost = 2, price = 5, stock = 20, unlock = 0, stage = 1, color = Color3.fromRGB(255, 60, 170) },
	{ id = "bebidas", name = "Bebidas", cost = 4, price = 10, stock = 20, unlock = 200, stage = 1, color = Color3.fromRGB(0, 170, 255) },
	{ id = "snacks", name = "Snacks", cost = 6, price = 15, stock = 16, unlock = 600, stage = 1, color = Color3.fromRGB(255, 170, 0) },
	{ id = "almacen", name = "Fideos y arroz", cost = 10, price = 25, stock = 16, unlock = 2_500, stage = 2, color = Color3.fromRGB(255, 230, 0) },
	{ id = "lacteos", name = "Lácteos", cost = 15, price = 38, stock = 14, unlock = 6_000, stage = 2, color = Color3.fromRGB(240, 240, 255) },
	{ id = "verduleria", name = "Verdulería", cost = 22, price = 55, stock = 14, unlock = 18_000, stage = 3, color = Color3.fromRGB(80, 220, 40) },
	{ id = "panaderia", name = "Panadería", cost = 30, price = 75, stock = 12, unlock = 30_000, stage = 3, color = Color3.fromRGB(210, 140, 60) },
	{ id = "carniceria", name = "Carnicería", cost = 55, price = 140, stock = 12, unlock = 90_000, stage = 4, color = Color3.fromRGB(230, 30, 40) },
	{ id = "limpieza", name = "Limpieza", cost = 80, price = 200, stock = 12, unlock = 140_000, stage = 4, color = Color3.fromRGB(150, 60, 255) },
	{ id = "electro", name = "Electro", cost = 250, price = 620, stock = 8, unlock = 400_000, stage = 5, color = Color3.fromRGB(40, 40, 60) },
}
Config.ProductById = {} :: { [string]: any }
for i, p in Config.Products do
	p.order = i
	Config.ProductById[p.id] = p
end

-- Store upgrades bought on the plot's buy pads. bonus = extra customers (0.15 = +15%).
Config.Decor = {
	{ id = "cartel", name = "Cartel luminoso", price = 900, stage = 1, bonus = 0.15 },
	{ id = "heladera", name = "Heladera exhibidora", price = 4_000, stage = 2, bonus = 0.15 },
	{ id = "aire", name = "Aire acondicionado", price = 20_000, stage = 3, bonus = 0.2 },
	{ id = "estacionamiento", name = "Estacionamiento", price = 110_000, stage = 4, bonus = 0.25 },
	{ id = "escaleras", name = "Escaleras mecánicas", price = 450_000, stage = 5, bonus = 0.3 },
}
Config.DecorById = {} :: { [string]: any }
for _, d in Config.Decor do
	Config.DecorById[d.id] = d
end

-- Small upgrades ("mini compras"): cheap, one after another on their own buy pad. Each one adds
-- something you can see and a few more customers. The kiosk starts bare and fills up with these.
Config.Extras = {
	{ id = "maceteros", name = "Maceteros", price = 40, stage = 1, bonus = 0.03 },
	{ id = "tacho", name = "Tacho de basura", price = 60, stage = 1, bonus = 0.02 },
	{ id = "farol1", name = "Farol de entrada", price = 90, stage = 1, bonus = 0.04 },
	{ id = "pizarra", name = "Pizarra de ofertas", price = 130, stage = 1, bonus = 0.04 },
	{ id = "toldo", name = "Toldo", price = 180, stage = 1, bonus = 0.05 },
	{ id = "carritos", name = "Carritos", price = 240, stage = 1, bonus = 0.04 },
	{ id = "farol2", name = "Segundo farol", price = 300, stage = 1, bonus = 0.04 },
	{ id = "banco", name = "Banco", price = 380, stage = 1, bonus = 0.03 },
	{ id = "luces", name = "Luces de techo", price = 500, stage = 1, bonus = 0.05 },
	{ id = "banderines", name = "Banderines", price = 700, stage = 2, bonus = 0.05 },
	{ id = "expendedora", name = "Expendedora", price = 950, stage = 2, bonus = 0.05 },
	{ id = "bicicletero", name = "Bicicletero", price = 1_300, stage = 2, bonus = 0.04 },
	{ id = "camaras", name = "Cámaras", price = 2_500, stage = 3, bonus = 0.04 },
	{ id = "parlantes", name = "Música", price = 4_000, stage = 3, bonus = 0.06 },
	{ id = "fuente", name = "Fuente", price = 9_000, stage = 4, bonus = 0.06 },
	{ id = "inflable", name = "Globo gigante", price = 25_000, stage = 4, bonus = 0.08 },
}
Config.ExtraById = {} :: { [string]: any }
for _, e in Config.Extras do
	Config.ExtraById[e.id] = e
end

-- The depot (warehouse) and its trucks. Trucks bring boxes at wholesale price; restocking uses
-- boxes before cash, so stock from the depot is cheaper. 1 box = $1 of stock at shelf cost.
Config.Depot = {
	price = 2_000, -- built on a buy pad
	stage = 2,
	wholesale = 0.7, -- a truck pays 70% of the shelf cost
	levels = { { cap = 300 }, { cap = 900, price = 12_000 }, { cap = 3_000, price = 80_000 } },
	tripSeconds = 30, -- away on the road after each delivery
}
Config.Trucks = {
	{ name = "Camioneta", price = 1_500, load = 150 },
	{ name = "Camión", price = 9_000, load = 400 },
	{ name = "Camión con acoplado", price = 45_000, load = 1_200 },
}

-- Employees, hired and upgraded from the Empleados window. prices[n] buys level n.
Config.Staff = {
	{ id = "cajero", name = "Cajero", desc = "Cobra la caja solo", prices = { 400, 3_000, 15_000 }, levelText = { "Cobra cada 4 s", "Cobra cada 2 s", "Cobra al instante" }, values = { 4, 2, 0.5 } },
	{ id = "repositor", name = "Repositor", desc = "Repone la góndola más vacía", prices = { 1_200, 8_000, 40_000 }, levelText = { "Repone cada 8 s", "Repone cada 4 s", "Repone cada 2 s" }, values = { 8, 4, 2 } },
	{ id = "promotor", name = "Promotor", desc = "Trae más clientes", prices = { 2_500, 12_000, 60_000 }, levelText = { "+20% clientes", "+45% clientes", "+75% clientes" }, values = { 0.2, 0.45, 0.75 } },
	{ id = "gerente", name = "Gerente", desc = "Pide los camiones solo y mejora las ventas", prices = { 6_000, 60_000, 300_000 }, levelText = { "Pide camiones · +10% por venta", "Pide camiones · +25% por venta", "Pide camiones · +50% por venta" }, values = { 0.1, 0.25, 0.5 } },
}
Config.StaffById = {} :: { [string]: any }
for _, s in Config.Staff do
	Config.StaffById[s.id] = s
end

-- Prices are set as a percent of the base price. Cheaper sells more, dearer sells less.
Config.PriceMin, Config.PriceMax = 50, 200

-- Chance (0-1.5) that a customer buys a product at this price percent. 100% -> 1.
function Config.Demand(percent: number): number
	return math.clamp(2 - percent / 100, 0.1, 1.5)
end

-- New branch (rebirth): needs the last stage. Each branch adds +50% income, forever.
Config.Branch = { stage = 5, base = 500_000, growth = 2.5, bonus = 0.5 }
function Config.BranchCost(branches: number): number
	return math.floor(Config.Branch.base * Config.Branch.growth ^ branches)
end
function Config.BranchMultiplier(branches: number): number
	return 1 + branches * Config.Branch.bonus
end

-- Goals in the Misiones window. stat = counter kept on the server; claimed once each.
Config.Quests = {
	{ section = "Inicio", id = "sell25", title = "Vendé 25 productos", desc = "Los clientes compran solos", stat = "Sold", need = 25, reward = 150 },
	{ section = "Inicio", id = "restock", title = "Reponé 3 veces", desc = "Ventana Stock: REPONER", stat = "Restocks", need = 3, reward = 200 },
	{ section = "Inicio", id = "hire", title = "Contratá un empleado", desc = "Ventana Empleados", stat = "Hired", need = 1, reward = 300 },
	{ section = "Inicio", id = "stage2", title = "Abrí el Almacén", desc = "Comprá la ampliación en tu terreno", stat = "Stage", need = 2, reward = 500 },
	{ section = "Inicio", id = "extras3", title = "Comprá 3 mejoras chicas", desc = "El botón de mejoras en tu terreno", stat = "Extras", need = 3, reward = 120 },
	{ section = "Cadena", id = "depot", title = "Construí el Depósito", desc = "Stock 30% más barato", stat = "Depot", need = 1, reward = 1_000 },
	{ section = "Cadena", id = "trucks5", title = "Recibí 5 camiones", desc = "Ventana Depósito: PEDIR", stat = "Deliveries", need = 5, reward = 2_500 },
	{ section = "Cadena", id = "sell1k", title = "Vendé 1.000 productos", desc = "Más góndolas, más ventas", stat = "Sold", need = 1_000, reward = 5_000 },
	{ section = "Cadena", id = "earn100k", title = "Ganá $100K", desc = "Sumá todo lo cobrado", stat = "Earned", need = 100_000, reward = 15_000 },
	{ section = "Cadena", id = "stage5", title = "Abrí el Hipermercado", desc = "La última ampliación", stat = "Stage", need = 5, reward = 50_000 },
	{ section = "Cadena", id = "branch", title = "Abrí una sucursal", desc = "Ventana Sucursal", stat = "Branches", need = 1, reward = 100_000 },
}

-- Player level. XP comes from building, hiring, selling and missions; it is never reset,
-- not even by a new branch. Each level above 1 adds LevelBonus to every sale.
Config.XP = { extra = 15, product = 40, decor = 40, depot = 60, stage = 150, hire = 30, truck = 40, sale = 1 }
Config.LevelBonus = 0.02
Config.LevelCash = 100 -- cash gift per level reached, times the level

function Config.LevelNeed(level: number): number
	return 80 + level * 50
end

-- total XP -> level, XP into that level, XP the level needs
function Config.LevelOf(xp: number): (number, number, number)
	local level = 1
	while xp >= Config.LevelNeed(level) do
		xp -= Config.LevelNeed(level)
		level += 1
	end
	return level, xp, Config.LevelNeed(level)
end

function Config.QuestXP(quest: any): number
	return 20 + math.floor(math.sqrt(quest.reward)) * 2
end

-- Extra cash given on join when playing inside Studio, to test late-game things fast.
-- Ignored on live servers. Leave it at 0 for a normal start.
Config.StudioTestCash = 40000

Config.PlayerData = {
	storeName = "SupermarketEmpire_v1", -- never rename after launch
	schemaVersion = 1,
	migrations = {},
}
Config.Currency = {
	-- paid = true: the x2 Dinero pass makes Cash indirectly buyable with Robux
	currencies = { Cash = { start = 50, paid = true, leaderstat = true } },
	maxMultiplier = 20,
}

return Config
