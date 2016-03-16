defmodule Absinthe.Relay.Mutation do
  @moduledoc """
  Support for building mutations with single inputs and client mutation IDs.

  This module provides a macro, `payload`, that should be used by schema
  designers to support mutation fields that receive a single input object
  argument with a client mutation ID and return that ID as part of the
  response payload.

  More information can be found at:
  - https://facebook.github.io/relay/docs/graphql-mutations.html
  - https://facebook.github.io/relay/graphql/mutations.htm

  ## Example

  In this example we add a mutation field `:simple_mutation` that
  accepts an `input` argument (which is defined for us automatically)
  which contains an `:input_data` field.

  We also declare the output will contain a field, `:result`.

  Notice the `resolve` function doesn't need to know anything about the
  wrapping `input` argument -- it only concerns itself with the contents
  -- and the client mutation ID doesn't need to be dealt with, either. It
  will be returned as part of the response payload.

  ```
  mutation do
    payload field :simple_mutation do
      input do
        field :input_data, non_null(:integer)
      end
      output do
        field :result, :integer
      end
      resolve fn
        %{input_data: input_data}, _ ->
          # Some mutation side-effect here
          {:ok, %{result: input_data * 2}}
      end
    end
  end
  ```

  Here's a query document that would hit this field:

  ```graphql
  mutation DoSomethingSimple {
    simpleMutation(input: {inputData: 2, clientMutationId: "abc"}) {
      result
      clientMutationId
    }
  }
  ```

  And here's the response:

  ```json
  {
    "data": {
      "simpleMutation": {
        "result": 4,
        "clientMutationId": "abc"
      }
    }
  }
  ```

  Note the above code would create the following types in our schema, ad hoc:

  - `SimpleMutationInput`
  - `SimpleMutationPayload`

  For this reason, the identifier passed to `payload field` must be unique
  across your schema.
  """

  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the module documentation for more information.
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

  @doc false
  # System resolver to extract values from the input and return the
  # client mutation ID as part of the response.
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
  Defines the input type for your payload field. See the module documentation for more information.
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
    Notation.record_input_object!(env, identifier, [], [client_mutation_id_field, block])
  end

  #
  # PAYLOAD
  #

  @doc """
  Defines the output (payload) type for your payload field. See the module documentation for more information.
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
