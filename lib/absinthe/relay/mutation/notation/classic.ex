defmodule Absinthe.Relay.Mutation.Notation.Classic do
  @moduledoc """
  Support for Relay Classic mutations with single inputs and client mutation IDs.

  The `payload` macro can be used by schema designers to support mutation
  fields that receive a single input object argument with a client mutation ID
  and return that ID as part of the response payload.

  More information can be found at https://facebook.github.io/relay/docs/guides-mutations.html

  ## Example

  In this example we add a mutation field `:simple_mutation` that
  accepts an `input` argument (which is defined for us automatically)
  which contains an `:input_data` field.

  We also declare the output will contain a field, `:result`.

  Notice the `resolve` function doesn't need to know anything about the
  wrapping `input` argument -- it only concerns itself with the contents
  -- and the client mutation ID doesn't need to be dealt with, either. It
  will be returned as part of the response payload automatically.

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

  ## The Escape Hatch

  The mutation macros defined here are just for convenience; if you want something that goes against these
  restrictions, don't worry! You can always just define your types and fields using normal (`field`, `arg`,
  `input_object`, etc) schema notation macros as usual.
  """
  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the module documentation for more information.
  """
  defmacro payload({:field, _, [field_ident]}, do: block) do
    __CALLER__
    |> do_payload(field_ident, [], block)
  end

  defmacro payload({:field, _, [field_ident | rest]}, do: block) do
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
    {maybe_resolve_function, attrs} =
      case Keyword.pop(attrs, :resolve) do
        {nil, attrs} ->
          {[], attrs}

        {func_ast, attrs} ->
          ast =
            quote do
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

      private(Absinthe.Relay, :mutation_field_identifier, unquote(field_ident))
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
  Defines the input type for your payload field. See the module documentation for an example.
  """
  defmacro input(do: block) do
    env = __CALLER__

    Notation.recordable!(
      env,
      :mutation_input_type,
      private_lookup: @private_field_identifier_path
    )

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
  Defines the output (payload) type for your payload field. See the module documentation for an example.
  """
  defmacro output(do: block) do
    env = __CALLER__

    Notation.recordable!(
      env,
      :mutation_output_type,
      private_lookup: @private_field_identifier_path
    )

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
