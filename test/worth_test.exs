defmodule WorthTest do
  use ExUnit.Case, async: true

  test "worth application starts" do
    assert Process.whereis(Worth.Supervisor) != nil
    assert Process.whereis(Worth.Repo) != nil
    assert Process.whereis(Worth.Brain) != nil
  end
end
