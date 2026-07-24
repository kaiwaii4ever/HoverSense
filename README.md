# HoverSense

A lightweight Roblox module for detecting mouse/touch/gamepad hover over tagged 3D instances, with click detection built in.

Hoverable instances are marked using a [CollectionService](https://create.roblox.com/docs/reference/engine/classes/CollectionService) tag (`"Hoverable"` by default), no manual raycasting or per-object setup required.

## Features

- Detects hover via mouse, touch, and gamepad input
- Configurable hover range and tag name
- Fires distinct signals for hover start, hover end, continuous hover, and click
- Client-only. Safe to require on the server (returns a no-op table)

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
HoverSense = "kaiwaii4ever/hoversense@1.0.1"
```

Then run:

```bash
wally install
```

## Usage

```lua
local HoverSense = require(path.to.HoeverSense)

local hover = HoverSense.new()
hover:Start()

hover.HoveringStarted:Connect(function(instance)
	print("Started hovering:", instance:GetFullName())
end)

hover.HoveringEnded:Connect(function(instance)
	print("Stopped hovering:", instance:GetFullName())
end)

hover.Clicked:Connect(function(instance)
	print("Clicked while hovering:", instance:GetFullName())
end)
```

Tag any part or model you want to be hoverable with the `"Hoverable"` CollectionService tag (or whatever tag you configure — see below).

### Custom configuration

```lua
local hover = HoverSense.new({
	HoverRange = 15,
	ContinuousHover = false,
	Tag = "MyCustomTag",
})
```

| Option            | Type    | Default       | Description                                                                           |
| ----------------- | ------- | ------------- | ------------------------------------------------------------------------------------- |
| `HoverRange`      | number  | `30`          | Max distance (studs) from the player's character to register a hover                  |
| `ContinuousHover` | boolean | `true`        | If `true`, `Hover` fires every frame while hovering; if `false`, only on state change |
| `Tag`             | string  | `"Hoverable"` | CollectionService tag used to mark hoverable instances                                |

### Cleanup

```lua
hover:Destroy()
```

Stops listening, disconnects all internal connections, and destroys all signals. Don't reuse the instance after calling this.

## API

Full API reference available in the [document](/api/Hover).

- `HoverSense.new(options?)` — creates a new instance
- `hover:Configure(options)` — update config after creation
- `hover:Start()` — begin listening for hovers
- `hover:Stop()` — stop listening and clear hover state
- `hover:GetHovered()` — returns the currently hovered instance, if any
- `hover:Destroy()` — stops and cleans up all connections/signals

### Signals

- `Hover` — fires while hovering (every frame if `ContinuousHover = true`)
- `HoveringStarted` — fires once when a new instance starts being hovered
- `HoveringEnded` — fires once when hover leaves an instance
- `Clicked` — fires when the currently hovered instance is clicked

## Dependencies

Included via Wally dependencies already

- [Signal](https://github.com/Sleitnick/RbxUtil/tree/main/modules/signal)
- [Observers](https://github.com/)

## License

MIT [LICENSE](https://github.com/kaiwaii4ever/HoverSense/blob/main/LICENSE)
