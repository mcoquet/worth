defmodule Worth.LLM.OpenRouter do
  @behaviour Worth.LLM.Adapter

  @base_url "https://openrouter.ai/api/v1/chat/completions"

  @impl true
  def chat(params, config) do
    api_key = config[:api_key]
    model = config[:default_model] || "anthropic/claude-sonnet-4"

    if is_nil(api_key) or api_key == "" do
      {:error, "OPENROUTER_API_KEY not configured"}
    else
      messages = transform_messages(params["messages"] || params[:messages] || [])

      body = %{
        model: model,
        messages: messages,
        max_tokens: params["max_tokens"] || 4096
      }

      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"content-type", "application/json"}
      ]

      case Req.post(@base_url, json: body, headers: headers, receive_timeout: 120_000) do
        {:ok, %{status: 200, body: response}} ->
          {:ok, normalize_response(response)}

        {:ok, %{status: status, body: %{"error" => %{"message" => msg}}}} ->
          {:error, "OpenRouter API error (#{status}): #{msg}"}

        {:error, exception} ->
          {:error, "HTTP error: #{Exception.message(exception)}"}
      end
    end
  end

  defp transform_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      role = msg["role"] || msg[:role]
      content = msg["content"] || msg[:content]
      %{"role" => role, "content" => content}
    end)
  end

  defp normalize_response(response) do
    choice = hd(response["choices"] || [%{}])

    %{
      "content" => [
        %{
          "type" => "text",
          "text" => get_in(choice, ["message", "content"]) || ""
        }
      ],
      "stop_reason" => choice["finish_reason"] || "stop",
      "usage" => %{
        "input_tokens" => get_in(response, ["usage", "prompt_tokens"]) || 0,
        "output_tokens" => get_in(response, ["usage", "completion_tokens"]) || 0
      }
    }
  end
end
