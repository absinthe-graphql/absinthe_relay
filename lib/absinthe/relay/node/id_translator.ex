defmodule Absinthe.Relay.Node.IDTranslator do
  @moduledoc """
  An ID translator handles encoding and decoding a global ID
  used in a relay node.

  This module provides the behaviour for implementing an ID Translator.
  Example use cases of this module would be a translator that encypts the 
  global ID or perhaps use a different base encoding.
  
  ## Example

  A basic example that encodes the global ID by joining the `type_name` and
  `source_id` with `":"`.

  ```
  defmodule MyApp.Absinthe.IDTranslator do
    @behaviour Absinthe.Relay.Node.IDTranslator

    def to_global_id(type_name, source_id, _schema) do
      {:ok, "\#{type_name}:\#{source_id}"}
    end
        
    def from_global_id(global_id, _schema) do
      case String.split(global_id, ":", parts: 2) do
        [type_name, source_id] ->
          {:ok, type_name, source_id}
        _ ->
          {:error, "Could not extract value from ID `\#{inspect global_id}`"}
      end
    end
  end
  ```
  """
    
  @callback to_global_id(type_name :: binary, source_id :: binary | integer, schema :: atom) :: {:ok, binary} | {:error, binary}
    
  @callback from_global_id(global_id :: binary, schema :: atom) :: {:ok, binary, binary} | {:error, binary}

end