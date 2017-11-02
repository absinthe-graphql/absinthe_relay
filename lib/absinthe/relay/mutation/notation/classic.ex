defmodule Absinthe.Relay.Mutation.Notation.Classic do

  @moduledoc """
  Macros used to define Mutation-related schema entities for Relay Classic.

  See `Absinthe.Relay.Mutation` for examples of use.
  """

  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the `Absinthe.Relay.Mutation` module documentation for more information.
  """
  defmacro payload({:field, _, [field_ident]}, [do: block]) do
    __CALLER__
    |> do_payload(field_ident, [], block)
  end
  defmacro payload({:field, _, [field_ident | rest]}, [do: block]) do
    __CALLER__
    |> do_payload(field_ident, List.flatten(rest), block)
  end
  defmacro payload({:field, _, [field_ident | rest]}) do
    __CALLER__
    |> do_payload(field_ident, List.flatten(rest), nil)
  end

  defp do_payload(env, field_ident, attrs, block) do
    env
    |> Notation.recordable!(:field)
    |> record_field!(field_ident, attrs, block)
  end

  @doc false
  # Record the mutation field
  def record_field!(env, field_ident, attrs, block) do
    {maybe_resolve_function, attrs} = case Keyword.pop(attrs, :resolve) do
      {nil, attrs} ->
        {[], attrs}
      {func_ast, attrs} ->
        ast = quote do
          resolve unquote(func_ast)
        end
        {ast, attrs}
    end
    Notation.record_field!(
      env,
      field_ident,
      Keyword.put(attrs, :type, ident(field_ident, :payload)),
      [
        field_body(field_ident),
        maybe_resolve_function,
        block,
        finalize()
      ]
    )
  end

  defp field_body(field_ident) do
    input_type_identifier = ident(field_ident, :input)
    quote do
      arg :input, non_null(unquote(input_type_identifier))

      middleware Absinthe.Relay.Mutation

      private Absinthe.Relay, :mutation_field_identifier, unquote(field_ident)
    end
  end

  defp finalize do
    quote do
      input do
        # Default!
      end
      output do
        # Default!
      end
    end
  end

  #
  # SHARED
  #

  @private_field_identifier_path [Absinthe.Relay, :mutation_field_identifier]

  # Common for both the input and payload objects
  defp client_mutation_id_field do
    quote do
      field :client_mutation_id, type: non_null(:string)
    end
  end

  #
  # INPUT
  #

  @doc """
  Defines the input type for your payload field. See the `Absinthe.Relay.Mutation` module documentation for an example.
  """
  defmacro input([do: block]) do
    env = __CALLER__
    Notation.recordable!(env, :mutation_input_type, private_lookup: @private_field_identifier_path)
    base_identifier = Notation.get_in_private(env.module, @private_field_identifier_path)
    record_input_object!(env, base_identifier, block)
  end

  @doc false
  # Record the mutation input object
  def record_input_object!(env, base_identifier, block) do
    identifier = ident(base_identifier, :input)
    unless already_recorded?(env.module, :input_object, identifier) do
      Notation.record_input_object!(env, identifier, [], [client_mutation_id_field(), block])
    end
  end

  #
  # PAYLOAD
  #

  @doc """
  Defines the output (payload) type for your payload field. See the `Absinthe.Relay.Mutation` module documentation for an example.
  """
  defmacro output([do: block]) do
    env = __CALLER__
    Notation.recordable!(env, :mutation_output_type, private_lookup: @private_field_identifier_path)
    base_identifier = Notation.get_in_private(env.module, @private_field_identifier_path)
    record_object!(env, base_identifier, block)
  end

  @doc false
  # Record the mutation input object
  def record_object!(env, base_identifier, block) do
    identifier = ident(base_identifier, :payload)
    unless already_recorded?(env.module, :object, identifier) do
      Notation.record_object!(env, identifier, [], [client_mutation_id_field(), block])
    end
  end

  #
  # UTILITIES
  #

  defp already_recorded?(mod, kind, identifier) do
    Notation.Scope.recorded?(mod, kind, identifier)
  end

  # Construct a namespaced identifier
  defp ident(base_identifier, category) do
    :"#{base_identifier}_#{category}"
  end

end
