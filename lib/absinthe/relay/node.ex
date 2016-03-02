defmodule Absinthe.Relay.Node do

  use Absinthe.Schema.Notation

  defmacro node_interface([do: block]) do
    __interface__(:node, block)
  end

  defmacro node_field([do: block]) do
    __field__(:node, :node, block)
  end

  defmacro node_object(identifier, [do: block]) do
    __object__(identifier, [], block)
  end
  defmacro node_object(identifier, opts, [do: block]) do
    __object__(identifier, opts, block)
  end

  defp __interface__(identifier, block) do
    quote do
      @desc "An object with an ID"
      interface unquote(identifier) do
        @desc "The id of the object."
        field :id, non_null(:id)
        unquote(block)
      end
    end
  end

  defp __field__(identifier, interface_identifier, block) do
    quote do
      @desc "Fetches an object given its ID"
      field unquote(identifier), unquote(interface_identifier) do

        @desc "The id of an object."
        arg :id, non_null(:id)

        wrap_resolve fn
          %{resolver: resolver}, %{id: global_id}, info ->
            case Absinthe.Relay.Node.from_global_id(global_id, info.schema) do
              {:ok, result} ->
                resolver.(result, info)
              other ->
                other
            end
        end

        unquote(block)

      end
    end
  end

  defp __object__(identifier, opts, block) do
    name = opts[:name] || identifier |> Atom.to_string |> Absinthe.Utils.camelize
    quote do
      object unquote(identifier), unquote(opts) do
        @desc "The ID of an object"
        field :id, non_null(:id) do
          resolve Absinthe.Relay.Node.global_id_resolver(unquote(name), unquote(Macro.escape(opts[:id_fetcher])))
        end
        unquote(block)
      end
    end
  end

  def from_global_id(global_id, schema) do
    case Base.decode64(global_id) do
      {:ok, decoded} ->
        String.split(decoded, ":", parts: 2)
        |> do_from_global_id(decoded, schema)
      :error ->
        {:error, "Could not decode ID value `#{global_id}'"}
    end
  end

  defp do_from_global_id([type_name, id], _, schema) when byte_size(id) > 0 and byte_size(type_name) > 0 do
    case schema.__absinthe_type__(type_name) do
      nil ->
        {:error, "Unknown type `#{type_name}'"}
      %{reference: %{identifier: ident}, interfaces: interfaces} ->
        if Enum.member?(interfaces || [], :node) do
          {:ok, %{type: ident, id: id}}
        else
          {:error, "Type `#{type_name}' is not a valid node type"}
        end
    end
  end
  defp do_from_global_id(_, decoded, _schema) do
    {:error, "Could not extract value from decoded ID `#{decoded}'"}
  end

  defp decode(value) do
    case Base.decode64(value) do
      {:ok, _} = result ->
        result
      _ ->
        {:error, ""}
    end
  end

  def to_global_id(node_type, nil) do
    {:error, "No source non-global ID value present on object"}
  end
  def to_global_id(node_type, source_id) do
    {:ok, "#{node_type}:#{source_id}" |> Base.encode64}
  end

  # The resolver for a global ID. If a type identifier instead of a type name
  # is used during field configuration, the type name needs to be looked up
  # during resolution.
  def global_id_resolver(identifier, nil)  do
    global_id_resolver(identifier, &default_id_fetcher/2)
  end
  def global_id_resolver(identifier, id_fetcher) when is_atom(identifier) do
    fn obj, info ->
      type = Absinthe.Schema.lookup_type(info.schema, identifier)
      to_global_id(
        type.name,
        id_fetcher.(info.source, info)
      )
    end
  end
  def global_id_resolver(type_name, id_fetcher) when is_binary(type_name) do
    fn _, info ->
      to_global_id(
        type_name,
        id_fetcher.(info.source, info)
      )
    end
  end

  @doc """
  The default ID fetcher used to retrieve raw, non-global IDs from values.

  * Matches `:id` out of the value.
    * If it's `nil`, it returns `nil`
    * If it's not nil, it coerces it to a binary using `Kernel.to_string/1`

  ## Examples

  ```
  iex> default_id_fetcher(%{id: "foo"})
  "foo"
  iex> default_id_fetcher(%{id: 123})
  "123"
  iex> default_id_fetcher(%{id: nil})
  nil
  iex> default_id_fetcher(%{nope: "no_id"})
  nil
  ```
  """
  @spec default_id_fetcher(any, Execution.Field.t) :: nil | binary
  def default_id_fetcher(%{id: id}, _info) when is_nil(id), do: nil
  def default_id_fetcher(%{id: id}, _info), do: id |> to_string
  def default_id_fetcher(_, _), do: nil

end
