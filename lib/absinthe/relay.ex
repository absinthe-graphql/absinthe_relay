defmodule Absinthe.Relay do
  @moduledoc """
  Relay support for Absinthe.

  - Global Identification: See `Absinthe.Relay.Node`
  - Connection Model: See `Absinthe.Relay.Connection`

  ## Examples

  Schemas should `use Absinthe.Relay.Schema`, eg:

  ```elixir
  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    # ...

  end
  ```

  For a type module, use `Absinthe.Relay.Schema.Notation`

  ```elixir
  defmodule Schema do
    use Absinthe.Schema.Notation
    use Absinthe.Relay.Schema.Notation

    # ...

  end
  ```

  See `Absinthe.Relay.Node` and `Absinthe.Relay.Connection` for
  specific macro information.
  """
end
