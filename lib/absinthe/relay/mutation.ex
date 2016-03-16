defmodule Absinthe.Relay.Mutation do
  @moduledoc """
  Support for building mutations with single inputs and client mutation IDs.
  """

  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID.
  """
  defmacro payload({:field, _, [field_ident]}, [do: block]) do
    __CALLER__
    |> Notation.recordable!(:field)
    |> record_field!(field_ident, block)
  end

  @doc false
  # Record the mutation field
  def record_field!(env, field_ident, block) do
    Notation.record_field!(
      env,
      field_ident,
      [type: ident(field_ident, :payload)],
      [field_body(field_ident), block]
    )
  end

  #
  defp field_body(field_ident) do
    input_type_identifier = ident(field_ident, :input)
    quote do
      arg :input, non_null(unquote(input_type_identifier))
      private Absinthe.Relay, :mutation_field_identifier, unquote(field_ident)
      private Absinthe, :resolve, &Absinthe.Relay.Mutation.resolve_with_input/3
    end
  end

  def resolve_with_input(%{input: %{client_mutation_id: mut_id} = input}, info, designer_resolver) do
    case designer_resolver.(input, info) do
      {flag, value} when is_map(value) ->
        {flag, Map.put(value, :client_mutation_id, mut_id)}
      other ->
        # On your own!
        other
    end
  end
  def resolve_with_input(_, info, designer_resolver) do
    designer_resolver.(%{}, info)
  end

  #
  # SHARED
  #

  @private_field_identifier_path [Absinthe.Relay, :mutation_field_identifier]

  defp client_mutation_id_field do
    quote do
      field :client_mutation_id, type: non_null(:string)
    end
  end

  #
  # INPUT
  #

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
    Notation.record_input_object!(env, identifier, [], [client_mutation_id_field, block])
  end

  #
  # PAYLOAD
  #

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
    Notation.record_object!(env, identifier, [], [client_mutation_id_field, block])
  end

  #
  # UTILITIES
  #

  # Construct a namespaced identifier
  defp ident(base_identifier, category) do
    :"#{base_identifier}_#{category}"
  end

end
