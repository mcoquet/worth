%{
  configs: %{
    worth: [
      checks: [
        {Credo.Check.Consistency.TabsOrSpaces, []},
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Warning.IoInspect, []}
      ]
    ]
  }
}
