defmodule Worth.ErrorTest do
  use ExUnit.Case, async: true

  test "creates error with reason and message" do
    error = Worth.Error.new(:not_found, "Thing not found")
    assert error.reason == :not_found
    assert error.message == "Thing not found"
    assert Exception.message(error) == "Thing not found"
  end

  test "creates error with context" do
    error = Worth.Error.new(:validation, "Invalid input", %{field: "name"})
    assert error.context == %{field: "name"}
  end
end
