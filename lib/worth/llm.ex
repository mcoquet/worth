defmodule Worth.LLM do
  @moduledoc false

  def chat(params, config \\ %{}) do
    provider = config[:llm][:default_provider] || :anthropic
    providers = config[:llm][:providers] || %{}

    case Map.get(providers, provider) do
      nil ->
        {:error, "No provider configured for #{provider}"}

      provider_config ->
        adapter = adapter_for(provider)
        adapter.chat(params, provider_config)
    end
  end

  defp adapter_for(:anthropic), do: Worth.LLM.Anthropic
  defp adapter_for(:openai), do: Worth.LLM.OpenAI
  defp adapter_for(:openrouter), do: Worth.LLM.OpenRouter
  defp adapter_for(_other), do: Worth.LLM.Anthropic
end
