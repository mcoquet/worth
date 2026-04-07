defmodule Worth.BrainTest do
  use ExUnit.Case

  test "brain starts and responds to get_status" do
    status = Worth.Brain.get_status()
    assert Map.has_key?(status, :status)
    assert Map.has_key?(status, :cost)
    assert Map.has_key?(status, :workspace)
    assert Map.has_key?(status, :mode)
  end

  test "switch_mode changes the mode" do
    :ok = Worth.Brain.switch_mode(:research)
    status = Worth.Brain.get_status()
    assert status.mode == :research

    Worth.Brain.switch_mode(:code)
  end

  test "switch_workspace changes workspace" do
    :ok = Worth.Brain.switch_workspace("personal")
    status = Worth.Brain.get_status()
    assert status.workspace == "personal"
  end
end
