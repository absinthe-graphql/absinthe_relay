defmodule Absinthe.Relay.ConnectionTest do
  use Absinthe.Relay.Case, async: true
  import ExUnit.CaptureLog

  alias Absinthe.Relay.Connection

  @jack_global_id Base.encode64("Person:jack")
  @isotopes_global_id Base.encode64("Team:1")
  @offset_cursor_1 Base.encode64("arrayconnection:1")
  @offset_cursor_2 Base.encode64("arrayconnection:5")
  @invalid_cursor_1 Base.encode64("not_arrayconnection:5")
  @invalid_cursor_2 Base.encode64("arrayconnection:five")
  @invalid_cursor_3 Base.encode64("not a cursor at all")

  defmodule CustomConnectionWithEdgeInfoSchema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    @teams %{
      "1" => %{
        id: "1",
        name: "Isotopes",
        users: [{:owner, "1"}, {:member, "2"}],
        repos: [{%{access: "read"}, "1"}, {%{access: "write"}, "2"}]
      },
      "2" => %{
        id: "2",
        name: "B-Sharps",
        users: [{:owner, "3"}, {:member, "2"}, {:member, "4"}],
        repos: [{%{access: "admin"}, "3"}]
      }
    }

    @users %{
      "1" => %{id: "1", email: "homer@sector7g.burnsnuclear.com"},
      "2" => %{id: "2", email: "lisa.simpson@se.edu"},
      "3" => %{id: "3", email: "bart.simpson@se.edu"},
      "4" => %{id: "4", email: "housewhiz77@hotmail.com"}
    }

    @repos %{
      "1" => %{id: "1", name: "bowlarama"},
      "2" => %{id: "2", name: "krustys"},
      "3" => %{id: "3", name: "leftorium"}
    }

    node object(:user) do
      field :email, :string
    end

    node object(:repo) do
      field :name, :string
    end

    connection node_type: :user do
      edge do
        field :role, :string
      end
    end

    connection node_type: :repo do
      edge do
        field :access, :string
      end
    end

    node object(:team) do
      field :name, :string

      connection field :users, node_type: :user do
        resolve fn
          resolve_args, %{source: team} ->
            Absinthe.Relay.Connection.from_list(
              Enum.map(team.users, fn {role, id} ->
                {Map.get(@users, id), role: role}
              end),
              resolve_args
            )
        end
      end

      connection field :repos, node_type: :repo do
        resolve fn
          resolve_args, %{source: team} ->
            Absinthe.Relay.Connection.from_list(
              Enum.map(team.repos, fn {attrs, id} ->
                {Map.get(@repos, id), attrs}
              end),
              resolve_args
            )
        end
      end
    end

    query do
      node field do
        resolve fn
          %{type: :team, id: id}, _ ->
            {:ok, Map.get(@teams, id)}
        end
      end
    end

    node interface do
      resolve_type fn
        %{name: _}, _ ->
          :team

        _, _ ->
          nil
      end
    end
  end

  defmodule CustomConnectionAndEdgeFieldsSchema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :classic

    @people %{
      "jack" => %{id: "jack", name: "Jack", age: 35, pets: ["1", "2"], favorite_pets: ["2"]},
      "jill" => %{id: "jill", name: "Jill", age: 31, pets: ["3"], favorite_pets: ["3"]}
    }

    @pets %{
      "1" => %{id: "1", name: "Svenja"},
      "2" => %{id: "2", name: "Jock"},
      "3" => %{id: "3", name: "Sherlock"}
    }

    node object(:pet) do
      field :name, :string
      field :age, :string
      field :custom_resolver, :boolean
    end

    connection node_type: :pet do
      field :twice_edges_count, :integer do
        resolve fn _, %{source: conn} ->
          {:ok, length(conn.edges) * 2}
        end
      end

      edge do
        field :node_name_backwards, :string do
          resolve fn _, %{source: edge} ->
            {:ok, edge.node.name |> String.reverse()}
          end
        end

        field :node, :pet do
          resolve fn _, %{source: source} ->
            {:ok, Map.put(source.node, :custom_resolver, true)}
          end
        end
      end
    end

    connection(:favorite_pets_bare, node_type: :pet)
    connection(:non_null_except_node, node_type: :person, non_null: true)
    connection(:non_null, node_type: non_null(:person), non_null: true)
    connection(:non_null_edges, node_type: non_null(:person), non_null_edges: true)
    connection(:non_null_edge, node_type: non_null(:person), non_null_edge: true)

    connection :favorite_pets, node_type: :pet do
      field :fav_twice_edges_count, :integer do
        resolve fn _, %{source: conn} ->
          {:ok, length(conn.edges) * 2}
        end
      end

      edge do
        field :fav_node_name_backwards, :string do
          resolve fn _, %{source: edge} ->
            {:ok, edge.node.name |> String.reverse()}
          end
        end
      end
    end

    node object(:person) do
      field :name, :string
      field :age, :string

      @desc "The pets for a person"
      connection field :pets, node_type: :pet do
        resolve fn resolve_args, %{source: person} ->
          Absinthe.Relay.Connection.from_list(
            Enum.map(person.pets, &Map.get(@pets, &1)),
            resolve_args
          )
        end
      end

      @desc "The favorite pets for a person"
      connection field :favorite_pets, node_type: :pet, connection: :favorite_pets do
        resolve fn resolve_args, %{source: person} ->
          Absinthe.Relay.Connection.from_list(
            Enum.map(person.favorite_pets, &Map.get(@pets, &1)),
            resolve_args
          )
        end
      end

      connection field :non_null_except_node,
                   node_type: :person,
                   connection: :non_null_except_node do
        resolve fn _, args -> Absinthe.Relay.Connection.from_list(@people, args) end
      end

      connection field :non_null, node_type: :person, connection: :non_null do
        resolve fn _, args -> Absinthe.Relay.Connection.from_list(@people, args) end
      end

      connection field :non_null_edge, node_type: :person, connection: :non_null_edge do
        resolve fn _, args -> Absinthe.Relay.Connection.from_list(@people, args) end
      end

      connection field :non_null_edges, node_type: :person, connection: :non_null_edges do
        resolve fn _, args -> Absinthe.Relay.Connection.from_list(@people, args) end
      end
    end

    query do
      node field do
        resolve fn %{type: :person, id: id}, _ ->
          {:ok, Map.get(@people, id)}
        end
      end
    end

    node interface do
      resolve_type fn
        %{age: _}, _ ->
          :person

        _, _ ->
          nil
      end
    end
  end

  defmodule CustomConnectionWithoutRelaySchema do
    use Absinthe.Schema
    import_types(Absinthe.Relay.Connection.Types)
    import Absinthe.Relay.Connection.Notation, only: :macros
    @pipeline_modifier Absinthe.Relay.Schema

    @teams %{
      "1" => %{
        id: "1",
        name: "Isotopes",
        users: [{:owner, "1"}, {:member, "2"}]
      },
      "2" => %{
        id: "2",
        name: "B-Sharps",
        users: [{:owner, "3"}, {:member, "2"}, {:member, "4"}]
      }
    }

    @users %{
      "1" => %{id: "1", email: "homer@sector7g.burnsnuclear.com"},
      "2" => %{id: "2", email: "lisa.simpson@se.edu"},
      "3" => %{id: "3", email: "bart.simpson@se.edu"},
      "4" => %{id: "4", email: "housewhiz77@hotmail.com"}
    }

    object :user do
      field :email, :string
    end

    connection node_type: :user do
      edge do
        field :role, :string
      end
    end

    object :team do
      field :name, :string

      connection field :users, node_type: :user do
        resolve fn
          resolve_args, %{source: team} ->
            Absinthe.Relay.Connection.from_list(
              Enum.map(team.users, fn {role, id} ->
                {Map.get(@users, id), role: role}
              end),
              resolve_args
            )
        end
      end
    end

    query do
      field :team, :team do
        arg :id, non_null(:id)

        resolve fn %{id: id}, _ ->
          {:ok, Map.get(@teams, id)}
        end
      end
    end
  end

  describe "Defining custom connection and edge fields" do
    test " allows querying those additional fields" do
      result =
        """
          query FirstPetName($personId: ID!) {
            node(id: $personId) {
              ... on Person {
                pets(first: 1) {
                  twiceEdgesCount
                  edges {
                    nodeNameBackwards
                    node {
                      name
                      custom_resolver
                    }
                  }
                }
                favoritePets(first: 1) {
                  favTwiceEdgesCount
                  edges {
                    favNodeNameBackwards
                    node {
                      name
                    }
                  }
                }
              }
            }
          }
        """
        |> Absinthe.run(
          CustomConnectionAndEdgeFieldsSchema,
          variables: %{"personId" => @jack_global_id}
        )

      assert {:ok,
              %{
                data: %{
                  "node" => %{
                    "pets" => %{
                      "twiceEdgesCount" => 2,
                      "edges" => [
                        %{
                          "nodeNameBackwards" => "ajnevS",
                          "node" => %{"name" => "Svenja", "custom_resolver" => true}
                        }
                      ]
                    },
                    "favoritePets" => %{
                      "favTwiceEdgesCount" => 2,
                      "edges" => [
                        %{"favNodeNameBackwards" => "kcoJ", "node" => %{"name" => "Jock"}}
                      ]
                    }
                  }
                }
              }} == result
    end
  end

  describe "Defining custom connection and edge fields, with redundant spread fragments" do
    test " allows querying those additional fields" do
      result =
        """
          query FirstPetName($personId: ID!) {
            node(id: $personId) {
              ... on Person {
                pets(first: 1) {
                  twiceEdgesCount
                  edges {
                    nodeNameBackwards
                    node {
                      id
                      ... on Node {
                        ... on Pet {
                          name
                        }
                      }
                    }
                  }
                }
                favoritePets(first: 1) {
                  favTwiceEdgesCount
                  edges {
                    favNodeNameBackwards
                    node {
                      id
                      ... on Pet {
                        ... on Node {
                          ... on Pet {
                            name
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        """
        |> Absinthe.run(
          CustomConnectionAndEdgeFieldsSchema,
          variables: %{"personId" => @jack_global_id}
        )

      assert {:ok,
              %{
                data: %{
                  "node" => %{
                    "pets" => %{
                      "twiceEdgesCount" => 2,
                      "edges" => [
                        %{
                          "nodeNameBackwards" => "ajnevS",
                          "node" => %{"id" => "UGV0OjE=", "name" => "Svenja"}
                        }
                      ]
                    },
                    "favoritePets" => %{
                      "favTwiceEdgesCount" => 2,
                      "edges" => [
                        %{
                          "favNodeNameBackwards" => "kcoJ",
                          "node" => %{"id" => "UGV0OjI=", "name" => "Jock"}
                        }
                      ]
                    }
                  }
                }
              }} == result
    end
  end

  describe "Defining custom edge fields" do
    test " allows querying a single field as 'predicate'" do
      result =
        """
          query TeamAndUsers($teamId: ID!) {
            node(id: $teamId) {
              ... on Team {
                users(first: 1) {
                  edges {
                    role
                    node {
                      email
                    }
                  }
                }
              }
            }
          }
        """
        |> Absinthe.run(CustomConnectionWithEdgeInfoSchema,
          variables: %{"teamId" => @isotopes_global_id}
        )

      assert {:ok,
              %{
                data: %{
                  "node" => %{
                    "users" => %{
                      "edges" => [
                        %{
                          "role" => "owner",
                          "node" => %{"email" => "homer@sector7g.burnsnuclear.com"}
                        }
                      ]
                    }
                  }
                }
              }} == result
    end

    test " allows querying arbitrary edge fields" do
      result =
        """
          query TeamAndRepos($teamId: ID!) {
            node(id: $teamId) {
              ... on Team {
                repos(first: 2) {
                  edges {
                    access
                    node {
                      name
                    }
                  }
                }
              }
            }
          }
        """
        |> Absinthe.run(CustomConnectionWithEdgeInfoSchema,
          variables: %{"teamId" => @isotopes_global_id}
        )

      assert {:ok,
              %{
                data: %{
                  "node" => %{
                    "repos" => %{
                      "edges" => [
                        %{"access" => "read", "node" => %{"name" => "bowlarama"}},
                        %{"access" => "write", "node" => %{"name" => "krustys"}}
                      ]
                    }
                  }
                }
              }} == result
    end
  end

  describe "Utilizing Relay.Connection.Notation macros without Relay.Schema" do
    test " returns the expected connection results" do
      result =
        """
          query GetTeam($teamId: ID!) {
            team(id: $teamId) {
              name
              users(first: 2) {
                edges {
                  role
                  node {
                    email
                  }
                }
              }
            }
          }
        """
        |> Absinthe.run(
          CustomConnectionWithoutRelaySchema,
          variables: %{"teamId" => "1"}
        )

      assert {:ok,
              %{
                data: %{
                  "team" => %{
                    "name" => "Isotopes",
                    "users" => %{
                      "edges" => [
                        %{
                          "role" => "owner",
                          "node" => %{"email" => "homer@sector7g.burnsnuclear.com"}
                        },
                        %{"node" => %{"email" => "lisa.simpson@se.edu"}, "role" => "member"}
                      ]
                    }
                  }
                }
              }} == result
    end
  end

  describe "when provided with a node as an edge arg" do
    setup do
      [record: {%{name: "Dan"}, %{role: "contributor", node: :bad}}]
    end

    test "it will ignore the additional node", %{record: record} do
      capture_log(fn ->
        {:ok, %{edges: [%{node: node} | _]}} = Connection.from_list([record], %{first: 1})
        assert node == %{name: "Dan"}
      end)
    end

    test "it will log a warning", %{record: record} do
      assert capture_log(fn ->
               Connection.from_list([record], %{first: 1})
             end) =~ "Ignoring additional node provided on edge"
    end
  end

  describe "when provided with a cursor as an edge arg" do
    setup do
      [
        records: [
          {%{name: "Dan"}, %{role: "contributor", cursor: "start_cursor"}},
          {%{name: "Bob"}, %{role: "contributor", cursor: "end_cursor"}}
        ]
      ]
    end

    test "it will override the default cursor", %{records: records} do
      assert(
        {:ok,
         %{
           edges: [%{cursor: "start_cursor"}, %{cursor: "end_cursor"}],
           page_info: %{
             start_cursor: "start_cursor",
             end_cursor: "end_cursor"
           }
         }} = Connection.from_list(records, %{first: 2})
      )
    end
  end

  describe "when defined with non_null: true, but node isn't non_null" do
    test "it will define edges and edge as non_null, but node is nullable" do
      connection =
        CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_except_node_connection)

      edge = CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_except_node_edge)

      assert %Absinthe.Type.NonNull{
               of_type: %Absinthe.Type.List{
                 of_type: %Absinthe.Type.NonNull{of_type: :non_null_except_node_edge}
               }
             } == connection.fields.edges.type

      refute Absinthe.Type.non_null?(edge.fields.node.type)
    end
  end

  describe "when defined with non_null: true" do
    test "it will define edges and edge as non_null" do
      connection = CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_connection)
      edge = CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_edge)

      assert %Absinthe.Type.NonNull{
               of_type: %Absinthe.Type.List{
                 of_type: %Absinthe.Type.NonNull{of_type: :non_null_edge}
               }
             } == connection.fields.edges.type

      assert %Absinthe.Type.NonNull{of_type: :person} == edge.fields.node.type
    end
  end

  describe "when defined with non_null_edge: true" do
    test "it will define edge as non_null" do
      connection =
        CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_edge_connection)

      edge = CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_edge_edge)

      assert %Absinthe.Type.List{of_type: %Absinthe.Type.NonNull{of_type: :non_null_edge_edge}} ==
               connection.fields.edges.type

      assert %Absinthe.Type.NonNull{of_type: :person} == edge.fields.node.type
    end
  end

  describe "when defined with non_null_edges: true" do
    test "it will define edges as non_null" do
      connection =
        CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_edges_connection)

      edge = CustomConnectionAndEdgeFieldsSchema.__absinthe_type__(:non_null_edges_edge)

      assert %Absinthe.Type.NonNull{of_type: %Absinthe.Type.List{of_type: :non_null_edges_edge}} ==
               connection.fields.edges.type

      assert %Absinthe.Type.NonNull{of_type: :person} == edge.fields.node.type
    end
  end

  describe ".from_slice/2" do
    test "when the offset is nil test will not do arithmetic on nil" do
      Connection.from_slice([%{foo: :bar}], nil)
    end
  end

  describe ".offset_and_limit_for_query/2" do
    test "with a cursor" do
      assert Connection.offset_and_limit_for_query(%{first: 10, before: @offset_cursor_1}, []) ==
               {:ok, 1, 10}

      assert Connection.offset_and_limit_for_query(%{first: 5, before: @offset_cursor_2}, []) ==
               {:ok, 5, 5}

      assert Connection.offset_and_limit_for_query(%{last: 10, before: @offset_cursor_1}, []) ==
               {:ok, 0, 1}

      assert Connection.offset_and_limit_for_query(%{last: 5, before: @offset_cursor_2}, []) ==
               {:ok, 0, 5}

      # Should be the same result even if nil :first and :after are provided:
      assert Connection.offset_and_limit_for_query(
               %{first: nil, after: nil, last: 5, before: @offset_cursor_2},
               []
             ) ==
               {:ok, 0, 5}

      assert Connection.offset_and_limit_for_query(%{last: 3, before: @offset_cursor_2}, []) ==
               {:ok, 2, 3}
    end

    test "without a cursor" do
      assert Connection.offset_and_limit_for_query(%{first: 10, before: nil}, []) == {:ok, 0, 10}
      assert Connection.offset_and_limit_for_query(%{first: 5, after: nil}, []) == {:ok, 0, 5}

      assert Connection.offset_and_limit_for_query(%{last: 10, before: nil}, count: 30) ==
               {:ok, 20, 10}

      assert Connection.offset_and_limit_for_query(%{last: 5, after: nil}, count: 30) ==
               {:ok, 25, 5}
    end

    test "with an invalid cursor" do
      assert Connection.offset_and_limit_for_query(%{first: 10, before: @invalid_cursor_1}, []) ==
               {:error, "Invalid cursor provided as `before` argument"}

      assert Connection.offset_and_limit_for_query(%{first: 10, before: @invalid_cursor_2}, []) ==
               {:error, "Invalid cursor provided as `before` argument"}

      assert Connection.offset_and_limit_for_query(%{first: 10, before: @invalid_cursor_3}, []) ==
               {:error, "Invalid cursor provided as `before` argument"}

      assert Connection.offset_and_limit_for_query(
               %{last: 5, after: @invalid_cursor_1},
               count: 30
             ) == {:error, "Invalid cursor provided as `after` argument"}
    end
  end

  describe "defaults work" do
    test "no custom edge still produces an edge" do
      assert StarWars.Schema.__absinthe_type__(:ship_edge)
    end
  end
end
