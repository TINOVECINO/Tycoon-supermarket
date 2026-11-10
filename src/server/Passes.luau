--!strict
-- Game passes: who owns what, checked on the server. An id of 0 in AssetIds means the pass
-- is not set up yet, so nobody owns it and nothing is prompted.
-- Status: reviewed, not run in Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))
local AssetIds = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("AssetIds")) :: any

local Passes = {}
Passes.Changed = Signal.new() -- (player, key)

local owned: { [Player]: { [string]: boolean } } = {}

function Passes.Owns(player: Player, key: string): boolean
	local map = owned[player]
	return map ~= nil and map[key] == true
end

local function grant(player: Player, key: string)
	local map = owned[player]
	if map and not map[key] then
		map[key] = true
		Passes.Changed:Fire(player, key)
	end
end

local function check(player: Player)
	owned[player] = {}
	for key, id in AssetIds.Passes do
		if id ~= 0 then
			task.spawn(function()
				for attempt = 1, 3 do
					local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
					if ok then
						if has then
							grant(player, key)
						end
						return
					end
					task.wait(attempt * 2)
				end
			end)
		end
	end
end

function Passes.Init()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		check(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
	end)
	-- bought during this session: grant now, the ownership check covers later joins
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		for key, id in AssetIds.Passes do
			if id ~= 0 and id == passId then
				grant(player, key)
			end
		end
	end)
end

return Passes
