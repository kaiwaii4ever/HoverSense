--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Hover = require(ReplicatedStorage:WaitForChild("Hover"))

local hover = Hover.new()
hover:Init()
hover:Start()

local FADE_TIME = 0.15
local FADE_TWEEN_INFO = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function GiveHighlight(inst: Instance?)
	if not inst then return end
	if inst:FindFirstChild("HoverHighlight") then return end

	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1

	highlight.Parent = inst
	highlight.Name = "HoverHighlight"
	highlight.Enabled = false
end

local function TagCharacter(character: Model)
	CollectionService:AddTag(character, hover.Config.Tag)
	GiveHighlight(character)
end

local function PlayerAdded(player: Player)
	if player == Players.LocalPlayer then return end

	if player.Character then
		TagCharacter(player.Character)
	end

	player.CharacterAdded:Connect(TagCharacter)
end

for _, plr in Players:GetPlayers() do
	PlayerAdded(plr)
end

Players.PlayerAdded:Connect(PlayerAdded)

for _, inst in workspace:GetDescendants() do
	if inst:IsA("Model") and CollectionService:HasTag(inst, hover.Config.Tag) then
		GiveHighlight(inst)
	end
end

-----------------------------------------------------------

local activeTweens: { [Highlight]: Tween } = {}

local function FadeHighlight(highlight: Highlight, fillTransparency: number, outlineTransparency: number, disableWhenDone: boolean)
	local existing = activeTweens[highlight]
	if existing then
		existing:Cancel()
	end

	local tween = TweenService:Create(highlight, FADE_TWEEN_INFO, {
		FillTransparency = fillTransparency,
		OutlineTransparency = outlineTransparency,
	})

	activeTweens[highlight] = tween

	if disableWhenDone then
		local connection: RBXScriptConnection
		connection = tween.Completed:Connect(function(playbackState)
			connection:Disconnect()
			if playbackState == Enum.PlaybackState.Completed and activeTweens[highlight] == tween then
				highlight.Enabled = false
				activeTweens[highlight] = nil
			end
		end)
	end

	tween:Play()
end

hover.HoveringStarted:Connect(function(target: Instance)
	local highlight = target:FindFirstChild("HoverHighlight")
	if not highlight or not highlight:IsA("Highlight") then
		return
	end

	highlight.Enabled = true
	FadeHighlight(highlight, 0.5, 0.9, false)
end)

hover.HoveringEnded:Connect(function(target: Instance)
	local highlight = target:FindFirstChild("HoverHighlight")
	if not highlight or not highlight:IsA("Highlight") then
		return
	end

	FadeHighlight(highlight, 1, 1, true)
end)
