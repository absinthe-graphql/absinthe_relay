defmodule StarWars.ConnectionTest do
  use ExSpec, async: true

  describe "Star Wars connections" do

    it "fetches the first ship of the rebels" do
      query = """
        query RebelsShipsQuery {
          rebels {
            name,
            ships(first: 1) {
              edges {
                node {
                  name
                }
              }
            }
          }
        }
      """
      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "ships" => %{
            "edges" => [
              %{
                "node" => %{
                  "name" => "X-Wing"
                }
              }
            ]
          }
        }
      }
      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

    @tag :focus
    it "fetches the first two ships of the rebels with a cursor" do
      query = """
        query MoreRebelShipsQuery {
          rebels {
            name,
            ships(first: 2) {
              edges {
                cursor,
                node {
                  name
                }
              }
            }
          }
        }
      """
      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "ships" => %{
            "edges" => [
              %{
                "cursor" => "YXJyYXljb25uZWN0aW9uOjA=",
                "node" => %{
                  "name" => "X-Wing"
                }
              },
              %{
                "cursor" => "YXJyYXljb25uZWN0aW9uOjE=",
                "node" => %{
                  "name" => "Y-Wing"
                }
              }
            ]
          }
        }
      }
      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

    it "fetches the next three ships of the rebels with a cursor" do
      query = """
        query EndOfRebelShipsQuery {
          rebels {
            name,
            ships(first: 3 after: "YXJyYXljb25uZWN0aW9uOjE=") {
              edges {
                cursor,
                node {
                  name
                }
              }
            }
          }
        }
      """
      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "ships" => %{
            "edges" => [
              %{
                "cursor" => "YXJyYXljb25uZWN0aW9uOjI=",
                "node" => %{
                  "name" => "A-Wing"
                }
              },
              %{
                "cursor" => "YXJyYXljb25uZWN0aW9uOjM=",
                "node" => %{
                  "name" => "Millenium Falcon"
                }
              },
              %{
                "cursor" => "YXJyYXljb25uZWN0aW9uOjQ=",
                "node" => %{
                  "name" => "Home One"
                }
              }
            ]
          }
        }
      }
      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

    it "fetches no ships of the rebels at the end of connection" do
      query = """
        query RebelsQuery {
          rebels {
            name,
            ships(first: 3 after: "YXJyYXljb25uZWN0aW9uOjQ=") {
              edges {
                cursor,
                node {
                  name
                }
              }
            }
          }
        }
      """
      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "ships" => %{
            "edges" => []
          }
        }
      }
      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

    it "identifies the end of the list" do
      query = """
        query EndOfRebelShipsQuery {
          rebels {
            name,
            originalShips: ships(first: 2) {
              edges {
                node {
                  name
                }
              }
              pageInfo {
                hasNextPage
              }
            }
            moreShips: ships(first: 3 after: "YXJyYXljb25uZWN0aW9uOjE=") {
              edges {
                node {
                  name
                }
              }
              pageInfo {
                hasNextPage
              }
            }
          }
        }
      """
      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "originalShips" => %{
            "edges" => [
              %{
                "node" => %{
                  "name" => "X-Wing"
                }
              },
              %{
                "node" => %{
                  "name" => "Y-Wing"
                }
              }
            ],
            "pageInfo" => %{
              "hasNextPage" => true
            }
          },
          "moreShips" => %{
            "edges" => [
              %{
                "node" => %{
                  "name" => "A-Wing"
                }
              },
              %{
                "node" => %{
                  "name" => "Millenium Falcon"
                }
              },
              %{
                "node" => %{
                  "name" => "Home One"
                }
              }
            ],
            "pageInfo" => %{
              "hasNextPage" => false
            }
          }
        }
      }
      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

  end
end
