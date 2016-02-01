defmodule Absinthe.Relay.SchemaTest do
  use ExSpec, async: true

  alias Absinthe.Type

  defmodule BlankSchema do
    use Absinthe.Relay.Schema

    @people %{"jack" => %{id: "jack", name: "Jack", age: 35},
              "jill" => %{id: "jill", name: "Jill", age: 31}}
    @businesses %{"papers" => %{name: "Papers, Inc!", employee_count: 100},
                  "toilets" => %{name: "Toilets International", employee_count: 1}}

    def query do
      %Type.Object{
        fields: fields(
          version: [type: :string, resolve: fn _, _ -> {:ok, "0.1.2"} end],
        node: Absinthe.Relay.Node.field(fn
          %{type: :person, id: id}, _ ->
            {:ok, Map.get(@people, id)}
          %{type: :business, id: id}, _ ->
            {:ok, Map.get(@businesses, id)}
        end)
        )
      }
    end

    def node_type_resolver(%{age: _}, _), do: :person
    def node_type_resolver(%{business: _}, _), do: :business
    def node_type_resolver(_, _), do: nil

    @absinthe :type
    def person do
      %Type.Object{
        fields: fields(
          id: Absinthe.Relay.Node.global_id_field(:person),
          name: [type: :string],
          age: [type: :integer]
        ),
        interfaces: [:node]
      }
    end

  end

  describe "using Absinthe.Relay.Schema" do
    it "gives you the :node type automatically" do
      assert %Type.Interface{name: "Node"} = BlankSchema.schema.types[:node]
    end
  end

  describe "using the node field" do
    @query """
    {
      node(id: "person:jack") {
        id
        ... on Person { name }
      }
    }
    """
    it "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => "person:jack", "name" => "Jack"}}}} = Absinthe.run(@query, BlankSchema)
    end
  end

end
