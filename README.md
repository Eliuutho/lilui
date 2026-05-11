# LilUI

Minimalist Roblox UI library for executors. Glass-morphism, animated gradient borders, Lucide icons, anti-detection by default.

API-compatible with WindUI for drop-in replacement.

## Quick start

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Eliuutho/lilui/main/lilui.lua"))()

local Window = UI:CreateWindow({
    Title = "My Script",
    Author = "by you",
})

local Tab = Window:Tab({ Title = "Combat", Icon = "swords" })

Tab:Section({ Title = "Aimbot" })

Tab:Button({
    Title = "Click me",
    Desc = "Optional description",
    Callback = function()
        UI:Notify({ Title = "Hello", Content = "world", Duration = 3 })
    end,
})

Tab:Toggle = nil  -- not implemented, use Button + state var

Tab:Dropdown({
    Title = "Mode",
    Values = {"All", "Nearest", "Random"},
    Value = "All",
    Callback = function(v) print(v) end,
})

Tab:Keybind({
    Title = "Hotkey",
    Value = "P",
    Callback = function(key) print(key) end,
})
```

## API

### Window

| Method | Returns | Description |
|--------|---------|-------------|
| `UI:CreateWindow({Title, Author})` | Window | Create main window |
| `UI:Notify({Title, Content, Duration})` | nil | Toast notification |
| `Window:Tab({Title, Icon})` | Tab | Add a tab |
| `Window:SelectTab(index)` | nil | Select tab by index |
| `Window:Toggle()` | nil | Show/hide window |
| `Window:Destroy()` | nil | Clean up everything |

### Tab

| Method | Returns | Description |
|--------|---------|-------------|
| `Tab:Section({Title})` | Frame | Section header |
| `Tab:Paragraph({Title, Desc})` | obj | Static text with `:SetTitle/:SetDesc` |
| `Tab:Button({Title, Desc, Callback})` | TextButton | Clickable |
| `Tab:Dropdown({Title, Values, Value, Callback})` | obj | Dropdown with `:Refresh(values)` |
| `Tab:Keybind({Title, Value, Callback})` | obj | Hotkey capture |

## Icons

Uses [Lucide](https://lucide.dev) icons. Pass any Lucide icon name as `Icon`:

```lua
Window:Tab({ Title = "Settings", Icon = "settings" })
Window:Tab({ Title = "Combat",   Icon = "swords" })
Window:Tab({ Title = "Visual",   Icon = "eye" })
```

Browse all icons at [lucide.dev/icons](https://lucide.dev/icons).

## Configuration

Override the icons source URL by setting `getgenv().LILUI_ICONS_URL` before loading:

```lua
getgenv().LILUI_ICONS_URL = "https://your-domain.com/icons.lua"
local UI = loadstring(game:HttpGet(".../lilui.lua"))()
```

Useful if you want to serve icons from your own infrastructure (anti-detection).

## Anti-detection

- Parents to `gethui()` / `cloneref(CoreGui)` when available (hidden from game scripts)
- All Instance names randomized hex on each load
- No fixed string identifiers the game can grep for
- Falls back to `PlayerGui` only if executor lacks bypass functions

## License

MIT
