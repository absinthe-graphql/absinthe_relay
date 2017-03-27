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

      field :dual_foo, list_of(:foo) do
        arg :id1, non_null(:id)
        arg :id2, non_null(:id)
        resolve parsing_node_ids(&resolve_foos/2, id1: :foo, id2: :foo)
      end
    end

    defp resolve_foo({:error, _msg} = error, _info), do: error
    defp resolve_foo(%{id: id}, _) do
      {:ok, Map.get(@foos, id)}
    end

    defp resolve_foos(%{id1: id1, id2: id2}, _) do
      {:ok, [
        Map.get(@foos, id1),
        Map.get(@foos, id2)
      ]}
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

  describe "parsing_node_id_args" do

    it "parses one id correctly" do
      result = """
      { singleFoo(id: "#{@foo1_id}") { id name } }
      """ |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"singleFoo" => %{"name" => "Bar 1", "id" => @foo1_id}}}} == result
    end

    it "handles one incorrect id" do
      result = """
      { singleFoo(id: "#{Node.to_global_id(:other_foo, 1, Schema)}") { id name } }
      """ |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: "In field \"singleFoo\": Invalid node type for argument `id`; should be foo, was other_foo"}
      ]}} = result
    end

    it "parses multiple ids correctly" do
      result = """
      { dualFoo(id1: "#{@foo1_id}", id2: "#{@foo2_id}") { id name } }
      """ |> Absinthe.run(Schema)
      assert {:ok, %{data: %{"dualFoo" => [
        %{"name" => "Bar 1", "id" => @foo1_id},
        %{"name" => "Bar 2", "id" => @foo2_id}
      ]}}} == result
    end

    # This never succeeeds.
    # The current implementation of `parsing_node_ids` clobbers the `args` variable on the first failure of `id1`
    # causing the next iteration of the `Enum.reduce` when processing `id2` to blow up when it tries to `Map.get`
    # on the now-clobbered `args` that is actually now a `{:error, ...}` tuple resulting from `id1`
    it "handles multiple incorrect ids" do
      result = """
      { dualFoo(id1: "#{Node.to_global_id(:other_foo, 1, Schema)}", id2: "#{Node.to_global_id(:other_foo, 2, Schema)}") { id name } }
      """ |> Absinthe.run(Schema)
      assert {:ok, %{data: %{}, errors: [
        %{message: "In field \"multipleFoo\": Invalid node type for argument `id1`; should be foo, was other_foo"},
        %{message: "In field \"multipleFoo\": Invalid node type for argument `id2`; should be foo, was other_foo"}
      ]}} = result
    end

  end

end
