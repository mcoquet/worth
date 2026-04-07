defmodule Worth.ConfigTest do
  use ExUnit.Case, async: true

  test "get returns config values" do
    assert Worth.Config.get(:cost_limit) != nil
  end

  test "get returns default for missing keys" do
    assert Worth.Config.get(:nonexistent_key, "default") == "default"
  end

  test "get_all returns all config" do
    config = Worth.Config.get_all()
    assert is_map(config)
  end
end
