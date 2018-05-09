defmodule Absinthe.Relay.Node.Notation do
  @moduledoc """
  Macros used to define Node-related schema entities

  See `Absinthe.Relay.Node` for examples of use.
  """

  alias Absinthe.Schema.Notation

  @doc """
  Define a node interface, field, or object type for a schema.

  See the `Absinthe.Relay.Node` module documentation for examples.
  """
  defmacro node({:interface, _, _}, do: block) do
    do_interface(__CALLER__, block)
  end

  defmacro node({:field, _, _}, do: block) do
    do_field(__CALLER__, block)
  end

  defmacro node({:object, _, [identifier | rest]}, do: block) do
    do_object(__CALLER__, identifier, List.flatten(rest), block)
  end

  #
  # INTERFACE
  #

  # Add the node interface
  defp do_interface(env, block) do
    env
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
      [interface_body(), block]
    )
  end

  # An id field is automatically configured
  defp interface_body do
    quote do
      field :id, non_null(:id), description: "The id of the object."
    end
  end

  #
  # FIELD
  #

  # Add the node field
  defp do_field(env, block) do
    env
    |> Notation.recordable!(:field)
    |> record_field!(:node, [type: :node], block)
  end

  @doc false
  # Record the node field
  def record_field!(env, identifier, attrs, block) do
    Notation.record_field!(
      env,
      identifier,
      Keyword.put_new(attrs, :description, "Fetches an object given its ID"),
      [field_body(), block]
    )
  end

  # An id arg is automatically added
  defp field_body do
    quote do
      @desc "The id of an object."
      arg :id, non_null(:id)

      middleware {Absinthe.Relay.Node, :resolve_with_global_id}
    end
  end

  #
  # OBJECT
  #

  # Define a node object type
  defp do_object(env, identifier, attrs, block) do
    record_object!(env, identifier, attrs, block)
  end

  @doc false
  # Record a node object type
  def record_object!(env, identifier, attrs, block) do
    name = attrs[:name] || identifier |> Atom.to_string() |> Absinthe.Utils.camelize()

    Notation.record_object!(env, identifier, Keyword.delete(attrs, :id_fetcher), [
      object_body(name, attrs[:id_fetcher]),
      block
    ])

    Notation.desc_attribute_recorder(identifier)
  end

  # Automatically add:
  # - An id field that resolves to the generated global ID
  #   for an object of this type
  # - A declaration that this implements the node interface
  defp object_body(name, id_fetcher) do
    quote do
      @desc "The ID of an object"
      field :id, non_null(:id) do
        resolve Absinthe.Relay.Node.global_id_resolver(unquote(name), unquote(id_fetcher))
      end

      interface :node
    end
  end
end
