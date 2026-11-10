--!strict
-- Supermarket Empire: the only server Script. Order matters:
--   map -> data config -> services (slices + remotes) -> load players.
-- Status: reviewed, not run in Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Lib = ServerScriptService:WaitForChild("LihFolk")
local GameServer = ServerScriptService:WaitForChild("GameServer")
local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("GameConfig")) :: any

local PlayerData = require(Lib:WaitForChild("PlayerData"))
local Currency = require(Lib:WaitForChild("Currency"))

local World = require(GameServer:WaitForChild("World"))
local Passes = require(GameServer:WaitForChild("Passes"))
local Store = require(GameServer:WaitForChild("Store"))
local Customers = require(GameServer:WaitForChild("Customers"))

-- Max players is set in Studio (Game Settings > Places), to Config.Plots: one plot each.
-- A player who joins with every plot taken is told the server is full.

World.Build()

-- 1. Data layer
PlayerData.Configure(Config.PlayerData)

-- 2. Services
Currency.Init(Config.Currency)
Passes.Init()
Store.Init()
Customers.Init()

-- 3. Load players last
PlayerData.Start()
