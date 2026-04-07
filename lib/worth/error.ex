defmodule Worth.Error do
  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          context: map()
        }

  defexception [:reason, :message, :context]

  def new(reason, message, context \\ %{}) do
    %__MODULE__{reason: reason, message: message, context: context}
  end

  @impl true
  def message(%__MODULE__{message: message}) do
    message
  end
end
