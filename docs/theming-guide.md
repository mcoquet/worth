# Theming Guide

This guide explains how to create, customize, and apply themes in Worth.

## Overview

Worth's theme system allows complete UI transformations through:
- **Color mappings** - Tailwind class overrides
- **Custom CSS** - Additional styling and effects
- **Template overrides** - Custom UI components (future)

## Quick Start

### Using an Existing Theme

Add to your `~/.worth/config.exs`:

```elixir
%{
  theme: :cyberdeck,
  llm: %{...}
}
```

Themes available:
- `:standard` - Catppuccin Mocha (default)
- `:cyberdeck` - Tactical HUD with neon accents
- `:fifth_element` - Industrial retro-futuristic

### Applying Theme CSS

In your root layout, inject theme CSS in the `<head>`:

```elixir
# lib/worth_web/components/layouts.ex
<head>
  <%= raw(WorthWeb.ThemeHelper.css_tag()) %>
</head>
```

### Using Theme Colors in Components

```elixir
defmodule MyComponent do
  use Phoenix.Component
  
  def my_component(assigns) do
    ~H"""
    <div class={WorthWeb.ThemeHelper.color(:background)}>
      <h1 class={WorthWeb.ThemeHelper.color(:primary)}>
        Hello World
      </h1>
      <p class={WorthWeb.ThemeHelper.color(:text)}>
        Theme-aware text
      </p>
    </div>
    """
  end
end
```

## Available Color Keys

| Key | Description |
|-----|-------------|
| `background` | Main background |
| `surface` | Card/panel background |
| `surface_elevated` | Elevated surfaces |
| `border` | Border color |
| `text` | Primary text |
| `text_muted` | Secondary text |
| `text_dim` | Disabled/placeholder text |
| `primary` | Primary accent |
| `secondary` | Secondary accent |
| `accent` | Interactive elements |
| `success` | Success states |
| `error` | Error states |
| `warning` | Warning states |
| `info` | Info states |
| `button_primary` | Primary button style |
| `button_secondary` | Secondary button style |
| `tab_active` | Active tab style |
| `tab_inactive` | Inactive tab style |
| `status_running` | Running status indicator |
| `status_idle` | Idle status indicator |
| `status_error` | Error status indicator |

## Creating a Custom Theme

### Step 1: Create Theme Module

Create `lib/worth/theme/my_theme.ex`:

```elixir
defmodule Worth.Theme.MyTheme do
  @moduledoc """
  My custom theme description.
  """
  
  @behaviour Worth.Theme
  
  use Phoenix.Component

  @impl true
  def name, do: "my_theme"
  
  @impl true
  def display_name, do: "My Theme"
  
  @impl true
  def description, do: "A custom theme with unique styling"
  
  @impl true
  def colors do
    %{
      background: "bg-slate-900",
      surface: "bg-slate-800",
      surface_elevated: "bg-slate-700",
      border: "border-slate-600",
      text: "text-slate-100",
      text_muted: "text-slate-400",
      text_dim: "text-slate-500",
      primary: "text-blue-400",
      secondary: "text-purple-400",
      accent: "text-emerald-400",
      success: "text-green-400",
      error: "text-red-400",
      warning: "text-yellow-400",
      info: "text-cyan-400",
      button_primary: "bg-blue-500 hover:bg-blue-600 text-white",
      button_secondary: "bg-slate-700 hover:bg-slate-600 text-slate-200",
      tab_active: "border-b-2 border-blue-400 text-blue-400",
      tab_inactive: "text-slate-500 hover:text-slate-300",
      status_running: "text-yellow-400",
      status_idle: "text-slate-500",
      status_error: "text-red-400"
    }
  end
  
  @impl true
  def css do
    """
    /* Custom CSS for my theme */
    .my-custom-card {
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }
    
    .my-special-button {
      transition: all 0.2s ease;
    }
    """
  end
  
  @impl true
  def has_template?(_), do: false
  
  @impl true
  def render(_, _), do: {:error, :not_found}
end
```

### Step 2: Register Theme

Update `lib/worth/theme/registry.ex`:

```elixir
def list, do: [Standard, Cyberdeck, FifthElement, MyTheme]

def get("my_theme"), do: {:ok, MyTheme}
```

### Step 3: Use Theme

```elixir
# config/runtime.exs
config :worth, theme: :my_theme
```

## Advanced: Template Overrides

For complete UI transformations, themes can override templates:

```elixir
@impl true
def has_template?(:header), do: true
def has_template?(:sidebar), do: true
def has_template?(_), do: false

@impl true
def render(:header, assigns) do
  {:ok, custom_header_template(assigns)}
end

def render(:sidebar, assigns) do
  {:ok, custom_sidebar_template(assigns)}
end

def render(_, _), do: {:error, :not_found}

defp custom_header_template(assigns) do
  ~H"""
  <header class="my-custom-header">
    <!-- Full custom header HTML -->
  </header>
  """
end
```

## Theme Examples

### Fifth Element Theme

The Fifth Element theme transforms the UI into an industrial retro-futuristic interface:

**Colors:**
- Primary: `#FF8C00` (Industrial Orange)
- Text: `#00FF41` (Terminal Green)
- Background: `#0a0a0a` (Near Black)

**CSS Features:**
- Multi-Pass card styling with corner screws
- Glass viewport with backdrop blur
- CRT scanline overlay
- Warning strips on headers
- 3D emergency button styling
- Orbitron + Fira Code fonts

### Cyberdeck Theme

The Cyberdeck theme is inspired by Ops Center's tactical interface:

**Colors:**
- Primary: `#00D4FF` (Neon Cyan)
- Secondary: `#F0C040` (Electric Amber)
- Background: `#0c0c12` (Deep Void)

**CSS Features:**
- Corner bracket cards (`.cyber-card`)
- Subtle grid background
- CRT scanline overlay
- Neon glow effects
- JetBrains Mono font

## Debugging Themes

To check which theme is active:

```elixir
# In iex
iex> WorthWeb.ThemeHelper.current_theme().display_name()
"Cyberdeck"
```

To list available themes:

```elixir
iex> WorthWeb.ThemeHelper.available_themes()
[
  %{name: "standard", display_name: "Standard", description: "..."},
  %{name: "cyberdeck", display_name: "Cyberdeck", description: "..."},
  %{name: "fifth_element", display_name: "Fifth Element", description: "..."}
]
```

## Best Practices

1. **Use Tailwind classes** for colors - theme colors map to existing Tailwind utilities
2. **Keep CSS minimal** - put complex effects in the theme's `css/0` function
3. **Test all states** - ensure buttons, inputs, and status indicators look good
4. **Consider accessibility** - maintain sufficient contrast ratios
5. **Document your theme** - include clear description and screenshot

## File Structure

```
lib/worth/theme/
├── behaviour.ex       # Theme behavior callbacks
├── registry.ex        # Theme lookup and listing
├── standard.ex        # Default theme
├── cyberdeck.ex       # Alternative theme
├── fifth_element.ex   # Alternative theme
└── my_theme.ex        # Your custom theme
```

See [theme-system.md](theme-system.md) for detailed implementation notes.