defmodule Absinthe.Relay.Node do

  alias Absinthe.Schema.Notation

  defmacro node_interface([do: block]) do
    __CALLER__
    |> Notation.recordable!(:interface)
    |> record_interface!(:node, [], block)
    Notation.desc_attribute_recorder(:node)
  end

  @doc false
  # Record the node interface
  def record_interface!(env, identifier, attrs, block) do
    Notation.record_interface!(
      env,
      identifier,
      Keyword.put_new(attrs, :description, "An object with an ID"),
      [interface_body, block]
    )
  end
  defp interface_body do
    quote do
      field :id, non_null(:id), description: "The id of the object."
    end
  end

  defmacro node_field([do: block]) do
    __CALLER__
    |> Notation.recordable!(:field)
    |> record_field!(:node, [type: :node], block)
  end

  def record_field!(env, identifier, attrs, block) do
    Notation.record_field!(
      env,
      identifier,
      Keyword.put_new(attrs, :description, "Fetches an object given its ID"),
      [field_body, block]
    )
  end
  defp field_body do
    quote do
      @desc "The id of an object."
      arg :id, non_null(:id)
    end
  end

  defmacro resolve(raw_func_ast) do
    env = __CALLER__
    func_ast = resolve_body(env, raw_func_ast)
    Notation.record_resolve!(env, func_ast)
  end

  defp resolve_body(env, raw_func_ast) do
    case scopes_above(env) do
      [{:field, :node}, {:object, :query}] ->
        wrap_resolve(raw_func_ast)
      _ ->
        Notation.recordable!(env, :resolve)
        raw_func_ast
    end
  end

  defp scopes_above(env) do
    Notation.Scope.on(env.module)
    |> Enum.map(fn
      scope ->
        {:%{}, [], ref_attrs} = scope.attrs[:__reference__]
        {scope.name, ref_attrs[:identifier]}
    end)
  end

  defp wrap_resolve(raw_func_ast) do
    quote do
      fn
        %{id: global_id}, info ->
          case Absinthe.Relay.Node.from_global_id(global_id, info.schema) do
            {:ok, result} ->
              user_resolver = unquote(raw_func_ast)
              user_resolver.(result, info)
            other ->
              other
          end
        args, info ->
          IO.inspect(args: args, fields: info.definition)
          user_resolver = unquote(raw_func_ast)
          user_resolver.(%{}, info)
      end
    end
  end

  defmacro node_object(identifier, [do: block]) do
    record_object!(__CALLER__, identifier, [], block)
  end
  defmacro node_object(identifier, attrs, [do: block]) do
    record_object!(__CALLER__, identifier, attrs, block)
  end

  def record_object!(env, identifier, attrs, block) do
    name = attrs[:name] || identifier |> Atom.to_string |> Absinthe.Utils.camelize
    Notation.record_object!(
      env,
      identifier,
      attrs,
      [object_body(name, attrs[:id_fetcher]), block]
    )
    Notation.desc_attribute_recorder(identifier)
  end
  defp object_body(name, id_fetcher) do
    quote do
      @desc "The ID of an object"
      field :id, non_null(:id) do
        resolve Absinthe.Relay.Node.global_id_resolver(unquote(name), unquote(id_fetcher))
      end
      interface :node
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
      %{__reference__: %{identifier: ident}, interfaces: interfaces} ->
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

  def to_global_id(_node_type, nil) do
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
    fn _obj, info ->
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
