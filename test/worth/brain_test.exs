defmodule Worth.BrainTest do
  use ExUnit.Case

  @workspace "personal"

  test "brain starts and responds to get_status" do
    status = Worth.Brain.get_status(@workspace)
    assert Map.has_key?(status, :status)
    assert Map.has_key?(status, :cost)
    assert Map.has_key?(status, :workspace)
    assert Map.has_key?(status, :mode)
  end

  test "switch_mode changes the mode" do
    :ok = Worth.Brain.switch_mode(@workspace, :research)
    status = Worth.Brain.get_status(@workspace)
    assert status.mode == :research

    Worth.Brain.switch_mode(@workspace, :code)
  end

  test "switch_workspace changes workspace" do
    :ok = Worth.Brain.switch_workspace(@workspace, "personal")
    status = Worth.Brain.get_status("personal")
    assert status.workspace == "personal"
  end
end
