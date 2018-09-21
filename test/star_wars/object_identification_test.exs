defmodule StarWars.ObjectIdentificationTest do
  use Absinthe.Relay.Case, async: true

  describe "Star Wars object identification" do
    test "fetches the ID and name of the rebels" do
      StarWars.Schema.__absinthe_type__(:faction) |> IO.inspect()

      """
      query RebelsQuery {
        rebels {
          id
          name
        }
      }
      """
      |> assert_data(%{
        "rebels" => %{"id" => "RmFjdGlvbjox", "name" => "Alliance to Restore the Republic"}
      })
    end

    test "fetches the ID and name of the empire" do
      """
      query EmpireQuery {
        empire {
          id
          name
        }
      }
      """
      |> assert_data(%{"empire" => %{"id" => "RmFjdGlvbjoy", "name" => "Galactic Empire"}})
    end

    test "refetches the empire" do
      """
      query EmpireRefetchQuery {
        node(id: "RmFjdGlvbjoy") {
          id
          ... on Faction {
            name
          }
        }
      }
      """
      |> assert_data(%{"node" => %{"id" => "RmFjdGlvbjoy", "name" => "Galactic Empire"}})
    end

    test "refetches the empire, with nested redundant Node fragment" do
      """
      query EmpireRefetchQueryWithExtraNodeFragment {
        node(id: "RmFjdGlvbjoy") {
          id
          ... on Faction {
            ... on Node {
              ... on Faction {
                name
              }
            }
          }
        }
      }
      """
      |> assert_data(%{"node" => %{"id" => "RmFjdGlvbjoy", "name" => "Galactic Empire"}})
    end

    test "refetches the X-Wing" do
      """
      query XWingRefetchQuery {
        node(id: "U2hpcDox") {
          id
          ... on Ship {
            name
          }
        }
      }
      """
      |> assert_data(%{"node" => %{"id" => "U2hpcDox", "name" => "X-Wing"}})
    end
  end

  defp assert_data(query, data) do
    assert {:ok, %{data: data}} == Absinthe.run(query, StarWars.Schema)
  end
end
