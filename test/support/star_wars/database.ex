defmodule StarWars.Database do

  alias Absinthe.Flag

  @xwing %{
    id: "1",
    name: "X-Wing"
  }

  @ywing %{
    id: "2",
    name: "Y-Wing",
  }

  @awing %{
    id: "3",
    name: "A-Wing",
  }

  # Yeah, technically it's Corellian. But it flew in the service of the rebels,
  # so for the purposes of this demo it"s a rebel ship.
  @falcon %{
    id: "4",
    name: "Millenium Falcon"
  }

  @home_one %{
    id: "5",
    name: "Home One"
  }

  @tie_fighter %{
    id: "6",
    name: "TIE Fighter"
  }

  @tie_interceptor %{
    id: "7",
    name: "TIE Interceptor"
  }

  @executor %{
    id: "8",
    name: "Executor"
}

  @rebels %{
    id: "1",
    name: "Alliance to Restore the Republic",
    ships: ["1", "2", "3", "4", "5"]
  }

  @empire %{
    id: "2",
    name: "Galactic Empire",
    ships: ["6", "7", "8"]
  }

  @data %{
    faction: %{
      "1" => @rebels,
      "2" => @empire
    },
    ship: %{
      "1" => @xwing,
      "2" => @ywing,
      "3" => @awing,
      "4" => @falcon,
      "5" => @home_one,
      "6" => @tie_fighter,
      "7" => @tie_interceptor,
      "8" => @executor
    }
  }

  def data do
    @data
    |> add_max_id(:ship)
    |> add_max_id(:faction)
  end

  def get(node_type, id) do
    data
    |> get_in([node_type, id])
    |> Flag.as(:ok)
  end

  def get_factions(names) do
    factions = data.factions |> Map.values
    names
    |> Enum.map(fn
      name ->
        factions
        |> Enum.find_value(&(&1 == name))
    end)
  end

end
