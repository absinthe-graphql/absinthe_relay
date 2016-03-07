defmodule Absinthe.Relay.Resolver do

  alias Absinthe.Schema.Notation
  alias Absinthe.Relay.Node

  #
  # RESOLVE
  #

  @doc """
  Define a resolver for a field.

  If done within a `node field`, the resolver will receive a
  `%{type: a_type_name, id: an_id}` value as the first argument.

  ## Example

  ```
  query do

    node field do
      resolve fn
        %{type: :person, id: id}, _ ->
          {:ok, Map.get(@people, id)}
        %{type: :business, id: id}, _ ->
          {:ok, Map.get(@businesses, id)}
      end
    end

  end
  ```
  """
  defmacro resolve(raw_func_ast) do
    env = __CALLER__
    func_ast = resolve_body(env, scopes_status(env), raw_func_ast)
    Notation.record_resolve!(env, func_ast)
  end

  # Retrieve the AST for the resolver
  #
  # Wrapped with global ID handling if it is for a node field.
  defp resolve_body(_, [{:field, :node}, {:object, :query}], raw_func_ast) do
    Node.resolve_with_global_id(raw_func_ast)
  end
  # Bare if this isn't for a node field.
  defp resolve_body(env, _, raw_func_ast) do
    Notation.recordable!(env, :resolve)
    raw_func_ast
  end

  # Get tuples representing the current state of the scope
  # stack
  defp scopes_status(env) do
    Notation.Scope.on(env.module)
    |> Enum.map(fn
      scope ->
        {:%{}, [], ref_attrs} = scope.attrs[:__reference__]
        {scope.name, ref_attrs[:identifier]}
    end)
  end

end
