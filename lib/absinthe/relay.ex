defmodule Absinthe.Relay do
  @moduledoc """
  Relay support for Absinthe.

  - Global Identification: See `Absinthe.Relay.Node`
  - Connection Model: See `Absinthe.Relay.Connection`

  ## Examples

  Schemas and type modules should `use Absinthe.Relay` to
  have access to the macros defined in this package.

  For example, in a schema:

  ```elixir
  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay

    # ...

  end
  ```

  In a different module where you're defining types:

  ```elixir
  defmodule Schema do
    use Absinthe.Schema.Notation
    use Absinthe.Relay

    # ...

  end
  ```

  See `Absinthe.Relay.Node` and `Absinthe.Relay.Connection` for
  specific macro information.
  """

  defmacro __using__(_opts) do
    quote do
      import Absinthe.Relay.Node, only: :macros
      import Absinthe.Relay.Connection, only: :macros
      import_types Absinthe.Relay.Connection.Types
    end
  end

end
