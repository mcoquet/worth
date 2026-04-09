defmodule Worth.Theme do
  @moduledoc """
  Behavior for theme implementations.

  Themes are self-contained modules that define:
  - Colors as Tailwind class mappings
  - Additional CSS (inline or static path)
  - Custom template overrides for UI elements

  ## Usage

      defmodule Worth.Theme.MyTheme do
        @behaviour Worth.Theme

        def name, do: "my_theme"
        def display_name, do: "My Theme"
        def description, do: "A beautiful custom theme"

        def colors do
          %{
            background: "bg-my-bg",
            primary: "text-my-primary",
            # ...
          }
        end

        def css, do: ""
        def has_template?(_), do: false
        def render(_, _), do: {:error, :not_found}
      end
  """

  @doc """
  Returns the internal theme name (used in config, CSS classes, etc.)
  """
  @callback name() :: String.t()

  @doc """
  Returns the human-readable display name for the theme
  """
  @callback display_name() :: String.t()

  @doc """
  Returns a description of the theme
  """
  @callback description() :: String.t()

  @doc """
  Returns a map of color class mappings for UI elements.
  Keys: background, surface, border, text, text_muted, primary, secondary, accent, success, error, etc.
  """
  @callback colors() :: map()

  @doc """
  Returns additional CSS for the theme (inline). Can be empty string if using static assets.
  """
  @callback css() :: String.t()

  @doc """
  Returns whether the theme has a custom template for the given element.
  Templates: :header, :sidebar, :left_panel, :input_bar, :message, :tabs
  """
  @callback has_template?(template :: atom()) :: boolean()

  @doc """
  Renders a custom template with the given assigns.
  Returns `{:ok, rendered_content}` or `{:error, :not_found}`.
  """
  @callback render(template :: atom(), assigns :: map()) ::
              {:ok, Phoenix.LiveView.Rendered.t()} | {:error, :not_found}

  @doc """
  Available template types that themes can override
  """
  def available_templates do
    [
      :header,
      :sidebar,
      :left_panel,
      :input_bar,
      :message,
      :tabs
    ]
  end
end
