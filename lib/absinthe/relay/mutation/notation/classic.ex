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
  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema
  alias Absinthe.Relay.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the module documentation for more information.
  """

  defmacro payload({:field, meta, args}, do: block) do
    Notation.payload(meta, args, [default_private(), block])
  end

  defmacro payload({:field, meta, args}) do
    Notation.payload(meta, args, default_private())
  end

  defp default_private() do
    [
      # This indicates to the Relay schema phase that this field should automatically
      # generate both input and payload types if they are not defined within the field
      # itself. The `input` notation also autogenerates the `input` argument to the field
      quote do
        private(:absinthe_relay, :payload, {:fill, unquote(__MODULE__)})
        private(:absinthe_relay, :input, {:fill, unquote(__MODULE__)})
      end
    ]
  end

  #
  # INPUT
  #

  @doc """
  Defines the input type for your payload field. See the module documentation for an example.
  """
  defmacro input(identifier, do: block) do
    Notation.input(__MODULE__, identifier, block)
  end

  #
  # PAYLOAD
  #

  @doc """
  Defines the output (payload) type for your payload field. See the module documentation for an example.
  """
  defmacro output(identifier, do: block) do
    Notation.output(__MODULE__, identifier, block)
  end

  def additional_types(:input, %Schema.FieldDefinition{identifier: field_ident}) do
    %Schema.InputObjectTypeDefinition{
      name: Notation.ident(field_ident, :input) |> Atom.to_string() |> Macro.camelize(),
      identifier: Notation.ident(field_ident, :input),
      module: __MODULE__,
      __private__: [absinthe_relay: [input: {:fill, __MODULE__}]],
      __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
    }
  end

  def additional_types(:payload, %Schema.FieldDefinition{identifier: field_ident}) do
    %Schema.ObjectTypeDefinition{
      name: Notation.ident(field_ident, :payload) |> Atom.to_string() |> Macro.camelize(),
      identifier: Notation.ident(field_ident, :payload),
      module: __MODULE__,
      __private__: [absinthe_relay: [payload: {:fill, __MODULE__}]],
      __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
    }
  end

  def additional_types(_, _), do: []

  def fillout(:input, %Schema.FieldDefinition{} = field) do
    Absinthe.Relay.Mutation.Notation.Modern.add_input_arg(field)
  end

  def fillout(:input, %Schema.InputObjectTypeDefinition{} = input) do
    # We could add this to the additional_types above, but we also need to fill
    # out this field if the user specified the types. It's easier to leave it out
    # of the defaults, and then unconditionally apply it after the fact.
    %{input | fields: [client_mutation_id_field() | input.fields]}
  end

  def fillout(:payload, %Schema.ObjectTypeDefinition{} = payload) do
    %{payload | fields: [client_mutation_id_field() | payload.fields]}
  end

  def fillout(_, node) do
    node
  end

  defp client_mutation_id_field() do
    %Blueprint.Schema.FieldDefinition{
      name: "client_mutation_id",
      identifier: :client_mutation_id,
      type: %Blueprint.TypeReference.NonNull{of_type: :string},
      module: __MODULE__,
      __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
    }
  end
end
