defmodule Absinthe.Relay.Node.Notation do
  @moduledoc """
  Macros used to define Node-related schema entities

  See `Absinthe.Relay.Node` for examples of use.

  If you wish to use this module on its own without `use Absinthe.Relay` you
  need to include
  ```
  @pipeline_modifier Absinthe.Relay.Schema
  ```
  in your root schema module.
  """

  alias Absinthe.Blueprint.Schema

  @doc """
  Define a node interface, field, or object type for a schema.

  See the `Absinthe.Relay.Node` module documentation for examples.
  """
  defmacro node({:interface, meta, attrs}, do: block) do
    attrs = attrs || []
    attrs = [:node | attrs]
    block = [interface_body(), block]
    {:interface, meta, attrs ++ [[do: block]]}
  end

  defmacro node({:field, meta, attrs}, do: block) do
    {:field, meta, [:node, :node, (attrs || []) ++ [do: [field_body(), block]]]}
  end

  defmacro node({:object, meta, [identifier, attrs]}, do: block) when is_list(attrs) do
    do_object(meta, identifier, attrs, block)
  end

  defmacro node({:object, meta, [identifier]}, do: block) do
    do_object(meta, identifier, [], block)
  end

  defp do_object(meta, identifier, attrs, block) do
    {id_fetcher, attrs} = Keyword.pop(attrs, :id_fetcher)

    block = [
      quote do
        private(:absinthe_relay, :node, {:fill, unquote(__MODULE__)})
        private(:absinthe_relay, :id_fetcher, unquote(id_fetcher))
      end,
      object_body(id_fetcher),
      block
    ]

    {:object, meta, [identifier, attrs] ++ [[do: block]]}
  end

  def additional_types(_, _), do: []

  # def fillout(:node, %Schema.ObjectTypeDefinition{} = obj) do
  #   id_field = id_field_template() |> Map.put(:middleware, [])

  #   %{obj | interfaces: [:node | obj.interfaces], fields: [id_field | obj.fields]}
  # end

  def fillout(_, %Schema.ObjectTypeDefinition{identifier: :faction} = obj) do
    obj
  end

  def fillout(_, node) do
    node
  end

  # An id field is automatically configured
  defp interface_body do
    quote do
      field(:id, non_null(:id), description: "The id of the object.")
    end
  end

  # An id arg is automatically added
  defp field_body do
    quote do
      @desc "The id of an object."
      arg(:id, non_null(:id))

      middleware({Absinthe.Relay.Node, :resolve_with_global_id})
    end
  end

  # Automatically add:
  # - An id field that resolves to the generated global ID
  #   for an object of this type
  # - A declaration that this implements the node interface
  defp object_body(id_fetcher) do
    quote do
      @desc "The ID of an object"
      field :id, non_null(:id) do
        middleware {Absinthe.Relay.Node, :global_id_resolver}, unquote(id_fetcher)
      end

      interface(:node)
    end
  end
end
