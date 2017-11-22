defmodule Absinthe.Relay.Node.IDTranslator.Error do
  @moduledoc """
  Exception raised when unable to translate to or from a global ID.
  """
  defexception message: "Failed to translate Global ID"

  def exception(message) do
    %__MODULE__{message: message}
  end
end