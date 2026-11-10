--!strict
-- Every Roblox id the game uses, in one place. 0 = not set yet: the game keeps working and
-- the Tienda shows "configurá el id" instead of prompting a purchase.

return {
	-- Game passes: create them in Creator Hub > your experience > Monetization > Passes, then paste the ids here.
	Passes = {
		x2Cash = 0, -- x2 Dinero: every sale pays double
		x2Customers = 0, -- Clientes x2: customers come twice as often
	},
	-- LihFolk Asset Pack models already uploaded to the owner's account. InsertService only loads
	-- models owned by the experience's creator, so they appear once the place is published;
	-- until then part-built trees stand in. 0 = skip.
	Models = {
		PineTree_01 = 93412857979609,
		PineTree_03 = 90126867091005,
		Boulder_01 = 88451458056778,
		Boulder_07 = 131349899929187,
		Rock_03 = 126194259502953,
		Rock_09 = 99232703542235,
	},
	-- Icons from the FOLK Icon Pack. The files are in assets/icons/ with these same names.
	-- Uploaded to the owner's Roblox account on 2026-11-09 (image ids, not decal ids).
	-- If one is set to "", the kit's placeholder star is shown in its place.
	Icons = {
		stock = "rbxassetid://101276433247901", -- stock.png: rail square, Stock window
		staff = "rbxassetid://87423586493030", -- staff.png: rail square, Empleados window
		prices = "rbxassetid://112553850753173", -- prices.png: rail square, Precios window
		cash = "rbxassetid://136493712944797", -- cash.png: x2 Dinero pass
		-- one per product: Stock and Precios rows
		golosinas = "rbxassetid://115336862846110",
		bebidas = "rbxassetid://79050800419344",
		snacks = "rbxassetid://135489561912093",
		almacen = "rbxassetid://115677341604743",
		lacteos = "rbxassetid://81225887080062",
		verduleria = "rbxassetid://89887990445246",
		panaderia = "rbxassetid://75983090965005",
		carniceria = "rbxassetid://80942559915277",
		limpieza = "rbxassetid://109361146941024",
		electro = "rbxassetid://90339274502937",
	},
}
