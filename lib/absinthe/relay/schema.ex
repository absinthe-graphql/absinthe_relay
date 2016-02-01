defmodule Absinthe.Relay.Schema do

  defmacro __using__(opts) do
    quote do
      use Absinthe.Schema

      @behaviour unquote(__MODULE__)

      @absinthe :type
      def node do
        Absinthe.Relay.Node.interface(&node_type_resolver/2)
      end

    end
  end

  @callback node_type_resolver(any, Absinthe.Execution.t) :: Absinthe.Type.t

end
