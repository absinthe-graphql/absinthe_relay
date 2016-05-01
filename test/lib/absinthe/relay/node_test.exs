defmodule Absinthe.Relay.NodeTest do
  use ExSpec, async: true

  alias Absinthe.Relay.Node

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    @foos %{
      "1" => %{id: "1", name: "Bar"}
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
      field :foo, :foo do
        arg :id, non_null(:id)
        resolve parsing_node_ids(&resolve_foo/2, __MODULE__, id: :foo)
      end
    end

    defp resolve_foo(%{id: id}, _) do
      {:ok, Map.get(@foos, id)}
    end

  end

  @foo_id Base.encode64("Foo:1")

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

  describe "parsing_node_id_args" do

    it "parses correctly" do
      result = """
      { foo(id: "#{@foo_id}") { id name } }
      """ |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"foo" => %{"name" => "Bar", "id" => @foo_id}}}} == result
    end

  end

end
