defmodule Worth.LLM.Anthropic do
  @behaviour Worth.LLM.Adapter

  @base_url "https://api.anthropic.com/v1/messages"

  @impl true
  def chat(params, config) do
    api_key = config[:api_key]
    model = config[:default_model] || "claude-sonnet-4-20250514"

    if is_nil(api_key) or api_key == "" do
      {:error, "ANTHROPIC_API_KEY not configured"}
    else
      messages = transform_messages(params["messages"] || params[:messages] || [])
      tools = transform_tools(params["tools"] || params[:tools])

      body =
        %{
          model: model,
          max_tokens: params["max_tokens"] || 4096,
          messages: messages
        }
        |> maybe_add_system(params)
        |> maybe_add_tools(tools)
        |> maybe_add_stream(params)

      headers = [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]

      case Req.post(@base_url, json: body, headers: headers, receive_timeout: 120_000) do
        {:ok, %{status: 200, body: response}} ->
          {:ok, normalize_response(response)}

        {:ok, %{status: status, body: %{"error" => %{"message" => msg}}}} ->
          {:error, "Anthropic API error (#{status}): #{msg}"}

        {:error, exception} ->
          {:error, "HTTP error: #{Exception.message(exception)}"}
      end
    end
  end

  defp transform_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        "role" => msg["role"] || msg[:role],
        "content" => msg["content"] || msg[:content]
      }
    end)
  end

  defp maybe_add_system(body, params) do
    case params["system"] || params[:system] do
      nil -> body
      system -> Map.put(body, :system, system)
    end
  end

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_stream(body, _params), do: body

  defp transform_tools(nil), do: []
  defp transform_tools(tools) when is_list(tools), do: tools

  defp normalize_response(response) do
    %{
      "content" => response["content"] || [],
      "stop_reason" => response["stop_reason"] || "end_turn",
      "usage" => %{
        "input_tokens" => get_in(response, ["usage", "input_tokens"]) || 0,
        "output_tokens" => get_in(response, ["usage", "output_tokens"]) || 0
      }
    }
  end
end
