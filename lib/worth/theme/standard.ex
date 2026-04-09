defmodule Worth.Theme.Standard do
  @moduledoc """
  Standard theme - Catppuccin Mocha (default).

  A soft dark theme with pastel accents.
  """

  @behaviour Worth.Theme

  def name, do: "standard"
  def display_name, do: "Standard"
  def description, do: "Catppuccin Mocha - soft dark theme with pastel accents"

  def colors do
    %{
      background: "bg-ctp-mantle",
      surface: "bg-ctp-surface0",
      surface_elevated: "bg-ctp-surface1",
      border: "border-ctp-surface0",
      text: "text-ctp-text",
      text_muted: "text-ctp-subtext0",
      text_dim: "text-ctp-overlay0",
      primary: "text-ctp-blue",
      secondary: "text-ctp-lavender",
      accent: "text-ctp-yellow",
      success: "text-ctp-green",
      error: "text-ctp-red",
      warning: "text-ctp-peach",
      info: "text-ctp-mauve",
      # Button classes
      button_primary: "bg-ctp-blue text-ctp-base hover:bg-ctp-lavender",
      button_secondary: "bg-ctp-surface1 text-ctp-text hover:bg-ctp-surface2",
      # Tab classes
      tab_active: "bg-ctp-blue text-ctp-base",
      tab_inactive: "text-ctp-subtext0 hover:text-ctp-text hover:bg-ctp-surface0",
      # Status indicators
      status_running: "text-ctp-blue",
      status_idle: "text-ctp-overlay0",
      status_error: "text-ctp-red",
      # Message wrapper classes
      message_user_bg: "bg-ctp-surface0/50",
      message_error_bg: "bg-ctp-red/10 border border-ctp-red/30",
      message_thinking_border: "border-l-2 border-ctp-mauve/30",
      message_system_bg: "bg-ctp-mauve/5 border border-ctp-mauve/20",
      # Input classes
      input_placeholder: "placeholder-ctp-overlay0",
      input_disabled_bg: "bg-ctp-surface1",
      input_disabled_text: "text-ctp-overlay0"
    }
  end

  def css do
    """
    /* Standard Theme - Reset to Catppuccin Mocha defaults */
    :root {
      --color-ctp-base: #1e1e2e;
      --color-ctp-mantle: #181825;
      --color-ctp-crust: #11111b;
      --color-ctp-surface0: #313244;
      --color-ctp-surface1: #45475a;
      --color-ctp-surface2: #585b70;
      --color-ctp-overlay0: #6c7086;
      --color-ctp-overlay1: #7f849c;
      --color-ctp-overlay2: #9399b2;
      --color-ctp-text: #cdd6f4;
      --color-ctp-subtext0: #a6adc8;
      --color-ctp-subtext1: #bac2de;
      --color-ctp-blue: #89b4fa;
      --color-ctp-lavender: #b4befe;
      --color-ctp-green: #a6e3a1;
      --color-ctp-yellow: #f9e2af;
      --color-ctp-red: #f38ba8;
      --color-ctp-teal: #94e2d5;
      --color-ctp-mauve: #cba6f7;
      --color-ctp-peach: #fab387;
      --color-ctp-pink: #f5c2e7;
      --color-ctp-sky: #89dcfe;
      --color-ctp-flamingo: #f2cdcd;
      --color-ctp-rosewater: #f5e0dc;
      --color-ctp-sapphire: #74c7ec;
    }
    """
  end

  def has_template?(_), do: false
  def render(_, _), do: {:error, :not_found}
end
