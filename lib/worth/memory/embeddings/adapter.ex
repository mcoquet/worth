defmodule Worth.Memory.Embeddings.Adapter do
  @moduledoc """
  Bridges Mneme's `Mneme.EmbeddingProvider` behaviour to the unified
  `AgentEx.LLM.embed_tier/3` stack.

  Configured in `config/config.exs`:

      config :mneme,
        embedding: [
          provider: Worth.Memory.Embeddings.Adapter,
          tier: :embeddings
        ]

  Tier resolution lives in `AgentEx.LLM.embed_tier/3` — it walks the
  catalog for `:embeddings`-tagged models, optionally filtered by the
  IDENTITY.md frontmatter tier override.
  """

  @behaviour Mneme.EmbeddingProvider

  alias AgentEx.LLM

  @default_tier :embeddings
  @default_dimensions 1536
  @default_model "text-embedding-3-small"

  @impl true
  def dimensions(opts) do
    Keyword.get(opts, :dimensions, @default_dimensions)
  end

  @impl true
  def generate(texts, opts) when is_list(texts) do
    tier = Keyword.get(opts, :tier, @default_tier)

    case LLM.embed_tier(texts, tier, embed_opts(opts)) do
      {:ok, vectors, _model_id} -> {:ok, vectors}
      {:error, %{message: message}} -> {:error, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def embed(text, opts) when is_binary(text) do
    tier = Keyword.get(opts, :tier, @default_tier)

    case LLM.embed_tier(text, tier, embed_opts(opts)) do
      {:ok, [vector | _], _model_id} -> {:ok, vector}
      {:ok, [], _model_id} -> {:error, :no_embedding_returned}
      {:error, %{message: message}} -> {:error, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def model_id(opts) do
    case Keyword.get(opts, :model) do
      nil ->
        case Keyword.get(opts, :model_override) do
          nil -> @default_model
          override when is_binary(override) -> override
        end

      model when is_binary(model) ->
        model
    end
  end

  defp embed_opts(opts) do
    opts
    |> Keyword.take([:provider, :model])
  end
end
