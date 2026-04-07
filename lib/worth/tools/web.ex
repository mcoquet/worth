defmodule Worth.Tools.Web do
  @moduledoc false

  def definitions do
    [
      %{
        "name" => "web_fetch",
        "description" => "Fetch and parse content from a URL. Returns the page content as text.",
        "input_schema" => %{
          "type" => "object",
          "properties" => %{
            "url" => %{"type" => "string", "description" => "The URL to fetch"},
            "format" => %{"type" => "string", "description" => "Response format: text or markdown", "default" => "text"}
          },
          "required" => ["url"]
        }
      },
      %{
        "name" => "web_search",
        "description" => "Search the web using a search API. Returns search results.",
        "input_schema" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{"type" => "string", "description" => "Search query"},
            "limit" => %{"type" => "integer", "description" => "Max results (default: 5)", "default" => 5}
          },
          "required" => ["query"]
        }
      }
    ]
  end

  def execute("web_fetch", input, _ctx) do
    url = input["url"]

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        content = if is_binary(body), do: body, else: inspect(body)
        {:ok, String.slice(content, 0, 50_000)}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  def execute("web_search", _input, _ctx) do
    {:error, "Web search not configured. Set up a search API key in config."}
  end
end
