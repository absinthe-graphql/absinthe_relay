defmodule Absinthe.Relay.SchemaTest do
  use Absinthe.Relay.Case, async: true

  alias Absinthe.Type

  @jack_global_id Base.encode64("Person:jack")

  @papers_global_id Base.encode64("Business:papers")

  @binx_global_id Base.encode64("Kitten:binx")

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :classic

    @people %{
      "jack" => %{id: "jack", name: "Jack", age: 35},
      "jill" => %{id: "jill", name: "Jill", age: 31}
    }
    @businesses %{
      "papers" => %{id: "papers", name: "Papers, Inc!", employee_count: 100},
      "toilets" => %{id: "toilets", name: "Toilets International", employee_count: 1}
    }
    @cats %{"binx" => %{tag: "binx", name: "Mr. Binx", whisker_count: 12}}

    query do
      field :version, :string do
        resolve fn _, _ ->
          {:ok, "0.1.2"}
        end
      end

      node field do
        resolve fn
          %{type: :person, id: id}, _ ->
            {:ok, Map.get(@people, id)}

          %{type: :business, id: id}, _ ->
            {:ok, Map.get(@businesses, id)}

          %{type: :cat, id: id}, _ ->
            {:ok, Map.get(@cats, id)}
        end
      end
    end

    @desc "My Interface"
    node interface do
      resolve_type fn
        %{age: _}, _ ->
          :person

        %{employee_count: _}, _ ->
          :business

        %{whisker_count: _}, _ ->
          :cat

        _, _ ->
          nil
      end
    end

    node object(:person) do
      field :name, :string
      field :age, :string
    end

    node object(:business) do
      field :name, :string
      field :employee_count, :integer
    end

    node object(:cat, name: "Kitten", id_fetcher: &tag_id_fetcher/2) do
      field :name, :string
      field :whisker_count, :integer
    end

    defp tag_id_fetcher(%{tag: value}, _), do: value
    defp tag_id_fetcher(_, _), do: nil
  end

  describe "using node interface" do
    test "creates the :node type" do
      assert %Type.Interface{
               name: "Node",
               description: "My Interface",
               fields: %{id: %Type.Field{name: "id", type: %Type.NonNull{of_type: :id}}}
             } = Schema.__absinthe_type__(:node)
    end
  end

  describe "using node field" do
    test "creates the :node field" do
      assert %{fields: %{node: %{name: "node", type: :node, middleware: middleware}}} =
               Schema.__absinthe_type__(:query)

      middleware = Absinthe.Middleware.unshim(middleware, Schema)

      assert [
               {Absinthe.Middleware.Telemetry, []},
               {{Absinthe.Relay.Node, :resolve_with_global_id}, []},
               {{Absinthe.Resolution, :call}, _}
             ] = middleware
    end
  end

  describe "using node object" do
    test "creates the object" do
      assert %{name: "Kitten"} = Schema.__absinthe_type__(:cat)
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
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @jack_global_id, "name" => "Jack"}}}} =
               Absinthe.run(@query, Schema)
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
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @papers_global_id, "name" => "Papers, Inc!"}}}} =
               Absinthe.run(@query, Schema)
    end
  end

  describe "using the node field and a custom id fetcher defined as an attribute" do
    @query """
    {
      node(id: "#{@binx_global_id}") {
        id
      }
    }
    """
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @binx_global_id}}}} =
               Absinthe.run(@query, Schema)
    end
  end

  defmodule SchemaCustomIdType do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :classic

    @people %{
      "jack" => %{id: "jack", name: "Jack", age: 35},
      "jill" => %{id: "jill", name: "Jill", age: 31}
    }
    @businesses %{
      "papers" => %{id: "papers", name: "Papers, Inc!", employee_count: 100},
      "toilets" => %{id: "toilets", name: "Toilets International", employee_count: 1}
    }
    @cats %{"binx" => %{tag: "binx", name: "Mr. Binx", whisker_count: 12}}

    query do
      field :version, :string do
        resolve fn _, _ ->
          {:ok, "0.1.2"}
        end
      end

      node field(id_type: :string) do
        resolve fn
          %{type: :person, id: id}, _ ->
            {:ok, Map.get(@people, id)}

          %{type: :business, id: id}, _ ->
            {:ok, Map.get(@businesses, id)}

          %{type: :cat, id: id}, _ ->
            {:ok, Map.get(@cats, id)}
        end
      end
    end

    @desc "My Interface"
    node interface(id_type: :string) do
      resolve_type fn
        %{age: _}, _ ->
          :person

        %{employee_count: _}, _ ->
          :business

        %{whisker_count: _}, _ ->
          :cat

        _, _ ->
          nil
      end
    end

    node object(:person, id_type: :string) do
      field :name, :string
      field :age, :string
    end

    node object(:business, id_type: :string) do
      field :name, :string
      field :employee_count, :integer
    end

    node object(:cat, name: "Kitten", id_fetcher: &tag_id_fetcher/2, id_type: :string) do
      field :name, :string
      field :whisker_count, :integer
    end

    defp tag_id_fetcher(%{tag: value}, _), do: value
    defp tag_id_fetcher(_, _), do: nil
  end

  describe "using node interface with custom id type" do
    test "creates the :node type" do
      assert %Type.Interface{
               name: "Node",
               description: "My Interface",
               fields: %{id: %Type.Field{name: "id", type: %Type.NonNull{of_type: :string}}}
             } = SchemaCustomIdType.__absinthe_type__(:node)
    end
  end

  describe "using node field with custom id type" do
    test "creates the :node field" do
      assert %{fields: %{node: %{name: "node", type: :node, middleware: middleware}}} =
               SchemaCustomIdType.__absinthe_type__(:query)

      middleware = Absinthe.Middleware.unshim(middleware, SchemaCustomIdType)

      assert [
               {Absinthe.Middleware.Telemetry, []},
               {{Absinthe.Relay.Node, :resolve_with_global_id}, []},
               {{Absinthe.Resolution, :call}, _}
             ] = middleware
    end
  end

  describe "using node object with custom id type" do
    test "creates the object" do
      assert %{name: "Kitten"} = SchemaCustomIdType.__absinthe_type__(:cat)
    end
  end

  describe "using the node field and a global ID configured with an identifier and custom id type" do
    @query """
    {
      node(id: "#{@jack_global_id}") {
        id
        ... on Person { name }
      }
    }
    """
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @jack_global_id, "name" => "Jack"}}}} =
               Absinthe.run(@query, SchemaCustomIdType)
    end
  end

  describe "using the node field and a global ID configured with a binary and custom id type" do
    @query """
    {
      node(id: "#{@papers_global_id}") {
        id
        ... on Business { name }
      }
    }
    """
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @papers_global_id, "name" => "Papers, Inc!"}}}} =
               Absinthe.run(@query, SchemaCustomIdType)
    end
  end

  describe "using the node field and a custom id fetcher defined as an attribute and custom id type" do
    @query """
    {
      node(id: "#{@binx_global_id}") {
        id
      }
    }
    """
    test "resolves using the global ID" do
      assert {:ok, %{data: %{"node" => %{"id" => @binx_global_id}}}} =
               Absinthe.run(@query, SchemaCustomIdType)
    end
  end
end
