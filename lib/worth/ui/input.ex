defmodule Worth.UI.Input do
  @moduledoc """
  Single-line input prompt at the bottom of the TUI.

  Includes keybinding hints bar inspired by Lazygit:
  - ? help
  - : command palette
  - / search
  """

  import TermUI.Component.Helpers
  alias Worth.UI.Theme

  @keyhints [
    {"?", "help"},
    {":", "cmd"},
    {"/", "search"},
    {"Tab", "sidebar"}
  ]

  def render(state) do
    input_line = text("> #{state.input_text}", Theme.user_style())
    keyhint_line = render_keyhints()

    stack(:vertical, [input_line, keyhint_line])
  end

  defp render_keyhints() do
    hints_str =
      @keyhints
      |> Enum.map(fn {key, action} ->
        "[#{key}] #{action}"
      end)
      |> Enum.join("  ")

    text(hints_str, Theme.keyhint_style())
  end
end
