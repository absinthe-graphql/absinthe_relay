defmodule Absinthe.Relay.Node.IDTranslator do
  @moduledoc """
  An ID translator handles encoding and decoding a global ID
  used in a Relay node.

  This module provides the behaviour for implementing an ID Translator.
  An example use case of this module would be a translator that encrypts the 
  global ID.

  To use an ID Translator in your schema there are two methods.

  #### Inline Config
  ```
  defmodule MyApp.Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, [
      flavor: :modern,
      global_id_translator: MyApp.Absinthe.IDTranslator
    ]

    # ...

  end
  ```

  #### Mix Config
  ```
  config Absinthe.Relay, MyApp.Schema,
    global_id_translator: MyApp.Absinthe.IDTranslator
  ```

  ## Example ID Translator

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

  @doc """
  Converts a node's type name and ID to a globally unique ID.

  Returns `{:ok, global_id}` on success.

  Returns `{:error, binary}` on failure.
  """
  @callback to_global_id(
              type_name :: binary,
              source_id :: binary | integer,
              schema :: Absinthe.Schema.t()
            ) :: {:ok, global_id :: Absinthe.Relay.Node.global_id()} | {:error, binary}

  @doc """
  Converts a globally unique ID to a node's type name and ID.

  Returns `{:ok, type_name, source_id}` on success.

  Returns `{:error, binary}` on failure.
  """
  @callback from_global_id(
              global_id :: Absinthe.Relay.Node.global_id(),
              schema :: Absinthe.Schema.t() | nil
            ) :: {:ok, type_name :: binary, source_id :: binary} | {:error, binary}
end
