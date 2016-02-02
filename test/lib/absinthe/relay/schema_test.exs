defmodule Absinthe.Relay.SchemaTest do
  use ExSpec, async: true

  alias Absinthe.Type

  defmodule Schema do
    use Absinthe.Relay.Schema

    @people %{"jack" => %{id: "jack", name: "Jack", age: 35},
              "jill" => %{id: "jill", name: "Jill", age: 31}}
    @businesses %{"papers" => %{id: "papers", name: "Papers, Inc!", employee_count: 100},
                  "toilets" => %{id: "toilets", name: "Toilets International", employee_count: 1}}

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
    def node_type_resolver(%{employee_count: _}, _), do: :business
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

    @absinthe :type
    def business do
      %Type.Object{
        fields: fields(
          id: Absinthe.Relay.Node.global_id_field("Business"),
          name: [type: :string],
          employee_count: [type: :integer]
        ),
        interfaces: [:node]
      }
    end

  end

  @jack_global_id Base.encode64("Person:jack")
  @jill_global_id Base.encode64("Person:jill")
  @papers_global_id Base.encode64("Business:papers")

  describe "using Absinthe.Relay.Schema" do
    it "gives you the :node type automatically" do
      assert %Type.Interface{name: "Node"} = Schema.schema.types[:node]
    end
  end

  describe "using the node field and a global ID configured with an identifier" do
    @query """
    {
      node(id: "#{@jack_global_id}") {
        id
        ... on Person { name }
      }
    }
    """
    it "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @jack_global_id, "name" => "Jack"}}}} = Absinthe.run(@query, Schema)
    end
  end

  describe "using the node field and a global ID configured with a binary" do
    @query """
    {
      node(id: "#{@papers_global_id}") {
        id
        ... on Business { name }
      }
    }
    """
    it "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @papers_global_id, "name" => "Papers, Inc!"}}}} = Absinthe.run(@query, Schema)
    end
  end


end
