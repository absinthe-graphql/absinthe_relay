defmodule Absinthe.Relay do
  @moduledoc """
  Relay support for Absinthe.

  - Global Identification: See `Absinthe.Relay.Node`
  - Connection Model: See `Absinthe.Relay.Connection`
  - Mutations: See `Absinthe.Relay.Mutation`

  ## Examples

  Schemas should `use Absinthe.Relay.Schema` and can optionally select
  either `:modern` (targeting Relay v1.0+) or `:classic` (targeting Relay < v1.0):

  ```elixir
  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    # ...

  end
  ```

  For a type module, use `Absinthe.Relay.Schema.Notation` instead:

  ```elixir
  defmodule Schema do
    use Absinthe.Schema.Notation
    use Absinthe.Relay.Schema.Notation, :modern

    # ...

  end
  ```

  If you do not indicate `:modern` or `:classic`---in v1.4 of this
  package---the default of `:classic` will be used.  A deprecation
  notice will be output indicating that this behavior will change in
  v1.5 (to `:modern`).

  See `Absinthe.Relay.Node`, `Absinthe.Relay.Connection`, and
  `Absinthe.Relay.Mutation` for specific macro information.
  """
end
