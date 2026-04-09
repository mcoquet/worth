# Theme System Design

## Overview

This document describes how to add a theme system to Worth, supporting:
1. **Standard Theme** - Current Catppuccin look (default)
2. **Alternative Themes** - Complete UI transformations like the "Fifth Element" proposal

## Design Inspiration

### Fifth Element Proposal (`design/brief.md`)

The design brief describes a complete transformation to a "lived-in" industrial interface inspired by Jean-Paul Gaultier's 23rd-century New York from the 1997 film:

| Original UI Element | Fifth Element Refactor |
|---------------------|----------------------|
| Dark Background | Animated Cityscape (flying traffic visible through glass) |
| Simple Sidebar | Hydraulic Chassis (orange metal frame with bolted corners) |
| Flat Tabs | Dial Selector (elemental icons: Fire, Water, Earth, Wind) |
| Small "Send" Button | Emergency Override Button (red, 3D, glowing) |
| Clean Text | Scanline Monospace (flickering terminal text) |

**Key Design Tokens:**
- Primary: Safety Orange (#FF8C00)
- Display: Terminal Green (#00FF41)
- Interactive: Taxi Yellow (#FDB813)
- Accents: Deep Chrome (#2C2C2C)

## Implementation

The theme system is implemented in `lib/worth/theme/`:

```
lib/worth/theme/
├── behaviour.ex       # Theme behavior (callbacks)
├── registry.ex         # Theme lookup + listing
├── standard.ex        # Catppuccin Mocha (default)
├── cyberdeck.ex       # Ops Center tactical HUD (alternative theme)
└── fifth_element.ex   # Moebius-style sci-fi (alternative theme)
```

### Theme Behavior

```elixir
# lib/worth/theme/behaviour.ex
defmodule Worth.Theme do
  @callback name() :: String.t()
  @callback display_name() :: String.t()
  @callback description() :: String.t()
  @callback colors() :: map()      # Color class mappings
  @callback css() :: String.t()    # Additional CSS
  @callback has_template?(atom()) :: boolean()
  @callback render(atom(), map()) :: {:ok, Phoenix.LiveView.Rendered.t()} | {:error, :not_found}
end
```

### Theme 1: Fifth Element (Design Proposal)

Full implementation based on `design/brief.md`:

```elixir
# lib/worth/theme/fifth_element.ex
def colors do
  %{
    background: "bg-[#0a0a0a]",
    primary: "text-[#FF8C00]",
    text: "text-[#00FF41]",
    # ...
  }
end

def css do
  """
  /* Multi-Pass Chassis */
  .multi-pass {
    border: 2px solid #FF8C00;
    border-radius: 12px;
  }
  
  /* Glass Viewport */
  .glass-viewport {
    backdrop-filter: blur(4px) brightness(0.8);
  }
  
  /* CRT Scanlines */
  .crt-overlay {
    background: repeating-linear-gradient(...);
  }
  """
end
```

### Theme 2: Cyberdeck (Ops Center Style)

Alternative theme inspired by `../ops_center`:

- Neon cyan/amber on void black
- Corner-bracket cards, grid backgrounds
- Monospace fonts, glow effects

### ThemeHelper

```elixir
# lib/worth_web/components/theme_helper.ex
def color(:primary)  # => "text-[#FF8C00]" (for fifth_element)
def css()           # => Returns full CSS string for theme
def css_tag()       # => "<style>...</style>"
```

### Config

```elixir
# config/runtime.exs
config :worth, theme: :fifth_element
```

Or via `~/.worth/config.exs`:

```elixir
%{
  theme: :cyberdeck,
  # ...
}
```

### Usage in Components

```elixir
# Using color helper
~H"""
<div class={WorthWeb.ThemeHelper.color(:background)}>
  <span class={WorthWeb.ThemeHelper.color(:primary)}>Hello</span>
</div>
"""

# Injecting CSS in layout head
<head>
  <%= raw(WorthWeb.ThemeHelper.css_tag()) %>
</head>
```

## Adding New Themes

To add a new theme:

1. Create `lib/worth/theme/my_theme.ex`
2. Implement the `Worth.Theme` behavior
3. Register in `lib/worth/theme/registry.ex`

Example:

```elixir
defmodule Worth.Theme.MyTheme do
  @behaviour Worth.Theme
  
  def name, do: "my_theme"
  def display_name, do: "My Theme"
  def description, do: "Description"
  
  def colors do
    %{
      background: "bg-[#000000]",
      primary: "text-[#00FF00]",
      # ...
    }
  end
  
  def css, do: ""
  def has_template?(_), do: false
  def render(_, _), do: {:error, :not_found}
end
```

## Migration Path

1. **Phase 1**: Create theme behavior + registry + Standard theme ✓
2. **Phase 2**: Implement FifthElement and Cyberdeck themes ✓
3. **Phase 3**: Add ThemeHelper to components for color mapping (in progress)
4. **Phase 4**: Update LiveView to pass theme to components
5. **Phase 5**: Add `/theme` command for runtime switching
6. **Phase 6**: (Future) Add custom template overrides per theme