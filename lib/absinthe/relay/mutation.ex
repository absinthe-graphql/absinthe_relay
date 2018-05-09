defmodule Absinthe.Relay.Mutation do
  @moduledoc """
  Middleware to support the macros located in:

  - For Relay Modern:  `Absinthe.Relay.Mutation.Notation.Modern`
  - For Relay Classic: `Absinthe.Relay.Mutation.Notation.Classic`

  Please see those modules for specific instructions.
  """

  @doc false

  # System resolver to extract values from the input and return the
  # client mutation ID (the latter for Relay Classic only) as part of the response.
  def call(%{state: :unresolved} = res, _) do
    case res.arguments do
      %{input: %{client_mutation_id: mut_id} = input} ->
        %{
          res
          | arguments: input,
            private:
              Map.merge(res.private, %{__client_mutation_id: mut_id, __parse_ids_root: :input}),
            middleware: res.middleware ++ [__MODULE__]
        }

      %{input: input} ->
        %{
          res
          | arguments: input,
            private: Map.merge(res.private, %{__parse_ids_root: :input}),
            middleware: res.middleware ++ [__MODULE__]
        }

      _ ->
        res
    end
  end

  def call(%{state: :resolved, value: value} = res, _) when is_map(value) do
    mut_id = res.private[:__client_mutation_id]

    %{res | value: Map.put(value, :client_mutation_id, mut_id)}
  end

  def call(res, _) do
    res
  end
end
