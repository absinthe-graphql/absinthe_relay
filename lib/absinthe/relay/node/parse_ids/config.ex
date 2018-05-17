defmodule Absinthe.Relay.Node.ParseIDs.Config do
  alias Absinthe.Relay.Node.ParseIDs.{Namespace, Rule}

  defstruct children: []

  @type node_t :: Namespace.t() | Rule.t()

  @type t :: %__MODULE__{
          children: [node_t]
        }

  def parse!(config) when is_map(config) do
    parse!(Keyword.new(config))
  end

  def parse!(config) when is_list(config) do
    parse!(config, %__MODULE__{})
  end

  defp parse!(config, %{children: _} = node) when is_list(config) do
    children =
      Enum.map(config, fn
        {key, [{_, _} | _] = value} ->
          parse!(value, %Namespace{key: key})

        {key, value} ->
          parse!(value, %Rule{key: key})

        other ->
          raise "Could not parse #{__MODULE__} namespace element: #{inspect(other)}"
      end)

    %{node | children: children}
  end

  defp parse!(value, %Rule{} = node) when is_atom(value) do
    %{node | expected_types: [value], output_mode: :simple}
  end

  defp parse!(value, %Rule{} = node) when is_list(value) do
    %{node | expected_types: value, output_mode: :full}
  end

  defp parse!(value, %Rule{}) do
    raise "Could not parse #{__MODULE__} rule: #{inspect(value)}"
  end
end
