defmodule Worth.Theme.Registry do
  @moduledoc """
  Theme registry - manages available themes and lookups.
  """

  alias Worth.Theme.{Standard, Cyberdeck, FifthElement}

  @doc """
  Returns all available themes
  """
  def list, do: [Standard, Cyberdeck, FifthElement]

  @doc """
  Get a theme module by name
  """
  def get("standard"), do: {:ok, Standard}
  def get("cyberdeck"), do: {:ok, Cyberdeck}
  def get("fifth_element"), do: {:ok, FifthElement}
  def get(_), do: {:error, :not_found}

  @doc """
  Returns the default theme
  """
  def default, do: Standard

  @doc """
  Get theme from config or return default
  """
  def resolve do
    case Application.get_env(:worth, :theme, "standard") |> get() do
      {:ok, theme} -> theme
      {:error, _} -> default()
    end
  end
end
