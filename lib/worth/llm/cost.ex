defmodule Worth.LLM.Cost do
  @pricing %{
    "claude-sonnet-4-20250514" => {3.0, 15.0},
    "claude-haiku-4-20250414" => {0.80, 4.0},
    "claude-opus-4-20250514" => {15.0, 75.0},
    "gpt-4o" => {2.5, 10.0},
    "gpt-4o-mini" => {0.15, 0.6}
  }

  @default_pricing {3.0, 15.0}

  def calculate(usage, model) do
    {input_price, output_price} = Map.get(@pricing, model, @default_pricing)

    input_tokens = (usage["input_tokens"] || usage[:input_tokens] || 0) / 1_000_000
    output_tokens = (usage["output_tokens"] || usage[:output_tokens] || 0) / 1_000_000

    input_price * input_tokens + output_price * output_tokens
  end
end
