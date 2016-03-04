defmodule Absinthe.Relay.SchemaTest do
  use ExSpec, async: true

  alias Absinthe.Type

  defmodule Schema do
    use Absinthe.Relay.Schema

    @people %{"jack" => %{id: "jack", name: "Jack", age: 35},
              "jill" => %{id: "jill", name: "Jill", age: 31}}
    @businesses %{"papers" => %{id: "papers", name: "Papers, Inc!", employee_count: 100},
                  "toilets" => %{id: "toilets", name: "Toilets International", employee_count: 1}}

    query do

      field :version, :string do
        resolve fn
          _, _ ->
            {:ok, "0.1.2"}
        end
      end

      node_field do
        resolve fn
          %{type: :person, id: id}, _ ->
            {:ok, Map.get(@people, id)}
          %{type: :business, id: id}, _ ->
            {:ok, Map.get(@businesses, id)}
        end
      end

    end

    @desc "My Interface"
    node_interface do
      resolve_type fn
        %{age: _}, _ ->
          :person
        %{employee_count: _}, _ ->
          :business
        _, _ ->
          nil
      end
    end

    node_object :person do
      field :name, :string
      field :age, :string
    end

    node_object :business do
      field :name, :string
      field :employee_count, :integer
    end

  end

  @jack_global_id Base.encode64("Person:jack")
  @jill_global_id Base.encode64("Person:jill")
  @papers_global_id Base.encode64("Business:papers")

  describe "using node_interface" do
    it "creates the :node type" do
      assert %Type.Interface{name: "Node", description: "My Interface", fields: %{id: %Type.Field{name: "id", type: %Type.NonNull{of_type: :id}}}} = Schema.__absinthe_type__(:node)
    end
  end

  describe "using node_field" do
    it "creates the :node field" do
      assert %{fields: %{node: %{name: "node", type: :node, resolve: resolver}}} = Schema.__absinthe_type__(:query)
      assert !is_nil(resolver)
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
