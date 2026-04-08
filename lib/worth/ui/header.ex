defmodule Worth.UI.Header do
  @moduledoc """
  Top bar with status indicator, workspace, mode badge, cost, and model.

  Renders as a single styled line:
  `○ worth │ workspace │ [code] │ t5 │ $0.0012 (model)`
  """

  import TermUI.Component.Helpers
  alias TermUI.Renderer.Style
  alias Worth.UI.Theme

  @separator "│"

  def render(state) do
    indicator = status_indicator(state.status)
    mode_badge = "[#{state.mode}]"
    cost = cost_display(state.cost)
    turns = "t#{state.turn}"
    model = model_display(state)

    segments =
      [
        {"#{indicator} worth", Theme.style_for(:header)},
        {state.workspace, Style.new(fg: :white)},
        {mode_badge, Theme.badge_style()},
        {turns, Style.new(fg: :bright_black)},
        {cost, Style.new(fg: :yellow)},
        {model, Style.new(fg: :bright_black)}
      ]
      |> Enum.reject(fn {text, _} -> text == "" end)

    line =
      segments
      |> Enum.map(&elem(&1, 0))
      |> Enum.join(" #{@separator} ")

    style =
      segments
      |> Enum.map(&elem(&1, 1))
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(Style.new(), &Style.merge(&2, &1))

    text(line, style)
  end

  def separator(width) do
    text(String.duplicate("─", width), Style.new(fg: :bright_black))
  end

  defp status_indicator(:running), do: "●"
  defp status_indicator(:idle), do: "○"
  defp status_indicator(:error), do: "×"

  defp cost_display(cost) when is_float(cost) do
    "$#{:erlang.float_to_binary(cost, [{:decimals, 4}])}"
  end

  defp model_display(state) do
    primary = Map.get(state.models, :primary, %{})
    label = Map.get(primary, :label, "")
    if label != "", do: "(#{label})", else: ""
  end
end
