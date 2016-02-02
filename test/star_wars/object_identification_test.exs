defmodule StarWars.ObjectIdentificationTest do
  use ExSpec, async: true

  describe "Star Wars object identification" do

    it "fetches the ID and name of the rebels" do
      """
      query RebelsQuery {
        rebels {
          id
          name
        }
      }
      """
      |> assert_data(%{"rebels" => %{"id" => "RmFjdGlvbjox", "name" => "Alliance to Restore the Republic"}})
    end

  end

  defp assert_data(query, data) do
    assert {:ok, %{data: data}} == Absinthe.run(query, StarWars.Schema)
  end

end
