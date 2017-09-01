defmodule Absinthe.Relay.Node.ParseIDsTest do
  use Absinthe.Relay.Case, async: true

  alias Absinthe.Relay.Node

  defmodule Foo do
    defstruct [:id, :name]
  end

  defmodule Parent do
    defstruct [:id, :name, :children]
  end

  defmodule Child do
    defstruct [:id, :name]
  end

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :classic

    alias Absinthe.Relay.Node.ParseIDsTest.Foo
    alias Absinthe.Relay.Node.ParseIDsTest.Parent
    alias Absinthe.Relay.Node.ParseIDsTest.Child

    @foos %{
      "1" => %Foo{id: "1", name: "Foo 1"},
      "2" => %Foo{id: "2", name: "Foo 2"}
    }

    node interface do
      resolve_type fn
        %Foo{}, _  ->
          :foo
        %Parent{}, _  ->
          :parent
        %Child{}, _  ->
          :child
        _, _ ->
          nil
      end
    end

    node object :foo do
      field :name, :string
    end

    node object :other_foo, name: "FancyFoo" do
      field :name, :string
    end

    node object :parent do
      field :name, :string
      field :children, list_of(:child)
      field :child, :child
    end

    node object :child do
      field :name, :string
    end

    input_object :parent_input do
      field :id, non_null(:id)
      field :children, list_of(:child_input)
      field :child, non_null(:child_input)
    end

    input_object :child_input do
      field :id, non_null(:id)
    end

    query do

      field :foo, :foo do
        arg :foo_id, :id
        arg :foobar_id, :id
        middleware Absinthe.Relay.Node.ParseIDs, foo_id: :foo
        middleware Absinthe.Relay.Node.ParseIDs, foobar_id: [:foo, :bar]
        resolve &resolve_foo/2
      end

      field :foos, list_of(:foo) do
        arg :foo_ids, list_of(:id)
        middleware Absinthe.Relay.Node.ParseIDs, foo_ids: :foo
        resolve &resolve_foos/2
      end

    end

    mutation do

      payload field :update_parent do

        input do
          field :parent, :parent_input
        end

        output do
          field :parent, :parent
        end

        resolve &resolve_parent/2

      end

      payload field :update_parent_local_middleware do

        input do
          field :parent, :parent_input
        end

        output do
          field :parent, :parent
        end

        middleware Absinthe.Relay.Node.ParseIDs, parent: [
          id: :parent,
          children: [id: :child],
          child: [id: :child]
        ]

        resolve &resolve_parent/2

      end

    end

    defp resolve_foo(%{foo_id: id}, _) do
      {:ok, Map.get(@foos, id)}
    end
    defp resolve_foo(%{foobar_id: %{id: id, type: :foo}}, _) do
      {:ok, Map.get(@foos, id)}
    end

    defp resolve_foos(%{foo_ids: ids}, _) do
      values = Enum.map(ids, &Map.get(@foos, &1))
      {:ok, values}
    end

    defp resolve_parent(args, _) do
      {:ok, args}
    end

    @update_parent_ids {
      Absinthe.Relay.Node.ParseIDs, [
        # Needs `input` because this is being inserted
        # before the mutation middleware.
        input: [
          parent: [
            id: :parent,
            children: [id: :child],
            child: [id: :child]
          ]
        ]
      ]
    }
    def middleware(middleware, %{identifier: :update_parent}, _) do
      [@update_parent_ids | middleware]
    end
    def middleware(middleware, _, _) do
      middleware
    end

  end

  @foo1_id Base.encode64("Foo:1")
  @foo2_id Base.encode64("Foo:2")

  test "parses one id correctly" do
    result =
      """
      {
        foo(fooId: "#{@foo1_id}") {
          id
          name
        }
      }
      """
      |> Absinthe.run(Schema)
    assert {:ok, %{data: %{"foo" => %{"name" => "Foo 1", "id" => @foo1_id}}}} == result
  end

  test "parses a list of ids correctly" do
    result =
      """
      {
        foos(fooIds: ["#{@foo1_id}", "#{@foo2_id}"]) { id name }
      }
      """
      |> Absinthe.run(Schema)
    assert {:ok,
      %{
        data: %{
          "foos" => [
            %{"name" => "Foo 1", "id" => @foo1_id},
            %{"name" => "Foo 2", "id" => @foo2_id}
          ]
        }
      }
    } == result
  end

  test "parses an id into one of multiple node types" do
    result =
      """
      {
        foo(foobarId: "#{@foo1_id}") { id name }
      }
      """
      |> Absinthe.run(Schema)
    assert {:ok, %{data: %{"foo" => %{"name" => "Foo 1", "id" => @foo1_id}}}} == result
  end

  @tag :focus
  test "parses nested ids" do
    encoded_parent_id = Base.encode64("Parent:1")
    encoded_child1_id = Base.encode64("Child:1")
    encoded_child2_id = Base.encode64("Child:1")
    result =
      """
      mutation Foobar {
        updateParent(input: {
          clientMutationId: "abc",
          parent: {
            id: "#{encoded_parent_id}",
            children: [{ id: "#{encoded_child1_id}"}, {id: "#{encoded_child2_id}"}],
            child: { id: "#{encoded_child2_id}"}
          }
        }) {
          parent {
            id
            children { id }
            child { id }
            }
          }
      }
      """
      |> Absinthe.run(Schema)

    expected_parent_data = %{
      "parent" => %{
        "id" => encoded_parent_id, # The output re-converts everything to global_ids.
        "children" => [%{"id" => encoded_child1_id}, %{"id" => encoded_child2_id}],
        "child" => %{
          "id" => encoded_child2_id
        }
      }
    }
    assert {:ok, %{data: %{"updateParent" => expected_parent_data}}} == result
  end

  test "parses incorrect nested ids" do
    encoded_parent_id = Base.encode64("Parent:1")
    incorrect_id = Node.to_global_id(:other_foo, 1, Schema)
    mutation =
      """
      mutation Foobar {
        updateParent(input: {
          clientMutationId: "abc",
          parent: {
            id: "#{encoded_parent_id}",
            child: {id: "#{incorrect_id}"}
          }
        }) {
          parent {
          id
          child { id }
        }
      }
    }
    """
    assert {:ok, result} = Absinthe.run(mutation, Schema)
    assert %{
      data: %{"updateParent" => nil},
      errors: [%{
        locations: [%{column: 0, line: 2}],
        message: ~s<In field "updateParent": In argument "input": In field "parent": In field "child": In field "id": Expected node type in ["Child"], found "FancyFoo".>
      }]
    } = result
  end

  test "handles one incorrect id correctly" do
    result =
      """
      {
        foo(fooId: "#{Node.to_global_id(:other_foo, 1, Schema)}") {
          id
          name
        }
      }
      """
      |> Absinthe.run(Schema)
    assert {
      :ok, %{
        data: %{},
        errors: [
          %{message: ~s<In field "foo": In argument "fooId": Expected node type in ["Foo"], found "FancyFoo".>}
        ]
      }
    } = result
  end

 test "parses nested ids with local middleware" do
    encoded_parent_id = Base.encode64("Parent:1")
    encoded_child1_id = Base.encode64("Child:1")
    encoded_child2_id = Base.encode64("Child:1")
    result =
      """
      mutation FoobarLocal {
        updateParentLocalMiddleware(input: {
          clientMutationId: "abc",
          parent: {
            id: "#{encoded_parent_id}",
            children: [{ id: "#{encoded_child1_id}"}, {id: "#{encoded_child2_id}"}],
            child: { id: "#{encoded_child2_id}"}
          }
        }) {
          parent {
            id
            children { id }
            child { id }
            }
          }
      }
      """
      |> Absinthe.run(Schema)

    expected_parent_data = %{
      "parent" => %{
        "id" => encoded_parent_id, # The output re-converts everything to global_ids.
        "children" => [%{"id" => encoded_child1_id}, %{"id" => encoded_child2_id}],
        "child" => %{
          "id" => encoded_child2_id
        }
      }
    }
    assert {:ok, %{data: %{"updateParentLocalMiddleware" => expected_parent_data}}} == result
  end

end
