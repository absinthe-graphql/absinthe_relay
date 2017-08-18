defmodule Absinthe.Relay.NodeTest do
  use Absinthe.Relay.Case, async: true

  alias Absinthe.Relay.Node

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    @foos %{
      "1" => %{id: "1", name: "Bar 1"},
      "2" => %{id: "2", name: "Bar 2"}
    }

    node interface do
      resolve_type fn
        _, _  ->
          # We just resolve :foos for now
          :foo
      end
    end

    node object :foo do
      field :name, :string
    end

    node object :other_foo, name: "FancyFoo" do
      field :name, :string
    end

    query do

      field :single_foo, :foo do
        arg :id, non_null(:id)
        resolve parsing_node_ids(&resolve_foo/2, id: :foo)
      end

      field :single_foo_with_multiple_node_types, :foo do
        arg :id, non_null(:id)
        resolve parsing_node_ids(&resolve_foo/2, id: [:foo, :bar])
      end

      field :dual_foo, list_of(:foo) do
        arg :id1, non_null(:id)
        arg :id2, non_null(:id)
        resolve parsing_node_ids(&resolve_foos/2, id1: :foo, id2: :foo)
      end

      field :dual_foo_with_multiple_node_types, list_of(:foo) do
        arg :id1, non_null(:id)
        arg :id2, non_null(:id)
        resolve parsing_node_ids(&resolve_foos/2, id1: [:foo, :bar], id2: [:foo, :bar])
      end

    end

    defp resolve_foo(%{id: %{type: :foo, id: id}}, _) do
      {:ok, Map.get(@foos, id)}
    end
    defp resolve_foo(%{id: id}, _) do
      {:ok, Map.get(@foos, id)}
    end

    defp resolve_foos(%{id1: %{type: :foo, id: id1}, id2: %{type: :foo, id: id2}}, _) do
      {
        :ok,
        [
          Map.get(@foos, id1),
          Map.get(@foos, id2)
        ]
      }
    end
    defp resolve_foos(%{id1: id1, id2: id2}, _) do
      {
        :ok,
        [
          Map.get(@foos, id1),
          Map.get(@foos, id2)
        ]
      }
    end

  end

  @foo1_id Base.encode64("Foo:1")
  @foo2_id Base.encode64("Foo:2")

  describe "to_global_id" do

    it "works given an atom for an existing type" do
      assert !is_nil(Node.to_global_id(:foo, 1, Schema))
    end

    it "returns an atom for an non-existing type" do
      assert is_nil(Node.to_global_id(:not_foo, 1, Schema))
    end

    it "works given a binary and internal ID" do
      assert Node.to_global_id("Foo", 1)
    end

    it "gives the same global ID for different type, equivalent references" do
      assert Node.to_global_id("FancyFoo", 1) == Node.to_global_id(:other_foo, 1, Schema)
    end

    it "gives the different global ID for different type, equivalent references" do
      assert Node.to_global_id("FancyFoo", 1) != Node.to_global_id(:foo, 1, Schema)
    end

    it "fails given a bad ID" do
      assert is_nil(Node.to_global_id("Foo", nil))
    end

  end

  describe "parsing_node_id" do

    it "parses one id correctly" do
      result =
        ~s<{ singleFoo(id: "#{@foo1_id}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"singleFoo" => %{"name" => "Bar 1", "id" => @foo1_id}}}} == result
    end

    it "handles one incorrect id with a single expected type" do
      result =
        ~s<{ singleFoo(id: "#{Node.to_global_id(:other_foo, 1, Schema)}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: ~s<In field "singleFoo": In argument "id": Expected node type in ["Foo"], found "FancyFoo".>}
      ]}} = result
    end

    it "handles one incorrect id with a multiple expected types" do
      result =
        ~s<{ singleFooWithMultipleNodeTypes(id: "#{Node.to_global_id(:other_foo, 1, Schema)}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: ~s<In field "singleFooWithMultipleNodeTypes": In argument "id": Expected node type in ["Foo"], found "FancyFoo".>}
      ]}} = result
    end

    it "handles one correct id with a multiple expected types" do
      result =
        ~s<{ singleFooWithMultipleNodeTypes(id: "#{@foo1_id}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"singleFooWithMultipleNodeTypes" => %{"name" => "Bar 1", "id" => @foo1_id}}}} == result
    end

    it "parses multiple ids correctly" do
      result =
        ~s<{ dualFoo(id1: "#{@foo1_id}", id2: "#{@foo2_id}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"dualFoo" => [
        %{"name" => "Bar 1", "id" => @foo1_id},
        %{"name" => "Bar 2", "id" => @foo2_id}
      ]}}} == result
    end

    it "handles multiple incorrect ids" do
      result =
        ~s<{ dualFoo(id1: "#{Node.to_global_id(:other_foo, 1, Schema)}", id2: "#{Node.to_global_id(:other_foo, 2, Schema)}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: ~s(In field "dualFoo": In argument "id1": Expected node type in ["Foo"], found "FancyFoo".)},
        %{message: ~s(In field "dualFoo": In argument "id2": Expected node type in ["Foo"], found "FancyFoo".)}
      ]}} = result
    end

    it "handles multiple incorrect ids with multiple node types" do
      result =
        ~s<{ dualFooWithMultipleNodeTypes(id1: "#{Node.to_global_id(:other_foo, 1, Schema)}", id2: "#{Node.to_global_id(:other_foo, 2, Schema)}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: ~s(In field "dualFooWithMultipleNodeTypes": In argument "id1": Expected node type in ["Foo"], found "FancyFoo".)},
        %{message: ~s(In field "dualFooWithMultipleNodeTypes": In argument "id2": Expected node type in ["Foo"], found "FancyFoo".)}
      ]}} = result
    end


    it "parses multiple ids correctly with multiple node types" do
      result =
        ~s<{ dualFooWithMultipleNodeTypes(id1: "#{@foo1_id}", id2: "#{@foo2_id}") { id name } }>
        |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"dualFooWithMultipleNodeTypes" => [
        %{"name" => "Bar 1", "id" => @foo1_id},
        %{"name" => "Bar 2", "id" => @foo2_id}
      ]}}} == result
    end

  end

end
