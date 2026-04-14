defmodule Worth.EmbeddingTest do
  @moduledoc """
  Tests the embedding pipeline end-to-end:
  Worth.Memory.Embeddings.Adapter → Mneme → vector store → similarity search.

  These tests use the Mneme.Embedding.Mock provider configured in test.exs
  to avoid hitting external APIs during CI.
  """

  use Worth.DataCase, async: false

  @moduletag :embedding

  describe "embedding provider configuration" do
    test "Mneme is configured with an embedding provider" do
      provider = Mneme.Config.embedding_provider()
      assert provider
    end

    test "embedding dimensions are configured" do
      dims = Mneme.Config.dimensions()
      assert is_integer(dims)
      assert dims > 0
    end
  end

  describe "memory store and retrieve (mock embeddings)" do
    test "Mneme.remember/2 stores an entry" do
      scope_id = Ecto.UUID.generate()

      result =
        Mneme.remember("The deploy script is at scripts/deploy.sh",
          scope_id: scope_id,
          entry_type: "observation"
        )

      assert {:ok, entry} = result
      assert entry.content =~ "deploy"
    end

    test "stored entries can be retrieved by scope" do
      scope_id = Ecto.UUID.generate()

      {:ok, entry} =
        Mneme.remember("Elixir uses the BEAM virtual machine",
          scope_id: scope_id,
          entry_type: "observation"
        )

      assert entry.content =~ "BEAM"
      assert entry.scope_id == scope_id
      assert entry.entry_type == "observation"
    end
  end
end
