defmodule Worth.LLM.Adapter do
  @callback chat(params :: map(), config :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
