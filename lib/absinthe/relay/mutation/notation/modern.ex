defmodule Absinthe.Relay.Mutation.Notation.Modern do
  @moduledoc """
  Convenience macros for Relay Modern mutations.

  (If you want `clientMutationId` handling, see `Absinthe.Relay.Mutation.Notation.Classic`!)

  The `payload` macro can be used by schema designers to support mutation
  fields that receive either:

  - A single non-null input object argument (using the `input` macro in this module)
  - Any arguments you want to use (using the normal `arg` macro)

  More information can be found at https://facebook.github.io/relay/docs/mutations.html

  ## Example

  In this example we add a mutation field `:simple_mutation` that
  accepts an `input` argument of a new type (which is defined for us
  because we use the `input` macro), which contains an `:input_data`
  field.

  We also declare the output will contain a field, `:result`.

  Notice the `resolve` function doesn't need to know anything about the
  wrapping `input` argument -- it only concerns itself with the contents.
  The input fields are passed to the resolver just like they were declared
  as separate top-level arguments.

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
    simpleMutation(input: {inputData: 2}) {
      result
    }
  }
  ```

  And here's the response:

  ```json
  {
    "data": {
      "simpleMutation": {
        "result": 4
      }
    }
  }
  ```

  Note the above code would create the following types in our schema, ad hoc:

  - `SimpleMutationInput`
  - `SimpleMutationPayload`

  For this reason, the identifier passed to `payload field` must be unique
  across your schema.

  ## Using your own arguments

  You are free to just declare your own arguments instead. The `input` argument and type behavior
  is only activated for your mutation field if you use the `input` macro.

  You're free to define your own arguments using `arg`, as usual, with one caveat: don't call one `:input`.

  ## The Escape Hatch

  The mutation macros defined here are just for convenience; if you want something that goes against these
  restrictions, don't worry! You can always just define your types and fields using normal (`field`, `arg`,
  `input_object`, etc) schema notation macros as usual.
  """
  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Schema
  alias Absinthe.Relay.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the module documentation for more information.
  """
  defmacro payload({:field, meta, args}, do: block) do
    Notation.payload(meta, args, [block_private(), block])
  end

  defmacro payload({:field, meta, args}) do
    Notation.payload(meta, args, block_private())
  end

  defp block_private() do
    # This indicates to the Relay schema phase that this field should automatically
    # generate the payload type for this field if it is not explicitly created
    quote do
      private(:absinthe_relay, :payload, {:fill, unquote(__MODULE__)})
    end
  end

  #
  # INPUT
  #

  @doc """
  Defines the input type for your payload field. See the module documentation for an example.
  """
  defmacro input(identifier, do: block) do
    [
      # Only if the `input` macro is actually used should we mark the field
      # as using an input type, autogenerating the `input` argument on the field.
      quote do
        private(:absinthe_relay, :input, {:fill, unquote(__MODULE__)})
      end,
      Notation.input(__MODULE__, identifier, block)
    ]
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
    add_input_arg(field)
  end

  def fillout(_, node) do
    node
  end

  def add_input_arg(field) do
    arg = %Schema.InputValueDefinition{
      identifier: :input,
      name: "input",
      type: %Blueprint.TypeReference.NonNull{of_type: Notation.ident(field.identifier, :input)},
      module: __MODULE__,
      __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
    }

    %{
      field
      | arguments: [arg | field.arguments],
        middleware: [Absinthe.Relay.Mutation | field.middleware]
    }
  end
end
