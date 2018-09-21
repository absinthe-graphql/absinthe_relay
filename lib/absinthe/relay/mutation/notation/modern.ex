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
  import Absinthe.Schema.Notation, only: [put_attr: 2]
  alias Absinthe.Schema.Notation

  @doc """
  Define a mutation with a single input and a client mutation ID. See the module documentation for more information.
  """
  defmacro payload({:field, meta, args}, do: block) do
    do_payload(meta, args, block)
  end

  defmacro payload({:field, meta, args}) do
    do_payload(meta, args, [])
  end

  defp do_payload(meta, [field_ident | rest], block) do
    block = rewrite_input_output(field_ident, block)

    {:field, meta, [field_ident, ident(field_ident, :payload) | rest] ++ [[do: block]]}
  end

  defp rewrite_input_output(field_ident, block) do
    Macro.prewalk(block, fn
      {:input, meta, args} ->
        {:input, meta, [ident(field_ident, :input) | args]}

      {:output, meta, args} ->
        {:output, meta, [ident(field_ident, :payload) | args]}

      node ->
        node
    end)
  end

  defp inspect_ast(ast, env) do
    string =
      ast
      |> Macro.to_string()
      |> Code.format_string!()

    IO.puts("#{env.line} #{string}")

    ast
  end

  #
  # INPUT
  #

  @doc """
  Defines the input type for your payload field. See the module documentation for an example.
  """
  defmacro input(identifier, do: block) do
    [
      quote do
        meta :absinthe_relay, input: unquote(__MODULE__)
      end,
      # We need to go up 2 levels so we can create the input object
      quote(do: Absinthe.Schema.Notation.stash()),
      quote(do: Absinthe.Schema.Notation.stash()),
      quote do
        input_object unquote(identifier) do
          unquote(block)
        end
      end,
      # Back down to finish the field
      quote(do: Absinthe.Schema.Notation.pop()),
      quote(do: Absinthe.Schema.Notation.pop())
    ]
  end

  #
  # PAYLOAD
  #

  @doc """
  Defines the output (payload) type for your payload field. See the module documentation for an example.
  """
  defmacro output(identifier, do: block) do
    [
      # We need to go up 2 levels so we can create the input object
      quote(do: Absinthe.Schema.Notation.stash()),
      quote(do: Absinthe.Schema.Notation.stash()),
      quote do
        object unquote(identifier) do
          unquote(block)
        end
      end,
      # Back down to finish the field
      quote(do: Absinthe.Schema.Notation.pop()),
      quote(do: Absinthe.Schema.Notation.pop())
    ]
  end

  # Construct a namespaced identifier
  def ident(base_identifier, category) do
    :"#{base_identifier}_#{category}"
  end
end
