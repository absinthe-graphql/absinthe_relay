defmodule Absinthe.Relay.Node.ParseIDsTest do
  use Absinthe.Relay.Case, async: true

  alias Absinthe.Relay.Node

  defmodule Foo do
    defstruct [:id, :name]
  end

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    alias Absinthe.Relay.Node.ParseIDsTest.Foo

    @foos %{
      "1" => %Foo{id: "1", name: "Foo 1"},
      "2" => %Foo{id: "2", name: "Foo 2"}
    }

    node interface do
      resolve_type fn
        %Foo{}, _  ->
          :foo
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

    query do

      field :foo, :foo do
        arg :foo_id, non_null(:id)
        middleware Absinthe.Relay.Node.ParseIDs, foo_id: :foo
        resolve &resolve_foo/2
      end

    end

    defp resolve_foo(%{foo_id: id}, _) do
      {:ok, Map.get(@foos, id)}
    end

  end

  @foo1_id Base.encode64("Foo:1")

  it "parses one id correctly" do
    result =
      ~s<{ foo(fooId: "#{@foo1_id}") { id name } }>
      |> Absinthe.run(Schema)
    assert {:ok, %{data: %{"foo" => %{"name" => "Foo 1", "id" => @foo1_id}}}} == result
  end

  it "handles one incorrect id correctly" do
    result =
      ~s<{ foo(fooId: "#{Node.to_global_id(:other_foo, 1, Schema)}") { id name } }>
      |> Absinthe.run(Schema)
    assert {:ok, %{data: %{}, errors: [
      %{message: ~s<In field "foo": In argument "fooId": Expected node type :foo, found :other_foo.>}
    ]}} = result
  end

end