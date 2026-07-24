--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))
local Observers = require(Packages:WaitForChild("Observers"))

export type HoverConfig = {
	HoverRange: number,
	ContinuousHover: boolean,
	Tag: string,
}

export type Hover = {
	Config: HoverConfig,

	Configure: (self: Hover, options: {[string]: any}) -> (),
	GetHovered: (self: Hover) -> Instance?,
	Init: (self: Hover) -> (),
	Start: (self: Hover) -> (),
	Stop: (self: Hover) -> (),
	Destroy: (self: Hover) -> (),

	Hover: Signal.Signal<Instance>,
	HoveringStarted: Signal.Signal<Instance>,
	HoveringEnded: Signal.Signal<Instance>,
	Clicked: Signal.Signal<Instance>,

	_hoverables: {[Instance]: boolean},
	_hovered: Instance?,
	_initialized: boolean,
	_started: boolean,
	_initStopFns: { () -> () },

	_findHoverableAncestor: (self: Hover, instance: Instance?) -> Instance?,
	_process: (self: Hover, instance: Instance?, distance: number) -> (),
	_processClick: (self: Hover) -> (),
	_clearHoverState: (self: Hover) -> (),
	_updateHoverState: (self: Hover, candidate: Instance?) -> (),
}

--[=[
	@class Hover

	Detects when the player's mouse (or touch/gamepad cursor) is hovering
	over tagged instances in the 3D world, using a raycast from the camera.

	Hoverable instances are marked using a CollectionService tag (configurable
	via `Config.Tag`, default `"Hoverable"`).

	:::info
	This module is client-only. Requiring it on the server returns an empty table.
	:::

	```lua
	local hover = Hover.new()
	hover:Start()

	hover.HoveringStarted:Connect(function(instance)
		print("Started hovering:", instance:GetFullName())
	end)

	hover.Clicked:Connect(function(instance)
		print("Clicked while hovering:", instance:GetFullName())
	end)
	```
]=]
local Hover = {}
Hover.__index = Hover

if RunService:IsServer() then return (Hover :: any) end

local localPlayer = Players.LocalPlayer :: Player

local DEFAULT_CONFIG: HoverConfig = {
	HoverRange = 30,
	ContinuousHover = true,
	Tag = "Hoverable",
}

local CLICK_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Gamepad1] = true,
}

-- #HELPERS#

local function getRootPart(character: Model?): BasePart?
	if not character then
		return nil
	end
	return (character.PrimaryPart :: BasePart?) or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

type MouseRayImpl = {
	_camera: Camera?,
	_rootPart: BasePart?,
	_raycastParams: RaycastParams,
	_subscribers: {[Hover]: boolean},
	_subscriberCount: number,
	_initialized: boolean,
	_initStopFns: {() -> ()},
	_runConns: {RBXScriptConnection},

	_init: (self: MouseRayImpl) -> (),
	_raycastFromMouse: (self: MouseRayImpl) -> (Instance?, number),
	_startLoop: (self: MouseRayImpl) -> (),
	_stopLoop: (self: MouseRayImpl) -> (),
	Subscribe: (self: MouseRayImpl, hoverInstance: Hover) -> (),
	Unsubscribe: (self: MouseRayImpl, hoverInstance: Hover) -> (),
}

local MouseRay: MouseRayImpl = {} :: MouseRayImpl

MouseRay._camera = workspace.CurrentCamera
MouseRay._rootPart = nil
MouseRay._raycastParams = RaycastParams.new()
MouseRay._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
MouseRay._raycastParams.IgnoreWater = true

MouseRay._subscribers = {}
MouseRay._subscriberCount = 0
MouseRay._initialized = false
MouseRay._initStopFns = {}
MouseRay._runConns = {}

function MouseRay:_init()
	if self._initialized then return end
	self._initialized = true

	table.insert(
		self._initStopFns,
		Observers.observeProperty(workspace, "CurrentCamera", function(newCamera: any | Camera?)
			self._camera = newCamera
			return function() end
		end)
	)

	table.insert(
		self._initStopFns,
		Observers.observeProperty(localPlayer, "Character", function(character: any | Model?)
			self._rootPart = getRootPart(character)
			self._raycastParams.FilterDescendantsInstances = if character then { character } else {}

			for hoverInstance in self._subscribers do
				hoverInstance:_clearHoverState()
			end

			return function() self._rootPart = nil end
		end)
	)
end

function MouseRay:_raycastFromMouse(): (Instance?, number)
	if not self._camera then return nil, math.huge end

	local location = UserInputService:GetMouseLocation()
	local viewportRay = self._camera:ViewportPointToRay(location.X, location.Y)

	local ok, result = pcall(function()
		return workspace:Raycast(viewportRay.Origin, viewportRay.Direction * 1000, self._raycastParams)
	end)

	if not ok or not result then return nil, math.huge end

	local distance = if self._rootPart then (result.Position - self._rootPart.Position).Magnitude else math.huge
	return result.Instance, distance
end

function MouseRay:_startLoop()
	table.insert(
		self._runConns,
		RunService.RenderStepped:Connect(function()
			local instance, distance = self:_raycastFromMouse()

			for hoverInstance in self._subscribers do
				hoverInstance:_process(instance, distance)
			end
		end)
	)

	table.insert(
		self._runConns,
		UserInputService.InputBegan:Connect(function(input: InputObject, GPE: boolean)
			if GPE then return end
			if not CLICK_INPUT_TYPES[input.UserInputType] then return end

			for hoverInstance in self._subscribers do
				hoverInstance:_processClick()
			end
		end)
	)
end

function MouseRay:_stopLoop()
	for _, conn in self._runConns do conn:Disconnect() end
	self._runConns = {}
end

function MouseRay:Subscribe(hoverInstance: Hover)
	if self._subscribers[hoverInstance] then return end

	self:_init()
	self._subscribers[hoverInstance] = true
	self._subscriberCount += 1

	if self._subscriberCount == 1 then
		self:_startLoop()
	end
end

function MouseRay:Unsubscribe(hoverInstance: Hover)
	if not self._subscribers[hoverInstance] then return end

	self._subscribers[hoverInstance] = nil
	self._subscriberCount -= 1

	if self._subscriberCount <= 0 then
		self._subscriberCount = 0
		self:_stopLoop()
	end
end

-- #CONSTRUCTOR#

--[=[
	@within Hover
	@param options table? -- Optional initial config overrides, see [Hover.Configure]
	@return Hover

	Creates a new `Hover` instance. Does not start listening for hovers —
	call [Hover:Start] to begin.
]=]
function Hover.new(options: { [string]: any }?): Hover
	local self = setmetatable({}, Hover) :: any

	self.Config = table.clone(DEFAULT_CONFIG)

	self.Hover = Signal.new() :: Signal.Signal<Instance>
	self.HoveringStarted = Signal.new() :: Signal.Signal<Instance>
	self.HoveringEnded = Signal.new() :: Signal.Signal<Instance>
	self.Clicked = Signal.new() :: Signal.Signal<Instance>

	self._hoverables = {}
	self._hovered = nil

	self._initialized = false
	self._started = false

	self._initStopFns = {}

	if options then self:Configure(options) end

	return self
end

--[=[
	@within Hover
	@param options table -- A table of config keys to override

	Overrides one or more values in [Hover.Config]. Valid keys are
	`HoverRange`, `ContinuousHover`, and `Tag`. Unknown keys produce a warning
	and are ignored.
]=]
function Hover:Configure(options: { [string]: any })
	for key, value in pairs(options) do
		if (self.Config :: any)[key] == nil then
			warn(("Hover.Configure: unknown option '%s'"):format(tostring(key)))
		else
			(self.Config :: any)[key] = value
		end
	end
end

-- #INTERNAL HELPERS#

function Hover:_findHoverableAncestor(instance: Instance?): Instance?
	local current = instance
	while current do
		if self._hoverables[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Hover:_process(instance: Instance?, distance: number)
	local withinRange = distance <= self.Config.HoverRange

	local candidate: Instance? = nil
	if instance and withinRange then
		candidate = self:_findHoverableAncestor(instance)
	end

	self:_updateHoverState(candidate)
end

function Hover:_processClick()
	if self._hovered then self.Clicked:Fire(self._hovered) end
end

function Hover:_clearHoverState()
	if self._hovered then
		self.HoveringEnded:Fire(self._hovered)
		self._hovered = nil
	end
end

function Hover:_updateHoverState(candidate: Instance?)
	local current = self._hovered

	if candidate ~= current then
		if current then
			self.HoveringEnded:Fire(current)
		end
		self._hovered = candidate
		if candidate then
			self.HoveringStarted:Fire(candidate)
		end
	end

	if candidate and (self.Config.ContinuousHover or candidate ~= current) then
		self.Hover:Fire(candidate)
	end
end

-- #PUBLIC ACCESSORS#

--[=[
	@within Hover
	@return Instance? -- The currently hovered instance, if any

	Returns the instance currently being hovered, or `nil` if nothing is hovered.
]=]
function Hover:GetHovered(): Instance?
	return self._hovered
end

-- #INIT#

--[=[
	@within Hover

	Sets up tag observation so tagged instances become hoverable. Called
	automatically by [Hover:Start] if not already initialized — you generally
	don't need to call this yourself.
]=]
function Hover:Init()
	local hoverSelf = self :: Hover

	if hoverSelf._initialized then return end
	hoverSelf._initialized = true

	table.insert(
		hoverSelf._initStopFns,
		Observers.observeTag(hoverSelf.Config.Tag, function(instance: Instance)
			hoverSelf._hoverables[instance] = true

			return function()
				hoverSelf._hoverables[instance] = nil
				if hoverSelf._hovered == instance then
					hoverSelf._hovered = nil
					hoverSelf.HoveringEnded:Fire(instance)
				end
			end
		end)
	)
end

-- #START / STOP#

--[=[
	@within Hover

	Begins listening for mouse/touch/gamepad hovers over tagged instances.
	Calls [Hover:Init] automatically if it hasn't run yet.
]=]
function Hover:Start()
	if not self._initialized then
		self:Init()
	end
	if self._started then
		return
	end
	self._started = true

	MouseRay:Subscribe(self)
end

--[=[
	@within Hover

	Stops listening for hovers and clears any current hover state, firing
	[Hover.HoveringEnded] if something was being hovered.
]=]
function Hover:Stop()
	if not self._started then
		return
	end
	self._started = false

	MouseRay:Unsubscribe(self)
	self:_clearHoverState()
end

--[=[
	@within Hover

	Stops the instance, disconnects all internal listeners, and destroys its
	signals. The `Hover` instance should not be used after calling this.
]=]
function Hover:Destroy()
	self:Stop()

	if self._initialized then
		self._initialized = false
		for _, stopFn in self._initStopFns do
			stopFn()
		end
		self._initStopFns = {}
	end

	self._hoverables = {}

	self.Hover:Destroy()
	self.HoveringStarted:Destroy()
	self.HoveringEnded:Destroy()
	self.Clicked:Destroy()
end

return Hover