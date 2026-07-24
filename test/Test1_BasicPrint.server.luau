--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hover = require(ReplicatedStorage:WaitForChild("Hover"))

local hover = Hover.new()
hover:Init()
hover:Start()

local function TagCharacter(character: Model)
	CollectionService:AddTag(character, hover.Config.Tag)
end

local function PlayerAdded(player: Player)
	if player == Players.LocalPlayer then return end

	if player.Character then TagCharacter(player.Character) end

	player.CharacterAdded:Connect(TagCharacter)
end

for _, plr in Players:GetPlayers() do
	PlayerAdded(plr)
end

for _, inst in workspace:GetDescendants() do
	CollectionService:AddTag(inst, hover.Config.Tag)
end

Players.PlayerAdded:Connect(PlayerAdded)

-----------------------------------------------------------

hover.HoveringStarted:Connect(function(target)
	print("[Hover] started hovering:", target)
end)

hover.HoveringEnded:Connect(function(target)
	print("[Hover] stopped hovering:", target)
end)

hover.Clicked:Connect(function(target)
	print("[Hover] clicked:", target)
end)