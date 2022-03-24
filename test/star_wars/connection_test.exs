defmodule StarWars.ConnectionTest do
  use Absinthe.Relay.Case, async: true

  describe "Backwards Pagination" do
    test "can start from the end of a list" do
      query = """
        query RebelsShipsQuery {
          rebels {
            name,
            ships1: ships(last: 2) {
              edges {
                node {
                  name
                }
              }
              pageInfo {
                hasPreviousPage
                hasNextPage
              }
            }
            ships2: ships(last: 5) {
              pageInfo {
                hasPreviousPage
                hasNextPage
              }
            }
          }
        }
      """

      expected = %{
        "rebels" => %{
          "name" => "Alliance to Restore the Republic",
          "ships1" => %{
            "edges" => [
              %{
                "node" => %{
                  "name" => "Millennium Falcon"
                }
              },
              %{
                "node" => %{
                  "name" => "Home One"
                }
              }
            ],
            "pageInfo" => %{
              "hasPreviousPage" => true,
              "hasNextPage" => false
            }
          },
          "ships2" => %{"pageInfo" => %{"hasNextPage" => false, "hasPreviousPage" => false}}
        }
      }

      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end

    test "should calculate hasNextPage correctly" do
      query = """
        query RebelsShipsQuery {
          rebels {
            ships(last: 2) {
              pageInfo {
                startCursor
              }
            }
          }
        }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, StarWars.Schema)
      cursor = data["rebels"]["ships"]["pageInfo"]["startCursor"]

      query = """
        query RebelsShipsQuery {
          rebels {
            ships(last: 3, before: "#{cursor}") {
              edges {
                node {
                  name
                }
              }
              pageInfo {
                hasNextPage
                hasPreviousPage
              }
            }
          }
        }
      """

      expected = %{
        "rebels" => %{
          "ships" => %{
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
              },
              %{
                "node" => %{
                  "name" => "A-Wing"
                }
              }
            ],
            "pageInfo" => %{
              "hasPreviousPage" => false,
              "hasNextPage" => true
            }
          }
        }
      }

      assert {:ok, %{data: expected}} == Absinthe.run(query, StarWars.Schema)
    end
  end

  describe "Star Wars connections" do
    test "fetches the first ship of the rebels" do
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

    test "fetches the first two ships of the rebels with a cursor" do
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

    test "fetches the next three ships of the rebels with a cursor" do
      query = """
        query EndOfRebelShipsQuery {
          rebels {
            name,
            ships(first: 3, after: "YXJyYXljb25uZWN0aW9uOjE=") {
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
                  "name" => "Millennium Falcon"
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

    test "fetches no ships of the rebels at the end of connection" do
      query = """
        query RebelsQuery {
          rebels {
            name,
            ships(first: 3, after: "YXJyYXljb25uZWN0aW9uOjQ=") {
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

    test "identifies the end of the list" do
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
            moreShips: ships(first: 3, after: "YXJyYXljb25uZWN0aW9uOjE=") {
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
                  "name" => "Millennium Falcon"
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
